extends TaleAction
## hide_prop(name, time = 0.3): removes a prop.


func get_action_name() -> String:
	return "hide_prop"


func run(ctx: TaleContext, name: String, time: float = 0.3) -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage != null:
		await stage.hide_prop(name, time)
