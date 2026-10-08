class_name ListChoiceMenu
extends ChoiceMenu
## The default choice style: a centered column of buttons. Supports
## [code]choose(timeout = seconds)[/code] with a countdown bar.

signal _picked(index: int)

var _column: VBoxContainer
var _timer_bar: ProgressBar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(420, 0)
	_column.add_theme_constant_override("separation", 10)
	center.add_child(_column)
	hide()


## Closes the menu as if the timeout expired.
func cancel() -> void:
	if visible:
		_picked.emit(-1)


func choose(options: Array[Dictionary], settings: Dictionary) -> int:
	for child in _column.get_children():
		child.queue_free()
	var first_enabled: Button = null
	for i in options.size():
		var button := Button.new()
		button.text = options[i]["text"]
		button.disabled = not options[i]["enabled"]
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(func() -> void: _picked.emit(i))
		_column.add_child(button)
		if first_enabled == null and not button.disabled:
			first_enabled = button
	var timeout: float = float(settings.get("timeout", 0.0))
	_timer_bar = null
	if timeout > 0.0:
		_timer_bar = ProgressBar.new()
		_timer_bar.show_percentage = false
		_timer_bar.max_value = timeout
		_timer_bar.value = timeout
		_column.add_child(_timer_bar)
	show()
	if first_enabled:
		first_enabled.grab_focus()

	var result := {"index": -2}
	var on_pick := func(index: int) -> void: result["index"] = index
	_picked.connect(on_pick)
	var remaining := timeout
	while result["index"] == -2:
		await get_tree().process_frame
		if timeout > 0.0:
			remaining -= get_process_delta_time()
			_timer_bar.value = remaining
			if remaining <= 0.0:
				result["index"] = -1
	_picked.disconnect(on_pick)
	hide()
	return result["index"]
