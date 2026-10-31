using System.Collections.Generic;

namespace TaleScript
{
    public enum TaleOp
    {
        Say,
        Eval,
        Set,
        Local,
        Jump,
        CallBeat,
        Return,
        Goto,
        BranchFalse,
        IterBegin,
        IterNext,
        Match,
        Choose,
        End,
    }

    /// <summary>A branch of a match instruction. A null pattern is the wildcard.</summary>
    public class TaleMatchBranch
    {
        public List<TaleExpr> Patterns = new List<TaleExpr>();
        public TaleExpr Guard;
        public int Target;
    }

    /// <summary>An option of a choose instruction.</summary>
    public class TaleOption
    {
        /// <summary>Text parts: strings, TaleExpr values, and <see cref="TaleText.TagPart"/> items.</summary>
        public List<object> Text = new List<object>();
        public TaleExpr Cond;
        public bool Once;
        public bool ShowDisabled;
        public string Picture = "";
        public string Id = "";
        public int Target;
        public int Line;
    }

    /// <summary>
    /// One step of a compiled beat. Which fields are used depends on <see cref="Op"/>
    /// (see the table in the GDScript class Tale).
    /// </summary>
    public class TaleInstruction
    {
        public TaleOp Op;
        /// <summary>Source line.</summary>
        public int Line;
        public bool NoRewind;
        public bool NoWait;
        public bool SkipSafe;

        // Say
        public string Speaker = "";
        public string Mood = "";
        public List<object> Text = new List<object>();
        public string Id = "";
        public string Voice = "";

        // Eval, Set, Local
        public TaleExpr Expr;
        public TaleExpr Place;
        public string Assign = "=";
        public TaleExpr Value;
        public string Name = "";

        // Jump, CallBeat. An empty Tale means the current tale.
        public string Tale = "";
        public string Beat = "";

        // Goto, BranchFalse, IterNext
        public int Target = -1;
        public TaleExpr Cond;

        // IterBegin, IterNext
        public string Slot = "";
        public TaleExpr Iterable;
        public string Var = "";

        // Match
        public TaleExpr Subject;
        public List<TaleMatchBranch> Branches = new List<TaleMatchBranch>();

        // Choose
        public OrderedMap<TaleExpr> Args = new OrderedMap<TaleExpr>();
        public List<TaleOption> Options = new List<TaleOption>();
        public int TimeoutTarget = -1;

        // Match, Choose
        public int EndTarget = -1;
    }

    /// <summary>A story, global, or constant variable declared at the top of a tale.</summary>
    public class TaleVariable
    {
        public string Name = "";
        public bool IsGlobal;
        public bool IsConst;
        /// <summary>Initial value, or null when the variable has none.</summary>
        public TaleExpr Value;
        public int Line;
    }

    /// <summary>A compiled tale, ready for the director to run. Created by <see cref="TaleCompiler"/>.</summary>
    public class Tale
    {
        public const int Format = 4;

        public string TaleName = "";
        /// <summary>Display title from @title, or "".</summary>
        public string Title = "";
        public string SourcePath = "";
        public List<TaleVariable> Variables = new List<TaleVariable>();
        /// <summary>Beat name to index of its first instruction.</summary>
        public OrderedMap<int> Beats = new OrderedMap<int>();
        /// <summary>Beat name to its display heading from @heading.</summary>
        public OrderedMap<string> Headings = new OrderedMap<string>();
        public List<TaleInstruction> Instructions = new List<TaleInstruction>();
        /// <summary>Source text of every line and option, by id.</summary>
        public OrderedMap<string> Texts = new OrderedMap<string>();

        /// <summary>Translation key of the line or option with the given id.</summary>
        public string TranslationKey(string id)
        {
            return TaleName + ":" + id;
        }

        /// <summary>Index of the first instruction of a beat, or -1.</summary>
        public int GetBeatStart(string beatName)
        {
            int start;
            return Beats.TryGetValue(beatName, out start) ? start : -1;
        }
    }
}
