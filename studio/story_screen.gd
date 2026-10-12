class_name StudioStoryScreen
extends Control
## One story open in the blocks (docs/studio-design.md §4): the top bar with
## the way home, the story's name, Undo, Redo, Play, and Share, over the
## block editor. Every change is saved at once.

## Emitted when the student taps ⌂ to go back to their stories.
signal home_requested

var library: StudioLibrary
var config: StoryConfig
var story_id := ""
var editor: StudioBlockEditor
var _title_button: Button
var _undo_button: Button
var _redo_button: Button
var _play_layer: CanvasLayer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = StudioUI.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	column.add_child(bar)
	bar.add_child(StudioUI.button("⌂ Stories", func() -> void: home_requested.emit()))
	_title_button = StudioUI.button("", rename)
	_title_button.flat = true
	_title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_button.clip_text = true
	_title_button.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE + 6)
	bar.add_child(_title_button)
	_undo_button = StudioUI.button("↶ Undo", func() -> void: editor.undo())
	bar.add_child(_undo_button)
	_redo_button = StudioUI.button("↷ Redo", func() -> void: editor.redo())
	bar.add_child(_redo_button)
	bar.add_child(StudioUI.button("▶ Play", func() -> void: play("start")))
	bar.add_child(StudioUI.button("▶ This scene", func() -> void: play(editor.current_scene)))
	bar.add_child(StudioUI.button("⇪ Share", share))
	editor = StudioBlockEditor.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.source_changed.connect(_on_source_changed)
	column.add_child(editor)


## Opens the story [param id] from [member library].
func open(id: String) -> void:
	story_id = id
	library.mark_opened(id)
	editor.current_scene = ""
	editor.open_tale(library.tale_path(id), config)
	_show_title()
	_update_buttons()


func get_title() -> String:
	return library.get_story(story_id).get("title", story_id)


## Asks for a new name for the story.
func rename() -> void:
	editor.ask_text("Name of your story", get_title(), false, func(text: String) -> void:
		library.rename(story_id, text)
		_show_title())


## Saves a copy of the story as a file (see [StudioFiles]).
func share() -> void:
	StudioFiles.share(library, story_id, editor.show_message)


func _show_title() -> void:
	_title_button.text = get_title() + "  ✎"


func _on_source_changed(source: String) -> void:
	library.save_tale(story_id, source)
	_update_buttons()


func _update_buttons() -> void:
	_undo_button.disabled = not editor.can_undo()
	_redo_button.disabled = not editor.can_redo()


## The story as the blocks show it, ready to play, or null when its text
## has a mistake. Problems the checker finds don't stop it: they show as
## hints on the blocks (docs/studio-design.md §2).
static func compile_story(source: String, tale_name: String, context: TaleCheckContext) -> Tale:
	var doc := TaleParser.parse(source)
	if doc.has_errors():
		return null
	var checker := TaleChecker.new()
	checker.run(doc, context if context != null else TaleCheckContext.new())
	return TaleCompiler.compile(doc, tale_name, checker.call_kinds)


## Plays the story from the start of [param scene], full screen with a ✕
## to come back. Returns when the story ends or ✕ is pressed.
func play(scene: String) -> void:
	var tale := compile_story(editor.source, editor.tale_name(), editor.check_context)
	if tale == null:
		editor.show_message("Part of this story has a mistake, so it can't play yet.")
		return
	if editor.doc.find_beat(scene) == null:
		editor.show_message("This story has no scene called “%s”." % StudioBlockEditor.scene_title(scene))
		return
	var app := get_parent() as Control
	(app if app != null else self).visible = false
	Story.start(config)
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.add_tale(tale)
	_play_layer = CanvasLayer.new()
	_play_layer.layer = 100
	var close := StudioUI.button("✕", stop_playing)
	close.custom_minimum_size = Vector2(64, 64)
	close.add_theme_font_size_override("font_size", 28)
	close.position = Vector2(16, 16)
	_play_layer.add_child(close)
	add_child(_play_layer)
	await Story.play(editor.tale_name(), scene)
	stop_playing()


func is_playing() -> bool:
	return _play_layer != null


## Stops the story and shows the blocks again.
func stop_playing() -> void:
	if _play_layer == null:
		return
	_play_layer.queue_free()
	_play_layer = null
	Story.shut_down()
	var app := get_parent() as Control
	(app if app != null else self).visible = true
