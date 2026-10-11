extends "res://tests/framework/story_test.gd"
## The parser must print every source back byte for byte, whatever its
## line endings, indentation, or mistakes.

const SAMPLES := {
	"empty": "",
	"only newline": "\n",
	"blank lines": "\n\n\n",
	"no final newline": "beat a:\n\t\"x\"",
	"final newline": "beat a:\n\t\"x\"\n",
	"several final newlines": "beat a:\n\t\"x\"\n\n\n",
	"crlf": "beat a:\r\n\t\"x\"\r\n\tmira: \"y\"\r\n",
	"crlf no final": "beat a:\r\n\t\"x\"",
	"trailing spaces": "beat a:   \n\t\"x\"   \n",
	"space indentation": "beat a:\n    if x:\n        \"y\"\n    \"z\"\n",
	"comments everywhere": "# head\nbeat a:  # tail\n\t# inner\n\t\"x\"\n\t\t# deeper\n# outer\n",
	"multi-line call": "beat a:\n\tshow(\n\t\t\"x\",\n\t\tfade = 1,\n\t)\n",
	"continuation": "beat a:\n\tx = 1 + \\\n\t\t2\n",
	"triple string": "beat a:\n\t\"\"\"one\ntwo\n\"\"\"\n",
	"unicode": "beat café:\n\tmira: \"Ça va? 日本語 🎭\"\n",
	"broken": "beat a:\n\tif x y:\n\t\t\"z\"\n\tmira: (\n\t\"w\"\n",
	"bad indentation": "beat a:\n\t\"x\"\n\t\t\"y\"\n  \"z\"\n",
	"unterminated": "beat a:\n\t\"open\n\t\"\"\"never closed\n",
}


func test_samples_round_trip() -> void:
	for sample_name in SAMPLES:
		var source: String = SAMPLES[sample_name]
		var doc := TaleParser.parse(source)
		assert_eq(doc.to_source(), source, "'%s' prints back unchanged" % sample_name)


func test_every_line_belongs_to_one_node() -> void:
	for sample_name in SAMPLES:
		var source: String = SAMPLES[sample_name]
		var doc := TaleParser.parse(source)
		var seen := {}
		_collect(doc.statements, seen)
		var content_lines := source.split("\n").size()
		if source.ends_with("\n") or source.is_empty():
			content_lines -= 1
		for line_number in range(1, content_lines + 1):
			if seen.get(line_number, 0) != 1:
				fail("'%s': line %d is covered %d times" % [sample_name, line_number, seen.get(line_number, 0)])


func _collect(nodes: Array[TaleNode], seen: Dictionary) -> void:
	for node in nodes:
		if not node.inline:
			for line_number in range(node.line_start, node.line_end + 1):
				seen[line_number] = seen.get(line_number, 0) + 1
		_collect(node.body, seen)
