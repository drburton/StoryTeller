extends "res://tests/framework/story_test.gd"
## Parses every fixture in tests/fixtures/talescript and compares the tree dump
## with the stored "<name>.expected.txt". Run the tests with
## "-- --update-golden" to rewrite the expected files after an intended change,
## then review the diff before committing.

const FIXTURES := "res://tests/fixtures/talescript"


func test_fixtures_match_expected_trees() -> void:
	var update := "--update-golden" in OS.get_cmdline_user_args()
	var names := _fixture_names()
	assert_true(names.size() >= 4, "fixtures found")
	for file_name in names:
		var path := FIXTURES.path_join(file_name)
		var doc := TaleParser.parse(FileAccess.get_file_as_string(path), path)
		var expected_path := path.get_basename() + ".expected.txt"
		var actual := doc.dump()
		if update:
			var file := FileAccess.open(expected_path, FileAccess.WRITE)
			file.store_string(actual)
			file.close()
			continue
		if not FileAccess.file_exists(expected_path):
			fail("%s has no expected output. Run the tests with -- --update-golden." % file_name)
			continue
		var expected := FileAccess.get_file_as_string(expected_path)
		if actual != expected:
			fail("%s: tree differs from %s\n%s" % [file_name, expected_path.get_file(), _first_difference(expected, actual)])


func test_fixtures_round_trip() -> void:
	for file_name in _fixture_names():
		var path := FIXTURES.path_join(file_name)
		var source := FileAccess.get_file_as_string(path)
		assert_eq(TaleParser.parse(source, path).to_source(), source, "%s prints back unchanged" % file_name)


func _fixture_names() -> PackedStringArray:
	var names := PackedStringArray()
	for file_name in DirAccess.get_files_at(FIXTURES):
		if file_name.ends_with(".tale"):
			names.append(file_name)
	names.sort()
	return names


static func _first_difference(expected: String, actual: String) -> String:
	var expected_lines := expected.split("\n")
	var actual_lines := actual.split("\n")
	for i in maxi(expected_lines.size(), actual_lines.size()):
		var want := expected_lines[i] if i < expected_lines.size() else "<missing>"
		var got := actual_lines[i] if i < actual_lines.size() else "<missing>"
		if want != got:
			return "      line %d\n        expected: %s\n        actual:   %s" % [i + 1, want, got]
	return ""
