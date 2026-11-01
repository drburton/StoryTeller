using System;
using System.Collections.Generic;
using TaleScript;
using UnityEngine;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>A name paired with a sprite, used for moods and backdrops.</summary>
    [Serializable]
    public class NamedSprite
    {
        public string name = "";
        public Sprite sprite;
    }

    /// <summary>A name paired with an audio clip, used for music and sounds.</summary>
    [Serializable]
    public class NamedClip
    {
        public string name = "";
        public AudioClip clip;
    }

    /// <summary>A character tales can use as a speaker and put on the 2D stage.</summary>
    [Serializable]
    public class CastMember
    {
        /// <summary>The name tales use, such as mira in <c>mira: Hello.</c></summary>
        public string id = "";
        /// <summary>The name shown in the dialogue box. Empty shows the id with a capital letter.</summary>
        public string displayName = "";
        /// <summary>Color of the name in the dialogue box.</summary>
        public Color color = Color.white;
        /// <summary>Sprites by mood name, such as smile or worried.</summary>
        public List<NamedSprite> moods = new List<NamedSprite>();
        /// <summary>Mood used when a tale enters the character without one. Empty uses the first mood.</summary>
        public string defaultMood = "";
        /// <summary>Size relative to the stage, where 1 is normal.</summary>
        public float scale = 1f;

        /// <summary>The sprite of a mood, or null.</summary>
        public Sprite FindMood(string moodName)
        {
            foreach (var mood in moods)
                if (mood.name == moodName) return mood.sprite;
            return null;
        }

        /// <summary>The mood names in order.</summary>
        public List<string> MoodNames()
        {
            var names = new List<string>();
            foreach (var mood in moods) names.Add(mood.name);
            return names;
        }
    }

    /// <summary>
    /// Project settings for Visual Novel Teller: which tales to load, the cast, the
    /// pictures and sounds tales can name, and the look of the dialogue box. Create one
    /// with Assets > Create > Visual Novel Teller > Story Config and give it to a
    /// <see cref="Story"/>. The importer also reads it to check .tale files.
    /// </summary>
    [CreateAssetMenu(fileName = "StoryConfig", menuName = "Visual Novel Teller/Story Config")]
    public class StoryConfig : ScriptableObject
    {
        [Header("Tales")]
        [SerializeField] private TaleAsset[] tales = new TaleAsset[0];
        [Tooltip("The tale that plays first.")]
        [SerializeField] private TaleAsset firstTale;
        [Tooltip("The beat where the first tale starts.")]
        [SerializeField] private string firstBeat = "start";

        [Header("Stage and sound")]
        [SerializeField] private List<CastMember> cast = new List<CastMember>();
        [SerializeField] private List<NamedSprite> backdrops = new List<NamedSprite>();
        [Tooltip("Music and sound effects, by the names tales use in music() and sound().")]
        [SerializeField] private List<NamedClip> audioClips = new List<NamedClip>();

        [Header("Game code")]
        [Tooltip("Names that game code adds with Story.Expose. Listing them lets tales that use them import without errors.")]
        [SerializeField] private List<string> exposedNames = new List<string>();

        [Header("Saves")]
        [Tooltip("How many lines and choices the player can step back through. 0 turns rewind off.")]
        [Min(0)] [SerializeField] private int rewindDepth = 50;
        [Header("Dialogue")]
        [Tooltip("Characters per second. 0 shows each line at once.")]
        [Range(0f, 200f)] [SerializeField] private float textSpeed = 40f;
        [Tooltip("Optional. Replaces the dialogue layout that comes with the package.")]
        [SerializeField] private VisualTreeAsset dialogueLayout;
        [Tooltip("Optional. Replaces the dialogue style sheet that comes with the package.")]
        [SerializeField] private StyleSheet dialogueStyle;
        [Tooltip("Optional. The theme for the UI panels. The default dialogue style looks right without one.")]
        [SerializeField] private ThemeStyleSheet themeStyleSheet;

        public IReadOnlyList<TaleAsset> Tales { get { return tales; } }
        public int RewindDepth { get { return Mathf.Max(rewindDepth, 0); } }
        public TaleAsset FirstTale { get { return firstTale; } }
        public string FirstBeat { get { return string.IsNullOrEmpty(firstBeat) ? "start" : firstBeat; } }
        public IReadOnlyList<CastMember> Cast { get { return cast; } }
        public IReadOnlyList<NamedSprite> Backdrops { get { return backdrops; } }
        public IReadOnlyList<NamedClip> AudioClips { get { return audioClips; } }
        public IReadOnlyList<string> ExposedNames { get { return exposedNames; } }
        public float TextSpeed { get { return textSpeed; } }
        public VisualTreeAsset DialogueLayout { get { return dialogueLayout; } }
        public StyleSheet DialogueStyle { get { return dialogueStyle; } }
        public ThemeStyleSheet ThemeStyleSheet { get { return themeStyleSheet; } }

        /// <summary>The cast member with this id, or null.</summary>
        public CastMember FindCast(string id)
        {
            foreach (var member in cast)
                if (member.id == id) return member;
            return null;
        }

        /// <summary>The backdrop sprite with this name, or null.</summary>
        public Sprite FindBackdrop(string backdropName)
        {
            foreach (var backdrop in backdrops)
                if (backdrop.name == backdropName) return backdrop.sprite;
            return null;
        }

        /// <summary>The audio clip with this name, or null.</summary>
        public AudioClip FindClip(string clipName)
        {
            foreach (var entry in audioClips)
                if (entry.name == clipName) return entry.clip;
            return null;
        }

        /// <summary>
        /// Builds what the checker needs to know about the project: the built-in actions,
        /// the cast and their moods, the exposed names, and the other tales in the list.
        /// </summary>
        public TaleCheckContext MakeCheckContext(string taleName = "")
        {
            var director = new TaleDirector();
            StoryActions.Register(director, null);
            TaleCheckContext context = director.MakeCheckContext(taleName);
            AddTo(context, taleName);
            return context;
        }

        /// <summary>Adds the cast, exposed names, asset checks, and other tales of this config to a context.</summary>
        public void AddTo(TaleCheckContext context, string taleName)
        {
            foreach (var member in cast)
                if (!string.IsNullOrEmpty(member.id)) context.AddCast(member.id, member.MoodNames());
            foreach (string exposed in exposedNames)
                if (!string.IsNullOrEmpty(exposed)) context.AddExposed(exposed);
            context.AddExposed("shots");
            foreach (var tale in tales)
            {
                if (tale == null || tale.TaleName == taleName || context.Tales.Has(tale.TaleName)) continue;
                context.AddTale(tale.TaleName, tale.Beats, tale.Variables);
            }
            if (backdrops.Count > 0)
                context.AddAssetCheck("backdrop", "name", delegate (string value)
                {
                    return FindBackdrop(value) != null ? "" : "Backdrop '" + value + "' is not in the Story Config.";
                });
            if (audioClips.Count > 0)
            {
                context.AddAssetCheck("music", "track", delegate (string value)
                {
                    return FindClip(value) != null ? "" : "Music '" + value + "' is not in the Story Config.";
                });
                context.AddAssetCheck("sound", "name", delegate (string value)
                {
                    return FindClip(value) != null ? "" : "Sound '" + value + "' is not in the Story Config.";
                });
            }
        }
    }
}
