class_name StoryFile
extends RefCounted
## A story file from Visual Novel StoryTeller Studio: one .zip with a
## story's details, its tale, and its pictures and sounds as plain files
## (decisions 0022 and 0023):
## [codeblock]
## story.json              its title, and when it was made and changed
## tales/<id>.tale         its TaleScript
## backdrops/<name>.png    its backgrounds (also .jpg and .webp)
## cgs/<name>.png          its big pictures (or cgs/<name>/<variant>.png)
## cast/<name>/<face>.png  its characters, with an optional profile.json
## audio/music/<name>.ogg  its music (also .wav and .mp3)
## audio/sounds/<name>.ogg its sounds
## [/codeblock]
## The Studio shares stories as these files, and the Story tab's
## [b]Open a Studio story[/b] adds one to a Godot project (see
## [StudioStoryImport]). [method read] takes only the details, the tale,
## and pictures, sounds, and character profiles in their usual places, so
## a story file can't carry anything that runs code.

## Paths of the pictures, sounds, and character profiles a story file may
## hold.
const ASSET_PATTERN := "^(backdrops/\\w+\\.(png|jpe?g|webp)|cgs/\\w+(/\\w+)?\\.(png|jpe?g|webp)|cast/\\w+/(\\w+\\.(png|jpe?g|webp)|profile\\.json)|audio/(music|sounds)/\\w+\\.(ogg|wav|mp3))$"
## The largest tale a story file may hold.
const MAX_TALE_BYTES := 1 << 20
## The largest picture or sound a story file may hold.
const MAX_ASSET_BYTES := 25 << 20
## The most a story file may hold in all.
const MAX_FILE_BYTES := 250 << 20


## Reads the story file at [param zip_path]. Returns
## [code]{"error", "title", "created", "tale_name", "text", "assets"}[/code]:
## [code]error[/code] is empty when the file is a story, and
## [code]assets[/code] maps each picture, sound, and profile's path in the
## file to its bytes.
static func read(zip_path: String) -> Dictionary:
	var result := {"error": "", "title": "", "created": 0.0, "tale_name": "", "text": "", "assets": {}}
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		result["error"] = "That file is not a story file."
		return result
	var files := reader.get_files()
	var tales := Array(files).filter(func(file: String) -> bool:
		return file.begins_with("tales/") and file.ends_with(".tale") and file.count("/") == 1)
	if not files.has("story.json") or tales.size() != 1:
		reader.close()
		result["error"] = "That file is not a story from the Studio."
		return result
	var info = JSON.parse_string(reader.read_file("story.json").get_string_from_utf8())
	var bytes := reader.read_file(tales[0])
	if not info is Dictionary or bytes.size() > MAX_TALE_BYTES:
		reader.close()
		result["error"] = "That story file is damaged."
		return result
	var pattern := RegEx.create_from_string(ASSET_PATTERN)
	var total := bytes.size()
	for file in files:
		if pattern.search(file) == null:
			continue
		var data := reader.read_file(file)
		total += data.size()
		if data.size() > MAX_ASSET_BYTES or total > MAX_FILE_BYTES:
			reader.close()
			result["error"] = "That story file is too big."
			result["assets"] = {}
			return result
		result["assets"][file] = data
	reader.close()
	result["tale_name"] = tales[0].get_file().get_basename()
	result["title"] = str(info.get("title", result["tale_name"]))
	var created = info.get("created", 0.0)
	result["created"] = float(created) if created is float or created is int else 0.0
	result["text"] = bytes.get_string_from_utf8()
	return result


## A name for a story or tale from [param text]: lowercase letters, digits,
## and underscores, as "My Story" is "my_story". Empty when nothing is left.
static func make_name(text: String) -> String:
	var result := ""
	for character in text.strip_edges().to_lower().replace(" ", "_").replace("-", "_"):
		if character == "_" or (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			result += character
	if not result.is_empty() and result[0] >= "0" and result[0] <= "9":
		result = "n_" + result
	return result if result.is_valid_identifier() else ""


## [param text] with its "has been to" tests of the story [param old_id]
## pointed at [param new_id], since tests name the story.
static func renamed(text: String, old_id: String, new_id: String) -> String:
	if old_id.is_empty() or old_id == new_id:
		return text
	return text.replace("visited(\"%s." % old_id, "visited(\"%s." % new_id)


## Writes each of [param assets] (paths in a story file and their bytes)
## under [param folder]. Returns the paths written.
static func write_assets(assets: Dictionary, folder: String) -> PackedStringArray:
	var written := PackedStringArray()
	for file in assets:
		var path := folder.path_join(file)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out != null:
			out.store_buffer(assets[file])
			out.close()
			written.append(path)
	return written
