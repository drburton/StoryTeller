extends "res://tests/framework/story_test.gd"
## Tests for TaleExpr.to_source(): printing an expression and parsing it
## again gives the same tree.

const TALES := [
	"res://tests/fixtures/talescript/expressions.tale",
	"res://tests/fixtures/talescript/statements.tale",
	"res://tests/fixtures/talescript/prologue.tale",
	"res://demo/tales/welcome.tale",
	"res://demo/tales/prologue.tale",
	"res://demo/tales/chapter_1.tale",
]


func _expr(source: String) -> TaleExpr:
	var parsed := TaleParser.parse_expression(source)
	assert_eq(parsed["error"], "", source)
	return parsed["expr"]


func _round_trip(expr: TaleExpr) -> void:
	var printed := expr.to_source()
	var again := TaleParser.parse_expression(printed)
	if again["error"]:
		fail("%s printed as %s, which does not parse: %s" % [expr.to_sexpr(), printed, again["error"]])
		return
	assert_eq(again["expr"].to_sexpr(), expr.to_sexpr(), printed)


func _round_trip_annotation(annotation: TaleExpr) -> void:
	var doc := TaleParser.parse(annotation.to_source() + "\n")
	assert_eq(doc.statements[0].annotations[0].to_sexpr(), annotation.to_sexpr(), annotation.to_source())


func test_prints_readable_source() -> void:
	assert_eq(_expr("mira.move_to(CENTER,time=0.6)").to_source(), "mira.move_to(CENTER, time = 0.6)")
	assert_eq(_expr("(a+b)*c").to_source(), "(a + b) * c")
	assert_eq(_expr("a+(b*c)").to_source(), "a + b * c")
	assert_eq(_expr("a-(b-c)").to_source(), "a - (b - c)")
	assert_eq(_expr("not (a and b)").to_source(), "not (a and b)")
	assert_eq(_expr("-(x+1)").to_source(), "-(x + 1)")
	assert_eq(_expr("\"s\" if n!=1 else \"\"").to_source(), "\"s\" if n != 1 else \"\"")
	assert_eq(_expr("await wait(1.0)").to_source(), "await wait(1.0)")
	assert_eq(_expr("{\"a\":[1,2]}").to_source(), "{\"a\": [1, 2]}")
	assert_eq(_expr("x && y || !z").to_source(), "x and y or not z")
	assert_eq(_expr("\"say \\\"hi\\\"\\n\"").to_source(), "\"say \\\"hi\\\"\\n\"")


func test_every_expression_in_sample_tales_round_trips() -> void:
	var count := 0
	for path in TALES:
		var doc := TaleParser.parse(FileAccess.get_file_as_string(path), path)
		var pending: Array = doc.statements.duplicate()
		while not pending.is_empty():
			var node: TaleNode = pending.pop_back()
			pending.append_array(node.body)
			var exprs: Array[TaleExpr] = []
			exprs.append_array(node.patterns)
			for expr in [node.target, node.condition]:
				if expr != null:
					exprs.append(expr)
			if node.expr != null and node.kind != TaleNode.Kind.CHOOSE:
				exprs.append(node.expr)
			for expr in exprs:
				_round_trip(expr)
				count += 1
			for annotation in node.annotations:
				_round_trip_annotation(annotation)
				count += 1
			if node.kind == TaleNode.Kind.CHOOSE and node.expr != null:
				var choose := TaleParser.parse("beat a:\n\t%s:\n\t\t\"x\": pass\n" % node.expr.to_source())
				assert_eq(choose.statements[0].body[0].expr.to_sexpr(), node.expr.to_sexpr())
	assert_true(count > 100, "checked %d expressions" % count)
