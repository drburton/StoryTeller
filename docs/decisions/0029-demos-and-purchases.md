# 0029. Demos and purchases through the stores

- **Status:** Proposed
- **Date:** 2026-11-10

## Context

Writers want to release a story as a free demo and let readers buy the rest inside the game: the full story, or extra chapters as DLC. Today a game has to write all of this itself, and the story has no way to ask whether the reader owns something.

Constraints:

- Each store has its own way to sell digital content inside a game. Steam sells DLC as separate app ids and opens its overlay to buy them. Google Play and the Apple App Store require their own in-app purchase systems for unlocking digital content.
- The plugin is MIT licensed and works without any store SDK. Each store's SDK comes as a separate Godot extension or plugin: GodotSteam, Godot's Google Play Billing plugin, and an iOS StoreKit plugin. The exact plugins and versions are confirmed in phase 0.
- `PRIVACY.md` says StoryTeller collects nothing. Store backends talk to the store the game already depends on, and to no server of ours.
- TaleScript is a cross-engine language (decision 0025), so any new names in it must be defined in the spec and the conformance suite.
- The Studio is for children and sells nothing.

## Decision

**Content ships locked.** The demo and the paid content are one build. Buying unlocks content that is already in the game. Downloadable content packs are not part of this decision.

**Products are data.** A `StoryProduct` resource names something a reader can buy. It holds an `id`, a title, a description, a picture, and its id on each store: `steam_app_id`, `google_play_id`, and `apple_id`. Products are found in `res://story/products/` (`StoryConfig.product_folder`) or listed in `StoryConfig.products`. Only non-consumable products are supported: things bought once and owned for good.

**A Store crew member.** `StoryStore` keeps track of what the reader owns. It talks to one store backend, chosen by `StoryConfig.store`:
- `"auto"` (the default) picks Steam, Google Play, or Apple by platform when that store's extension is present.
- Running from the editor uses the test store.
- `"none"` means the reader owns nothing.

Backends extend `StoreBackend`, which has:
- `start()`
- `owns(id)`
- `price(id)`, the store's localized price text
- `purchase(id)`, which is awaitable and returns bought, cancelled, pending, or failed
- `restore()`
- a `changed` signal

Four backends are built in: Test, Steam, Google Play, and Apple. A game can supply its own in `StoryConfig.store_backend`, for example for another storefront or its own key system. Store SDKs are found at run time, so the plugin never requires one.

**Ownership.** The store decides what the reader owns:
- `StoryStore` asks it when the story starts and whenever it reports a change.
- It keeps the last answer in the global data, so the game works offline.
- A refund locks the content again on the next check.

The plugin does no receipt checking on a server and has no copy protection.

**TaleScript**, in the same style as `collect()` and `collected()`:
- `owns("id")` is a built-in function that is true when the reader owns the product.
- `offer("id")` is an action that shows the purchase screen. With `await`, it gives true when the reader bought the product (or already owned it): `if await offer("full_story"):`.
- `@needs("id")` goes on a beat, or at the top of a tale for the whole tale, and marks content that requires the product. Entering it without the product shows the offer. If the reader doesn't buy, the story goes to the title screen. The checker warns about a jump into a `@needs` beat that isn't guarded by `owns()` or `offer()`, so writers handle the demo's end themselves.

**Screens:**
- The purchase screen is a replaceable scene (`StoryConfig.offer_scene`). By default it shows the product's picture, title, description, and store price, with Buy and Not now.
- The title and pause menus show **Restore purchases** when the backend supports it; Apple requires one.
- A save made in locked content shows a lock on the load screen, and opening it shows the offer.

**A separate demo build** is still possible for stores that prefer one, such as a Steam demo app. In an export with the `demo` feature tag, `owns()` is false for every product and `offer()` explains that the full game is a separate purchase.

**Tools:**
- The checker knows the product ids.
- The path explorer follows both the owned and the unowned way.
- The Map view marks `@needs` beats with a lock.
- The debug console's `store own <id>`, `store drop <id>`, and `store reset` drive the test store.

**Order:** Godot first. The new TaleScript names join the spec and the conformance suite. The Unity layer gets matching backends (Steamworks.NET and Unity IAP) after Unity 1.0.

## Alternatives considered

- **Leave purchases to game code:** every writer would rebuild the same screens and store code, and the story, checker, and path explorer couldn't see what is locked.
- **Separate demo and full builds only:** Steam handles this well, but the mobile stores expect one app with in-app purchases, and readers would lose their demo saves. It stays available through the `demo` feature tag.
- **Downloadable content packs (`.pck`):** a smaller demo, but more to build and test: download, storage, versioning, and each store's own way of delivering files. They can be added later on top of the same products and `owns()`.
- **One store only:** simpler to start, but the interface would be shaped around one store's quirks. The test backend and three stores keep it honest.
- **Server-side receipt checking:** stronger against piracy, but it needs a server for every game and would mean collecting data, against `PRIVACY.md`. Games that want it can write their own backend.
- **Consumables and subscriptions:** they bring balances, currencies, and renewal states that a story rarely needs, and they draw closer store review.

## Consequences

- A new crew member, a resource type, three TaleScript names, a purchase screen, and five backends to maintain.
- `PRIVACY.md` needs a note that a game using a store backend talks to that store, plus a legal review of the wording.
- Steam and the mobile stores can only be tested by hand: a Steam app id with a test DLC, a Google Play internal testing track, and the App Store sandbox (`docs/release-testing.md` gets a section for each). CI uses the test store.
- The store SDKs stay outside the repository. The setup wizard explains how to add the one a game needs.
- The Studio is unaffected.
