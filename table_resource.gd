# table_resource.gd
# This file is part of I, Voyager
# https://ivoyager.dev
# *****************************************************************************
# Copyright 2017-2024 Charlie Whitfield
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
@tool
class_name IVTableResource
extends Resource

## Resource used by the table importer plugin.
##
## The imported resource only needs to be loaded for data postprocessing by
## [IVTablePostprocessor]. After that, all processed table data is available in
## autoload singleton [IVTableData]. The resources are
## de-referenced so they free themselves and go out of memory.
##
## Data here is preprocessed for the needs of the postprocessor. It isn't
## usefull in its preprocessed form except for table debugging.

enum TableDirectives {
	# table formats
	DB_ENTITIES,
	DB_ENTITIES_MOD,
	DB_ANONYMOUS_ROWS,
	ENUMERATION,
	WIKI_LOOKUP,
	ENUM_X_ENUM,
	N_FORMATS,
	# specific directives
	MODIFIES,
	DATA_TYPE,
	DATA_DEFAULT,
	DATA_UNIT,
	TRANSPOSE,
	# any file
	DONT_PARSE, # do nothing (for debugging or under-construction table)
}


## Arrays of any of these types are also supported.
const SUPPORTED_TYPES := {
	&"BOOL" : TYPE_BOOL,
	&"INT" : TYPE_INT,
	&"FLOAT" : TYPE_FLOAT,
	&"STRING" : TYPE_STRING,
	&"STRING_NAME" : TYPE_STRING_NAME,
	&"VECTOR2" : TYPE_VECTOR2,
	&"VECTOR3" : TYPE_VECTOR3,
	&"VECTOR4" : TYPE_VECTOR4,
	&"COLOR" : TYPE_COLOR,
}

const UNIT_ALLOWED_TYPES: Array[int] = [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4,
		TYPE_COLOR]

const ALLOWED_SPECIFIC_DIRECTIVES := [
	# List for each table format (we don't need DONT_PARSE here).
	[],
	[TableDirectives.MODIFIES],
	[],
	[],
	[],
	[TableDirectives.DATA_TYPE, TableDirectives.DATA_DEFAULT, TableDirectives.DATA_UNIT,
			TableDirectives.TRANSPOSE],
]

const REQUIRES_ARGUMENT := [false, false, false, false, false, false, false,
		true, true, true, true, false, false]

const VERBOSE := true # prints a single line on import

@export var table_format := -1
@export var table_name := &""
@export var specific_directives: Array[int] = []
@export var specific_directive_args: Array[String] = []

# For vars below, content depends on table format:
#  - All have 'n_rows' & 'n_columns'
#  - ENUMERATION has 'row_names' & 'entity_prefix'
#  - WIKI_LOOKUP has 'column_names', 'row_names' & 'dict_of_field_arrays'
#  - DB_ENTITIES has 'column_names', 'row_names' & all under 'db style'
#  - DB_ENTITIES_MOD has above plus 'modifies_table_name'
#  - DB_ANONYMOUS_ROWS has 'column_names' & all under 'db style'
#  - ENUM_X_ENUM has 'column_names', 'row_names' & all under 'enum x enum'

@export var column_names: Array[StringName] # fields if applicable
@export var row_names: Array[StringName] # entities if applicable
@export var n_rows := -1
@export var n_columns := -1 # not counting row_names (e.g., 0 for ENUMERATION)
@export var entity_prefix := "" # only if header has Prefix/<entity prefix>
@export var modifies_table_name := &"" # DB_ENTITIES_MOD only

# db style
@export var dict_of_field_arrays: Dictionary # indexed data [field][row]
@export var db_prefixes: Dictionary
@export var db_types: Dictionary # ints indexed [field]
@export var db_units: Dictionary # StringNames [field] (FLOAT fields if Unit exists)
@export var db_import_defaults: Dictionary # indexed data [field] (if Default exists)

# enum x enum
@export var array_of_arrays: Array[Array] # preprocessed data indexed [row_enum][column_enum]
@export var exe_type: int
@export var exe_unit: StringName
@export var exe_import_default: int

# indexing
@export var indexing := {"" : 0} # empty cell is always idx = 0
var next_idx := 1

# debug data
@export var path: String


func import_file(file: FileAccess, source_path: String) -> void:
	
	path = source_path
	
	# store data cells and set table_format
	var cells: Array[Array] = []
	var comment_columns: Array[int] = []
	var n_data_columns: int
	var file_length := file.get_length()
	var debug_row := -1
	while file.get_position() < file_length:
		var file_line := file.get_line()
		debug_row += 1
		
		# skip comment lines
		if file_line.begins_with("#") or file_line.begins_with('"#') or file_line.begins_with("'#"):
			continue
		
		# Get line into array and do edge stripping and quote processing.
		# Double quotes are removed only if at both ends. Single quote if at begining.
		var line_split := file_line.split("\t") # PackedStringArray, but we want an Array
		var line_array: Array[String] = Array(Array(line_split), TYPE_STRING, &"", null)
		for i in line_array.size():
			var value := line_array[i].strip_edges()
			if value.begins_with('"') and value.ends_with('"'):
				value = value.lstrip('"').rstrip('"')
			if value.begins_with("'"):
				value = value.lstrip("'")
			line_array[i] = value.strip_edges() # could have stray spaces inside or outside quotes
		
		# handle or store directives
		if line_array[0].begins_with("@"):
			var dir_str := line_array[0].trim_prefix("@")
			var dir_split := dir_str.split("=")
			assert(dir_split.size() <= 2,
					">1 '=' in directive '%s' in %s, %s" % [line_array[0], path, debug_row])
			var split0 := dir_split[0].rstrip(" ")
			var arg := dir_split[1].lstrip(" ") if dir_split.size() > 1 else ""
			assert(TableDirectives.has(split0),
					"Unknown table directive '@%s' in %s, %s" % [split0, path, debug_row])
			var directive: int = TableDirectives[split0]
			if directive == TableDirectives.DONT_PARSE:
				if VERBOSE:
					print("Importing (but not parsing!) " + path)
				return
			if directive < TableDirectives.N_FORMATS:
				assert(table_format == -1, ">1 format specified in %s, %s" % [path, debug_row])
				table_format = directive
				if arg: # otherwise, we'll get table name from file name
					table_name = StringName(arg)
			else:
				assert(directive > TableDirectives.N_FORMATS,
						"Don't use @N_FORMATS in %s, %s" % [path, debug_row])
				specific_directives.append(directive)
				specific_directive_args.append(arg)
			continue
		
		# identify comment columns in 1st non-comment, non-directive row (fields, if we have them)
		if !cells:
			n_data_columns = line_array.size()
			for column in line_array.size():
				if line_array[column].begins_with("#"):
					comment_columns.append(column)
					n_data_columns -= 1
			comment_columns.reverse() # we'll remove from back
		
		# remove comment columns in all rows
		for comment_column in comment_columns: # back to front
			line_array.remove_at(comment_column)
		assert(line_array.size() == n_data_columns,
			"Inconsistent row cell number after delimination in %s, %s" % [path, debug_row])
		cells.append(line_array)
	
	# set format and/or name if not specified in directive
	if table_format == -1:
		if n_data_columns == 1:
			table_format = TableDirectives.ENUMERATION
		elif specific_directives.has(TableDirectives.MODIFIES):
			table_format = TableDirectives.DB_ENTITIES_MOD
		elif cells[-1][0]: # last row name (we expect all or none, and test this below)
			table_format = TableDirectives.DB_ENTITIES
		else:
			table_format = TableDirectives.DB_ANONYMOUS_ROWS
	if !table_name:
		table_name = StringName(path.get_file().get_basename())
	
	# directive error check
	var allowed_directives: Array = ALLOWED_SPECIFIC_DIRECTIVES[table_format]
	for i in specific_directives.size():
		var directive := specific_directives[i]
		assert(allowed_directives.has(directive),
				"Unallowed directive '%s' in format %s in %s" % [directive, table_format, path])
		assert(!REQUIRES_ARGUMENT[directive] or specific_directive_args[i],
				"Directive '%s' requires an argument in %s" % [directive, path])
	
	# send cells for preprocessing
	match table_format:
		TableDirectives.DB_ENTITIES:
			if VERBOSE:
				print("Importing DB_ENTITIES " + path)
			_preprocess_db_style(cells, false, false, true)
		TableDirectives.DB_ENTITIES_MOD:
			if VERBOSE:
				print("Importing DB_ENTITIES_MOD " + path)
			_preprocess_db_style(cells, false, false, true)
		TableDirectives.DB_ANONYMOUS_ROWS:
			if VERBOSE:
				print("Importing DB_ANONYMOUS_ROWS " + path)
			_preprocess_db_style(cells, false, false, false)
		TableDirectives.ENUMERATION:
			if VERBOSE:
				print("Importing ENUMERATION " + path)
			_preprocess_db_style(cells, true, false, true)
		TableDirectives.WIKI_LOOKUP:
			if VERBOSE:
				print("Importing WIKI_LOOKUP " + path)
			_preprocess_db_style(cells, false, true, true)
		TableDirectives.ENUM_X_ENUM:
			if VERBOSE:
				print("Importing ENUM_X_ENUM " + path)
			_preprocess_enum_x_enum(cells)


func _preprocess_db_style(cells: Array[Array], is_enumeration: bool, is_wiki_lookup: bool,
		has_row_names: bool) -> void:
	
	# specific directives
	var modifies_pos := specific_directives.find(TableDirectives.MODIFIES)
	if modifies_pos >= 0:
		modifies_table_name = StringName(specific_directive_args[modifies_pos])
	
	# dictionaries & arrays we'll populate
	db_prefixes = {}
	if !is_enumeration:
		dict_of_field_arrays = {}
		if !is_wiki_lookup:
			db_types = {} # indexed by fields
			db_units = {} # indexed by FLOAT fields
			db_import_defaults = {} # indexed by fields
	if has_row_names:
		row_names = []
	
	var n_cell_rows := cells.size()
	var n_cell_columns := cells[0].size()
	var skip_column_0_iterator := range(1, n_cell_columns)
	var row := 0
	var content_row := 0
	var is_header := true
	var has_types := false
	
	# handle field names
	if !is_enumeration:
		var line_array: Array[String] = cells[0]
		assert(!line_array[0], "Left-most cell of field name header must be empty in %s, 0" % path)
		column_names = []
		for column: int in skip_column_0_iterator:
			var field := StringName(line_array[column])
			assert(field != &"name", "Use of 'name' as field is not allowed in %s, 0, %s" % [path,
					column])
			assert(!column_names.has(field), "Duplicate field name '%s' in %s, 0, %s" % [field,
					path, column])
			if is_wiki_lookup:
				assert(field.ends_with(".wiki"),
						"WIKI_LOOKUP fields must have '.wiki' suffix in %s, 0, %s" % [path, column])
			column_names.append(field)
		row += 1
	
	# process rows after field names
	while row < n_cell_rows:
		
		var line_array: Array[String] = cells[row]
		
		# header
		if is_header:
			# process header rows until we don't recognize line_array[0] as header item
			if line_array[0] == "Type":
				assert(!is_enumeration,
						"Don't use Type in ENUMERATION table %s, %s" % [path, row])
				assert(!is_wiki_lookup,
						"Don't use Type in WIKI_LOOKUP table %s, %s" % [path, row])
				for column: int in skip_column_0_iterator:
					assert(line_array[column], "Missing Type in %s, %s, %s" % [path, row, column])
					var field := column_names[column - 1]
					db_types[field] = _get_postprocess_type(line_array[column])
				has_types = true
				row += 1
				continue
			
			if line_array[0] == "Unit":
				assert(!is_enumeration,
						"Don't use Unit in ENUMERATION table %s, %s" % [path, row])
				assert(!is_wiki_lookup,
						"Don't use Unit in WIKI_LOOKUP table %s, %s" % [path, row])
				for column: int in skip_column_0_iterator:
					if line_array[column]: # is non-empty
						var field := column_names[column - 1]
						db_units[field] = StringName(line_array[column]) # verify is FLOAT below
				row += 1
				continue
			
			if line_array[0] == "Default":
				assert(!is_enumeration,
						"Don't use Default in ENUMERATION table %s, %s" % [path, row])
				assert(!is_wiki_lookup,
						"Don't use Default in WIKI_LOOKUP table %s, %s" % [path, row])
				for column: int in skip_column_0_iterator:
					if line_array[column]: # is non-empty
						var field := column_names[column - 1]
						db_import_defaults[field] = _get_value_index(line_array[column])
				row += 1
				continue
			
			if line_array[0].begins_with("Prefix"):
				if line_array[0].length() > 6:
					assert(line_array[0][6] == "/",
							"Bad Prefix construction %s in %s, %s" % [line_array[0], path, row])
					entity_prefix = line_array[0].trim_prefix("Prefix/")
					db_prefixes[&"name"] = entity_prefix
				for column: int in skip_column_0_iterator:
					if line_array[column]: # is non-empty
						var field := column_names[column - 1]
						db_prefixes[field] = line_array[column]
				row += 1
				continue
			
			# header finished!
			n_rows = n_cell_rows - row
			assert(has_types or is_enumeration or is_wiki_lookup,
					"Table format requires 'Type' in " + path)
			for field: StringName in db_units:
				var type: int = db_types[field]
				assert(UNIT_ALLOWED_TYPES.has(type) if type < TYPE_MAX
						else UNIT_ALLOWED_TYPES.has(type - TYPE_MAX),
						"Unit specified in column type that should not have unit; '%s', %s" % [
						field, path])
			
			# init arrays in dictionaries
			for field in column_names: # none if is_enumeration
				var field_array := Array([], TYPE_INT, &"", null)
				field_array.resize(n_rows)
				dict_of_field_arrays[field] = field_array
		
			is_header = false
		
		# process content row
		if has_row_names:
			assert(line_array[0], "Missing expected row name in %s, %s" % [path, row])
		else:
			assert(!line_array[0],
					"DB_ANONYMOUS_ROWS table has row name in %s, %s" % [path, row])
		
		if has_row_names:
			var row_name := StringName(entity_prefix + line_array[0])
			assert(!row_names.has(row_name),
					"Duplicate row_name '%s' in %s, %s" % [row_name, path, row])
			row_names.append(row_name)
			if is_enumeration: # We're done! We only needed row name.
				content_row += 1
				row += 1
				continue
		
		# process content columns
		for column: int in skip_column_0_iterator:
			var field := column_names[column - 1]
			var raw_value: String = line_array[column]
			var preprocess_value: Variant
			if !raw_value and db_import_defaults.has(field):
				preprocess_value = db_import_defaults[field]
			else:
				preprocess_value = _get_value_index(raw_value)
			dict_of_field_arrays[field][content_row] = preprocess_value
		content_row += 1
		row += 1
	
	n_columns = 0 if is_enumeration else dict_of_field_arrays.size()


func _preprocess_enum_x_enum(cells: Array[Array]) -> void:
	
	var n_cell_rows := cells.size() # includes column_names
	var n_cell_columns := cells[0].size() # includes row_names
	n_rows = n_cell_rows - 1
	n_columns = n_cell_columns - 1
	
	# get prefixes
	var row_prefix := ""
	var column_prefix := ""
	if cells[0][0]:
		var prefixes_str: String = cells[0][0]
		var prefixes_split := prefixes_str.split("\\")
		assert(prefixes_split.size() == 2,
				"To prefix, use <row prefix>\\<column prefix> in %s, 0, 0" % path)
		row_prefix = prefixes_split[0]
		column_prefix = prefixes_split[1]
	
	# apply directives
	var type_pos := specific_directives.find(TableDirectives.DATA_TYPE)
	assert(type_pos >= 0, "Table format requires @DATA_TYPE in " + path)
	var raw_type := specific_directive_args[type_pos]
	exe_type = _get_postprocess_type(raw_type)
	var raw_default := ""
	var default_pos := specific_directives.find(TableDirectives.DATA_DEFAULT)
	if default_pos >= 0:
		raw_default = specific_directive_args[default_pos]
	exe_import_default = _get_value_index(raw_default)
	var unit_pos := specific_directives.find(TableDirectives.DATA_UNIT)
	exe_unit = &""
	if unit_pos >= 0:
		assert(UNIT_ALLOWED_TYPES.has(exe_type) if exe_type < TYPE_MAX
				else UNIT_ALLOWED_TYPES.has(exe_type - TYPE_MAX),
				"Can't use '@DATA_UNIT' in this table type: " + path)
		exe_unit = StringName(specific_directive_args[unit_pos])
	if specific_directives.has(TableDirectives.TRANSPOSE):
		var swap_prefix := row_prefix
		row_prefix = column_prefix
		column_prefix = swap_prefix
		var swap_data: Array[Array] = []
		swap_data.resize(n_cell_columns)
		for i in n_cell_columns:
			var swap_row: Array[String] = []
			swap_row.resize(n_cell_rows)
			swap_data[i] = swap_row
			for j in n_cell_rows:
				swap_data[i][j] = cells[j][i]
		cells = swap_data
		n_cell_rows = cells.size()
		n_cell_columns = cells[0].size()
		n_rows = n_cell_rows - 1
		n_columns = n_cell_columns - 1
	
	# init all arrays
	row_names = []
	row_names.resize(n_rows)
	column_names = []
	column_names.resize(n_columns)
	var skip_column_0_iterator := range(1, n_cell_columns)
	array_of_arrays = []
	array_of_arrays.resize(n_rows)
	var row_array := []
	row_array.resize(n_columns)
	for i in n_rows:
		array_of_arrays[i] = row_array.duplicate()
	
	# set column names
	var line_array: Array[String] = cells[0]
	for column: int in skip_column_0_iterator:
		column_names[column - 1] = StringName(column_prefix + line_array[column])
	
	# process data rows
	var row := 1
	while row < n_cell_rows:
		line_array = cells[row]
		row_names[row - 1] = StringName(row_prefix + line_array[0])
		for column: int in skip_column_0_iterator:
			var raw_value := line_array[column]
			var preprocess_value: int
			if raw_value:
				preprocess_value = _get_value_index(raw_value)
			else:
				preprocess_value = exe_import_default
			array_of_arrays[row - 1][column - 1] = preprocess_value
		row += 1


func _get_postprocess_type(type_str: StringName) -> int:
	
	if SUPPORTED_TYPES.has(type_str):
		return SUPPORTED_TYPES[type_str]
	
	# Array types are encoded using int values >= TYPE_MAX. We don't expect to
	# ever want nested arrays so don't recurse here.
	if type_str.begins_with("ARRAY[") and type_str.ends_with("]"):
		var array_type_str := type_str.trim_prefix("ARRAY[").trim_suffix("]")
		var array_type: int = SUPPORTED_TYPES.get(array_type_str, -1)
		assert(array_type != -1, "Missing or unsupported array Type '%s' in %s" % [type_str, path])
		return TYPE_MAX + array_type
	
	assert(false, "Missing or unsupported Type '%s' in %s" % [type_str, path])
	return -1


func _get_value_index(value: String) -> int:
	if !value:
		return 0 # empty is most common value
	var idx: int = indexing.get(value, -1)
	if idx == -1:
		idx = next_idx
		indexing[value] = idx
		next_idx += 1
	return idx
