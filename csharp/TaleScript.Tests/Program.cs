using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace TaleScript.Tests
{
    /// <summary>Raised by the assertion helpers.</summary>
    internal class TestFailure : Exception
    {
        public TestFailure(string message) : base(message)
        {
        }
    }

    internal static class Check
    {
        public static void True(bool condition, string message = "expected true")
        {
            if (!condition) throw new TestFailure(message);
        }

        public static void Equal<T>(T expected, T actual, string what = "value")
        {
            if (!EqualityComparer<T>.Default.Equals(expected, actual))
                throw new TestFailure(what + ": expected " + expected + " but got " + actual);
        }

        public static void Lines(IList<string> expected, IList<string> actual, string what = "lines")
        {
            string a = "[" + string.Join(" | ", expected) + "]";
            string b = "[" + string.Join(" | ", actual) + "]";
            if (a != b) throw new TestFailure(what + ": expected " + a + " but got " + b);
        }
    }

    internal static class Program
    {
        private static int Main()
        {
            int passed = 0, failed = 0;
            foreach (var test in StateTests.All())
            {
                try
                {
                    test.Value();
                    Console.WriteLine("ok    " + test.Key);
                    passed++;
                }
                catch (Exception e)
                {
                    Console.WriteLine("FAIL  " + test.Key + ": " + e.Message);
                    failed++;
                }
            }
            Console.WriteLine(passed + " passed, " + failed + " failed");
            return failed > 0 ? 1 : 0;
        }
    }
}
