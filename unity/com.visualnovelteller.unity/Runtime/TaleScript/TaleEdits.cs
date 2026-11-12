using System;
using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>
    /// Line-level edits to a tale's source that keep the rest of the file as it is: comments,
    /// blank lines, indentation, and line endings. The C# version of the Godot plugin's TaleEdit
    /// functions that the Story Map uses (decision 0012). Line numbers start at 1.
    /// </summary>
    public static class TaleEdits
    {
        /// <summary>
        /// Adds text as the last statement of a block, such as a beat. A block holding only a
        /// "pass" line gets the text in its place.
        /// </summary>
        public static string AppendTo(string source, TaleDocument doc, TaleNode parent, string text)
        {
            List<TaleNode> children = ContentChildren(parent);
            if (children.Count == 0)
            {
                string indent = ChildIndent(doc, parent);
                TaleNode passNode = OnlyPass(parent);
                if (passNode != null && !passNode.Inline)
                    return ReplaceLines(source, passNode.LineStart, passNode.LineEnd, Indented(text, passNode.Indent));
                int end = EndLine(parent);
                return ReplaceLines(source, end + 1, end, Indented(text, indent));
            }
            return InsertAfter(source, children[children.Count - 1], text);
        }

        /// <summary>Adds a beat at the end of the file, after a blank line, with one statement in it.</summary>
        public static string AddBeat(string source, TaleDocument doc, string beatName, string firstLine = "pass")
        {
            string unit = IndentUnit(doc);
            string text = source ?? "";
            if (text.Length > 0 && !text.EndsWith("\n", StringComparison.Ordinal)) text += "\n";
            if (text.Length > 0 && !text.EndsWith("\n\n", StringComparison.Ordinal)) text += "\n";
            return text + "beat " + beatName + ":\n" + unit + firstLine + "\n";
        }

        /// <summary>A beat name the tale doesn't use yet: "new_beat", then "new_beat_2", "new_beat_3", ...</summary>
        public static string NewBeatName(TaleDocument doc, string baseName = "new_beat")
        {
            string name = baseName;
            int n = 2;
            while (doc.FindBeat(name) != null)
            {
                name = baseName + "_" + n;
                n++;
            }
            return name;
        }

        /// <summary>The target of a jump from a beat in tale to the beat id ("tale.beat"): just the beat name within the same tale.</summary>
        public static string JumpTarget(string id, string tale)
        {
            return id.StartsWith(tale + ".", StringComparison.Ordinal) ? id.Substring(tale.Length + 1) : id;
        }

        /// <summary>Inserts text after a statement and its body, at the statement's indentation.</summary>
        public static string InsertAfter(string source, TaleNode anchor, string text)
        {
            int end = EndLine(anchor);
            return ReplaceLines(source, end + 1, end, Indented(text, anchor.Indent));
        }

        /// <summary>
        /// Replaces lines first to last (1-based, inclusive) with new lines. Use last = first - 1 to
        /// insert before line first. Keeps the file's CRLF line endings.
        /// </summary>
        public static string ReplaceLines(string source, int first, int last, IList<string> newLines)
        {
            string[] lines = (source ?? "").Split('\n');
            bool crlf = lines.Length > 1 && lines[0].EndsWith("\r", StringComparison.Ordinal);
            var result = new List<string>();
            for (int i = 0; i < Math.Min(first - 1, lines.Length); i++) result.Add(lines[i]);
            foreach (string line in newLines) result.Add(crlf ? line + "\r" : line);
            for (int i = Math.Max(last, first - 1); i < lines.Length; i++) result.Add(lines[i]);
            return string.Join("\n", result);
        }

        /// <summary>The statements of a block other than blank lines and "pass".</summary>
        public static List<TaleNode> ContentChildren(TaleNode parent)
        {
            var result = new List<TaleNode>();
            foreach (var child in parent.Body)
                if (child.Kind != TaleNodeKind.Blank && child.Kind != TaleNodeKind.Pass) result.Add(child);
            return result;
        }

        /// <summary>The indentation for statements inside a block.</summary>
        public static string ChildIndent(TaleDocument doc, TaleNode parent)
        {
            foreach (var child in parent.Body)
                if (child.Kind != TaleNodeKind.Blank && !child.Inline) return child.Indent;
            return parent.Indent + IndentUnit(doc);
        }

        /// <summary>The file's indentation step: a tab, or the smallest run of spaces used.</summary>
        public static string IndentUnit(TaleDocument doc)
        {
            int smallest = 0;
            foreach (string line in doc.Lines)
            {
                if (line.StartsWith("\t", StringComparison.Ordinal)) return "\t";
                if (line.StartsWith(" ", StringComparison.Ordinal) && line.Trim().Length > 0)
                {
                    int count = line.Length - line.TrimStart(' ').Length;
                    if (smallest == 0 || count < smallest) smallest = count;
                }
            }
            return smallest > 0 ? new string(' ', smallest) : "\t";
        }

        private static int EndLine(TaleNode node)
        {
            int end = node.LineEnd;
            for (int i = node.Body.Count - 1; i >= 0; i--)
            {
                TaleNode child = node.Body[i];
                if (child.Kind != TaleNodeKind.Blank) return Math.Max(end, EndLine(child));
            }
            return end;
        }

        private static TaleNode OnlyPass(TaleNode parent)
        {
            foreach (var child in parent.Body)
                if (child.Kind == TaleNodeKind.Pass) return child;
            return null;
        }

        private static List<string> Indented(string text, string indent)
        {
            var output = new List<string>();
            foreach (string line in text.Split('\n'))
                output.Add(line.Trim().Length > 0 ? indent + line : "");
            return output;
        }
    }
}
