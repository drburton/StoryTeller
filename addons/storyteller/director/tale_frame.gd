class_name TaleFrame
extends RefCounted
## One entry of the director's call stack: a running beat.

var tale: Tale
var beat := ""
## Index of the next instruction to run.
var pc := 0
## Temporary variables of the beat.
var locals: Dictionary = {}
## State of running for loops: slot -> {"items": Array, "index": int}.
var iterators: Dictionary = {}


func _init(p_tale: Tale, p_beat: String) -> void:
	tale = p_tale
	beat = p_beat
	pc = p_tale.get_beat_start(p_beat)
