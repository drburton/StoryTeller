using System;
using System.IO;
using System.Text;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// The player's preferences: text speed, auto delay, skipping unread lines, volumes, and
    /// full screen. They save as JSON to settings.json in the persistent data folder.
    /// <see cref="StoryMenus"/> loads them when the scene starts and shows them on its settings
    /// screen. Values the file does not hold keep the defaults of the Story Config.
    /// </summary>
    [Serializable]
    public class StorySettings
    {
        /// <summary>The highest text speed on the settings screen, in characters per second.</summary>
        public const float MaxTextSpeed = 120f;

        /// <summary>Characters per second. 0 shows each line at once.</summary>
        public float textSpeed = 40f;
        /// <summary>Seconds auto mode waits after a line has finished typing.</summary>
        public float autoDelay = 1f;
        /// <summary>Lets skip pass lines the player has not read yet.</summary>
        public bool skipUnread;
        /// <summary>Volume of everything, from 0 to 1. It sets AudioListener.volume.</summary>
        public float masterVolume = 1f;
        /// <summary>Volume of music, from 0 to 1.</summary>
        public float musicVolume = 1f;
        /// <summary>Volume of sound effects, from 0 to 1.</summary>
        public float soundVolume = 1f;
        /// <summary>Full screen on or off.</summary>
        public bool fullScreen;

        /// <summary>Where the settings are saved.</summary>
        public static string FilePath
        {
            get { return Path.Combine(Application.persistentDataPath, "settings.json"); }
        }

        /// <summary>The defaults: the Story Config's values, full volume, and the current screen mode.</summary>
        public static StorySettings Defaults(StoryConfig config)
        {
            var settings = new StorySettings();
            if (config != null)
            {
                settings.textSpeed = config.TextSpeed;
                settings.autoDelay = config.AutoDelay;
                settings.skipUnread = config.SkipUnread;
            }
            settings.fullScreen = Screen.fullScreen;
            return settings;
        }

        /// <summary>Reads settings.json over the defaults. A missing or broken file gives the defaults.</summary>
        public static StorySettings Load(StoryConfig config)
        {
            StorySettings settings = Defaults(config);
            try
            {
                if (File.Exists(FilePath)) JsonUtility.FromJsonOverwrite(File.ReadAllText(FilePath, Encoding.UTF8), settings);
            }
            catch (Exception e)
            {
                Debug.LogWarning("Visual Novel Teller: could not read " + FilePath + ". " + e.Message);
            }
            settings.Clamp();
            return settings;
        }

        /// <summary>Writes settings.json.</summary>
        public void Save()
        {
            try
            {
                Directory.CreateDirectory(Application.persistentDataPath);
                File.WriteAllText(FilePath, JsonUtility.ToJson(this, true), new UTF8Encoding(false));
            }
            catch (Exception e)
            {
                Debug.LogError("Visual Novel Teller: could not save " + FilePath + ". " + e.Message);
            }
        }

        /// <summary>Keeps every value in the range the settings screen allows.</summary>
        public void Clamp()
        {
            textSpeed = Mathf.Clamp(textSpeed, 0f, MaxTextSpeed);
            autoDelay = Mathf.Clamp(autoDelay, 0.2f, 5f);
            masterVolume = Mathf.Clamp01(masterVolume);
            musicVolume = Mathf.Clamp01(musicVolume);
            soundVolume = Mathf.Clamp01(soundVolume);
        }

        /// <summary>Puts the values to work on the story's dialogue and audio, and on the screen.</summary>
        public void Apply(Story story)
        {
            if (story != null)
            {
                if (story.Dialogue != null)
                {
                    story.Dialogue.TextSpeed = textSpeed;
                    story.Dialogue.AutoDelay = autoDelay;
                    story.Dialogue.SkipUnread = skipUnread;
                }
                if (story.Audio != null)
                {
                    story.Audio.MusicVolume = musicVolume;
                    story.Audio.SoundVolume = soundVolume;
                }
            }
            AudioListener.volume = masterVolume;
            if (Screen.fullScreen != fullScreen) Screen.fullScreen = fullScreen;
        }
    }
}
