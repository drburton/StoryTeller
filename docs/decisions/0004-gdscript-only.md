# 0004. GDScript only, no C# for now

- **Status:** Accepted
- **Date:** 2026-10-08

## Context

Godot supports GDScript in every build and C# only in the .NET build, which also limits some export targets.

## Decision

StoryTeller is written entirely in GDScript and does not ship a C# API. C# projects can still call StoryTeller through Godot's normal cross-language interop.

## Alternatives considered

- **C# core:** rejected because it would require the .NET build and exclude many users.
- **GDScript core with a C# wrapper from the start:** postponed; it adds maintenance with no current demand.

## Consequences

- Works with the standard Godot download and every export platform.
- A C# API can be reconsidered after 1.0 if users ask for it.
