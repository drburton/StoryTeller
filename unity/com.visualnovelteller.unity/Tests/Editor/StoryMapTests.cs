using System.Collections.Generic;
using System.IO;
using System.Reflection;
using NUnit.Framework;
using TaleScript;
using UnityEditor;
using UnityEngine;

namespace VisualNovelTeller.Tests
{
    // The Story Map window: it builds the graph of a Story Config's tales, lays the beats out,
    // and keeps moved beats in tale.tale.map, the file the Godot plugin uses.
    public class StoryMapTests
    {
        private const string Folder = "Assets/VntStoryMapTest";

        [SetUp]
        public void SetUp()
        {
            Directory.CreateDirectory(Folder);
            File.WriteAllText(Folder + "/main.tale", "beat start:\n\t\"Hello.\"\n\tchoose:\n\t\t\"Left\":\n\t\t\tjump left\n\t\t\"Away\":\n\t\t\tjump side.away\n\nbeat left:\n\t\"Left.\"\n\nbeat lost:\n\tjump nowhere\n");
            File.WriteAllText(Folder + "/side.tale", "beat away:\n\t\"Away.\"\n");
            AssetDatabase.ImportAsset(Folder + "/main.tale");
            AssetDatabase.ImportAsset(Folder + "/side.tale");
        }

        [TearDown]
        public void TearDown()
        {
            AssetDatabase.DeleteAsset(Folder);
        }

        private static void SetField(object target, string name, object value)
        {
            target.GetType().GetField(name, BindingFlags.NonPublic | BindingFlags.Instance).SetValue(target, value);
        }

        private static T GetField<T>(object target, string name)
        {
            return (T)target.GetType().GetField(name, BindingFlags.NonPublic | BindingFlags.Instance).GetValue(target);
        }

        private StoryMapWindow MakeWindow()
        {
            var main = AssetDatabase.LoadAssetAtPath<TaleAsset>(Folder + "/main.tale");
            var side = AssetDatabase.LoadAssetAtPath<TaleAsset>(Folder + "/side.tale");
            Assert.IsNotNull(main, "main.tale imports as a TaleAsset");
            var config = ScriptableObject.CreateInstance<StoryConfig>();
            SetField(config, "tales", new[] { main, side });
            SetField(config, "firstTale", main);
            var window = ScriptableObject.CreateInstance<StoryMapWindow>();
            SetField(window, "config", config);
            window.Rebuild();
            return window;
        }

        [Test]
        public void TheMapHasEveryBeatAndItsProblems()
        {
            StoryMapWindow window = MakeWindow();
            var graph = GetField<TaleGraph>(window, "_graph");
            Assert.AreEqual(new List<string> { "main.start", "main.left", "main.lost", "side.away" }, new List<string>(graph.Beats.Keys));
            Assert.AreEqual(new List<string> { "main.lost" }, graph.Unreachable, "nothing leads to lost");
            Assert.AreEqual("main.nowhere", graph.Missing[0].To, "a jump to a missing beat");
            Assert.AreEqual("choice", graph.Beats["main.start"].Exits[1].Kind);
            Object.DestroyImmediate(window);
        }

        [Test]
        public void BeatsAreLaidOutInBandsAndColumns()
        {
            StoryMapWindow window = MakeWindow();
            var positions = GetField<Dictionary<string, Vector2>>(window, "_positions");
            Assert.AreEqual(new Vector2(40f, 70f), positions["main.start"], "the start beat, with the map's margin");
            Assert.AreEqual(320f, positions["main.left"].x, "one column to the right");
            Assert.Greater(positions["side.away"].y, positions["main.start"].y, "the next tale's band is below");
            Object.DestroyImmediate(window);
        }

        [Test]
        public void MovedBeatsAreSavedInTheGodotMapFile()
        {
            string talePath = Folder + "/main.tale";
            StoryMapWindow.SavePosition(talePath, "left", new Vector2(500.4f, 120.6f));
            StoryMapWindow.SavePosition(talePath, "start", new Vector2(10f, 20f));
            string json = File.ReadAllText(talePath + ".map");
            var data = (OrderedMap<object>)GdJson.Parse(json);
            var beats = (OrderedMap<object>)data["beats"];
            Assert.AreEqual(new List<object> { 500.0, 121.0 }, beats["left"], "rounded, as Godot saves them");
            Assert.AreEqual(2, beats.Count, "other beats are kept");
            Dictionary<string, Vector2> loaded = StoryMapWindow.LoadPositions(talePath);
            Assert.AreEqual(new Vector2(500f, 121f), loaded["left"]);
            AssetDatabase.ImportAsset(talePath + ".map");
            StoryMapWindow window = MakeWindow();
            var positions = GetField<Dictionary<string, Vector2>>(window, "_positions");
            Assert.AreEqual(new Vector2(500f, 121f), positions["main.left"], "a saved position wins over the layout");
            Object.DestroyImmediate(window);
        }

        [Test]
        public void AGodotMapFileIsRead()
        {
            string talePath = Folder + "/side.tale";
            File.WriteAllText(talePath + ".map", "{\n\t\"beats\": {\n\t\t\"away\": [\n\t\t\t900.0,\n\t\t\t40.0\n\t\t]\n\t}\n}\n");
            Assert.AreEqual(new Vector2(900f, 40f), StoryMapWindow.LoadPositions(talePath)["away"]);
        }
    }
}
