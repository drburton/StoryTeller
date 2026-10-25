# StoryTeller: Planning Document

StoryTeller is a visual novel and interactive story framework for **Godot 4**. Writers author stories in **TaleScript**, a small language that looks and feels like GDScript. The framework handles characters, scenery, dialogue boxes, choices, audio, saving, localization, and menus so creators can ship a complete visual novel, or add story sequences to any Godot game, with little or no extra code.

Status: **Draft v0.34** (the plugin: M0 to M4 and M6 complete, M5 built with its usability test open, M7 under way. Visual Novel StoryTeller Studio: M8 under way, with its home screen, blocks, stage preview, and story pictures and sounds built)

### Where things stand (2026-10-14)

- **Two products (2026-10-12):** **Visual Novel StoryTeller**, the Godot plugin for adults, finishes as 1.0 from the current 0.1.0 beta. **Visual Novel StoryTeller Studio** is for kids: a standalone, block-based story builder, downloaded as an app for iPads and Android tablets, with a live stage preview (milestone M8, decisions 0020 and 0021, `docs/studio-design.md`). The maintainer is writing a textbook for teachers to use with the Studio. Both live in this repository. There is no Pro tier; everything is open source (decision 0019, §12).
- **Built and merged to `main`:** milestones M0 to M6. M5 is built but stays open until the usability test with writers (§11). The language and compiler, the runtime with twelve crew members (§5.1), stage, audio, effects, movies, saves, rewind, history, settings, menus, Extras, translation, the debug console, live reload, and the Story tab with Text, Cards, and Map views.
- **M6:** inline text tags, CGs with gallery variants (decision 0013), character renames, character animations with drawing order, per-character data (`ada.affection`), a save screen with pages, renaming, deleting, and timed autosave, presentation details (title art and music, an animated dialogue box, and named text styles), a route chart for players in Extras, picture choices with a registry of choice styles, and Yarn Spinner import. Also merged: clicking anywhere on the dialogue box continues, and the default theme shows `[code]` in a tinted monospace font.
- **Tests:** 544 tests in the built-in runner pass on Linux and Windows in CI, plus a browser check of the Studio's web version, an export check of the demo as a `.pck` that also plays, saves, and loads it, the demo exported as a Windows game and run on Windows, and an install check of the plugin zip in an empty project.
- **Demo:** `demo/` plays a tour, a prologue, chapter 1, and chapter 2 with two endings (about 12 to 15 minutes by estimate; not yet timed with a player) in English and Spanish; `demo/embedded/` shows dialogue inside a 3D scene. The tour shows the TaleScript behind each feature it explains. Ada is "???" until she introduces herself, chapter 1 has a CG with two variants, characters hop, nod, and shake, and Mira's friendship grows with the player's choices.
- **M7 so far:** the last extension points for add-ons, named transitions and Story tab hooks (§12.3), the setup wizard and Pin Line IDs (§8), the documentation guides and a generated Action Reference (§17), custom actions listed in `StoryConfig.actions`, chapter titles on save slots, interruption tests (§16), demo chapter 2, gamepad buttons, a hide-interface key, a text size setting, typing sounds, and in the card editor a markup toolbar, copy and paste between tales, pictures in the character, mood, and asset lists, a variable picker, lists narrowed by typing, folding cards, keys to move and add cards, selecting several cards, and a condition builder (§9.3), lip-flap (§5.5), shared rewind snapshots, 3D characters through `ViewportLook` (§5.5), dialogue box portraits and character text colors (§5.5), warnings for missing assets (§5.6), an action folder for custom actions (§5.4), word-at-a-time and fade-in typing, high-contrast and readable font settings, reading lines aloud, blur and vignette filters, save encryption (§7), `@no_wait` (§5.1), and loading tales from a mod folder (§4).
- **Not done yet:** for the plugin, the M5 usability test with writers, the rest of M7 (timing the demo with a player, trailer and screenshots, the legal review, publishing the 0.1.0-beta release and the Asset Library listing), and a trademark search. For the Studio, the rest of M8: running the tablet check on real tablets (S0), a share sheet (S1), trying the photo and sound pickers on real tablets (S4), lessons matched to the textbook's chapters (S5), and the store test releases (S6).
- **To continue on another computer:** clone the repository, open `project.godot` in Godot 4.7.2, and run the tests with `.\tools\run_tests.ps1 -Godot <folder with Godot>` on Windows or `GODOT_BIN=<path> tools/run_tests.sh` elsewhere (see README). Work branches start from the latest `main`. Regenerating demo art and audio with `tools/demo_assets/generate.py` (and the Studio's starter art with `tools/demo_assets/starter_library.py`) needs Python 3 with Pillow and NumPy. `tools/check_export.sh` needs a preset named "Linux" when `export_presets.cfg` exists (it is not committed).

Changes in v0.34:
- Shots (`StoryShots`): a crew member that plays a scene's animations for tales, such as 3D characters rigged and animated in Blender, with `await shots.play()` and `shots.hold()`, and keeps the shot showing in saves and rewind, so a story told in your own 3D scene can pause for choices and load mid-scene.
- A path explorer (`TalePaths`, `addons/storyteller/editor/explore_paths.gd`) plays a tale down every path and reports its endings, scenes no path reaches, and paths that hit an error, get stuck, or loop.

Changes in v0.33:
- The Studio also runs as a web page (decision 0024). `tools/build_studio.sh web` builds it from the same project as the apps, with an install manifest for the home screen. In a browser, Share saves a download, and stories, pictures, and sounds come from the browser's file picker (`studio/web/`). The Studio asks the browser to keep its storage and says so on the home screen when it can't. `tools/check_studio_web.sh` checks it in Chromium: a story keeps its tale and pictures after the page is loaded again, opens in the blocks and the map, and plays. The Studio workflow runs it and keeps the web build.
- StoryTeller Symbols: a small font drawn for StoryTeller (`tools/demo_assets/symbols_font.py`) with the symbols its screens and the Studio show. Godot's default font has none of them and a web page has no system fonts, so web games showed empty boxes for the dialogue box's ▼; the Story autoload now adds the font behind Godot's default font. A test checks that every symbol on screen has a glyph.

Changes in v0.32:
- A Windows export build: `tools/check_windows_export.ps1` exports the demo as a Windows game, starts the exported game, and runs the export check and a new play check on it; CI runs it on Windows. The play check (`tools/export_play_check.gd`) presses New Game, waits for a line, saves, starts again, and loads; `tools/check_export.sh` runs it too. Exported games don't run scripts from the command line, so both checks run on the game's `.pck` with the Godot executable.
- The checker warns about a face a character doesn't have in `enter()` and in `mood = ...`, as it already did for lines like `mira (angry): "..."`. In the Studio this shows as a hint on the Show and Change the face blocks.
- When a story shuts down, the audio crew stops every player and lets go of its sounds, so no music keeps playing or stays loaded. **Quit** on the title screen and pause menu stops the music and gives the audio mixer a moment before closing, so a game quit mid-song exits without Godot reporting the music as still in use.

Changes in v0.31:
- **Open a Studio story** (M8, S5, decision 0022): the Story tab adds a story file from the Studio to a Godot project as its own story folder with a config and a scene that plays it, so a teacher or parent can review it and export it as a game. Reading story files moved into the plugin (`StoryFile`), so the Studio and the plugin take the same files. `StoryLauncher` is a node that plays a story with its own config. `tools/check_studio_story.sh` checks the whole path to a web build, and `docs/guides/publishing-studio-stories.md` walks teachers through it.
- The Studio's map of scenes (M8, S5): **Map** beside the scene buttons shows the story's scenes as boxes with arrows, laid out by `StoryGraph` like the plugin's Story Map, with the start, the endings, and problems marked in plain words. Tapping a scene opens it in the blocks; dragging moves the map.
- Templates and lessons (M8, S5): **New story** offers a blank story, a mystery, an adventure, "Choose your path", or a copy of Where's Biscuit, each with a line on what it is. **Lessons** on the home screen lists five draft lessons (sequence, input, branching, numbers and Ifs, and debugging), each with **Start** and **See it finished**. They use the starter art, open with no Code blocks, and ship as `.txt` files so exported apps keep their text.
- The textbook's screenshot script (M8, S5): `tools/studio_screenshots.sh <folder>` opens the Studio on a screen (under xvfb-run when there is none) and saves each shot in `studio/lessons/screenshots.json`, a list of steps such as opening a lesson, showing a palette group, tapping a block, opening the map, or playing. A shot list entry needs no code, so the book's author can add shots.
- The Studio's own starter art (M8, S4): park, forest, castle, beach, and space backgrounds; four characters with five faces each (Maya, Sam, Robo the robot, and Whiskers the cat); adventure and mystery music; and pop, whoosh, and magic sounds. It is made by `tools/demo_assets/starter_library.py` into `studio/library/art/`, and its characters are folders of faces with a `profile.json`, like the students' own.
- Fixed: sound tiles in the library panel cut their names short.

Changes in v0.30:
- The plugin reads raw pictures and sounds that were never imported, such as those saved in `user://` (decision 0023): `StoryAssets.exists`, `load_path`, and `list_directory`, used by backdrops, CGs, props, cast folders, faces, audio, and the collection. A character folder may hold a plain `profile.json` (display name, name color, default mood).
- The Studio's stories keep their own pictures and sounds (M8, S4): each story's folder holds its backgrounds, characters, music, and sounds as plain files, plays with a config of its own, and its story file carries them; opening one reads only pictures, sounds, and character profiles in their usual places. The starter library (`studio/library/`) gathers the Where's Biscuit and demo art and sounds; a starter item a story uses is copied in. The library panel adds starter items and the student's own pictures, faces, and sound files.
- The demo's sounds are imported uncompressed, so the Studio can copy them out as `.wav` files.

Changes in v0.29:
- The stage preview and Play from here (M8, S3). Beside the blocks, the preview shows the stage and the line at the chosen block. It runs a small story of its own (director, stage, effects, and dialogue box, with no sound) in a SubViewport, playing the blocks on the way that set the stage and then the block (`studio/preview/`). **▶ Play from here** plays full screen from the chosen block with the stage, music, and numbers as they would be there. **▶ This scene** is gone, since Play from here covers it.
- Fixed: the home screen's story cards printed an error for their ⋯ button.

Changes in v0.28:
- Publishing (decision 0022): students share story files and adults publish them. A teacher or parent opens a student's story in Godot with **Open a Studio story**, reviews it, and exports it as a game. The Studio itself never publishes, so the playable link is dropped from §12. Story files will carry their pictures and sounds (S4), and S5 grows to two weeks for the plugin's side, a web export check, and a teacher's guide.

Changes in v0.27:
- The Studio shell (M8, S1): a home screen with the student's stories as cards, New story (blank or a copy of the sample), Open a story file, and Rename, Share, and Delete on each card, with a reminder to share a copy of a story changed a week ago. Stories live in the app's storage (`studio/stories/`), one folder each with `story.json` and the tale. Share saves a `.zip` through the system's file picker; the share sheet needs a native plugin and comes later. The story screen adds the way home, renaming, and Share.
- Fixed: an exported Studio holds only the imported tale, so the sample opened empty; `tools/build_studio.sh` now ships the sample's text as a plain copy.

Changes in v0.26:
- The Studio's blocks (M8, S2): `StoryBlocks` (`addons/storyteller/visual/story_blocks.gd`) maps each block of `docs/studio-design.md` §5 to one TaleScript statement and back, and turns anything the blocks can't show into a Code block holding its exact text. The block editor (`studio/blocks/block_editor.gd`) has scene buttons, the colored palette, drag and snap with a drop line, dragging back to the palette to delete, a long-press menu, pickers with pictures, − and + for amounts, "Make a number", undo and redo, and hints in plain words from the checker.
- The Studio app (`studio/studio.tscn`) opens the Where's Biscuit sample in the blocks, saves every change in the app's storage, and plays the story with ✕ to come back. Checker problems don't stop it from playing. Exports with the `studio` tag now start here; the tablet check is in its ⋯ menu.
- `TaleSignatures.make_context` builds a check context outside the editor (moved from the importer), and `TaleEdit.fill_empty_blocks` adds `pass` under a block left holding only comments.
- Fixed: stopping a story while a line was typing printed a script error from the dialogue box.

Changes in v0.25:
- Two products (decisions 0019 and 0020): **Visual Novel StoryTeller**, the Godot plugin for adults, finishes as 1.0 from the current beta; **Visual Novel StoryTeller Studio** is a standalone product for kids in this repository's `studio/` folder, with its own version numbers. Goal 8 is added for the Studio (§1).
- New milestone M8 for the Studio (§11, §9.6, `docs/studio-design.md`): a story builder with Scratch-style blocks, a live stage preview, and Play, shipped as apps for iOS and Android (decision 0021). It starts with a one-week feasibility check on a real iPad and Android tablet and runs alongside finishing the plugin's 1.0.
- The maintainer is writing a textbook for the Studio, so the Studio freezes its interface within each major version, keeps every major version online, and ships lesson projects and a screenshot script (`docs/studio-design.md` §13).
- There is no Pro tier. §12 now schedules the former Pro features, all free: the stage preview, "play from here", and starter templates come first with the Studio; the rest follow in plugin 1.x releases. §7 and §13 to §20 drop the Pro tier, its EULA, and its repository.
- Platforms (§14): iPads and Android tablets are the Studio's first targets, as store apps (decision 0021).
- The Studio ships as downloadable apps for iOS and Android (decision 0021) in place of a web page; the classroom test moves after M8.

Changes in v0.24:
- Project policies for the open-source plugin: `PRIVACY.md` (StoryTeller collects nothing and stores saves, global data, and settings on the player's device), `TRADEMARKS.md` (the MIT license covers the code; the name and logo have their own rules), `CODE_OF_CONDUCT.md`, `SECURITY.md` (private reports through GitHub), and Developer Certificate of Origin sign-offs for contributions (`CONTRIBUTING.md`). They are drafts for the legal review (§2.8). Terms of service, billing, and arbitration terms are left for the Pro EULA (§12).
- The Where's Biscuit example and the documentation no longer name the toolkits used as the scope reference (§2, rule 6).
- Release testing: `docs/release-testing.md` lists the checks to run by hand before publishing, and the Release workflow replaces an unpublished draft when run again. A play-through of the demo and the example through the real screens found and fixed three problems: a save could use a thumbnail taken when a menu had opened long before (menus now drop it when they close), reading a plain save with `save_key` set printed engine errors (the file header is checked first), and the example shared the demo's save folder (it now has its own).

Changes in v0.23:
- The plugin is packaged for release (§11, M7). `tools/package_addon.sh` builds `storyteller-<version>.zip` with only `addons/storyteller/`, and `.gitattributes` keeps everything else out of GitHub and Asset Library downloads. `tools/check_addon_install.sh` installs the zip in an empty project, enables it, runs Set Up Project, and plays the starter tale; CI runs it on every pull request. Pushing a `v<version>` tag runs the **Release** workflow, which opens a draft GitHub release with the zip. `docs/publishing.md` lists the steps and the Asset Library form values.
- Turning on skip or auto while a line waits now takes effect at once, and turning auto off keeps the line waiting (found by the install check).
- `examples/wheres_biscuit/` is a short story for young players, with a test that plays every route. A project can hold more than one story: each tale is checked against the `story_config.tres` that owns its folder (`Story.config_for_tale`).

Changes in v0.22:
- The card editor fills the §9.3 gaps that need no usability test: a markup toolbar on narration and dialogue, copy and paste between tales, selecting several cards, pictures in the character, mood, and asset lists, a variable picker, lists narrowed by typing, folding Choice and Condition cards, and keys to move and add cards.
- Characters can have dialogue box portraits, optionally only while off stage, and their own text color (§5.5). Ada has portraits in the demo.
- Players get word-at-a-time and fade-in typing, high contrast, a readable font, reading lines aloud with the system's text-to-speech, and typing sounds per character (§7).
- Writers get warnings for asset names that match no file, an action folder for custom actions, `@no_wait`, and blur and vignette filters (§4, §5.4, §5.6). Saves can be encrypted (§7).

Changes in v0.21:
- M7 progress: the setup wizard is built (§8). While a project has no StoryConfig, the Story tab offers **Set Up Project**, which makes the story folders, a config, a first tale, and a main scene that opens the title screen.
- Every extension point in §12.4 is built (decision 0018). Transitions can be added by name with `StoryTransition` resources (a built-in mode with its own mask, direction, and softness, or a custom shader), from `StoryConfig.transition_folder`, `StoryConfig.transitions`, or `StoryStage.add_transition()`, and the card forms list them. The Story tab offers `TaleEditorPanel.get_instance()`, `add_toolbar_control()`, `add_side_panel()`, and the `line_selected` signal for add-ons such as a stage preview.

Changes in v0.20:
- M6 complete: Yarn Spinner import is built (§11, decision 0017). **Import Yarn** in the Story tab (or `addons/storyteller/editor/import_yarn.gd` from the command line) converts a `.yarn` file into a tale: nodes become beats, with dialogue, options, conditions, variables, jumps, detours, waits, and line ids. Anything else is kept as a comment and listed. `demo/yarn/lighthouse.yarn` is an original sample, and a test converts it and plays it.
- §1.1 and §20 updated now that M6 is done.

Changes in v0.19:
- M6 progress: image choices are built (§11, decision 0016). `choose(style = "pictures"):` shows picture cards, each option's picture named with the new `@picture` annotation (§4.6, §4.8). Choice styles now have a registry: `StoryConfig.choice_styles` adds menus, and game code can add any object as a style at runtime, which is the hook for choices made by clicking objects in a 2D or 3D scene. This is also the first extension point Pro needs (§12.4).
- Chapter 1's rain choice is now a picture choice, with three generated pictures, and the card editor shows a picture field for options of picture choices.
- Compiled tales move to format 4 for option pictures.

Changes in v0.18:
- M6 progress: the route chart is built (§11). Extras has a Routes tab showing each beat the player has reached, grouped by tale, the ways they went between beats, and the choices they met, with options never shown left out. Beats are named on the chart with the new `@heading` annotation (§4.8). The record covers every playthrough and is saved with the global data (§10, decision 0015).
- Compiled tales move to format 3 for the headings, so Godot imports existing tales again.
- The demo names its beats with headings in English and Spanish, and the tour mentions the chart.

Changes in v0.17:
- The free and Pro split is decided (decision 0014, §12.2). Free covers everything needed to make and ship a complete game, including every system players see and the whole visual editor; Pro covers production tools and extra presentation content.
- The route chart and image choices are free (§7), which closes question 5 (§19). Pro keeps the hotspot authoring tool, messenger replies, and story analytics.
- New §12.4 lists the extension points the free tier must add before Pro work starts: a choice style registry (built with image choices in M6), transition registration, and editor hooks (M7, now 4 weeks; 1.0 moves to about 34 weeks).

Changes in v0.16:
- The MIT license is reconfirmed after weighing Apache 2.0, MPL 2.0, and source-available licenses (§13). The name and the Pro tier are protected by a trademark, Pro's own EULA, and a contributor agreement, not by the free tier's license.

Changes in v0.15:
- M6 progress: inline text tags, CGs, character renames, character animations, per-character data, the save screen, and presentation details are built (§11). The reference sections describe them: vocabulary (§3), markup (§4.5), runtime and layers (§5.1, §5.3), looks and assets (§5.5, §5.6), actions (§6), player-facing systems (§10), and testing (§16).
- CGs draw on a new layer 4, so weather and color filters move to layers 5 and 6 (decision 0013).
- The README now uses "Visual Novel StoryTeller" as its title; the product name question stays open until the trademark search (§19).

Changes in v0.14:
- Brought the reference sections up to date with what is built: vocabulary (§3), statements, markup, and annotations (§4), the runtime structure, configuration, layers, custom actions, looks, and asset finding (§5), the action list (§6), editor tooling (§8), the visual editor as built (§9), player-facing systems (§10), repository layout (§15), testing (§16), and risks (§18). Features described in earlier drafts that are not built are now marked as planned, with a milestone where one exists.
- §7 and §12.2 now match what the free tier already includes: timed choices, rain and snow, color filters, and CSV string export are free. Hotspot and messenger choices, the remaining effects, and the rest of the translation workflow stay Pro.
- Importing open formats such as Yarn Spinner is no longer a non-goal (§1.1), since M6 plans it.
- The setup wizard and documentation guides move to M7 (§11).

Changes in v0.13:
- New milestone M6, "Genre features", from a review of Visual Novel Machinery (an Unreal Engine visual novel plugin). Its feature list showed common genre features StoryTeller lacks: inline text tags, CGs, character renames, character animations, a fuller save screen, per-character data, a player route chart, image choices, and Yarn Spinner import. Each will be designed in StoryTeller's own terms under the originality rules (§2).
- Launch preparation becomes M7, and the 1.0 estimate grows to about 33 weeks.
- New open question on the tier of image choices and the route chart (§19, question 5).

Changes in v0.12:
- M5 features complete: the Story tab has Text, Cards, and Map views of the same file. Edits are line-level and share one undo history (decision 0012).
- A test builds a branching scene from an empty file using only cards and checks that the result matches hand-written TaleScript. The usability test with writers who do not program has not happened yet; it needs people, so it is listed in §20.
- Not built yet from §9.3: a markup toolbar for narration (bold, pause, speed), multi-select, copy and paste between tales, and portrait and mood thumbnails in the pickers. Cards edit fields in place, so there is no separate inspector panel.

Changes in v0.11:
- M4 complete: weather, color filters, flashes, screen fades, movies, the collection and Extras screen, localization through Godot translations (decision 0011), the debug console, live reload, autocomplete in the Story tab, and the dialogue-only embedding preset.
- Both M4 exit criteria are met: the demo is translated into Spanish, and `demo/embedded` runs a conversation inside a small 3D scene.
- The demo gained a full chapter 1. One playthrough takes about 7 to 8 minutes, so the 15-minute demo target moves to M6 with the original sample project (§11).
- Tests now play the whole demo in English and Spanish.

Changes in v0.10:
- M3 features complete: save slots with thumbnails, quick save, autosave before choices, global data, read tracking, settings, rewind with `@no_rewind`, history, `@skip_safe`, the menu set (title, pause, save and load, settings, history, confirmations, text input) with one shared theme, a quick menu, and the "page" dialogue style.
- The demo opens on a title screen and its tour now covers the M3 features.
- Exported games are checked in CI by `tools/check_export.sh`. The check found that cast moods and `.tres` profiles were missing from exported games, and that is fixed.
- The M3 exit criterion is only partly met; see §11.

Changes in v0.9:
- M2 complete: stage, cast members and looks, backdrops with transitions, props, camera, audio, asset preloading, and a demo that plays the §4.2 sample with original generated art and music.

Changes in v0.8:
- M1 complete: the "Story" editor screen adds syntax highlighting, live error checking, and saving with reimport. It is the start of the visual editor's text view (§9).

Changes in v0.7:
- M1 progress: checker, compiler, import plugin, director, classic dialogue box, list choice menu, and a playable demo scene are done.

Changes in v0.6:
- The TaleScript specification now lives in `docs/talescript-spec.md` and is the authoritative reference; §4 below is an overview.
- M1 progress: lexer and lossless parser done (decision 0010).

Changes in v0.5:
- License chosen: MIT (decision 0008, §13).
- Pro tier deferred until the free tier is a working system (decision 0009, §12). Pro features stay listed but are removed from the 1.0 schedule.
- Schedule to 1.0 shortened to about 28 weeks.

Changes in v0.4:
- Godot 4.7.2 confirmed as the supported version.
- M0 setup work started; decisions are now kept as records in `docs/decisions/`.
- A small built-in test runner replaces GUT (decision 0007).

Changes in v0.3:
- Recorded the decisions made so far (§1.2).
- Godot target set to the latest stable release; C# removed from scope.
- The visual editor and Story Map move ahead of 1.0 as a headline feature (§9).
- Added the free and Pro product tiers (§12).
- Added exploration notes for licensing (§13) and target platforms (§14).
- The parser now keeps formatting and comments so text and visual editing stay in sync (§4.10).

Changes in v0.2:
- Replaced the earlier command-style script syntax with TaleScript, a GDScript-flavored language.
- Introduced original terminology and concepts throughout (see §3).
- Added §2, Originality and IP Guidelines.
- Reframed the feature scope around standard visual novel genre features.

---

## 1. Goals

1. **Familiar to Godot users.** Anyone who has written GDScript can read and write TaleScript within minutes: same comments, indentation, `var`, `if`/`elif`/`else`, `match`, `await`, and annotations.
2. **Friendly to writers.** Dialogue reads like a screenplay. A non-programmer can write a full scene after reading a one-page cheat sheet, or build it entirely in the visual editor without typing any syntax.
3. **Batteries included.** A new project gets a working title screen, save/load, settings, history log, and dialogue box out of the box.
4. **Godot-native.** Built on nodes, resources, signals, themes, tweens, shaders, `RichTextLabel` effects, and the `TranslationServer`.
5. **Extensible.** Developers add custom actions, cast types, effects, and menus by writing small GDScript classes.
6. **Embeddable.** Works as a standalone visual novel engine and as a dialogue or cutscene system inside 2D and 3D games.
7. **Fast iteration.** Live reload of story files while the game runs, clear errors with file and line, and an in-game debug console.
8. **Usable by a middle schooler (the Studio).** A student of 11 to 14 builds and plays a branching story with blocks in Visual Novel StoryTeller Studio, an app on an iPad or Android tablet, without seeing the Godot editor (decision 0020, `docs/studio-design.md`).

### 1.1 Non-goals for 1.0

- Compatibility with other engines' script formats. (Yarn Spinner scripts, an open format, can be imported since M6; StoryTeller does not read commercial engines' formats.)
- A general-purpose visual programming language. The visual editor (§9) covers story content; game logic stays in GDScript.
- C# support. GDScript classes remain callable from C# through Godot's normal interop, and a dedicated C# API can be revisited after 1.0.
- Spine or Live2D support in the core package (possible later add-ons).
- Multiplayer storytelling.
- Godot 3.x support, or Godot 4 versions older than the current stable release.

### 1.2 Decision log

| # | Date | Decision |
|---|---|---|
| D1 | 2026-10-08 | Existing toolkits define the feature scope only. StoryTeller uses its own language, vocabulary, and design (§2). |
| D2 | 2026-10-08 | The story language follows GDScript conventions (TaleScript, §4). |
| D3 | 2026-10-08 | Target the latest stable Godot release, currently 4.7.2 (§1.3). |
| D4 | 2026-10-08 | No C# support for now. |
| D5 | 2026-10-08 | Names accepted: TaleScript, `.tale` files, `beat` blocks. |
| D6 | 2026-10-08 | The visual editor ships before 1.0 as a key differentiator (§9). |
| D7 | 2026-10-08 | Business model: free base tier plus a paid Pro tier (§12). Superseded by D13. |
| D8 | 2026-10-08 | MIT license for StoryTeller (§13). Reconfirmed 2026-10-09. |
| D9 | open | Target platforms and their order (exploring, §14). |
| D10 | 2026-10-08 | Built-in test runner instead of GUT. |
| D11 | 2026-10-08 | Pro tier deferred until the free tier is a working system (§12). Superseded by D13. |
| D12 | 2026-10-09 | Free and Pro split: free ships complete games, Pro saves production time (§12.2, decision 0014). Superseded by D13. |
| D13 | 2026-10-12 | Everything is open source; no Pro tier (§12, decision 0019). Supersedes D7, D11, and D12. |
| D14 | 2026-10-12 | Two products: Visual Novel StoryTeller, the Godot plugin for adults, and Visual Novel StoryTeller Studio, a block-based story builder for students as an app for iPads and Android tablets (decision 0021), with a textbook for teachers (§9.6, decision 0020). |

From M0 onward, each decision has a full record in `docs/decisions/`.

### 1.3 Godot version policy

- StoryTeller targets the **latest stable Godot 4 release**, currently **4.7.2**.
- When a new stable minor version ships (for example 4.8), StoryTeller moves to it in its next minor release, after the first patch release of that Godot version (x.y.1) to avoid early regressions.
- CI runs against the supported version and also tests the newest Godot beta as a non-blocking job, giving early warning of breaking changes.
- New Godot features (typed dictionaries, newer editor APIs, improved web export) can be used freely, since older versions are out of scope.

---

## 2. Originality and IP Guidelines

Complete commercial toolkits for other engines are the reference for the overall **scope** of the project: a script-driven visual novel toolkit with strong editor support. StoryTeller must be an independent work. General ideas and genre conventions (dialogue boxes, branching choices, save slots, rewind, galleries) are common to the whole visual novel field and appear in many engines such as Ren'Py, TyranoBuilder, Dialogic, and Ink-based tools. Specific expression (source code, documentation text, names, file formats, sample content, art, UI layouts) belongs to its authors.

The project follows these rules:

1. **Clean-room development.** Contributors do not read, copy, or translate the source code of commercial visual novel toolkits. Inspiration comes only from publicly visible, feature-level information (what a feature does for the user), and every design is written fresh from that.
2. **Own language.** TaleScript is designed around GDScript conventions. It does not reuse another toolkit's line prefixes, command names, parameter syntax, or file extension.
3. **Own vocabulary.** StoryTeller uses its own terms for its concepts (see §3). Terms specific to other toolkits are avoided in code, docs, and UI.
4. **Own documentation and samples.** All docs, tutorials, example characters, stories, art, audio, and UI designs are original. No paraphrasing of another product's documentation.
5. **Own architecture.** Systems are organized around Godot's node and resource model, which naturally produces a different structure from toolkits built for other engines.
6. **Trademarks.** Public materials (store listing, website, README, marketing) and the documentation do not name the toolkits that served as the scope reference, do not use other products' branding, and do not claim compatibility with or affiliation to commercial toolkits. Formats StoryTeller imports, such as Yarn Spinner scripts, are named only to describe the import.
7. **Decision log.** Major design decisions are recorded in `docs/decisions/` with the reasoning behind them, which documents independent development.
8. **Legal review.** Before the public 1.0 release, the maintainers obtain a review from a lawyer familiar with software IP, covering this section, the license (§13), the project policies (`PRIVACY.md`, `TRADEMARKS.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, and the DCO sign-off in `CONTRIBUTING.md`), and a trademark search for the product name. This plan is general guidance and does not constitute legal advice.

---

## 3. Core Concepts and Vocabulary

StoryTeller uses a **theater** metaphor. Every term below is used consistently in code, docs, and the editor.

| Term | Meaning | Godot building block |
|---|---|---|
| **Tale** | A story file written in TaleScript (`.tale`) | Imported as a `Tale` resource |
| **Beat** | A named section of a tale that can be jumped to or called | Parsed block, similar to a `func` |
| **Stage** | The on-screen area where the story is presented | `CanvasLayer` stack inside a `StoryStage` scene |
| **Cast member** | A character that can enter, leave, move, and change mood | `CastMember` node with a pluggable look |
| **Look** | How a cast member is drawn (sprite set, layered rig, custom scene, video) | `CastLook` resource |
| **Mood** | A named appearance of a cast member, e.g. `"smile"` | Texture, layer combination, or animation name |
| **Backdrop** | Full-screen scenery behind the cast | `BackdropView` with a transition shader |
| **CG** | A full-screen event picture that covers the stage at a story moment and joins the gallery, with variants | `BackdropView` on the stage's CG layer; images in `story/cgs/` |
| **Prop** | Any extra object placed on stage (item, overlay, custom scene) | Image or `Node2D` scene on the stage's prop layer |
| **Dialogue box** | UI that shows lines of text | `DialogueBox` scene with interchangeable styles |
| **Choice menu** | UI that presents options to the player | `ChoiceMenu` scene with interchangeable styles |
| **Action** | A built-in or custom function callable from TaleScript, e.g. `backdrop()` | `TaleAction` class |
| **Director** | The runtime that executes tales | `TaleDirector` node |
| **Crew** | The set of runtime systems (audio, camera, saves, etc.) | Child nodes of the `Story` autoload |
| **Story vars** | Variables saved per playthrough | Dictionary in save data |
| **Global vars** | Variables shared across all playthroughs (`@global`) | Separate persistent file |
| **Rewind** | Stepping back to earlier lines | Snapshot ring buffer |
| **History** | Scrollable log of past lines with voice replay | `StoryHistory` crew member and history screen |
| **Collection** | Unlockable gallery images, music, and codex entries | `StoryCollection` crew member, `CollectionItem` resources, Extras screen |
| **Cards** | The visual editor's view of a beat, one card per statement | `TaleCardEditor` in the Story tab |
| **Story Map** | Editor view of beats and the links between them | `StoryMapView` (`GraphEdit`) in the Story tab |
| **Route chart** | Players' view of the beats they have reached and the choices they made, in Extras | `RouteLog` kept by the director, drawn by `RouteChartView` |

---

## 4. TaleScript Language

> The full, authoritative definition is in [`docs/talescript-spec.md`](talescript-spec.md). This section is an overview.

### 4.1 Design principles

- **GDScript first.** If GDScript has a way to express something, TaleScript uses the same form: `#` comments, `##` doc comments, tab or space indentation with `:` block headers, `var`/`const`, `:=` inference, optional type hints, `if`/`elif`/`else`, `match`, `and`/`or`/`not`, `await`, and `@annotations`.
- **Dialogue is the lightest thing to type.** A spoken line is a speaker and a quoted string. Narration is a bare string.
- **Small, deliberate additions to GDScript**, each justified by story writing needs:
  1. Dialogue and narration statements.
  2. `beat` blocks (like `func`, but resumable and saveable).
  3. `jump` for one-way flow.
  4. `choose:` blocks for player choices.
  5. Named arguments in action calls (`fade = 0.5`), since story actions often have many optional settings.
- Anything that would surprise a GDScript user is avoided.

### 4.2 Sample tale

```gdscript
## prologue.tale
## The first morning at school.
@title("Prologue")

var trust := 0
@global var prologue_done := false

beat start:
	backdrop("classroom_morning", transition = "fade", time = 1.0)
	music("quiet_morning", volume = 0.8)
	mira.enter("smile", at = LEFT)

	"Sunlight spills across rows of empty desks."
	mira: "You're here early.[pause] Couldn't sleep?"
	mira (curious): "Nervous about the exam?"

	choose:
		"Admit you were nervous":
			trust += 1
			jump honest
		"Act like everything is fine":
			jump bluff
		"Change the subject" if trust > 2:
			mira: "Smooth. Really smooth."

beat honest:
	mira (soft): "Same here, honestly."
	await mira.move_to(CENTER, time = 0.6)
	mira: "Want to study together at lunch?"
	jump walk

beat bluff:
	mira (smirk): "Look at you, all confident."
	jump walk

beat walk:
	if trust > 0:
		mira: "Let's head out, {player_name}."
	else:
		mira: "Well. See you in class."

	mira.exit(transition = "slide_left")
	prologue_done = true
	jump chapter_1.start
```

### 4.3 Statements

| Statement | Form | Notes |
|---|---|---|
| Narration | `"text"` | Shown in the active dialogue box with no speaker. |
| Dialogue | `speaker: "text"` | `speaker` is a cast member id or a `const` name string. |
| Dialogue with mood | `speaker (mood): "text"` | Screenplay-style parenthetical; changes mood then speaks. |
| Long text | `speaker: """..."""` | Multi-line strings, as in GDScript. |
| Beat | `beat name:` | Named, indented block. |
| Jump | `jump beat` / `jump tale.beat` | One-way transfer. |
| Call a beat | `beat_name()` / `tale.beat_name()` | Runs the beat and comes back, like calling a function. `return` exits early. |
| Variables | `var x := 0`, `x += 1` | File-level `var` is a story var. `@global var` persists across playthroughs. Beat-level `var` is temporary. |
| Constants | `const HERO := "Alex"` | |
| Conditionals | `if` / `elif` / `else` | Same as GDScript, including single-line form `if x: jump y`. |
| Pattern match | `match value:` | Same pattern syntax as GDScript (literals, `_`, arrays, guards with `when`). |
| Loops | `while cond:` / `for x in list:` | A loop that runs 100,000 steps without showing a line or choice is stopped and reported. |
| Choices | `choose:` block | Each option is a string, optional `if` condition, and an indented body. |
| Actions | `name(args, key = value)` | Built-in or custom actions. Return immediately unless awaited. |
| Waiting | `await action(...)` / `await mira.move_to(...)` | Blocks until an action or cast member method finishes. |
| Signals | `emit("door_opened", arg)` | Notifies game code. |
| Annotations | `@title`, `@global`, `@once`, `@show_disabled`, `@id`, `@voice`, `@no_rewind`, `@skip_safe`, `@heading` | See §4.8. |

### 4.4 Actions and timing

Actions mirror Godot's async model:

- An action call **starts** its effect and returns immediately, so several effects can run at the same time.
- `await` before an action blocks the tale until that action completes, exactly as `await` works with tweens and signals in GDScript.
- Before any dialogue, narration, or choice appears, the director waits for running actions to finish. This keeps simple tales in order with no `await` at all. `@no_wait` shows one line or choice at once, and `StoryConfig.wait_for_actions = false` turns waiting off for the project (M7).

```gdscript
mira.enter("smile", at = LEFT)          # starts sliding in
jonas.enter("neutral", at = RIGHT)      # slides in at the same time
await camera.zoom(1.2, time = 0.8)      # tale waits for the zoom
shake(0.3)                              # fires and continues
"The door slams open."                  # waits for the shake, then shows text
```

Cast members are objects with methods and properties:

```gdscript
mira.enter("smile", at = LEFT)
mira.mood = "angry"
mira.move_to(Vector2(0.7, 0.0), time = 0.5)
mira.tint = Color.GRAY
mira.flip = true
mira.exit()
```

### 4.5 Text markup

Dialogue strings use Godot's BBCode, so all `RichTextLabel` formatting works (`[b]`, `[i]`, `[color=red]`, `[wave]`, `[shake]`). StoryTeller adds a few tags of its own:

| Tag | Effect | Status |
|---|---|---|
| `[pause]` | Wait for the player to continue, then keep typing on the same line. | Built |
| `[pause=0.5]` | Wait half a second. | Built |
| `{expression}` | Insert a value, e.g. `{player_name}` or `{gold * 2}`. | Built |
| `[speed=2.0]...[/speed]` | Type a span at a multiple of the text speed; spans nest and multiply. | Built (M6) |
| `[instant]...[/instant]` | Show a span at once, without typing. | Built (M6) |
| `[sound=bell]` | Play a sound when typing reaches this point. | Built (M6) |
| `[act=shake(0.2)]` | Run any expression, usually an action, when typing reaches this point; `[act=await wait(1)]` holds the typing. | Built (M6) |

The checker validates `[act]` and `[sound]` like `{expression}` values and reports bad `[speed]` and `[pause]` values. Choice options leave out `[act]` and `[sound]`, and the history and save slots show text without these tags. The default theme draws `[code]` in a tinted monospace font (`code_color` for the `DialogueBox` theme type). Named text styles (`StoryConfig.text_styles`) turn `[whisper]...[/whisper]` and others into formatting; the defaults are whisper, shout, and thought.

### 4.6 Choices

```gdscript
choose:
	"Open the door":
		jump hallway
	"Knock first" if not knocked:
		knocked = true
		"You knock twice."
	@once "Ask about the key":
		mira: "I lost it last week."
	"Leave" if has_item("map"):
		jump exit
```

- Options with a false `if` are hidden by default, or shown disabled with `@show_disabled`.
- `@once` options disappear after being chosen in the current playthrough.
- `choose(timeout = 5.0):` adds a countdown; the `timeout:` branch runs when time expires. (Built.)
- `choose(style = "pictures"):` shows options as picture cards, each picture named with `@picture("umbrella")` on the option. (Built.) Other styles come from `StoryConfig.choice_styles` or from game code (decision 0016); hotspot and messenger styles are planned for 1.x (§12).

### 4.7 Expressions and game code

- Expressions use GDScript's operators and literals: arithmetic, comparison, `and`/`or`/`not`, `in`, `%`, ternary `a if cond else b`, arrays, dictionaries, `Vector2`, `Color`.
- Built-in functions: `abs`, `ceil`, `floor`, `round`, `clamp`, `min`, `max`, `randf`, `randi`, `randf_range`, `randi_range`, `len`, `str`, `int`, `float`, `visited("tale.beat")`, `collected("id")`, `tr("key")`, and the constructors `Vector2`, `Vector2i`, `Vector3`, `Color`, `Rect2`.
- Game code exposes objects and functions to tales explicitly:

```gdscript
# In game code (GDScript)
Story.expose("inventory", $Inventory, ["has", "add", "remove"])
Story.expose_function("day_of_week", func(): return calendar.weekday)
```

```gdscript
# In a tale
if inventory.has("lantern"):
	"The lantern flickers to life."
	inventory.remove("oil")
```

Only exposed members are reachable. Tales cannot call arbitrary engine methods, which keeps user content safe. List exposed names in `StoryConfig.exposed_names` so tales that use them import without errors and the Story tab suggests them.

### 4.8 Annotations

| Annotation | Purpose |
|---|---|
| `@title("...")` | Display name of a tale (save slots, Story Map). |
| `@global` | Marks a `var` as shared across playthroughs. |
| `@once` | Choice option that disappears after it is chosen in a playthrough. |
| `@show_disabled` | Choice option shown greyed out when its condition is false. |
| `@no_rewind` | Prevents rewinding past this point (e.g. after a mini-game). |
| `@id("intro_04")` | Pins a stable id (for translation, read tracking, and `@once`) to a line or choice option. |
| `@voice("mira_004")` | Assigns a voice clip to the next line. |
| `@skip_safe` | Marks a beat's lines as already read for skipping. |
| `@heading("The walk home")` | Names a beat in the players' route chart. |
| `@picture("umbrella")` | Picture for a choice option in the "pictures" choice style. |

### 4.9 Why an interpreter instead of compiling to GDScript

Compiling tales to real GDScript was considered. It was rejected because a running GDScript coroutine cannot be serialized, which makes saving mid-scene, rewinding, and live reload impossible. TaleScript instead compiles to a compact instruction list that the director executes. Each instruction has a position (`tale`, `beat`, index path), so the full execution state (position, call stack, variables, stage state) fits in a save file.

### 4.10 Compilation pipeline

```
.tale ─▶ Lexer ─▶ Parser ─▶ Syntax tree (lossless) ─▶ Checker ─▶ Compiler ─▶ Tale resource (instructions + metadata)
                                   ▲        │
                                   └────────┴──▶ Visual editor reads and edits the same tree, then writes text back
```

- The parser produces a **lossless syntax tree**: comments, blank lines, indentation style, and spacing are kept. The visual editor (§9) edits this tree and writes it back, so a change made visually alters only the affected lines and produces clean diffs in version control. This requirement shapes the parser from M1 onward.
- Runs in an `EditorImportPlugin`, so errors appear in the Output panel with clickable `file:line`.
- The **checker** reports unknown actions, wrong argument types, unknown beats, undefined variables, unknown cast members or moods (warnings), asset names that match no file (warnings), unreachable code, and indentation problems.
- Every dialogue line and choice option receives a **line id** (beat name plus a content hash, or a pinned `@id`). Translations are keyed `<tale>:<id>` (decision 0011). **Pin Line IDs** in the Story tab writes `@id` in front of every line that has none, so later edits never change them (M7).
- The same parser and compiler run in the game for live reload (§8). Tales outside the project, such as player-made stories in `user://mods`, load with `TaleDirector.load_tale_folder()` or from `StoryConfig.mod_folder` at start (M7). They can refer to each other and replace project tales of the same name.

---

## 5. Architecture

### 5.1 Runtime structure

The `Story` autoload creates the crew members listed in `StoryConfig.crew`, in this order (class, then the name used with `Story.get_crew()`):

```
Story (autoload)
├── TaleDirector     "TaleDirector"  runs tales: instructions, await, call stack, variables,
│                                    expression evaluation, skip and auto, read tracking,
│                                    the route record,
│                                    translation lookup, live reload
├── StoryStage       "Stage"         backdrops, cast members and looks, props, CGs, camera,
│                                    asset preloading
├── StoryAudio       "Audio"         music crossfade, sounds, ambience, voice on audio buses
├── StoryEffects     "Effects"       weather, color filters, flashes, screen fades, movies
├── StoryCollection  "Collection"    gallery (with CG variants), music room, and codex unlocks
├── StorySaves       "Saves"         slots, quick save, autosave, thumbnails, global data
├── StorySettings    "Settings"      player preferences and language
├── StoryRewind      "Rewind"        snapshots for stepping back
├── StoryHistory     "History"       log of past lines
├── StoryDialogue    "Dialogue"      dialogue box styles, choice styles, input actions
├── StoryMenus       "Menus"         title, pause, save and load, settings, history, Extras,
│                                    confirmations, text input, quick menu, notices
└── StoryConsole     "Console"       debug console (debug builds only)
```

Every crew member extends one small base class:

```gdscript
class_name StoryCrew extends Node

func get_crew_name() -> StringName      # key for Story.get_crew() and save data
func setup(config: StoryConfig) -> void
func clear() -> void                    # new game
func capture() -> Dictionary            # state for saves and rewind
func restore(data: Dictionary) -> void
func teardown() -> void
```

Crew members with `capture_globals()` and `restore_globals()` also keep data across playthroughs in the global save file. Projects can replace any crew member with a subclass, or leave members out, through `StoryConfig.crew`. `StoryConfig.dialogue_only()` returns a smaller crew for games that only need conversations (director, audio, saves, settings, history, dialogue).

### 5.2 Configuration

- One `StoryConfig` resource holds every setting, grouped in the inspector (Game, Stage, Audio, Effects, Extras, Localization, Saves, Dialogue). The project setting `storyteller/config_path` points to it (default `res://story/story_config.tres`); without one, defaults are used.
- A **setup wizard** that creates the config, folders, and a sample tale on first enable is planned for M7.

### 5.3 Stage layers

Canvas layers from back to front: the game's own canvas (0), backdrops (1), cast (2), props (3), CGs (4), weather (5), color filter (6), dialogue box and choices (10), flashes, screen fades, and movies (15), menus (20), notices (21), and the debug console (50). The backdrop is transparent until a tale shows one, so dialogue can sit on top of a game's 2D or 3D scene; `StoryConfig.dialogue_only()` leaves the stage out entirely.

### 5.4 Custom actions

```gdscript
extends TaleAction
## lightning(time = 0.3): flashes the screen and plays thunder.

func get_action_name() -> String:
	return "lightning"

func run(ctx: TaleContext, time: float = 0.3) -> void:
	var audio := ctx.get_crew(&"Audio") as StoryAudio
	if audio != null:
		audio.play_sound("thunder")
	var effects := ctx.get_crew(&"Effects") as StoryEffects
	if effects == null:
		ctx.fail("lightning() needs the Effects crew member.")
		return
	await effects.flash(Color.WHITE, time)
```

- Save it in `StoryConfig.action_folder` (`res://story/actions` by default), list it in `StoryConfig.actions`, or register it from code with `TaleDirector.add_action(preload("action_lightning.gd").new())`. Scripts in the folder that extend `TaleAction` are found when the story starts and by the Story tab (M7). Built-in actions are listed in `TaleDirector.BUILTIN_ACTIONS`.
- Parameters are read from the `run` signature, so the checker and the visual editor's action forms know names, types, and defaults.
- Skipping makes effects finish at once (crew members check the director's `skipping` flag), and loading or rewinding stops the running beat through the director's generation counter, so actions never need their own cancellation code.

### 5.5 Cast looks

| Look | Description |
|---|---|
| `SpriteSetLook` | One texture per mood, found by folder convention or explicit table. |
| `LayeredLook` | Builds a character from named layer groups (body, outfit, face, accessory). Mood strings like `"face=smile, outfit=coat"`. |
| `SceneLook` | Any `PackedScene`; moods map to `AnimationPlayer` animations, and `animate(name)` plays any named animation. |
| `ViewportLook` | A 3D scene rendered into its own viewport and shown like a sprite, with moods and `animate()` as for `SceneLook`. Adds a camera, a light, and ambient light when the scene has none (M7). |
| `VideoLook` | `VideoStreamPlayer`, one clip per mood. Planned for 1.x, not built. |

Built cast extras: display name (translatable), name color, scale, default mood, and speaker highlighting (others are dimmed). From M6: renaming during play (`display_name`, saved and translated), `hop()`, `shake()`, and `nod()` (they move only the look, so they combine with `move_to()`), `animate(name)` for scene looks, and a saved `draw_order` with `to_front()` and `to_back()`. Cast methods report problems to the tale through the director. From M7: per-character typing sounds (`CastProfile.typing_sound`) and dialogue box portraits, one image per mood from `CastProfile.portrait_folder`, optionally shown only while the character is off stage, a text color per character (`CastProfile.text_color`), and lip-flap: while a voiced line plays, the speaker switches between a mood and its `<mood>_talk` frame. From M6 too: per-character data, declared in `CastProfile.fields` and used as `ada.affection`, checked by the checker, offered by autocomplete, and saved.

### 5.6 Asset finding

- Assets are found by name in folders set in `StoryConfig`: `cast/<id>.tres` or `cast/<id>/<mood>.png`, `backdrops/<name>.png`, `props/`, `cgs/<name>.png` or `cgs/<name>/<variant>.png`, `audio/music/`, `sounds/`, `ambience/`, `voice/`, `movies/`, and `collection/`. Folders are read with `ResourceLoader.list_directory`, so exported games find the same files.
- When a beat starts, the director asks crew members to load the assets it names in the background (`ResourceLoader.load_threaded_request`). There is no memory budget yet.
- A missing asset is reported when the line runs. The checker also warns, as the tale is written, about asset names that match no file: backdrops, CGs, props, music, sounds, ambience, voice clips, movies, and collection items given as plain strings (M7).

---

## 6. Built-in Actions

Built (the full reference with arguments is §13 of `docs/talescript-spec.md`):

| Group | Actions |
|---|---|
| Scenery | `backdrop()`, `prop()`, `hide_prop()`, `clear_props()`, `cg()`, `hide_cg()` |
| Cast | members `enter()`, `exit()`, `move_to()`, `scale_to()`, `hop()`, `shake()`, `nod()`, `animate()`, `to_front()`, `to_back()`, `mood`, `tint`, `flip`, `on_stage`, `display_name`, `draw_order`, and the fields from the cast profile; action `exit_all()` |
| Dialogue | `dialogue_style()`, `hide_dialogue()`, `clear_page()` |
| Audio | `music()`, `stop_music()`, `sound()`, `ambience()`, `stop_ambience()`, `voice()`, `stop_audio()` |
| Camera | `camera.zoom()`, `camera.pan()`, `camera.rotate()`, `camera.shake()`, `camera.reset()`, and the action `shake()` |
| Effects | `flash()`, `fade_out()`, `fade_in()`, `weather()`, `filter()`, `play_movie()` |
| Flow | `wait()`, `autosave()`, `emit()` |
| Player input | `ask_text()`, `ask_number()` |
| Collection | `collect()` |

Planned: the remaining M6 items (§11). Considered in earlier drafts and not scheduled: `line_up()`, `skip_lock()`, `change_scene()`, and a manual `preload()` (beats already preload their assets). Generated reference docs for actions are part of M7.

---

## 7. Feature Scope

Standard visual novel genre features, with the milestone (§11). Everything is free and open source (decision 0019). Features once planned for a Pro tier show M8 (the Studio) or 1.x (§12).

| Feature | Description | Milestone |
|---|---|---|
| TaleScript | Language, compiler, checker, syntax highlighting | M1 |
| Director | Execution, await, call stack, skip and auto modes | M1 |
| Variables and expressions | Story vars, global vars, safe evaluator, exposure API | M1 |
| Dialogue box: classic | Bottom box with name plate and typewriter text | M1 |
| Choice menu: list | Vertical button list | M1 |
| Cast looks: sprite set, layered, scene | Characters from textures, layer rigs, or any Godot scene | M2 |
| Cast look: video | Characters from video clips | 1.x |
| Backdrops and props | With transitions | M2 |
| Core transitions | Fade, dissolve with mask texture, slide, wipe | M2 |
| Transition pack | Iris, pixelate, ripple, shatter, page turn, custom shader templates | 1.x |
| Audio | Music crossfade, sounds, voice, ambience, buses | M2 |
| Camera | Zoom, pan, shake, rotate | M2 |
| Saves | Slots with thumbnails, quick save, auto save, global data, versioned format | M3 |
| Rewind and history | Step back through lines and choices; log with voice replay | M3 |
| Dialogue style: full page | Full-screen text for prose-heavy scenes | M3 |
| Dialogue styles: bubble, messenger, caption | Speech bubbles, phone-chat stories, cinematic captions | 1.x |
| Timed choices | Countdown with a `timeout:` branch | M1 |
| Choice styles: hotspots, messenger reply | Hotspot authoring tool (clickable regions drawn over a backdrop in the editor), chat replies | 1.x |
| Menus and default theme | Title, pause, save/load, settings, history, confirm, loading, text input | M3 |
| Theme and template pack | Extra polished themes and genre starter projects (mystery, romance, messenger story) | M8 (Studio templates), 1.x (themes) |
| Basic effects | Flash, fade to color, rain and snow, color filters, blur, and vignette | M4 |
| Effects pack | Fog, light rays, glitch, film grain, particle presets | 1.x |
| Collection | Gallery, music room, codex | M4 |
| Localization | Godot translations, language setting, CSV string export that keeps translations (decision 0011) | M4 |
| Translation workflow | `.po` export, missing-line reports, translator preview mode | 1.x |
| Voice production tools | Per-actor voice scripts, automatic clip mapping by line id, lip-flap from audio | 1.x |
| Debug console | Run TaleScript lines, inspect and edit vars, jump to beats | M4 |
| Live reload | Edit a tale during play and continue from the same line | M4 |
| Movies | Full-screen video playback | M4 |
| Embedding preset | Dialogue-only mode for 2D and 3D games, trigger tales from game events | M4 |
| Visual editor | Card-based editing of tales, synced with text (§9) | M5 |
| Story Map | Graph of beats, jumps, calls, and choices (§9) | M5 |
| Visual Novel StoryTeller Studio | Block-based story builder for students, an app for iPads and Android tablets, with a live stage preview (§9.6) | M8 |
| Stage preview and play from here | Live preview of the stage at any line; launch the game from that line | M8 (the Studio); 1.x in the Story tab |
| Story analytics | Route coverage, word counts per character, choice statistics from playtests | 1.x |
| Inline text tags | Typing speed, instant spans, sounds and actions at points in a line | M6 |
| CGs | Event pictures on their own layer that unlock gallery entries, with variants | M6 |
| Character names during play | Rename cast members from tales; saved and translated | M6 |
| Character animations | Hop, shake, nod, named animations, drawing order | M6 |
| Save screen paging | Unlimited slots in pages, delete and label saves, timed autosave | M6 |
| Per-character data | Fields declared in cast profiles, such as affection | M6 |
| Route chart | Player-facing map of explored branches without spoilers | M6 |
| Image choices | Choices as pictures; a hook for in-world choices in 2D and 3D scenes | M6 |
| Yarn Spinner import | Convert Yarn Spinner scripts into tales | M6 |
| Language server | Autocomplete and diagnostics in VS Code and other editors | Post-1.0 |

---

## 8. Editor Tooling

| Tool | Description | Milestone |
|---|---|---|
| Story screen | Main-screen editor for `.tale` files: syntax highlighting in the editor's colors, live problem list, save and reimport | M1 ✔ |
| Import diagnostics | Errors and warnings in the Output panel and the Story tab's problem list | M1 ✔ |
| Autocomplete | Completion for actions, cast ids, moods, beats, variables, annotations, camera and cast members | M4 ✔ |
| Live reload | A running game recompiles a tale whose file changed and continues at the same line | M4 ✔ |
| Export Strings | Writes the translation CSV and registers it (Story tab button or command-line script) | M4 ✔ |
| Visual editor and Story Map | Cards and Map views; see §9 | M5 ✔ |
| Setup wizard | Config, folders, starter scene, sample tale (Story tab, while the project has no StoryConfig) | M7 ✔ |
| Pin line ids | Write `@id` into every line so edits never change ids (**Pin Line IDs** in the Story tab) | M7 ✔ |
| Cast inspector | Custom inspector with mood previews and a "test enter" button | Not scheduled |
| Language server | LSP for VS Code and other editors | Post-1.0 |

---

## 9. Visual Editor and Story Map

The visual editor lets writers build complete tales without typing syntax, while programmers keep working in text. It is a headline feature and a major point of difference from other visual novel tools.

### 9.1 Principles

1. **One source of truth.** The `.tale` file is always the saved format. The visual editor and the text editor are two views of the same file, and a change in either appears in the other immediately.
2. **Clean round trips.** Visual edits change only the affected lines and keep comments and formatting (§4.10), so writers and programmers can work on the same files in version control.
3. **Nothing is lost.** Any code the visual editor cannot represent as a card appears as an editable "script card" holding the raw text.
4. **Godot-native.** Built as a main-screen editor plugin (a "Story" tab next to 2D, 3D, Script, and AssetLib), using Godot's own controls and theme. Undo uses the text editor's own history, so it is shared by all views (decision 0012).

### 9.2 Layout

As built in M5:

```
┌──────────────────────────── Story tab ─────────────────────────────┐
│ path            [Refresh] [Export Strings] [Text|Cards|Map] [Save] │
├────────────┬───────────────────────────────────────────────────────┤
│ Tale list  │ Text:  TaleScript editor with highlighting and         │
│            │        autocomplete                                    │
│ prologue   │ Cards: beat list │ cards of the selected beat, edited  │
│ chapter_1  │                  │ in place (lanes for choices and     │
│ welcome    │                  │ conditions)                         │
│            │ Map:   beats of the folder as a graph                  │
│            ├───────────────────────────────────────────────────────┤
│            │ Problem list                                           │
└────────────┴───────────────────────────────────────────────────────┘
```

Cards are edited in place, so there is no separate inspector. The stage preview (§9.5) comes first in the Studio, then in the Story tab.

### 9.3 Cards

| Card | Editing controls (as built) | Not built yet |
|---|---|---|
| Narration | Text field with a markup toolbar: bold, italic, pause, timed wait, slow, fast, sound, and the project's named text styles. Buttons wrap the selected text or insert at the cursor | |
| Dialogue | Speaker and mood pickers with a thumbnail of each character and mood, text field with the same markup toolbar | |
| Choice | One lane per option with text, condition, `@once`, show-disabled, and nested cards | |
| Condition | If, else if, and otherwise lanes with a condition field and a **Build…** dialog: compare a variable with a value, or test a visited beat or collected item, then replace the condition or join it with `and` or `or`. Choice options have the same builder | |
| Action | Form from the action's signature: typed fields, color picker, lists of matching assets, transitions, and moods, with pictures of backdrops, CGs, props, and moods, a "wait until it finishes" switch | |
| Jump / run beat | Field with a list of beats in this and other tales; typing part of a name narrows the list | |
| Set variable | Variable with a list of this tale's variables, other tales' (`tale.variable`), and cast fields (`mira.friendship`); operator; value | |
| Comment | Text field | |
| Script | Raw TaleScript for anything else (loops, `match`, local variables, one-line `if`) | |

Interaction built: add from a menu, move up and down, drag to reorder or into another lane, delete, copy a card (with its nested cards) and paste it in this or another tale, add, rename, and delete beats, problems shown on the card, and undo shared with the text view. Paste also takes TaleScript lines copied from the text view. Choice and Condition cards fold to a one-line summary. From the keyboard, Tab moves between fields, Alt+Up and Alt+Down move the card being edited, and Alt+Insert adds a narration card below it. Clicking card titles selects one card, and Shift+click a range in the same list; copy, delete, the move buttons, the Delete key, and Ctrl+C then act on the whole selection.

### 9.4 Story Map

- Each beat is a `GraphNode`; arrows show jumps, calls, and choice branches, colored by tale.
- Automatic layout with manual adjustment saved to a sidecar file (`.tale.map`), so the tale file itself stays clean.
- Highlights unreachable beats and jumps to missing beats, and marks beats where the story can end.
- Drag from a node's output to empty space to create and link a new beat.
- Double-click a node to open it in the beat editor.
- Tales appear in horizontal bands in the order play reaches them, and beats in columns by step.
- Analytics overlay (1.x, not built): route coverage from playtests and word counts per branch.

### 9.5 Stage preview (the Studio, then 1.x)

Selecting any card shows the stage as it would look at that line. The director runs the tale up to that point in a fast "dry run" mode with all animations skipped, then renders the result in an editor viewport. A "Play from here" button launches the game at the same point with the computed state.

The Studio shows this preview next to its blocks. The Story tab gets the same preview as a side panel through its hooks (§12.3) in a plugin 1.x release.

### 9.6 Visual Novel StoryTeller Studio (M8)

A standalone story builder for middle school students, separate from the plugin (decision 0020). A textbook for teachers goes with it. The full design is in `docs/studio-design.md`.

- A free app for iPads and Android tablets from the App Store and Google Play (decision 0021); students never see the Godot editor.
- Stories are built from Scratch-style blocks in five colored groups (Talk, Act, Scene, Choose, Numbers) that snap together, next to a live stage preview, Play, and Play from here.
- Students add characters, backgrounds, and sounds from a starter library or from their own photos.
- The Studio reads and writes the same `.tale` files through the card model (decision 0012), so a story can move into Godot later. Stories are saved in the app and shared as `.zip` files through the system's share sheet.

---

## 10. Player-Facing Systems

Built:

- **Dialogue boxes:** fade or slide in and out (`StoryConfig.dialogue_box_transition`). Each style extends `DialogueBox` (`show_line`, `hide_box`, `clear_page`, `cancel`, and `reveal` for the typewriter). Two styles ship: "classic" (box with name plate) and "page" (lines collect on a full page). Restyle with a Godot `Theme` (`StoryConfig.theme`) or add styles in `StoryConfig.dialogue_styles`.
- **Choice menus:** each style extends `ChoiceMenu` (`choose`, `cancel`, and `wait_for_pick` for the shared countdown). Two styles ship: "list" (a column of buttons) and "pictures" (picture cards from `@picture`). `StoryConfig.choice_styles` adds scenes, and `StoryDialogue.add_choice_style()` takes any object with an awaitable `choose`, so a game can offer the choices through objects in its own scene.
- **Typewriter:** per character, a whole word at a time, or with letters fading in (`StoryConfig.text_reveal`: "type", "word", or "fade"), speed from settings (0 shows text at once), with the tags in §4.5: `[pause]`, `[speed]`, `[instant]`, and `[act]` and `[sound]` at points in a line. A click while a line types shows it up to the next pause, and tags passed on the way still run. A click anywhere on the dialogue box continues.
- **Title screen:** optional artwork and music (`StoryConfig.title_background`, `title_music`); the music stops when a game starts and comes back after the Extras music room.
- **Extras:** gallery, music room, codex, and route chart. Every CG has a gallery entry that unlocks when the CG is shown; the viewer steps through the variants the player has seen.
- **Route chart:** the Routes tab in Extras draws the beats the player has entered in any playthrough, one band per tale in the order they were reached, with a line for each way they went from one beat to another. Each beat lists the choices met there: picked options with a filled dot, options seen but never picked with an empty one, and options never shown left out, so the chart gives nothing away. Beats show their `@heading`, or their name without one. The director records it in a `RouteLog` saved with the global data. `StoryConfig.show_route_chart` turns it off.
- **Playback controls:** continue (click, tap, Space, Enter), auto (delay scales with line length), skip (read lines only, or all with the setting), rewind (mouse wheel, Page Up), history (H), pause menu (Escape, right click), hide the interface (V, middle click; any press brings it back without continuing), quick save and load (F5, F9). Gamepads work by default (A, shoulders, Start, Y, X, Back). All are `InputMap` actions (`story_*`) that games can rebind. A quick menu sits beside the dialogue box. Settings include a text size that scales every dialogue style.
- **Typing sounds:** a short sound plays as lines type (`StoryConfig.typing_sound`, or a character's own `CastProfile.typing_sound`), every few characters (`typing_sound_every`). Voiced lines stay silent, and players can turn it off in Settings.
- **Saves:** JSON in `user://saves/` with a format number and migration hooks, PNG thumbnails, numbered slots in pages (six per page by default, `StoryConfig.save_slot_count`; as many pages as players fill unless `save_pages` sets a limit) plus quick and auto slots, renaming and deleting saves from the screen, autosave before choices and optionally every few minutes (`autosave_minutes`), and a global file for `@global` variables, read lines, collection unlocks, and the CG variants seen. Setting `StoryConfig.save_key` encrypts slots and the global file with that passphrase (M7); plain saves from before still load.
- **Rewind:** a snapshot of every crew member's `capture()` at each line and choice, up to `StoryConfig.rewind_depth`, with `@no_rewind` barriers. Parts equal to the previous snapshot are shared, not copied.
- **Read tracking:** read line ids kept in global data and used by skip; each line passed to dialogue boxes says whether it was read.
- **Settings:** text speed, auto delay, five volumes, full screen, skipping unread lines, and language. From M7: text size, typing sounds, and high contrast (opaque black panels with white borders and text, and yellow focus, built from the game's own theme by `StoryTheme.high_contrast()`), **Readable font** (the first of Atkinson Hyperlegible, Lexend, Verdana, and other clear fonts the system has, combinable with high contrast), and **Read lines aloud**, which speaks each line with its speaker and the choice options through the system's text-to-speech (`StoryDialogue.speak`, replaceable by game code). It shows only when the system has voices, which needs the project setting `audio/general/text_to_speech`; the setup wizard turns it on. Voiced and skipped lines stay quiet.

Rewind snapshots share every part that did not change since the one before (M7), so a story's stage, audio, and variables are stored once while they stay the same.

---

## 11. Milestones

### M0: Scaffolding (1 week)
- Pin Godot 4.7.2 in CI. ✔
- Addon skeleton (`plugin.cfg`, `EditorPlugin`, autoload registration, `StoryCrew` base, `StoryConfig`). ✔
- Built-in test runner running headless in GitHub Actions on Linux and Windows, plus an optional non-blocking job on the newest Godot beta. ✔
- Contribution guide with the clean-room rules from §2, decision records, issue and pull request templates. ✔
- License file added (MIT). ✔
- ~~Private repository for the Pro add-on.~~ Dropped: there is no Pro tier (decision 0019).

### M1: TaleScript and a minimal playable (5 weeks) ✔
- Formal grammar and specification (`docs/talescript-spec.md`). ✔
- Lexer and **lossless** parser with round-trip and golden tests. ✔
- Checker, compiler, import plugin. ✔
- Director with await, call stack, skip, auto. ✔
- Vars, global vars, safe expression evaluator, `Story.expose`. ✔
- Flow: beats, `jump`, beat calls, `if`/`elif`/`else`, `match`, `choose`. ✔
- Classic dialogue box and list choice menu. ✔
- Syntax highlighting, in a "Story" editor screen with live checking. ✔
- **Exit criteria:** the §4.2 sample runs end to end with placeholder art; parsing and re-printing every fixture reproduces the original file byte for byte. ✔

### M2: Stage, cast, audio (5 weeks) ✔
- Cast looks (sprite set, layered, scene), backdrops, props, core transitions, camera, audio, asset finder with preloading. ✔
- Demo plays the §4.2 sample with original placeholder art and music generated by `tools/demo_assets/generate.py`. ✔
- **Exit criteria:** the §4.2 sample runs with real art, music, and transitions. ✔

### M3: Saves and menus (4 weeks)
- Saves, rewind, history, read tracking, settings. ✔
- Dialogue and choice styles, full menu set with one shared theme. ✔
- Export check in CI: the project is exported as a `.pck` and checked the way a shipped game sees it. ✔
- **Exit criteria:** a 15-minute original demo story exports and plays on the platforms chosen for M3 (§14).
  - Met so far: an exported Linux pack plays the demo from the title screen through saving, loading, and every menu.
  - Still open: Windows and web builds have not been run, since they need export templates and a browser. The platform choice (§14) is also still open. The 15-minute story moved to launch preparation, now M7 (it runs about 7 to 8 minutes after M4).

### M4: Production features (4 weeks) ✔
- Effects, collection, localization, debug console, live reload, autocomplete, movies, embedding preset. ✔
- **Exit criteria:** demo translated into a second language ✔ (Spanish); demo embedded in a small 3D scene ✔ (`demo/embedded`).

### M5: Visual editor and Story Map (6 weeks)
- Story tab, beat editor with all card types, undo and redo. ✔ (cards are edited in place instead of through an inspector)
- Story Map with auto layout and problem highlighting. ✔
- Usability test with at least three writers who do not program. Not done yet. The Studio gets its own classroom test with students later, once it works.
- **Exit criteria:** a writer builds a branching five-minute scene entirely in the visual editor; the resulting file reads naturally as text and diffs cleanly.
  - Met in an automated test (`tests/unit/visual/test_visual_scene.gd`): a branching scene built only with cards matches hand-written TaleScript and checks cleanly.
  - Still open: the same with real writers, which the usability test covers.

### M6: Genre features (5 weeks) ✔
Features most visual novels expect that StoryTeller lacks, found by reviewing Visual Novel Machinery (October 2026). Only the feature ideas come from that review; names, syntax, and designs are StoryTeller's own (§2).
- **Inline text tags:** finish the tags planned in the spec (§7.1 of `docs/talescript-spec.md`): `[speed]` for typing speed, `[instant]` for a span shown at once without typing, `[sound]` at a point in the text, and `[act]` to run an action mid-line. ✔
- **CGs:** full-screen event pictures on their own layer, above the cast and below the dialogue box (`cg()` and `hide_cg()`). Showing a CG unlocks its gallery entry, and one gallery entry can hold several variants of a picture. ✔ (CGs live in `res://story/cgs/` as single images or folders of variants; every CG gets a gallery item, and the gallery shows the variants a player has seen. Weather and filters draw over CGs; the camera does not move them. Decision 0013.)
- **Character names during play:** change a cast member's displayed name from a tale (for example "???" until they introduce themselves, or a name the player types with `ask_text`). The new name is saved and translated like other names. ✔ (Tales assign `mira.display_name`; "" restores the profile name.)
- **Character animations and order:** built-in hop, shake, and nod; playing a named animation on scene-based looks; bringing a character to the front or setting their drawing order. ✔ (`hop()`, `shake()`, `nod()`, `animate(name)` for scene looks, `to_front()`, `to_back()`, and a saved `draw_order`.)
- **Save screen:** as many slots as players want, shown in pages; deleting and labeling saves from the screen; an optional autosave on a timer. ✔ (Six slots per page by default; the grid scrolls when a page is taller than the window.)
- **Per-character data:** fields declared in a cast profile (for example `affection`), used in tales as `ada.affection += 1`, known to the checker and autocomplete, and saved with the story. ✔ (Declared in `CastProfile.fields`; field names that would hide a cast member property or method are refused.)
- **Presentation details:** title screen artwork and music in `StoryConfig`; a show and hide animation for the dialogue box; named text styles set in the config (for example `[whisper]`) that expand to formatting. ✔ (`title_background` and `title_music`; `dialogue_box_transition` "fade" (default), "slide", or "none", instant while skipping; `text_styles` with whisper, shout, and thought.)
- **Route chart for players:** a screen that shows the branches a player has explored, built from read tracking and choice ids, with choices they have not seen kept hidden to avoid spoilers. ✔ (A Routes tab in Extras. The director records beats entered, the links between them, and options seen and picked in a `RouteLog` kept with the global data; beats are named with `@heading`. Decision 0015.)
- **Image choices:** choices shown as clickable pictures, plus a hook so games can let players choose by interacting with objects in a 2D or 3D scene. Free (decision 0014). Built as a second choice style through a new choice style registry, so `choose(style = ...)` picks the menu (§12.4). ✔ (`choose(style = "pictures")` with `@picture("name")` on options, pictures in `StoryConfig.choice_picture_folder`; `StoryConfig.choice_styles` for more menus; `StoryDialogue.add_choice_style()` for game code. Decision 0016.)
- **Yarn Spinner import:** convert Yarn Spinner scripts (an open-source format) into tales, so writers can bring existing dialogue. ✔ (`YarnConverter`: nodes become beats named in snake_case with the node title as `@heading`; speakers that are not cast members become constants; `$variables` become story variables; shortcut options, `<<if>>` chains, `<<set>>`, `<<declare>>`, `<<jump>>`, `<<detour>>`, `<<return>>`, `<<stop>>`, `<<wait>>`, `#line:` ids, and the common functions convert; other commands stay as comments and are listed. Decision 0017.)
- Every new action and cast field gets a card form in the visual editor automatically and is covered by the checker, translation export, and tests.
- **Exit criteria:** the demo uses CGs, a character rename, per-character data, an image choice, and the route chart, in English and Spanish; a sample Yarn Spinner script imports into a tale that plays.
  - Met so far: CGs (chapter 1, `window_table` in two variants), a character rename (Ada in the tour), and per-character data (Mira's `friendship` in chapter 1), in both languages. The demo also uses the text tags and character animations.
  - The route chart: every beat of the demo has a heading in both languages, and the playthrough tests check the chart.
  - An image choice: chapter 1's rain choice shows three pictures in both languages, and the playthrough tests check it.
  - Yarn Spinner import: `demo/yarn/lighthouse.yarn` converts into a tale that checks cleanly and plays through its choices in a test.
- **Progress:** all 10 items are built. Still to do by hand: play the demo to judge timing and feel (§20, step 7).

### M7: Launch preparation (4 weeks)
- Legal review (§2.8).
- The remaining extension points add-ons need (§12.3): transition registration and editor hooks. ✔ (Decision 0018.)
- Setup wizard (§8). ✔ (`StorySetup` makes the story folders, a `StoryConfig`, a first tale, and a main scene that opens the title screen, never overwriting; the Story tab offers it while the project has no config.)
- The documentation guides in §17, including generated action reference pages. ✔
- Full documentation, original sample project (a demo story of at least 15 minutes, carried over from M3), trailer and screenshots. (Progress: chapter 2 adds an exam morning, a timed choice that recalls chapter 1's quiz, a new riverside backdrop, and two endings that follow Mira's friendship. Still to do: time a real playthrough.)
- Publish on the Godot Asset Library or Asset Store and GitHub. (Progress: the plugin zip, an install check in CI, and a release workflow are built; see `docs/publishing.md`. Still to do: set the version, tag the first release, and submit the Asset Library listing.)

### M8: Visual Novel StoryTeller Studio (about 13 weeks)
A block-based story builder for middle school students, shipped as apps for iOS and Android (decisions 0020 and 0021). It runs alongside finishing the plugin's 1.0, and the maintainer writes the textbook once the interface is frozen. Steps from `docs/studio-design.md` §11:
- S0: feasibility check with a test app on a real iPad and Android tablet: start time, dragging with a finger, the on-screen keyboard, choosing a photo and sharing a file, storage after a restart, audio, and the Compatibility renderer; plus the developer accounts and the GitHub Actions builds (1 week).
- S1: Studio shell: home screen, stories in the app's storage, Share and Open as `.zip` (2 weeks).
- S2: blocks: palette, drag and snap, pickers, undo, hints, and a Code block (4 weeks).
- S3: stage preview, Play, and Play from here (2 weeks).
- S4: starter library, and adding the student's own pictures and sounds; story files carry the pictures and sounds they use (1 week).
- S5: map of scenes, starter templates, and the lesson projects and screenshot script the textbook needs; in the plugin, **Open a Studio story**, a check that a story file opens, plays, and exports for the web, and a teacher's guide to publishing a student's story (decision 0022) (2 weeks).
- S6: store listings (privacy details, Kids category, screenshots) and the first test release on TestFlight and Google Play's testing track (1 week).
- **Exit criteria:** every block, the stage preview, the starter library, and sharing work on an iPad and an Android tablet, and a test build is in both stores' testing tracks.
- **Later:** a classroom test with middle school students (`docs/studio-design.md` §1), once the Studio works.
- **Progress (web, decision 0024):** the Studio builds as a web page and passes a browser check in CI. Still to do: try typing, dragging blocks, and picking files on a real iPad and a Chromebook, and choose where to host it.
- **Progress (S5):** in the plugin, **Open a Studio story** in the Story tab adds a story file as its own folder under `res://studio_stories/`, with a `story_config.tres` and a `main.tscn` that plays it (`StudioStoryImport`, `StoryFile`, `StoryLauncher`). `tools/check_studio_story.sh` installs the plugin in an empty project, opens a story file made with the starter art, plays it to the end, and exports it for the web; the Studio workflow runs it. The teacher's guide is `docs/guides/publishing-studio-stories.md`. In the Studio, **Map** beside the scene buttons shows every scene as a box with arrows, marks the start, the endings, scenes nothing leads to, and Go to scene blocks whose scene is gone, and opens the scene a student taps (`studio/map/`). **New story** offers three templates (a mystery, an adventure, and "Choose your path"), and **Lessons** on the home screen starts one of five draft lessons, one for each idea in `docs/studio-design.md` §13, from its start or its finished version (`studio/templates/`, `studio/lessons/`). `tools/studio_screenshots.sh` saves the textbook's screenshots from the lessons and templates, following the shot list in `studio/lessons/screenshots.json`. Still to do: lessons matched to the textbook's chapters once they are written.
- **Progress (S4):** stories keep their own pictures and sounds, the starter library is copied in on use, and the library panel adds starter items and the student's own pictures, faces, and sounds (`studio/library/`, `studio/stories/`, decision 0023). The Studio's own starter art is in `studio/library/art/`. Still to do: trying the photo and sound pickers on real tablets.
- **Progress (S3):** the stage preview and Play from here are built (`studio/preview/`, `studio/story_screen.gd`). Both start from the beginning of the block's scene, so numbers changed in earlier scenes start at their first values. Still to do: check the preview's speed on real tablets.
- **Progress (S1):** the home screen, stories in the app's storage, New story, Rename, Delete, Share and Open as `.zip`, and the reminder to share are built (`studio/home/`, `studio/stories/`, `studio/story_screen.gd`). Share saves the file through the system's file picker; the share sheet (AirDrop, Classroom, email) needs a small native plugin. Still to do: that plugin, and trying Share and Open on real tablets.
- **Progress (S2):** the blocks are built (`studio/blocks/`, `addons/storyteller/visual/story_blocks.gd`): every block in `docs/studio-design.md` §5 plus Note, the palette, drag and snap, deleting by dragging to the palette, Duplicate and Delete on a long press, pickers with pictures, − and + for amounts, "Make a number", undo and redo, hints, and the Code block behind a setting. Every block and every line of the sample tales reads back exactly; the Where's Biscuit sample needs no Code blocks. The Studio app opens the sample in the blocks, saves every change, and plays it (`studio/studio.tscn`). Still to do: Help on the long-press menu, and trying the blocks with a finger on real tablets.
- **Progress (S0):** the tablet check app is built (`studio/check/`, `studio/README.md`): seven panels for the seven checks, with Works and Problem buttons and a results summary to send. `tools/build_studio.sh` exports it with the `studio` feature tag, and GitHub Actions builds the Android app (`.github/workflows/studio.yml`). Still to do: run it on an Android tablet and, once the Apple account exists, an iPad.

### Plugin 1.0 Release (about 34 weeks after M0 starts)
The Godot plugin with M0 to M7, for adults.

### Studio 1.0 Release (after M8)
Visual Novel StoryTeller Studio for kids, with its interface frozen for the textbook's first edition.

### After the releases
- **Plugin 1.x:** the rest of the former Pro features (§12.2), all free, and the stage preview in the Story tab.
- **Studio:** a character maker and blocks inside the plugin's Story tab (`docs/studio-design.md` §12). Students share story files and adults publish them in Godot (decision 0022), so a playable link is no longer planned.
- Language server and VS Code extension.
- Optional add-ons: Spine, Live2D, C# API (if demand appears), community action packs.

---

## 12. Everything Is Free (decision 0019)

StoryTeller has no paid tier. Every feature is open source under the MIT license (§13), and the project is supported through GitHub Sponsors. Decisions 0006, 0009, and 0014, which planned a Pro add-on, are superseded.

### 12.1 Guiding rules

1. **Students and solo creators get everything.** A student can build and play a story in the Studio, and a creator can make and sell a full visual novel, with nothing held back.
2. **Built on public hooks.** Larger features use the same extension points as community add-ons (§12.3), so the core stays small and anyone can build alternatives.
3. **Games stay free of fees.** Games built with StoryTeller owe no royalties, and players never need a license.

### 12.2 The former Pro features

| Feature | When |
|---|---|
| Stage preview and play from here | Studio 1.0 (M8); plugin 1.x in the Story tab |
| Starter templates (mystery, adventure, a "choose your path" lesson) | Studio 1.0 (M8) |
| Video cast look | 1.x |
| Bubble, messenger, and caption dialogue styles | 1.x |
| Hotspot and messenger choice styles, and the hotspot authoring tool | 1.x |
| Transition pack and effects pack | 1.x |
| Theme pack | 1.x |
| Translation workflow tools (`.po`, missing-line reports, preview) | 1.x |
| Voice production tools | 1.x |
| Story analytics (route coverage, word counts, choice statistics) | 1.x |

### 12.3 Extension points for add-ons

These hooks were built so features could live in separate add-ons. They stay: the 1.x features above and community add-ons use them.

| Feature | Extension point | Status |
|---|---|---|
| Bubble, messenger, and caption dialogue styles | `StoryConfig.dialogue_styles` | Built |
| Video cast look | Scene looks (any Godot scene) | Built |
| Effects pack | Custom actions (§5.4) and extra crew members (`StoryConfig.crew`) | Built |
| Theme and template pack | `StoryConfig.theme` and starter projects | Built |
| Hotspot and messenger choice styles | A registry of choice menu styles, chosen with `choose(style = ...)`: `StoryConfig.choice_styles` and `StoryDialogue.add_choice_style()` | Built (M6) |
| Transition pack | `StoryTransition` resources registered by name (`StoryConfig.transition_folder`, `StoryConfig.transitions`, `StoryStage.add_transition()`), listed by the card forms | Built (M7) |
| Stage preview, analytics, translation and voice tools | Story tab hooks: `TaleEditorPanel.get_instance()`, `add_toolbar_control()`, `add_side_panel()`, and the `line_selected` signal | Built (M7) |

---

## 13. License Exploration (free tier)

The license affects adoption and what others may do with the code.

| License | What it allows | Fit for StoryTeller |
|---|---|---|
| **MIT** | Anyone may use, modify, and resell, including closed forks. Requires keeping the copyright notice. | Same license as Godot; most familiar to the community; maximum adoption. A competitor could sell a modified copy. |
| **Apache 2.0** | Same freedoms as MIT, plus an explicit patent grant, and it states that no trademark rights are granted. | Good balance; helps protect the StoryTeller name and gives users patent clarity. Slightly longer notice requirements. |
| **MPL 2.0** | Changes to StoryTeller's own files must stay open source; games and separate add-ons can use any license. | Keeps improvements flowing back without affecting games. Less familiar to some Godot users. |
| **GPL / LGPL** | Copyleft that can extend to the whole game. | Not recommended; it would discourage commercial games. |
| **Source-available (custom)** | Free to use, with restrictions such as "no reselling as a competing tool". | Strongest protection, but not open source; may not be accepted by the Godot Asset Library and may reduce trust. |

**Decision (0008):** StoryTeller is released under the **MIT license**, the same license as Godot. Anyone may use, modify, and redistribute it, including in commercial games, as long as the copyright notice is kept.

**Reconfirmed (2026-10-09):** the other options were weighed again before the first public release. Apache 2.0 adds a patent grant and a trademark clause but changes little for a GDScript tool; MPL 2.0 would require changes to StoryTeller's own files to be shared, at some cost to adoption; source-available licenses would keep the free tier off the Godot Asset Library and cost trust in an MIT-heavy community. MIT stays. Protection comes from elsewhere:

- **Trademark:** register the final product name after the trademark search (§19, question 2). The license grants no trademark rights, so forks cannot use the name.
- **Contributor sign-off:** contributions are signed off under the Developer Certificate of Origin (`CONTRIBUTING.md`).
- **Support:** GitHub Sponsors (§12).

This plan is general guidance; the legal review (§2.8) confirms these steps.

---

## 14. Platform Exploration

All platforms below are supported by Godot's export system. The question is which ones StoryTeller tests and designs for at each milestone.

| Platform | Considerations | Suggested timing |
|---|---|---|
| Windows, macOS, Linux (and Steam Deck) | Easiest targets; most commercial visual novels sell here. macOS builds need signing and notarization for distribution. | M3 |
| Web (HTML5) | Popular for visual novels on itch.io and game jams. Watch download size, audio that must start after a click, and saves stored in browser storage. | M3 |
| Android | Large visual novel audience. Needs touch controls, safe-area layouts, smaller textures, and app-store packaging. | M4 |
| iOS | Same design needs as Android; exporting requires a Mac and an Apple developer account. | M4 |
| iPad and Android tablets (Studio apps) | Visual Novel StoryTeller Studio's first targets (decision 0021): store apps with the Compatibility renderer, touch only, the on-screen keyboard, and the system's photo pickers and share sheet. iOS builds run on GitHub's macOS runners. Checked on real tablets first (M8, S0). | M8 |
| Consoles | Godot console exports come from third-party porting partners under platform NDAs. | Out of scope; keep code portable (no OS-specific file access, all saves under `user://`). |

**Current recommendation:** design the default UI for mouse, keyboard, gamepad, and touch, test desktop and web first, then mobile. This keeps mobile-friendly layouts from becoming a costly retrofit.

**Status (2026-10-14):** Linux is tested in CI (tests and a `.pck` export check that plays, saves, and loads the demo). Windows runs the tests in CI, and the demo is exported as a Windows game there, started, and checked the same way (`tools/check_windows_export.ps1`). A Studio story is exported for the web and played in a browser by `tools/check_studio_story.sh`. No mobile build of the demo has been made; the Studio's Android app is built in CI. The mobile testing once suggested for M4 did not happen. Touch works for continuing lines, and gamepad buttons are bound by default.

**Notes from M3:**
- Asset discovery uses `ResourceLoader.list_directory`, because exported games keep only imported files. `tools/check_export.sh` guards this in CI.
- Saves, settings, and global data live under `user://`, which maps to browser storage on the web.
- Quit buttons are hidden on the web, where a page cannot close itself.
- Still to try: the demo itself as a web build in a browser (download size, audio starting after the first click). A Windows build is checked in CI.

---

## 15. Repository Layout

As built:

```
StoryTeller/                     # public repository
├── addons/storyteller/
│   ├── plugin.cfg, plugin.gd, LICENSE
│   ├── core/            # Story autoload, StoryCrew base, StoryConfig
│   ├── talescript/      # lexer, lossless parser, checker, compiler, Tale resource, completion
│   ├── director/        # TaleDirector, evaluator, tasks, context, presenter interface
│   ├── actions/         # built-in TaleAction classes
│   ├── stage/           # stage, cast members and looks, backdrops, props, camera, assets
│   ├── audio/           # StoryAudio
│   ├── effects/         # StoryEffects and the filter shader
│   ├── collection/      # StoryCollection and CollectionItem
│   ├── saves/           # StorySaves and StorySettings
│   ├── rewind/          # StoryRewind and StoryHistory
│   ├── ui/              # dialogue styles, choice styles, StoryDialogue, default theme
│   ├── menus/           # StoryMenus and its screens
│   ├── localization/    # StoryStrings (string export)
│   ├── debug/           # StoryConsole
│   ├── editor/          # import plugin, Story tab panel, highlighter, export script
│   └── visual/          # card editor, Story Map, and their editing layer
├── demo/                # original sample story, generated assets, translations, 3D scene
├── examples/            # small example stories, such as Where's Biscuit?
├── studio/              # Visual Novel StoryTeller Studio (M8): the app, its block editor, and the tablet check
├── tests/               # built-in runner, unit tests, fixtures
├── tools/               # test and export-check scripts, CI installer, demo asset generator
├── docs/                # TaleScript spec, decisions, this plan
└── .github/             # CI workflow, issue and pull request templates
```

---

## 16. Testing Strategy

Built (506 tests in `tests/`, run by `tools/run_tests.sh` or `tools/run_tests.ps1`):

- **Unit tests (built-in runner, decision 0007):** lexer, parser, checker messages, compiler, evaluator, director, stage, CGs, cast animations and fields, audio, effects, saves, rewind, menus, dialogue boxes and text tags, localization, collection, route chart, console and live reload, editor panel, completion, card editor, Story Map, the Studio's blocks, block editor, story library, home screen, stage preview, Play from here, starter library, and library panel, raw pictures and sounds, and the tablet check.
- **Round-trip tests:** every fixture `.tale` is parsed and printed back unchanged; every expression in the sample tales prints and parses back the same; card edits change only the expected lines; every statement a Studio block shows is written back exactly.
- **Golden tests:** fixture parse trees compared against stored `*.expected.txt` dumps (`-- --update-golden` rewrites them).
- **Playthrough tests:** the whole demo plays in skip mode with scripted choices, in English and Spanish; the 3D scene's conversation opens its gate.
- **Interruption tests:** the demo is saved at eight points spread through it; loading each save goes on exactly as the first playthrough did, and rewinding one step at the same points shows the line before and goes on the same way.
- **Script error watcher:** any script error during a test fails it.
- **CI:** GitHub Actions on Linux and Windows for Godot 4.7.2, a non-blocking job on a Godot beta when `GODOT_BETA` is set, an export check of the demo as a `.pck` that also plays, saves, and loads it (`tools/check_export.sh`), and on Windows the demo exported as a Windows game and checked the same way (`tools/check_windows_export.ps1`).

Planned: interruption tests at every line rather than eight points (if CI time allows), export checks for each chosen platform, and Studio builds for iOS and Android in CI.

---

## 17. Documentation Plan

Built in M7, in `docs/guides/` unless noted. Every TaleScript example in the guides passes the checker (`tools/check_tale.gd`).

- **Getting Started:** install, wizard, first scene in ten minutes. ✔
- **Visual Editor Guide:** building a branching scene without typing syntax. ✔
- **TaleScript for Writers:** cheat sheet plus examples, no programming background assumed. ✔
- **TaleScript for GDScript Users:** a short page listing only the differences from GDScript. ✔
- **Action Reference:** generated from action signatures and doc comments (`docs/action-reference.md`; a test keeps it current). ✔
- **Developer Guide:** custom actions, looks, crew members, dialogue and choice styles, transitions, menus, embedding, saving custom state, Story tab hooks. ✔
- **Recipes:** relationship meters, inventory checks, mini-game handoff, timed choices, picture choices, flashbacks, visited beats. ✔ (The phone-messenger story waits for the messenger style, 1.x.)
- **Studio materials (M8):** a quick start for students, and a guide for teachers and parents to publishing a student's story (`docs/guides/publishing-studio-stories.md`). ✔ for the publishing guide. The textbook for teachers is written by the maintainer; the repository holds its lesson projects (`studio/lessons/`) and the screenshot script (`tools/studio_screenshots.sh`, `docs/studio-design.md` §13).

---

## 18. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| IP or trademark concerns | Takedown or legal cost | Clean-room rules (§2), original vocabulary and language, decision log, legal review before 1.0. |
| Product name conflicts | Forced rename after launch | "Storyteller" is a common word and is also the title of an existing commercial game; run a trademark search early and pick a distinctive product name if needed. |
| Visual editor round trips damage hand-written files | Lost trust from programmers | Lossless parser from M1, byte-for-byte round-trip tests, script cards for anything unsupported. |
| Studio schedule overrun | The Studio and the textbook slip | Feasibility check first (M8, S0); the Studio builds on the existing card model; the plugin's 1.0 does not wait for it. |
| Studio changes make the textbook wrong | Teachers lose trust in the book | Interface freeze before writing; every major version stays online at its own address; screenshots made by a script (`docs/studio-design.md` §13). |
| Tablet and store limits | Awkward typing or photo picking; store review delays or rejections | Check on real tablets first (M8, S0); the system's own pickers and share sheet; nothing collected and no ads, to fit the stores' rules for children's apps; test releases through TestFlight and Google Play's testing track. |
| Blocks too hard for students | Students give up | Pictures in blocks, plain words, undo everywhere, hints that never block Play; a classroom test once the Studio works. |
| Godot releases break the addon | Breakage | Track latest stable with a non-blocking beta CI job (§1.3). |
| TaleScript drifts from GDScript | Steeper learning curve | Keep the five deliberate additions only; review the "for GDScript users" page each release. |
| Async cancellation bugs (skip, load, rewind mid-effect) | Broken stage state | The director's generation counter stops a superseded run; crew members finish effects at once while skipping; tests cover loading and rewinding mid-scene, and interruption tests save, load, and rewind at points through the whole demo. |
| Rewind memory use | Slow on mobile | Configurable depth and `@no_rewind` today; delta snapshots if mobile testing shows a need. |
| Visual tools not yet tried by real users | Writers and students may get stuck | The M5 usability test with writers (the plugin) and a classroom test with students once the Studio works, each followed by fixes. |
| Overlap with Dialogic, Dialogue Manager, Escoria | Low adoption | Differentiate with the visual editor, a GDScript-style language, a full visual novel stack, and rewind. |
| Unsafe scripts from mods | Code execution | Own evaluator; only explicitly exposed members are reachable. |

---

## 19. Open Questions

1. **Platforms (D9):** exploring; see §14.
2. **Product name:** keep "StoryTeller" after a trademark search, or choose a more distinctive name? The README's title is now "Visual Novel StoryTeller"; the code, addon folder, and other documents still say StoryTeller.
3. **Dialogue strings:** require quotes (closest to GDScript, as planned) or also allow an unquoted shorthand for heavy prose?
4. ~~**Pro tier details.**~~ Resolved 2026-10-12: there is no Pro tier (decision 0019).
5. ~~**Tier of image choices and the route chart (M6).**~~ Resolved 2026-10-09: both are free (decision 0014, since superseded: everything is free).
6. ~~**Studio address.**~~ Resolved 2026-10-12: the Studio is a downloadable app (decision 0021); a project website at a Visual Novel StoryTeller domain links to the stores.
7. **Classroom test:** which school and class, and when? Deferred until the Studio works.
8. ~~**The Studio's name and version numbers.**~~ Resolved 2026-10-12: Visual Novel StoryTeller Studio, numbered separately from the plugin.

---

## 20. Immediate Next Steps

The plugin (Visual Novel StoryTeller):
1. Finish testing the 0.1.0-beta release with `docs/release-testing.md` and publish it.
2. Run the M5 usability test: three writers who do not program each build a short branching scene with cards and the map.
3. Run a trademark and name search for "StoryTeller" and "Visual Novel StoryTeller", then settle the name (§19, question 2).
4. Finish M7: time the demo with a real player, the legal review, a trailer and screenshots, the Asset Library listing, then 1.0.

The Studio (Visual Novel StoryTeller Studio):
5. Set up an Apple Developer Program membership and a Google Play Console account, and register the Visual Novel StoryTeller domain for the project website.
6. Start M8 with the feasibility check (S0): a small test app built by GitHub Actions, installed on a real iPad (TestFlight) and Android tablet, and checked against `docs/studio-design.md` §10.
