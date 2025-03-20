# Changelog

This file documents changes to [ivoyager_tables](https://github.com/ivoyager/ivoyager_tables).

File format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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

[v0.0.2]: https://github.com/ivoyager/ivoyager_tables/compare/v0.0.1...v0.0.2
