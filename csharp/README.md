# TaleScript for C#

This folder holds a C# port of the TaleScript front end, written for Unity. The Godot plugin in `addons/storyteller/talescript/` stays the reference. The port proves itself by running the shared cases in `conformance/` and matching the expected files character for character.

## Layout

- `TaleScript.Core` holds the library. Each GDScript class has a C# file with the same name: `TaleToken`, `TaleLexer`, `TaleDiagnostic`, `TaleExpr`, `TaleNode`, `TaleDocument`, `TaleParser`, `TaleText`, `TaleCheckContext`, and `TaleChecker`. Names follow the GDScript ones in PascalCase, and the node kinds and fields keep their meaning. `GdFormat` reproduces the GDScript number and string formatting that shows up in dumps. `OrderedMap` stands in for a GDScript Dictionary where insertion order matters.
- `TaleScript.Conformance` holds a console runner that reads the cases and compares the output.

The port now covers the lexer, parser, and checker. The compiler, evaluator, and director come in later phases.

To check a tale, build a `TaleCheckContext` with `AddAction`, `AddActionUnchecked`, `AddCast`, `AddExposed`, and `AddTale`, then call `TaleChecker.Check(doc, context)`. Diagnostics come back sorted by line and column, and ties keep their report order. `CallKinds` on a checker instance records how each call resolved, for the compiler.

## Build and run

You need the .NET 8 SDK. From the repository root:

    dotnet build csharp/TaleScript.sln
    dotnet run --project csharp/TaleScript.Conformance

The runner looks for a `conformance` folder by walking up from the current directory. To point it somewhere else, pass the folder as an argument:

    dotnet run --project csharp/TaleScript.Conformance -- path/to/conformance

It prints `ok` or `FAIL` for each parse and check case, with the first differing line on a failure, then a total. The exit code is 1 when any case fails. The `run` folder is skipped for now, though the runner still parses its tales and confirms that each one prints back unchanged. The runner reads each check case's `.context.json` with System.Text.Json and builds the context the same way the GDScript test does.

## Unity constraints

Unity 6 reads the library as source or as a built assembly, so `TaleScript.Core` limits itself to what Unity supports:

- Target framework `netstandard2.1`.
- Language version C# 9. No file-scoped namespaces, no global usings, no implicit usings.
- No NuGet packages.
- Number and text formatting always uses `CultureInfo.InvariantCulture`.

The runner targets `net8.0` because it only runs on a developer machine.
