using System;
using System.Collections.Generic;
using System.Text;
using TaleScript;
using UnityEditor;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Plays a tale down every path and lists what a player could run into: the endings,
    /// runtime errors, paths that loop or get stuck, and scenes no path reaches. Open it with
    /// Window > Visual Novel Teller > Path Explorer, pick a tale (or select one in the
    /// Project window), and press Explore. The project's <see cref="StoryConfig"/> supplies
    /// the exposed names, the cast, and the other tales. Objects from game code are
    /// replaced by stand-ins and the built-in actions do nothing, so nothing in the scene
    /// changes while it runs.
    /// </summary>
    public class PathExplorerWindow : EditorWindow
    {
        private const int MaxPathsShown = 500;
        private const int MaxChoicesShown = 12;

        [SerializeField] private TaleAsset tale;
        [SerializeField] private string beat = "start";
        [SerializeField] private int maxPaths = 1000;
        [SerializeField] private int maxChoices = 60;
        [SerializeField] private int maxLines = 2000;
        [SerializeField] private float pathSeconds = 10f;
        [SerializeField] private bool showLimits;

        private TalePathsResult _result;
        private readonly Dictionary<string, TaleAsset> _assets = new Dictionary<string, TaleAsset>();
        private bool _running;
        private bool _showPaths = true;
        private Vector2 _scroll;
        private Vector2 _pathScroll;
        private GUIStyle _rowStyle;

        [MenuItem("Window/Visual Novel Teller/Path Explorer")]
        public static void Open()
        {
            var window = GetWindow<PathExplorerWindow>();
            window.titleContent = new GUIContent("Path Explorer");
            window.minSize = new Vector2(360f, 320f);
            window.UseSelection();
        }

        private void OnEnable()
        {
            UseSelection();
        }

        private void OnSelectionChange()
        {
            if (UseSelection()) Repaint();
        }

        /// <summary>Takes the selected tale, if a tale is selected. Returns true when it changed.</summary>
        private bool UseSelection()
        {
            var selected = Selection.activeObject as TaleAsset;
            if (selected == null || selected == tale) return false;
            tale = selected;
            _result = null;
            return true;
        }

        private void OnGUI()
        {
            if (_rowStyle == null)
            {
                _rowStyle = new GUIStyle(EditorStyles.miniButton);
                _rowStyle.alignment = TextAnchor.MiddleLeft;
                _rowStyle.wordWrap = true;
            }

            EditorGUILayout.Space();
            EditorGUI.BeginChangeCheck();
            tale = (TaleAsset)EditorGUILayout.ObjectField("Tale", tale, typeof(TaleAsset), false);
            if (EditorGUI.EndChangeCheck()) _result = null;
            beat = EditorGUILayout.TextField("Start beat", beat);

            showLimits = EditorGUILayout.Foldout(showLimits, "Limits", true);
            if (showLimits)
            {
                EditorGUI.indentLevel++;
                maxPaths = Mathf.Max(1, EditorGUILayout.IntField("Paths", maxPaths));
                maxChoices = Mathf.Max(1, EditorGUILayout.IntField("Choices on a path", maxChoices));
                maxLines = Mathf.Max(1, EditorGUILayout.IntField("Lines between choices", maxLines));
                pathSeconds = Mathf.Max(0.1f, EditorGUILayout.FloatField("Seconds on a path", pathSeconds));
                EditorGUI.indentLevel--;
            }

            EditorGUILayout.BeginHorizontal();
            EditorGUI.BeginDisabledGroup(tale == null || _running);
            if (GUILayout.Button(_running ? "Exploring..." : "Explore", GUILayout.Height(24f))) Explore();
            EditorGUI.EndDisabledGroup();
            EditorGUILayout.EndHorizontal();

            if (tale == null)
            {
                EditorGUILayout.HelpBox("Pick a tale, or select a .tale file in the Project window.", MessageType.Info);
                return;
            }
            if (tale.HasErrors)
                EditorGUILayout.HelpBox("This tale has errors from import. Fix them first; they show in the Inspector.", MessageType.Warning);
            if (_result == null) return;

            _scroll = EditorGUILayout.BeginScrollView(_scroll);
            DrawResult(_result);
            EditorGUILayout.EndScrollView();
        }

        // --- Running ---------------------------------------------------------------

        private async void Explore()
        {
            if (_running || tale == null) return;
            _running = true;
            _result = null;
            Repaint();
            try
            {
                StoryConfig config = FindConfig();
                var sources = new Dictionary<string, string>();
                _assets.Clear();
                if (config != null)
                {
                    foreach (TaleAsset other in config.Tales)
                    {
                        if (other == null || string.IsNullOrEmpty(other.TaleName)) continue;
                        sources[other.TaleName] = other.Source;
                        _assets[other.TaleName] = other;
                    }
                }
                sources[tale.TaleName] = tale.Source;
                _assets[tale.TaleName] = tale;

                TalePathsResult result = await TalePaths.Explore(tale.TaleName, string.IsNullOrEmpty(beat) ? "start" : beat,
                    sources, MakeOptions(config));
                _result = result;
            }
            catch (Exception e)
            {
                Debug.LogException(e);
            }
            finally
            {
                _running = false;
                Repaint();
            }
        }

        private TalePathsOptions MakeOptions(StoryConfig config)
        {
            var options = new TalePathsOptions();
            options.MaxPaths = maxPaths;
            options.MaxChoices = maxChoices;
            options.MaxLines = maxLines;
            options.PathSeconds = pathSeconds;
            if (config != null)
            {
                foreach (string exposed in config.ExposedNames)
                    if (!string.IsNullOrEmpty(exposed)) options.Exposed.Add(exposed);
                foreach (CastMember member in config.Cast)
                    if (!string.IsNullOrEmpty(member.id)) options.CastIds.Add(member.id);
            }
            options.Exposed.Add("shots");

            // The built-in actions with their real signatures that do nothing, so music()
            // and backdrop() neither need a Story in the scene nor touch one.
            var probe = new TaleDirector();
            StoryActions.Register(probe, null);
            TaleCheckContext known = probe.MakeCheckContext("");
            var signatures = new List<KeyValuePair<string, TaleActionSignature>>();
            foreach (string name in known.Actions.Keys)
                signatures.Add(new KeyValuePair<string, TaleActionSignature>(name, known.Actions[name]));

            options.Setup = director =>
            {
                foreach (var pair in signatures)
                {
                    if (pair.Key == "emit" || pair.Key == "wait" || pair.Value == null) continue;
                    director.AddAction(new TaleStubAction(pair.Key, pair.Value.Params, pair.Value.Required));
                }
                if (config != null)
                    director.ContextExtender = context => config.AddTo(context, context.TaleName);
            };
            return options;
        }

        /// <summary>The project's StoryConfig (the first by path), or null. The importer picks the same one.</summary>
        private static StoryConfig FindConfig()
        {
            string[] guids = AssetDatabase.FindAssets("t:StoryConfig");
            if (guids.Length == 0) return null;
            var paths = new List<string>();
            foreach (string guid in guids) paths.Add(AssetDatabase.GUIDToAssetPath(guid));
            paths.Sort(StringComparer.Ordinal);
            return AssetDatabase.LoadAssetAtPath<StoryConfig>(paths[0]);
        }

        // --- Showing results -------------------------------------------------------

        private void DrawResult(TalePathsResult result)
        {
            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Totals", EditorStyles.boldLabel);
            EditorGUILayout.LabelField("Paths played", result.PathCount.ToString());
            EditorGUILayout.LabelField("Lines shown", result.TotalLines.ToString());
            if (result.CutOffCount > 0) EditorGUILayout.LabelField("Paths cut off", result.CutOffCount.ToString());
            if (!result.Complete)
                EditorGUILayout.HelpBox("Stopped at the limit of " + maxPaths + " paths. There are more.", MessageType.Warning);
            else if (result.LimitReached)
                EditorGUILayout.HelpBox("A path reached a limit and was cut off. See the problems below.", MessageType.Warning);

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Endings", EditorStyles.boldLabel);
            if (result.Endings.Count == 0) EditorGUILayout.LabelField("none");
            foreach (string ending in result.Endings.Keys)
                EditorGUILayout.LabelField(ending, result.Endings[ending] + (result.Endings[ending] == 1 ? " path" : " paths"));

            EditorGUILayout.Space();
            if (result.Unreached.Count == 0)
            {
                EditorGUILayout.LabelField("Every scene is reached.");
            }
            else
            {
                EditorGUILayout.LabelField("Never reached", EditorStyles.boldLabel);
                EditorGUILayout.LabelField(string.Join(", ", result.Unreached), EditorStyles.wordWrappedLabel);
            }

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Problems", EditorStyles.boldLabel);
            if (result.Problems.Count == 0) EditorGUILayout.HelpBox("No problems found.", MessageType.Info);
            foreach (TalePathProblem problem in result.Problems) DrawProblem(problem);

            EditorGUILayout.Space();
            _showPaths = EditorGUILayout.Foldout(_showPaths, "Paths (" + result.PathCount + ")", true);
            if (_showPaths) DrawPaths(result);
        }

        private void DrawProblem(TalePathProblem problem)
        {
            string where = problem.Line > 0 ? problem.Tale + ":" + problem.Line + "  " : "";
            string count = problem.Paths + (problem.Paths == 1 ? " path" : " paths");
            string message = where + problem.Kind + ": " + problem.Message + " (" + count + ")";
            TaleAsset asset;
            bool canOpen = problem.Line > 0 && _assets.TryGetValue(problem.Tale, out asset) && asset != null;
            EditorGUI.BeginDisabledGroup(!canOpen);
            if (GUILayout.Button(new GUIContent(message, canOpen ? "Open the tale at this line" : ""), _rowStyle))
            {
                if (_assets.TryGetValue(problem.Tale, out asset)) AssetDatabase.OpenAsset(asset, problem.Line);
            }
            EditorGUI.EndDisabledGroup();
            EditorGUILayout.LabelField("First after: " + Describe(problem.FirstPath), EditorStyles.wordWrappedMiniLabel);
        }

        private void DrawPaths(TalePathsResult result)
        {
            _pathScroll = EditorGUILayout.BeginScrollView(_pathScroll, GUILayout.MinHeight(140f), GUILayout.MaxHeight(320f));
            int shown = Mathf.Min(result.Paths.Count, MaxPathsShown);
            for (int i = 0; i < shown; i++)
            {
                TalePath path = result.Paths[i];
                string ending = path.IsCutOff ? "cut off" : path.Ending;
                EditorGUILayout.LabelField((i + 1) + ". " + Describe(path.Choices) + "  ->  " + ending + " (" + path.Lines + " lines)",
                    EditorStyles.wordWrappedMiniLabel);
            }
            if (result.Paths.Count > shown)
                EditorGUILayout.LabelField("And " + (result.Paths.Count - shown) + " more.", EditorStyles.miniLabel);
            EditorGUILayout.EndScrollView();
        }

        private static string Describe(List<string> choices)
        {
            if (choices.Count == 0) return "(no choices)";
            var text = new StringBuilder();
            int count = Mathf.Min(choices.Count, MaxChoicesShown);
            for (int i = 0; i < count; i++)
            {
                if (i > 0) text.Append(" > ");
                text.Append(choices[i]);
            }
            if (choices.Count > count) text.Append(" > ... (").Append(choices.Count - count).Append(" more)");
            return text.ToString();
        }
    }
}
