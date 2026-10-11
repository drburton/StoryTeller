class_name StoryStrings
extends RefCounted
## Collects the text players see and writes it to a CSV file for
## translators. See decision 0011.
##
## The CSV has a [code]keys[/code] column, one column per language (the
## source language first), and [code]_context[/code] and
## [code]_status[/code] columns that Godot's importer ignores. Writing again
## keeps existing translations.
## [codeblock]
## var result := StoryStrings.collect(config)
## StoryStrings.write_csv(config.translation_file, result["entries"], "en", ["es"])
## [/codeblock]

const CONTEXT_COLUMN := "_context"
const STATUS_COLUMN := "_status"
const STATUS_UNUSED := "unused"
const STATUS_CHANGED := "source changed"


## Collects every string, writes [member StoryConfig.translation_file], and
## registers its translations in Project Settings. Returns
## [code]{"count": int, "problems": PackedStringArray}[/code].
static func export_strings(config: StoryConfig) -> Dictionary:
	var result := collect(config)
	var problems: PackedStringArray = result["problems"]
	var error := write_csv(config.translation_file, result["entries"], config.source_language, config.languages)
	if error != OK:
		problems.append("Could not write %s: %s." % [config.translation_file, error_string(error)])
		return {"count": 0, "problems": problems}
	if register_translations(config.translation_file):
		ProjectSettings.save()
	return {"count": result["entries"].size(), "problems": problems}


## Returns [code]{"entries": Array[Dictionary], "problems": PackedStringArray}[/code].
## Each entry is [code]{key, text, context}[/code]: lines and options from
## every tale, [code]tr("...")[/code] texts, tale titles, cast names,
## collection items, the game title, and menu text.
static func collect(config: StoryConfig) -> Dictionary:
	var entries: Array[Dictionary] = []
	var seen := {}
	var problems := PackedStringArray()
	var folder := config.tales_folder
	var files := PackedStringArray()
	if DirAccess.dir_exists_absolute(folder):
		for file_name in DirAccess.get_files_at(folder):
			if file_name.get_extension() == "tale":
				files.append(file_name)
	files.sort()
	for file_name in files:
		var path := folder.path_join(file_name)
		var tale_name := file_name.get_basename()
		var doc := TaleParser.parse(FileAccess.get_file_as_string(path), path)
		var tale := TaleCompiler.compile(doc, tale_name)
		if tale == null:
			problems.append("%s has errors; fix them before exporting strings." % path)
			continue
		if not tale.title.is_empty():
			_add(entries, seen, tale.title, tale.title, "title of %s" % file_name)
		for beat in tale.headings:
			_add(entries, seen, tale.headings[beat], tale.headings[beat], "heading of beat '%s' in %s" % [beat, file_name])
		for instruction in tale.instructions:
			_collect_instruction(entries, seen, tale, file_name, instruction)
	var profiles := StoryStage.scan_cast(config.cast_folder)
	var ids := profiles.keys()
	ids.sort()
	for id in ids:
		var display_name: String = profiles[id].get_display_name()
		_add(entries, seen, display_name, display_name, "name of cast member '%s'" % id)
	var items := StoryCollection.scan(config.collection_folder)
	var item_ids := items.keys()
	item_ids.sort()
	for id in item_ids:
		var item: CollectionItem = items[id]
		_add(entries, seen, item.title, item.title, "title of collection item '%s'" % id)
		_add(entries, seen, item.text, item.text, "text of collection item '%s'" % id)
	if not config.game_title.is_empty():
		_add(entries, seen, config.game_title, config.game_title, "game title")
	for text in StoryMenus.UI_TEXT:
		_add(entries, seen, text, text, "menu")
	return {"entries": entries, "problems": problems}


## Writes [param entries] to the CSV at [param path], merging with what is
## already there. Returns OK or an error.
static func write_csv(path: String, entries: Array[Dictionary], source_language: String, languages: PackedStringArray) -> Error:
	var existing := read_csv(path)
	var rows: Dictionary = existing["rows"]
	var columns := PackedStringArray([source_language])
	for language in existing["languages"] + Array(languages):
		if language not in columns:
			columns.append(language)
	var keys: Array = []
	for entry in entries:
		var key: String = entry["key"]
		keys.append(key)
		var row: Dictionary = rows.get(key, {})
		var status := ""
		if row.has(source_language) and row[source_language] != entry["text"] and _has_translation(row, columns, source_language):
			status = STATUS_CHANGED
		row[source_language] = entry["text"]
		row[CONTEXT_COLUMN] = entry["context"]
		row[STATUS_COLUMN] = status
		rows[key] = row
	for key in existing["order"]:
		if key not in keys:
			rows[key][STATUS_COLUMN] = STATUS_UNUSED
			keys.append(key)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_csv_line(PackedStringArray(["keys"]) + columns + PackedStringArray([CONTEXT_COLUMN, STATUS_COLUMN]))
	for key in keys:
		var row: Dictionary = rows[key]
		var line := PackedStringArray([key])
		for column in columns:
			line.append(row.get(column, ""))
		line.append(row.get(CONTEXT_COLUMN, ""))
		line.append(row.get(STATUS_COLUMN, ""))
		file.store_csv_line(line)
	file.close()
	return OK


## Reads a CSV written by [method write_csv]. Returns
## [code]{"languages": Array, "order": Array, "rows": {key: {column: text}}}[/code].
static func read_csv(path: String) -> Dictionary:
	var result := {"languages": [], "order": [], "rows": {}}
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var header := file.get_csv_line()
	for column in header.slice(1):
		if not column.begins_with("_"):
			result["languages"].append(column)
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or line[0].is_empty():
			continue
		var row := {}
		for i in range(1, mini(line.size(), header.size())):
			row[header[i]] = line[i]
		result["rows"][line[0]] = row
		result["order"].append(line[0])
	return result


## Adds the translation files Godot imports from [param csv_path] to
## Project Settings, for each language column. Returns true if anything was
## added. Call [method ProjectSettings.save] afterwards to keep the change.
static func register_translations(csv_path: String) -> bool:
	var setting := "internationalization/locale/translations"
	var paths := PackedStringArray(ProjectSettings.get_setting(setting, PackedStringArray()))
	var changed := false
	for language in read_csv(csv_path)["languages"]:
		var translation_path := "%s.%s.translation" % [csv_path.get_basename(), language]
		if translation_path not in paths:
			paths.append(translation_path)
			changed = true
	if changed:
		ProjectSettings.set_setting(setting, paths)
	return changed


static func _collect_instruction(entries: Array[Dictionary], seen: Dictionary, tale: Tale, file_name: String, instruction: Dictionary) -> void:
	match instruction["op"]:
		"say":
			var id: String = instruction["id"]
			var speaker: String = instruction["speaker"]
			var where := "%s:%d" % [file_name, instruction["line"]]
			_add(entries, seen, tale.translation_key(id), tale.texts.get(id, ""), where + (" (%s)" % speaker if not speaker.is_empty() else ""))
		"choose":
			for option in instruction["options"]:
				_add(entries, seen, tale.translation_key(option["id"]), tale.texts.get(option["id"], ""), "%s:%d (choice)" % [file_name, option["line"]])
		"set":
			# A name given during play, such as mira.display_name = "???".
			var place: Array = instruction["place"]
			var value: Array = instruction["value"]
			if place[0] == "attr" and place[2] == "display_name" and place[1][0] == "name" \
					and value[0] == "lit" and value[1] is String:
				_add(entries, seen, value[1], value[1], "%s:%d (name of %s)" % [file_name, instruction["line"], place[1][1]])
	for value in instruction.values():
		_collect_tr_calls(entries, seen, value, "%s:%d" % [file_name, instruction["line"]])


## Finds tr("literal") calls in an expression array.
static func _collect_tr_calls(entries: Array[Dictionary], seen: Dictionary, value: Variant, where: String) -> void:
	if value is Dictionary:
		for item in value.values():
			_collect_tr_calls(entries, seen, item, where)
	elif value is Array:
		if value.size() >= 3 and value[0] is String and value[0] == "call" and value[1] == ["name", "tr"]:
			var args: Array = value[2]
			if args.size() == 1 and args[0] is Array and args[0].size() == 2 and args[0][0] == "lit" and args[0][1] is String:
				_add(entries, seen, args[0][1], args[0][1], where + " (tr)")
		for item in value:
			_collect_tr_calls(entries, seen, item, where)


static func _add(entries: Array[Dictionary], seen: Dictionary, key: String, text: String, context: String) -> void:
	if key.is_empty() or seen.has(key):
		return
	seen[key] = true
	entries.append({"key": key, "text": text, "context": context})


static func _has_translation(row: Dictionary, columns: PackedStringArray, source_language: String) -> bool:
	for column in columns:
		if column != source_language and not str(row.get(column, "")).is_empty():
			return true
	return false
