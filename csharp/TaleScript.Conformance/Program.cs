using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using TaleScript.Tools;

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
            var runCases = new List<string>();
            if (Directory.Exists(runDir))
            {
                foreach (string file in Directory.GetFiles(runDir, "*.tale"))
                    runCases.Add(Path.GetFileNameWithoutExtension(file));
            }
            runCases.Sort(StringComparer.Ordinal);
            foreach (string name in runCases)
            {
                string source = File.ReadAllText(Path.Combine(runDir, name + ".tale"), utf8);
                string settingsPath = Path.Combine(runDir, name + ".run.json");
                JsonElement? settings = null;
                if (File.Exists(settingsPath))
                {
                    var doc = JsonDocument.Parse(File.ReadAllText(settingsPath, utf8));
                    if (doc.RootElement.ValueKind == JsonValueKind.Object) settings = doc.RootElement;
                }
                string actual = RunCase(source, settings, name).GetAwaiter().GetResult();
                string expectedPath = Path.Combine(runDir, name + ".expected.txt");
                string expected = File.Exists(expectedPath) ? File.ReadAllText(expectedPath, utf8) : null;
                if (expected == actual)
                {
                    Console.WriteLine("ok    run/" + name);
                    passed++;
                }
                else
                {
                    Console.WriteLine("FAIL  run/" + name);
                    Console.WriteLine(expected == null ? "      no expected file" : FirstDifference(expected, actual));
                    failed++;
                }
            }

            Console.WriteLine(passed + " passed, " + failed + " failed");
            return failed > 0 ? 1 : 0;
        }

        /// <summary>Plays a run case and returns its transcript (see conformance/README.md).</summary>
        private static async Task<string> RunCase(string source, JsonElement? settings, string taleName)
        {
            var director = new TaleDirector();
            var player = new Player();
            JsonElement value;
            if (CheckContextJson.TryGet(settings, "picks", out value) && value.ValueKind == JsonValueKind.Array)
                foreach (var pick in value.EnumerateArray()) player.Picks.Add(pick.Clone());
            director.Presenter = player;
            director.Skipping = true;
            var events = player.Events;
            director.RuntimeError += (message, tale, line) => events.Add("error: line " + line + ": " + message);
            director.StorySignal += (signalName, signalValue) => events.Add("signal: " + signalName + " " + GdJson.Stringify(signalValue));
            var built = TaleCompiler.Build(source, taleName, director.MakeCheckContext(taleName));
            foreach (var diagnostic in built.Diagnostics)
                if (diagnostic.IsError())
                    events.Add("compile error: line " + diagnostic.Line + ": " + diagnostic.Message);
            Tale tale = built.Tale;
            if (tale != null)
            {
                director.AddTale(tale);
                string start = CheckContextJson.TryGet(settings, "start", out value) ? value.GetString() : "start";
                await director.Play(taleName, start);
                var names = new List<string>();
                foreach (var variable in tale.Variables) names.Add(variable.Name);
                names.Sort(StringComparer.Ordinal);
                foreach (string varName in names)
                    events.Add("var: " + varName + " = " + GdJson.Stringify(director.GetVar(taleName, varName)));
            }
            events.Add("end");
            return string.Join("\n", events) + "\n";
        }

        /// <summary>Shows lines at once and picks options from a list: an index, an option's text, or -1.</summary>
        private class Player : TalePresenter
        {
            public readonly List<JsonElement> Picks = new List<JsonElement>();
            public readonly List<string> Events = new List<string>();

            public override Task ShowLine(OrderedMap<object> line)
            {
                string speaker = GdValue.Str(line["speaker_name"]);
                Events.Add("line: " + (speaker.Length > 0 ? speaker + ": " : "") + GdValue.Str(line["text"]));
                return Task.CompletedTask;
            }

            public override Task<int> Choose(List<OrderedMap<object>> options, OrderedMap<object> settings)
            {
                var texts = new List<string>();
                int first = -1;
                for (int i = 0; i < options.Count; i++)
                {
                    bool enabled = (bool)options[i]["enabled"];
                    string text = GdValue.Str(options[i]["text"]);
                    texts.Add(enabled ? text : "[" + text + "]");
                    if (first == -1 && enabled) first = i;
                }
                object timeout;
                double seconds = settings.TryGetValue("timeout", out timeout) && GdValue.IsNumber(timeout) ? GdValue.ToDouble(timeout) : 0.0;
                Events.Add("choose: " + string.Join(" | ", texts) + (seconds > 0.0 ? " (timed)" : ""));
                int pick = first;
                if (Picks.Count > 0)
                {
                    JsonElement wanted = Picks[0];
                    Picks.RemoveAt(0);
                    if (wanted.ValueKind == JsonValueKind.Number) pick = (int)wanted.GetDouble();
                    else pick = texts.IndexOf(wanted.ValueKind == JsonValueKind.String ? wanted.GetString() : wanted.ToString());
                }
                Events.Add("pick: " + (pick >= 0 && pick < options.Count ? GdValue.Str(options[pick]["text"]) : "(time runs out)"));
                return Task.FromResult(pick);
            }
        }

        private static string CheckCase(string source, JsonElement? settings, string taleName)
        {
            var doc = TaleParser.Parse(source);
            var lines = new List<string>();
            foreach (var d in doc.Diagnostics)
                lines.Add(d.Line + ": parse: " + d.Message);
            foreach (var d in TaleChecker.Check(doc, CheckContextJson.ContextFor(settings, taleName)))
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
