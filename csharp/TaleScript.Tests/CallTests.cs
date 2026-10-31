using System;
using System.Collections.Generic;

namespace TaleScript.Tests
{
    /// <summary>Tests for calling methods on exposed objects with named arguments.</summary>
    internal static class CallTests
    {
        public static IEnumerable<KeyValuePair<string, Action>> All()
        {
            yield return Test("named arguments reach a plain object's method", NamedByReflection);
            yield return Test("named arguments reach an ITaleObject with signatures", NamedBySignatures);
            yield return Test("an unknown argument name is an error", UnknownName);
            yield return Test("an object without signatures refuses named arguments", NoSignatures);
        }

        private static KeyValuePair<string, Action> Test(string name, Action body)
        {
            return new KeyValuePair<string, Action>(name, body);
        }

        public class Walker
        {
            public readonly List<string> Calls = new List<string>();

            public void Go(string place, double speed = 1.0, string how = "walk")
            {
                Calls.Add(place + " " + speed.ToString(System.Globalization.CultureInfo.InvariantCulture) + " " + how);
            }
        }

        private class Signed : ITaleObject, ITaleSignatures
        {
            public readonly List<string> Calls = new List<string>();

            public bool TryGetProperty(string name, out object value)
            {
                value = null;
                return false;
            }

            public bool TrySetProperty(string name, object value)
            {
                return false;
            }

            public object CallMethod(string name, object[] args)
            {
                var parts = new List<string>();
                foreach (object arg in args) parts.Add(arg == null ? "null" : GdValue.Str(arg));
                Calls.Add(name + "(" + string.Join(", ", parts) + ")");
                return null;
            }

            public IReadOnlyList<string> GetParameters(string method)
            {
                return method == "enter" ? new[] { "mood_name", "at", "time", "transition" } : null;
            }
        }

        private class Unsigned : Signed, ITaleObject
        {
        }

        private static List<string> Play(object target, string methods, string source)
        {
            var errors = new List<string>();
            var director = new TaleDirector();
            director.Presenter = new Player();
            director.RuntimeError += (message, tale, line) => errors.Add(line + ": " + message);
            director.Expose("it", target, new[] { methods });
            var built = TaleCompiler.Build(source, "main", director.MakeCheckContext("main"));
            if (built.Tale == null) throw new TestFailure("the tale did not compile");
            director.AddTale(built.Tale);
            director.Play("main").GetAwaiter().GetResult();
            return errors;
        }

        private static void NamedByReflection()
        {
            var walker = new Walker();
            var errors = Play(walker, "Go", "beat start:\n\tit.Go(\"home\", how = \"run\")\n\tit.Go(\"park\", speed = 2.5)\n");
            Check.Lines(new string[0], errors, "errors");
            Check.Lines(new[] { "home 1 run", "park 2.5 walk" }, walker.Calls, "calls");
        }

        private static void NamedBySignatures()
        {
            var signed = new Signed();
            var errors = Play(signed, "enter", "beat start:\n\tit.enter(\"smile\", time = 1.5)\n\tit.enter(at = 0.25)\n");
            Check.Lines(new string[0], errors, "errors");
            Check.Lines(new[] { "enter(smile, null, 1.5)", "enter(null, 0.25)" }, signed.Calls, "calls");
        }

        private static void UnknownName()
        {
            var errors = Play(new Signed(), "enter", "beat start:\n\tit.enter(speed = 2)\n");
            Check.Lines(new[] { "2: 'enter' has no argument named 'speed'." }, errors, "errors");
        }

        private static void NoSignatures()
        {
            var errors = Play(new Unsigned(), "leave", "beat start:\n\tit.leave(time = 2)\n");
            Check.Lines(new[] { "2: Named arguments only work with actions." }, errors, "errors");
        }
    }
}
