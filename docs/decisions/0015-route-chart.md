# 0015. The route chart: what it records and what it shows

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

M6 adds a route chart for players: a screen that shows the branches they have explored, so they can see what they have found and where they might go next. It must not spoil the story. We needed to decide what to record, where to keep it, how beats are named on the chart, and how much to show of paths the player has not taken.

## Decision

- **What is recorded.** The director keeps a `RouteLog`: each beat entered, each link between two beats (a jump or a beat call), and each choice option as seen or picked, keyed like translations (`<tale>:<id>`). It is recorded as play happens, not worked out from the tales, so the chart only ever holds what the player has done.
- **Where it lives.** The log covers every playthrough and is saved with the global data (read lines and `@global` variables), not in save slots. Loading an old save does not hide routes the player already found.
- **What the chart shows.** Every beat the player has entered, one band per tale in the order the tales were reached, with lines for the links taken. Each beat lists the choices met there. Picked options get a filled dot, and options seen but never picked get an empty one. That empty dot is the only hint of an unexplored path. Options never shown, such as those whose condition was false, are left out, and so are beats never entered.
- **Names.** A new `@heading("...")` annotation names a beat on the chart. It is translated like tale titles, keyed by its text, and Export Strings includes it. A beat without one shows its name. `@title` was not reused, because a `@title` line above a beat already means the tale's title.
- **Where players find it.** A Routes tab in Extras, shown once the log has a beat. `StoryConfig.show_route_chart` turns it off.

## Alternatives considered

- **Building the chart from the tales and greying out unvisited beats:** shows the size and shape of the story, which spoils it, and beats reached only through game code would be missing anyway.
- **Showing only beats with a heading and joining the links through the others:** a cleaner chart for large stories, but choices inside unnamed beats would have no place, and writers would have to name beats before the chart showed anything. It can be added later as an option.
- **Keeping the log in save slots:** a player loading an early save would lose the routes they had found, which is the opposite of what a route chart is for.

## Consequences

- Global save files gain a `routes` entry; files written before it load with an empty chart.
- The chart has no "jump to this scene" button. Replaying from a beat would need a saved state for every beat, which is a larger feature.
- Image choices and other choice styles appear on the chart without extra work, because options are recorded by the director, not by the menu.
