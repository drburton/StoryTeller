class_name TextInputDialog
extends MenuScreen
## Asks the player to type something, such as their name. Used through
## [method StoryMenus.ask_text].

signal submitted(text: String)

var prompt := ""
var default_text := ""
var max_length := 24
var _label: Label
var _edit: LineEdit


func _ready() -> void:
	add_dim(0.5)
	var column := add_center_panel(420)
	_label = MenuScreen.make_title("", 20)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_label)
	_edit = LineEdit.new()
	_edit.custom_minimum_size = Vector2(0, 40)
	_edit.text_submitted.connect(func(_text: String) -> void: _submit())
	column.add_child(_edit)
	column.add_child(MenuScreen.make_button("OK", _submit))


func open() -> void:
	_label.text = prompt
	_edit.max_length = max_length
	_edit.text = default_text
	_edit.grab_focus()
	_edit.select_all()


func on_back() -> bool:
	return false


func _submit() -> void:
	var text := _edit.text.strip_edges()
	submitted.emit(text if not text.is_empty() else default_text)
