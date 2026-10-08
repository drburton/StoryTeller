class_name StoryRewind
extends StoryCrew
## Crew member that lets the player step back to earlier lines and choices.
##
## A snapshot of the whole story is kept each time a line or choice appears.
## Rewinding loads an earlier snapshot. Lines marked [code]@no_rewind[/code]
## clear the snapshots, so the player can't go back past them.

signal rewound

## Most snapshots kept.
var depth := 50

var _snapshots: Array[Dictionary] = []
var _rewinding := false


func get_crew_name() -> StringName:
	return &"Rewind"


func setup(config: StoryConfig) -> void:
	depth = config.rewind_depth
	_connect_director.call_deferred()


func clear() -> void:
	_snapshots.clear()


func can_rewind() -> bool:
	return _snapshots.size() >= 2 and _director() != null and _director().is_playing()


## Number of steps back that are possible.
func get_available_steps() -> int:
	return maxi(_snapshots.size() - 1, 0)


## Goes back [param steps] lines or choices. Returns false if not possible.
func rewind(steps := 1) -> bool:
	if steps < 1 or _snapshots.size() <= steps or _rewinding:
		return false
	var director := _director()
	if director == null:
		return false
	_rewinding = true
	for i in steps:
		_snapshots.pop_back()
	# The target is shown again, which takes a new snapshot of it.
	var target: Dictionary = _snapshots.pop_back()
	get_parent().restore(target)
	_rewinding = false
	rewound.emit()
	director.resume()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("story_rewind") and event.is_action_pressed("story_rewind") and can_rewind():
		rewind()
		get_viewport().set_input_as_handled()


func _snapshot(_payload: Variant = null) -> void:
	if _rewinding:
		return
	var state: Dictionary = get_parent().capture()
	# A round trip through JSON makes an independent copy.
	_snapshots.append(JSON.parse_string(JSON.stringify(state)))
	while _snapshots.size() > depth + 1:
		_snapshots.pop_front()


func _connect_director() -> void:
	var director := _director()
	if director == null:
		return
	director.line_started.connect(_snapshot)
	director.choice_started.connect(_snapshot)
	director.rewind_barrier.connect(clear)
	director.story_started.connect(func(_tale: String, _beat: String) -> void: clear())
	var saves: Node = get_parent().get_crew(&"Saves")
	if saves != null:
		saves.loaded.connect(func(_slot: String) -> void: clear())


func _director() -> TaleDirector:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		return story.get_crew(&"TaleDirector") as TaleDirector
	return null
