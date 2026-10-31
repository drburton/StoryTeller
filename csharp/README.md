# TaleScript for C#

This folder holds a C# port of the TaleScript front end, written for Unity. The Godot plugin in `addons/storyteller/talescript/` stays the reference. The port proves itself by running the shared cases in `conformance/` and matching the expected files character for character.

## Layout

- `TaleScript.Core` holds the library. Each GDScript class has a C# file with the same name: `TaleToken`, `TaleLexer`, `TaleDiagnostic`, `TaleExpr`, `TaleNode`, `TaleDocument`, `TaleParser`, `TaleText`, `TaleCheckContext`, and `TaleChecker`. Names follow the GDScript ones in PascalCase, and the node kinds and fields keep their meaning. `GdFormat` reproduces the GDScript number and string formatting that shows up in dumps. `OrderedMap` stands in for a GDScript Dictionary where insertion order matters.
- `TaleScript.Conformance` holds a console runner that reads the cases and compares the output.

The port covers the lexer, parser, checker, compiler, evaluator, and an engine-neutral director. `TaleCompiler.Build(source, taleName, context)` returns the compiled `Tale` with the diagnostics. `TaleDirector` plays it.

To check a tale, build a `TaleCheckContext` with `AddAction`, `AddActionUnchecked`, `AddCast`, `AddExposed`, and `AddTale`, then call `TaleChecker.Check(doc, context)`. Diagnostics come back sorted by line and column, and ties keep their report order. `CallKinds` on a checker instance records how each call resolved, for the compiler.

## Playing tales

Subclass `TalePresenter` to show lines and choices. `ShowLine` receives an `OrderedMap<object>` with the keys `speaker_id`, `speaker_name`, `speaker_color`, `mood`, `text`, `id`, `voice`, `tale`, `beat`, `source_line`, and `read`. `Choose` receives the options (`text`, `id`, `enabled`, `picture`) and the choose settings such as `timeout`. It returns the picked index, or -1 when the timeout runs out. Both return a `Task`, so a presenter can wait for a button press.

Host code reaches tales through the director:

- `AddAction` registers a `TaleAction` subclass with parameter names, a required count, and defaults. Override `Run` for a quick action or `RunAsync` to await something.
- `Expose(name, target, methods, properties)` lets tales use an object, limited to the listed members. Implement `ITaleObject` on the target to skip reflection. `ExposeFunction(name, func)` adds a function.
- Methods and functions may return `Task` or `Task<T>`. A tale that writes `await thing()` waits for it, and a line or choice waits for running actions unless it carries `@no_wait`.
- `StorySignal` carries `emit("name", value)` calls. `RuntimeError` carries the message, the tale name, and the line. `BeatEntered`, `LineStarted`, `LineFinished`, `ChoiceStarted`, and `ChoiceMade` report progress.
- `GetVar` and `SetVar` read and write story and global variables. Set `Skipping` to finish actions at once.
- Hooks stand in for the Godot crew members: `NameResolver` (cast members), `ContextExtender` (names for the checker), `TypeConstants`, `ValueConstructor`, `Translator`, `Collected`, `TaleLoader`, and `Waiter`.

    var director = new TaleDirector();
    director.Presenter = new MyPresenter();
    director.StorySignal += (name, value) => Debug.Log(name);
    director.RuntimeError += (message, tale, line) => Debug.LogWarning(tale + ":" + line + " " + message);
    director.Expose("player", player, new[] { "give" }, new[] { "gold" });

    var built = TaleCompiler.Build(source, "prologue", director.MakeCheckContext("prologue"));
    if (built.Tale != null)
    {
        director.AddTale(built.Tale);
        await director.Play("prologue");
    }

`Play` returns a `Task` that completes when the story ends or `Stop` runs. The core never blocks on a task and never starts a thread, so continuations run on whatever context awaited them, which is Unity's main thread.

Left out of the director: saves and rewind, route log, live reload, localization tables, asset preloading, and the Godot built-in actions other than `emit` and `wait`. Vector and color values need the host hooks above.

## Build and run

You need the .NET 8 SDK. From the repository root:

    dotnet build csharp/TaleScript.sln
    dotnet run --project csharp/TaleScript.Conformance

The runner looks for a `conformance` folder by walking up from the current directory. To point it somewhere else, pass the folder as an argument:

    dotnet run --project csharp/TaleScript.Conformance -- path/to/conformance

It prints `ok` or `FAIL` for each parse, check, and run case, with the first differing line on a failure, then a total. The exit code is 1 when any case fails. The runner reads each check case's `.context.json` with System.Text.Json and builds the context the same way the GDScript test does. For run cases it plays the tale with a small presenter and writes the transcript described in `conformance/README.md`.

## Unity constraints

Unity 6 reads the library as source or as a built assembly, so `TaleScript.Core` limits itself to what Unity supports:

- Target framework `netstandard2.1`.
- Language version C# 9. No file-scoped namespaces, no global usings, no implicit usings.
- No NuGet packages.
- Number and text formatting always uses `CultureInfo.InvariantCulture`.

The runner targets `net8.0` because it only runs on a developer machine.
