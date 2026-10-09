class_name ListChoiceMenu
extends ChoiceMenu
## The default choice style, "list": a centered column of buttons. Supports
## [code]choose(timeout = seconds)[/code] with a countdown bar.

var _column: VBoxContainer
var _timer_bar: ProgressBar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Centered in the space above the classic dialogue box.
	center.anchor_bottom = 0.7
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(420, 0)
	_column.add_theme_constant_override("separation", 10)
	center.add_child(_column)
	hide()


func choose(options: Array[Dictionary], settings: Dictionary) -> int:
	for child in _column.get_children():
		child.queue_free()
	var first_enabled: Button = null
	for i in options.size():
		var button := Button.new()
		button.text = options[i]["text"]
		button.disabled = not options[i]["enabled"]
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(pick.bind(i))
		_column.add_child(button)
		if first_enabled == null and not button.disabled:
			first_enabled = button
	_timer_bar = ChoiceMenu.make_timer_bar(settings)
	if _timer_bar != null:
		_column.add_child(_timer_bar)
	show()
	if first_enabled:
		first_enabled.grab_focus()
	return await wait_for_pick(float(settings.get("timeout", 0.0)), _timer_bar)
