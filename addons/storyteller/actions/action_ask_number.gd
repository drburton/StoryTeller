extends TaleAction
## ask_number(prompt, default = 0, min = 0, max = 100): asks the player for a
## whole number. Use with await to get the answer.


func get_action_name() -> String:
	return "ask_number"


func run(ctx: TaleContext, prompt: String, default: int = 0, min: int = 0, max: int = 100) -> int:
	var menus := ctx.get_crew(&"Menus") as StoryMenus
	if menus == null:
		ctx.fail("ask_number() needs the Menus crew member.")
		return default
	var text := await menus.ask_text(prompt, str(default), 12)
	return clampi(text.to_int() if text.is_valid_int() else default, min, max)
