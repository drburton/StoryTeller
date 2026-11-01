using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    public enum TaleExprKind
    {
        Literal,
        Identifier,
        Unary,
        Binary,
        Ternary,
        Await,
        Call,
        Attribute,
        Index,
        Array,
        Dictionary,
        Annotation,
    }

    /// <summary>
    /// An expression in a tale, such as <c>trust + 1</c> or
    /// <c>mira.move_to(CENTER, time = 0.6)</c>.
    /// </summary>
    public class TaleExpr
    {

        public TaleExprKind Kind;
        /// <summary>Value of a LITERAL: null, bool, long, double, or string.</summary>
        public object Value;
        /// <summary>Name of an IDENTIFIER, ATTRIBUTE, or ANNOTATION.</summary>
        public string Name = "";
        /// <summary>Operator of a UNARY or BINARY expression, e.g. "+" or "not in".</summary>
        public string Op = "";
        /// <summary>
        /// Sub-expressions. UNARY and AWAIT: [operand]. BINARY: [left, right].
        /// TERNARY: [if_true, condition, if_false]. CALL: [callee]. ATTRIBUTE: [object].
        /// INDEX: [object, index]. ARRAY: items. DICTIONARY: alternating keys and values.
        /// </summary>
        public List<TaleExpr> Operands = new List<TaleExpr>();
        /// <summary>Positional arguments of a CALL or ANNOTATION.</summary>
        public List<TaleExpr> Args = new List<TaleExpr>();
        /// <summary>Named arguments of a CALL or ANNOTATION, in source order.</summary>
        public OrderedMap<TaleExpr> NamedArgs = new OrderedMap<TaleExpr>();
        /// <summary>1-based position of the expression's first token.</summary>
        public int Line;
        public int Column;

        public TaleExpr(TaleExprKind kind, int line = 0, int column = 0)
        {
            Kind = kind;
            Line = line;
            Column = column;
        }

        /// <summary>Returns the callee name of a call to a plain identifier, or "".</summary>
        public string GetCallName()
        {
            if (Kind == TaleExprKind.Call && Operands[0].Kind == TaleExprKind.Identifier)
                return Operands[0].Name;
            return "";
        }

        /// <summary>Returns a compact, unambiguous text form, used by tests and debugging.</summary>
        public string ToSexpr()
        {
            switch (Kind)
            {
                case TaleExprKind.Literal:
                    return LiteralText(Value);
                case TaleExprKind.Identifier:
                    return Name;
                case TaleExprKind.Unary:
                    return "(" + Op + " " + Operands[0].ToSexpr() + ")";
                case TaleExprKind.Await:
                    return "(await " + Operands[0].ToSexpr() + ")";
                case TaleExprKind.Binary:
                    return "(" + Op + " " + Operands[0].ToSexpr() + " " + Operands[1].ToSexpr() + ")";
                case TaleExprKind.Ternary:
                    return "(if " + Operands[1].ToSexpr() + " " + Operands[0].ToSexpr() + " " + Operands[2].ToSexpr() + ")";
                case TaleExprKind.Call:
                {
                    var parts = new List<string> { Operands[0].ToSexpr() };
                    parts.AddRange(ArgTexts());
                    return "(call " + string.Join(" ", parts) + ")";
                }
                case TaleExprKind.Annotation:
                {
                    var texts = ArgTexts();
                    return texts.Count == 0 ? "@" + Name : "@" + Name + "(" + string.Join(" ", texts) + ")";
                }
                case TaleExprKind.Attribute:
                    return "(. " + Operands[0].ToSexpr() + " " + Name + ")";
                case TaleExprKind.Index:
                    return "([] " + Operands[0].ToSexpr() + " " + Operands[1].ToSexpr() + ")";
                case TaleExprKind.Array:
                {
                    var items = new List<string>();
                    foreach (var item in Operands) items.Add(item.ToSexpr());
                    return "[" + string.Join(" ", items) + "]";
                }
                case TaleExprKind.Dictionary:
                {
                    var entries = new List<string>();
                    for (int i = 0; i < Operands.Count; i += 2)
                        entries.Add(Operands[i].ToSexpr() + ": " + Operands[i + 1].ToSexpr());
                    return "{" + string.Join(", ", entries) + "}";
                }
            }
            return "?";
        }

        /// <summary>
        /// Returns TaleScript source for this expression, with parentheses only
        /// where precedence needs them.
        /// </summary>
        public string ToSource()
        {
            return Source(0);
        }

        /// <summary>Quotes text as a TaleScript string literal.</summary>
        public static string Quote(string text)
        {
            string escaped = text.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\t", "\\t").Replace("\r", "\\r");
            return "\"" + escaped + "\"";
        }

        /// <summary>Binding strength of this expression, as in <see cref="TaleParser"/>.</summary>
        public int Precedence()
        {
            switch (Kind)
            {
                case TaleExprKind.Binary:
                {
                    int p;
                    return TaleParser.BinaryPrecedence.TryGetValue(Op, out p) ? p : 0;
                }
                case TaleExprKind.Ternary:
                    return TaleParser.PrecTernary;
                case TaleExprKind.Unary:
                    if (Op == "not") return TaleParser.PrecNot;
                    return Op == "~" ? TaleParser.PrecBitNot : TaleParser.PrecUnary;
                case TaleExprKind.Await:
                    return TaleParser.PrecAwait;
            }
            return 100;
        }

        private string Source(int minPrecedence)
        {
            string text = SourceUnwrapped();
            return Precedence() < minPrecedence ? "(" + text + ")" : text;
        }

        private string SourceUnwrapped()
        {
            switch (Kind)
            {
                case TaleExprKind.Literal:
                    return Value is string s ? Quote(s) : LiteralText(Value);
                case TaleExprKind.Identifier:
                    return Name;
                case TaleExprKind.Unary:
                    return (Op == "not" ? "not " : Op) + Operands[0].Source(Precedence());
                case TaleExprKind.Await:
                    return "await " + Operands[0].Source(Precedence());
                case TaleExprKind.Binary:
                {
                    int own = Precedence();
                    return Operands[0].Source(own) + " " + Op + " " + Operands[1].Source(own + 1);
                }
                case TaleExprKind.Ternary:
                {
                    int own = Precedence();
                    return Operands[0].Source(own + 1) + " if " + Operands[1].Source(own + 1) + " else " + Operands[2].Source(own);
                }
                case TaleExprKind.Call:
                    return Operands[0].Source(100) + "(" + string.Join(", ", ArgSources()) + ")";
                case TaleExprKind.Annotation:
                {
                    var texts = ArgSources();
                    return texts.Count == 0 ? "@" + Name : "@" + Name + "(" + string.Join(", ", texts) + ")";
                }
                case TaleExprKind.Attribute:
                    return Operands[0].Source(100) + "." + Name;
                case TaleExprKind.Index:
                    return Operands[0].Source(100) + "[" + Operands[1].Source(0) + "]";
                case TaleExprKind.Array:
                {
                    var items = new List<string>();
                    foreach (var item in Operands) items.Add(item.Source(0));
                    return "[" + string.Join(", ", items) + "]";
                }
                case TaleExprKind.Dictionary:
                {
                    var entries = new List<string>();
                    for (int i = 0; i < Operands.Count; i += 2)
                        entries.Add(Operands[i].Source(0) + ": " + Operands[i + 1].Source(0));
                    return "{" + string.Join(", ", entries) + "}";
                }
            }
            return "";
        }

        private List<string> ArgSources()
        {
            var texts = new List<string>();
            foreach (var arg in Args) texts.Add(arg.Source(0));
            foreach (var key in NamedArgs.Keys) texts.Add(key + " = " + NamedArgs[key].Source(0));
            return texts;
        }

        private List<string> ArgTexts()
        {
            var texts = new List<string>();
            foreach (var arg in Args) texts.Add(arg.ToSexpr());
            foreach (var key in NamedArgs.Keys) texts.Add(key + "=" + NamedArgs[key].ToSexpr());
            return texts;
        }

        private static string LiteralText(object literal)
        {
            if (literal is string s)
                return "\"" + GdFormat.CEscape(s) + "\"";
            if (literal == null)
                return "null";
            if (literal is double d)
            {
                string text = GdFormat.FloatToString(d);
                return text.Contains(".") || text.Contains("e") || text.Contains("inf") || text.Contains("nan") ? text : text + ".0";
            }
            return GdFormat.Str(literal);
        }
    }
}
