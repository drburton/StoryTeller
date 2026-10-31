using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>
    /// A tale dictionary: keys of any value kind, enumerated in insertion order
    /// like a GDScript Dictionary. Keys of different kinds stay apart, so the
    /// integer 1 and the float 1.0 are two keys.
    /// </summary>
    public class TaleDict
    {
        private sealed class NullKey
        {
            public static readonly NullKey Instance = new NullKey();
        }

        private sealed class KeyComparer : IEqualityComparer<object>
        {
            public new bool Equals(object a, object b)
            {
                if (a is long x && b is long y) return x == y;
                if (a is double d && b is double e) return d.Equals(e);
                if (a is string s && b is string t) return s == t;
                if (a is bool p && b is bool q) return p == q;
                if (a is List<object> || a is TaleDict) return GdValue.Equal(a, b) && a.GetType() == b.GetType();
                return ReferenceEquals(a, b);
            }

            public int GetHashCode(object value)
            {
                if (value is List<object> || value is TaleDict) return 17;
                return value.GetHashCode();
            }
        }

        private readonly List<object> _keys = new List<object>();
        private readonly Dictionary<object, object> _values = new Dictionary<object, object>(new KeyComparer());

        public int Count { get { return _keys.Count; } }

        /// <summary>Keys in insertion order. The list is a copy.</summary>
        public List<object> Keys { get { return new List<object>(_keys); } }

        public List<object> Values
        {
            get
            {
                var result = new List<object>();
                foreach (object key in _keys) result.Add(_values[Wrap(key)]);
                return result;
            }
        }

        private static object Wrap(object key)
        {
            return key ?? NullKey.Instance;
        }

        public bool Has(object key)
        {
            return _values.ContainsKey(Wrap(key));
        }

        public bool TryGetValue(object key, out object value)
        {
            return _values.TryGetValue(Wrap(key), out value);
        }

        public object this[object key]
        {
            get { return _values[Wrap(key)]; }
            set
            {
                object k = Wrap(key);
                if (!_values.ContainsKey(k)) _keys.Add(key);
                _values[k] = value;
            }
        }

        public bool Remove(object key)
        {
            object k = Wrap(key);
            if (!_values.Remove(k)) return false;
            for (int i = 0; i < _keys.Count; i++)
            {
                if (Wrap(_keys[i]).Equals(k) || new KeyComparer().Equals(Wrap(_keys[i]), k))
                {
                    _keys.RemoveAt(i);
                    break;
                }
            }
            return true;
        }

        public void Clear()
        {
            _keys.Clear();
            _values.Clear();
        }

        public TaleDict Duplicate()
        {
            var copy = new TaleDict();
            foreach (object key in _keys) copy[key] = _values[Wrap(key)];
            return copy;
        }
    }
}
