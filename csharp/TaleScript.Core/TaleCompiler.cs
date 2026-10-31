using System.Collections.Generic;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace TaleScript
{
    /// <summary>The result of <see cref="TaleCompiler.Build"/>.</summary>
    public class TaleBuildResult
    {
        /// <summary>The compiled tale, or null when there are errors.</summary>
        public Tale Tale;
        public List<TaleDiagnostic> Diagnostics = new List<TaleDiagnostic>();
    }

    /// <summary>
    /// Turns a parsed and checked <see cref="TaleDocument"/> into a <see cref="Tale"/>.
    /// Control flow (if, loops, match, choose) becomes jumps between instruction
    /// indices, so the director only needs a position and a call stack to run a tale.
    /// </summary>
    public class TaleCompiler
    {
        private class Loop
        {
            public int Continue;
            public List<int> Breaks = new List<int>();
        }

        private Tale _tale;
        private Dictionary<TaleExpr, string> _callKinds;
        private string _beat = "";
        private bool _skipSafe;
        private int _loopCounter;
        private readonly List<Loop> _loops = new List<Loop>();
        private readonly HashSet<string> _usedIds = new HashSet<string>();

        /// <summary>
        /// Compiles doc. callKinds comes from <see cref="TaleChecker.CallKinds"/> and tells which
        /// calls are beat calls. Returns null if the document has parse errors.
        /// </summary>
        public static Tale Compile(TaleDocument doc, string taleName, Dictionary<TaleExpr, string> callKinds = null)
        {
            if (doc.HasErrors()) return null;
            return new TaleCompiler().CompileDocument(doc, taleName, callKinds ?? new Dictionary<TaleExpr, string>());
        }

        /// <summary>Parses, checks, and compiles source in one step. The tale is null when there are errors.</summary>
        public static TaleBuildResult Build(string source, string taleName, TaleCheckContext context = null, string path = "")
        {
            var result = new TaleBuildResult();
            var doc = TaleParser.Parse(source, path);
            result.Diagnostics.AddRange(doc.Diagnostics);
            if (doc.HasErrors()) return result;
            if (context == null) context = new TaleCheckContext();
            if (string.IsNullOrEmpty(context.TaleName)) context.TaleName = taleName;
            var checker = new TaleChecker();
            var problems = checker.Run(doc, context);
            result.Diagnostics.AddRange(problems);
            foreach (var problem in problems)
                if (problem.IsError()) return result;
            var tale = Compile(doc, taleName, checker.CallKinds);
            tale.SourcePath = path;
            result.Tale = tale;
            return result;
        }

        /// <summary>Compiles text with {expr} interpolation, such as a translated line, into text parts.</summary>
        public static TaleText.SplitResult CompileText(string text)
        {
            return TaleText.SplitInterpolation(text);
        }

        private Tale CompileDocument(TaleDocument doc, string taleName, Dictionary<TaleExpr, string> callKinds)
        {
            _tale = new Tale { TaleName = taleName, SourcePath = doc.Path };
            _callKinds = callKinds;
            var pending = new List<TaleExpr>();
            foreach (var node in doc.Statements)
            {
                switch (node.Kind)
                {
                    case TaleNodeKind.Annotation:
                        foreach (var annotation in node.Annotations)
                        {
                            if (annotation.Name == "title" && annotation.Args.Count == 1)
                                _tale.Title = annotation.Args[0].Value as string ?? "";
                            else
                                pending.Add(annotation);
                        }
                        break;
                    case TaleNodeKind.Var:
                    case TaleNodeKind.Const:
                        _tale.Variables.Add(new TaleVariable
                        {
                            Name = node.Name,
                            IsGlobal = HasAnnotation(pending, node, "global"),
                            IsConst = node.Kind == TaleNodeKind.Const,
                            Value = node.Expr,
                            Line = node.LineStart,
                        });
                        pending.Clear();
                        break;
                    case TaleNodeKind.Beat:
                    {
                        _beat = node.Name;
                        _skipSafe = HasAnnotation(pending, node, "skip_safe");
                        var beatAnnotations = new List<TaleExpr>(pending);
                        beatAnnotations.AddRange(node.Annotations);
                        string heading = AnnotationText(beatAnnotations, "heading");
                        if (heading.Length > 0) _tale.Headings[node.Name] = heading;
                        _tale.Beats[node.Name] = _tale.Instructions.Count;
                        Block(node.Body);
                        Emit(new TaleInstruction { Op = TaleOp.End }, node.LineEnd);
                        pending.Clear();
                        break;
                    }
                }
            }
            return _tale;
        }

        // --- Statements ---------------------------------------------------------

        private void Block(List<TaleNode> nodes)
        {
            var pending = new List<TaleExpr>();
            int i = 0;
            while (i < nodes.Count)
            {
                var node = nodes[i];
                i++;
                if (node.IsTrivia() || node.Kind == TaleNodeKind.Pass) continue;
                if (node.Kind == TaleNodeKind.Annotation)
                {
                    pending.AddRange(node.Annotations);
                    continue;
                }
                if (node.Kind == TaleNodeKind.If)
                {
                    var chain = new List<TaleNode> { node };
                    while (i < nodes.Count)
                    {
                        var next = nodes[i];
                        if (next.IsTrivia())
                        {
                            i++;
                        }
                        else if (next.Kind == TaleNodeKind.Elif || next.Kind == TaleNodeKind.Else)
                        {
                            chain.Add(next);
                            i++;
                            if (next.Kind == TaleNodeKind.Else) break;
                        }
                        else
                        {
                            break;
                        }
                    }
                    IfChain(chain, pending);
                }
                else
                {
                    Statement(node, pending);
                }
                pending.Clear();
            }
        }

        private void Statement(TaleNode node, List<TaleExpr> pending)
        {
            var annotations = new List<TaleExpr>(pending);
            annotations.AddRange(node.Annotations);
            int index = _tale.Instructions.Count;
            switch (node.Kind)
            {
                case TaleNodeKind.Dialogue:
                case TaleNodeKind.Narration:
                {
                    string text = (string)node.Expr.Value;
                    Emit(new TaleInstruction
                    {
                        Op = TaleOp.Say,
                        Speaker = node.Kind == TaleNodeKind.Dialogue ? node.Name : "",
                        Mood = node.Mood,
                        Text = Text(text),
                        Id = LineId(annotations, text),
                        Voice = AnnotationText(annotations, "voice"),
                    }, node.LineStart);
                    break;
                }
                case TaleNodeKind.Expression:
                {
                    string kind;
                    if (!_callKinds.TryGetValue(node.Expr, out kind)) kind = "";
                    if (kind == "beat")
                    {
                        Emit(new TaleInstruction { Op = TaleOp.CallBeat, Tale = "", Beat = node.Expr.Operands[0].Name }, node.LineStart);
                    }
                    else if (kind == "tale_beat")
                    {
                        var callee = node.Expr.Operands[0];
                        Emit(new TaleInstruction { Op = TaleOp.CallBeat, Tale = callee.Operands[0].Name, Beat = callee.Name }, node.LineStart);
                    }
                    else
                    {
                        Emit(new TaleInstruction { Op = TaleOp.Eval, Expr = node.Expr }, node.LineStart);
                    }
                    break;
                }
                case TaleNodeKind.Assign:
                    Emit(new TaleInstruction { Op = TaleOp.Set, Place = node.Target, Assign = node.Op, Value = node.Expr }, node.LineStart);
                    break;
                case TaleNodeKind.Var:
                case TaleNodeKind.Const:
                    Emit(new TaleInstruction { Op = TaleOp.Local, Name = node.Name, Value = node.Expr }, node.LineStart);
                    break;
                case TaleNodeKind.Jump:
                {
                    string[] parts = node.JumpTarget.Split('.');
                    string tale = parts.Length == 2 ? parts[0] : "";
                    Emit(new TaleInstruction { Op = TaleOp.Jump, Tale = tale, Beat = parts[parts.Length - 1] }, node.LineStart);
                    break;
                }
                case TaleNodeKind.Return:
                    Emit(new TaleInstruction { Op = TaleOp.Return }, node.LineStart);
                    break;
                case TaleNodeKind.While:
                    While(node);
                    break;
                case TaleNodeKind.For:
                    For(node);
                    break;
                case TaleNodeKind.Match:
                    Match(node);
                    break;
                case TaleNodeKind.Choose:
                    Choose(node);
                    break;
                case TaleNodeKind.Break:
                    _loops[_loops.Count - 1].Breaks.Add(Emit(new TaleInstruction { Op = TaleOp.Goto, Target = -1 }, node.LineStart));
                    break;
                case TaleNodeKind.Continue:
                    Emit(new TaleInstruction { Op = TaleOp.Goto, Target = _loops[_loops.Count - 1].Continue }, node.LineStart);
                    break;
            }
            if (HasAnnotation(annotations, null, "no_rewind") && index < _tale.Instructions.Count)
                _tale.Instructions[index].NoRewind = true;
            if (HasAnnotation(annotations, null, "no_wait") && index < _tale.Instructions.Count)
                _tale.Instructions[index].NoWait = true;
        }

        private void IfChain(List<TaleNode> chain, List<TaleExpr> pending)
        {
            var exits = new List<int>();
            int first = _tale.Instructions.Count;
            foreach (var branch in chain)
            {
                if (branch.Kind == TaleNodeKind.Else)
                {
                    Block(branch.Body);
                    break;
                }
                int test = Emit(new TaleInstruction { Op = TaleOp.BranchFalse, Cond = branch.Expr, Target = -1 }, branch.LineStart);
                Block(branch.Body);
                if (branch != chain[chain.Count - 1])
                    exits.Add(Emit(new TaleInstruction { Op = TaleOp.Goto, Target = -1 }, branch.LineStart));
                Patch(test);
            }
            foreach (int exit in exits) Patch(exit);
            if (HasAnnotation(pending, null, "no_rewind") && first < _tale.Instructions.Count)
                _tale.Instructions[first].NoRewind = true;
        }

        private void While(TaleNode node)
        {
            int start = _tale.Instructions.Count;
            int test = Emit(new TaleInstruction { Op = TaleOp.BranchFalse, Cond = node.Expr, Target = -1 }, node.LineStart);
            _loops.Add(new Loop { Continue = start });
            Block(node.Body);
            Emit(new TaleInstruction { Op = TaleOp.Goto, Target = start }, node.LineStart);
            CloseLoop(test);
        }

        private void For(TaleNode node)
        {
            _loopCounter++;
            string slot = "$for" + _loopCounter.ToString(CultureInfo.InvariantCulture);
            Emit(new TaleInstruction { Op = TaleOp.IterBegin, Slot = slot, Iterable = node.Expr }, node.LineStart);
            int next = Emit(new TaleInstruction { Op = TaleOp.IterNext, Slot = slot, Var = node.Name, Target = -1 }, node.LineStart);
            _loops.Add(new Loop { Continue = next });
            Block(node.Body);
            Emit(new TaleInstruction { Op = TaleOp.Goto, Target = next }, node.LineStart);
            CloseLoop(next);
        }

        /// <summary>Points the loop's exit instruction and its breaks past the loop.</summary>
        private void CloseLoop(int exit)
        {
            Patch(exit);
            var loop = _loops[_loops.Count - 1];
            _loops.RemoveAt(_loops.Count - 1);
            foreach (int breakIndex in loop.Breaks) Patch(breakIndex);
        }

        private void Match(TaleNode node)
        {
            var instruction = new TaleInstruction { Op = TaleOp.Match, Subject = node.Expr, EndTarget = -1 };
            Emit(instruction, node.LineStart);
            var exits = new List<int>();
            foreach (var branch in node.Body)
            {
                if (branch.Kind != TaleNodeKind.MatchBranch) continue;
                var compiled = new TaleMatchBranch { Guard = branch.Condition, Target = _tale.Instructions.Count };
                foreach (var pattern in branch.Patterns)
                {
                    bool wildcard = pattern.Kind == TaleExprKind.Identifier && pattern.Name == "_";
                    compiled.Patterns.Add(wildcard ? null : pattern);
                }
                instruction.Branches.Add(compiled);
                Block(branch.Body);
                exits.Add(Emit(new TaleInstruction { Op = TaleOp.Goto, Target = -1 }, branch.LineStart));
            }
            instruction.EndTarget = _tale.Instructions.Count;
            foreach (int exit in exits) Patch(exit);
        }

        private void Choose(TaleNode node)
        {
            var instruction = new TaleInstruction { Op = TaleOp.Choose, TimeoutTarget = -1, EndTarget = -1 };
            if (node.Expr != null)
                foreach (string key in node.Expr.NamedArgs.Keys)
                    instruction.Args[key] = node.Expr.NamedArgs[key];
            Emit(instruction, node.LineStart);
            var exits = new List<int>();
            var pending = new List<TaleExpr>();
            foreach (var child in node.Body)
            {
                if (child.Kind == TaleNodeKind.Annotation)
                {
                    pending.AddRange(child.Annotations);
                    continue;
                }
                if (child.Kind != TaleNodeKind.Option && child.Kind != TaleNodeKind.Timeout) continue;
                int target = _tale.Instructions.Count;
                if (child.Kind == TaleNodeKind.Timeout)
                {
                    instruction.TimeoutTarget = target;
                }
                else
                {
                    var annotations = new List<TaleExpr>(pending);
                    annotations.AddRange(child.Annotations);
                    string text = (string)child.Expr.Value;
                    instruction.Options.Add(new TaleOption
                    {
                        Text = Text(text),
                        Cond = child.Condition,
                        Once = HasAnnotation(annotations, null, "once"),
                        ShowDisabled = HasAnnotation(annotations, null, "show_disabled"),
                        Picture = AnnotationText(annotations, "picture"),
                        Id = LineId(annotations, text),
                        Target = target,
                        Line = child.LineStart,
                    });
                }
                pending.Clear();
                Block(child.Body);
                exits.Add(Emit(new TaleInstruction { Op = TaleOp.Goto, Target = -1 }, child.LineStart));
            }
            instruction.EndTarget = _tale.Instructions.Count;
            foreach (int exit in exits) Patch(exit);
        }

        // --- Text and helpers ---------------------------------------------------

        private static List<object> Text(string text)
        {
            return TaleText.SplitInterpolation(text).Parts;
        }

        /// <summary>Pinned id from @id, or "beat_hash" made unique within the tale.</summary>
        private string LineId(List<TaleExpr> annotations, string text)
        {
            string pinned = AnnotationText(annotations, "id");
            if (pinned.Length > 0)
            {
                _tale.Texts[pinned] = text;
                return pinned;
            }
            string baseId = _beat + "_" + Md5Hex(text).Substring(0, 6);
            string id = baseId;
            int n = 2;
            while (_usedIds.Contains(id))
            {
                id = baseId + "_" + n.ToString(CultureInfo.InvariantCulture);
                n++;
            }
            _usedIds.Add(id);
            _tale.Texts[id] = text;
            return id;
        }

        private static string Md5Hex(string text)
        {
            using (var md5 = MD5.Create())
            {
                byte[] hash = md5.ComputeHash(new UTF8Encoding(false).GetBytes(text));
                var sb = new StringBuilder();
                foreach (byte b in hash) sb.Append(b.ToString("x2", CultureInfo.InvariantCulture));
                return sb.ToString();
            }
        }

        private int Emit(TaleInstruction instruction, int line)
        {
            instruction.Line = line;
            if (_skipSafe && instruction.Op == TaleOp.Say) instruction.SkipSafe = true;
            _tale.Instructions.Add(instruction);
            return _tale.Instructions.Count - 1;
        }

        /// <summary>Points the jump at index to the next instruction to be emitted.</summary>
        private void Patch(int index)
        {
            _tale.Instructions[index].Target = _tale.Instructions.Count;
        }

        private static bool HasAnnotation(List<TaleExpr> annotations, TaleNode node, string annotationName)
        {
            foreach (var annotation in annotations)
                if (annotation.Name == annotationName) return true;
            if (node != null)
                foreach (var annotation in node.Annotations)
                    if (annotation.Name == annotationName) return true;
            return false;
        }

        private static string AnnotationText(List<TaleExpr> annotations, string annotationName)
        {
            foreach (var annotation in annotations)
            {
                if (annotation.Name == annotationName && annotation.Args.Count == 1 && annotation.Args[0].Value is string text)
                    return text;
            }
            return "";
        }
    }
}
