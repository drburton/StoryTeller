class_name RouteChartView
extends Control
## Draws a [RouteChart]: a panel per beat with its choices, lines between
## beats the player went between, and each tale's name above its band.
## Picked options have a filled dot; options seen but never picked have an
## empty one and dimmer text. Put it in a [ScrollContainer].

const MARGIN := 16.0
const PICKED_ALPHA := 1.0
const UNPICKED_ALPHA := 0.55

var chart: RouteChart
## Panel of each node in [member RouteChart.nodes], in the same order.
var panels: Array[PanelContainer] = []
## Name label of each band in [member RouteChart.bands].
var band_labels: Array[Label] = []


## Replaces what the view shows with [param new_chart].
func show_chart(new_chart: RouteChart) -> void:
	chart = new_chart
	panels.clear()
	band_labels.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for band in chart.bands:
		var label := Label.new()
		label.text = band["title"]
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.add_theme_font_size_override("font_size", 18)
		add_child(label)
		band_labels.append(label)
	for node in chart.nodes:
		var panel := _make_panel(node)
		add_child(panel)
		panels.append(panel)
	_arrange()


func _notification(what: int) -> void:
	# Sizes settle once the theme reaches the panels, so measure after that.
	if what == NOTIFICATION_THEME_CHANGED and chart != null:
		_arrange.call_deferred()


## Gives each node the height its panel needs with the current theme, lays
## the chart out again, and moves the panels and labels into place.
func _arrange() -> void:
	if is_inside_tree():
		var style := _card_style()
		for i in panels.size():
			panels[i].add_theme_stylebox_override("panel", style)
			chart.nodes[i]["size"].y = panels[i].get_combined_minimum_size().y
		chart.arrange()
	for i in band_labels.size():
		band_labels[i].position = Vector2(MARGIN, MARGIN + chart.bands[i]["top"])
	for i in panels.size():
		panels[i].position = Vector2(MARGIN, MARGIN) + chart.nodes[i]["position"]
		panels[i].size = chart.nodes[i]["size"]
	custom_minimum_size = chart.size + Vector2(MARGIN, MARGIN) * 2
	queue_redraw()


func _draw() -> void:
	if chart == null:
		return
	var color := get_theme_color("font_color", "Label")
	color.a = 0.5
	for link in chart.links:
		var points := link_points(chart.nodes[link["from"]], chart.nodes[link["to"]])
		draw_polyline(points, color, 2.0, true)
		draw_circle(points[points.size() - 1], 4.0, color)


## Points of the line from node [param from] to node [param to]. A beat to
## the right is joined side to side, at the height of the titles; any other
## beat, such as the first beat of the next tale, is joined from the bottom
## of one to the top of the other, so the line stays out of the text.
static func link_points(from: Dictionary, to: Dictionary) -> PackedVector2Array:
	var offset := Vector2(MARGIN, MARGIN)
	var from_rect := Rect2(offset + from["position"], from["size"])
	var to_rect := Rect2(offset + to["position"], to["size"])
	var title_y := RouteChart.PADDING + RouteChart.TITLE_HEIGHT * 0.5
	var curve := Curve2D.new()
	if to_rect.position.x >= from_rect.end.x:
		var start := Vector2(from_rect.end.x, from_rect.position.y + title_y)
		var end := Vector2(to_rect.position.x, to_rect.position.y + title_y)
		var bend := maxf((end.x - start.x) * 0.5, RouteChart.COLUMN_GAP * 0.5)
		curve.add_point(start, Vector2.ZERO, Vector2(bend, 0))
		curve.add_point(end, Vector2(-bend, 0), Vector2.ZERO)
	else:
		var below := to_rect.position.y >= from_rect.end.y
		var start := Vector2(from_rect.get_center().x, from_rect.end.y if below else from_rect.position.y)
		var end := Vector2(to_rect.get_center().x, to_rect.position.y if below else to_rect.end.y)
		var bend := maxf(absf(end.y - start.y) * 0.5, RouteChart.ROW_GAP) * (1.0 if below else -1.0)
		curve.add_point(start, Vector2.ZERO, Vector2(0, bend))
		curve.add_point(end, Vector2(0, -bend), Vector2.ZERO)
	return curve.tessellate()


func _make_panel(node: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node["id"].replace(".", "_")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _card_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var title := Label.new()
	title.text = node["title"]
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.custom_minimum_size = Vector2(0, RouteChart.TITLE_HEIGHT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)
	for options: Array in node["choices"]:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, RouteChart.CHOICE_GAP)
		column.add_child(gap)
		for option: Dictionary in options:
			column.add_child(_make_option(option))
	return panel


## A light card in the theme's text color, with the padding the layout
## assumed whatever the theme's own panels use.
func _card_style() -> StyleBoxFlat:
	var ink := get_theme_color("font_color", "Label")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ink, 0.07)
	style.border_color = Color(ink, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(RouteChart.PADDING)
	return style


func _make_option(option: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, RouteChart.OPTION_HEIGHT)
	row.modulate.a = PICKED_ALPHA if option["picked"] else UNPICKED_ALPHA
	var marker := OptionMarker.new()
	marker.picked = option["picked"]
	marker.custom_minimum_size = Vector2(16, RouteChart.OPTION_HEIGHT)
	row.add_child(marker)
	var label := Label.new()
	label.text = option["text"]
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 13)
	label.tooltip_text = option["text"]
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	return row


## The dot before an option: filled when the player has picked it.
class OptionMarker:
	extends Control

	var picked := false

	func _draw() -> void:
		var color := get_theme_color("font_color", "Label")
		var center := Vector2(6, size.y * 0.5)
		if picked:
			draw_circle(center, 4.0, color)
		else:
			draw_arc(center, 3.5, 0.0, TAU, 16, color, 1.5, true)
