using System;
using System.Collections.Generic;
using System.Globalization;
using TaleScript;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Gives tales the value types of Unity: Vector2, Vector2i, Vector3, Rect2, and Color,
    /// their constants such as Color.RED, and the stage positions LEFT, CENTER, and RIGHT.
    /// <see cref="Story"/> installs these on its director.
    /// </summary>
    public static class TaleValues
    {
        /// <summary>Sets the value hooks and the stage position constants on a director.</summary>
        public static void Install(TaleDirector director)
        {
            director.TypeConstants = TryGetConstant;
            director.ValueConstructor = Construct;
            SetStagePositions(director, 0.25f, 0.5f, 0.75f);
        }

        /// <summary>Sets LEFT, CENTER, and RIGHT as stage positions, given as fractions of the screen width.</summary>
        public static void SetStagePositions(TaleDirector director, float left, float center, float right)
        {
            director.SetConstant("LEFT", new Vector2(left, 0f));
            director.SetConstant("CENTER", new Vector2(center, 0f));
            director.SetConstant("RIGHT", new Vector2(right, 0f));
        }

        /// <summary>Constants of value types, such as Color.RED or Vector2.ZERO.</summary>
        public static bool TryGetConstant(string typeName, string constant, out object value)
        {
            value = null;
            if (typeName == "Color")
            {
                switch (constant)
                {
                    case "WHITE": value = Color.white; return true;
                    case "BLACK": value = Color.black; return true;
                    case "RED": value = Color.red; return true;
                    case "GREEN": value = Color.green; return true;
                    case "BLUE": value = Color.blue; return true;
                    case "YELLOW": value = Color.yellow; return true;
                    case "CYAN": value = Color.cyan; return true;
                    case "MAGENTA": value = Color.magenta; return true;
                    case "GRAY": value = Color.gray; return true;
                    case "ORANGE": value = new Color(1f, 0.647f, 0f, 1f); return true;
                    case "PURPLE": value = new Color(0.627f, 0.125f, 0.941f, 1f); return true;
                    case "TRANSPARENT": value = new Color(1f, 1f, 1f, 0f); return true;
                }
            }
            else if (typeName == "Vector2")
            {
                switch (constant)
                {
                    case "ZERO": value = Vector2.zero; return true;
                    case "ONE": value = Vector2.one; return true;
                    case "LEFT": value = Vector2.left; return true;
                    case "RIGHT": value = Vector2.right; return true;
                    case "UP": value = new Vector2(0f, -1f); return true;
                    case "DOWN": value = new Vector2(0f, 1f); return true;
                }
            }
            else if (typeName == "Vector3")
            {
                switch (constant)
                {
                    case "ZERO": value = Vector3.zero; return true;
                    case "ONE": value = Vector3.one; return true;
                }
            }
            return false;
        }

        /// <summary>Builds a value type from the arguments of a call such as <c>Vector2(0.5, 0.2)</c>. Throws when the arguments do not fit.</summary>
        public static object Construct(string typeName, List<object> args)
        {
            switch (typeName)
            {
                case "Vector2":
                    if (args.Count == 2) return new Vector2(F(args[0]), F(args[1]));
                    break;
                case "Vector2i":
                    if (args.Count == 2) return new Vector2Int((int)GdValue.ToLong(args[0]), (int)GdValue.ToLong(args[1]));
                    break;
                case "Vector3":
                    if (args.Count == 3) return new Vector3(F(args[0]), F(args[1]), F(args[2]));
                    break;
                case "Rect2":
                    if (args.Count == 4) return new Rect(F(args[0]), F(args[1]), F(args[2]), F(args[3]));
                    break;
                case "Color":
                    if (args.Count == 1 && args[0] is string)
                    {
                        Color parsed;
                        string text = (string)args[0];
                        if (!text.StartsWith("#", StringComparison.Ordinal) && text.Length > 0 && Uri.IsHexDigit(text[0]) && text.Length >= 6)
                            text = "#" + text;
                        if (ColorUtility.TryParseHtmlString(text, out parsed)) return parsed;
                    }
                    else if (args.Count == 3)
                    {
                        return new Color(F(args[0]), F(args[1]), F(args[2]), 1f);
                    }
                    else if (args.Count == 4)
                    {
                        return new Color(F(args[0]), F(args[1]), F(args[2]), F(args[3]));
                    }
                    break;
            }
            throw new ArgumentException("Wrong arguments for " + typeName + "().");
        }

        private static float F(object value)
        {
            if (!GdValue.IsNumber(value)) throw new ArgumentException("A number was expected.");
            return (float)GdValue.ToDouble(value);
        }

        /// <summary>Reads a value as a number, or returns the fallback when it is not one.</summary>
        public static float ToFloat(object value, float fallback)
        {
            return GdValue.IsNumber(value) ? (float)GdValue.ToDouble(value) : fallback;
        }

        /// <summary>Reads a value as text, or returns the fallback for null.</summary>
        public static string ToText(object value, string fallback = "")
        {
            return value == null ? fallback : GdValue.Str(value);
        }

        /// <summary>Reads a stage position (a Vector2) or returns the fallback.</summary>
        public static Vector2 ToPosition(object value, Vector2 fallback)
        {
            if (value is Vector2) return (Vector2)value;
            if (value is Vector2Int)
            {
                var whole = (Vector2Int)value;
                return new Vector2(whole.x, whole.y);
            }
            return fallback;
        }

        /// <summary>Formats a number for messages, always with a period.</summary>
        public static string Format(float value)
        {
            return value.ToString("0.###", CultureInfo.InvariantCulture);
        }
    }
}
