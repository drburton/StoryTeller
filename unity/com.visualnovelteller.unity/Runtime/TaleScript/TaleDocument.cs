using System.Collections.Generic;
using System.Text;

namespace TaleScript
{
    /// <summary>
    /// A parsed tale: its syntax tree, its diagnostics, and its original lines.
    /// Created by <see cref="TaleParser.Parse"/>.
    /// </summary>
    public class TaleDocument
    {
        /// <summary>Path of the tale file, or "" for text parsed from memory.</summary>
        public string Path = "";
        /// <summary>Top-level statements in source order.</summary>
        public List<TaleNode> Statements = new List<TaleNode>();
        /// <summary>Errors and warnings, in source order.</summary>
        public List<TaleDiagnostic> Diagnostics = new List<TaleDiagnostic>();
        /// <summary>The source split on "\n". Line endings such as "\r" stay in each line.</summary>
        public string[] Lines = new string[0];

        public bool HasErrors()
        {
            foreach (var diagnostic in Diagnostics)
                if (diagnostic.IsError()) return true;
            return false;
        }

        /// <summary>Returns the top-level beat called beatName, or null.</summary>
        public TaleNode FindBeat(string beatName)
        {
            foreach (var statement in Statements)
                if (statement.Kind == TaleNodeKind.Beat && statement.Name == beatName)
                    return statement;
            return null;
        }

        /// <summary>Rebuilds the source text by walking the tree.</summary>
        public string ToSource()
        {
            var output = new List<string>();
            CollectLines(Statements, output);
            if (Lines.Length > ContentLineCount())
                output.Add(Lines[Lines.Length - 1]);
            return string.Join("\n", output);
        }

        /// <summary>Returns the indented tree dump followed by any diagnostics, used by tests.</summary>
        public string Dump()
        {
            var text = new StringBuilder();
            foreach (var statement in Statements)
                text.Append(statement.Dump());
            if (Diagnostics.Count > 0)
            {
                text.Append("--- diagnostics ---\n");
                foreach (var diagnostic in Diagnostics)
                    text.Append(diagnostic.ToString()).Append('\n');
            }
            return text.ToString();
        }

        /// <summary>
        /// Number of lines holding content. A trailing "\n" adds an empty final
        /// element to Lines that is not a line of its own.
        /// </summary>
        private int ContentLineCount()
        {
            if (Lines.Length > 0 && Lines[Lines.Length - 1] == "")
                return Lines.Length - 1;
            return Lines.Length;
        }

        private void CollectLines(List<TaleNode> nodes, List<string> output)
        {
            foreach (var node in nodes)
            {
                if (!node.Inline)
                {
                    for (int lineNumber = node.LineStart; lineNumber <= node.LineEnd; lineNumber++)
                        output.Add(Lines[lineNumber - 1]);
                }
                CollectLines(node.Body, output);
            }
        }
    }
}
