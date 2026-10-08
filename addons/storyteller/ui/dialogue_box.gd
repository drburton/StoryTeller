class_name DialogueBox
extends Control
## Base class for dialogue box styles. A style shows one line at a time and
## returns from [method show_line] when the player continues.
##
## The base class handles the typewriter effect, the [code][pause][/code]
## tags, auto mode, skipping, and continue input, so a style only needs to
## build its controls and call [method reveal].
##
## Tags handled here before the text reaches the [RichTextLabel]:
## [code][pause][/code] waits for the player, [code][pause=0.5][/code] waits
## half a second. Everything else is passed on as BBCode.

## Emitted when the player asks to continue (click, tap, or accept key).
signal continue_pressed
## Emitted when a line has been fully revealed.
signal line_revealed

## Characters revealed per second. 0 shows text instantly.
var characters_per_second := 40.0
## When true, lines continue on their own after [member auto_delay] plus
## time proportional to the text length.
var auto_advance := false
var auto_delay := 1.0
## When true, lines are skipped as fast as possible.
var skipping := false
## Returns true while something (such as a menu) should take the player's
## input instead of the dialogue box.
var input_blocked := func() -> bool: return false

var _typing := false
var _cancelled := false
var _waiting := false


## Shows [param line] (see [method TalePresenter.show_line]). Awaitable.
func show_line(_line: Dictionary) -> void:
	pass


## Hides the box between scenes.
func hide_box() -> void:
	hide()


## Where the quick menu's bottom-right corner goes, in canvas coordinates.
## Override this in boxes with their own layout.
func get_quick_menu_corner() -> Vector2:
	var rect := get_global_rect()
	return Vector2(rect.end.x - 28, rect.position.y + rect.size.y * 0.7 - 4)


## Starts a new page, for styles that keep several lines on screen.
func clear_page() -> void:
	pass


## Stops waiting for the player and returns from show_line at once.
func cancel() -> void:
	_cancelled = true
	_typing = false
	continue_pressed.emit()


## Types [param text] into [param label], stopping at pause tags, then waits
## for the player. Awaitable. [param indicator] is shown while waiting.
func reveal(label: RichTextLabel, text: String, indicator: CanvasItem = null) -> void:
	_cancelled = false
	var parsed := extract_pauses(text)
	var start := label.get_parsed_text().length()
	if label.get_parsed_text().is_empty():
		label.text = parsed["text"]
	else:
		label.append_text(parsed["text"])
	var total := label.get_parsed_text().length()
	label.visible_characters = start
	var stops: Array = []
	for pause in parsed["pauses"]:
		stops.append({"at": start + pause["at"], "seconds": pause["seconds"]})
	stops.append({"at": total, "seconds": -1.0})
	for stop in stops:
		if _cancelled:
			return
		await _reveal_to(label, stop["at"])
		if stop["seconds"] >= 0.0:
			if not skipping:
				await get_tree().create_timer(stop["seconds"]).timeout
		else:
			if indicator:
				indicator.visible = true
			await _wait_for_continue(total - start)
			if indicator:
				indicator.visible = false
	label.visible_characters = -1
	line_revealed.emit()


## Splits text at pause tags. Returns {"text": bbcode without pause tags,
## "pauses": [{"at": visible character index, "seconds": float or -1}]}.
static func extract_pauses(text: String) -> Dictionary:
	var regex := RegEx.create_from_string("\\[pause(?:=([0-9.]+))?\\]")
	var measure := RichTextLabel.new()
	measure.bbcode_enabled = true
	var pauses: Array[Dictionary] = []
	var clean := ""
	var last := 0
	for found in regex.search_all(text):
		clean += text.substr(last, found.get_start() - last)
		last = found.get_end()
		measure.text = clean
		var seconds := found.get_string(1).to_float() if found.get_string(1) else -1.0
		pauses.append({"at": measure.get_parsed_text().length(), "seconds": seconds})
	clean += text.substr(last)
	measure.free()
	return {"text": clean, "pauses": pauses}


func _reveal_to(label: RichTextLabel, count: int) -> void:
	if skipping or characters_per_second <= 0.0:
		label.visible_characters = count
		return
	_typing = true
	var shown := float(maxi(label.visible_characters, 0))
	while _typing and shown < count:
		await get_tree().process_frame
		shown += characters_per_second * get_process_delta_time()
		label.visible_characters = mini(int(shown), count)
	label.visible_characters = count
	_typing = false


func _wait_for_continue(length: int) -> void:
	if skipping:
		await get_tree().process_frame
		return
	_waiting = true
	if auto_advance:
		var timer := get_tree().create_timer(auto_delay + length * 0.03)
		while timer.time_left > 0.0 and auto_advance and not skipping and not _cancelled:
			if await _next_input_or_frame():
				break
	else:
		await continue_pressed
	_waiting = false


## Waits one frame. Returns true if the player pressed continue meanwhile.
func _next_input_or_frame() -> bool:
	var state := {"pressed": false}
	var mark := func() -> void: state["pressed"] = true
	continue_pressed.connect(mark, CONNECT_ONE_SHOT)
	await get_tree().process_frame
	if continue_pressed.is_connected(mark):
		continue_pressed.disconnect(mark)
	return state["pressed"]


func _gui_input(event: InputEvent) -> void:
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var touched: bool = event is InputEventScreenTouch and event.pressed
	if (clicked or touched) and not input_blocked.call():
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not input_blocked.call() and event.is_action_pressed("story_continue"):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _typing:
		_typing = false
	else:
		continue_pressed.emit()
