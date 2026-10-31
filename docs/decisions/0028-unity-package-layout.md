# 0028. The Unity package holds the C# core

- **Status:** Accepted
- **Date:** 2026-10-31

## Context

M10 put the C# port of TaleScript in `csharp/TaleScript.Core`. The Unity version needs the same code inside its package, because Unity compiles a package from the files in its own folder. A package added from a Git URL is read only, and Unity skips any file in it that has no `.meta` file. Decision 0027 says the Unity version never ships under the old name.

## Decision

- The Unity package lives in `unity/com.visualnovelteller.unity`, named `com.visualnovelteller.unity` with the display name "Visual Novel Teller". It targets Unity 6.7 LTS (`"unity": "6000.7"`).
- The C# core sources move to the package's `Runtime/TaleScript` folder, with an assembly definition `TaleScript.Core` that sets `noEngineReferences`. Unity then refuses any use of UnityEngine in the core, which keeps it engine neutral.
- `csharp/TaleScript.Core/TaleScript.Core.csproj` compiles those same files, so the conformance runner, `talescript-check`, and Unity all build one copy.
- The Unity layer lives in `Runtime/Unity` (assembly `VisualNovelTeller`) and the editor tools in `Editor` (assembly `VisualNovelTeller.Editor`). New Unity code uses the namespace `VisualNovelTeller`. The core keeps the namespace `TaleScript`.
- `tools/unity_meta.py` writes the `.meta` files, with GUIDs made from each path so they never change, and CI fails when one is missing or left over.
- Users add the package in the Package Manager with the Git URL `https://github.com/drburton/StoryTeller.git?path=/unity/com.visualnovelteller.unity`.

## Alternatives considered

- **A copy of the core in the package, kept in step by a script:** two copies drift, and a fix could land in only one.
- **A prebuilt TaleScript.Core.dll in the package:** a binary in the repository, and students could not read the source the book talks about.
- **The core in its own package:** cleaner for Unreal, which only uses the command-line tool. One package is simpler for students to install, and the core can split out later without changing its code.

## Consequences

- Godot skips the `unity/` folder through `unity/.gdignore`.
- A new file in the package needs `python3 tools/unity_meta.py` before it is committed.
- Unity tests need a Unity license in CI (decision 0026). Until then, the engine-neutral parts are tested with `dotnet`, and the Unity layer is tested by hand in Unity 6.7.
