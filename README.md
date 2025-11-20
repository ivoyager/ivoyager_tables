# I, Voyager - Tables

TL;DR: This Godot Editor plugin imports tables like [this](https://github.com/ivoyager/ivoyager_core/blob/master/tables/planets.tsv) and provides access to processed, statically typed data. It can impute defaults, convert floats by specified units, prefix text, convert text enumerations to integers, and much more! 

This plugin works best in combination with our [Units plugin](https://github.com/ivoyager/ivoyager_units). You can use it without that plugin, but you will need to supply your own unit coversion method to use any units functionality.

This plugin was developed for our solar system explorer app [Planetarium](https://www.ivoyager.dev/planetarium/) and related projects.

## Installation

Find more detailed instructions at our [Developers Page](https://www.ivoyager.dev/developers/).

The plugin directory `ivoyager_tables` should be added _directly to your addons directory_. You can do this one of two ways:

1. Download and extract the plugin, then add it (in its entirety) to your addons directory, creating an "addons" directory in your project if needed.
2. (Recommended) Add as a git submodule. From your project directory, use git command:  
	`git submodule add https://github.com/ivoyager/ivoyager_tables addons/ivoyager_tables`  
	This method will allow you to version-control the plugin from within your project rather than moving directories manually. You'll be able to pull updates, checkout any commit, or submit pull requests back to us. This does require some learning to use git submodules. (We use [GitKraken](https://www.gitkraken.com/) to make this easier!)

Then enable "I, Voyager - Tables" from Project/Project Settings/Plugins. The plugin will provide an autoload singleton called "IVTableData" through which you can provide postprocessing intructions and interact with processed table data.

## Overview

This plugin is powerful but requires specific file formatting. It's not meant to be a general "read any" table utility.

Table features:
* Specification of data **Type** so that all table values are correctly converted to statically typed internal values.
* Specification of data **Default** to reduce table clutter. Cells that are a common default value can be left empty.
* Specification of data **Prefix** to reduce enumeration text size. E.g., skip redundant prefix text in PLANET_MERCURY, PLANET_VENUS, etc..
* Specification of float **Unit** so file data can be entered in the most convenient units while maintaining consistent internal representation. Unit can be specified for a whole float column or within a float cell (e.g., "1000 d" or "1000/d"). Conversion is provided by our [Units plugin](https://github.com/ivoyager/ivoyager_units), or, alternatively, by a project-supplied conversion Callable. Our Units plugin knows SI units and many others, and can parse arbitrary compound units like "m^3/(kg s^2)".
* Table **enumerations** that may reference project or Godot enums _**or**_ table-defined entity names. For example, in our project, "PLANET_EARTH" resolves to 3 (in columns of type TABLE_ROW) _in any table_ because "PLANET_EARTH" is row 3 in [planets.tsv](https://github.com/ivoyager/ivoyager_core/blob/master/tables/planets.tsv).
* Table **constants** that can be used in columns of any type. This is how the plugin handles things like "TRUE" and "-Inf" but also can be used to add arbitrary constants like "MARS_PERIHELION" or "SOME_LARGE_TEXT_ITEM" if needed.
* Tables that modify other tables.
* **Modding support** that allows your game or project users to replace base tables with modded tables (e.g., in a user directory: user://modding/mod_files/).
* Construction of a **wiki** lookup dictionary from file tables to use for an internal or external wiki.
* [For scientific apps, mostly] Determination of float **significant digits** from file number text, so precision can be correctly displayed even after unit conversion.
* Singleton **IVTableData** provides access to statically typed data directly in data structures (e.g., dictionaries of field arrays for "db-style" data) or via methods. Methods include "constructors" for building objects, dictionaries or flag fields directly from table data.

File and table formats are described below.

## Usage

All user interface is via an autoload singleton **IVTableData** added by the plugin. From here you will give postprocessing intructions and access all postprocessed table data directly in data structures or via methods. See API in [table_data.gd](https://github.com/ivoyager/ivoyager_tables/blob/master/table_data.gd).

Postprocessing happens once when the project calls `postprocess_tables()`. The call allows specification of tables to process, new table constants, redefinition of default "missing values" (NAN for FLOAT, -1 for INT, etc.), specification of wiki page title fields, and other options. After this call, all table data is read only.

The editor plugin imports table files as a custom resource class, but you can ignore that. The resource isn't useful except possibly for table debugging.

## General File Format

#### Delimiter and File Extension

We support only tab-delimited files with extension "tsv".

#### Table Directives

Any line starting with "@" is read as a table directive, which is used to specify one of several table formats and provide additional format-specific instructions. These can be at any line in the file. It may be convenient to include these at the end as many table viewers (including GitHub web pages) assume field names in the top line.

Table format is specified by one of `@DB_ENTITIES` (default), `@DB_ENTITIES_MOD`, `@DB_ANONYMOUS`, `@ENUMERATION`, `@WIKI_ONLY`, or `@ENTITY_X_ENTITY`, optionally followed by "=" and then the table name. If omitted, table name is taken from the base file name (e.g., "planets" for "res://path/planets.tsv" file). Several table formats don't need a table format specifier as the importer can figure it out from other clues. Some table formats allow or require additional specific directives. See details in format sections below.

For debugging or work-in-progress, you can prevent any imported table from being processed using `@DONT_PARSE`. (It's still technically imported by the editor but won't be parsed line-by-line or handled by the postprocessor.)

#### Comments

Any line starting with "#" is ignored. Additionally, entire columns are ignored if the column field name begins with "#".

#### General Cell Processing

All cells are stripped of double-quotes if they enclose the cell on both sides (these are silently added by some editors).

Spaces are edge-stripped from cells and cell elements ("cell element" refers to comma- or semicolon-delimited data within cells of certain types, such as VECTORx, COLOR, and ARRAY[xxxx]).

#### Data Types

Type is specified by column field for "db-style" format or for the whole table for "entity x entity" format. Each data type has a "missing" value that is used if the cell is empty and there is no field or table default value. Default "missing" values are indicated by type below, but these can be respecified. Allowed types are:

* `STRING` - Data processing applies Godot escaping such as \n, \t, etc. We also convert unicode "\u" escaping  up to \uFFFF, but not "\U" escaping for larger unicodes. Empty cells will be imputed with default value (if specified) or "".
* `STRING_NAME` - No escaping. Empty cells will be imputed with default value (if specified) or &"".
* `BOOL` - Recognized table values include: "TRUE", "True", "true", "x" (interpreted as true), "FALSE", "False" and "false" (these are table constants that can be modified in the call to `postprocess_tables()`). Empty cells will be imputed with default value (if specified) or false. Any other cell values will cause an error.
* `FLOAT` - Commas and underscores are allowed and removed before float conversion. "E" or "e" are ok. A "~" prefix is allowed and affects precision (see below) but not float value. Recognized table values include: "NAN", "Nan", "nan", "INF", "Inf", "inf", "-INF", "-Inf" and "-inf" (these are table constants that can be modified in the call to `postprocess_tables()`). Empty cells will be imputed with default value (if specified) or NAN. **Inline units:** An inline unit can be specified using format "x unit" or "x/unit". E.g., "1000 d" and "1000/d" are valid (the latter is equivilent to "1000 1/d"). If an inline unit is present, it will override the column or table unit (see table formats below).
* `VECTOR2`, `VECTOR3`, `VECTOR4` - Enter in table cell as a comma-delimited set of 2, 3 or 4 float values. All rules for floats above apply except vector elements cannot have commas. Empty cells will be imputed with default value (if specified) or VectorX(-INF, -INF,...).
* `COLOR` - Cell content is interpretted in a sensible way. Valid representations of red include: "red", "ff0000", "red, 1.0", "1, 0, 0" and "1, 0, 0, 1". Empty cells will be imputed with default value (if specified) or Color(-INF, -INF, -INF, -INF).
* `INT` - A valid integer. Empty cells will be imputed with default value (if specified) or -1.
* `TABLE_ROW` - An entity name as an integer enumeration. The entity name can be from _any_ db-style table included in the `postprocess_tables()` call. E.g., "PLANET_EARTH" in our [planets.tsv](https://github.com/ivoyager/ivoyager_core/blob/master/tables/planets.tsv) would evaluate to 3 because it is row three. Note that table entity names are globally unique (this is enforced). The internal postprocessed data type will be `int`. Empty cells will be imputed with default value (if specified) or -1.
* `<ClassName>.<EnumName>` or `<Class>` - For specifying project or Godot enums. Class and EnumName are needed for project enums (where Class can be the name of a singleton). For Godot classes, EnumName can optionally be omitted. The internal postprocessed data type will be `int`. Empty cells will be imputed with default value (if specified) or -1.
* `ARRAY[xxxx]` (where "xxxx" specifies element type and is any of the above type strings) - Array elements are expected to be delimited by semicolon (;). After splitting by semicolon, each element is interpreted exactly as its type above. Column `Unit` and `Prefix`, if specified, are applied element-wise. Empty cells will be imputed with default value (if specified) or an empty, typed array.

**Note on "missing" values:** Some "missing" values noted above may seem strange, like Color(-INF, -INF, -INF, -INF). The reason for this is that we want to distiguish missing values from potentially valid values like Color.BLACK. A "missing" value entered in the file table is exactly equivalent to an empty cell (without any specified default) for the purpose of `db_has_value()` and constructor methods such as `db_build_object()`. In the former, a "missing" value would result in false; in the latter, a "missing" value would not be set in the object. If needed, missing values can be respecified in the call to `postprocess_tables()`.

#### Float Precision

For scientific or educational apps (but probably not games), it is important to know and correctly represent data precision in GUI. To obtain a float value's original file precision in significant digits, specify `enable_precisions = true` in the `postprocess_tables()` call. You can then access float precisions via the "precisions" dictionary or "get_precision" methods in IVTableData. It's up to you to use precision in your GUI display. Keep in mind that unit-conversion will cause values like "1.0000001" if you don't do any string formatting.

See warning below about .csv/.tsv editors. If you must use Excel or another "smart" editor, then prefix all floats with underscore (_) to prevent the editor from stripping significant digits after the decimal place.

Significant digits are counted from the left-most non-0 digit to the right-most digit if decimal is present, or to the right-most non-0 digit if decimal is not present, ignoring the exponential. Examples:

* "1e3" (1 significant digit)
* "1.000e3" (4 significant digits)
* "1000" (1 significant digit)
* "1100" (2 significant digits)
* "1000." (4 significant digits)
* "1000.0" (5 significant digits)
* "1.0010" (5 significant digits)
* "0.0010" (2 significant digits)

Additionally, any number that is prefixed with "~" is considered a "zero-precision" value (0 significant digits). We use this in our Planetarium to display GUI text like "~1 km".

#### Table Editor Warning!

Most .csv/.tsv file editors will "interpret" and change (i.e., corrupt) table data without any warning, including numbers and text that looks even vaguely like dates (or perhaps other things). Excel is especially agressive in stripping out precision in large or small numbers, e.g., "1.32712440018E+20" converts to "1.33E+20" on saving. One editor that does NOT change data without your input is [Rons Data Edit](https://www.ronsplace.ca/Products/RonsDataEdit). There is a free version that will let you work with files with up to 1000 rows.

## DB_ENTITIES Format

[Example Table](https://github.com/ivoyager/ivoyager_core/blob/master/tables/planets.tsv)

Optional specifier: `@DB_ENTITIES[=<table_name>]` (table_name defaults to the base file name)  
Optional directive: `@DONT_PARSE`

This is the default table format assumed by the importer if other conditions (described under formats below) don't exist. The format has database-style entities (as rows) and fields (as columns). The first column of each row is taken as an "entity name" and used to create an implicit "name" field. Entity names are treated as enumerations and are accessible in other tables if the enumeration name appears in a field with Type=TABLE_ROW. Entity names must be globally unique.

Processed data are structured as a dictionary-of-statically-typed-field-arrays. Access the dictionary directly or use "get" methods in IVTableData.

#### Header Rows

The first non-comment, non-directive line is assumed to hold the field names. The left-most cell must be empty.

After field names and before data, tables can have the following header rows in any order:
* `Type` (required): See data types above.
* `Default` (optional): Default values must be empty or follow Type rules above. If non-empty, this value is imputed for any empty cells in the column.
* `Unit` (optional; FLOAT and ARRAY[FLOAT] fields only): This is supported if our [Units pluging](https://github.com/ivoyager/ivoyager_units) is also active, or if the project supplies its own unit conversion Callable. Our Units plugin supports SI and other units, and can parse arbitrary compound units like "m^3/(kg s^2)".
* `Prefix` (optional; STRING, STRING_NAME, TABLE_ROW, and <ClassName>.<EnumName> fields only, or ARRAY[xxxx] of any preceding type): Prefixes any non-empty cells and `Default` (if specified) with provided prefix text. To prefix the column 0 implicit "name" field, use `Prefix/<entity prefix>`. E.g., we use `Prefix/PLANET_` in [planets.tsv](https://github.com/ivoyager/ivoyager_core/blob/master/tables/planets.tsv) to prefix all entity names with "PLANET_".

#### Entity Names

The left-most 0-column specifies an "entity name" for each row. Entity names are included in an implicit field called "name" of type STRING_NAME. Note that the header specifiers (Type, Default, Unit, Prefix) are directly over this column. Prefix can be specified for the 0-column by changing the `Prefix` header specifier to `Prefix/<entity prefix>`. Entity names (after prefixing) must be globally unique. Note that most IVTableData "get" methods require specification `row: int`. You can get row directly from the `enumerations` dictionary or via `get_row(entity_name)`.

#### Wiki Page Title Fields

To create a wiki page titles dictionary (or dictrionaries), specify `wiki_page_title_fields: Array[StringName]` in the `postprocess_tables()` call. After postprocessing, page titles dictionaries can be obtained directly (in a dictionary of dictionaries) or via `get_wiki_page_titles(page_titles_field)`.

For example usage, our [Planetarium](https://www.ivoyager.dev/planetarium/) specifies one wiki field with name "en.wikipedia". Cells in this field contain Wikipedia English language page titles like "Sun", "Ceres_(dwarf_planet)", "Hyperion_(moon)", etc. We use these to create hyperlinks to external Wikipedia pages. Alternatively, wiki fields could be specified to point to pages of an internal game wiki.

## DB_ENTITIES_MOD Format

[Example Table](https://github.com/t2civ/astropolis_sdk/blob/master/public/tables/planets_mod.tsv)

Optional specifier: `@DB_ENTITIES_MOD[=<table_name>]` (table_name defaults to the base file name)  
Required directive: `@MODIFIES=<table_name>`  
Optional directive: `@DONT_PARSE`

This table modifies an existing DB_ENTITIES table. It can add entities or fields or overwrite existing data. There can be any number of DB_ENTITIES_MOD tables that modify a single DB_ENTITIES table. The importer assumes this format if the `@MODIFIES` directive is present.

Rules exactly follow DB_ENTITIES except that entity names _must_ be present and they _may or may not already exist_ in the DB_ENTITIES table being modified. If an entity name already exists, the mod table data will overwrite existing values. Otherwise, a new entity/row is added to the existing table. Similarly, field names may or may not already exist. If a new field/column is specified, then all previously existing entities (that are absent in the mod table) will be assigned the default value for this field.

## DB_ANONYMOUS Format

[Example Table](https://github.com/ivoyager/ivoyager_core/blob/master/tables/file_adjustments.tsv)

Optional specifier: `@DB_ANONYMOUS[=<table_name>]` (table_name defaults to the base file name)   
Optional directive: `@DONT_PARSE`

This table is exactly like [DB_ENTITIES](#DB_ENTITIES-Format) except that row names (the first column of each content row) are empty. The importer can identify this situation without the specifier directive. (Inconsistent use of row names will cause an import error assert.) This table will not create entity enumerations and does not have a "name" field and cannot be modified by DB_ENTITIES_MOD, but is in other ways like DB_ENTITIES.

## ENUMERATION Format

[Example Table](https://github.com/t2civ/astropolis_public/blob/master/tables/major_strata.tsv)

Optional specifier: `@ENUMERATION[=<table_name>]` (table_name defaults to the base file name)  
Optional directive: `@DONT_PARSE`

This is a single-column "enumeration"-only table. The importer assumes this format if the table has only one column. 

This is essentially a [DB_ENTITIES](#DB_ENTITIES-Format) table with only the 0-column. It creates entities enumerations with no data. There is no header row for field names and the only header tag that may be used (optionally) is `Prefix`. As for DB_ENTITIES, prefix the 0-column by modifying the header tag to `Prefix/<entity prefix>`.

See [Entity Names](#Entity-Names) in the DB_ENTITIES Format above.

## WIKI_ONLY Format

[Example Table](https://github.com/ivoyager/ivoyager_core/blob/master/tables/wiki_extras.tsv)

Required specifier: `@WIKI_ONLY[=<table_name>]` (table_name defaults to the base file name)  
Optional directive: `@DONT_PARSE`

This format can add items to wiki page title dictionaries that are not added by fields in DB_ENTITIES or DB_ENTITIES_MOD tables.

The format is the same as [DB_ENTITIES](#DB_ENTITIES-Format) except that fields can include only wiki page title fields and the only header that may be used (optionally) is `Prefix`. As for DB_ENTITIES, prefix the 0-column by modifying the header tag to `Prefix/<entity prefix>`. Unlike DB_ENTITIES, the 0-column is **not** used to create entity name enumerations.

See [Wiki Page Title Fields](#Wiki-Page-Title-Fields) in the DB_ENTITIES Format above.

For example usage, our [Planetarium](https://www.ivoyager.dev/planetarium/) uses this table format to create hyperlinks to Wikipedia.org pages for concepts such as "Orbital_eccentricity" and "Longitude_of_the_ascending_node" (i.e., non-"entity" items that don't exist in planets.tsv, moons.tsv, etc.).

## ENTITY_X_ENTITY Format

[Example Table](https://github.com/t2civ/astropolis_sdk/blob/master/public/tables/compositions_resources_proportions.tsv)

Required specifier: `@ENTITY_X_ENTITY[=<table_name>]` (table_name defaults to the base file name)  
Required directive: `@DATA_TYPE=<Type>`  
Optional directives: `@DATA_DEFAULT=<Default>`, `@DATA_UNIT=<Unit>`, `@TRANSPOSE`, `@DONT_PARSE`

This format creates an array-of-arrays data structure where data is indexed [row_enumeration][column_enumeration] or the transpose if `@TRANSPOSE` is specified. All cells in the table have the same Type, Default and Unit (if applicable) specified by data directives above.

At this time, the only "enumerations" that the plugin knows are entity names defined in other tables (specifically, DB_ENTITIES, DB_ENTITIES_MOD or ENUMERATION tables). TODO: We plan to support project or Godot enums as enumerations in the ENTITY_X_ENTITY format.

The upper-left table cell can either be empty or specify row and column entity prefixes delimited by a backslash. E.g., "RESOURCE_\FACILITY_" prefixes all row names with "RESOURCE_" and all column names with "FACILITY_".

The resulting array-of-arrays structure will always have rows and columns that are sized and ordered according to the enumeration, not the table! Entities can be missing or out of order in the table. Data not specified in the table file (because the cell is empty or the entity row or column is missing) will be imputed with the default value.
