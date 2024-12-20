# Changelog

File format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).


## v0.0.1 - 2024-12-20

Developed using Godot 4.3.

This plugin resulted from splitting plugin 'ivoyager_table_importer' into two plugins, 'ivoyager_tables' and 'ivoyager_units'.

v0.0.1 is almost a 'drop-in' replacement for ''ivoyager_table_importer' v0.0.9. The main breaking change is in the method signature for postprocess_tables(). The order is changed and you now MUST supply a unit coversion method (you probably want the one in the 'Units' plugin).
