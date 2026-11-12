using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using TaleScript;
using UnityEditor;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Window > Visual Novel Teller > Story Map: every beat of a Story Config's tales as a box,
    /// with arrows for jumps, beat calls, and choice branches, colored by tale. Tales sit in bands
    /// in the order play reaches them, and beats in columns by step, as in the Godot plugin's
    /// Map view (§9.4). Beats nothing leads to, jumps to missing beats, beats where the story can
    /// end, and paid beats (@needs) are marked. Drag a box to move it; the position is saved
    /// next to the tale in tale.tale.map, the file the Godot plugin uses. Double-click a box to
    /// open its beat. Drag from a box's handle (the square on its right edge) to another box to
    /// add a jump to it, or to empty space to create a new beat there, linked with a jump. Undo
    /// Map Edit puts the tale back as it was before the last of these edits. Drag the background
    /// (or with the middle button) to pan, and use Ctrl and the mouse wheel, or the zoom buttons,
    /// to zoom.
    /// </summary>
    public class StoryMapWindow : EditorWindow
    {
        private static readonly Color[] TaleColors =
        {
            new Color(0.4f, 0.65f, 0.95f), new Color(0.95f, 0.6f, 0.35f), new Color(0.5f, 0.8f, 0.5f),
            new Color(0.85f, 0.5f, 0.8f), new Color(0.9f, 0.8f, 0.35f), new Color(0.45f, 0.8f, 0.8f),
        };
        private static readonly Color UnreachableColor = new Color(0.95f, 0.65f, 0.25f);
        private static readonly Color MissingColor = new Color(0.95f, 0.35f, 0.3f);
        private static readonly Color NeedsColor = new Color(0.55f, 0.8f, 0.95f);
        private static readonly Color BoxColor = new Color(0.12f, 0.13f, 0.16f);
        private const float BoxWidth = 220f;
        private const float RowHeight = 18f;
        private const float TitleHeight = 24f;
        private const float Padding = 8f;

        [SerializeField] private StoryConfig config;
        [SerializeField] private float zoom = 1f;
        [SerializeField] private Vector2 scroll;

        private TaleGraph _graph;
        private readonly Dictionary<string, TaleAsset> _assets = new Dictionary<string, TaleAsset>();
        private readonly Dictionary<string, Vector2> _positions = new Dictionary<string, Vector2>();
        private readonly Dictionary<string, Color> _colors = new Dictionary<string, Color>();
        private string _dragging;
        private bool _panning;
        private string _linkFrom;
        private Vector2 _linkMouse;
        private string _undoPath;
        private string _undoSource;
        private string _undoMapPath;
        private string _undoMapSource;
        private GUIStyle _title;
        private GUIStyle _row;

        [MenuItem("Window/Visual Novel Teller/Story Map")]
        public static void Open()
        {
            var window = GetWindow<StoryMapWindow>();
            window.titleContent = new GUIContent("Story Map");
            window.minSize = new Vector2(400f, 300f);
            var selected = Selection.activeObject as StoryConfig;
            if (selected != null) window.config = selected;
            window.Rebuild();
        }

        private void OnEnable()
        {
            if (config == null) config = FindConfig();
            Rebuild();
        }

        // Tales are reimported when they change, so the map follows their edits.
        private void OnProjectChange()
        {
            Rebuild();
            Repaint();
        }

        private static StoryConfig FindConfig()
        {
            foreach (string guid in AssetDatabase.FindAssets("t:StoryConfig"))
            {
                var found = AssetDatabase.LoadAssetAtPath<StoryConfig>(AssetDatabase.GUIDToAssetPath(guid));
                if (found != null) return found;
            }
            return null;
        }

        /// <summary>Builds the graph of the config's tales and places the beats: saved positions first, then the automatic layout.</summary>
        public void Rebuild()
        {
            _graph = null;
            _assets.Clear();
            _positions.Clear();
            _colors.Clear();
            if (config == null) return;
            var docs = new Dictionary<string, TaleDocument>();
            var order = new List<string>();
            foreach (var asset in config.Tales)
            {
                if (asset == null || string.IsNullOrEmpty(asset.TaleName) || docs.ContainsKey(asset.TaleName)) continue;
                docs[asset.TaleName] = TaleParser.Parse(asset.Source ?? "", AssetDatabase.GetAssetPath(asset));
                _assets[asset.TaleName] = asset;
                order.Add(asset.TaleName);
            }
            order.Sort(string.CompareOrdinal);
            string startTale = config.FirstTale != null ? config.FirstTale.TaleName : "";
            if (order.Remove(startTale)) order.Insert(0, startTale);
            for (int i = 0; i < order.Count; i++) _colors[order[i]] = TaleColors[i % TaleColors.Length];
            _graph = TaleGraph.Build(docs, startTale, config.FirstBeat);
            OrderedMap<TaleGraphPoint> layout = _graph.Layout(startTale.Length > 0 ? new[] { startTale } : null);
            foreach (string id in layout.Keys)
                _positions[id] = new Vector2(layout[id].X + 40f, layout[id].Y + 70f);
            foreach (string tale in order)
            {
                foreach (var saved in LoadPositions(AssetDatabase.GetAssetPath(_assets[tale])))
                    if (_graph.Beats.Has(tale + "." + saved.Key)) _positions[tale + "." + saved.Key] = saved.Value;
            }
        }

        private void OnGUI()
        {
            DrawToolbar();
            if (config == null)
            {
                EditorGUILayout.HelpBox("Choose a Story Config to see its tales as a map.", MessageType.Info);
                return;
            }
            if (_graph == null) Rebuild();
            if (_graph == null || _graph.Beats.Count == 0)
            {
                EditorGUILayout.HelpBox("The Story Config has no tales with beats.", MessageType.Info);
                return;
            }
            EnsureStyles();
            Rect area = GUILayoutUtility.GetRect(0f, 100000f, 0f, 100000f);
            Vector2 size = ContentSize();
            scroll = GUI.BeginScrollView(area, scroll, new Rect(0f, 0f, size.x * zoom, size.y * zoom));
            HandleInput();
            if (Event.current.type == EventType.Repaint) DrawLinks();
            foreach (string id in _graph.Beats.Keys) DrawBeat(id);
            GUI.EndScrollView();
        }

        private void DrawToolbar()
        {
            EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);
            var chosen = (StoryConfig)EditorGUILayout.ObjectField(config, typeof(StoryConfig), false, GUILayout.Width(260f));
            if (chosen != config)
            {
                config = chosen;
                Rebuild();
            }
            if (GUILayout.Button("Refresh", EditorStyles.toolbarButton)) Rebuild();
            if (GUILayout.Button("Automatic Layout", EditorStyles.toolbarButton)) ResetLayout();
            EditorGUI.BeginDisabledGroup(_undoPath == null);
            if (GUILayout.Button("Undo Map Edit", EditorStyles.toolbarButton)) UndoMapEdit();
            EditorGUI.EndDisabledGroup();
            GUILayout.FlexibleSpace();
            if (GUILayout.Button("-", EditorStyles.toolbarButton, GUILayout.Width(24f))) SetZoom(zoom / 1.25f);
            GUILayout.Label(Mathf.RoundToInt(zoom * 100f) + "%", EditorStyles.miniLabel, GUILayout.Width(40f));
            if (GUILayout.Button("+", EditorStyles.toolbarButton, GUILayout.Width(24f))) SetZoom(zoom * 1.25f);
            EditorGUILayout.EndHorizontal();
        }

        private void SetZoom(float value)
        {
            zoom = Mathf.Clamp(value, 0.3f, 2f);
            _title = null;
            Repaint();
        }

        // Forgets the saved positions of the config's tales and lays the beats out again.
        private void ResetLayout()
        {
            if (!EditorUtility.DisplayDialog("Automatic Layout", "Lay out every beat automatically? Moved boxes go back to their automatic places.", "Lay Out", "Cancel")) return;
            foreach (var asset in _assets.Values)
            {
                string mapPath = AssetDatabase.GetAssetPath(asset) + ".map";
                if (File.Exists(mapPath)) AssetDatabase.DeleteAsset(mapPath);
            }
            Rebuild();
        }

        private void EnsureStyles()
        {
            if (_title != null) return;
            _title = new GUIStyle(EditorStyles.boldLabel) { fontSize = Mathf.Max(6, Mathf.RoundToInt(12f * zoom)), clipping = TextClipping.Clip };
            _title.normal.textColor = Color.white;
            _row = new GUIStyle(EditorStyles.label) { fontSize = Mathf.Max(5, Mathf.RoundToInt(11f * zoom)), clipping = TextClipping.Clip };
            _row.normal.textColor = new Color(0.85f, 0.87f, 0.9f);
        }

        private Vector2 ContentSize()
        {
            var size = new Vector2(400f, 300f);
            foreach (string id in _graph.Beats.Keys)
            {
                Rect box = BoxRect(id, 1f);
                size.x = Mathf.Max(size.x, box.xMax + 200f);
                size.y = Mathf.Max(size.y, box.yMax + 200f);
            }
            return size;
        }

        /// <summary>The box of a beat, in map coordinates times scale.</summary>
        private Rect BoxRect(string id, float scale)
        {
            Vector2 at;
            if (!_positions.TryGetValue(id, out at)) at = Vector2.zero;
            List<string> rows = Rows(id);
            float height = TitleHeight + rows.Count * RowHeight + Padding * 2f;
            return new Rect(at.x * scale, at.y * scale, BoxWidth * scale, height * scale);
        }

        // The text rows of a box: tale, size, choices, paid content, problems, and the ending mark.
        private List<string> Rows(string id)
        {
            TaleGraphBeat beat = _graph.Beats[id];
            var rows = new List<string> { beat.Tale, beat.Statements + (beat.Statements == 1 ? " statement" : " statements") };
            foreach (var exit in beat.Exits)
                if (exit.Kind == "choice") rows.Add("“" + exit.Label + "” → " + Short(exit.To, beat.Tale));
            if (beat.Needs.Length > 0) rows.Add("Needs " + beat.Needs);
            if (_graph.Unreachable.Contains(id)) rows.Add("⚠ Nothing leads here");
            foreach (var problem in _graph.Missing)
                if (problem.From == id) rows.Add("⚠ Jumps to missing " + Short(problem.To, beat.Tale));
            if (beat.Ends) rows.Add("■ story can end here");
            return rows;
        }

        private static string Short(string id, string tale)
        {
            return id.StartsWith(tale + ".", StringComparison.Ordinal) ? id.Substring(tale.Length + 1) : id;
        }

        private Color BorderOf(string id)
        {
            foreach (var problem in _graph.Missing)
                if (problem.From == id) return MissingColor;
            if (_graph.Unreachable.Contains(id)) return UnreachableColor;
            Color color;
            return _colors.TryGetValue(_graph.Beats[id].Tale, out color) ? color * 0.8f : Color.gray;
        }

        private void DrawBeat(string id)
        {
            TaleGraphBeat beat = _graph.Beats[id];
            Rect box = BoxRect(id, zoom);
            Color tale;
            if (!_colors.TryGetValue(beat.Tale, out tale)) tale = Color.gray;
            float border = Mathf.Max(1f, 2f * zoom);
            EditorGUI.DrawRect(box, BorderOf(id));
            var inner = new Rect(box.x + border, box.y + border, box.width - border * 2f, box.height - border * 2f);
            EditorGUI.DrawRect(inner, BoxColor);
            var titleBar = new Rect(inner.x, inner.y, inner.width, TitleHeight * zoom);
            EditorGUI.DrawRect(titleBar, tale * 0.55f);
            GUI.Label(new Rect(titleBar.x + Padding * zoom, titleBar.y, titleBar.width - Padding * zoom, titleBar.height), beat.Beat, _title);
            float y = titleBar.yMax + Padding * zoom * 0.5f;
            foreach (string row in Rows(id))
            {
                Color old = _row.normal.textColor;
                if (row == beat.Tale) _row.normal.textColor = tale;
                else if (row.StartsWith("Needs ", StringComparison.Ordinal)) _row.normal.textColor = NeedsColor;
                else if (row.StartsWith("⚠ Jumps", StringComparison.Ordinal)) _row.normal.textColor = MissingColor;
                else if (row.StartsWith("⚠", StringComparison.Ordinal)) _row.normal.textColor = UnreachableColor;
                GUI.Label(new Rect(inner.x + Padding * zoom, y, inner.width - Padding * zoom * 2f, RowHeight * zoom), row, _row);
                _row.normal.textColor = old;
                y += RowHeight * zoom;
            }
            EditorGUIUtility.AddCursorRect(box, MouseCursor.MoveArrow);
            Rect port = PortRect(id);
            EditorGUI.DrawRect(port, Color.white);
            EditorGUI.DrawRect(new Rect(port.x + 1f, port.y + 1f, port.width - 2f, port.height - 2f), tale);
            EditorGUIUtility.AddCursorRect(port, MouseCursor.Arrow);
        }

        /// <summary>The handle on a box's right edge: drag from it to link the beat.</summary>
        private Rect PortRect(string id)
        {
            Rect box = BoxRect(id, zoom);
            float size = Mathf.Max(8f, 12f * zoom);
            return new Rect(box.xMax - size * 0.5f, box.y + TitleHeight * zoom * 0.5f - size * 0.5f, size, size);
        }

        private void DrawLinks()
        {
            if (_linkFrom != null && _graph.Beats.Has(_linkFrom))
            {
                Rect port = PortRect(_linkFrom);
                Vector2 start = port.center;
                float bend = Mathf.Max(40f * zoom, Mathf.Abs(_linkMouse.x - start.x) * 0.5f);
                Color color;
                if (!_colors.TryGetValue(_graph.Beats[_linkFrom].Tale, out color)) color = Color.white;
                Handles.DrawBezier(start, _linkMouse, start + Vector2.right * bend, _linkMouse + Vector2.left * bend, color, null, Mathf.Max(1.5f, 2.5f * zoom));
            }
            var drawn = new HashSet<string>();
            foreach (string id in _graph.Beats.Keys)
            {
                TaleGraphBeat beat = _graph.Beats[id];
                Color color;
                if (!_colors.TryGetValue(beat.Tale, out color)) color = Color.gray;
                foreach (var exit in beat.Exits)
                {
                    if (!_graph.Beats.Has(exit.To) || !drawn.Add(id + ">" + exit.To)) continue;
                    Rect from = BoxRect(id, zoom);
                    Rect to = BoxRect(exit.To, zoom);
                    var start = new Vector2(from.xMax, from.y + TitleHeight * zoom * 0.5f);
                    var end = new Vector2(to.x, to.y + TitleHeight * zoom * 0.5f);
                    float bend = Mathf.Max(40f * zoom, Mathf.Abs(end.x - start.x) * 0.5f);
                    Handles.DrawBezier(start, end, start + Vector2.right * bend, end + Vector2.left * bend, color, null, Mathf.Max(1.5f, 2.5f * zoom));
                    float head = 7f * zoom;
                    Handles.color = color;
                    Handles.DrawAAConvexPolygon(end, end + new Vector2(-head, -head * 0.6f), end + new Vector2(-head, head * 0.6f));
                }
            }
        }

        private void HandleInput()
        {
            Event e = Event.current;
            switch (e.type)
            {
                case EventType.MouseDown:
                    string port = PortAt(e.mousePosition);
                    if (e.button == 0 && port != null)
                    {
                        _linkFrom = port;
                        _linkMouse = e.mousePosition;
                        e.Use();
                        break;
                    }
                    string hit = BeatAt(e.mousePosition);
                    if (e.button == 0 && hit != null)
                    {
                        if (e.clickCount == 2)
                        {
                            OpenBeat(hit);
                        }
                        else
                        {
                            _dragging = hit;
                        }
                        e.Use();
                    }
                    else if (e.button == 2 || (e.button == 0 && hit == null))
                    {
                        _panning = true;
                        e.Use();
                    }
                    break;
                case EventType.MouseDrag:
                    if (_linkFrom != null)
                    {
                        _linkMouse = e.mousePosition;
                        e.Use();
                        Repaint();
                    }
                    else if (_dragging != null)
                    {
                        _positions[_dragging] += e.delta / zoom;
                        e.Use();
                        Repaint();
                    }
                    else if (_panning)
                    {
                        scroll -= e.delta;
                        e.Use();
                        Repaint();
                    }
                    break;
                case EventType.MouseUp:
                    if (_linkFrom != null)
                    {
                        string from = _linkFrom;
                        _linkFrom = null;
                        string target = BeatAt(e.mousePosition);
                        if (target == null) LinkToNewBeat(from, e.mousePosition / zoom);
                        else if (target != from) Link(from, target);
                        e.Use();
                        Repaint();
                    }
                    else if (_dragging != null)
                    {
                        SavePosition(_dragging);
                        _dragging = null;
                        e.Use();
                    }
                    _panning = false;
                    break;
                case EventType.ScrollWheel:
                    if (e.control || e.command)
                    {
                        SetZoom(zoom * (e.delta.y > 0f ? 1f / 1.1f : 1.1f));
                        e.Use();
                    }
                    break;
            }
        }

        private string BeatAt(Vector2 point)
        {
            string found = null;
            foreach (string id in _graph.Beats.Keys)
                if (BoxRect(id, zoom).Contains(point)) found = id;
            return found;
        }

        private string PortAt(Vector2 point)
        {
            foreach (string id in _graph.Beats.Keys)
                if (PortRect(id).Contains(point)) return id;
            return null;
        }

        /// <summary>Adds "jump to" at the end of the beat fromId. Returns false when the tale can't be changed.</summary>
        public bool Link(string fromId, string toId)
        {
            TaleGraphBeat from = _graph != null && _graph.Beats.Has(fromId) ? _graph.Beats[fromId] : null;
            if (from == null) return false;
            string talePath = TalePath(from.Tale);
            string source = ReadTale(talePath);
            if (source == null) return false;
            TaleDocument doc = TaleParser.Parse(source, talePath);
            TaleNode beat = doc.FindBeat(from.Beat);
            if (beat == null) return false;
            WriteTale(talePath, source, TaleEdits.AppendTo(source, doc, beat, "jump " + TaleEdits.JumpTarget(toId, from.Tale)));
            return true;
        }

        /// <summary>
        /// Creates a new beat in fromId's tale, linked from it with a jump, and places it at the
        /// given map position. Returns the new beat's name, or null when the tale can't be changed.
        /// </summary>
        public string LinkToNewBeat(string fromId, Vector2 at)
        {
            TaleGraphBeat from = _graph != null && _graph.Beats.Has(fromId) ? _graph.Beats[fromId] : null;
            if (from == null) return null;
            string talePath = TalePath(from.Tale);
            string source = ReadTale(talePath);
            if (source == null) return null;
            TaleDocument doc = TaleParser.Parse(source, talePath);
            TaleNode beat = doc.FindBeat(from.Beat);
            if (beat == null) return null;
            string name = TaleEdits.NewBeatName(doc);
            string linked = TaleEdits.AppendTo(source, doc, beat, "jump " + name);
            string mapPath = talePath + ".map";
            _undoMapPath = mapPath;
            _undoMapSource = File.Exists(mapPath) ? File.ReadAllText(mapPath, Encoding.UTF8) : null;
            SavePosition(talePath, name, at);
            WriteTale(talePath, source, TaleEdits.AddBeat(linked, TaleParser.Parse(linked, talePath), name), true);
            return name;
        }

        private string TalePath(string tale)
        {
            TaleAsset asset;
            return _assets.TryGetValue(tale, out asset) ? AssetDatabase.GetAssetPath(asset) : null;
        }

        private static string ReadTale(string talePath)
        {
            if (string.IsNullOrEmpty(talePath) || !File.Exists(talePath)) return null;
            return File.ReadAllText(talePath, Encoding.UTF8);
        }

        // Writes the tale and reimports it, keeping the old text for Undo Map Edit.
        private void WriteTale(string talePath, string oldSource, string newSource, bool keepMapUndo = false)
        {
            if (!keepMapUndo)
            {
                _undoMapPath = null;
                _undoMapSource = null;
            }
            _undoPath = talePath;
            _undoSource = oldSource;
            File.WriteAllText(talePath, newSource, new UTF8Encoding(false));
            AssetDatabase.ImportAsset(talePath);
            if (File.Exists(talePath + ".map")) AssetDatabase.ImportAsset(talePath + ".map");
            Rebuild();
        }

        /// <summary>Puts the tale (and its map file) back as they were before the last link or new beat.</summary>
        public void UndoMapEdit()
        {
            if (_undoPath == null) return;
            File.WriteAllText(_undoPath, _undoSource, new UTF8Encoding(false));
            AssetDatabase.ImportAsset(_undoPath);
            if (_undoMapPath != null)
            {
                if (_undoMapSource != null)
                {
                    File.WriteAllText(_undoMapPath, _undoMapSource, new UTF8Encoding(false));
                    AssetDatabase.ImportAsset(_undoMapPath);
                }
                else if (File.Exists(_undoMapPath)) AssetDatabase.DeleteAsset(_undoMapPath);
            }
            _undoPath = null;
            _undoSource = null;
            _undoMapPath = null;
            _undoMapSource = null;
            Rebuild();
        }

        private void OpenBeat(string id)
        {
            TaleGraphBeat beat = _graph.Beats[id];
            TaleAsset asset;
            if (_assets.TryGetValue(beat.Tale, out asset)) AssetDatabase.OpenAsset(asset, beat.Line);
        }

        /// <summary>Saved positions from "tale.tale.map", the file the Godot plugin writes: beat name to position.</summary>
        public static Dictionary<string, Vector2> LoadPositions(string talePath)
        {
            var result = new Dictionary<string, Vector2>();
            string mapPath = talePath + ".map";
            if (string.IsNullOrEmpty(talePath) || !File.Exists(mapPath)) return result;
            try
            {
                var data = GdJson.Parse(File.ReadAllText(mapPath, Encoding.UTF8)) as OrderedMap<object>;
                object beats;
                if (data == null || !data.TryGetValue("beats", out beats) || !(beats is OrderedMap<object>)) return result;
                var map = (OrderedMap<object>)beats;
                foreach (string name in map.Keys)
                {
                    var at = map[name] as List<object>;
                    if (at != null && at.Count == 2 && GdValue.IsNumber(at[0]) && GdValue.IsNumber(at[1]))
                        result[name] = new Vector2((float)GdValue.ToDouble(at[0]), (float)GdValue.ToDouble(at[1]));
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning("Story Map: could not read " + mapPath + ". " + e.Message);
            }
            return result;
        }

        /// <summary>Saves a beat's position in "tale.tale.map", keeping the other beats' positions.</summary>
        public static void SavePosition(string talePath, string beatName, Vector2 at)
        {
            string mapPath = talePath + ".map";
            var data = new OrderedMap<object>();
            var beats = new OrderedMap<object>();
            if (File.Exists(mapPath))
            {
                var parsed = GdJson.Parse(File.ReadAllText(mapPath, Encoding.UTF8)) as OrderedMap<object>;
                object saved;
                if (parsed != null && parsed.TryGetValue("beats", out saved) && saved is OrderedMap<object>)
                {
                    data = parsed;
                    beats = (OrderedMap<object>)saved;
                }
            }
            beats[beatName] = new List<object> { (double)Mathf.Round(at.x), (double)Mathf.Round(at.y) };
            data["beats"] = beats;
            File.WriteAllText(mapPath, GdJson.Stringify(data) + "\n", new UTF8Encoding(false));
        }

        private void SavePosition(string id)
        {
            TaleGraphBeat beat = _graph.Beats[id];
            TaleAsset asset;
            if (!_assets.TryGetValue(beat.Tale, out asset)) return;
            string talePath = AssetDatabase.GetAssetPath(asset);
            SavePosition(talePath, beat.Beat, _positions[id]);
            AssetDatabase.ImportAsset(talePath + ".map");
        }
    }
}
