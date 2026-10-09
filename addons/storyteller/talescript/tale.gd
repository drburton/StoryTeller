@tool
class_name Tale
extends Resource
## A compiled tale, ready for the director to run.
##
## Created by [TaleCompiler], usually through the import plugin when a
## [code].tale[/code] file is saved. Instructions and expressions are stored as
## plain arrays and dictionaries so the resource serializes cleanly.
##
## [b]Instructions[/b] are dictionaries with an [code]"op"[/code] key and a
## [code]"line"[/code] key (source line). Ops:
## [codeblock]
## say          speaker, mood, text, id, voice      Show dialogue or narration.
## eval         expr                                Evaluate an expression (usually a call).
## set          place, assign, value                Assignment (assign is "=", "+=", ...).
## local        name, value                         Declare a temporary variable.
## jump         tale, beat                          Go to a beat ("" tale = this tale).
## call_beat    tale, beat                          Run a beat, then come back.
## return                                           Leave the current beat.
## goto         target                              Continue at instruction index.
## branch_false cond, target                        Go to target when cond is false.
## iter_begin   slot, iterable                      Start a for loop.
## iter_next    slot, var, target                   Next loop value, or go to target when done.
## match        subject, branches, end              Pick a branch: {patterns, guard, target}.
## choose       args, options, timeout_target, end  Show a choice menu. Options:
##              {text, cond, once, show_disabled, picture, id, target, line}.
## end                                              End of a beat.
## [/codeblock]
## Any instruction may carry [code]"no_rewind": true[/code]. Say instructions in
## [code]@skip_safe[/code] beats carry [code]"skip_safe": true[/code].
##
## [b]Expressions[/b] are arrays whose first element names the kind:
## [codeblock]
## ["lit", value]        ["name", name]          ["un", op, x]
## ["bin", op, a, b]     ["if", cond, a, b]      ["await", x]
## ["call", callee, args, named]                 ["attr", object, name]
## ["idx", object, index]                        ["arr", items]
## ["dict", [key, value, key, value, ...]]
## [/codeblock]
## [b]Text[/b] (dialogue, narration, options) is an array of parts: Strings for
## literal text and expression arrays for interpolated values.

## Version of the compiled format. Changes when the layout above changes.
const FORMAT := 4

@export var format := FORMAT
## The tale's name: its file name without extension.
@export var tale_name := ""
## Display title from [code]@title[/code], or "".
@export var title := ""
## Path of the source file.
@export var source_path := ""
## Story and global variables: [code]{name, global, const, value, line}[/code],
## where value is an expression array or null.
@export var variables: Array[Dictionary] = []
## Beat name to index of its first instruction.
@export var beats: Dictionary = {}
## Beat name to its display heading from [code]@heading[/code], shown in
## the route chart. Beats without one show their name there.
@export var headings: Dictionary = {}
@export var instructions: Array[Dictionary] = []
## Source text of every line and choice option, by id. Used to export
## strings for translation.
@export var texts: Dictionary = {}


## Translation key of the line or option with [param id].
func translation_key(id: String) -> String:
	return "%s:%s" % [tale_name, id]


## Index of the first instruction of [param beat_name], or -1.
func get_beat_start(beat_name: String) -> int:
	return beats.get(beat_name, -1)
