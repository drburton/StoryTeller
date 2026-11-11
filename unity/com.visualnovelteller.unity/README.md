# Visual Novel Teller for Unity

Write visual novels in TaleScript and play them in Unity 6.3 or 6.7 (final releases, not betas). The same tales run in the Godot version, and both pass one shared conformance suite.

This package is in early development (milestone M11). The TaleScript core works today; the Unity runtime and editor tools are being built.

## Install

In Unity, open **Window > Package Manager**, choose **+ > Install package from git URL**, and enter:

    https://github.com/drburton/StoryTeller.git?path=/unity/com.visualnovelteller.unity

## Folders

- `Runtime/TaleScript`: the TaleScript language core (lexer, parser, checker, compiler, and director). It uses no Unity code, and the command-line tools in `csharp/` build the same files.
- `Runtime/Unity`: components that play tales in a Unity scene.
- `Runtime/Purchasing`: selling through the Apple App Store and Google Play with Unity In-App Purchasing. It only compiles when the project has `com.unity.purchasing` 5.0 or newer.
- `Runtime/Steam`: selling DLC on Steam with Steamworks.NET. It only compiles when the project has `com.rlabrecque.steamworks.net`, and only for Windows, macOS, and Linux.
- `Editor`: import of `.tale` files and the editor tools.

## Demos and purchases

A story can ship as a free demo and sell the rest inside the game (decision 0029). The paid content ships in the game, locked until bought.

1. **Products:** in the Story Config, add each thing readers can buy under **Store > Products**:
   - an `id` that tales use;
   - a title, description, and picture for the purchase screen;
   - the product id in App Store Connect (`appleId`) and in the Google Play Console (`googlePlayId`).

   Create each one there as a **non-consumable** in-app purchase.
2. **Tales:**

   ```
   beat end_of_demo:
   	"That's the end of the free chapter."
   	if await offer("full_story"):     # shows the purchase screen
   		jump chapter_2
   	"Thanks for playing the demo!"

   @needs("full_story")                  # paid content starts here
   beat chapter_2:
   	"Chapter two."
   ```

   - `owns("id")` tells whether the reader owns a product.
   - `await offer("id")` shows the purchase screen.
   - `@needs("id")` marks a beat where paid content begins. Readers who reach it without the product are offered it, and the story ends if they don't buy.
3. **Menus:** with a `StoryMenus` component, the purchase screen shows the product and the store's price, with Buy and Not now. The title and pause menus show **Restore purchases**, which Apple requires. Saves made in paid content show **Locked** for readers who don't own it, and loading one offers the product first.
4. **Testing:** in the editor, the game uses a test store where every purchase works. It remembers purchases in `test_store.json` in the persistent data folder; delete that file to start over. In code, `TestStoreBackend.NextResult` tries a cancelled, pending, or failed purchase.
5. **Selling:**
   - In **Window > Package Manager**, add **In-App Purchasing** (`com.unity.purchasing`) 5.0 or newer; 5.4.0 is tested.
   - In a build, Store **Auto** then sells through the App Store on iOS and macOS, and Google Play on Android.
   - The store's answers decide what the reader owns. The last answer is kept in `saves/store.json`, so the game works offline.

6. **Selling on Steam:**
   - In Steamworks, create a DLC for each product and put its app id in the product's `steamAppId`.
   - Add Steamworks.NET with the git URL `https://github.com/rlabrecque/Steamworks.NET.git?path=/com.rlabrecque.steamworks.net#2025.164.1`. That version is tested.
   - In a Windows, macOS, or Linux build that Steam starts, Store **Auto** then sells through Steam. On a Mac, Steam comes first, and the Mac App Store is used when the game wasn't started through Steam.
   - **Buy** opens the DLC's page in the Steam overlay. The purchase counts when the reader owns the DLC as the overlay closes. Steam doesn't tell games prices, so the purchase screen shows none, and Restore purchases is hidden because Steam keeps ownership with the account.
   - The overlay must be on in Steam's settings.
   - While testing outside Steam, put a `steam_appid.txt` with your game's app id next to the executable.
   - Visual Novel Teller starts Steam and runs its callbacks. If the game has its own Steam manager, set `SteamworksStoreApi.ManageSteam = false` before the story starts.

`Story.Store.SetBackend` takes any `StoreBackend`, for another storefront or a game's own key system. `StoryStore.AddPlatformBackend` adds one to the stores Auto tries.

## License

MIT. See `LICENSE.md`.
