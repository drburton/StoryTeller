using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Menu items that put a playable story into the open scene in one step: a Story Config
    /// listing the project's tales, and a GameObject with a <see cref="Story"/> and a
    /// <see cref="DialoguePresenter"/>. Press Play afterwards to read the first tale.
    /// </summary>
    public static class StorySceneSetup
    {
        private const string ConfigPath = "Assets/Story Config.asset";

        [MenuItem("GameObject/Visual Novel Teller/Story", false, 10)]
        [MenuItem("Tools/Visual Novel Teller/Set Up Story in Scene")]
        public static void SetUp()
        {
            StoryConfig config = FindOrCreateConfig();
            var story = Object.FindFirstObjectByType<Story>();
            if (story == null)
            {
                var gameObject = new GameObject("Story");
                Undo.RegisterCreatedObjectUndo(gameObject, "Set Up Story");
                story = gameObject.AddComponent<Story>();
                gameObject.AddComponent<DialoguePresenter>();
            }
            var serialized = new SerializedObject(story);
            SerializedProperty configProperty = serialized.FindProperty("config");
            if (configProperty != null && configProperty.objectReferenceValue == null)
            {
                configProperty.objectReferenceValue = config;
                serialized.ApplyModifiedProperties();
            }
            Selection.activeGameObject = story.gameObject;
            EditorGUIUtility.PingObject(config);
            Debug.Log("Visual Novel Teller: the scene has a Story using " + AssetDatabase.GetAssetPath(config) + ". Press Play to read " +
                (config.FirstTale != null ? config.FirstTale.name : "the first tale") + ".", story);
        }

        /// <summary>The project's first Story Config, or a new one at Assets/Story Config.asset listing every tale.</summary>
        public static StoryConfig FindOrCreateConfig()
        {
            string[] found = AssetDatabase.FindAssets("t:" + typeof(StoryConfig).Name);
            StoryConfig config = found.Length > 0
                ? AssetDatabase.LoadAssetAtPath<StoryConfig>(AssetDatabase.GUIDToAssetPath(found[0]))
                : null;
            if (config == null)
            {
                config = ScriptableObject.CreateInstance<StoryConfig>();
                AssetDatabase.CreateAsset(config, AssetDatabase.GenerateUniqueAssetPath(ConfigPath));
            }
            if (config.Tales.Count == 0) AddProjectTales(config);
            return config;
        }

        private static void AddProjectTales(StoryConfig config)
        {
            var tales = new List<TaleAsset>();
            foreach (string guid in AssetDatabase.FindAssets("t:" + typeof(TaleAsset).Name))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (!path.StartsWith("Assets/")) continue;
                var tale = AssetDatabase.LoadAssetAtPath<TaleAsset>(path);
                if (tale != null) tales.Add(tale);
            }
            if (tales.Count == 0) return;
            tales.Sort((a, b) => string.CompareOrdinal(AssetDatabase.GetAssetPath(a), AssetDatabase.GetAssetPath(b)));
            var serialized = new SerializedObject(config);
            SerializedProperty list = serialized.FindProperty("tales");
            list.arraySize = tales.Count;
            for (int i = 0; i < tales.Count; i++) list.GetArrayElementAtIndex(i).objectReferenceValue = tales[i];
            SerializedProperty first = serialized.FindProperty("firstTale");
            if (first.objectReferenceValue == null) first.objectReferenceValue = tales[0];
            serialized.ApplyModifiedProperties();
            AssetDatabase.SaveAssets();
        }
    }
}
