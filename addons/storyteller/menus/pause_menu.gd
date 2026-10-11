class_name PauseMenu
extends MenuScreen
## The in-game menu opened with Escape or a right click.


func _ready() -> void:
	add_dim(0.55)
	var column := add_center_panel(320)
	column.add_child(MenuScreen.make_title("Paused"))
	column.add_child(MenuScreen.make_button("Resume", func() -> void: menus.close_top()))
	column.add_child(MenuScreen.make_button("Save", func() -> void: menus.open("save")))
	column.add_child(MenuScreen.make_button("Load", func() -> void: menus.open("load")))
	column.add_child(MenuScreen.make_button("History", func() -> void: menus.open("history")))
	column.add_child(MenuScreen.make_button("Settings", func() -> void: menus.open("settings")))
	column.add_child(MenuScreen.make_button("Title Screen", _to_title))
	if menus.can_quit():
		column.add_child(MenuScreen.make_button("Quit", _quit))


func open() -> void:
	focus_first()


func _to_title() -> void:
	if await menus.confirm("Return to the title screen? Unsaved progress will be lost."):
		menus.show_title()


func _quit() -> void:
	if await menus.confirm("Quit the game? Unsaved progress will be lost."):
		menus.quit_game()
