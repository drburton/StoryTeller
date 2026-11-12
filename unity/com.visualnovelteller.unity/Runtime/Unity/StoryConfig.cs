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

        [Header("Menus (needs a StoryMenus component)")]
        [Tooltip("Show the title screen when the scene starts instead of playing the first tale at once. New Game starts the story.")]
        [SerializeField] private bool showTitleScreen = false;
        [Tooltip("The game's name on the title screen. Empty uses the product name from Project Settings.")]
        [SerializeField] private string title = "";
        [Tooltip("Optional. A picture that fills the title screen.")]
        [SerializeField] private Sprite titleBackground;
        [Tooltip("Optional. The name of a clip in Audio Clips that plays on the title screen.")]
        [SerializeField] private string titleMusic = "";
        [Tooltip("Optional. Replaces the menu style sheet that comes with the package.")]
        [SerializeField] private StyleSheet menuStyle;
        [Header("Store (demos and purchases)")]
        [Tooltip("What readers can buy inside the game, such as the full story. Tales use the ids in owns(), offer(), and @needs.")]
        [SerializeField] private List<StoryProduct> products = new List<StoryProduct>();
        [Tooltip("Auto uses the test store in the editor and the platform's store in a build when Unity In-App Purchasing is installed.")]
        [SerializeField] private StoreMode store = StoreMode.Auto;
        [Header("Localization")]
        [Tooltip("The strings CSV with the translations, the same file the Godot plugin writes. Assets > Visual Novel Teller > Export Strings writes and updates it.")]
        [SerializeField] private TextAsset translationFile;
        [Tooltip("The language the tales are written in, such as en.")]
        [SerializeField] private string sourceLanguage = "en";
        [Tooltip("Languages to add as columns when exporting strings, such as es and fr.")]
        [SerializeField] private List<string> languages = new List<string>();
        [Header("Saves")]
        [Tooltip("How many lines and choices the player can step back through. 0 turns rewind off.")]
        [Min(0)] [SerializeField] private int rewindDepth = 50;
        [Header("Dialogue")]
        [Tooltip("Characters per second. 0 shows each line at once.")]
        [Range(0f, 200f)] [SerializeField] private float textSpeed = 40f;
        [Tooltip("Lets skip pass lines the player has not read yet. Off, skip stops at the first unread line.")]
        [SerializeField] private bool skipUnread = false;
        [Tooltip("Seconds auto mode waits after a line has finished typing. It adds 0.03 seconds for each visible character.")]
        [Range(0.2f, 5f)] [SerializeField] private float autoDelay = 1f;
        [Tooltip("How many shown lines the history screen keeps.")]
        [Range(10, 1000)] [SerializeField] private int historyLength = 200;
        [Tooltip("Makes the dialogue box and choices larger or smaller. 1 fits text for a 1920 by 1080 screen; raise it when text is hard to read.")]
        [Range(0.5f, 2f)] [SerializeField] private float uiScale = 1f;
        [Tooltip("Optional. Replaces the dialogue layout that comes with the package.")]
        [SerializeField] private VisualTreeAsset dialogueLayout;
        [Tooltip("Optional. Replaces the dialogue style sheet that comes with the package.")]
        [SerializeField] private StyleSheet dialogueStyle;
        [Tooltip("Optional. The theme for the UI panels. Without one, Unity's default runtime theme is used.")]
        [SerializeField] private ThemeStyleSheet themeStyleSheet;

        public IReadOnlyList<TaleAsset> Tales { get { return tales; } }
        public int RewindDepth { get { return Mathf.Max(rewindDepth, 0); } }
        public TaleAsset FirstTale { get { return firstTale; } }
        public string FirstBeat { get { return string.IsNullOrEmpty(firstBeat) ? "start" : firstBeat; } }
        public IReadOnlyList<CastMember> Cast { get { return cast; } }
        public IReadOnlyList<NamedSprite> Backdrops { get { return backdrops; } }
        public IReadOnlyList<NamedClip> AudioClips { get { return audioClips; } }
        public IReadOnlyList<string> ExposedNames { get { return exposedNames; } }
        /// <summary>The strings CSV with the translations, or null.</summary>
        public TextAsset TranslationFile { get { return translationFile; } set { translationFile = value; } }
        /// <summary>The language the tales are written in.</summary>
        public string SourceLanguage { get { return string.IsNullOrEmpty(sourceLanguage) ? "en" : sourceLanguage; } }
        /// <summary>Languages Export Strings adds as columns.</summary>
        public IReadOnlyList<string> Languages { get { return languages; } }
        /// <summary>What readers can buy inside the game.</summary>
        public IReadOnlyList<StoryProduct> Products { get { return products; } }
        /// <summary>Which store the game sells through.</summary>
        public StoreMode Store { get { return store; } }
        public float TextSpeed { get { return textSpeed; } }
        public bool SkipUnread { get { return skipUnread; } }
        public float AutoDelay { get { return Mathf.Clamp(autoDelay, 0.2f, 5f); } }
        public int HistoryLength { get { return Mathf.Clamp(historyLength, 10, 1000); } }
        public float UiScale { get { return Mathf.Clamp(uiScale, 0.5f, 2f); } }
        /// <summary>True when <see cref="StoryMenus"/> shows the title screen before the story starts.</summary>
        public bool ShowTitleScreen { get { return showTitleScreen; } }
        /// <summary>The game's name on the title screen, or "" to use the product name.</summary>
        public string Title { get { return title ?? ""; } }
        public Sprite TitleBackground { get { return titleBackground; } }
        /// <summary>The name of the title screen's music clip, or "".</summary>
        public string TitleMusic { get { return titleMusic ?? ""; } }
        public StyleSheet MenuStyle { get { return menuStyle; } }
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

        /// <summary>The product with this id, or null.</summary>
        public StoryProduct FindProduct(string id)
        {
            foreach (var product in products)
                if (product != null && product.id == id) return product;
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
            context.AddAssetCheck("offer", "id", delegate (string value)
            {
                return FindProduct(value) != null ? "" : "There is no product '" + value + "' in the Story Config.";
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
