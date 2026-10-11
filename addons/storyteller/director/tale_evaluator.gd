class_name TaleEvaluator
extends RefCounted
## Evaluates compiled expressions (see [Tale]) for the director.
##
## Only safe things are reachable: tale variables, built-in values and
## functions, actions, and objects that game code exposed with
## [method TaleDirector.expose]. Mistakes such as adding text to a number set
## [member error] and return null; they never crash the game.

## Message of the first error since [method reset], or "".
var error := ""

var _director: TaleDirector
var _expressions: Dictionary = {}


func _init(director: TaleDirector) -> void:
	_director = director


func reset() -> void:
	error = ""


func failed() -> bool:
	return not error.is_empty()


## Evaluates [param expr] in [param frame]. Awaitable.
func evaluate(expr: Array, frame: TaleFrame) -> Variant:
	if failed():
		return null
	match expr[0]:
		"lit":
			return expr[1]
		"name":
			var found: Array = _director.resolve_name(expr[1], frame)
			if not found[0]:
				fail("Unknown name '%s'." % expr[1])
			return found[1]
		"un":
			var operand: Variant = await evaluate(expr[2], frame)
			return _unary(expr[1], operand)
		"bin":
			return await _binary_expr(expr, frame)
		"if":
			var condition: Variant = await evaluate(expr[1], frame)
			return await evaluate(expr[2] if condition else expr[3], frame)
		"await":
			var value: Variant = await evaluate(expr[1], frame)
			if value is TaleTask:
				return await value.wait()
			if value is Signal:
				return await value
			return value
		"call":
			return await _call(expr, frame)
		"attr":
			var base: Array = expr[1]
			if base[0] == "name" and base[1] in TaleCheckContext.CONSTRUCTORS and not _director.resolve_name(base[1], frame)[0]:
				return _type_constant(base[1], expr[2])
			var object: Variant = await evaluate(expr[1], frame)
			return get_member(object, expr[2])
		"idx":
			var container: Variant = await evaluate(expr[1], frame)
			var key: Variant = await evaluate(expr[2], frame)
			return _run_expression("v[k]", ["v", "k"], [container, key], "Can't read index %s." % str(key)) \
				if not container is Object else _object_error(container)
		"arr":
			var items: Array = []
			for item in expr[1]:
				items.append(await evaluate(item, frame))
			return items
		"dict":
			var dictionary := {}
			var entries: Array = expr[1]
			for i in range(0, entries.size(), 2):
				var key: Variant = await evaluate(entries[i], frame)
				dictionary[key] = await evaluate(entries[i + 1], frame)
			return dictionary
	fail("Unknown expression '%s'." % expr[0])
	return null


## Stores [param value] into [param place] (a "name", "attr", or "idx"
## expression). For compound operators such as "+=", combines first. Awaitable.
func assign(place: Array, op: String, value: Variant, frame: TaleFrame) -> void:
	if op != "=":
		var current: Variant = await evaluate(place, frame)
		if failed():
			return
		value = binary(op.trim_suffix("="), current, value)
	if not failed():
		await _store(place, value, frame)


## Applies a binary operator with GDScript semantics.
func binary(op: String, a: Variant, b: Variant) -> Variant:
	match op:
		"==":
			return values_equal(a, b)
		"!=":
			return not values_equal(a, b)
		"in":
			return _contains(b, a)
		"not in":
			return not _contains(b, a)
	return _run_expression("a %s b" % op, ["a", "b"], [a, b],
		"Can't use '%s' with %s and %s." % [op, type_string(typeof(a)), type_string(typeof(b))])


## Equality that never fails on mismatched types. Numbers compare by value.
static func values_equal(a: Variant, b: Variant) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numbers and typeof(b) in numbers:
		return a == b
	var texts := [TYPE_STRING, TYPE_STRING_NAME]
	if typeof(a) in texts and typeof(b) in texts:
		return String(a) == String(b)
	if typeof(a) != typeof(b):
		return false
	return a == b


## Reads [param member_name] from [param object] within the sandbox.
func get_member(object: Variant, member_name: String) -> Variant:
	if failed():
		return null
	if object is TaleNamespace:
		var found: Array = _director.get_tale_var(object.tale_name, member_name)
		if not found[0]:
			fail("Tale '%s' has no variable '%s'." % [object.tale_name, member_name])
		return found[1]
	if object is TaleExposed:
		if member_name in object.properties:
			return object.target.get(member_name)
		fail("'%s' is not available to tales." % member_name)
		return null
	if _is_scriptable(object):
		if member_name in object.get_tale_api().get("properties", []):
			return object.get(member_name)
		fail("'%s' is not available to tales." % member_name)
		return null
	if object is Object:
		return _object_error(object)
	if object is Dictionary:
		if not object.has(member_name):
			fail("The dictionary has no key '%s'." % member_name)
			return null
		return object[member_name]
	return _run_expression("v.%s" % member_name, ["v"], [object], "%s has no property '%s'." % [type_string(typeof(object)), member_name])


func fail(message: String) -> void:
	if error.is_empty():
		error = message


# --- Internals ----------------------------------------------------------------

func _binary_expr(expr: Array, frame: TaleFrame) -> Variant:
	var op: String = expr[1]
	var left: Variant = await evaluate(expr[2], frame)
	if op == "and":
		return bool(left) and bool(await evaluate(expr[3], frame))
	if op == "or":
		return bool(left) or bool(await evaluate(expr[3], frame))
	var right: Variant = await evaluate(expr[3], frame)
	if failed():
		return null
	return binary(op, left, right)


func _unary(op: String, operand: Variant) -> Variant:
	if failed():
		return null
	if op == "not":
		return not operand
	return _run_expression("%sa" % op, ["a"], [operand], "Can't use '%s' with %s." % [op, type_string(typeof(operand))])


func _contains(container: Variant, item: Variant) -> bool:
	if container is Object:
		_object_error(container)
		return false
	var result: Variant = _run_expression("a in b", ["a", "b"], [item, container], "Can't use 'in' with %s." % type_string(typeof(container)))
	return bool(result)


func _call(expr: Array, frame: TaleFrame) -> Variant:
	var callee: Array = expr[1]
	var args: Array = []
	for argument in expr[2]:
		args.append(await evaluate(argument, frame))
	var named := {}
	for key in expr[3]:
		named[key] = await evaluate(expr[3][key], frame)
	if failed():
		return null
	match callee[0]:
		"name":
			return await _director.call_function(callee[1], args, named, frame)
		"attr":
			var object: Variant = await evaluate(callee[1], frame)
			if failed():
				return null
			return _call_method(object, callee[2], args, named)
	fail("This value can't be called.")
	return null


func _call_method(object: Variant, method: String, args: Array, named: Dictionary) -> Variant:
	if _is_scriptable(object):
		if method not in object.get_tale_api().get("methods", []):
			fail("'%s' is not available to tales." % method)
			return null
		var bound := TaleCalls.bind(object, method, args, named)
		if bound["error"]:
			fail(bound["error"])
			return null
		return _director.start_task(Callable(object, method), bound["values"])
	if not named.is_empty():
		fail("Named arguments only work with actions.")
		return null
	if object is TaleNamespace:
		fail("Beats can only be called on a line of their own, e.g. %s.%s()." % [object.tale_name, method])
		return null
	if object is TaleExposed:
		if method not in object.methods:
			fail("'%s' is not available to tales." % method)
			return null
		return _director.start_task(Callable(object.target, method), args)
	if object is Object:
		return _object_error(object)
	var names := ["v"]
	var placeholders := PackedStringArray()
	for i in args.size():
		names.append("a%d" % i)
		placeholders.append("a%d" % i)
	var values := [object]
	values.append_array(args)
	return _run_expression("v.%s(%s)" % [method, ", ".join(placeholders)], names, values,
		"Can't call '%s' on %s." % [method, type_string(typeof(object))])


func _store(place: Array, value: Variant, frame: TaleFrame) -> void:
	match place[0]:
		"name":
			var problem: String = _director.assign_name(place[1], value, frame)
			if not problem.is_empty():
				fail(problem)
		"attr":
			var base: Variant = await evaluate(place[1], frame)
			if failed():
				return
			var member: String = place[2]
			if base is TaleNamespace:
				var problem: String = _director.set_tale_var(base.tale_name, member, value)
				if not problem.is_empty():
					fail(problem)
			elif base is TaleExposed:
				if member in base.properties:
					base.target.set(member, value)
				else:
					fail("'%s' can't be changed by tales." % member)
			elif _is_scriptable(base):
				if member in base.get_tale_api().get("properties", []):
					base.set(member, value)
				else:
					fail("'%s' can't be changed by tales." % member)
			elif base is Object:
				_object_error(base)
			elif base is Dictionary:
				base[member] = value
			elif _is_component(base, member):
				base[member] = value
				await _store(place[1], base, frame)
			else:
				fail("Can't change '%s' of %s." % [member, type_string(typeof(base))])
		"idx":
			var container: Variant = await evaluate(place[1], frame)
			var key: Variant = await evaluate(place[2], frame)
			if failed():
				return
			if container is Dictionary:
				container[key] = value
			elif container is Array:
				if not (key is int and key >= -container.size() and key < container.size()):
					fail("Index %s is outside the array (size %d)." % [str(key), container.size()])
					return
				container[key] = value
			else:
				fail("Can't change items of %s." % type_string(typeof(container)))
		_:
			fail("Can't assign to this expression.")


## Constants of value types, e.g. Color.RED or Vector2.ZERO.
func _type_constant(type_name: String, constant: String) -> Variant:
	if type_name == "Color":
		var missing := Color(-1, -1, -1, -1)
		var color := Color.from_string(constant, missing)
		if color != missing:
			return color
	else:
		var directions := {
			"ZERO": Vector3.ZERO, "ONE": Vector3.ONE, "LEFT": Vector3.LEFT, "RIGHT": Vector3.RIGHT,
			"UP": Vector3(0, -1, 0), "DOWN": Vector3(0, 1, 0), "FORWARD": Vector3.FORWARD, "BACK": Vector3.BACK,
		}
		if type_name == "Vector3":
			directions["UP"] = Vector3.UP
			directions["DOWN"] = Vector3.DOWN
		if directions.has(constant):
			var value: Vector3 = directions[constant]
			match type_name:
				"Vector2":
					if constant not in ["FORWARD", "BACK"]:
						return Vector2(value.x, value.y)
				"Vector2i":
					if constant not in ["FORWARD", "BACK"]:
						return Vector2i(int(value.x), int(value.y))
				"Vector3":
					return value
	fail("%s has no constant '%s'." % [type_name, constant])
	return null


## True for StoryTeller objects that list what tales may use, such as cast
## members and the camera.
static func _is_scriptable(value: Variant) -> bool:
	return value is Object and is_instance_valid(value) and value.has_method("get_tale_api")


static func _is_component(value: Variant, member: String) -> bool:
	match typeof(value):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return member in ["x", "y"]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return member in ["x", "y", "z"]
		TYPE_COLOR:
			return member in ["r", "g", "b", "a", "h", "s", "v"]
	return false


func _object_error(_object: Object) -> Variant:
	fail("Tales can only use objects that game code exposes with Story.expose().")
	return null


## Runs a small Godot Expression with the given inputs, caching the parsed
## form. Failures set [member error] instead of crashing.
func _run_expression(source: String, names: Array, values: Array, message: String) -> Variant:
	if failed():
		return null
	var key := "%s|%s" % [source, ",".join(names)]
	var expression: Expression = _expressions.get(key)
	if expression == null:
		expression = Expression.new()
		if expression.parse(source, PackedStringArray(names)) != OK:
			fail(message)
			return null
		_expressions[key] = expression
	var result: Variant = expression.execute(values, null, false)
	if expression.has_execute_failed():
		fail(message)
		return null
	return result
