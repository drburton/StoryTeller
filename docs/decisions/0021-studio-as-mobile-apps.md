# 0021. The Studio ships as apps for iOS and Android

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

Decision 0020 planned Visual Novel StoryTeller Studio as a web page that students open in Safari on an iPad. The maintainer plans for students to download it instead, as an app for iOS (iPads first) and Android (tablets first). A web page on an iPad also has real limits: Safari may delete a site's storage after seven days without a visit, picking photos and typing go through the browser, and the first load is a large download on school Wi-Fi.

## Decision

- The Studio ships as a free app on the App Store (iPadOS and iOS) and Google Play (Android), built from the same Godot project with Godot's iOS and Android exports. Tablets come first; phones follow if the layout works there.
- Stories live in the app's own storage, which the system keeps until the app is removed.
- Students share a story as a `.zip` through the system share sheet (AirDrop, Files, Google Drive, Classroom) and open one from Files.
- Photos and files come from the system's own pickers.
- The project's public website, at a Visual Novel StoryTeller domain, links to both stores and hosts the guides. A web or desktop version may follow later.
- GitHub Actions builds both apps: Android on Linux and iOS on a macOS runner, signed with the maintainer's developer accounts and uploaded to TestFlight and Google Play's testing track.
- This replaces decision 0020's GitHub Pages hosting and browser storage; the rest of 0020 stands.

## Alternatives considered

- **Web page only (decision 0020):** nothing to install, but storage can be cleared, and photo picking and typing are weaker on an iPad.
- **Both a web page and apps from the start:** more reach, but twice the testing before the first release. A web version can follow later.

## Consequences

- The maintainer needs an Apple Developer Program membership and a Google Play Console account, and the store listings need privacy details. StoryTeller collects nothing, which fits Apple's Kids category and Google Play's Families policy.
- iOS builds need macOS; they run on GitHub's macOS runners, so no Mac is needed day to day.
- App stores offer only the newest version, so each major version of the Studio that a textbook edition depends on ships as its own app listing, or stays unchanged for the life of that edition.
- The feasibility check (M8, S0) tests a real app on an iPad and an Android tablet.
- The classroom test is no longer part of M8; it comes later, once the Studio works.
