using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>One path through a tale: the options taken and where it ended.</summary>
    public class TalePath
    {
        /// <summary>The text of each option taken, in order. "(time runs out)" stands for a timed choice that ran out.</summary>
        public List<string> Choices = new List<string>();
        /// <summary>The scene the path ended in as "tale.beat", or <see cref="TalePaths.CutOff"/> when a limit stopped it.</summary>
        public string Ending = "";
        /// <summary>True when a limit or an error stopped the path before the tale ended.</summary>
        public bool IsCutOff;
        /// <summary>How many lines the path showed.</summary>
        public int Lines;
    }

    /// <summary>One kind of trouble found on the paths, with how many paths hit it.</summary>
    public class TalePathProblem
    {
        /// <summary>"error", "stuck", "loop", or "no_options".</summary>
        public string Kind = "error";
        public string Message = "";
        public string Tale = "";
        /// <summary>The line in the tale, or 0 when there is none.</summary>
        public int Line;
        /// <summary>How many paths hit it.</summary>
        public int Paths;
        /// <summary>The choices made on the first path that hit it.</summary>
        public List<string> FirstPath = new List<string>();
    }

    /// <summary>What <see cref="TalePaths.Explore"/> found.</summary>
    public class TalePathsResult
    {
        public string Tale = "";
        public string Beat = "start";
        public List<TalePath> Paths = new List<TalePath>();
        /// <summary>Endings ("tale.beat") with the number of paths that end there. Cut off paths are not counted.</summary>
        public OrderedMap<int> Endings = new OrderedMap<int>();
        /// <summary>The problems, each shown once with the number of paths that hit it.</summary>
        public List<TalePathProblem> Problems = new List<TalePathProblem>();
        /// <summary>Beats of the start tale that no path entered.</summary>
        public List<string> Unreached = new List<string>();
        /// <summary>False when the explorer stopped at MaxPaths with paths left to try.</summary>
        public bool Complete = true;
        /// <summary>True when a limit (paths, choices, lines, or seconds) stopped the exploration or a path.</summary>
        public bool LimitReached;
        /// <summary>Total lines shown over all paths.</summary>
        public long TotalLines;

        public int PathCount { get { return Paths.Count; } }
        public int CutOffCount
        {
            get
            {
                int count = 0;
                foreach (TalePath path in Paths) if (path.IsCutOff) count++;
                return count;
            }
        }

        /// <summary>True when a path hit a runtime error or another problem.</summary>
        public bool HasProblems { get { return Problems.Count > 0; } }

        /// <summary>The result in words, in the format of the Godot explorer.</summary>
        public string Describe()
        {
            return TalePaths.Describe(this);
        }
    }

    /// <summary>One choice met on a path: the picks possible there and the one taken.</summary>
    public class TalePathStep
    {
        public List<int> Options = new List<int>();
        public int Pick;
        public Dictionary<int, string> Texts = new Dictionary<int, string>();
    }

    /// <summary>Limits and hooks for <see cref="TalePaths.Explore"/>.</summary>
    public class TalePathsOptions
    {
        /// <summary>Stops after this many paths; the result then says it is not complete.</summary>
        public int MaxPaths = 1000;
        /// <summary>A path that makes more choices than this is reported as a loop.</summary>
        public int MaxChoices = 60;
        /// <summary>A path that shows more lines than this without a choice is reported as a loop.</summary>
        public int MaxLines = 2000;
        /// <summary>A path still running after this many seconds is reported as stuck.</summary>
        public double PathSeconds = 10.0;
        /// <summary>Names game code exposes. Each gets a stand-in object.</summary>
        public List<string> Exposed = new List<string>();
        /// <summary>Cast ids that tales call methods on. Cast ids in the check context are added to these.</summary>
        public List<string> CastIds = new List<string>();
        /// <summary>
        /// Runs on every director the explorer makes, after the stand-ins are in place: register
        /// actions, set <see cref="TaleDirector.ContextExtender"/>, and so on. An action it
        /// registers should finish at once, since nobody is playing.
        /// </summary>
        public Action<TaleDirector> Setup;
    }

    /// <summary>
    /// Stands in for an object game code exposes: every property reads as 0, every property
    /// can be set, and every method returns null. It records nothing.
    /// </summary>
    public class TaleStandIn : ITaleObject
    {
        public bool TryGetProperty(string name, out object value)
        {
            value = 0L;
            return true;
        }

        public bool TrySetProperty(string name, object value)
        {
            return true;
        }

        public object CallMethod(string name, object[] args)
        {
            return null;
        }
    }

    /// <summary>An action with the signature of a real one that does nothing, for exploring tales without a game.</summary>
    public class TaleStubAction : TaleAction
    {
        public TaleStubAction(string name, IEnumerable<string> parameters = null, int required = 0)
            : base(name, parameters, required)
        {
        }
    }

    /// <summary>
    /// Plays a tale down every path, taking each option at every choice, and reports what a
    /// player could run into: runtime errors, paths that go round in a loop or get stuck, and
    /// scenes no path reaches. A timed choice is also tried with the time running out. Each
    /// path runs in a director of its own with a presenter that completes at once, so the
    /// whole exploration finishes without blocking a thread when the tale's actions finish at
    /// once. Objects game code exposes get stand-ins (<see cref="TaleStandIn"/>).
    /// </summary>
    public static class TalePaths
    {
        /// <summary>The ending of a path a limit stopped.</summary>
        public const string CutOff = "cut off";

        private const string TimeRunsOut = "(time runs out)";

        /// <summary>
        /// Plays <paramref name="taleName"/> from <paramref name="beat"/> down every path.
        /// <paramref name="sources"/> maps tale names to TaleScript text, and
        /// <paramref name="builtTales"/> adds tales that are already compiled. Either may be
        /// null, but the start tale must be in one of them. Tale text also tells which members
        /// of the stand-ins the tales use. A source with mistakes is not played, and its
        /// mistakes come back as problems.
        /// </summary>
        public static async Task<TalePathsResult> Explore(string taleName, string beat,
            IDictionary<string, string> sources, IEnumerable<Tale> builtTales, TalePathsOptions options = null)
        {
            if (options == null) options = new TalePathsOptions();
            var result = new TalePathsResult();
            result.Tale = taleName;
            result.Beat = beat;
            var tales = new List<Tale>();
            if (builtTales != null) tales.AddRange(builtTales);
            var allText = new StringBuilder();
            if (sources != null)
                foreach (var pair in sources) allText.Append(pair.Value).Append('\n');

            // Stand-ins for the exposed names and cast ids, with the members the tales use.
            var names = new List<string>();
            AddNames(names, options.Exposed);
            AddNames(names, options.CastIds);
            TaleDirector probe = MakeDirector(options, null, tales, new Dictionary<string, TaleExposed>());
            TaleCheckContext known = probe.MakeCheckContext("");
            AddNames(names, known.Exposed.Keys);
            AddNames(names, known.Cast.Keys);
            var standIns = MakeStandIns(names, known, allText.ToString());

            if (sources != null)
            {
                var compiled = new List<Tale>();
                foreach (var pair in sources)
                {
                    TaleDirector builder = MakeDirector(options, null, tales, standIns);
                    TaleCheckContext context = builder.MakeCheckContext(pair.Key);
                    foreach (var other in sources)
                    {
                        if (other.Key == pair.Key || context.Tales.Has(other.Key)) continue;
                        AddTaleInfo(context, other.Key, other.Value);
                    }
                    TaleBuildResult built = TaleCompiler.Build(pair.Value, pair.Key, context);
                    var errors = new List<TaleDiagnostic>();
                    foreach (TaleDiagnostic diagnostic in built.Diagnostics)
                        if (diagnostic.IsError()) errors.Add(diagnostic);
                    if (errors.Count > 0 || built.Tale == null)
                    {
                        foreach (TaleDiagnostic diagnostic in errors)
                        {
                            var problem = new TalePathProblem();
                            problem.Kind = "error";
                            problem.Message = diagnostic.Message;
                            problem.Tale = pair.Key;
                            problem.Line = diagnostic.Line;
                            problem.Paths = 1;
                            result.Problems.Add(problem);
                        }
                        return result;
                    }
                    compiled.Add(built.Tale);
                }
                tales.AddRange(compiled);
            }

            var entered = new HashSet<string>();
            var grouped = new Dictionary<string, TalePathProblem>();
            var plan = new List<int>();
            while (true)
            {
                if (result.Paths.Count >= options.MaxPaths)
                {
                    result.Complete = false;
                    result.LimitReached = true;
                    break;
                }
                PathRun run = await PlayPath(options, taleName, beat, plan, tales, standIns);
                var path = new TalePath();
                foreach (TalePathStep step in run.Trace)
                {
                    string text;
                    path.Choices.Add(step.Texts.TryGetValue(step.Pick, out text) ? text : TimeRunsOut);
                }
                path.Lines = run.Lines;
                path.IsCutOff = run.CutOff;
                path.Ending = run.CutOff ? CutOff : run.Ending;
                result.Paths.Add(path);
                result.TotalLines += run.Lines;
                if (run.CutOff && run.Problems.Exists(p => p.Kind == "loop" || p.Kind == "stuck")) result.LimitReached = true;
                foreach (string id in run.Entered) entered.Add(id);
                if (!run.CutOff && run.Ending.Length > 0)
                    result.Endings[run.Ending] = (result.Endings.Has(run.Ending) ? result.Endings[run.Ending] : 0) + 1;
                foreach (TalePathProblem problem in run.Problems)
                {
                    string key = problem.Kind + "|" + problem.Line.ToString(CultureInfo.InvariantCulture) + "|" + problem.Message;
                    TalePathProblem group;
                    if (!grouped.TryGetValue(key, out group))
                    {
                        group = problem;
                        group.FirstPath = new List<string>(path.Choices);
                        grouped[key] = group;
                        result.Problems.Add(group);
                    }
                    group.Paths++;
                }
                List<int> next = NextPlan(run.Trace);
                if (next.Count == 0) break;
                plan = next;
            }

            foreach (Tale tale in tales)
            {
                if (tale.TaleName != taleName) continue;
                foreach (string beatName in tale.Beats.Keys)
                    if (!entered.Contains(taleName + "." + beatName)) result.Unreached.Add(beatName);
            }
            return result;
        }

        /// <summary>Explores tales given as source text. See the longer overload.</summary>
        public static Task<TalePathsResult> Explore(string taleName, string beat, IDictionary<string, string> sources, TalePathsOptions options = null)
        {
            return Explore(taleName, beat, sources, null, options);
        }

        /// <summary>
        /// The picks for the next path after the path whose choices were
        /// <paramref name="trace"/>: the same picks up to the last choice with an option not
        /// tried yet, then that option. Empty when every path has been tried.
        /// </summary>
        public static List<int> NextPlan(IList<TalePathStep> trace)
        {
            for (int k = trace.Count - 1; k >= 0; k--)
            {
                List<int> options = trace[k].Options;
                int at = options.IndexOf(trace[k].Pick);
                if (at >= 0 && at + 1 < options.Count)
                {
                    var plan = new List<int>();
                    for (int i = 0; i < k; i++) plan.Add(trace[i].Pick);
                    plan.Add(options[at + 1]);
                    return plan;
                }
            }
            return new List<int>();
        }

        /// <summary>The result in words: the same text the Godot explorer prints.</summary>
        public static string Describe(TalePathsResult result)
        {
            var lines = new List<string>();
            lines.Add(result.Tale + ": " + result.Paths.Count.ToString(CultureInfo.InvariantCulture) + " path"
                + (result.Paths.Count == 1 ? "" : "s") + " played"
                + (result.Complete ? "" : " (stopped early; there are more)") + ".");
            var endings = new List<string>();
            foreach (string ending in result.Endings.Keys)
                endings.Add(ending + " (" + result.Endings[ending].ToString(CultureInfo.InvariantCulture) + ")");
            lines.Add("Endings: " + (endings.Count > 0 ? string.Join(", ", endings) : "none"));
            if (result.Unreached.Count == 0) lines.Add("Every scene is reached.");
            else lines.Add("Never reached: " + string.Join(", ", result.Unreached));
            if (result.Problems.Count == 0)
            {
                lines.Add("No problems found.");
            }
            else
            {
                lines.Add(result.Problems.Count.ToString(CultureInfo.InvariantCulture) + " problem" + (result.Problems.Count == 1 ? "" : "s") + ":");
                foreach (TalePathProblem problem in result.Problems)
                {
                    string where = problem.Line > 0 ? " (line " + problem.Line.ToString(CultureInfo.InvariantCulture) + ")" : "";
                    lines.Add("  " + problem.Kind + where + ": " + problem.Message);
                    string path = problem.FirstPath.Count > 0 ? string.Join(" > ", problem.FirstPath) : "(no choices)";
                    if (problem.Paths > 1)
                        lines.Add("    on " + problem.Paths.ToString(CultureInfo.InvariantCulture) + " paths, first after: " + path);
                    else
                        lines.Add("    after: " + path);
                }
            }
            return string.Join("\n", lines);
        }

        // --- Internals ----------------------------------------------------------

        private class PathRun
        {
            public List<TalePathStep> Trace;
            public HashSet<string> Entered = new HashSet<string>();
            public string Ending = "";
            public bool CutOff;
            public int Lines;
            public List<TalePathProblem> Problems = new List<TalePathProblem>();
        }

        private static void AddNames(List<string> names, IEnumerable<string> more)
        {
            if (more == null) return;
            foreach (string name in more)
                if (!string.IsNullOrEmpty(name) && !names.Contains(name)) names.Add(name);
        }

        private static void AddTaleInfo(TaleCheckContext context, string name, string source)
        {
            var beats = new List<string>();
            var vars = new List<string>();
            foreach (TaleNode statement in TaleParser.Parse(source).Statements)
            {
                if (statement.Kind == TaleNodeKind.Beat) beats.Add(statement.Name);
                else if (statement.Kind == TaleNodeKind.Var || statement.Kind == TaleNodeKind.Const) vars.Add(statement.Name);
            }
            context.AddTale(name, beats, vars);
        }

        /// <summary>A director with the stand-ins exposed, then the caller's setup, then ask_text.</summary>
        private static TaleDirector MakeDirector(TalePathsOptions options, PathPlayer player, List<Tale> tales, Dictionary<string, TaleExposed> standIns)
        {
            var director = new TaleDirector();
            director.Presenter = player;
            director.Skipping = true;
            foreach (var pair in standIns)
                director.Expose(pair.Key, pair.Value.Target, pair.Value.Methods, pair.Value.Properties);
            if (options.Setup != null) options.Setup(director);
            if (director.GetAction("ask_text") == null) director.AddAction(new AskTextAction());
            foreach (Tale tale in tales) director.AddTale(tale);
            return director;
        }

        private static Dictionary<string, TaleExposed> MakeStandIns(List<string> names, TaleCheckContext known, string text)
        {
            var standIns = new Dictionary<string, TaleExposed>();
            foreach (string name in names)
            {
                var methods = new List<string>();
                var properties = new List<string>();
                if (known.Cast.Has(name))
                {
                    methods.AddRange(TaleCheckContext.CastMethods);
                    properties.AddRange(TaleCheckContext.CastProperties);
                    List<string> fields;
                    if (known.CastFields.TryGetValue(name, out fields)) properties.AddRange(fields);
                }
                var used = new Regex("\\b" + Regex.Escape(name) + "\\.(\\w+)(\\s*\\()?", RegexOptions.CultureInvariant);
                foreach (Match found in used.Matches(text))
                {
                    string member = found.Groups[1].Value;
                    List<string> list = found.Groups[2].Success ? methods : properties;
                    if (!list.Contains(member)) list.Add(member);
                }
                standIns[name] = new TaleExposed(new TaleStandIn(), methods, properties);
            }
            return standIns;
        }

        private static async Task<PathRun> PlayPath(TalePathsOptions options, string taleName, string beat, List<int> plan,
            List<Tale> tales, Dictionary<string, TaleExposed> standIns)
        {
            var run = new PathRun();
            var timer = Stopwatch.StartNew();
            var player = new PathPlayer(options, plan, timer);
            TaleDirector director = MakeDirector(options, player, tales, standIns);
            player.Director = director;
            director.RuntimeError += (message, errorTale, line) =>
            {
                var problem = new TalePathProblem();
                problem.Kind = "error";
                problem.Message = message;
                problem.Tale = errorTale;
                problem.Line = line;
                run.Problems.Add(problem);
            };
            director.BeatEntered += (enteredTale, enteredBeat) =>
            {
                string id = enteredTale + "." + enteredBeat;
                run.Entered.Add(id);
                run.Ending = id;
            };
            Task play = director.Play(taleName, beat);
            bool finished = play.IsCompleted;
            if (!finished)
            {
                // Something is waiting. Give the path its time, without blocking.
                double left = Math.Max(options.PathSeconds - timer.Elapsed.TotalSeconds, 0.0);
                using (var cancel = new CancellationTokenSource())
                {
                    Task limit = Task.Delay(TimeSpan.FromSeconds(left), cancel.Token);
                    Task first = await Task.WhenAny(play, limit);
                    finished = first == play;
                    cancel.Cancel();
                }
                if (!finished)
                {
                    player.Halt("stuck", "still playing after " + ((int)options.PathSeconds).ToString(CultureInfo.InvariantCulture)
                        + " seconds, maybe waiting on something that never finishes");
                }
            }
            if (player.Stopped)
            {
                var problem = new TalePathProblem();
                problem.Kind = player.StopKind;
                problem.Message = player.StopReason;
                problem.Tale = taleName;
                run.Problems.Add(problem);
            }
            // A path cut short has no ending.
            if (!finished || player.Stopped)
            {
                director.Stop();
                run.CutOff = true;
                run.Ending = "";
            }
            run.Trace = player.Trace;
            run.Lines = player.Lines;
            return run;
        }

        /// <summary>Answers ask_text() with its default, or "Tester".</summary>
        private class AskTextAction : TaleAction
        {
            public AskTextAction()
                : base("ask_text", new[] { "prompt", "default_text", "max_length" }, 1, new object[] { "", 24L })
            {
            }

            public override Task<object> RunAsync(TaleContext context, object[] args)
            {
                string answer = GdValue.Str(args[1]);
                return Task.FromResult<object>(answer.Length > 0 ? answer : "Tester");
            }
        }

        /// <summary>Shows lines at once and picks options from the plan, then the first option not tried yet.</summary>
        private class PathPlayer : TalePresenter
        {
            public TaleDirector Director;
            public readonly List<TalePathStep> Trace = new List<TalePathStep>();
            public bool Stopped;
            public string StopKind = "";
            public string StopReason = "";
            public int Lines;

            private readonly TalePathsOptions _options;
            private readonly List<int> _plan;
            private readonly Stopwatch _timer;
            private int _linesSinceChoice;

            public PathPlayer(TalePathsOptions options, List<int> plan, Stopwatch timer)
            {
                _options = options;
                _plan = plan;
                _timer = timer;
            }

            public override Task ShowLine(OrderedMap<object> line)
            {
                Lines++;
                _linesSinceChoice++;
                if (_linesSinceChoice > _options.MaxLines)
                    Halt("loop", "more than " + _options.MaxLines.ToString(CultureInfo.InvariantCulture) + " lines without a choice, maybe a loop");
                else CheckTime();
                return Task.CompletedTask;
            }

            public override Task<int> Choose(List<OrderedMap<object>> options, OrderedMap<object> settings)
            {
                _linesSinceChoice = 0;
                var picks = new List<int>();
                var texts = new Dictionary<int, string>();
                for (int i = 0; i < options.Count; i++)
                {
                    if ((bool)options[i]["enabled"]) picks.Add(i);
                    texts[i] = GdValue.Str(options[i]["text"]);
                }
                object timeout;
                if (settings.TryGetValue("timeout", out timeout) && GdValue.IsNumber(timeout) && GdValue.ToDouble(timeout) > 0.0)
                    picks.Add(-1);
                if (picks.Count == 0)
                {
                    Halt("no_options", "a choice with no option the player can pick");
                    return Task.FromResult(-1);
                }
                if (Stopped || Trace.Count >= _options.MaxChoices)
                {
                    Halt("loop", "more than " + _options.MaxChoices.ToString(CultureInfo.InvariantCulture) + " choices, maybe a loop");
                    return Task.FromResult(-1);
                }
                CheckTime();
                int depth = Trace.Count;
                int pick = depth < _plan.Count ? _plan[depth] : picks[0];
                var step = new TalePathStep();
                step.Options = picks;
                step.Pick = pick;
                step.Texts = texts;
                Trace.Add(step);
                return Task.FromResult(pick);
            }

            /// <summary>Ends the path: the director stops, so a loop cannot keep it busy.</summary>
            public void Halt(string kind, string reason)
            {
                if (Stopped) return;
                Stopped = true;
                StopKind = kind;
                StopReason = reason;
                Director.Stop();
            }

            private void CheckTime()
            {
                if (!Stopped && _timer.Elapsed.TotalSeconds > _options.PathSeconds)
                    Halt("stuck", "still playing after " + ((int)_options.PathSeconds).ToString(CultureInfo.InvariantCulture)
                        + " seconds, maybe waiting on something that never finishes");
            }
        }
    }
}
