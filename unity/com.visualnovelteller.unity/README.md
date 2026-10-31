# Visual Novel Teller for Unity

Write visual novels in TaleScript and play them in Unity 6.7. The same tales run in the Godot version, and both pass one shared conformance suite.

This package is in early development (milestone M11). The TaleScript core works today; the Unity runtime and editor tools are being built.

## Install

In Unity, open **Window > Package Manager**, choose **+ > Install package from git URL**, and enter:

    https://github.com/drburton/StoryTeller.git?path=/unity/com.visualnovelteller.unity

## Folders

- `Runtime/TaleScript`: the TaleScript language core (lexer, parser, checker, compiler, and director). It uses no Unity code, and the command-line tools in `csharp/` build the same files.
- `Runtime/Unity`: components that play tales in a Unity scene.
- `Editor`: import of `.tale` files and the editor tools.

## License

MIT. See `LICENSE.md`.
