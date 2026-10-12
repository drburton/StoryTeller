# Visual Novel StoryTeller Studio

The block-based story builder for kids (decisions 0020 and 0021, design in `docs/studio-design.md`). The Studio is built from this Godot project: exports with the `studio` feature tag start in this folder instead of the plugin's demo (see the `.studio` overrides in `project.godot`).

## What is here now

- `studio.tscn` is the app. It opens on the **home screen** (`home/`): the student's stories as cards with a picture, **New story** (a blank story or a copy of the **Where's Biscuit?** sample), and **Open a story file**. Each card's **⋯** renames, shares, or deletes its story, and a card reminds the student to share a copy of a story they changed a week ago and haven't shared since. The **⋯** at the top shows the Code blocks and opens the tablet check.
- `story_screen.gd` shows one story in the blocks, with **⌂ Stories**, the story's name (tap it to rename), **Undo**, **Redo**, **▶ Play** (from the start), and **⇪ Share**. Every change is saved at once. Play runs the story full screen with a ✕ to come back. Beside the blocks, the **stage preview** shows the stage at the chosen block, and **▶ Play from here** plays from it.
- `library/` holds the starter library (`StudioStarter`: the Where's Biscuit and demo characters, backgrounds, music, and sounds) and the library panel beside the blocks (`StudioLibraryPanel`), where **+ Add** brings in a starter item or the student's own picture or sound file, and tapping a character shows its faces.
- `preview/` holds the stage preview (`StudioStagePreview`), a small story of its own drawn in a SubViewport, and `StudioFromHere`, which writes the TaleScript that sets the stage on the way to a block and goes on after it.
- `stories/` keeps the stories in the app's own storage (`StudioLibrary`): one folder per story with its `story.json`, `tales/<id>.tale`, and its own pictures and sounds as plain files (`backdrops/`, `cgs/`, `cast/<name>/<face>.png`, `audio/music/`, `audio/sounds/`). A starter item the story uses is copied in, so a story file carries everything. **Share** packs a story into one `.zip` and saves it through the system's file picker (`StudioFiles`), and **Open a story file** adds one. A share sheet with AirDrop, Classroom, and email needs a small native plugin and comes later.
- `blocks/block_editor.gd` is the block editor (`StudioBlockEditor`): scene buttons, a palette of colored block groups, and the chosen scene's blocks. Drag a block in from the palette (or tap it to add it under the chosen block), drag blocks to move them, and drag one back to the palette to delete it. Hold a block for **Duplicate** and **Delete**. Tapping a field opens a picker: faces and backgrounds as pictures, lists for sounds and scenes, − and + for amounts. A **!** on a block explains a problem in plain words. The blocks themselves, and the TaleScript each one writes, are in `addons/storyteller/visual/story_blocks.gd`.
- `check/` holds the **tablet check** (milestone M8, step S0): one panel for each risk in `docs/studio-design.md` §10. A tester runs it on a real tablet, taps **Works** or **Problem** on each panel, and sends the results summary back.

Until the starter library (step S4), every story uses the characters, backgrounds, and sounds of the Where's Biscuit sample.

## Building

```bash
GODOT_BIN=/path/to/godot tools/build_studio.sh linux build/studio.x86_64   # desktop, for trying it out
GODOT_BIN=/path/to/godot tools/build_studio.sh android build/studio.apk    # needs the Android SDK
```

GitHub Actions builds the Android app on every change to the Studio (`.github/workflows/studio.yml`). The iOS build is added once the Apple developer account exists.

## Trying it on an Android tablet

1. Open the repository's **Actions** tab, choose the latest **Studio** run, and download **storyteller-studio-android** from its Summary page. Unzip it to get `storyteller-studio.apk`.
2. Copy the `.apk` to the tablet (email, Google Drive, or a USB cable) and open it there. Android asks to allow installing apps from that source; allow it for this install.
3. Open **StoryTeller Studio**, make a story, and try the blocks with your finger. Try **⇪ Share** and **Open a story file** too.
4. For the tablet check, tap **⋯** on the home screen, then **Tablet check**. Work through the seven panels, then tap **Show results to send** and paste the results into a message.
