using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>One line or choice in the history screen.</summary>
    public struct HistoryEntry
    {
        /// <summary>The speaker's name. Empty for narration and for choices taken.</summary>
        public string Speaker;
        /// <summary>The color of the speaker's name.</summary>
        public Color Color;
        /// <summary>The text without any tags.</summary>
        public string Text;

        public HistoryEntry(string speaker, Color color, string text)
        {
            Speaker = speaker;
            Color = color;
            Text = text;
        }
    }

    /// <summary>
    /// Shows lines and choices with UI Toolkit. The speaker's name appears in the speaker's
    /// color and the text types out at the config's speed. A click, Space, or Enter
    /// finishes the typing, then continues. Choices are buttons; options that are not
    /// available are greyed out, and a timed choice shows a shrinking bar and picks
    /// nothing when the time runs out.
    /// The layout and style come from the fields below, then from the Story Config, then
    /// from the files that ship in the package (Resources/VisualNovelTeller/Dialogue).
    /// The player can also skip, let lines continue on their own (auto mode), open a log of
    /// past lines (history), and use a small quick menu. Skip, auto, history, save, and load
    /// show as buttons when the layout has the elements for them.
    /// </summary>
    public class DialoguePresenter : MonoBehaviour
    {
        private const string ResourcePath = "VisualNovelTeller/Dialogue";
        private const string QuickSlot = "quick";

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
        [Tooltip("Optional theme for the panel. Without one, Unity's default runtime theme is used.")]
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
        private Button _autoButton;
        private Button _skipButton;

        private readonly List<HistoryEntry> _history = new List<HistoryEntry>();
        private VisualElement _historyOverlay;
        private ScrollView _historyScroll;
        private bool _historyOpen;
        private bool _visible;

        private bool _auto;
        private float _autoElapsed;
        private bool _skipOn;
        private bool _ctrlHeld;
        private bool _skipApplied;
        private bool _lineRead;
        private bool _wasPaused;
        private float _autoDelayOverride = -1f;
        private int _skipUnreadOverride = -1;
        private HistoryEntry _currentLine;
        private List<string> _optionTexts;

        private TaskCompletionSource<bool> _lineDone;
        private RevealText _reveal;
        private float _elapsed;
        private int _shown;
        private bool _revealDone;
        private int _lastAdvanceFrame = -1;
        private int _lastShortcutFrame = -1;

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

        /// <summary>
        /// True while auto mode is on. A line that has finished typing then continues after the
        /// Auto Delay of the Story Config plus a little time for each character. Auto mode does
        /// not pick choices. A click or Space still moves on at once.
        /// </summary>
        public bool Auto
        {
            get { return _auto; }
            set
            {
                if (_auto == value) return;
                _auto = value;
                _autoElapsed = 0f;
                RefreshQuick();
            }
        }

        /// <summary>
        /// True while skip is switched on. Skip passes lines the player has read before, and
        /// lines that are not read yet when Skip Unread is on in the Story Config. It switches
        /// itself off at an unread line, at a choice, and when a load or rewind happens.
        /// Holding Ctrl skips as well, without changing this value.
        /// </summary>
        public bool SkipOn
        {
            get { return _skipOn; }
            set
            {
                _skipOn = value;
                ApplySkip();
            }
        }

        /// <summary>True while the history screen is open.</summary>
        public bool HistoryOpen { get { return _historyOpen; } }

        /// <summary>The last line shown, with its speaker. Empty before the first line. Saves use it to describe a slot.</summary>
        public HistoryEntry CurrentLine { get { return _currentLine; } }

        /// <summary>
        /// Seconds auto mode waits after a line has finished typing. Setting it overrides the
        /// Story Config, for example from a settings screen.
        /// </summary>
        public float AutoDelay
        {
            get
            {
                if (_autoDelayOverride >= 0f) return _autoDelayOverride;
                return _story != null && _story.Config != null ? _story.Config.AutoDelay : 1f;
            }
            set { _autoDelayOverride = Mathf.Max(value, 0f); }
        }

        /// <summary>
        /// True when skip may pass lines the player has not read yet. Setting it overrides the
        /// Story Config, for example from a settings screen.
        /// </summary>
        public bool SkipUnread
        {
            get
            {
                if (_skipUnreadOverride >= 0) return _skipUnreadOverride == 1;
                return _story != null && _story.Config != null && _story.Config.SkipUnread;
            }
            set { _skipUnreadOverride = value ? 1 : 0; }
        }

        private bool Paused { get { return _story != null && _story.Paused; } }

        /// <summary>The lines and choices shown so far, oldest first. The Story Config limits the count.</summary>
        public IReadOnlyList<HistoryEntry> History { get { return _history; } }

        /// <summary>Connects the presenter to a story and builds the interface. <see cref="Story"/> calls this.</summary>
        public void Attach(Story story)
        {
            _story = story;
            EnsureUi();
        }

        /// <summary>Forgets the lines of the history screen and the current line. A new game does this.</summary>
        public void ClearHistory()
        {
            _history.Clear();
            _currentLine = default(HistoryEntry);
        }

        /// <summary>Hides the dialogue box and choices.</summary>
        public void Hide()
        {
            _visible = false;
            if (_root != null) _root.style.display = DisplayStyle.None;
        }

        private void Show()
        {
            _visible = true;
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
                    _createdSettings = StoryUI.CreatePanelSettings(themeSheet, sortingOrder, config != null ? config.UiScale : 1f);
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
            _choices.style.display = DisplayStyle.None;
            SetUpQuickMenu(tree);
            Hide();
        }

        private void SetUpQuickMenu(VisualElement tree)
        {
            VisualElement quick = tree.Q<VisualElement>("vnt-quick");
            if (quick == null) return;
            // A click on the quick menu must not also move the story on.
            quick.RegisterCallback<PointerDownEvent>(delegate (PointerDownEvent evt) { evt.StopPropagation(); });
            _autoButton = QuickButton(quick, "vnt-auto", delegate { Auto = !Auto; });
            _skipButton = QuickButton(quick, "vnt-skip", delegate { SkipOn = !SkipOn; });
            QuickButton(quick, "vnt-history", ShowHistory);
            QuickButton(quick, "vnt-save", delegate { Shortcut(KeyCode.F5); });
            QuickButton(quick, "vnt-load", delegate { Shortcut(KeyCode.F9); });
            RefreshQuick();
        }

        private static Button QuickButton(VisualElement quick, string buttonName, Action onClick)
        {
            Button button = quick.Q<Button>(buttonName);
            if (button == null) return null;
            // Without focus, Space and Enter do not press the button a second time.
            button.focusable = false;
            button.clicked += onClick;
            return button;
        }

        private void RefreshQuick()
        {
            if (_autoButton != null) _autoButton.EnableInClassList("vnt-on", _auto);
            if (_skipButton != null) _skipButton.EnableInClassList("vnt-on", _skipOn || _ctrlHeld);
        }

        // --- Input --------------------------------------------------------------

        private void OnPointerDown(PointerDownEvent evt)
        {
            if (evt.button == 0) Advance();
        }

        /// <summary>
        /// Reads the keyboard and mouse wheel through the Input System: Space or Enter moves
        /// the story on, Ctrl skips while held, Tab switches skip on or off, A switches auto
        /// mode, H opens the history, and the test shortcuts work as described below. Clicks reach the
        /// dialogue box through UI Toolkit.
        /// </summary>
        private void PollInput()
        {
            Keyboard keyboard = Keyboard.current;
            if (keyboard != null)
            {
                if (_lineDone != null && (keyboard.spaceKey.wasPressedThisFrame || keyboard.enterKey.wasPressedThisFrame
                    || keyboard.numpadEnterKey.wasPressedThisFrame))
                    Advance();
                if (keyboard.f5Key.wasPressedThisFrame) Shortcut(KeyCode.F5);
                if (keyboard.f9Key.wasPressedThisFrame) Shortcut(KeyCode.F9);
                if (keyboard.pageUpKey.wasPressedThisFrame) Shortcut(KeyCode.PageUp);
                _ctrlHeld = keyboard.leftCtrlKey.isPressed || keyboard.rightCtrlKey.isPressed;
                if (keyboard.tabKey.wasPressedThisFrame) SkipOn = !_skipOn;
                if (keyboard.aKey.wasPressedThisFrame) Auto = !_auto;
                if (keyboard.hKey.wasPressedThisFrame) ShowHistory();
            }
            else
            {
                _ctrlHeld = false;
            }
            Mouse mouse = Mouse.current;
            if (mouse != null && mouse.scroll.ReadValue().y > 0f) Shortcut(KeyCode.PageUp);
        }

        /// <summary>While the history screen is open, only H, Escape, and a click on its buttons are read.</summary>
        private void PollHistoryInput()
        {
            Keyboard keyboard = Keyboard.current;
            if (keyboard != null && (keyboard.hKey.wasPressedThisFrame || keyboard.escapeKey.wasPressedThisFrame))
                HideHistory();
        }

        /// <summary>
        /// Test shortcuts: F5 saves to the slot "quick", F9 loads it, and PageUp or the mouse
        /// wheel up steps back one line or choice. Each works only when the story allows it.
        /// </summary>
        private void Shortcut(KeyCode key)
        {
            if (_story == null || Time.frameCount == _lastShortcutFrame) return;
            if (key == KeyCode.F5)
            {
                if (!_story.IsPlaying) return;
                _lastShortcutFrame = Time.frameCount;
                _story.SaveSlot(QuickSlot);
            }
            else if (key == KeyCode.F9)
            {
                if (!_story.HasSlot(QuickSlot)) return;
                _lastShortcutFrame = Time.frameCount;
                _ = _story.LoadSlot(QuickSlot);
            }
            else if (key == KeyCode.PageUp)
            {
                if (!_story.CanRewind) return;
                _lastShortcutFrame = Time.frameCount;
                _ = _story.Rewind(1);
            }
        }

        /// <summary>
        /// The player's continue input: finishes the typing of the line, or, when it is
        /// finished, continues the story. Call it from your own input code if you like.
        /// </summary>
        public void Advance()
        {
            if (_lineDone == null || Paused || Time.frameCount == _lastAdvanceFrame) return;
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
            if (Paused)
            {
                // Input that closed a menu in this frame must not also move the story on.
                _wasPaused = true;
                _ctrlHeld = false;
                ApplySkip();
                return;
            }
            if (_wasPaused)
            {
                _wasPaused = false;
                return;
            }
            if (_historyOpen)
            {
                PollHistoryInput();
                return;
            }
            PollInput();
            ApplySkip();
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
                if (_auto && _revealDone)
                {
                    _autoElapsed += Time.unscaledDeltaTime;
                    if (_autoElapsed >= AutoDelay + 0.03f * _reveal.VisibleCount) CompleteLine();
                }
            }
            else if (_choiceDone != null && _timeout > 0f)
            {
                _remaining -= Time.unscaledDeltaTime;
                if (_timerFill != null) _timerFill.style.width = Length.Percent(Mathf.Clamp01(_remaining / _timeout) * 100f);
                if (_remaining <= 0f) CompleteChoice(-1);
            }
        }

        // --- Skip ---------------------------------------------------------------

        /// <summary>
        /// Sets Story.Skipping from what the player asks for. Skip needs the toggle or Ctrl, no
        /// history screen, no choice on screen, and a read line unless Skip Unread is on.
        /// Only changes are passed on, so game code that sets Story.Skipping itself keeps its value.
        /// </summary>
        private void ApplySkip()
        {
            bool wanted = !_historyOpen && !Paused && (_skipOn || _ctrlHeld);
            bool allowed = _choiceDone == null && (_lineDone == null || _lineRead || SkipUnread);
            bool target = wanted && allowed;
            if (target != _skipApplied)
            {
                _skipApplied = target;
                if (_story != null) _story.Skipping = target;
            }
            RefreshQuick();
        }

        // --- History ------------------------------------------------------------

        private void AddHistory(string speaker, Color color, string text)
        {
            _history.Add(new HistoryEntry(speaker, color, text));
            int limit = _story != null && _story.Config != null ? _story.Config.HistoryLength : 200;
            if (_history.Count > limit) _history.RemoveRange(0, _history.Count - limit);
        }

        /// <summary>
        /// Opens the history screen over the dialogue. Advance, the shortcuts, and the timers of
        /// timed choices and auto mode wait until it closes. Skip switches off.
        /// </summary>
        public void ShowHistory()
        {
            if (_historyOpen || _root == null || !_visible) return;
            EnsureHistoryUi();
            _historyOpen = true;
            _skipOn = false;
            ApplySkip();
            FillHistory();
            _historyOverlay.style.display = DisplayStyle.Flex;
            _historyScroll.schedule.Execute(ScrollHistoryToEnd);
            _historyScroll.schedule.Execute(ScrollHistoryToEnd).ExecuteLater(60);
        }

        /// <summary>Closes the history screen.</summary>
        public void HideHistory()
        {
            if (!_historyOpen) return;
            _historyOpen = false;
            if (_historyOverlay != null) _historyOverlay.style.display = DisplayStyle.None;
            if (_root != null) _root.Focus();
        }

        private void ScrollHistoryToEnd()
        {
            if (_historyScroll == null) return;
            _historyScroll.scrollOffset = new Vector2(0f, _historyScroll.verticalScroller.highValue);
        }

        private void EnsureHistoryUi()
        {
            if (_historyOverlay != null) return;
            _historyOverlay = new VisualElement();
            _historyOverlay.name = "vnt-history-overlay";
            _historyOverlay.AddToClassList("vnt-history");
            StoryUI.Fill(_historyOverlay, true);
            _historyOverlay.style.display = DisplayStyle.None;
            // Clicks stop here so they never move the story on. A right click closes the screen.
            _historyOverlay.RegisterCallback<PointerDownEvent>(delegate (PointerDownEvent evt)
            {
                evt.StopPropagation();
                if (evt.button == 1) HideHistory();
            });
            var title = new Label("History");
            title.name = "vnt-history-title";
            title.AddToClassList("vnt-history-title");
            _historyOverlay.Add(title);
            _historyScroll = new ScrollView();
            _historyScroll.name = "vnt-history-scroll";
            _historyScroll.AddToClassList("vnt-history-scroll");
            _historyOverlay.Add(_historyScroll);
            var close = new Button();
            close.name = "vnt-history-close";
            close.text = "Close";
            close.AddToClassList("vnt-history-close");
            close.focusable = false;
            close.clicked += HideHistory;
            _historyOverlay.Add(close);
            _root.Add(_historyOverlay);
        }

        private void FillHistory()
        {
            _historyScroll.Clear();
            if (_history.Count == 0)
            {
                _historyScroll.Add(HistoryLabel("Nothing yet.", "vnt-history-text"));
                return;
            }
            foreach (HistoryEntry entry in _history)
            {
                var row = new VisualElement();
                row.AddToClassList("vnt-history-entry");
                if (!string.IsNullOrEmpty(entry.Speaker))
                {
                    Label speaker = HistoryLabel(entry.Speaker, "vnt-history-speaker");
                    speaker.style.color = entry.Color;
                    row.Add(speaker);
                }
                row.Add(HistoryLabel(entry.Text, "vnt-history-text"));
                _historyScroll.Add(row);
            }
        }

        private static Label HistoryLabel(string text, string className)
        {
            var label = new Label();
            label.enableRichText = false;
            label.text = text;
            label.AddToClassList(className);
            return label;
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
            Color historyColor = Color.white;
            if (line.TryGetValue("speaker_color", out colorValue) && colorValue is Color && ((Color)colorValue).a > 0f)
                historyColor = (Color)colorValue;
            AddHistory(speakerName, historyColor, _reveal.PlainText);
            _currentLine = new HistoryEntry(speakerName, historyColor, _reveal.PlainText);
            object readValue;
            _lineRead = line.TryGetValue("read", out readValue) && readValue is bool && (bool)readValue;
            // Skip stops at the first line the player has not read.
            if (!_lineRead && !SkipUnread) _skipOn = false;
            _autoElapsed = 0f;
            _elapsed = 0f;
            _shown = -1;
            _revealDone = false;
            _more.style.visibility = Visibility.Hidden;
            UpdateReveal();
            _lineDone = new TaskCompletionSource<bool>();
            ApplySkip();
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
            _optionTexts = new List<string>();
            for (int i = 0; i < options.Count; i++)
            {
                int index = i;
                _optionTexts.Add(Text(options[i], "text"));
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
            // Skip stops at a choice.
            _skipOn = false;
            ApplySkip();
            return _choiceDone.Task;
        }

        private void CompleteChoice(int index)
        {
            TaskCompletionSource<int> done = _choiceDone;
            if (done == null) return;
            _choiceDone = null;
            _lastAdvanceFrame = Time.frameCount;
            if (index >= 0 && _optionTexts != null && index < _optionTexts.Count)
                AddHistory("", Color.white, "> " + _optionTexts[index]);
            _optionTexts = null;
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
            _optionTexts = null;
            ClearChoices();
            HideHistory();
            // A load or rewind ends skip.
            _skipOn = false;
            ApplySkip();
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
