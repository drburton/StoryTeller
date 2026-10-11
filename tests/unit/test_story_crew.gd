extends "res://tests/framework/story_test.gd"
## Tests for the StoryCrew base class.

const FakeCrew := preload("res://tests/fixtures/fake_crew.gd")


func test_default_name_is_class_name() -> void:
	var crew: StoryCrew = track(StoryCrew.new())
	assert_eq(crew.get_crew_name(), &"StoryCrew")


func test_override_name() -> void:
	var crew: StoryCrew = track(FakeCrew.new())
	assert_eq(crew.get_crew_name(), &"Fake")


func test_base_capture_is_empty() -> void:
	var crew: StoryCrew = track(StoryCrew.new())
	assert_eq(crew.capture(), {})
