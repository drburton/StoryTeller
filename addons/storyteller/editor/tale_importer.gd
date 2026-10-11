@tool
extends EditorImportPlugin
## Imports .tale files as compiled [Tale] resources.
##
## Parse errors stop the import and are shown in the Output panel with file
## and line. Checker problems are shown as warnings for now, because custom
## actions are not registered with the checker yet.


func _get_importer_name() -> String:
	return "storyteller.tale"


func _get_visible_name() -> String:
	return "TaleScript"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["tale"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_priority() -> float:
	return 1.0


## Tales imported with an older compiled format are imported again.
func _get_format_version() -> int:
	return Tale.FORMAT


func _get_import_order() -> int:
	return 0


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _import(source_file: String, save_path: String, _options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var source := FileAccess.get_file_as_string(source_file)
	if source.is_empty() and FileAccess.get_open_error() != OK:
		push_error("StoryTeller: can't read %s." % source_file)
		return FileAccess.get_open_error()

	var tale_name := source_file.get_file().get_basename()
	var doc := TaleParser.parse(source, source_file)
	if doc.has_errors():
		for diagnostic in doc.diagnostics:
			push_error("%s:%d:%d: %s" % [source_file, diagnostic.line, diagnostic.column, diagnostic.message])
		return ERR_PARSE_ERROR

	var context := _make_context(source_file, tale_name)
	var checker := TaleChecker.new()
	for problem in checker.run(doc, context):
		push_warning("%s:%d:%d: %s" % [source_file, problem.line, problem.column, problem.message])

	var tale := TaleCompiler.compile(doc, tale_name, checker.call_kinds)
	return ResourceSaver.save(tale, "%s.%s" % [save_path, _get_save_extension()])


## Builds a check context with the built-in actions and the beats and
## variables of the other tales in the same folder.
static func _make_context(source_file: String, tale_name: String) -> TaleCheckContext:
	var config: StoryConfig = preload("res://addons/storyteller/core/story.gd").load_config()
	var director := TaleDirector.new()
	director.setup(config)
	var context := director.make_check_context(tale_name)
	director.free()
	var profiles := StoryStage.scan_cast(config.cast_folder)
	for id in profiles:
		var profile: CastProfile = profiles[id]
		context.add_cast(id, profile.look.get_moods() if profile.look else PackedStringArray(), profile.get_field_names())
	context.add_exposed("camera")
	for exposed_name in config.exposed_names:
		context.add_exposed(exposed_name)
	var folder := source_file.get_base_dir()
	for file_name in DirAccess.get_files_at(folder):
		if not file_name.ends_with(".tale") or file_name.get_basename() == tale_name:
			continue
		var doc := TaleParser.parse(FileAccess.get_file_as_string(folder.path_join(file_name)))
		var beats := PackedStringArray()
		var vars := PackedStringArray()
		for statement in doc.statements:
			if statement.kind == TaleNode.Kind.BEAT:
				beats.append(statement.name)
			elif statement.kind == TaleNode.Kind.VAR or statement.kind == TaleNode.Kind.CONST:
				vars.append(statement.name)
		context.add_tale(file_name.get_basename(), beats, vars)
	return context
