using System.Collections.Generic;
using System.Threading.Tasks;

namespace TaleScript
{
    public partial class TaleDirector
    {
        /// <summary>Version of the data returned by <see cref="Capture"/>.</summary>
        public const int StateFormat = 1;

        /// <summary>
        /// Adds host state, such as a stage or audio, to every <see cref="Capture"/> and hands it
        /// back in <see cref="Restore"/>. A provider with the same name replaces the earlier one.
        /// </summary>
        public void AddStateProvider(ITaleStateProvider provider)
        {
            RemoveStateProvider(provider.Name);
            _stateProviders.Add(provider);
        }

        public void RemoveStateProvider(string providerName)
        {
            _stateProviders.RemoveAll(p => p.Name == providerName);
        }

        /// <summary>
        /// The state of the story as plain data (<see cref="OrderedMap{TValue}"/>, <c>List&lt;object&gt;</c>,
        /// string, long, double, bool, null) that <see cref="GdJson.Stringify"/> writes and
        /// <see cref="GdJson.Parse"/> reads back. Host state from the registered providers is
        /// under "crew", keyed by provider name.
        /// </summary>
        public OrderedMap<object> Capture()
        {
            var frames = new List<object>();
            for (int i = 0; i < _stack.Count; i++)
            {
                TaleFrame frame = _stack[i];
                bool top = i == _stack.Count - 1;
                var iterators = new OrderedMap<object>();
                var slots = new List<string>(frame.Iterators.Keys);
                slots.Sort(string.CompareOrdinal);
                foreach (string slot in slots)
                {
                    TaleIterator state = frame.Iterators[slot];
                    var entry = new OrderedMap<object>();
                    entry["items"] = TaleStateCodec.Encode(state.Items);
                    entry["index"] = (long)state.Index;
                    iterators[slot] = entry;
                }
                var saved = new OrderedMap<object>();
                saved["tale"] = frame.Tale.TaleName;
                saved["beat"] = frame.Beat;
                saved["pc"] = (long)(top && _linePc >= 0 ? _linePc : frame.Pc);
                saved["locals"] = TaleStateCodec.EncodeMap(frame.Locals);
                saved["iterators"] = iterators;
                frames.Add(saved);
            }
            var vars = new OrderedMap<object>();
            var taleNames = new List<string>(_storyVars.Keys);
            taleNames.Sort(string.CompareOrdinal);
            foreach (string taleName in taleNames) vars[taleName] = TaleStateCodec.EncodeMap(_storyVars[taleName]);
            var crew = new OrderedMap<object>();
            foreach (ITaleStateProvider provider in _stateProviders) crew[provider.Name] = provider.Capture();
            var state2 = new OrderedMap<object>();
            state2["format"] = (long)StateFormat;
            state2["stack"] = frames;
            state2["vars"] = vars;
            state2["visited"] = TaleStateCodec.SortedList(_visited);
            state2["once"] = TaleStateCodec.SortedList(_onceChosen);
            state2["crew"] = crew;
            return state2;
        }

        /// <summary>
        /// Replaces the story state with data from <see cref="Capture"/>. Call <see cref="Resume"/>
        /// afterwards to continue. A <see cref="Play"/> in progress keeps waiting and completes when
        /// the restored story ends.
        /// </summary>
        public void Restore(OrderedMap<object> data)
        {
            Halt();
            _playing = false;
            _storyVars.Clear();
            _constants.Clear();
            object value;
            var vars = data.TryGetValue("vars", out value) ? value as OrderedMap<object> : null;
            if (vars != null)
            {
                foreach (string taleName in vars.Keys)
                {
                    _storyVars[taleName] = TaleStateCodec.DecodeMap(vars[taleName]);
                    var constants = new HashSet<string>();
                    _constants[taleName] = constants;
                    Tale known = GetTale(taleName);
                    if (known == null) continue;
                    foreach (var variable in known.Variables)
                        if (variable.IsConst && !variable.IsGlobal) constants.Add(variable.Name);
                }
            }
            _visited.Clear();
            foreach (string key in TaleRouteLog.Strings(data, "visited")) _visited.Add(key);
            _onceChosen.Clear();
            foreach (string key in TaleRouteLog.Strings(data, "once")) _onceChosen.Add(key);
            var stack = data.TryGetValue("stack", out value) ? value as List<object> : null;
            if (stack != null)
            {
                foreach (object item in stack)
                {
                    var saved = item as OrderedMap<object>;
                    if (saved == null) continue;
                    string taleName = GdValue.Str(saved["tale"]);
                    Tale tale = GetTale(taleName);
                    if (tale == null)
                    {
                        Report("Can't restore: tale '" + taleName + "' is missing.", taleName, 0);
                        _stack.Clear();
                        return;
                    }
                    var frame = new TaleFrame(tale, GdValue.Str(saved["beat"]));
                    frame.Pc = (int)GdValue.ToLong(saved["pc"]);
                    frame.Locals = TaleStateCodec.DecodeMap(Field(saved, "locals"));
                    var iterators = Field(saved, "iterators") as OrderedMap<object>;
                    if (iterators != null)
                    {
                        foreach (string slot in iterators.Keys)
                        {
                            var entry = iterators[slot] as OrderedMap<object>;
                            if (entry == null) continue;
                            var state = new TaleIterator();
                            state.Items = TaleStateCodec.Decode(Field(entry, "items")) as List<object> ?? new List<object>();
                            state.Index = (int)GdValue.ToLong(Field(entry, "index") ?? 0L);
                            frame.Iterators[slot] = state;
                        }
                    }
                    _stack.Add(frame);
                }
            }
            var crew = data.TryGetValue("crew", out value) ? value as OrderedMap<object> : null;
            if (crew != null)
            {
                foreach (string providerName in crew.Keys)
                {
                    ITaleStateProvider found = _stateProviders.Find(p => p.Name == providerName);
                    if (found == null)
                    {
                        Report("Can't restore: no state provider '" + providerName + "'.", "", 0);
                        continue;
                    }
                    found.Restore(crew[providerName]);
                }
            }
        }

        /// <summary>
        /// Continues playback from a restored state. The task completes when the story ends.
        /// A line or choice that was showing when the state was captured appears again.
        /// </summary>
        public async Task Resume()
        {
            if (_stack.Count == 0 || _playing) return;
            _generation++;
            int generation = _generation;
            _playing = true;
            if (_finished.Task.IsCompleted) _finished = new TaskCompletionSource<bool>();
            Task finished = _finished.Task;
            Task run = RunLoop(generation);
            if (_playing) await finished;
            else await run;
        }

        /// <summary>
        /// Data kept across playthroughs: global variables, read lines, and the routes explored.
        /// Save it apart from the save slots.
        /// </summary>
        public OrderedMap<object> CaptureGlobals()
        {
            var result = new OrderedMap<object>();
            result["vars"] = TaleStateCodec.EncodeMap(_globalVars);
            result["read"] = TaleStateCodec.SortedList(_readLines);
            result["routes"] = Routes.ToDict();
            return result;
        }

        public void RestoreGlobals(OrderedMap<object> data)
        {
            object value;
            _globalVars.Clear();
            foreach (var pair in TaleStateCodec.DecodeMap(data.TryGetValue("vars", out value) ? value : null))
                _globalVars[pair.Key] = pair.Value;
            _readLines.Clear();
            foreach (string id in TaleRouteLog.Strings(data, "read")) _readLines.Add(id);
            Routes.FromDict(data.TryGetValue("routes", out value) ? value as OrderedMap<object> : null);
        }

        private static object Field(OrderedMap<object> map, string key)
        {
            object value;
            return map.TryGetValue(key, out value) ? value : null;
        }
    }
}
