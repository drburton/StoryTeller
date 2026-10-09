# 0014. Where the free tier ends and Pro begins

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

Decision 0006 set up a free base tier and a paid Pro tier but left the exact feature split open (`docs/PLANNING.md` §12.2). M6 added features whose tier was unclear, namely the player route chart and image choices (§19, question 5). The free tier is MIT licensed (0008), so anyone may rebuild a Pro feature on top of it; Pro has to earn its price through content and time saved, not through anything locked.

## Decision

The line falls between **making a complete game** and **producing one faster, at a larger scale, or with more variety**.

- **Free:** everything a solo creator needs to write, play, save, translate, and ship a full visual novel. That includes every system players see and use, and the whole visual editor.
- **Pro:** production tools for teams, voice work, and translation, plus extra presentation content (dialogue styles, transitions, effects, themes, and genre templates).

Applied to the open cases:

- **Route chart: free.** Players see it, and it is becoming a standard genre feature. Story analytics in the editor (route coverage, word counts, choice statistics from playtests) stay Pro.
- **Image choices: free.** Choices shown as pictures, and the hook that lets a game offer choices through objects in a 2D or 3D scene, are free. Pro adds the hotspot authoring tool (clickable regions drawn over a backdrop in the editor) and messenger-style replies.

Pro may only use public extension points. Before Pro work starts, the free tier adds the ones it lacks: a registry of choice menu styles, a way to register named transitions, and editor hooks for tools such as the stage preview.

## Alternatives considered

- **Route chart in Pro:** games made with the free tier would look less complete to players, which breaks the rule that the free tier ships complete games.
- **All image choices in Pro:** choosing with a picture is a basic genre feature, and the in-world choice hook matters most to games that embed StoryTeller, which the free tier is meant to serve.
- **Visual editor in Pro:** it is the strongest reason to choose StoryTeller, and charging for it would limit adoption (§12.2 already recommended keeping it free).

## Consequences

- §7, §12.2, and §19 of the plan record the split, and question 5 is closed.
- The image choices item in M6 builds the choice style registry, and M7 adds transition registration and editor hooks.
- Community add-ons can use the same extension points to build their own versions of Pro features, which MIT allows anyway.
- Pricing and the storefront remain open (§12.3, §19).
