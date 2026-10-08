extends SceneTree
## Run by tools/check_export.sh inside an exported .pck. Checks that the
## game finds its cast, moods, tales, and translations without the source
## files.


func _initialize() -> void:
	_check.call_deferred()


func _check() -> void:
	var failures: Array[String] = []
	var story := root.get_node_or_null("Story")
	if story == null:
		_finish(["The Story autoload is missing."])
		return
	var stage := story.get_crew(&"Stage") as StoryStage
	if stage != null:
		var moods: Dictionary = stage.get_cast_moods()
		print("Cast: %s" % ", ".join(PackedStringArray(moods.keys())))
		for id in moods:
			if moods[id].is_empty():
				failures.append("Cast member '%s' has no moods." % id)
	var director := story.get_crew(&"TaleDirector") as TaleDirector
	var tales := PackedStringArray()
	for file_name in ResourceLoader.list_directory(director.tales_folder):
		if file_name.get_extension() == "tale":
			tales.append(file_name.get_basename())
			if director.get_tale(file_name.get_basename()) == null:
				failures.append("Tale '%s' did not load." % file_name)
	print("Tales: %s" % ", ".join(tales))
	if tales.is_empty():
		failures.append("No tales found in %s." % director.tales_folder)
	var loaded := TranslationServer.get_loaded_locales()
	print("Languages: %s" % ", ".join(loaded))
	for language in story.config.languages:
		if language not in loaded:
			failures.append("No translation loaded for '%s'." % language)
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	for failure in failures:
		print("FAIL  %s" % failure)
	print("Export check %s." % ("failed" if not failures.is_empty() else "passed"))
	quit(1 if not failures.is_empty() else 0)
