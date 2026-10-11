@tool
class_name StorySetupDialog
extends ConfirmationDialog
## The setup wizard: asks for a game title, a folder, and languages, then
## runs [StorySetup] and points the project at the new [StoryConfig].

## Emitted after setup runs, with the result of [method StorySetup.run].
signal setup_finished(result: Dictionary)

var title_field: LineEdit
var root_field: LineEdit
var language_field: LineEdit
var languages_field: LineEdit
var sample_check: CheckBox
var scene_check: CheckBox


func _init() -> void:
	title = "Set Up StoryTeller"
	ok_button_text = "Set Up"
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 12)
	add_child(form)
	title_field = _field(form, "Game title", "My Story", "")
	root_field = _field(form, "Story folder", "res://story", StorySetup.DEFAULTS["root"])
	language_field = _field(form, "Written in", "en", StorySetup.DEFAULTS["source_language"])
	languages_field = _field(form, "Translate into", "es, fr (optional)", "")
	sample_check = _check(form, "Write a first tale to start from")
	scene_check = _check(form, "Make a main scene that opens the title screen")
	confirmed.connect(_run)


## Runs the setup with the dialog's values. Returns the result.
func run_setup() -> Dictionary:
	var languages := PackedStringArray()
	for language in languages_field.text.split(",", false):
		if not language.strip_edges().is_empty():
			languages.append(language.strip_edges())
	return StorySetup.run({
		"root": root_field.text.strip_edges() if not root_field.text.strip_edges().is_empty() else StorySetup.DEFAULTS["root"],
		"game_title": title_field.text.strip_edges(),
		"source_language": language_field.text.strip_edges() if not language_field.text.strip_edges().is_empty() else "en",
		"languages": languages,
		"sample_tale": sample_check.button_pressed,
		"starter_scene": scene_check.button_pressed,
	})


func _run() -> void:
	var result := run_setup()
	if result["errors"].is_empty():
		StorySetup.register(result["config_path"], result["scene_path"])
	for error in result["errors"]:
		push_warning("StoryTeller setup: " + error)
	setup_finished.emit(result)


func _field(form: GridContainer, label_text: String, placeholder: String, value: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	form.add_child(label)
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.text = value
	field.custom_minimum_size = Vector2(280, 0)
	form.add_child(field)
	return field


func _check(form: GridContainer, text: String) -> CheckBox:
	form.add_child(Control.new())
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = true
	form.add_child(check)
	return check
