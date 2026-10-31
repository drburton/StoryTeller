using System;
using System.Collections.Generic;
using System.IO;
using TaleScript;
using UnityEditor;
using UnityEditor.AssetImporters;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Imports .tale files as <see cref="TaleAsset"/> objects. Parse errors and checker
    /// warnings go to the Console as "file:line: message". When the project has a
    /// <see cref="StoryConfig"/>, the checker also knows its cast, exposed names, and
    /// tales, and reports unknown names as errors. Without one, only parse errors and
    /// warnings are reported, since names from game code cannot be known yet.
    /// </summary>
    [ScriptedImporter(1, "tale")]
    public class TaleImporter : ScriptedImporter
    {
        public override void OnImportAsset(AssetImportContext ctx)
        {
            string text = File.ReadAllText(ctx.assetPath);
            string taleName = Path.GetFileNameWithoutExtension(ctx.assetPath);
            StoryConfig config = FindConfig(ctx);

            TaleDocument document = TaleParser.Parse(text, ctx.assetPath);
            var found = new List<TaleDiagnostic>(document.Diagnostics);
            if (!document.HasErrors())
            {
                TaleCheckContext context;
                if (config != null)
                {
                    context = config.MakeCheckContext(taleName);
                }
                else
                {
                    context = new TaleCheckContext();
                    context.TaleName = taleName;
                }
                foreach (TaleDiagnostic problem in TaleChecker.Check(document, context))
                {
                    if (config != null || !problem.IsError()) found.Add(problem);
                }
            }

            var beats = new List<string>();
            var variables = new List<string>();
            foreach (TaleNode statement in document.Statements)
            {
                if (statement.Kind == TaleNodeKind.Beat) beats.Add(statement.Name);
                else if (statement.Kind == TaleNodeKind.Var || statement.Kind == TaleNodeKind.Const) variables.Add(statement.Name);
            }

            var asset = ScriptableObject.CreateInstance<TaleAsset>();
            asset.name = taleName;
            asset.SetImported(taleName, text, found, beats, variables);
            ctx.AddObjectToAsset("tale", asset);
            ctx.SetMainObject(asset);

            foreach (TaleDiagnostic problem in found)
            {
                string message = ctx.assetPath + ":" + problem.Line + ": " + problem.Message;
                if (problem.IsError()) ctx.LogImportError(message, asset);
                else ctx.LogImportWarning(message, asset);
            }
        }

        /// <summary>
        /// Finds the project's StoryConfig (the first by path) and makes the tale reimport
        /// when it changes. Returns null when there is none.
        /// </summary>
        private static StoryConfig FindConfig(AssetImportContext ctx)
        {
            string[] guids = AssetDatabase.FindAssets("t:StoryConfig");
            if (guids.Length == 0) return null;
            var paths = new List<string>();
            foreach (string guid in guids) paths.Add(AssetDatabase.GUIDToAssetPath(guid));
            paths.Sort(StringComparer.Ordinal);
            string path = paths[0];
            ctx.DependsOnSourceAsset(path);
            return AssetDatabase.LoadAssetAtPath<StoryConfig>(path);
        }
    }
}
