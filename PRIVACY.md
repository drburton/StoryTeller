# Privacy Statement

Last updated: 2026-10-11

This statement covers the open-source StoryTeller plugin for Godot (the code in `addons/storyteller/`) and the games that use it. It describes what the plugin itself does with information. It is written for players and for the developers who build games with StoryTeller.

## The short version

StoryTeller collects no personal information and sends nothing anywhere. It has no analytics, no telemetry, no advertising, and no accounts, and it makes no network connections. Everything it stores stays on the player's own device.

## What StoryTeller stores on the player's device

A game made with StoryTeller keeps these files in its own user data folder (Godot's `user://`), which only that game uses:

| What | Where (by default) | Contents |
|---|---|---|
| Save slots | `user://saves/*.json` | The story's progress: the current scene, choices made, story variables, character states, and anything the player typed in the story, such as a character name |
| Save thumbnails | inside each save slot | A small picture of the game screen at the moment of saving |
| Global data | `user://saves/global.json` | Progress shared across playthroughs: lines already read, unlocked gallery items, the route chart, and `@global` story variables |
| Settings | `user://settings.cfg` | Text speed, volumes, language, text size, accessibility choices, and similar options |
| Player-made stories | the mod folder, when the game turns it on | Story files the player chose to add |

The game's developer can change these locations in the game's `StoryConfig`. When the developer sets a save key, save slots and the global file are encrypted on the device. The key ships inside the game, so encryption discourages casual editing of saves and does not protect them from a determined person with access to the device.

Players can delete this information at any time by deleting the game's user data folder or by deleting saves from the game's save screen.

## Reading lines aloud

When a player turns on **Read lines aloud** in the settings, StoryTeller passes each line of text to the speech engine built into the player's operating system. StoryTeller does not record audio and does not send the text anywhere itself. Whether the operating system's speech engine processes text on the device or online depends on the operating system and its settings.

## In the Godot editor

The plugin's editor tools (the Story tab, the card editor, and the Story Map) read and write files in the open project only. Copying and pasting cards uses the computer's clipboard. The editor tools make no network connections either.

## For developers who make games with StoryTeller

StoryTeller is one part of your game. Your game, the Godot engine, other plugins you add, and the stores and platforms you publish on may collect information that this statement does not cover. You are responsible for your game's own privacy policy and for any privacy forms a store asks for. For StoryTeller's part, you can describe it as collecting no data and storing the files listed above on the player's device.

If your game exposes its own functions to tales (for example with `Story.expose()`), anything those functions do is part of your game, not StoryTeller.

## The StoryTeller website and repository

The StoryTeller source code is hosted on GitHub. When you visit the repository, open an issue, or download a release, GitHub's own privacy statement applies to that visit.

## Changes

If a future version of the plugin changes how it handles information, this statement will be updated in the same release, and the change will be listed in the release notes.

## Questions

Open an issue in the StoryTeller repository: https://github.com/drburton/StoryTeller/issues
