using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using TaleScript.Tools;

namespace TaleScript.Check
{
    /// Checks .tale files from the command line with the C# core, the way an
    /// editor or a build step outside Godot would. Prints one problem per
    /// line as "<file>:<line>: <message>" and exits with 1 when any file has
    /// an error. Usage:
    ///   talescript-check [--context=<file.json>] [--strict] [--paths] [--expose=a,b] [--actions=a,b] <file or folder>...
    /// The context file uses the conformance check format (conformance/README.md).
    /// With --strict, warnings also fail the check. With --paths, each file that checks
    /// clean is also played down every path from the beat "start", and a path that hits a
    /// problem fails the run. --expose adds names that game code exposes, and --actions
    /// adds actions such as music or backdrop with their arguments unchecked.
    public static class Program
    {
        public static int Main(string[] args)
        {
            string contextPath = null;
            bool strict = false;
            bool explore = false;
            var exposeNames = new List<string>();
            var actionNames = new List<string>();
            var paths = new List<string>();
            foreach (string arg in args)
            {
                if (arg.StartsWith("--context=", StringComparison.Ordinal)) contextPath = arg.Substring("--context=".Length);
                else if (arg == "--strict") strict = true;
                else if (arg == "--paths") explore = true;
                else if (arg.StartsWith("--expose=", StringComparison.Ordinal))
                    exposeNames.AddRange(arg.Substring("--expose=".Length).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries));
                else if (arg.StartsWith("--actions=", StringComparison.Ordinal))
                    actionNames.AddRange(arg.Substring("--actions=".Length).Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries));
                else if (arg == "--help" || arg == "-h") return Usage(0);
                else if (arg.StartsWith("--", StringComparison.Ordinal)) return Usage(2);
                else paths.Add(arg);
            }
            if (paths.Count == 0) return Usage(2);

            JsonElement? settings = null;
            if (contextPath != null)
            {
                if (!File.Exists(contextPath))
                {
                    Console.Error.WriteLine("Context file not found: " + contextPath);
                    return 2;
                }
                using (var json = JsonDocument.Parse(File.ReadAllText(contextPath, Encoding.UTF8)))
                    settings = json.RootElement.Clone();
            }

            var files = new List<string>();
            foreach (string path in paths)
            {
                if (Directory.Exists(path))
                {
                    var found = new List<string>(Directory.GetFiles(path, "*.tale", SearchOption.AllDirectories));
                    found.Sort(StringComparer.Ordinal);
                    files.AddRange(found);
                }
                else if (File.Exists(path)) files.Add(path);
                else
                {
                    Console.Error.WriteLine("Not found: " + path);
                    return 2;
                }
            }

            int errors = 0, warnings = 0;
            var clean = new List<string>();
            foreach (string file in files)
            {
                string taleName = Path.GetFileNameWithoutExtension(file);
                var doc = TaleParser.Parse(File.ReadAllText(file, Encoding.UTF8));
                int before = errors;
                foreach (var d in doc.Diagnostics)
                {
                    Console.WriteLine(file + ":" + d.Line + ": " + d.Message);
                    errors++;
                }
                TaleCheckContext context = CheckContextJson.ContextFor(settings, taleName);
                foreach (string name in exposeNames) context.AddExposed(name);
                foreach (string name in actionNames) context.AddActionUnchecked(name);
                foreach (var d in TaleChecker.Check(doc, context))
                {
                    Console.WriteLine(file + ":" + d.Line + ": " + (d.IsError() ? "" : "warning: ") + d.Message);
                    if (d.IsError()) errors++;
                    else warnings++;
                }
                if (errors == before) clean.Add(file);
            }
            int pathProblems = 0;
            if (explore) pathProblems = ExplorePaths(clean, settings, exposeNames, actionNames);
            Console.WriteLine(files.Count + (files.Count == 1 ? " file, " : " files, ") + errors + (errors == 1 ? " error, " : " errors, ") + warnings + (warnings == 1 ? " warning" : " warnings"));
            return errors > 0 || pathProblems > 0 || (strict && warnings > 0) ? 1 : 0;
        }

        /// Plays each file from the beat "start" down every path and prints a short report.
        /// Returns how many problems the paths found. The other files are available to the
        /// tale as tales it can jump to.
        private static int ExplorePaths(List<string> files, JsonElement? settings, List<string> exposeNames, List<string> actionNames)
        {
            var sources = new Dictionary<string, string>();
            foreach (string file in files)
                sources[Path.GetFileNameWithoutExtension(file)] = File.ReadAllText(file, Encoding.UTF8);
            TaleCheckContext known = CheckContextJson.ContextFor(settings, "");
            foreach (string name in actionNames) known.AddActionUnchecked(name);
            var options = new TalePathsOptions();
            options.Exposed.AddRange(exposeNames);
            options.Exposed.AddRange(known.Exposed.Keys);
            options.CastIds.AddRange(known.Cast.Keys);
            options.Setup = director =>
            {
                foreach (string action in known.Actions.Keys)
                {
                    TaleActionSignature signature = known.Actions[action];
                    if (signature != null)
                    {
                        director.AddAction(new TaleStubAction(action, signature.Params, signature.Required));
                        continue;
                    }
                    var open = new List<string>();
                    for (int i = 1; i <= 8; i++) open.Add("a" + i);
                    director.AddAction(new TaleStubAction(action, open, 0));
                }
                director.ContextExtender = c =>
                {
                    foreach (string id in known.Cast.Keys) c.AddCast(id, known.Cast[id], known.CastFields[id]);
                    foreach (string other in known.Tales.Keys)
                        if (!c.Tales.Has(other)) c.AddTale(other, known.Tales[other].Beats, known.Tales[other].Vars);
                };
            };
            int problems = 0;
            foreach (string file in files)
            {
                string taleName = Path.GetFileNameWithoutExtension(file);
                TalePathsResult result = TalePaths.Explore(taleName, "start", sources, options).GetAwaiter().GetResult();
                Console.WriteLine(file + ": " + result.PathCount + (result.PathCount == 1 ? " path" : " paths")
                    + (result.Complete ? "" : " (stopped early; there are more)"));
                var endings = new List<string>();
                foreach (string ending in result.Endings.Keys) endings.Add(ending + " (" + result.Endings[ending] + ")");
                Console.WriteLine("  endings: " + (endings.Count > 0 ? string.Join(", ", endings) : "none"));
                if (result.Unreached.Count > 0) Console.WriteLine("  never reached: " + string.Join(", ", result.Unreached));
                foreach (TalePathProblem problem in result.Problems)
                {
                    problems++;
                    string where = problem.Line > 0 ? file + ":" + problem.Line : file;
                    string after = problem.FirstPath.Count == 0 ? "(no choices)"
                        : problem.FirstPath.Count <= 12 ? string.Join(" > ", problem.FirstPath)
                        : string.Join(" > ", problem.FirstPath.GetRange(0, 12)) + " > ... (" + (problem.FirstPath.Count - 12) + " more)";
                    Console.WriteLine("  " + where + ": " + problem.Kind + ": " + problem.Message
                        + " (" + problem.Paths + (problem.Paths == 1 ? " path" : " paths") + ", first after: " + after + ")");
                }
            }
            return problems;
        }

        private static int Usage(int code)
        {
            Console.Error.WriteLine("Usage: talescript-check [--context=<file.json>] [--strict] [--paths] [--expose=a,b] [--actions=a,b] <file or folder>...");
            return code;
        }
    }
}
