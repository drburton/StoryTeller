# 0013. CGs, their layer, and gallery variants

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

M6 adds CGs: full-screen event pictures shown at important story moments, which most visual novels collect in a gallery. A CG often comes in several variants (the same scene at another time of day, or with another expression), and players expect the gallery to group them. We needed to decide where CG files live, how tales name variants, where CGs draw relative to the stage and effects, and how they reach the gallery.

## Decision

- CGs live in `StoryConfig.cg_folder` (`res://story/cgs/` by default). A single image `<name>.png` is a CG with one picture. A folder `<name>/` is a CG whose images are its variants. This matches cast members, whose folders hold one image per mood.
- Tales show them with `cg(name, variant = "", transition, time)` and remove them with `hide_cg(transition, time)`. Without a variant, the `default` image is shown, or the first by name. Transitions are the backdrop transitions, drawn by a second `BackdropView`.
- CGs draw on their own canvas layer (4), above props and below weather (5) and color filters (6). Rain and filters therefore apply to CGs as they do to the stage. The stage camera does not move CGs.
- Every CG has a gallery item. It is a saved `CollectionItem` whose `cg` field names the CG (or whose id is the CG's name and which has no image), or one made automatically with a title from the CG's name. Showing a CG unlocks its item without a notice, and records the variant as seen in the global data. The gallery viewer steps through the seen variants. An item unlocked another way (`collect()` or the console's `unlock_all`) shows every variant.
- The stage saves the CG on screen with the rest of the stage, so loading and rewinding restore it.

## Alternatives considered

- **Variants as separate files (`rooftop_night.png`) or as `name.variant` strings.** File-name suffixes are ambiguous when names contain underscores, and dotted names would read like attribute access in TaleScript. Folders mirror cast moods and keep each CG's pictures together.
- **CGs as backdrops with a gallery flag.** A backdrop sits under the cast, while a CG must hide the cast and props without removing them, so the scene is unchanged when the CG goes away. A separate layer does that.
- **Requiring a `CollectionItem` for every CG.** Most games put every CG in the gallery, so automatic items save busywork. Saved items remain for titles, captions, translations, and order.
- **A notice when a CG unlocks.** The picture itself is the reveal; a notice on top of it would cover the art.
- **Letting the camera zoom and pan CGs.** That would let a zoom left over from the scene crop a CG by accident. Panning across a CG may come later as a separate option.

## Consequences

- Weather and filter layers moved from 4 and 5 to 5 and 6. Projects that put their own nodes on those layer numbers should check their order.
- A CG and a saved collection item with the same id but an image of its own are not linked. The CG then gets no automatic item, since ids must be unique.
- The export check lists the CGs an exported game finds and loads each variant.
