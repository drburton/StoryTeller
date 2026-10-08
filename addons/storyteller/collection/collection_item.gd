@tool
class_name CollectionItem
extends Resource
## Something the player unlocks with [code]collect("id")[/code] and finds
## again in the Extras screen: a gallery picture, a music track, or a codex
## entry. Save one [code].tres[/code] per item in
## [member StoryConfig.collection_folder].

## Name used by collect() and collected(). Defaults to the file name.
@export var id := ""
## "image" (gallery), "music" (music room), or "entry" (codex).
@export_enum("image", "music", "entry") var kind := "image"
## Name shown in the Extras screen.
@export var title := ""
## Codex text, or a caption for a picture or track.
@export_multiline var text := ""
## Gallery picture, or a picture for a codex entry.
@export var image: Texture2D
## Music track name from the audio folder, for the music room.
@export var music := ""
## Lower numbers are listed first; ties are sorted by title.
@export var order := 0
