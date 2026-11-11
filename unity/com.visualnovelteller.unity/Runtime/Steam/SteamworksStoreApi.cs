// Steamworks.NET leaves out its types when the build target isn't a desktop platform (or
// Android), even in the editor, so this file follows the same rule.
#if !(UNITY_STANDALONE_WIN || UNITY_STANDALONE_LINUX || UNITY_STANDALONE_OSX || UNITY_ANDROID || STEAMWORKS_WIN || STEAMWORKS_LIN_OSX)
#define DISABLESTEAMWORKS
#endif

#if !DISABLESTEAMWORKS
using System;
using Steamworks;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Connects <see cref="SteamStoreBackend"/> to Steam through Steamworks.NET. This assembly
    /// only compiles when the project has com.rlabrecque.steamworks.net, and then Steam is added
    /// as a platform store (<see cref="StoryStore.AddPlatformBackend"/>, priority 10) for Windows,
    /// macOS, and Linux builds. It is used when Steam starts, that is when the game runs through
    /// Steam (or has a steam_appid.txt while testing); otherwise the next store is tried.
    /// </summary>
    public class SteamworksStoreApi : ISteamStoreApi
    {
        /// <summary>
        /// When true (the default), this package starts Steam, runs its callbacks every frame,
        /// and shuts it down when the game quits. Set it to false before the story starts when
        /// the game has its own Steam manager that does this.
        /// </summary>
        public static bool ManageSteam = true;

        private static bool _started;
        private Callback<DlcInstalled_t> _dlcInstalled;
        private Callback<GameOverlayActivated_t> _overlay;

        public event Action<uint> DlcInstalled;
        public event Action<bool> OverlayActivated;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void Register()
        {
            StoryStore.AddPlatformBackend(MakeForPlatform, 10);
        }

        private static StoreBackend MakeForPlatform()
        {
            switch (Application.platform)
            {
                case RuntimePlatform.WindowsPlayer:
                case RuntimePlatform.OSXPlayer:
                case RuntimePlatform.LinuxPlayer:
                    break;
                default:
                    return null;
            }
            if (!StartSteam()) return null;
            return new SteamStoreBackend(new SteamworksStoreApi());
        }

        /// <summary>Starts Steam once. False when Steam isn't running or the game wasn't started through it.</summary>
        public static bool StartSteam()
        {
            if (_started || !ManageSteam) return true;
            string message;
            ESteamAPIInitResult result = SteamAPI.InitEx(out message);
            if (result != ESteamAPIInitResult.k_ESteamAPIInitResult_OK)
            {
                Debug.Log("StoryStore: Steam is not available (" + result + "). " + message);
                return false;
            }
            _started = true;
            var pump = new GameObject("Visual Novel Teller Steam");
            pump.hideFlags = HideFlags.HideAndDontSave;
            UnityEngine.Object.DontDestroyOnLoad(pump);
            pump.AddComponent<SteamCallbackPump>();
            return true;
        }

        public SteamworksStoreApi()
        {
            _dlcInstalled = Callback<DlcInstalled_t>.Create(OnDlcInstalled);
            _overlay = Callback<GameOverlayActivated_t>.Create(OnOverlay);
        }

        public bool OwnsDlc(uint appId)
        {
            var id = new AppId_t(appId);
            return SteamApps.BIsSubscribedApp(id) || SteamApps.BIsDlcInstalled(id);
        }

        public bool OverlayEnabled { get { return SteamUtils.IsOverlayEnabled(); } }

        public void OpenStoreOverlay(uint appId)
        {
            SteamFriends.ActivateGameOverlayToStore(new AppId_t(appId), EOverlayToStoreFlag.k_EOverlayToStoreFlag_AddToCartAndShow);
        }

        private void OnDlcInstalled(DlcInstalled_t data)
        {
            if (DlcInstalled != null) DlcInstalled(data.m_nAppID.m_AppId);
        }

        private void OnOverlay(GameOverlayActivated_t data)
        {
            if (OverlayActivated != null) OverlayActivated(data.m_bActive != 0);
        }

        /// <summary>Runs Steam's callbacks every frame and shuts Steam down when the game quits.</summary>
        private class SteamCallbackPump : MonoBehaviour
        {
            private void Update()
            {
                if (_started) SteamAPI.RunCallbacks();
            }

            private void OnApplicationQuit()
            {
                if (!_started) return;
                _started = false;
                SteamAPI.Shutdown();
            }
        }
    }
}
#endif
