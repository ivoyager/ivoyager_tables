# table_modding.gd
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
class_name IVTableModding
extends RefCounted

## Enables easy user modding of tables (and optionally other files).
##
## Instantiate this class to enable easy user modding of tables or other files
## in 'user://modding/base_files/' and 'user://modding/mod_files/'
## (or other specified directories). The modding/base_files/ directory will
## contain read-only files for user to use as templates. Users will have access
## only to specified files. This class handles import of modded table files that
## users add to the modding/mod_files directory; you'll have to handle any other
## mod files with additional code.[br][br]
##
## (Don't confuse user modding with TableDirectives.DB_ENTITIES_MOD. That's for
## in-table changes to existing tables by projects or plugins.)[br][br]
##
## You probably only need to use the function 'process_modding_tables_and_files()'
## to do everything. It will call the other functions.[br][br]
##
## Functions here must be called before IVTableData.postprocess_tables().[br][br]
##
## Using this class in an editor run will create and populate a directory in
## your project (at 'res://unimported/' by default).
## The files in this directory are copies of modable files with added extension
## '.unimported' to protect them from Godot's import system. This is necessary
## for the modding system to work in export projects. See warning below for more
## details. You might want to add this directory or '*.unimported' to your
## .gitignore file.[br][br]
##
## WARNING: Two things are needed for export projects to work properly:
## 1. The project must be run at least once in the editor before export. This
##    will create and populate an 'unimported' directory in your project that
##    contains the moddable files (see comments above).
## 2. Add filter '*.unimported' (or a directory filter if you want) to
##    Project/Export/Resources/'Filters to export non-resource files/folders'.

const DEFAULT_BASE_FILES_README_TEXT := """Files are read-only!

To mod:
  * Copy the file to modding/mod_files/.
  * Open the copied file's properties and unset attribute 'Read-only'.
  * Mod away!

Don't modify files in THIS directory (modding/base_files/). To force an update
of base files, delete the version.cfg file or the whole base_files directory.

WARNING! Bad mod data may cause errors or crash the application. To recover,
delete the problematic file(s) in modding/mod_files or delete the whole
mod_files directory.

Note: Most csv/tsv editors will change data without warning and without any
reasonable way to prevent it, e.g., "reformatting" text if it looks vaguely
like a date, truncating high-precision numbers, etc. One editor that does
not do this is Rons Data Edit: https://www.ronsplace.ca/products/ronsdataedit.
"""


var _version: String
var _project_unimported_dir: String
var _modding_base_files_dir: String
var _modding_mod_files_dir: String
var _base_files_readme_text := DEFAULT_BASE_FILES_README_TEXT


## 'version' is used to test whether files in modding_base_files_dir are current
## and don't need to be replaced; they are always replaced if version == "".
## 'project_unimported_dir' will be created in your project to hold file copies
## protected from Godot import with exension '.unimported'.
func _init(version := "",
		project_unimported_dir := "res://unimported",
		modding_base_files_dir := "user://modding/base_files",
		modding_mod_files_dir := "user://modding/mod_files",
		base_files_readme_text := "<use default>") -> void:
	assert(project_unimported_dir)
	_project_unimported_dir = project_unimported_dir
	_version = version
	if modding_base_files_dir:
		_modding_base_files_dir = modding_base_files_dir
		DirAccess.make_dir_recursive_absolute(modding_base_files_dir)
	if modding_mod_files_dir:
		_modding_mod_files_dir = modding_mod_files_dir
		DirAccess.make_dir_recursive_absolute(modding_mod_files_dir)
	if base_files_readme_text != "<use default>":
		_base_files_readme_text = base_files_readme_text


## This function wraps three other functions to set up modding base files and
## update them only when not present or not current for the user. File
## names in 'source_paths' and 'relative_base_file_paths' should be the same.
## Adds base files to 'modding_base_files_dir' at specified relative paths. If
## no subdirectories are needed, then 'relative_base_file_paths' is just an
## array of file names. 
func process_base_files(source_paths: Array, relative_base_file_paths: Array) -> void:
	populate_project_unimported_dir(source_paths) # editor run only
	if !is_modding_base_files_current():
		add_modding_base_files(relative_base_file_paths)


## In editor run, this function copies modding files to 'project_unimported_dir'
## with '.unimported' extension to protect them from Godot import. This is
## needed to set up modding base files. Use process_base_files() instead to do
## all base file handling in one function call.
func populate_project_unimported_dir(source_paths: Array) -> void:
	
	if !OS.has_feature("editor"):
		return
	
	DirAccess.make_dir_recursive_absolute(_project_unimported_dir)
	_remove_files_recursive(_project_unimported_dir, "unimported")
	var file_names := [] # for duplication assert
	for source_path: String in source_paths:
		var file_name := source_path.get_file()
		assert(!file_names.has(file_name), "Attempt to add duplicate file name for modding")
		file_names.append(file_name)
		var to_path := _project_unimported_dir.path_join(file_name + ".unimported")
		var err := DirAccess.copy_absolute(source_path, to_path) # only works in editor? ok here
		assert(err == OK)


## Uses 'version' specified at _init() to test whether the user's modding base
## files are current.
func is_modding_base_files_current() -> bool:
	if !_version:
		return false
	var version_config := ConfigFile.new()
	var err := version_config.load(_modding_base_files_dir.path_join("version.cfg"))
	if err != OK:
		return false
	var existing_version: String = version_config.get_value("version", "version", "")
	return existing_version == _version


## Adds base files to 'modding_base_files_dir' using relative paths specified in
## 'relative_base_file_paths'. If no subdirectories are needed, then these are
## file names only. This function only works if populate_project_unimported_dir()
## was already called. Use process_base_files() instead to do all base file
## handling in one function call.
func add_modding_base_files(relative_base_file_paths: Array) -> void:
	
	_remove_files_recursive(_modding_base_files_dir, "")
	
	# copy from _project_unimported_dir to _modding_base_files_dir at relative path
	for relative_path: String in relative_base_file_paths:
		var base_path := _modding_base_files_dir.path_join(relative_path)
		if FileAccess.file_exists(base_path):
			FileAccess.set_read_only_attribute(base_path, false) # allows overwrite
		else:
			var base_dir := base_path.get_base_dir()
			DirAccess.make_dir_recursive_absolute(base_dir)
		var file_name := relative_path.get_file()
		var unimported_path := _project_unimported_dir.path_join(file_name + ".unimported")
		
		# Godot 4.3 ISSUE: DirAccess.copy_absolute(unimported_path, base_path) fails
		# with read error in export project, even though below works...
		var unimported_file := FileAccess.open(unimported_path, FileAccess.READ)
		var content := unimported_file.get_as_text()
		var write_file := FileAccess.open(base_path, FileAccess.WRITE)
		write_file.store_string(content)
		
		FileAccess.set_read_only_attribute(base_path, true)
	
	if _base_files_readme_text:
		var readme := FileAccess.open(_modding_base_files_dir.path_join("README.txt"),
				FileAccess.WRITE)
		readme.store_string(_base_files_readme_text)
	
	var version_config := ConfigFile.new()
	version_config.set_value("version", "version", _version)
	version_config.save(_modding_base_files_dir.path_join("version.cfg"))


## Subdirectory nesting structure doesn't matter at all to this function. User
## might parallel modding/base_files subdirectories (if present), but they don't
## have to.
func import_mod_tables(table_names: Array) -> void:
	
	var mod_table_paths := {}
	if DirAccess.dir_exists_absolute(_modding_mod_files_dir):
		_add_table_paths_recursive(_modding_mod_files_dir, mod_table_paths)
	if !mod_table_paths:
		return # no mod tables!
	
	var modded_tables: Array[String] = [] # for print only
	var modding_table_resources := {}
	for name: String in table_names:
		if !mod_table_paths.has(name):
			continue
		var path: String = mod_table_paths[name]
		var file := FileAccess.open(path, FileAccess.READ)
		assert(file)
		var table_res := IVTableResource.new()
		table_res.import_file(file, path)
		modding_table_resources[name] = table_res
		modded_tables.append(name)
	if !modding_table_resources:
		return
	
	print("Applying user mod tables for: ", modded_tables)
	var table_postprocessor := IVTableData.table_postprocessor
	table_postprocessor.set_modding_tables(modding_table_resources)


func _add_table_paths_recursive(dir_path: String, dict: Dictionary) -> void:
	# 'dir_path' must exist.
	var dir := DirAccess.open(dir_path)
	dir.list_dir_begin()
	var file_or_dir_name := dir.get_next()
	while file_or_dir_name:
		var path := dir_path.path_join(file_or_dir_name)
		if dir.current_is_dir():
			_add_table_paths_recursive(path, dict)
		elif file_or_dir_name.get_extension() == "tsv":
			dict[file_or_dir_name.get_basename()] = path
		file_or_dir_name = dir.get_next()


func _get_original_table_path(name: String, original_table_paths: Array) -> String:
	for source_path: String in original_table_paths:
		if source_path.get_basename().get_file() == name:
			return source_path
	return ""


func _is_file_in_paths_array(file_name: String, paths: Array) -> bool:
	for path: String in paths:
		if path.get_file() == file_name:
			return true
	return false


func _remove_files_recursive(dir_path: String, extension: String) -> void:
	# Removes files in dir_path and dir_path subdirectories with specified extension.
	# Use extension == "" to remove all files. Also removes subdirectories if
	# they are empty after file removal. OK if dir_path doesn't exist.
	if !dir_path.begins_with("res://") and !dir_path.begins_with("user://"):
		return # make disaster a little less likely
	var dir := DirAccess.open(dir_path)
	if !dir:
		return
	dir.list_dir_begin()
	var file_or_dir_name := dir.get_next()
	while file_or_dir_name:
		if dir.current_is_dir():
			_remove_files_recursive(dir_path.path_join(file_or_dir_name), extension)
			dir.remove(file_or_dir_name) # only happens if empty
		elif !extension or file_or_dir_name.get_extension() == extension:
			FileAccess.set_read_only_attribute(dir_path.path_join(file_or_dir_name), false)
			dir.remove(file_or_dir_name)
		file_or_dir_name = dir.get_next()
