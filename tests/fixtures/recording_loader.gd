extends StoryCrew
## Crew member for tests that records preload requests.

var requests: Array[String] = []


func get_crew_name() -> StringName:
	return &"Recorder"


func preload_asset(kind: String, asset_name: String) -> void:
	requests.append("%s:%s" % [kind, asset_name])
