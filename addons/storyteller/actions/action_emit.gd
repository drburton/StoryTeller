extends TaleAction
## emit(name, value = null): tells game code that something happened.
## Game code listens to [signal TaleDirector.story_signal].


func get_action_name() -> String:
	return "emit"


func run(ctx: TaleContext, signal_name: String, value: Variant = null) -> void:
	ctx.director.story_signal.emit(signal_name, value)
