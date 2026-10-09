# StoryTeller: Planning Document

StoryTeller is a visual novel and interactive story framework for **Godot 4**. Writers author stories in **TaleScript**, a small language that looks and feels like GDScript. The framework handles characters, scenery, dialogue boxes, choices, audio, saving, localization, and menus so creators can ship a complete visual novel, or add story sequences to any Godot game, with little or no extra code.

Status: **Draft v0.15** (M0 to M5 complete; M6 under way, 6 of its 10 items built)

### Where things stand (2026-10-09)

- **Built and merged to `main`:** milestones M0 to M5. The language and compiler, the runtime with twelve crew members (§5.1), stage, audio, effects, movies, saves, rewind, history, settings, menus, Extras, translation, the debug console, live reload, and the Story tab with Text, Cards, and Map views.
- **M6 so far:** inline text tags, CGs with gallery variants (decision 0013), character renames, character animations with drawing order, per-character data (`ada.affection`), and a save screen with pages, renaming, deleting, and timed autosave. Also merged: clicking anywhere on the dialogue box continues, and the default theme shows `[code]` in a tinted monospace font.
- **Tests:** 323 tests in the built-in runner pass on Linux and Windows in CI, plus an export check of the demo as a `.pck`.
- **Demo:** `demo/` plays a tour, a prologue, and chapter 1 (about 8 minutes) in English and Spanish; `demo/embedded/` shows dialogue inside a 3D scene. The tour shows the TaleScript behind each feature it explains. Ada is "???" until she introduces herself, chapter 1 has a CG with two variants, characters hop, nod, and shake, and Mira's friendship grows with the player's choices.
- **Not done yet:** the rest of M6 (presentation details, the route chart, image choices, and Yarn Spinner import), the M5 usability test with writers, Windows and web export builds, the platform choice, and a trademark search.
- **To continue on another computer:** clone the repository, open `project.godot` in Godot 4.7.2, and run the tests with `.\tools\run_tests.ps1 -Godot <folder with Godot>` on Windows or `GODOT_BIN=<path> tools/run_tests.sh` elsewhere (see README). Work branches start from the latest `main`. Regenerating demo art and audio with `tools/demo_assets/generate.py` needs Python 3 with Pillow and NumPy. `tools/check_export.sh` needs a preset named "Linux" when `export_presets.cfg` exists (it is not committed).

Changes in v0.15:
- M6 progress: inline text tags, CGs, character renames, character animations, per-character data, and the save screen are built (§11). The reference sections describe them: vocabulary (§3), markup (§4.5), runtime and layers (§5.1, §5.3), looks and assets (§5.5, §5.6), actions (§6), player-facing systems (§10), and testing (§16).
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
- Replaced the Naninovel-style script syntax with TaleScript, a GDScript-flavored language.
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

### 1.1 Non-goals for 1.0

- Compatibility with other engines' script formats. (Importing open formats such as Yarn Spinner is planned for M6; StoryTeller still does not read commercial engines' formats.)
- A general-purpose visual programming language. The visual editor (§9) covers story content; game logic stays in GDScript.
- C# support. GDScript classes remain callable from C# through Godot's normal interop, and a dedicated C# API can be revisited after 1.0.
- Spine or Live2D support in the core package (possible later add-ons).
- Multiplayer storytelling.
- Godot 3.x support, or Godot 4 versions older than the current stable release.

### 1.2 Decision log

| # | Date | Decision |
|---|---|---|
| D1 | 2026-10-08 | Naninovel defines the feature scope only. StoryTeller uses its own language, vocabulary, and design (§2). |
| D2 | 2026-10-08 | The story language follows GDScript conventions (TaleScript, §4). |
| D3 | 2026-10-08 | Target the latest stable Godot release, currently 4.7.2 (§1.3). |
| D4 | 2026-10-08 | No C# support for now. |
| D5 | 2026-10-08 | Names accepted: TaleScript, `.tale` files, `beat` blocks. |
| D6 | 2026-10-08 | The visual editor ships before 1.0 as a key differentiator (§9). |
| D7 | 2026-10-08 | Business model: free base tier plus a paid Pro tier (§12). |
| D8 | 2026-10-08 | MIT license for StoryTeller (§13). |
| D9 | open | Target platforms and their order (exploring, §14). |
| D10 | 2026-10-08 | Built-in test runner instead of GUT. |
| D11 | 2026-10-08 | Pro tier deferred until the free tier is a working system (§12). |

From M0 onward, each decision has a full record in `docs/decisions/`.

### 1.3 Godot version policy

- StoryTeller targets the **latest stable Godot 4 release**, currently **4.7.2**.
- When a new stable minor version ships (for example 4.8), StoryTeller moves to it in its next minor release, after the first patch release of that Godot version (x.y.1) to avoid early regressions.
- CI runs against the supported version and also tests the newest Godot beta as a non-blocking job, giving early warning of breaking changes.
- New Godot features (typed dictionaries, newer editor APIs, improved web export) can be used freely, since older versions are out of scope.

---

## 2. Originality and IP Guidelines

Naninovel (for Unity) is the reference for the overall **scope** of the project: a complete, script-driven visual novel toolkit with strong editor support. StoryTeller must be an independent work. General ideas and genre conventions (dialogue boxes, branching choices, save slots, rewind, galleries) are common to the whole visual novel field and appear in many engines such as Ren'Py, TyranoBuilder, Dialogic, and Ink-based tools. Specific expression (source code, documentation text, names, file formats, sample content, art, UI layouts) belongs to its authors.

The project follows these rules:

1. **Clean-room development.** Contributors do not read, copy, or translate Naninovel source code. Inspiration comes only from publicly visible, feature-level information (what a feature does for the user), and every design is written fresh from that.
2. **Own language.** TaleScript is designed around GDScript conventions. It does not reuse Naninovel's line prefixes, command names, parameter syntax, or file extension.
3. **Own vocabulary.** StoryTeller uses its own terms for its concepts (see §3). Naninovel-specific terms such as its script format name, "printer", "choice handler", "generic line", "engine service", and "managed text" are avoided in code, docs, and UI.
4. **Own documentation and samples.** All docs, tutorials, example characters, stories, art, audio, and UI designs are original. No paraphrasing of another product's documentation.
5. **Own architecture.** Systems are organized around Godot's node and resource model, which naturally produces a different structure from a Unity framework.
6. **Trademarks.** Public materials (store listing, website, README, marketing) do not use the Naninovel name or branding, and do not claim compatibility or affiliation. This internal planning document mentions it only to record where the scope came from.
7. **Decision log.** Major design decisions are recorded in `docs/decisions/` with the reasoning behind them, which documents independent development.
8. **Legal review.** Before the public 1.0 release and again before selling a Pro tier, the maintainers obtain a review from a lawyer familiar with software IP, covering this section, the license (§13), any Pro EULA (§12), and a trademark search for the product name. This plan is general guidance and does not constitute legal advice.

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
| Annotations | `@title`, `@global`, `@once`, `@show_disabled`, `@id`, `@voice`, `@no_rewind`, `@skip_safe` | See §4.8. |

### 4.4 Actions and timing

Actions mirror Godot's async model:

- An action call **starts** its effect and returns immediately, so several effects can run at the same time.
- `await` before an action blocks the tale until that action completes, exactly as `await` works with tweens and signals in GDScript.
- Before any dialogue, narration, or choice appears, the director waits for running actions to finish. This keeps simple tales in order with no `await` at all. (A switch to turn this off per project or per line is not built.)

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

The checker validates `[act]` and `[sound]` like `{expression}` values and reports bad `[speed]` and `[pause]` values. Choice options leave out `[act]` and `[sound]`, and the history and save slots show text without these tags. The default theme draws `[code]` in a tinted monospace font (`code_color` for the `DialogueBox` theme type). Named text styles such as `[whisper]` are planned with the M6 presentation details.

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
- `choose(style = "..."):` is parsed and passed to the choice menu, but only the default list menu exists. Image choices are planned for M6; hotspot and messenger styles are Pro.

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
- The **checker** reports unknown actions, wrong argument types, unknown beats, undefined variables, unknown cast members or moods (warnings), unreachable code, and indentation problems.
- Every dialogue line and choice option receives a **line id** (beat name plus a content hash, or a pinned `@id`). Translations are keyed `<tale>:<id>` (decision 0011). An editor command to pin ids in bulk, so later edits never change them, is planned but not built.
- The same parser and compiler run in the game for live reload (§8). Loading tales from outside the project (mods) is not built.

---

## 5. Architecture

### 5.1 Runtime structure

The `Story` autoload creates the crew members listed in `StoryConfig.crew`, in this order (class, then the name used with `Story.get_crew()`):

```
Story (autoload)
├── TaleDirector     "TaleDirector"  runs tales: instructions, await, call stack, variables,
│                                    expression evaluation, skip and auto, read tracking,
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
├── StoryDialogue    "Dialogue"      dialogue box styles, choice menu, input actions
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

- Register it with `TaleDirector.add_action(preload("action_lightning.gd").new())`. Built-in actions are listed in `TaleDirector.BUILTIN_ACTIONS`; discovering custom actions in a folder automatically is not built.
- Parameters are read from the `run` signature, so the checker and the visual editor's action forms know names, types, and defaults.
- Skipping makes effects finish at once (crew members check the director's `skipping` flag), and loading or rewinding stops the running beat through the director's generation counter, so actions never need their own cancellation code.

### 5.5 Cast looks

| Look | Description |
|---|---|
| `SpriteSetLook` | One texture per mood, found by folder convention or explicit table. |
| `LayeredLook` | Builds a character from named layer groups (body, outfit, face, accessory). Mood strings like `"face=smile, outfit=coat"`. |
| `SceneLook` | Any `PackedScene`; moods map to `AnimationPlayer` animations, and `animate(name)` plays any named animation. (3D characters rendered into a viewport: not built.) |
| `VideoLook` | `VideoStreamPlayer`, one clip per mood. Pro, not built. |

Built cast extras: display name (translatable), name color, scale, default mood, and speaker highlighting (others are dimmed). From M6: renaming during play (`display_name`, saved and translated), `hop()`, `shake()`, and `nod()` (they move only the look, so they combine with `move_to()`), `animate(name)` for scene looks, and a saved `draw_order` with `to_front()` and `to_back()`. Cast methods report problems to the tale through the director. Not built: text color, portraits in the dialogue box, lip-flap for voiced lines, and per-character typing sounds. From M6 too: per-character data, declared in `CastProfile.fields` and used as `ada.affection`, checked by the checker, offered by autocomplete, and saved.

### 5.6 Asset finding

- Assets are found by name in folders set in `StoryConfig`: `cast/<id>.tres` or `cast/<id>/<mood>.png`, `backdrops/<name>.png`, `props/`, `cgs/<name>.png` or `cgs/<name>/<variant>.png`, `audio/music/`, `sounds/`, `ambience/`, `voice/`, `movies/`, and `collection/`. Folders are read with `ResourceLoader.list_directory`, so exported games find the same files.
- When a beat starts, the director asks crew members to load the assets it names in the background (`ResourceLoader.load_threaded_request`). There is no memory budget yet.
- A missing asset is reported when the line runs. Checking for missing files at import time is not built.

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

Standard visual novel genre features, with the milestone (§11) and the proposed tier (§12). Features marked **Pro** are deferred until the free tier works (decision 0009); their milestone column reads "Pro phase".

| Feature | Description | Milestone | Tier |
|---|---|---|---|
| TaleScript | Language, compiler, checker, syntax highlighting | M1 | Free |
| Director | Execution, await, call stack, skip and auto modes | M1 | Free |
| Variables and expressions | Story vars, global vars, safe evaluator, exposure API | M1 | Free |
| Dialogue box: classic | Bottom box with name plate and typewriter text | M1 | Free |
| Choice menu: list | Vertical button list | M1 | Free |
| Cast looks: sprite set, layered, scene | Characters from textures, layer rigs, or any Godot scene | M2 | Free |
| Cast look: video | Characters from video clips | Pro phase | Pro |
| Backdrops and props | With transitions | M2 | Free |
| Core transitions | Fade, dissolve with mask texture, slide, wipe | M2 | Free |
| Transition pack | Iris, pixelate, ripple, shatter, page turn, custom shader templates | Pro phase | Pro |
| Audio | Music crossfade, sounds, voice, ambience, buses | M2 | Free |
| Camera | Zoom, pan, shake, rotate | M2 | Free |
| Saves | Slots with thumbnails, quick save, auto save, global data, versioned format | M3 | Free |
| Rewind and history | Step back through lines and choices; log with voice replay | M3 | Free |
| Dialogue style: full page | Full-screen text for prose-heavy scenes | M3 | Free |
| Dialogue styles: bubble, messenger, caption | Speech bubbles, phone-chat stories, cinematic captions | Pro phase | Pro |
| Timed choices | Countdown with a `timeout:` branch | M1 | Free |
| Choice styles: hotspots, messenger reply | Point-and-click areas, chat replies | Pro phase | Pro |
| Menus and default theme | Title, pause, save/load, settings, history, confirm, loading, text input | M3 | Free |
| Theme and template pack | Extra polished themes and genre starter projects (mystery, romance, messenger story) | Pro phase | Pro |
| Basic effects | Flash, fade to color, rain and snow, color filters (blur and vignette not built) | M4 | Free |
| Effects pack | Fog, light rays, glitch, film grain, particle presets | Pro phase | Pro |
| Collection | Gallery, music room, codex | M4 | Free |
| Localization | Godot translations, language setting, CSV string export that keeps translations (decision 0011) | M4 | Free |
| Translation workflow | `.po` export, missing-line reports, translator preview mode | Pro phase | Pro |
| Voice production tools | Per-actor voice scripts, automatic clip mapping by line id, lip-flap from audio | Pro phase | Pro |
| Debug console | Run TaleScript lines, inspect and edit vars, jump to beats | M4 | Free |
| Live reload | Edit a tale during play and continue from the same line | M4 | Free |
| Movies | Full-screen video playback | M4 | Free |
| Embedding preset | Dialogue-only mode for 2D and 3D games, trigger tales from game events | M4 | Free |
| Visual editor | Card-based editing of tales, synced with text (§9) | M5 | Free |
| Story Map | Graph of beats, jumps, calls, and choices (§9) | M5 | Free |
| Stage preview and play from here | Live preview of the stage at any line; launch the game from that line | Pro phase | Pro |
| Story analytics | Route coverage, word counts per character, choice statistics from playtests | Pro phase | Pro |
| Inline text tags | Typing speed, instant spans, sounds and actions at points in a line | M6 | Free |
| CGs | Event pictures on their own layer that unlock gallery entries, with variants | M6 | Free |
| Character names during play | Rename cast members from tales; saved and translated | M6 | Free |
| Character animations | Hop, shake, nod, named animations, drawing order | M6 | Free |
| Save screen paging | Unlimited slots in pages, delete and label saves, timed autosave | M6 | Free |
| Per-character data | Fields declared in cast profiles, such as affection | M6 | Free |
| Route chart | Player-facing map of explored branches without spoilers | M6 | Open (§19) |
| Image choices | Choices as pictures or screen areas; a hook for in-world choices | M6 | Open (§19) |
| Yarn Spinner import | Convert Yarn Spinner scripts into tales | M6 | Free |
| Language server | Autocomplete and diagnostics in VS Code and other editors | Post-1.0 | Free |

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
| Setup wizard | Config, folders, starter scene, sample tale | M7 |
| Pin line ids | Write `@id` into every line so edits never change ids | Not scheduled |
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

Cards are edited in place, so there is no separate inspector. The stage preview (§9.5) is Pro.

### 9.3 Cards

| Card | Editing controls (as built) | Not built yet |
|---|---|---|
| Narration | Text field | Markup toolbar (bold, pause, speed, sound) |
| Dialogue | Speaker and mood pickers, text field | Portraits and mood thumbnails |
| Choice | One lane per option with text, condition, `@once`, show-disabled, and nested cards | |
| Condition | If, else if, and otherwise lanes with a free-text condition | Expression builder |
| Action | Form from the action's signature: typed fields, color picker, lists of matching assets, transitions, and moods, a "wait until it finishes" switch | Previews in the asset lists |
| Jump / run beat | Field with a list of beats in this and other tales | Search |
| Set variable | Variable, operator, value | Variable picker |
| Comment | Text field | |
| Script | Raw TaleScript for anything else (loops, `match`, local variables, one-line `if`) | |

Interaction built: add from a menu, move up and down, drag to reorder or into another lane, delete, add, rename, and delete beats, problems shown on the card, and undo shared with the text view. Not built: multi-select, copy and paste between tales, full keyboard navigation, and collapsing lanes.

### 9.4 Story Map

- Each beat is a `GraphNode`; arrows show jumps, calls, and choice branches, colored by tale.
- Automatic layout with manual adjustment saved to a sidecar file (`.tale.map`), so the tale file itself stays clean.
- Highlights unreachable beats and jumps to missing beats, and marks beats where the story can end.
- Drag from a node's output to empty space to create and link a new beat.
- Double-click a node to open it in the beat editor.
- Tales appear in horizontal bands in the order play reaches them, and beats in columns by step.
- Pro overlay (not built): route coverage from playtests and word counts per branch.

### 9.5 Stage preview (Pro)

Selecting any card shows the stage as it would look at that line. The director runs the tale up to that point in a fast "dry run" mode with all animations skipped, then renders the result in an editor viewport. A "Play from here" button launches the game at the same point with the computed state.

---

## 10. Player-Facing Systems

Built:

- **Dialogue boxes:** each style extends `DialogueBox` (`show_line`, `hide_box`, `clear_page`, `cancel`, and `reveal` for the typewriter). Two styles ship: "classic" (box with name plate) and "page" (lines collect on a full page). Restyle with a Godot `Theme` (`StoryConfig.theme`) or add styles in `StoryConfig.dialogue_styles`.
- **Typewriter:** per character, speed from settings (0 shows text at once), with the tags in §4.5: `[pause]`, `[speed]`, `[instant]`, and `[act]` and `[sound]` at points in a line. A click while a line types shows it up to the next pause, and tags passed on the way still run. A click anywhere on the dialogue box continues.
- **Extras:** gallery, music room, and codex. Every CG has a gallery entry that unlocks when the CG is shown; the viewer steps through the variants the player has seen.
- **Playback controls:** continue (click, tap, Space, Enter), auto (delay scales with line length), skip (read lines only, or all with the setting), rewind (mouse wheel, Page Up), history (H), pause menu (Escape, right click), quick save and load (F5, F9). All are `InputMap` actions (`story_*`) that games can rebind. A quick menu sits beside the dialogue box.
- **Saves:** JSON in `user://saves/` with a format number and migration hooks, PNG thumbnails, numbered slots in pages (six per page by default, `StoryConfig.save_slot_count`; as many pages as players fill unless `save_pages` sets a limit) plus quick and auto slots, renaming and deleting saves from the screen, autosave before choices and optionally every few minutes (`autosave_minutes`), and a global file for `@global` variables, read lines, collection unlocks, and the CG variants seen.
- **Rewind:** a snapshot of every crew member's `capture()` at each line and choice, up to `StoryConfig.rewind_depth`, with `@no_rewind` barriers.
- **Read tracking:** read line ids kept in global data and used by skip; each line passed to dialogue boxes says whether it was read.
- **Settings:** text speed, auto delay, five volumes, full screen, skipping unread lines, and language.

Not built yet: per-word and fade-in typing, typing sounds, gamepad bindings by default, a hide-UI button, delta-compressed rewind snapshots, save encryption, a "new line" indicator, and accessibility options (text size and font, high-contrast theme, screen reader hook).

---

## 11. Milestones

### M0: Scaffolding (1 week)
- Pin Godot 4.7.2 in CI. ✔
- Addon skeleton (`plugin.cfg`, `EditorPlugin`, autoload registration, `StoryCrew` base, `StoryConfig`). ✔
- Built-in test runner running headless in GitHub Actions on Linux and Windows, plus an optional non-blocking job on the newest Godot beta. ✔
- Contribution guide with the clean-room rules from §2, decision records, issue and pull request templates. ✔
- License file added (MIT). ✔
- Private repository for the Pro add-on: deferred with the Pro tier (decision 0009).

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
- Usability test with at least three writers who do not program. Not done yet.
- **Exit criteria:** a writer builds a branching five-minute scene entirely in the visual editor; the resulting file reads naturally as text and diffs cleanly.
  - Met in an automated test (`tests/unit/visual/test_visual_scene.gd`): a branching scene built only with cards matches hand-written TaleScript and checks cleanly.
  - Still open: the same with real writers, which the usability test covers.

### M6: Genre features (5 weeks)
Features most visual novels expect that StoryTeller lacks, found by reviewing Visual Novel Machinery (October 2026). Only the feature ideas come from that review; names, syntax, and designs are StoryTeller's own (§2).
- **Inline text tags:** finish the tags planned in the spec (§7.1 of `docs/talescript-spec.md`): `[speed]` for typing speed, `[instant]` for a span shown at once without typing, `[sound]` at a point in the text, and `[act]` to run an action mid-line. ✔
- **CGs:** full-screen event pictures on their own layer, above the cast and below the dialogue box (`cg()` and `hide_cg()`). Showing a CG unlocks its gallery entry, and one gallery entry can hold several variants of a picture. ✔ (CGs live in `res://story/cgs/` as single images or folders of variants; every CG gets a gallery item, and the gallery shows the variants a player has seen. Weather and filters draw over CGs; the camera does not move them. Decision 0013.)
- **Character names during play:** change a cast member's displayed name from a tale (for example "???" until they introduce themselves, or a name the player types with `ask_text`). The new name is saved and translated like other names. ✔ (Tales assign `mira.display_name`; "" restores the profile name.)
- **Character animations and order:** built-in hop, shake, and nod; playing a named animation on scene-based looks; bringing a character to the front or setting their drawing order. ✔ (`hop()`, `shake()`, `nod()`, `animate(name)` for scene looks, `to_front()`, `to_back()`, and a saved `draw_order`.)
- **Save screen:** as many slots as players want, shown in pages; deleting and labeling saves from the screen; an optional autosave on a timer. ✔ (Six slots per page by default; the grid scrolls when a page is taller than the window.)
- **Per-character data:** fields declared in a cast profile (for example `affection`), used in tales as `ada.affection += 1`, known to the checker and autocomplete, and saved with the story. ✔ (Declared in `CastProfile.fields`; field names that would hide a cast member property or method are refused.)
- **Presentation details:** title screen artwork and music in `StoryConfig`; a show and hide animation for the dialogue box; named text styles set in the config (for example `[whisper]`) that expand to formatting.
- **Route chart for players:** a screen that shows the branches a player has explored, built from read tracking and choice ids, with choices they have not seen kept hidden to avoid spoilers.
- **Image choices:** choices shown as clickable pictures or places on the screen, plus a hook so games can let players choose by interacting with objects in a 2D or 3D scene. (Its tier is open; see §19.)
- **Yarn Spinner import:** convert Yarn Spinner scripts (an open-source format) into tales, so writers can bring existing dialogue.
- Every new action and cast field gets a card form in the visual editor automatically and is covered by the checker, translation export, and tests.
- **Exit criteria:** the demo uses CGs, a character rename, per-character data, an image choice, and the route chart, in English and Spanish; a sample Yarn Spinner script imports into a tale that plays.
  - Met so far: CGs (chapter 1, `window_table` in two variants), a character rename (Ada in the tour), and per-character data (Mira's `friendship` in chapter 1), in both languages. The demo also uses the text tags and character animations.
  - Still open: an image choice, the route chart, and the Yarn Spinner import.
- **Progress:** 6 of the 10 items are built. The remaining items are listed in §20.

### M7: Launch preparation (3 weeks)
- Legal review (§2.8).
- Setup wizard (§8) and the documentation guides in §17, including generated action reference pages.
- Full documentation, original sample project (a demo story of at least 15 minutes, carried over from M3), trailer and screenshots.
- Publish on the Godot Asset Library or Asset Store and GitHub.

### 1.0 Release (about 33 weeks after M0 starts)

### After 1.0
- **Pro phase:** build the Pro add-on once the free tier is a working system (§12), starting with the features marked Pro in §7.
- Language server and VS Code extension.
- Optional add-ons: Spine, Live2D, C# API (if demand appears), community action packs.

---

## 12. Product Tiers: Free and Pro

> **Deferred (decision 0009).** Work on the Pro tier starts once the free tier is a working system. Until then, everything in this section is a planning sketch, and the free tier is built with clean extension points so Pro can be added later without changes to the core.

### 12.1 Guiding rules

1. **The free tier ships complete games.** A solo creator can make and sell a full visual novel using only the free tier, including the visual editor.
2. **Pro saves time on larger productions.** Pro adds polish, presentation variety, and production tools for teams, voice work, and translation.
3. **Pro is a pure add-on.** It lives in its own addon folder (`addons/storyteller_pro/`) and uses only the public extension points of the free tier (custom actions, looks, dialogue styles, crew members, editor hooks). This keeps the free tier honestly extensible, since anything Pro can do, community add-ons can do too.
4. **No license checks in the free tier.** Pro relies on its EULA. GDScript ships as readable source, so technical copy protection would be weak and would hurt honest customers.
5. **Games stay free of fees.** Games built with either tier owe no royalties, and players never need a license.

### 12.2 Proposed split

| Free (StoryTeller) | Pro (StoryTeller Pro) |
|---|---|
| TaleScript, checker, highlighting, autocomplete | Everything in Free |
| Director, variables, expressions | Video cast look |
| Cast (sprite set, layered, scene looks), backdrops, props | Bubble, messenger, and caption dialogue styles |
| Core transitions and basic effects (flash, fades, rain, snow, filters) | Hotspot and messenger choice menus |
| Audio, camera, movies | Transition pack and effects pack |
| Saves, rewind, history, read tracking | Theme and genre template pack |
| Classic and full-page dialogue, list and timed choices | Translation workflow tools (`.po`, missing-line reports, preview) |
| Full menu set and default theme | Voice production tools |
| Collection, localization with CSV string export | Stage preview and play from here |
| Debug console, live reload, embedding preset | Story analytics |
| **Visual editor and Story Map** | Priority support and early access builds |

The visual editor sits in the free tier because it is the strongest reason to choose StoryTeller; putting it behind payment would limit adoption. This is a recommendation and is listed in §19 for confirmation.

### 12.3 Pricing and sales (to explore)

- **Pricing models:** one-time purchase with a year of updates, yearly subscription, or per-seat licenses for teams. A one-time price with paid major upgrades is common for game tools and simple to explain.
- **Storefronts:** the official Godot Asset Store has announced plans for paid assets, but reports through mid-2026 describe paid listings as not yet open to all creators; check its current status during M7. Alternatives include itch.io, Gumroad, Lemon Squeezy, and a dedicated website.
- **Contributor agreements:** if outside contributors send code to the free tier, a Contributor License Agreement (or at least a Developer Certificate of Origin) keeps future licensing options open. Discuss with the lawyer during the §2.8 review.

---

## 13. License Exploration (free tier)

The license affects adoption, what competitors may do with the code, and how the Pro tier fits.

| License | What it allows | Fit for StoryTeller |
|---|---|---|
| **MIT** | Anyone may use, modify, and resell, including closed forks. Requires keeping the copyright notice. | Same license as Godot; most familiar to the community; maximum adoption. A competitor could sell a modified copy. |
| **Apache 2.0** | Same freedoms as MIT, plus an explicit patent grant, and it states that no trademark rights are granted. | Good balance; helps protect the StoryTeller name and gives users patent clarity. Slightly longer notice requirements. |
| **MPL 2.0** | Changes to StoryTeller's own files must stay open source; games and separate add-ons (including Pro) can use any license. | Keeps improvements flowing back without affecting games. Less familiar to some Godot users. |
| **GPL / LGPL** | Copyleft that can extend to the whole game. | Not recommended; it would discourage commercial games. |
| **Source-available (custom)** | Free to use, with restrictions such as "no reselling as a competing tool". | Strongest protection, but not open source; may not be accepted by the Godot Asset Library and may reduce trust. |

**Decision (0008):** StoryTeller is released under the **MIT license**, the same license as Godot. Anyone may use, modify, and redistribute it, including in commercial games, as long as the copyright notice is kept. A future Pro add-on can still use its own proprietary EULA, because it will be a separate work. MIT also allows others to fork or resell the free tier; the project accepts this in exchange for maximum adoption.

---

## 14. Platform Exploration

All platforms below are supported by Godot's export system. The question is which ones StoryTeller tests and designs for at each milestone.

| Platform | Considerations | Suggested timing |
|---|---|---|
| Windows, macOS, Linux (and Steam Deck) | Easiest targets; most commercial visual novels sell here. macOS builds need signing and notarization for distribution. | M3 |
| Web (HTML5) | Popular for visual novels on itch.io and game jams. Watch download size, audio that must start after a click, and saves stored in browser storage. | M3 |
| Android | Large visual novel audience. Needs touch controls, safe-area layouts, smaller textures, and app-store packaging. | M4 |
| iOS | Same design needs as Android; exporting requires a Mac and an Apple developer account. | M4 |
| Consoles | Godot console exports come from third-party porting partners under platform NDAs. | Out of scope; keep code portable (no OS-specific file access, all saves under `user://`). |

**Current recommendation:** design the default UI for mouse, keyboard, gamepad, and touch, test desktop and web first, then mobile. This keeps mobile-friendly layouts from becoming a costly retrofit.

**Status (2026-10-09):** Linux is tested in CI (tests and a `.pck` export check) and Windows runs the tests in CI. No Windows, web, or mobile game build has been made yet; the mobile testing once suggested for M4 did not happen. Touch works for continuing lines; gamepad buttons are not bound by default.

**Notes from M3:**
- Asset discovery uses `ResourceLoader.list_directory`, because exported games keep only imported files. `tools/check_export.sh` guards this in CI.
- Saves, settings, and global data live under `user://`, which maps to browser storage on the web.
- Quit buttons are hidden on the web, where a page cannot close itself.
- Still to try: a web build in a browser (download size, audio starting after the first click) and a Windows build.

---

## 15. Repository Layout

As built:

```
StoryTeller/                     # public repository (free tier)
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
│   ├── ui/              # dialogue styles, choice menu, StoryDialogue, default theme
│   ├── menus/           # StoryMenus and its screens
│   ├── localization/    # StoryStrings (string export)
│   ├── debug/           # StoryConsole
│   ├── editor/          # import plugin, Story tab panel, highlighter, export script
│   └── visual/          # card editor, Story Map, and their editing layer
├── demo/                # original sample story, generated assets, translations, 3D scene
├── tests/               # built-in runner, unit tests, fixtures
├── tools/               # test and export-check scripts, CI installer, demo asset generator
├── docs/                # TaleScript spec, decisions, this plan
└── .github/             # CI workflow, issue and pull request templates

StoryTellerPro/                  # private repository (Pro tier)
├── addons/storyteller_pro/
│   ├── looks/  ui/  effects/  transitions/
│   ├── tools/           # translation, voice, analytics
│   └── editor/          # stage preview, play from here
└── tests/
```

---

## 16. Testing Strategy

Built (323 tests in `tests/`, run by `tools/run_tests.sh` or `tools/run_tests.ps1`):

- **Unit tests (built-in runner, decision 0007):** lexer, parser, checker messages, compiler, evaluator, director, stage, CGs, cast animations and fields, audio, effects, saves, rewind, menus, dialogue boxes and text tags, localization, collection, console and live reload, editor panel, completion, card editor, and Story Map.
- **Round-trip tests:** every fixture `.tale` is parsed and printed back unchanged; every expression in the sample tales prints and parses back the same; card edits change only the expected lines.
- **Golden tests:** fixture parse trees compared against stored `*.expected.txt` dumps (`-- --update-golden` rewrites them).
- **Playthrough tests:** the whole demo plays in skip mode with scripted choices, in English and Spanish; the 3D scene's conversation opens its gate.
- **Script error watcher:** any script error during a test fails it.
- **CI:** GitHub Actions on Linux and Windows for Godot 4.7.2, a non-blocking job on a Godot beta when `GODOT_BETA` is set, and an export check of the demo as a `.pck` (`tools/check_export.sh`).

Planned: save, load, skip, and rewind at every line of the fixtures (interruption tests), export checks for each chosen platform, and the Pro compatibility suite.

---

## 17. Documentation Plan

Today the README, the TaleScript specification, and the decision records are the documentation. The guides below are planned for M7.

- **Getting Started:** install, wizard, first scene in ten minutes.
- **Visual Editor Guide:** building a branching scene without typing syntax.
- **TaleScript for Writers:** cheat sheet plus examples, no programming background assumed.
- **TaleScript for GDScript Users:** a short page listing only the differences from GDScript.
- **Action Reference:** generated from action signatures and doc comments.
- **Developer Guide:** custom actions, looks, crew members, dialogue styles, menus, embedding.
- **Recipes:** relationship meters, inventory checks, mini-game handoff, phone-messenger story, timed choices.
- **Pro Guide:** separate documentation for Pro features.

---

## 18. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| IP or trademark concerns | Takedown or legal cost | Clean-room rules (§2), original vocabulary and language, decision log, legal review before 1.0. |
| Product name conflicts | Forced rename after launch | "Storyteller" is a common word and is also the title of an existing commercial game; run a trademark search early and pick a distinctive product name if needed. |
| Visual editor round trips damage hand-written files | Lost trust from programmers | Lossless parser from M1, byte-for-byte round-trip tests, script cards for anything unsupported. |
| Visual editor schedule overrun | 1.0 slips | Start with the card editor, then Story Map; stage preview can slip to 1.1 without blocking release. |
| Free tier feels limited | Low adoption | Rule 12.1.1: free must ship complete games; review the split with early users. |
| Pro copied without paying | Lost revenue | Clear EULA, fair pricing, updates and support as the main value; avoid DRM that burdens customers. |
| Godot releases break the addon | Breakage | Track latest stable with a non-blocking beta CI job (§1.3). |
| TaleScript drifts from GDScript | Steeper learning curve | Keep the five deliberate additions only; review the "for GDScript users" page each release. |
| Async cancellation bugs (skip, load, rewind mid-effect) | Broken stage state | The director's generation counter stops a superseded run; crew members finish effects at once while skipping; tests cover loading and rewinding mid-scene. Interruption tests at every line are planned. |
| Rewind memory use | Slow on mobile | Configurable depth and `@no_rewind` today; delta snapshots if mobile testing shows a need. |
| Visual editor not yet tried by writers | Writers may find cards hard to use | M5 usability test (§20), then fix what it finds before M7. |
| Overlap with Dialogic, Dialogue Manager, Escoria | Low adoption | Differentiate with the visual editor, a GDScript-style language, a full visual novel stack, and rewind. |
| Unsafe scripts from mods | Code execution | Own evaluator; only explicitly exposed members are reachable. |

---

## 19. Open Questions

1. **Platforms (D9):** exploring; see §14.
2. **Product name:** keep "StoryTeller" after a trademark search, or choose a more distinctive name? The README's title is now "Visual Novel StoryTeller"; the code, addon folder, and other documents still say StoryTeller.
3. **Dialogue strings:** require quotes (closest to GDScript, as planned) or also allow an unquoted shorthand for heavy prose?
4. **Pro tier details** (deferred): feature split (§12.2), pricing, and storefront.
5. **Tier of image choices and the route chart (M6):** §7 lists hotspot, messenger, and timed choice styles as Pro. Timed choices are already built in the free tier, and image choices overlap the hotspot style. Should image choices and the player route chart be free (common genre features) or Pro?

---

## 20. Immediate Next Steps

1. Run the M5 usability test: three writers who do not program each build a short branching scene with cards and the map, and note where they get stuck.
2. Run a quick trademark and name search for "StoryTeller" and "Visual Novel StoryTeller", then settle the name (§19, question 2).
3. Choose the platforms (§14), then build and try Windows and web exports of the demo.
4. Fill the §9.3 gaps the usability test shows matter most (markup toolbar, multi-select, copy and paste, mood thumbnails).
5. Decide the tier question for image choices and the route chart (§19, question 5).
6. Continue M6: genre features. Inline text tags, CGs, character renames, character animations, per-character data, and the save screen are done. Next, in order: presentation details (title art and music, dialogue box animation, named text styles), the route chart, image choices, and Yarn Spinner import.
7. Play the demo to judge what tests can't: typing speeds in the tour, the chapter 1 CG and its timing, and the size and speed of the hop, nod, and shake.
