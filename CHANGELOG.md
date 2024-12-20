# Changelog

File format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

**DEPRECIATED:** After v0.0.9, the plugin was split into two new plugins: 'ivoyager_tables' and 'ivoyager_units'. It should be very straightforward to swap in the two new plugins in place of this one.

## [v0.0.9] - 2024-12-20

Developed using Godot 4.3.

### Fixed
* Export breaking reference to EditorInterface outside of EditorPlugin.

## [v0.0.8] - 2024-12-16

Developed using Godot 4.3.

### Added
* You can optionally supply your own 'unit_conversion_method' when calling postprocess_tables().
* You can supply your own (or override existing) table constants when calling postprocess_tables(). Table constants are imputed only in type-compatable columns, but can be used in any column type (as opposed to enums that can be used only in INT columns).
* Support new column types: VECTOR2, VECTOR3, VECTOR4 and COLOR (and arrays of any of these types). Vector columns expect comma-delimited floats. COLOR is very flexible in interpretting values in a sensible way: e.g., "red", "ff0000", "1,0,0", "1,0,0,1", "red, 1.0".
* Support inline unit specification for floats. E.g., '1000 s' and '1000/s' are valid anywhere a float is expected. If an inline unit is specified, it will override the column `Unit` (for 'db' formatted tables) or the table `Unit` (for enum x enum format).
* Easy user modding by replacement files in a user directory. See details in [table_modding.gd](https://github.com/ivoyager/ivoyager_table_importer/blob/master/program/table_postprocessor.gd).

### Changed
* Edge-strip spaces for cells and comma- & semicolon-delimited list elements.
* Allow commas in float values.
* [Breaks existing tables!] Elements specified in column type ARRAY[xxxx] are now semicolon-delimited rather than comma-delimited. This is needed because array elements requre commas in the case of ARRAY[COLOR] and ARRAY[VECTORx].
* Newly encounterd compound units are parsed once and then memoized as keys in unit_multipliers. (The parser is slow so this is a good optimization.)

### Fixed
* Don't assert when Unit specified for column type ARRAY[FLOAT].

## [v0.0.7] - 2024-03-15

Developed using Godot 4.2.1. _Has backward breaking changes!_

### Changed
* Fix all undeclared type warnings.
* All IVTableData dictionaries and nested dictionaries and arrays are read-only.
* For loop typing and error fixes for Godot 4.2.

## [v0.0.6] - 2023-10-05

Developed using Godot 4.1.1.

### Changed
* Removed dictionary keys for some peculiar compound units used in astronomy. (The parser can still process these.)

### Fixed
* Added missing text translation file for large numbers and long-form units.

## [v0.0.5] - 2023-10-03

Developed using Godot 4.1.1.

### Added

* Autoload singletons IVQFormat, IVUnits and IVQConvert (the latter two replace static classes).
* table_importer.cfg

### Changed
* Editor plugin now uses a config file (with optional project level override config) to define all autoloads. This is mainly so the user can reasign IVUnits.
* Restructured directories.

## [v0.0.4] - 2023-09-25

Developed using Godot 4.1.1.

### Added
* A compound unit string parser! It can parse compound units like 'm^3/(kg s^2)'.
* @DB_ANONYMOUS_ROWS table format.

### Changed
* More and more informative asserts for table problems and function misuse.
* [Breaks API] Renamed several IVTableData functions.

## [v0.0.3] - 2023-09-06

Developed using Godot 4.1.1.

### Changed
* Removed @tool from files that are not part of the resource import.
* [Breaks API] Renamed many API functions with `_db_` to make it clear what tables are valid input.

## [v0.0.2] - 2023-09-05

Developed using Godot 4.1.1.

### Changed
* Improved table asserts with row, column and/or field position
* [Breaking] Table directive format is now @XXXX=xxxx (in one table cell).

## v0.0.1 - 2023-09-04

Developed using Godot 4.1.1.

Initial alpha release!


[v0.0.9]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.8...v0.0.9
[v0.0.8]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.7...v0.0.8
[v0.0.7]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.6...v0.0.7
[v0.0.6]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.5...v0.0.6
[v0.0.5]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.4...v0.0.5
[v0.0.4]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.3...v0.0.4
[v0.0.3]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.2...v0.0.3
[v0.0.2]: https://github.com/ivoyager/ivoyager_table_importer/compare/v0.0.1...v0.0.2
