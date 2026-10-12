extends Control
## Visual Novel StoryTeller Studio (docs/studio-design.md). For now it opens
## one story, the Where's Biscuit sample, in the block editor, saves every
## change in the app's storage, and plays the story as it is. The home
## screen with the student's stories (step S1) and the stage preview (S3)
## come next.

const SAMPLE_TALE := "res://examples/wheres_biscuit/tales/wheres_biscuit.tale"
const SAMPLE_CONFIG := "res://examples/wheres_biscuit/story_config.tres"
## Where the student's copy of the sample is saved.
const SAVED_TALE := "user://stories/wheres_biscuit/wheres_biscuit.tale"
const CHECK_SCENE := "res://studio/check/tablet_check.tscn"
const FONT_SIZE := 20

var editor: StudioBlockEditor
var config: StoryConfig
var _undo_button: Button
var _redo_button: Button
var _menu: MenuButton
var _play_layer: CanvasLayer


func _ready() -> void:
	config = load(SAMPLE_CONFIG)
	_build()
	var saved = FileAccess.get_file_as_string(SAVED_TALE) if FileAccess.file_exists(SAVED_TALE) else null
	editor.open_tale(SAMPLE_TALE, config, saved)
	editor.source_changed.connect(_on_source_changed)
	_update_buttons()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("1b1e27")
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
	var title := Label.new()
	title.text = "Where's Biscuit?"
	title.add_theme_font_size_override("font_size", FONT_SIZE + 6)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	_undo_button = _button("↶ Undo", func() -> void: editor.undo())
	bar.add_child(_undo_button)
	_redo_button = _button("↷ Redo", func() -> void: editor.redo())
	bar.add_child(_redo_button)
	bar.add_child(_button("▶ Play", func() -> void: play("start")))
	bar.add_child(_button("▶ This scene", func() -> void: play(editor.current_scene)))
	_menu = MenuButton.new()
	_menu.text = "⋯"
	_menu.flat = false
	_menu.custom_minimum_size = Vector2(StudioBlockEditor.TOUCH_SIZE + 12, StudioBlockEditor.TOUCH_SIZE)
	_menu.add_theme_font_size_override("font_size", FONT_SIZE)
	var popup := _menu.get_popup()
	popup.add_theme_font_size_override("font_size", FONT_SIZE)
	popup.add_check_item("Show Code blocks", 0)
	popup.add_item("Start the sample over", 1)
	popup.add_item("Tablet check", 2)
	popup.id_pressed.connect(_on_menu)
	bar.add_child(_menu)
	editor = StudioBlockEditor.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(editor)


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, StudioBlockEditor.TOUCH_SIZE)
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(on_press)
	return button


func _on_menu(id: int) -> void:
	match id:
		0:
			var popup := _menu.get_popup()
			popup.set_item_checked(0, not popup.is_item_checked(0))
			editor.show_code_blocks = popup.is_item_checked(0)
		1:
			# Undo brings the student's version back.
			editor.commit(FileAccess.get_file_as_string(SAMPLE_TALE))
		2:
			Engine.set_meta("studio_return", scene_file_path)
			get_tree().change_scene_to_file(CHECK_SCENE)


func _on_source_changed(source: String) -> void:
	DirAccess.make_dir_recursive_absolute(SAVED_TALE.get_base_dir())
	var file := FileAccess.open(SAVED_TALE, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
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
	visible = false
	Story.start(config)
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.add_tale(tale)
	_play_layer = CanvasLayer.new()
	_play_layer.layer = 100
	var close := _button("✕", stop_playing)
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
	visible = true
