# 0030. Unity purchases before Unity 1.0, and Unity 6.3 support

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

Decision 0029 planned demos and purchases for the Godot plugin first, with the Unity version getting them after Unity 1.0. Two things changed on 2026-11-10:

- The maintainer's first commercial visual novels (a free demo, with the rest bought inside the game) ship on the App Store and Steam at the end of January 2027. They are built in Unity, with either Naninovel or Visual Novel Teller. Unity In-App Purchasing is mature, while the Godot StoreKit 2 plugin's API is still a draft.
- Those games use a final Unity release, never a beta: Unity 6.3 or 6.7. The Unity package asked for 6.7, which was only available as a beta.

## Decision

- **Purchases come to the Unity package now, ahead of Unity 1.0.** This replaces the line in decision 0029 that put them after it.
- **The Unity layer matches the Godot plugin:** `StoryProduct` entries in the Story Config, a `StoryStore` that answers `owns()`, `offer()`, and `@needs`, a test store in the editor, a purchase screen, Restore purchases, and locked saves. The C# core records the products of the `@needs` beats a playthrough entered, as the Godot director does.
- **Unity In-App Purchasing 5 sells on the App Store and Google Play.** It lives in an optional assembly, `VisualNovelTeller.Purchasing`, that compiles only when the project has `com.unity.purchasing` 5.0 or newer, so games that sell nothing don't need the package. Steam DLC through Steamworks.NET comes next.
- **The package supports Unity 6.3 and 6.7.** It asks for Unity 6000.3 and Input System 1.20.0, which Unity 6.7 replaces with its built-in Input System. Changes are compiled in both before they merge.

## Alternatives considered

- **Keep the order of decision 0029:** the maintainer's games would then need Naninovel and their own purchase code for January, and Visual Novel Teller would not be an option for them.
- **Make Unity In-App Purchasing a dependency of the package:** simpler, but every game would pull in Unity Gaming Services packages it may not want.
- **Unity 6.7 only:** 6.7 was still in beta in November 2026, and the first games can't wait for its final release.

## Consequences

- Godot's Steam work (M13 phase 3) waits until the Unity purchases and Steam DLC are working.
- Testing on both Unity versions needs a local Unity install, since Unity has no license in CI yet (decision 0026). The Unity 6.3 compile found one real incompatibility, an ambiguous `schedule.Execute` call, which is fixed.
- The App Store and Google Play paths still need a run on real devices with the store accounts, after January 1, 2027.
