extends TaleAction
## wait(seconds): pauses for a number of seconds. Use with await to hold the
## tale, or without it to delay the next dialogue line.


func get_action_name() -> String:
	return "wait"


func run(ctx: TaleContext, seconds: float) -> void:
	await ctx.wait(seconds)
