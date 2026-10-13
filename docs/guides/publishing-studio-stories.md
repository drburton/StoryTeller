# Publishing a student's story

This guide is for teachers and parents. A student makes a story in **Visual Novel StoryTeller Studio** and taps **Share**, which saves the story as one `.zip` file. The Studio never puts a story online by itself (decision 0022): you open the file in Godot, play it, decide whether it should be public, and publish it yourself. It takes about fifteen minutes the first time.

You need:

- Godot 4.7.2 (the standard build) on a Windows, macOS, or Linux computer.
- A Godot project with the StoryTeller add-on enabled. Step 1 of [Getting started](getting-started.md) shows how. You don't need to run the setup wizard.
- The student's story file, such as `castle_trip.zip`, from AirDrop, email, Google Classroom, or a USB stick.

## 1. Open the story

1. Open the **Story** tab at the top of the editor.
2. Click **Open a Studio story** in its toolbar and choose the story file.

The story gets a folder of its own under `res://studio_stories/`, named after the story:

| In the folder | What it is |
|---|---|
| `tales/<name>.tale` | The story's text, which the Studio's blocks wrote |
| `backdrops/`, `cgs/` | Its backgrounds and big pictures |
| `cast/<character>/` | One picture per face for each character, and a `profile.json` with the name shown on screen and its color |
| `audio/music/`, `audio/sounds/` | Its music and sounds |
| `story_config.tres` | The story's settings: its title, its folders, and where its saves go |
| `main.tscn` | A scene that plays the story |

Opening the same file again makes a second folder (`castle_trip_2`), so nothing you changed is replaced. A story file can only hold the story's text, pictures, sounds, and character names; anything else in the file is left out, so opening one can't run any code.

## 2. Play it and read it

Open `main.tscn` from the story's folder in the FileSystem dock and press **F6** (Run Current Scene). The title screen shows the story's name; **New Game** plays it.

The story's text opens in the Story tab. **Text** shows it as TaleScript, **Cards** one statement at a time, and **Map** its scenes and how they connect, which is quickest for seeing every path a reader can take.

Before you publish, check:

- **Real people.** Photos of the student, classmates, or family, and full names. A first name or a made-up character is safer.
- **Personal details.** The school's name, a town, an address, or anything that tells a stranger where to find the student.
- **What it says.** Every path through the story, including the ones behind choices. The Map shows them all.
- **Permission.** Your school's rules, and the student's and their family's agreement to publish it.

You can fix small things yourself in the Story tab, or ask the student to change the story in the Studio and share it again.

## 3. Finish the details (optional)

Select `story_config.tres` and look at the Inspector:

- **Game Title** is the name on the title screen and in the browser tab.
- **Title Background** shows a picture behind the title screen. Drag one of the story's backgrounds onto it.

## 4. Export it for the web

A web build plays in any modern browser, on computers and tablets, with nothing to install.

1. Make the story's scene the one that starts: **Project > Project Settings > Application > Run > Main Scene**, then choose the story's `main.tscn`.
2. Install Godot's export templates once: **Editor > Manage Export Templates > Download and Install**.
3. Open **Project > Export**, click **Add...**, and choose **Web**.
4. Turn off **Thread Support** under Variant. The game then runs on itch.io and on ordinary web hosts without special server settings.
5. Click **Export Project**, choose an empty folder, name the file `index.html`, and untick **Export With Debug**.

The folder now holds `index.html` and the files it needs. A web build doesn't run by double-clicking `index.html`; it has to come from a web server. To try it first, click the **Remote Deploy** button at the top right of the editor (it appears once a Web preset exists) and choose **Run in Browser**.

## 5. Put it online

**itch.io.** Zip the export folder's files (not the folder itself), make a new project on itch.io, set **Kind of project** to **HTML**, upload the zip, and tick **This file will be played in the browser**. Set the viewport to the game's size, 1152 by 648 unless you changed **Project Settings > Display > Window**. Choose who can see the page: **Draft** or **Restricted** lets you share a private link with families first.

**A class or school website.** Upload the export folder's files to the site and link to its `index.html`. Ask your web administrator if you are unsure where files go.

**Other builds.** The same Export dialog makes a Windows, macOS, Linux, or Android build that families can download instead.

## More than one story in a project

A project can hold many students' stories, each in its own folder under `res://studio_stories/`. Each folder's `main.tscn` plays that story with its own settings and saves. To export a different story, change the main scene (step 4.1) and export again to a new folder.

## Troubleshooting

- **"That file is not a story from the Studio."** The file isn't a Studio story file. Ask the student to tap **Share** again and send the `.zip` it saves.
- **A picture or sound is missing when the story plays.** Wait until Godot finishes importing (the progress bar at the bottom right), then play again.
- **The web page stays black or shows an error about threads.** Check that **Thread Support** is off (step 4.4) and that the page comes from a web server, not straight from the folder.
