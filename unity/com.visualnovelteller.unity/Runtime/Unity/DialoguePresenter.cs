using System.Collections.Generic;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>
    /// Shows lines and choices with UI Toolkit. The speaker's name appears in the speaker's
    /// color and the text types out at the config's speed. A click, Space, or Enter
    /// finishes the typing, then continues. Choices are buttons; options that are not
    /// available are greyed out, and a timed choice shows a shrinking bar and picks
    /// nothing when the time runs out.
    /// The layout and style come from the fields below, then from the Story Config, then
    /// from the files that ship in the package (Resources/VisualNovelTeller/Dialogue).
    /// </summary>
    public class DialoguePresenter : MonoBehaviour
    {
        private const string ResourcePath = "VisualNovelTeller/Dialogue";

        [Tooltip("Optional. A UIDocument to draw on. Left empty, the presenter makes its own.")]
        [SerializeField] private UIDocument document;
        [Tooltip("Optional. Left empty, panel settings that scale from 1920 by 1080 are made.")]
        [SerializeField] private PanelSettings panelSettings;
        [Tooltip("Panels with a higher number draw in front. The 2D stage uses -10.")]
        [SerializeField] private float sortingOrder = 10f;
        [Tooltip("Optional. Replaces the layout from the Story Config and the package.")]
        [SerializeField] private VisualTreeAsset layout;
        [Tooltip("Optional. Replaces the style sheet from the Story Config and the package.")]
        [SerializeField] private StyleSheet style;
        [Tooltip("Optional theme for the panel. The default style looks right without one.")]
        [SerializeField] private ThemeStyleSheet theme;
        [Tooltip("Characters per second. A negative number uses the Story Config. 0 shows each line at once.")]
        [SerializeField] private float textSpeed = -1f;

        private Story _story;
        private PanelSettings _createdSettings;
        private Bridge _bridge;
        private VisualElement _root;
        private VisualElement _box;
        private Label _speaker;
        private Label _text;
        private VisualElement _more;
        private VisualElement _choices;

        private TaskCompletionSource<bool> _lineDone;
        private RevealText _reveal;
        private float _elapsed;
        private int _shown;
        private bool _revealDone;
        private int _lastAdvanceFrame = -1;

        private TaskCompletionSource<int> _choiceDone;
        private float _timeout;
        private float _remaining;
        private VisualElement _timerFill;

        /// <summary>The presenter to give the director. <see cref="Story"/> does this.</summary>
        public TalePresenter Presenter
        {
            get
            {
                if (_bridge == null) _bridge = new Bridge(this);
                return _bridge;
            }
        }

        /// <summary>Characters per second, from this component or the Story Config.</summary>
        public float TextSpeed
        {
            get
            {
                if (textSpeed >= 0f) return textSpeed;
                return _story != null && _story.Config != null ? _story.Config.TextSpeed : 40f;
            }
            set { textSpeed = value; }
        }

        /// <summary>Connects the presenter to a story and builds the interface. <see cref="Story"/> calls this.</summary>
        public void Attach(Story story)
        {
            _story = story;
            EnsureUi();
        }

        /// <summary>Hides the dialogue box and choices.</summary>
        public void Hide()
        {
            if (_root != null) _root.style.display = DisplayStyle.None;
        }

        private void Show()
        {
            if (_root != null) _root.style.display = DisplayStyle.Flex;
        }

        private void OnDestroy()
        {
            if (_createdSettings != null) Destroy(_createdSettings);
        }

        // --- Building the interface --------------------------------------------

        private void EnsureUi()
        {
            if (_root != null) return;
            StoryConfig config = _story != null ? _story.Config : null;
            ThemeStyleSheet themeSheet = theme != null ? theme : (config != null ? config.ThemeStyleSheet : null);
            if (document == null) document = GetComponent<UIDocument>();
            if (document == null || document.panelSettings == null)
            {
                if (panelSettings == null)
                {
                    _createdSettings = StoryUI.CreatePanelSettings(themeSheet, sortingOrder);
                    panelSettings = _createdSettings;
                }
                if (document == null) document = StoryUI.CreateDocument(transform, "Dialogue UI", panelSettings);
                else document.panelSettings = panelSettings;
            }
            VisualTreeAsset uxml = layout;
            if (uxml == null && config != null) uxml = config.DialogueLayout;
            if (uxml == null) uxml = Resources.Load<VisualTreeAsset>(ResourcePath);
            StyleSheet sheet = style;
            if (sheet == null && config != null) sheet = config.DialogueStyle;
            if (sheet == null) sheet = Resources.Load<StyleSheet>(ResourcePath);
            if (uxml == null)
            {
                Debug.LogError("DialoguePresenter: the dialogue layout was not found. Reinstall the package or assign a layout.", this);
                return;
            }
            if (document.rootVisualElement == null)
            {
                Debug.LogError("DialoguePresenter: the UIDocument has no root element yet. Check that its object is active and has panel settings.", this);
                return;
            }
            VisualElement tree = uxml.CloneTree();
            StoryUI.Fill(document.rootVisualElement, false);
            StoryUI.Fill(tree, true);
            if (sheet != null) tree.styleSheets.Add(sheet);
            document.rootVisualElement.Add(tree);
            _box = tree.Q<VisualElement>("vnt-box");
            _speaker = tree.Q<Label>("vnt-speaker");
            _text = tree.Q<Label>("vnt-text");
            _more = tree.Q<VisualElement>("vnt-more");
            _choices = tree.Q<VisualElement>("vnt-choices");
            if (_box == null || _speaker == null || _text == null || _more == null || _choices == null)
            {
                Debug.LogError("DialoguePresenter: the layout needs elements named vnt-box, vnt-speaker, vnt-text, vnt-more, and vnt-choices.", this);
                return;
            }
            _text.enableRichText = true;
            _root = tree;
            _root.focusable = true;
            _root.RegisterCallback<PointerDownEvent>(OnPointerDown);
            _root.RegisterCallback<KeyDownEvent>(OnKeyDown, TrickleDown.TrickleDown);
            _choices.style.display = DisplayStyle.None;
            Hide();
        }

        // --- Input --------------------------------------------------------------

        private void OnPointerDown(PointerDownEvent evt)
        {
            if (evt.button == 0) Advance();
        }

        private void OnKeyDown(KeyDownEvent evt)
        {
            if (evt.keyCode == KeyCode.Space || evt.keyCode == KeyCode.Return || evt.keyCode == KeyCode.KeypadEnter)
                Advance();
        }

        /// <summary>
        /// The player's continue input: finishes the typing of the line, or, when it is
        /// finished, continues the story. Call it from your own input code if you like.
        /// </summary>
        public void Advance()
        {
            if (_lineDone == null || Time.frameCount == _lastAdvanceFrame) return;
            _lastAdvanceFrame = Time.frameCount;
            if (!_revealDone)
            {
                _elapsed = float.MaxValue;
                UpdateReveal();
            }
            else
            {
                CompleteLine();
            }
        }

        private void Update()
        {
            if (_lineDone != null)
            {
                if (_story != null && _story.Skipping)
                {
                    _elapsed = float.MaxValue;
                    UpdateReveal();
                    CompleteLine();
                    return;
                }
                if (_elapsed < float.MaxValue) _elapsed += Time.unscaledDeltaTime;
                UpdateReveal();
            }
            else if (_choiceDone != null && _timeout > 0f)
            {
                _remaining -= Time.unscaledDeltaTime;
                if (_timerFill != null) _timerFill.style.width = Length.Percent(Mathf.Clamp01(_remaining / _timeout) * 100f);
                if (_remaining <= 0f) CompleteChoice(-1);
            }
#if ENABLE_LEGACY_INPUT_MANAGER
            if (_lineDone != null && (Input.GetKeyDown(KeyCode.Space) || Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)))
                Advance();
#endif
        }

        // --- Lines --------------------------------------------------------------

        private Task ShowLineAsync(OrderedMap<object> line)
        {
            EnsureUi();
            if (_root == null) return Task.CompletedTask;
            Show();
            ClearChoices();
            string speakerName = Text(line, "speaker_name");
            _speaker.text = StoryUI.EscapeRichText(speakerName);
            _speaker.style.display = speakerName.Length == 0 ? DisplayStyle.None : DisplayStyle.Flex;
            object colorValue;
            if (line.TryGetValue("speaker_color", out colorValue) && colorValue is Color && ((Color)colorValue).a > 0f)
                _speaker.style.color = (Color)colorValue;
            else
                _speaker.style.color = StyleKeyword.Null;
            _reveal = RevealText.Parse(Text(line, "text"), TextSpeed);
            _elapsed = 0f;
            _shown = -1;
            _revealDone = false;
            _more.style.visibility = Visibility.Hidden;
            UpdateReveal();
            _lineDone = new TaskCompletionSource<bool>();
            _root.Focus();
            return _lineDone.Task;
        }

        private void UpdateReveal()
        {
            int count = _reveal.CountAt(_elapsed);
            if (count != _shown)
            {
                _shown = count;
                _text.text = _reveal.Prefix(count);
            }
            if (!_revealDone && count >= _reveal.VisibleCount)
            {
                _revealDone = true;
                _more.style.visibility = Visibility.Visible;
            }
        }

        private void CompleteLine()
        {
            TaskCompletionSource<bool> done = _lineDone;
            _lineDone = null;
            _more.style.visibility = Visibility.Hidden;
            if (done != null) done.TrySetResult(true);
        }

        // --- Choices ------------------------------------------------------------

        private Task<int> ChooseAsync(List<OrderedMap<object>> options, OrderedMap<object> settings)
        {
            EnsureUi();
            if (_root == null) return Task.FromResult(0);
            Show();
            ClearChoices();
            _more.style.visibility = Visibility.Hidden;
            for (int i = 0; i < options.Count; i++)
            {
                int index = i;
                bool enabled = true;
                object flag;
                if (options[i].TryGetValue("enabled", out flag) && flag is bool) enabled = (bool)flag;
                var button = new Button();
                button.enableRichText = false;
                button.text = Text(options[i], "text");
                button.AddToClassList("vnt-choice");
                if (!enabled) button.AddToClassList("vnt-choice--disabled");
                button.SetEnabled(enabled);
                button.clicked += delegate { CompleteChoice(index); };
                _choices.Add(button);
            }
            object timeoutValue;
            _timeout = 0f;
            if (settings != null && settings.TryGetValue("timeout", out timeoutValue) && GdValue.IsNumber(timeoutValue))
                _timeout = (float)GdValue.ToDouble(timeoutValue);
            if (_timeout > 0f)
            {
                _remaining = _timeout;
                var track = new VisualElement();
                track.AddToClassList("vnt-timer");
                track.pickingMode = PickingMode.Ignore;
                _timerFill = new VisualElement();
                _timerFill.AddToClassList("vnt-timer-fill");
                _timerFill.pickingMode = PickingMode.Ignore;
                _timerFill.style.width = Length.Percent(100f);
                track.Add(_timerFill);
                _choices.Add(track);
            }
            _choices.style.display = DisplayStyle.Flex;
            _choiceDone = new TaskCompletionSource<int>();
            return _choiceDone.Task;
        }

        private void CompleteChoice(int index)
        {
            TaskCompletionSource<int> done = _choiceDone;
            if (done == null) return;
            _choiceDone = null;
            _lastAdvanceFrame = Time.frameCount;
            ClearChoices();
            done.TrySetResult(index);
        }

        private void ClearChoices()
        {
            _timeout = 0f;
            _timerFill = null;
            if (_choices == null) return;
            _choices.Clear();
            _choices.style.display = DisplayStyle.None;
        }

        private void CancelPending()
        {
            TaskCompletionSource<bool> line = _lineDone;
            TaskCompletionSource<int> choice = _choiceDone;
            _lineDone = null;
            _choiceDone = null;
            ClearChoices();
            if (line != null) line.TrySetResult(true);
            if (choice != null) choice.TrySetResult(-1);
            Hide();
        }

        private static string Text(OrderedMap<object> map, string key)
        {
            object value;
            return map.TryGetValue(key, out value) && value != null ? GdValue.Str(value) : "";
        }

        private sealed class Bridge : TalePresenter
        {
            private readonly DialoguePresenter _owner;

            public Bridge(DialoguePresenter owner)
            {
                _owner = owner;
            }

            public override Task ShowLine(OrderedMap<object> line)
            {
                return _owner.ShowLineAsync(line);
            }

            public override Task<int> Choose(List<OrderedMap<object>> options, OrderedMap<object> settings)
            {
                return _owner.ChooseAsync(options, settings);
            }

            public override void Cancel()
            {
                _owner.CancelPending();
            }
        }
    }
}
