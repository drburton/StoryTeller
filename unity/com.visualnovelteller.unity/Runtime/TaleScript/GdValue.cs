using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    /// <summary>Raised by value helpers when an operation does not apply. The evaluator turns it into a runtime error message.</summary>
    public class GdOpException : Exception
    {
        public GdOpException() : base("Invalid operation.") { }
    }

    /// <summary>
    /// Value semantics of tale values, following GDScript: null, bool, long,
    /// double, string, List&lt;object&gt; (Array), and <see cref="TaleDict"/> (Dictionary).
    /// </summary>
    public static class GdValue
    {
        /// <summary>Converts host numbers and lists to the value kinds tales use.</summary>
        public static object Normalize(object value)
        {
            if (value == null) return null;
            if (value is long || value is double || value is bool || value is string) return value;
            if (value is int i) return (long)i;
            if (value is short sh) return (long)sh;
            if (value is byte by) return (long)by;
            if (value is uint ui) return (long)ui;
            if (value is ushort us) return (long)us;
            if (value is float f) return (double)f;
            if (value is decimal m) return (double)m;
            if (value is char c) return c.ToString();
            if (value is Enum) return Convert.ToInt64(value, CultureInfo.InvariantCulture);
            return value;
        }

        /// <summary>The GDScript type_string() of a value.</summary>
        public static string TypeName(object value)
        {
            if (value == null) return "Nil";
            if (value is bool) return "bool";
            if (value is long) return "int";
            if (value is double) return "float";
            if (value is string) return "String";
            if (value is List<object>) return "Array";
            if (value is TaleDict) return "Dictionary";
            return "Object";
        }

        /// <summary>GDScript bool(): false for null, zero, empty text and empty containers.</summary>
        public static bool Truthy(object value)
        {
            if (value == null) return false;
            if (value is bool b) return b;
            if (value is long l) return l != 0;
            if (value is double d) return d != 0.0;
            if (value is string s) return s.Length > 0;
            if (value is List<object> list) return list.Count > 0;
            if (value is TaleDict dict) return dict.Count > 0;
            return true;
        }

        /// <summary>GDScript str(): null prints as "&lt;null&gt;", and text inside containers is quoted.</summary>
        public static string Str(object value)
        {
            return Stringify(value, false);
        }

        private static string Stringify(object value, bool nested)
        {
            if (value == null) return "<null>";
            if (value is string s) return nested ? "\"" + s + "\"" : s;
            if (value is bool b) return b ? "true" : "false";
            if (value is long l) return l.ToString(CultureInfo.InvariantCulture);
            if (value is double d) return FloatToString(d);
            if (value is List<object> list)
            {
                var parts = new List<string>();
                foreach (object item in list) parts.Add(Stringify(item, true));
                return "[" + string.Join(", ", parts) + "]";
            }
            if (value is TaleDict dict)
            {
                if (dict.Count == 0) return "{ }";
                var parts = new List<string>();
                foreach (object key in dict.Keys)
                    parts.Add(Stringify(key, true) + ": " + Stringify(dict[key], true));
                return "{ " + string.Join(", ", parts) + " }";
            }
            return "<" + TypeName(value) + ">";
        }

        /// <summary>
        /// Godot's String.num(): 14 decimals for numbers up to 10 and fewer for
        /// larger ones, trailing zeros removed but one kept after the period.
        /// </summary>
        public static string FloatToString(double d)
        {
            if (double.IsNaN(d)) return "nan";
            if (double.IsPositiveInfinity(d)) return "inf";
            if (double.IsNegativeInfinity(d)) return "-inf";
            int decimals = 14;
            double abs = Math.Abs(d);
            if (abs > 10) decimals -= (int)Math.Floor(Math.Log10(abs));
            if (decimals > 16) decimals = 16;
            if (decimals < 0) decimals = 0;
            string text = d.ToString("F" + decimals.ToString(CultureInfo.InvariantCulture), CultureInfo.InvariantCulture);
            if (text.IndexOf('.') < 0) return text;
            int end = text.Length;
            while (end > 0 && text[end - 1] == '0') end--;
            if (text[end - 1] == '.') end++;
            return text.Substring(0, end);
        }

        /// <summary>Equality that never fails on mismatched types. Numbers compare by value.</summary>
        public static bool Equal(object a, object b)
        {
            bool an = a is long || a is double;
            bool bn = b is long || b is double;
            if (an && bn)
            {
                if (a is long x && b is long y) return x == y;
                return ToDouble(a) == ToDouble(b);
            }
            if (a == null || b == null) return a == null && b == null;
            if (a is string s && b is string t) return s == t;
            if (a.GetType() != b.GetType()) return false;
            if (a is bool p) return p == (bool)b;
            if (a is List<object> la)
            {
                var lb = (List<object>)b;
                if (la.Count != lb.Count) return false;
                for (int i = 0; i < la.Count; i++)
                    if (!Equal(la[i], lb[i])) return false;
                return true;
            }
            if (a is TaleDict da)
            {
                var db = (TaleDict)b;
                if (da.Count != db.Count) return false;
                foreach (object key in da.Keys)
                {
                    object other;
                    if (!db.TryGetValue(key, out other) || !Equal(da[key], other)) return false;
                }
                return true;
            }
            return ReferenceEquals(a, b) || a.Equals(b);
        }

        public static double ToDouble(object value)
        {
            if (value is long l) return l;
            if (value is double d) return d;
            throw new GdOpException();
        }

        public static long ToLong(object value)
        {
            if (value is long l) return l;
            if (value is double d) return (long)d;
            if (value is bool b) return b ? 1 : 0;
            throw new GdOpException();
        }

        public static bool IsNumber(object value)
        {
            return value is long || value is double;
        }

        /// <summary>Applies &lt;, &gt;, &lt;=, or &gt;= with GDScript rules. Throws <see cref="GdOpException"/> for kinds that do not compare.</summary>
        public static bool Relation(string op, object a, object b)
        {
            if (a is long x && b is long y)
            {
                switch (op)
                {
                    case "<": return x < y;
                    case ">": return x > y;
                    case "<=": return x <= y;
                    default: return x >= y;
                }
            }
            if (IsNumber(a) && IsNumber(b))
            {
                double p = ToDouble(a), q = ToDouble(b);
                switch (op)
                {
                    case "<": return p < q;
                    case ">": return p > q;
                    case "<=": return p <= q;
                    default: return p >= q;
                }
            }
            int c;
            if (a is string s && b is string t) c = string.CompareOrdinal(s, t);
            else if (a is bool u && b is bool v) c = (u ? 1 : 0) - (v ? 1 : 0);
            else if (a is List<object> la && b is List<object> lb) c = CompareLists(la, lb);
            else throw new GdOpException();
            switch (op)
            {
                case "<": return c < 0;
                case ">": return c > 0;
                case "<=": return c <= 0;
                default: return c >= 0;
            }
        }

        private static int CompareLists(List<object> a, List<object> b)
        {
            int n = Math.Min(a.Count, b.Count);
            for (int i = 0; i < n; i++)
            {
                if (Equal(a[i], b[i])) continue;
                return Relation("<", a[i], b[i]) ? -1 : 1;
            }
            return a.Count.CompareTo(b.Count);
        }

        /// <summary>Applies an arithmetic, bit, or comparison operator (not ==, !=, in, and, or).</summary>
        public static object Binary(string op, object a, object b)
        {
            switch (op)
            {
                case "<":
                case ">":
                case "<=":
                case ">=":
                    return Relation(op, a, b);
                case "+":
                    if (a is long && b is long) return unchecked((long)a + (long)b);
                    if (IsNumber(a) && IsNumber(b)) return ToDouble(a) + ToDouble(b);
                    if (a is string s1 && b is string s2) return s1 + s2;
                    if (a is List<object> l1 && b is List<object> l2)
                    {
                        var joined = new List<object>(l1);
                        joined.AddRange(l2);
                        return joined;
                    }
                    break;
                case "-":
                    if (a is long && b is long) return unchecked((long)a - (long)b);
                    if (IsNumber(a) && IsNumber(b)) return ToDouble(a) - ToDouble(b);
                    break;
                case "*":
                    if (a is long && b is long) return unchecked((long)a * (long)b);
                    if (IsNumber(a) && IsNumber(b)) return ToDouble(a) * ToDouble(b);
                    if (a is string s3 && b is long n) return GdFormat.Repeat(s3, (int)Math.Min(n, int.MaxValue));
                    break;
                case "/":
                    if (a is long && b is long)
                    {
                        long y = (long)b;
                        if (y == 0) throw new GdOpException();
                        return y == -1 ? unchecked(-(long)a) : (long)a / y;
                    }
                    if (IsNumber(a) && IsNumber(b)) return ToDouble(a) / ToDouble(b);
                    break;
                case "%":
                    if (a is long && b is long)
                    {
                        long y = (long)b;
                        if (y == 0) throw new GdOpException();
                        return y == -1 ? 0L : (long)a % y;
                    }
                    if (a is string format) return Format(format, b);
                    break;
                case "**":
                    if (a is long && b is long) return (long)Math.Pow((long)a, (long)b);
                    if (IsNumber(a) && IsNumber(b)) return Math.Pow(ToDouble(a), ToDouble(b));
                    break;
                case "<<":
                    if (a is long && b is long) return (long)a << (int)(long)b;
                    break;
                case ">>":
                    if (a is long && b is long) return (long)a >> (int)(long)b;
                    break;
                case "&":
                    if (a is long && b is long) return (long)a & (long)b;
                    break;
                case "|":
                    if (a is long && b is long) return (long)a | (long)b;
                    break;
                case "^":
                    if (a is long && b is long) return (long)a ^ (long)b;
                    break;
            }
            throw new GdOpException();
        }

        /// <summary>The "text %s" operator with %s, %d, and %% placeholders.</summary>
        private static string Format(string format, object arguments)
        {
            var values = arguments as List<object> ?? new List<object> { arguments };
            var sb = new StringBuilder();
            int next = 0;
            for (int i = 0; i < format.Length; i++)
            {
                char c = format[i];
                if (c != '%' || i + 1 >= format.Length)
                {
                    sb.Append(c);
                    continue;
                }
                char code = format[++i];
                if (code == '%')
                {
                    sb.Append('%');
                    continue;
                }
                if (code != 's' && code != 'd') throw new GdOpException();
                if (next >= values.Count) throw new GdOpException();
                object value = values[next++];
                sb.Append(code == 'd' ? ToLong(value).ToString(CultureInfo.InvariantCulture) : Str(value));
            }
            if (next < values.Count) throw new GdOpException();
            return sb.ToString();
        }

        /// <summary>True when item is in container (Array element, Dictionary key, or substring).</summary>
        public static bool Contains(object container, object item)
        {
            if (container is List<object> list)
            {
                foreach (object element in list)
                    if (Equal(element, item)) return true;
                return false;
            }
            if (container is TaleDict dict) return dict.Has(item);
            if (container is string text)
            {
                if (!(item is string part)) throw new GdOpException();
                return text.Contains(part);
            }
            throw new GdOpException();
        }

        /// <summary>Reads container[key] for an Array, Dictionary, or String.</summary>
        public static object Index(object container, object key)
        {
            if (container is List<object> list)
            {
                long i = IndexValue(key);
                if (i < 0) i += list.Count;
                if (i < 0 || i >= list.Count) throw new GdOpException();
                return list[(int)i];
            }
            if (container is TaleDict dict)
            {
                object value;
                if (!dict.TryGetValue(key, out value)) throw new GdOpException();
                return value;
            }
            if (container is string text)
            {
                long i = IndexValue(key);
                if (i < 0) i += text.Length;
                if (i < 0 || i >= text.Length) throw new GdOpException();
                return text[(int)i].ToString();
            }
            throw new GdOpException();
        }

        private static long IndexValue(object key)
        {
            if (key is long l) return l;
            if (key is double d) return (long)d;
            throw new GdOpException();
        }

        /// <summary>The items a for loop visits: Array items, Dictionary keys, characters, or 0 up to a count.</summary>
        public static List<object> ToItems(object value)
        {
            if (value is List<object> list) return new List<object>(list);
            if (value is TaleDict dict) return dict.Keys;
            if (value is string text)
            {
                var characters = new List<object>();
                for (int i = 0; i < text.Length; i++)
                {
                    if (char.IsHighSurrogate(text[i]) && i + 1 < text.Length)
                    {
                        characters.Add(text.Substring(i, 2));
                        i++;
                    }
                    else
                    {
                        characters.Add(text[i].ToString());
                    }
                }
                return characters;
            }
            if (value is long count)
            {
                var items = new List<object>();
                for (long i = 0; i < count; i++) items.Add(i);
                return items;
            }
            throw new GdOpException();
        }
    }
}
