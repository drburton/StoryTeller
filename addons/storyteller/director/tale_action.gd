class_name TaleAction
extends RefCounted
## Base class for actions that tales can call, such as [code]wait(1.0)[/code].
##
## Subclasses override [method get_action_name] and define a [code]run[/code]
## method. The first parameter of [code]run[/code] is always the
## [TaleContext]; the rest become the action's arguments, with their names and
## defaults read from the method signature:
## [codeblock]
## extends TaleAction
##
## func get_action_name() -> String:
##     return "flash"
##
## func run(ctx: TaleContext, color: Color = Color.WHITE, time: float = 0.2) -> void:
##     await ctx.wait(time)
## [/codeblock]
## Tales then call [code]flash()[/code], [code]flash(Color.RED)[/code], or
## [code]flash(time = 0.5)[/code].


## Name used in tales. Must be overridden.
func get_action_name() -> String:
	return ""


## Parameter names of [code]run[/code] after the context, in order.
func get_parameters() -> PackedStringArray:
	return TaleCalls.signature(self, "run", 1)["params"]


## Number of parameters that must be given.
func get_required_count() -> int:
	return TaleCalls.signature(self, "run", 1)["required"]
