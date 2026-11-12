@tool
class_name StoryProduct
extends Resource
## Something a reader can buy inside the game, such as the full story or an
## extra chapter (decision 0029). Bought once and owned for good.
##
## Save products in [member StoryConfig.product_folder] or list them in
## [member StoryConfig.products]. Tales use the id:
## [codeblock]
## if await offer("full_story"):
##     jump chapter_2
## [/codeblock]

## Name used by owns(), offer(), and @needs. Defaults to the file name.
@export var id := ""
## Name shown on the purchase screen.
@export var title := ""
## What the reader gets, shown on the purchase screen.
@export_multiline var description := ""
## Picture shown on the purchase screen.
@export var picture: Texture2D

@export_group("Store ids")
## The DLC's app id on Steam.
@export var steam_app_id := 0
## The product id in the Google Play Console.
@export var google_play_id := ""
## The product id in App Store Connect.
@export var apple_id := ""
## Price the test store shows.
@export var test_price := "$4.99"
