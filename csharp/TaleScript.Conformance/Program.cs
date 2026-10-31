using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;

namespace TaleScript.Conformance
{
    public static class Program
    {
        public static int Main(string[] args)
        {
            string root = args.Length > 0 ? args[0] : FindConformanceDir();
            if (root == null || !Directory.Exists(root))
            {
                Console.Error.WriteLine("Conformance directory not found. Pass it as the first argument.");
                return 2;
            }

            int passed = 0;
            int failed = 0;
            var utf8 = new UTF8Encoding(false);

            string parseDir = Path.Combine(root, "parse");
            var cases = new List<string>();
            if (Directory.Exists(parseDir))
            {
                foreach (string file in Directory.GetFiles(parseDir, "*.tale"))
                    cases.Add(Path.GetFileNameWithoutExtension(file));
            }
            cases.Sort(StringComparer.Ordinal);

            foreach (string name in cases)
            {
                string talePath = Path.Combine(parseDir, name + ".tale");
                string expectedPath = Path.Combine(parseDir, name + ".expected.txt");
                string source = File.ReadAllText(talePath, utf8);
                string actual = TaleParser.Parse(source, talePath).Dump();
                if (!File.Exists(expectedPath))
                {
                    Console.WriteLine("FAIL  parse/" + name);
                    Console.WriteLine("      no expected file");
                    failed++;
                    continue;
                }
                string expected = File.ReadAllText(expectedPath, utf8);
                string roundTrip = TaleParser.Parse(source, talePath).ToSource();
                if (actual == expected && roundTrip == source)
                {
                    Console.WriteLine("ok    parse/" + name);
                    passed++;
                }
                else
                {
                    Console.WriteLine("FAIL  parse/" + name);
                    Console.WriteLine(actual == expected ? "      source does not print back unchanged" : FirstDifference(expected, actual));
                    failed++;
                }
            }

            string checkDir = Path.Combine(root, "check");
            var checkCases = new List<string>();
            if (Directory.Exists(checkDir))
            {
                foreach (string file in Directory.GetFiles(checkDir, "*.tale"))
                    checkCases.Add(Path.GetFileNameWithoutExtension(file));
            }
            checkCases.Sort(StringComparer.Ordinal);
            foreach (string name in checkCases)
            {
                string source = File.ReadAllText(Path.Combine(checkDir, name + ".tale"), utf8);
                string contextPath = Path.Combine(checkDir, name + ".context.json");
                JsonElement? settings = null;
                if (File.Exists(contextPath))
                {
                    var doc = JsonDocument.Parse(File.ReadAllText(contextPath, utf8));
                    if (doc.RootElement.ValueKind == JsonValueKind.Object) settings = doc.RootElement;
                }
                string actual = CheckCase(source, settings, name);
                string expectedPath = Path.Combine(checkDir, name + ".expected.txt");
                string expected = File.Exists(expectedPath) ? File.ReadAllText(expectedPath, utf8) : null;
                if (expected == actual)
                {
                    Console.WriteLine("ok    check/" + name);
                    passed++;
                }
                else
                {
                    Console.WriteLine("FAIL  check/" + name);
                    Console.WriteLine(expected == null ? "      no expected file" : FirstDifference(expected, actual));
                    failed++;
                }
            }

            string runDir = Path.Combine(root, "run");
            if (Directory.Exists(runDir))
            {
                Console.WriteLine("skip  run/ (not ported yet)");
                foreach (string file in Directory.GetFiles(runDir, "*.tale"))
                {
                    string source = File.ReadAllText(file, utf8);
                    if (TaleParser.Parse(source, file).ToSource() != source)
                    {
                        Console.WriteLine("FAIL  roundtrip/run/" + Path.GetFileNameWithoutExtension(file));
                        failed++;
                    }
                }
            }

            Console.WriteLine(passed + " passed, " + failed + " failed");
            return failed > 0 ? 1 : 0;
        }

        private static List<string> Strings(JsonElement element)
        {
            var list = new List<string>();
            if (element.ValueKind == JsonValueKind.Array)
                foreach (var item in element.EnumerateArray()) list.Add(item.GetString());
            return list;
        }

        private static bool TryGet(JsonElement? settings, string key, out JsonElement value)
        {
            value = default(JsonElement);
            return settings.HasValue && settings.Value.TryGetProperty(key, out value);
        }

        private static TaleCheckContext ContextFor(JsonElement? settings, string taleName)
        {
            var context = new TaleCheckContext();
            JsonElement value;
            context.TaleName = TryGet(settings, "tale_name", out value) ? value.GetString() : taleName;
            if (TryGet(settings, "actions", out value))
            {
                foreach (var action in value.EnumerateObject())
                {
                    JsonElement p, r;
                    var parameters = action.Value.TryGetProperty("params", out p) ? Strings(p) : new List<string>();
                    int required = action.Value.TryGetProperty("required", out r) ? r.GetInt32() : 0;
                    context.AddAction(action.Name, parameters, required);
                }
            }
            if (TryGet(settings, "actions_unchecked", out value))
                foreach (string action in Strings(value)) context.AddActionUnchecked(action);
            if (TryGet(settings, "cast", out value))
            {
                foreach (var entry in value.EnumerateObject())
                {
                    if (entry.Value.ValueKind == JsonValueKind.Object)
                    {
                        JsonElement m, f;
                        context.AddCast(entry.Name,
                            entry.Value.TryGetProperty("moods", out m) ? Strings(m) : null,
                            entry.Value.TryGetProperty("fields", out f) ? Strings(f) : null);
                    }
                    else
                    {
                        context.AddCast(entry.Name, Strings(entry.Value));
                    }
                }
            }
            if (TryGet(settings, "exposed", out value))
                foreach (string name in Strings(value)) context.AddExposed(name);
            if (TryGet(settings, "tales", out value))
            {
                foreach (var other in value.EnumerateObject())
                {
                    JsonElement b, v;
                    context.AddTale(other.Name,
                        other.Value.TryGetProperty("beats", out b) ? Strings(b) : new List<string>(),
                        other.Value.TryGetProperty("vars", out v) ? Strings(v) : new List<string>());
                }
            }
            return context;
        }

        private static string CheckCase(string source, JsonElement? settings, string taleName)
        {
            var doc = TaleParser.Parse(source);
            var lines = new List<string>();
            foreach (var d in doc.Diagnostics)
                lines.Add(d.Line + ": parse: " + d.Message);
            foreach (var d in TaleChecker.Check(doc, ContextFor(settings, taleName)))
                lines.Add(d.Line + ": " + (d.IsError() ? "" : "warning: ") + d.Message);
            return lines.Count == 0 ? "(no problems)\n" : string.Join("\n", lines) + "\n";
        }

        private static string FirstDifference(string expected, string actual)
        {
            string[] want = expected.Split('\n');
            string[] got = actual.Split('\n');
            int count = Math.Max(want.Length, got.Length);
            for (int i = 0; i < count; i++)
            {
                string w = i < want.Length ? want[i] : "<missing>";
                string g = i < got.Length ? got[i] : "<missing>";
                if (w != g)
                {
                    return "      line " + (i + 1) + "\n        expected: " + w + "\n        actual:   " + g;
                }
            }
            return "      no differing line";
        }

        private static string FindConformanceDir()
        {
            foreach (string start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
            {
                var dir = new DirectoryInfo(start);
                while (dir != null)
                {
                    string candidate = Path.Combine(dir.FullName, "conformance");
                    if (Directory.Exists(Path.Combine(candidate, "parse")))
                        return candidate;
                    dir = dir.Parent;
                }
            }
            return null;
        }
    }
}
