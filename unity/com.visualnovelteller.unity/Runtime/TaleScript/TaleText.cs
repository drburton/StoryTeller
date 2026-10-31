using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace TaleScript
{
    /// <summary>Helpers for the text of dialogue, narration, and choice options.</summary>
    public static class TaleText
    {
        /// <summary>A [act=...] or [sound=...] tag inside text.</summary>
        public class TagPart
        {
            /// <summary>"act" or "sound".</summary>
            public string Tag;
            public TaleExpr Expr;
        }

        /// <summary>Result of <see cref="SplitInterpolation"/>.</summary>
        public class SplitResult
        {
            /// <summary>Strings (literal text), TaleExpr (values to insert), and TagPart items.</summary>
            public List<object> Parts = new List<object>();
            public List<string> Errors = new List<string>();
        }

        private class TagValue
        {
            public string Error = "";
            public TaleExpr Expr;
        }

        /// <summary>
        /// Splits text into literal pieces, {expression} pieces, and tags that run
        /// something at a point in the text. "{{" and "}}" stand for literal braces.
        /// [sound=bell] becomes the call sound("bell").
        /// </summary>
        public static SplitResult SplitInterpolation(string text)
        {
            var parts = new List<object>();
            var errors = new List<string>();
            var literal = new StringBuilder();
            int i = 0;
            while (i < text.Length)
            {
                char c = text[i];
                if (c == '{' && GdFormat.Substr(text, i, 2) == "{{")
                {
                    literal.Append('{');
                    i += 2;
                }
                else if (c == '}' && GdFormat.Substr(text, i, 2) == "}}")
                {
                    literal.Append('}');
                    i += 2;
                }
                else if (c == '}')
                {
                    errors.Add("Unmatched '}' in text. Write '}}' for a literal brace.");
                    literal.Append(c);
                    i += 1;
                }
                else if (c == '{')
                {
                    int end = FindClosingBrace(text, i);
                    if (end == -1)
                    {
                        errors.Add("Unclosed '{' in text. Write '{{' for a literal brace.");
                        literal.Append(GdFormat.Substr(text, i));
                        break;
                    }
                    if (literal.Length > 0)
                    {
                        parts.Add(literal.ToString());
                        literal.Clear();
                    }
                    string source = GdFormat.Substr(text, i + 1, end - i - 1);
                    var parsed = TaleParser.ParseExpression(source);
                    if (parsed.Error.Length > 0)
                        errors.Add("In '{" + source + "}': " + parsed.Error);
                    else
                        parts.Add(parsed.Expr);
                    i = end + 1;
                }
                else if (c == '[' && (GdFormat.Substr(text, i, 5) == "[act=" || GdFormat.Substr(text, i, 7) == "[sound="))
                {
                    string tag = GdFormat.Substr(text, i, 5) == "[act=" ? "act" : "sound";
                    int end = FindClosingBracket(text, i);
                    if (end == -1)
                    {
                        errors.Add("Unclosed '[" + tag + "=' tag in text.");
                        literal.Append(GdFormat.Substr(text, i));
                        break;
                    }
                    string value = GdFormat.StripEdges(GdFormat.Substr(text, i + tag.Length + 2, end - i - tag.Length - 2));
                    var parsed = ParseTagValue(tag, value);
                    if (parsed.Error.Length > 0)
                    {
                        errors.Add("In '[" + tag + "=" + value + "]': " + parsed.Error);
                    }
                    else
                    {
                        if (literal.Length > 0)
                        {
                            parts.Add(literal.ToString());
                            literal.Clear();
                        }
                        parts.Add(new TagPart { Tag = tag, Expr = parsed.Expr });
                    }
                    i = end + 1;
                }
                else
                {
                    literal.Append(c);
                    i += 1;
                }
            }
            if (literal.Length > 0)
                parts.Add(literal.ToString());
            errors.AddRange(CheckTypingTags(text));
            return new SplitResult { Parts = parts, Errors = errors };
        }

        /// <summary>
        /// Expands named text styles: [name]...[/name] becomes the BBCode that
        /// styles gives for name, closed with the matching closing tags.
        /// </summary>
        public static string ExpandStyles(string text, IDictionary<string, string> styles)
        {
            if (styles.Count == 0 || !text.Contains("["))
                return text;
            foreach (var pair in styles)
            {
                text = text.Replace("[" + pair.Key + "]", pair.Value).Replace("[/" + pair.Key + "]", ClosingTags(pair.Value));
            }
            return text;
        }

        /// <summary>
        /// Closing tags for the BBCode tags that bbcode opens, innermost first:
        /// "[i][color=red]" gives "[/color][/i]".
        /// </summary>
        public static string ClosingTags(string bbcode)
        {
            var names = new List<string>();
            foreach (Match found in Regex.Matches(bbcode, "\\[([A-Za-z_]+)[^\\]]*\\]"))
                names.Insert(0, "[/" + found.Groups[1].Value + "]");
            return string.Join("", names);
        }

        /// <summary>
        /// Problems with the typing tags in text: [pause=...] and [speed=...] values
        /// that are not numbers, and closing tags without an opening one.
        /// </summary>
        public static List<string> CheckTypingTags(string text)
        {
            var errors = new List<string>();
            var regex = new Regex("\\[(/?)(pause|speed|instant)(?:=([^\\]]*))?\\]");
            int openSpeed = 0;
            int openInstant = 0;
            foreach (Match found in regex.Matches(text))
            {
                bool closing = found.Groups[1].Value == "/";
                string tag = found.Groups[2].Value;
                string value = found.Groups[3].Value;
                bool hasValue = found.Groups[3].Success;
                // A value from {expression} is only known while the story plays.
                bool computed = value.Contains("{");
                if (closing)
                {
                    if (tag == "pause" || hasValue)
                    {
                        errors.Add("'" + found.Value + "' is not a closing tag StoryTeller knows.");
                    }
                    else if ((tag == "speed" ? openSpeed : openInstant) == 0)
                    {
                        errors.Add("[/" + tag + "] has no [" + tag + "] before it.");
                    }
                    else if (tag == "speed")
                    {
                        openSpeed -= 1;
                    }
                    else
                    {
                        openInstant -= 1;
                    }
                    continue;
                }
                switch (tag)
                {
                    case "pause":
                        if (hasValue && !computed && !(GdFormat.IsValidFloat(value) && GdFormat.ToFloat(value) >= 0.0))
                            errors.Add("[pause=" + value + "] needs a number of seconds, e.g. [pause=0.5].");
                        break;
                    case "speed":
                        if (!computed && !(hasValue && GdFormat.IsValidFloat(value) && GdFormat.ToFloat(value) > 0.0))
                            errors.Add("[speed=" + value + "] needs a number above 0, e.g. [speed=2] types twice as fast.");
                        openSpeed += 1;
                        break;
                    case "instant":
                        if (hasValue)
                            errors.Add("[instant] takes no value.");
                        openInstant += 1;
                        break;
                }
            }
            return errors;
        }

        private static TagValue ParseTagValue(string tag, string value)
        {
            if (value.Length == 0)
            {
                string example = tag == "act" ? "[act=shake(0.2)]" : "[sound=bell]";
                return new TagValue { Error = "The tag needs a value, e.g. " + example + "." };
            }
            if (tag == "act")
            {
                var result = TaleParser.ParseExpression(value);
                return new TagValue { Error = result.Error, Expr = result.Expr };
            }
            string soundName = value;
            if (soundName.Length >= 2 && (soundName[0] == '"' || soundName[0] == '\'') && soundName[soundName.Length - 1] == soundName[0])
                soundName = soundName.Substring(1, soundName.Length - 2);
            if (soundName.Contains("{") || soundName.Contains("\"") || soundName.Contains("'"))
                return new TagValue { Error = "Write a sound name, or pick one with an expression in [act=sound(...)]." };
            var sound = TaleParser.ParseExpression("sound(\"" + GdFormat.CEscape(soundName) + "\")");
            return new TagValue { Error = sound.Error, Expr = sound.Expr };
        }

        /// <summary>
        /// Index of the ']' that closes the '[' at open, skipping nested
        /// brackets and quoted strings, or -1.
        /// </summary>
        private static int FindClosingBracket(string text, int open)
        {
            return FindClosing(text, open, '[', ']');
        }

        /// <summary>
        /// Index of the '}' that closes the '{' at open, skipping nested
        /// braces and quoted strings, or -1.
        /// </summary>
        private static int FindClosingBrace(string text, int open)
        {
            return FindClosing(text, open, '{', '}');
        }

        private static int FindClosing(string text, int open, char opener, char closer)
        {
            int depth = 0;
            char quote = '\0';
            int i = open;
            while (i < text.Length)
            {
                char c = text[i];
                if (quote != '\0')
                {
                    if (c == '\\')
                        i += 1;
                    else if (c == quote)
                        quote = '\0';
                }
                else if (c == '"' || c == '\'')
                {
                    quote = c;
                }
                else if (c == opener)
                {
                    depth += 1;
                }
                else if (c == closer)
                {
                    depth -= 1;
                    if (depth == 0)
                        return i;
                }
                i += 1;
            }
            return -1;
        }
    }
}
