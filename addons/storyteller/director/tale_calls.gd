class_name TaleCalls
extends RefCounted
## Matches positional and named arguments from a tale to a GDScript method's
## parameters, filling in default values.


## Returns {"values": Array, "error": String}. [param skip] leading
## parameters are not part of the tale-facing signature (for example the
## context parameter of actions). [param label] names the callee in errors.
static func bind(target: Object, method: String, args: Array, named: Dictionary, skip := 0, label := "") -> Dictionary:
	var info := find_method(target, method)
	if info.is_empty():
		return {"values": [], "error": "'%s' can't be called." % (label if label else method)}
	if label.is_empty():
		label = method
	var params := PackedStringArray()
	var all_args: Array = info.get("args", [])
	for i in range(skip, all_args.size()):
		params.append(all_args[i]["name"])
	var defaults: Array = info.get("default_args", [])
	var first_default := params.size() - defaults.size()
	if args.size() > params.size():
		return {"values": [], "error": "'%s' takes at most %d arguments." % [label, params.size()]}
	for key in named:
		var index := params.find(key)
		if index == -1:
			return {"values": [], "error": "'%s' has no argument named '%s'." % [label, key]}
		if index < args.size():
			return {"values": [], "error": "Argument '%s' is already given by position." % key}
	var values: Array = args.duplicate()
	for i in range(args.size(), params.size()):
		if named.has(params[i]):
			values.append(named[params[i]])
		elif i >= first_default:
			values.append(defaults[i - first_default])
		else:
			return {"values": [], "error": "'%s' needs the argument '%s'." % [label, params[i]]}
	return {"values": values, "error": ""}


## Parameter names of [param method] after [param skip], and how many are required.
static func signature(target: Object, method: String, skip := 0) -> Dictionary:
	var info := find_method(target, method)
	var params := PackedStringArray()
	var all_args: Array = info.get("args", [])
	for i in range(skip, all_args.size()):
		params.append(all_args[i]["name"])
	var defaults: Array = info.get("default_args", [])
	return {"params": params, "required": params.size() - defaults.size()}


## Parameters of [param method] in [param script], after skipping the first
## [param skip]: a list of [code]{"name", "type", "default", "required"}[/code],
## where type is a [enum Variant.Type] ([constant TYPE_NIL] for untyped).
## Used by the visual editor to build forms.
static func parameters(script: Script, method: String, skip := 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var info := {}
	while script != null and info.is_empty():
		for entry in script.get_script_method_list():
			if entry["name"] == method:
				info = entry
				break
		script = script.get_base_script()
	var all_args: Array = info.get("args", [])
	var defaults: Array = info.get("default_args", [])
	var first_default := all_args.size() - defaults.size()
	for i in range(skip, all_args.size()):
		var has_default := i >= first_default
		result.append({
			"name": all_args[i]["name"],
			"type": all_args[i]["type"],
			"default": defaults[i - first_default] if has_default else null,
			"required": not has_default,
		})
	return result


static func find_method(target: Object, method: String) -> Dictionary:
	var script := target.get_script() as Script
	while script != null:
		for entry in script.get_script_method_list():
			if entry["name"] == method:
				return entry
		script = script.get_base_script()
	return {}
