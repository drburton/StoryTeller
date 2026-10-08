# StoryTeller: Planning Document

StoryTeller is a visual novel and narrative framework for **Godot 4**, inspired by the feature set of Naninovel for Unity. Writers author stories in plain-text script files using a small, readable language. The framework handles characters, backgrounds, dialogue boxes, choices, audio, saving, localization, and UI so creators can ship a complete visual novel (or add story sequences to any Godot game) with little or no code.

Status: **Draft v0.1** (planning stage, no code yet)

---

## 1. Goals

1. **Writer-first.** A non-programmer can write a full scene in a text editor after reading a one-page cheat sheet.
2. **Batteries included.** A new project gets a working title menu, save/load, settings, backlog, and dialogue UI out of the box.
3. **Godot-native.** Built on Godot nodes, resources, signals, themes, tweens, shaders, and the translation server. No foreign runtime.
4. **Extensible.** Developers add custom commands, actor types, effects, and UI by writing small GDScript classes, with no forks of the addon.
5. **Embeddable.** Works as a standalone visual novel engine and also as a dialogue/cutscene system inside 2D or 3D games.
6. **Fast iteration.** Hot reload of scripts while the game runs, clear error messages with file and line, and a debug console.

### Non-goals (for 1.0)

- A full node-based visual programming language replacing text scripts.
- Spine/Live2D support in the core package (planned as optional add-ons later).
- Networked or multiplayer storytelling.
- Godot 3.x support.

---

## 2. Target Platform and Tech Choices

| Area | Decision | Notes |
|---|---|---|
| Engine | Godot 4.3+ | Uses typed GDScript, `@export_tool_button`-era editor APIs where available. |
| Language | GDScript for core | Widest compatibility (works in non-.NET builds). A thin C# facade can come later. |
| Distribution | Godot addon in `addons/storyteller/` | Published to the Godot Asset Library and GitHub releases. |
| Script format | `.story` text files | Imported via `EditorImportPlugin` into a compiled `StoryScript` resource. |
| Expressions | Custom safe evaluator | Godot's `Expression` class can call arbitrary methods, so we parse a restricted grammar ourselves (see §5.6). |
| Saves | JSON files under `user://` | Human-readable, versioned, easy to migrate. Optional binary/encrypted mode later. |
| Localization | Godot `TranslationServer` + per-script string tables | Exports to CSV and gettext `.po`. |
| License | TBD (MIT suggested) | See Open Questions. |

---

## 3. Feature Overview (Naninovel parity map)

The table maps major Naninovel capabilities to StoryTeller plans and the target milestone (see §9).

| Naninovel feature | StoryTeller plan | Milestone |
|---|---|---|
| NaniScript language | StoryScript language (`.story`) | M1 |
| Text printers (dialogue, fullscreen/NVL, wide, chat, bubble) | Printer actors with swappable UI scenes | M1 (dialogue), M3 (rest) |
| Choice handlers | Choice actors (button list, button area, chat reply) | M1 (list), M3 (rest) |
| Characters (sprite, layered, generic, video) | Character actors with pluggable implementations | M2 |
| Backgrounds | Background actors (sprite, scene, video) | M2 |
| Transitions and effects | Shader-based transition library and effect spawner | M2 / M4 |
| Audio (BGM, SFX, voice, auto voice) | Audio service with buses and voice mapping | M2 |
| Custom variables and expressions | Variable service with safe expression engine | M1 |
| Conditionals, goto, gosub | Flow control commands with nested blocks | M1 |
| Save/load, quick save, global state, settings | State service with slot system | M3 |
| Rollback | Snapshot-based rollback | M3 |
| Backlog | Backlog UI with voice replay | M3 |
| Skip / auto mode | Playback modes on the script player | M1 |
| Unlockables (CG gallery, tips) | Unlockable service plus gallery and tips UI | M4 |
| Built-in UI (title, settings, save menu, etc.) | Theme-able default UI scenes | M3 |
| Localization | Script and UI localization tooling | M4 |
| Camera control | Camera service (zoom, offset, shake, rotate) | M2 |
| Movies | Movie command using `VideoStreamPlayer` | M4 |
| Story graph / visual editor | Editor main-screen plugin using `GraphEdit` | M5 |
| IDE support (VS Code extension) | Syntax highlighting in Godot editor, then LSP / VS Code extension | M1 (highlight), M5 (LSP) |
| Resource providers | Resource locator with path conventions and preloading | M2 |
| Dev console | In-game debug console and variable inspector | M4 |
| Hot reload | Re-import and resume on file change | M4 |
| Custom commands / actors via C# | Custom commands / actors via GDScript classes | M1 / M2 |
| Adventure / dialogue mode in non-VN games | Embedding API and "dialogue only" preset | M4 |

---

## 4. Architecture

### 4.1 High-level structure

```
StoryTeller (autoload singleton)
├── ScriptPlayer          # runs commands, handles waiting, skip, auto
├── ScriptManager         # loads/caches compiled StoryScript resources
├── VariableManager       # custom variables, expression evaluation
├── ActorManagers
│   ├── CharacterManager
│   ├── BackgroundManager
│   ├── PrinterManager
│   └── ChoiceManager
├── AudioManager          # bgm, sfx, voice, ambient
├── CameraManager
├── EffectManager         # spawnable effects (rain, shake, glitch...)
├── StateManager          # save/load, global state, rollback snapshots
├── SettingsManager       # player preferences
├── UnlockableManager
├── LocalizationManager
├── InputManager          # continue, skip, auto, rollback, hide UI
├── UIManager             # title, pause, save/load, backlog, settings
└── ResourceLocator       # path resolution + preloading
```

Each manager is a **service**: a class extending `StoryService` with a common lifecycle.

```gdscript
class_name StoryService extends Node

func initialize(config: StoryConfig) -> void: pass   # once at engine start
func reset() -> void: pass                          # on new game / load
func save_state(state: Dictionary) -> void: pass    # write into snapshot
func load_state(state: Dictionary) -> void: pass    # restore from snapshot
func destroy() -> void: pass
```

Services are registered in `StoryConfig` so users can replace a built-in service with their own subclass.

### 4.2 Configuration

- `StoryConfig` is a `Resource` (`res://storyteller/config.tres`) with sub-resources per service (printer defaults, audio buses, save slot count, resource paths, etc.).
- A **Project Settings** page ("StoryTeller") plus a custom inspector exposes common options.
- A setup wizard (first run of the plugin) creates the config, default folders, a sample script, and a starter scene.

### 4.3 Scene layering

A `StoryStage` scene (a `CanvasLayer` stack) owns the visual layers, from back to front:

1. Backgrounds
2. Characters
3. Effects (world)
4. Printers and choices
5. Effects (screen / post-process)
6. UI (menus, backlog, console)

For 3D games the stage can render into a `SubViewport` overlay, or the user can disable the background/character layers and use only printers and choices.

### 4.4 Command execution model

- Each command is a class extending `StoryCommand`, with typed parameters declared in a static schema.
- `execute(ctx) -> void` may be **async** (uses `await`). The player awaits it when the command is "blocking" (`wait:true` or the command's default).
- Commands receive an `AsyncToken`-style object so skip/fast-forward and cancellation (on load or rollback) can complete animations instantly.
- The player tracks `PlaybackSpot` (script path + line index + inline index) for saves, rollback, and the backlog.

```gdscript
class_name CmdShake extends StoryCommand

const ALIASES := ["shake"]
@export var target: String = "camera"
@export var intensity: float = 0.5
@export var duration: float = 0.3

func execute(ctx: StoryContext) -> void:
    await ctx.camera.shake(intensity, duration, ctx.token)
```

Custom commands are discovered by scanning configured folders for `StoryCommand` subclasses (or registered explicitly in config).

### 4.5 Actors

An **actor** is any named, stateful visual entity controlled by script: characters, backgrounds, printers, choice handlers.

Common actor state: `id`, `visible`, `position`, `rotation`, `scale`, `tint`, `appearance`, plus implementation-specific data. State is serializable for saves and rollback.

Pluggable **implementations** per actor type:

| Implementation | Character | Background | Notes |
|---|---|---|---|
| Sprite | ✔ | ✔ | One texture per appearance. |
| Layered | ✔ | | Composes body/face/outfit layers from a scene; appearance like `Body>Uniform,Face>Smile`. |
| Scene (generic) | ✔ | ✔ | Any user `PackedScene`; appearances map to `AnimationPlayer` animations or method calls. |
| Video | ✔ | ✔ | `VideoStreamPlayer` (Theora/OGV). |
| Spine / Live2D | later | | Optional add-on packages. |

Character extras: display name (localizable), name color, message color, avatar image, auto-highlight speaker, lip-sync hooks, look direction, pose presets.

### 4.6 Resource resolution

- Convention-based paths, configurable in `StoryConfig`, e.g. `res://story/characters/{actor}/{appearance}.png`.
- Explicit mapping tables in actor metadata for anything that does not follow conventions.
- `ResourceLocator` preloads resources for upcoming commands using `ResourceLoader.load_threaded_request`, with a configurable look-ahead window and memory budget. Unused resources are released at script boundaries.

---

## 5. StoryScript Language

### 5.1 Design principles

- Plain text, UTF-8, one statement per line.
- Readable without knowing the syntax; dialogue looks like a screenplay.
- Stays close to Naninovel conventions so experienced users feel at home, with small cleanups.

### 5.2 Line types

| Prefix | Line type | Example |
|---|---|---|
| (none) | Generic text (narration or dialogue) | `Kohaku: Good morning!` |
| `@` | Command | `@back Classroom.Day` |
| `#` | Label | `# after_school` |
| `;` | Comment | `; TODO rewrite this scene` |

### 5.3 Sample script

```
; prologue.story
# start
@back Classroom transition:CrossFade time:1
@bgm MorningTheme loop:true volume:0.8
@char Kohaku.Happy pos:30,0

Kohaku: Morning! You're early today.[i] Couldn't sleep?
@char Kohaku.Thinking
Kohaku: Hmm, maybe it's the exam.

@choice "Admit you were nervous" goto:.nervous
@choice "Pretend everything is fine" goto:.fine set:bravado+=1
@stop

# nervous
Kohaku: Same here, honestly.
@goto .walk

# fine
Kohaku: Wow, look at you, all confident.

# walk
@if bravado > 0
    Kohaku: Let's see if that confidence lasts until lunch.
@else
    Kohaku: Let's walk together, then.
@endif

@hide Kohaku
@goto Chapter1
```

### 5.4 Generic text lines

- `Name: text` sets the speaker (character id or display name lookup). Plain text with no prefix is narration.
- Inline commands in square brackets: `[i]` wait for input, `[w 0.5]` wait, `[speed 0.5]`, `[shake]`, `[sfx Bell]`, `[br]` line break.
- Expressions in curly braces: `Your score is {score}.`
- BBCode passes through to `RichTextLabel` (`[b]`, `[color=red]`, etc.). Inline commands that collide with BBCode tag names use an `@` form inside brackets: `[@shake]`.
- Optional per-line voice reference via a `voice:` tag or an auto-voice map keyed by line id.

### 5.5 Commands and parameters

- Syntax: `@command nameless_param named:value named2:value`.
- Parameter types: string, int, float, bool, list (`a,b,c`), named value (`Kohaku.Happy`), position (`30,0` in scene-relative percent), and any expression `{...}`.
- Common parameters on every command: `if:` (condition), `wait:` (block until done), `time:` (duration), `easing:`.

### 5.6 Variables and expressions

- Variable scopes: **local** (per playthrough, saved in slots) and **global** (prefixed `g_`, shared across all playthroughs, for unlocks and completion flags).
- `@set score += 10; met_kohaku = true`
- Expression grammar: arithmetic, comparison, logic (`and`, `or`, `not`, `&&`, `||`, `!`), string concatenation, ternary, parentheses, and a whitelist of functions (`random(a,b)`, `min`, `max`, `clamp`, `round`, `has_played(label)`, `is_unlocked(id)`, `t(key)` for localized strings).
- Developers register extra functions from GDScript: `StoryTeller.variables.register_function("affection", callable)`.
- The evaluator is a small Pratt parser compiled once at import time. It has no access to arbitrary objects, which keeps user-generated or modded scripts safe.

### 5.7 Flow control

| Command | Purpose |
|---|---|
| `@goto script.label` | Jump (same script: `.label`) |
| `@gosub script.label` / `@return` | Subroutine call with return stack |
| `@if` / `@elseif` / `@else` / `@endif` | Block conditionals (indentation optional, end markers required) |
| `@choice` | Add a choice option; `@stop` or the next generic line presents the choices |
| `@stop` | Halt playback until resumed by code or choice |
| `@wait` | Wait for time, input, or a signal |
| `@input` | Ask player for text into a variable |
| `@call` | Call a registered GDScript function (sandboxed through a whitelist) |
| `@emit` | Emit a named signal to game code |

### 5.8 Compilation pipeline

```
.story file ──EditorImportPlugin──▶ Lexer ─▶ Parser ─▶ AST ─▶ Validator ─▶ StoryScript (.res)
```

- The **validator** checks unknown commands, bad parameter types, missing labels, unknown actors/resources (warnings), and unclosed blocks. Errors appear in the Godot Output panel with clickable `file:line`.
- Each line gets a stable **line id** (hash of content plus an optional explicit `|#id|` suffix) used for localization and voice mapping, so reordering lines does not break translations.
- Runtime loading of raw `.story` files is also supported (for modding and hot reload) using the same parser.

---

## 6. Built-in Commands (initial set)

**Text and UI:** `print`, `printer`, `hide_printer`, `clear`, `choice`, `input`, `ui show/hide`, `title`
**Actors:** `char`, `back`, `hide`, `hide_all`, `arrange`, `look`, `pose`, `tint`, `move`, `scale`, `rotate`
**Audio:** `bgm`, `stop_bgm`, `sfx`, `stop_sfx`, `voice`, `stop_voice`, `ambient`
**Camera and effects:** `camera`, `shake`, `spawn`, `despawn`, `trans` (scene transition), `fade`
**Flow:** `goto`, `gosub`, `return`, `if`/`elseif`/`else`/`endif`, `stop`, `wait`, `skip on/off`, `lock_rollback`
**State:** `set`, `save`, `load`, `unlock`, `lock`, `reset`
**Integration:** `call`, `emit`, `movie`, `scene` (load a Godot scene), `preload`

Each command will have generated reference docs (from its parameter schema and doc comments), mirroring the per-command API reference Naninovel offers.

---

## 7. Player-Facing Systems

### 7.1 Text printers
- Dialogue (ADV), Fullscreen (NVL), Wide, Chat (messenger style), Bubble (speech bubble anchored to a character).
- Reveal modes: per character, per word, fade-in, instant; speed from settings.
- Each printer is a scene implementing a small `TextPrinter` interface, so users can restyle with Godot themes or replace it entirely.

### 7.2 Choice handlers
- Button list, button area (free-positioned buttons for point-and-click), chat reply.
- Timed choices, disabled options with reasons, "already chosen" styling.

### 7.3 Playback modes
- Continue (click/tap/key), **Auto** (delay scales with text length and voice), **Skip** (read-only or all text, configurable), **Hide UI**, **Rollback** (scroll wheel / gamepad).
- Input actions registered in the Godot InputMap with sensible defaults (mouse, keyboard, gamepad, touch).

### 7.4 Saving and state
- Slot saves with thumbnail screenshot, timestamp, chapter title, playtime.
- Quick save/load, auto save on configurable events.
- Global state (unlocks, read-text tracking, completion flags) stored separately from slots.
- Settings (volumes, text speed, auto delay, fullscreen, language) stored in a settings file.
- Save format includes a version number and a migration hook.

### 7.5 Rollback
- Before each blocking command the StateManager records a lightweight snapshot (services' `save_state`).
- Ring buffer with configurable depth; snapshots are diffed to keep memory low.
- Commands can mark themselves "not rollbackable" (e.g., `@call` with side effects) to create a rollback barrier.

### 7.6 Backlog
- Records speaker, text, voice clip, and playback spot.
- Replay voice and jump back to a line (if rollback allows).

### 7.7 Default UI
Title menu, pause menu, save/load menu, settings menu, backlog, CG gallery, tips/glossary, confirmation dialog, loading screen, text input dialog. All built from scenes using a shared `Theme`, so a project restyles everything by swapping one theme resource.

---

## 8. Editor Tooling

| Tool | Description | Milestone |
|---|---|---|
| Syntax highlighting | `EditorSyntaxHighlighter` for `.story` in Godot's script editor | M1 |
| Import validation | Errors/warnings on import with clickable locations | M1 |
| Setup wizard | Creates config, folders, starter scene and sample script | M1 |
| Actor editor | Inspector for characters/backgrounds with appearance previews | M2 |
| Play from line | Right-click a line in the editor to launch the game at that point | M4 |
| Hot reload | Re-import changed scripts and resume at the current line during play | M4 |
| Debug console | In-game console: run commands, inspect/set variables, jump to labels | M4 |
| Story graph | Main-screen tab showing scripts/labels and their goto/gosub/choice links (`GraphEdit`) | M5 |
| Visual script editor | Form-based line editor for writers who prefer not to type syntax | M5 |
| Language server | LSP providing completion, hover docs, go-to-label, diagnostics; VS Code extension uses it | M5 |
| Localization tool | Generate/update string tables, report missing translations | M4 |

---

## 9. Milestones

### M0: Project scaffolding (1 week)
- Repository layout, addon skeleton, plugin.cfg, autoload registration.
- GUT (Godot Unit Test) set up and running in CI (GitHub Actions, headless Godot).
- Coding standards, contribution guide, issue templates.

### M1: Core language and minimal playable (4-5 weeks)
- Lexer, parser, AST, validator, import plugin, `StoryScript` resource.
- Script player with async commands, waiting, skip, auto.
- Variables and the safe expression engine.
- Flow control (`goto`, `gosub`, `if` blocks, `choice`, `stop`, `wait`, `set`).
- One dialogue printer and one choice handler.
- Syntax highlighting.
- **Exit criteria:** the sample script in §5.3 (minus actors and audio) plays end to end.

### M2: Actors, audio, camera (4-5 weeks)
- Actor framework with sprite, layered, scene, and video implementations.
- Character and background managers; positioning, tint, appearance changes with transitions.
- Shader transition library (cross-fade, dissolve with mask, slide, wipe, pixelate, ripple, etc.).
- Audio manager (BGM crossfade, SFX, voice, ambient), audio buses.
- Camera manager; resource locator with preloading.
- **Exit criteria:** the full §5.3 sample plays with art and sound.

### M3: State and UI (4 weeks)
- Save/load slots, quick save, auto save, global state, settings.
- Rollback and backlog.
- All printers and choice handlers from §7.
- Default UI set with a single theme.
- **Exit criteria:** a 15-minute demo VN is shippable as an exported build on desktop and web.

### M4: Polish and production features (4 weeks)
- Effects (rain, snow, shake, glitch, blur, bokeh, sun shafts, flash).
- Unlockables, CG gallery, tips.
- Localization pipeline (string tables, CSV/PO export, language switch at runtime).
- Debug console, hot reload, play-from-line.
- Movies; embedding/dialogue-only preset for non-VN games.
- **Exit criteria:** demo project localized into a second language; mobile export verified.

### M5: Advanced tooling (ongoing)
- Story graph, visual editor, language server and VS Code extension.
- C# facade, Spine and Live2D add-ons, community command packs.

### 1.0 Release
- API frozen and documented, migration guide policy, Asset Library listing, sample project, tutorial videos.

---

## 10. Repository Layout (proposed)

```
StoryTeller/
├── addons/storyteller/
│   ├── plugin.cfg
│   ├── plugin.gd                 # EditorPlugin entry
│   ├── core/                     # StoryTeller autoload, services base, config
│   ├── script/                   # lexer, parser, ast, validator, importer, expressions
│   ├── commands/                 # built-in StoryCommand classes
│   ├── actors/                   # actor base + implementations
│   ├── services/                 # managers (audio, camera, state, ...)
│   ├── ui/                       # default UI scenes and theme
│   ├── effects/                  # effect scenes and shaders
│   ├── transitions/              # transition shaders
│   └── editor/                   # highlighter, inspectors, graph, wizard
├── demo/                         # sample project content
├── tests/                        # GUT unit and integration tests
├── docs/                         # user guide, command reference, this plan
└── tools/lsp/                    # language server (M5)
```

---

## 11. Testing Strategy

- **Unit tests (GUT):** lexer/parser edge cases, expression evaluator, validator diagnostics, save serialization round trips, rollback correctness.
- **Golden tests:** parse every `.story` file in `tests/fixtures` and compare the AST dump to a stored snapshot.
- **Integration tests:** headless run of scripted playthroughs that assert variable values, visited labels, and actor states at checkpoints.
- **CI:** GitHub Actions with headless Godot on Linux; export smoke tests for Windows, Linux, Web.
- **Manual QA checklist** per milestone covering input devices, resolutions, and platforms.

---

## 12. Documentation Plan

- Getting Started (install, wizard, first scene in 10 minutes).
- Writer's Guide (StoryScript syntax with copy-paste examples).
- Command Reference (generated from command schemas).
- Developer Guide (custom commands, actors, services, UI, embedding in a 3D game).
- Recipes (dating-sim affection meter, inventory checks, mini-game handoff, chat-app story).
- Migration notes for users coming from Naninovel, Ren'Py, and Dialogic.

---

## 13. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Scope is very large | Slipping milestones | Strict milestone exit criteria; defer M5 items freely. |
| Async command cancellation bugs (skip, load, rollback mid-animation) | Broken state | Central cancellation token; integration tests that skip/load at every line of fixtures. |
| Rollback memory growth | Poor performance on mobile | Diffed snapshots, configurable depth, barrier commands. |
| Godot API changes between 4.x versions | Breakage | Pin minimum version, test on latest stable in CI. |
| Overlap with existing Godot tools (Dialogic, Dialogue Manager, Escoria) | Low adoption | Focus on what they lack together: full VN stack, Naninovel-style scripting, rollback, built-in UI, story tooling. |
| Expression engine security in modded scripts | Arbitrary code execution | Own parser with whitelisted functions; no `Expression` class on user text. |
| Legal / trademark | Takedown risk | Original code, docs, and assets only; reference Naninovel solely as inspiration, never copy code or text. |

---

## 14. Open Questions

1. **Minimum Godot version:** 4.3 or 4.4+? (Newer versions offer better editor APIs and typed dictionaries.)
2. **C# support:** GDScript-only core is planned. Is first-class C# needed early?
3. **Script file extension:** `.story`, `.tale`, or `.nani`-like? (`.story` is assumed in this plan.)
4. **License:** MIT, Apache 2.0, or something else?
5. **Primary target platforms:** desktop only first, or mobile and web from M3?
6. **Visual editor priority:** do target users need a no-typing editor before 1.0?
7. **Monetization / distribution:** free and open source, or a paid tier like Naninovel?

---

## 15. Immediate Next Steps

1. Resolve the open questions above.
2. Complete M0 scaffolding (addon skeleton, CI, test framework).
3. Write the formal StoryScript grammar (EBNF) in `docs/storyscript-spec.md`.
4. Implement the lexer and parser with golden tests.
