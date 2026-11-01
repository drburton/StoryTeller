using TaleScript;
using UnityEditor;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>Shows what the importer found in a tale: its beats, its problems, and its source.</summary>
    [CustomEditor(typeof(TaleAsset))]
    public class TaleAssetEditor : Editor
    {
        private const int MaxProblems = 50;
        private const int MaxSourceCharacters = 6000;

        private Vector2 _scroll;

        public override void OnInspectorGUI()
        {
            var asset = (TaleAsset)target;
            EditorGUILayout.LabelField("Tale", asset.TaleName);
            EditorGUILayout.LabelField("Beats", asset.Beats.Count == 0 ? "none" : string.Join(", ", asset.Beats));

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Problems", EditorStyles.boldLabel);
            if (asset.Diagnostics.Count == 0)
            {
                EditorGUILayout.HelpBox("No problems found.", MessageType.Info);
            }
            else
            {
                int shown = 0;
                foreach (TaleAssetDiagnostic problem in asset.Diagnostics)
                {
                    if (shown++ >= MaxProblems)
                    {
                        EditorGUILayout.LabelField("And " + (asset.Diagnostics.Count - MaxProblems) + " more.");
                        break;
                    }
                    string message = "Line " + problem.line + ": " + problem.message;
                    EditorGUILayout.HelpBox(message, problem.severity == TaleSeverity.Error ? MessageType.Error : MessageType.Warning);
                }
            }

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Source", EditorStyles.boldLabel);
            string source = asset.Source;
            if (source.Length > MaxSourceCharacters) source = source.Substring(0, MaxSourceCharacters) + "\n...";
            _scroll = EditorGUILayout.BeginScrollView(_scroll, GUILayout.MaxHeight(320f));
            GUILayout.Label(source, EditorStyles.wordWrappedLabel);
            EditorGUILayout.EndScrollView();
        }
    }
}
