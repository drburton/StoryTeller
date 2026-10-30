# 0027. Rename the product before 1.0

- **Status:** Accepted
- **Date:** 2026-10-30

## Context

The product is called "StoryTeller" and "Visual Novel StoryTeller" (the Studio is "Visual Novel StoryTeller Studio"). Version 1.0 and a printed textbook are coming, and a name is hard to change after either.

On 2026-10-30 a preliminary web search looked for conflicts. This was a web search only. It is not legal advice and not a trademark clearance. The USPTO search site could not be reached, so the trademark register was not searched directly.

What the search found:

- **Storyteller (2023):** a puzzle game by Daniel Benmergui, published by Annapurna Interactive.
- **Storyteller 2 and Storyteller (DaiMangou):** narrative tools on the Unity Asset Store. They are in the same engine and the same kind of product as the planned Unity version.
- **Storyteller Read Aloud to Kids:** an educational app for children, close to the Studio's audience.
- **Live US trademarks containing STORYTELLER in software:** for example AccuWeather (Reg. 4337228) and Disney ("STORYTELLER LIVE").
- **Visual Novel StoryTeller:** no exact match. "Visual Novel" describes the product, so the distinctive word is still StoryTeller.

## Risk assessment

The risk for "StoryTeller" is high. The word is common, several products and trademarks use it, and one of them sells narrative tools in Unity's own store, where the Unity version will be listed. Adding "Visual Novel" does not make the name distinctive.

## Candidate names

These had no product found in the searches. None is cleared.

- Plotwright
- Novelwright
- Tellwright
- Branchline

## Decision

The product is renamed **Visual Novel Teller** before 1.0 and before the book goes to print. The Studio is renamed **Visual Novel Teller Studio**. The maintainer chose these names on 2026-10-30.

A follow-up preliminary web search (not legal advice and not a trademark clearance) found no exact match for "Visual Novel Teller", "VN Teller", or "Novel Teller". The closest hits were "Teller Novel" (Teller Novel Inc.), a free app for reading chat-style fiction, and "Visual Novel Maker", a known commercial tool with a similar naming pattern.

The trade-off: "Visual Novel" is descriptive, and the field is crowded. The maintainer accepts this because schools are the target audience. A descriptive name is harder to register and protect as a trademark. A trademark attorney's search is still recommended before the name is printed or used in store listings. The findings about "StoryTeller" above remain the reason for the rename.

What the rename covers, in milestone M9:

- The plugin name and description in `addons/storyteller/plugin.cfg`.
- The README and all docs.
- The Story tab's visible text where it shows the product name.
- The Studio's app name and store package display name.
- The release zip name.
- The GitHub repository description.
- The Asset Library listing.

Code identifiers stay as they are for 1.0 to avoid breaking projects, unless the maintainer decides otherwise. These include the `addons/storyteller` folder, class names such as `StoryConfig`, the `Story` autoload, and the TaleScript language name.

## Alternatives considered

- **Keep the name:** no rename work, but a high chance of a forced rename after launch, with the book already printed.
- **Keep the name with a longer title:** the added words describe the product and do not separate it from the other Storyteller products.

## Consequences

- The rename is part of milestone M9: the attorney's search, then the repository text, plugin, documentation, Asset Library listing, and domain.
- The rename should land before the Unity package is listed, so the Unity version never ships under the old name.
- The Studio's name changes with the product.
- The name is chosen, but it is not cleared until the attorney's search is done. Get that search before printing and before store listings.
