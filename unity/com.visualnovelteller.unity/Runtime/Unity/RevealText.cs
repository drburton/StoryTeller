using System.Collections.Generic;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace VisualNovelTeller
{
    /// <summary>
    /// A line of dialogue prepared for a typewriter reveal. It reads the BBCode tags of a
    /// tale (b, i, u, s, color, font_size), the typing tags pause, speed, and instant, and
    /// turns the rest into the rich text a UI Toolkit label shows. Other tags, such as
    /// act and sound, are dropped.
    /// </summary>
    public sealed class RevealText
    {
        private struct Piece
        {
            public bool Visible;
            public string Markup;
            public string OpenName;
            public string CloseName;
        }

        private static readonly Regex TagPattern = new Regex(@"\G\[(/?)([A-Za-z_]+)(?:=([^\]]*))?\]", RegexOptions.CultureInvariant);

        private readonly List<Piece> _pieces = new List<Piece>();
        private readonly List<float> _times = new List<float>();

        /// <summary>How many characters the line shows when fully revealed.</summary>
        public int VisibleCount { get { return _times.Count; } }
        /// <summary>Seconds until the last character appears.</summary>
        public float Duration { get; private set; }

        /// <summary>Prepares text. A speed of 0 or less shows everything at once.</summary>
        public static RevealText Parse(string text, float charactersPerSecond)
        {
            var result = new RevealText();
            result.Build(text ?? "", charactersPerSecond);
            return result;
        }

        private void Build(string text, float charactersPerSecond)
        {
            float time = 0f;
            var speeds = new List<float>();
            int instantDepth = 0;
            int i = 0;
            while (i < text.Length)
            {
                char c = text[i];
                if (c == '[')
                {
                    Match found = TagPattern.Match(text, i);
                    if (found.Success && HandleTag(found, speeds, ref instantDepth, ref time))
                    {
                        i += found.Length;
                        continue;
                    }
                }
                string unit;
                if (char.IsHighSurrogate(c) && i + 1 < text.Length)
                {
                    unit = text.Substring(i, 2);
                    i += 2;
                }
                else
                {
                    unit = c == '<' ? "<noparse><</noparse>" : c.ToString();
                    i++;
                }
                _pieces.Add(new Piece { Visible = true, Markup = unit });
                _times.Add(time);
                float speed = charactersPerSecond;
                if (speeds.Count > 0) speed *= speeds[speeds.Count - 1];
                if (instantDepth > 0 || speed <= 0f) continue;
                time += 1f / speed;
            }
            Duration = _times.Count == 0 ? 0f : _times[_times.Count - 1];
        }

        private bool HandleTag(Match found, List<float> speeds, ref int instantDepth, ref float time)
        {
            bool closing = found.Groups[1].Value == "/";
            string name = found.Groups[2].Value;
            string value = found.Groups[3].Success ? found.Groups[3].Value.Replace("\"", "").Replace("<", "") : "";
            switch (name)
            {
                case "b":
                case "i":
                case "u":
                case "s":
                    if (closing) AddClose(name, "</" + name + ">");
                    else AddOpen(name, "<" + name + ">");
                    return true;
                case "color":
                    if (closing) AddClose("color", "</color>");
                    else AddOpen("color", "<color=" + value + ">");
                    return true;
                case "font_size":
                    if (closing) AddClose("size", "</size>");
                    else AddOpen("size", "<size=" + value + ">");
                    return true;
                case "pause":
                    if (!closing)
                    {
                        float seconds;
                        if (float.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out seconds) && seconds > 0f) time += seconds;
                    }
                    return true;
                case "speed":
                    if (closing)
                    {
                        if (speeds.Count > 0) speeds.RemoveAt(speeds.Count - 1);
                    }
                    else
                    {
                        float factor;
                        if (!float.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out factor) || factor <= 0f) factor = 1f;
                        speeds.Add(factor);
                    }
                    return true;
                case "instant":
                    if (closing) { if (instantDepth > 0) instantDepth--; }
                    else instantDepth++;
                    return true;
                case "act":
                case "sound":
                case "center":
                    return true;
            }
            return false;
        }

        private void AddOpen(string name, string markup)
        {
            _pieces.Add(new Piece { Markup = markup, OpenName = name });
        }

        private void AddClose(string name, string markup)
        {
            _pieces.Add(new Piece { Markup = markup, CloseName = name });
        }

        /// <summary>How many characters have appeared after the given seconds.</summary>
        public int CountAt(float seconds)
        {
            int count = 0;
            while (count < _times.Count && _times[count] <= seconds) count++;
            return count;
        }

        /// <summary>The rich text of the first <paramref name="visible"/> characters, with open tags closed.</summary>
        public string Prefix(int visible)
        {
            var text = new StringBuilder();
            var open = new List<string>();
            int shown = 0;
            foreach (var piece in _pieces)
            {
                if (piece.Visible)
                {
                    if (shown >= visible) break;
                    shown++;
                }
                else if (piece.OpenName != null)
                {
                    open.Add(piece.OpenName);
                }
                else if (piece.CloseName != null)
                {
                    int index = open.LastIndexOf(piece.CloseName);
                    if (index < 0) continue;
                    open.RemoveAt(index);
                }
                text.Append(piece.Markup);
            }
            for (int i = open.Count - 1; i >= 0; i--)
                text.Append("</").Append(open[i]).Append('>');
            return text.ToString();
        }
    }
}
