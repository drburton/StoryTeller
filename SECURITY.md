# Security Policy

Last updated: 2026-10-11

## Supported versions

StoryTeller is in beta. Security fixes go into the latest release only.

| Version | Supported |
|---|---|
| Latest release (currently 0.1.x beta) | Yes |
| Older releases and unreleased branches | No |

## Reporting a vulnerability

Report security problems **privately**, never in a public issue:

1. Open the repository's **Security** tab: https://github.com/drburton/StoryTeller/security
2. Choose **Report a vulnerability** and fill in the form.

Only the maintainers can see the report. Please include:

- The StoryTeller and Godot versions.
- What an attacker could do, and what they would need (for example, a crafted save file or story file).
- Steps or a small project that shows the problem.

The maintainers aim to reply within a week, to agree on a fix and a disclosure date with you, and to credit you in the release notes unless you prefer otherwise.

## What counts as a security problem

StoryTeller runs inside a game on the player's own device and makes no network connections, so most of its risk comes from files the game reads. Examples worth reporting:

- A crafted save file, settings file, or story file that makes a game run code the developer did not intend, or read or write files outside the game's own folders.
- A player-made story in the mod folder that gets past the limits on what tales can call (tales may only use actions and the functions a game exposes with `Story.expose()`).
- Anything in the editor plugin that runs or downloads code when a project is opened.

Not covered:

- Editing your own saves. Save encryption (`StoryConfig.save_key`) uses a key that ships inside the game, so it discourages casual editing and is not meant to stop a determined player.
- Problems in the Godot engine itself. Report those to the Godot project.
- Problems in a game's own code, including functions it exposes to tales.
