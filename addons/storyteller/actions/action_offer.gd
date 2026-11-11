extends TaleAction
## offer(id): shows the purchase screen for a product. With await, gives
## true when the reader owns it afterwards:
## [code]if await offer("full_story"):[/code]


func get_action_name() -> String:
	return "offer"


func run(ctx: TaleContext, id: String) -> bool:
	var store := ctx.get_crew(&"Store") as StoryStore
	if store == null:
		ctx.fail("offer() needs the Store crew member.")
		return false
	if not store.has_product(id):
		ctx.fail("There is no product '%s' in %s." % [id, store.product_folder])
		return false
	return await store.offer(id)
