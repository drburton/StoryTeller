# The visual editor

The **Story** tab edits `.tale` files in three views: **Text**, **Cards**, and **Map**. All three work on the same file. A card edit changes only the lines of that card, so your comments, blank lines, and formatting stay as they were. You can switch views at any time.

This guide covers the toolbar, the Cards view, building a branching scene with cards, the Map, undo, and the Import Yarn and Export Strings buttons. If you have not set up a project yet, start with [Getting started](getting-started.md).

Contents:

- [The Story tab](#the-story-tab)
- [Cards view](#cards-view)
- [Build a branching scene with cards](#build-a-branching-scene-with-cards)
- [Choice lanes](#choice-lanes)
- [Condition lanes](#condition-lanes)
- [Action forms](#action-forms)
- [Story Map](#story-map)
- [Undo](#undo)
- [Import Yarn](#import-yarn)
- [Export Strings](#export-strings)

## The Story tab

The tale list on the left holds every `.tale` file in the project. Click one to open it. The toolbar along the top has these buttons:

| Button | What it does |
|---|---|
| **Refresh List** | Rescans the project for `.tale` files |
| **Export Strings** | Writes the translation CSV (see [Export Strings](#export-strings)) |
| **Import Yarn** | Converts a Yarn Spinner script into a tale (see [Import Yarn](#import-yarn)) |
| **Pin Line IDs** | Writes `@id("...")` in front of every line and choice of the open tale that has none (see [Export Strings](#export-strings)) |
| **Text**, **Cards**, **Map** | Switch between the three views |
| **Save** | Saves the open tale and reimports it. Enabled while there are unsaved changes |

The title at the left of the toolbar shows the open file, with "(unsaved)" after it while it has changes. An asterisk marks unsaved tales in the list. Switching tales keeps unsaved edits in memory.

Problems appear in a list at the bottom, with the line number. In the Text view, lines with errors are tinted red and warnings yellow. In the Text view, click a problem to jump to its line. The list reads "No problems found." when the tale is clean.

The **Text** view is a TaleScript editor with highlighting. It suggests actions, characters, moods, beats, and variables as you type. Press **Ctrl+S** in the Text view to save. In the other views, click **Save**.

While the game runs from the editor, saving a tale reloads it in the running game and continues at the same line.

## Cards view

Click **Cards**. The left column lists the beats of the open tale under the label **Beats**. Click one to show its cards on the right.

Beat buttons under the list:

- **+ Beat** adds a beat named `new_beat` (or `new_beat_2`, and so on) at the end of the file and selects it. The new beat has no cards yet.
- **Delete Beat** removes the selected beat, including its cards.

To rename a beat, edit the name field next to the word "beat" above the cards, then press Enter or click away. The name must be a valid identifier (letters, digits, and underscores, not starting with a digit) and must not match another beat in the tale. A name that does not qualify is ignored. Jumps that point to the old name are not renamed, so check the problem list afterwards.

Each statement of the beat appears as one card:

| Card | Made from |
|---|---|
| **Narration** | A line of text in quotes |
| **Dialogue** | `speaker: "text"`, with a speaker list and a mood list |
| **Action** | A call such as `backdrop("library")` or `mira.enter("smile")` |
| **Run beat** | A call to another beat, `hallway()` |
| **Jump** | `jump hallway` |
| **Set variable** | `trust += 1` |
| **Choice** | A `choose:` block, with a lane per option |
| **Condition** | An `if` chain, with a lane per branch |
| **Comment** | A `#` comment line |
| **Script** | Anything else: loops, `match`, one-line `if`, and local `var` lines. The card holds the raw text |

A card whose line has a problem gets a red border (errors) or a yellow one (warnings). Hover over it to read the message. If the whole tale has a syntax error, a banner at the top of the cards says so, and the cards may be incomplete until you fix the error in the Text view.

### Working with cards

- Every card has a header with its kind, the buttons **▲** and **▼** (move up and down), **+** (add a card below this one), **⧉** (copy), and **✕** (delete).
- **+ Add card** at the end of a beat or lane opens the menu: Narration, Dialogue, Choice, Condition, Jump, Run beat, Set variable, Comment, Script, and an **Action** submenu that lists every built-in action.
- **⧉** copies a card, with any cards nested inside it. Choose **Paste** at the bottom of a **+** or **+ Add card** menu to put the copy there, in the same tale or another one. Paste also takes TaleScript lines you copied from the Text view, and it is greyed out when the clipboard holds something else.
- Choice and Condition cards have a **▾** at the left of the header that folds their lanes away and shows a one-line summary, such as `2 options: "Wave", "Leave"`. **▸** opens them again. Folding is kept while you edit and switch beats.
- While you edit a field, **Alt+Up** and **Alt+Down** move its card, and **Alt+Insert** adds a Narration card below it and puts the cursor there. Tab moves between fields.
- Drag a card by its header to reorder it, or to move it into another lane or beat block. Drop it on another card to place it before that card, or on **+ Add card** to place it at the end.
- Text fields apply their change when you press Enter or move to another field. Narration and dialogue text boxes apply when you click away.
- A Dialogue card's speaker and mood lists show a small picture of the character in each mood, taken from the top of their sprite. Characters drawn by a scene (`SceneLook`) have no picture. The **▾** lists on Action cards show pictures of backdrops, CGs, props, and moods, and a picture choice's option lists its pictures the same way.
- Narration and dialogue cards have a row of markup buttons above the text. Select some words and click **B** (bold), **I** (italic), **Slow** or **Fast** (typing speed), or pick one of the project's text styles from **Style**. **Pause** makes the line wait for a click at the cursor, **Wait** waits half a second, and **Sound** plays a sound when typing reaches the cursor. With nothing selected, the tags go in at the cursor and you type between them.
- New cards start with placeholder content: a Dialogue card takes the first character of the cast and the text "New line.", a Choice card has two options, and a Condition card starts as `if true:`. Edit them in place.
- The Action submenu lists the built-in actions. Calls on a character, such as `mira.enter("smile")`, have no menu entry. Add a **Script** card, type the call, and click away. The card turns into an Action card with fields.
- Top-level lines such as `var trust := 0` and `@title(...)` have no card. Edit them in the Text view.

## Build a branching scene with cards

This walkthrough builds a short scene with a choice and a condition. It uses characters from the demo project, so choose your own from the lists.

1. Open the **Text** view and add a variable at the very top of the tale: `var trust := 0`. Variables are declared at the top of a tale, and the Cards view has no card for that.
2. Click **Cards**, then **+ Beat**. Rename the new beat to `lost_key`.
3. Click **+ Add card**, open **Action**, and choose `backdrop`. In the form, click the **▾** next to `name` and pick a backdrop.
4. Add a **Narration** card and type the opening line.
5. Add a **Dialogue** card. Pick a speaker and a mood from the two lists, then type the line.
6. Add a **Choice** card. It starts with two lanes. Type the text of each option in its lane.
7. In the first lane, click **+ Add card** inside the lane and add a **Set variable** card. Pick `trust` from the **▾** list next to the variable field (it also lists other tales' variables and character fields such as `mira.friendship`), pick `+=`, and type `1` as the value. Then add a **Dialogue** card to the same lane for the reply.
8. In the second lane, add a **Dialogue** card for a different reply.
9. Under the choice, add a **Condition** card. Type `trust > 0` in the **If** field and add a Dialogue card in that lane. Click **+ Otherwise** and add a Dialogue card in the new lane.
10. Add a **Jump** card and pick a beat from its list. Create the target with **+ Beat** first if it does not exist yet.
11. Click **Save**.

The result in the Text view looks like this:

```gdscript
var trust := 0

beat lost_key:
	backdrop("library")
	"Mira is searching the shelves with a worried look."
	mira (curious): "Have you seen my key?"
	choose:
		"Help her look":
			trust += 1
			mira (smile): "Thank you!"
		"Say you're busy":
			mira (soft): "Oh. Okay."
	if trust > 0:
		mira: "I owe you one."
	else:
		mira: "I'll find it myself."
	jump ending

beat ending:
	"The bell rings."
```

## Choice lanes

A Choice card shows one lane per option. A lane has these controls:

| Control | Writes |
|---|---|
| Option text field | The option's text |
| **only if…** field | An `if` condition after the text, such as `"Ask about the key" if trust > 2:` |
| **Once** | `@once`, so the option disappears after it is picked |
| **Show when unavailable** | `@show_disabled`, so a false condition greys the option out instead of hiding it |
| **picture** field | `@picture("name")`, for the picture style (see below) |
| **✕** | Removes the option. Shown while the card has more than one lane |

Inside each lane, the cards below the header run when the player picks that option. They support everything a beat does, including nested choices.

**+ Option** adds another lane.

The picture field appears when the choice uses `style = "pictures"` or when any option already has a `@picture`. A Choice card has no field for the arguments in `choose(...)`. To switch the style or add a time limit, edit the `choose` line in the Text view:

```gdscript
beat start:
	choose(style = "pictures", timeout = 5.0):
		@picture("umbrella") "Share mine":
			mira (smile): "My hero."
		@picture("door") "Run for it":
			mira (smirk): "You first."
		timeout:
			mira: "Fine, I'll decide."
```

A `timeout:` branch shows as a lane labeled "When time runs out:". The cards inside it run when the timer expires.

## Condition lanes

A Condition card has an **If** lane. **+ Else if** adds another test, and **+ Otherwise** adds the final branch. The **Otherwise** button goes away once the card has one. Each branch has a condition field (except Otherwise) and its own cards. **✕** removes a branch, except the first.

Conditions are written as TaleScript expressions, for example `trust > 2 and not met_ada`. The [writers' cheat sheet](talescript-for-writers.md#conditions) lists the common forms.

## Action forms

An Action card shows the action's name and a form built from its arguments. Each field's gray placeholder text says "required" or shows the default.

- **Wait until it finishes** puts `await` in front of the call, so the story waits for the action to end.
- Fields for names of assets have a **▾** menu that lists what your project has: backdrops, music, sounds, props, CGs, characters' moods, transitions, and so on. Pick one or type your own.
- Text arguments are quoted for you. Start a value with `=` to write an expression instead, as in `=Vector2(0.3, 0)`.
- The `at` argument of `enter` and `move_to` offers `LEFT`, `CENTER`, and `RIGHT` in its **▾** menu. Number fields take the number as typed.
- Yes/no arguments are a list with `(default)`, `true`, and `false`.
- Color arguments have a **Set** box and a color picker. Leave **Set** off to use the default.
- A field left empty is left out of the line, so the action uses its default.

Calls the editor has no form for, such as actions that game code adds, show a single **arguments** field instead.

## Story Map

Click **Map** to see every beat of the tales in the open tale's folder. The map redraws each time you switch to it, and it includes unsaved edits.

Each beat shows as a box. The box lists the tale it belongs to, the number of statements in it, and one row per choice option with the beat it leads to. Arrows join beats that jump, call, or branch to each other. Colors tell the tales apart. Tales sit in horizontal bands, with your start tale first when the folder is your tales folder. The beats of a tale fan out in columns by the number of steps from the entry beats.

### Problem highlights

| Mark on the box | Meaning |
|---|---|
| Orange border and "⚠ Nothing leads here" | No jump, call, or choice reaches this beat from an entry point. Beats named `start` and the start beat of your start tale count as entry points |
| Red border and "⚠ Jumps to missing …" | A jump or call points to a beat that does not exist |
| "■ story can end here" | Play can run off the end of this beat, which ends the story or returns to a caller |

### Editing on the map

- **Double-click** a beat to open it. The Story tab switches to the Cards view with that beat selected.
- **Drag** from the dot on a beat's right edge onto another beat to add a jump. The editor appends `jump other_beat` as the last statement of the first beat. If that beat already ends in a jump, the checker reports the new one as unreachable, so delete the old one in the Cards view.
- **Drag to empty space** from the same dot to create a new beat there. The beat is named `new_beat` (or `new_beat_2`, and so on), lives in the same tale, and receives a jump from the beat you dragged from.
- **Move** a beat by dragging its title. The position is saved in a small `.tale.map` file next to the tale, so the tale itself stays clean. Commit the file if you want teammates to see your layout.

Map edits change the text of the tale like any other edit, so they appear in the Text and Cards views and can be undone. The Story tab opens the tale that was edited.

## Undo

The three views share the Text view's undo history. A card edit is one undo step, and so is a map edit.

- In the Text view, **Ctrl+Z** undoes and **Ctrl+Y** (or **Ctrl+Shift+Z**) redoes, as always.
- In the Cards view, the same shortcuts work when the cursor is not inside a card's text field. A card edit made there can also be undone from the Text view.
- Opening a different tale starts a new undo history for it.

## Import Yarn

Click **Import Yarn** and pick a `.yarn` file. StoryTeller converts it to a tale with the same name in the tales folder from your StoryConfig and opens the new tale. Each Yarn node becomes a beat.

If a tale with that name already exists, nothing is written, and a message says to rename or remove it first. Anything the converter could not translate stays in the tale as a `# Yarn:` comment and is listed in the Output panel. The [README](../../README.md#importing-yarn-spinner-scripts) lists what converts. The repository's `demo/yarn/lighthouse.yarn` is a small file to try.

## Export Strings

Click **Export Strings** to write every line, choice, name, and menu text to the translation CSV set in your StoryConfig (by default `res://story/translations/story.csv`). The button also registers the file in **Project Settings > Localization**.

The editor shows a message with the number of strings written, and prints it to the Output panel. A tale with errors is skipped, and the Output panel says which one. Export again whenever the tales change. Existing translations are kept, and the `_status` column flags lines whose text changed.

Before the first export, list the languages you want in the StoryConfig under **Localization > Languages**. The steps for translators are in the [README](../../README.md#translating) and in [section 7.3](../talescript-spec.md#73-translation) of the specification.

Before translators start, click **Pin Line IDs** with each tale open. A line's id comes from its text until it is pinned, so pinning keeps its translation attached when you fix a typo later. It adds one undoable edit to the tale and reports how many ids it wrote. A tale with syntax errors must be fixed first.
