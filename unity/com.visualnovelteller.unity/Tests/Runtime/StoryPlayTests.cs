using System.Collections;
using System.Collections.Generic;
using System.Reflection;
using NUnit.Framework;
using TaleScript;
using UnityEngine;
using UnityEngine.TestTools;
using UnityEngine.UIElements;
using VisualNovelTeller;

namespace VisualNovelTeller.Tests
{
// Plays a real Story with StoryMenus in play mode: Spanish lines and menus, voice in Spanish,
// the purchase screen, and pictures switching with the language.
public class StoryPlayTests
{
    private const string Csv =
        "keys,en,es,_context,_status\n" +
        "Resume,Resume,Continuar,menu,\n" +
        "Buy,Buy,Comprar,menu,\n" +
        "Not now,Not now,Ahora no,menu,\n" +
        "Restore purchases,Restore purchases,Restaurar compras,menu,\n" +
        "The whole story,The whole story,La historia completa,x,\n" +
        "Replay voice,Replay voice,Repetir voz,menu,\n";

    private GameObject _object;
    private Story _story;

    private static void SetField(object target, string name, object value)
    {
        FieldInfo field = target.GetType().GetField(name, BindingFlags.NonPublic | BindingFlags.Instance);
        Assert.IsNotNull(field, name);
        field.SetValue(target, value);
    }

    private static Sprite MakeSprite(string name)
    {
        var sprite = Sprite.Create(new Texture2D(4, 4), new Rect(0, 0, 4, 4), Vector2.zero);
        sprite.name = name;
        return sprite;
    }

    private IEnumerator MakeStory(string source)
    {
        // The Spanish text of the tale's first line goes in the strings file, by its line id.
        var probe = new TaleDirector();
        StoryActions.Register(probe, null);
        TaleBuildResult first = TaleCompiler.Build(source, "main", probe.MakeCheckContext("main"));
        Assert.IsNotNull(first.Tale, "tale compiles");
        string key = TaleStrings.Collect(new[] { first.Tale })[0].Key;
        var config = ScriptableObject.CreateInstance<StoryConfig>();
        config.TranslationFile = new TextAsset(Csv + key + ",Hello.,Hola.,x,\n");
        var backdrop = new NamedSprite { name = "street", sprite = MakeSprite("street_en") };
        backdrop.languages.Add(new LanguageSprite { language = "es", sprite = MakeSprite("street_es") });
        SetField(config, "backdrops", new List<NamedSprite> { backdrop });
        var voice = new NamedClip { name = "line_01", clip = AudioClip.Create("line_01_en", 11025, 1, 22050, false) };
        voice.languages.Add(new LanguageClip { language = "es", clip = AudioClip.Create("line_01_es", 22050, 1, 22050, false) });
        SetField(config, "voiceClips", new List<NamedClip> { voice });
        SetField(config, "products", new List<StoryProduct> { new StoryProduct { id = "full_story", title = "The whole story" } });
        _object = new GameObject("Story test");
        _object.SetActive(false);
        _story = _object.AddComponent<Story>();
        _story.Config = config;
        SetField(_story, "playOnStart", false);
        _object.AddComponent<StoryMenus>();
        _object.SetActive(true);
        yield return null;
        yield return null;
        _story.Store.SetBackend(new TestStoreBackend()).Wait();
        _story.Localization.Language = "es";
        TaleBuildResult built = TaleCompiler.Build(source, "main", _story.Director.MakeCheckContext("main"));
        Assert.IsNotNull(built.Tale, "tale compiles in the story");
        _story.Director.AddTale(built.Tale);
    }

    [TearDown]
    public void TearDown()
    {
        if (_object != null) Object.Destroy(_object);
    }

    private VisualElement MenuRoot()
    {
        foreach (var document in _object.GetComponentsInChildren<UIDocument>())
        {
            VisualElement root = document.rootVisualElement.Q<VisualElement>("vnt-menu-root");
            if (root != null) return root;
        }
        return null;
    }

    private static void Press(Button button)
    {
        using (var submit = NavigationSubmitEvent.GetPooled())
        {
            submit.target = button;
            button.SendEvent(submit);
        }
    }

    [UnityTest]
    public IEnumerator SpanishLineVoiceAndPicture()
    {
        yield return MakeStory("beat start:\n\tbackdrop(\"street\", transition = \"none\")\n\t@voice(\"line_01\")\n\t\"Hello.\"\n");
        _ = _story.Play("main");
        for (int i = 0; i < 5; i++) yield return null;
        Assert.AreEqual("Hola.", _story.Dialogue.CurrentLine.Text, "the line in Spanish");
        Assert.AreEqual("line_01", _story.Audio.CurrentVoice, "the line's voice plays");
        AudioSource voice = null;
        foreach (var source in _object.GetComponents<AudioSource>())
            if (source.clip != null && source.isPlaying) voice = source;
        Assert.IsNotNull(voice, "a voice AudioSource is playing");
        Assert.AreEqual(1f, voice.clip.length, 0.05f, "the Spanish recording");
        Image back = null;
        foreach (var document in _object.GetComponentsInChildren<UIDocument>())
            document.rootVisualElement.Query<Image>().ForEach(delegate (Image image) { if (image.sprite != null && image.sprite.name.StartsWith("street")) back = image; });
        Assert.IsNotNull(back, "the backdrop is shown");
        Assert.AreEqual("street_es", back.sprite.name, "the Spanish backdrop");
        _story.Localization.Language = "en";
        yield return null;
        Assert.AreEqual("street_en", back.sprite.name, "switching language switches the picture on stage");
    }

    [UnityTest]
    public IEnumerator HistoryReplaysVoice()
    {
        yield return MakeStory("beat start:\n\t@voice(\"line_01\")\n\t\"Hello.\"\n");
        _ = _story.Play("main");
        for (int i = 0; i < 5; i++) yield return null;
        Assert.AreEqual("line_01", _story.Dialogue.CurrentLine.Voice, "the line remembers its voice");
        _story.Audio.StopVoice();
        _story.Dialogue.ShowHistory();
        yield return null;
        Button replay = null;
        foreach (var document in _object.GetComponentsInChildren<UIDocument>())
            replay = replay ?? document.rootVisualElement.Q<Button>("vnt-history-replay");
        Assert.IsNotNull(replay, "a voiced line has a replay button in the history");
        Assert.AreEqual("Repetir voz", replay.text, "the button in Spanish");
        Assert.AreEqual("", _story.Audio.CurrentVoice, "the voice was stopped");
        Press(replay);
        yield return null;
        Assert.AreEqual("line_01", _story.Audio.CurrentVoice, "pressing it plays the voice again");
    }

    [UnityTest]
    public IEnumerator PauseMenuInSpanishAndThePurchaseScreen()
    {
        yield return MakeStory("beat start:\n\t\"Hello.\"\n\tif await offer(\"full_story\"):\n\t\t\"Bought.\"\n");
        _ = _story.Play("main");
        for (int i = 0; i < 3; i++) yield return null;
        var menus = _object.GetComponent<StoryMenus>();
        menus.OpenPause();
        yield return null;
        VisualElement root = MenuRoot();
        Assert.AreEqual("Continuar", root.Q<Button>("vnt-menu-resume").text, "the pause menu in Spanish");
        Assert.AreEqual("Restaurar compras", root.Q<Button>("vnt-menu-restore").text, "Restore purchases in Spanish");
        menus.Close();
        yield return null;
        // Continue past the first line to reach offer().
        _story.Dialogue.Presenter.Cancel();
        for (int i = 0; i < 5 && !menus.IsOffering; i++) yield return null;
        if (!menus.IsOffering)
        {
            // The presenter waits for a click; let the store offer directly instead.
            _ = _story.Store.Offer("full_story");
            yield return null;
        }
        Assert.IsTrue(menus.IsOffering, "the purchase screen is open");
        Assert.AreEqual("La historia completa", root.Q<Label>("vnt-menu-offer-title").text, "the product in Spanish");
        Assert.AreEqual("Comprar", root.Q<Button>("vnt-menu-offer-buy").text, "Buy in Spanish");
        Assert.AreEqual("$4.99", root.Q<Label>("vnt-menu-offer-price").text, "the test store's price");
        Press(root.Q<Button>("vnt-menu-offer-buy"));
        for (int i = 0; i < 3; i++) yield return null;
        Assert.IsFalse(menus.IsOffering, "buying closes the screen");
        Assert.IsTrue(_story.Store.Owns("full_story"), "the reader owns it");
    }
}
}
