class_name StudioFiles
extends RefCounted
## Sharing a story as one .zip file and opening one, through the system's
## own file picker: Files and iCloud on an iPad, Files and Google Drive on
## Android (docs/studio-design.md §8). In a web browser, sharing saves a
## download and opening uses the browser's file picker ([StudioWeb]). A
## share sheet with AirDrop, Classroom, and email needs a small native
## plugin and comes later.

## Where a story file is made before it is saved elsewhere.
const OUTBOX := "user://shared"


## Packs the story [param id] and asks where to save it. [param report] is
## called with what happened, in plain words.
static func share(library: StudioLibrary, id: String, report: Callable) -> void:
	var zip_path := OUTBOX.path_join(id + ".zip")
	DirAccess.make_dir_recursive_absolute(OUTBOX)
	if not library.pack(id, zip_path):
		report.call(library.last_error)
		return
	if StudioWeb.is_web():
		StudioWeb.save_file(FileAccess.get_file_as_bytes(zip_path), id + ".zip", "application/zip")
		library.mark_shared(id)
		report.call("Saved a copy of your story as %s in your downloads." % (id + ".zip"))
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		library.mark_shared(id)
		report.call("The story file is ready at %s." % ProjectSettings.globalize_path(zip_path))
		return
	DisplayServer.file_dialog_show("Save a copy of your story", "", id + ".zip", false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		PackedStringArray(["*.zip; Story files"]), func(status: bool, paths: PackedStringArray, _filter: int) -> void:
			if not status or paths.is_empty():
				report.call("Nothing was saved.")
				return
			if not copy_file(zip_path, paths[0]):
				report.call("The copy could not be saved there.")
				return
			library.mark_shared(id)
			report.call("Saved a copy of your story."))


## Asks for a story file and adds it to [param library]. Calls
## [param on_opened] with the new story's id, or [param report] with what
## went wrong.
static func open(library: StudioLibrary, on_opened: Callable, report: Callable) -> void:
	if StudioWeb.is_web():
		StudioWeb.pick_file(".zip,application/zip", func(bytes: PackedByteArray, _name: String) -> void:
			var path := _save_picked(bytes, "picked.zip")
			if path.is_empty():
				report.call("That file could not be read.")
			else:
				open_path(library, path, on_opened, report))
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		report.call("This device can't open story files yet.")
		return
	DisplayServer.file_dialog_show("Open a story file", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.zip; Story files"]), func(status: bool, paths: PackedStringArray, _filter: int) -> void:
			if not status or paths.is_empty():
				return
			open_path(library, paths[0], on_opened, report))


## Adds the story file at [param path], copied into the app first because
## a picked file may only be readable for a moment.
static func open_path(library: StudioLibrary, path: String, on_opened: Callable, report: Callable) -> void:
	var local := OUTBOX.path_join("opened.zip")
	DirAccess.make_dir_recursive_absolute(OUTBOX)
	if not copy_file(path, local):
		report.call("That file could not be read.")
		return
	var id := library.unpack(local)
	DirAccess.remove_absolute(local)
	if id.is_empty():
		report.call(library.last_error)
	else:
		on_opened.call(id)


static func copy_file(from: String, to: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(from)
	if bytes.is_empty():
		return false
	var out := FileAccess.open(to, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(bytes)
	out.close()
	return true


## Asks for a picture with the system's picker (on a tablet, the photos and
## the camera), then calls [param on_picked] with it as an Image.
static func pick_picture(on_picked: Callable, report: Callable) -> void:
	if StudioWeb.is_web():
		StudioWeb.pick_file("image/png,image/jpeg,image/webp", func(bytes: PackedByteArray, _name: String) -> void:
			var image := picture_from_bytes(bytes)
			if image == null:
				report.call("That picture could not be read.")
			else:
				on_picked.call(image))
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		report.call("This device can't pick pictures yet.")
		return
	DisplayServer.file_dialog_show("Choose a picture", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp; Pictures"]), func(status: bool, paths: PackedStringArray, _filter: int) -> void:
			if not status or paths.is_empty():
				return
			var image := read_picture(paths[0])
			if image == null:
				report.call("That picture could not be read.")
			else:
				on_picked.call(image))


## Asks for a sound file, then calls [param on_picked] with its path.
static func pick_sound(on_picked: Callable, report: Callable) -> void:
	if StudioWeb.is_web():
		StudioWeb.pick_file("audio/*,.ogg,.wav,.mp3", func(bytes: PackedByteArray, file_name: String) -> void:
			# The sound's kind comes from its first bytes (see sound_kind);
			# keeping the file's own name gives the name field a start.
			var path := _save_picked(bytes, file_name.get_file().get_basename().validate_filename())
			if path.is_empty():
				report.call("That sound could not be read.")
			else:
				on_picked.call(path))
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		report.call("This device can't pick sounds yet.")
		return
	DisplayServer.file_dialog_show("Choose a sound", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		PackedStringArray(["*.ogg, *.wav, *.mp3; Sounds"]), func(status: bool, paths: PackedStringArray, _filter: int) -> void:
			if status and not paths.is_empty():
				on_picked.call(paths[0]))


## The picture in the file at [param path], read from its bytes, since a
## picked file may have no extension. Null when it isn't a picture.
static func read_picture(path: String) -> Image:
	return picture_from_bytes(FileAccess.get_file_as_bytes(path))


## The picture in [param bytes], or null when they aren't a PNG, JPEG, or
## WebP picture.
static func picture_from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.is_empty():
		return null
	var image := Image.new()
	for loader in [image.load_png_from_buffer, image.load_jpg_from_buffer, image.load_webp_from_buffer]:
		if loader.call(bytes) == OK and not image.is_empty():
			return image
	return null


## The kind of sound file [param bytes] hold, from their first bytes:
## "ogg", "wav", "mp3", or "".
static func sound_kind(bytes: PackedByteArray) -> String:
	if bytes.size() < 4:
		return ""
	var head := bytes.slice(0, 4).get_string_from_ascii()
	if head == "OggS":
		return "ogg"
	if head == "RIFF":
		return "wav"
	if head.begins_with("ID3") or (bytes[0] == 0xFF and (bytes[1] & 0xE0) == 0xE0):
		return "mp3"
	return ""


# Keeps a file picked in a browser in the outbox, and returns its path, or
# "" when it is empty or can't be written.
static func _save_picked(bytes: PackedByteArray, file_name: String) -> String:
	if bytes.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(OUTBOX)
	var path := OUTBOX.path_join(file_name if not file_name.is_empty() else "picked")
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(bytes)
	out.close()
	return path
