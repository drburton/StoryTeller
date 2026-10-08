extends TaleAction
## ask_text(prompt, default = "", max_length = 24): asks the player to type
## something. Use with await to get the answer:
## [codeblock]
## player_name = await ask_text("What's your name?", "Sam")
## [/codeblock]


func get_action_name() -> String:
	return "ask_text"


func run(ctx: TaleContext, prompt: String, default: String = "", max_length: int = 24) -> String:
	var menus := ctx.get_crew(&"Menus") as StoryMenus
	if menus == null:
		ctx.fail("ask_text() needs the Menus crew member.")
		return default
	return await menus.ask_text(prompt, default, max_length)
