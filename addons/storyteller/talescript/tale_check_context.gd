class_name TaleCheckContext
extends RefCounted
## What the checker knows about the project around a tale: actions, cast
## members, objects exposed by game code, and other tales.
##
## The import plugin and the director build this from the project. Tests build
## it by hand.

## Names usable as values in every tale.
const BUILTIN_CONSTANTS: Array[String] = ["LEFT", "CENTER", "RIGHT", "PI", "TAU", "INF", "NAN"]
## Functions usable in every tale.
const BUILTIN_FUNCTIONS: Array[String] = [
	"abs", "ceil", "clamp", "collected", "float", "floor", "int", "len", "max",
	"min", "randf", "randf_range", "randi", "randi_range", "round", "str", "tr",
	"visited",
]
## Godot value types that can be constructed in tales.
const CONSTRUCTORS: Array[String] = ["Color", "Rect2", "Vector2", "Vector2i", "Vector3"]

## Name of the tale being checked, so it can refer to itself as
## [code]tale_name.beat[/code].
var tale_name := ""
## Actions by name. The value is a signature dictionary
## ([code]{"params": PackedStringArray, "required": int}[/code]) or null when
## the arguments should not be checked.
var actions: Dictionary = {}
## Cast member ids. The value is the list of known moods, or an empty list to
## accept any mood.
var cast: Dictionary = {}
## Field names of cast members ([member CastProfile.fields]), by id.
var cast_fields: Dictionary = {}
## Names of objects and functions exposed by game code.
var exposed: Dictionary = {}
## Other tales by name: [code]{"beats": PackedStringArray, "vars": PackedStringArray}[/code].
var tales: Dictionary = {}


## Registers an action. [param params] lists parameter names in order; the
## first [param required] of them must be given.
func add_action(action_name: String, params: PackedStringArray = [], required := 0) -> TaleCheckContext:
	actions[action_name] = {"params": params, "required": required}
	return self


## Registers an action whose arguments are not checked.
func add_action_unchecked(action_name: String) -> TaleCheckContext:
	actions[action_name] = null
	return self


func add_cast(id: String, moods: PackedStringArray = [], fields: PackedStringArray = []) -> TaleCheckContext:
	cast[id] = moods
	cast_fields[id] = fields
	return self


## Everything a tale can use after [code]<id>.[/code]: the cast member's
## methods and properties, then its fields.
func get_cast_members(id: String) -> PackedStringArray:
	var members := PackedStringArray(TaleCompletion.CAST_METHODS + TaleCompletion.CAST_PROPERTIES)
	members.append_array(cast_fields.get(id, PackedStringArray()))
	return members


func add_exposed(exposed_name: String) -> TaleCheckContext:
	exposed[exposed_name] = true
	return self


func add_tale(other_tale: String, beats: PackedStringArray, vars: PackedStringArray = []) -> TaleCheckContext:
	tales[other_tale] = {"beats": beats, "vars": vars}
	return self
