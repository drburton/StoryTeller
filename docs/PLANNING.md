# StoryTeller: Planning Document

StoryTeller is a visual novel and interactive story framework for **Godot 4**. Writers author stories in **TaleScript**, a small language that looks and feels like GDScript. The framework handles characters, scenery, dialogue boxes, choices, audio, saving, localization, and menus so creators can ship a complete visual novel, or add story sequences to any Godot game, with little or no extra code.

Status: **Draft v0.9** (M2 complete)

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

- Compatibility with, or import from, any other engine's script format.
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
| **Backdrop** | Full-screen scenery behind the cast | `Backdrop` node |
| **Prop** | Any extra object placed on stage (item, overlay, custom scene) | `Prop` node wrapping a `PackedScene` |
| **Dialogue box** | UI that shows lines of text | `DialogueBox` scene with interchangeable styles |
| **Choice menu** | UI that presents options to the player | `ChoiceMenu` scene with interchangeable styles |
| **Action** | A built-in or custom function callable from TaleScript, e.g. `backdrop()` | `TaleAction` class |
| **Director** | The runtime that executes tales | `TaleDirector` node |
| **Crew** | The set of runtime systems (audio, camera, saves, etc.) | Child nodes of the `Story` autoload |
| **Story vars** | Variables saved per playthrough | Dictionary in save data |
| **Global vars** | Variables shared across all playthroughs (`@global`) | Separate persistent file |
| **Rewind** | Stepping back to earlier lines | Snapshot ring buffer |
| **History** | Scrollable log of past lines with voice replay | `History` system and UI |
| **Collection** | Unlockable gallery images, music, and codex entries | `Collection` system and UI |
| **Story Map** | Editor view of beats and the links between them | `GraphEdit`-based editor screen |

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
| Loops | `while cond:` / `for x in list:` | Limited by a configurable iteration cap to prevent runaway scripts. |
| Choices | `choose:` block | Each option is a string, optional `if` condition, and an indented body. |
| Actions | `name(args, key = value)` | Built-in or custom actions. Return immediately unless awaited. |
| Waiting | `await action(...)` / `await signal_name` | Blocks until an action finishes or a signal fires. |
| Signals | `emit("door_opened", arg)` | Notifies game code. |
| Annotations | `@title`, `@global`, `@once`, `@skip_safe`, `@id` | See §4.8. |

### 4.4 Actions and timing

Actions mirror Godot's async model:

- An action call **starts** its effect and returns immediately, so several effects can run at the same time.
- `await` before an action blocks the tale until that action completes, exactly as `await` works with tweens and signals in GDScript.
- Before any dialogue or narration line appears, the director waits for running stage effects to finish. This default keeps simple tales in order with no `await` at all, and can be turned off per project or per line.

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

| Tag | Effect |
|---|---|
| `[pause]` | Wait for the player to continue, then keep typing on the same line. |
| `[pause=0.5]` | Wait half a second. |
| `[speed=2.0]...[/speed]` | Change typing speed for a span. |
| `[sound=bell]` | Play a sound at this point in the text. |
| `[act=shake(0.2)]` | Run any action at this point in the text. |
| `{expression}` | Insert a value, e.g. `{player_name}` or `{gold * 2}`. |

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
- `choose(style = "hotspots", timeout = 5.0):` selects a menu style and an optional timer; the `timeout:` branch runs when time expires.

### 4.7 Expressions and game code

- Expressions use GDScript's operators and literals: arithmetic, comparison, `and`/`or`/`not`, `in`, `%`, ternary `a if cond else b`, arrays, dictionaries, `Vector2`, `Color`.
- Built-in functions: `randi_range`, `randf`, `min`, `max`, `clamp`, `round`, `len`, `str`, `visited("tale.beat")`, `collected("id")`, `tr("key")`.
- Game code exposes objects and functions to tales explicitly:

```gdscript
# In game code (GDScript)
Story.expose("inventory", $Inventory, ["has", "add", "remove"])
Story.expose_func("day_of_week", func(): return calendar.weekday)
```

```gdscript
# In a tale
if inventory.has("lantern"):
	"The lantern flickers to life."
	inventory.remove("oil")
```

Only exposed members are reachable. Tales cannot call arbitrary engine methods, which keeps downloaded mods and user content safe.

### 4.8 Annotations

| Annotation | Purpose |
|---|---|
| `@title("...")` | Display name of a tale (save slots, Story Map). |
| `@global` | Marks a `var` as shared across playthroughs. |
| `@once` | Choice option or block that runs once per playthrough. |
| `@no_rewind` | Prevents rewinding past this point (e.g. after a mini-game). |
| `@id("intro_04")` | Pins a stable translation and voice id to the next line. |
| `@voice("mira_004")` | Assigns a voice clip to the next line. |
| `@skip_safe` | Marks a beat as already seen for skip purposes regardless of read tracking. |

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
- Every dialogue line receives a stable **line id** (beat name plus a content hash, or a pinned `@id`). An editor command, "Pin line ids", writes ids into the file so later edits never break translations or voice mapping.
- The same parser runs at runtime to load `.tale` files from outside the project (mods, live reload).

---

## 5. Architecture

### 5.1 Runtime structure

```
Story (autoload)
├── TaleDirector       # executes instructions, await handling, skip/auto, call stack
├── TaleLibrary        # loads and caches Tale resources
├── Vars               # story vars, global vars, expression evaluation
├── Cast               # cast members and their looks
├── Scenery            # backdrops and props
├── Dialogue           # dialogue boxes and their styles
├── Choices            # choice menus and their styles
├── Audio              # music, sound, voice, ambience on Godot audio buses
├── Camera             # zoom, pan, shake, rotate
├── Effects            # weather, flashes, screen filters, transitions
├── Saves              # slots, quick save, auto save, global data
├── Rewind             # snapshot ring buffer
├── History            # past lines log
├── Collection         # gallery, music room, codex
├── Settings           # player preferences
├── Locale             # language switching, string tables
├── Controls           # continue, skip, auto, hide UI, rewind (InputMap actions)
├── Menus              # title, pause, save/load, settings, history, gallery
└── AssetFinder        # path conventions, background preloading
```

Every crew member extends one small base class:

```gdscript
class_name StoryCrew extends Node

func setup(config: StoryConfig) -> void: pass
func clear() -> void: pass
func capture() -> Dictionary: return {}      # state for saves and rewind
func restore(data: Dictionary) -> void: pass
```

Projects can replace any crew member with a subclass through `StoryConfig`.

### 5.2 Configuration

- `StoryConfig` resource at `res://story/story_config.tres`, with one sub-resource per crew member.
- A "StoryTeller" section in Project Settings for common options.
- A **setup wizard** on first enable creates the config, folders, a starter stage scene, two sample cast members, and a sample tale.

### 5.3 Stage layers

`StoryStage` stacks `CanvasLayer`s from back to front: backdrops, cast, props, world effects, dialogue and choices, screen effects, menus, debug console. For 3D games the stage renders as an overlay, and projects can disable the scenery layers to use dialogue and choices only.

### 5.4 Custom actions

```gdscript
class_name ActionLightning extends TaleAction

## Flashes the screen and plays thunder.
func _name() -> String: return "lightning"

func run(ctx: TaleContext, intensity: float = 1.0, time: float = 0.3) -> void:
	ctx.audio.sound("thunder")
	await ctx.effects.flash(Color.WHITE, intensity, time, ctx.cancel)
```

- Parameters are read from the `run` signature, so the checker, autocomplete, and generated docs know names, types, and defaults automatically.
- `ctx.cancel` lets skip, load, and rewind finish or abort animations instantly.
- Actions in configured folders are discovered automatically.

### 5.5 Cast looks

| Look | Description |
|---|---|
| `SpriteSetLook` | One texture per mood, found by folder convention or explicit table. |
| `LayeredLook` | Builds a character from named layer groups (body, outfit, face, accessory). Mood strings like `"face=smile, outfit=coat"`. |
| `SceneLook` | Any `PackedScene`; moods map to `AnimationPlayer` animations or methods. Supports 3D characters rendered into a viewport. |
| `VideoLook` | `VideoStreamPlayer`, one clip per mood. |

Cast extras: display name (translatable), name and text colors, portrait for dialogue boxes, speaker highlighting (dim others), lip-flap hook for voiced lines, and per-character typing sound.

### 5.6 Asset finding

- Conventions configured in `StoryConfig`, for example `res://story/cast/{id}/{mood}.png` and `res://story/backdrops/{id}.png`.
- The checker warns about missing files at import time.
- `AssetFinder` scans upcoming instructions and preloads with `ResourceLoader.load_threaded_request`, within a memory budget.

---

## 6. Built-in Actions (initial set)

| Group | Actions |
|---|---|
| Scenery | `backdrop()`, `prop()`, `clear_props()` |
| Cast | `enter()`, `exit()`, `move_to()`, `mood`, `tint`, `flip`, `scale_to()`, `line_up()`, `exit_all()` |
| Dialogue | `dialogue_style()`, `hide_dialogue()`, `show_dialogue()`, `clear_page()` |
| Audio | `music()`, `stop_music()`, `sound()`, `ambience()`, `voice()`, `stop_audio()` |
| Camera and effects | `camera.zoom()`, `camera.pan()`, `shake()`, `flash()`, `weather()`, `filter()`, `transition()` |
| Flow and time | `wait()`, `skip_lock()`, `autosave()` |
| Player input | `ask_text()`, `ask_number()` |
| Collection | `collect()` |
| Integration | `emit()`, `play_movie()`, `change_scene()`, `preload()` |

Reference docs for every action are generated from their signatures and `##` doc comments.

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
| Choice styles: hotspots, messenger reply, timed | Point-and-click areas, chat replies, countdown choices | Pro phase | Pro |
| Menus and default theme | Title, pause, save/load, settings, history, confirm, loading, text input | M3 | Free |
| Theme and template pack | Extra polished themes and genre starter projects (mystery, romance, messenger story) | Pro phase | Pro |
| Basic effects | Flash, fade to color, blur, vignette | M4 | Free |
| Effects pack | Rain, snow, fog, light rays, glitch, film grain, particles presets | Pro phase | Pro |
| Collection | Gallery, music room, codex | M4 | Free |
| Localization runtime | String tables, runtime language switch | M4 | Free |
| Translation workflow | CSV and `.po` export and import, missing-line reports, translator preview mode | Pro phase | Pro |
| Voice production tools | Per-actor voice scripts, automatic clip mapping by line id, lip-flap from audio | Pro phase | Pro |
| Debug console | Run TaleScript lines, inspect and edit vars, jump to beats | M4 | Free |
| Live reload | Edit a tale during play and continue from the same line | M4 | Free |
| Movies | Full-screen video playback | M4 | Free |
| Embedding preset | Dialogue-only mode for 2D and 3D games, trigger tales from game events | M4 | Free |
| Visual editor | Card-based editing of tales, synced with text (§9) | M5 | Free |
| Story Map | Graph of beats, jumps, calls, and choices (§9) | M5 | Free |
| Stage preview and play from here | Live preview of the stage at any line; launch the game from that line | Pro phase | Pro |
| Story analytics | Route coverage, word counts per character, choice statistics from playtests | Pro phase | Pro |
| Language server | Autocomplete and diagnostics in VS Code and other editors | Post-1.0 | Free |

---

## 8. Editor Tooling

| Tool | Description | Milestone |
|---|---|---|
| Story screen | Main-screen editor for `.tale` files: syntax highlighting in the editor's colors, live problem list, save and reimport | M1 ✔ |
| Import diagnostics | Errors and warnings with clickable locations | M1 |
| Setup wizard | Config, folders, starter scene, sample tale | M1 |
| Cast inspector | Custom inspector with mood previews and a "test enter" button | M2 |
| Autocomplete | In-editor completion for actions, cast ids, moods, beats, vars | M4 |
| Live reload | Re-import on save and resume | M4 |
| Translation tool | Create and update string tables, report missing lines | M4 |
| Visual editor and Story Map | See §9 | M5 |
| Language server | LSP for VS Code and other editors | Post-1.0 |

---

## 9. Visual Editor and Story Map

The visual editor lets writers build complete tales without typing syntax, while programmers keep working in text. It is a headline feature and a major point of difference from other visual novel tools.

### 9.1 Principles

1. **One source of truth.** The `.tale` file is always the saved format. The visual editor and the text editor are two views of the same file, and a change in either appears in the other immediately.
2. **Clean round trips.** Visual edits change only the affected lines and keep comments and formatting (§4.10), so writers and programmers can work on the same files in version control.
3. **Nothing is lost.** Any code the visual editor cannot represent as a card appears as an editable "script card" holding the raw text.
4. **Godot-native.** Built as a main-screen editor plugin (a "Story" tab next to 2D, 3D, Script, and AssetLib), using Godot's own controls, theme, and `EditorUndoRedoManager` for undo.

### 9.2 Layout

```
┌──────────────────────── Story tab ────────────────────────┐
│ Tale list │        Beat editor (cards)        │  Inspector │
│           │                                   │  for the   │
│ prologue  │  [Backdrop: classroom_morning]    │  selected  │
│  ▸ start  │  [Mira enters: smile, left]       │  card      │
│  ▸ honest │  [Narration: "Sunlight spills…"]  │            │
│  ▸ bluff  │  [Mira (curious): "Nervous…?"]    │  Stage     │
│ chapter_1 │  [Choice ▾ 3 options]             │  preview   │
│           │                                   │  (Pro)     │
├───────────┴───────────────────────────────────┴────────────┤
│ Story Map (toggle): beats as nodes, arrows for jump/call/choice │
└────────────────────────────────────────────────────────────┘
```

### 9.3 Cards

| Card | Editing controls |
|---|---|
| Narration | Text field with a markup toolbar (bold, pause, speed, sound) |
| Dialogue | Speaker dropdown with portraits, mood picker with thumbnails, text field |
| Choice | One lane per option, each with its own condition and nested cards |
| Condition | `if` / `elif` / `else` lanes with an expression builder or a free-text expression |
| Action | Form generated automatically from the action's signature: typed fields, color pickers, asset pickers with previews |
| Jump / call | Beat picker with search |
| Set variable | Variable picker, operator, value |
| Script | Raw TaleScript for anything else |

Interaction: drag to reorder, multi-select, copy and paste between tales, keyboard navigation for every action, collapse and expand nested lanes, and inline checker warnings on each card.

### 9.4 Story Map

- Each beat is a `GraphNode`; arrows show jumps, calls, and choice branches, colored by tale.
- Automatic layout with manual adjustment saved to a sidecar file (`.tale.map`), so the tale file itself stays clean.
- Highlights unreachable beats, dead ends, and missing targets.
- Drag from a node's output to empty space to create and link a new beat.
- Double-click a node to open it in the beat editor.
- Pro overlay: route coverage from playtests and word counts per branch.

### 9.5 Stage preview (Pro)

Selecting any card shows the stage as it would look at that line. The director runs the tale up to that point in a fast "dry run" mode with all animations skipped, then renders the result in an editor viewport. A "Play from here" button launches the game at the same point with the computed state.

---

## 10. Player-Facing Systems

- **Dialogue boxes:** each style is a scene implementing a small `DialogueBox` interface (`show_line`, `finish_typing`, `clear`). Restyle with a Godot `Theme` or replace the scene.
- **Typewriter:** per character, per word, fade-in, or instant; speed from settings; typing sounds per cast member.
- **Playback controls:** continue (click, key, tap, gamepad), auto (delay scales with line length and voice length), skip (seen lines only or all), hide UI, rewind (wheel, key, gamepad). All bound through `InputMap` actions.
- **Saves:** JSON in `user://saves/` with version number and migration hooks; thumbnails as PNG; optional encryption.
- **Rewind:** each crew member's `capture()` result stored per line in a ring buffer, delta-compressed, with `@no_rewind` barriers.
- **Read tracking:** seen line ids stored in global data, used by skip and by "new line" indicators.
- **Accessibility:** text size and font options, high-contrast theme, auto mode, screen reader hook for dialogue text, configurable typing speed including instant.

---

## 11. Milestones

### M0: Scaffolding (1 week)
- Pin Godot 4.7.2 in CI. ✔
- Addon skeleton (`plugin.cfg`, `EditorPlugin`, autoload registration, `StoryCrew` base, `StoryConfig`). ✔
- Built-in test runner running headless in GitHub Actions on Linux and Windows, plus an optional non-blocking job on the newest Godot beta. ✔
- Contribution guide with the clean-room rules from §2, decision records, issue and pull request templates. ✔
- License file added (MIT). ✔
- Private repository for the Pro add-on: deferred with the Pro tier (decision 0009).

### M1: TaleScript and a minimal playable (5 weeks)
- Formal grammar and specification (`docs/talescript-spec.md`). ✔
- Lexer and **lossless** parser with round-trip and golden tests. ✔
- Checker, compiler, import plugin. ✔
- Director with await, call stack, skip, auto. ✔
- Vars, global vars, safe expression evaluator, `Story.expose`. ✔
- Flow: beats, `jump`, beat calls, `if`/`elif`/`else`, `match`, `choose`. ✔
- Classic dialogue box and list choice menu. ✔
- Syntax highlighting, in a "Story" editor screen with live checking. ✔
- **Exit criteria:** the §4.2 sample runs end to end with placeholder art; parsing and re-printing every fixture reproduces the original file byte for byte.

### M2: Stage, cast, audio (5 weeks)
- Cast looks (sprite set, layered, scene), backdrops, props, core transitions, camera, audio, asset finder with preloading. ✔
- Demo plays the §4.2 sample with original placeholder art and music generated by `tools/demo_assets/generate.py`. ✔
- **Exit criteria:** the §4.2 sample runs with real art, music, and transitions.

### M3: Saves and menus (4 weeks)
- Saves, rewind, history, read tracking, settings.
- Dialogue and choice styles, full menu set with one shared theme.
- **Exit criteria:** a 15-minute original demo story exports and plays on the platforms chosen for M3 (§14).

### M4: Production features (4 weeks)
- Effects, collection, localization, debug console, live reload, autocomplete, movies, embedding preset.
- **Exit criteria:** demo translated into a second language; demo embedded in a small 3D scene.

### M5: Visual editor and Story Map (6 weeks)
- Story tab, beat editor with all card types, inspector, undo and redo.
- Story Map with auto layout and problem highlighting.
- Usability test with at least three writers who do not program.
- **Exit criteria:** a writer builds a branching five-minute scene entirely in the visual editor; the resulting file reads naturally as text and diffs cleanly.

### M6: Launch preparation (3 weeks)
- Legal review (§2.8).
- Full documentation, original sample project, trailer and screenshots.
- Publish on the Godot Asset Library or Asset Store and GitHub.

### 1.0 Release (about 28 weeks after M0 starts)

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
| Core transitions and basic effects | Hotspot, messenger, and timed choice menus |
| Audio, camera, movies | Transition pack and effects pack |
| Saves, rewind, history, read tracking | Theme and genre template pack |
| Classic and full-page dialogue, list choices | Translation workflow tools |
| Full menu set and default theme | Voice production tools |
| Collection, localization runtime | Stage preview and play from here |
| Debug console, live reload, embedding preset | Story analytics |
| **Visual editor and Story Map** | Priority support and early access builds |

The visual editor sits in the free tier because it is the strongest reason to choose StoryTeller; putting it behind payment would limit adoption. This is a recommendation and is listed in §19 for confirmation.

### 12.3 Pricing and sales (to explore)

- **Pricing models:** one-time purchase with a year of updates, yearly subscription, or per-seat licenses for teams. A one-time price with paid major upgrades is common for game tools and simple to explain.
- **Storefronts:** the official Godot Asset Store has announced plans for paid assets, but reports through mid-2026 describe paid listings as not yet open to all creators; check its current status during M6. Alternatives include itch.io, Gumroad, Lemon Squeezy, and a dedicated website.
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

**Current recommendation:** design the default UI for mouse, keyboard, gamepad, and touch from M1, test desktop and web from M3, and add mobile testing in M4. This keeps mobile-friendly layouts from becoming a costly retrofit.

---

## 15. Repository Layout (proposed)

```
StoryTeller/                     # public repository (free tier)
├── addons/storyteller/
│   ├── plugin.cfg
│   ├── plugin.gd
│   ├── core/            # Story autoload, StoryCrew base, StoryConfig
│   ├── talescript/      # lexer, lossless parser, checker, compiler, importer, evaluator
│   ├── director/        # TaleDirector, TaleContext, cancellation
│   ├── actions/         # built-in TaleAction classes
│   ├── stage/           # cast, looks, backdrops, props, camera
│   ├── crew/            # audio, saves, rewind, history, collection, locale...
│   ├── ui/              # dialogue styles, choice styles, menus, theme
│   ├── effects/         # basic effects and shaders
│   ├── transitions/     # core transition shaders and masks
│   └── editor/          # highlighter, inspectors, wizard, visual editor, Story Map
├── demo/                # original sample story and assets
├── tests/               # GUT tests and .tale fixtures
└── docs/                # guides, TaleScript spec, decisions, this plan

StoryTellerPro/                  # private repository (Pro tier)
├── addons/storyteller_pro/
│   ├── looks/  ui/  effects/  transitions/
│   ├── tools/           # translation, voice, analytics
│   └── editor/          # stage preview, play from here
└── tests/
```

---

## 16. Testing Strategy

- **Unit tests (built-in runner):** lexer, parser, checker messages, expression evaluator, save round trips, rewind correctness.
- **Round-trip tests:** every fixture `.tale` is parsed and printed back unchanged; scripted visual-editor operations produce the expected minimal text diffs.
- **Golden tests:** every fixture compiles to an instruction dump compared against a stored snapshot.
- **Playthrough tests:** headless runs that pick scripted choices and assert vars, visited beats, and stage state at checkpoints.
- **Interruption tests:** save, load, skip, and rewind at every line of the fixtures to catch async cancellation bugs.
- **Pro compatibility tests:** the Pro test suite runs against each free-tier build to catch broken extension points.
- **CI:** headless Godot on Linux for the supported version, a non-blocking job on the newest beta, and export smoke tests for each target platform.

---

## 17. Documentation Plan

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
| Async cancellation bugs (skip, load, rewind mid-effect) | Broken stage state | Single cancellation path through `ctx.cancel`; interruption tests. |
| Rewind memory use | Slow on mobile | Delta snapshots, configurable depth, `@no_rewind`. |
| Overlap with Dialogic, Dialogue Manager, Escoria | Low adoption | Differentiate with the visual editor, a GDScript-style language, a full visual novel stack, and rewind. |
| Unsafe scripts from mods | Code execution | Own evaluator; only explicitly exposed members are reachable. |

---

## 19. Open Questions

1. **Platforms (D9):** exploring; see §14.
2. **Product name:** keep "StoryTeller" after a trademark search, or choose a more distinctive name?
3. **Dialogue strings:** require quotes (closest to GDScript, as planned) or also allow an unquoted shorthand for heavy prose?
4. **Pro tier details** (deferred): feature split (§12.2), pricing, and storefront.

---

## 20. Immediate Next Steps

1. Run a quick trademark and name search for "StoryTeller".
2. Start M3: saves with slots and thumbnails, rewind, history, settings, more dialogue styles, and the menu set.
3. Optional: a VS Code syntax file for writers who use an external editor.
