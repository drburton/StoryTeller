using System.Collections.Generic;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>
    /// Whole-screen effects drawn with UI Toolkit: weather, color filters, flashes, screen
    /// fades, and screen shake. Tales use <c>fade_out(color, time)</c>, <c>fade_in(time)</c>,
    /// <c>flash(color, time)</c>, <c>shake(strength, time)</c>, <c>filter(name, strength, time)</c>,
    /// and <c>weather(kind, strength, fade)</c>, with the names and defaults of the Godot version.
    /// Weather and filters draw above the stage and below the dialogue. Flashes and screen
    /// fades also cover the dialogue. Neither panel takes clicks.
    /// UI Toolkit has no screen shaders, so the filters are overlays. Sepia, night, warm, and
    /// cold tint the picture with a translucent color. Grayscale is an approximation: it draws a
    /// gray layer over the picture, which lowers the contrast and the color but leaves some
    /// color behind. Blur is not available yet and only logs a warning.
    /// </summary>
    public class StoryEffects : MonoBehaviour, ITaleStateProvider
    {
        [Tooltip("Optional. Left empty, the effects make panel settings that scale from 1920 by 1080.")]
        [SerializeField] private PanelSettings panelSettings;
        [Tooltip("Panel order of weather and filters. The stage uses -10 and the dialogue 10.")]
        [SerializeField] private float lowerSortingOrder = 0f;
        [Tooltip("Panel order of flashes and screen fades. The dialogue uses 10 and the menus 20.")]
        [SerializeField] private float screenSortingOrder = 15f;

        private static readonly string[] WeatherKinds = { "none", "rain", "snow" };
        private static readonly string[] Filters = { "none", "grayscale", "sepia", "night", "warm", "cold", "blur", "vignette" };

        private readonly StoryTweens _tweens = new StoryTweens();
        private readonly List<WeatherView> _weatherViews = new List<WeatherView>();
        private Story _story;
        private PanelSettings _lowerSettings;
        private PanelSettings _screenSettings;
        private VisualElement _lowerContent;
        private VisualElement _weatherHost;
        private VisualElement _filterOverlay;
        private Image _vignette;
        private Texture2D _vignetteTexture;
        private VisualElement _curtain;
        private VisualElement _flash;

        private WeatherView _weather;
        private string _weatherKind = "none";
        private float _weatherStrength = 1f;

        private string _filterName = "none";
        private float _filterStrength = 1f;
        private string _filterShown = "none";
        private float _filterLevel;
        private int _filterToken;
        private bool _warnedBlur;

        private Color _curtainColor = new Color(0f, 0f, 0f, 1f);
        private float _curtainAlpha;
        private int _curtainToken;
        private int _flashToken;

        private float _shakeLeft;
        private float _shakeStrength;
        private TaskCompletionSource<bool> _shakeDone;

        /// <summary>The weather kind that runs: "rain", "snow", or "none".</summary>
        public string Weather { get { return _weatherKind; } }

        /// <summary>The filter that is set: a name such as "sepia", or "none".</summary>
        public string Filter { get { return _filterName; } }

        /// <summary>True while the screen is faded out to a color.</summary>
        public bool IsFadedOut { get { return _curtainAlpha > 0f; } }

        /// <summary>Connects the effects to a story and builds their panels. <see cref="Story"/> calls this.</summary>
        public void Attach(Story story)
        {
            if (_story == story) return;
            _story = story;
            BuildUi();
        }

        private void OnDestroy()
        {
            if (_lowerSettings != null) Destroy(_lowerSettings);
            if (_screenSettings != null) Destroy(_screenSettings);
            if (_vignetteTexture != null) Destroy(_vignetteTexture);
        }

        private void BuildUi()
        {
            ThemeStyleSheet theme = _story.Config != null ? _story.Config.ThemeStyleSheet : null;
            PanelSettings lower = panelSettings;
            if (lower == null)
            {
                _lowerSettings = StoryUI.CreatePanelSettings(theme, lowerSortingOrder);
                lower = _lowerSettings;
            }
            _screenSettings = StoryUI.CreatePanelSettings(theme, screenSortingOrder);
            VisualElement lowerRoot = StoryUI.CreateDocument(transform, "Effects Lower UI", lower).rootVisualElement;
            VisualElement screenRoot = StoryUI.CreateDocument(transform, "Effects Screen UI", _screenSettings).rootVisualElement;
            if (lowerRoot == null || screenRoot == null)
            {
                Debug.LogError("StoryEffects: a UIDocument has no root element yet. Check that its object is active and has panel settings.", this);
                return;
            }
            StoryUI.Fill(lowerRoot, false);
            StoryUI.Fill(screenRoot, false);

            _lowerContent = new VisualElement { name = "vnt-effects-lower" };
            StoryUI.Fill(_lowerContent, false);
            _weatherHost = new VisualElement { name = "vnt-weather" };
            StoryUI.Fill(_weatherHost, false);
            _filterOverlay = new VisualElement { name = "vnt-filter" };
            StoryUI.Fill(_filterOverlay, false);
            _filterOverlay.style.display = DisplayStyle.None;
            _vignetteTexture = MakeVignetteTexture();
            _vignette = new Image { name = "vnt-vignette" };
            StoryUI.Fill(_vignette, false);
            _vignette.image = _vignetteTexture;
            _vignette.scaleMode = UnityEngine.ScaleMode.StretchToFill;
            _vignette.style.display = DisplayStyle.None;
            _lowerContent.Add(_weatherHost);
            _lowerContent.Add(_filterOverlay);
            _lowerContent.Add(_vignette);
            lowerRoot.Add(_lowerContent);

            _curtain = new VisualElement { name = "vnt-curtain" };
            StoryUI.Fill(_curtain, false);
            _curtain.style.display = DisplayStyle.None;
            _flash = new VisualElement { name = "vnt-flash" };
            StoryUI.Fill(_flash, false);
            _flash.style.display = DisplayStyle.None;
            screenRoot.Add(_curtain);
            screenRoot.Add(_flash);
        }

        // A 256 by 256 picture that is clear in the middle and dark at the edges and corners.
        private static Texture2D MakeVignetteTexture()
        {
            const int size = 256;
            var texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.wrapMode = TextureWrapMode.Clamp;
            float half = (size - 1) * 0.5f;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float dx = (x - half) / half;
                    float dy = (y - half) / half;
                    float distance = Mathf.Sqrt(dx * dx + dy * dy);
                    float t = Mathf.Clamp01((distance - 0.45f) / (1.3f - 0.45f));
                    float alpha = t * t * (3f - 2f * t) * 0.9f;
                    texture.SetPixel(x, y, new Color(0f, 0f, 0f, alpha));
                }
            }
            texture.Apply();
            return texture;
        }

        private bool Skipping { get { return _story != null && _story.Skipping; } }

        private Task Animate(float seconds, System.Action<float> apply)
        {
            return _tweens.Run(seconds, apply, Skipping);
        }

        private void Update()
        {
            if (_story == null || _story.Paused) return;
            float delta = Time.unscaledDeltaTime;
            _tweens.Tick(delta, Skipping);
            if (delta > 0.1f) delta = 0.1f;
            foreach (WeatherView view in _weatherViews) view.Advance(delta);
            if (_shakeLeft > 0f)
            {
                _shakeLeft -= delta;
                if (_shakeLeft <= 0f || Skipping)
                {
                    EndShake();
                }
                else
                {
                    float amplitude = _shakeStrength * 40f;
                    ApplyShake(new Vector2(UnityEngine.Random.Range(-amplitude, amplitude), UnityEngine.Random.Range(-amplitude, amplitude)));
                }
            }
        }

        // --- Screen fades and flashes -------------------------------------------

        /// <summary>
        /// Fades the whole screen, dialogue included, to a color. The color's alpha is the
        /// final opacity. Completes when the fade ends.
        /// </summary>
        public Task FadeOut(Color color, float time)
        {
            if (_curtain == null) return Task.CompletedTask;
            _curtainColor = new Color(color.r, color.g, color.b, 1f);
            float from = _curtainAlpha;
            float to = color.a;
            int token = ++_curtainToken;
            return Animate(time, delegate (float t)
            {
                if (token != _curtainToken) return;
                _curtainAlpha = Mathf.Lerp(from, to, t);
                ApplyCurtain();
            });
        }

        /// <summary>Fades the screen back in after <see cref="FadeOut"/>. Completes when the fade ends.</summary>
        public Task FadeIn(float time)
        {
            if (_curtain == null) return Task.CompletedTask;
            float from = _curtainAlpha;
            int token = ++_curtainToken;
            return Animate(time, delegate (float t)
            {
                if (token != _curtainToken) return;
                _curtainAlpha = Mathf.Lerp(from, 0f, t);
                ApplyCurtain();
            });
        }

        private void ApplyCurtain()
        {
            bool visible = _curtainAlpha > 0f;
            _curtain.style.display = visible ? DisplayStyle.Flex : DisplayStyle.None;
            _curtain.style.backgroundColor = new Color(_curtainColor.r, _curtainColor.g, _curtainColor.b, _curtainAlpha);
        }

        /// <summary>Flashes the whole screen with a color and lets it fade away. Completes when it is gone.</summary>
        public Task Flash(Color color, float time)
        {
            if (_flash == null) return Task.CompletedTask;
            int token = ++_flashToken;
            return Animate(time, delegate (float t)
            {
                if (token != _flashToken) return;
                float alpha = color.a * (1f - t);
                _flash.style.display = alpha > 0f ? DisplayStyle.Flex : DisplayStyle.None;
                _flash.style.backgroundColor = new Color(color.r, color.g, color.b, alpha);
            });
        }

        // --- Shake --------------------------------------------------------------

        /// <summary>
        /// Shakes the stage and the weather and filter panel at random for the given seconds.
        /// Strength 0.5 moves each by up to about 20 pixels at the 1920 by 1080 layout. The
        /// dialogue stays still. Completes when the shake ends. While the player skips, it does nothing.
        /// </summary>
        public Task Shake(float strength, float time)
        {
            if (time <= 0f || Skipping || _lowerContent == null) return Task.CompletedTask;
            if (_shakeDone != null) EndShake();
            _shakeStrength = strength;
            _shakeLeft = time;
            _shakeDone = new TaskCompletionSource<bool>();
            return _shakeDone.Task;
        }

        private void EndShake()
        {
            _shakeLeft = 0f;
            ApplyShake(Vector2.zero);
            TaskCompletionSource<bool> done = _shakeDone;
            _shakeDone = null;
            if (done != null) done.TrySetResult(true);
        }

        private void ApplyShake(Vector2 pixels)
        {
            _lowerContent.style.translate = new Translate(new Length(pixels.x, LengthUnit.Pixel), new Length(pixels.y, LengthUnit.Pixel));
            if (_story != null && _story.Stage != null) _story.Stage.SetShake(pixels);
        }

        // --- Filters ------------------------------------------------------------

        /// <summary>
        /// Sets the screen filter: grayscale, sepia, night, warm, cold, vignette, or none.
        /// Strength runs from 0 to 1. Changing from one filter to another fades the old one
        /// out and the new one in, each over half the time. Blur is not available in Unity yet:
        /// it logs a warning once and changes nothing. Completes when the change ends and returns
        /// an error message for an unknown name, or "".
        /// </summary>
        public async Task<string> SetFilter(string filterName, float strength, float time)
        {
            if (System.Array.IndexOf(Filters, filterName) < 0)
                return "Unknown filter '" + filterName + "'. Filters: " + string.Join(", ", Filters) + ".";
            if (_filterOverlay == null) return "";
            if (filterName == "blur")
            {
                if (!_warnedBlur)
                {
                    _warnedBlur = true;
                    Debug.LogWarning("Visual Novel Teller: the blur filter is not available in Unity yet. Nothing changes.", this);
                }
                return "";
            }
            string previous = _filterName;
            _filterName = filterName;
            _filterStrength = strength;
            int token = ++_filterToken;
            if (previous != filterName && previous != "none" && filterName != "none")
            {
                float from = _filterLevel;
                await Animate(time * 0.5f, delegate (float t)
                {
                    if (token != _filterToken) return;
                    _filterLevel = Mathf.Lerp(from, 0f, t);
                    ApplyFilter();
                });
                if (token != _filterToken) return "";
                time *= 0.5f;
            }
            if (filterName != "none") _filterShown = filterName;
            float start = _filterLevel;
            float target = filterName != "none" ? Mathf.Clamp01(strength) : 0f;
            await Animate(time, delegate (float t)
            {
                if (token != _filterToken) return;
                _filterLevel = Mathf.Lerp(start, target, t);
                ApplyFilter();
            });
            if (token == _filterToken && _filterName == "none")
            {
                _filterShown = "none";
                ApplyFilter();
            }
            return "";
        }

        private void ApplyFilter()
        {
            bool visible = _filterShown != "none" && _filterLevel > 0f;
            bool isVignette = _filterShown == "vignette";
            _vignette.style.display = visible && isVignette ? DisplayStyle.Flex : DisplayStyle.None;
            _filterOverlay.style.display = visible && !isVignette ? DisplayStyle.Flex : DisplayStyle.None;
            if (!visible) return;
            if (isVignette)
            {
                _vignette.style.opacity = _filterLevel;
                return;
            }
            Color tint = FilterTint(_filterShown);
            _filterOverlay.style.backgroundColor = new Color(tint.r, tint.g, tint.b, tint.a * _filterLevel);
        }

        // The overlay color of a filter at full strength. Grayscale only approximates.
        private static Color FilterTint(string filterName)
        {
            switch (filterName)
            {
                case "grayscale": return new Color(0.5f, 0.5f, 0.5f, 0.6f);
                case "sepia": return new Color(0.44f, 0.26f, 0.08f, 0.42f);
                case "night": return new Color(0.05f, 0.1f, 0.35f, 0.45f);
                case "warm": return new Color(1f, 0.6f, 0.2f, 0.2f);
                case "cold": return new Color(0.3f, 0.55f, 1f, 0.2f);
            }
            return new Color(0f, 0f, 0f, 0f);
        }

        // --- Weather ------------------------------------------------------------

        /// <summary>
        /// Starts rain or snow over the stage, or stops weather with "none". Strength scales
        /// how many particles fall. The old weather fades out while the new one fades in over
        /// the given seconds. Completes when the fade ends and returns an error message for an
        /// unknown kind, or "".
        /// </summary>
        public async Task<string> SetWeather(string kind, float strength, float fade)
        {
            if (System.Array.IndexOf(WeatherKinds, kind) < 0)
                return "Unknown weather '" + kind + "'. Kinds: " + string.Join(", ", WeatherKinds) + ".";
            if (_weatherHost == null) return "";
            _weatherKind = kind;
            _weatherStrength = strength;
            WeatherView old = _weather;
            _weather = null;
            if (old != null) FadeOutWeather(old, fade);
            if (kind == "none") return "";
            var view = new WeatherView(kind, Mathf.Clamp(strength, 0.05f, 2f));
            view.Opacity = 0f;
            _weatherHost.Add(view);
            _weatherViews.Add(view);
            _weather = view;
            await Animate(fade, delegate (float t)
            {
                if (_weather != view) return;
                view.Opacity = t;
            });
            return "";
        }

        private void FadeOutWeather(WeatherView view, float fade)
        {
            if (fade <= 0f || Skipping)
            {
                RemoveWeather(view);
                return;
            }
            float from = view.Opacity;
            // The fade ends by itself, so nothing waits for it.
            Animate(fade, delegate (float t)
            {
                view.Opacity = Mathf.Lerp(from, 0f, t);
                if (t >= 1f) RemoveWeather(view);
            });
        }

        private void RemoveWeather(WeatherView view)
        {
            _weatherViews.Remove(view);
            _weatherHost.Remove(view);
        }

        // --- Reset and saves ----------------------------------------------------

        /// <summary>Removes every effect at once: weather, filter, flash, fade, and shake.</summary>
        public void Clear()
        {
            if (_lowerContent == null) return;
            _tweens.FinishAll();
            ClearWeatherViews();
            _filterToken++;
            _filterName = "none";
            _filterShown = "none";
            _filterLevel = 0f;
            _filterStrength = 1f;
            ApplyFilter();
            _curtainToken++;
            _curtainAlpha = 0f;
            ApplyCurtain();
            _flashToken++;
            _flash.style.display = DisplayStyle.None;
            if (_shakeDone != null) EndShake();
            else ApplyShake(Vector2.zero);
        }

        private void ClearWeatherViews()
        {
            foreach (WeatherView view in _weatherViews.ToArray()) RemoveWeather(view);
            _weather = null;
            _weatherKind = "none";
            _weatherStrength = 1f;
        }

        /// <summary>The key of the effects in a save.</summary>
        public string Name { get { return "Effects"; } }

        /// <summary>
        /// The weather, filter, and screen fade as plain data: "weather" (kind, strength),
        /// "filter" (name, strength), and "curtain" (r, g, b, a).
        /// </summary>
        public object Capture()
        {
            var data = new OrderedMap<object>();
            var weather = new OrderedMap<object>();
            weather["kind"] = _weatherKind;
            weather["strength"] = (double)_weatherStrength;
            data["weather"] = weather;
            var filter = new OrderedMap<object>();
            filter["name"] = _filterName;
            filter["strength"] = (double)_filterStrength;
            data["filter"] = filter;
            var curtain = new OrderedMap<object>();
            curtain["r"] = (double)_curtainColor.r;
            curtain["g"] = (double)_curtainColor.g;
            curtain["b"] = (double)_curtainColor.b;
            curtain["a"] = (double)_curtainAlpha;
            data["curtain"] = curtain;
            return data;
        }

        /// <summary>Puts the effects back from data made by <see cref="Capture"/>, at once and without fades.</summary>
        public void Restore(object data)
        {
            if (_lowerContent == null) return;
            Clear();
            var map = data as OrderedMap<object>;
            if (map == null) return;
            object value;
            var weather = map.TryGetValue("weather", out value) ? value as OrderedMap<object> : null;
            if (weather != null)
            {
                string kind = TextOf(weather, "kind", "none");
                if (kind != "none") _ = SetWeather(kind, (float)NumberOf(weather, "strength", 1.0), 0f);
            }
            var filter = map.TryGetValue("filter", out value) ? value as OrderedMap<object> : null;
            if (filter != null)
            {
                string filterName = TextOf(filter, "name", "none");
                if (filterName != "none") _ = SetFilter(filterName, (float)NumberOf(filter, "strength", 1.0), 0f);
            }
            var curtain = map.TryGetValue("curtain", out value) ? value as OrderedMap<object> : null;
            if (curtain != null)
            {
                _curtainColor = new Color((float)NumberOf(curtain, "r", 0.0), (float)NumberOf(curtain, "g", 0.0), (float)NumberOf(curtain, "b", 0.0), 1f);
                _curtainAlpha = Mathf.Clamp01((float)NumberOf(curtain, "a", 0.0));
                ApplyCurtain();
            }
        }

        private static string TextOf(OrderedMap<object> map, string key, string fallback)
        {
            object value;
            return map.TryGetValue(key, out value) && value != null ? GdValue.Str(value) : fallback;
        }

        private static double NumberOf(OrderedMap<object> map, string key, double fallback)
        {
            object value;
            return map.TryGetValue(key, out value) && GdValue.IsNumber(value) ? GdValue.ToDouble(value) : fallback;
        }

        // --- Weather drawing ----------------------------------------------------

        // Draws falling particles with Painter2D. Positions are fractions of the element's
        // size, so the weather keeps its look when the window changes size.
        private class WeatherView : VisualElement
        {
            private readonly bool _rain;
            private readonly float[] _x;
            private readonly float[] _y;
            private readonly float[] _speed;
            private readonly float[] _size;
            private readonly float[] _phase;
            private float _opacity;

            /// <summary>How visible the particles are, from 0 to 1.</summary>
            public float Opacity
            {
                get { return _opacity; }
                set
                {
                    _opacity = value;
                    style.opacity = value;
                }
            }

            public WeatherView(string kind, float strength)
            {
                _rain = kind == "rain";
                StoryUI.Fill(this, false);
                int count = Mathf.Max(1, Mathf.RoundToInt((_rain ? 260f : 160f) * strength));
                _x = new float[count];
                _y = new float[count];
                _speed = new float[count];
                _size = new float[count];
                _phase = new float[count];
                for (int i = 0; i < count; i++)
                {
                    _x[i] = UnityEngine.Random.Range(-0.05f, 1.05f);
                    _y[i] = UnityEngine.Random.Range(0f, 1f);
                    _speed[i] = _rain ? UnityEngine.Random.Range(1.1f, 1.5f) : UnityEngine.Random.Range(0.06f, 0.14f);
                    _size[i] = _rain ? UnityEngine.Random.Range(18f, 34f) : UnityEngine.Random.Range(2f, 4.5f);
                    _phase[i] = UnityEngine.Random.Range(0f, 6.28f);
                }
                generateVisualContent += Paint;
            }

            // Moves every particle by the elapsed seconds and asks for a redraw.
            public void Advance(float delta)
            {
                Rect rect = contentRect;
                float aspect = rect.width > 1f && rect.height > 1f ? rect.height / rect.width : 0.5625f;
                for (int i = 0; i < _x.Length; i++)
                {
                    _y[i] += _speed[i] * delta;
                    if (_rain)
                    {
                        _x[i] -= _speed[i] * 0.18f * aspect * delta;
                    }
                    else
                    {
                        _phase[i] += delta;
                        _x[i] += (Mathf.Sin(_phase[i]) * 0.02f + 0.01f) * aspect * delta;
                    }
                    if (_y[i] > 1.05f)
                    {
                        _y[i] -= 1.1f;
                        _x[i] = UnityEngine.Random.Range(-0.05f, 1.05f);
                    }
                    if (_x[i] < -0.1f) _x[i] += 1.2f;
                    else if (_x[i] > 1.1f) _x[i] -= 1.2f;
                }
                MarkDirtyRepaint();
            }

            private void Paint(MeshGenerationContext context)
            {
                Rect rect = contentRect;
                float width = rect.width;
                float height = rect.height;
                if (width <= 1f || height <= 1f) return;
                Painter2D painter = context.painter2D;
                if (_rain)
                {
                    painter.lineWidth = 2f;
                    painter.strokeColor = new Color(0.78f, 0.86f, 1f, 0.6f);
                    painter.BeginPath();
                    for (int i = 0; i < _x.Length; i++)
                    {
                        float px = _x[i] * width;
                        float py = _y[i] * height;
                        painter.MoveTo(new Vector2(px, py));
                        painter.LineTo(new Vector2(px - _size[i] * 0.18f, py + _size[i]));
                    }
                    painter.Stroke();
                }
                else
                {
                    painter.fillColor = new Color(1f, 1f, 1f, 0.85f);
                    painter.BeginPath();
                    for (int i = 0; i < _x.Length; i++)
                    {
                        var center = new Vector2(_x[i] * width, _y[i] * height);
                        painter.MoveTo(new Vector2(center.x + _size[i], center.y));
                        painter.Arc(center, _size[i], Angle.Degrees(0f), Angle.Degrees(360f));
                        painter.ClosePath();
                    }
                    painter.Fill();
                }
            }
        }
    }
}
