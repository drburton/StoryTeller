class_name DialogueBox
extends Control
## Base class for dialogue box styles. A style shows one line at a time and
## returns from [method show_line] when the player continues.
##
## The base class handles the typewriter effect, the typing tags, auto mode,
## skipping, and continue input, so a style only needs to build its controls
## and call [method reveal].
##
## Tags handled here before the text reaches the [RichTextLabel]:
## [code][pause][/code] waits for the player, [code][pause=0.5][/code] waits
## half a second, [code][speed=2]...[/speed][/code] types twice as fast,
## [code][instant]...[/instant][/code] shows its text at once, and
## [code][act=N][/code] and [code][sound=N][/code] (made by the director from
## the tale's tags) call [member on_text_tag] when typing reaches them.
## Everything else is passed on as BBCode.

## Emitted when the player asks to continue (click, tap, or accept key).
signal continue_pressed
## Emitted when a line has been fully revealed.
signal line_revealed

func _init() -> void:
	# Lines arrive translated already (see TaleDirector), so a line that
	# matches a UI key must not be translated again.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


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
## Size of the text relative to the style's own, from the player's "Text
## size" setting. Styles apply it in [method _apply_text_scale].
var text_scale := 1.0:
	set(value):
		text_scale = value
		_apply_text_scale()
## How the box appears and hides: "fade", "slide" (rises from below while
## fading), or "none". Set from [member StoryConfig.dialogue_box_transition].
var box_transition := "none"
## Seconds the box takes to appear or hide.
var box_transition_time := 0.2
## Called with the tag name and value when typing reaches an
## [code][act=N][/code] or [code][sound=N][/code] tag. Typing waits for it.
## The Dialogue crew member runs the tag through the director.
var on_text_tag := Callable()

var _typing := false
var _cancelled := false
var _waiting := false
## True from the start of [method reveal] until it returns.
var _revealing := false
## Set when the player clicks while text types: the text shows at once up
## to the next pause.
var _rushing := false
## Typing speed spans of the text being revealed, in label characters:
## [code]{"from", "to", "factor"}[/code], where factor 0 shows text at once.
var _spans: Array[Dictionary] = []
var _box_tween: Tween
## True while the box fades out after hide_box().
var _hiding := false
## Goes up on every cancel(), so a line that was waiting for the box to
## appear knows to stop.
var _cancel_count := 0

## Pixels the box moves with the "slide" transition.
const SLIDE_DISTANCE := 40.0


## Shows [param line] (see [method TalePresenter.show_line]). Awaitable.
func show_line(_line: Dictionary) -> void:
	pass


## Hides the box between scenes, with [member box_transition].
func hide_box() -> void:
	disappear()


## Shows the box with [member box_transition] if it is hidden. Awaitable.
## Returns false when the line was cancelled (a save was loaded) while the
## box appeared, so [method show_line] should stop. Styles call this at the
## start of [method show_line].
func begin_line() -> bool:
	var token := _cancel_count
	await appear()
	return token == _cancel_count


## Shows the box with [member box_transition]. Awaitable.
func appear() -> void:
	if visible and not _hiding:
		return
	_stop_box_tween()
	if _hiding:
		# A hide that was still fading out counts as finished.
		_hiding = false
		_on_hidden()
	show()
	if not _animates_box():
		_set_box_shown(1.0)
		return
	_set_box_shown(0.0)
	_box_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_box_tween.tween_method(_set_box_shown, 0.0, 1.0, box_transition_time)
	# A timer rather than the tween's signal: a killed tween never finishes.
	await get_tree().create_timer(box_transition_time).timeout


## Hides the box with [member box_transition], then calls [method _on_hidden].
func disappear() -> void:
	if not visible or _hiding:
		return
	_stop_box_tween()
	if not _animates_box():
		hide()
		_set_box_shown(1.0)
		_on_hidden()
		return
	_hiding = true
	_box_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_box_tween.tween_method(_set_box_shown, 1.0, 0.0, box_transition_time)
	_box_tween.finished.connect(func() -> void:
		_hiding = false
		hide()
		_set_box_shown(1.0)
		_on_hidden())


## Called once the box is hidden. Styles that keep text between lines
## clear it here.
func _on_hidden() -> void:
	pass


func _animates_box() -> bool:
	return box_transition != "none" and box_transition_time > 0.0 and not skipping and is_inside_tree()


## Fades and (for "slide") moves the box: 0 is hidden, 1 is in place.
func _set_box_shown(amount: float) -> void:
	modulate.a = amount
	position.y = SLIDE_DISTANCE * (1.0 - amount) if box_transition == "slide" else 0.0


func _stop_box_tween() -> void:
	if _box_tween != null and _box_tween.is_valid():
		_box_tween.kill()
	_box_tween = null


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
	_cancel_count += 1
	_cancelled = true
	_typing = false
	continue_pressed.emit()


## Types [param text] into [param label], stopping at pause tags, then waits
## for the player. Awaitable. [param indicator] is shown while waiting.
func reveal(label: RichTextLabel, text: String, indicator: CanvasItem = null) -> void:
	_cancelled = false
	_rushing = false
	_revealing = true
	if has_theme_color("code_color", "DialogueBox"):
		text = tint_code(text, get_theme_color("code_color", "DialogueBox"))
	var parsed := extract_tags(text)
	var start := label.get_parsed_text().length()
	if label.get_parsed_text().is_empty():
		label.text = parsed["text"]
	else:
		label.append_text(parsed["text"])
	var total := label.get_parsed_text().length()
	label.visible_characters = start
	_spans.clear()
	for span in parsed["spans"]:
		_spans.append({"from": start + span["from"], "to": start + span["to"], "factor": span["factor"]})
	var stops: Array = []
	for stop in parsed["stops"]:
		var moved: Dictionary = stop.duplicate()
		moved["at"] += start
		stops.append(moved)
	stops.append({"at": total, "kind": "pause", "seconds": -1.0})
	for stop in stops:
		if _cancelled:
			break
		await _reveal_to(label, stop["at"])
		if _cancelled:
			break
		if stop["kind"] == "tag":
			if on_text_tag.is_valid():
				await on_text_tag.call(stop["tag"], stop["value"])
		elif stop["seconds"] >= 0.0:
			if not skipping:
				await get_tree().create_timer(stop["seconds"]).timeout
			_rushing = false
		else:
			if indicator:
				indicator.visible = true
			await _wait_for_continue(total - start)
			if indicator:
				indicator.visible = false
			_rushing = false
	_revealing = false
	if _cancelled:
		return
	label.visible_characters = -1
	line_revealed.emit()


## Splits text at the tags this class handles. Returns a dictionary with:
## - [code]text[/code]: the BBCode without those tags;
## - [code]stops[/code]: points where typing stops, in visible characters:
##   [code]{"at", "kind": "pause", "seconds"}[/code] (seconds is -1 to wait
##   for the player) or [code]{"at", "kind": "tag", "tag", "value"}[/code]
##   for [code][act][/code] and [code][sound][/code];
## - [code]spans[/code]: [code]{"from", "to", "factor"}[/code] for
##   [code][speed][/code] (factor times the typing speed) and
##   [code][instant][/code] (factor 0). An unclosed span runs to the end.
static func extract_tags(text: String) -> Dictionary:
	var regex := RegEx.create_from_string("\\[(/?)(pause|speed|instant|act|sound)(?:=([^\\]]*))?\\]")
	var measure := RichTextLabel.new()
	measure.bbcode_enabled = true
	var stops: Array[Dictionary] = []
	var spans: Array[Dictionary] = []
	var open: Array[Dictionary] = []
	var clean := ""
	var last := 0
	for found in regex.search_all(text):
		clean += text.substr(last, found.get_start() - last)
		last = found.get_end()
		measure.text = clean
		var at := measure.get_parsed_text().length()
		var tag := found.get_string(2)
		var value := found.get_string(3)
		if found.get_string(1) == "/":
			for i in range(open.size() - 1, -1, -1):
				if open[i]["tag"] == tag:
					var closed: Dictionary = open.pop_at(i)
					spans.append({"from": closed["from"], "to": at, "factor": closed["factor"]})
					break
			continue
		match tag:
			"pause":
				var seconds := value.to_float() if value.is_valid_float() else -1.0
				stops.append({"at": at, "kind": "pause", "seconds": seconds})
			"speed":
				var factor := value.to_float() if value.is_valid_float() and value.to_float() > 0.0 else 1.0
				open.append({"tag": tag, "from": at, "factor": factor})
			"instant":
				open.append({"tag": tag, "from": at, "factor": 0.0})
			_:
				stops.append({"at": at, "kind": "tag", "tag": tag, "value": value})
	clean += text.substr(last)
	measure.text = clean
	var total := measure.get_parsed_text().length()
	for unclosed in open:
		spans.append({"from": unclosed["from"], "to": total, "factor": unclosed["factor"]})
	measure.free()
	return {"text": clean, "stops": stops, "spans": spans}


## Colors every [code][code][/code] span in [param text] with [param color].
## [method reveal] does this when the theme has a [code]code_color[/code]
## for the [code]DialogueBox[/code] type, as the default theme does.
static func tint_code(text: String, color: Color) -> String:
	var open := "[code][color=#%s]" % color.to_html(false)
	return text.replace("[code]", open).replace("[/code]", "[/color][/code]")


## The text a player reads in [param text], without BBCode or typing tags,
## for places that show plain text such as save slots.
static func plain_text(text: String) -> String:
	var measure := RichTextLabel.new()
	measure.bbcode_enabled = true
	measure.text = extract_tags(text)["text"]
	var plain := measure.get_parsed_text()
	measure.free()
	return plain


## Splits text at pause tags and removes the other typing tags. Returns
## {"text": bbcode without the tags, "pauses": [{"at": visible character
## index, "seconds": float or -1}]}.
static func extract_pauses(text: String) -> Dictionary:
	var parsed := extract_tags(text)
	var pauses: Array[Dictionary] = []
	for stop in parsed["stops"]:
		if stop["kind"] == "pause":
			pauses.append({"at": stop["at"], "seconds": stop["seconds"]})
	return {"text": parsed["text"], "pauses": pauses}


func _reveal_to(label: RichTextLabel, count: int) -> void:
	if skipping or characters_per_second <= 0.0 or _rushing:
		label.visible_characters = count
		return
	_typing = true
	var shown := float(maxi(label.visible_characters, 0))
	while _typing and shown < count:
		var factor := _speed_at(int(shown))
		if factor == 0.0:
			shown = float(mini(_instant_end(int(shown)), count))
			label.visible_characters = int(shown)
			continue
		await get_tree().process_frame
		shown += characters_per_second * factor * get_process_delta_time()
		label.visible_characters = mini(int(shown), count)
	label.visible_characters = count
	_typing = false


## Typing speed factor at label character [param index]: the product of
## the [speed] spans around it, or 0 inside an [instant] span.
func _speed_at(index: int) -> float:
	var factor := 1.0
	for span in _spans:
		if index >= span["from"] and index < span["to"]:
			if span["factor"] == 0.0:
				return 0.0
			factor *= span["factor"]
	return factor


## Where the [instant] spans around [param index] end.
func _instant_end(index: int) -> int:
	var end := index + 1
	for span in _spans:
		if span["factor"] == 0.0 and index >= span["from"] and index < span["to"]:
			end = maxi(end, span["to"])
	return end


## Resizes the style's text for [member text_scale]. Styles override it.
func _apply_text_scale() -> void:
	pass


func _wait_for_continue(length: int) -> void:
	if skipping:
		await get_tree().process_frame
		return
	_waiting = true
	if auto_advance:
		var timer := get_tree().create_timer(auto_delay + length * 0.03)
		# Auto mode holds while a menu is open or the box is hidden.
		while (timer.time_left > 0.0 or input_blocked.call()) and auto_advance and not skipping and not _cancelled:
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
	if _typing or (_revealing and not _waiting):
		# Show the rest of the text up to the next pause at once.
		_typing = false
		_rushing = true
	else:
		continue_pressed.emit()
