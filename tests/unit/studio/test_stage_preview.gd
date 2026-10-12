extends "res://tests/framework/story_test.gd"
## Tests for the Studio's stage preview (studio/preview/stage_preview.gd):
## its own small story shows the stage and the line at a chosen block.

const TALE := "res://examples/wheres_biscuit/tales/wheres_biscuit.tale"
const CONFIG := "res://examples/wheres_biscuit/story_config.tres"

var source := ""
var doc: TaleDocument
var context: TaleCheckContext


func before_each() -> void:
	super()
	source = FileAccess.get_file_as_string(TALE)
	doc = TaleParser.parse(source)
	context = TaleSignatures.make_context(TALE, "wheres_biscuit", load(CONFIG))


func _open() -> StudioStagePreview:
	var preview: StudioStagePreview = track(StudioStagePreview.new())
	preview.size = Vector2(400, 225)
	tree.root.add_child(preview)
	preview.setup(load(CONFIG))
	await tree.process_frame
	return preview


func _statement(beat_name: String, index: int) -> TaleNode:
	return TaleEdit.content_children(doc.find_beat(beat_name))[index]


func _shown_text(preview: StudioStagePreview) -> String:
	for label in preview.story.find_children("*", "RichTextLabel", true, false):
		if label.is_visible_in_tree() and not label.get_parsed_text().is_empty():
			return label.get_parsed_text()
	return ""


## Waits until the preview shows [param text], or for up to three seconds,
## since the box fades in over real time. Returns what it shows.
func _wait_for_text(preview: StudioStagePreview, text: String) -> String:
	var waited := 0.0
	while _shown_text(preview) != text and waited < 3.0:
		await tree.create_timer(0.1).timeout
		waited += 0.1
	return _shown_text(preview)


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func test_the_preview_shows_the_stage_and_the_line_at_a_block() -> void:
	var preview := await _open()
	preview.show_at(source, doc, "wheres_biscuit", _statement("start", 4), context)
	assert_eq(await _wait_for_text(preview, "Waaah!"), "Waaah!")
	var stage: Dictionary = preview.story.get_crew(&"Stage").capture()
	assert_eq(stage["backdrop"], "living_room")
	assert_eq(stage["cast"].keys(), ["cleo"])
	assert_eq(stage["cast"]["cleo"]["mood"], "sad")
	assert_true(preview.get_director().is_playing(), "the line waits")


func test_a_newer_block_replaces_the_last() -> void:
	var preview := await _open()
	preview.show_at(source, doc, "wheres_biscuit", _statement("start", 4), context)
	preview.show_at(source, doc, "wheres_biscuit", _statement("start", 8), context)
	# The box fades out from the first line before it shows the second.
	var line := "Look, her hands are empty. Where is Biscuit?"
	assert_eq(await _wait_for_text(preview, line), line)
	var cast: Dictionary = preview.story.get_crew(&"Stage").capture()["cast"]
	assert_eq(cast.keys().filter(func(id: String) -> bool: return cast[id]["on_stage"]).size(), 3, "Cleo, Theo, and Leo")
	preview.show_at(source, doc, "wheres_biscuit", null, context)
	await _frames(3)
	assert_false(preview.get_director().is_playing(), "no block, no story")


func test_the_preview_waits_while_the_story_plays() -> void:
	var preview := await _open()
	preview.show_at(source, doc, "wheres_biscuit", _statement("start", 4), context)
	await _frames(3)
	preview.set_paused(true)
	assert_false(preview.get_director().is_playing())
	assert_eq(preview.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	preview.set_paused(false)
	assert_eq(preview.viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	assert_false(preview.story.get_crew_names().has(&"Audio"), "the preview makes no sound")
