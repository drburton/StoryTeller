using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using NUnit.Framework;
using TaleScript;
using UnityEditor;
using UnityEngine;
using UnityEngine.TestTools;
using VisualNovelTeller;

namespace VisualNovelTeller.Tests
{
// Edit mode checks of the store (purchases, Steam, platform stores), localization, voice and
// pictures per language, and Export Strings. They run without play mode; each Check logs ok or
// FAIL, and the test fails when any check fails. Async parts run on the thread pool, where the
// test store and stand-ins complete at once.
public class StoreChecks
{
    private static int _failures;

    [Test]
    public void AllChecksPass()
    {
        _failures = 0;
        // Some checks expect errors in the log, such as offering an unknown product; the
        // checks count their own failures.
        LogAssert.ignoreFailingMessages = true;
        try
        {
            LocalizationChecks();
            LanguageAssetChecks();
            Task.Run(RunAll).Wait();
        }
        catch (Exception e)
        {
            Fail("crashed: " + e);
        }
        Assert.AreEqual(0, _failures, _failures + " checks failed; see the log for FAIL lines.");
    }

    // Runs on the main thread: it makes Unity objects.
    private static void LocalizationChecks()
    {
        const string csv = "keys,en,es,_context,_status\nmain:hello,\"Hello, {name}.\",\"Hola, {name}.\",x,\nBuy,Buy,Comprar,menu,\nOverwrite {0}?,Overwrite {0}?,¿Sobrescribir {0}?,menu,\nSlot {0},Slot {0},Ranura {0},menu,\nThe whole story,The whole story,La historia completa,x,\n";
        var config = ScriptableObject.CreateInstance<StoryConfig>();
        config.TranslationFile = new TextAsset(csv);
        var loc = new StoryLocalization(config);
        Check(string.Join(",", loc.Languages) == "en,es", "localization: languages from the file");
        Check(loc.Language == "en" && loc.IsSourceLanguage, "localization: starts in the source language");
        Check(loc.Translate("main:hello") == "main:hello", "localization: lines keep their own text in the source language");
        Check(loc.T("Buy") == "Buy", "localization: menu text in the source language");
        int changes = 0;
        loc.LanguageChanged += () => changes++;
        loc.Language = "es";
        Check(changes == 1 && loc.Language == "es", "localization: switching language");
        Check(loc.Translate("main:hello") == "Hola, {name}.", "localization: a line in Spanish");
        Check(loc.T("Buy") == "Comprar", "localization: a menu label in Spanish");
        Check(loc.T("Overwrite {0}?", loc.T("Slot {0}", 3)) == "¿Sobrescribir Ranura 3?", "localization: formatted menu text");
        Check(loc.T("Not translated") == "Not translated", "localization: missing text stays as it is");
        loc.Language = "fr";
        Check(loc.Language == "es", "localization: a language the file lacks is ignored");
        Check(loc.PickLanguage("es") == "es" && loc.PickLanguage("de") == loc.PickLanguage(""), "localization: picking the start language");
        Check(StoryLocalization.LanguageName("es") == "Español", "localization: language names: " + StoryLocalization.LanguageName("es"));
        Check(new StoryLocalization(ScriptableObject.CreateInstance<StoryConfig>()).Languages.Count == 1, "localization: no file, source language only");

        // Export Strings collects the tales' strings and the config's own text.
        var director = new TaleDirector();
        TaleBuildResult built = TaleCompiler.Build("@title(\"The Visit\")\nbeat start:\n\t\"Hello, friend.\"\n", "main", director.MakeCheckContext("main"));
        var so = new SerializedObject(config);
        so.FindProperty("title").stringValue = "My Game";
        var products = so.FindProperty("products");
        products.arraySize = 1;
        products.GetArrayElementAtIndex(0).FindPropertyRelative("id").stringValue = "full_story";
        products.GetArrayElementAtIndex(0).FindPropertyRelative("title").stringValue = "The whole story";
        products.GetArrayElementAtIndex(0).FindPropertyRelative("description").stringValue = "Chapters two to five.";
        var cast = so.FindProperty("cast");
        cast.arraySize = 1;
        cast.GetArrayElementAtIndex(0).FindPropertyRelative("id").stringValue = "ada";
        so.ApplyModifiedPropertiesWithoutUndo();
        var keys = new List<string>();
        foreach (var entry in StringsExport.Collect(config, new[] { built.Tale })) keys.Add(entry.Key.StartsWith("main:") ? "line" : entry.Key);
        string joined = string.Join("|", keys);
        Check(joined.StartsWith("The Visit|line|Ada|The whole story|Chapters two to five.|My Game|New Game|"), "export: tales, cast, products, title, then menus: " + joined.Substring(0, Math.Min(120, joined.Length)));
        Check(keys.Contains("Restore purchases") && keys.Contains("Locked: {0}"), "export: purchase screen text");
        string written = TaleStrings.Write(csv, StringsExport.Collect(config, new[] { built.Tale }), "en", null);
        Check(TaleStrings.Parse(written).Translate("Buy", "es") == "Comprar", "export: an existing translation is kept");
    }

    private static Sprite MakeSprite(string name)
    {
        var sprite = Sprite.Create(new Texture2D(4, 4), new Rect(0, 0, 4, 4), Vector2.zero);
        sprite.name = name;
        return sprite;
    }

    // Voice and pictures per language. Runs on the main thread: it loads assets.
    private static void LanguageAssetChecks()
    {
        // Voice clips listed in the config; the Resources/Voice folders work the same way.
        var config = ScriptableObject.CreateInstance<StoryConfig>();
        var line = new NamedClip { name = "line_01", clip = AudioClip.Create("line_01_en", 11025, 1, 22050, false) };
        line.languages.Add(new LanguageClip { language = "es", clip = AudioClip.Create("line_01_es", 22050, 1, 22050, false) });
        var onlyEnglish = new NamedClip { name = "only_en", clip = AudioClip.Create("only_en", 5512, 1, 22050, false) };
        typeof(StoryConfig).GetField("voiceClips", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
            .SetValue(config, new List<NamedClip> { line, onlyEnglish });
        Check(config.FindVoice("line_01", "es").name == "line_01_es", "voice: the Spanish recording");
        Check(config.FindVoice("line_01", "en").name == "line_01_en", "voice: the English recording");
        Check(config.FindVoice("only_en", "es").name == "only_en", "voice: a line Spanish lacks plays in the source language");
        Check(config.FindVoice("vnt_missing_clip", "es") == null, "voice: a missing clip is null");

        var listed = new NamedClip { name = "line_01", clip = AudioClip.Create("listed_en", 100, 1, 22050, false) };
        listed.languages.Add(new LanguageClip { language = "fr", clip = AudioClip.Create("listed_fr", 100, 1, 22050, false) });
        Check(listed.For("fr").name == "listed_fr" && listed.For("es").name == "listed_en" && listed.For(null).name == "listed_en", "voice: listed clips with versions per language");

        var backdrop = new NamedSprite { name = "street", sprite = MakeSprite("street_en") };
        backdrop.languages.Add(new LanguageSprite { language = "es", sprite = MakeSprite("street_es") });
        Check(backdrop.For("es").name == "street_es", "pictures: the Spanish version of a picture with text");
        Check(backdrop.For("fr").name == "street_en" && backdrop.For(null).name == "street_en", "pictures: other languages use the main picture");
        var member = new CastMember { id = "ada" };
        var mood = new NamedSprite { name = "sign", sprite = MakeSprite("sign_en") };
        mood.languages.Add(new LanguageSprite { language = "es", sprite = MakeSprite("sign_es") });
        member.moods.Add(mood);
        Check(member.FindMood("sign", "es").name == "sign_es" && member.FindMood("sign").name == "sign_en", "pictures: cast moods per language");

        var so = new SerializedObject(config);
        so.FindProperty("backdrops").arraySize = 0;
        so.ApplyModifiedPropertiesWithoutUndo();
        Check(config.TitleBackgroundFor("es") == null, "pictures: no title picture gives null");

        var director = new TaleDirector();
        StoryActions.Register(director, null);
        TaleBuildResult built = TaleCompiler.Build("beat start:\n\tvoice(\"line_01\")\n\t@voice(\"line_01\")\n\t\"Hello.\"\n", "main", director.MakeCheckContext("main"));
        Check(built.Tale != null, "voice: tales may use voice() and @voice in Unity");
        bool voiced = false;
        foreach (var instruction in built.Tale.Instructions)
            if (instruction.Op == TaleOp.Say && instruction.Voice == "line_01") voiced = true;
        Check(voiced, "voice: @voice reaches the line");
    }

    private static async Task RunAll()
    {
        await StoreBasics();
        await CacheWhileOffline();
        await NeedsBeats();
        await LockedSaveData();
        PlatformBackendIsRegistered();
        await SteamBackend();
        PlatformPriority();
    }

    private class FakeSteam : ISteamStoreApi
    {
        public readonly HashSet<uint> Owned = new HashSet<uint>();
        public bool Overlay = true;
        public uint Opened;
        public bool BuyWhenOpened = true;
        public event Action<uint> DlcInstalled;
        public event Action<bool> OverlayActivated;
        public bool OwnsDlc(uint appId) { return Owned.Contains(appId); }
        public bool OverlayEnabled { get { return Overlay; } }
        public void OpenStoreOverlay(uint appId)
        {
            Opened = appId;
            OverlayActivated?.Invoke(true);
            if (BuyWhenOpened)
            {
                Owned.Add(appId);
                DlcInstalled?.Invoke(appId);
            }
            OverlayActivated?.Invoke(false);
        }
        public void Refund(uint appId) { Owned.Remove(appId); DlcInstalled?.Invoke(appId); }
    }

    private static async Task SteamBackend()
    {
        var products = Products();
        products[0].steamAppId = 1234567;
        var store = new StoryStore(products);
        var steam = new FakeSteam();
        steam.Owned.Add(1234567);
        await store.SetBackend(new SteamStoreBackend(steam));
        Check(store.Owns("full_story"), "steam: DLC owned on the account");
        Check(store.GetPrice("full_story") == "", "steam: no price from Steam");
        Check(!store.CanRestore, "steam: nothing to restore");
        steam.Refund(1234567);
        Check(!store.Owns("full_story"), "steam: losing the DLC locks it");
        Check(await store.Purchase("full_story") == PurchaseResult.Bought && steam.Opened == 1234567, "steam: buying through the overlay");
        Check(store.Owns("full_story"), "steam: owned after buying");
        steam.Refund(1234567);
        steam.BuyWhenOpened = false;
        Check(await store.Purchase("full_story") == PurchaseResult.Cancelled, "steam: closing the overlay without buying cancels");
        steam.Overlay = false;
        Check(await store.Purchase("full_story") == PurchaseResult.Failed, "steam: no overlay, no purchase");
        Check(await store.Purchase("bonus") == PurchaseResult.Failed, "steam: a product without a Steam app id fails");
        steam.Overlay = true;
        steam.BuyWhenOpened = true;
        var run = await Play(store, PaidNeeds);
        Check(string.Join("|", run.Item1.Lines) == "Free.|Paid.", "steam: a @needs beat buys through Steam");
    }

    private const string PaidNeeds = "beat start:\n\t\"Free.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n";

    private static void PlatformPriority()
    {
        StoreBackend low = new StoreBackend();
        StoreBackend high = new TestStoreBackend();
        StoryStore.AddPlatformBackend(() => low, -100);
        StoryStore.AddPlatformBackend(() => null, 1000);
        StoryStore.AddPlatformBackend(() => high, 500);
        // In the editor the real Steam and IAP factories give null (they only apply in players).
        Check(StoryStore.MakePlatformBackend() == high, "platform stores: highest priority that applies wins");
    }

    private static List<StoryProduct> Products()
    {
        return new List<StoryProduct>
        {
            new StoryProduct { id = "full_story", title = "The whole story", testPrice = "$4.99" },
            new StoryProduct { id = "bonus", title = "Bonus" },
        };
    }

    private static async Task StoreBasics()
    {
        var store = new StoryStore(Products());
        var test = new TestStoreBackend();
        await store.SetBackend(test);
        Check(!store.Owns("full_story"), "owns nothing at first");
        Check(store.GetPrice("full_story") == "$4.99", "test price");
        Check(store.CanRestore, "the test store can restore");
        int changes = 0;
        store.OwnershipChanged += () => changes++;
        Check(await store.Purchase("full_story") == PurchaseResult.Bought, "buying works");
        Check(store.Owns("full_story") && changes == 1, "bought and announced");
        test.NextResult = PurchaseResult.Cancelled;
        Check(!await store.Offer("bonus"), "a cancelled offer owns nothing");
        Check(await store.Offer("bonus"), "the next offer buys");
        test.NextResult = PurchaseResult.Failed;
        Check(await store.Offer("bonus"), "an owned product needs no purchase");
        test.SetOwned("bonus", false);
        Check(!store.Owns("bonus"), "a refund locks it again");
        Check(!await store.Offer("nope"), "an unknown product is not owned");
        Check(store.Missing(new[] { "full_story", "bonus" }).Count == 1, "Missing lists what isn't owned");
    }

    private class Offline : StoreBackend
    {
        public override bool IsReady { get { return false; } }
    }

    private static async Task CacheWhileOffline()
    {
        string cache = Path.Combine(Path.GetTempPath(), "vnt_store_check.json");
        if (File.Exists(cache)) File.Delete(cache);
        var first = new StoryStore(Products(), cache);
        var test = new TestStoreBackend();
        await first.SetBackend(test);
        test.SetOwned("full_story", true);
        var second = new StoryStore(Products(), cache);
        await second.SetBackend(new Offline());
        Check(second.Owns("full_story"), "what was owned last time is used while the store hasn't answered");
        var third = new StoryStore(Products(), cache);
        await third.SetBackend(new TestStoreBackend());
        Check(!third.Owns("full_story"), "the store's answer wins once it has one");
        File.Delete(cache);
    }

    private class Player : TalePresenter
    {
        public readonly List<string> Lines = new List<string>();

        public override Task ShowLine(OrderedMap<object> line)
        {
            Lines.Add(GdValue.Str(line["text"]));
            return Task.CompletedTask;
        }

        public override Task<int> Choose(List<OrderedMap<object>> options, OrderedMap<object> settings)
        {
            return Task.FromResult(0);
        }

        public override void Cancel()
        {
        }
    }

    private const string PaidTale = "beat start:\n\t\"Free.\"\n\tif await offer(\"full_story\"):\n\t\tjump paid\n\t\"Demo ends.\"\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n";

    private static async Task<Tuple<Player, TaleDirector>> Play(StoryStore store, string source)
    {
        var director = new TaleDirector();
        StoryActions.Register(director, null);
        director.Owns = store.Owns;
        director.Offer = store.Offer;
        var player = new Player();
        director.Presenter = player;
        TaleBuildResult result = TaleCompiler.Build(source, "main", director.MakeCheckContext("main"));
        foreach (var problem in result.Diagnostics)
            if (problem.IsError()) Fail("compile: " + problem.Message);
        director.AddTale(result.Tale);
        await director.Play("main");
        return Tuple.Create(player, director);
    }

    private static async Task NeedsBeats()
    {
        var store = new StoryStore(Products());
        var test = new TestStoreBackend();
        await store.SetBackend(test);
        test.NextResult = PurchaseResult.Cancelled;
        // offer() needs a Story, so this tale only uses @needs and owns().
        var run = await Play(store, "beat start:\n\t\"Free.\"\n\tif owns(\"full_story\"):\n\t\t\"Owner.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n");
        Check(string.Join("|", run.Item1.Lines) == "Free.", "a declined @needs beat ends the story: " + string.Join("|", run.Item1.Lines));
        run = await Play(store, "beat start:\n\t\"Free.\"\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n");
        Check(string.Join("|", run.Item1.Lines) == "Free.|Paid.", "buying at the @needs beat plays it: " + string.Join("|", run.Item1.Lines));
        Check(store.Owns("full_story"), "bought on the way in");
        run = await Play(store, "beat start:\n\tif owns(\"full_story\"):\n\t\t\"Owner.\"\n");
        Check(string.Join("|", run.Item1.Lines) == "Owner.", "owns() is true after buying");
    }

    private static async Task LockedSaveData()
    {
        var store = new StoryStore(Products());
        var test = new TestStoreBackend();
        await store.SetBackend(test);
        test.SetOwned("full_story", true);
        var director = new TaleDirector();
        director.Owns = store.Owns;
        director.Offer = store.Offer;
        var player = new Player();
        director.Presenter = player;
        TaleBuildResult result = TaleCompiler.Build("beat start:\n\tjump paid\n\n@needs(\"full_story\")\nbeat paid:\n\t\"Paid.\"\n\t\"More.\"\n", "main", director.MakeCheckContext("main"));
        director.AddTale(result.Tale);
        OrderedMap<object> saved = null;
        player.Lines.Clear();
        var holding = new HoldingPlayer(() => saved = director.Capture());
        director.Presenter = holding;
        await director.Play("main");
        Check(saved != null && saved.Has("paid"), "a save in paid content records its products");
        Check(string.Join(",", director.GetPaidProducts()) == "full_story", "GetPaidProducts");
        director.Clear();
        Check(director.GetPaidProducts().Count == 0, "a new game forgets them");
        director.Restore(saved);
        Check(string.Join(",", director.GetPaidProducts()) == "full_story", "loading brings them back");
    }

    private class HoldingPlayer : TalePresenter
    {
        private readonly Action _onFirstLine;
        private bool _done;

        public HoldingPlayer(Action onFirstLine)
        {
            _onFirstLine = onFirstLine;
        }

        public override Task ShowLine(OrderedMap<object> line)
        {
            if (!_done)
            {
                _done = true;
                _onFirstLine();
            }
            return Task.CompletedTask;
        }

        public override Task<int> Choose(List<OrderedMap<object>> options, OrderedMap<object> settings)
        {
            return Task.FromResult(0);
        }

        public override void Cancel()
        {
        }
    }

    private static void PlatformBackendIsRegistered()
    {
        Check(Type.GetType("VisualNovelTeller.UnityIapStoreBackend, VisualNovelTeller.Purchasing") != null, "the Unity IAP backend is built when com.unity.purchasing is installed");
        Check(Type.GetType("VisualNovelTeller.SteamworksStoreApi, VisualNovelTeller.Steam") != null, "the Steam adapter is built when Steamworks.NET is installed");
    }

    private static void Check(bool condition, string what)
    {
        if (condition) Debug.Log("[StoreCheck] ok   " + what);
        else Fail(what);
    }

    private static void Fail(string what)
    {
        _failures++;
        Debug.LogError("[StoreCheck] FAIL " + what);
    }
}
}
