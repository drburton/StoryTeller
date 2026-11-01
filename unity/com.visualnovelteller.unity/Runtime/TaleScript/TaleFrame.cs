using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>State of a running for loop.</summary>
    public class TaleIterator
    {
        public List<object> Items = new List<object>();
        public int Index;
    }

    /// <summary>One entry of the director's call stack: a running beat.</summary>
    public class TaleFrame
    {
        public Tale Tale;
        public string Beat;
        /// <summary>Index of the next instruction to run.</summary>
        public int Pc;
        /// <summary>Temporary variables of the beat.</summary>
        public Dictionary<string, object> Locals = new Dictionary<string, object>();
        /// <summary>State of running for loops by slot.</summary>
        public Dictionary<string, TaleIterator> Iterators = new Dictionary<string, TaleIterator>();

        public TaleFrame(Tale tale, string beat)
        {
            Tale = tale;
            Beat = beat;
            Pc = tale.GetBeatStart(beat);
        }
    }

    /// <summary>Stands for another tale in expressions, as in <c>chapter_1.met_jonas</c>.</summary>
    public class TaleNamespace
    {
        public string TaleName;

        public TaleNamespace(string taleName)
        {
            TaleName = taleName;
        }
    }
}
