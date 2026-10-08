# StoryTeller

A visual novel and interactive story framework for Godot.

Writers create stories in TaleScript, a small language that looks and feels like GDScript. StoryTeller handles characters, scenery, dialogue, choices, audio, saving, localization, and menus.

> **Status:** early development (milestone M0, project setup). Not ready for use yet.

## Requirements

- Godot **4.7.2** (standard build; .NET is not required)

## Getting the project running

1. Clone this repository.
2. Open `project.godot` in Godot 4.7.2. The StoryTeller plugin is already enabled.
3. Run the tests:
   - Windows: `.\tools\run_tests.ps1 -Godot D:\Godot` (the folder that holds the Godot console executable)
   - Linux and macOS: `GODOT_BIN=/path/to/godot tools/run_tests.sh`

## Documentation

- [Project plan](docs/PLANNING.md)
- [Decision records](docs/decisions/README.md)
- [Contributing guide](CONTRIBUTING.md)

## License

StoryTeller is released under the [MIT license](LICENSE).
