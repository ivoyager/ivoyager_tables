# Tables v0.3 Redesign: Advance Notice

Tables v0.3 will store table columns in Godot's packed arrays. It will be released together with ivoyager_core v0.3. Table files keep working as they are. Code that reads IVTableData's data structures directly, or that calls one of the four methods whose return type changes, will need updating.

## In short

* Every column type that has a packed counterpart is stored as that packed array: FLOAT as `PackedFloat64Array`, BOOL as `PackedByteArray`, and so on. STRING_NAME, VARIANT and ARRAY columns stay Arrays.
* ENTITY_X_ENTITY rows and float precisions are packed by the same rule.
* New column types: FLOAT64, FLOAT32, INT64, INT32 and BYTE.
* Nothing is read-only anymore. Read-only becomes guidance that the plugin does not enforce.
* `get_db_field_array()` returns `Variant`, and `get_db_matching_rows()`, `get_db_true_rows()` and `get_db_float_precisions()` return `PackedInt32Array`. All other return types are unchanged.
* Methods hand out arrays as copies instead of live table data: a column from `get_db_field_array()`, an enumeration from `get_enumeration_array()`, and any cell that holds an array. Dictionaries stay live.

## Why

v0.2 stored every column in a typed Array, and every element of an Array takes 24 bytes whether typed or not. A packed array stores each element at its own size: a FLOAT cell takes 8 bytes, a FLOAT32 cell 4 (v0.2 had no 32-bit option) and a BOOL cell 1. Smaller elements mean a smaller cache footprint, and packed arrays are generally faster to iterate than typed Arrays. A packed column also passes to engine APIs and to GDExtension C++ without converting each element.

The costs are the read-only protection (described below) and Array methods that packed arrays lack, such as `map()`, `filter()` and `max()`. If the latter methods are needed, you can convert the specific packed table data to an Array.

## Column storage

| Table type | v0.2 column | v0.3 column |
|---|---|---|
| `FLOAT`, `FLOAT64` (new) | `Array[float]` | `PackedFloat64Array` |
| `FLOAT32` (new) | | `PackedFloat32Array` |
| `INT`, `INT64` (new) | `Array[int]` | `PackedInt64Array` |
| `INT32` (new) | | `PackedInt32Array` |
| `<ClassName>.<EnumName>` | `Array[int]` | `PackedInt64Array` |
| `TABLE_ROW` | `Array[int]` | `PackedInt32Array` |
| `BOOL` | `Array[bool]` | `PackedByteArray` |
| `BYTE` (new) | | `PackedByteArray` |
| `STRING` | `Array[String]` | `PackedStringArray` |
| `STRING_NAME` | `Array[StringName]` | `Array[StringName]` (unchanged) |
| `VECTOR2`, `VECTOR3`, `VECTOR4` | `Array[Vector2]`, ... | `PackedVector2Array`, ... |
| `COLOR` | `Array[Color]` | `PackedColorArray` |
| `VARIANT` | `Array` | `Array` (unchanged) |
| `ARRAY[<type>]` | `Array[Array]` | `Array[Array]` (unchanged) |

The implicit `name` column stays `Array[StringName]`.

* **Packing changes no values.** FLOAT and INT keep 64 bits, and vectors and colors keep the precision Godot's Vector and Color types always have. Only the opt-in FLOAT32 and INT32 narrow a column, for values that fit.
* **FLOAT64 and INT64 are other names for FLOAT and INT.** FLOAT32 and INT32 read cells exactly as FLOAT and INT do, including empty cells (NAN and -1).
* **TABLE_ROW is 32-bit; enum columns are 64-bit.** A row index always fits in 32 bits. An enum column holds the enum's own values, and flag enums use bits above 31: ivoyager_core's `IVBody.BodyFlags` allows bits up to `1 << 62`.
* **BOOL cells read back as the ints 0 and 1.** `get_db_bool()` still returns a `bool`. Reading the column directly gives an int: `if column[row]:` works, but `column[row] == true` is a runtime error (Godot has no `==` between int and bool) and `is_same(column[row], true)` is false.
* **BYTE is new:** an unsigned value from 0 to 255. Cells take INT's syntax (decimal, hex, binary and `|`-or'd flags). An empty cell with no Default reads 255 (`0xFF`), the byte that INT's -1 becomes, so `db_has_value()` can still tell an empty cell from 0.
* **ENTITY_X_ENTITY rows follow the same rule.** Each row of `exe_tables[table]` is the column type its `@DATA_TYPE` gives above, so a `@DATA_TYPE=VECTOR2` table has `PackedVector2Array` rows. `@DATA_TYPE` accepts the new types.
* **ARRAY cells stay typed Arrays** (`Array[float]`, `Array[int]`, ...). Those can't hold narrower values, so FLOAT32, INT32 and BYTE are not valid inside `ARRAY[...]`. FLOAT64 and INT64 are, as aliases.
* **Float precisions** (with `enable_precisions = true`) become `PackedInt32Array` columns in `precisions`.

## Read-only becomes guidance

Godot can't make a packed array read-only, so v0.3 drops `make_read_only()` everywhere rather than protecting some containers and not others. Nothing IVTableData holds is read-only anymore, dictionaries and Arrays included. We recommend treating table data as immutable as a design principle, but this is no longer enforced or detected immediately at write as a GDScript error.

* **Direct access reaches the live table data.** GDScript passes packed arrays by reference, so `var masses: PackedFloat64Array = ships[&"mass"]` aliases the column, and a write through `masses` changes it for every reader.
* **Methods hand out arrays as copies,** so reading arrays through the API is safe. `get_db_field_array()` copies the column and `get_enumeration_array()` the enumeration. A cell that holds an array (an ARRAY cell, or a VARIANT cell holding an Array or packed array) is copied by every method that hands it out, whether the method returns it (`get_db_array()`, `get_db_variant()`, `db_lookup()`, `get_db_row_data_array()`) or puts it into your object or dictionary (`db_build_object()`, `db_build_dictionary()`). Each copy is copy-on-write, so it is essentially free: it shares the table's storage until something writes to it, and the first write gives it storage of its own.
* **Copies are shallow.** An element that is itself an Array or Dictionary is still the table's own. In particular, the cells of a copied ARRAY column are live; take one cell with `get_db_array()` to get it as a copy.
* **Dictionaries are not copied,** because duplicating one copies every entry. `get_enumeration_dict()` and `get_wiki_page_titles()` return the plugin's own dictionaries, and a VARIANT cell holding a Dictionary is live wherever a method hands it out, including `get_db_dictionary()`.
* **A write that raised an error in v0.2 now succeeds silently.** Code can no longer rely on the read-only error to catch this misuse.
* **Thread safety is unchanged in practice.** The plugin writes table data only inside `postprocess_tables()`, so any number of threads can read it afterward, as long as nothing writes to it.

## API changes

* `get_db_field_array(table, field)` returns a copy of the column, as `Variant`. Type the variable that receives it: `var masses: PackedFloat64Array = IVTableData.get_db_field_array(&"ships", &"mass")`.
* `get_db_matching_rows()`, `get_db_true_rows()` and `get_db_float_precisions()` return `PackedInt32Array` instead of `Array[int]`.
* `get_enumeration_array()` keeps its signature but returns a copy, still an `Array[StringName]` (StringName has no packed array).
* `get_db_array()`, `get_db_variant()`, `db_lookup()`, `get_db_row_data_array()`, `db_build_object()` and `db_build_dictionary()` keep their signatures, but a cell that holds an array comes out as a copy.
* Every other method keeps its signature and behavior.
* The data structures change wherever they hold columns or rows. A table in `db_tables` becomes a `Dictionary[StringName, Variant]` (was `Dictionary[StringName, Array]`), because its columns no longer share a type. The columns in `precisions` and the rows in `exe_tables` become packed arrays as described above.

## Updating your code

Most of these errors surface only at runtime, because a read from `db_tables` or `exe_tables` is Variant-typed and the editor can't check it. Search for them rather than waiting for the editor.

The rule: hold a table in an untyped `Dictionary` (or an ENTITY_X_ENTITY table in an untyped `Array`), and type the column or row you take out of it. The examples use a hypothetical `ships` table.

| v0.2 code | In v0.3 | Write instead |
|---|---|---|
| `var ships: Dictionary[StringName, Array] = IVTableData.db_tables[&"ships"]` | Error: the table is a `Dictionary[StringName, Variant]` | `var ships: Dictionary = IVTableData.db_tables[&"ships"]` |
| `var masses: Array[float] = ships[&"mass"]` | Error: a packed array is not an `Array[float]` | `var masses: PackedFloat64Array = ships[&"mass"]` |
| `var masses: Array = ships[&"mass"]` | Runs, but builds an untyped copy of the column each time | Type it as the packed array |
| `PackedFloat32Array(ships[&"mass"])` | Error: Godot has no conversion from one packed type to another | Declare the column FLOAT32, or use the `PackedFloat64Array` |
| `PackedInt32Array(ships[&"crew"])` on an INT column | Error, as above: the column is a `PackedInt64Array` | Declare the column INT32, or use the `PackedInt64Array` |
| `PackedInt32Array(ships[&"home_port"])` on a TABLE_ROW column | Runs, but only copies | Use the column itself |
| `if ships[&"is_armed"][row] == true:` | Error: no `==` between int and bool | `if ships[&"is_armed"][row]:` |
| `var row: Array[Vector2] = IVTableData.exe_tables[&"ships_ports"][i]` | Error: a packed array is not an `Array[Vector2]` | `var row: PackedVector2Array = IVTableData.exe_tables[&"ships_ports"][i]` |
| `var rows: Array[int] = IVTableData.get_db_true_rows(&"ships", &"is_armed")` | Error | `var rows := IVTableData.get_db_true_rows(&"ships", &"is_armed")` |

In Godot 4.7 the runtime errors read:

* `Trying to assign a dictionary of type "Dictionary[StringName, Nil]" to a variable of type "Dictionary[StringName, Array]".`
* `Trying to assign a value of type "PackedFloat64Array" to a variable of type "Array[float]".`
* `Invalid type in 'PackedFloat32Array' constructor. Cannot convert argument 1 from PackedFloat64Array to Array.`
* `Invalid operands 'int' and 'bool' in operator '=='.`

To find affected code, search for `Dictionary[StringName, Array]` and `Array[...]` variables that receive table data, for `Packed...Array(` wrapped around a table read, and for `== true` or `== false` on a BOOL cell. Projects that convert columns to packed arrays at startup can drop that code, and must drop it where the conversion crosses packed types. Holding a table in an untyped `Dictionary` already works in v0.2, so that part can change now.
