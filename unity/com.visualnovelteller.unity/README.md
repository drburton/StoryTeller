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
- `Tests`: Unity tests of the package (edit mode and play mode). To run them, add `"testables": ["com.visualnovelteller.unity"]` to a project's `Packages/manifest.json` and open **Window > General > Test Runner**, or run Unity with `-runTests -testPlatform EditMode` (or `PlayMode`).

## Localization

Translations use the same strings file as the Godot plugin (decision 0011): one CSV with a `keys` column, a column per language, and `_context` and `_status` columns for translators. Lines and choice options are keyed `tale:line-id`; names, titles, products, and menu text are keyed by their English text. The same tales and the same file work in both engines.

1. In the Story Config, set **Source Language** (such as `en`) and list the **Languages** to translate into (such as `es`, `fr`).
2. Select the Story Config and choose **Assets > Visual Novel Teller > Export Strings**. It writes `Translations/strings.csv` next to the config and sets it as the config's **Translation File**. The file includes every line and choice, tale titles and beat headings, `tr("...")` texts, cast names, product titles and descriptions, the game title, and the menu text.
3. Translators fill in the language columns in a spreadsheet or translation tool. A translated line may use `{expr}` and text tags like the original.
4. Export again after changing tales: translations are kept, new strings are added, and the `_status` column marks strings no longer used or whose English text changed.

### Voice and pictures per language

- **Voice:** a line marked `@voice("line_01")` plays that clip when it shows and stops the clip before it. `voice("line_01")` plays one from a tale, and nothing plays while skipping. Put the clips under the Story Config's **Voice Folder** in `Resources`, one folder per language: `Resources/Voice/en/line_01.wav`, `Resources/Voice/es/line_01.wav`. A line a language has no recording for plays in the source language, so a partly dubbed language still has voice. Small games can list clips under **Voice Clips** instead. Settings has a **Voice volume**.
- **Pictures with text:** any backdrop or cast mood, and the title background, can have versions per language: add them under the entry's **Languages**. The stage shows the reader's language, and switching language switches the pictures on screen. Music and sound clips can have versions per language the same way.

The game starts in the language the player chose before, or the system's language when the file has it, or the source language. With `StoryMenus`, **Settings > Language** lists the file's languages and switches at once. In code, use `Story.Localization`: its `Language`, `Languages`, `T("text")` for your own interface text, and the `LanguageChanged` event.

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
