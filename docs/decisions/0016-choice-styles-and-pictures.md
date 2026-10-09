# 0016. Choice styles and picture choices

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

M6 adds image choices: options shown as pictures, plus a way for games to let players choose by interacting with objects in a 2D or 3D scene. Decision 0014 also requires a public registry of choice menu styles before any Pro choice style can exist. Tales could already write `choose(style = "...")`, but only one choice menu existed. We needed to decide how styles are registered, how an option names its picture, and what the in-world hook looks like.

## Decision

- **Styles by name.** `StoryDialogue` keeps one menu per style name. "list" is the default and "pictures" is built in. `StoryConfig.choice_styles` adds scenes or replaces "pictures", and `StoryConfig.choice_menu_scene` still replaces "list". `choose(style = "name")` picks the menu; an unknown name is reported through the director's runtime errors and the list is used, so a typo never blocks the story.
- **Pictures per option.** A new `@picture("name")` annotation on an option names its picture, found in `StoryConfig.choice_picture_folder` like other assets. The compiler stores the name with the option, the director passes it to the presenter, and `StoryDialogue` loads the texture before calling the menu. A missing picture is reported and the option shows its text alone.
- **The in-world hook.** `StoryDialogue.add_choice_style(name, object)` accepts any object with an awaitable `choose(options, settings) -> int`, and optionally `cancel()`. It is used as it is, not added to the dialogue layer, so a node in the game's scene can offer the choices however it likes and return the index picked. Options carry their `id`, which writers pin with `@id` so game code can match them to objects.
- **One shared wait.** `ChoiceMenu` provides `pick()`, `cancel()`, and `wait_for_pick(timeout, bar)`, so every style handles timeouts the same way.

## Alternatives considered

- **Pictures by naming convention (a picture per option id):** hidden from the writer, and generated ids change when text changes.
- **A list of pictures as a `choose` argument:** pictures would be matched by position, which breaks when a condition hides an option.
- **A signal for in-world choices instead of an object:** the director awaits a result; an object with `choose()` fits the existing presenter contract and needs no new wiring.

## Consequences

- Compiled tales move to format 4, since options gain a `picture` field.
- Pro's hotspot and messenger styles can be added through `StoryConfig.choice_styles` without changes to the free tier.
- The checker does not yet know which style names a project has, so an unknown style is found while playing, not while writing.
