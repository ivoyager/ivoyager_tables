# Changelog

This file documents changes to [ivoyager_tables](https://github.com/ivoyager/ivoyager_tables).

File format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## v0.0.1 - 2025-01-07

Developed using Godot 4.3.

This plugin resulted from splitting the now-depreciated [Table Importer](https://github.com/ivoyager/ivoyager_table_importer) (v0.0.9) into two plugins: [Tables](https://github.com/ivoyager/ivoyager_tables) (v0.0.1) and [Units](https://github.com/ivoyager/ivoyager_units) (v0.0.1).

v0.0.1 is almost a "drop-in" replacement for ivoyager_table_importer v0.0.9. The main breaking change is in the method signature for postprocess_tables(). The order is changed and you now MUST supply a unit coversion method (you probably want the one in the ivoyager_units plugin).
