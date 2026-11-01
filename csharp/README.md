# TaleScript for C#

This folder holds a C# port of the TaleScript front end, written for Unity. The Godot plugin in `addons/storyteller/talescript/` stays the reference. The port proves itself by running the shared cases in `conformance/` and matching the expected files character for character.

## Layout

- `TaleScript.Core` builds the library from `unity/com.visualnovelteller.unity/Runtime/TaleScript`, where the sources live so Unity compiles the same files (decision 0028). Each GDScript class has a C# file with the same name: `TaleToken`, `TaleLexer`, `TaleDiagnostic`, `TaleExpr`, `TaleNode`, `TaleDocument`, `TaleParser`, `TaleText`, `TaleCheckContext`, and `TaleChecker`. Names follow the GDScript ones in PascalCase, and the node kinds and fields keep their meaning. `GdFormat` reproduces the GDScript number and string formatting that shows up in dumps. `OrderedMap` stands in for a GDScript Dictionary where insertion order matters.
- `TaleScript.Conformance` holds a console runner that reads the cases and compares the output.
- `TaleScript.Check` builds `talescript-check`, a command-line checker for `.tale` files.
- `Shared` holds code both tools compile in, such as reading a check context from JSON.

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

Left out of the director: live reload, localization tables, asset preloading, and the Godot built-in actions other than `emit` and `wait`. Vector and color values need the host hooks above.

## Saves, rewind, and the route log

`Capture()` returns the story state as plain data (`OrderedMap<object>`, `List<object>`, string, long, double, bool, null). `GdJson.Stringify` writes it and `GdJson.Parse` reads it back, so a Unity host can keep it in a file. `Restore(state)` replaces the story state, and `await Resume()` plays on from the saved line, showing the line or choice that was on screen. Tale dictionaries and non-finite floats are wrapped as `{"$dict": ...}` and `{"$float": ...}` so they survive JSON.

    string json = GdJson.Stringify(director.Capture());
    // later, in a director that has the same tales registered
    director.Restore((OrderedMap<object>)GdJson.Parse(json));
    await director.Resume();

`CaptureGlobals()` and `RestoreGlobals(data)` cover what outlives a playthrough: global variables, read lines, and `Routes`. Keep that data apart from the save slots.

Host state joins the save through `ITaleStateProvider` (`Name`, `Capture()`, `Restore(data)`). Register one with `AddStateProvider`, and its data is stored under its name in the `crew` entry of the save. A stage, audio, or shots layer can use this.

`new TaleHistory(director, depth)` keeps a snapshot at each line and choice. `Rewind(steps)` loads an earlier one and resumes, `CanRewind` and `AvailableSteps` tell what is possible, and a line marked `@no_rewind` clears the snapshots. Call `Clear()` after loading a save.

`director.Routes` is a `TaleRouteLog` with the beats entered (`Beats`, `HasBeat`), the links between them (`GetLinks`), and the state of each choice option (`GetOptionState` returns `Unseen`, `Seen`, or `Picked`).

## Exploring every path

`TalePaths.Explore` plays a tale down every path, taking each option at every choice, and also tries a timed choice with the time running out. It is the C# version of `addons/storyteller/director/tale_paths.gd`, and it reports the same things: the endings, runtime errors, paths that loop or get stuck, and beats no path enters.

    var sources = new Dictionary<string, string> { { "prologue", File.ReadAllText("prologue.tale") } };
    var options = new TalePathsOptions();
    options.Exposed.Add("game");
    TalePathsResult result = await TalePaths.Explore("prologue", "start", sources, options);
    Console.WriteLine(result.Describe());

Pass tale source text, already built `Tale` objects, or both. A source with mistakes is not played, and its mistakes come back as problems. Each path runs in a new `TaleDirector` with skipping on and a presenter that completes at once, so an exploration whose actions finish at once completes without waiting. Nothing blocks a thread. A path whose tale waits on something that never finishes is stopped after `PathSeconds` and reported as stuck.

`TalePathsResult` holds the paths (`Choices` as option texts, `Ending` as `tale.beat` or `"cut off"`, `Lines`), the endings with counts, the problems grouped by kind, line, and message (each with `Paths`, the number of paths that hit it, and `FirstPath`), `Unreached` beats, `TotalLines`, `Complete`, and `LimitReached`. A cut off path has no ending. The limits are in `TalePathsOptions` with the defaults of the Godot explorer: `MaxPaths` 1000, `MaxChoices` 60, `MaxLines` 2000, and `PathSeconds` 10. Problem messages match the GDScript ones.

Names that game code exposes get stand-ins: a `TaleStandIn` (an `ITaleObject`) whose methods return null and whose properties read as 0 and accept writes. Put the names in `Exposed`. Cast ids from `CastIds` and from the check context get one too. The methods and properties a tale may use are found by scanning the source text for `name.member`, as the Godot explorer does, so stand-ins need `sources`. They take positional arguments only. `ask_text()` answers with its default, or "Tester".

`Setup` runs on every director the explorer makes. Use it to register the actions a tale calls, usually `TaleStubAction` objects that copy a real action's signature and do nothing, and to set `ContextExtender` so the checker knows the cast and tales.

## Build and run

You need the .NET 8 SDK. From the repository root:

    dotnet build csharp/TaleScript.sln
    dotnet run --project csharp/TaleScript.Conformance

The runner looks for a `conformance` folder by walking up from the current directory. To point it somewhere else, pass the folder as an argument:

    dotnet run --project csharp/TaleScript.Conformance -- path/to/conformance

It prints `ok` or `FAIL` for each parse, check, and run case, with the first differing line on a failure, then a total. The exit code is 1 when any case fails. The runner reads each check case's `.context.json` with System.Text.Json and builds the context the same way the GDScript test does. For run cases it plays the tale with a small presenter and writes the transcript described in `conformance/README.md`.

## Checking tales from the command line

`talescript-check` checks files or whole folders of `.tale` files without Godot or Unity:

    dotnet run --project csharp/TaleScript.Check -- [--context=names.json] [--strict] [--paths] [--expose=a,b] [--actions=a,b] <file or folder>...

Each problem prints as `<file>:<line>: <message>`, with `warning:` before warnings, and a total follows. The exit code is 1 when a file has an error, or a warning too with `--strict`, and 2 for a bad argument. Names that come from the game, such as actions, cast members, and exposed objects, go in a context file in the format of the conformance check cases (`conformance/README.md`). Without one, the checker knows only the built-in names.

`--expose=a,b` adds names that game code exposes, for the checker and for `--paths`. `--actions=a,b` adds actions such as `music` or `backdrop` without checking their arguments, for tales written for a runtime whose actions the context file does not list. For example, `--paths --expose=shots --actions=music` explores a tale that uses Shots and music. `--paths` also plays every file that checks clean down every path from the beat `start`, with the other files available as tales to jump to, and prints a short report for each file: the number of paths, the endings with counts, beats no path reaches, and the problems as `file:line: kind: message` with how many paths hit them and the choices on the first one. Actions from the context file become actions that do nothing, and the cast ids and exposed names get stand-ins. The exit code is 1 when a path hits a runtime error or another problem, such as a loop.

CI builds the solution with warnings treated as errors, runs the conformance suite and the tests in `TaleScript.Tests`, and tries the checker on a clean tale and a broken one.

## Unity constraints

Unity 6 reads the library as source or as a built assembly, so `TaleScript.Core` limits itself to what Unity supports:

- Target framework `netstandard2.1`.
- Language version C# 9. No file-scoped namespaces, no global usings, no implicit usings.
- No NuGet packages.
- Number and text formatting always uses `CultureInfo.InvariantCulture`.

The runner targets `net8.0` because it only runs on a developer machine.
