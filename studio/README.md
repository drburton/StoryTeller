# Visual Novel StoryTeller Studio

The block-based story builder for kids (decisions 0020 and 0021, design in `docs/studio-design.md`). The Studio is built from this Godot project: exports with the `studio` feature tag start in this folder instead of the plugin's demo (see the `.studio` overrides in `project.godot`).

## What is here now

`check/` holds the **tablet check**, the first step of milestone M8 (S0). It is a small app with one panel for each risk in `docs/studio-design.md` §10: starting up, dragging blocks, typing, photos and sharing, saving, sound, and the stage. A tester runs it on a real tablet, taps **Works** or **Problem** on each panel, and sends the results summary back.

## Building

```bash
GODOT_BIN=/path/to/godot tools/build_studio.sh linux build/studio.x86_64   # desktop, for trying it out
GODOT_BIN=/path/to/godot tools/build_studio.sh android build/studio.apk    # needs the Android SDK
```

GitHub Actions builds the Android app on every change to the Studio (`.github/workflows/studio.yml`). The iOS build is added once the Apple developer account exists.

## Trying the tablet check on an Android tablet

1. Open the repository's **Actions** tab, choose the latest **Studio** run, and download **studio-tablet-check-android** from its Summary page. Unzip it to get `studio-tablet-check.apk`.
2. Copy the `.apk` to the tablet (email, Google Drive, or a USB cable) and open it there. Android asks to allow installing apps from that source; allow it for this install.
3. Open **Studio Tablet Check**, work through the seven panels, then tap **Show results to send** and paste the results into a message.
