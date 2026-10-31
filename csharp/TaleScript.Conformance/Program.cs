using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace TaleScript.Conformance
{
    public static class Program
    {
        public static int Main(string[] args)
        {
            string root = args.Length > 0 ? args[0] : FindConformanceDir();
            if (root == null || !Directory.Exists(root))
            {
                Console.Error.WriteLine("Conformance directory not found. Pass it as the first argument.");
                return 2;
            }

            int passed = 0;
            int failed = 0;
            var utf8 = new UTF8Encoding(false);

            string parseDir = Path.Combine(root, "parse");
            var cases = new List<string>();
            if (Directory.Exists(parseDir))
            {
                foreach (string file in Directory.GetFiles(parseDir, "*.tale"))
                    cases.Add(Path.GetFileNameWithoutExtension(file));
            }
            cases.Sort(StringComparer.Ordinal);

            foreach (string name in cases)
            {
                string talePath = Path.Combine(parseDir, name + ".tale");
                string expectedPath = Path.Combine(parseDir, name + ".expected.txt");
                string source = File.ReadAllText(talePath, utf8);
                string actual = TaleParser.Parse(source, talePath).Dump();
                if (!File.Exists(expectedPath))
                {
                    Console.WriteLine("FAIL  parse/" + name);
                    Console.WriteLine("      no expected file");
                    failed++;
                    continue;
                }
                string expected = File.ReadAllText(expectedPath, utf8);
                string roundTrip = TaleParser.Parse(source, talePath).ToSource();
                if (actual == expected && roundTrip == source)
                {
                    Console.WriteLine("ok    parse/" + name);
                    passed++;
                }
                else
                {
                    Console.WriteLine("FAIL  parse/" + name);
                    Console.WriteLine(actual == expected ? "      source does not print back unchanged" : FirstDifference(expected, actual));
                    failed++;
                }
            }

            foreach (string kind in new[] { "check", "run" })
            {
                string kindDir = Path.Combine(root, kind);
                if (!Directory.Exists(kindDir))
                    continue;
                Console.WriteLine("skip  " + kind + "/ (not ported yet)");
                // Parser sanity: every tale must parse and print back unchanged.
                foreach (string file in Directory.GetFiles(kindDir, "*.tale"))
                {
                    string source = File.ReadAllText(file, utf8);
                    if (TaleParser.Parse(source, file).ToSource() != source)
                    {
                        Console.WriteLine("FAIL  roundtrip/" + kind + "/" + Path.GetFileNameWithoutExtension(file));
                        failed++;
                    }
                }
            }

            Console.WriteLine(passed + " passed, " + failed + " failed");
            return failed > 0 ? 1 : 0;
        }

        private static string FirstDifference(string expected, string actual)
        {
            string[] want = expected.Split('\n');
            string[] got = actual.Split('\n');
            int count = Math.Max(want.Length, got.Length);
            for (int i = 0; i < count; i++)
            {
                string w = i < want.Length ? want[i] : "<missing>";
                string g = i < got.Length ? got[i] : "<missing>";
                if (w != g)
                {
                    return "      line " + (i + 1) + "\n        expected: " + w + "\n        actual:   " + g;
                }
            }
            return "      no differing line";
        }

        private static string FindConformanceDir()
        {
            foreach (string start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
            {
                var dir = new DirectoryInfo(start);
                while (dir != null)
                {
                    string candidate = Path.Combine(dir.FullName, "conformance");
                    if (Directory.Exists(Path.Combine(candidate, "parse")))
                        return candidate;
                    dir = dir.Parent;
                }
            }
            return null;
        }
    }
}
