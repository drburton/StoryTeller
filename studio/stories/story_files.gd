class_name StudioFiles
extends RefCounted
## Sharing a story as one .zip file and opening one, through the system's
## own file picker: Files and iCloud on an iPad, Files and Google Drive on
## Android (docs/studio-design.md §8). A share sheet with AirDrop, Classroom,
## and email needs a small native plugin and comes later.

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
