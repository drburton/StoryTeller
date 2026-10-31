using System;
using System.Collections.Generic;
using System.Globalization;

namespace TaleScript
{
    /// <summary>
    /// Finds mistakes in a parsed tale that the parser cannot see: unknown names,
    /// statements in the wrong place, wrong arguments, misused annotations, and
    /// code that can never run.
    /// </summary>
    public class TaleChecker
    {
        private const string MoodParameter = "mood_name";

        /// <summary>How each call expression was resolved, for the compiler: "beat", "tale_beat", "action", "function", "constructor", "exposed", "method", or "choose".</summary>
        public Dictionary<TaleExpr, string> CallKinds = new Dictionary<TaleExpr, string>();

        private TaleDocument _doc;
        private TaleCheckContext _context;
        private List<TaleDiagnostic> _diagnostics = new List<TaleDiagnostic>();
        private readonly OrderedMap<TaleNode> _storyVars = new OrderedMap<TaleNode>();
        private readonly OrderedMap<TaleNode> _beats = new OrderedMap<TaleNode>();
        private readonly List<Dictionary<string, string>> _scopes = new List<Dictionary<string, string>>();
        private readonly Dictionary<string, int> _lineIds = new Dictionary<string, int>();

        /// <summary>Checks doc and returns the problems found, sorted by position.</summary>
        public static List<TaleDiagnostic> Check(TaleDocument doc, TaleCheckContext context = null)
        {
            return new TaleChecker().Run(doc, context);
        }

        public List<TaleDiagnostic> Run(TaleDocument doc, TaleCheckContext context = null)
        {
            _doc = doc;
            _context = context ?? new TaleCheckContext();
            _diagnostics = new List<TaleDiagnostic>();
            _storyVars.Clear();
            _beats.Clear();
            _scopes.Clear();
            _lineIds.Clear();
            CallKinds.Clear();
            CollectDeclarations();
            CheckTopLevel();
            // Stable insertion sort by line, then column.
            for (int i = 1; i < _diagnostics.Count; i++)
            {
                var item = _diagnostics[i];
                int j = i - 1;
                while (j >= 0 && Before(item, _diagnostics[j]))
                {
                    _diagnostics[j + 1] = _diagnostics[j];
                    j--;
                }
                _diagnostics[j + 1] = item;
            }
            return _diagnostics;
        }

        private static bool Before(TaleDiagnostic a, TaleDiagnostic b)
        {
            return a.Line < b.Line || (a.Line == b.Line && a.Column < b.Column);
        }

        private static string Fmt(string format, params object[] args)
        {
            return string.Format(CultureInfo.InvariantCulture, format, args);
        }

        // --- Top level ---------------------------------------------------------

        private void CollectDeclarations()
        {
            foreach (var node in _doc.Statements)
            {
                if (node.Kind != TaleNodeKind.Var && node.Kind != TaleNodeKind.Const && node.Kind != TaleNodeKind.Beat)
                    continue;
                TaleNode previous;
                if (!_storyVars.TryGetValue(node.Name, out previous))
                    _beats.TryGetValue(node.Name, out previous);
                if (previous != null)
                    ErrorNode(node, Fmt("'{0}' is already declared on line {1}.", node.Name, previous.LineStart));
                else if (node.Kind == TaleNodeKind.Beat)
                    _beats[node.Name] = node;
                else
                    _storyVars[node.Name] = node;
            }
        }

        private void CheckTopLevel()
        {
            var pending = new List<TaleExpr>();
            bool hasTitle = false;
            foreach (var node in _doc.Statements)
            {
                if (node.IsTrivia() || node.Kind == TaleNodeKind.Error)
                    continue;
                if (node.Kind == TaleNodeKind.Annotation)
                {
                    foreach (var annotation in node.Annotations)
                    {
                        if (annotation.Name == "title")
                        {
                            if (hasTitle)
                                ErrorExpr(annotation, "A tale can only have one @title.");
                            ExpectOneString(annotation);
                            hasTitle = true;
                        }
                        else
                        {
                            pending.Add(annotation);
                        }
                    }
                    continue;
                }
                CheckAnnotations(Merge(pending, node.Annotations), node, true);
                pending.Clear();
                switch (node.Kind)
                {
                    case TaleNodeKind.Var:
                    case TaleNodeKind.Const:
                        if (node.Expr != null)
                            CheckExpr(node.Expr);
                        break;
                    case TaleNodeKind.Beat:
                        CheckBlock(node.Body, false);
                        break;
                }
            }
            ReportUnusedAnnotations(pending);
        }

        // --- Blocks and statements ---------------------------------------------

        private void CheckBlock(List<TaleNode> nodes, bool inLoop)
        {
            _scopes.Add(new Dictionary<string, string>());
            var pending = new List<TaleExpr>();
            TaleNodeKind? previous = null;
            bool leftBlock = false;
            bool warnedUnreachable = false;
            foreach (var node in nodes)
            {
                if (node.IsTrivia())
                    continue;
                if (node.Kind == TaleNodeKind.Annotation)
                {
                    pending.AddRange(node.Annotations);
                    previous = node.Kind;
                    continue;
                }
                if (node.Kind == TaleNodeKind.Error)
                {
                    pending.Clear();
                    previous = node.Kind;
                    continue;
                }
                CheckAnnotations(Merge(pending, node.Annotations), node, false);
                pending.Clear();
                if (leftBlock && !warnedUnreachable)
                {
                    WarnNode(node, "This line can never run, because the line before it always leaves the block.");
                    warnedUnreachable = true;
                }
                if ((node.Kind == TaleNodeKind.Elif || node.Kind == TaleNodeKind.Else)
                    && previous != TaleNodeKind.If && previous != TaleNodeKind.Elif && previous != TaleNodeKind.Error)
                {
                    ErrorNode(node, Fmt("'{0}' must follow an 'if' or 'elif' block.", node.Kind == TaleNodeKind.Elif ? "elif" : "else"));
                }
                CheckStatement(node, inLoop);
                previous = node.Kind;
                if (node.Kind == TaleNodeKind.Jump || node.Kind == TaleNodeKind.Return
                    || node.Kind == TaleNodeKind.Break || node.Kind == TaleNodeKind.Continue)
                    leftBlock = true;
            }
            ReportUnusedAnnotations(pending);
            _scopes.RemoveAt(_scopes.Count - 1);
        }

        private void CheckStatement(TaleNode node, bool inLoop)
        {
            switch (node.Kind)
            {
                case TaleNodeKind.Var:
                case TaleNodeKind.Const:
                    if (node.Expr != null)
                        CheckExpr(node.Expr);
                    Declare(node);
                    break;
                case TaleNodeKind.Dialogue:
                    CheckSpeaker(node);
                    CheckText(node.Expr);
                    break;
                case TaleNodeKind.Narration:
                    CheckText(node.Expr);
                    break;
                case TaleNodeKind.Jump:
                    CheckJump(node);
                    break;
                case TaleNodeKind.Expression:
                    CheckExpr(node.Expr);
                    if (node.Expr.Kind != TaleExprKind.Call && node.Expr.Kind != TaleExprKind.Await)
                        WarnNode(node, "This expression has no effect.");
                    break;
                case TaleNodeKind.Assign:
                {
                    CheckAssignTarget(node);
                    CheckExpr(node.Expr);
                    var target = node.Target;
                    if (target.Kind == TaleExprKind.Attribute && target.Name == "mood" && target.Operands[0].Kind == TaleExprKind.Identifier)
                        CheckCastMood(target.Operands[0].Name, node.Expr, null);
                    break;
                }
                case TaleNodeKind.If:
                case TaleNodeKind.Elif:
                    CheckExpr(node.Expr);
                    CheckBlock(node.Body, inLoop);
                    break;
                case TaleNodeKind.While:
                    CheckExpr(node.Expr);
                    CheckBlock(node.Body, true);
                    break;
                case TaleNodeKind.Else:
                case TaleNodeKind.Timeout:
                    CheckBlock(node.Body, inLoop);
                    break;
                case TaleNodeKind.For:
                    CheckExpr(node.Expr);
                    _scopes.Add(new Dictionary<string, string> { { node.Name, "var" } });
                    CheckBlock(node.Body, true);
                    _scopes.RemoveAt(_scopes.Count - 1);
                    break;
                case TaleNodeKind.Match:
                    CheckExpr(node.Expr);
                    CheckMatch(node, inLoop);
                    break;
                case TaleNodeKind.MatchBranch:
                    foreach (var pattern in node.Patterns)
                        CheckPattern(pattern);
                    if (node.Condition != null)
                        CheckExpr(node.Condition);
                    CheckBlock(node.Body, inLoop);
                    break;
                case TaleNodeKind.Choose:
                    CheckChoose(node, inLoop);
                    break;
                case TaleNodeKind.Option:
                    CheckText(node.Expr);
                    if (node.Condition != null)
                        CheckExpr(node.Condition);
                    CheckBlock(node.Body, inLoop);
                    break;
                case TaleNodeKind.Return:
                    if (node.Expr != null)
                        ErrorNode(node, "Beats don't return values. Use 'return' on its own.");
                    break;
                case TaleNodeKind.Break:
                case TaleNodeKind.Continue:
                    if (!inLoop)
                        ErrorNode(node, Fmt("'{0}' can only be used inside a loop.", node.Kind == TaleNodeKind.Break ? "break" : "continue"));
                    break;
                case TaleNodeKind.Beat:
                    break; // The parser already reports nested beats.
            }
        }

        private void Declare(TaleNode node)
        {
            var scope = _scopes[_scopes.Count - 1];
            if (scope.ContainsKey(node.Name))
            {
                ErrorNode(node, Fmt("'{0}' is already declared in this block.", node.Name));
                return;
            }
            for (int i = _scopes.Count - 2; i >= 0; i--)
            {
                if (_scopes[i].ContainsKey(node.Name))
                {
                    WarnNode(node, Fmt("'{0}' hides a variable with the same name declared earlier in the beat.", node.Name));
                    break;
                }
            }
            if (_storyVars.Has(node.Name))
                WarnNode(node, Fmt("'{0}' hides the story variable with the same name.", node.Name));
            scope[node.Name] = node.Kind == TaleNodeKind.Const ? "const" : "var";
        }

        /// <summary>Warns when mood is a face the cast member id doesn't have.</summary>
        private void CheckCastMood(string id, TaleExpr mood, TaleExpr anchor)
        {
            if (mood == null || mood.Kind != TaleExprKind.Literal)
                return;
            var value = mood.Value as string;
            if (value == null || value.Contains("{") || value.Length == 0)
                return;
            if (Lookup(id) != "cast")
                return;
            var moods = _context.Cast[id];
            if (moods.Count > 0 && !moods.Contains(value))
                WarnExpr(mood, Fmt("Cast member '{0}' has no mood '{1}'.", id, value), anchor);
        }

        private void CheckSpeaker(TaleNode node)
        {
            List<string> moods;
            if (_context.Cast.TryGetValue(node.Name, out moods))
            {
                if (node.Mood.Length > 0 && moods.Count > 0 && !moods.Contains(node.Mood))
                    WarnNode(node, Fmt("Cast member '{0}' has no mood '{1}'.", node.Name, node.Mood));
                return;
            }
            if (Lookup(node.Name) == "const")
            {
                if (node.Mood.Length > 0)
                    WarnNode(node, Fmt("Only cast members have moods; '{0}' is a constant.", node.Name));
                return;
            }
            ErrorNode(node, Fmt("Unknown speaker '{0}'. Use a cast member id or a const holding the speaker's name.", node.Name));
        }

        private void CheckText(TaleExpr text)
        {
            var result = TaleText.SplitInterpolation((string)text.Value);
            foreach (var message in result.Errors)
                ErrorExpr(text, message);
            foreach (var part in result.Parts)
            {
                var expr = part as TaleExpr;
                if (expr != null)
                {
                    CheckExpr(expr, text);
                    continue;
                }
                var tag = part as TaleText.TagPart;
                if (tag != null)
                    CheckExpr(tag.Expr, text);
            }
        }

        private void CheckJump(TaleNode node)
        {
            var parts = node.JumpTarget.Split('.');
            if (parts.Length == 1)
            {
                if (!_beats.Has(parts[0]))
                    ErrorNode(node, Fmt("Unknown beat '{0}'.", parts[0]));
                return;
            }
            string tale = parts[0];
            TaleInfo info;
            if (tale == _context.TaleName)
            {
                if (!_beats.Has(parts[1]))
                    ErrorNode(node, Fmt("Unknown beat '{0}'.", parts[1]));
            }
            else if (!_context.Tales.TryGetValue(tale, out info))
            {
                ErrorNode(node, Fmt("Unknown tale '{0}'.", tale));
            }
            else if (!info.Beats.Contains(parts[1]))
            {
                ErrorNode(node, Fmt("Tale '{0}' has no beat '{1}'.", tale, parts[1]));
            }
        }

        private void CheckAssignTarget(TaleNode node)
        {
            var target = node.Target;
            if (target.Kind != TaleExprKind.Identifier)
            {
                CheckExpr(target);
                return;
            }
            string kind = Lookup(target.Name);
            switch (kind)
            {
                case "var":
                    break;
                case "const":
                case "builtin_const":
                    ErrorExpr(target, Fmt("Can't assign to the constant '{0}'.", target.Name));
                    break;
                case "":
                    ErrorExpr(target, Fmt("Unknown variable '{0}'. Declare it first with 'var {0}'.", target.Name));
                    break;
                default:
                    ErrorExpr(target, Fmt("Can't assign to '{0}', because it is {1}.", target.Name, DescribeKind(kind)));
                    break;
            }
        }

        private void CheckMatch(TaleNode node, bool inLoop)
        {
            bool wildcardSeen = false;
            bool warned = false;
            foreach (var branch in node.Body)
            {
                if (branch.Kind != TaleNodeKind.MatchBranch)
                    continue;
                if (wildcardSeen && !warned)
                {
                    WarnNode(branch, "This branch can never match, because an earlier '_' branch matches everything.");
                    warned = true;
                }
                foreach (var pattern in branch.Patterns)
                {
                    if (pattern.Kind == TaleExprKind.Identifier && pattern.Name == "_" && branch.Condition == null)
                        wildcardSeen = true;
                }
            }
            CheckBlock(node.Body, inLoop);
        }

        private void CheckPattern(TaleExpr pattern)
        {
            if (pattern.Kind == TaleExprKind.Identifier && pattern.Name == "_")
                return;
            if (pattern.Kind != TaleExprKind.Literal && pattern.Kind != TaleExprKind.Identifier
                && pattern.Kind != TaleExprKind.Attribute && pattern.Kind != TaleExprKind.Unary)
            {
                ErrorExpr(pattern, "Match patterns must be literals, constants, or '_'.");
                return;
            }
            CheckExpr(pattern);
        }

        private void CheckChoose(TaleNode node, bool inLoop)
        {
            bool hasTimeoutArgument = false;
            if (node.Expr != null)
            {
                CallKinds[node.Expr] = "choose";
                if (node.Expr.Args.Count > 0)
                    ErrorExpr(node.Expr.Args[0], "choose only takes named arguments, e.g. choose(style = \"list\").");
                foreach (var key in node.Expr.NamedArgs.Keys)
                {
                    CheckExpr(node.Expr.NamedArgs[key]);
                    if (key == "timeout")
                        hasTimeoutArgument = true;
                }
            }
            int options = 0;
            int timeouts = 0;
            foreach (var child in node.Body)
            {
                if (child.Kind == TaleNodeKind.Option)
                {
                    options++;
                }
                else if (child.Kind == TaleNodeKind.Timeout)
                {
                    timeouts++;
                    if (timeouts == 2)
                        ErrorNode(child, "A 'choose' block can only have one 'timeout:' branch.");
                    if (!hasTimeoutArgument && timeouts == 1)
                        WarnNode(child, "'timeout:' only runs when the choose has a timeout, e.g. choose(timeout = 5.0):");
                }
            }
            if (options == 0)
                ErrorNode(node, "A 'choose' block needs at least one option.");
            CheckBlock(node.Body, inLoop);
        }

        private void CheckAnnotations(List<TaleExpr> annotations, TaleNode node, bool topLevel)
        {
            var seen = new HashSet<string>();
            foreach (var annotation in annotations)
            {
                if (seen.Contains(annotation.Name))
                {
                    ErrorExpr(annotation, Fmt("@{0} is used twice on the same line.", annotation.Name));
                    continue;
                }
                seen.Add(annotation.Name);
                var kind = node.Kind;
                switch (annotation.Name)
                {
                    case "title":
                        ErrorExpr(annotation, "@title belongs on its own line at the top level of the tale.");
                        break;
                    case "global":
                        if (!(topLevel && kind == TaleNodeKind.Var))
                            ErrorExpr(annotation, "@global only applies to a 'var' at the top level of the tale.");
                        ExpectNoArguments(annotation);
                        break;
                    case "once":
                    case "show_disabled":
                        if (kind != TaleNodeKind.Option)
                            ErrorExpr(annotation, Fmt("@{0} only applies to choice options.", annotation.Name));
                        ExpectNoArguments(annotation);
                        break;
                    case "id":
                        if (kind != TaleNodeKind.Dialogue && kind != TaleNodeKind.Narration && kind != TaleNodeKind.Option)
                            ErrorExpr(annotation, "@id only applies to dialogue, narration, and choice options.");
                        if (ExpectOneString(annotation))
                        {
                            string id = (string)annotation.Args[0].Value;
                            int existing;
                            if (_lineIds.TryGetValue(id, out existing))
                                ErrorExpr(annotation, Fmt("Line id '{0}' is already used on line {1}.", id, existing));
                            else
                                _lineIds[id] = annotation.Line;
                        }
                        break;
                    case "voice":
                        if (kind != TaleNodeKind.Dialogue && kind != TaleNodeKind.Narration)
                            ErrorExpr(annotation, "@voice only applies to dialogue and narration lines.");
                        ExpectOneString(annotation);
                        break;
                    case "no_rewind":
                        if (topLevel)
                            ErrorExpr(annotation, "@no_rewind only applies to lines inside a beat.");
                        ExpectNoArguments(annotation);
                        break;
                    case "no_wait":
                        if (kind != TaleNodeKind.Dialogue && kind != TaleNodeKind.Narration && kind != TaleNodeKind.Choose)
                            ErrorExpr(annotation, "@no_wait only applies to dialogue, narration, and choose.");
                        ExpectNoArguments(annotation);
                        break;
                    case "skip_safe":
                        if (kind != TaleNodeKind.Beat)
                            ErrorExpr(annotation, "@skip_safe only applies to beats.");
                        ExpectNoArguments(annotation);
                        break;
                    case "heading":
                        if (kind != TaleNodeKind.Beat)
                            ErrorExpr(annotation, "@heading only applies to beats.");
                        ExpectOneString(annotation);
                        break;
                    case "picture":
                        if (kind != TaleNodeKind.Option)
                            ErrorExpr(annotation, "@picture only applies to choice options.");
                        ExpectOneString(annotation);
                        break;
                    default:
                        ErrorExpr(annotation, Fmt("Unknown annotation '@{0}'.", annotation.Name));
                        break;
                }
            }
        }

        private void ExpectNoArguments(TaleExpr annotation)
        {
            if (annotation.Args.Count > 0 || annotation.NamedArgs.Count > 0)
                ErrorExpr(annotation, Fmt("@{0} takes no arguments.", annotation.Name));
        }

        private bool ExpectOneString(TaleExpr annotation)
        {
            bool valid = annotation.Args.Count == 1 && annotation.NamedArgs.Count == 0
                && annotation.Args[0].Kind == TaleExprKind.Literal && annotation.Args[0].Value is string;
            if (!valid)
                ErrorExpr(annotation, Fmt("@{0} needs one text argument, e.g. @{0}(\"...\").", annotation.Name));
            return valid;
        }

        private void ReportUnusedAnnotations(List<TaleExpr> pending)
        {
            foreach (var annotation in pending)
                ErrorExpr(annotation, Fmt("@{0} is not followed by a line it can apply to.", annotation.Name));
        }

        // --- Expressions -------------------------------------------------------

        /// <summary>Checks names and calls in expr. anchor is the expression whose position is reported, used for values interpolated into text.</summary>
        private void CheckExpr(TaleExpr expr, TaleExpr anchor = null)
        {
            switch (expr.Kind)
            {
                case TaleExprKind.Literal:
                    break;
                case TaleExprKind.Identifier:
                    CheckValueName(expr, anchor);
                    break;
                case TaleExprKind.Call:
                    CheckCall(expr, anchor);
                    break;
                case TaleExprKind.Attribute:
                {
                    var baseExpr = expr.Operands[0];
                    string baseKind = baseExpr.Kind == TaleExprKind.Identifier ? Lookup(baseExpr.Name) : "";
                    if (baseKind == "tale")
                    {
                        CheckTaleMember(baseExpr.Name, expr.Name, false, expr, anchor);
                    }
                    else if (baseKind == "cast")
                    {
                        if (!_context.GetCastMembers(baseExpr.Name).Contains(expr.Name))
                            ErrorExpr(expr, Fmt("Cast member '{0}' has no '{1}'. Its fields come from the cast profile.", baseExpr.Name, expr.Name), anchor);
                    }
                    else if (baseKind != "constructor")
                    {
                        CheckExpr(baseExpr, anchor);
                    }
                    break;
                }
                default:
                    foreach (var operand in expr.Operands)
                        CheckExpr(operand, anchor);
                    break;
            }
        }

        private void CheckValueName(TaleExpr expr, TaleExpr anchor)
        {
            string kind = Lookup(expr.Name);
            switch (kind)
            {
                case "":
                    ErrorExpr(expr, Fmt("Unknown name '{0}'.", expr.Name), anchor);
                    break;
                case "beat":
                    ErrorExpr(expr, Fmt("'{0}' is a beat. Call it with {0}() or use 'jump {0}'.", expr.Name), anchor);
                    break;
                case "action":
                case "function":
                case "constructor":
                    ErrorExpr(expr, Fmt("'{0}' is {1}. Call it with {0}(...).", expr.Name, DescribeKind(kind)), anchor);
                    break;
                case "tale":
                    ErrorExpr(expr, Fmt("'{0}' is a tale. Refer to one of its beats or variables, e.g. {0}.start.", expr.Name), anchor);
                    break;
            }
        }

        private void CheckCall(TaleExpr expr, TaleExpr anchor)
        {
            foreach (var argument in expr.Args)
                CheckExpr(argument, anchor);
            foreach (var key in expr.NamedArgs.Keys)
                CheckExpr(expr.NamedArgs[key], anchor);

            var callee = expr.Operands[0];
            if (callee.Kind == TaleExprKind.Attribute && callee.Operands[0].Kind == TaleExprKind.Identifier
                && Lookup(callee.Operands[0].Name) == "tale")
            {
                CallKinds[expr] = "tale_beat";
                CheckTaleMember(callee.Operands[0].Name, callee.Name, true, expr, anchor);
                ExpectNoCallArguments(expr, anchor);
                return;
            }
            if (callee.Kind != TaleExprKind.Identifier)
            {
                CallKinds[expr] = "method";
                CheckExpr(callee, anchor);
                if (callee.Kind == TaleExprKind.Attribute && callee.Operands[0].Kind == TaleExprKind.Identifier && callee.Name == "enter")
                {
                    TaleExpr moodArg = null;
                    if (expr.Args.Count > 0) moodArg = expr.Args[0];
                    else expr.NamedArgs.TryGetValue(MoodParameter, out moodArg);
                    CheckCastMood(callee.Operands[0].Name, moodArg, anchor);
                }
                return;
            }

            string kind = Lookup(callee.Name);
            switch (kind)
            {
                case "beat":
                    CallKinds[expr] = "beat";
                    ExpectNoCallArguments(expr, anchor);
                    break;
                case "action":
                    CallKinds[expr] = "action";
                    CheckActionArguments(expr, callee.Name, anchor);
                    break;
                case "function":
                case "constructor":
                    CallKinds[expr] = kind;
                    if (expr.NamedArgs.Count > 0)
                        ErrorExpr(expr, Fmt("'{0}' does not take named arguments.", callee.Name), anchor);
                    break;
                case "exposed":
                    CallKinds[expr] = "exposed";
                    break;
                case "":
                    ErrorExpr(callee, Fmt("Unknown action or beat '{0}'.", callee.Name), anchor);
                    break;
                default:
                    ErrorExpr(callee, Fmt("'{0}' is {1} and can't be called.", callee.Name, DescribeKind(kind)), anchor);
                    break;
            }
        }

        private void ExpectNoCallArguments(TaleExpr expr, TaleExpr anchor)
        {
            if (expr.Args.Count > 0 || expr.NamedArgs.Count > 0)
                ErrorExpr(expr, "Beats don't take arguments.", anchor);
        }

        private void CheckActionArguments(TaleExpr expr, string action, TaleExpr anchor)
        {
            var signature = _context.Actions[action];
            if (signature == null)
                return;
            var parameters = signature.Params;
            int required = signature.Required;
            if (expr.Args.Count > parameters.Count)
                ErrorExpr(expr, Fmt("'{0}' takes at most {1} arguments, but {2} were given.", action, parameters.Count, expr.Args.Count), anchor);
            foreach (var key in expr.NamedArgs.Keys)
            {
                int index = parameters.IndexOf(key);
                if (index == -1)
                    ErrorExpr(expr.NamedArgs[key], Fmt("'{0}' has no argument named '{1}'.", action, key), anchor);
                else if (index < expr.Args.Count)
                    ErrorExpr(expr.NamedArgs[key], Fmt("Argument '{0}' is already given by position.", key), anchor);
            }
            for (int i = expr.Args.Count; i < Math.Min(required, parameters.Count); i++)
            {
                if (!expr.NamedArgs.Has(parameters[i]))
                    ErrorExpr(expr, Fmt("'{0}' needs the argument '{1}'.", action, parameters[i]), anchor);
            }
            for (int i = 0; i < parameters.Count; i++)
            {
                Func<string, string> check;
                if (!_context.AssetChecks.TryGetValue(action + "." + parameters[i], out check) || check == null)
                    continue;
                TaleExpr argument = null;
                if (i < expr.Args.Count) argument = expr.Args[i];
                else expr.NamedArgs.TryGetValue(parameters[i], out argument);
                var text = argument != null && argument.Kind == TaleExprKind.Literal ? argument.Value as string : null;
                if (text != null && !text.Contains("{"))
                {
                    string problem = check(text);
                    if (!string.IsNullOrEmpty(problem))
                        WarnExpr(argument, problem, anchor);
                }
            }
        }

        private void CheckTaleMember(string tale, string member, bool isCall, TaleExpr expr, TaleExpr anchor)
        {
            IList<string> beats;
            IList<string> vars;
            if (tale == _context.TaleName)
            {
                beats = new List<string>(_beats.Keys);
                vars = new List<string>(_storyVars.Keys);
            }
            else
            {
                beats = _context.Tales[tale].Beats;
                vars = _context.Tales[tale].Vars;
            }
            if (isCall && !beats.Contains(member))
                ErrorExpr(expr, Fmt("Tale '{0}' has no beat '{1}'.", tale, member), anchor);
            else if (!isCall && !vars.Contains(member))
                ErrorExpr(expr, Fmt("Tale '{0}' has no variable '{1}'.", tale, member), anchor);
        }

        /// <summary>
        /// Returns what name refers to: "var", "const", "builtin_const", "cast",
        /// "exposed", "beat", "action", "function", "constructor", "tale", or ""
        /// when unknown. Inner scopes win over outer ones.
        /// </summary>
        private string Lookup(string name)
        {
            for (int i = _scopes.Count - 1; i >= 0; i--)
            {
                string kind;
                if (_scopes[i].TryGetValue(name, out kind))
                    return kind;
            }
            TaleNode storyVar;
            if (_storyVars.TryGetValue(name, out storyVar))
                return storyVar.Kind == TaleNodeKind.Const ? "const" : "var";
            if (Array.IndexOf(TaleCheckContext.BuiltinConstants, name) >= 0) return "builtin_const";
            if (_context.Cast.Has(name)) return "cast";
            if (_context.Exposed.Has(name)) return "exposed";
            if (_beats.Has(name)) return "beat";
            if (_context.Actions.Has(name)) return "action";
            if (Array.IndexOf(TaleCheckContext.BuiltinFunctions, name) >= 0) return "function";
            if (Array.IndexOf(TaleCheckContext.Constructors, name) >= 0) return "constructor";
            if (name == _context.TaleName || _context.Tales.Has(name)) return "tale";
            return "";
        }

        private static string DescribeKind(string kind)
        {
            switch (kind)
            {
                case "cast": return "a cast member";
                case "exposed": return "an object from game code";
                case "beat": return "a beat";
                case "action": return "an action";
                case "function": return "a built-in function";
                case "constructor": return "a type";
                case "tale": return "a tale";
                case "var": return "a variable";
            }
            return "a constant";
        }

        // --- Reporting ---------------------------------------------------------

        private static List<TaleExpr> Merge(List<TaleExpr> first, List<TaleExpr> second)
        {
            var merged = new List<TaleExpr>(first);
            merged.AddRange(second);
            return merged;
        }

        private void ErrorNode(TaleNode node, string message)
        {
            Add(TaleSeverity.Error, message, node.LineStart, node.Indent.Length + 1);
        }

        private void WarnNode(TaleNode node, string message)
        {
            Add(TaleSeverity.Warning, message, node.LineStart, node.Indent.Length + 1);
        }

        private void WarnExpr(TaleExpr expr, string message, TaleExpr anchor = null)
        {
            var at = anchor ?? expr;
            Add(TaleSeverity.Warning, message, at.Line, at.Column);
        }

        private void ErrorExpr(TaleExpr expr, string message, TaleExpr anchor = null)
        {
            var at = anchor ?? expr;
            Add(TaleSeverity.Error, message, at.Line, at.Column);
        }

        private void Add(TaleSeverity severity, string message, int line, int column)
        {
            _diagnostics.Add(new TaleDiagnostic(severity, message, line, column));
        }
    }
}
