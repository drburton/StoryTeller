# Visual Novel Teller sample project

A Unity 6.7 project that loads the package from `../com.visualnovelteller.unity`, so changes to the package show up here at once.

1. In Unity Hub, choose **Add > Add project from disk** and pick this folder. The first open takes a few minutes while Unity builds its Library folder and project settings.
2. Choose **Tools > Visual Novel Teller > Set Up Story in Scene**. It makes a Story Config with `Assets/Tales/hello.tale` and adds a Story to the open scene.
3. Press Play. Click, Space, or Enter moves on, and the buttons pick a choice.
4. **Window > Visual Novel Teller > Path Explorer** plays every path of a tale and lists its endings and problems.

Unity writes `Library`, `Temp`, `Logs`, and `UserSettings`, which `.gitignore` leaves out. Commit `Assets`, `Packages`, and `ProjectSettings`.
