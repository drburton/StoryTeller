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
            else if (value is int n) sb.Append(n.ToString(CultureInfo.InvariantCulture));
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
            else if (value is OrderedMap<object> map)
            {
                var names = new List<string>(map.Keys);
                names.Sort(string.CompareOrdinal);
                sb.Append('{');
                for (int i = 0; i < names.Count; i++)
                {
                    if (i > 0) sb.Append(',');
                    Quote(sb, names[i]);
                    sb.Append(':');
                    Write(sb, map[names[i]]);
                }
                sb.Append('}');
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

        /// <summary>
        /// Reads JSON text into plain data: <see cref="OrderedMap{TValue}"/> of object for objects,
        /// <c>List&lt;object&gt;</c> for arrays, string, long for numbers without a fraction or
        /// exponent, double for the rest, bool, and null. Throws <see cref="FormatException"/> on bad input.
        /// </summary>
        public static object Parse(string text)
        {
            int pos = 0;
            object value = ReadValue(text, ref pos);
            SkipSpace(text, ref pos);
            if (pos != text.Length) throw Bad(pos);
            return value;
        }

        private static FormatException Bad(int pos)
        {
            return new FormatException("Invalid JSON at position " + pos.ToString(CultureInfo.InvariantCulture) + ".");
        }

        private static void SkipSpace(string text, ref int pos)
        {
            while (pos < text.Length && (text[pos] == ' ' || text[pos] == '\t' || text[pos] == '\n' || text[pos] == '\r')) pos++;
        }

        private static object ReadValue(string text, ref int pos)
        {
            SkipSpace(text, ref pos);
            if (pos >= text.Length) throw Bad(pos);
            char c = text[pos];
            if (c == '{')
            {
                pos++;
                var map = new OrderedMap<object>();
                SkipSpace(text, ref pos);
                if (pos < text.Length && text[pos] == '}')
                {
                    pos++;
                    return map;
                }
                while (true)
                {
                    SkipSpace(text, ref pos);
                    if (pos >= text.Length || text[pos] != '"') throw Bad(pos);
                    string key = ReadString(text, ref pos);
                    SkipSpace(text, ref pos);
                    if (pos >= text.Length || text[pos] != ':') throw Bad(pos);
                    pos++;
                    map[key] = ReadValue(text, ref pos);
                    SkipSpace(text, ref pos);
                    if (pos >= text.Length) throw Bad(pos);
                    if (text[pos] == ',')
                    {
                        pos++;
                        continue;
                    }
                    if (text[pos] == '}')
                    {
                        pos++;
                        return map;
                    }
                    throw Bad(pos);
                }
            }
            if (c == '[')
            {
                pos++;
                var list = new List<object>();
                SkipSpace(text, ref pos);
                if (pos < text.Length && text[pos] == ']')
                {
                    pos++;
                    return list;
                }
                while (true)
                {
                    list.Add(ReadValue(text, ref pos));
                    SkipSpace(text, ref pos);
                    if (pos >= text.Length) throw Bad(pos);
                    if (text[pos] == ',')
                    {
                        pos++;
                        continue;
                    }
                    if (text[pos] == ']')
                    {
                        pos++;
                        return list;
                    }
                    throw Bad(pos);
                }
            }
            if (c == '"') return ReadString(text, ref pos);
            if (Literal(text, ref pos, "true")) return true;
            if (Literal(text, ref pos, "false")) return false;
            if (Literal(text, ref pos, "null")) return null;
            return ReadNumber(text, ref pos);
        }

        private static bool Literal(string text, ref int pos, string word)
        {
            if (string.CompareOrdinal(text, pos, word, 0, word.Length) != 0) return false;
            pos += word.Length;
            return true;
        }

        private static object ReadNumber(string text, ref int pos)
        {
            int start = pos;
            bool isFloat = false;
            if (pos < text.Length && text[pos] == '-') pos++;
            while (pos < text.Length)
            {
                char c = text[pos];
                if (c >= '0' && c <= '9') pos++;
                else if (c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-')
                {
                    isFloat = true;
                    pos++;
                }
                else break;
            }
            string token = text.Substring(start, pos - start);
            if (token.Length == 0 || token == "-") throw Bad(start);
            if (!isFloat)
            {
                long l;
                if (long.TryParse(token, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out l)) return l;
            }
            double d;
            if (!double.TryParse(token, NumberStyles.Float, CultureInfo.InvariantCulture, out d)) throw Bad(start);
            return d;
        }

        private static string ReadString(string text, ref int pos)
        {
            pos++;
            var sb = new StringBuilder();
            while (true)
            {
                if (pos >= text.Length) throw Bad(pos);
                char c = text[pos++];
                if (c == '"') return sb.ToString();
                if (c != '\\')
                {
                    sb.Append(c);
                    continue;
                }
                if (pos >= text.Length) throw Bad(pos);
                char e = text[pos++];
                switch (e)
                {
                    case '"': sb.Append('"'); break;
                    case '\\': sb.Append('\\'); break;
                    case '/': sb.Append('/'); break;
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'u':
                    {
                        int code;
                        if (pos + 4 > text.Length
                            || !int.TryParse(text.Substring(pos, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out code))
                            throw Bad(pos);
                        sb.Append((char)code);
                        pos += 4;
                        break;
                    }
                    default: throw Bad(pos);
                }
            }
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
