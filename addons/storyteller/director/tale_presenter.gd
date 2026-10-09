class_name TalePresenter
extends Node
## Shows lines and choices to the player. The director awaits these methods.
##
## The built-in dialogue box implements this; projects can provide their own
## by extending it and setting [member TaleDirector.presenter].


## Shows one line and returns when the player continues. [param line] has:
## speaker_id, speaker_name, speaker_color, mood, text, id, voice, tale,
## beat, source_line.
func show_line(_line: Dictionary) -> void:
	pass


## Shows choices and returns the index of the chosen option, or -1 when the
## timeout expires. Each option has: text, id, enabled, and picture (the
## name from [code]@picture[/code], or ""). [param settings] has
## the choose arguments, such as style and timeout.
func choose(_options: Array[Dictionary], _settings: Dictionary) -> int:
	return 0
