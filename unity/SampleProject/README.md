# Visual Novel Teller sample project

A Unity 6.7 project that loads the package from `../com.visualnovelteller.unity`, so changes to the package show up here at once.

1. In Unity Hub, choose **Add > Add project from disk** and pick this folder. The first open takes a few minutes while Unity builds its Library folder and project settings.
2. Choose **Tools > Visual Novel Teller > Set Up Story in Scene**. It makes a Story Config with `Assets/Tales/hello.tale` and adds a Story to the open scene.
3. Press Play. Click, Space, or Enter moves on, and the buttons pick a choice.
4. **Window > Visual Novel Teller > Path Explorer** plays every path of a tale and lists its endings and problems.

Unity writes `Library`, `Temp`, `Logs`, and `UserSettings`, which `.gitignore` leaves out. Commit `Assets`, `Packages`, and `ProjectSettings`.

## Checking from the command line

On Windows, close the project in Unity, then from the repository folder run:

    .\tools\check_unity.ps1

It finds Unity 6.7 under Unity Hub, opens this project in batch mode, and runs `VisualNovelTeller.BatchCheck`: it compiles the package, lists each tale's problems, and plays every path of each tale. It prints the compile errors and the report, and exits with 1 when something fails. The full log goes to `unity/check_unity.log`. Pass `-Unity <path to Unity.exe>` when Unity lives somewhere else.
