class_name StudioStoryScreen
extends Control
## One story open in the blocks (docs/studio-design.md §4): the top bar with
## the way home, the story's name, Undo, Redo, Play, and Share, over the
## block editor. Every change is saved at once.

## Emitted when the student taps ⌂ to go back to their stories.
signal home_requested

var library: StudioLibrary
## The app's config: the dialogue box, theme, and settings every story shares.
var config: StoryConfig
## [member config] with the open story's own folders (see
## [method StudioLibrary.story_config]).
var story_config: StoryConfig
var story_id := ""
## Width of the stage preview, in pixels.
const PREVIEW_WIDTH := 360
var editor: StudioBlockEditor
## The stage at the chosen block, beside the blocks.
var preview: StudioStagePreview
## The story's characters, backgrounds, and sounds, under the preview.
var library_panel: StudioLibraryPanel
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
	bar.add_child(StudioUI.button("⇪ Share", share))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	editor = StudioBlockEditor.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.source_changed.connect(_on_source_changed)
	editor.block_selected.connect(func(_line: int) -> void: refresh_preview())
	editor.scene_selected.connect(func(_beat_name: String) -> void: refresh_preview())
	editor.map_requested.connect(open_map)
	row.add_child(editor)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = PREVIEW_WIDTH
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	preview = StudioStagePreview.new()
	preview.custom_minimum_size = Vector2(PREVIEW_WIDTH, PREVIEW_WIDTH * 9.0 / 16.0)
	side.add_child(preview)
	side.add_child(StudioUI.button("▶ Play from here", play_from_here))
	var hint := StudioUI.label("Tap a block to see the stage there.", StudioUI.FONT_SIZE - 4, Color(0.75, 0.78, 0.85))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	library_panel = StudioLibraryPanel.new()
	library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_panel.assets_changed.connect(reload_assets)
	scroll.add_child(library_panel)


## Opens the story [param id] from [member library].
func open(id: String) -> void:
	story_id = id
	library.mark_opened(id)
	library.add_starter_items(id)
	story_config = library.story_config(id, config)
	editor.use_starter = true
	editor.current_scene = ""
	editor.open_tale(library.tale_path(id), story_config)
	_show_title()
	_update_buttons()
	preview.setup(story_config)
	library_panel.show_story(library, id)
	refresh_preview()


## Reads the story's characters, pictures, and sounds again after some were
## added, in the blocks, the hints, and the preview.
func reload_assets() -> void:
	editor.reload_assets()
	preview.setup(story_config)
	refresh_preview()


## The block the preview and Play from here start at: the chosen block, or
## else the first block of the scene shown. Null when the scene is empty.
func chosen_block() -> TaleNode:
	var line := editor.get_selected_line()
	var node := TaleEdit.find_at_line(editor.doc, line) if line > 0 else null
	if node != null:
		return node
	var beat := editor.doc.find_beat(editor.current_scene)
	var children := TaleEdit.content_children(beat) if beat != null else ([] as Array[TaleNode])
	return children[0] if not children.is_empty() else null


## Shows the stage at the chosen block.
func refresh_preview() -> void:
	if preview.story != null and is_visible_in_tree():
		preview.show_at(editor.source, editor.doc, editor.tale_name(), chosen_block(), editor.check_context)


## Plays the story from the chosen block, with the stage, music, and numbers
## as they would be there (see [StudioFromHere]).
func play_from_here() -> void:
	var target := chosen_block()
	if target == null:
		editor.show_message("Add a block to this scene first.")
		return
	await play(StudioFromHere.FROM_HERE_BEAT, StudioFromHere.from_here_source(editor.source, editor.doc, target))


func get_title() -> String:
	return library.get_story(story_id).get("title", story_id)


## Shows the map of scenes over the blocks; tapping a scene opens it.
func open_map() -> StudioSceneMap:
	var map := StudioSceneMap.new()
	map.top_level = true
	map.z_index = 20
	add_child(map)
	map.show_story(editor.doc, editor.tale_name(), editor.current_scene)
	map.scene_chosen.connect(editor.select_scene)
	return map


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
	# A starter character, background, or sound the blocks now use comes into
	# the story's folder.
	if not library.add_starter_items(story_id).is_empty():
		editor.reload_assets()
		preview.setup(story_config)
		library_panel.refresh()
	_update_buttons()
	refresh_preview()


func _update_buttons() -> void:
	_undo_button.disabled = not editor.can_undo()
	_redo_button.disabled = not editor.can_redo()


## The story as the blocks show it, ready to play, or null when its text
## has a mistake. Problems the checker finds don't stop it: they show as
## hints on the blocks (docs/studio-design.md §2).
static func compile_story(source: String, tale_name: String, context: TaleCheckContext) -> Tale:
	return StudioFromHere.compile_story(source, tale_name, context)


## Plays the story from the start of [param scene], full screen with a ✕
## to come back. [param source] replaces the story's text, for Play from
## here. Returns when the story ends or ✕ is pressed.
func play(scene: String, source := "") -> void:
	if source.is_empty():
		source = editor.source
	var tale := compile_story(source, editor.tale_name(), editor.check_context)
	if tale == null:
		editor.show_message("Part of this story has a mistake, so it can't play yet.")
		return
	if TaleParser.parse(source).find_beat(scene) == null:
		editor.show_message("This story has no scene called “%s”." % StudioBlockEditor.scene_title(scene))
		return
	preview.set_paused(true)
	var app := get_parent() as Control
	(app if app != null else self).visible = false
	Story.start(story_config)
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
	preview.set_paused(false)
	refresh_preview()
