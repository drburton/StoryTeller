using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading.Tasks;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>
    /// The menus of a game: a title screen, a pause menu (Escape or the gamepad Start button),
    /// save and load screens with slots, a settings screen, a confirm dialog, and the purchase
    /// screen for demos with paid content (decision 0029). Put it on the
    /// same object as the <see cref="Story"/>. It draws its own UI Toolkit panel in front of the
    /// dialogue. Turn on Show Title Screen in the Story Config to start at the title; New Game
    /// then starts the story. The look comes from Menus.uss in the package, or from the Story
    /// Config's Menu Style. While a menu is open, <see cref="Story.Paused"/> is true.
    /// </summary>
    public class StoryMenus : MonoBehaviour
    {
        private const string ResourcePath = "VisualNovelTeller/Menus";
        private const int SlotsPerPage = 6;
        private const int SlotPages = 3;
        private const int SlotTextLength = 60;

        private enum Page
        {
            Title,
            Pause,
            Save,
            Load,
            Settings
        }

        [Tooltip("Panels with a higher number draw in front. The dialogue uses 10.")]
        [SerializeField] private float sortingOrder = 20f;
        [Tooltip("Optional. Replaces the style sheet from the Story Config and the package.")]
        [SerializeField] private StyleSheet style;
        [Tooltip("Optional theme for the panel. Without one, the Story Config's theme or Unity's default runtime theme is used.")]
        [SerializeField] private ThemeStyleSheet theme;

        private readonly List<Page> _stack = new List<Page>();
        private Story _story;
        private StorySettings _settings;
        private bool _settingsDirty;
        private PanelSettings _createdSettings;
        private UIDocument _document;
        private VisualElement _root;
        private Image _background;
        private VisualElement _screen;
        private VisualElement _confirmLayer;
        private Label _confirmMessage;
        private Button _confirmNo;
        private Action _confirmYes;
        private bool _confirmOpen;
        private VisualElement _firstFocus;
        private int _slotPage;
        private bool _ignoreFinish;
        private bool _historyWasOpen;
        private VisualElement _offerLayer;
        private Image _offerPicture;
        private Label _offerTitle;
        private Label _offerDescription;
        private Label _offerPrice;
        private Label _offerMessage;
        private Button _offerBuy;
        private Button _offerDecline;
        private StoryProduct _offerProduct;
        private TaskCompletionSource<bool> _offerDone;
        private bool _offerPausedStory;

        /// <summary>True while the purchase screen is open.</summary>
        public bool IsOffering { get { return _offerDone != null; } }

        /// <summary>True when the Story Config asks for a title screen. <see cref="Story"/> then waits for New Game instead of playing at once.</summary>
        public bool WantsTitle
        {
            get { return isActiveAndEnabled && _story != null && _story.Config != null && _story.Config.ShowTitleScreen; }
        }

        /// <summary>True while any menu screen is open.</summary>
        public bool IsOpen { get { return _stack.Count > 0; } }

        /// <summary>True while the title screen is the base of the open menus.</summary>
        public bool IsTitle { get { return _stack.Count > 0 && _stack[0] == Page.Title; } }

        /// <summary>The player's settings. Change a value, then call <see cref="StorySettings.Apply"/> and <see cref="StorySettings.Save"/>.</summary>
        public StorySettings Settings { get { return _settings; } }

        private void Awake()
        {
            _story = GetComponent<Story>();
            if (_story == null) _story = FindAnyObjectByType<Story>();
        }

        private void Start()
        {
            if (_story == null)
            {
                Debug.LogError("StoryMenus: there is no Story in the scene. Put this component on the Story's object.", this);
                enabled = false;
                return;
            }
            _settings = StorySettings.Load(_story.Config);
            _settings.Apply(_story);
            _story.Finished += OnStoryFinished;
            _story.Store.OfferScreen = Offer;
            EnsureUi();
            if (WantsTitle) ShowTitle();
        }

        private void OnDestroy()
        {
            if (_story != null)
            {
                _story.Finished -= OnStoryFinished;
                if (_story.Store.OfferScreen == (Func<StoryProduct, Task<bool>>)Offer) _story.Store.OfferScreen = null;
                if (IsOpen || IsOffering) _story.Paused = false;
            }
            SaveSettingsIfDirty();
            if (_createdSettings != null) Destroy(_createdSettings);
        }

        private void Update()
        {
            Keyboard keyboard = Keyboard.current;
            Gamepad pad = Gamepad.current;
            bool escape = keyboard != null && keyboard.escapeKey.wasPressedThisFrame;
            bool start = pad != null && pad.startButton.wasPressedThisFrame;
            bool back = pad != null && pad.buttonEast.wasPressedThisFrame;
            if (!escape && !start && !back) return;
            if (IsOffering)
            {
                DeclineOffer();
                return;
            }
            if (IsOpen)
            {
                Back();
                return;
            }
            if (back) return;
            // One Escape press closes the history screen. It must not open the pause menu as well.
            DialoguePresenter dialogue = _story.Dialogue;
            if (dialogue != null && (dialogue.HistoryOpen || _historyWasOpen)) return;
            OpenPause();
        }

        private void LateUpdate()
        {
            DialoguePresenter dialogue = _story != null ? _story.Dialogue : null;
            _historyWasOpen = dialogue != null && dialogue.HistoryOpen;
        }

        // --- Opening and closing ------------------------------------------------

        /// <summary>Shows the title screen, plays the title music, and pauses the story.</summary>
        public void ShowTitle()
        {
            EnsureUi();
            if (_root == null) return;
            _stack.Clear();
            _stack.Add(Page.Title);
            _slotPage = 0;
            Build();
            PlayTitleMusic();
        }

        /// <summary>Opens the pause menu. Does nothing when no story is playing or a menu is open already.</summary>
        public void OpenPause()
        {
            if (IsOpen || _story == null || !_story.IsPlaying) return;
            EnsureUi();
            if (_root == null) return;
            if (_story.Dialogue != null) _story.Dialogue.SkipOn = false;
            _stack.Add(Page.Pause);
            _slotPage = 0;
            Build();
        }

        /// <summary>Closes every menu screen and lets the story go on.</summary>
        public void Close()
        {
            SaveSettingsIfDirty();
            _stack.Clear();
            HideConfirm();
            if (_root != null) _root.style.display = DisplayStyle.None;
            if (_story != null) _story.Paused = false;
        }

        private void Back()
        {
            if (_confirmOpen)
            {
                ConfirmAnswer(false);
                return;
            }
            if (_stack.Count == 0) return;
            Page top = _stack[_stack.Count - 1];
            if (top == Page.Pause)
            {
                Close();
                return;
            }
            if (top == Page.Title) return;
            if (top == Page.Settings) SaveSettingsIfDirty();
            _stack.RemoveAt(_stack.Count - 1);
            Build();
        }

        private void Push(Page page)
        {
            _stack.Add(page);
            Build();
        }

        private void OnStoryFinished()
        {
            if (_ignoreFinish || !WantsTitle) return;
            ShowTitle();
        }

        private void PlayTitleMusic()
        {
            StoryConfig config = _story.Config;
            if (config == null || config.TitleMusic.Length == 0 || _story.Audio == null) return;
            string problem = _story.Audio.PlayMusic(config.TitleMusic, 1f, 0.5f, true);
            if (problem.Length > 0) Debug.LogWarning("StoryMenus: " + problem, this);
        }

        // --- Actions ------------------------------------------------------------

        private void NewGame()
        {
            Close();
            _story.ResetToStart();
            _ = _story.Play();
        }

        private void ContinueGame()
        {
            string slot = _story.LatestSlot();
            if (slot != null) LoadAndClose(slot);
            else Close();
        }

        private void LoadAndClose(string slot)
        {
            _ = LoadOffering(slot);
        }

        /// <summary>
        /// Loads a slot, first offering any product the save needs that the reader doesn't own.
        /// Gives true when it loaded.
        /// </summary>
        public async Task<bool> LoadOffering(string slot)
        {
            foreach (string id in _story.GetLockedProducts(slot))
            {
                StoryProduct product = _story.Store.GetProduct(id);
                if (product == null || !await Offer(product)) return false;
            }
            Close();
            _ = _story.LoadSlot(slot);
            return true;
        }

        private async void RestorePurchases(Button button)
        {
            button.SetEnabled(false);
            await _story.Store.Restore();
            button.text = "Purchases restored";
        }

        private void ReturnToTitle()
        {
            _ignoreFinish = true;
            try
            {
                _story.ResetToStart();
            }
            finally
            {
                _ignoreFinish = false;
            }
            ShowTitle();
        }

        private void ShowHistory()
        {
            DialoguePresenter dialogue = _story.Dialogue;
            Close();
            if (dialogue != null) dialogue.ShowHistory();
        }

        private static void QuitGame()
        {
            Application.Quit();
        }

        // --- Building the interface ---------------------------------------------

        private void EnsureUi()
        {
            if (_root != null || _story == null) return;
            StoryConfig config = _story.Config;
            ThemeStyleSheet themeSheet = theme != null ? theme : (config != null ? config.ThemeStyleSheet : null);
            _createdSettings = StoryUI.CreatePanelSettings(themeSheet, sortingOrder, config != null ? config.UiScale : 1f);
            _document = StoryUI.CreateDocument(transform, "Menus UI", _createdSettings);
            if (_document.rootVisualElement == null)
            {
                Debug.LogError("StoryMenus: the UIDocument has no root element yet. Check that its object is active.", this);
                return;
            }
            StyleSheet sheet = style;
            if (sheet == null && config != null) sheet = config.MenuStyle;
            if (sheet == null) sheet = Resources.Load<StyleSheet>(ResourcePath);
            _root = new VisualElement();
            _root.name = "vnt-menu-root";
            _root.AddToClassList("vnt-menu-root");
            StoryUI.Fill(_root, true);
            // The panel draws in front of the dialogue and takes the clicks, so none reach the story.
            _root.style.display = DisplayStyle.None;
            if (sheet != null) _root.styleSheets.Add(sheet);
            _background = new Image();
            _background.name = "vnt-menu-background";
            _background.AddToClassList("vnt-menu-background");
            _background.pickingMode = PickingMode.Ignore;
            _background.scaleMode = ScaleMode.ScaleAndCrop;
            _background.sprite = config != null ? config.TitleBackground : null;
            _background.style.display = DisplayStyle.None;
            _root.Add(_background);
            _screen = new VisualElement();
            _screen.name = "vnt-menu-screen";
            _screen.AddToClassList("vnt-menu-screen");
            _root.Add(_screen);
            BuildConfirm();
            BuildOffer();
            StoryUI.Fill(_document.rootVisualElement, false);
            _document.rootVisualElement.Add(_root);
        }

        /// <summary>Rebuilds the screen on top of the stack.</summary>
        private void Build()
        {
            if (_root == null || _stack.Count == 0) return;
            HideConfirm();
            _screen.Clear();
            _firstFocus = null;
            bool title = _stack[0] == Page.Title;
            _root.EnableInClassList("vnt-menu-root--title", title);
            _background.style.display = title && _background.sprite != null ? DisplayStyle.Flex : DisplayStyle.None;
            switch (_stack[_stack.Count - 1])
            {
                case Page.Title: BuildTitle(); break;
                case Page.Pause: BuildPause(); break;
                case Page.Save: BuildSlots(true); break;
                case Page.Load: BuildSlots(false); break;
                case Page.Settings: BuildSettings(); break;
            }
            _root.style.display = DisplayStyle.Flex;
            _story.Paused = true;
            FocusFirst();
        }

        private void BuildTitle()
        {
            StoryConfig config = _story.Config;
            string gameTitle = config != null ? config.Title : "";
            if (gameTitle.Length == 0) gameTitle = Application.productName;
            var heading = new Label();
            heading.name = "vnt-menu-game-title";
            heading.AddToClassList("vnt-menu-game-title");
            heading.enableRichText = false;
            heading.text = gameTitle;
            _screen.Add(heading);
            Button newGame = AddButton(_screen, "vnt-menu-new", "New Game", NewGame);
            Button resume = AddButton(_screen, "vnt-menu-continue", "Continue", ContinueGame);
            resume.SetEnabled(_story.LatestSlot() != null);
            AddButton(_screen, "vnt-menu-load", "Load", delegate { Push(Page.Load); });
            AddButton(_screen, "vnt-menu-settings", "Settings", delegate { Push(Page.Settings); });
            AddRestoreButton();
            AddButton(_screen, "vnt-menu-quit", "Quit", QuitGame);
            _firstFocus = newGame;
        }

        private void BuildPause()
        {
            AddHeading("Paused");
            Button resume = AddButton(_screen, "vnt-menu-resume", "Resume", Close);
            AddButton(_screen, "vnt-menu-save", "Save", delegate { Push(Page.Save); });
            AddButton(_screen, "vnt-menu-load", "Load", delegate { Push(Page.Load); });
            AddButton(_screen, "vnt-menu-settings", "Settings", delegate { Push(Page.Settings); });
            Button history = AddButton(_screen, "vnt-menu-history", "History", ShowHistory);
            history.SetEnabled(_story.Dialogue != null);
            AddRestoreButton();
            if (WantsTitle)
                AddButton(_screen, "vnt-menu-title", "Title", delegate
                {
                    Confirm("Return to the title? Unsaved progress is lost.", ReturnToTitle);
                });
            AddButton(_screen, "vnt-menu-quit", "Quit", delegate
            {
                Confirm("Quit the game? Unsaved progress is lost.", QuitGame);
            });
            _firstFocus = resume;
        }

        private void BuildSlots(bool saving)
        {
            AddHeading(saving ? "Save" : "Load");
            var pages = new VisualElement();
            pages.name = "vnt-menu-pages";
            pages.AddToClassList("vnt-menu-pages");
            for (int i = 0; i < SlotPages; i++)
            {
                int index = i;
                Button page = AddButton(pages, "vnt-menu-page-" + (i + 1), (i + 1).ToString(CultureInfo.InvariantCulture),
                    delegate
                    {
                        _slotPage = index;
                        Build();
                    }, "vnt-menu-page");
                page.EnableInClassList("vnt-on", i == _slotPage);
            }
            _screen.Add(pages);
            var grid = new VisualElement();
            grid.name = "vnt-menu-slots";
            grid.AddToClassList("vnt-menu-slots");
            for (int i = 0; i < SlotsPerPage; i++)
                AddSlot(grid, "slot" + (_slotPage * SlotsPerPage + i + 1).ToString(CultureInfo.InvariantCulture), saving);
            if (!saving && _slotPage == 0)
            {
                if (_story.HasSlot("quick")) AddSlot(grid, "quick", false);
                if (_story.HasSlot("auto")) AddSlot(grid, "auto", false);
            }
            _screen.Add(grid);
            AddButton(_screen, "vnt-menu-back", "Back", Back);
            // The first slot that can be pressed gets the focus.
            _firstFocus = grid.Q<Button>("vnt-menu-slot-button");
            if (_firstFocus == null) _firstFocus = _screen.Q<Button>("vnt-menu-back");
        }

        /// <summary>Restore purchases, shown when the game has products and the store can restore. Apple requires it.</summary>
        private void AddRestoreButton()
        {
            if (!_story.Store.CanRestore) return;
            Button restore = null;
            restore = AddButton(_screen, "vnt-menu-restore", "Restore purchases", delegate { RestorePurchases(restore); });
        }

        private void AddSlot(VisualElement grid, string slot, bool saving)
        {
            SlotInfo info = _story.GetSlotInfo(slot);
            var holder = new VisualElement();
            holder.name = "vnt-menu-slot-" + slot;
            holder.AddToClassList("vnt-menu-slot");
            var button = new Button();
            button.name = "vnt-menu-slot-button";
            button.AddToClassList("vnt-menu-slot-button");
            button.enableRichText = false;
            string label = SlotLabel(slot);
            if (info == null)
            {
                button.text = label + "\nEmpty";
                button.AddToClassList("vnt-empty");
                // An empty slot can take a save. When loading, it does nothing.
                if (saving) button.clicked += delegate { SaveTo(slot); };
                else button.SetEnabled(false);
            }
            else
            {
                List<string> locked = saving ? new List<string>() : _story.Store.Missing(info.Needs);
                button.text = label + "   " + info.SavedAt.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture)
                    + "\n" + (locked.Count > 0 ? "Locked: " + ProductTitles(locked) : Shorten(info.Speaker, info.Text));
                button.EnableInClassList("vnt-locked", locked.Count > 0);
                if (saving)
                    button.clicked += delegate { Confirm("Overwrite " + SlotWords(slot) + "?", delegate { SaveTo(slot); }); };
                else
                    button.clicked += delegate { LoadAndClose(slot); };
            }
            holder.Add(button);
            if (info != null)
                AddButton(holder, "vnt-menu-delete", "Delete", delegate
                {
                    Confirm("Delete " + SlotWords(slot) + "?", delegate
                    {
                        _story.DeleteSlot(slot);
                        Build();
                    });
                }, "vnt-menu-delete");
            grid.Add(holder);
        }

        private void SaveTo(string slot)
        {
            _story.SaveSlot(slot);
            Build();
        }

        private string ProductTitles(List<string> ids)
        {
            var titles = new List<string>();
            foreach (string id in ids)
            {
                StoryProduct product = _story.Store.GetProduct(id);
                titles.Add(product != null ? product.DisplayTitle : id);
            }
            return string.Join(", ", titles);
        }

        private static string SlotLabel(string slot)
        {
            if (slot == "quick") return "Quick save";
            if (slot == "auto") return "Autosave";
            if (slot.StartsWith("slot", StringComparison.Ordinal)) return "Slot " + slot.Substring(4);
            return slot;
        }

        private static string SlotWords(string slot)
        {
            if (slot == "quick") return "the quick save";
            if (slot == "auto") return "the autosave";
            if (slot.StartsWith("slot", StringComparison.Ordinal)) return "slot " + slot.Substring(4);
            return "slot " + slot;
        }

        private static string Shorten(string speaker, string text)
        {
            string line = string.IsNullOrEmpty(speaker) ? text : speaker + ": " + text;
            if (string.IsNullOrEmpty(line)) return "";
            line = line.Replace('\n', ' ').Replace('\r', ' ');
            if (line.Length > SlotTextLength) line = line.Substring(0, SlotTextLength - 3).TrimEnd() + "...";
            return line;
        }

        private void BuildSettings()
        {
            AddHeading("Settings");
            var list = new VisualElement();
            list.name = "vnt-menu-settings-list";
            list.AddToClassList("vnt-menu-settings");
            _screen.Add(list);
            StorySettings s = _settings;
            VisualElement first = AddSlider(list, "Text speed", "vnt-menu-text-speed", 0f, StorySettings.MaxTextSpeed, s.textSpeed,
                delegate (float v) { return v <= 0f ? "Instant" : Mathf.RoundToInt(v) + " /s"; },
                delegate (float v) { s.textSpeed = Mathf.Round(v); });
            AddSlider(list, "Auto delay", "vnt-menu-auto-delay", 0.2f, 5f, s.autoDelay,
                delegate (float v) { return (Mathf.Round(v * 10f) / 10f).ToString("0.0", CultureInfo.InvariantCulture) + " s"; },
                delegate (float v) { s.autoDelay = Mathf.Round(v * 10f) / 10f; });
            AddToggle(list, "Skip unread lines", "vnt-menu-skip-unread", s.skipUnread, delegate (bool v) { s.skipUnread = v; });
            AddSlider(list, "Master volume", "vnt-menu-master-volume", 0f, 1f, s.masterVolume, Percent, delegate (float v) { s.masterVolume = v; });
            AddSlider(list, "Music volume", "vnt-menu-music-volume", 0f, 1f, s.musicVolume, Percent, delegate (float v) { s.musicVolume = v; });
            AddSlider(list, "Sound volume", "vnt-menu-sound-volume", 0f, 1f, s.soundVolume, Percent, delegate (float v) { s.soundVolume = v; });
            AddToggle(list, "Full screen", "vnt-menu-full-screen", s.fullScreen, delegate (bool v) { s.fullScreen = v; });
            var row = new VisualElement();
            row.AddToClassList("vnt-menu-buttons");
            AddButton(row, "vnt-menu-defaults", "Defaults", ResetSettings);
            AddButton(row, "vnt-menu-back", "Back", Back);
            _screen.Add(row);
            _firstFocus = first;
        }

        private static string Percent(float v)
        {
            return Mathf.RoundToInt(v * 100f) + "%";
        }

        private VisualElement AddSlider(VisualElement parent, string label, string elementName, float min, float max, float value,
            Func<float, string> format, Action<float> set)
        {
            var row = new VisualElement();
            row.AddToClassList("vnt-menu-setting-row");
            var slider = new Slider(label, min, max);
            slider.name = elementName;
            slider.AddToClassList("vnt-menu-setting");
            slider.value = value;
            var readout = new Label(format(value));
            readout.AddToClassList("vnt-menu-setting-value");
            slider.RegisterValueChangedCallback(delegate (ChangeEvent<float> evt)
            {
                set(evt.newValue);
                readout.text = format(evt.newValue);
                SettingChanged();
            });
            row.Add(slider);
            row.Add(readout);
            parent.Add(row);
            return slider;
        }

        private void AddToggle(VisualElement parent, string label, string elementName, bool value, Action<bool> set)
        {
            var row = new VisualElement();
            row.AddToClassList("vnt-menu-setting-row");
            var toggle = new Toggle(label);
            toggle.name = elementName;
            toggle.AddToClassList("vnt-menu-setting");
            toggle.value = value;
            toggle.RegisterValueChangedCallback(delegate (ChangeEvent<bool> evt)
            {
                set(evt.newValue);
                SettingChanged();
            });
            row.Add(toggle);
            parent.Add(row);
        }

        private void SettingChanged()
        {
            _settings.Clamp();
            _settings.Apply(_story);
            _settingsDirty = true;
        }

        private void ResetSettings()
        {
            _settings = StorySettings.Defaults(_story.Config);
            _settings.Apply(_story);
            _settingsDirty = true;
            Build();
        }

        private void SaveSettingsIfDirty()
        {
            if (!_settingsDirty || _settings == null) return;
            _settingsDirty = false;
            _settings.Save();
        }

        private void AddHeading(string text)
        {
            var heading = new Label(text);
            heading.name = "vnt-menu-heading";
            heading.AddToClassList("vnt-menu-heading");
            _screen.Add(heading);
        }

        private static Button AddButton(VisualElement parent, string buttonName, string text, Action onClick, string className = "vnt-menu-button")
        {
            var button = new Button();
            button.name = buttonName;
            button.text = text;
            button.AddToClassList(className);
            button.clicked += onClick;
            parent.Add(button);
            return button;
        }

        private void FocusFirst()
        {
            VisualElement target = _firstFocus;
            if (target == null || _root == null) return;
            // The new elements join the panel on the next update, so the focus waits for it.
            _root.schedule.Execute(() => target.Focus());
        }

        // --- Purchase screen ----------------------------------------------------

        private void BuildOffer()
        {
            _offerLayer = new VisualElement();
            _offerLayer.name = "vnt-menu-offer";
            _offerLayer.AddToClassList("vnt-menu-confirm");
            _offerLayer.AddToClassList("vnt-menu-offer");
            _offerLayer.style.display = DisplayStyle.None;
            var box = new VisualElement();
            box.name = "vnt-menu-offer-box";
            box.AddToClassList("vnt-menu-confirm-box");
            box.AddToClassList("vnt-menu-offer-box");
            _offerPicture = new Image();
            _offerPicture.name = "vnt-menu-offer-picture";
            _offerPicture.AddToClassList("vnt-menu-offer-picture");
            _offerPicture.scaleMode = ScaleMode.ScaleToFit;
            box.Add(_offerPicture);
            _offerTitle = AddOfferLabel(box, "vnt-menu-offer-title");
            _offerDescription = AddOfferLabel(box, "vnt-menu-offer-description");
            _offerPrice = AddOfferLabel(box, "vnt-menu-offer-price");
            _offerMessage = AddOfferLabel(box, "vnt-menu-offer-message");
            var row = new VisualElement();
            row.AddToClassList("vnt-menu-buttons");
            _offerBuy = AddButton(row, "vnt-menu-offer-buy", "Buy", delegate { _ = BuyOffered(); });
            _offerDecline = AddButton(row, "vnt-menu-offer-decline", "Not now", DeclineOffer);
            box.Add(row);
            _offerLayer.Add(box);
            _root.Add(_offerLayer);
        }

        private static Label AddOfferLabel(VisualElement parent, string elementName)
        {
            var label = new Label();
            label.name = elementName;
            label.AddToClassList(elementName);
            label.AddToClassList("vnt-menu-confirm-message");
            label.enableRichText = false;
            parent.Add(label);
            return label;
        }

        /// <summary>
        /// Shows the purchase screen for a product: its picture, title, description, and the
        /// store's price, with Buy and Not now. Gives true when the reader owns it afterwards.
        /// <see cref="StoryStore.Offer"/> uses it for offer() and @needs in tales.
        /// </summary>
        public Task<bool> Offer(StoryProduct product)
        {
            EnsureUi();
            if (_root == null || product == null) return Task.FromResult(false);
            if (_offerDone != null) return Task.FromResult(_story.Store.Owns(product.id));
            _offerProduct = product;
            _offerDone = new TaskCompletionSource<bool>();
            _offerPicture.sprite = product.picture;
            _offerPicture.style.display = product.picture != null ? DisplayStyle.Flex : DisplayStyle.None;
            _offerTitle.text = product.DisplayTitle;
            _offerDescription.text = product.description ?? "";
            _offerDescription.style.display = string.IsNullOrEmpty(product.description) ? DisplayStyle.None : DisplayStyle.Flex;
            string price = _story.Store.GetPrice(product.id);
            _offerPrice.text = price;
            _offerPrice.style.display = price.Length > 0 ? DisplayStyle.Flex : DisplayStyle.None;
            ShowOfferMessage("");
            _offerBuy.style.display = DisplayStyle.Flex;
            _offerBuy.SetEnabled(true);
            _offerDecline.SetEnabled(true);
            _offerDecline.text = "Not now";
            _offerPausedStory = !_story.Paused;
            _story.Paused = true;
            _root.style.display = DisplayStyle.Flex;
            if (_screen != null) _screen.SetEnabled(false);
            _offerLayer.style.display = DisplayStyle.Flex;
            Button target = _offerBuy;
            _root.schedule.Execute(() => target.Focus());
            return _offerDone.Task;
        }

        private async Task BuyOffered()
        {
            if (_offerProduct == null) return;
            _offerBuy.SetEnabled(false);
            _offerDecline.SetEnabled(false);
            PurchaseResult result = await _story.Store.Purchase(_offerProduct.id);
            if (_offerDone == null) return;
            _offerBuy.SetEnabled(true);
            _offerDecline.SetEnabled(true);
            switch (result)
            {
                case PurchaseResult.Bought:
                    FinishOffer(true);
                    break;
                case PurchaseResult.Pending:
                    ShowOfferMessage("Your purchase is waiting for the store to confirm it.");
                    _offerBuy.style.display = DisplayStyle.None;
                    _offerDecline.text = "OK";
                    break;
                case PurchaseResult.Failed:
                    ShowOfferMessage("The purchase didn't go through. Please try again.");
                    break;
            }
        }

        /// <summary>Closes the purchase screen without buying.</summary>
        private void DeclineOffer()
        {
            if (_offerProduct == null) return;
            FinishOffer(_story.Store.Owns(_offerProduct.id));
        }

        private void FinishOffer(bool owned)
        {
            TaskCompletionSource<bool> done = _offerDone;
            _offerDone = null;
            _offerProduct = null;
            _offerLayer.style.display = DisplayStyle.None;
            if (_screen != null) _screen.SetEnabled(true);
            if (_stack.Count == 0) _root.style.display = DisplayStyle.None;
            else FocusFirst();
            if (_offerPausedStory && _stack.Count == 0) _story.Paused = false;
            if (done != null) done.TrySetResult(owned);
        }

        private void ShowOfferMessage(string text)
        {
            _offerMessage.text = text;
            _offerMessage.style.display = text.Length > 0 ? DisplayStyle.Flex : DisplayStyle.None;
        }

        // --- Confirm dialog -----------------------------------------------------

        private void BuildConfirm()
        {
            _confirmLayer = new VisualElement();
            _confirmLayer.name = "vnt-menu-confirm";
            _confirmLayer.AddToClassList("vnt-menu-confirm");
            _confirmLayer.style.display = DisplayStyle.None;
            var box = new VisualElement();
            box.name = "vnt-menu-confirm-box";
            box.AddToClassList("vnt-menu-confirm-box");
            _confirmMessage = new Label();
            _confirmMessage.name = "vnt-menu-confirm-message";
            _confirmMessage.AddToClassList("vnt-menu-confirm-message");
            _confirmMessage.enableRichText = false;
            box.Add(_confirmMessage);
            var row = new VisualElement();
            row.AddToClassList("vnt-menu-buttons");
            AddButton(row, "vnt-menu-yes", "Yes", delegate { ConfirmAnswer(true); });
            _confirmNo = AddButton(row, "vnt-menu-no", "No", delegate { ConfirmAnswer(false); });
            box.Add(row);
            _confirmLayer.Add(box);
            _root.Add(_confirmLayer);
        }

        /// <summary>Asks a yes or no question over the open screen. No has the focus, since Yes can lose progress.</summary>
        private void Confirm(string message, Action onYes)
        {
            _confirmMessage.text = message;
            _confirmYes = onYes;
            _confirmOpen = true;
            _confirmLayer.style.display = DisplayStyle.Flex;
            // Keys and the gamepad must not reach the screen below the dialog.
            _screen.SetEnabled(false);
            VisualElement target = _confirmNo;
            _root.schedule.Execute(() => target.Focus());
        }

        private void ConfirmAnswer(bool yes)
        {
            Action action = _confirmYes;
            HideConfirm();
            if (yes && action != null) action();
            else FocusFirst();
        }

        private void HideConfirm()
        {
            _confirmOpen = false;
            _confirmYes = null;
            if (_confirmLayer != null) _confirmLayer.style.display = DisplayStyle.None;
            if (_screen != null) _screen.SetEnabled(true);
        }
    }
}
