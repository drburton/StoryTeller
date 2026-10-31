using System.Collections.Generic;
using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>
    /// Base class for actions that tales can call, such as <c>wait(1.0)</c>. Give the
    /// action a name, its parameter names, how many are required, and default values
    /// for the optional ones, then override <see cref="Run"/> or <see cref="RunAsync"/>.
    /// </summary>
    public abstract class TaleAction
    {
        /// <summary>Name used in tales.</summary>
        public string Name { get; private set; }
        /// <summary>Parameter names in order.</summary>
        public IReadOnlyList<string> Parameters { get; private set; }
        /// <summary>How many leading parameters must be given.</summary>
        public int Required { get; private set; }
        /// <summary>Defaults of the optional parameters, in order.</summary>
        public IReadOnlyList<object> Defaults { get; private set; }

        protected TaleAction(string name, IEnumerable<string> parameters = null, int required = 0, IEnumerable<object> defaults = null)
        {
            Name = name;
            Parameters = new List<string>(parameters ?? new string[0]);
            Required = required;
            var list = new List<object>(defaults ?? new object[0]);
            while (list.Count < Parameters.Count - Required) list.Add(null);
            Defaults = list;
        }

        /// <summary>Runs the action synchronously. The arguments are bound and filled with defaults.</summary>
        public virtual void Run(TaleContext context, object[] args)
        {
        }

        /// <summary>Runs the action. Override this to await something; the default calls <see cref="Run"/>.</summary>
        public virtual Task<object> RunAsync(TaleContext context, object[] args)
        {
            Run(context, args);
            return Task.FromResult<object>(null);
        }
    }

    /// <summary>Matches positional and named arguments from a tale to parameters, filling in defaults.</summary>
    public static class TaleCalls
    {
        /// <summary>Returns the argument values in order, or null with an error message.</summary>
        public static object[] Bind(IReadOnlyList<string> parameters, int required, IReadOnlyList<object> defaults,
            List<object> args, OrderedMap<object> named, string label, out string error)
        {
            error = "";
            int count = parameters.Count;
            if (args.Count > count)
            {
                error = "'" + label + "' takes at most " + count + " arguments.";
                return null;
            }
            foreach (string key in named.Keys)
            {
                int index = -1;
                for (int i = 0; i < count; i++)
                    if (parameters[i] == key) index = i;
                if (index == -1)
                {
                    error = "'" + label + "' has no argument named '" + key + "'.";
                    return null;
                }
                if (index < args.Count)
                {
                    error = "Argument '" + key + "' is already given by position.";
                    return null;
                }
            }
            var values = new List<object>(args);
            for (int i = args.Count; i < count; i++)
            {
                object value;
                if (named.TryGetValue(parameters[i], out value)) values.Add(value);
                else if (i >= required) values.Add(defaults[i - required]);
                else
                {
                    error = "'" + label + "' needs the argument '" + parameters[i] + "'.";
                    return null;
                }
            }
            return values.ToArray();
        }
    }
}
