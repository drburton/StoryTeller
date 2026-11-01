using System.Collections.Generic;
using System.Globalization;

namespace TaleScript
{
    /// <summary>
    /// Parses TaleScript source into a <see cref="TaleDocument"/>.
    /// Parsing never stops at the first problem. A line that cannot be parsed
    /// becomes an ERROR node, and parsing continues with the next line.
    /// </summary>
    public class TaleParser
    {
        public static readonly string[] AssignOps =
        {
            "=", "+=", "-=", "*=", "/=", "%=", "**=", "&=", "|=", "^=", "<<=", ">>=",
        };

        /// <summary>Binary operator precedence, following GDScript. Higher binds tighter.</summary>
        public static readonly Dictionary<string, int> BinaryPrecedence = new Dictionary<string, int>
        {
            { "or", 2 }, { "||", 2 },
            { "and", 3 }, { "&&", 3 },
            { "in", 5 }, { "not in", 5 },
            { "<", 6 }, { ">", 6 }, { "<=", 6 }, { ">=", 6 }, { "==", 6 }, { "!=", 6 },
            { "|", 7 }, { "^", 8 }, { "&", 9 }, { "<<", 10 }, { ">>", 10 },
            { "+", 11 }, { "-", 11 },
            { "*", 12 }, { "/", 12 }, { "%", 12 },
            { "**", 15 },
        };

        public const int PrecTernary = 1;
        public const int PrecNot = 4;
        public const int PrecUnary = 13;
        public const int PrecBitNot = 14;
        public const int PrecAwait = 16;

        /// <summary>What a block may contain.</summary>
        public enum Context { Top, Block, Match, Choose }

        /// <summary>Result of <see cref="ParseExpression"/>. On failure Expr is null and Error explains why.</summary>
        public class ExpressionResult
        {
            public TaleExpr Expr;
            public string Error = "";
        }

        private class Line
        {
            public List<TaleToken> Tokens = new List<TaleToken>();
            public TaleToken Comment;
            public int Start;
            public int End;
            public string Indent = "";
        }

        private class Frame
        {
            public string Indent;
            public List<TaleNode> Body;
            public Context Context;

            public Frame(string indent, List<TaleNode> body, Context context)
            {
                Indent = indent;
                Body = body;
                Context = context;
            }
        }

        private TaleDocument _doc;
        private List<TaleToken> _tokens = new List<TaleToken>();
        private int _index;
        private TaleToken _endToken;
        private bool _failed;
        private string _failMessage = "";
        private TaleToken _failToken;
        private string _indentChar = "";

        /// <summary>Parses source. path is only used for messages and lookups.</summary>
        public static TaleDocument Parse(string source, string path = "")
        {
            return new TaleParser().ParseDocument(source, path);
        }

        /// <summary>
        /// Parses a single expression, as used inside {...} in text.
        /// On failure Expr is null and Error explains why.
        /// </summary>
        public static ExpressionResult ParseExpression(string source)
        {
            var parser = new TaleParser();
            var lexer = new TaleLexer();
            var tokens = new List<TaleToken>();
            foreach (var token in lexer.Tokenize(source))
            {
                switch (token.Type)
                {
                    case TaleTokenType.End:
                    case TaleTokenType.Comment:
                        break;
                    case TaleTokenType.Newline:
                        return new ExpressionResult { Error = "Expressions in text must fit on one line." };
                    case TaleTokenType.Error:
                        return new ExpressionResult { Error = token.StringValue };
                    default:
                        tokens.Add(token);
                        break;
                }
            }
            if (tokens.Count == 0)
                return new ExpressionResult { Error = "Expected an expression between the braces." };
            parser._tokens = tokens;
            parser._index = 0;
            parser._endToken = new TaleToken(TaleTokenType.Newline, "end of line", null, 1, source.Length + 1);
            var expr = parser.Expression();
            if (!parser._failed && !parser.AtEnd())
                parser.Fail("Unexpected '" + parser.Peek().Text + "'.");
            if (parser._failed)
                return new ExpressionResult { Error = parser._failMessage };
            return new ExpressionResult { Expr = expr };
        }

        private TaleDocument ParseDocument(string source, string path)
        {
            _doc = new TaleDocument();
            _doc.Path = path;
            _doc.Lines = source.Split('\n');
            var lexer = new TaleLexer();
            var tokens = lexer.Tokenize(source);
            _doc.Diagnostics.AddRange(lexer.Diagnostics);

            var stack = new List<Frame> { new Frame("", _doc.Statements, Context.Top) };
            TaleNode pending = null;
            var trivia = new List<TaleNode>();

            foreach (var line in LogicalLines(tokens))
            {
                if (line.Tokens.Count == 0)
                {
                    trivia.Add(TriviaNode(line));
                    continue;
                }
                CheckIndentChars(line);

                bool opened = false;
                if (pending != null)
                {
                    var top = stack[stack.Count - 1];
                    if (line.Indent.Length > top.Indent.Length && line.Indent.StartsWith(top.Indent, System.StringComparison.Ordinal))
                    {
                        stack.Add(new Frame(line.Indent, pending.Body, BodyContext(pending)));
                        opened = true;
                    }
                    else if (pending.Kind != TaleNodeKind.Error)
                    {
                        Error("Expected an indented block after '" + HeaderLabel(pending) + "'.", line.Start, 1);
                    }
                    pending = null;
                }

                var deepest = stack[stack.Count - 1];
                if (!opened)
                {
                    if (line.Indent.Length > deepest.Indent.Length)
                    {
                        Error("Unexpected indentation.", line.Start, 1);
                        // Read the rest of this indented run as ordinary statements, so
                        // one misplaced block reports one error instead of one per line.
                        stack.Add(new Frame(line.Indent, deepest.Body, Context.Block));
                    }
                    else if (line.Indent != deepest.Indent)
                    {
                        Frame lastPopped = null;
                        while (stack.Count > 1 && stack[stack.Count - 1].Indent.Length > line.Indent.Length)
                        {
                            lastPopped = stack[stack.Count - 1];
                            stack.RemoveAt(stack.Count - 1);
                        }
                        if (stack[stack.Count - 1].Indent != line.Indent)
                        {
                            Error("Indentation does not match any outer block.", line.Start, 1);
                            // Keep the line in the closest block it was meant for.
                            if (lastPopped != null)
                                stack.Add(lastPopped);
                        }
                    }
                }

                var frame = stack[stack.Count - 1];
                PlaceTrivia(trivia, deepest, frame, line.Indent);
                var node = ParseLine(line, frame.Context);
                frame.Body.Add(node);
                bool opensBlock = node.IsBlock() || (node.Kind == TaleNodeKind.Error && line.Tokens[line.Tokens.Count - 1].IsOp(":"));
                if (opensBlock && node.Body.Count == 0)
                    pending = node;
            }

            if (pending != null && pending.Kind != TaleNodeKind.Error)
                Error("Expected an indented block after '" + HeaderLabel(pending) + "'.", pending.LineEnd, 1);
            PlaceTrivia(trivia, stack[stack.Count - 1], stack[0], "");
            StableSortDiagnostics(_doc.Diagnostics);
            return _doc;
        }

        private static void StableSortDiagnostics(List<TaleDiagnostic> list)
        {
            // Insertion sort keeps equal positions in the order they were found.
            for (int i = 1; i < list.Count; i++)
            {
                var item = list[i];
                int j = i - 1;
                while (j >= 0 && (list[j].Line > item.Line || (list[j].Line == item.Line && list[j].Column > item.Column)))
                {
                    list[j + 1] = list[j];
                    j--;
                }
                list[j + 1] = item;
            }
        }

        // --- Lines and blocks -------------------------------------------------

        /// <summary>
        /// Groups tokens into logical lines. Every content line of the source ends up
        /// in exactly one logical line.
        /// </summary>
        private List<Line> LogicalLines(List<TaleToken> tokens)
        {
            int contentLines = _doc.Lines.Length;
            if (contentLines > 0 && _doc.Lines[contentLines - 1] == "")
                contentLines -= 1;
            var result = new List<Line>();
            var current = new Line();
            int previousEnd = 0;
            foreach (var token in tokens)
            {
                if (token.Type == TaleTokenType.Newline || token.Type == TaleTokenType.End)
                {
                    int last = token.Line;
                    if (token.Type == TaleTokenType.End)
                    {
                        if (previousEnd >= contentLines)
                            break;
                        last = contentLines;
                    }
                    current.Start = previousEnd + 1;
                    current.End = last;
                    current.Indent = LeadingWhitespace(_doc.Lines[current.Start - 1]);
                    result.Add(current);
                    previousEnd = last;
                    current = new Line();
                }
                else if (token.Type == TaleTokenType.Comment)
                {
                    if (current.Comment == null)
                        current.Comment = token;
                }
                else
                {
                    current.Tokens.Add(token);
                }
            }
            return result;
        }

        private TaleNode TriviaNode(Line line)
        {
            var node = new TaleNode(line.Comment != null ? TaleNodeKind.Comment : TaleNodeKind.Blank);
            node.LineStart = line.Start;
            node.LineEnd = line.End;
            node.Indent = line.Indent;
            if (line.Comment != null)
                node.Comment = line.Comment.StringValue;
            return node;
        }

        /// <summary>
        /// Puts buffered blank and comment lines into a block. When the next statement
        /// closes blocks, comments indented deeper than it stay with the inner block.
        /// </summary>
        private void PlaceTrivia(List<TaleNode> trivia, Frame deepest, Frame frame, string indent)
        {
            int split = 0;
            if (deepest != frame)
            {
                for (int i = 0; i < trivia.Count; i++)
                {
                    if (trivia[i].Kind == TaleNodeKind.Comment && trivia[i].Indent.Length > indent.Length)
                        split = i + 1;
                }
            }
            for (int i = 0; i < trivia.Count; i++)
                (i < split ? deepest : frame).Body.Add(trivia[i]);
            trivia.Clear();
        }

        private void CheckIndentChars(Line line)
        {
            if (line.Indent.Length == 0)
                return;
            if (line.Indent.Contains(" ") && line.Indent.Contains("\t"))
            {
                Error("Mixed tabs and spaces in indentation.", line.Start, 1);
                return;
            }
            string used = line.Indent.Substring(0, 1);
            if (_indentChar.Length == 0)
            {
                _indentChar = used;
            }
            else if (used != _indentChar)
            {
                string expected = _indentChar == "\t" ? "tabs" : "spaces";
                Error("Indentation uses " + expected + " elsewhere in this file.", line.Start, 1);
            }
        }

        private static Context BodyContext(TaleNode header)
        {
            switch (header.Kind)
            {
                case TaleNodeKind.Match: return Context.Match;
                case TaleNodeKind.Choose: return Context.Choose;
            }
            return Context.Block;
        }

        private static string HeaderLabel(TaleNode header)
        {
            switch (header.Kind)
            {
                case TaleNodeKind.Beat: return "beat " + header.Name;
                case TaleNodeKind.MatchBranch: return "match branch";
                case TaleNodeKind.Option: return "choice option";
            }
            return GdFormat.EnumKey(header.Kind).ToLowerInvariant();
        }

        private static string LeadingWhitespace(string text)
        {
            int i = 0;
            while (i < text.Length && (text[i] == ' ' || text[i] == '\t'))
                i++;
            return text.Substring(0, i);
        }

        // --- Statements -------------------------------------------------------

        private TaleNode ParseLine(Line line, Context context)
        {
            _tokens = line.Tokens;
            _index = 0;
            _failed = false;
            _failMessage = "";
            _failToken = null;
            var last = line.Tokens[line.Tokens.Count - 1];
            _endToken = new TaleToken(TaleTokenType.Newline, "end of line", null, last.Line, last.Column + last.Text.Length);

            TaleNode node = null;
            bool lexerError = false;
            foreach (var token in line.Tokens)
            {
                if (token.Type == TaleTokenType.Error)
                {
                    lexerError = true;
                    node = ErrorNode(token.StringValue);
                    break;
                }
            }
            if (!lexerError)
            {
                node = Statement(context, false);
                if (!_failed && !AtEnd())
                    Fail("Unexpected '" + Peek().Text + "'.");
                if (_failed)
                {
                    Error(_failMessage, _failToken.Line, _failToken.Column);
                    node = ErrorNode(_failMessage);
                }
            }

            node.LineStart = line.Start;
            node.LineEnd = line.End;
            node.Indent = line.Indent;
            if (line.Comment != null)
                node.Comment = line.Comment.StringValue;
            foreach (var child in node.Body)
            {
                child.LineStart = line.Start;
                child.LineEnd = line.End;
                child.Indent = line.Indent;
            }
            return node;
        }

        private static TaleNode ErrorNode(string message)
        {
            var node = new TaleNode(TaleNodeKind.Error);
            node.Message = message;
            return node;
        }

        private TaleNode Statement(Context context, bool inline)
        {
            var annotations = Annotations();
            if (_failed)
                return null;
            if (AtEnd())
            {
                if (inline)
                {
                    Fail("Expected a statement after ':'.");
                    return null;
                }
                var holder = new TaleNode(TaleNodeKind.Annotation);
                holder.Annotations = annotations;
                return holder;
            }

            TaleNode node;
            switch (context)
            {
                case Context.Top:
                    node = TopStatement();
                    break;
                case Context.Match:
                    node = MatchBranch();
                    break;
                case Context.Choose:
                    node = ChooseOption();
                    break;
                default:
                    node = BlockStatement();
                    break;
            }
            if (_failed)
                return null;
            node.Annotations = annotations;

            if (node.IsBlock() && !AtEnd())
            {
                if (inline)
                {
                    Fail("Only one block header is allowed per line.");
                    return null;
                }
                if (node.Kind == TaleNodeKind.Match || node.Kind == TaleNodeKind.Choose)
                {
                    Fail("Start a new line after '" + HeaderLabel(node) + ":'.");
                    return null;
                }
                var child = Statement(Context.Block, true);
                if (_failed)
                    return null;
                if (child.IsBlock())
                {
                    Fail("A block can't start on the same line as another block.");
                    return null;
                }
                child.Inline = true;
                node.Body.Add(child);
            }
            return node;
        }

        private List<TaleExpr> Annotations()
        {
            var result = new List<TaleExpr>();
            while (!_failed && Peek().Type == TaleTokenType.Annotation)
            {
                var token = Advance();
                var annotation = new TaleExpr(TaleExprKind.Annotation, token.Line, token.Column);
                annotation.Name = token.StringValue;
                if (Peek().IsOp("("))
                {
                    Advance();
                    CallArguments(annotation);
                }
                result.Add(annotation);
            }
            return result;
        }

        private TaleNode TopStatement()
        {
            var token = Peek();
            if (token.IsKeyword("var"))
                return VarDeclaration();
            if (token.IsKeyword("const"))
                return ConstDeclaration();
            if (token.IsKeyword("beat"))
                return Beat();
            Fail("Only 'var', 'const', and 'beat' are allowed here. Put story lines inside a beat.");
            return null;
        }

        private TaleNode BlockStatement()
        {
            var token = Peek();
            if (token.Type == TaleTokenType.Keyword)
            {
                switch (token.StringValue)
                {
                    case "var":
                        return VarDeclaration();
                    case "const":
                        return ConstDeclaration();
                    case "beat":
                        Fail("Beats can't be nested. Declare 'beat " + PeekAt(1).Text + "' at the top level of the file.");
                        return null;
                    case "if":
                    case "elif":
                    case "while":
                        return ConditionalHeader();
                    case "else":
                    {
                        Advance();
                        var elseNode = new TaleNode(TaleNodeKind.Else);
                        ExpectOp(":", "after 'else'");
                        return elseNode;
                    }
                    case "for":
                        return ForLoop();
                    case "match":
                    {
                        Advance();
                        var matchNode = new TaleNode(TaleNodeKind.Match);
                        matchNode.Expr = Expression();
                        ExpectOp(":", "after the match value");
                        return matchNode;
                    }
                    case "choose":
                        return Choose();
                    case "jump":
                        return Jump();
                    case "return":
                    {
                        Advance();
                        var returnNode = new TaleNode(TaleNodeKind.Return);
                        if (!AtEnd())
                            returnNode.Expr = Expression();
                        return returnNode;
                    }
                    case "pass":
                        Advance();
                        return new TaleNode(TaleNodeKind.Pass);
                    case "break":
                        Advance();
                        return new TaleNode(TaleNodeKind.Break);
                    case "continue":
                        Advance();
                        return new TaleNode(TaleNodeKind.Continue);
                }
            }
            if (token.Type == TaleTokenType.String)
            {
                var next = PeekAt(1);
                if (next.Type == TaleTokenType.Newline)
                {
                    Advance();
                    var narration = new TaleNode(TaleNodeKind.Narration);
                    narration.Expr = Literal(token);
                    return narration;
                }
                if (next.IsOp(":") || next.IsKeyword("if"))
                {
                    Fail("Choice options belong inside a 'choose:' block.");
                    return null;
                }
            }
            if (token.Type == TaleTokenType.Identifier && IsDialogue())
                return Dialogue();
            return ExpressionStatement();
        }

        private TaleNode VarDeclaration()
        {
            Advance();
            var node = new TaleNode(TaleNodeKind.Var);
            node.Name = ExpectIdentifier("variable name");
            if (Peek().IsOp(":"))
            {
                Advance();
                node.TypeHint = TypeHint();
            }
            if (Peek().IsOp(":="))
            {
                Advance();
                node.InferType = true;
                node.Expr = Expression();
            }
            else if (Peek().IsOp("="))
            {
                Advance();
                node.Expr = Expression();
            }
            return node;
        }

        private TaleNode ConstDeclaration()
        {
            Advance();
            var node = new TaleNode(TaleNodeKind.Const);
            node.Name = ExpectIdentifier("constant name");
            if (Peek().IsOp(":"))
            {
                Advance();
                node.TypeHint = TypeHint();
            }
            if (Peek().IsOp(":="))
            {
                Advance();
                node.InferType = true;
            }
            else if (!ExpectOp("=", "and a value for the constant"))
            {
                return node;
            }
            node.Expr = Expression();
            return node;
        }

        private string TypeHint()
        {
            string typeName = ExpectIdentifier("type name");
            if (Peek().IsOp("["))
            {
                Advance();
                typeName += "[" + ExpectIdentifier("type name") + "]";
                ExpectOp("]", "to close the type");
            }
            return typeName;
        }

        private TaleNode Beat()
        {
            Advance();
            var node = new TaleNode(TaleNodeKind.Beat);
            node.Name = ExpectIdentifier("beat name");
            if (Peek().IsOp("("))
            {
                Fail("Beats don't take parameters. Use variables to pass values.");
                return node;
            }
            ExpectOp(":", "after the beat name");
            return node;
        }

        private TaleNode ConditionalHeader()
        {
            var keyword = Advance();
            TaleNodeKind kind;
            switch (keyword.StringValue)
            {
                case "if": kind = TaleNodeKind.If; break;
                case "elif": kind = TaleNodeKind.Elif; break;
                default: kind = TaleNodeKind.While; break;
            }
            var node = new TaleNode(kind);
            node.Expr = Expression();
            ExpectOp(":", "after the condition");
            return node;
        }

        private TaleNode ForLoop()
        {
            Advance();
            var node = new TaleNode(TaleNodeKind.For);
            node.Name = ExpectIdentifier("loop variable");
            if (Peek().IsOp(":"))
            {
                Advance();
                node.TypeHint = TypeHint();
            }
            ExpectKeyword("in", "after the loop variable");
            node.Expr = Expression();
            ExpectOp(":", "after the loop");
            return node;
        }

        private TaleNode Choose()
        {
            var keyword = Advance();
            var node = new TaleNode(TaleNodeKind.Choose);
            if (Peek().IsOp("("))
            {
                Advance();
                var call = new TaleExpr(TaleExprKind.Call, keyword.Line, keyword.Column);
                var callee = new TaleExpr(TaleExprKind.Identifier, keyword.Line, keyword.Column);
                callee.Name = "choose";
                call.Operands.Add(callee);
                CallArguments(call);
                node.Expr = call;
            }
            ExpectOp(":", "after 'choose'");
            return node;
        }

        private TaleNode Jump()
        {
            Advance();
            var node = new TaleNode(TaleNodeKind.Jump);
            node.JumpTarget = ExpectIdentifier("beat name after 'jump'");
            if (Peek().IsOp("."))
            {
                Advance();
                node.JumpTarget += "." + ExpectIdentifier("beat name after '.'");
            }
            return node;
        }

        /// <summary>True when the line starts with name: or name (mood):.</summary>
        private bool IsDialogue()
        {
            int i = _index + 1;
            if (PeekAt(1).IsOp("("))
            {
                int depth = 0;
                while (i < _tokens.Count)
                {
                    if (_tokens[i].IsOp("("))
                    {
                        depth += 1;
                    }
                    else if (_tokens[i].IsOp(")"))
                    {
                        depth -= 1;
                        if (depth == 0)
                            break;
                    }
                    i += 1;
                }
                i += 1;
            }
            return i < _tokens.Count && _tokens[i].IsOp(":");
        }

        private TaleNode Dialogue()
        {
            var node = new TaleNode(TaleNodeKind.Dialogue);
            node.Name = Advance().StringValue;
            if (Peek().IsOp("("))
            {
                Advance();
                var mood = Advance();
                if (mood.Type != TaleTokenType.Identifier && mood.Type != TaleTokenType.String)
                {
                    Fail("Expected a mood name inside the parentheses.", mood);
                    return node;
                }
                node.Mood = mood.StringValue;
                ExpectOp(")", "after the mood");
            }
            ExpectOp(":", "after the speaker");
            if (_failed)
                return node;
            var text = Peek();
            if (text.Type != TaleTokenType.String)
            {
                Fail("Dialogue text must be a quoted string, e.g. " + node.Name + ": \"Hello\".", text);
                return node;
            }
            Advance();
            node.Expr = Literal(text);
            return node;
        }

        private TaleNode ExpressionStatement()
        {
            var value = Expression();
            if (_failed)
                return null;
            var next = Peek();
            if (next.Type == TaleTokenType.Operator && System.Array.IndexOf(AssignOps, next.StringValue) >= 0)
            {
                if (value.Kind != TaleExprKind.Identifier && value.Kind != TaleExprKind.Attribute && value.Kind != TaleExprKind.Index)
                {
                    Fail("Can't assign to this expression.", next);
                    return null;
                }
                Advance();
                var node = new TaleNode(TaleNodeKind.Assign);
                node.Target = value;
                node.Op = next.StringValue;
                node.Expr = Expression();
                return node;
            }
            if (next.IsOp(":"))
            {
                Fail("Unexpected ':'. Dialogue lines look like: name: \"text\".", next);
                return null;
            }
            var statement = new TaleNode(TaleNodeKind.Expression);
            statement.Expr = value;
            return statement;
        }

        private TaleNode MatchBranch()
        {
            var node = new TaleNode(TaleNodeKind.MatchBranch);
            if (Peek().IsKeyword("var"))
            {
                Fail("Binding patterns ('var name') are not supported yet.");
                return node;
            }
            node.Patterns.Add(Expression());
            while (!_failed && Peek().IsOp(","))
            {
                Advance();
                node.Patterns.Add(Expression());
            }
            if (Peek().IsKeyword("when"))
            {
                Advance();
                node.Condition = Expression();
            }
            ExpectOp(":", "after the match pattern");
            return node;
        }

        private TaleNode ChooseOption()
        {
            var token = Peek();
            if (token.Type == TaleTokenType.Identifier && token.StringValue == "timeout" && PeekAt(1).IsOp(":"))
            {
                Advance();
                Advance();
                return new TaleNode(TaleNodeKind.Timeout);
            }
            if (token.Type != TaleTokenType.String)
            {
                Fail("Expected a choice option, e.g. \"Open the door\":");
                return null;
            }
            Advance();
            var node = new TaleNode(TaleNodeKind.Option);
            node.Expr = Literal(token);
            if (Peek().IsKeyword("if"))
            {
                Advance();
                node.Condition = Expression();
            }
            ExpectOp(":", "after the option text");
            return node;
        }

        // --- Expressions ------------------------------------------------------

        private TaleExpr Expression(int minPrecedence = 0)
        {
            var left = Unary();
            while (!_failed && !AtEnd())
            {
                var token = Peek();
                string op = BinaryOperator();
                if (op != "")
                {
                    int precedence = BinaryPrecedence[op];
                    if (precedence < minPrecedence)
                        break;
                    Advance();
                    if (op == "not in")
                        Advance();
                    var binary = new TaleExpr(TaleExprKind.Binary, left.Line, left.Column);
                    binary.Op = NormalizeOperator(op);
                    binary.Operands.Add(left);
                    binary.Operands.Add(Expression(precedence + 1));
                    left = binary;
                }
                else if (token.IsKeyword("if") && PrecTernary >= minPrecedence)
                {
                    Advance();
                    var ternary = new TaleExpr(TaleExprKind.Ternary, left.Line, left.Column);
                    var condition = Expression(PrecTernary + 1);
                    ExpectKeyword("else", "in the conditional expression");
                    ternary.Operands.Add(left);
                    ternary.Operands.Add(condition);
                    ternary.Operands.Add(Expression(PrecTernary));
                    left = ternary;
                }
                else
                {
                    break;
                }
            }
            return left;
        }

        private string BinaryOperator()
        {
            var token = Peek();
            if (token.Type == TaleTokenType.Operator && BinaryPrecedence.ContainsKey(token.StringValue))
                return token.StringValue;
            if (token.Type == TaleTokenType.Keyword)
            {
                string word = token.StringValue;
                if (word == "and" || word == "or" || word == "in")
                    return word;
                if (word == "not" && PeekAt(1).IsKeyword("in"))
                    return "not in";
            }
            return "";
        }

        private static string NormalizeOperator(string op)
        {
            switch (op)
            {
                case "&&": return "and";
                case "||": return "or";
                case "!": return "not";
            }
            return op;
        }

        private TaleExpr Unary()
        {
            var token = Peek();
            int precedence = -1;
            var kind = TaleExprKind.Unary;
            if (token.IsOp("-") || token.IsOp("+"))
            {
                precedence = PrecUnary;
            }
            else if (token.IsOp("~"))
            {
                precedence = PrecBitNot;
            }
            else if (token.IsKeyword("not") || token.IsOp("!"))
            {
                precedence = PrecNot;
            }
            else if (token.IsKeyword("await"))
            {
                precedence = PrecAwait;
                kind = TaleExprKind.Await;
            }
            if (precedence < 0)
                return Postfix(Primary());
            Advance();
            var unary = new TaleExpr(kind, token.Line, token.Column);
            unary.Op = NormalizeOperator(token.StringValue);
            unary.Operands.Add(Expression(precedence));
            return unary;
        }

        private TaleExpr Primary()
        {
            var token = Advance();
            switch (token.Type)
            {
                case TaleTokenType.Int:
                case TaleTokenType.Float:
                case TaleTokenType.String:
                    return Literal(token);
                case TaleTokenType.Identifier:
                {
                    var identifier = new TaleExpr(TaleExprKind.Identifier, token.Line, token.Column);
                    identifier.Name = token.StringValue;
                    return identifier;
                }
                case TaleTokenType.Keyword:
                    switch (token.StringValue)
                    {
                        case "true": return LiteralValue(token, true);
                        case "false": return LiteralValue(token, false);
                        case "null": return LiteralValue(token, null);
                    }
                    break;
                case TaleTokenType.Operator:
                    switch (token.StringValue)
                    {
                        case "(":
                        {
                            var inner = Expression();
                            ExpectOp(")", "to close '('");
                            return inner;
                        }
                        case "[":
                            return ArrayLiteral(token);
                        case "{":
                            return DictionaryLiteral(token);
                    }
                    break;
            }
            if (token.Type == TaleTokenType.Newline)
                Fail("Expected an expression, but the line ended.", token);
            else
                Fail("Expected an expression, found '" + token.Text + "'.", token);
            return new TaleExpr(TaleExprKind.Literal, token.Line, token.Column);
        }

        private TaleExpr Postfix(TaleExpr baseExpr)
        {
            var result = baseExpr;
            while (!_failed)
            {
                var token = Peek();
                if (token.IsOp("("))
                {
                    Advance();
                    var call = new TaleExpr(TaleExprKind.Call, result.Line, result.Column);
                    call.Operands.Add(result);
                    CallArguments(call);
                    result = call;
                }
                else if (token.IsOp("."))
                {
                    Advance();
                    var attribute = new TaleExpr(TaleExprKind.Attribute, result.Line, result.Column);
                    attribute.Operands.Add(result);
                    attribute.Name = ExpectIdentifier("name after '.'");
                    result = attribute;
                }
                else if (token.IsOp("["))
                {
                    Advance();
                    var index = new TaleExpr(TaleExprKind.Index, result.Line, result.Column);
                    index.Operands.Add(result);
                    index.Operands.Add(Expression());
                    ExpectOp("]", "to close '['");
                    result = index;
                }
                else
                {
                    break;
                }
            }
            return result;
        }

        /// <summary>Parses arguments after '(' up to and including ')'.</summary>
        private void CallArguments(TaleExpr call)
        {
            while (!_failed && !Peek().IsOp(")"))
            {
                var token = Peek();
                if (token.Type == TaleTokenType.Identifier && PeekAt(1).IsOp("="))
                {
                    Advance();
                    Advance();
                    if (call.NamedArgs.Has(token.StringValue))
                    {
                        Fail("Argument '" + token.StringValue + "' is given twice.", token);
                        return;
                    }
                    call.NamedArgs[token.StringValue] = Expression();
                }
                else
                {
                    if (!call.NamedArgs.IsEmpty)
                    {
                        Fail("Positional arguments must come before named arguments.", token);
                        return;
                    }
                    call.Args.Add(Expression());
                }
                if (!Peek().IsOp(","))
                    break;
                Advance();
            }
            ExpectOp(")", "to close the argument list");
        }

        private TaleExpr ArrayLiteral(TaleToken open)
        {
            var array = new TaleExpr(TaleExprKind.Array, open.Line, open.Column);
            while (!_failed && !Peek().IsOp("]"))
            {
                array.Operands.Add(Expression());
                if (!Peek().IsOp(","))
                    break;
                Advance();
            }
            ExpectOp("]", "to close the array");
            return array;
        }

        private TaleExpr DictionaryLiteral(TaleToken open)
        {
            var dictionary = new TaleExpr(TaleExprKind.Dictionary, open.Line, open.Column);
            while (!_failed && !Peek().IsOp("}"))
            {
                var token = Peek();
                if (token.Type == TaleTokenType.Identifier && PeekAt(1).IsOp("="))
                {
                    Advance();
                    Advance();
                    dictionary.Operands.Add(LiteralValue(token, token.Value));
                }
                else
                {
                    dictionary.Operands.Add(Expression());
                    ExpectOp(":", "after the dictionary key");
                }
                dictionary.Operands.Add(Expression());
                if (!Peek().IsOp(","))
                    break;
                Advance();
            }
            ExpectOp("}", "to close the dictionary");
            return dictionary;
        }

        private TaleExpr Literal(TaleToken token)
        {
            return LiteralValue(token, token.Value);
        }

        private TaleExpr LiteralValue(TaleToken token, object value)
        {
            var literal = new TaleExpr(TaleExprKind.Literal, token.Line, token.Column);
            literal.Value = value;
            return literal;
        }

        // --- Token helpers ----------------------------------------------------

        private TaleToken Peek()
        {
            return _index < _tokens.Count ? _tokens[_index] : _endToken;
        }

        private TaleToken PeekAt(int offset)
        {
            int i = _index + offset;
            return i < _tokens.Count ? _tokens[i] : _endToken;
        }

        private TaleToken Advance()
        {
            var token = Peek();
            if (_index < _tokens.Count)
                _index += 1;
            return token;
        }

        private bool AtEnd()
        {
            return _index >= _tokens.Count;
        }

        private bool ExpectOp(string op, string context)
        {
            if (_failed)
                return false;
            if (Peek().IsOp(op))
            {
                Advance();
                return true;
            }
            Fail("Expected '" + op + "' " + context + ", found " + Describe(Peek()) + ".");
            return false;
        }

        private bool ExpectKeyword(string word, string context)
        {
            if (_failed)
                return false;
            if (Peek().IsKeyword(word))
            {
                Advance();
                return true;
            }
            Fail("Expected '" + word + "' " + context + ", found " + Describe(Peek()) + ".");
            return false;
        }

        private string ExpectIdentifier(string what)
        {
            if (_failed)
                return "";
            var token = Peek();
            if (token.Type == TaleTokenType.Identifier)
            {
                Advance();
                return token.StringValue;
            }
            if (token.Type == TaleTokenType.Keyword)
                Fail("'" + token.Text + "' is a reserved word and can't be used as a " + what + ".");
            else
                Fail("Expected a " + what + ", found " + Describe(token) + ".");
            return "";
        }

        private static string Describe(TaleToken token)
        {
            if (token.Type == TaleTokenType.Newline)
                return "the end of the line";
            return "'" + token.Text + "'";
        }

        private void Fail(string message, TaleToken token = null)
        {
            if (_failed)
                return;
            _failed = true;
            _failMessage = message;
            _failToken = token ?? Peek();
        }

        private void Error(string message, int line, int column)
        {
            _doc.Diagnostics.Add(new TaleDiagnostic(TaleSeverity.Error, message, line, column));
        }
    }
}
