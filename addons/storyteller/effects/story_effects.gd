class_name StoryEffects
extends StoryCrew
## Crew member for whole-screen effects: weather, color filters, flashes,
## fading the screen to a color, and movies.
##
## Weather and filters sit just above the stage, so the dialogue box and
## menus are not affected. Flashes and screen fades cover the dialogue box
## too.
## [codeblock]
## weather("rain", strength = 0.6)
## filter("sepia")
## await fade_out(Color.BLACK)
## await fade_in()
## [/codeblock]

const WEATHER_LAYER := 4
const FILTER_LAYER := 5
## Above the dialogue box (10), below the menus (20).
const SCREEN_LAYER := 15
const WEATHER_KINDS := ["none", "rain", "snow"]
const FILTERS := ["none", "grayscale", "sepia", "night", "warm", "cold"]

## Folder with movies (Ogg Theora .ogv files), used by play_movie().
var movie_folder := "res://story/movies"
var weather_layer: CanvasLayer
var filter_layer: CanvasLayer
var screen_layer: CanvasLayer

var _weather: CPUParticles2D
var _weather_state := {"kind": "none", "strength": 1.0}
var _filter_rect: ColorRect
var _filter_material: ShaderMaterial
var _filter_state := {"name": "none", "strength": 1.0}
var _curtain: ColorRect
var _flash: ColorRect
var _tweens: Dictionary = {}
var _movie: Control
var _movie_skippable := false
var _movie_skip_requested := false


func get_crew_name() -> StringName:
	return &"Effects"


func setup(config: StoryConfig) -> void:
	movie_folder = config.movie_folder
	weather_layer = _make_layer("Weather", WEATHER_LAYER)
	filter_layer = _make_layer("Filter", FILTER_LAYER)
	screen_layer = _make_layer("ScreenEffects", SCREEN_LAYER)
	_filter_material = ShaderMaterial.new()
	_filter_material.shader = preload("res://addons/storyteller/effects/screen_filter.gdshader")
	# Set the uniforms so tweens start from a number.
	_filter_material.set_shader_parameter("mode", 0)
	_filter_material.set_shader_parameter("strength", 0.0)
	_filter_rect = _make_rect("Filter", filter_layer, Color.WHITE)
	_filter_rect.material = _filter_material
	_filter_rect.visible = false
	_curtain = _make_rect("Curtain", screen_layer, Color(0, 0, 0, 0))
	_flash = _make_rect("Flash", screen_layer, Color(1, 1, 1, 0))


func clear() -> void:
	stop_movie()
	set_weather("none", 1.0, 0.0)
	set_filter("none", 1.0, 0.0)
	_stop_tween("curtain")
	_stop_tween("flash")
	_curtain.color.a = 0.0
	_flash.color.a = 0.0


## Starts or stops weather: "rain", "snow", or "none". Awaitable. Returns an
## error message or "".
func set_weather(kind: String, strength := 1.0, fade := 1.0) -> String:
	if kind not in WEATHER_KINDS:
		return "Unknown weather '%s'. Kinds: %s." % [kind, ", ".join(WEATHER_KINDS)]
	_weather_state = {"kind": kind, "strength": strength}
	var old := _weather
	_weather = null
	if old != null:
		_fade_out_weather(old, fade)
	if kind == "none":
		return ""
	_weather = _make_weather(kind, clampf(strength, 0.05, 2.0))
	weather_layer.add_child(_weather)
	_weather.modulate.a = 0.0
	await _tween_property("weather", _weather, "modulate:a", 1.0, fade)
	return ""


## Recolors the stage: "grayscale", "sepia", "night", "warm", "cold", or
## "none". Awaitable. Returns an error message or "".
func set_filter(filter_name: String, strength := 1.0, time := 0.5) -> String:
	if filter_name not in FILTERS:
		return "Unknown filter '%s'. Filters: %s." % [filter_name, ", ".join(FILTERS)]
	var previous: String = _filter_state["name"]
	_filter_state = {"name": filter_name, "strength": strength}
	if previous != filter_name and previous != "none" and filter_name != "none":
		await _tween_property("filter", _filter_material, "shader_parameter/strength", 0.0, time * 0.5)
		time *= 0.5
	if filter_name != "none":
		_filter_material.set_shader_parameter("mode", FILTERS.find(filter_name))
		_filter_rect.visible = true
	var target := clampf(strength, 0.0, 1.0) if filter_name != "none" else 0.0
	await _tween_property("filter", _filter_material, "shader_parameter/strength", target, time)
	if _filter_state["name"] == "none":
		_filter_rect.visible = false
	return ""


## Fades the whole screen, dialogue box included, to [param color].
## Awaitable.
func fade_out(color := Color.BLACK, time := 0.5) -> void:
	var start := _curtain.color
	_curtain.color = Color(color, start.a if start.a > 0.0 else 0.0)
	await _tween_property("curtain", _curtain, "color:a", color.a, time)


## Fades the screen back in after [method fade_out]. Awaitable.
func fade_in(time := 0.5) -> void:
	await _tween_property("curtain", _curtain, "color:a", 0.0, time)


## Flashes the screen with [param color]. Awaitable.
func flash(color := Color.WHITE, time := 0.3) -> void:
	_flash.color = color
	await _tween_property("flash", _flash, "color:a", 0.0, time)


## Plays a movie from [member movie_folder] over everything but the menus.
## A click or the continue key skips it when [param skippable]. Awaitable.
## Returns an error message or "".
func play_movie(movie_name: String, skippable := true) -> String:
	var path := StoryAssets.find(movie_folder, movie_name, ["ogv"])
	if path.is_empty():
		return "Movie '%s' was not found in %s." % [movie_name, movie_folder]
	if _is_skipping() or not is_inside_tree():
		return ""
	stop_movie()
	var root := Control.new()
	root.name = "Movie"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(black)
	var player := VideoStreamPlayer.new()
	player.stream = load(path) as VideoStream
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(player)
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_movie_skip_requested = true)
	screen_layer.add_child(root)
	_movie = root
	_movie_skippable = skippable
	_movie_skip_requested = false
	var state := {"done": false}
	player.finished.connect(func() -> void: state["done"] = true)
	player.play()
	while not state["done"] and _movie == root:
		await get_tree().process_frame
		if (_movie_skippable and _movie_skip_requested) or _is_skipping():
			break
	if _movie == root:
		stop_movie()
	return ""


## Stops a movie started with [method play_movie].
func stop_movie() -> void:
	if _movie != null:
		_movie.queue_free()
		_movie = null


## True while a movie plays.
func is_playing_movie() -> bool:
	return _movie != null


## Skips the movie that is playing, if it can be skipped.
func skip_movie() -> void:
	if _movie != null and _movie_skippable:
		_movie_skip_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if _movie != null and event.is_action_pressed("story_continue"):
		skip_movie()
		get_viewport().set_input_as_handled()


func get_weather() -> String:
	return _weather_state["kind"]


func get_filter() -> String:
	return _filter_state["name"]


## True while the screen is faded out.
func is_faded_out() -> bool:
	return _curtain.color.a > 0.0


func capture() -> Dictionary:
	var curtain := _curtain.color
	return {
		"weather": _weather_state.duplicate(),
		"filter": _filter_state.duplicate(),
		"curtain": [curtain.r, curtain.g, curtain.b, curtain.a],
	}


func restore(data: Dictionary) -> void:
	stop_movie()
	_stop_tween("flash")
	_flash.color.a = 0.0
	var weather: Dictionary = data.get("weather", {})
	var kind: String = weather.get("kind", "none")
	if kind != _weather_state["kind"] or weather.get("strength", 1.0) != _weather_state["strength"]:
		set_weather(kind, weather.get("strength", 1.0), 0.0)
	var filter: Dictionary = data.get("filter", {})
	set_filter(filter.get("name", "none"), filter.get("strength", 1.0), 0.0)
	var curtain: Array = data.get("curtain", [0.0, 0.0, 0.0, 0.0])
	_stop_tween("curtain")
	_curtain.color = Color(curtain[0], curtain[1], curtain[2], curtain[3])


func _make_weather(kind: String, strength: float) -> CPUParticles2D:
	var size := _screen_size()
	var particles := CPUParticles2D.new()
	particles.name = "Weather"
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(size.x * 0.6, 4.0)
	particles.position = Vector2(size.x * 0.5, -20.0)
	particles.local_coords = false
	if kind == "rain":
		particles.amount = int(260 * strength)
		particles.lifetime = 0.9
		particles.direction = Vector2(-0.18, 1.0)
		particles.spread = 2.0
		particles.gravity = Vector2(0, 600)
		particles.initial_velocity_min = size.y * 0.9
		particles.initial_velocity_max = size.y * 1.2
		particles.texture = _streak_texture()
		particles.color = Color(0.8, 0.86, 1.0, 0.75)
		particles.rotation = 0.18
	else:
		particles.amount = int(160 * strength)
		particles.lifetime = 6.0
		particles.direction = Vector2(0.1, 1.0)
		particles.spread = 20.0
		particles.gravity = Vector2(0, 12)
		particles.initial_velocity_min = 40.0
		particles.initial_velocity_max = 90.0
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 5.0
		particles.color = Color(1, 1, 1, 0.85)
	particles.preprocess = particles.lifetime
	particles.emitting = true
	return particles


func _fade_out_weather(particles: CPUParticles2D, fade: float) -> void:
	if fade <= 0.0 or _is_skipping() or not particles.is_inside_tree():
		particles.queue_free()
		return
	particles.emitting = false
	var tween := particles.create_tween()
	tween.tween_property(particles, "modulate:a", 0.0, fade)
	tween.tween_callback(particles.queue_free)


static func _streak_texture() -> Texture2D:
	var image := Image.create(3, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		var alpha := float(y) / 21.0
		image.set_pixel(0, y, Color(1, 1, 1, alpha * 0.5))
		image.set_pixel(1, y, Color(1, 1, 1, alpha))
		image.set_pixel(2, y, Color(1, 1, 1, alpha * 0.5))
	return ImageTexture.create_from_image(image)


func _tween_property(key: String, object: Object, property: String, value: Variant, time: float) -> void:
	_stop_tween(key)
	if time <= 0.0 or _is_skipping() or not is_inside_tree():
		object.set_indexed(property, value)
		return
	var tween := create_tween()
	_tweens[key] = tween
	tween.tween_property(object, property, value, time)
	await tween.finished
	if _tweens.get(key) == tween:
		_tweens.erase(key)


func _stop_tween(key: String) -> void:
	var tween: Tween = _tweens.get(key)
	if tween != null and tween.is_valid():
		tween.kill()
		tween.finished.emit()
	_tweens.erase(key)


func _make_layer(layer_name: String, index: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = layer_name
	layer.layer = index
	add_child(layer)
	return layer


func _make_rect(rect_name: String, layer: CanvasLayer, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = rect_name
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	return rect


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1152, 648)


func _is_skipping() -> bool:
	var story := get_parent()
	if story != null and story.has_method("get_crew"):
		var director := story.get_crew(&"TaleDirector") as TaleDirector
		return director != null and director.skipping
	return false
