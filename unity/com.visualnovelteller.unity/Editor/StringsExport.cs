using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using TaleScript;
using UnityEditor;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Assets > Visual Novel Teller > Export Strings: writes the selected Story Config's strings
    /// CSV for translators (decision 0011). It is the same file the Godot plugin writes:
    /// every line and choice option of the config's tales, tale titles and beat headings,
    /// <c>tr("...")</c> texts, cast names, product titles and descriptions, the game title, and
    /// the menu text. Exporting again keeps the translations, adds new strings, and marks those
    /// no longer used or whose source text changed.
    /// </summary>
    public static class StringsExport
    {
        private const string MenuPath = "Assets/Visual Novel Teller/Export Strings";

        [MenuItem(MenuPath, true)]
        private static bool CanExport()
        {
            return Selection.activeObject is StoryConfig;
        }

        [MenuItem(MenuPath, false, 20)]
        private static void ExportSelected()
        {
            var config = Selection.activeObject as StoryConfig;
            if (config == null) return;
            string path = Export(config);
            if (path != null)
            {
                Debug.Log("Visual Novel Teller: wrote the strings for translators to " + path + ".", config.TranslationFile);
                EditorGUIUtility.PingObject(config.TranslationFile);
            }
        }

        /// <summary>
        /// Writes the config's strings CSV: its translation file, or a new Translations/strings.csv
        /// next to the config, which then becomes its translation file. Returns the file's path, or
        /// null when a tale has errors.
        /// </summary>
        public static string Export(StoryConfig config)
        {
            var tales = new List<Tale>();
            foreach (var asset in config.Tales)
            {
                if (asset == null) continue;
                TaleBuildResult result = asset.Build(config.MakeCheckContext(asset.TaleName));
                if (result.Tale == null)
                {
                    Debug.LogError("Visual Novel Teller: " + asset.name + ".tale has errors; fix them before exporting strings.", asset);
                    return null;
                }
                tales.Add(result.Tale);
            }
            string path = config.TranslationFile != null ? AssetDatabase.GetAssetPath(config.TranslationFile) : DefaultPath(config);
            string existing = File.Exists(path) ? File.ReadAllText(path, Encoding.UTF8) : "";
            string csv = TaleStrings.Write(existing, Collect(config, tales), config.SourceLanguage, config.Languages);
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            File.WriteAllText(path, csv, new UTF8Encoding(false));
            AssetDatabase.ImportAsset(path);
            if (config.TranslationFile == null)
            {
                config.TranslationFile = AssetDatabase.LoadAssetAtPath<TextAsset>(path);
                EditorUtility.SetDirty(config);
                AssetDatabase.SaveAssets();
            }
            return path;
        }

        /// <summary>Every string of a config and its compiled tales, in the order the CSV lists them.</summary>
        public static List<TaleStringEntry> Collect(StoryConfig config, IEnumerable<Tale> tales)
        {
            List<TaleStringEntry> entries = TaleStrings.Collect(tales);
            foreach (var member in config.Cast)
            {
                if (member == null || string.IsNullOrEmpty(member.id)) continue;
                string name = string.IsNullOrEmpty(member.displayName) ? GdMethods.Capitalize(member.id) : member.displayName;
                TaleStrings.AddText(entries, name, "name of cast member '" + member.id + "'");
            }
            foreach (var product in config.Products)
            {
                if (product == null || string.IsNullOrEmpty(product.id)) continue;
                TaleStrings.AddText(entries, product.DisplayTitle, "title of product '" + product.id + "'");
                TaleStrings.AddText(entries, product.description, "description of product '" + product.id + "'");
            }
            TaleStrings.AddText(entries, config.Title, "game title");
            foreach (string text in StoryLocalization.UiText) TaleStrings.AddText(entries, text, "menu");
            return entries;
        }

        private static string DefaultPath(StoryConfig config)
        {
            string folder = Path.GetDirectoryName(AssetDatabase.GetAssetPath(config));
            if (string.IsNullOrEmpty(folder)) folder = "Assets";
            return Path.Combine(folder, "Translations", "strings.csv").Replace('\\', '/');
        }
    }
}
