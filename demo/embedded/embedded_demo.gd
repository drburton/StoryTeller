extends Node3D
## StoryTeller inside a small 3D scene. Walk with WASD or the arrow keys and
## press E near the gatekeeper to talk. The conversation uses the
## dialogue-only crew, so the 3D view stays visible behind the dialogue box.
##
## Shows three ways game code and tales work together:
## - Story.expose() gives the tale the gate's "open" method and "is_open".
## - emit() in the tale reaches game code through TaleDirector.story_signal.
## - Story.play() is awaited, so the game knows when the talk is over.

const SPEED := 4.0
const TALK_DISTANCE := 2.2

var _player: CharacterBody3D
var _npc: Node3D
var _prompt: Label3D
var _gate: Gate
var _talking := false


## The gate the tale can open. Only "open" and "is_open" are exposed.
class Gate extends Node3D:
	var is_open := false

	func open() -> void:
		if is_open:
			return
		is_open = true
		var tween := create_tween()
		tween.tween_property(self, "position:y", -2.2, 1.0).set_trans(Tween.TRANS_SINE)
		await tween.finished


func _ready() -> void:
	_build_world()
	var config := StoryConfig.dialogue_only()
	config.tales_folder = "res://demo/embedded/tales"
	config.text_speed = 50.0
	Story.start(config)
	Story.expose("gate", _gate, ["open"], ["is_open"])
	var director := Story.get_crew(&"TaleDirector") as TaleDirector
	director.story_signal.connect(func(signal_name: String, _value: Variant) -> void:
		if signal_name == "rook_impressed":
			_prompt.text = "Rook looks impressed.")


func _physics_process(_delta: float) -> void:
	var near := _player.global_position.distance_to(_npc.global_position) < TALK_DISTANCE
	_prompt.visible = near and not _talking
	if _talking:
		_player.velocity = Vector3.ZERO
		return
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	_player.velocity = Vector3(input.x, 0, input.y).normalized() * SPEED
	_player.move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if not _talking and _prompt.visible:
			talk()


## Plays the gatekeeper conversation. Awaitable.
func talk() -> void:
	_talking = true
	await Story.play("gatekeeper")
	_talking = false


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.55, 0.7, 0.85)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	_add_box(Vector3(0, -0.25, 0), Vector3(20, 0.5, 20), Color(0.42, 0.6, 0.35), true)
	_add_box(Vector3(-4.5, 1.5, -4), Vector3(7, 3, 0.6), Color(0.6, 0.55, 0.5), true)
	_add_box(Vector3(4.5, 1.5, -4), Vector3(7, 3, 0.6), Color(0.6, 0.55, 0.5), true)
	_add_box(Vector3(0, 1.5, -9), Vector3(2, 0.1, 2), Color(0.85, 0.4, 0.5), false)

	_gate = Gate.new()
	_gate.name = "Gate"
	_gate.position = Vector3(0, 1.1, -4)
	add_child(_gate)
	var bars := _add_box(Vector3.ZERO, Vector3(2, 2.2, 0.3), Color(0.35, 0.3, 0.28), true)
	bars.reparent(_gate, false)

	_npc = Node3D.new()
	_npc.position = Vector3(1.6, 0, -3.2)
	add_child(_npc)
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	body.position.y = 1.0
	body.material_override = _material(Color(0.85, 0.65, 0.25))
	_npc.add_child(body)
	_prompt = Label3D.new()
	_prompt.text = "Press E to talk"
	_prompt.position.y = 2.4
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 48
	_prompt.pixel_size = 0.008
	_prompt.outline_size = 12
	_npc.add_child(_prompt)

	_player = CharacterBody3D.new()
	_player.position = Vector3(0, 0, 3)
	add_child(_player)
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	_player.add_child(shape)
	var player_mesh := MeshInstance3D.new()
	player_mesh.mesh = CapsuleMesh.new()
	player_mesh.position.y = 1.0
	player_mesh.material_override = _material(Color(0.3, 0.45, 0.85))
	_player.add_child(player_mesh)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 3.4, 5)
	camera.rotation_degrees = Vector3(-24, 0, 0)
	_player.add_child(camera)


func _add_box(at: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = at
	add_child(root)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	root.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		root.add_child(shape)
	return root


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
