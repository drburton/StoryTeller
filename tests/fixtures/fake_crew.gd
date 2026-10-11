extends StoryCrew
## Crew member used by tests. Records every lifecycle call.

var setup_config: StoryConfig
var setup_count := 0
var clear_count := 0
var teardown_count := 0
var value := 0
## Shared log that outlives this node, so tests can see teardown calls.
var events: Array = []


func get_crew_name() -> StringName:
	return &"Fake"


func setup(config: StoryConfig) -> void:
	setup_config = config
	setup_count += 1


func clear() -> void:
	clear_count += 1
	value = 0


func capture() -> Dictionary:
	return {"value": value}


func restore(data: Dictionary) -> void:
	value = int(data.get("value", 0))


func teardown() -> void:
	teardown_count += 1
	events.append("teardown")
