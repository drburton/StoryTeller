class_name DialogueBox
extends Control
## Base class for dialogue box styles. A style shows one line at a time and
## returns from [method show_line] when the player continues.
##
## Tags handled here before the text reaches the [RichTextLabel]:
## [code][pause][/code] waits for the player, [code][pause=0.5][/code] waits
## half a second. Everything else is passed on as BBCode.

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


## Shows [param line] (see [method TalePresenter.show_line]). Awaitable.
func show_line(_line: Dictionary) -> void:
	pass


## Hides the box between scenes.
func hide_box() -> void:
	hide()


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
