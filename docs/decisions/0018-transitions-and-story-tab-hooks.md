# 0018. Named transitions and Story tab hooks

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

Decision 0014 lists the extension points the free tier needs before any Pro work, so Pro and community add-ons can be built without changing the core. The choice style registry came with image choices (decision 0016). Two remained: a way to add transitions beyond the fixed table in `backdrop_view.gd`, and hooks in the Story tab for editor tools such as a stage preview.

## Decision

- **`StoryTransition` resources.** A transition is either a built-in effect (cut, fade, dissolve, wipe, slide) with its own mask, direction, and softness, or a canvas_item shader that draws the whole transition from the same uniforms the built-in shader receives. Data-only transitions cover most needs (a swirl or a page-shaped dissolve is a mask) without writing a shader.
- **Registered by name** from three places: `.tres` files in `StoryConfig.transition_folder` (by file name), `StoryConfig.transitions`, and `StoryStage.add_transition()` at runtime. Backdrops and CGs share one registry. The card forms list every registered name. Unknown names still fall back to `fade` with a warning.
- **Shaders take over only while they run.** `BackdropView` keeps the two pictures in script, gives them to a transition's own material for its duration, and hands back to the built-in material at the end, so saves, skipping, and the next transition work the same as before.
- **Story tab hooks.** `TaleEditorPanel.get_instance()` returns the tab; `add_toolbar_control()` and `add_side_panel()` place an add-on's controls; the `line_selected(path, line)` signal reports the line being edited in the text view (the caret) or the cards view (the card being edited).

## Alternatives considered

- **More modes in the built-in shader for every new effect:** each new transition would need a core change, which is what Pro must avoid.
- **An editor plugin API of our own with registration calls:** Godot add-ons already run as editor plugins; giving them the panel and a signal is simpler and needs no lifecycle of ours.

## Consequences

- Every extension point in §12.4 of the plan exists, so Pro (and community packs) can add transitions, choice styles, dialogue styles, looks, effects, and Story tab tools through public APIs.
- The checker does not yet warn about unknown transition names; the runtime warning and the card form's list cover them for now.
