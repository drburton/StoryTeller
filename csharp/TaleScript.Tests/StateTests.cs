using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace TaleScript.Tests
{
    internal static class StateTests
    {
        private const string Counting =
            "var count := 0\nbeat start:\n\tvar local := \"L\"\n\tfor i in 3:\n\t\tcount += 1\n\t\t\"line {i} {local} {count}\"\n\t\"end\"\n";

        private const string Branching =
            "@global var endings := 0\nvar gold := 5\nbeat start:\n\t\"Welcome\"\n\tgold += 2\n\tchoose:\n\t\t\"Take it\":\n\t\t\tgold += 10\n\t\t\"Leave it\":\n\t\t\tgold -= 1\n\t\"gold {gold}\"\n\tendings += 1\n";

        public static IEnumerable<KeyValuePair<string, Action>> All()
        {
            yield return Test("save mid-tale and continue in a fresh director", SaveMidTale);
            yield return Test("save at a choice shows the choice again", SaveAtChoice);
            yield return Test("variables and constants survive a save", VariablesSurvive);
            yield return Test("globals, read lines, and routes survive", GlobalsSurvive);
            yield return Test("save round trips through JSON", JsonRoundTrip);
            yield return Test("JSON parse reads every value kind", JsonParse);
            yield return Test("dictionaries and special floats survive", DictsAndFloats);
            yield return Test("rewind one step", RewindOne);
            yield return Test("rewind several steps", RewindSeveral);
            yield return Test("rewind refuses too many steps", RewindTooFar);
            yield return Test("rewind restores a choice", RewindChoice);
            yield return Test("history depth limits the snapshots", HistoryDepth);
            yield return Test("no_rewind clears the snapshots", NoRewind);
            yield return Test("route log records beats, links, and options", RouteLogRecords);
            yield return Test("route log round trips", RouteLogDict);
            yield return Test("state provider is captured and restored", ProviderRoundTrip);
            yield return Test("state provider rewinds with the story", ProviderRewinds);
        }

        private static KeyValuePair<string, Action> Test(string name, Action body)
        {
            return new KeyValuePair<string, Action>(name, body);
        }

        private static TaleDirector Make(Player player, params string[] sources)
        {
            var director = new TaleDirector();
            director.Presenter = player;
            for (int i = 0; i + 1 < sources.Length; i += 2)
                Add(director, sources[i], sources[i + 1]);
            return director;
        }

        private static void Add(TaleDirector director, string name, string source)
        {
            var built = TaleCompiler.Build(source, name, director.MakeCheckContext(name));
            if (built.Tale == null) throw new TestFailure("tale '" + name + "' did not compile");
            director.AddTale(built.Tale);
        }

        private static OrderedMap<object> ThroughJson(OrderedMap<object> state)
        {
            return (OrderedMap<object>)GdJson.Parse(GdJson.Stringify(state));
        }

        private static void SaveMidTale()
        {
            var player = new Player();
            var director = Make(player, "main", Counting);
            OrderedMap<object> saved = null;
            player.OnLine = line =>
            {
                if (GdValue.Str(line["text"]) == "line 1 L 2" && saved == null) saved = ThroughJson(director.Capture());
            };
            Task play = director.Play("main");
            Check.True(play.IsCompleted, "story finished");
            Check.Lines(new[] { "line 0 L 1", "line 1 L 2", "line 2 L 3", "end" }, player.Lines);

            var second = new Player();
            var fresh = Make(second, "main", Counting);
            fresh.Restore(saved);
            Task resumed = fresh.Resume();
            Check.True(resumed.IsCompleted, "resumed story finished");
            Check.Lines(new[] { "line 1 L 2", "line 2 L 3", "end" }, second.Lines, "shows the saved line again, then continues");
        }

        private static void SaveAtChoice()
        {
            var player = new Player { Manual = true };
            var director = Make(player, "main", Branching);
            Task play = director.Play("main");
            player.Continue();
            Check.Equal("Take it | Leave it", player.Current, "choice on screen");
            var saved = ThroughJson(director.Capture());
            director.Stop();

            var second = new Player { Manual = true };
            var fresh = Make(second, "main", Branching);
            fresh.Restore(saved);
            Task resumed = fresh.Resume();
            Check.Equal("Take it | Leave it", second.Current, "the choice shows again");
            Check.Equal(7L, fresh.GetVar("main", "gold"), "gold before choosing");
            second.Pick(0);
            Check.Equal("gold 17", second.Current);
            second.Continue();
            Check.True(resumed.IsCompleted, "story ended");
        }

        private static void VariablesSurvive()
        {
            const string source = "const MAX := 3\nvar gold := 1\nbeat start:\n\t\"one\"\n\tgold = 9\n\t\"two\"\n\tgold = MAX\n";
            var player = new Player { Manual = true };
            var director = Make(player, "main", source);
            Task play = director.Play("main");
            player.Continue();
            var saved = ThroughJson(director.Capture());

            var second = new Player { Manual = true };
            var fresh = Make(second, "main", source);
            var errors = new List<string>();
            fresh.RuntimeError += (message, tale, line) => errors.Add(message);
            fresh.Restore(saved);
            Check.Equal(9L, fresh.GetVar("main", "gold"));
            Check.Equal(3L, fresh.GetVar("main", "MAX"));
            Check.True(fresh.SetVar("main", "MAX", 4L).Length > 0, "constants stay constant");
            Task resumed = fresh.Resume();
            Check.Equal("two", second.Current);
            second.Continue();
            Check.True(resumed.IsCompleted, "done");
            Check.Equal(3L, fresh.GetVar("main", "gold"));
            Check.Equal(0, errors.Count, "no errors");
        }

        private static void GlobalsSurvive()
        {
            var player = new Player { AutoPick = 0 };
            var director = Make(player, "main", Branching);
            director.Play("main");
            var globals = ThroughJson(director.CaptureGlobals());

            var fresh = Make(new Player(), "main", Branching);
            fresh.RestoreGlobals(globals);
            Check.Equal(1L, fresh.GetVar("main", "endings"), "global variable");
            Check.True(ReadCount(globals) > 0, "read lines saved");
            Check.True(fresh.Routes.HasBeat("main.start"), "routes saved");
            fresh.Play("main");
            Check.Equal(2L, fresh.GetVar("main", "endings"), "global keeps counting");
        }

        private static int ReadCount(OrderedMap<object> globals)
        {
            return ((List<object>)globals["read"]).Count;
        }

        private static void JsonRoundTrip()
        {
            var player = new Player { Manual = true };
            var director = Make(player, "main", Counting);
            Task play = director.Play("main");
            player.Continue();
            var state = director.Capture();
            string text = GdJson.Stringify(state);
            var parsed = (OrderedMap<object>)GdJson.Parse(text);
            Check.Equal(text, GdJson.Stringify(parsed), "same text after a round trip");
            Check.True(text.Contains("\"pc\""), "has frames");
        }

        private static void JsonParse()
        {
            var value = (OrderedMap<object>)GdJson.Parse("{ \"a\": [1, 2.5, -3, 1e2, \"x\\n\\u0041\"], \"b\": null, \"c\": true, \"d\": 2.0 }");
            var list = (List<object>)value["a"];
            Check.True(list[0] is long && (long)list[0] == 1, "long");
            Check.True(list[1] is double && (double)list[1] == 2.5, "double");
            Check.Equal(-3L, (long)list[2]);
            Check.True(list[3] is double, "exponent is a double");
            Check.Equal("x\nA", (string)list[4]);
            Check.True(value["b"] == null, "null");
            Check.Equal(true, (bool)value["c"]);
            Check.True(value["d"] is double, "2.0 stays a double");
            try
            {
                GdJson.Parse("{\"a\": }");
                throw new TestFailure("bad JSON should throw");
            }
            catch (FormatException)
            {
            }
        }

        private static void DictsAndFloats()
        {
            const string source = "var table := {1: \"a\", \"k\": [1, 2.0]}\nvar f := 2.0\nvar inf := INF\nbeat start:\n\t\"hold\"\n";
            var player = new Player { Manual = true };
            var director = Make(player, "main", source);
            Task play = director.Play("main");
            var saved = ThroughJson(director.Capture());
            var fresh = Make(new Player { Manual = true }, "main", source);
            fresh.Restore(saved);
            var table = (TaleDict)fresh.GetVar("main", "table");
            Check.Equal("a", (string)table[1L]);
            Check.True(table["k"] is List<object> && ((List<object>)table["k"])[1] is double, "float inside a list");
            Check.True(fresh.GetVar("main", "f") is double, "float stays float");
            Check.True(double.IsPositiveInfinity((double)fresh.GetVar("main", "inf")), "infinity");
        }

        private static (TaleDirector, Player, TaleHistory) Rewindable(string source)
        {
            var player = new Player { Manual = true };
            var director = Make(player, "main", source);
            var history = new TaleHistory(director);
            return (director, player, history);
        }

        private static void RewindOne()
        {
            var (director, player, history) = Rewindable("var n := 0\nbeat start:\n\tn += 1\n\t\"a {n}\"\n\tn += 10\n\t\"b {n}\"\n\tn += 100\n\t\"c {n}\"\n");
            Task play = director.Play("main");
            player.Continue();
            player.Continue();
            Check.Equal("c 111", player.Current);
            Check.Equal(2, history.AvailableSteps);
            Check.True(history.Rewind(1), "rewound");
            Check.Equal("b 11", player.Current, "shows the previous line again");
            Check.Equal(11L, director.GetVar("main", "n"));
            player.Continue();
            Check.Equal("c 111", player.Current, "play continues forward");
            player.Continue();
            Check.True(play.IsCompleted, "story ends");
        }

        private static void RewindSeveral()
        {
            var (director, player, history) = Rewindable("beat start:\n\t\"1\"\n\t\"2\"\n\t\"3\"\n\t\"4\"\n");
            Task play = director.Play("main");
            player.Continue();
            player.Continue();
            player.Continue();
            Check.Equal("4", player.Current);
            Check.True(history.Rewind(3), "rewound three");
            Check.Equal("1", player.Current);
            Check.Equal(0, history.AvailableSteps, "nothing left to rewind");
            player.Continue();
            Check.Equal("2", player.Current);
            Check.Equal(1, history.AvailableSteps);
        }

        private static void RewindTooFar()
        {
            var (director, player, history) = Rewindable("beat start:\n\t\"1\"\n\t\"2\"\n");
            Task play = director.Play("main");
            player.Continue();
            Check.True(!history.Rewind(2), "only one step exists");
            Check.True(!history.Rewind(0), "zero steps");
            Check.Equal("2", player.Current, "story is unchanged");
        }

        private static void RewindChoice()
        {
            var (director, player, history) = Rewindable(Branching);
            Task play = director.Play("main");
            player.Continue();
            player.Pick(0);
            Check.Equal("gold 17", player.Current);
            Check.True(history.Rewind(1), "rewound to the choice");
            Check.Equal("Take it | Leave it", player.Current);
            Check.Equal(7L, director.GetVar("main", "gold"), "the pick is undone");
            player.Pick(1);
            Check.Equal("gold 6", player.Current, "the other path");
        }

        private static void HistoryDepth()
        {
            var (director, player, history) = Rewindable("beat start:\n\t\"1\"\n\t\"2\"\n\t\"3\"\n\t\"4\"\n\t\"5\"\n");
            history.Depth = 2;
            Task play = director.Play("main");
            for (int i = 0; i < 4; i++) player.Continue();
            Check.Equal("5", player.Current);
            Check.Equal(2, history.AvailableSteps, "limited to the depth");
            Check.True(!history.Rewind(3), "beyond the limit");
            Check.True(history.Rewind(2), "within the limit");
            Check.Equal("3", player.Current);
        }

        private static void NoRewind()
        {
            var (director, player, history) = Rewindable("beat start:\n\t\"1\"\n\t\"2\"\n\t@no_rewind \"3\"\n\t\"4\"\n");
            Task play = director.Play("main");
            player.Continue();
            player.Continue();
            Check.Equal("3", player.Current);
            Check.Equal(0, history.AvailableSteps, "the barrier cleared them");
            player.Continue();
            Check.Equal(1, history.AvailableSteps);
            Check.True(history.Rewind(1), "back to the barrier line");
            Check.Equal("3", player.Current);
            Check.True(!history.Rewind(1), "not past it");
        }

        private static void RouteLogRecords()
        {
            const string source = "beat start:\n\t\"hi\"\n\tchoose:\n\t\t\"Left\":\n\t\t\tgo_left()\n\t\t\"Right\":\n\t\t\t\"r\"\nbeat go_left:\n\t\"l\"\n";
            var player = new Player { AutoPick = 0 };
            var director = Make(player, "main", source);
            director.Play("main");
            var routes = director.Routes;
            Check.True(routes.HasBeat("main.start"), "start entered");
            Check.True(routes.HasBeat("main.go_left"), "called beat entered");
            Check.True(!routes.HasBeat("main.nowhere"), "unknown beat");
            Check.Equal("main.start", routes.Beats[0]);
            var links = routes.GetLinks();
            Check.Equal(1, links.Count, "one link");
            Check.Equal("main.start", links[0][0]);
            Check.Equal("main.go_left", links[0][1]);
            var tale = director.GetTale("main");
            string left = null, right = null;
            foreach (var instruction in tale.Instructions)
            {
                if (instruction.Op != TaleOp.Choose) continue;
                left = tale.TranslationKey(instruction.Options[0].Id);
                right = tale.TranslationKey(instruction.Options[1].Id);
            }
            Check.Equal(TaleRouteLog.Picked, routes.GetOptionState(left), "picked option");
            Check.Equal(TaleRouteLog.Seen, routes.GetOptionState(right), "seen option");
            Check.Equal(TaleRouteLog.Unseen, routes.GetOptionState("main:other"), "unknown option");
        }

        private static void RouteLogDict()
        {
            var log = new TaleRouteLog();
            log.Enter("a.start");
            log.Enter("a.next", "a.start");
            log.SeeOption("a:x");
            log.SeeOption("a:y");
            log.PickOption("a:y");
            var copy = new TaleRouteLog();
            copy.FromDict((OrderedMap<object>)GdJson.Parse(GdJson.Stringify(log.ToDict())));
            Check.Lines(log.Beats, copy.Beats, "beats");
            Check.Equal(1, copy.GetLinks().Count, "links");
            Check.Equal(TaleRouteLog.Seen, copy.GetOptionState("a:x"));
            Check.Equal(TaleRouteLog.Picked, copy.GetOptionState("a:y"));
            copy.Clear();
            Check.True(copy.IsEmpty, "cleared");
        }

        private sealed class Stage : ITaleStateProvider
        {
            public string Background = "none";
            public long Actors;
            public string Name { get { return "stage"; } }

            public object Capture()
            {
                var data = new OrderedMap<object>();
                data["background"] = Background;
                data["actors"] = Actors;
                return data;
            }

            public void Restore(object data)
            {
                var map = (OrderedMap<object>)data;
                Background = (string)map["background"];
                Actors = (long)map["actors"];
            }
        }

        private static void ProviderRoundTrip()
        {
            const string source = "beat start:\n\t\"a\"\n\t\"b\"\n";
            var player = new Player { Manual = true };
            var director = Make(player, "main", source);
            var stage = new Stage { Background = "forest", Actors = 2 };
            director.AddStateProvider(stage);
            Task play = director.Play("main");
            var saved = ThroughJson(director.Capture());
            var crew = (OrderedMap<object>)saved["crew"];
            Check.True(crew.Has("stage"), "saved under its name");

            var fresh = Make(new Player { Manual = true }, "main", source);
            var other = new Stage();
            fresh.AddStateProvider(other);
            fresh.Restore(saved);
            Check.Equal("forest", other.Background);
            Check.Equal(2L, other.Actors);
        }

        private static void ProviderRewinds()
        {
            var (director, player, history) = Rewindable("beat start:\n\t\"1\"\n\t\"2\"\n\t\"3\"\n");
            var stage = new Stage();
            director.AddStateProvider(stage);
            player.OnLine = line => stage.Actors = GdValue.ToLong(long.Parse(GdValue.Str(line["text"])));
            Task play = director.Play("main");
            player.Continue();
            player.Continue();
            Check.Equal(3L, stage.Actors);
            history.Rewind(1);
            Check.Equal(2L, stage.Actors, "provider state rewound");
        }
    }
}
