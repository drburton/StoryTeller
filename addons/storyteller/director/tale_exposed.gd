class_name TaleExposed
extends RefCounted
## An object from game code that tales may use, limited to the listed
## methods and properties. Created by [method TaleDirector.expose].

var target: Object
var methods: PackedStringArray
var properties: PackedStringArray


func _init(p_target: Object, p_methods: PackedStringArray, p_properties: PackedStringArray) -> void:
	target = p_target
	methods = p_methods
	properties = p_properties
