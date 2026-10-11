# Publishing the plugin

StoryTeller ships as one folder, `addons/storyteller/`. This page covers building the plugin zip, releasing it on GitHub, and listing it on the Godot Asset Library.

## What people download

- **The plugin zip** (`storyteller-<version>.zip`) holds `addons/storyteller/` and nothing else. Unzipped in a project's root folder, it lands at `res://addons/storyteller/`.
- **GitHub and Asset Library downloads** of the repository hold the same folder. `.gitattributes` marks everything else (demo, examples, tests, tools, docs) as `export-ignore`, so installing from the Asset Library adds only the plugin. People who want the demo and examples clone the repository.

The plugin depends on nothing outside its own folder. It registers its autoload, project setting, and input actions itself when enabled.

## Checking a build

```bash
tools/package_addon.sh                                   # writes build/storyteller-<version>.zip
GODOT_BIN=/path/to/godot tools/check_addon_install.sh    # builds the zip and installs it in an empty project
```

`check_addon_install.sh` does what a new user does: it enables the plugin, presses **Set Up Project**, runs the game, presses **New Game**, and plays the starter tale to the end. It fails on any script error, so it catches code that relies on files only this repository has. CI runs it on every pull request.

## Releasing

1. Set the version in `addons/storyteller/plugin.cfg` and `Story.VERSION` in `addons/storyteller/core/story.gd` (a test checks that they match), for example `0.1.0`. Versions with a hyphen, such as `0.1.0-beta`, become prereleases.
2. Merge that to `main`, then start the release in either of two ways:
   - **From GitHub:** open **Actions > Release > Run workflow**, keep the branch on `main`, tick **Open a draft release**, and run it.
   - **With a tag:** push a tag that matches the version:
     ```bash
     git tag v0.1.0
     git push origin v0.1.0
     ```
3. The **Release** workflow runs the tests, builds the zip, checks that it installs, and opens a **draft** release named `v<version>` with the zip attached and generated notes.
4. Test the draft's zip by hand with the checklist in `docs/release-testing.md`. If something needs fixing, merge the fix and run the workflow again: it replaces the unpublished draft.
5. Read the draft on the Releases page, edit the notes, and publish it. When the release was started from GitHub, publishing also creates the `v<version>` tag on the commit it was built from.

Running the workflow by hand with the box left empty builds and checks the zip without releasing. The zip is kept as a workflow artifact.

## Listing on the Godot Asset Library

The Asset Library at https://godotengine.org/asset-library lists free assets and installs them from a GitHub commit. Submissions need a Godot account and go through a short review by its moderators.

Use these values in the submission form:

| Field | Value |
|---|---|
| Asset name | StoryTeller |
| Category | Tools |
| Godot version | 4.7 |
| Version | the version in `plugin.cfg`, such as 0.1.0 |
| Repository host | GitHub |
| Repository URL | https://github.com/drburton/StoryTeller |
| Issues URL | https://github.com/drburton/StoryTeller/issues |
| Download commit | the full commit hash the release tag points at |
| Icon URL | https://raw.githubusercontent.com/drburton/StoryTeller/main/docs/images/icon.png |
| License | MIT |

Description:

> A visual novel and interactive story framework. Write stories in TaleScript, a GDScript-style language, as text, as cards, or on a story map, and play them with a ready-made dialogue box, choices, characters, backdrops, audio, saves, settings, history, rewind, translation, and an Extras screen. Enable the plugin, open the Story tab, and press Set Up Project to start.

Preview images (each as a raw GitHub URL under `docs/images/`): `title.png`, `dialogue.png`, `story_tab_cards.png`, `story_tab_map.png`, `route_chart.png`.

For each new release, edit the listing to point at the new tag's commit and version. After the first listing is approved, add "install from the AssetLib tab" to the getting-started guide and the README.

The newer Godot Asset Store takes the plugin zip as an upload instead of a commit. Check its current submission rules at the time of release.
