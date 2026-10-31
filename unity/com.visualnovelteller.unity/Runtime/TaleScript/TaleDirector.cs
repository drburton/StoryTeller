using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>
    /// Runs tales: steps through instructions, keeps variables and the call stack, calls
    /// actions, and hands lines and choices to the presenter. It has no engine dependency.
    /// Unity code drives it with <c>await director.Play("prologue")</c>.
    /// </summary>
    public partial class TaleDirector
    {
        /// <summary>Looks up a name that tales use as a value, such as a cast member. Return false when the name is unknown.</summary>
        public delegate bool NameResolverDelegate(string name, out object value);

        /// <summary>Supplies constants of value types, such as Color.RED. Return false when unknown.</summary>
        public delegate bool TypeConstantDelegate(string typeName, string constant, out object value);

        /// <summary>Emitted when a tale starts playing from <see cref="Play"/>.</summary>
        public event Action<string, string> StoryStarted;
        /// <summary>Emitted when playback ends: the last beat finished or <see cref="Stop"/> ran.</summary>
        public event Action StoryFinished;
        /// <summary>Emitted when a beat starts, including beat calls and jumps.</summary>
        public event Action<string, string> BeatEntered;
        /// <summary>Emitted for every line, before the presenter shows it.</summary>
        public event Action<OrderedMap<object>> LineStarted;
        /// <summary>Emitted when the player continues past a line.</summary>
        public event Action<OrderedMap<object>> LineFinished;
        /// <summary>Emitted before the presenter shows choices.</summary>
        public event Action<List<OrderedMap<object>>> ChoiceStarted;
        /// <summary>Emitted after the player picks an option.</summary>
        public event Action<OrderedMap<object>> ChoiceMade;
        /// <summary>Emitted when a line marked @no_rewind runs.</summary>
        public event Action RewindBarrier;
        /// <summary>Emitted by <c>emit("name", value)</c> in tales.</summary>
        public event Action<string, object> StorySignal;
        /// <summary>Emitted when a tale does something invalid at runtime (message, tale name, line). The tale continues.</summary>
        public event Action<string, string, int> RuntimeError;

        /// <summary>Upper limit of instructions run without showing a line or choice, which stops endless loops.</summary>
        public int MaxStepsWithoutPause = 100000;
        /// <summary>Object that shows lines and choices.</summary>
        public TalePresenter Presenter;
        /// <summary>True while the player is skipping. Actions finish instantly.</summary>
        public bool Skipping;
        /// <summary>Named text styles expanded in every line before it is shown.</summary>
        public Dictionary<string, string> TextStyles = new Dictionary<string, string>();
        /// <summary>When true, lines and choices wait for running actions to finish. A line marked @no_wait never waits.</summary>
        public bool WaitForActions = true;
        /// <summary>Replaces the timer behind <see cref="TaleContext.Wait"/>, for example with a game clock.</summary>
        public Func<double, Task> Waiter;
        /// <summary>Translates text for tr(). Without it, tr() returns its argument.</summary>
        public Func<string, string> Translator;
        /// <summary>Tells collected("id"). Without it, collected() is false.</summary>
        public Func<string, bool> Collected;
        /// <summary>Loads a tale that is not registered yet, such as one from a file.</summary>
        public Func<string, Tale> TaleLoader;
        /// <summary>Resolves names such as cast members. Values may implement <see cref="ITaleSpeaker"/>, <see cref="TaleExposed"/>, or be plain tale values.</summary>
        public NameResolverDelegate NameResolver;
        /// <summary>Constants such as Color.RED.</summary>
        public TypeConstantDelegate TypeConstants;
        /// <summary>Builds Vector2(...), Color(...), and similar. Receives the type name and arguments; may throw to reject them.</summary>
        public Func<string, List<object>, object> ValueConstructor;
        /// <summary>Adds the host's cast members and other names to the context built by <see cref="MakeCheckContext"/>.</summary>
        public Action<TaleCheckContext> ContextExtender;
        /// <summary>Names that tales may use without a registered object, as declared by the host.</summary>
        public List<string> DeclaredNames = new List<string>();
        /// <summary>Random numbers for randf(), randi(), and friends.</summary>
        public Random Random = new Random();

        private readonly Dictionary<string, Tale> _tales = new Dictionary<string, Tale>();
        private readonly Dictionary<string, Dictionary<string, object>> _storyVars = new Dictionary<string, Dictionary<string, object>>();
        private readonly Dictionary<string, object> _globalVars = new Dictionary<string, object>();
        private readonly Dictionary<string, HashSet<string>> _constants = new Dictionary<string, HashSet<string>>();
        private readonly Dictionary<string, TaleAction> _actions = new Dictionary<string, TaleAction>();
        private readonly Dictionary<string, object> _exposed = new Dictionary<string, object>();
        private readonly Dictionary<string, object> _namedConstants = new Dictionary<string, object>();
        private readonly HashSet<string> _visited = new HashSet<string>();
        private readonly HashSet<string> _onceChosen = new HashSet<string>();
        private readonly HashSet<string> _readLines = new HashSet<string>();
        private readonly List<TaleFrame> _stack = new List<TaleFrame>();
        private readonly List<ITaleStateProvider> _stateProviders = new List<ITaleStateProvider>();
        private readonly List<TaleTask> _pending = new List<TaleTask>();
        private readonly TaleEvaluator _evaluator;
        private readonly TaleContext _context;
        private bool _playing;
        private string _currentTale = "";
        private int _currentLine;
        private int _generation;
        private int _linePc = -1;
        private TaskCompletionSource<bool> _finished = new TaskCompletionSource<bool>();

        public TaleDirector()
        {
            _evaluator = new TaleEvaluator(this);
            _context = new TaleContext(this);
            AddAction(new EmitAction());
            AddAction(new WaitAction());
        }

        /// <summary>Beats entered and choice options seen and picked, kept across playthroughs for a route chart. Saved by <see cref="CaptureGlobals"/>.</summary>
        public readonly TaleRouteLog Routes = new TaleRouteLog();

        public bool IsPlaying { get { return _playing; } }

        // --- Public API ---------------------------------------------------------

        /// <summary>Stops playback and forgets story variables, visited beats, and chosen options. Global variables stay.</summary>
        public void Clear()
        {
            Stop();
            _storyVars.Clear();
            _constants.Clear();
            _visited.Clear();
            _onceChosen.Clear();
        }

        /// <summary>
        /// Plays a tale from a beat. The returned task completes when the story finishes or
        /// is stopped.
        /// </summary>
        public async Task Play(string taleName, string beat = "start")
        {
            Stop();
            int generation = _generation;
            Tale tale = GetTale(taleName);
            if (tale == null)
            {
                Report("Tale '" + taleName + "' was not found.", taleName, 0);
                return;
            }
            if (tale.GetBeatStart(beat) < 0)
            {
                Report("Tale '" + taleName + "' has no beat '" + beat + "'.", taleName, 0);
                return;
            }
            await PrepareTale(tale);
            if (generation != _generation) return;
            _stack.Add(EnterBeat(tale, beat));
            _playing = true;
            _finished = new TaskCompletionSource<bool>();
            Task finished = _finished.Task;
            if (StoryStarted != null) StoryStarted(taleName, beat);
            Task run = RunLoop(generation);
            if (_playing) await finished;
            else await run;
        }

        /// <summary>Stops playback. A <see cref="Play"/> in progress completes.</summary>
        public void Stop()
        {
            Halt();
            EndStory();
        }

        /// <summary>Registers a compiled tale, replacing one with the same name.</summary>
        public void AddTale(Tale tale)
        {
            _tales[tale.TaleName] = tale;
        }

        /// <summary>Returns the tale with the given name, asking <see cref="TaleLoader"/> when needed, or null.</summary>
        public Tale GetTale(string taleName)
        {
            Tale tale;
            if (_tales.TryGetValue(taleName, out tale)) return tale;
            if (TaleLoader == null) return null;
            tale = TaleLoader(taleName);
            if (tale != null) _tales[taleName] = tale;
            return tale;
        }

        /// <summary>Registers an action so tales can call it.</summary>
        public void AddAction(TaleAction action)
        {
            _actions[action.Name] = action;
        }

        public TaleAction GetAction(string actionName)
        {
            TaleAction action;
            return _actions.TryGetValue(actionName, out action) ? action : null;
        }

        /// <summary>
        /// Makes an object available to tales under a name, limited to the listed methods and
        /// readable and writable properties. Implement <see cref="ITaleObject"/> on the object
        /// to avoid reflection.
        /// </summary>
        public void Expose(string exposedName, object target, IEnumerable<string> methods = null, IEnumerable<string> properties = null)
        {
            _exposed[exposedName] = new TaleExposed(target, methods, properties);
        }

        /// <summary>
        /// Makes a function available to tales. It may return a Task or Task&lt;T&gt;; tales can
        /// await it.
        /// </summary>
        public void ExposeFunction(string functionName, Func<object[], object> function)
        {
            _exposed[functionName] = function;
        }

        /// <summary>Makes a value available to tales as a constant name, such as LEFT.</summary>
        public void SetConstant(string constantName, object value)
        {
            _namedConstants[constantName] = value;
        }

        /// <summary>Returns the value of a story or global variable, or null.</summary>
        public object GetVar(string taleName, string varName)
        {
            object value;
            GetTaleVar(taleName, varName, out value);
            return value;
        }

        /// <summary>Sets a story or global variable. Returns an error message or "".</summary>
        public string SetVar(string taleName, string varName, object value)
        {
            return SetTaleVar(taleName, varName, GdValue.Normalize(value));
        }

        /// <summary>True if a beat has run, by tale name and beat name.</summary>
        public bool IsVisited(string taleName, string beat)
        {
            return _visited.Contains(taleName + "." + beat);
        }

        /// <summary>True if the player has seen the line with this id.</summary>
        public bool IsLineRead(string lineId)
        {
            return _readLines.Contains(lineId);
        }

        /// <summary>Builds a <see cref="TaleCheckContext"/> from the registered actions, exposed names, and loaded tales.</summary>
        public TaleCheckContext MakeCheckContext(string taleName = "")
        {
            var context = new TaleCheckContext();
            context.TaleName = taleName;
            foreach (var pair in _actions)
                context.AddAction(pair.Key, pair.Value.Parameters, pair.Value.Required);
            foreach (string exposedName in _exposed.Keys)
                context.AddExposed(exposedName);
            foreach (string declared in DeclaredNames)
                context.AddExposed(declared);
            if (ContextExtender != null) ContextExtender(context);
            foreach (var pair in _tales)
            {
                var vars = new List<string>();
                foreach (var variable in pair.Value.Variables) vars.Add(variable.Name);
                context.AddTale(pair.Key, pair.Value.Beats.Keys, vars);
            }
            return context;
        }

        /// <summary>Reports a problem with the instruction being run through <see cref="RuntimeError"/>.</summary>
        public void ReportError(string message)
        {
            Report(message, _currentTale, _currentLine);
        }

        /// <summary>Raises <see cref="StorySignal"/>. The emit action calls it.</summary>
        public void RaiseSignal(string signalName, object value)
        {
            if (StorySignal != null) StorySignal(signalName, value);
        }

        // --- Evaluator support --------------------------------------------------

        internal bool ResolveName(string name, TaleFrame frame, out object value)
        {
            if (frame != null)
            {
                if (frame.Locals.TryGetValue(name, out value)) return true;
                if (GetTaleVar(frame.Tale.TaleName, name, out value)) return true;
            }
            if (_namedConstants.TryGetValue(name, out value)) return true;
            switch (name)
            {
                case "PI": value = Math.PI; return true;
                case "TAU": value = Math.PI * 2.0; return true;
                case "INF": value = double.PositiveInfinity; return true;
                case "NAN": value = double.NaN; return true;
            }
            object exposed;
            if (_exposed.TryGetValue(name, out exposed) && exposed is TaleExposed)
            {
                value = exposed;
                return true;
            }
            if (NameResolver != null && NameResolver(name, out value))
            {
                value = GdValue.Normalize(value);
                return true;
            }
            if (GetTale(name) != null)
            {
                value = new TaleNamespace(name);
                return true;
            }
            value = null;
            return false;
        }

        internal bool GetTaleVar(string taleName, string varName, out object value)
        {
            Dictionary<string, object> vars;
            if (_storyVars.TryGetValue(taleName, out vars) && vars.TryGetValue(varName, out value)) return true;
            Tale tale = GetTale(taleName);
            if (tale != null)
            {
                foreach (var variable in tale.Variables)
                {
                    if (variable.Name == varName && variable.IsGlobal)
                    {
                        _globalVars.TryGetValue(varName, out value);
                        return true;
                    }
                }
            }
            value = null;
            return false;
        }

        internal string SetTaleVar(string taleName, string varName, object value)
        {
            HashSet<string> constants;
            if (_constants.TryGetValue(taleName, out constants) && constants.Contains(varName))
                return "Can't assign to the constant '" + varName + "'.";
            Dictionary<string, object> vars;
            if (_storyVars.TryGetValue(taleName, out vars) && vars.ContainsKey(varName))
            {
                vars[varName] = value;
                return "";
            }
            Tale tale = GetTale(taleName);
            if (tale != null)
            {
                foreach (var variable in tale.Variables)
                {
                    if (variable.Name == varName && variable.IsGlobal)
                    {
                        _globalVars[varName] = value;
                        return "";
                    }
                }
            }
            return "Tale '" + taleName + "' has no variable '" + varName + "'.";
        }

        internal string AssignName(string name, object value, TaleFrame frame)
        {
            if (frame.Locals.ContainsKey(name))
            {
                frame.Locals[name] = value;
                return "";
            }
            return SetTaleVar(frame.Tale.TaleName, name, value);
        }

        /// <summary>Calls an action, built-in function, constructor, or exposed function.</summary>
        internal object CallFunction(string name, List<object> args, OrderedMap<object> named, TaleFrame frame)
        {
            object ignored;
            if (frame != null && (frame.Locals.ContainsKey(name) || GetTaleVar(frame.Tale.TaleName, name, out ignored)))
            {
                _evaluator.Fail("'" + name + "' is a variable and can't be called.");
                return null;
            }
            if (frame != null && frame.Tale.GetBeatStart(name) >= 0)
            {
                _evaluator.Fail("Beats can only be called on a line of their own, e.g. " + name + "().");
                return null;
            }
            TaleAction action;
            if (_actions.TryGetValue(name, out action)) return CallAction(action, args, named);
            object exposed;
            if (_exposed.TryGetValue(name, out exposed) && exposed is Func<object[], object>)
            {
                if (!named.IsEmpty)
                {
                    _evaluator.Fail("'" + name + "' does not take named arguments.");
                    return null;
                }
                var function = (Func<object[], object>)exposed;
                object[] values = args.ToArray();
                return StartTask(() => function(values));
            }
            if (!named.IsEmpty)
            {
                _evaluator.Fail("'" + name + "' does not take named arguments.");
                return null;
            }
            return BuiltinFunction(name, args);
        }

        /// <summary>
        /// Starts a host call. Returns its result when it finishes at once, or a
        /// <see cref="TaleTask"/> while it is still running.
        /// </summary>
        internal object StartTask(Func<object> invoke)
        {
            object result;
            try
            {
                result = TaleTask.FromReturn(invoke());
            }
            catch (Exception e)
            {
                _evaluator.Fail(e is GdOpException ? "This can't be called." : e.Message);
                return null;
            }
            var task = result as TaleTask;
            if (task != null && !task.IsDone) _pending.Add(task);
            return result;
        }

        private object CallAction(TaleAction action, List<object> args, OrderedMap<object> named)
        {
            string error;
            object[] values = TaleCalls.Bind(action.Parameters, action.Required, action.Defaults, args, named, action.Name, out error);
            if (error.Length > 0)
            {
                _evaluator.Fail(error);
                return null;
            }
            return StartTask(() => action.RunAsync(_context, values));
        }

        // --- Run loop -----------------------------------------------------------

        private async Task RunLoop(int generation)
        {
            try
            {
                int steps = 0;
                while (generation == _generation && _stack.Count > 0)
                {
                    TaleFrame frame = _stack[_stack.Count - 1];
                    if (frame.Pc < 0 || frame.Pc >= frame.Tale.Instructions.Count)
                    {
                        _stack.RemoveAt(_stack.Count - 1);
                        continue;
                    }
                    TaleInstruction instruction = frame.Tale.Instructions[frame.Pc];
                    frame.Pc++;
                    steps++;
                    if (steps >= MaxStepsWithoutPause)
                    {
                        Report("Stopped after " + steps.ToString(CultureInfo.InvariantCulture)
                            + " steps without showing a line. Is there an endless loop?", frame.Tale.TaleName, instruction.Line);
                        break;
                    }
                    if (instruction.Op == TaleOp.Say || instruction.Op == TaleOp.Choose) steps = 0;
                    _currentTale = frame.Tale.TaleName;
                    _currentLine = instruction.Line;
                    if (instruction.NoRewind && RewindBarrier != null) RewindBarrier();
                    _evaluator.Reset();
                    await Execute(instruction, frame);
                    if (_evaluator.Failed()) Report(_evaluator.Error, frame.Tale.TaleName, instruction.Line);
                }
                if (generation == _generation && _playing) EndStory();
            }
            catch (Exception e)
            {
                if (generation == _generation)
                {
                    Report(e.Message, _currentTale, _currentLine);
                    if (_playing) EndStory();
                }
            }
        }

        private async Task Execute(TaleInstruction instruction, TaleFrame frame)
        {
            switch (instruction.Op)
            {
                case TaleOp.Say:
                    await Say(instruction, frame);
                    break;
                case TaleOp.Eval:
                    if (!await TryTaleBeatCall(instruction.Expr, frame))
                        await _evaluator.Evaluate(instruction.Expr, frame);
                    break;
                case TaleOp.Set:
                {
                    object value = await _evaluator.Evaluate(instruction.Value, frame);
                    if (!_evaluator.Failed())
                        await _evaluator.Assign(instruction.Place, instruction.Assign, value, frame);
                    break;
                }
                case TaleOp.Local:
                {
                    object initial = null;
                    if (instruction.Value != null) initial = await _evaluator.Evaluate(instruction.Value, frame);
                    frame.Locals[instruction.Name] = initial;
                    break;
                }
                case TaleOp.Jump:
                {
                    Tale target = FindTale(instruction.Tale, frame);
                    if (target != null && CheckBeat(target, instruction.Beat))
                    {
                        await PrepareTale(target);
                        _stack[_stack.Count - 1] = EnterBeat(target, instruction.Beat);
                    }
                    break;
                }
                case TaleOp.CallBeat:
                {
                    Tale callee = FindTale(instruction.Tale, frame);
                    if (callee != null && CheckBeat(callee, instruction.Beat))
                    {
                        await PrepareTale(callee);
                        _stack.Add(EnterBeat(callee, instruction.Beat));
                    }
                    break;
                }
                case TaleOp.Return:
                case TaleOp.End:
                    _stack.RemoveAt(_stack.Count - 1);
                    break;
                case TaleOp.Goto:
                    frame.Pc = instruction.Target;
                    break;
                case TaleOp.BranchFalse:
                {
                    object condition = await _evaluator.Evaluate(instruction.Cond, frame);
                    if (!GdValue.Truthy(condition)) frame.Pc = instruction.Target;
                    break;
                }
                case TaleOp.IterBegin:
                {
                    object iterable = await _evaluator.Evaluate(instruction.Iterable, frame);
                    frame.Iterators[instruction.Slot] = new TaleIterator { Items = ToItems(iterable), Index = 0 };
                    break;
                }
                case TaleOp.IterNext:
                {
                    TaleIterator state;
                    if (!frame.Iterators.TryGetValue(instruction.Slot, out state)) state = new TaleIterator();
                    if (state.Index >= state.Items.Count)
                    {
                        frame.Iterators.Remove(instruction.Slot);
                        frame.Pc = instruction.Target;
                    }
                    else
                    {
                        frame.Locals[instruction.Var] = state.Items[state.Index];
                        state.Index++;
                    }
                    break;
                }
                case TaleOp.Match:
                    await Match(instruction, frame);
                    break;
                case TaleOp.Choose:
                    await Choose(instruction, frame);
                    break;
            }
        }

        private async Task Say(TaleInstruction instruction, TaleFrame frame)
        {
            int generation = _generation;
            if (WaitForActions && !instruction.NoWait) await FinishPending();
            var acts = new List<TaleExpr>();
            string text = await Render(instruction.Text, frame, acts);
            text = TaleText.ExpandStyles(text, TextStyles);
            string speaker = instruction.Speaker;
            string speakerName;
            object speakerColor;
            SpeakerInfo(speaker, frame, out speakerName, out speakerColor);
            var line = new OrderedMap<object>();
            line["speaker_id"] = speaker;
            line["speaker_name"] = speakerName;
            line["speaker_color"] = speakerColor;
            line["mood"] = instruction.Mood;
            line["text"] = text;
            line["id"] = instruction.Id;
            line["voice"] = instruction.Voice;
            line["tale"] = frame.Tale.TaleName;
            line["beat"] = frame.Beat;
            line["source_line"] = (long)instruction.Line;
            line["read"] = _readLines.Contains(instruction.Id) || instruction.SkipSafe;
            if (generation != _generation) return;
            _linePc = frame.Pc - 1;
            if (LineStarted != null) LineStarted(line);
            if (Presenter != null) await Presenter.ShowLine(line);
            if (generation == _generation)
            {
                _readLines.Add(instruction.Id);
                _linePc = -1;
                if (LineFinished != null) LineFinished(line);
            }
        }

        private async Task Match(TaleInstruction instruction, TaleFrame frame)
        {
            object subject = await _evaluator.Evaluate(instruction.Subject, frame);
            foreach (var branch in instruction.Branches)
            {
                bool matched = false;
                foreach (var pattern in branch.Patterns)
                {
                    if (pattern == null) matched = true;
                    else matched = GdValue.Equal(subject, await _evaluator.Evaluate(pattern, frame));
                    if (matched) break;
                }
                if (matched && branch.Guard != null)
                    matched = GdValue.Truthy(await _evaluator.Evaluate(branch.Guard, frame));
                if (matched)
                {
                    frame.Pc = branch.Target;
                    return;
                }
            }
            frame.Pc = instruction.EndTarget;
        }

        private async Task Choose(TaleInstruction instruction, TaleFrame frame)
        {
            int generation = _generation;
            if (WaitForActions && !instruction.NoWait) await FinishPending();
            var settings = new OrderedMap<object>();
            foreach (string key in instruction.Args.Keys)
                settings[key] = await _evaluator.Evaluate(instruction.Args[key], frame);
            var shown = new List<OrderedMap<object>>();
            var sources = new List<TaleOption>();
            bool hasEnabled = false;
            foreach (var option in instruction.Options)
            {
                if (option.Once && _onceChosen.Contains(option.Id)) continue;
                bool enabled = true;
                if (option.Cond != null) enabled = GdValue.Truthy(await _evaluator.Evaluate(option.Cond, frame));
                if (!enabled && !option.ShowDisabled) continue;
                var entry = new OrderedMap<object>();
                entry["text"] = await Render(option.Text, frame, null);
                entry["id"] = option.Id;
                entry["enabled"] = enabled;
                entry["picture"] = option.Picture;
                shown.Add(entry);
                sources.Add(option);
                Routes.SeeOption(frame.Tale.TranslationKey(option.Id));
                if (enabled) hasEnabled = true;
            }
            if (!hasEnabled)
            {
                frame.Pc = instruction.TimeoutTarget >= 0 ? instruction.TimeoutTarget : instruction.EndTarget;
                return;
            }
            if (generation != _generation) return;
            _linePc = frame.Pc - 1;
            if (ChoiceStarted != null) ChoiceStarted(shown);
            int picked = 0;
            if (Presenter != null) picked = await Presenter.Choose(shown, settings);
            if (generation != _generation) return;
            _linePc = -1;
            if (picked < 0 || picked >= shown.Count || !(bool)shown[picked]["enabled"])
            {
                frame.Pc = instruction.TimeoutTarget >= 0 ? instruction.TimeoutTarget : instruction.EndTarget;
                return;
            }
            TaleOption chosen = sources[picked];
            if (chosen.Once) _onceChosen.Add(chosen.Id);
            Routes.PickOption(frame.Tale.TranslationKey(chosen.Id));
            if (ChoiceMade != null) ChoiceMade(shown[picked]);
            frame.Pc = chosen.Target;
        }

        // --- Helpers ------------------------------------------------------------

        private void Halt()
        {
            _generation++;
            _stack.Clear();
            _pending.Clear();
            _linePc = -1;
            if (Presenter != null) Presenter.Cancel();
        }

        private void EndStory()
        {
            if (!_playing) return;
            _playing = false;
            if (StoryFinished != null) StoryFinished();
            _finished.TrySetResult(true);
        }

        private TaleFrame EnterBeat(Tale tale, string beat)
        {
            string beatId = tale.TaleName + "." + beat;
            _visited.Add(beatId);
            TaleFrame from = _stack.Count > 0 ? _stack[_stack.Count - 1] : null;
            Routes.Enter(beatId, from != null ? from.Tale.TaleName + "." + from.Beat : "");
            if (BeatEntered != null) BeatEntered(tale.TaleName, beat);
            return new TaleFrame(tale, beat);
        }

        /// <summary>Gives a tale's story and global variables their initial values the first time it runs.</summary>
        private async Task PrepareTale(Tale tale)
        {
            if (_storyVars.ContainsKey(tale.TaleName)) return;
            var vars = new Dictionary<string, object>();
            var constants = new HashSet<string>();
            _storyVars[tale.TaleName] = vars;
            _constants[tale.TaleName] = constants;
            var frame = new TaleFrame(tale, "");
            foreach (var variable in tale.Variables)
            {
                object value = null;
                if (variable.Value != null)
                {
                    _evaluator.Reset();
                    value = await _evaluator.Evaluate(variable.Value, frame);
                    if (_evaluator.Failed()) Report(_evaluator.Error, tale.TaleName, variable.Line);
                }
                if (variable.IsGlobal)
                {
                    if (!_globalVars.ContainsKey(variable.Name)) _globalVars[variable.Name] = value;
                }
                else
                {
                    vars[variable.Name] = value;
                    if (variable.IsConst) constants.Add(variable.Name);
                }
            }
        }

        private Tale FindTale(string taleName, TaleFrame frame)
        {
            if (taleName.Length == 0) return frame.Tale;
            Tale tale = GetTale(taleName);
            if (tale == null) _evaluator.Fail("Tale '" + taleName + "' was not found.");
            return tale;
        }

        private bool CheckBeat(Tale tale, string beat)
        {
            if (tale.GetBeatStart(beat) >= 0) return true;
            _evaluator.Fail("Tale '" + tale.TaleName + "' has no beat '" + beat + "'.");
            return false;
        }

        /// <summary>Handles "other_tale.beat()" lines that the compiler could not resolve because it did not know the other tale.</summary>
        private async Task<bool> TryTaleBeatCall(TaleExpr expr, TaleFrame frame)
        {
            if (expr.Kind != TaleExprKind.Call || expr.Operands[0].Kind != TaleExprKind.Attribute
                || expr.Operands[0].Operands[0].Kind != TaleExprKind.Identifier)
                return false;
            if (expr.Args.Count > 0 || !expr.NamedArgs.IsEmpty) return false;
            string taleName = expr.Operands[0].Operands[0].Name;
            object ignored;
            if (frame.Locals.ContainsKey(taleName) || GetTaleVar(frame.Tale.TaleName, taleName, out ignored) || _exposed.ContainsKey(taleName))
                return false;
            Tale tale = GetTale(taleName);
            string beat = expr.Operands[0].Name;
            if (tale == null || tale.GetBeatStart(beat) < 0) return false;
            await PrepareTale(tale);
            _stack.Add(EnterBeat(tale, beat));
            return true;
        }

        private async Task FinishPending()
        {
            foreach (var task in _pending.ToArray())
            {
                if (task.IsDone) continue;
                try
                {
                    await task.Wait();
                }
                catch (Exception e)
                {
                    ReportError(e.Message);
                }
            }
            _pending.Clear();
        }

        private object BuiltinFunction(string name, List<object> args)
        {
            int count = args.Count;
            try
            {
                switch (name)
                {
                    case "abs":
                        if (count == 1 && args[0] is long) return (long)args[0] < 0 ? unchecked(-(long)args[0]) : args[0];
                        if (count == 1 && args[0] is double) return Math.Abs((double)args[0]);
                        break;
                    case "ceil":
                        if (count == 1 && GdValue.IsNumber(args[0])) return args[0] is long ? args[0] : Math.Ceiling((double)args[0]);
                        break;
                    case "floor":
                        if (count == 1 && GdValue.IsNumber(args[0])) return args[0] is long ? args[0] : Math.Floor((double)args[0]);
                        break;
                    case "round":
                        if (count == 1 && GdValue.IsNumber(args[0]))
                            return args[0] is long ? args[0] : Math.Round((double)args[0], MidpointRounding.AwayFromZero);
                        break;
                    case "clamp":
                        if (count == 3)
                        {
                            if (GdValue.Relation("<", args[0], args[1])) return args[1];
                            if (GdValue.Relation(">", args[0], args[2])) return args[2];
                            return args[0];
                        }
                        break;
                    case "min":
                    case "max":
                        if (count >= 1)
                        {
                            object best = args[0];
                            foreach (object value in args)
                                if (GdValue.Relation(name == "min" ? "<" : ">", value, best)) best = value;
                            return best;
                        }
                        break;
                    case "randf":
                        if (count == 0) return Random.NextDouble();
                        break;
                    case "randi":
                        if (count == 0) return (long)(Random.NextDouble() * 4294967296.0);
                        break;
                    case "randf_range":
                        if (count == 2 && GdValue.IsNumber(args[0]) && GdValue.IsNumber(args[1]))
                        {
                            double from = GdValue.ToDouble(args[0]), to = GdValue.ToDouble(args[1]);
                            return from + (to - from) * Random.NextDouble();
                        }
                        break;
                    case "randi_range":
                        if (count == 2 && args[0] is long && args[1] is long)
                        {
                            long low = Math.Min((long)args[0], (long)args[1]), high = Math.Max((long)args[0], (long)args[1]);
                            return low + (long)(Random.NextDouble() * (high - low + 1));
                        }
                        break;
                    case "len":
                        if (count == 1 && args[0] is string) return (long)((string)args[0]).Length;
                        if (count == 1 && args[0] is List<object>) return (long)((List<object>)args[0]).Count;
                        if (count == 1 && args[0] is TaleDict) return (long)((TaleDict)args[0]).Count;
                        break;
                    case "str":
                    {
                        var text = new System.Text.StringBuilder();
                        foreach (object value in args) text.Append(GdValue.Str(value));
                        return text.ToString();
                    }
                    case "int":
                        if (count == 1)
                        {
                            if (args[0] is string) return GdFormat.ToInt((string)args[0]);
                            if (args[0] is double d) return double.IsNaN(d) ? 0L : (long)d;
                            if (args[0] is long || args[0] is bool) return GdValue.ToLong(args[0]);
                        }
                        break;
                    case "float":
                        if (count == 1)
                        {
                            if (args[0] is string) return GdFormat.ToFloat((string)args[0]);
                            if (GdValue.IsNumber(args[0])) return GdValue.ToDouble(args[0]);
                            if (args[0] is bool) return (bool)args[0] ? 1.0 : 0.0;
                        }
                        break;
                    case "tr":
                        if (count == 1)
                        {
                            string key = GdValue.Str(args[0]);
                            return Translator != null ? Translator(key) : key;
                        }
                        break;
                    case "visited":
                        if (count == 1) return _visited.Contains(GdValue.Str(args[0]));
                        break;
                    case "collected":
                        if (count == 1) return Collected != null && Collected(GdValue.Str(args[0]));
                        break;
                    case "Vector2":
                    case "Vector2i":
                    case "Vector3":
                    case "Color":
                    case "Rect2":
                        if (ValueConstructor != null)
                        {
                            try
                            {
                                return GdValue.Normalize(ValueConstructor(name, args));
                            }
                            catch (Exception)
                            {
                            }
                        }
                        _evaluator.Fail("Wrong arguments for " + name + "().");
                        return null;
                    default:
                        _evaluator.Fail("Unknown function '" + name + "'.");
                        return null;
                }
            }
            catch (GdOpException)
            {
            }
            _evaluator.Fail("Wrong arguments for '" + name + "'.");
            return null;
        }

        private List<object> ToItems(object value)
        {
            try
            {
                return GdValue.ToItems(value);
            }
            catch (GdOpException)
            {
                _evaluator.Fail("Can't loop over " + GdValue.TypeName(value) + ".");
                return new List<object>();
            }
        }

        /// <summary>Builds the text of a line. Tags become [act=N] and [sound=N] when acts is given; in choice options they are left out.</summary>
        private async Task<string> Render(List<object> parts, TaleFrame frame, List<TaleExpr> acts)
        {
            var text = new System.Text.StringBuilder();
            foreach (object part in parts)
            {
                var literal = part as string;
                if (literal != null)
                {
                    text.Append(literal);
                    continue;
                }
                var tag = part as TaleText.TagPart;
                if (tag != null)
                {
                    if (acts != null)
                    {
                        text.Append('[').Append(tag.Tag).Append('=').Append(acts.Count.ToString(CultureInfo.InvariantCulture)).Append(']');
                        acts.Add(tag.Expr);
                    }
                    continue;
                }
                text.Append(GdValue.Str(await _evaluator.Evaluate((TaleExpr)part, frame)));
            }
            return text.ToString();
        }

        /// <summary>Display name and color for a speaker id.</summary>
        private void SpeakerInfo(string speaker, TaleFrame frame, out string name, out object color)
        {
            color = null;
            if (speaker.Length == 0)
            {
                name = "";
                return;
            }
            object found;
            if (ResolveName(speaker, frame, out found))
            {
                var text = found as string;
                if (text != null)
                {
                    name = Translate(text);
                    return;
                }
                var named = found as ITaleSpeaker;
                if (named != null)
                {
                    name = Translate(named.DisplayName);
                    color = named.NameColor;
                    return;
                }
            }
            name = Translate(GdMethods.Capitalize(speaker));
        }

        private string Translate(string text)
        {
            return Translator != null && text.Length > 0 ? Translator(text) : text;
        }

        private void Report(string message, string taleName, int line)
        {
            if (RuntimeError != null) RuntimeError(message, taleName, line);
        }
    }
}
