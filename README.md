# StoryTeller

A visual novel and interactive story framework for Godot.

Writers create stories in TaleScript, a small language that looks and feels like GDScript. StoryTeller handles characters, scenery, dialogue, choices, audio, saving, localization, and menus.

> **Status:** early development (milestone M1). The language, runtime, and a basic dialogue box work; characters, backgrounds, audio, saving menus, and the visual editor are still to come.

## Requirements

- Godot **4.7.2** (standard build; .NET is not required)

## Getting the project running

1. Clone this repository.
2. Open `project.godot` in Godot 4.7.2. The StoryTeller plugin is already enabled.
3. Run the tests:
   - Windows: `.\tools\run_tests.ps1 -Godot D:\Godot` (the folder that holds the Godot console executable)
   - Linux and macOS: `GODOT_BIN=/path/to/godot tools/run_tests.sh`

## Try the demo

Press **Play** in the Godot editor. The demo scene (`demo/demo.tscn`) plays `demo/tales/welcome.tale`.

| Input | Action |
|---|---|
| Space, Enter, or click | Continue |
| Hold Ctrl | Skip |
| A | Toggle auto mode |

## Writing a tale

Create a file ending in `.tale` (by default in `res://story/tales/`):

```gdscript
const GUIDE := "Ada"
var visits := 0

beat start:
	visits += 1
	"A quiet library."
	GUIDE: "Welcome back. Visit number {visits}."
	choose:
		"Stay":
			jump start
		"Leave":
			"Goodbye."
```

Then play it from game code:

```gdscript
await Story.play("my_tale")
```

The full language reference is in [docs/talescript-spec.md](docs/talescript-spec.md).

## Documentation

- [TaleScript specification](docs/talescript-spec.md)
- [Project plan](docs/PLANNING.md)
- [Decision records](docs/decisions/README.md)
- [Contributing guide](CONTRIBUTING.md)

## License

StoryTeller is released under the [MIT license](LICENSE).
