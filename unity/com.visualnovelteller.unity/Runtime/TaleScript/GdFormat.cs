using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    /// <summary>
    /// Helpers that reproduce GDScript string and number behavior, so dumps and
    /// messages match the reference implementation character for character.
    /// </summary>
    public static class GdFormat
    {
        /// <summary>GDScript str() for the value kinds a tale can hold.</summary>
        public static string Str(object value)
        {
            if (value == null) return "null";
            if (value is string s) return s;
            if (value is bool b) return b ? "true" : "false";
            if (value is double d) return FloatToString(d);
            if (value is float f) return FloatToString(f);
            if (value is long l) return l.ToString(CultureInfo.InvariantCulture);
            if (value is int i) return i.ToString(CultureInfo.InvariantCulture);
            return Convert.ToString(value, CultureInfo.InvariantCulture);
        }

        /// <summary>GDScript str(float): shortest round trip digits, "1" for 1.0, "inf", "nan".</summary>
        public static string FloatToString(double d)
        {
            if (double.IsNaN(d)) return "nan";
            if (double.IsPositiveInfinity(d)) return "inf";
            if (double.IsNegativeInfinity(d)) return "-inf";
            string r = d.ToString("R", CultureInfo.InvariantCulture);
            int e = r.IndexOf('E');
            if (e < 0) return r;
            string mantissa = r.Substring(0, e);
            string exp = r.Substring(e + 1);
            char sign = '+';
            if (exp[0] == '+' || exp[0] == '-')
            {
                sign = exp[0];
                exp = exp.Substring(1);
            }
            if (exp.Length < 2) exp = "0" + exp;
            return mantissa + "e" + sign + exp;
        }

        /// <summary>GDScript String.c_escape().</summary>
        public static string CEscape(string text)
        {
            var sb = new StringBuilder(text.Length + 8);
            foreach (char c in text)
            {
                switch (c)
                {
                    case '\\': sb.Append("\\\\"); break;
                    case '\a': sb.Append("\\a"); break;
                    case '\b': sb.Append("\\b"); break;
                    case '\f': sb.Append("\\f"); break;
                    case '\n': sb.Append("\\n"); break;
                    case '\r': sb.Append("\\r"); break;
                    case '\t': sb.Append("\\t"); break;
                    case '\v': sb.Append("\\v"); break;
                    case '\'': sb.Append("\\'"); break;
                    case '"': sb.Append("\\\""); break;
                    default: sb.Append(c); break;
                }
            }
            return sb.ToString();
        }

        /// <summary>GDScript String.substr(from, len), which clamps instead of throwing.</summary>
        public static string Substr(string s, int from, int len = int.MaxValue)
        {
            if (from < 0) from = 0;
            if (from >= s.Length || len <= 0) return "";
            if (len > s.Length - from) len = s.Length - from;
            return s.Substring(from, len);
        }

        public static string Repeat(string s, int count)
        {
            if (count <= 0) return "";
            var sb = new StringBuilder(s.Length * count);
            for (int i = 0; i < count; i++) sb.Append(s);
            return sb.ToString();
        }

        private static readonly char[] Whitespace = { ' ', '\t', '\n', '\r', '\f', '\v' };

        /// <summary>GDScript String.strip_edges().</summary>
        public static string StripEdges(string s)
        {
            return s.Trim(Whitespace);
        }

        /// <summary>The GDScript enum key for a C# enum member: MatchBranch becomes MATCH_BRANCH.</summary>
        public static string EnumKey(object enumValue)
        {
            string name = enumValue.ToString();
            var sb = new StringBuilder();
            for (int i = 0; i < name.Length; i++)
            {
                char c = name[i];
                if (i > 0 && char.IsUpper(c)) sb.Append('_');
                sb.Append(char.ToUpperInvariant(c));
            }
            return sb.ToString();
        }

        /// <summary>GDScript String.to_int(): reads a leading integer, clamps on overflow.</summary>
        public static long ToInt(string s)
        {
            int i = 0;
            while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
            bool negative = false;
            while (i < s.Length && (s[i] == '-' || s[i] == '+'))
            {
                if (s[i] == '-') negative = !negative;
                i++;
            }
            ulong acc = 0;
            bool overflow = false;
            for (; i < s.Length && s[i] >= '0' && s[i] <= '9'; i++)
            {
                int digit = s[i] - '0';
                if (acc > (ulong.MaxValue - (ulong)digit) / 10UL)
                {
                    overflow = true;
                    break;
                }
                acc = acc * 10UL + (ulong)digit;
            }
            if (negative)
            {
                if (overflow || acc > 9223372036854775808UL) return long.MinValue;
                return unchecked((long)(0UL - acc));
            }
            if (overflow || acc > long.MaxValue) return long.MaxValue;
            return (long)acc;
        }

        /// <summary>GDScript String.hex_to_int() for digits without a prefix. Wraps on overflow.</summary>
        public static long HexToInt(string digits)
        {
            ulong acc = 0;
            foreach (char c in digits)
            {
                int v;
                if (c >= '0' && c <= '9') v = c - '0';
                else if (c >= 'a' && c <= 'f') v = c - 'a' + 10;
                else if (c >= 'A' && c <= 'F') v = c - 'A' + 10;
                else break;
                acc = unchecked(acc * 16UL + (ulong)v);
            }
            return unchecked((long)acc);
        }

        /// <summary>GDScript String.bin_to_int() for digits without a prefix. Wraps on overflow.</summary>
        public static long BinToInt(string digits)
        {
            ulong acc = 0;
            foreach (char c in digits)
            {
                if (c != '0' && c != '1') break;
                acc = unchecked(acc * 2UL + (ulong)(c - '0'));
            }
            return unchecked((long)acc);
        }

        public static bool IsValidHexNumber(string s)
        {
            if (s.Length == 0) return false;
            foreach (char c in s)
            {
                bool ok = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
                if (!ok) return false;
            }
            return true;
        }

        /// <summary>GDScript String.is_valid_float().</summary>
        public static bool IsValidFloat(string s)
        {
            int len = s.Length;
            if (len == 0) return false;
            int from = 0;
            if (s[0] == '+' || s[0] == '-') from++;
            bool exponentFound = false, periodFound = false, signFound = false;
            bool exponentValuesFound = false, numbersFound = false;
            for (int i = from; i < len; i++)
            {
                char c = s[i];
                if (c >= '0' && c <= '9')
                {
                    if (exponentFound) exponentValuesFound = true;
                    else numbersFound = true;
                }
                else if (numbersFound && !exponentFound && (c == 'e' || c == 'E')) exponentFound = true;
                else if (!periodFound && !exponentFound && c == '.') periodFound = true;
                else if ((c == '-' || c == '+') && exponentFound && !exponentValuesFound && !signFound) signFound = true;
                else return false;
            }
            return numbersFound;
        }

        /// <summary>GDScript String.to_float(): reads the longest numeric prefix, 0.0 when there is none.</summary>
        public static double ToFloat(string s)
        {
            int i = 0;
            while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
            int start = i;
            if (i < s.Length && (s[i] == '+' || s[i] == '-')) i++;
            int digitsStart = i;
            while (i < s.Length && s[i] >= '0' && s[i] <= '9') i++;
            int intDigits = i - digitsStart;
            int fracDigits = 0;
            if (i < s.Length && s[i] == '.')
            {
                int j = i + 1;
                while (j < s.Length && s[j] >= '0' && s[j] <= '9') j++;
                fracDigits = j - i - 1;
                if (intDigits > 0 || fracDigits > 0) i = j;
            }
            if (intDigits == 0 && fracDigits == 0) return 0.0;
            if (i < s.Length && (s[i] == 'e' || s[i] == 'E'))
            {
                int j = i + 1;
                if (j < s.Length && (s[j] == '+' || s[j] == '-')) j++;
                int expStart = j;
                while (j < s.Length && s[j] >= '0' && s[j] <= '9') j++;
                if (j > expStart) i = j;
            }
            double result;
            if (double.TryParse(s.Substring(start, i - start), NumberStyles.Float, CultureInfo.InvariantCulture, out result))
                return result;
            return 0.0;
        }
    }
}
