extends SceneTree
## Used by tools/check_studio_story.sh. Makes a story file the way a
## student would in the Studio: a story with starter characters, a
## background, music, a sound, a choice, and a "has been to" test, shared
## as a .zip.
## [codeblock]
## godot --headless --path . -s res://tools/studio_story/make_story.gd -- <work folder> <story.zip>
## [/codeblock]

const TALE := """beat start:
	backdrop("castle")
	music("adventure")
	maya.enter("happy", at = LEFT)
	maya: "We made it to the castle!"
	robo.enter("surprised", at = RIGHT)
	robo (surprised): "Beep! Which way now?"
	choose:
		"Go inside":
			jump hall
		"Stay out here":
			maya (thinking): "Let's look around first."
			jump hall

beat hall:
	backdrop("forest")
	sound("magic")
	whiskers.enter("neutral")
	whiskers: "Meow."
	if visited("castle_trip.start"):
		"The end."
"""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var library := StudioLibrary.new(args[0])
	var id := library.create("Castle Trip", TALE)
	library.add_starter_items(id)
	var ok := library.pack(id, args[1])
	print("CHECK story_file=%s" % ok)
	quit(0 if ok else 1)
