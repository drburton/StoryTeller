# 0023. Raw pictures and sounds outside the import system

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

Godot imports a project's pictures and sounds into its own formats, and an exported game holds only the imported versions. Files that were never imported, such as a photo a student adds in Visual Novel StoryTeller Studio (saved in `user://`), or a picture in a mod folder, were invisible to StoryTeller: `ResourceLoader.exists` returns false for them and `load()` fails, so a backdrop, a character's face, or a sound saved at run time could not be shown or played.

## Decision

- `StoryAssets` reads raw pictures (`png`, `jpg`, `jpeg`, `webp`) and sounds (`ogg`, `wav`, `mp3`) straight from their files when they are not imported resources. `StoryAssets.exists`, `load_path`, and `list_directory` cover both kinds, and `find`, `load_asset`, `list_names`, and `scan_cgs` use them.
- Everything that finds or loads assets goes through them: backdrops, CGs, props, cast folders and `SpriteSetLook` faces, audio, choice pictures, and the collection.
- A raw file is cached by path and read again when its modified time or size changes, so a replaced photo shows the new picture. A program that replaces a file can also drop it from the cache with `StoryAssets.forget_raw`.
- A character's folder may hold a `profile.json` with plain settings (display name, name color, default mood). It is data only, so a shared folder can't carry code the way a `.tres` profile could.
- Imported resources load exactly as before; the raw path is only a fallback.

## Alternatives considered

- **Importing at run time:** Godot's importers are editor-only, so an exported game cannot import files.
- **Saving every added picture as a `.tres` or `.res` resource:** loads through `ResourceLoader`, but the files are no longer plain pictures a person can open, and a story moved into a Godot project would carry Godot-only files instead of its photos.

## Consequences

- The Studio keeps a story's pictures and sounds as ordinary files in its folder, and a story file carries them as they are (decision 0022).
- Mods can bring their own pictures and sounds.
- A raw picture takes more memory than an imported, compressed texture, so the Studio scales large photos down when they are added.
- Imported sounds that are compressed cannot be written back out as `.wav` files, so starter sounds the Studio copies into a story must be kept uncompressed or as raw files.
