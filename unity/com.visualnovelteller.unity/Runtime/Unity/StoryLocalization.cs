using System;
using System.Collections.Generic;
using System.Globalization;
using TaleScript;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// The reader's language and the translations in the Story Config's strings file
    /// (decision 0011). The file is the same CSV the Godot plugin writes: lines and choice options
    /// keyed "tale:line-id", and names, titles, and menu text keyed by their source text.
    /// <see cref="Story"/> makes one and translates tales with it; the menus and dialogue box
    /// translate their own text with <see cref="T"/>. Write the file with
    /// Assets > Visual Novel Teller > Export Strings.
    /// </summary>
    public class StoryLocalization
    {
        /// <summary>
        /// The text the menus, dialogue box, and purchase screen show, so Export Strings can list it
        /// for translators. A slot name is written "Slot {0}".
        /// </summary>
        public static readonly string[] UiText =
        {
            "New Game", "Continue", "Load", "Save", "Settings", "Quit", "Paused", "Resume", "History",
            "Title", "Back", "Yes", "No", "OK", "Close", "Defaults", "Delete", "Empty", "Nothing yet.",
            "Return to the title? Unsaved progress is lost.", "Quit the game? Unsaved progress is lost.",
            "Overwrite {0}?", "Delete {0}?", "Quick save", "Autosave", "Slot {0}", "the quick save",
            "the autosave", "slot {0}", "Text speed", "Instant", "Auto delay", "Skip unread lines",
            "Master volume", "Music volume", "Sound volume", "Voice volume", "Replay voice", "Full screen", "Language", "Skip", "Auto",
            "Buy", "Not now", "Restore purchases", "Purchases restored", "Locked: {0}",
            "Your purchase is waiting for the store to confirm it.",
            "The purchase didn't go through. Please try again.",
        };

        private readonly TaleStrings _table;
        private string _language;

        /// <summary>Raised when the reader's language changes. Menus rebuild their text.</summary>
        public event Action LanguageChanged;

        /// <summary>Reads the strings file of a config. A config without one gives a story in its source language only.</summary>
        public StoryLocalization(StoryConfig config)
        {
            SourceLanguage = config != null && !string.IsNullOrEmpty(config.SourceLanguage) ? config.SourceLanguage : "en";
            string csv = config != null && config.TranslationFile != null ? config.TranslationFile.text : "";
            _table = TaleStrings.Parse(csv);
            _language = SourceLanguage;
        }

        /// <summary>The language the tales are written in, such as "en".</summary>
        public string SourceLanguage { get; private set; }

        /// <summary>The languages the reader can choose: the source language, then each language column of the strings file.</summary>
        public List<string> Languages
        {
            get
            {
                var languages = new List<string> { SourceLanguage };
                foreach (string language in _table.Languages)
                    if (!languages.Contains(language)) languages.Add(language);
                return languages;
            }
        }

        /// <summary>The reader's language. Setting one the strings file doesn't have keeps the current one.</summary>
        public string Language
        {
            get { return _language; }
            set
            {
                if (string.IsNullOrEmpty(value) || value == _language || !Languages.Contains(value)) return;
                _language = value;
                if (LanguageChanged != null) LanguageChanged();
            }
        }

        /// <summary>True while the reader reads the language the tales are written in.</summary>
        public bool IsSourceLanguage { get { return _language == SourceLanguage; } }

        /// <summary>
        /// The translation of a key in the reader's language, or the key when there is none. In the
        /// source language every key comes back as it is, so tales show their own text.
        /// <see cref="Story"/> gives this to the director.
        /// </summary>
        public string Translate(string key)
        {
            if (IsSourceLanguage || string.IsNullOrEmpty(key)) return key;
            return _table.Translate(key, _language);
        }

        /// <summary>Translates interface text, such as a button label. Arguments fill {0}, {1}, ... after translating.</summary>
        public string T(string text, params object[] args)
        {
            string translated = Translate(text) ?? "";
            return args != null && args.Length > 0 ? string.Format(CultureInfo.InvariantCulture, translated, args) : translated;
        }

        /// <summary>
        /// The language to start in: a saved choice when the strings file has it, otherwise the
        /// system's language when the file has it, otherwise the source language.
        /// </summary>
        public string PickLanguage(string saved)
        {
            List<string> languages = Languages;
            if (!string.IsNullOrEmpty(saved) && languages.Contains(saved)) return saved;
            string system = SystemLanguageCode();
            if (languages.Contains(system)) return system;
            return SourceLanguage;
        }

        /// <summary>A language's own name for showing in the settings, such as "Español" for "es", or the code when it isn't known.</summary>
        public static string LanguageName(string code)
        {
            try
            {
                CultureInfo culture = CultureInfo.GetCultureInfo(code);
                string name = culture.NativeName;
                if (string.IsNullOrEmpty(name) || culture.Name.Length == 0) return code;
                return char.ToUpper(name[0], culture) + name.Substring(1);
            }
            catch (CultureNotFoundException)
            {
                return code;
            }
        }

        /// <summary>The two-letter code of the system's language, such as "es".</summary>
        public static string SystemLanguageCode()
        {
            switch (Application.systemLanguage)
            {
                case SystemLanguage.English: return "en";
                case SystemLanguage.Spanish: return "es";
                case SystemLanguage.French: return "fr";
                case SystemLanguage.German: return "de";
                case SystemLanguage.Italian: return "it";
                case SystemLanguage.Portuguese: return "pt";
                case SystemLanguage.Japanese: return "ja";
                case SystemLanguage.Korean: return "ko";
                case SystemLanguage.ChineseSimplified: return "zh_CN";
                case SystemLanguage.ChineseTraditional: return "zh_TW";
                case SystemLanguage.Chinese: return "zh";
                case SystemLanguage.Russian: return "ru";
                case SystemLanguage.Polish: return "pl";
                case SystemLanguage.Dutch: return "nl";
                case SystemLanguage.Turkish: return "tr";
                case SystemLanguage.Arabic: return "ar";
                case SystemLanguage.Ukrainian: return "uk";
                case SystemLanguage.Vietnamese: return "vi";
                case SystemLanguage.Indonesian: return "id";
                case SystemLanguage.Thai: return "th";
            }
            return CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
        }
    }
}
