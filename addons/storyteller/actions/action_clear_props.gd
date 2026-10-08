extends TaleAction
## clear_props(time = 0.3): removes every prop.


func get_action_name() -> String:
	return "clear_props"


func run(ctx: TaleContext, time: float = 0.3) -> void:
	var stage := ctx.get_crew(&"Stage") as StoryStage
	if stage != null:
		await stage.clear_props(time)
