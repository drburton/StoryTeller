# 0031. Voice and pictures per language

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

Decision 0011 translates text: lines, choices, names, and menus, through one strings CSV. The maintainer's projects also need voice recorded in each language and pictures with text, such as signs, letters, and title art, shown in the reader's language. Both engines need it, and a game should not have to change its tales to get it.

## Decision

- **The tales stay the same.** `backdrop("street")`, `@voice("line_01")`, and faces by mood keep their names. The engine picks the reader's language's version of the file, and the original when there is none.
- **Godot: a folder per language inside any asset folder.**
  - `res://story/backdrops/es/street.png` is shown while the game is in Spanish, and `res://story/cast/ada/es/smile.png` is Ada's Spanish face. The same goes for props, CGs, transition masks, and audio.
  - The locale is tried first, then its language (`es_MX`, then `es`), and the main folder last. No language folders are searched in the source language.
  - A language folder is named with the code of a language the game has: a loaded translation, the source language, or `StoryConfig.languages`. So a character can still be called "leo", and a language folder is never taken for a CG or a cast member.
  - A picture set directly in the config, such as the title background, uses a sibling file: `title.es.png` next to `title.png`.
- **Unity: versions on each entry, and voice by folder.**
  - Backdrops, cast moods, music and sound clips (`NamedSprite`, `NamedClip`), and the title background have a list of versions per language.
  - Voice clips come from `Resources/<Voice Folder>/<language>/<clip>`, because a fully voiced story has too many clips for inspector lists. Voice Clips in the Story Config can list them instead.
- **Voice falls back to the source language.** A line a language has no recording for plays the source language's clip. In Godot that's `audio/voice/<source>/` and then `audio/voice/`; in Unity, the source language's folder and then the voice folder. So a partly dubbed language still has voice.
- **Changing the language switches what is on screen.** The backdrop, CG, and cast on stage switch to the new language's pictures at once, and the next voice line uses the new language.
- **Export Strings includes product titles and descriptions** in both engines.

## Alternatives considered

- **Language-specific names in tales**, such as `backdrop("street_es")`: every tale would branch on the language, and translators couldn't work without editing tales.
- **The same per-entry lists in Godot:** Godot finds assets by folder convention everywhere else, and a folder per language is easier for artists and voice studios to deliver.
- **Folders by language at the top level** (`res://story/es/backdrops/...`): every asset kind would need a second tree, and a missing file would be harder to see beside its original.
- **Treating any short lowercase folder name as a language:** tried and rejected. It hid characters named "sam" and "leo".

## Consequences

- Artists and voice studios deliver files with the same names, into a folder per language.
- A Unity game's voice clips live under `Resources`, which loads them on demand and includes them in builds. Addressables could replace this later behind the same lookup.
- Tests cover both engines: Godot's `test_language_assets.gd`, and Unity's edit-mode and play-mode tests in the package.
