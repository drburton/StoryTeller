using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    /// <summary>A way out of a beat: a jump, a beat call, or a choice option's jump.</summary>
    public class TaleGraphExit
    {
        /// <summary>The beat it leads to, as "tale.beat".</summary>
        public string To = "";
        /// <summary>"jump", "call", or "choice".</summary>
        public string Kind = "";
        /// <summary>The choice option's text, "timeout", or "" outside a choice.</summary>
        public string Label = "";
        public int Line;
    }

    /// <summary>A beat on the Story Map.</summary>
    public class TaleGraphBeat
    {
        public string Tale = "";
        public string Beat = "";
        public int Line;
        /// <summary>How many statements the beat has, nested ones included.</summary>
        public int Statements;
        /// <summary>True when play can run off its end, ending the story or returning to a caller.</summary>
        public bool Ends;
        /// <summary>The product its @needs names, or "".</summary>
        public string Needs = "";
        public List<TaleGraphExit> Exits = new List<TaleGraphExit>();
    }

    /// <summary>An exit to a beat that doesn't exist.</summary>
    public class TaleGraphMissing
    {
        public string From = "";
        public string To = "";
        public int Line;
    }

    /// <summary>A position on the Story Map.</summary>
    public struct TaleGraphPoint
    {
        public float X;
        public float Y;

        public TaleGraphPoint(float x, float y)
        {
            X = x;
            Y = y;
        }
    }

    /// <summary>
    /// The shape of a story for the Story Map, the C# version of the Godot plugin's StoryGraph:
    /// every beat of a set of tales, the jumps, beat calls, and choice branches between them,
    /// beats no path reaches, and jumps to beats that don't exist. <see cref="Layout"/> places the
    /// beats in a band per tale and a column per step.
    /// </summary>
    public class TaleGraph
    {
        /// <summary>"tale.beat" to its beat, tales by name and beats in file order.</summary>
        public readonly OrderedMap<TaleGraphBeat> Beats = new OrderedMap<TaleGraphBeat>();
        public readonly List<TaleGraphMissing> Missing = new List<TaleGraphMissing>();
        /// <summary>Beats no path from an entry point reaches.</summary>
        public readonly List<string> Unreachable = new List<string>();
        /// <summary>Where play can begin: the start tale's beat, then each tale's "start" beat.</summary>
        public readonly List<string> Entries = new List<string>();

        /// <summary>Builds the graph of the tales in docs (tale name to its parsed document).</summary>
        public static TaleGraph Build(IDictionary<string, TaleDocument> docs, string startTale = "", string startBeat = "start")
        {
            var graph = new TaleGraph();
            var names = new List<string>(docs.Keys);
            names.Sort(string.CompareOrdinal);
            foreach (string taleName in names)
            {
                var annotations = new List<TaleExpr>();
                foreach (var statement in docs[taleName].Statements)
                {
                    if (statement.Kind == TaleNodeKind.Annotation)
                    {
                        annotations.AddRange(statement.Annotations);
                        continue;
                    }
                    if (statement.Kind != TaleNodeKind.Beat)
                    {
                        if (!statement.IsTrivia()) annotations.Clear();
                        continue;
                    }
                    annotations.AddRange(statement.Annotations);
                    var beat = new TaleGraphBeat
                    {
                        Tale = taleName,
                        Beat = statement.Name,
                        Line = statement.LineStart,
                        Statements = Count(statement),
                        Ends = FallsThrough(statement),
                        Needs = NeedsOf(annotations),
                    };
                    annotations.Clear();
                    CollectExits(statement, taleName, docs, beat.Exits, "");
                    graph.Beats[taleName + "." + statement.Name] = beat;
                }
            }
            foreach (string id in graph.Beats.Keys)
                foreach (var exit in graph.Beats[id].Exits)
                    if (!graph.Beats.Has(exit.To))
                        graph.Missing.Add(new TaleGraphMissing { From = id, To = exit.To, Line = exit.Line });
            string startId = startTale + "." + startBeat;
            if (graph.Beats.Has(startId)) graph.Entries.Add(startId);
            foreach (string id in graph.Beats.Keys)
                if (graph.Beats[id].Beat == "start" && !graph.Entries.Contains(id)) graph.Entries.Add(id);
            var reached = new HashSet<string>();
            var pending = new List<string>(graph.Entries);
            while (pending.Count > 0)
            {
                string id = pending[pending.Count - 1];
                pending.RemoveAt(pending.Count - 1);
                if (reached.Contains(id) || !graph.Beats.Has(id)) continue;
                reached.Add(id);
                foreach (var exit in graph.Beats[id].Exits) pending.Add(exit.To);
            }
            foreach (string id in graph.Beats.Keys)
                if (!reached.Contains(id)) graph.Unreachable.Add(id);
            return graph;
        }

        /// <summary>Rows of text a beat's box shows: its tale, its size, one per choice, its problems, and whether the story can end there.</summary>
        public int RowsFor(string id)
        {
            int rows = 2;
            TaleGraphBeat beat = Beats[id];
            foreach (var exit in beat.Exits)
                if (exit.Kind == "choice") rows++;
            foreach (var problem in Missing)
                if (problem.From == id) rows++;
            if (Unreachable.Contains(id)) rows++;
            if (beat.Ends) rows++;
            return rows;
        }

        /// <summary>Tale names in the order play first reaches them from the entry points, then the rest by name.</summary>
        public List<string> TaleOrder()
        {
            var order = new List<string>();
            var seen = new HashSet<string>();
            foreach (string entry in Entries)
            {
                var queue = new Queue<string>();
                queue.Enqueue(entry);
                while (queue.Count > 0)
                {
                    string id = queue.Dequeue();
                    if (seen.Contains(id) || !Beats.Has(id)) continue;
                    seen.Add(id);
                    if (!order.Contains(Beats[id].Tale)) order.Add(Beats[id].Tale);
                    foreach (var exit in Beats[id].Exits) queue.Enqueue(exit.To);
                }
            }
            var rest = new List<string>();
            foreach (string id in Beats.Keys)
            {
                string tale = Beats[id].Tale;
                if (!order.Contains(tale) && !rest.Contains(tale)) rest.Add(tale);
            }
            rest.Sort(string.CompareOrdinal);
            order.AddRange(rest);
            return order;
        }

        /// <summary>
        /// Positions for the beats: one horizontal band per tale (in order, then in
        /// <see cref="TaleOrder"/>), and within it one column per step from the tale's entry
        /// beats. Beats in a column are stacked by their height (rowHeight per row from
        /// <see cref="RowsFor"/>, plus gap). Matches the Godot plugin's layout.
        /// </summary>
        public OrderedMap<TaleGraphPoint> Layout(IEnumerable<string> order = null, float columnWidth = 280f, float rowHeight = 30f, float gap = 40f)
        {
            var tales = new List<string>();
            if (order != null)
                foreach (string tale in order)
                    if (!tales.Contains(tale)) tales.Add(tale);
            foreach (string tale in TaleOrder())
                if (!tales.Contains(tale)) tales.Add(tale);
            var positions = new OrderedMap<TaleGraphPoint>();
            float bandTop = 0f;
            foreach (string tale in tales)
            {
                var ids = new List<string>();
                foreach (string id in Beats.Keys)
                    if (Beats[id].Tale == tale) ids.Add(id);
                if (ids.Count == 0) continue;
                // A stable sort by line, as Godot's sort keeps file order for equal lines.
                var sorted = new List<string>(ids);
                sorted.Sort((a, b) => Beats[a].Line != Beats[b].Line ? Beats[a].Line.CompareTo(Beats[b].Line) : ids.IndexOf(a).CompareTo(ids.IndexOf(b)));
                ids = sorted;
                var depth = new Dictionary<string, int>();
                var queue = new Queue<string>();
                foreach (string id in ids)
                {
                    if (Entries.Contains(id) || EnteredFromOutside(id, tale))
                    {
                        depth[id] = 0;
                        queue.Enqueue(id);
                    }
                }
                if (queue.Count == 0)
                {
                    depth[ids[0]] = 0;
                    queue.Enqueue(ids[0]);
                }
                while (queue.Count > 0)
                {
                    string id = queue.Dequeue();
                    foreach (var exit in Beats[id].Exits)
                    {
                        if (Beats.Has(exit.To) && Beats[exit.To].Tale == tale && !depth.ContainsKey(exit.To))
                        {
                            depth[exit.To] = depth[id] + 1;
                            queue.Enqueue(exit.To);
                        }
                    }
                }
                int deepest = 0;
                foreach (int d in depth.Values) deepest = Math.Max(deepest, d);
                foreach (string id in ids)
                {
                    if (depth.ContainsKey(id)) continue;
                    deepest++;
                    depth[id] = deepest;
                }
                var columnTops = new Dictionary<int, float>();
                float bandBottom = bandTop;
                foreach (string id in ids)
                {
                    int column = depth[id];
                    float top;
                    if (!columnTops.TryGetValue(column, out top)) top = bandTop;
                    positions[id] = new TaleGraphPoint(column * columnWidth, top);
                    float bottom = top + (RowsFor(id) + 1.5f) * rowHeight;
                    columnTops[column] = bottom + gap;
                    bandBottom = Math.Max(bandBottom, bottom);
                }
                bandTop = bandBottom + gap * 2f;
            }
            return positions;
        }

        /// <summary>A text form of the graph and its layout, the same in C# and in the Godot plugin, for tests.</summary>
        public string Dump()
        {
            var output = new StringBuilder();
            foreach (string id in Beats.Keys)
            {
                TaleGraphBeat beat = Beats[id];
                var exits = new List<string>();
                foreach (var exit in beat.Exits) exits.Add(exit.Kind + " " + exit.To + " \"" + exit.Label + "\" " + exit.Line);
                output.Append(id).Append(" line=").Append(beat.Line).Append(" statements=").Append(beat.Statements)
                    .Append(" ends=").Append(beat.Ends ? "true" : "false").Append(" needs=").Append(beat.Needs)
                    .Append(" exits=[").Append(string.Join(", ", exits)).Append("]\n");
            }
            foreach (var problem in Missing) output.Append("missing ").Append(problem.From).Append(" -> ").Append(problem.To).Append(" ").Append(problem.Line).Append('\n');
            output.Append("unreachable ").Append(string.Join(", ", Unreachable)).Append('\n');
            output.Append("entries ").Append(string.Join(", ", Entries)).Append('\n');
            output.Append("order ").Append(string.Join(", ", TaleOrder())).Append('\n');
            OrderedMap<TaleGraphPoint> positions = Layout();
            foreach (string id in positions.Keys)
                output.Append("at ").Append(id).Append(' ')
                    .Append(Math.Round(positions[id].X).ToString(CultureInfo.InvariantCulture)).Append(' ')
                    .Append(Math.Round(positions[id].Y).ToString(CultureInfo.InvariantCulture)).Append('\n');
            return output.ToString();
        }

        private bool EnteredFromOutside(string id, string tale)
        {
            foreach (string other in Beats.Keys)
            {
                if (Beats[other].Tale == tale) continue;
                foreach (var exit in Beats[other].Exits)
                    if (exit.To == id) return true;
            }
            return false;
        }

        private static void CollectExits(TaleNode node, string taleName, IDictionary<string, TaleDocument> docs, List<TaleGraphExit> exits, string label)
        {
            foreach (var child in node.Body)
            {
                if (child.Kind == TaleNodeKind.Jump)
                {
                    exits.Add(new TaleGraphExit { To = Resolve(child.JumpTarget, taleName), Kind = label.Length > 0 ? "choice" : "jump", Label = label, Line = child.LineStart });
                }
                else if (child.Kind == TaleNodeKind.Expression)
                {
                    string target = BeatCall(child.Expr, taleName, docs);
                    if (target.Length > 0)
                        exits.Add(new TaleGraphExit { To = target, Kind = "call", Label = label, Line = child.LineStart });
                }
                string childLabel = label;
                if (child.Kind == TaleNodeKind.Option)
                    childLabel = child.Expr != null && child.Expr.Kind == TaleExprKind.Literal ? GdValue.Str(child.Expr.Value) : "";
                else if (child.Kind == TaleNodeKind.Timeout)
                    childLabel = "timeout";
                CollectExits(child, taleName, docs, exits, childLabel);
            }
        }

        private static string NeedsOf(List<TaleExpr> annotations)
        {
            foreach (var annotation in annotations)
                if (annotation.Name == "needs" && annotation.Args.Count == 1 && annotation.Args[0].Value is string)
                    return (string)annotation.Args[0].Value;
            return "";
        }

        private static string Resolve(string target, string taleName)
        {
            return target.Contains(".") ? target : taleName + "." + target;
        }

        // "tale.beat" for a statement like other() or chapter.scene(), or "".
        private static string BeatCall(TaleExpr expr, string taleName, IDictionary<string, TaleDocument> docs)
        {
            if (expr == null) return "";
            if (expr.Kind == TaleExprKind.Await) expr = expr.Operands[0];
            if (expr.Kind != TaleExprKind.Call || expr.Args.Count > 0) return "";
            TaleExpr callee = expr.Operands[0];
            if (callee.Kind == TaleExprKind.Identifier && docs[taleName].FindBeat(callee.Name) != null)
                return taleName + "." + callee.Name;
            if (callee.Kind == TaleExprKind.Attribute && callee.Operands[0].Kind == TaleExprKind.Identifier && docs.ContainsKey(callee.Operands[0].Name))
                return callee.Operands[0].Name + "." + callee.Name;
            return "";
        }

        private static int Count(TaleNode node)
        {
            int total = 0;
            foreach (var child in node.Body)
                if (!child.IsTrivia() && child.Kind != TaleNodeKind.Pass) total += 1 + Count(child);
            return total;
        }

        // True if play can run off the end of a beat rather than always jumping somewhere.
        private static bool FallsThrough(TaleNode beat)
        {
            var children = new List<TaleNode>();
            foreach (var child in beat.Body)
                if (child.Kind != TaleNodeKind.Blank && child.Kind != TaleNodeKind.Pass) children.Add(child);
            while (children.Count > 0 && children[children.Count - 1].Kind == TaleNodeKind.Comment) children.RemoveAt(children.Count - 1);
            if (children.Count == 0) return true;
            TaleNode last = children[children.Count - 1];
            if (last.Kind == TaleNodeKind.Jump) return false;
            if (last.Kind == TaleNodeKind.Choose)
            {
                foreach (var option in last.Body)
                    if ((option.Kind == TaleNodeKind.Option || option.Kind == TaleNodeKind.Timeout) && FallsThrough(option)) return true;
                return false;
            }
            return true;
        }
    }
}
