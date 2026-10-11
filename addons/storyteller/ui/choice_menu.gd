class_name ChoiceMenu
extends Control
## Base class for choice menu styles. [StoryDialogue] keeps one per style
## name and picks it from [code]choose(style = "...")[/code]: "list" and
## "pictures" are built in, and [member StoryConfig.choice_styles] adds or
## replaces styles.
##
## A style builds its buttons in [method choose], calls [method pick] when
## the player picks one, and returns [method wait_for_pick].

## Emitted by [method pick].
signal option_picked(index: int)


func _init() -> void:
	# Options arrive translated already.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


## Shows [param options] and returns the chosen index, or -1 on timeout.
## See [method TalePresenter.choose]. Each option may also have a
## [code]"picture"[/code] texture from [code]@picture[/code]. Awaitable.
func choose(_options: Array[Dictionary], _settings: Dictionary) -> int:
	return 0


## Closes the menu as if the timeout expired.
func cancel() -> void:
	if visible:
		option_picked.emit(-1)


## Ends the wait in [method wait_for_pick] with option [param index].
func pick(index: int) -> void:
	option_picked.emit(index)


## Shows the menu and waits until [method pick] or [method cancel] is
## called, or [param timeout] seconds pass (0 waits forever), then hides it.
## [param bar], if given, counts the time down. Returns the picked index,
## or -1 when time ran out. Awaitable.
func wait_for_pick(timeout: float, bar: ProgressBar = null) -> int:
	if bar != null:
		bar.max_value = timeout
		bar.value = timeout
	show()
	var result := {"index": -2}
	var on_pick := func(index: int) -> void: result["index"] = index
	option_picked.connect(on_pick)
	var remaining := timeout
	while result["index"] == -2:
		await get_tree().process_frame
		if timeout > 0.0:
			remaining -= get_process_delta_time()
			if bar != null:
				bar.value = remaining
			if remaining <= 0.0:
				result["index"] = -1
	option_picked.disconnect(on_pick)
	hide()
	return result["index"]


## A countdown bar for [code]choose(timeout = seconds)[/code], or null when
## [param settings] has no timeout.
static func make_timer_bar(settings: Dictionary) -> ProgressBar:
	if float(settings.get("timeout", 0.0)) <= 0.0:
		return null
	var bar := ProgressBar.new()
	bar.show_percentage = false
	return bar
