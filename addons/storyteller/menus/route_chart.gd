class_name RouteChart
extends RefCounted
## The layout of the route chart: the beats a player has entered, arranged
## in one band per tale, with the choices they met in each beat and the
## ways they went between beats. Built from a [RouteLog]; beats, options,
## and tales the player has not reached are left out.
## [codeblock]
## var chart := RouteChart.build(director.routes, director)
## for node in chart.nodes:
##     print(node["title"], " at ", node["position"])
## [/codeblock]

const NODE_WIDTH := 240.0
const TITLE_HEIGHT := 30.0
const OPTION_HEIGHT := 22.0
## Space above each group of options from one choice.
const CHOICE_GAP := 8.0
const PADDING := 10.0
const COLUMN_GAP := 56.0
const ROW_GAP := 16.0
## Height of a tale's name above its band.
const BAND_TITLE_HEIGHT := 34.0
const BAND_GAP := 24.0

## One per beat entered, in the order the player first entered them:
## [code]{"id", "tale", "beat", "title", "choices", "position", "size"}[/code].
## [code]choices[/code] holds one array per choice met in the beat, each
## option a [code]{"text", "picked"}[/code] dictionary.
var nodes: Array[Dictionary] = []
## Ways the player went between beats: [code]{"from", "to"}[/code] indexes
## into [member nodes].
var links: Array[Dictionary] = []
## One per tale reached, top to bottom: [code]{"tale", "title", "top"}[/code].
var bands: Array[Dictionary] = []
## Size of the whole chart.
var size := Vector2.ZERO


## Lays out what [param route_log] recorded. [param director] supplies the tales,
## for beat headings, choices, and option text in the current language.
static func build(route_log: RouteLog, director: TaleDirector) -> RouteChart:
	var chart := RouteChart.new()
	var index_of := {}
	var tale_order: Array[String] = []
	for beat_id in route_log.beats:
		var tale_name := beat_id.get_slice(".", 0)
		var beat := beat_id.get_slice(".", 1)
		var tale := director.get_tale(tale_name)
		if tale == null or tale.get_beat_start(beat) < 0:
			continue
		if tale_name not in tale_order:
			tale_order.append(tale_name)
		index_of[beat_id] = chart.nodes.size()
		var heading: String = tale.headings.get(beat, "")
		var choices := _choices(route_log, director, tale, beat)
		var height := PADDING * 2 + TITLE_HEIGHT
		for options: Array in choices:
			height += CHOICE_GAP + OPTION_HEIGHT * options.size()
		chart.nodes.append({
			"id": beat_id, "tale": tale_name, "beat": beat,
			"title": tr_text(heading) if not heading.is_empty() else beat.capitalize(),
			"choices": choices, "position": Vector2.ZERO, "size": Vector2(NODE_WIDTH, height),
		})
	for pair in route_log.get_links():
		if index_of.has(pair[0]) and index_of.has(pair[1]):
			chart.links.append({"from": index_of[pair[0]], "to": index_of[pair[1]]})
	for tale_name in tale_order:
		var tale := director.get_tale(tale_name)
		chart.bands.append({
			"tale": tale_name,
			"title": tr_text(tale.title) if not tale.title.is_empty() else tale_name.capitalize(),
			"top": 0.0,
		})
	chart.arrange()
	return chart


## Places the nodes and bands for the current node sizes. [method build]
## estimates the sizes; call this again after changing them, as
## [RouteChartView] does once it knows how tall its panels really are.
func arrange() -> void:
	var top := 0.0
	var width := 0.0
	for band in bands:
		band["top"] = top
		var bottom := _place_band(band["tale"], top + BAND_TITLE_HEIGHT)
		for node in nodes:
			if node["tale"] == band["tale"]:
				width = maxf(width, node["position"].x + node["size"].x)
		top = bottom + BAND_GAP
	size = Vector2(width, maxf(top - BAND_GAP, 0.0))


## Index of the node for "tale.beat", or -1.
func find_node(beat_id: String) -> int:
	for i in nodes.size():
		if nodes[i]["id"] == beat_id:
			return i
	return -1


## Translates [param text] the way tale titles and names are translated:
## keyed by the text itself.
static func tr_text(text: String) -> String:
	return String(TranslationServer.translate(text))


## Places the nodes of one tale in columns by how many steps they are from
## where the player entered the tale, and returns the bottom of the band.
func _place_band(tale_name: String, top: float) -> float:
	var members: Array[int] = []
	for i in nodes.size():
		if nodes[i]["tale"] == tale_name:
			members.append(i)
	var incoming := {}
	var outgoing := {}
	for i in members:
		incoming[i] = []
		outgoing[i] = []
	for link in links:
		if incoming.has(link["to"]):
			incoming[link["to"]].append(link["from"])
		if outgoing.has(link["from"]) and incoming.has(link["to"]):
			outgoing[link["from"]].append(link["to"])
	# Entry points: beats reached from another tale or where play started.
	var pending: Array[int] = []
	for i in members:
		var from_outside: bool = incoming[i].is_empty() or incoming[i].any(func(from: int) -> bool: return not incoming.has(from))
		if from_outside:
			pending.append(i)
	if pending.is_empty():
		pending.append(members[0])
	var depth := {}
	for i in pending:
		depth[i] = 0
	while not pending.is_empty():
		var current: int = pending.pop_front()
		for next: int in outgoing[current]:
			if not depth.has(next):
				depth[next] = depth[current] + 1
				pending.append(next)
	var deepest := 0
	for i in members:
		deepest = maxi(deepest, depth.get(i, 0))
	# Beats only reached in ways the log does not show go after the rest.
	for i in members:
		if not depth.has(i):
			deepest += 1
			depth[i] = deepest
	var column_bottom := {}
	var bottom := top
	for i in members:
		var column: int = depth[i]
		var y: float = column_bottom.get(column, top)
		nodes[i]["position"] = Vector2(column * (NODE_WIDTH + COLUMN_GAP), y)
		column_bottom[column] = y + nodes[i]["size"].y + ROW_GAP
		bottom = maxf(bottom, y + nodes[i]["size"].y)
	return bottom


## The choices of [param beat] the player has met, in the order they appear
## in the tale, with the options they were shown.
static func _choices(route_log: RouteLog, director: TaleDirector, tale: Tale, beat: String) -> Array:
	var result := []
	for i in range(tale.get_beat_start(beat), tale.instructions.size()):
		var instruction: Dictionary = tale.instructions[i]
		if instruction["op"] == "end":
			break
		if instruction["op"] != "choose":
			continue
		var options := []
		for option in instruction["options"]:
			var state := route_log.get_option_state(tale.translation_key(option["id"]))
			if state != RouteLog.UNSEEN:
				options.append({"text": _option_text(director, tale, option["id"]), "picked": state == RouteLog.PICKED})
		if not options.is_empty():
			result.append(options)
	return result


## An option's text in the current language, without markup. Values that
## depend on the story, written as {...}, show as an ellipsis.
static func _option_text(director: TaleDirector, tale: Tale, id: String) -> String:
	var text: String = tale.texts.get(id, "")
	if not director.is_source_language():
		var key := tale.translation_key(id)
		var translated := String(TranslationServer.translate(key))
		if translated != key and not translated.is_empty():
			text = translated
	var values := RegEx.create_from_string("\\{[^}]*\\}")
	var tags := RegEx.create_from_string("\\[[^\\]]*\\]")
	return tags.sub(values.sub(text, "…", true), "", true).strip_edges()
