# The Lighthouse Signal: sample project outline

The sample project for the textbook (M11, §11 of `docs/PLANNING.md`). A short mystery for teens, built up chapter by chapter, so each chapter of the book adds the TaleScript or Unity feature it teaches to a story students already know.

- **Audience:** ages 13 to 18, in a classroom or on their own. No romance, no violence, and the peril is mild and implied (a boat near the rocks in a storm). Nobody is hurt in any ending.
- **Length:** 15 to 20 minutes for one playthrough, about 220 lines in three tales. Replaying for the other endings takes 5 to 10 minutes each.
- **Engines:** written once in TaleScript, so the same tales run in Unity (the main lab) and Godot (the Godot lab).
- **Originality:** all writing, art, music, and sounds are new (decision 0001). The first build uses simple placeholder art and sounds, swapped for final assets later (see "Assets").

## The story

Marrow Point is a small fishing town on a rocky coast. An autumn storm is coming in. The lighthouse on the point was shut down ten years ago, but tonight, from the window of the Calloway family's harbor café, the player sees it blinking: three short, three long, three short, over and over.

The player and two friends set out to find out who is signaling, and why, before the storm peaks. The answer: Ines Halvorsen, the last lighthouse keeper, has climbed the tower with an old battery lamp. Her nephew's fishing boat, the *Gull*, is overdue, its radio is out, and it's heading for the rocks off the point in the dark. She's sending SOS, but nobody in town has noticed, and her phone has no signal on the point.

The player can work this out from clues around town, and then decide what to do about it.

### Cast

| Id | Name | Who they are | Moods |
|---|---|---|---|
| (the player) | named by the player | New in town this year; the one who notices the light | (not shown) |
| `priya` | Priya Shah | Fixes radios in her garage and wants to be an engineer. Logical and brave, but impatient. | `neutral`, `happy`, `thinking`, `worried`, `determined` |
| `wes` | Wes Calloway | His family runs the café; he knows every story in town. Kind and funny, and he doesn't like heights. | `neutral`, `happy`, `nervous`, `surprised`, `serious` |
| `kenji` | Kenji Mori | Draws in a sketchbook everywhere and notices details others miss. Quiet. | `neutral`, `smile`, `curious`, `worried`, `amazed` |
| `ines` | Ines Halvorsen | The last lighthouse keeper, now in her seventies. Stubborn, warm, and scared for her nephew. | `stern`, `worried`, `relieved`, `smile` |

### The five clues

Each clue is a codex entry (`collect()`) and adds 1 to `clues`.

| Clue | Where | What it tells the player |
|---|---|---|
| `clue_pattern` | The café, or later in the lantern room | The blinking is Morse code: SOS. |
| `clue_logbook` | The library archive | The old keeper's logbook shows the lamp was always checked by Ines, who still has a key. |
| `clue_tide` | The harbor office | High tide is at 10:40 tonight; the rocks off the point are hidden at high tide. |
| `clue_gull` | The harbor office, or the café | The *Gull* left this morning and hasn't checked in. |
| `clue_radio` | Priya's radio shack | Static, then a broken message: a boat with a dead radio is somewhere near the point. |

### Structure

```
prologue.tale         investigate.tale                       lighthouse.tale
  start                 town_square  (the hub)                 cliff_path  (timed choice in the storm)
  the_light     ──►       harbor_office                ──►     stairs
  name_yourself           library_archive                      lantern_room  (decode the signal)
  choose_partner          radio_shack                          meet_ines
                          (each returns to the hub)            ending_rescue / ending_lamp / ending_morning
```

### Beats

**prologue.tale: "A light on the point"**

1. `start`: the café at dusk, rain starting. Wes wipes tables; Priya complains that her radio picks up nothing but static tonight. Wes asks the player's name (`ask_text`). Music: calm.
2. `the_light`: the player notices the lighthouse blinking. Wes says it's been dark for ten years. Kenji sketches the pattern: three short, three long, three short. If the player asks "Is that Morse code?", Priya recognizes SOS (`clue_pattern`). Music changes to mystery.
3. `choose_partner`: who comes with the player? Priya, or Kenji (Wes stays to call his mother, who is out with the harbor master). The choice sets `partner` and adds 1 to that friend's trust (`trust_priya` or `trust_kenji`). It changes some lines and one clue later on.

**investigate.tale: "Asking around"**

4. `town_square`, the hub: the storm is building. The player chooses where to go next. Each place can be visited once (`@once`), and after any two visits a fourth option appears: "Head for the lighthouse now" (`@show_disabled` until then, to show the option exists).
5. `harbor_office`: the harbor master's assistant is busy with the storm. The tide table on the wall gives `clue_tide`. If the player asks about boats, they get `clue_gull`. With Kenji, he spots the *Gull*'s name crossed out on the "due back" board.
6. `library_archive`: the librarian is closing up. The old keeper's logbook gives `clue_logbook`. With Priya, she notices the lamp battery list in the back and guesses someone could run a lamp from a car battery (a line only, no clue).
7. `radio_shack`: Priya's garage. Tuning through static (a sound effect and screen shake) gives `clue_radio`. Only reachable if Priya is the partner, or if the player asks Wes for Priya's spare key (an extra choice). This shows a condition on an option.
8. Each place returns to `town_square` through a beat call, so students see calling and returning.

**lighthouse.tale: "The keeper's light"**

9. `cliff_path`: a timed choice in the wind (`choose(timeout = 6)`): hold the railing, or go back for a flashlight. Running out of time picks "hold the railing". Weather: heavy rain, lightning flashes, a darker color filter.
10. `stairs`: the friend's courage scene. With Kenji, he admits he's scared and the player can encourage him (`trust_kenji += 1`). Wes texts that his mother hasn't heard from the *Gull* (this gives `clue_gull` if the player missed it).
11. `lantern_room`: Ines is at the lamp. If the player doesn't have `clue_pattern`, they decode it here with Ines's help, as a small puzzle: an `ask_text` answer, "SOS", with a hint after one wrong try.
12. `meet_ines`: Ines explains. What happens next depends on `clues` and the partner's trust (`match` and `if`):
    - **`ending_rescue`** (4 or more clues): the player puts the tide and the radio message together. With Priya's help (or Kenji's map sketch), they call the harbor master with the boat's likely position before high tide. Dawn: the *Gull* comes in safely. Ines and her nephew meet on the pier. Music: resolution.
    - **`ending_lamp`** (2 or 3 clues): the player helps Ines keep the lamp signaling until a passing ship relays the message. The *Gull* gets in late but safe. A good ending, and the epilogue hints at what they missed.
    - **`ending_morning`** (0 or 1 clues, or not believing Ines): the player helps Ines down the stairs and home. The next morning, the town learns the *Gull* sheltered in a cove all night and is fine, but the friends never quite know what the light was for. A gentle "mystery unsolved" ending that invites a replay.
13. Every ending records itself in an `@global var endings_found`, and the title screen's Extras show the codex of clues found across playthroughs.

## How it maps to the book

| Chapter | What students build or read in the sample | Features |
|---|---|---|
| **Story craft** | The premise, the cast, the hook (the light), the stakes (the boat, the tide), and three endings that reward curiosity. | Outline and beats on paper first, then as empty `beat` blocks. |
| **TaleScript** | `prologue.tale`: lines and narration, speakers and moods, entering and leaving the stage, backdrops and music, asking the player's name. | `"..."`, `wes (happy): "..."`, `enter()`, `backdrop()`, `music()`, `ask_text`, `{player_name}` |
| **Branching** | Choosing a partner, the town hub with places visited once, a hidden-until-ready option, beat calls that return, the timed choice on the cliff. | `choose:`, `jump`, beat calls, `@once`, `@show_disabled`, options with conditions, `choose(timeout = ...)` |
| **Variables** | Counting clues, partner trust, the codex, endings found across playthroughs, and the ending chosen by the clue count. | `var`, `+=`, `if`/`elif`, `match`, `collect()`, `@global` |
| **Testing paths** | Running the path explorer to find all three endings and count the paths. An exercise plants a bug (a jump to a misspelled beat, a clue that can never be found) for students to catch with the checker, the Story Map, and the path explorer. | The checker, the Story Map, the path explorer |
| **Unity lab** | Setting up the Story Config and scene, the menus, saves, weather and effects on the cliff, an optional 3D lighthouse scene with Shots, and a Spanish translation. | Story Config, `StoryMenus`, `weather()`, `flash()`, `shake()`, `filter()`, Shots, Export Strings |
| **Godot lab** | The same tales in the Godot plugin's project setup and Story tab. | The Godot plugin |

Each chapter's exercises start from the version of the sample at the end of the chapter before. A finished copy is kept for each chapter, so a student who falls behind can catch up.

## Assets

Placeholders come first; final art comes later, made for the book.

- **Backdrops (9):** the café at dusk, the town square in the rain, the harbor office, the library archive, Priya's radio shack, the cliff path at night, the lighthouse stairs, the lantern room, and the harbor at dawn.
- **Cast:** four characters, each with the moods above.
- **CG:** the *Gull* coming into the harbor at dawn (the rescue ending).
- **Music (4 loops):** calm, mystery, storm, and resolution.
- **Sounds:** rain, thunder, wind, radio static, a foghorn, footsteps on metal stairs, and a lamp switching on.
- **Optional 3D (Unity lab):** a simple lighthouse model with a turning lamp, for the Shots section.
- **Voice:** none at first. A later edition could voice Ines to show voice playback.

## Delivery

- **Unity:** a package sample in `unity/com.visualnovelteller.unity/Samples~/LighthouseSignal`, listed in `package.json` under `samples`. Students import it from the Package Manager's **Samples** tab. It includes a scene, a Story Config, and the tales, with per-chapter folders (`Chapter 1` to `Chapter 6`) holding each stage of the story.
- **Godot:** the same tales in `examples/lighthouse_signal/` with a story config, for the Godot lab.
- **Tests:** the finished story's paths are checked in CI (all three endings reachable, no unreachable beats or problems), and the Unity sample compiles in the package checks.

## Unity features this sample needs

The outline uses TaleScript the Godot plugin already supports. The Unity package doesn't have these yet, so they come before or with the sample:

- `ask_text` (and `ask_number`): a text box for the player's name and the Morse answer.
- `collect()` and the Extras screen with a codex, for the clues.
- `cg()` and `hide_cg()`, for the dawn rescue picture.

Trust uses plain variables (`trust_priya`, `trust_kenji`) rather than per-character fields such as `priya.trust`, which the Unity package doesn't have; the book can introduce fields in the Godot lab or a later edition.

## Open questions

1. Should the player character be named by the player (as outlined), or have a fixed name so the book's screenshots match every student's screen?
2. Is the Morse puzzle (typing "SOS") too easy or too hard for 13-year-olds? A three-choice version is the fallback.
3. Should the optional 3D lighthouse be part of the core Unity lab, or a bonus section?
