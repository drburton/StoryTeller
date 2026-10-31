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
    ///   talescript-check [--context=<file.json>] [--strict] <file or folder>...
    /// The context file uses the conformance check format (conformance/README.md).
    /// With --strict, warnings also fail the check.
    public static class Program
    {
        public static int Main(string[] args)
        {
            string contextPath = null;
            bool strict = false;
            var paths = new List<string>();
            foreach (string arg in args)
            {
                if (arg.StartsWith("--context=", StringComparison.Ordinal)) contextPath = arg.Substring("--context=".Length);
                else if (arg == "--strict") strict = true;
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
            foreach (string file in files)
            {
                string taleName = Path.GetFileNameWithoutExtension(file);
                var doc = TaleParser.Parse(File.ReadAllText(file, Encoding.UTF8));
                foreach (var d in doc.Diagnostics)
                {
                    Console.WriteLine(file + ":" + d.Line + ": " + d.Message);
                    errors++;
                }
                foreach (var d in TaleChecker.Check(doc, CheckContextJson.ContextFor(settings, taleName)))
                {
                    Console.WriteLine(file + ":" + d.Line + ": " + (d.IsError() ? "" : "warning: ") + d.Message);
                    if (d.IsError()) errors++;
                    else warnings++;
                }
            }
            Console.WriteLine(files.Count + (files.Count == 1 ? " file, " : " files, ") + errors + (errors == 1 ? " error, " : " errors, ") + warnings + (warnings == 1 ? " warning" : " warnings"));
            return errors > 0 || (strict && warnings > 0) ? 1 : 0;
        }

        private static int Usage(int code)
        {
            Console.Error.WriteLine("Usage: talescript-check [--context=<file.json>] [--strict] <file or folder>...");
            return code;
        }
    }
}
