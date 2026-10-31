using System;
using System.Collections.Generic;
using System.Reflection;
using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>
    /// Lets an exposed object answer tales without reflection, which suits IL2CPP builds.
    /// Implement it on the object passed to <see cref="TaleDirector.Expose"/>.
    /// </summary>
    public interface ITaleObject
    {
        bool TryGetProperty(string name, out object value);
        bool TrySetProperty(string name, object value);
        /// <summary>Calls a method. The result may be a Task or Task&lt;T&gt;.</summary>
        object CallMethod(string name, object[] args);
    }

    /// <summary>A name tales may use as a speaker. A value that implements it shows a display name.</summary>
    public interface ITaleSpeaker
    {
        string DisplayName { get; }
        /// <summary>Name color for the presenter, in whatever form the presenter expects.</summary>
        object NameColor { get; }
    }

    /// <summary>
    /// An object from game code that tales may use, limited to the listed methods and
    /// properties. Created by <see cref="TaleDirector.Expose"/>.
    /// </summary>
    public class TaleExposed
    {
        public object Target;
        public List<string> Methods;
        public List<string> Properties;

        public TaleExposed(object target, IEnumerable<string> methods, IEnumerable<string> properties)
        {
            Target = target;
            Methods = new List<string>(methods ?? new string[0]);
            Properties = new List<string>(properties ?? new string[0]);
        }

        public object GetProperty(string name)
        {
            var host = Target as ITaleObject;
            object value;
            if (host != null)
            {
                if (!host.TryGetProperty(name, out value)) throw new GdOpException();
                return GdValue.Normalize(value);
            }
            Type type = Target.GetType();
            PropertyInfo property = type.GetProperty(name, BindingFlags.Public | BindingFlags.Instance);
            if (property != null) return ToValue(property.GetValue(Target, null));
            FieldInfo field = type.GetField(name, BindingFlags.Public | BindingFlags.Instance);
            if (field != null) return ToValue(field.GetValue(Target));
            throw new GdOpException();
        }

        public void SetProperty(string name, object value)
        {
            var host = Target as ITaleObject;
            if (host != null)
            {
                if (!host.TrySetProperty(name, value)) throw new GdOpException();
                return;
            }
            Type type = Target.GetType();
            PropertyInfo property = type.GetProperty(name, BindingFlags.Public | BindingFlags.Instance);
            if (property != null && property.CanWrite)
            {
                property.SetValue(Target, ConvertTo(value, property.PropertyType), null);
                return;
            }
            FieldInfo field = type.GetField(name, BindingFlags.Public | BindingFlags.Instance);
            if (field != null)
            {
                field.SetValue(Target, ConvertTo(value, field.FieldType));
                return;
            }
            throw new GdOpException();
        }

        /// <summary>Calls a method and returns what it returns (possibly a Task).</summary>
        public object Call(string name, object[] args)
        {
            var host = Target as ITaleObject;
            if (host != null) return host.CallMethod(name, args);
            foreach (MethodInfo method in Target.GetType().GetMethods(BindingFlags.Public | BindingFlags.Instance))
            {
                if (method.Name != name) continue;
                ParameterInfo[] parameters = method.GetParameters();
                if (parameters.Length < args.Length) continue;
                var values = new object[parameters.Length];
                bool fits = true;
                for (int i = 0; i < parameters.Length && fits; i++)
                {
                    if (i < args.Length) values[i] = ConvertTo(args[i], parameters[i].ParameterType);
                    else if (parameters[i].HasDefaultValue) values[i] = parameters[i].DefaultValue;
                    else fits = false;
                }
                if (!fits) continue;
                try
                {
                    return method.Invoke(Target, values);
                }
                catch (TargetInvocationException e)
                {
                    throw e.InnerException ?? e;
                }
            }
            throw new GdOpException();
        }

        private static object ToValue(object value)
        {
            return GdValue.Normalize(value);
        }

        private static object ConvertTo(object value, Type type)
        {
            if (value == null) return type.IsValueType ? Activator.CreateInstance(type) : null;
            if (type.IsInstanceOfType(value)) return value;
            Type target = Nullable.GetUnderlyingType(type) ?? type;
            if (target.IsEnum) return Enum.ToObject(target, Convert.ToInt64(value, System.Globalization.CultureInfo.InvariantCulture));
            return Convert.ChangeType(value, target, System.Globalization.CultureInfo.InvariantCulture);
        }
    }
}
