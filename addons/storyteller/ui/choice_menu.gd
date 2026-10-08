class_name ChoiceMenu
extends Control
## Base class for choice menu styles.


func _init() -> void:
	# Options arrive translated already.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


## Shows [param options] and returns the chosen index, or -1 on timeout.
## See [method TalePresenter.choose]. Awaitable.
func choose(_options: Array[Dictionary], _settings: Dictionary) -> int:
	return 0
