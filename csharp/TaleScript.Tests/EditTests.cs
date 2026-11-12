using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace TaleScript.Tests
{
    /// <summary>
    /// Tests for TaleEdits, the Story Map's line-level edits: the results must match the Godot
    /// plugin's TaleEdit (Data/tale_edits.json holds its output for each case).
    /// </summary>
    internal static class EditTests
    {
        public static IEnumerable<KeyValuePair<string, Action>> All()
        {
            yield return Test("edits match the Godot plugin's TaleEdit", MatchGodot);
            yield return Test("new beat names don't clash", NewBeatNames);
            yield return Test("jump targets are short within a tale", JumpTargets);
        }

        private static KeyValuePair<string, Action> Test(string name, Action body)
        {
            return new KeyValuePair<string, Action>(name, body);
        }

        private static string DataFile(string name)
        {
            string folder = AppContext.BaseDirectory;
            while (!string.IsNullOrEmpty(folder))
            {
                string path = Path.Combine(folder, "csharp", "TaleScript.Tests", "Data", name);
                if (File.Exists(path)) return path;
                path = Path.Combine(folder, "Data", name);
                if (File.Exists(path)) return path;
                folder = Path.GetDirectoryName(folder);
            }
            throw new TestFailure("could not find Data/" + name);
        }

        private static void MatchGodot()
        {
            using (var json = JsonDocument.Parse(File.ReadAllText(DataFile("tale_edits.json"))))
            {
                int count = 0;
                foreach (var item in json.RootElement.GetProperty("cases").EnumerateArray())
                {
                    string name = item.GetProperty("name").GetString();
                    string source = item.GetProperty("source").GetString();
                    TaleDocument doc = TaleParser.Parse(source);
                    string appended = TaleEdits.AppendTo(source, doc, doc.FindBeat(item.GetProperty("beat").GetString()), "jump new_beat");
                    Check.Equal(item.GetProperty("appended").GetString(), appended, name + ": appended");
                    string added = TaleEdits.AddBeat(appended, TaleParser.Parse(appended), "new_beat");
                    Check.Equal(item.GetProperty("added").GetString(), added, name + ": added");
                    count++;
                }
                Check.True(count >= 7, "cases found");
            }
        }

        private static void NewBeatNames()
        {
            Check.Equal("new_beat", TaleEdits.NewBeatName(TaleParser.Parse("beat start:\n\tpass\n")));
            Check.Equal("new_beat_3", TaleEdits.NewBeatName(TaleParser.Parse("beat new_beat:\n\tpass\n\nbeat new_beat_2:\n\tpass\n")));
        }

        private static void JumpTargets()
        {
            Check.Equal("left", TaleEdits.JumpTarget("main.left", "main"));
            Check.Equal("side.away", TaleEdits.JumpTarget("side.away", "main"));
        }
    }
}
