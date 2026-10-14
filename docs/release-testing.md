# Testing a release

Run these checks before publishing a draft release. The automatic checks run in CI and in the Release workflow. The checks by hand cover what a machine can't judge: how the plugin looks, sounds, and feels on a real computer.

## Automatic (no action needed)

The **Release** workflow runs all of these before it opens the draft:

- The full test suite on Linux, and CI runs it on Windows too.
- `tools/check_export.sh`: the demo exported as a `.pck` still finds its tales, art, and translations, and New Game shows a line that saving and loading bring back.
- `tools/check_windows_export.ps1` (CI on Windows): the demo exported as a Windows game starts and quits cleanly, and passes the same checks.
- `tools/check_addon_install.sh`: the release zip installed in an empty project, enabled, set up with **Set Up Project**, and played to the end of the starter tale.
- `tools/check_studio_story.sh`: a story file from the Studio opened with **Open a Studio story** in an empty project, played to its end, and exported for the web (decision 0022). The web step needs Godot's web export templates.

## By hand

Use the `storyteller-<version>.zip` attached to the draft, on the computer and Godot version (4.7.2) your students or players will use. Tick each item, and note anything that looks wrong.

### 1. Install in a new project (about 5 minutes)

- [ ] Make a new, empty Godot project and unzip the release zip into its folder. `addons/storyteller/` appears in the FileSystem dock.
- [ ] **Project > Project Settings > Plugins**: enable **StoryTeller**. A **Story** tab appears next to 2D, 3D, and Script, with no errors in the Output panel.
- [ ] In the Story tab, click **Set Up Project** and accept the defaults. The story folders, `story/story_config.tres`, `story/tales/start.tale`, and `main.tscn` appear.
- [ ] Press **Play** (F5). The title screen shows; **New Game** plays the starter tale; its choice works; the story returns to the title at the end.

### 2. Write in the Story tab (about 10 minutes)

- [ ] **Text** view: type a line with a mistake, such as `ada: "Hi` with no closing quote. A problem appears in the list below the editor, and goes away when fixed.
- [ ] Autocomplete offers beat names after `jump `, and action names at the start of a line.
- [ ] **Cards** view: add a Dialogue card and a Choice card, move a card with the arrow buttons, fold and unfold a card, and undo with Ctrl+Z. The Text view shows the same changes.
- [ ] **Map** view: beats appear as boxes with arrows for jumps and choices. Double-click a box to open that beat.
- [ ] Add a character: drop a few PNGs named after moods (`neutral.png`, `smile.png`) into `story/cast/<name>/`, then make a CastProfile in `story/cast/`. The name and moods appear in autocomplete and in the Cards view's lists.
- [ ] Save (Ctrl+S) and play. The edits show in the game.

### 3. Play the demo (about 15 minutes)

Open the StoryTeller repository's project (a clone, not the zip) and press Play.

- [ ] Music plays on the title screen, and sounds and typing blips play in the story.
- [ ] Mouse: left-click continues, right-click opens the pause menu, the mouse wheel up rewinds, the middle button hides the interface.
- [ ] Keyboard: Space or Enter continues, Ctrl skips while held, A toggles auto mode, H opens history, Page Up rewinds, V hides the interface, Escape opens the pause menu, F5 quick saves, F9 quick loads.
- [ ] Gamepad, if you have one: A continues, Y toggles auto, the right shoulder skips, the left shoulder rewinds, Start opens the menu.
- [ ] Save in a slot, play on, then load it. The story returns to the saved line with the right backdrop, characters, and music. The slot's picture shows the story, not a menu.
- [ ] Quit the game and start it again. **Continue** resumes from the latest save.
- [ ] **Settings**: change text speed, volumes, text size, full screen, high contrast, and readable font. Each change shows at once and is still set after a restart.
- [ ] **Read lines aloud** (if the setting is shown): lines and choices are spoken.
- [ ] **Settings > Language > Español**: the menus and the demo story switch to Spanish.
- [ ] Reach both endings of the demo. **Extras** shows the unlocked pictures, music, codex entries, and the route chart.

### 4. Example story (about 5 minutes)

- [ ] Open `examples/wheres_biscuit/main.tscn` and press **Run Current Scene** (F6). Play both endings: the couch and the "together" choice lead to "Super helpers"; any other path leads to "Happy again".

### 5. Export (about 10 minutes, needs export templates)

- [ ] **Project > Export**: export the demo for Windows (and for the web, if you plan to support it). The exported game starts, plays, saves, and loads.

## When something fails

Note the step, what you expected, what happened, and any message in the Output panel. Open an issue, or for anything that looks like a security problem, follow `SECURITY.md`. Fix, merge, and run the **Release** workflow again: it replaces the draft with a new build.
