class_name StudioTemplates
extends RefCounted
## Stories to start from (docs/studio-design.md §8 and §13): the templates
## New story offers, and the lesson projects under Lessons on the home
## screen, each with a start and a finished version. Each is TaleScript in a
## .txt file, so an exported app keeps its text (a .tale file in the
## project would be imported, and its text left out), listed with its title
## in an index file:
## [codeblock]
## studio/templates/templates.json   [{"id", "title", "about"}]
## studio/templates/<id>.txt
## studio/lessons/lessons.json       [{"id", "title", "idea", "about"}]
## studio/lessons/<id>_start.txt and <id>_finished.txt
## [/codeblock]
## A template's or lesson's "has been to" tests name it by its id, and
## [method StudioLibrary.create] points them at the new story.

const TEMPLATES := "res://studio/templates/templates.json"
const LESSONS := "res://studio/lessons/lessons.json"


## The templates, in the order New story offers them.
static func templates() -> Array[Dictionary]:
	return _read_index(TEMPLATES)


## The lessons, in the book's order.
static func lessons() -> Array[Dictionary]:
	return _read_index(LESSONS)


## The text of the template [param id], or "" when there is none.
static func template_text(id: String) -> String:
	return _read_text(TEMPLATES.get_base_dir().path_join(id + ".txt"))


## The text of the lesson [param id]: its start, or its finished version
## when [param finished] is true.
static func lesson_text(id: String, finished := false) -> String:
	return _read_text(LESSONS.get_base_dir().path_join("%s_%s.txt" % [id, "finished" if finished else "start"]))


static func _read_index(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and str(entry.get("id", "")).is_valid_identifier():
				result.append(entry)
	return result


static func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
