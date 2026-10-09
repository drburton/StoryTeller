class_name RouteLog
extends RefCounted
## What the player has explored across every playthrough, for the route
## chart: the beats they entered, the ways they went from one beat to
## another, and the choice options they saw and picked. The director keeps
## one in [member TaleDirector.routes] and saves it with the global data.
## [codeblock]
## var routes := Story.get_crew(&"TaleDirector").routes
## routes.has_beat("prologue.honest")
## routes.get_option_state("prologue:start_2a9f") == RouteLog.PICKED
## [/codeblock]

## An option the player has never been shown.
const UNSEEN := 0
## An option the player was shown but has never picked.
const SEEN := 1
## An option the player has picked at least once.
const PICKED := 2

## "tale.beat" ids in the order the player first entered them.
var beats := PackedStringArray()

var _beat_set: Dictionary = {}
## "from>to" beat ids to true.
var _links: Dictionary = {}
## Option translation key ("tale:id") to SEEN or PICKED.
var _options: Dictionary = {}


## Records that the player entered [param beat_id], coming from
## [param from_id] ("" when play started there).
func enter(beat_id: String, from_id := "") -> void:
	if not _beat_set.has(beat_id):
		_beat_set[beat_id] = true
		beats.append(beat_id)
	if not from_id.is_empty() and from_id != beat_id:
		_links["%s>%s" % [from_id, beat_id]] = true


## Records that the option keyed [param key] was shown.
func see_option(key: String) -> void:
	if not _options.has(key):
		_options[key] = SEEN


## Records that the option keyed [param key] was picked.
func pick_option(key: String) -> void:
	_options[key] = PICKED


func has_beat(beat_id: String) -> bool:
	return _beat_set.has(beat_id)


## [constant UNSEEN], [constant SEEN], or [constant PICKED].
func get_option_state(key: String) -> int:
	return _options.get(key, UNSEEN)


## Links between beats as [code][from_id, to_id][/code] pairs, in the order
## they were first taken.
func get_links() -> Array:
	var result := []
	for key: String in _links:
		result.append(Array(key.split(">")))
	return result


func is_empty() -> bool:
	return beats.is_empty()


func clear() -> void:
	beats.clear()
	_beat_set.clear()
	_links.clear()
	_options.clear()


func to_dict() -> Dictionary:
	var seen := []
	var picked := []
	for key: String in _options:
		(picked if _options[key] == PICKED else seen).append(key)
	return {"beats": Array(beats), "links": _links.keys(), "seen": seen, "picked": picked}


func from_dict(data: Dictionary) -> void:
	clear()
	for beat_id in data.get("beats", []):
		enter(str(beat_id))
	for link in data.get("links", []):
		_links[str(link)] = true
	for key in data.get("seen", []):
		see_option(str(key))
	for key in data.get("picked", []):
		pick_option(str(key))
