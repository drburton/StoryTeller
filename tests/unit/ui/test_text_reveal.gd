extends "res://tests/framework/story_test.gd"
## Tests for the text reveal styles: letter by letter, a word at a time,
## and fading in.


## A classic box showing [param text] with [param reveal]. Returns the box
## and records each visible letter count it passes through in [param seen].
func _show(text: String, reveal: String, seen: Array) -> ClassicDialogueBox:
	var box: ClassicDialogueBox = track(ClassicDialogueBox.new())
	box.text_reveal = reveal
	box.characters_per_second = 120.0
	tree.root.add_child(box)
	await tree.process_frame
	box.show_line({"speaker_name": "", "text": text})
	var label: RichTextLabel = box.find_child("Text", true, false)
	for i in 120:
		await tree.process_frame
		if not seen.has(label.visible_characters):
			seen.append(label.visible_characters)
		if box._waiting:
			break
	return box


func test_word_reveal_shows_whole_words() -> void:
	var seen := []
	var box := await _show("Hello big world", "word", seen)
	for count in seen:
		assert_true(count in [0, 6, 10, 15, -1], "letters shown: %d of %s" % [count, seen])
	box._plain = "Hello big world"
	assert_eq([box.visible_count(1), box.visible_count(6), box.visible_count(7), box.visible_count(12)], [6, 6, 10, 15], "typing inside a word shows the whole word")
	box.cancel()


func test_letter_reveal_types_letters() -> void:
	var seen := []
	var box := await _show("Hello big world", "type", seen)
	assert_true(seen.any(func(count: int) -> bool: return count > 0 and count not in [6, 10, 15]), "letters in between: %s" % [seen])
	box.cancel()


func test_fade_reveal_fades_letters_in() -> void:
	var seen := []
	var box := await _show("Hello big world", "fade", seen)
	var label: RichTextLabel = box.find_child("Text", true, false)
	assert_true(label.text.begins_with("[st_fade]"), label.text)
	assert_eq(label.custom_effects.size(), 1)
	assert_eq(label.get_parsed_text(), "Hello big world")
	var fade: ClassicDialogueBox.FadeEffect = label.custom_effects[0]
	fade.full_before = 4
	fade.shown = 8.0
	assert_eq(fade.alpha_at(2), 1.0, "letters typed earlier are fully shown")
	assert_eq(fade.alpha_at(8), 0.0, "letters not reached yet are hidden")
	assert_true(absf(fade.alpha_at(6) - 2.0 / DialogueBox.FADE_CHARACTERS) < 0.001, "the newest letters are fading in")
	box.cancel()
