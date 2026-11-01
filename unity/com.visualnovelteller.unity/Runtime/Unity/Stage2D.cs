using System.Collections.Generic;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>
    /// A 2D stage drawn with UI Toolkit behind the dialogue: a backdrop and cast members
    /// at stage positions. Tales use the actions <c>backdrop(name, transition, time)</c>
    /// and <c>exit_all(time)</c>, and the cast methods enter, exit, move_to, scale_to, hop,
    /// shake, nod, to_front, and to_back, with the properties mood, display_name, flip, tint,
    /// draw_order, and on_stage.
    /// Positions are fractions of the screen: x runs from 0 (left edge) to 1 (right edge),
    /// and y lifts the character's feet above the bottom of the screen.
    /// </summary>
    public class Stage2D : MonoBehaviour, ITaleStateProvider
    {
        [Tooltip("Optional. A UIDocument to draw on. Left empty, the stage makes its own.")]
        [SerializeField] private UIDocument document;
        [Tooltip("Optional. Left empty, the stage makes panel settings that scale from 1920 by 1080.")]
        [SerializeField] private PanelSettings panelSettings;
        [Tooltip("Panels with a higher number draw in front. The dialogue uses 10.")]
        [SerializeField] private float sortingOrder = -10f;
        [Header("Cast")]
        [Tooltip("How tall a character is, as a percent of the screen height.")]
        [Range(10f, 100f)] [SerializeField] private float castHeightPercent = 92f;
        [Tooltip("How wide a character's box is, as a percent of the screen width.")]
        [Range(10f, 100f)] [SerializeField] private float castWidthPercent = 45f;
        [Tooltip("Dim cast members who are not speaking.")]
        [SerializeField] private bool highlightSpeaker = true;
        [SerializeField] private Color dimColor = new Color(0.55f, 0.55f, 0.6f, 1f);
        [Header("Positions")]
        [SerializeField] private float leftPosition = 0.25f;
        [SerializeField] private float centerPosition = 0.5f;
        [SerializeField] private float rightPosition = 0.75f;

        private const float ReferenceWidth = 1920f;
        private const float ReferenceHeight = 1080f;

        private readonly StoryTweens _tweens = new StoryTweens();
        private Story _story;
        private PanelSettings _createdSettings;
        private VisualElement _stage;
        private Image _back;
        private Image _front;
        private VisualElement _castLayer;
        private Sprite _pendingSprite;
        private Color _pendingColor;
        private bool _pending;
        private int _backdropGeneration;
        private int _useCounter;
        private string _backdropName = "";
        private bool _hasBackdropColor;
        private Color _backdropColor;

        /// <summary>The story this stage belongs to.</summary>
        public Story Story { get { return _story; } }

        /// <summary>Connects the stage to a story and builds its picture. <see cref="Story"/> calls this.</summary>
        public void Attach(Story story)
        {
            if (_story == story) return;
            _story = story;
            BuildUi();
            TaleValues.SetStagePositions(story.Director, leftPosition, centerPosition, rightPosition);
            story.Director.LineStarted += OnLineStarted;
        }

        private void OnDestroy()
        {
            if (_story != null && _story.Director != null) _story.Director.LineStarted -= OnLineStarted;
            if (_createdSettings != null) Destroy(_createdSettings);
        }

        private void Update()
        {
            _tweens.Tick(Time.unscaledDeltaTime, _story != null && _story.Skipping);
        }

        private void BuildUi()
        {
            if (document == null) document = GetComponent<UIDocument>();
            if (document == null)
            {
                if (panelSettings == null)
                {
                    _createdSettings = StoryUI.CreatePanelSettings(_story.Config != null ? _story.Config.ThemeStyleSheet : null, sortingOrder);
                    panelSettings = _createdSettings;
                }
                document = StoryUI.CreateDocument(transform, "Stage2D UI", panelSettings);
            }
            else if (document.panelSettings == null)
            {
                if (panelSettings == null)
                {
                    _createdSettings = StoryUI.CreatePanelSettings(_story.Config != null ? _story.Config.ThemeStyleSheet : null, sortingOrder);
                    panelSettings = _createdSettings;
                }
                document.panelSettings = panelSettings;
            }
            VisualElement root = document.rootVisualElement;
            if (root == null)
            {
                Debug.LogError("Stage2D: the UIDocument has no root element yet. Check that its object is active and has panel settings.", this);
                return;
            }
            StoryUI.Fill(root, false);
            _stage = new VisualElement { name = "vnt-stage" };
            StoryUI.Fill(_stage, false);
            _back = MakeBackdropLayer("vnt-backdrop");
            _front = MakeBackdropLayer("vnt-backdrop-next");
            _front.style.display = DisplayStyle.None;
            _castLayer = new VisualElement { name = "vnt-cast" };
            StoryUI.Fill(_castLayer, false);
            _stage.Add(_back);
            _stage.Add(_front);
            _stage.Add(_castLayer);
            root.Add(_stage);
        }

        private static Image MakeBackdropLayer(string layerName)
        {
            var layer = new Image { name = layerName };
            StoryUI.Fill(layer, false);
            layer.scaleMode = UnityEngine.UIElements.ScaleMode.ScaleAndCrop;
            return layer;
        }

        // --- Backdrop -----------------------------------------------------------

        /// <summary>
        /// Shows a backdrop. The source is a backdrop name from the Story Config, or a Color
        /// for a plain color; Color.TRANSPARENT removes the backdrop. Transitions: none, or
        /// anything else for a fade.
        /// </summary>
        public Task ShowBackdrop(object source, string transition, float time)
        {
            if (_stage == null) return Task.CompletedTask;
            CommitBackdrop();
            Sprite sprite = null;
            Color color = new Color(0f, 0f, 0f, 0f);
            if (source is Color)
            {
                color = (Color)source;
            }
            else
            {
                string backdropName = TaleValues.ToText(source);
                sprite = _story.Config != null ? _story.Config.FindBackdrop(backdropName) : null;
                if (sprite == null)
                {
                    _story.Director.ReportError("Backdrop '" + backdropName + "' was not found in the Story Config.");
                    return Task.CompletedTask;
                }
            }
            bool instant = transition == "none" || _story.Skipping;
            int generation = ++_backdropGeneration;
            RememberBackdrop(source is Color ? null : TaleValues.ToText(source), sprite == null ? color : new Color(0f, 0f, 0f, 0f));
            if (sprite == null && color.a <= 0f)
            {
                return _tweens.Run(time, delegate (float t)
                {
                    if (generation != _backdropGeneration) return;
                    _back.style.opacity = 1f - t;
                    if (t >= 1f)
                    {
                        _back.sprite = null;
                        _back.style.backgroundColor = new Color(0f, 0f, 0f, 0f);
                        _back.style.opacity = 1f;
                    }
                }, instant);
            }
            _pendingSprite = sprite;
            _pendingColor = sprite != null ? new Color(0f, 0f, 0f, 0f) : color;
            _pending = true;
            _front.sprite = sprite;
            _front.style.backgroundColor = _pendingColor;
            _front.style.display = DisplayStyle.Flex;
            return _tweens.Run(time, delegate (float t)
            {
                if (generation != _backdropGeneration) return;
                _front.style.opacity = t;
                if (t >= 1f) CommitBackdrop();
            }, instant);
        }

        private void CommitBackdrop()
        {
            if (!_pending) return;
            _pending = false;
            _back.sprite = _pendingSprite;
            _back.style.backgroundColor = _pendingColor;
            _back.style.opacity = 1f;
            _front.style.display = DisplayStyle.None;
            _front.style.opacity = 0f;
        }

        // --- Cast ---------------------------------------------------------------

        /// <summary>Redraws one cast member from its state.</summary>
        public void Layout(CastActor actor)
        {
            if (actor.View == null) return;
            Image view = actor.View;
            view.style.display = actor.Visible ? DisplayStyle.Flex : DisplayStyle.None;
            Sprite current = actor.CurrentSprite();
            if (view.sprite != current) view.sprite = current;
            view.style.left = Length.Percent(actor.Position.x * 100f);
            view.style.bottom = Length.Percent(actor.Position.y * 100f);
            view.style.opacity = actor.Alpha;
            view.style.translate = new Translate(new Length(actor.OffsetPixels.x, LengthUnit.Pixel), new Length(actor.OffsetPixels.y, LengthUnit.Pixel));
            view.style.scale = new Scale(new Vector3(actor.Flip ? -actor.Scale : actor.Scale, actor.Scale, 1f));
            view.tintColor = actor.Tint * (actor.Highlighted ? Color.white : dimColor);
        }

        private void EnsureView(CastActor actor)
        {
            if (actor.View != null) return;
            var view = new Image { name = "vnt-cast-" + actor.Id };
            view.pickingMode = PickingMode.Ignore;
            view.scaleMode = UnityEngine.UIElements.ScaleMode.ScaleToFit;
            view.style.position = Position.Absolute;
            view.style.width = Length.Percent(castWidthPercent);
            view.style.height = Length.Percent(castHeightPercent);
            view.style.marginLeft = Length.Percent(-castWidthPercent * 0.5f);
            view.style.transformOrigin = new TransformOrigin(Length.Percent(50f), Length.Percent(100f));
            actor.View = view;
            actor.FirstUse = _useCounter++;
            _castLayer.Add(view);
            ReorderCast();
        }

        /// <summary>Puts cast members in drawing order: higher draw_order in front, ties in the order first used.</summary>
        public void ReorderCast()
        {
            if (_story == null || _castLayer == null) return;
            var actors = new List<CastActor>();
            foreach (var actor in _story.Actors)
                if (actor.View != null) actors.Add(actor);
            actors.Sort(delegate (CastActor a, CastActor b)
            {
                int byOrder = a.DrawOrder.CompareTo(b.DrawOrder);
                return byOrder != 0 ? byOrder : a.FirstUse.CompareTo(b.FirstUse);
            });
            foreach (var actor in actors) _castLayer.Remove(actor.View);
            foreach (var actor in actors) _castLayer.Add(actor.View);
        }

        /// <summary>The highest draw_order among cast members.</summary>
        public int HighestOrder()
        {
            int highest = 0;
            foreach (var actor in _story.Actors) if (actor.DrawOrder > highest) highest = actor.DrawOrder;
            return highest;
        }

        /// <summary>The lowest draw_order among cast members.</summary>
        public int LowestOrder()
        {
            int lowest = 0;
            foreach (var actor in _story.Actors) if (actor.DrawOrder < lowest) lowest = actor.DrawOrder;
            return lowest;
        }

        private static bool IsSlide(string transition)
        {
            return transition == "slide_left" || transition == "slide_right";
        }

        private static float SlideX(string transition)
        {
            return transition == "slide_left" ? -0.25f : 1.25f;
        }

        /// <summary>Shows a character. Transitions: fade, slide_left, slide_right, none.</summary>
        public async Task Enter(CastActor actor, string mood, Vector2 at, float time, string transition)
        {
            if (_stage == null) return;
            EnsureView(actor);
            if (!string.IsNullOrEmpty(mood)) actor.SetMood(mood);
            actor.OnStage = true;
            actor.Visible = true;
            bool instant = transition == "none" || _story.Skipping;
            if (IsSlide(transition) && !instant)
            {
                actor.AlphaToken++;
                actor.Alpha = 1f;
                actor.Position = new Vector2(SlideX(transition), at.y);
                Layout(actor);
                await TweenPosition(actor, at, time);
            }
            else
            {
                actor.MoveToken++;
                actor.Position = at;
                actor.Alpha = instant ? 1f : 0f;
                Layout(actor);
                await TweenAlpha(actor, 1f, time);
            }
        }

        /// <summary>Hides a character. Transitions as in <see cref="Enter"/>.</summary>
        public async Task Exit(CastActor actor, float time, string transition)
        {
            if (_stage == null) return;
            actor.OnStage = false;
            if (transition == "none" || _story.Skipping)
            {
                actor.AlphaToken++;
                actor.MoveToken++;
            }
            else if (IsSlide(transition))
            {
                await TweenPosition(actor, new Vector2(SlideX(transition), actor.Position.y), time);
            }
            else
            {
                await TweenAlpha(actor, 0f, time);
            }
            if (!actor.OnStage)
            {
                actor.Visible = false;
                Layout(actor);
            }
        }

        /// <summary>Moves a character to another stage position.</summary>
        public Task MoveTo(CastActor actor, Vector2 at, float time)
        {
            return TweenPosition(actor, at, time);
        }

        /// <summary>Scales a character relative to its configured size.</summary>
        public Task ScaleTo(CastActor actor, float factor, float time)
        {
            float baseScale = actor.Member.scale <= 0f ? 1f : actor.Member.scale;
            int token = ++actor.ScaleToken;
            float from = actor.Scale;
            float to = baseScale * factor;
            return _tweens.Run(time, delegate (float t)
            {
                if (token != actor.ScaleToken) return;
                actor.Scale = Mathf.Lerp(from, to, t);
                Layout(actor);
            }, _story.Skipping);
        }

        /// <summary>Jumps up and lands. The height is a fraction of the screen height.</summary>
        public Task Hop(CastActor actor, float height, float time)
        {
            return Motion(actor, time, delegate (float t)
            {
                return new Vector2(0f, -Mathf.Sin(t * Mathf.PI) * height * ReferenceHeight);
            });
        }

        /// <summary>Shakes from side to side, fading out. Strength 1 moves about 3 percent of the screen width.</summary>
        public Task Shake(CastActor actor, float strength, float time)
        {
            return Motion(actor, time, delegate (float t)
            {
                return new Vector2(Mathf.Sin(t * Mathf.PI * 8f) * (1f - t) * strength * 0.03f * ReferenceWidth, 0f);
            });
        }

        /// <summary>Nods twice.</summary>
        public Task Nod(CastActor actor, float time)
        {
            return Motion(actor, time, delegate (float t)
            {
                return new Vector2(0f, Mathf.Abs(Mathf.Sin(t * Mathf.PI * 2f)) * 0.02f * ReferenceHeight);
            });
        }

        private Task Motion(CastActor actor, float time, System.Func<float, Vector2> offsetAt)
        {
            int token = ++actor.MotionToken;
            return _tweens.Run(time, delegate (float t)
            {
                if (token != actor.MotionToken) return;
                actor.OffsetPixels = t >= 1f ? Vector2.zero : offsetAt(t);
                Layout(actor);
            }, _story.Skipping);
        }

        private Task TweenAlpha(CastActor actor, float to, float time)
        {
            int token = ++actor.AlphaToken;
            float from = actor.Alpha;
            return _tweens.Run(time, delegate (float t)
            {
                if (token != actor.AlphaToken) return;
                actor.Alpha = Mathf.Lerp(from, to, t);
                Layout(actor);
            }, _story.Skipping);
        }

        private Task TweenPosition(CastActor actor, Vector2 to, float time)
        {
            if (_stage == null) return Task.CompletedTask;
            EnsureView(actor);
            int token = ++actor.MoveToken;
            Vector2 from = actor.Position;
            return _tweens.Run(time, delegate (float t)
            {
                if (token != actor.MoveToken) return;
                actor.Position = Vector2.Lerp(from, to, t);
                Layout(actor);
            }, _story.Skipping);
        }

        /// <summary>Every cast member on stage exits.</summary>
        public Task ExitAll(float time)
        {
            var tasks = new List<Task>();
            foreach (var actor in _story.Actors)
                if (actor.OnStage) tasks.Add(Exit(actor, time, "fade"));
            return Task.WhenAll(tasks);
        }

        /// <summary>Removes the backdrop and every cast member at once.</summary>
        public void Clear()
        {
            if (_stage == null) return;
            _backdropGeneration++;
            _tweens.FinishAll();
            _pending = false;
            _back.sprite = null;
            _back.style.backgroundColor = new Color(0f, 0f, 0f, 0f);
            _back.style.opacity = 1f;
            _front.style.display = DisplayStyle.None;
            RememberBackdrop(null, new Color(0f, 0f, 0f, 0f));
            foreach (var actor in _story.Actors)
            {
                actor.OnStage = false;
                actor.Visible = false;
                actor.Alpha = 1f;
                actor.OffsetPixels = Vector2.zero;
                Layout(actor);
            }
        }

        // --- Saves --------------------------------------------------------------

        /// <summary>The key of this stage in a save.</summary>
        public string Name { get { return "Stage"; } }

        private void RememberBackdrop(string backdropName, Color color)
        {
            _backdropName = backdropName ?? "";
            _hasBackdropColor = backdropName == null && color.a > 0f;
            _backdropColor = _hasBackdropColor ? color : new Color(0f, 0f, 0f, 0f);
        }

        /// <summary>
        /// The backdrop and every cast member on stage as plain data: the keys "backdrop"
        /// (a name), "backdrop_color" (r, g, b, a, only for a plain color), and "cast", a
        /// list with id, mood, x, y, flip, tint, scale, and order for each member.
        /// </summary>
        public object Capture()
        {
            var data = new OrderedMap<object>();
            data["backdrop"] = _backdropName;
            if (_hasBackdropColor) data["backdrop_color"] = ColorData(_backdropColor);
            var cast = new List<object>();
            if (_story != null)
            {
                foreach (var actor in _story.Actors)
                {
                    if (!actor.OnStage) continue;
                    var entry = new OrderedMap<object>();
                    entry["id"] = actor.Id;
                    entry["mood"] = actor.Mood;
                    entry["x"] = (double)actor.Position.x;
                    entry["y"] = (double)actor.Position.y;
                    entry["flip"] = actor.Flip;
                    entry["tint"] = ColorData(actor.Tint);
                    entry["scale"] = (double)actor.Scale;
                    entry["order"] = (long)actor.DrawOrder;
                    cast.Add(entry);
                }
            }
            data["cast"] = cast;
            return data;
        }

        /// <summary>Puts the stage back from data made by <see cref="Capture"/>, at once and without fades.</summary>
        public void Restore(object data)
        {
            if (_stage == null || _story == null) return;
            var map = data as OrderedMap<object>;
            _tweens.FinishAll();
            _backdropGeneration++;
            _pending = false;
            _front.style.display = DisplayStyle.None;
            _front.style.opacity = 0f;
            _back.style.opacity = 1f;
            var sprite = default(Sprite);
            var color = new Color(0f, 0f, 0f, 0f);
            string backdropName = map != null ? TextOf(map, "backdrop") : "";
            object value;
            if (backdropName.Length > 0)
            {
                sprite = _story.Config != null ? _story.Config.FindBackdrop(backdropName) : null;
                if (sprite == null) _story.Director.ReportError("Backdrop '" + backdropName + "' was not found in the Story Config.");
            }
            else if (map != null && map.TryGetValue("backdrop_color", out value))
            {
                color = ToColor(value, color);
            }
            _back.sprite = sprite;
            _back.style.backgroundColor = sprite != null ? new Color(0f, 0f, 0f, 0f) : color;
            if (sprite != null) RememberBackdrop(backdropName, color);
            else RememberBackdrop(null, color);

            foreach (var actor in _story.Actors) actor.ResetForRestore();
            var list = map != null && map.TryGetValue("cast", out value) ? value as List<object> : null;
            if (list != null)
            {
                foreach (object item in list)
                {
                    var entry = item as OrderedMap<object>;
                    if (entry == null) continue;
                    CastActor actor = _story.GetActor(TextOf(entry, "id"));
                    if (actor == null) continue;
                    EnsureView(actor);
                    string mood = TextOf(entry, "mood");
                    if (mood.Length > 0) actor.SetMood(mood);
                    actor.OnStage = true;
                    actor.Visible = true;
                    actor.Position = new Vector2((float)NumberOf(entry, "x", 0.5), (float)NumberOf(entry, "y", 0.0));
                    actor.Flip = entry.TryGetValue("flip", out value) && GdValue.Truthy(value);
                    actor.Tint = entry.TryGetValue("tint", out value) ? ToColor(value, Color.white) : Color.white;
                    actor.Scale = (float)NumberOf(entry, "scale", actor.Scale);
                    actor.DrawOrder = (int)NumberOf(entry, "order", 0.0);
                }
            }
            foreach (var actor in _story.Actors) Layout(actor);
            ReorderCast();
        }

        private static OrderedMap<object> ColorData(Color color)
        {
            var data = new OrderedMap<object>();
            data["r"] = (double)color.r;
            data["g"] = (double)color.g;
            data["b"] = (double)color.b;
            data["a"] = (double)color.a;
            return data;
        }

        private static Color ToColor(object value, Color fallback)
        {
            var map = value as OrderedMap<object>;
            if (map == null) return fallback;
            return new Color((float)NumberOf(map, "r", fallback.r), (float)NumberOf(map, "g", fallback.g),
                (float)NumberOf(map, "b", fallback.b), (float)NumberOf(map, "a", fallback.a));
        }

        private static string TextOf(OrderedMap<object> map, string key)
        {
            object value;
            return map.TryGetValue(key, out value) && value != null ? GdValue.Str(value) : "";
        }

        private static double NumberOf(OrderedMap<object> map, string key, double fallback)
        {
            object value;
            return map.TryGetValue(key, out value) && GdValue.IsNumber(value) ? GdValue.ToDouble(value) : fallback;
        }

        private void OnLineStarted(OrderedMap<object> line)
        {
            object value;
            string speaker = line.TryGetValue("speaker_id", out value) && value != null ? GdValue.Str(value) : "";
            string mood = line.TryGetValue("mood", out value) && value != null ? GdValue.Str(value) : "";
            CastActor speaking = speaker.Length > 0 ? _story.GetActor(speaker) : null;
            if (speaking != null && mood.Length > 0) speaking.SetMood(mood);
            foreach (var actor in _story.Actors)
            {
                bool lit = !highlightSpeaker || speaking == null || actor == speaking;
                if (actor.Highlighted == lit) continue;
                actor.Highlighted = lit;
                Layout(actor);
            }
        }
    }
}
