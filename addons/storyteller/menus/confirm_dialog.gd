class_name ConfirmDialog
extends MenuScreen
## Asks a yes or no question. Used through [method StoryMenus.confirm].

signal answered(yes: bool)

var message := ""
var _label: Label


func _ready() -> void:
	add_dim(0.5)
	var column := add_center_panel(420)
	_label = MenuScreen.make_title("", 20)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.add_child(MenuScreen.make_button("Yes", func() -> void: answered.emit(true)))
	buttons.add_child(MenuScreen.make_button("No", func() -> void: answered.emit(false)))
	column.add_child(buttons)


func open() -> void:
	_label.text = message
	focus_first()


func on_back() -> bool:
	answered.emit(false)
	return false
