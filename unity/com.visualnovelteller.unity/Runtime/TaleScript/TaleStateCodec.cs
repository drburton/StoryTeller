using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>
    /// Turns tale values into plain data that survives <see cref="GdJson"/> and back.
    /// Dictionaries become {"$dict": [[key, value], ...]}, and the floats NaN and infinity
    /// become {"$float": "nan"}. Values the core does not know, such as host vectors, are
    /// stored as their text.
    /// </summary>
    internal static class TaleStateCodec
    {
        public static object Encode(object value)
        {
            if (value == null || value is bool || value is long || value is string) return value;
            if (value is double)
            {
                double d = (double)value;
                if (double.IsNaN(d) || double.IsInfinity(d))
                {
                    var special = new OrderedMap<object>();
                    special["$float"] = double.IsNaN(d) ? "nan" : d > 0 ? "inf" : "-inf";
                    return special;
                }
                return d;
            }
            var list = value as List<object>;
            if (list != null)
            {
                var items = new List<object>();
                foreach (object item in list) items.Add(Encode(item));
                return items;
            }
            var dict = value as TaleDict;
            if (dict != null)
            {
                var pairs = new List<object>();
                foreach (object key in dict.Keys) pairs.Add(new List<object> { Encode(key), Encode(dict[key]) });
                var wrapped = new OrderedMap<object>();
                wrapped["$dict"] = pairs;
                return wrapped;
            }
            if (value is int) return (long)(int)value;
            if (value is TaleExposed || value is TaleNamespace) return null;
            return GdValue.Str(value);
        }

        public static object Decode(object data)
        {
            var list = data as List<object>;
            if (list != null)
            {
                var items = new List<object>();
                foreach (object item in list) items.Add(Decode(item));
                return items;
            }
            var map = data as OrderedMap<object>;
            if (map != null)
            {
                object inner;
                if (map.TryGetValue("$float", out inner))
                {
                    string kind = inner as string;
                    return kind == "nan" ? double.NaN : kind == "-inf" ? double.NegativeInfinity : double.PositiveInfinity;
                }
                if (map.TryGetValue("$dict", out inner))
                {
                    var dict = new TaleDict();
                    var pairs = inner as List<object>;
                    if (pairs != null)
                    {
                        foreach (object pair in pairs)
                        {
                            var kv = pair as List<object>;
                            if (kv != null && kv.Count == 2) dict[Decode(kv[0])] = Decode(kv[1]);
                        }
                    }
                    return dict;
                }
            }
            return data;
        }

        public static OrderedMap<object> EncodeMap(Dictionary<string, object> values)
        {
            var keys = new List<string>(values.Keys);
            keys.Sort(string.CompareOrdinal);
            var result = new OrderedMap<object>();
            foreach (string key in keys) result[key] = Encode(values[key]);
            return result;
        }

        public static Dictionary<string, object> DecodeMap(object data)
        {
            var result = new Dictionary<string, object>();
            var map = data as OrderedMap<object>;
            if (map == null) return result;
            foreach (string key in map.Keys) result[key] = Decode(map[key]);
            return result;
        }

        public static List<object> SortedList(IEnumerable<string> values)
        {
            var sorted = new List<string>(values);
            sorted.Sort(string.CompareOrdinal);
            var result = new List<object>();
            foreach (string value in sorted) result.Add(value);
            return result;
        }
    }
}
