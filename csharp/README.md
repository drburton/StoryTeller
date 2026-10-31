# TaleScript for C#

This folder holds a C# port of the TaleScript front end, written for Unity. The Godot plugin in `addons/storyteller/talescript/` stays the reference. The port proves itself by running the shared cases in `conformance/` and matching the expected files character for character.

## Layout

- `TaleScript.Core` holds the library. Each GDScript class has a C# file with the same name: `TaleToken`, `TaleLexer`, `TaleDiagnostic`, `TaleExpr`, `TaleNode`, `TaleDocument`, `TaleParser`, and `TaleText`. Names follow the GDScript ones in PascalCase, and the node kinds and fields keep their meaning. `GdFormat` reproduces the GDScript number and string formatting that shows up in dumps. `OrderedMap` stands in for a GDScript Dictionary where insertion order matters.
- `TaleScript.Conformance` holds a console runner that reads the cases and compares the output.

At this stage the port covers the lexer and parser. The checker, compiler, evaluator, and director come in later phases.

## Build and run

You need the .NET 8 SDK. From the repository root:

    dotnet build csharp/TaleScript.sln
    dotnet run --project csharp/TaleScript.Conformance

The runner looks for a `conformance` folder by walking up from the current directory. To point it somewhere else, pass the folder as an argument:

    dotnet run --project csharp/TaleScript.Conformance -- path/to/conformance

It prints `ok` or `FAIL` for each parse case, with the first differing line on a failure, then a total. The exit code is 1 when any case fails. The `check` and `run` folders are skipped for now, though the runner still parses their tales and confirms that each one prints back unchanged.

## Unity constraints

Unity 6 reads the library as source or as a built assembly, so `TaleScript.Core` limits itself to what Unity supports:

- Target framework `netstandard2.1`.
- Language version C# 9. No file-scoped namespaces, no global usings, no implicit usings.
- No NuGet packages.
- Number and text formatting always uses `CultureInfo.InvariantCulture`.

The runner targets `net8.0` because it only runs on a developer machine.
