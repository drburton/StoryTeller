using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>
    /// What the player has explored across every playthrough, for a route chart: the beats
    /// they entered, the ways they went from one beat to another, and the choice options they
    /// saw and picked. The director keeps one in <see cref="TaleDirector.Routes"/> and saves
    /// it with the global data.
    /// </summary>
    public class TaleRouteLog
    {
        /// <summary>An option the player has never been shown.</summary>
        public const int Unseen = 0;
        /// <summary>An option the player was shown but has never picked.</summary>
        public const int Seen = 1;
        /// <summary>An option the player has picked at least once.</summary>
        public const int Picked = 2;

        /// <summary>"tale.beat" ids in the order the player first entered them.</summary>
        public readonly List<string> Beats = new List<string>();

        private readonly HashSet<string> _beatSet = new HashSet<string>();
        private readonly OrderedMap<bool> _links = new OrderedMap<bool>();
        private readonly OrderedMap<int> _options = new OrderedMap<int>();

        /// <summary>Records that the player entered a beat, coming from <paramref name="fromId"/> ("" when play started there).</summary>
        public void Enter(string beatId, string fromId = "")
        {
            if (_beatSet.Add(beatId)) Beats.Add(beatId);
            if (fromId.Length > 0 && fromId != beatId) _links[fromId + ">" + beatId] = true;
        }

        /// <summary>Records that the option with this translation key ("tale:id") was shown.</summary>
        public void SeeOption(string key)
        {
            if (!_options.Has(key)) _options[key] = Seen;
        }

        /// <summary>Records that the option with this translation key was picked.</summary>
        public void PickOption(string key)
        {
            _options[key] = Picked;
        }

        public bool HasBeat(string beatId)
        {
            return _beatSet.Contains(beatId);
        }

        /// <summary><see cref="Unseen"/>, <see cref="Seen"/>, or <see cref="Picked"/>.</summary>
        public int GetOptionState(string key)
        {
            int state;
            return _options.TryGetValue(key, out state) ? state : Unseen;
        }

        /// <summary>Links between beats as {from, to} pairs, in the order they were first taken.</summary>
        public List<string[]> GetLinks()
        {
            var result = new List<string[]>();
            foreach (string key in _links.Keys) result.Add(key.Split('>'));
            return result;
        }

        public bool IsEmpty { get { return Beats.Count == 0; } }

        public void Clear()
        {
            Beats.Clear();
            _beatSet.Clear();
            _links.Clear();
            _options.Clear();
        }

        /// <summary>Plain data with the keys beats, links, seen, and picked.</summary>
        public OrderedMap<object> ToDict()
        {
            var seen = new List<object>();
            var picked = new List<object>();
            foreach (string key in _options.Keys) (_options[key] == Picked ? picked : seen).Add(key);
            var beats = new List<object>();
            foreach (string beat in Beats) beats.Add(beat);
            var links = new List<object>();
            foreach (string link in _links.Keys) links.Add(link);
            var result = new OrderedMap<object>();
            result["beats"] = beats;
            result["links"] = links;
            result["seen"] = seen;
            result["picked"] = picked;
            return result;
        }

        public void FromDict(OrderedMap<object> data)
        {
            Clear();
            foreach (string beat in Strings(data, "beats")) Enter(beat);
            foreach (string link in Strings(data, "links")) _links[link] = true;
            foreach (string key in Strings(data, "seen")) SeeOption(key);
            foreach (string key in Strings(data, "picked")) PickOption(key);
        }

        internal static List<string> Strings(OrderedMap<object> data, string key)
        {
            var result = new List<string>();
            object value;
            var list = data != null && data.TryGetValue(key, out value) ? value as List<object> : null;
            if (list != null)
                foreach (object item in list) result.Add(GdValue.Str(item));
            return result;
        }
    }
}
