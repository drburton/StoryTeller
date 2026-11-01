using System;
using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>Signature of a checked action: parameter names in order and how many are required.</summary>
    public class TaleActionSignature
    {
        public List<string> Params;
        public int Required;
    }

    /// <summary>Beats and variables of another tale.</summary>
    public class TaleInfo
    {
        public List<string> Beats;
        public List<string> Vars;
    }

    /// <summary>
    /// What the checker knows about the project around a tale: actions, cast
    /// members, objects exposed by game code, and other tales.
    /// </summary>
    public class TaleCheckContext
    {
        /// <summary>Names usable as values in every tale.</summary>
        public static readonly string[] BuiltinConstants = { "LEFT", "CENTER", "RIGHT", "PI", "TAU", "INF", "NAN" };

        /// <summary>Functions usable in every tale.</summary>
        public static readonly string[] BuiltinFunctions =
        {
            "abs", "ceil", "clamp", "collected", "float", "floor", "int", "len", "max",
            "min", "randf", "randf_range", "randi", "randi_range", "round", "str", "tr",
            "visited",
        };

        /// <summary>Value types that can be constructed in tales.</summary>
        public static readonly string[] Constructors = { "Color", "Rect2", "Vector2", "Vector2i", "Vector3" };

        /// <summary>Methods of a cast member.</summary>
        public static readonly string[] CastMethods = { "animate", "enter", "exit", "hop", "move_to", "nod", "scale_to", "shake", "to_back", "to_front" };

        /// <summary>Properties of a cast member.</summary>
        public static readonly string[] CastProperties = { "display_name", "draw_order", "flip", "mood", "on_stage", "tint" };

        /// <summary>Name of the tale being checked, so it can refer to itself as tale_name.beat.</summary>
        public string TaleName = "";
        /// <summary>Actions by name. A null signature means the arguments are not checked.</summary>
        public OrderedMap<TaleActionSignature> Actions = new OrderedMap<TaleActionSignature>();
        /// <summary>Cast member ids with their known moods. An empty list accepts any mood.</summary>
        public OrderedMap<List<string>> Cast = new OrderedMap<List<string>>();
        /// <summary>Field names of cast members, by id.</summary>
        public OrderedMap<List<string>> CastFields = new OrderedMap<List<string>>();
        /// <summary>Names of objects and functions exposed by game code.</summary>
        public OrderedMap<bool> Exposed = new OrderedMap<bool>();
        /// <summary>Asset checks by "action.param". The function returns "" when the asset exists, or a message.</summary>
        public OrderedMap<Func<string, string>> AssetChecks = new OrderedMap<Func<string, string>>();
        /// <summary>Other tales by name.</summary>
        public OrderedMap<TaleInfo> Tales = new OrderedMap<TaleInfo>();

        public TaleCheckContext AddAction(string actionName, IEnumerable<string> parameters = null, int required = 0)
        {
            Actions[actionName] = new TaleActionSignature
            {
                Params = parameters == null ? new List<string>() : new List<string>(parameters),
                Required = required,
            };
            return this;
        }

        public TaleCheckContext AddActionUnchecked(string actionName)
        {
            Actions[actionName] = null;
            return this;
        }

        public TaleCheckContext AddCast(string id, IEnumerable<string> moods = null, IEnumerable<string> fields = null)
        {
            Cast[id] = moods == null ? new List<string>() : new List<string>(moods);
            CastFields[id] = fields == null ? new List<string>() : new List<string>(fields);
            return this;
        }

        /// <summary>Everything a tale can use after "id.": methods, properties, then fields.</summary>
        public List<string> GetCastMembers(string id)
        {
            var members = new List<string>(CastMethods);
            members.AddRange(CastProperties);
            List<string> fields;
            if (CastFields.TryGetValue(id, out fields)) members.AddRange(fields);
            return members;
        }

        public TaleCheckContext AddAssetCheck(string action, string param, Func<string, string> check)
        {
            AssetChecks[action + "." + param] = check;
            return this;
        }

        public TaleCheckContext AddExposed(string exposedName)
        {
            Exposed[exposedName] = true;
            return this;
        }

        public TaleCheckContext AddTale(string otherTale, IEnumerable<string> beats, IEnumerable<string> vars = null)
        {
            Tales[otherTale] = new TaleInfo
            {
                Beats = new List<string>(beats),
                Vars = vars == null ? new List<string>() : new List<string>(vars),
            };
            return this;
        }
    }
}
