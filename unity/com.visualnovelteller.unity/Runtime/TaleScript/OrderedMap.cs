using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>
    /// A string keyed map that enumerates in insertion order, like a GDScript Dictionary.
    /// </summary>
    public class OrderedMap<TValue>
    {
        private readonly List<string> _keys = new List<string>();
        private readonly Dictionary<string, TValue> _values = new Dictionary<string, TValue>();

        public int Count { get { return _keys.Count; } }

        public bool IsEmpty { get { return _keys.Count == 0; } }

        /// <summary>Keys in insertion order.</summary>
        public IReadOnlyList<string> Keys { get { return _keys; } }

        public void Clear()
        {
            _keys.Clear();
            _values.Clear();
        }

        public bool Has(string key)
        {
            return _values.ContainsKey(key);
        }

        public TValue this[string key]
        {
            get { return _values[key]; }
            set
            {
                if (!_values.ContainsKey(key)) _keys.Add(key);
                _values[key] = value;
            }
        }

        public bool TryGetValue(string key, out TValue value)
        {
            return _values.TryGetValue(key, out value);
        }
    }
}
