# Visual Novel StoryTeller Studio: design

Status: proposed (decisions 0020 and 0021). Visual Novel StoryTeller Studio is a standalone product for kids, separate from Visual Novel StoryTeller, the Godot plugin for adults, with its own version numbers. This page describes what the Studio is, how a student uses it, how it is built, and what it needs so a textbook can be written for it. It is the plan for milestone M8 (`docs/PLANNING.md` §11).

## 1. Who it is for

Visual Novel StoryTeller Studio is a story builder for middle school students, ages 11 to 14, working on tablets: iPads first, and Android tablets. Students download it as a free app from the App Store or Google Play. Teachers use it in class, guided by a textbook written for it (§13), and anyone can use it at home.

**Success test.** A 12-year-old who has used Scratch, working alone on a tablet, makes a story with three scenes, two characters, a background, and one choice within a 45-minute class period, then plays it for a classmate.

## 2. Principles

1. **Open and play in seconds.** The Studio is a free app: no account, no Godot editor, and it works without a connection.
2. **Pictures over names.** Blocks show a character's face and a small picture of the background, so a student recognizes them at a glance.
3. **Touch first.** Every target is at least 44 points tall. Everything works with one finger: drag, tap, long-press. Nothing depends on hover or right-click. The on-screen keyboard is needed only for typing words.
4. **The same story files.** The Studio reads and writes TaleScript `.tale` files, the same files the Godot plugin uses (§9.1 of the plan: one source of truth). A student's story can move into Godot later and keep growing.
5. **Hard to break.** Every change can be undone. Problems show as friendly hints on the block they belong to and never stop the student from playing.
6. **Plain words.** Labels and hints are written for a fifth or sixth grade reader.
7. **Saved all the time.** Every change is saved on the device at once. There is no Save button to forget.

## 3. Words students see

The Studio uses simpler words for some of StoryTeller's terms. The files and the Godot plugin keep the usual terms.

| In the Studio | In TaleScript and the plugin |
|---|---|
| Story | Tale (a `.tale` file) and its folder |
| Scene | Beat |
| Character | Cast member |
| Face | Mood |
| Background | Backdrop |
| Big picture | CG |
| Choice | `choose:` |
| Number to remember | Variable |
| Go to scene | `jump` |

## 4. The screen

Landscape on a tablet (1024 x 768 points and up, about the size of the smallest iPad).

```
┌──────────────────────────────────────────────────────────────────────┐
│ ⌂  My Story ✎              ↶ Undo  ↷ Redo        ▶ Play    ⇪ Share   │
├──────────┬──────────────────────────────────────┬────────────────────┤
│ Blocks   │ Scenes:  [Start] [Toy box] [Yard] [+]│  Stage preview     │
│          ├──────────────────────────────────────┤  ┌──────────────┐  │
│ ● Talk   │                                      │  │  (the scene  │  │
│ ● Act    │   Background [living room ▾]         │  │  at the      │  │
│ ● Scene  │   Show [Theo ☺] at [left]            │  │  chosen      │  │
│ ● Choose │   Theo ☺ says "Where is Biscuit?"    │  │  block)      │  │
│ ● Numbers│   Choice                             │  └──────────────┘  │
│          │   ├ "Look in the toy box"            │  ▶ Play from here  │
│ [blocks  │   │    Go to scene [Toy box]         ├────────────────────┤
│  of the  │   └ "Look outside"                   │  Characters        │
│  chosen  │        Go to scene [Yard]            │  [Theo][Leo][Cleo] │
│  color]  │                                      │  [+ Add]           │
│          │                                      │  Backgrounds  [+]  │
│          │   ↓ drag blocks here                 │  Sounds       [+]  │
└──────────┴──────────────────────────────────────┴────────────────────┘
```

- **Blocks palette (left).** Five colored groups, plus a gray one for notes. Tapping a group shows its blocks, and dragging a block into the scene adds it.
- **Scene (middle).** The blocks of the chosen scene, top to bottom, in the order they play. Tabs above switch scenes; **+** adds one. A **Map** button shows all scenes as boxes with arrows (the Story Map, simplified).
- **Stage preview (right, top).** The scene as it looks at the chosen block. **Play from here** starts the story at that block.
- **Library (right, bottom).** The story's characters, backgrounds, and sounds, with **+** to add from the starter library or from the student's own pictures.
- **Top bar.** Home (the list of stories), the story's name, undo and redo, **Play** from the beginning, and **Share**.

## 5. Blocks

Each block writes one TaleScript statement, so the file reads naturally if a student opens it as text later.

| Group (color) | Block | TaleScript it writes |
|---|---|---|
| Talk (blue) | [character][face] says "…" | `theo (happy): "Hi!"` |
| | Narrator says "…" | `"It is a sunny morning."` |
| | Ask the player for a name, keep it in [name] | `player_name = await ask_text("What is your name?")` |
| Act (purple) | Show [character][face] at [left / middle / right] | `theo.enter("happy", at = LEFT)` |
| | Change face of [character] to [face] | `theo.mood = "sad"` |
| | Move [character] to [left / middle / right] | `theo.move_to(RIGHT)` |
| | Hide [character] / Hide everyone | `theo.exit()` / `exit_all()` |
| | [character] hops / shakes / nods | `theo.hop()` |
| Scene (green) | Background [picture] | `backdrop("yard")` |
| | Big picture [picture] / Hide big picture | `cg("hug")` / `hide_cg()` |
| | Play music [track] / Stop music | `music("happy_tune")` / `stop_music()` |
| | Play sound [sound] | `sound("ding")` |
| | Wait [1] seconds | `wait(1.0)` |
| | Weather [rain / snow / none] | `weather("rain")` |
| | Shake the screen | `shake()` |
| Choose (orange) | Choice, with an arm for each option ("…" then blocks) | `choose:` with options |
| | Go to scene [scene] | `jump yard` |
| | The end | `return` (the story ends when a scene finishes with nowhere to go) |
| Numbers (red) | Set [number] to [0] | `var` and `score = 0` |
| | Add [1] to [number] | `score += 1` |
| | If [number] [is at least] [2], with an arm for "otherwise" | `if score >= 2:` / `else:` |
| | If the player has been to [scene] | `if visited("my_story.yard"):` |
| Code (gray) | Note: "…" | `# …` (a comment) |
| | Code (an advanced setting) | any TaleScript, kept exactly as written |

- **Shapes.** Most blocks stack. Choice and If are wrapped blocks with arms that hold other blocks. Go to scene and The end close a stack, so nothing can be placed under them.
- **Editing a block.** Tapping a field opens a picker: faces and backgrounds as pictures, scenes as a list, numbers with − and + buttons. Text fields open the on-screen keyboard.
- **Moving and deleting.** Drag a block to move it; a line shows where it will land. Drag it back to the palette to delete it. A long-press offers Duplicate, Delete, and Help.
- **Advanced blocks.** A switch in the settings shows one more block, **Code**, holding raw TaleScript, and shows any part of a file the other blocks can't show (the same idea as the plugin's script cards).

## 6. Characters, backgrounds, and sounds

- **Starter library.** Original characters with several faces each, backgrounds (home, school, park, forest, castle, space), music, and sounds, all made for the project like the demo's art, so students can start at once. The library (`studio/library/`) holds the Studio's own art in `studio/library/art/`, made by `tools/demo_assets/starter_library.py`: park, forest, castle, beach, and space backgrounds; Maya, Sam, Robo, and Whiskers with neutral, happy, sad, surprised, and thinking faces; adventure and mystery music; and pop, whoosh, and magic sounds. It also offers the Where's Biscuit characters and backgrounds and the demo's characters, backgrounds, music, and sounds.
- **Each story keeps its own copies.** A story's pictures and sounds are plain files in its folder (decision 0023). When a story uses a starter item, the Studio copies it in, so a story file carries everything it needs (decision 0022). Pickers offer the story's own items first, then the rest of the starter library.
- **Library panel.** Under the stage preview, the story's characters, backgrounds, and sounds, each with **+ Add**: an item from the starter library, or the student's own picture or sound file. Tapping a character shows its faces, with **+ Add a face**; tapping a sound plays it.
- **Their own pictures.** **+ Add** opens the tablet's own picker: take a photo, or choose one from Photos or the gallery. A character's faces are pictures named by the student ("happy", "sad"). The Studio scales large photos down to save space (backgrounds to 1920 by 1080, faces to 1024 by 1024) and saves photos as `.jpg`.
- **Character maker (later, §12).** Build a character from parts (skin, hair, eyes, shirt colors) without drawing, using the same drawing code as the example art.

## 7. Preview and play

- **Stage preview.** Choosing a block shows the stage as it looks at that point, with the block's line in the dialogue box. The preview runs a small story of its own: from the start of the scene, the blocks on the way that set the stage (backgrounds, big pictures, characters, faces and places, weather, numbers, and Ifs holding those), then the chosen block. Lines, choices, sounds, and waits on the way are left out; inside a Choice only the block's own option counts, and inside an If its own arm. The preview makes no sound. This is the stage preview once planned for Pro (`docs/PLANNING.md` §9.5), now free.
- **Play.** Full screen, from the beginning, with a large ✕ to go back to editing.
- **Play from here.** Starts at the chosen block with the stage, music, and numbers as they would be there, then goes on the way the story would, past the end of the Choice or If the block is in. Like the preview it starts from the beginning of the block's scene, so numbers changed in earlier scenes start at their first values.

## 8. Stories, saving, and sharing

- **Home screen.** The student's stories as cards with a picture, plus **New story**, which offers a blank story or a starter template (a mystery, an adventure, a "choose your path" lesson).
- **Saving.** Every change saves in the app's own storage on the device (Godot's `user://`), which stays until the app is removed.
- **Share.** **Share** packs the story into one `.zip` file (its tales, pictures, sounds, and config) and opens the system's share sheet: AirDrop, Files, Google Drive, Google Classroom, or email. The first version saves the `.zip` through the system's file picker (Files and iCloud on an iPad, Files and Google Drive on Android); the share sheet needs a small native plugin and follows. **Open a story file** on the home screen loads a `.zip` from Files, so a teacher can open a student's story, and a student can move a story between devices.
- **Keeping stories safe.** Removing the app removes its stories, so the Studio reminds students to Share a copy of a story they changed and haven't shared for a week.
- **Publishing goes through an adult (decision 0022).** The Studio never publishes a story itself. A student Shares the story file with a teacher or parent, who opens it in Godot and decides whether it goes public.
- **Into Godot.** The plugin's **Open a Studio story** command, in the Story tab, unpacks a story file into a Godot project as its own story folder under `res://studio_stories/` with its own config and a `main.tscn` that plays it. `docs/guides/publishing-studio-stories.md` is the teacher's guide. The story plays in the editor, opens in the Story tab, and exports as a game: a web build for itch.io or a class website, or a desktop or Android build. So the file carries everything a build needs: the tale, `story.json`, and the pictures and sounds the story uses (from the starter library and the student's own). The command writes the story config itself, since a story file never holds a Godot resource, which could run code.

## 9. How it is built

- **A Godot project.** The Studio is a Godot project in the repository's `studio/` folder that uses the StoryTeller plugin's runtime and editing layer. It is exported as an iOS app and an Android app, and needs no server. The same project can be exported for desktops or the web later (decision 0021).
- **One story model.** Blocks are a new view over the card model from M5 (`TaleCards`, `TaleEdit`). They edit the `.tale` text line by line, exactly as the cards do, so round trips stay clean and the existing round-trip tests cover them.
- **Runtime editing.** The parser, checker, and editing layer must run in an exported game, without the Godot editor. Some editor code uses `EditorInterface`; that code moves behind a small interface so the Studio can supply its own file listing, pictures, and undo.
- **Stage preview.** A `StoryStage` drawn in a `SubViewport`, fed by the director's fast mode.
- **Pictures and files.** The system's own photo and file pickers, through Godot's native file dialog where it supports them, or a small iOS and Android plugin where it doesn't. The share sheet works the same way.
- **Rendering.** Godot's Compatibility renderer (OpenGL ES 3), which runs on older and cheaper school tablets as well as new iPads. The plugin's shaders (transitions, screen filters) must work there.
- **Builds and releases.** GitHub Actions builds the Android app on Linux and the iOS app on a macOS runner, signs them with the maintainer's developer accounts, and uploads them to Google Play's testing track and TestFlight. Releases go to the stores from there.
- **Store rules for children's apps.** The Studio collects nothing, shows no ads, and has no outside links in the student's path, which fits Apple's Kids category and Google Play's Families policy.
- **Website.** A project website at a Visual Novel StoryTeller domain links to both stores and hosts the guides and lesson files.

## 10. Risks and the first step

The biggest unknowns are about tablets, so M8 starts with a one-week feasibility check: a small test app installed on a real iPad (through TestFlight) and a real Android tablet, before the Studio is built:

1. The app starts quickly (target: under 5 seconds) and stays smooth on an older, low-cost tablet.
2. Dragging a block with a finger feels smooth, and long-press works.
3. Tapping a text field brings up the on-screen keyboard, typed text arrives, and the layout survives the keyboard covering half the screen.
4. Choosing a photo from Photos or the gallery reaches the Studio, and the share sheet sends a `.zip` to Files.
5. A saved story is still there after closing the app and restarting the tablet.
6. Music and sounds play after the first tap.
7. The stage, transitions, and filters draw correctly in the Compatibility renderer.

Each item gets a pass or a workaround before the Studio work goes on. The check needs a person with the tablets and the developer accounts (§9); the test app is built by GitHub Actions from the repository.

## 11. Plan (milestone M8, about 13 weeks)

| Step | Work | Weeks |
|---|---|---|
| S0 | Tablet feasibility check (§10), with the developer accounts and the build pipeline set up | 1 |
| S1 | Studio shell: home screen, stories in the app's storage, Share and Open as `.zip` | 2 |
| S2 | Blocks: palette, drag and snap, pickers, undo, hints, Code block | 4 |
| S3 | Stage preview, Play, and Play from here | 2 |
| S4 | Starter library and adding the student's own pictures and sounds; story files carry the pictures and sounds they use | 1 |
| S5 | Map of scenes, starter templates, lesson projects and the screenshot script for the textbook (§13); **Open a Studio story** in the plugin, a web export check, and a teacher's guide to publishing a student's story (decision 0022) | 2 |
| S6 | Store listings (privacy details, Kids category, screenshots) and the first TestFlight and Google Play test release | 1 |

**Exit criteria:** every block, the stage preview, the starter library, and sharing work on an iPad and an Android tablet, and a test build is on TestFlight and Google Play's testing track.

**Later:** a classroom test with middle school students against the success test (§1), once the Studio works. Its timing is open.

## 12. Later

- Character maker (§6).
- Blocks inside the Godot plugin's Story tab, as a fourth view next to Text, Cards, and Map.
- Phone layouts, and web and desktop versions (decision 0021).
- The rest of the former Pro features (`docs/PLANNING.md` §12).

## 13. Textbook support

The maintainer is writing a textbook that teachers use to run a class with the Studio. A book stays in print for years and can't change when the Studio does, so the Studio makes these promises:

- **A stable interface for each edition.** Before the first edition is written, the Studio's block names, colors, groups, screen layout, and words for students (§3) are frozen. Changes that would make the book wrong wait for the next major version.
- **Every edition keeps working.** App stores offer only an app's newest version, so the interface stays as the book shows for the life of an edition. A major version with interface changes ships as its own app listing (for example "Visual Novel StoryTeller Studio 2"), and classes using the older edition keep installing the app their book shows.
- **Lesson projects.** Each chapter's starting and finished stories live in the repository (`studio/lessons/`) and open from the Studio's home screen under **Lessons**, so students start a chapter with one tap.
- **A stable starter library.** Characters, backgrounds, and sounds used in the book keep their names and pictures within a major version.
- **Screenshots from a script.** A script opens each lesson project in the Studio and saves the screenshots the book uses, so they can be made again for a new edition or language. It builds on the play-through harness used in release testing.
- **Concepts each chapter can teach.** The blocks cover the main ideas of a first programming course alongside story writing:

| Idea | Where it appears in the Studio |
|---|---|
| Sequence | Blocks run from top to bottom in a scene |
| Events and input | The player's choices; Ask the player for a name |
| Branching | Choice, Go to scene, the Map |
| Variables | Numbers to remember: Set, Add |
| Conditions | If, otherwise, and "has been to scene" |
| Debugging | Hints on blocks, Play from here, the stage preview |
| Story structure | Scenes, characters, beginnings and endings |

The book itself, its license, and its publishing are the maintainer's, separate from the Studio's MIT license.
