# editor_plugin.gd
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
@tool
extends EditorPlugin

# Adds an EditorImportPlugin and autoload singletons as specified by config files
# 'res://addons/ivoyager_tables/tables.cfg' and 'res://ivoyager_override.cfg'.
#
# All table data interface is through singleton 'IVTableData' (table_data.gd).


const plugin_utils := preload("tables_plugin_utils.gd")
const EditorImportPluginClass := preload("editor_import_plugin.gd")

var _config: ConfigFile # base config with overrides
var _editor_import_plugin: EditorImportPlugin
var _autoloads := {}



func _enter_tree() -> void:
	plugin_utils.print_plugin_name_and_version("ivoyager_tables", " - https://ivoyager.dev")
	_config = plugin_utils.get_ivoyager_config("res://addons/ivoyager_tables/tables.cfg")
	if !_config:
		return
	_editor_import_plugin = EditorImportPluginClass.new()
	add_import_plugin(_editor_import_plugin)
	_add_autoloads()


func _exit_tree() -> void:
	print("Removing I, Voyager - Tables (plugin)")
	_config = null
	remove_import_plugin(_editor_import_plugin)
	_editor_import_plugin = null
	_remove_autoloads()


func _get_table_resource_icon() -> Texture2D:
	var editor_gui := EditorInterface.get_base_control()
	return editor_gui.get_theme_icon("Grid", "EditorIcons")


func _add_autoloads() -> void:
	for autoload_name in _config.get_section_keys("tables_autoload"):
		var value: Variant = _config.get_value("tables_autoload", autoload_name)
		if value: # could be null or "" to negate
			assert(typeof(value) == TYPE_STRING,
					"'%s' must specify a path as String" % autoload_name)
			_autoloads[autoload_name] = value
	for autoload_name: String in _autoloads:
		var path: String = _autoloads[autoload_name]
		add_autoload_singleton(autoload_name, path)


func _remove_autoloads() -> void:
	for autoload_name: String in _autoloads:
		remove_autoload_singleton(autoload_name)
	_autoloads.clear()
