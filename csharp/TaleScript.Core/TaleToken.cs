namespace TaleScript
{
    public enum TaleTokenType
    {
        Identifier,
        Keyword,
        Int,
        Float,
        String,
        Operator,
        Annotation,
        Comment,
        Newline,
        End,
        Error,
    }

    /// <summary>A single token produced by <see cref="TaleLexer"/>.</summary>
    public class TaleToken
    {

        public TaleTokenType Type;
        /// <summary>Exact source text of the token.</summary>
        public string Text;
        /// <summary>
        /// Identifier, keyword, or operator text (string); the parsed value of a literal
        /// (long, double, or string); the name of an annotation; the text of a comment
        /// after '#'; or the message of an error token.
        /// </summary>
        public object Value;
        /// <summary>1-based line where the token starts.</summary>
        public int Line;
        /// <summary>1-based column where the token starts.</summary>
        public int Column;

        public TaleToken(TaleTokenType type, string text, object value, int line, int column)
        {
            Type = type;
            Text = text;
            Value = value;
            Line = line;
            Column = column;
        }

        /// <summary>Value as text, or "" when it is not a string.</summary>
        public string StringValue
        {
            get { return Value as string ?? ""; }
        }

        public bool IsOp(string op)
        {
            return Type == TaleTokenType.Operator && Value is string s && s == op;
        }

        public bool IsKeyword(string word)
        {
            return Type == TaleTokenType.Keyword && Value is string s && s == word;
        }

        public override string ToString()
        {
            return GdFormat.EnumKey(Type) + "(" + GdFormat.CEscape(Text) + ")";
        }
    }
}
