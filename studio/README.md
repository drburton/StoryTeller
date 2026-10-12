# Visual Novel StoryTeller Studio

The block-based story builder for kids (decisions 0020 and 0021, design in `docs/studio-design.md`). The Studio is built from this Godot project: exports with the `studio` feature tag start in this folder instead of the plugin's demo (see the `.studio` overrides in `project.godot`).

## What is here now

- `studio.tscn` is the app. It opens the **Where's Biscuit?** sample in the block editor, saves every change in the app's own storage, and plays the story with **▶ Play** (from the start) or **▶ This scene**, with a ✕ to come back. **Undo** and **Redo** are in the top bar. The **⋯** menu shows the Code blocks, starts the sample over, and opens the tablet check.
- `blocks/block_editor.gd` is the block editor (`StudioBlockEditor`): scene buttons, a palette of colored block groups, and the chosen scene's blocks. Drag a block in from the palette (or tap it to add it under the chosen block), drag blocks to move them, and drag one back to the palette to delete it. Hold a block for **Duplicate** and **Delete**. Tapping a field opens a picker: faces and backgrounds as pictures, lists for sounds and scenes, − and + for amounts. A **!** on a block explains a problem in plain words. The blocks themselves, and the TaleScript each one writes, are in `addons/storyteller/visual/story_blocks.gd`.
- `check/` holds the **tablet check** (milestone M8, step S0): one panel for each risk in `docs/studio-design.md` §10. A tester runs it on a real tablet, taps **Works** or **Problem** on each panel, and sends the results summary back.

## Building

```bash
GODOT_BIN=/path/to/godot tools/build_studio.sh linux build/studio.x86_64   # desktop, for trying it out
GODOT_BIN=/path/to/godot tools/build_studio.sh android build/studio.apk    # needs the Android SDK
```

GitHub Actions builds the Android app on every change to the Studio (`.github/workflows/studio.yml`). The iOS build is added once the Apple developer account exists.

## Trying it on an Android tablet

1. Open the repository's **Actions** tab, choose the latest **Studio** run, and download **storyteller-studio-android** from its Summary page. Unzip it to get `storyteller-studio.apk`.
2. Copy the `.apk` to the tablet (email, Google Drive, or a USB cable) and open it there. Android asks to allow installing apps from that source; allow it for this install.
3. Open **StoryTeller Studio** and try the blocks with your finger.
4. For the tablet check, tap **⋯**, then **Tablet check**. Work through the seven panels, then tap **Show results to send** and paste the results into a message.
