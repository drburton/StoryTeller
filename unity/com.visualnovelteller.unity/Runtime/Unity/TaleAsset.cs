using System;
using System.Collections.Generic;
using TaleScript;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>One error or warning found when a .tale file was imported, stored in the <see cref="TaleAsset"/>.</summary>
    [Serializable]
    public class TaleAssetDiagnostic
    {
        public int line;
        public int column;
        public TaleSeverity severity;
        public string message = "";

        public TaleAssetDiagnostic()
        {
        }

        public TaleAssetDiagnostic(TaleDiagnostic diagnostic)
        {
            line = diagnostic.Line;
            column = diagnostic.Column;
            severity = diagnostic.Severity;
            message = diagnostic.Message;
        }
    }

    /// <summary>
    /// A .tale file imported into the project. It keeps the tale's name, its source text,
    /// and the problems found at import, so the Inspector can show them and the
    /// <see cref="Story"/> can compile the tale when the game starts.
    /// </summary>
    public class TaleAsset : ScriptableObject
    {
        [SerializeField] private string taleName = "";
        [SerializeField, TextArea(3, 30)] private string source = "";
        [SerializeField] private List<TaleAssetDiagnostic> diagnostics = new List<TaleAssetDiagnostic>();
        [SerializeField] private List<string> beats = new List<string>();
        [SerializeField] private List<string> variables = new List<string>();

        /// <summary>The name tales use for this tale, taken from the file name.</summary>
        public string TaleName { get { return taleName; } }
        /// <summary>The text of the .tale file.</summary>
        public string Source { get { return source; } }
        /// <summary>Errors and warnings found at import.</summary>
        public IReadOnlyList<TaleAssetDiagnostic> Diagnostics { get { return diagnostics; } }
        /// <summary>Names of the top-level beats, found at import so other tales can be checked against them.</summary>
        public IReadOnlyList<string> Beats { get { return beats; } }
        /// <summary>Names of the tale's var and const declarations, found at import.</summary>
        public IReadOnlyList<string> Variables { get { return variables; } }

        /// <summary>True when the import found at least one error.</summary>
        public bool HasErrors
        {
            get
            {
                foreach (var diagnostic in diagnostics)
                    if (diagnostic.severity == TaleSeverity.Error) return true;
                return false;
            }
        }

        /// <summary>Fills the asset. The importer calls this; game code does not need to.</summary>
        public void SetImported(string name, string text, IEnumerable<TaleDiagnostic> found, IEnumerable<string> beatNames, IEnumerable<string> variableNames)
        {
            taleName = name;
            source = text ?? "";
            diagnostics = new List<TaleAssetDiagnostic>();
            if (found != null)
                foreach (var diagnostic in found) diagnostics.Add(new TaleAssetDiagnostic(diagnostic));
            beats = beatNames == null ? new List<string>() : new List<string>(beatNames);
            variables = variableNames == null ? new List<string>() : new List<string>(variableNames);
        }

        /// <summary>
        /// Parses, checks, and compiles the tale. <see cref="TaleBuildResult.Tale"/> is null
        /// when there are errors.
        /// </summary>
        public TaleBuildResult Build(TaleCheckContext context)
        {
            return TaleCompiler.Build(source, taleName, context, name);
        }
    }
}
