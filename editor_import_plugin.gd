# editor_import_plugin.gd
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
extends EditorImportPlugin



func _get_importer_name() -> String:
	return "ivoyager.table_importer"


func _get_visible_name() -> String:
	return "IVoyager Table Format"


func _get_recognized_extensions() -> PackedStringArray:
	return ["tsv"]


func _get_save_extension() -> String:
	return "tres"


func _get_resource_type() -> String:
	return "IVTableResource"


func _get_preset_count() -> int:
	return 0


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array:
	return []


func _get_priority() -> float:
	return 100.0


func _get_import_order() -> int:
	return 0


func _import(source_path: String, save_path: String, _options: Dictionary,
		_r_platform_variants: Array, _r_gen_files: Array) -> Error:
	var file := FileAccess.open(source_path, FileAccess.READ)
	if !file:
		return FileAccess.get_open_error()
	var table_res := IVTableResource.new()
	table_res.import_file(file, source_path)
	
	var filename := save_path + "." + _get_save_extension()
	return ResourceSaver.save(table_res, filename)
