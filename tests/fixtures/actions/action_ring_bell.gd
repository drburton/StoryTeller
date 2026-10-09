extends TaleAction
## ring_bell(times = 1): a custom action for tests.


func get_action_name() -> String:
	return "ring_bell"


func run(ctx: TaleContext, times: int = 1) -> void:
	ctx.director.story_signal.emit("bell", times)
