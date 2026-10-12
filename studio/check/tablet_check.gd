extends Control
## The tablet check for Visual Novel StoryTeller Studio (milestone M8, step
## S0; docs/studio-design.md §10). A small app with one panel per check: a
## person runs it on a real iPad or Android tablet, taps Works or Problem on
## each panel, and sends the results summary back.

const RESULTS_PATH := "user://tablet_check_results.json"
const STARTS_PATH := "user://tablet_check_starts.json"
const STORY_SCENE := "res://examples/wheres_biscuit/main.tscn"
const BLOCK_COLORS: Array[Color] = [Color("4c97ff"), Color("9966ff"), Color("59c059"), Color("ff8c1a"), Color("ff6680")]
const BLOCK_NAMES: Array[String] = ["Say", "Show", "Background", "Choice", "Add 1"]
const LONG_PRESS_SECONDS := 0.5

## Each check: an id, a title, and what to do.
const CHECKS := [
	{"id": "start", "title": "1. Starting up", "how": "How long the app took to start, and how smooth it runs. Watch the frames per second while you drag and scroll."},
	{"id": "drag", "title": "2. Dragging blocks", "how": "Drag the colored blocks into the box with your finger and put them in a new order. Hold one still for half a second: it should say \"Long press\"."},
	{"id": "typing", "title": "3. Typing", "how": "Tap the box and type a sentence. The keyboard should appear, and you should still see what you type."},
	{"id": "photo", "title": "4. Photos and sharing", "how": "Choose a photo: it should appear here. Then save a story file and look for it in Files (or your file manager)."},
	{"id": "saving", "title": "5. Saving", "how": "Close the app, restart the tablet, and open the app again. The number of starts should go up by one."},
	{"id": "sound", "title": "6. Sound", "how": "Tap Play sound. You should hear a short tune."},
	{"id": "stage", "title": "7. The stage", "how": "Play the sample story. Characters, backgrounds, fades, and the dialogue box should look right. Use ✕ Back to return."},
]

var _results := {}
var _starts := 0
var _startup_seconds := 0.0
var _fps_label: Label
var _info_label: Label
var _drop_column: VBoxContainer
var _drop_hint: Label
var _drag_block: Control
var _drag_offset := Vector2.ZERO
var _press_time := 0.0
var _pressing: Control
var _long_press_label: Label
var _typed_label: Label
var _keyboard_label: Label
var _photo_rect: TextureRect
var _photo_label: Label
var _share_label: Label
var _sound_player: AudioStreamPlayer


func _ready() -> void:
	_startup_seconds = Time.get_ticks_msec() / 1000.0
	_load_results()
	_count_start()
	_build()


func _process(delta: float) -> void:
	if _fps_label:
		_fps_label.text = "%d frames per second" % Engine.get_frames_per_second()
	if _keyboard_label and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_keyboard_label.text = "Keyboard height: %d pixels" % DisplayServer.virtual_keyboard_get_height()
	if _pressing != null and _drag_block == null:
		_press_time += delta
		if _press_time >= LONG_PRESS_SECONDS:
			_long_press_label.text = "Long press on \"%s\" works." % _pressing.get_meta("block_name")
			_pressing = null


## Text to paste into a message: the device, and each check's result.
func summary() -> String:
	var lines := PackedStringArray([
		"Visual Novel StoryTeller Studio tablet check",
		_device_text(),
		"Started in %.1f s. Starts so far: %d." % [_startup_seconds, _starts],
	])
	for check in CHECKS:
		lines.append("%s: %s" % [check["title"], _results.get(check["id"], "not checked")])
	return "\n".join(lines)


# --- Layout -------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("1e2230")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)

	if Engine.has_meta("studio_return"):
		var back := _button("← Back to the Studio", func() -> void:
			get_tree().change_scene_to_file(Engine.get_meta("studio_return")))
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(back)
	column.add_child(_label("Visual Novel StoryTeller Studio: tablet check", 30))
	_info_label = _label("%s\nStarted in %.1f seconds. Starts so far: %d." % [_device_text(), _startup_seconds, _starts], 18)
	column.add_child(_info_label)
	_fps_label = _label("", 18)
	column.add_child(_fps_label)

	var builders := {
		"start": _build_start, "drag": _build_drag, "typing": _build_typing, "photo": _build_photo,
		"saving": _build_saving, "sound": _build_sound, "stage": _build_stage,
	}
	for check in CHECKS:
		column.add_child(_panel(check, builders[check["id"]]))

	var results_button := _button("Show results to send", func() -> void: _show_summary())
	column.add_child(results_button)


func _panel(check: Dictionary, builder: Callable) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2c3245")
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label(check["title"], 24))
	var how := _label(check["how"], 18)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)
	builder.call(box)
	var verdict := HBoxContainer.new()
	verdict.add_theme_constant_override("separation", 12)
	var status := _label("Result: %s" % _results.get(check["id"], "not checked yet"), 18)
	for answer in ["Works", "Problem"]:
		verdict.add_child(_button(answer, func() -> void:
			_results[check["id"]] = answer.to_lower()
			status.text = "Result: %s" % answer.to_lower()
			_save_results()))
	verdict.add_child(status)
	box.add_child(verdict)
	return panel


func _build_start(box: VBoxContainer) -> void:
	box.add_child(_label("Renderer: %s. Screen: %s at %d dpi." % [
		RenderingServer.get_current_rendering_method(), DisplayServer.screen_get_size(), DisplayServer.screen_get_dpi()], 18))


func _build_drag(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var palette := VBoxContainer.new()
	palette.add_theme_constant_override("separation", 8)
	row.add_child(palette)
	for i in BLOCK_NAMES.size():
		palette.add_child(_block(BLOCK_NAMES[i], BLOCK_COLORS[i]))
	var drop := PanelContainer.new()
	drop.custom_minimum_size = Vector2(320, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("161a24")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	drop.add_theme_stylebox_override("panel", style)
	row.add_child(drop)
	var drop_area := VBoxContainer.new()
	drop.add_child(drop_area)
	_drop_hint = _label("Drop blocks here", 16)
	drop_area.add_child(_drop_hint)
	_drop_column = VBoxContainer.new()
	_drop_column.add_theme_constant_override("separation", 6)
	_drop_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drop_area.add_child(_drop_column)
	_long_press_label = _label("Long press: not tried yet.", 18)
	box.add_child(_long_press_label)


func _build_typing(box: VBoxContainer) -> void:
	var edit := LineEdit.new()
	edit.placeholder_text = "Tap here and type"
	edit.custom_minimum_size = Vector2(0, 56)
	edit.add_theme_font_size_override("font_size", 22)
	box.add_child(edit)
	_typed_label = _label("You typed: ", 18)
	box.add_child(_typed_label)
	edit.text_changed.connect(func(text: String) -> void: _typed_label.text = "You typed: " + text)
	_keyboard_label = _label("Keyboard height: not shown", 18)
	box.add_child(_keyboard_label)


func _build_photo(box: VBoxContainer) -> void:
	var native := DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)
	box.add_child(_label("The system's own file picker is %s." % ("available" if native else "NOT available"), 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_button("Choose a photo", _choose_photo))
	row.add_child(_button("Save a story file", _save_story_file))
	_photo_label = _label("No photo yet.", 18)
	box.add_child(_photo_label)
	_photo_rect = TextureRect.new()
	_photo_rect.custom_minimum_size = Vector2(240, 180)
	_photo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_photo_rect)
	_share_label = _label("No story file saved yet.", 18)
	box.add_child(_share_label)


func _build_saving(box: VBoxContainer) -> void:
	box.add_child(_label("Starts so far: %d. Stored at %s." % [_starts, ProjectSettings.globalize_path("user://")], 18))


func _build_sound(box: VBoxContainer) -> void:
	_sound_player = AudioStreamPlayer.new()
	_sound_player.stream = _tune()
	add_child(_sound_player)
	box.add_child(_button("Play sound", func() -> void: _sound_player.play()))


func _build_stage(box: VBoxContainer) -> void:
	box.add_child(_button("Play the sample story", _play_story))


# --- Dragging -----------------------------------------------------------------

func _block(block_name: String, color: Color) -> Control:
	var block := PanelContainer.new()
	block.set_meta("block_name", block_name)
	block.custom_minimum_size = Vector2(200, 52)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	block.add_theme_stylebox_override("panel", style)
	var text := _label(block_name, 20)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(text)
	block.gui_input.connect(_on_block_input.bind(block))
	return block


func _on_block_input(event: InputEvent, block: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pressing = block
		_press_time = 0.0
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _drag_block == null and _pressing == block and event.relative.length() > 2.0:
			_start_drag(block, event.global_position)


# Once a drag starts, the block may leave its parent, so the rest of the
# drag is followed here instead of through the block's own input.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_pressing = null
		if _drag_block != null:
			_drop(event.global_position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_block != null:
		_drag_block.global_position = event.global_position - _drag_offset
		get_viewport().set_input_as_handled()


func _start_drag(block: Control, at: Vector2) -> void:
	# Blocks from the palette are copied; blocks already dropped are moved.
	if block.get_parent() == _drop_column:
		_drag_block = block
		block.get_parent().remove_child(block)
	else:
		_drag_block = _block(block.get_meta("block_name"), (block.get_theme_stylebox("panel") as StyleBoxFlat).bg_color)
	_drag_offset = Vector2(40, 26)
	_drag_block.top_level = true
	_drag_block.modulate.a = 0.85
	add_child(_drag_block)
	_drag_block.global_position = at - _drag_offset
	_pressing = null


func _drop(at: Vector2) -> void:
	var block := _drag_block
	_drag_block = null
	block.top_level = false
	block.modulate.a = 1.0
	block.get_parent().remove_child(block)
	if not (_drop_column.get_parent() as Control).get_global_rect().grow(40).has_point(at):
		block.queue_free()
		_drop_hint.visible = _drop_column.get_child_count() == 0
		return
	var index := _drop_column.get_child_count()
	for child in _drop_column.get_children():
		if at.y < child.get_global_rect().get_center().y:
			index = child.get_index()
			break
	_drop_column.add_child(block)
	_drop_column.move_child(block, index)
	_drop_hint.visible = false


# --- Photos and story files ---------------------------------------------------

func _choose_photo() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		_photo_label.text = "The system file picker is not available here."
		return
	DisplayServer.file_dialog_show("Choose a photo", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp; Pictures"]), _on_photo_chosen)


func _on_photo_chosen(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if not status or paths.is_empty():
		_photo_label.text = "No photo chosen."
		return
	var bytes := FileAccess.get_file_as_bytes(paths[0])
	var image := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	for loader in [image.load_jpg_from_buffer, image.load_png_from_buffer, image.load_webp_from_buffer]:
		if not bytes.is_empty():
			error = loader.call(bytes)
		if error == OK:
			break
	if error != OK:
		_photo_label.text = "Could not read %s (%d bytes, error %d)." % [paths[0], bytes.size(), error]
		return
	_photo_rect.texture = ImageTexture.create_from_image(image)
	_photo_label.text = "Photo loaded: %d x %d from %s" % [image.get_width(), image.get_height(), paths[0]]


func _save_story_file() -> void:
	var zip_path := "user://check_story.zip"
	var packer := ZIPPacker.new()
	if packer.open(zip_path) != OK:
		_share_label.text = "Could not make the story file."
		return
	packer.start_file("story.tale")
	packer.write_file("beat start:\n\t\"Hello from the tablet check.\"\n".to_utf8_buffer())
	packer.close_file()
	packer.close()
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		_share_label.text = "Story file made at %s, but the system file picker is not available to save it elsewhere." % ProjectSettings.globalize_path(zip_path)
		return
	DisplayServer.file_dialog_show("Save the story file", "", "my_story.zip", false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		PackedStringArray(["*.zip; Story files"]), func(status: bool, paths: PackedStringArray, _filter: int) -> void:
			if not status or paths.is_empty():
				_share_label.text = "Saving was cancelled."
				return
			var out := FileAccess.open(paths[0], FileAccess.WRITE)
			if out == null:
				_share_label.text = "Could not write %s (error %d)." % [paths[0], FileAccess.get_open_error()]
				return
			out.store_buffer(FileAccess.get_file_as_bytes(zip_path))
			out.close()
			_share_label.text = "Saved to %s. Look for it in Files." % paths[0])


# --- The sample story ---------------------------------------------------------

func _play_story() -> void:
	var back := BackLayer.new()
	back.return_scene = scene_file_path
	get_tree().root.add_child(back)
	get_tree().change_scene_to_file(STORY_SCENE)


## A ✕ Back button that stays on top of the sample story. It is its own
## node because the check screen is freed while the story plays.
class BackLayer extends CanvasLayer:
	var return_scene := ""

	func _ready() -> void:
		layer = 100
		name = "TabletCheckBack"
		var button := Button.new()
		button.text = "✕ Back"
		button.custom_minimum_size = Vector2(120, 52)
		button.add_theme_font_size_override("font_size", 20)
		button.position = Vector2(16, 16)
		button.pressed.connect(_go_back)
		add_child(button)

	func _go_back() -> void:
		Story.shut_down()
		get_tree().change_scene_to_file(return_scene)
		queue_free()


# --- Saved data ---------------------------------------------------------------

func _count_start() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(STARTS_PATH)) if FileAccess.file_exists(STARTS_PATH) else null
	_starts = int(data.get("starts", 0)) if data is Dictionary else 0
	if not Engine.has_meta("tablet_check_counted"):
		# Count real app starts only, not returns from the sample story.
		Engine.set_meta("tablet_check_counted", true)
		_starts += 1
		var file := FileAccess.open(STARTS_PATH, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"starts": _starts, "last": Time.get_datetime_string_from_system()}))


func _load_results() -> void:
	if FileAccess.file_exists(RESULTS_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RESULTS_PATH))
		if data is Dictionary:
			_results = data


func _save_results() -> void:
	var file := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_results))


func _show_summary() -> void:
	var text := summary()
	DisplayServer.clipboard_set(text)
	var dialog := AcceptDialog.new()
	dialog.title = "Results (copied, ready to paste)"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))


# --- Small helpers ------------------------------------------------------------

func _device_text() -> String:
	return "%s %s, %s, Godot %s" % [OS.get_name(), OS.get_version(), OS.get_model_name(), Engine.get_version_info()["string"]]


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 52)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(on_press)
	return button


## A short rising tune, made in code so the check needs no sound files.
static func _tune() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	for freq in [523.25, 659.25, 783.99, 1046.5]:
		var count := int(rate * 0.18)
		for i in count:
			var envelope := 1.0 - float(i) / count
			var value := int(sin(TAU * freq * i / rate) * envelope * 12000.0)
			data.append(value & 0xFF)
			data.append((value >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
