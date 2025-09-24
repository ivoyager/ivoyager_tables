# table_data.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2025 Charlie Whitfield
# I, Voyager is a registered trademark of Charlie Whitfield in the US
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *****************************************************************************
extends Node

## Singleton "IVTableData". Provides all interface to data tables.
##
## This node is added as singleton "IVTableData".[br][br]
##
## Data dictionaries are populated by calling [method postprocess_tables]. Data
## can be accessed directly in data structures or via methods. All dictionaries
## and arrays (including nested structures) are fully typed and read-only.[br][br]
##
## The methods API is useful for object construction and GUI. It has asserts to
## catch usage and type errors. For very optimized operation, direct access will
## be faster.[br][br]
##
## All postprocessed table data is nested within dictionaries [member db_tables]
## (DB-style tables) and [member exe_tables] (Entity x Entity tables), both indexed
## by table name (e.g., "planets", not "planets.tsv"). The data structures are as
## follows:[br][br]
##
## * DB-style tables are dictionaries of field arrays and can be indexed by
##   [code]db_tables[table_name][field_name][row_int][/code], where row_int can
##   be obtained from [member enumerations].[br][br]
## 
## * Entity x Entity tables are arrays of arrays and can be indexed by
##   [code]exe_tables[table_name][row_int][column_int][/code], where row and
##   column ints are entity row numbers in their defining tables. Swap row and
##   column if table has @TRANSPOSE directive.[br][br]
##
## For get functions, [param table] is "planets", "moons", etc. (not "planets.tsv",
## etc.). In general, functions will throw an error if [param table] doesn't exist
## or [param row] is out of range. However, a missing [param field] or missing
## cell value (withoud default) will not error and will return a "typed null"
## value (e.g., "", &"", NAN, -1, etc.) as defined in [member missing_values].[br][br]
##
## See plugin
## [url=https://github.com/ivoyager/ivoyager_tables/blob/master/README.md]README[/url]
## for details.


## Contains all postprocessed data for DB-style tables. Values are dictionaries
## of field arrays.
var db_tables: Dictionary[StringName, Dictionary] = {}
## Contains all postprocessed data for Entity x Entity tables. Values are
## arrays of arrays.
var exe_tables: Dictionary[StringName, Array] = {}
## Indexed by 1st-column entity names from [b]all[/b] 'db-style' tables, which
## are required to be globally unique ([method postprocess_tables] will assert
## if this is not the case). Values are row number from the defining tables.
var enumerations: Dictionary[StringName, int] = {}
## Contains 'enum-like' entity enumerations for each table as a separate dictionary. This
## dictionary is indexed by table name [i]and[/i] by individual entity (i.e. row) names. You
## can use the latter to obtain the full table enumeration given any single table entity name.
var enumeration_dicts: Dictionary[StringName, Dictionary] = {}
## See [member enumeration_dicts]. This is the same except the enumerations are inverted
## (array index is the enumeration value).
var enumeration_arrays: Dictionary[StringName, Array] = {}
## Number of rows for each 'db-style' table indexed by table name.
var table_n_rows: Dictionary[StringName, int] = {}
## Indexed by table name for 'db-style' tables. This is the value specified as prefix
## for the 1st column entity names. E.g., in a planets.tsv table with entities
## PLANET_MERCURY, PLANET_VENUS, etc., it should be 'PLANET_'.
var entity_prefixes: Dictionary[StringName, String] = {}
## Not populated by default. Set [param wiki_fields] in [method postprocess_tables]
## to populate. Indexed by provided wiki_fields. Values are in the form
## Dictionary[StringName, String] and provide wiki page titles keyed by entity names.
## Can be used for external or internal wiki lookup.
var wiki_page_titles_by_field: Dictionary[StringName, Dictionary] ={}
## Not populated by default. Set [code]enable_precisions = true[/code] in [method postprocess_tables]
## to populate. Has nested indexing structure exactly parallel with [member db_tables] except
## it only has FLOAT columns. Provides significant digits as determined from the table
## number text. This is useful only to science geeks making science projects like our
## [url=https://github.com/ivoyager/planetarium]Planetarium[/url] (for example).
var precisions: Dictionary[StringName, Dictionary] = {}
## Defines how text in table files is interpreted if the cell or Default is
## not empty. Constants are used [b]without[/b] any other specified postprocessing
## such as prefixing or unit conversion. The constant is used only if the type is
## correct for the column or container element (with STRING and STRING_NAME being
## mutually compatable). E.g., "inf" is the float INF in a FLOAT column but
## is simply "inf" in a STRING column. User can add, replace or disable values by
## supplying [param merge_overwrite_table_constants] in [method postprocess_tables] (use null to
## disable an existing value).
var table_constants: Dictionary[StringName, Variant] = {
	&"x" : true,
	&"true" : true,
	&"True" : true,
	&"TRUE" : true,
	&"false" : false,
	&"False" : false,
	&"FALSE" : false,
	&"nan" : NAN,
	&"NAN" : NAN,
	&"?" : INF,
	&"inf" : INF,
	&"INF" : INF,
	&"-?" : -INF,
	&"-inf" : -INF,
	&"-INF" : -INF,
}
## Defines how empty table cells without Default are interpreted by column type,
## where keys are from [annotation @GlobalScope.Variant.Type].
## Use [param overwrite_missing_values] in [method postprocess_tables]
## to replace specific missing type values. By default, missing values for the
## appropriate types are: false, "", &"", -1, NAN, [], <VectorX or Color>(-INF, -INF,...).
## Note that a "missing" value in the file table is exactly equivalent to an empty cell
## without Default for the purpose of [method db_has_value] and other methods.
## This is why it is important not to use potentially valid values (e.g., 0, 0.0,
## Vector3.ZERO, Color.BLACK, etc.) as "missing" values.[br][br]
##
## WARNING: Don't replace [code]TYPE_ARRAY : [][/code]. That's hard-coded!
var missing_values: Dictionary[int, Variant] = {
	TYPE_BOOL : false,
	TYPE_STRING : "",
	TYPE_STRING_NAME : &"",
	TYPE_INT : -1,
	TYPE_FLOAT : NAN,
	TYPE_VECTOR2 : Vector2(-INF, -INF),
	TYPE_VECTOR3 : Vector3(-INF, -INF, -INF),
	TYPE_VECTOR4 : Vector4(-INF, -INF, -INF, -INF),
	TYPE_COLOR : Color(-INF, -INF, -INF, -INF),
	TYPE_ARRAY : [], # Hard-coded. Don't change this one!
}
## This will be null after calling [method postprocess_tables]. It's accessible before
## postprocessing for [IVTableModding].
var table_postprocessor := IVTablePostprocessor.new()

## Placeholder method. Will assert an error if any table file has units and user
## did not supply [param unit_conversion_method].
static var placeholder_unit_conversion_method := func(_x: float, _unit: StringName,
		 _parse_compound_unit: bool) -> float:
	assert(false, "Unit in table but no unit_conversion_method specified in postprocess_tables()")
	return NAN

var _missing_float_is_nan := true # requires special handling since NAN != NAN


## Call this function once to populate dictionaries with postprocessed table
## data. All data containers will be set to read-only.[br][br]
##
## If float units are used in any table file you MUST specify
## [param unit_conversion_method]. If using I, Voyager's 'Units' plugin, the
## Callable to supply is IVQConvert.to_internal.[br][br]
##
## To use enum constants in table file INT columns, include the enums in
## [param project_enums].[br][br]
##
## To add arbitrary constants in table file columns of any type, include key: value
## pairs in [param merge_overwrite_table_constants]. The constants will be applied
## only if the constant type matches the column type. Use this also to overwrite
## or disable existing constants in [member table_constants] (use null to disable).[br][br]
##
## To replace default "missing" type values, supply replacements in
## [param overwrite_missing_values]. See notes and cautions in [member missing_values].
func postprocess_tables(
		table_file_paths: Array[String],
		unit_conversion_method := placeholder_unit_conversion_method,
		wiki_page_title_fields: Array[StringName] = [],
		enable_precisions := false,
		merge_overwrite_table_constants: Dictionary[StringName, Variant] = {},
		merge_overwrite_missing_values: Dictionary[int, Variant] = {}
	) -> void:
	
	table_constants.merge(merge_overwrite_table_constants, true)
	missing_values.merge(merge_overwrite_missing_values, true)
	assert(missing_values[TYPE_ARRAY] == [], "Don't change missing array value!") # hard-coding!
	var missing_float: float = missing_values[TYPE_FLOAT]
	_missing_float_is_nan = is_nan(missing_float)
	
	table_postprocessor.postprocess(
			table_file_paths,
			db_tables, 
			exe_tables,
			enumerations,
			enumeration_dicts,
			enumeration_arrays,
			table_n_rows,
			entity_prefixes,
			wiki_page_titles_by_field,
			precisions,
			wiki_page_title_fields,
			enable_precisions,
			table_constants,
			missing_values,
			unit_conversion_method,
			get_tree().get_root()
	)
	
	table_postprocessor = null # free unreferenced working containers



func has_wiki_page_titles(page_titles_field: StringName) -> bool:
	return wiki_page_titles_by_field.has(page_titles_field)


func get_wiki_page_titles(page_titles_field: StringName) -> Dictionary[StringName, String]:
	assert(wiki_page_titles_by_field.has(page_titles_field),
			"Wiki page title fields must be specified in method postprocess_tables()")
	return wiki_page_titles_by_field[page_titles_field]


## Returns -1 if missing. "entity" is table row name (1st colum) and is
## guaranteed to be globally unique.
func get_row(entity: StringName) -> int:
	return enumerations.get(entity, -1)


## Returns an enum-like dictionary of row numbers keyed by table name or the 
## name of any entity in the table.
## Works for DB_ENTITIES and ENUMERATION tables and [param project_enums].
func get_enumeration_dict(table_or_entity: StringName) -> Dictionary[StringName, int]:
	assert(enumeration_dicts.has(table_or_entity),
			"Specified table or entity '%s' does not exist or table does not have entity names"
			% table_or_entity)
	return enumeration_dicts[table_or_entity] # read-only


## Returns an array of entity names (i.e., an inversion of an enumeration dictionary)
## keyed by table name or the name of any entity in the table.
## Works for DB_ENTITIES and ENUMERATION tables.
## Also works for 'project_enums' IF it is simple sequential: 0, 1, 2,...
func get_enumeration_array(table_or_entity: StringName) -> Array[StringName]:
	assert(enumeration_dicts.has(table_or_entity),
			"Specified table or entity '%s' does not exist or table does not have entity names"
			% table_or_entity)
	return enumeration_arrays[table_or_entity] # read-only


## Works for DB_ENTITIES and ENUMERATION tables.
func has_entity_name(table: StringName, entity: StringName) -> bool:
	assert(enumeration_dicts.has(table),
			"Specified table '%s' does not exist or does not have entity names" % table)
	var enumeration_dict := enumeration_dicts[table]
	return enumeration_dict.has(entity)


## Works for DB_ENTITIES, DB_ANONYMOUS_ROWS and ENUMERATION tables.
func get_n_rows(table: StringName) -> int:
	assert(table_n_rows.has(table),
			"Specified table '%s' does not exist" % table)
	return table_n_rows[table]


## Works for DB_ENTITIES and ENUMERATION tables.
## Will return "" unless table has header "Prefix/<entity_prefix>".
func get_entity_prefix(table: StringName) -> String:
	assert(entity_prefixes.has(table),
			"Specified table '%s' does not exist" % table)
	return entity_prefixes[table]



# All below work only for DB_ENTITIES and DB_ANONYMOUS_ROWS.


## Returns &"" if table is DB_ANONYMOUS_ROWS or if row is out of bounds.
## Returns entity name for DB_ENTITIES tables only.
func get_db_entity_name(table: StringName, row: int) -> StringName:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	if !enumeration_arrays.has(table):
		return &""
	var enumeration_array: Array[StringName] = enumeration_arrays[table]
	if row < 0 or row >= enumeration_array.size():
		return &""
	return enumeration_array[row]


## Return array is content-typed by field and read-only.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_field_array(table: StringName, field: StringName) -> Array:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return []
	return table_dict[field] # read-only


## Returns the first row that contains the specified item.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_find(table: StringName, field: StringName, value: Variant) -> int:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return -1
	var field_array: Array = table_dict[field]
	return field_array.find(value)


## Returns the first row that has an array containing the specified item. Field
## must be an ARRAY type.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_find_in_array(table: StringName, field: StringName, value: Variant) -> int:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return -1
	var field_array: Array = table_dict[field]
	assert(field_array.get_typed_builtin() == TYPE_ARRAY, "Specified field is not an ARRAY type")
	for row in field_array.size():
		var item_array: Array = field_array[row]
		if item_array.has(value):
			return row
	return -1


## Searches for value in lookup_field and returns the corresponding (same row)
## value in return_field. Use &"name" for lookup_field to search by 1st
## column "entity" name. If value is not found or lookup_field or return_field
## are not present, return will be return_missing (null if unspecified).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_lookup(table: StringName, lookup_field: StringName, value: Variant,
		return_field: StringName, return_missing: Variant = null) -> Variant:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(lookup_field) or !table_dict.has(return_field):
		return return_missing
	var lookup_column: Array = table_dict[lookup_field]
	var row := lookup_column.find(value)
	if row == -1:
		return return_missing
	var return_column: Array = table_dict[return_field]
	return return_column[row]


## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func count_db_matching(table: StringName, field: StringName, match_value: Variant) -> int:
	# Returns -1 if field not found.
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return -1
	var column_array: Array = table_dict[field]
	return column_array.count(match_value)


## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_matching_rows(table: StringName, field: StringName, match_value: Variant) -> Array[int]:
	# May cause error if match_value type differs from field column.
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return [] as Array[int]
	var column_array: Array = table_dict[field]
	var size := column_array.size()
	var result: Array[int] = []
	var row := 0
	while row < size:
		if column_array[row] == match_value:
			result.append(row)
		row += 1
	return result


## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_true_rows(table: StringName, field: StringName) -> Array[int]:
	# Any value that evaluates true in an 'if' statement. Type is not enforced.
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return [] as Array[int]
	var column_array: Array = table_dict[field]
	var size := column_array.size()
	var result: Array[int] = []
	var row := 0
	while row < size:
		if column_array[row]:
			result.append(row)
		row += 1
	return result


## Returns true if the table has field and does not contain type-specific
## "missing" value defined in [member missing_values].
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_has_value(table: StringName, field: StringName, row: int) -> bool:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return false
	var value: Variant = table_dict[field][row]
	var type := typeof(value)
	if type == TYPE_FLOAT and _missing_float_is_nan:
		var float_value: float = value
		if is_nan(float_value):
			return false
	return value != missing_values[type]


## Returns true if the table has field and does not contain float-specific
## "missing" value defined in [member missing_values] (NAN by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_has_float_value(table: StringName, field: StringName, row: int) -> bool:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return false
	var float_value: float = table_dict[field][row]
	if _missing_float_is_nan and is_nan(float_value):
		return false
	return float_value != missing_values[TYPE_FLOAT]


## Use for STRING field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist ("" by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_string(table: StringName, field: StringName, row: int) -> String:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_STRING]
	return table_dict[field][row]


## Use for STRING_NAME field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (&"" by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_string_name(table: StringName, field: StringName, row: int) -> StringName:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_STRING_NAME]
	return table_dict[field][row]


## Use for BOOL field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (false by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_bool(table: StringName, field: StringName, row: int) -> bool:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_BOOL]
	return table_dict[field][row]


## Use for INT field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (-1 by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_int(table: StringName, field: StringName, row: int) -> int:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_INT]
	return table_dict[field][row]


## Use for FLOAT field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (NAN by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_float(table: StringName, field: StringName, row: int) -> float:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_FLOAT]
	return table_dict[field][row]


## Use for VECTOR3 field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (Vector3(-INF,-INF,-INF) by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_vector2(table: StringName, field: StringName, row: int) -> Vector2:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_VECTOR2]
	return table_dict[field][row]


## Use for VECTOR3 field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (Vector3(-INF,-INF,-INF) by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_vector3(table: StringName, field: StringName, row: int) -> Vector3:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_VECTOR3]
	return table_dict[field][row]


## Use for VECTOR3 field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (Vector3(-INF,-INF,-INF) by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_vector4(table: StringName, field: StringName, row: int) -> Vector4:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_VECTOR4]
	return table_dict[field][row]


## Use for COLOR field. Returns "missing" value defined in [member missing_values]
## if empty cell or field does not exist (Color(-INF,-INF,-INF,-INF) by default).
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_color(table: StringName, field: StringName, row: int) -> Color:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return missing_values[TYPE_COLOR]
	return table_dict[field][row]


## Use for ARRAY[<content_type>] field. Returns an empty typed array if empty cell.
## Returns an empty untyped array if field does not exist.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_array(table: StringName, field: StringName, row: int) -> Array:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if !table_dict.has(field):
		return []
	return table_dict[field][row]


## Returns -1 if the field does not exist or is not type FLOAT.
## Asserts if [code]enable_precisions = false[/code] (default) in [method postprocess_tables].
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_float_precision(table: StringName, field: StringName, row: int) -> int:
	assert(precisions.has(table),
			"No precisions for '%s'; did you set enable_precisions = true?" % table)
	var precisions_dict := precisions[table]
	if !precisions_dict.has(field):
		return -1
	return precisions_dict[field][row]


## Returns the lowest precision in a set of fields. All fields must exist and be type FLOAT.
## Asserts if [code]enable_precisions = false[/code] (default) in [method postprocess_tables].
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_least_float_precision(table: StringName, fields: Array[StringName], row: int) -> int:
	assert(precisions.has(table),
			"No precisions for '%s'; did you set enable_precisions = true?" % table)
	var min_precision := 9999
	for field in fields:
		var precission: int = precisions[table][field][row]
		if min_precision > precission:
			min_precision = precission
	return min_precision


## Returns an array with an integer value for each specified field. Missing and
## non-FLOAT fields are allowed and will have precision -1.
## Asserts if [code]enable_precisions = false[/code] (default) in [method postprocess_tables].
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_float_precisions(table: StringName, fields: Array[StringName], row: int) -> Array[int]:
	assert(precisions.has(table),
			"No precisions for '%s'; did you set enable_precisions = true?" % table)
	var precisions_dict := precisions[table]
	var n_fields := fields.size()
	var result: Array[int] = []
	result.resize(n_fields)
	result.fill(-1)
	var i := 0
	while i < n_fields:
		var field: StringName = fields[i]
		if precisions_dict.has(field):
			result[i] = precisions_dict[field][row]
		i += 1
	return result


## Returns an array with a value for each specified field. All fields must exist.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func get_db_row_data_array(table: StringName, fields: Array[StringName], row: int) -> Array:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	var n_fields := fields.size()
	var data := []
	data.resize(n_fields)
	var i := 0
	while i < n_fields:
		var field: StringName = fields[i]
		data[i] = table_dict[field][row]
		i += 1
	return data


## If [param fields] is specified and non-empty, sets key:value pair in
## [param dict] for each field in [param fields] that exists in [param table].
## Otherwise, sets key:value pair for all fields in [param table]. In either
## case, a "missing" value in table will not be set.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_build_dictionary(dict: Dictionary, table: StringName, row: int,
		fields: Array[StringName] = []) -> void:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if fields:
		for field in fields:
			if db_has_value(table, field, row):
				dict[field] = table_dict[field][row]
		return
	# all table fields
	for field: StringName in db_tables[table]:
		if db_has_value(table, field, row):
			dict[field] = table_dict[field][row]


## If [param fields] is specified and non-empty, sets object property for each
## field in [param fields] that exists in [param table]. Otherwise, attempts to
## set object property for all fields in [param table]. In either case, a
## "missing" value in table will not be set. If object doesn't have specified
## field name as a property, there is no error and nothing happens for that
## field.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_build_object(object: Object, table: StringName, row: int, fields: Array[StringName] = []
		) -> void:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var table_dict := db_tables[table]
	if fields:
		for field in fields:
			if db_has_value(table, field, row):
				object.set(field, table_dict[field][row])
		return
	# all table fields
	for field: StringName in db_tables[table]:
		if db_has_value(table, field, row):
			object.set(field, table_dict[field][row])


## Sets flag(s) for every key in [param field_flags] that has a corresponding
## field in [param table] with a true value. The flag(s) to be set are
## specified by [param field_flags] values. Does not unset.
## Works for DB_ENTITIES and DB_ANONYMOUS_ROWS tables.
func db_get_flags(table: StringName, row: int, field_flags: Dictionary[StringName, int]) -> int:
	assert(db_tables.has(table), "Specified table '%s' does not exist" % table)
	var flags := 0
	for field in field_flags:
		if get_db_bool(table, field, row):
			flags |= field_flags[field]
	return flags
