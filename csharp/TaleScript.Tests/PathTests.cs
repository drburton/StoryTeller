using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;

namespace TaleScript.Tests
{
    /// <summary>Tests for the path explorer, ported from tests/unit/director/test_tale_paths.gd.</summary>
    internal static class PathTests
    {
        private const string Trip = @"var brave := false
var name := """"

beat start:
	name = await ask_text(""Your name?"", ""Robin"")
	""Hello, {name}.""
	choose:
		""Fight"":
			brave = true
			jump fight
		""Run"":
			jump run

beat fight:
	game.reward(2)
	if game.score > 1:
		""You won a prize.""
	choose:
		""Shout"" if brave:
			""A mighty shout.""
		""Stay quiet"":
			""Silence.""
	jump ending

beat run:
	choose(timeout = 2.0):
		""Hide"":
			music(""no_such_track"")
			jump ending
		timeout:
			""Too slow.""
			jump ending

beat ending:
	""The end, {name}.""

beat forgotten:
	""Nobody comes here.""
";

        private const string Loop = "beat start:\n\tchoose:\n\t\t\"Again\":\n\t\t\tjump start\n\t\t\"Leave\":\n\t\t\t\"Bye.\"\n";

        private const string RunawayPath = "/tmp/claude-0/-home-user-StoryTeller/3769153a-3b7b-56c0-a5b2-575555a24898/scratchpad/runaway/runaway.tale";

        public static IEnumerable<KeyValuePair<string, Action>> All()
        {
            yield return Test("every path is played with its ending", EveryPath);
            yield return Test("problems name the path that meets them", ProblemsNamePath);
            yield return Test("a loop is reported and the rest still played", LoopReported);
            yield return Test("a tale with mistakes is not played", Mistakes);
            yield return Test("next plan tries each option once", NextPlan);
            yield return Test("lines past the limit cut the path off", LineLimit);
            yield return Test("path limit stops the exploration", PathLimit);
            yield return Test("cast ids get stand-ins", CastStandIn);
            if (File.Exists(RunawayPath)) yield return Test("runaway explores to 43 paths", Runaway);
        }

        private static KeyValuePair<string, Action> Test(string name, Action body)
        {
            return new KeyValuePair<string, Action>(name, body);
        }

        private static TalePathsOptions Options()
        {
            var options = new TalePathsOptions();
            options.Exposed.Add("game");
            options.Setup = director => director.AddAction(new MusicAction());
            return options;
        }

        private static TalePathsResult Explore(string name, string source, TalePathsOptions options)
        {
            Task<TalePathsResult> task = TalePaths.Explore(name, "start", new Dictionary<string, string> { { name, source } }, options);
            Check.True(task.IsCompleted, "the explorer finishes without waiting");
            return task.Result;
        }

        private class MusicAction : TaleAction
        {
            public MusicAction() : base("music", new[] { "track" }, 1)
            {
            }

            public override void Run(TaleContext context, object[] args)
            {
                if (GdValue.Str(args[0]) == "no_such_track") context.Fail("Music 'no_such_track' is not in the Story Config.");
            }
        }

        private static void EveryPath()
        {
            TalePathsResult result = Explore("trip", Trip, Options());
            // Fight: Shout or Stay quiet. Run: Hide, or the time runs out.
            Check.Equal(4, result.PathCount, "paths");
            Check.True(result.Complete, "complete");
            Check.Equal(1, result.Endings.Count, "ending count");
            Check.Equal(4, result.Endings["trip.ending"], "paths at the ending");
            Check.Lines(new[] { "forgotten" }, result.Unreached);
        }

        private static void ProblemsNamePath()
        {
            TalePathsResult result = Explore("trip", Trip, Options());
            Check.Equal(1, result.Problems.Count, "problems");
            TalePathProblem problem = result.Problems[0];
            Check.Equal("error", problem.Kind, "kind");
            Check.True(problem.Message.Contains("no_such_track"), problem.Message);
            Check.Lines(new[] { "Run", "Hide" }, problem.FirstPath);
            Check.Equal(1, problem.Paths, "paths that hit it");
            Check.Equal("trip", problem.Tale, "tale");
            Check.True(problem.Line > 0, "line");
            string words = result.Describe();
            Check.True(words.Contains("4 paths played."), words);
            Check.True(words.Contains("Never reached: forgotten"), words);
            Check.True(words.Contains("after: Run > Hide"), words);
        }

        private static void LoopReported()
        {
            var options = Options();
            options.MaxChoices = 4;
            TalePathsResult result = Explore("loop", Loop, options);
            int ended = result.Endings.Has("loop.start") ? result.Endings["loop.start"] : 0;
            Check.Equal(result.PathCount - 1, ended, "every path but the endless one ends");
            var loops = result.Problems.FindAll(p => p.Kind == "loop");
            Check.Equal(1, loops.Count, "loops");
            Check.Lines(new[] { "Again", "Again", "Again", "Again" }, loops[0].FirstPath);
            Check.True(result.LimitReached, "limit reached");
            Check.Equal(1, result.CutOffCount, "cut off paths");
            TalePath cut = result.Paths.Find(p => p.IsCutOff);
            Check.Equal(TalePaths.CutOff, cut.Ending, "cut off ending");
        }

        private static void Mistakes()
        {
            TalePathsResult result = Explore("broken", "beat start:\n\tjump nowhere\n", Options());
            Check.Equal(0, result.PathCount, "paths");
            Check.Equal("Unknown beat 'nowhere'.", result.Problems[0].Message, "message");
        }

        private static TalePathStep Step(int pick, params int[] options)
        {
            var step = new TalePathStep();
            step.Pick = pick;
            step.Options = new List<int>(options);
            return step;
        }

        private static void NextPlan()
        {
            Check.Lines(new[] { "1" }, Strings(TalePaths.NextPlan(new[] { Step(0, 0, 1), Step(2, 0, 1, 2) })));
            Check.Lines(new[] { "0", "2" }, Strings(TalePaths.NextPlan(new[] { Step(0, 0, 1), Step(1, 0, 1, 2) })));
            Check.Equal(0, TalePaths.NextPlan(new[] { Step(-1, 0, -1) }).Count, "done");
        }

        private static List<string> Strings(List<int> numbers)
        {
            var list = new List<string>();
            foreach (int number in numbers) list.Add(number.ToString());
            return list;
        }

        private static void LineLimit()
        {
            var options = Options();
            options.MaxLines = 10;
            TalePathsResult result = Explore("spin", "beat start:\n\twhile true:\n\t\t\"again\"\n", options);
            Check.Equal(1, result.PathCount, "paths");
            Check.Equal("loop", result.Problems[0].Kind, "kind");
            Check.Equal("more than 10 lines without a choice, maybe a loop", result.Problems[0].Message, "message");
            Check.True(result.Paths[0].IsCutOff, "cut off");
            Check.Equal(0, result.Endings.Count, "a cut off path has no ending");
        }

        private static void PathLimit()
        {
            var options = Options();
            options.MaxPaths = 2;
            TalePathsResult result = Explore("trip", Trip, options);
            Check.Equal(2, result.PathCount, "paths");
            Check.True(!result.Complete, "not complete");
            Check.True(result.LimitReached, "limit reached");
            Check.True(result.Describe().Contains("stopped early"), "described");
        }

        private static void CastStandIn()
        {
            var options = new TalePathsOptions();
            options.CastIds.Add("mira");
            options.Setup = director => director.ContextExtender = context => context.AddCast("kai", new[] { "smile" });
            string source = "beat start:\n\tmira.enter(\"smile\")\n\tkai.nod()\n\tkai: \"Hi.\"\n\tmira.mood = \"smile\"\n";
            TalePathsResult result = Explore("cast", source, options);
            Check.Equal(0, result.Problems.Count, result.Describe());
            Check.Equal(1, result.Paths[0].Lines, "lines");
        }

        private static void Runaway()
        {
            var options = new TalePathsOptions();
            options.Exposed.Add("shots");
            options.Setup = director =>
            {
                director.AddAction(new Stub("music", "track", "volume", "fade", "loop"));
                director.AddAction(new Stub("sound", "name", "volume"));
                director.AddAction(new Stub("stop_music", "fade"));
                director.AddAction(new Stub("backdrop", "name", "transition", "time", "mask"));
            };
            string source = File.ReadAllText(RunawayPath);
            TalePathsResult result = Explore("runaway", source, options);
            Check.Equal(43, result.PathCount, "paths");
            Check.Equal(9, result.Endings["runaway.bridge_holds"], "bridge_holds");
            Check.Equal(28, result.Endings["runaway.mage_lost"], "mage_lost");
            Check.Equal(6, result.Endings["runaway.climb_down"], "climb_down");
            Check.Equal(0, result.Problems.Count, result.Describe());
        }

        private class Stub : TaleAction
        {
            public Stub(string name, params string[] parameters) : base(name, parameters, 1)
            {
            }
        }
    }
}
