using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    /// <summary>
    /// Splits TaleScript source into tokens.
    /// A NEWLINE token ends every logical line, including blank and comment-only
    /// lines. Line breaks inside brackets, after a backslash, or inside
    /// triple-quoted strings do not end a logical line. Problems are recorded in
    /// <see cref="Diagnostics"/> and produce ERROR tokens; the lexer never stops early.
    /// </summary>
    public class TaleLexer
    {
        public static readonly string[] Keywords =
        {
            "and", "await", "beat", "break", "choose", "const", "continue", "elif",
            "else", "false", "for", "if", "in", "jump", "match", "not", "null", "or",
            "pass", "return", "true", "var", "when", "while",
        };

        /// <summary>Longest operators first, so the first match is the longest one.</summary>
        public static readonly string[] Operators =
        {
            "**=", "<<=", ">>=",
            "**", "==", "!=", "<=", ">=", "&&", "||", "+=", "-=", "*=", "/=", "%=",
            "&=", "|=", "^=", ":=", "->", "<<", ">>",
            "+", "-", "*", "/", "%", "<", ">", "=", "!", "&", "|", "^", "~",
            "(", ")", "[", "]", "{", "}", ",", ":", ".",
        };

        private const string Openers = "([{";
        private const string Closers = ")]}";

        public List<TaleDiagnostic> Diagnostics = new List<TaleDiagnostic>();

        private string _src = "";
        private int _pos;
        private int _line = 1;
        private int _lineStart;
        private readonly List<TaleToken> _brackets = new List<TaleToken>();
        /// <summary>Indentation width of the line where the outermost open bracket started.</summary>
        private int _bracketLineIndent;
        private List<TaleToken> _tokens = new List<TaleToken>();

        /// <summary>Returns the tokens of source, always ending with an END token.</summary>
        public List<TaleToken> Tokenize(string source)
        {
            _src = source;
            _pos = 0;
            _line = 1;
            _lineStart = 0;
            _brackets.Clear();
            _tokens = new List<TaleToken>();
            Diagnostics.Clear();

            int length = _src.Length;
            while (_pos < length)
            {
                char c = _src[_pos];
                if (c == ' ' || c == '\t' || c == '\r')
                {
                    _pos += 1;
                }
                else if (c == '\n')
                {
                    if (_brackets.Count > 0 && NextLineLeavesBrackets())
                        CloseBracketsWithError();
                    if (_brackets.Count == 0)
                        _tokens.Add(new TaleToken(TaleTokenType.Newline, "\n", "\n", _line, Column(_pos)));
                    _pos += 1;
                    NewLine();
                }
                else if (c == '#')
                {
                    Comment();
                }
                else if (c == '\\')
                {
                    Continuation();
                }
                else if (c == '"' || c == '\'')
                {
                    String();
                }
                else if (c == '@')
                {
                    Annotation();
                }
                else if (IsDigit(c) || (c == '.' && IsDigit(CharAt(_pos + 1))))
                {
                    Number();
                }
                else if (IsIdentifierStart(c))
                {
                    Identifier();
                }
                else
                {
                    Operator();
                }
            }

            CloseBracketsWithError();
            _tokens.Add(new TaleToken(TaleTokenType.End, "", null, _line, Column(_pos)));
            return _tokens;
        }

        private void NewLine()
        {
            _line += 1;
            _lineStart = _pos;
        }

        private int Column(int offset)
        {
            return offset - _lineStart + 1;
        }

        /// <summary>The character at offset as a string, or "" past the end.</summary>
        private string CharAt(int offset)
        {
            return offset < _src.Length ? _src[offset].ToString() : "";
        }

        private void Comment()
        {
            int start = _pos;
            while (_pos < _src.Length && _src[_pos] != '\n')
                _pos += 1;
            string text = GdFormat.Substr(_src, start, _pos - start);
            if (text.EndsWith("\r")) text = text.Substring(0, text.Length - 1);
            _tokens.Add(new TaleToken(TaleTokenType.Comment, text, text.Substring(1), _line, Column(start)));
        }

        private void Continuation()
        {
            int next = _pos + 1;
            if (CharAt(next) == "\r")
                next += 1;
            if (CharAt(next) == "\n")
            {
                _pos = next + 1;
                NewLine();
            }
            else
            {
                AddError("\\", "A backslash must be the last character on the line.", _pos);
                _pos += 1;
            }
        }

        private void String()
        {
            int start = _pos;
            int startLine = _line;
            int startColumn = Column(_pos);
            char quote = _src[_pos];
            string quote3 = GdFormat.Repeat(quote.ToString(), 3);
            bool triple = GdFormat.Substr(_src, _pos, 3) == quote3;
            _pos += triple ? 3 : 1;
            var value = new StringBuilder();
            bool closed = false;
            while (_pos < _src.Length)
            {
                char c = _src[_pos];
                if (triple && GdFormat.Substr(_src, _pos, 3) == quote3)
                {
                    _pos += 3;
                    closed = true;
                    break;
                }
                if (!triple && c == quote)
                {
                    _pos += 1;
                    closed = true;
                    break;
                }
                if (c == '\n')
                {
                    if (!triple)
                        break;
                    value.Append(c);
                    _pos += 1;
                    NewLine();
                }
                else if (c == '\\')
                {
                    value.Append(Escape());
                }
                else
                {
                    value.Append(c);
                    _pos += 1;
                }
            }
            string text = GdFormat.Substr(_src, start, _pos - start);
            if (!closed)
            {
                ErrorAt("Unterminated string.", startLine, startColumn);
                _tokens.Add(new TaleToken(TaleTokenType.Error, text, "Unterminated string.", startLine, startColumn));
                return;
            }
            _tokens.Add(new TaleToken(TaleTokenType.String, text, value.ToString(), startLine, startColumn));
        }

        /// <summary>Reads an escape sequence at the current backslash and returns its value.</summary>
        private string Escape()
        {
            int start = _pos;
            string c = CharAt(_pos + 1);
            switch (c)
            {
                case "n": _pos += 2; return "\n";
                case "t": _pos += 2; return "\t";
                case "r": _pos += 2; return "\r";
                case "\\": _pos += 2; return "\\";
                case "\"": _pos += 2; return "\"";
                case "'": _pos += 2; return "'";
            }
            if (c == "u" || c == "U")
            {
                int digits = c == "u" ? 4 : 6;
                string hex = GdFormat.Substr(_src, _pos + 2, digits);
                if (hex.Length == digits && GdFormat.IsValidHexNumber(hex))
                {
                    _pos += 2 + digits;
                    return Chr(GdFormat.HexToInt(hex));
                }
                ErrorAt("Invalid unicode escape.", _line, Column(start));
                _pos += 2;
                return "";
            }
            if (c == "\n" || (c == "\r" && CharAt(_pos + 2) == "\n"))
            {
                // A backslash before a line break joins the lines.
                _pos += c == "\r" ? 3 : 2;
                NewLine();
                return "";
            }
            ErrorAt("Unknown escape sequence '\\" + c + "'.", _line, Column(start));
            _pos += c != "" ? 2 : 1;
            return c;
        }

        private static string Chr(long codePoint)
        {
            if (codePoint < 0 || codePoint > 0x10FFFF || (codePoint >= 0xD800 && codePoint <= 0xDFFF))
                return "";
            return char.ConvertFromUtf32((int)codePoint);
        }

        private void Annotation()
        {
            int start = _pos;
            _pos += 1;
            while (_pos < _src.Length && IsIdentifierChar(_src[_pos]))
                _pos += 1;
            string text = GdFormat.Substr(_src, start, _pos - start);
            if (text.Length == 1)
            {
                AddError(text, "Expected an annotation name after '@'.", start);
                return;
            }
            _tokens.Add(new TaleToken(TaleTokenType.Annotation, text, text.Substring(1), _line, Column(start)));
        }

        private void Number()
        {
            int start = _pos;
            bool isFloat = false;
            string basePrefix = GdFormat.Substr(_src, _pos, 2).ToLowerInvariant();
            if (basePrefix == "0x" || basePrefix == "0b")
            {
                _pos += 2;
                int digitsStart = _pos;
                string valid = basePrefix == "0x" ? "0123456789abcdefABCDEF_" : "01_";
                while (_pos < _src.Length && valid.IndexOf(_src[_pos]) >= 0)
                    _pos += 1;
                string prefixedText = GdFormat.Substr(_src, start, _pos - start);
                string digits = GdFormat.Substr(_src, digitsStart, _pos - digitsStart).Replace("_", "");
                if (digits.Length == 0)
                {
                    AddError(prefixedText, "Expected digits after '" + basePrefix + "'.", start);
                    return;
                }
                long number = basePrefix == "0x" ? GdFormat.HexToInt(digits) : GdFormat.BinToInt(digits);
                _tokens.Add(new TaleToken(TaleTokenType.Int, prefixedText, number, _line, Column(start)));
                return;
            }

            SkipDigits();
            if (CharAt(_pos) == "." && IsDigit(CharAt(_pos + 1)))
            {
                isFloat = true;
                _pos += 1;
                SkipDigits();
            }
            string e = CharAt(_pos);
            if (e == "e" || e == "E")
            {
                string sign = CharAt(_pos + 1);
                int exponentStart = _pos + (sign == "+" || sign == "-" ? 2 : 1);
                if (IsDigit(CharAt(exponentStart)))
                {
                    isFloat = true;
                    _pos = exponentStart;
                    SkipDigits();
                }
            }
            string numberText = GdFormat.Substr(_src, start, _pos - start);
            string clean = numberText.Replace("_", "");
            if (isFloat)
                _tokens.Add(new TaleToken(TaleTokenType.Float, numberText, GdFormat.ToFloat(clean), _line, Column(start)));
            else
                _tokens.Add(new TaleToken(TaleTokenType.Int, numberText, GdFormat.ToInt(clean), _line, Column(start)));
        }

        private void SkipDigits()
        {
            while (_pos < _src.Length && (IsDigit(_src[_pos]) || _src[_pos] == '_'))
                _pos += 1;
        }

        private void Identifier()
        {
            int start = _pos;
            while (_pos < _src.Length && IsIdentifierChar(_src[_pos]))
                _pos += 1;
            string text = GdFormat.Substr(_src, start, _pos - start);
            var type = System.Array.IndexOf(Keywords, text) >= 0 ? TaleTokenType.Keyword : TaleTokenType.Identifier;
            _tokens.Add(new TaleToken(type, text, text, _line, Column(start)));
        }

        private void Operator()
        {
            foreach (string op in Operators)
            {
                if (string.CompareOrdinal(_src, _pos, op, 0, op.Length) == 0 && _pos + op.Length <= _src.Length)
                {
                    var token = new TaleToken(TaleTokenType.Operator, op, op, _line, Column(_pos));
                    _tokens.Add(token);
                    _pos += op.Length;
                    TrackBracket(token);
                    return;
                }
            }
            char c = _src[_pos];
            string message = "Unexpected character '" + c + "'.";
            if (c == ';')
                message = "TaleScript does not use ';'. Put each statement on its own line.";
            AddError(c.ToString(), message, _pos);
            _pos += 1;
        }

        private void TrackBracket(TaleToken token)
        {
            if (token.Text.Length == 1 && Openers.IndexOf(token.Text[0]) >= 0)
            {
                if (_brackets.Count == 0)
                    _bracketLineIndent = IndentWidth(_lineStart);
                _brackets.Add(token);
            }
            else if (token.Text.Length == 1 && Closers.IndexOf(token.Text[0]) >= 0)
            {
                string expectedOpener = Openers[Closers.IndexOf(token.Text[0])].ToString();
                if (_brackets.Count == 0 || _brackets[_brackets.Count - 1].Text != expectedOpener)
                    ErrorAt("'" + token.Text + "' does not match any opening bracket.", token.Line, token.Column);
                else
                    _brackets.RemoveAt(_brackets.Count - 1);
            }
        }

        /// <summary>
        /// Called at a line break inside brackets. True when the next non-blank line is
        /// not indented deeper than the line that opened the brackets.
        /// </summary>
        private bool NextLineLeavesBrackets()
        {
            int start = _pos + 1;
            while (start < _src.Length)
            {
                int end = _src.IndexOf('\n', start);
                if (end == -1)
                    end = _src.Length;
                string content = GdFormat.StripEdges(GdFormat.Substr(_src, start, end - start));
                if (content.Length > 0 && !content.StartsWith("#"))
                {
                    if (Closers.IndexOf(content[0]) >= 0)
                        return false;
                    return IndentWidth(start) <= _bracketLineIndent;
                }
                start = end + 1;
            }
            return false;
        }

        private void CloseBracketsWithError()
        {
            foreach (var opener in _brackets)
            {
                ErrorAt("'" + opener.Text + "' is never closed.", opener.Line, opener.Column);
                _tokens.Add(new TaleToken(TaleTokenType.Error, "", "'" + opener.Text + "' is never closed.", opener.Line, opener.Column));
            }
            _brackets.Clear();
        }

        private int IndentWidth(int lineStart)
        {
            int i = lineStart;
            while (i < _src.Length && (_src[i] == ' ' || _src[i] == '\t'))
                i += 1;
            return i - lineStart;
        }

        private void AddError(string text, string message, int offset)
        {
            ErrorAt(message, _line, Column(offset));
            _tokens.Add(new TaleToken(TaleTokenType.Error, text, message, _line, Column(offset)));
        }

        private void ErrorAt(string message, int line, int column)
        {
            Diagnostics.Add(new TaleDiagnostic(TaleSeverity.Error, message, line, column));
        }

        private static bool IsDigit(char c)
        {
            return c >= '0' && c <= '9';
        }

        private static bool IsDigit(string c)
        {
            return c.Length == 1 && IsDigit(c[0]);
        }

        private static bool IsIdentifierStart(char c)
        {
            return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c > 127;
        }

        private static bool IsIdentifierChar(char c)
        {
            return IsIdentifierStart(c) || IsDigit(c);
        }
    }
}
