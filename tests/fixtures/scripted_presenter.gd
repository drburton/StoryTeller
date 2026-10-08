extends TalePresenter
## Presenter for tests: records lines and choices and picks options from a
## queue instead of waiting for a player.

## Lines shown, as "Speaker: text" or just "text" for narration.
var lines: Array[String] = []
## Full line dictionaries, in order.
var line_data: Array[Dictionary] = []
## Options offered at each choice, as text. Disabled options are in brackets.
var offered: Array = []
## Settings passed to each choice.
var settings: Array = []
## Picks to make: an option text or an index. -1 simulates a timeout.
var picks: Array = []
## Called with each line before it is recorded, if set.
var on_line: Callable


func show_line(line: Dictionary) -> void:
	if on_line.is_valid():
		on_line.call(line)
	line_data.append(line)
	lines.append(("%s: %s" % [line["speaker_name"], line["text"]]) if line["speaker_name"] else line["text"])
	await get_tree().process_frame


func choose(options: Array[Dictionary], choice_settings: Dictionary) -> int:
	var texts: Array[String] = []
	for option in options:
		texts.append(option["text"] if option["enabled"] else "[%s]" % option["text"])
	offered.append(texts)
	settings.append(choice_settings)
	await get_tree().process_frame
	if picks.is_empty():
		return 0
	var pick: Variant = picks.pop_front()
	return texts.find(pick) if pick is String else pick
