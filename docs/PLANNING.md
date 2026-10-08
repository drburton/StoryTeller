# StoryTeller: Planning Document

StoryTeller is a visual novel and interactive story framework for **Godot 4**. Writers author stories in **TaleScript**, a small language that looks and feels like GDScript. The framework handles characters, scenery, dialogue boxes, choices, audio, saving, localization, and menus so creators can ship a complete visual novel, or add story sequences to any Godot game, with little or no extra code.

Status: **Draft v0.2** (planning stage, no code yet)

Changes in v0.2:
- Replaced the Naninovel-style script syntax with TaleScript, a GDScript-flavored language.
- Introduced original terminology and concepts throughout (see §3).
- Added §2, Originality and IP Guidelines.
- Reframed the feature scope around standard visual novel genre features.

---

## 1. Goals

1. **Familiar to Godot users.** Anyone who has written GDScript can read and write TaleScript within minutes: same comments, indentation, `var`, `if`/`elif`/`else`, `match`, `await`, and annotations.
2. **Friendly to writers.** Dialogue reads like a screenplay. A non-programmer can write a full scene after reading a one-page cheat sheet.
3. **Batteries included.** A new project gets a working title screen, save/load, settings, history log, and dialogue box out of the box.
4. **Godot-native.** Built on nodes, resources, signals, themes, tweens, shaders, `RichTextLabel` effects, and the `TranslationServer`.
5. **Extensible.** Developers add custom actions, cast types, effects, and menus by writing small GDScript classes.
6. **Embeddable.** Works as a standalone visual novel engine and as a dialogue or cutscene system inside 2D and 3D games.
7. **Fast iteration.** Live reload of story files while the game runs, clear errors with file and line, and an in-game debug console.

### Non-goals for 1.0

- Compatibility with, or import from, any other engine's script format.
- A full visual programming language replacing text scripts.
- Spine or Live2D support in the core package (planned as optional add-ons).
- Multiplayer storytelling.
- Godot 3.x support.

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
8. **Legal review.** Before a public 1.0 release (and before any paid distribution), the maintainers obtain a short review from a lawyer familiar with software IP. This plan is general guidance and does not constitute legal advice.

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
.tale ─▶ Lexer ─▶ Parser ─▶ AST ─▶ Checker ─▶ Compiler ─▶ Tale resource (instructions + metadata)
```

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

Standard visual novel genre features, grouped by milestone (see §10).

| Feature | Description | Milestone |
|---|---|---|
| TaleScript | Language, compiler, checker, syntax highlighting | M1 |
| Director | Execution, await, call stack, skip and auto modes | M1 |
| Variables and expressions | Story vars, global vars, safe evaluator, exposure API | M1 |
| Dialogue box: classic | Bottom box with name plate and typewriter text | M1 |
| Choice menu: list | Vertical button list | M1 |
| Cast and looks | Sprite set, layered, scene, video | M2 |
| Backdrops and props | With transitions | M2 |
| Transition library | Fade, dissolve with mask texture, slide, wipe, iris, pixelate, ripple | M2 |
| Audio | Music crossfade, sounds, voice, ambience, buses | M2 |
| Camera | Zoom, pan, shake, rotate | M2 |
| Saves | Slots with thumbnails, quick save, auto save, global data, versioned format | M3 |
| Rewind | Step back through lines and choices | M3 |
| History | Log with voice replay and jump back | M3 |
| More dialogue styles | Full page, caption, speech bubble, messenger | M3 |
| More choice styles | Hotspots (point-and-click), messenger reply, timed | M3 |
| Menus | Title, pause, save/load, settings, history, confirm, loading, text input | M3 |
| Effects | Rain, snow, fog, light rays, blur, flash, glitch, vignette | M4 |
| Collection | Gallery, music room, codex | M4 |
| Localization | String tables, CSV and `.po` export, runtime language switch | M4 |
| Debug console | Run TaleScript lines, inspect and edit vars, jump to beats | M4 |
| Live reload | Edit a tale during play and continue from the same line | M4 |
| Play from here | Launch the game from a chosen line in the editor | M4 |
| Movies | Full-screen video playback | M4 |
| Embedding preset | Dialogue-only mode for 2D and 3D games, trigger tales from game events | M4 |
| Story Map | Visual map of beats, jumps, calls, and choices | M5 |
| Writer view | Form-based editor for people who prefer not to type syntax | M5 |
| Language server | Autocomplete, hover docs, go to beat, diagnostics in external editors | M5 |

---

## 8. Editor Tooling

| Tool | Description | Milestone |
|---|---|---|
| Syntax highlighting | `EditorSyntaxHighlighter` for `.tale` in Godot's script editor, using GDScript's color theme | M1 |
| Import diagnostics | Errors and warnings with clickable locations | M1 |
| Setup wizard | Config, folders, starter scene, sample tale | M1 |
| Cast inspector | Custom inspector with mood previews and a "test enter" button | M2 |
| Autocomplete | In-editor completion for actions, cast ids, moods, beats, vars | M4 |
| Play from here | Right-click a line to launch at that point | M4 |
| Live reload | Re-import on save and resume | M4 |
| Translation tool | Create and update string tables, report missing lines | M4 |
| Story Map | Main-screen tab built on `GraphEdit` | M5 |
| Writer view | Line-by-line form editor | M5 |
| Language server | LSP for VS Code and other editors | M5 |

---

## 9. Player-Facing Systems

- **Dialogue boxes:** each style is a scene implementing a small `DialogueBox` interface (`show_line`, `finish_typing`, `clear`). Restyle with a Godot `Theme` or replace the scene.
- **Typewriter:** per character, per word, fade-in, or instant; speed from settings; typing sounds per cast member.
- **Playback controls:** continue (click, key, tap, gamepad), auto (delay scales with line length and voice length), skip (seen lines only or all), hide UI, rewind (wheel, key, gamepad). All bound through `InputMap` actions.
- **Saves:** JSON in `user://saves/` with version number and migration hooks; thumbnails as PNG; optional encryption.
- **Rewind:** each crew member's `capture()` result stored per line in a ring buffer, delta-compressed, with `@no_rewind` barriers.
- **Read tracking:** seen line ids stored in global data, used by skip and by "new line" indicators.
- **Accessibility:** text size and font options, high-contrast theme, auto mode, screen reader hook for dialogue text, configurable typing speed including instant.

---

## 10. Milestones

### M0: Scaffolding (1 week)
- Addon skeleton (`plugin.cfg`, `EditorPlugin`, autoload registration).
- GUT test framework running headless in GitHub Actions.
- Contribution guide including the clean-room rules from §2, decision log folder, issue templates.

### M1: TaleScript and a minimal playable (5 weeks)
- Formal grammar, lexer, parser, checker, compiler, import plugin.
- Director with await, call stack, skip, auto.
- Vars, global vars, safe expression evaluator, `Story.expose`.
- Flow: beats, `jump`, beat calls, `if`/`elif`/`else`, `match`, `choose`.
- Classic dialogue box and list choice menu. Syntax highlighting.
- **Exit criteria:** the §4.2 sample runs end to end with placeholder art.

### M2: Stage, cast, audio (5 weeks)
- Cast with all four looks, backdrops, props, transitions, camera, audio, asset finder with preloading.
- **Exit criteria:** the §4.2 sample runs with real art, music, and transitions.

### M3: Saves and menus (4 weeks)
- Saves, rewind, history, read tracking, settings.
- All dialogue and choice styles, full menu set with one shared theme.
- **Exit criteria:** a 15-minute original demo story exports and plays on desktop and web.

### M4: Production features (4 weeks)
- Effects, collection, localization, debug console, live reload, play from here, autocomplete, movies, embedding preset.
- **Exit criteria:** demo translated into a second language; Android export verified; demo embedded in a small 3D scene.

### M5: Advanced tooling (ongoing)
- Story Map, writer view, language server and VS Code extension.
- Optional add-ons: C# API, Spine, Live2D, community action packs.

### 1.0 Release
- Stable API, full docs, original sample project, legal review (§2.8), Asset Library listing.

---

## 11. Repository Layout (proposed)

```
StoryTeller/
├── addons/storyteller/
│   ├── plugin.cfg
│   ├── plugin.gd
│   ├── core/            # Story autoload, StoryCrew base, StoryConfig
│   ├── talescript/      # lexer, parser, checker, compiler, importer, evaluator
│   ├── director/        # TaleDirector, TaleContext, cancellation
│   ├── actions/         # built-in TaleAction classes
│   ├── stage/           # cast, looks, backdrops, props, camera
│   ├── crew/            # audio, saves, rewind, history, collection, locale...
│   ├── ui/              # dialogue styles, choice styles, menus, theme
│   ├── effects/         # effect scenes and shaders
│   ├── transitions/     # transition shaders and masks
│   └── editor/          # highlighter, inspectors, wizard, Story Map
├── demo/                # original sample story and assets
├── tests/               # GUT tests and .tale fixtures
├── docs/                # guides, TaleScript spec, decisions, this plan
└── tools/lsp/           # language server (M5)
```

---

## 12. Testing Strategy

- **Unit tests (GUT):** lexer, parser, checker messages, expression evaluator, save round trips, rewind correctness.
- **Golden tests:** every fixture `.tale` compiles to an instruction dump compared against a stored snapshot.
- **Playthrough tests:** headless runs that pick scripted choices and assert vars, visited beats, and stage state at checkpoints.
- **Interruption tests:** save, load, skip, and rewind at every line of the fixtures to catch async cancellation bugs.
- **CI:** headless Godot on Linux; export smoke tests for Windows, Linux, and Web.

---

## 13. Documentation Plan

- **Getting Started:** install, wizard, first scene in ten minutes.
- **TaleScript for Writers:** cheat sheet plus examples, no programming background assumed.
- **TaleScript for GDScript Users:** a short page listing only the differences from GDScript.
- **Action Reference:** generated from action signatures and doc comments.
- **Developer Guide:** custom actions, looks, crew members, dialogue styles, menus, embedding.
- **Recipes:** relationship meters, inventory checks, mini-game handoff, phone-messenger story, timed choices.

---

## 14. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| IP or trademark concerns | Takedown or legal cost | Clean-room rules (§2), original vocabulary and language, decision log, legal review before 1.0. |
| TaleScript drifts from GDScript and confuses users | Steeper learning curve | Keep the five deliberate additions only; "for GDScript users" doc page reviewed each release. |
| Very large scope | Missed milestones | Strict exit criteria; M5 items can slip freely. |
| Async cancellation bugs (skip, load, rewind mid-effect) | Broken stage state | Single cancellation path through `ctx.cancel`; interruption tests. |
| Rewind memory use | Slow on mobile | Delta snapshots, configurable depth, `@no_rewind`. |
| Godot 4.x API changes | Breakage | Pin a minimum version, run CI on latest stable. |
| Overlap with Dialogic, Dialogue Manager, Escoria | Low adoption | Differentiate with a GDScript-style language, a full visual novel stack, rewind, built-in menus, and the Story Map. |
| Unsafe scripts from mods | Code execution | Own evaluator; only explicitly exposed members are reachable. |

---

## 15. Open Questions

1. **Minimum Godot version:** 4.3 or 4.4+?
2. **Names:** keep "TaleScript", `.tale`, and `beat`, or choose alternatives?
3. **Dialogue strings:** require quotes (closest to GDScript, as planned) or also allow an unquoted shorthand for heavy prose?
4. **C# support:** needed before 1.0?
5. **License:** MIT, Apache 2.0, or other?
6. **Target platforms:** desktop first, or mobile and web from M3?
7. **Distribution:** free and open source, or a paid tier?

---

## 16. Immediate Next Steps

1. Resolve the open questions.
2. Complete M0 scaffolding and add the clean-room rules to `CONTRIBUTING.md`.
3. Write the formal TaleScript grammar in `docs/talescript-spec.md`, including a precise list of every difference from GDScript.
4. Implement the lexer and parser with golden tests.
