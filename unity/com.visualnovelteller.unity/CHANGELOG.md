# Changelog

## 0.1.0-preview.1 (unreleased)

- The TaleScript core (lexer, parser, checker, compiler, and director) in C#, passing the shared conformance suite.
- Package layout for Unity 6.7 LTS. Also works in Unity 6.3: the package asks for Unity 6000.3 and Input System 1.20.0, which 6.7 replaces with its built-in Input System.
- Demos and purchases (decision 0029):
  - `StoryProduct` entries and a Store mode in the Story Config.
  - `StoryStore` (`Story.Store`), with a test store in the editor and Unity In-App Purchasing 5 in builds (App Store and Google Play, in the optional `VisualNovelTeller.Purchasing` assembly).
  - `owns()`, `offer()`, and `@needs` in tales, the purchase screen and Restore purchases in `StoryMenus`, and locked saves for paid content.
- Skip (hold Ctrl or press Tab, read lines only unless Skip Unread is on), auto mode (key A), a history screen (key H), and a quick menu on the dialogue box. The Story Config gets Skip Unread, Auto Delay, and History Length.
- Menus: the StoryMenus component adds a title screen (Show Title Screen in the Story Config), a pause menu on Escape or gamepad Start, save and load screens with slots, a settings screen saved to settings.json, and a confirm dialog. Story gets Paused, ResetToStart, GetSlotInfo, LatestSlot, and a Finished event. Saves also write a slot.meta.json.
