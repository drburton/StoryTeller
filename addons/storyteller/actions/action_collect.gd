extends TaleAction
## collect(id, notify = true): unlocks a gallery picture, music track, or
## codex entry from the collection folder. With notify, a short notice
## tells the player.


func get_action_name() -> String:
	return "collect"


func run(ctx: TaleContext, id: String, notify: bool = true) -> void:
	var collection := ctx.get_crew(&"Collection") as StoryCollection
	if collection == null:
		ctx.fail("collect() needs the Collection crew member.")
		return
	var was_collected := collection.is_collected(id)
	var problem := collection.collect(id)
	if not problem.is_empty():
		ctx.fail(problem)
		return
	var menus := ctx.get_crew(&"Menus") as StoryMenus
	if notify and not was_collected and menus != null:
		menus.show_notice(TranslationServer.translate("Unlocked: %s") % TranslationServer.translate(collection.get_item(id).title))
