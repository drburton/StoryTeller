using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    /// <summary>The methods tales can call on text, arrays, and dictionaries.</summary>
    public static class GdMethods
    {
        /// <summary>Calls method on target. Throws <see cref="GdOpException"/> when the method or its arguments do not fit.</summary>
        public static object Call(object target, string method, object[] args)
        {
            if (target is string text) return CallString(text, method, args);
            if (target is List<object> list) return CallArray(list, method, args);
            if (target is TaleDict dict) return CallDict(dict, method, args);
            throw new GdOpException();
        }

        private static void Expect(object[] args, int min, int max)
        {
            if (args.Length < min || args.Length > max) throw new GdOpException();
        }

        private static string Text(object[] args, int i)
        {
            if (i < args.Length && args[i] is string s) return s;
            throw new GdOpException();
        }

        private static int Int(object[] args, int i)
        {
            if (i < args.Length && args[i] is long l) return (int)Math.Max(int.MinValue, Math.Min(int.MaxValue, l));
            throw new GdOpException();
        }

        private static object CallString(string s, string method, object[] args)
        {
            switch (method)
            {
                case "length":
                    Expect(args, 0, 0);
                    return (long)s.Length;
                case "is_empty":
                    Expect(args, 0, 0);
                    return s.Length == 0;
                case "to_upper":
                    Expect(args, 0, 0);
                    return s.ToUpperInvariant();
                case "to_lower":
                    Expect(args, 0, 0);
                    return s.ToLowerInvariant();
                case "capitalize":
                    Expect(args, 0, 0);
                    return Capitalize(s);
                case "begins_with":
                    Expect(args, 1, 1);
                    return s.StartsWith(Text(args, 0), StringComparison.Ordinal);
                case "ends_with":
                    Expect(args, 1, 1);
                    return s.EndsWith(Text(args, 0), StringComparison.Ordinal);
                case "contains":
                    Expect(args, 1, 1);
                    return s.Contains(Text(args, 0));
                case "find":
                {
                    Expect(args, 1, 2);
                    int from = args.Length > 1 ? Int(args, 1) : 0;
                    if (from < 0 || from > s.Length) return -1L;
                    return (long)s.IndexOf(Text(args, 0), from, StringComparison.Ordinal);
                }
                case "rfind":
                    Expect(args, 1, 1);
                    return (long)s.LastIndexOf(Text(args, 0), StringComparison.Ordinal);
                case "count":
                {
                    Expect(args, 1, 1);
                    string part = Text(args, 0);
                    if (part.Length == 0) return 0L;
                    long n = 0;
                    int at = 0;
                    while ((at = s.IndexOf(part, at, StringComparison.Ordinal)) >= 0)
                    {
                        n++;
                        at += part.Length;
                    }
                    return n;
                }
                case "replace":
                {
                    Expect(args, 2, 2);
                    string from = Text(args, 0);
                    return from.Length == 0 ? s : s.Replace(from, Text(args, 1));
                }
                case "strip_edges":
                    Expect(args, 0, 2);
                    return GdFormat.StripEdges(s);
                case "trim_prefix":
                {
                    Expect(args, 1, 1);
                    string p = Text(args, 0);
                    return p.Length > 0 && s.StartsWith(p, StringComparison.Ordinal) ? s.Substring(p.Length) : s;
                }
                case "trim_suffix":
                {
                    Expect(args, 1, 1);
                    string p = Text(args, 0);
                    return p.Length > 0 && s.EndsWith(p, StringComparison.Ordinal) ? s.Substring(0, s.Length - p.Length) : s;
                }
                case "split":
                {
                    Expect(args, 0, 2);
                    string delimiter = args.Length > 0 ? Text(args, 0) : "";
                    bool allowEmpty = args.Length < 2 || GdValue.Truthy(args[1]);
                    var parts = new List<object>();
                    if (delimiter.Length == 0)
                    {
                        parts.AddRange(GdValue.ToItems(s));
                        return parts;
                    }
                    foreach (string piece in s.Split(new[] { delimiter }, StringSplitOptions.None))
                        if (allowEmpty || piece.Length > 0) parts.Add(piece);
                    return parts;
                }
                case "substr":
                    Expect(args, 1, 2);
                    return GdFormat.Substr(s, Int(args, 0), args.Length > 1 ? Int(args, 1) : int.MaxValue);
                case "left":
                    Expect(args, 1, 1);
                    return Int(args, 0) < 0 ? GdFormat.Substr(s, 0, Math.Max(0, s.Length + Int(args, 0))) : GdFormat.Substr(s, 0, Int(args, 0));
                case "right":
                {
                    Expect(args, 1, 1);
                    int n = Int(args, 0);
                    if (n < 0) return GdFormat.Substr(s, -n);
                    return GdFormat.Substr(s, Math.Max(0, s.Length - n));
                }
                case "to_int":
                    Expect(args, 0, 0);
                    return GdFormat.ToInt(s);
                case "to_float":
                    Expect(args, 0, 0);
                    return GdFormat.ToFloat(s);
                case "is_valid_int":
                {
                    Expect(args, 0, 0);
                    long ignored;
                    return long.TryParse(s, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out ignored);
                }
                case "is_valid_float":
                    Expect(args, 0, 0);
                    return GdFormat.IsValidFloat(s);
                case "pad_zeros":
                {
                    Expect(args, 1, 1);
                    int width = Int(args, 0);
                    bool negative = s.StartsWith("-", StringComparison.Ordinal);
                    string digits = negative ? s.Substring(1) : s;
                    return (negative ? "-" : "") + digits.PadLeft(Math.Max(0, width), '0');
                }
                case "join":
                {
                    Expect(args, 1, 1);
                    var list = args[0] as List<object>;
                    if (list == null) throw new GdOpException();
                    var parts = new List<string>();
                    foreach (object item in list) parts.Add(GdValue.Str(item));
                    return string.Join(s, parts);
                }
            }
            throw new GdOpException();
        }

        /// <summary>GDScript String.capitalize(): "old_guide" and "oldGuide" become "Old Guide".</summary>
        public static string Capitalize(string s)
        {
            var sb = new StringBuilder();
            bool startOfWord = true;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (c == '_' || c == '-' || c == ' ')
                {
                    if (sb.Length > 0 && sb[sb.Length - 1] != ' ') sb.Append(' ');
                    startOfWord = true;
                    continue;
                }
                if (!startOfWord && char.IsUpper(c) && char.IsLower(s[i - 1]))
                {
                    sb.Append(' ');
                    startOfWord = true;
                }
                sb.Append(startOfWord ? char.ToUpperInvariant(c) : char.ToLowerInvariant(c));
                startOfWord = false;
            }
            return sb.ToString().TrimEnd(' ');
        }

        private static object CallArray(List<object> a, string method, object[] args)
        {
            switch (method)
            {
                case "append":
                case "push_back":
                    Expect(args, 1, 1);
                    a.Add(args[0]);
                    return null;
                case "push_front":
                    Expect(args, 1, 1);
                    a.Insert(0, args[0]);
                    return null;
                case "append_array":
                    Expect(args, 1, 1);
                    if (!(args[0] is List<object> more)) throw new GdOpException();
                    a.AddRange(new List<object>(more));
                    return null;
                case "pop_back":
                {
                    Expect(args, 0, 0);
                    if (a.Count == 0) return null;
                    object last = a[a.Count - 1];
                    a.RemoveAt(a.Count - 1);
                    return last;
                }
                case "pop_front":
                {
                    Expect(args, 0, 0);
                    if (a.Count == 0) return null;
                    object first = a[0];
                    a.RemoveAt(0);
                    return first;
                }
                case "size":
                    Expect(args, 0, 0);
                    return (long)a.Count;
                case "is_empty":
                    Expect(args, 0, 0);
                    return a.Count == 0;
                case "has":
                    Expect(args, 1, 1);
                    return GdValue.Contains(a, args[0]);
                case "find":
                {
                    Expect(args, 1, 2);
                    for (int i = args.Length > 1 ? Int(args, 1) : 0; i < a.Count; i++)
                        if (GdValue.Equal(a[i], args[0])) return (long)i;
                    return -1L;
                }
                case "count":
                {
                    Expect(args, 1, 1);
                    long n = 0;
                    foreach (object item in a)
                        if (GdValue.Equal(item, args[0])) n++;
                    return n;
                }
                case "clear":
                    Expect(args, 0, 0);
                    a.Clear();
                    return null;
                case "insert":
                {
                    Expect(args, 2, 2);
                    int at = Int(args, 0);
                    if (at < 0 || at > a.Count) throw new GdOpException();
                    a.Insert(at, args[1]);
                    return 0L;
                }
                case "erase":
                {
                    Expect(args, 1, 1);
                    for (int i = 0; i < a.Count; i++)
                    {
                        if (!GdValue.Equal(a[i], args[0])) continue;
                        a.RemoveAt(i);
                        break;
                    }
                    return null;
                }
                case "remove_at":
                {
                    Expect(args, 1, 1);
                    int at = Int(args, 0);
                    if (at < 0) at += a.Count;
                    if (at < 0 || at >= a.Count) throw new GdOpException();
                    a.RemoveAt(at);
                    return null;
                }
                case "reverse":
                    Expect(args, 0, 0);
                    a.Reverse();
                    return null;
                case "sort":
                {
                    Expect(args, 0, 0);
                    var sorted = StableSort(a);
                    a.Clear();
                    a.AddRange(sorted);
                    return null;
                }
                case "duplicate":
                    Expect(args, 0, 1);
                    return new List<object>(a);
                case "front":
                    Expect(args, 0, 0);
                    return a.Count > 0 ? a[0] : null;
                case "back":
                    Expect(args, 0, 0);
                    return a.Count > 0 ? a[a.Count - 1] : null;
                case "min":
                case "max":
                {
                    Expect(args, 0, 0);
                    if (a.Count == 0) return null;
                    object best = a[0];
                    foreach (object item in a)
                        if (GdValue.Relation(method == "min" ? "<" : ">", item, best)) best = item;
                    return best;
                }
                case "slice":
                {
                    Expect(args, 1, 2);
                    int begin = Int(args, 0);
                    int end = args.Length > 1 ? Int(args, 1) : a.Count;
                    if (begin < 0) begin += a.Count;
                    if (end < 0) end += a.Count;
                    begin = Math.Max(0, Math.Min(begin, a.Count));
                    end = Math.Max(begin, Math.Min(end, a.Count));
                    return a.GetRange(begin, end - begin);
                }
            }
            throw new GdOpException();
        }

        private static List<object> StableSort(List<object> items)
        {
            var indexed = new List<KeyValuePair<int, object>>();
            for (int i = 0; i < items.Count; i++) indexed.Add(new KeyValuePair<int, object>(i, items[i]));
            indexed.Sort((x, y) =>
            {
                if (GdValue.Equal(x.Value, y.Value)) return x.Key.CompareTo(y.Key);
                return GdValue.Relation("<", x.Value, y.Value) ? -1 : 1;
            });
            var result = new List<object>();
            foreach (var pair in indexed) result.Add(pair.Value);
            return result;
        }

        private static object CallDict(TaleDict d, string method, object[] args)
        {
            switch (method)
            {
                case "has":
                    Expect(args, 1, 1);
                    return d.Has(args[0]);
                case "has_all":
                {
                    Expect(args, 1, 1);
                    var keys = args[0] as List<object>;
                    if (keys == null) throw new GdOpException();
                    foreach (object key in keys)
                        if (!d.Has(key)) return false;
                    return true;
                }
                case "keys":
                    Expect(args, 0, 0);
                    return d.Keys;
                case "values":
                    Expect(args, 0, 0);
                    return d.Values;
                case "size":
                    Expect(args, 0, 0);
                    return (long)d.Count;
                case "is_empty":
                    Expect(args, 0, 0);
                    return d.Count == 0;
                case "erase":
                    Expect(args, 1, 1);
                    return d.Remove(args[0]);
                case "clear":
                    Expect(args, 0, 0);
                    d.Clear();
                    return null;
                case "get":
                {
                    Expect(args, 1, 2);
                    object value;
                    if (d.TryGetValue(args[0], out value)) return value;
                    return args.Length > 1 ? args[1] : null;
                }
                case "merge":
                {
                    Expect(args, 1, 2);
                    var other = args[0] as TaleDict;
                    if (other == null) throw new GdOpException();
                    bool overwrite = args.Length > 1 && GdValue.Truthy(args[1]);
                    foreach (object key in other.Keys)
                        if (overwrite || !d.Has(key)) d[key] = other[key];
                    return null;
                }
                case "duplicate":
                    Expect(args, 0, 1);
                    return d.Duplicate();
            }
            throw new GdOpException();
        }
    }
}
