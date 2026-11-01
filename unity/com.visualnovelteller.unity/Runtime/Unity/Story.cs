using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;
using UnityEngine.Events;

namespace VisualNovelTeller
{
    /// <summary>A UnityEvent that carries the name of a tale's <c>emit()</c> and its value as text.</summary>
    [Serializable]
    public class StorySignalEvent : UnityEvent<string, string>
    {
    }

    /// <summary>
    /// The main component of Visual Novel Teller. Put one in a scene with a
    /// <see cref="StoryConfig"/>. It compiles the config's tales, registers the actions
    /// (backdrop, music, sound, and more), connects the dialogue, stage, audio, and shots
    /// components, and plays. Everything runs on Unity's main thread.
    /// </summary>
    [DefaultExecutionOrder(-100)]
    public class Story : MonoBehaviour
    {
        private class TimedWait
        {
            public double Remaining;
            public TaskCompletionSource<bool> Source;
        }

        [SerializeField] private StoryConfig config;
        [Tooltip("Play the config's first tale when the scene starts.")]
        [SerializeField] private bool playOnStart = true;
        [Header("Parts (found in the scene when left empty)")]
        [SerializeField] private DialoguePresenter dialogue;
        [SerializeField] private Stage2D stage;
        [SerializeField] private StoryAudio storyAudio;
        [SerializeField] private StoryShots shots;
        [Header("Events")]
        [Tooltip("Raised by emit(\"name\", value) in a tale. The value arrives as text.")]
        [SerializeField] private StorySignalEvent onSignal = new StorySignalEvent();
        [SerializeField] private UnityEvent onStoryFinished = new UnityEvent();

        private readonly List<TimedWait> _waits = new List<TimedWait>();
        private readonly List<TaskCompletionSource<bool>> _frameWaiters = new List<TaskCompletionSource<bool>>();
        private readonly List<CastActor> _actors = new List<CastActor>();
        private readonly Dictionary<string, CastActor> _actorsById = new Dictionary<string, CastActor>();
        private readonly Dictionary<string, TaleExposed> _actorObjects = new Dictionary<string, TaleExposed>();
        private TaleDirector _director;
        private TaleHistory _history;
        private bool _ready;
        private bool _loading;

        /// <summary>Raised by <c>emit("name", value)</c> in a tale.</summary>
        public event Action<string, object> Signal;

        /// <summary>The settings this story plays with.</summary>
        public StoryConfig Config { get { return config; } set { config = value; } }
        /// <summary>The director that runs the tales. Use it for hooks the Story does not wrap.</summary>
        public TaleDirector Director { get { EnsureDirector(); return _director; } }
        public DialoguePresenter Dialogue { get { return dialogue; } }
        public Stage2D Stage { get { return stage; } }
        public StoryAudio Audio { get { return storyAudio; } }
        public StoryShots Shots { get { return shots; } }
        /// <summary>The cast members of the config, as tales see them.</summary>
        public IEnumerable<CastActor> Actors { get { return _actors; } }

        /// <summary>True while the player skips: waits and fades end at once and lines go by.</summary>
        public bool Skipping
        {
            get { return _director != null && _director.Skipping; }
            set { Director.Skipping = value; }
        }

        /// <summary>True while a tale is playing.</summary>
        public bool IsPlaying { get { return _director != null && _director.IsPlaying; } }

        private void Awake()
        {
            EnsureDirector();
        }

        private void Start()
        {
            EnsureReady();
            LoadGlobals();
            if (playOnStart) _ = Play();
        }

        private void OnDestroy()
        {
            if (_director != null) _director.Stop();
        }

        private void Update()
        {
            if (_frameWaiters.Count > 0)
            {
                var frame = _frameWaiters.ToArray();
                _frameWaiters.Clear();
                foreach (var source in frame) source.TrySetResult(true);
            }
            if (_waits.Count == 0) return;
            bool skipping = Skipping;
            float delta = Time.unscaledDeltaTime;
            List<TimedWait> due = null;
            foreach (var wait in _waits)
            {
                wait.Remaining -= delta;
                if (skipping || wait.Remaining <= 0.0)
                {
                    if (due == null) due = new List<TimedWait>();
                    due.Add(wait);
                }
            }
            if (due == null) return;
            foreach (var wait in due) _waits.Remove(wait);
            foreach (var wait in due) wait.Source.TrySetResult(true);
        }

        // --- Public API ---------------------------------------------------------

        /// <summary>
        /// Plays a tale from a beat. With no tale, plays the config's first tale and beat.
        /// The task completes when the story finishes or stops.
        /// </summary>
        public Task Play(string tale = null, string beat = null)
        {
            EnsureReady();
            if (string.IsNullOrEmpty(tale))
            {
                if (config == null || config.FirstTale == null)
                {
                    Debug.LogError("Story: no tale to play. Give the Story Config a first tale, or call Play with a tale name.", this);
                    return Task.CompletedTask;
                }
                tale = config.FirstTale.TaleName;
                if (string.IsNullOrEmpty(beat)) beat = config.FirstBeat;
            }
            return PlayAsync(tale, string.IsNullOrEmpty(beat) ? "start" : beat);
        }

        /// <summary>Stops the story. A <see cref="Play"/> in progress completes.</summary>
        public void Stop()
        {
            if (_director != null) _director.Stop();
            CompleteWaits();
        }

        /// <summary>
        /// Makes an object available to tales under a name. Without lists, tales may call
        /// the public methods and use the public properties and fields declared on the
        /// object's own class; pass lists to limit them. List the name in the Story Config's
        /// exposed names so the importer knows it.
        /// </summary>
        public void Expose(string exposedName, object target, IEnumerable<string> methods = null, IEnumerable<string> properties = null)
        {
            EnsureDirector();
            if (methods == null && properties == null)
            {
                var foundMethods = new List<string>();
                var foundProperties = new List<string>();
                DeriveMembers(target, foundMethods, foundProperties);
                methods = foundMethods;
                properties = foundProperties;
            }
            _director.Expose(exposedName, target, methods, properties);
        }

        /// <summary>Makes a function available to tales. It may return a Task, which tales can await.</summary>
        public void ExposeFunction(string functionName, Func<object[], object> function)
        {
            Director.ExposeFunction(functionName, function);
        }

        /// <summary>Reads a story or global variable of a tale, or null.</summary>
        public object GetVar(string taleName, string varName)
        {
            return Director.GetVar(taleName, varName);
        }

        /// <summary>Writes a story or global variable of a tale. Returns an error message or "".</summary>
        public string SetVar(string taleName, string varName, object value)
        {
            return Director.SetVar(taleName, varName, value);
        }

        /// <summary>A task that completes after the given seconds, or at once while skipping. Update completes it on the main thread.</summary>
        public Task Wait(double seconds)
        {
            if (seconds <= 0.0 || Skipping) return Task.CompletedTask;
            var wait = new TimedWait { Remaining = seconds, Source = new TaskCompletionSource<bool>() };
            _waits.Add(wait);
            return wait.Source.Task;
        }

        /// <summary>A task that completes in the next Update on the main thread.</summary>
        public Task NextFrame()
        {
            var source = new TaskCompletionSource<bool>();
            _frameWaiters.Add(source);
            return source.Task;
        }

        /// <summary>The cast member with this id, or null.</summary>
        public CastActor GetActor(string id)
        {
            CastActor actor;
            return _actorsById.TryGetValue(id, out actor) ? actor : null;
        }

        // --- Saves and rewind ---------------------------------------------------

        /// <summary>
        /// The whole story state as JSON text: where the story is, its variables, and the
        /// stage, audio, and shots. Pass it to <see cref="LoadFromJson"/> later.
        /// </summary>
        public string SaveToJson()
        {
            EnsureReady();
            return GdJson.Stringify(_director.Capture());
        }

        /// <summary>
        /// Stops the current play, puts the story back as <see cref="SaveToJson"/> saved it, and
        /// plays on. The task completes when the story ends. Bad data is reported and nothing changes.
        /// </summary>
        public async Task LoadFromJson(string json)
        {
            EnsureReady();
            OrderedMap<object> data = ParseSave(json);
            if (data == null) return;
            _loading = true;
            try
            {
                Stop();
            }
            finally
            {
                _loading = false;
            }
            try
            {
                _director.Restore(data);
                if (_history != null) _history.Clear();
                await _director.Resume();
            }
            catch (Exception e)
            {
                Debug.LogError("Story: could not load the save. " + e.Message, this);
                Debug.LogException(e, this);
            }
        }

        /// <summary>Writes the story state to saves/slot.json in the persistent data folder, and the globals to saves/globals.json. A slot name has letters, digits, '-', and '_'.</summary>
        public void SaveSlot(string slot)
        {
            if (!CheckSlot(slot)) return;
            EnsureReady();
            if (!_director.IsPlaying)
            {
                Debug.LogWarning("Story: nothing to save, no tale is playing.", this);
                return;
            }
            try
            {
                Directory.CreateDirectory(SaveFolder());
                WriteText(SlotPath(slot), SaveToJson());
                WriteText(GlobalsPath(), GdJson.Stringify(_director.CaptureGlobals()));
            }
            catch (Exception e)
            {
                Debug.LogError("Story: could not save slot '" + slot + "'. " + e.Message, this);
            }
        }

        /// <summary>Loads a slot written by <see cref="SaveSlot"/> and plays on. The task completes when the story ends.</summary>
        public Task LoadSlot(string slot)
        {
            if (!CheckSlot(slot)) return Task.CompletedTask;
            string path = SlotPath(slot);
            string json;
            try
            {
                if (!File.Exists(path))
                {
                    Debug.LogWarning("Story: there is no save in slot '" + slot + "'.", this);
                    return Task.CompletedTask;
                }
                json = File.ReadAllText(path, Encoding.UTF8);
            }
            catch (Exception e)
            {
                Debug.LogError("Story: could not read slot '" + slot + "'. " + e.Message, this);
                return Task.CompletedTask;
            }
            return LoadFromJson(json);
        }

        /// <summary>True when the slot has a save.</summary>
        public bool HasSlot(string slot)
        {
            if (!IsValidSlot(slot)) return false;
            try
            {
                return File.Exists(SlotPath(slot));
            }
            catch (Exception)
            {
                return false;
            }
        }

        /// <summary>Deletes the save in a slot, if there is one.</summary>
        public void DeleteSlot(string slot)
        {
            if (!CheckSlot(slot)) return;
            try
            {
                string path = SlotPath(slot);
                if (File.Exists(path)) File.Delete(path);
            }
            catch (Exception e)
            {
                Debug.LogError("Story: could not delete slot '" + slot + "'. " + e.Message, this);
            }
        }

        /// <summary>True when the player can step back at least one line or choice.</summary>
        public bool CanRewind { get { return _history != null && _history.CanRewind; } }

        /// <summary>
        /// Goes back that many lines or choices and plays on from there. Returns false when
        /// that many steps are not available or rewind is off in the Story Config.
        /// </summary>
        public Task<bool> Rewind(int steps = 1)
        {
            if (_history == null || steps < 1 || !_history.CanRewind || steps > _history.AvailableSteps)
                return Task.FromResult(false);
            // Waits of the abandoned run end now. The history restores the story, which
            // cancels the line or choice on screen, and resumes play itself.
            CompleteWaits();
            return Task.FromResult(_history.Rewind(steps));
        }

        private OrderedMap<object> ParseSave(string json)
        {
            if (string.IsNullOrEmpty(json))
            {
                Debug.LogError("Story: could not load the save. The text is empty.", this);
                return null;
            }
            OrderedMap<object> data;
            try
            {
                data = GdJson.Parse(json) as OrderedMap<object>;
            }
            catch (Exception e)
            {
                Debug.LogError("Story: could not load the save. It is not valid JSON. " + e.Message, this);
                return null;
            }
            object value;
            if (data == null || !data.TryGetValue("stack", out value) || !(value is List<object>)
                || !data.TryGetValue("format", out value) || !GdValue.IsNumber(value) || GdValue.ToLong(value) != TaleDirector.StateFormat)
            {
                Debug.LogError("Story: could not load the save. It is not story save data, or it comes from another version.", this);
                return null;
            }
            return data;
        }

        private void LoadGlobals()
        {
            string path = GlobalsPath();
            try
            {
                if (!File.Exists(path)) return;
                var data = GdJson.Parse(File.ReadAllText(path, Encoding.UTF8)) as OrderedMap<object>;
                if (data != null) _director.RestoreGlobals(data);
            }
            catch (Exception e)
            {
                Debug.LogError("Story: could not read " + path + ". " + e.Message, this);
            }
        }

        private bool CheckSlot(string slot)
        {
            if (IsValidSlot(slot)) return true;
            Debug.LogError("Story: '" + slot + "' is not a save slot name. Use letters, digits, '-', and '_'.", this);
            return false;
        }

        private static bool IsValidSlot(string slot)
        {
            if (string.IsNullOrEmpty(slot)) return false;
            foreach (char c in slot)
            {
                bool letter = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
                if (!letter && !(c >= '0' && c <= '9') && c != '-' && c != '_') return false;
            }
            return true;
        }

        private static string SaveFolder()
        {
            return Path.Combine(Application.persistentDataPath, "saves");
        }

        private static string SlotPath(string slot)
        {
            return Path.Combine(SaveFolder(), slot + ".json");
        }

        private static string GlobalsPath()
        {
            return Path.Combine(SaveFolder(), "globals.json");
        }

        private static void WriteText(string path, string text)
        {
            string temp = path + ".tmp";
            File.WriteAllText(temp, text, new UTF8Encoding(false));
            if (File.Exists(path)) File.Delete(path);
            File.Move(temp, path);
        }

        // --- Setup --------------------------------------------------------------

        private async Task PlayAsync(string tale, string beat)
        {
            try
            {
                await _director.Play(tale, beat);
            }
            catch (Exception e)
            {
                Debug.LogException(e, this);
            }
        }

        private void EnsureDirector()
        {
            if (_director != null) return;
            _director = new TaleDirector();
            _director.Waiter = Wait;
            _director.RuntimeError += OnRuntimeError;
            _director.StorySignal += OnSignal;
            _director.StoryFinished += OnStoryFinished;
            _director.NameResolver = ResolveName;
            _director.ContextExtender = ExtendContext;
            _director.TextStyles["whisper"] = "[i][color=#b4b9c8]";
            _director.TextStyles["shout"] = "[b][font_size=44]";
            _director.TextStyles["thought"] = "[i][color=#9fc4e8]";
            TaleValues.Install(_director);
            StoryActions.Register(_director, this);
            BuildActors();
        }

        private void EnsureReady()
        {
            if (_ready) return;
            _ready = true;
            EnsureDirector();
            FindParts();
            if (dialogue != null)
            {
                dialogue.Attach(this);
                _director.Presenter = dialogue.Presenter;
            }
            if (stage != null)
            {
                stage.Attach(this);
                _director.AddStateProvider(stage);
            }
            if (storyAudio != null)
            {
                storyAudio.Attach(this);
                _director.AddStateProvider(storyAudio);
            }
            if (shots != null)
            {
                shots.Attach(this);
                _director.AddStateProvider(shots);
                Expose("shots", shots, new[] { "play", "hold", "has_shot" }, new[] { "current" });
            }
            LoadTales();
            if (config != null && config.RewindDepth > 0) _history = new TaleHistory(_director, config.RewindDepth);
        }

        private void FindParts()
        {
            if (dialogue == null) dialogue = GetComponentInChildren<DialoguePresenter>();
            if (dialogue == null) dialogue = FindFirstObjectByType<DialoguePresenter>();
            if (dialogue == null) dialogue = gameObject.AddComponent<DialoguePresenter>();
            if (stage == null) stage = GetComponentInChildren<Stage2D>();
            if (stage == null) stage = FindFirstObjectByType<Stage2D>();
            if (stage == null && config != null && (config.Cast.Count > 0 || config.Backdrops.Count > 0))
                stage = gameObject.AddComponent<Stage2D>();
            if (storyAudio == null) storyAudio = GetComponentInChildren<StoryAudio>();
            if (storyAudio == null) storyAudio = FindFirstObjectByType<StoryAudio>();
            if (storyAudio == null && config != null && config.AudioClips.Count > 0)
                storyAudio = gameObject.AddComponent<StoryAudio>();
            if (shots == null) shots = GetComponentInChildren<StoryShots>();
            if (shots == null) shots = FindFirstObjectByType<StoryShots>();
        }

        private void BuildActors()
        {
            _actors.Clear();
            _actorsById.Clear();
            _actorObjects.Clear();
            if (config == null) return;
            foreach (var member in config.Cast)
            {
                if (member == null || string.IsNullOrEmpty(member.id) || _actorsById.ContainsKey(member.id)) continue;
                var actor = new CastActor(this, member);
                _actors.Add(actor);
                _actorsById[member.id] = actor;
                _actorObjects[member.id] = actor.MakeExposed();
            }
        }

        private void LoadTales()
        {
            if (config == null) return;
            foreach (var asset in config.Tales)
            {
                if (asset == null) continue;
                TaleBuildResult result = asset.Build(_director.MakeCheckContext(asset.TaleName));
                foreach (var problem in result.Diagnostics)
                {
                    string text = asset.name + ".tale:" + problem.Line + ": " + problem.Message;
                    if (problem.IsError()) Debug.LogError(text, asset);
                    else Debug.LogWarning(text, asset);
                }
                if (result.Tale != null) _director.AddTale(result.Tale);
            }
        }

        private bool ResolveName(string name, out object value)
        {
            TaleExposed found;
            if (_actorObjects.TryGetValue(name, out found))
            {
                value = found;
                return true;
            }
            value = null;
            return false;
        }

        private void ExtendContext(TaleCheckContext context)
        {
            if (config != null) config.AddTo(context, context.TaleName);
            else context.AddExposed("shots");
        }

        private static void DeriveMembers(object target, List<string> methods, List<string> properties)
        {
            if (target == null) return;
            const BindingFlags flags = BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly;
            Type type = target.GetType();
            foreach (MethodInfo method in type.GetMethods(flags))
                if (!method.IsSpecialName && !methods.Contains(method.Name)) methods.Add(method.Name);
            foreach (PropertyInfo property in type.GetProperties(flags))
                if (!properties.Contains(property.Name)) properties.Add(property.Name);
            foreach (FieldInfo field in type.GetFields(flags))
                if (!properties.Contains(field.Name)) properties.Add(field.Name);
        }

        // --- Events -------------------------------------------------------------

        private void OnRuntimeError(string message, string taleName, int line)
        {
            Debug.LogError(taleName + ":" + line + ": " + message, this);
        }

        private void OnSignal(string signalName, object value)
        {
            if (Signal != null) Signal(signalName, value);
            if (onSignal != null) onSignal.Invoke(signalName, value == null ? "" : GdValue.Str(value));
        }

        private void OnStoryFinished()
        {
            if (_loading) return;
            if (dialogue != null) dialogue.Hide();
            if (onStoryFinished != null) onStoryFinished.Invoke();
        }

        private void CompleteWaits()
        {
            var waits = _waits.ToArray();
            _waits.Clear();
            foreach (var wait in waits) wait.Source.TrySetResult(true);
            var frame = _frameWaiters.ToArray();
            _frameWaiters.Clear();
            foreach (var source in frame) source.TrySetResult(true);
        }
    }
}
