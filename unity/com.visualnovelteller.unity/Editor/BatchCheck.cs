using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using TaleScript;
using UnityEditor;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// A check that runs from the command line, so a project can be tested without opening
    /// the editor window:
    /// <code>Unity.exe -batchmode -nographics -projectPath MyProject -executeMethod VisualNovelTeller.BatchCheck.Run -logFile -</code>
    /// It lists each tale's import problems, plays every path of each tale from its beat
    /// <c>start</c>, and quits with exit code 1 when a tale has an error or a path finds a
    /// problem. Every report line starts with "[Visual Novel Teller]".
    /// </summary>
    public static class BatchCheck
    {
        private const string Prefix = "[Visual Novel Teller] ";

        /// <summary>Entry point for <c>-executeMethod</c>.</summary>
        public static void Run()
        {
            Task<int> check = CheckAll();
            EditorApplication.CallbackFunction wait = null;
            wait = () =>
            {
                if (!check.IsCompleted) return;
                EditorApplication.update -= wait;
                int code = 1;
                if (check.IsFaulted) Debug.LogException(check.Exception);
                else code = check.Result;
                Debug.Log(Prefix + (code == 0 ? "Check passed." : "Check failed."));
                EditorApplication.Exit(code);
            };
            EditorApplication.update += wait;
        }

        private static async Task<int> CheckAll()
        {
            var tales = new List<TaleAsset>();
            foreach (string guid in AssetDatabase.FindAssets("t:" + typeof(TaleAsset).Name))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (!path.StartsWith("Assets/", StringComparison.Ordinal)) continue;
                var tale = AssetDatabase.LoadAssetAtPath<TaleAsset>(path);
                if (tale != null) tales.Add(tale);
            }
            tales.Sort((a, b) => string.CompareOrdinal(AssetDatabase.GetAssetPath(a), AssetDatabase.GetAssetPath(b)));
            Debug.Log(Prefix + "Unity " + Application.unityVersion + ", " + tales.Count + (tales.Count == 1 ? " tale." : " tales."));

            int failures = 0;
            var sources = new Dictionary<string, string>();
            foreach (TaleAsset tale in tales)
            {
                sources[tale.TaleName] = tale.Source;
                string path = AssetDatabase.GetAssetPath(tale);
                foreach (TaleAssetDiagnostic diagnostic in tale.Diagnostics)
                {
                    bool error = diagnostic.severity == TaleSeverity.Error;
                    Debug.Log(Prefix + path + ":" + diagnostic.line + ": " + (error ? "error: " : "warning: ") + diagnostic.message);
                    if (error) failures++;
                }
            }

            StoryConfig config = PathExplorerWindow.FindConfig();
            foreach (TaleAsset tale in tales)
            {
                if (tale.HasErrors) continue;
                if (!ContainsBeat(tale, "start")) continue;
                TalePathsResult result = await TalePaths.Explore(tale.TaleName, "start", sources,
                    PathExplorerWindow.MakeOptions(config, new TalePathsOptions()));
                foreach (string line in result.Describe().Split('\n'))
                    if (line.Length > 0) Debug.Log(Prefix + line);
                if (result.HasProblems) failures++;
            }
            return failures == 0 ? 0 : 1;
        }

        private static bool ContainsBeat(TaleAsset tale, string beat)
        {
            foreach (string name in tale.Beats)
                if (name == beat) return true;
            return false;
        }
    }
}
