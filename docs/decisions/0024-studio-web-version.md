# 0024. The Studio also runs as a web page

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

Decision 0021 ships the Studio as apps for iPads and Android tablets and leaves a web version for later. Many classrooms use Chromebooks or laptops, which the tablet apps don't serve, and a web page needs nothing installed, no store accounts, and no store review. App stores also offer only an app's newest version, while a website can keep each textbook edition's Studio at its own address. The Studio is a Godot project, and Godot exports it for the web from the same code, so a web version costs testing more than building.

## Decision

- The Studio is also built as a web page from the same Godot project (`tools/build_studio.sh web`): Godot's single-threaded web build, which runs on any static web host without special server settings, with an install manifest so it can be added to a home screen. The tablet apps stay.
- Stories live in the browser's storage for the page. The Studio asks the browser to keep it, and when the browser can't promise that, the home screen asks students to add the Studio to their home screen and share a copy of each story.
- In a browser, **Share** saves the story file as a download, and **Open a story file**, pictures, and sounds come from the browser's file picker (`StudioWeb`).
- The symbols the Studio and the plugin's screens show (▼, ▶, ⌂, arrows, and more) come from StoryTeller Symbols, a small font drawn for StoryTeller and MIT licensed (`tools/demo_assets/symbols_font.py`), since a web page has no system fonts to borrow them from. The Story autoload adds it behind Godot's default font, so web games made with the plugin show them too.
- `tools/check_studio_web.sh` builds the web version and checks it in Chromium: a story made from a template keeps its tale and pictures after the page is loaded again, opens in the blocks and the map, and plays. The Studio workflow runs it and keeps the web build to download.

## Alternatives considered

- **Rewriting the Studio in JavaScript or TypeScript:** a smaller download and more natural typing in the browser, but a second copy of the TaleScript parser, checker, and story runtime to keep in step with the plugin, and the risk that a student's story no longer opens in Godot exactly as written.
- **Tablet apps only (decision 0021):** the safest storage on iPads, but nothing for Chromebook classrooms, and only through the app stores.
- **Bundling an existing open font for the symbols:** less drawing, but a second license in a project that is MIT throughout.

## Consequences

- A browser may still clear a site's storage (Safari after seven days without a visit, unless the page is on the home screen), so the share reminder matters more on the web, and teachers should know to add the Studio to the home screen.
- The web build is about 44 MB; it is cached after the first visit.
- Typing, dragging blocks, and picking files need trying on a real iPad and a Chromebook, as the tablet check does for the apps.
- The web page carries a self-check that runs only when its address asks for it (`?check=make`, then `?check=reopen`); it makes a story called "Web Check".
