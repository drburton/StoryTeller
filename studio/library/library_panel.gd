class_name StudioLibraryPanel
extends VBoxContainer
## The story's characters, backgrounds, and sounds beside the blocks
## (docs/studio-design.md §4 and §6). Each kind has + Add, which offers the
## starter library and the student's own pictures and sound files. Tapping
## a character shows its faces, with + Add a face; tapping a sound plays it.

## Emitted after a character, face, background, or sound is added.
signal assets_changed

const KIND_TITLES := {"cast": "Characters", "backdrops": "Backgrounds", "sounds": "Sounds"}
const TILE_SIZE := Vector2(100, 104)

var library: StudioLibrary
var story_id := ""
var _sections := {}
var _message: Label
var _player: AudioStreamPlayer


func _init() -> void:
	add_theme_constant_override("separation", 6)
	for kind in KIND_TITLES:
		var header := HBoxContainer.new()
		var title := StudioUI.label(KIND_TITLES[kind], StudioUI.FONT_SIZE - 2, Color(0.85, 0.87, 0.9))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var add := StudioUI.button("+ Add", open_add.bind(kind))
		add.set_meta("add_kind", kind)
		add.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE - 4)
		header.add_child(add)
		add_child(header)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		add_child(flow)
		_sections[kind] = flow
	_message = StudioUI.label("", StudioUI.FONT_SIZE - 4, Color(1, 0.85, 0.5))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	add_child(_message)
	_player = AudioStreamPlayer.new()
	add_child(_player)


## Shows the pictures and sounds of the story [param id].
func show_story(new_library: StudioLibrary, id: String) -> void:
	library = new_library
	story_id = id
	refresh()


func refresh() -> void:
	for kind in _sections:
		var flow: HFlowContainer = _sections[kind]
		for child in flow.get_children():
			flow.remove_child(child)
			child.queue_free()
		var tiles := _tiles(kind)
		for tile in tiles:
			flow.add_child(tile)
		if tiles.is_empty():
			flow.add_child(StudioUI.label("None yet", StudioUI.FONT_SIZE - 4, Color(0.6, 0.63, 0.7)))


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()


## The tiles of [param kind] in the panel, by item name.
func get_tiles(kind: String) -> Dictionary:
	var tiles := {}
	for child in _sections[kind].get_children():
		if child.has_meta("item"):
			tiles[child.get_meta("item")] = child
	return tiles


func _tiles(kind: String) -> Array[Control]:
	var tiles: Array[Control] = []
	if library == null or story_id.is_empty():
		return tiles
	match kind:
		"cast":
			var profiles := StoryStage.scan_cast(library.asset_folder(story_id, "cast"))
			for id in library.asset_names(story_id, "cast"):
				var profile: CastProfile = profiles[id]
				var face := profile.look.get_preview(profile.default_mood) if profile.look != null else null
				tiles.append(_tile(id, profile.get_display_name(), StudioBlockEditor._thumbnail(face, true), open_character.bind(id)))
		"backdrops":
			for item in library.asset_names(story_id, "backdrops"):
				var texture := StoryAssets.load_asset(library.asset_folder(story_id, "backdrops"), item, StoryAssets.IMAGE_EXTENSIONS) as Texture2D
				tiles.append(_tile(item, StudioBlockEditor.scene_title(item), StudioBlockEditor._thumbnail(texture, false), Callable()))
		"sounds":
			for sound_kind in ["music", "sounds"]:
				for item in library.asset_names(story_id, sound_kind):
					var mark := "♫ " if sound_kind == "music" else "♪ "
					tiles.append(_tile(item, mark + StudioBlockEditor.scene_title(item), null, play_sound.bind(sound_kind, item)))
	return tiles


func _tile(item: String, words: String, picture: Texture2D, on_press: Callable) -> Button:
	var tile := StudioUI.button(words, on_press)
	tile.set_meta("item", item)
	tile.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE - 6)
	tile.clip_text = true
	if picture != null:
		tile.icon = picture
		tile.expand_icon = true
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.custom_minimum_size = TILE_SIZE
	return tile


## Plays the story's music or sound [param item], or stops it when it is
## already playing.
func play_sound(kind: String, item: String) -> void:
	var stream := StoryAssets.load_asset(library.asset_folder(story_id, kind), item, StoryAssets.AUDIO_EXTENSIONS) as AudioStream
	if _player.playing and _player.stream == stream:
		_player.stop()
		return
	_player.stream = stream
	_player.play()


# --- Adding ---------------------------------------------------------------

## Offers what can be added to [param kind]: the starter library's items the
## story doesn't have yet, and the student's own pictures or sounds.
func open_add(kind: String) -> VBoxContainer:
	var words := {"cast": "Add a character", "backdrops": "Add a background", "sounds": "Add music or a sound"}
	var column := StudioUI.open_dialog(self, words[kind])
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var close := func() -> void: column.get_meta("dialog").queue_free()
	var starter_kinds: Array = ["music", "sounds"] if kind == "sounds" else [kind]
	for starter_kind in starter_kinds:
		var have := library.asset_names(story_id, starter_kind)
		for item in StudioStarter.names(starter_kind):
			if item in have:
				continue
			var picture: Texture2D = null
			if starter_kind in ["cast", "backdrops"]:
				picture = StudioBlockEditor._thumbnail(StudioStarter.picture(starter_kind, item), starter_kind == "cast")
			var label := StudioBlockEditor.scene_title(item)
			if starter_kind == "music":
				label = "♫ " + label
			elif starter_kind == "sounds":
				label = "♪ " + label
			var tile := _tile(item, label, picture, func() -> void:
				close.call()
				add_starter(starter_kind, item))
			tile.set_meta("starter_kind", starter_kind)
			flow.add_child(tile)
	if flow.get_child_count() > 0:
		column.add_child(StudioUI.label("From the starter library", StudioUI.FONT_SIZE - 2, Color(0.85, 0.87, 0.9)))
		column.add_child(flow)
	var own := {"cast": [["Make a character from your pictures", _new_character]],
		"backdrops": [["Use your own picture", _pick_backdrop]],
		"sounds": [["Use your own music", _pick_sound.bind("music")], ["Use your own sound", _pick_sound.bind("sounds")]]}
	for choice in own[kind]:
		var button := StudioUI.button(choice[0], func() -> void:
			close.call()
			choice[1].call())
		button.set_meta("own_choice", choice[0])
		column.add_child(button)
	StudioUI.add_buttons(column, [["Cancel", Callable()]])
	return column


## Adds the starter item [param item] of [param kind] to the story.
func add_starter(kind: String, item: String) -> bool:
	var added := library.add_starter_item(story_id, kind, item)
	_changed("Added %s." % StudioBlockEditor.scene_title(item) if added else "That could not be added.")
	return added


## Adds [param image] as the background [param name]. Returns its name.
func add_own_picture(name: String, image: Image) -> String:
	var item := library.add_picture(story_id, "backdrops", name, image)
	_changed("Added %s." % StudioBlockEditor.scene_title(item) if not item.is_empty() else "That picture could not be added.")
	return item


## Adds [param image] as the face [param face] of [param character].
## Returns the character's id.
func add_own_face(character: String, face: String, image: Image) -> String:
	var id := library.add_face(story_id, character, face, image)
	_changed("Added the %s face." % face.strip_edges() if not id.is_empty() else "That picture could not be added.")
	return id


## Adds the sound file at [param path] as music or a sound. Returns its name.
func add_own_sound(kind: String, name: String, path: String) -> String:
	var item := library.add_sound(story_id, kind, name, path)
	_changed("Added %s." % StudioBlockEditor.scene_title(item) if not item.is_empty() else "That isn't a sound the Studio can play.")
	return item


## Shows the faces of the story's character [param id], with + Add a face.
func open_character(id: String) -> VBoxContainer:
	var profile: CastProfile = StoryStage.scan_cast(library.asset_folder(story_id, "cast")).get(id)
	var column := StudioUI.open_dialog(self, profile.get_display_name() if profile != null else id)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	column.add_child(flow)
	if profile != null and profile.look != null:
		for mood in profile.look.get_moods():
			flow.add_child(_tile(mood, mood.capitalize(), StudioBlockEditor._thumbnail(profile.look.get_preview(mood), true), Callable()))
	var add := StudioUI.button("+ Add a face", func() -> void:
		column.get_meta("dialog").queue_free()
		_ask(self, "Name of the face, like happy or sad", "", func(face: String) -> void:
			StudioFiles.pick_picture(func(image: Image) -> void:
				add_own_face(profile.get_display_name() if profile != null else id, face, image)
				open_character(id), show_message)))
	add.set_meta("own_choice", "+ Add a face")
	column.add_child(add)
	StudioUI.add_buttons(column, [["Done", Callable()]])
	return column


func _new_character() -> void:
	_ask(self, "Name of the new character", "", func(character: String) -> void:
		_ask(self, "Name of their first face, like happy", "happy", func(face: String) -> void:
			StudioFiles.pick_picture(func(image: Image) -> void:
				var id := add_own_face(character, face, image)
				if not id.is_empty():
					open_character(id), show_message)))


func _pick_backdrop() -> void:
	StudioFiles.pick_picture(func(image: Image) -> void:
		_ask(self, "Name of this background", "", func(name: String) -> void: add_own_picture(name, image)), show_message)


func _pick_sound(kind: String) -> void:
	StudioFiles.pick_sound(func(path: String) -> void:
		_ask(self, "Name of this " + ("music" if kind == "music" else "sound"), path.get_file().get_basename(),
			func(name: String) -> void: add_own_sound(kind, name, path)), show_message)


func _changed(message: String) -> void:
	refresh()
	show_message(message)
	assets_changed.emit()


## Asks for a name over [param parent], then calls [param on_done] with it.
static func _ask(parent: Control, question: String, value: String, on_done: Callable) -> void:
	var column := StudioUI.open_dialog(parent, question)
	var field := LineEdit.new()
	field.text = value
	field.custom_minimum_size.y = StudioUI.TOUCH_SIZE
	field.add_theme_font_size_override("font_size", StudioUI.FONT_SIZE)
	field.set_meta("field_key", "dialog:name")
	column.add_child(field)
	var done := func() -> void:
		if not StudioBlockEditor.make_name(field.text).is_empty():
			on_done.call(field.text)
	field.text_submitted.connect(func(_text: String) -> void:
		column.get_meta("dialog").queue_free()
		done.call())
	StudioUI.add_buttons(column, [["Cancel", Callable()], ["OK", done]])
	(func() -> void:
		if field.is_inside_tree():
			field.grab_focus()).call_deferred()
