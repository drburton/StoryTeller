extends TaleAction
## autosave(): saves to the autosave slot, for example at the start of a
## chapter.


func get_action_name() -> String:
	return "autosave"


func run(ctx: TaleContext) -> void:
	var saves := ctx.get_crew(&"Saves") as StorySaves
	if saves == null:
		ctx.fail("autosave() needs the Saves crew member.")
		return
	var error := saves.save_slot(StorySaves.AUTO_SLOT)
	if error != OK:
		ctx.fail("Autosave failed: %s." % error_string(error))
