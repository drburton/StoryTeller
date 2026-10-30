# 0026. Unity 1.0 with Godot 1.0, Unreal as 1.1

- **Status:** Accepted
- **Date:** 2026-10-30

## Context

The maintainer earns money from a textbook on visual novel creation for game development courses. Unity is the engine taught most often, Unreal has a smaller but real share, and Godot is growing. This year all of the maintainer's students chose Unity with Naninovel over Godot with StoryTeller, because they already knew Unity. Schools adopt a book when it fits the engine they teach, so the tool has to exist in Unity, and later in Unreal.

Version 1.0 should be available by Spring 2027 (about April), so schools can adopt the book for Fall 2027. The maintainer will require their own students to use the tool in Fall 2027, which is the first full classroom pilot.

Decision 0004 chose GDScript only. That choice was made for the Godot plugin and still holds there.

## Decision

- Version 1.0 means two engines released together by April 2027: Godot 1.0 (feature complete, needing release work) and Unity 1.0 (new, for Unity 6 LTS, frozen for the book's first edition).
- Unreal follows as 1.1 in summer or fall 2027, with an online chapter added to the book when it ships.
- The Unity version ports the language core (lexer, parser, checker, compiler, director) to C# under decision 0025. The runtime uses Unity's own tools: uGUI or UI Toolkit for the dialogue box and menus, Timeline and Animator for shots (a tale calls `shots.play()` and `shots.hold()` as it does with the Godot Shots crew member), and Unity's saves, audio, 2D stage, and 3D scenes.
- The Unity editor tools are errors shown while writing, the path explorer, and then the Map view. The Cards view may come after 1.0 if time is short.
- Because the core is C#, it also builds as a command-line checker. Unreal users use it, and a later VS Code extension or language server can use it.
- Unreal 1.1 is a smaller runtime that plays compiled tales and relies on the command-line tool for checking.
- This supersedes decision 0004's "GDScript only" for the engine ports. Decision 0004 still holds for the Godot plugin.
- The Studio stays a Godot-built app. Students never see its engine. Its story files could later open in Unity too.

## Alternatives considered

- **Godot only:** no new work, but the maintainer's own students chose another engine, and other schools would do the same.
- **All three engines at once:** one release, but three new runtimes risk the spring date. Splitting Unreal into 1.1 keeps April realistic.
- **Unreal first:** Unreal teaches less than Unity, so fewer schools would be reached sooner.

## Consequences

- The repository gets C# code. Proposed layout: `unity/` for the Unity package and sample projects, `csharp/core/` for the shared language core and command-line tool, and `conformance/` for the suite's data files. The final layout is settled in M10.
- CI for Unity needs a Unity license. Setting up a license for GitHub Actions is a task for the maintainer. Until then, Unity tests run locally.
- The book's interface freeze applies to both engines. The freeze is planned for February 2027, with a release candidate in March.
- Unity and Unreal licensing and costs differ from Godot's, so the book gets an appendix "Choosing an engine". Its figures are checked against official pages before printing.
- Time before April is tight. The Cards view in Unity and all of Unreal are the first things to move later.
