# 0001. Feature scope and originality rules

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

StoryTeller aims to give Godot users a complete, script-driven visual novel toolkit. Naninovel for Unity is a well-known example of that kind of toolkit and is the reference for the overall feature scope. StoryTeller must not raise intellectual property concerns.

## Decision

- Naninovel informs the scope only: which kinds of features a complete toolkit needs.
- StoryTeller uses its own script language, vocabulary, architecture, documentation, and sample content.
- Contributors follow clean-room rules: no reading or copying of Naninovel source code, no reuse of its names, syntax, file formats, or text. The rules live in `CONTRIBUTING.md`.
- Public materials do not use the Naninovel name or claim compatibility.
- A lawyer reviews the project before the public 1.0 release and before Pro sales.

## Alternatives considered

- **A compatible clone** (same script syntax and commands): rejected because it maximizes IP risk and ties the design to a Unity product.
- **No external reference at all:** rejected because a known, successful scope reduces the risk of building the wrong product.

## Consequences

- Every feature needs an independent design, which takes more effort but gives a product that fits Godot better.
- Decision records like this one document the independent design process.
