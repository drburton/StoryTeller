using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace TaleScript
{
    public enum TaleNodeKind
    {
        Blank,
        Comment,
        Annotation,
        Var,
        Const,
        Beat,
        Dialogue,
        Narration,
        Jump,
        Expression,
        Assign,
        If,
        Elif,
        Else,
        While,
        For,
        Match,
        MatchBranch,
        Choose,
        Option,
        Timeout,
        Return,
        Pass,
        Break,
        Continue,
        Error,
    }

    /// <summary>
    /// One statement in a tale's syntax tree. Every physical line of the source
    /// belongs to exactly one node (blank lines and comments included).
    /// Block statements keep their nested statements in <see cref="Body"/>.
    /// </summary>
    public class TaleNode
    {

        /// <summary>Kinds that end with ':' and own a block of statements.</summary>
        public static readonly TaleNodeKind[] BlockKinds =
        {
            TaleNodeKind.Beat, TaleNodeKind.If, TaleNodeKind.Elif, TaleNodeKind.Else, TaleNodeKind.While, TaleNodeKind.For, TaleNodeKind.Match,
            TaleNodeKind.MatchBranch, TaleNodeKind.Choose, TaleNodeKind.Option, TaleNodeKind.Timeout,
        };

        public TaleNodeKind Kind;
        /// <summary>First and last physical line of this statement (1-based, inclusive), excluding its body.</summary>
        public int LineStart;
        public int LineEnd;
        /// <summary>Leading whitespace of the statement's first line.</summary>
        public string Indent = "";
        /// <summary>True when this statement sits on the same line as its block header.</summary>
        public bool Inline;
        /// <summary>Annotations written before the statement on the same line.</summary>
        public List<TaleExpr> Annotations = new List<TaleExpr>();
        /// <summary>Comment at the end of the line (text after '#'), or the text of a COMMENT line.</summary>
        public string Comment = "";

        /// <summary>Name of a VAR, CONST, BEAT, or FOR variable, or the speaker of a DIALOGUE.</summary>
        public string Name = "";
        /// <summary>Type hint of a VAR, CONST, or FOR variable, e.g. "int" or "Array[String]".</summary>
        public string TypeHint = "";
        /// <summary>True for VAR and CONST declared with ':='.</summary>
        public bool InferType;
        /// <summary>Mood of a DIALOGUE. Empty when not given.</summary>
        public string Mood = "";
        /// <summary>Main expression: value, text, condition, iterable, subject, or call arguments of CHOOSE.</summary>
        public TaleExpr Expr;
        /// <summary>Target of an ASSIGN.</summary>
        public TaleExpr Target;
        /// <summary>Assignment operator of an ASSIGN, e.g. "=" or "+=".</summary>
        public string Op = "";
        /// <summary>Condition of an OPTION or guard of a MATCH_BRANCH.</summary>
        public TaleExpr Condition;
        /// <summary>Patterns of a MATCH_BRANCH.</summary>
        public List<TaleExpr> Patterns = new List<TaleExpr>();
        /// <summary>Destination of a JUMP: "beat" or "tale.beat".</summary>
        public string JumpTarget = "";
        /// <summary>Nested statements of a block.</summary>
        public List<TaleNode> Body = new List<TaleNode>();
        /// <summary>Error message of an ERROR node.</summary>
        public string Message = "";

        public TaleNode(TaleNodeKind kind)
        {
            Kind = kind;
        }

        public bool IsBlock()
        {
            return System.Array.IndexOf(BlockKinds, Kind) >= 0;
        }

        /// <summary>True for blank and comment lines, which do not affect the story.</summary>
        public bool IsTrivia()
        {
            return Kind == TaleNodeKind.Blank || Kind == TaleNodeKind.Comment;
        }

        /// <summary>Returns an indented text form of this node and its body, used by tests.</summary>
        public string Dump(int depth = 0)
        {
            var parts = new List<string> { GdFormat.EnumKey(Kind) };
            foreach (var annotation in Annotations)
                parts.Add(annotation.ToSexpr());
            switch (Kind)
            {
                case TaleNodeKind.Comment:
                    parts.Add("\"" + GdFormat.CEscape(Comment) + "\"");
                    break;
                case TaleNodeKind.Var:
                case TaleNodeKind.Const:
                    parts.Add(Name + (TypeHint.Length > 0 ? ": " + TypeHint : ""));
                    if (Expr != null)
                    {
                        parts.Add(InferType ? ":=" : "=");
                        parts.Add(Expr.ToSexpr());
                    }
                    break;
                case TaleNodeKind.Beat:
                    parts.Add(Name);
                    break;
                case TaleNodeKind.Dialogue:
                    parts.Add(Name);
                    if (Mood.Length > 0)
                        parts.Add("(" + Mood + ")");
                    parts.Add(Expr.ToSexpr());
                    break;
                case TaleNodeKind.Jump:
                    parts.Add(JumpTarget);
                    break;
                case TaleNodeKind.Assign:
                    parts.Add(Target.ToSexpr());
                    parts.Add(Op);
                    parts.Add(Expr.ToSexpr());
                    break;
                case TaleNodeKind.For:
                    parts.Add(Name + (TypeHint.Length > 0 ? ": " + TypeHint : ""));
                    parts.Add("in");
                    parts.Add(Expr.ToSexpr());
                    break;
                case TaleNodeKind.MatchBranch:
                    foreach (var pattern in Patterns)
                        parts.Add(pattern.ToSexpr());
                    break;
                case TaleNodeKind.Error:
                    parts.Add("\"" + GdFormat.CEscape(Message) + "\"");
                    break;
                default:
                    if (Expr != null)
                        parts.Add(Expr.ToSexpr());
                    break;
            }
            if (Condition != null)
            {
                parts.Add(Kind == TaleNodeKind.MatchBranch ? "when" : "if");
                parts.Add(Condition.ToSexpr());
            }
            if (Comment.Length > 0 && Kind != TaleNodeKind.Comment)
                parts.Add("#\"" + GdFormat.CEscape(Comment) + "\"");
            string span = LineStart == LineEnd
                ? LineStart.ToString(CultureInfo.InvariantCulture)
                : LineStart.ToString(CultureInfo.InvariantCulture) + "-" + LineEnd.ToString(CultureInfo.InvariantCulture);
            var text = new StringBuilder();
            text.Append(GdFormat.Repeat("  ", depth)).Append(string.Join(" ", parts)).Append(" [").Append(span).Append(']');
            if (Inline) text.Append(" inline");
            text.Append('\n');
            foreach (var child in Body)
                text.Append(child.Dump(depth + 1));
            return text.ToString();
        }
    }
}
