using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    /// <summary>
    /// Reproduces Godot's JSON.stringify(): compact output, integers without a
    /// period, floats like "2.0", and dictionary keys in sorted order.
    /// </summary>
    public static class GdJson
    {
        public static string Stringify(object value)
        {
            var sb = new StringBuilder();
            Write(sb, value);
            return sb.ToString();
        }

        private static void Write(StringBuilder sb, object value)
        {
            if (value == null) sb.Append("null");
            else if (value is bool b) sb.Append(b ? "true" : "false");
            else if (value is long l) sb.Append(l.ToString(CultureInfo.InvariantCulture));
            else if (value is double d) sb.Append(GdValue.FloatToString(d));
            else if (value is string s) Quote(sb, s);
            else if (value is List<object> list)
            {
                sb.Append('[');
                for (int i = 0; i < list.Count; i++)
                {
                    if (i > 0) sb.Append(',');
                    Write(sb, list[i]);
                }
                sb.Append(']');
            }
            else if (value is TaleDict dict)
            {
                var keys = dict.Keys;
                var names = new List<KeyValuePair<string, object>>();
                foreach (object key in keys) names.Add(new KeyValuePair<string, object>(GdValue.Str(key), dict[key]));
                names.Sort((x, y) => string.CompareOrdinal(x.Key, y.Key));
                sb.Append('{');
                for (int i = 0; i < names.Count; i++)
                {
                    if (i > 0) sb.Append(',');
                    Quote(sb, names[i].Key);
                    sb.Append(':');
                    Write(sb, names[i].Value);
                }
                sb.Append('}');
            }
            else Quote(sb, GdValue.Str(value));
        }

        private static void Quote(StringBuilder sb, string text)
        {
            sb.Append('"');
            foreach (char c in text)
            {
                switch (c)
                {
                    case '"': sb.Append("\\\""); break;
                    case '\\': sb.Append("\\\\"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    default:
                        if (c < 0x20) sb.Append("\\u").Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                        else sb.Append(c);
                        break;
                }
            }
            sb.Append('"');
        }
    }
}
