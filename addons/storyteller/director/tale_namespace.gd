class_name TaleNamespace
extends RefCounted
## Stands for another tale in expressions, as in [code]chapter_1.met_jonas[/code].

var tale_name: String


func _init(p_tale_name: String) -> void:
	tale_name = p_tale_name
