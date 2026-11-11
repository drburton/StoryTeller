using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

namespace TaleScript.Tests
{
    /// <summary>
    /// Tests for the strings CSV (decision 0011) in C#: reading and writing it as the Godot
    /// plugin does, collecting a tale's strings with the same keys, and translated lines.
    /// </summary>
    internal static class LocalizationTests
    {
        public static IEnumerable<KeyValuePair<string, Action>> All()
        {
            yield return Test("strings CSV round trips quotes, commas, and line breaks", RoundTrip);
            yield return Test("writing again keeps translations and marks old keys", Merge);
            yield return Test("the Godot demo's CSV reads in C#", ReadsGodotCsv);
            yield return Test("C# keys every demo line as the Godot plugin did", SameKeysAsGodot);
            yield return Test("collect finds titles, headings, lines, options, names, and tr()", CollectsStrings);
            yield return Test("lines and options play translated, with interpolation", TranslatedLines);
            yield return Test("a broken translation is reported and the original shown", BrokenTranslation);
        }

        private static KeyValuePair<string, Action> Test(string name, Action body)
        {
            return new KeyValuePair<string, Action>(name, body);
        }

        private static string RepoFile(string relative)
        {
            string folder = AppContext.BaseDirectory;
            while (!string.IsNullOrEmpty(folder))
            {
                string path = Path.Combine(folder, relative);
                if (File.Exists(path)) return path;
                folder = Path.GetDirectoryName(folder);
            }
            throw new TestFailure("could not find " + relative + " above " + AppContext.BaseDirectory);
        }

        private static void RoundTrip()
        {
            var entries = new List<TaleStringEntry>
            {
                new TaleStringEntry { Key = "main:a", Text = "Hello, \"friend\".", Context = "main.tale:2 (ada)" },
                new TaleStringEntry { Key = "main:b", Text = "Two\nlines", Context = "main.tale:3" },
                new TaleStringEntry { Key = "Plain", Text = "Plain", Context = "menu" },
            };
            string csv = TaleStrings.Write("", entries, "en", new[] { "es" });
            string firstLine = csv.Substring(0, csv.IndexOf('\n'));
            Check.Equal("keys,en,es,_context,_status", firstLine, "header");
            TaleStrings table = TaleStrings.Parse(csv);
            Check.Lines(new[] { "en", "es" }, table.Languages, "languages");
            Check.Lines(new[] { "main:a", "main:b", "Plain" }, table.Order, "keys");
            Check.Equal("Hello, \"friend\".", table.Rows["main:a"]["en"], "quotes and commas");
            Check.Equal("Two\nlines", table.Rows["main:b"]["en"], "line breaks");
            Check.Equal("main:a", table.Translate("main:a", "es"), "no translation gives the key back");
        }

        private static void Merge()
        {
            // A file a translator has filled in.
            string translated = "keys,en,es,_context,_status\nmain:a,Hello.,Hola.,c,\nmain:b,Bye.,Adiós.,c,\nmain:c,Same.,,c,\n";
            var second = new List<TaleStringEntry>
            {
                new TaleStringEntry { Key = "main:a", Text = "Hello there.", Context = "c" },
                new TaleStringEntry { Key = "main:c", Text = "Same.", Context = "c" },
                new TaleStringEntry { Key = "main:d", Text = "New.", Context = "c" },
            };
            TaleStrings merged = TaleStrings.Parse(TaleStrings.Write(translated, second, "en", null));
            Check.Lines(new[] { "en", "es" }, merged.Languages, "languages kept");
            Check.Lines(new[] { "main:a", "main:c", "main:d", "main:b" }, merged.Order, "kept and added keys");
            Check.Equal("Hola.", merged.Rows["main:a"]["es"], "translation kept");
            Check.Equal(TaleStrings.StatusChanged, merged.Rows["main:a"][TaleStrings.StatusColumn], "source changed");
            Check.Equal("", merged.Rows["main:c"][TaleStrings.StatusColumn], "unchanged");
            Check.Equal(TaleStrings.StatusUnused, merged.Rows["main:b"][TaleStrings.StatusColumn], "no longer used");
            Check.Equal("Adiós.", merged.Rows["main:b"]["es"], "an unused key keeps its translation");
            Check.Equal("Hola.", merged.Translate("main:a", "es"), "Translate");
        }

        private static void ReadsGodotCsv()
        {
            TaleStrings table = TaleStrings.Parse(File.ReadAllText(RepoFile("demo/translations/demo.csv")));
            Check.True(table.Languages.Contains("en") && table.Languages.Contains("es"), "en and es columns");
            Check.True(table.Order.Count > 100, "many keys, got " + table.Order.Count);
            Check.Equal("Opciones", table.Translate("Choices", "es"), "a menu string");
            Check.Equal("Comprar", table.Translate("Buy", "es"), "a purchase screen string");
        }

        private static void SameKeysAsGodot()
        {
            TaleStrings table = TaleStrings.Parse(File.ReadAllText(RepoFile("demo/translations/demo.csv")));
            string folder = Path.GetDirectoryName(RepoFile("demo/tales/prologue.tale"));
            var tales = new List<Tale>();
            foreach (string path in Directory.GetFiles(folder, "*.tale"))
            {
                string name = Path.GetFileNameWithoutExtension(path);
                TaleDocument doc = TaleParser.Parse(File.ReadAllText(path), path);
                tales.Add(TaleCompiler.Compile(doc, name));
            }
            int lines = 0;
            foreach (var entry in TaleStrings.Collect(tales))
            {
                if (!entry.Key.Contains(":") || entry.Key.Contains(" ")) continue;
                lines++;
                if (!table.Rows.ContainsKey(entry.Key))
                    throw new TestFailure("key " + entry.Key + " (" + entry.Context + ") is not in the Godot demo's CSV");
                Check.Equal(table.Rows[entry.Key]["en"], entry.Text, "source text of " + entry.Key);
            }
            Check.True(lines > 50, "many demo lines, got " + lines);
        }

        private const string Story =
            "@title(\"The Visit\")\nvar gold := 3\n\n@heading(\"Arrival\")\nbeat start:\n\tada: \"You have {gold} coins.\"\n\tada.display_name = \"???\"\n\t\"A {tr('quiet')} night.\"\n\tchoose:\n\t\t\"Stay\":\n\t\t\tpass\n\t\t\"Go\":\n\t\t\tpass\n";

        private static Tale Build(TaleDirector director, string name, string source)
        {
            TaleBuildResult built = TaleCompiler.Build(source, name, director.MakeCheckContext(name));
            if (built.Tale == null) throw new TestFailure("tale did not compile");
            return built.Tale;
        }

        private static void CollectsStrings()
        {
            var director = new TaleDirector();
            var context = director.MakeCheckContext("visit");
            context.AddCast("ada", new List<string>());
            TaleBuildResult built = TaleCompiler.Build(Story, "visit", context);
            if (built.Tale == null)
            {
                var problems = new List<string>();
                foreach (var problem in built.Diagnostics) problems.Add(problem.Line + ": " + problem.Message);
                throw new TestFailure("tale did not compile: " + string.Join("; ", problems));
            }
            var texts = new List<string>();
            foreach (var entry in TaleStrings.Collect(new[] { built.Tale }))
                texts.Add(entry.Key.StartsWith("visit:", StringComparison.Ordinal) ? "line:" + entry.Text : entry.Key);
            Check.Lines(new[] { "The Visit", "Arrival", "line:You have {gold} coins.", "???", "line:A {tr('quiet')} night.", "quiet", "line:Stay", "line:Go" }, texts);
        }

        private static void TranslatedLines()
        {
            var player = new Player();
            var director = new TaleDirector { Presenter = player };
            var tale = Build(director, "main", "var gold := 3\nbeat start:\n\t\"You have {gold} coins.\"\n\tchoose:\n\t\t\"Stay\":\n\t\t\t\"Untranslated.\"\n");
            director.AddTale(tale);
            var rows = new List<TaleStringEntry>();
            foreach (var entry in TaleStrings.Collect(new[] { tale })) rows.Add(entry);
            TaleStrings table = TaleStrings.Parse(TaleStrings.Write("", rows, "en", new[] { "es" }));
            table.Rows[rows[0].Key]["es"] = "Tienes {gold} monedas.";
            table.Rows[rows[1].Key]["es"] = "Quedarse";
            director.Translator = key => table.Translate(key, "es");
            Task play = director.Play("main");
            Check.True(play.IsCompleted, "story finished");
            Check.Lines(new[] { "Tienes 3 monedas.", "Untranslated." }, player.Lines, "translated line, then a line with no translation");
            Check.Lines(new[] { "Quedarse" }, player.Choices, "translated option");
        }

        private static void BrokenTranslation()
        {
            var player = new Player();
            var director = new TaleDirector { Presenter = player };
            var tale = Build(director, "main", "beat start:\n\t\"Hello.\"\n\t\"Hello.\"\n");
            director.AddTale(tale);
            var errors = new List<string>();
            director.RuntimeError += (message, taleName, line) => errors.Add(line + ": " + message);
            string key = TaleStrings.Collect(new[] { tale })[0].Key;
            director.Translator = k => k == key ? "Hola {" : k;
            director.Play("main");
            Check.Lines(new[] { "Hello.", "Hello." }, player.Lines, "the original is shown");
            Check.Equal(1, errors.Count, "reported once");
            Check.True(errors[0].StartsWith("2: The translation of this line has a problem", StringComparison.Ordinal), errors[0]);
        }
    }
}
