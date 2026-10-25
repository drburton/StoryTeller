extends "res://tests/framework/story_test.gd"
## Tests for StoryTeller's symbol font (addons/storyteller/ui/
## storyteller_symbols.ttf): every symbol the plugin's screens and the
## Studio show is in Godot's default font or in it, since a web page has no
## system fonts to borrow from.

const StoryScript := preload("res://addons/storyteller/core/story.gd")
const FOLDERS := ["res://addons/storyteller/ui", "res://addons/storyteller/menus", "res://addons/storyteller/core",
	"res://addons/storyteller/stage", "res://studio"]


static func _scripts(folder: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name in DirAccess.get_files_at(folder):
		if file_name.get_extension() in ["gd", "txt", "json"]:
			found.append(folder.path_join(file_name))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found


func test_the_default_font_falls_back_on_the_symbols() -> void:
	var symbols := load(StoryScript.SYMBOL_FONT) as Font
	assert_not_null(symbols)
	assert_true(ThemeDB.fallback_font.fallbacks.has(symbols), "the Story autoload adds it")
	var font := SystemFont.new()
	StoryScript.add_symbol_font(font)
	StoryScript.add_symbol_font(font)
	assert_eq(font.fallbacks.size(), 1, "added once")


func test_every_symbol_on_screen_has_a_glyph() -> void:
	var symbols := load(StoryScript.SYMBOL_FONT) as Font
	var default_font := ThemeDB.fallback_font.duplicate() as Font
	default_font.fallbacks = []
	var missing := {}
	for folder in FOLDERS:
		for path in _scripts(folder):
			for character in FileAccess.get_file_as_string(path):
				var code := character.unicode_at(0)
				# Arrows, shapes, and other symbols; letters of other alphabets
				# come from the game's own fonts.
				if code < 0x2190 or code > 0x2BFF:
					continue
				if not default_font.has_char(code) and not symbols.has_char(code):
					missing[character] = path
	assert_eq(missing, {}, "symbols with no glyph on the web")
