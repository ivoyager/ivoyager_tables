# Changelog

This file documents changes to [ivoyager_tables](https://github.com/ivoyager/ivoyager_tables).

File format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [v0.0.4] - UNRELEASED

Developed using Godot 4.4.1.

### Changed

* [API breaking] Simplified all "get" functions to require row without entity option. (Row is super easy to get.)
* [API breaking] Streamlined API so db_build_dictionary() and db_build_object() handle cases w/ or w/out field specification.
* [API breaking] Changed other function signatures.

## [v0.0.3] - 2025-03-31

Developed using Godot 4.4.

### Added

* INT column can contain hex ("0x"-prefixed) or binary ("0b"-prefixed) numbers. Underscore ("_") is ignored in both cases.
* INT column can contain a "|"-delimited list of valid INT values. The post-processor will perform a bit-wise or operation on all values. This is useful for specifying flags.

### Removed

* Removed `get_db_array_as_flags()`. Flags can be or'ed within an INT cell (see above). 

## [v0.0.2] - 2025-03-20

Developed using Godot 4.4.

### Added

* Added methods `get_db_vector2()`, `get_db_vector4()` and `get_db_array_as_flags()`.

### Changed

* [API breaking] Typed all dictionaries.

## v0.0.1 - 2025-01-07

Developed using Godot 4.3.

This plugin resulted from splitting the now-depreciated [Table Importer](https://github.com/ivoyager/ivoyager_table_importer) (v0.0.9) into two plugins: [Tables](https://github.com/ivoyager/ivoyager_tables) (v0.0.1) and [Units](https://github.com/ivoyager/ivoyager_units) (v0.0.1).

v0.0.1 is almost a "drop-in" replacement for ivoyager_table_importer v0.0.9. The main breaking change is in the method signature for postprocess_tables(). The order is changed and you now MUST supply a unit coversion method (you probably want the one in the ivoyager_units plugin).

[v0.0.4]: https://github.com/ivoyager/ivoyager_tables/compare/v0.0.3...HEAD
[v0.0.3]: https://github.com/ivoyager/ivoyager_tables/compare/v0.0.2...v0.0.3
[v0.0.2]: https://github.com/ivoyager/ivoyager_tables/compare/v0.0.1...v0.0.2
