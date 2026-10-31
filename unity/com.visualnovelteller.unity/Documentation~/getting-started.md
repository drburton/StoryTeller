# Getting started with Visual Novel Teller for Unity

This guide takes you from an empty Unity 6 project to a tale playing in a scene, then adds an Animator so a Blender character can act in it.

## Install the package

1. Open **Window > Package Manager**.
2. Choose **+ > Install package from git URL**.
3. Enter this address and press **Install**:

       https://github.com/drburton/StoryTeller.git?path=/unity/com.visualnovelteller.unity

Unity downloads the package and its dependencies (Timeline, UI Toolkit, Audio, and Animation). Packages added this way are read only in your project, which keeps updates simple.

## Make a Story Config

A Story Config holds the settings for your game: which tales to load, who is in the cast, and which pictures and sounds tales can name.

1. In the Project window, choose **Assets > Create > Visual Novel Teller > Story Config**.
2. Select the new asset. Under **Cast**, add an entry for each character. Give it an id (lowercase, such as `mira`), a display name, a name color, and a list of moods. Each mood pairs a name such as `smile` with a sprite.
3. Add backdrops (a name and a sprite each) and audio clips (a name and a clip each). Tales refer to them by these names.
4. If game code will add objects for tales to use, list their names under **Exposed Names**. Tales that mention them then import without errors.

Sprites need the **Sprite (2D and UI)** texture type in their import settings.

## Add a .tale file

1. Create a text file in your project named `prologue.tale`. Unity imports it as a Tale asset, and the file name becomes the tale name.
2. Write a short story:

       beat start:
           backdrop("classroom")
           music("quiet_morning", volume = 0.8)
           mira: Good morning!
           choose:
               "Good morning.":
                   mira: You are early today.
               "Five more minutes.":
                   mira: Come on, the bell is about to ring.

3. Select the tale in the Project window. Its Inspector lists the beats, any problems, and the source. Errors and warnings also appear in the Console with the file and line.
4. Drag the tale into the Story Config's **Tales** list, and set **First Tale** to it. Play begins at the beat `start` unless you change **First Beat**.

Tales are checked against the first Story Config found in the project. Without a config, the importer reports only syntax errors and warnings, since it cannot know your names yet.

## Put a Story in a scene

The quickest way: choose **Tools > Visual Novel Teller > Set Up Story in Scene** (also under **GameObject > Visual Novel Teller > Story**). It uses the project's Story Config, or makes `Assets/Story Config.asset` listing every tale in the project, then adds a GameObject with a Story and a DialoguePresenter. Press Play to read the first tale.

To set it up by hand:

1. Create an empty GameObject and add the **Story** component.
2. Assign your Story Config. Leave **Play On Start** on.
3. Add a **DialoguePresenter** to the same object, or leave it out and the Story adds one. It builds a UI Toolkit panel on its own, with large high contrast text that needs no theme style sheet.
4. If the config has cast or backdrops, the Story also adds a **Stage2D**. If it has audio clips, it adds a **StoryAudio**. You can add these yourself to change their settings.
5. Press Play.

Click, Space, or Enter finishes the typing of a line and then moves on. Choices appear as buttons, and options that are not available show greyed out. A timed choice, written `choose(timeout = 5)`, shows a shrinking bar and takes the timeout path when it runs out.

If clicks do nothing, check that the scene has an EventSystem (**GameObject > UI > Event System**) that matches your input setting.

### Change the look

Copy `Dialogue.uxml` and `Dialogue.uss` from `Runtime/Unity/Resources/VisualNovelTeller` in the package into your project, edit them, and assign them in the Story Config under **Dialogue**. Keep the element names that start with `vnt-`, since the presenter looks for them. If you use a ThemeStyleSheet, assign it in the same place.

### Talk to game code

Game code can read and change tale variables and listen for signals:

    var story = FindFirstObjectByType<Story>();
    story.Expose("player", player);          // tales may call player.give("key")
    story.SetVar("prologue", "trust", 3);
    story.Signal += (name, value) => Debug.Log(name);

Tales raise a signal with `emit("door_opened")`. An **On Signal** event in the Inspector receives the same call. Runtime errors in a tale go to the Console as `tale:line: message`.

## What tales can use

| Name | Does |
| --- | --- |
| `backdrop(name, transition = "fade", time = 1.0)` | Shows a backdrop, or a Color such as `Color.BLACK` |
| `music(track, volume = 1.0, fade = 1.0, loop = true)` | Crossfades to a music track |
| `stop_music(fade = 1.0)` | Fades the music out |
| `sound(name, volume = 1.0)` | Plays a sound effect, and `await` waits for its end |
| `exit_all(time = 0.4)` | Every cast member leaves |
| `mira.enter("smile", LEFT)` | Puts a cast member on stage at LEFT, CENTER, or RIGHT |
| `mira.exit()`, `mira.move_to(CENTER, 0.6)` | Moves a cast member off stage or across it |
| `mira.mood = "worried"` | Changes the sprite |
| `mira.scale_to`, `hop`, `shake`, `nod`, `to_front`, `to_back` | Small animations and drawing order |
| `emit(name, value)`, `wait(seconds)` | From the core |

Cast methods take their arguments by position, in the order the Godot reference lists them (enter: mood, at, time, transition). Positions are fractions of the screen: x runs from 0 to 1, and a second number lifts the character above the bottom edge, as in `Vector2(0.5, 0.1)`.

## Shots: Blender characters with an Animator

For stories told in your own 3D scene, the **StoryShots** component plays animations by name and waits for them.

1. Export your Blender character as a `.glb` or `.fbx` with its animations and drop it into the scene.
2. Build an Animator Controller with one state per shot, named as tales will call them, such as `approach`, `jump_gap`, and `idle_wait`. Mark idle poses as looping.
3. Add **StoryShots** to any object in the scene. Assign the character's Animator. To use Timeline instead, assign a PlayableDirector and list Timeline assets by name under **Timeline Shots**.
4. Make sure the scene has a Story. It finds the StoryShots and exposes it to tales as `shots`.
5. Use it in a tale:

       beat bridge:
           await shots.play("approach")
           mira: We have to jump.
           choose:
               "Jump the gap":
                   await shots.play("jump_gap")
               "Wait here":
                   shots.hold("idle_wait")

`shots.play("name")` returns when the animation reaches its end. A looping state returns at once. `shots.hold("name")` starts a looping pose and lets the tale continue. `shots.has_shot("name")` tells a tale whether a shot exists. While the player skips, a shot jumps to its last frame.

For a Timeline shot, set the director's extrapolation to None so the end of the timeline can be detected. Tracks that should keep their final pose can hold it in their own settings.

StoryShots keeps `Current` and `Holding` for scripts. Saves include the shot automatically, as described below.

## Saving and rewinding

Story saves the whole play state: the place in the tale, its variables, the stage, the music, and the current shot. The stage, audio, and shots components join every save on their own.

    story.SaveSlot("slot1");                 // writes saves/slot1.json
    if (story.HasSlot("slot1")) await story.LoadSlot("slot1");
    story.DeleteSlot("slot1");

    string json = story.SaveToJson();        // keep the text anywhere you like
    await story.LoadFromJson(json);

Slot names allow letters, digits, `-`, and `_`. Files go to `Application.persistentDataPath/saves/` as UTF-8 JSON. Saving a slot also writes `globals.json` next to it, which holds the global variables, the lines already read, and the route log. Story reads that file when the scene starts. Loading stops the current play, restores the state, and plays on from the saved line or choice. A save that cannot be read is reported with `Debug.LogError` and the story keeps going where it was.

Rewind steps back through lines and choices. The Story Config has a **Rewind Depth** field, 50 by default, and 0 turns rewind off. A line marked `@no_rewind` clears the history, so the player cannot go back past it.

    if (story.CanRewind) await story.Rewind(1);

While testing in play mode, the dialogue answers a few keys: F5 saves to the slot `quick`, F9 loads it, and PageUp or the mouse wheel up rewinds one step. Each does nothing when the story cannot do it. A line or choice on screen is cancelled during a load or rewind, so nothing from the old moment finishes later.

Game code can add its own state with `story.Director.AddStateProvider(provider)`. A provider names itself, returns plain data from `Capture()`, and receives it again in `Restore(data)`.

## Testing every path

A tale with choices has more routes than you can click through by hand. The Path Explorer plays all of them for you. Choose **Window > Visual Novel Teller > Path Explorer**, select a `.tale` file in the Project window (or drag one into the Tale field), and press **Explore**.

The window takes its exposed names, cast, and other tales from the Story Config in your project. Objects from game code are replaced by stand-ins whose methods do nothing, and the built-in actions such as `music()` and `backdrop()` do nothing as well, so your scene stays untouched while it runs. A timed choice is tried with the time running out. `ask_text()` answers with its default.

Results include:

- the number of paths and lines, and a warning when a limit cut the exploration short;
- the endings, with how many paths reach each;
- the beats no path enters;
- the problems, such as runtime errors, choices that never end, and paths that run past the limits. Each shows how many paths hit it and the choices that led to the first one. Click a problem to open the tale at that line;
- every path, with the options taken and where it ended.

Under **Limits** you set the most paths, the most choices on one path, the most lines between two choices, and the seconds a path may run. A path that passes a limit is cut off and has no ending. Because each choice multiplies the paths, a tale with many independent choices can reach the path limit. The window then says the list is not complete.

Outside Unity, `talescript-check --paths prologue.tale` prints the same report in a terminal and fails when a path hits a problem, which suits a build server. See `csharp/README.md` for the options. Game code can call `TalePaths.Explore` too, for example from a test.

## Where to go next

Godot's plugin documents the same TaleScript language, so its reference applies here. The package README lists the folders, and `csharp/README.md` in the repository describes the core API for game code.
