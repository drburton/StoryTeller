# StoryTeller

A visual novel and interactive story framework for Godot 4.7. Write stories in TaleScript, a GDScript-style language, as text or as cards, and play them with a ready-made dialogue box, choices, characters, saves, settings, history, and rewind.

## Getting started

1. Make sure this folder sits at `res://addons/storyteller/` in your project.
2. Open **Project > Project Settings > Plugins** and tick **Enable** next to **StoryTeller**. A **Story** tab appears next to 2D, 3D, and Script.
3. Open the **Story** tab and click **Set Up Project**. It makes the story folders, a StoryConfig, a first tale, and a main scene. It never overwrites files that already exist.
4. Press Play.

## Learn more

The guides, the TaleScript reference, a demo, and example stories are in the StoryTeller repository: https://github.com/drburton/StoryTeller

- Getting started: https://github.com/drburton/StoryTeller/blob/main/docs/guides/getting-started.md
- TaleScript for writers: https://github.com/drburton/StoryTeller/blob/main/docs/guides/talescript-for-writers.md
- Developer guide: https://github.com/drburton/StoryTeller/blob/main/docs/guides/developer-guide.md

## Privacy

StoryTeller collects no personal information and makes no network connections. A game that uses it stores saves (with a small screenshot each), progress shared across playthroughs, and settings in the game's own `user://` folder on the player's device. **Read lines aloud** passes text to the operating system's speech engine. Details: https://github.com/drburton/StoryTeller/blob/main/PRIVACY.md

## License and name

StoryTeller is released under the MIT license (see `LICENSE` in this folder). The license covers the code; the name and logo follow the trademark policy: https://github.com/drburton/StoryTeller/blob/main/TRADEMARKS.md
