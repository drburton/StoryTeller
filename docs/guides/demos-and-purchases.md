# Demos and purchases

A story can ship as a free demo and let readers buy the rest inside the game: the full story, or extra chapters. The paid content ships in the game, locked until the reader buys it. This guide covers writing the story, testing it without any store account, and selling through the Apple App Store. Steam and Google Play follow (milestone M13, decision 0029).

Only things bought once and owned for good are supported (non-consumable purchases). There are no coins, consumables, or subscriptions, and no receipt checking on a server.

## 1. Describe what readers can buy

Each thing a reader can buy is a `StoryProduct` resource in `res://story/products/` (`StoryConfig.product_folder`). In the FileSystem dock, right-click the folder, choose **Create New > Resource**, pick **StoryProduct**, and save it, for example as `full_story.tres`.

| Field | Meaning |
|---|---|
| `id` | The name tales use. Defaults to the file name (`full_story`). |
| `title`, `description`, `picture` | What the purchase screen shows. |
| `apple_id` | The product id in App Store Connect, such as `com.yourstudio.yourgame.full`. Empty uses `id`. |
| `steam_app_id`, `google_play_id` | For Steam and Google Play, coming later. |
| `test_price` | The price the test store shows. |

## 2. Write the story

Three things in TaleScript work with products:

```
beat start:
	"The free part of the story."
	jump end_of_demo

beat end_of_demo:
	"That's the end of the free chapter."
	if await offer("full_story"):     # shows the purchase screen
		jump chapter_2
	"Thanks for playing the demo!"

@needs("full_story")                  # paid content starts here
beat chapter_2:
	"Chapter two."
```

- `owns("full_story")` is true when the reader owns the product. It shows nothing.
- `await offer("full_story")` shows the purchase screen and gives true when the reader owns the product afterwards. It returns true at once for a reader who already owns it, so the same line works for everyone.
- `@needs("full_story")` marks the beat where paid content begins. A reader who reaches it without the product is offered it, and if they don't buy, the story ends and returns to the title screen. Mark every beat that is a way into paid content.

The checker warns about a `jump` into a `@needs` beat that isn't inside an `if owns(...)` or `if await offer(...)`, so you decide what demo readers see. The path explorer plays the story twice, once as a reader who owns nothing and once as one who owns everything, and the Map view marks `@needs` beats with a lock.

Saves made in paid content remember what they need. For a reader who doesn't own it, for example after a refund, the load screen shows **Locked**, and loading the save offers the product first.

The title and pause menus show **Restore purchases** whenever the game has products. Apple requires a way to restore purchases.

To use your own purchase screen, make a scene whose root extends `OfferScreen` and set it as `StoryConfig.offer_scene`.

## 3. Test without a store

When the game runs from the Godot editor, StoryTeller uses the **test store**: every purchase works, and it remembers what was bought in `user://test_store.cfg`. Open the debug console (F3 or the `` ` `` key, in debug builds) to change it:

| Command | Does |
|---|---|
| `store` | Lists the products and whether the reader owns them. |
| `store own full_story` | Gives the reader the product. |
| `store drop full_story` | Takes it away, as a refund would. |
| `store reset` | Takes everything away. |

In code, `TestStoreBackend.next_result` makes the next purchase cancel, wait (pending), or fail, so you can see how the screen handles each.

## 4. Sell on the Apple App Store

StoryTeller talks to the App Store through the **Godot StoreKit 2** plugin ([godot-sdk-integrations/godot-storekit2](https://github.com/godot-sdk-integrations/godot-storekit2), MIT licensed). Its API is still a draft (v0.2), so StoryTeller keeps everything that uses it in `AppleStoreBackend`.

You need a Mac with Xcode to export for iOS, and a paid Apple Developer Program membership to sell.

1. **App Store Connect:**
   - Create the app.
   - Accept the Paid Apps agreement and fill in tax and banking under Agreements, Tax, and Banking. In-app purchases don't work, even in testing, until it's active.
   - Under In-App Purchases, create one **Non-Consumable** per `StoryProduct`. Use the product's `apple_id` as the product id, and give it a price, a display name, and a review screenshot.
2. **The plugin:** download the latest release for your Godot version and extract it into your project's `ios/plugins` folder. In **Project > Export**, open the iOS preset and tick **Godot Storekit 2** under Plugins.
3. **StoryConfig:** leave `store` on `auto`. An iOS export with the plugin uses the App Store, and running from the editor still uses the test store. Set it to `apple` to force the App Store.
4. **Test on a device:**
   - Before App Store Connect is ready, you can test from Xcode with a StoreKit configuration file. In Xcode, add one with the same product ids, then choose it in the scheme's Run options.
   - With App Store Connect ready, create a Sandbox Apple Account under Users and Access > Sandbox, sign in with it on the device, and buy, restore, and refund for real without being charged.
   - Use TestFlight for testers outside your team.
5. **Before review:**
   - Make sure the demo ends somewhere sensible for readers who don't buy.
   - Check that **Restore purchases** brings back a purchase after reinstalling the game.
   - Check that the purchase screen shows the App Store's price.

What StoryTeller does on Apple:

- At launch it asks the App Store for each product's price and whether the reader owns it. Until the App Store answers, it uses what the reader owned last time, kept with the global data, so the game works offline.
- Refunds and purchases approved later through Ask to Buy arrive at any time and lock or unlock content right away. A pending Ask to Buy purchase closes the purchase screen with a notice.
- **Restore purchases** syncs with the App Store, which asks the reader to sign in.

## 5. A separate demo build

Some stores prefer a separate demo app. Add the custom feature `demo` to an export preset. In that build the reader owns nothing, and the purchase screen says the full game is a separate purchase instead of selling it.
