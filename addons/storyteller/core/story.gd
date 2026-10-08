extends Node
## Runtime entry point for StoryTeller, registered as the [code]Story[/code]
## autoload.
##
## Owns the crew members (runtime systems) and coordinates their lifecycle:
## creation from [StoryConfig], reset, state capture for saves and rewind, and
## shutdown.

## Emitted after [method start] has created every crew member.
signal crew_ready

## StoryTeller version. Kept in sync with [code]plugin.cfg[/code].
const VERSION := "0.1.0-dev"
## Project setting holding the path of the [StoryConfig] resource.
const CONFIG_SETTING := "storyteller/config_path"
## Version of the dictionary returned by [method capture].
const STATE_FORMAT := 1

## The active configuration. Set by [method start].
var config: StoryConfig
## True once [method start] has finished and crew members are available.
var is_ready := false

var _crew: Dictionary[StringName, StoryCrew] = {}


func _ready() -> void:
	if not is_ready:
		start(load_config())


## Loads the project's [StoryConfig], or returns defaults when none exists.
static func load_config() -> StoryConfig:
	var path: String = ProjectSettings.get_setting(CONFIG_SETTING, StoryConfig.DEFAULT_PATH)
	if ResourceLoader.exists(path):
		var loaded := load(path) as StoryConfig
		if loaded != null:
			return loaded
		push_warning("StoryTeller: '%s' is not a StoryConfig. Using defaults." % path)
	return StoryConfig.new()


## Creates every crew member listed in [param new_config]. Any crew from a
## previous start is shut down first.
func start(new_config: StoryConfig) -> void:
	shut_down()
	config = new_config
	for script in config.crew:
		var member := _instantiate_crew(script)
		if member != null:
			add_crew(member)
	is_ready = true
	crew_ready.emit()


## Adds a crew member created in code. Returns false if another member already
## uses the same name.
func add_crew(member: StoryCrew) -> bool:
	var key := member.get_crew_name()
	if key.is_empty():
		push_error("StoryTeller: crew member '%s' has no name. Give its script a class_name or override get_crew_name()." % member)
		member.free()
		return false
	if _crew.has(key):
		push_error("StoryTeller: duplicate crew member '%s'." % key)
		member.free()
		return false
	member.name = key
	_crew[key] = member
	add_child(member)
	member.setup(config)
	return true


## Returns the crew member registered under [param key], or null.
func get_crew(key: StringName) -> StoryCrew:
	return _crew.get(key)


func has_crew(key: StringName) -> bool:
	return _crew.has(key)


## Names of all crew members, in creation order.
func get_crew_names() -> Array[StringName]:
	var names: Array[StringName] = []
	names.assign(_crew.keys())
	return names


## Resets every crew member, for example when starting a new game.
func clear_all() -> void:
	for member in _crew.values():
		member.clear()


## Collects the state of every crew member for saves and rewind.
func capture() -> Dictionary:
	var crew_state := {}
	for key in _crew:
		crew_state[String(key)] = _crew[key].capture()
	return {"format": STATE_FORMAT, "crew": crew_state}


## Restores state produced by [method capture]. State for crew members that
## no longer exist is skipped with a warning.
func restore(state: Dictionary) -> void:
	var format := int(state.get("format", 0))
	if format != STATE_FORMAT:
		push_warning("StoryTeller: state format %d differs from %d." % [format, STATE_FORMAT])
	var crew_state: Dictionary = state.get("crew", {})
	for key in crew_state:
		var member := get_crew(StringName(key))
		if member == null:
			push_warning("StoryTeller: no crew member '%s' to restore." % key)
			continue
		member.restore(crew_state[key])


## Plays a tale with the director. Awaitable: returns when the story ends.
## [codeblock]
## await Story.play("prologue")
## [/codeblock]
func play(tale_name: String, beat := "start") -> void:
	var director := get_crew(&"TaleDirector") as TaleDirector
	if director == null:
		push_error("StoryTeller: no TaleDirector crew member. Check StoryConfig.crew.")
		return
	await director.play(tale_name, beat)


## Makes a game object available to tales under [param exposed_name],
## limited to the listed methods and properties.
## [codeblock]
## Story.expose("inventory", $Inventory, ["has", "add"], ["gold"])
## [/codeblock]
func expose(exposed_name: String, object: Object, methods: PackedStringArray = [], properties: PackedStringArray = []) -> void:
	var director := get_crew(&"TaleDirector") as TaleDirector
	if director != null:
		director.expose(exposed_name, object, methods, properties)


## Makes a function available to tales.
## [codeblock]
## Story.expose_function("day_of_week", func(): return calendar.weekday)
## [/codeblock]
func expose_function(function_name: String, callable: Callable) -> void:
	var director := get_crew(&"TaleDirector") as TaleDirector
	if director != null:
		director.expose_function(function_name, callable)


## Removes and frees every crew member.
func shut_down() -> void:
	for member in _crew.values():
		member.teardown()
		remove_child(member)
		member.free()
	_crew.clear()
	is_ready = false


func _instantiate_crew(script: Script) -> StoryCrew:
	if script == null:
		push_error("StoryTeller: empty entry in StoryConfig.crew.")
		return null
	var instance: Object = script.new()
	if instance is StoryCrew:
		return instance
	push_error("StoryTeller: '%s' does not extend StoryCrew." % script.resource_path)
	if instance is Node:
		instance.free()
	return null
