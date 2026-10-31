using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>
    /// Evaluates compiled expressions for the director. Only safe things are reachable:
    /// tale variables, built-in values and functions, actions, and objects that game code
    /// exposed with <see cref="TaleDirector.Expose"/>. Mistakes such as adding text to a
    /// number set <see cref="Error"/> and give null; they never throw.
    /// </summary>
    public class TaleEvaluator
    {
        /// <summary>Message of the first error since <see cref="Reset"/>, or "".</summary>
        public string Error = "";

        private readonly TaleDirector _director;

        public TaleEvaluator(TaleDirector director)
        {
            _director = director;
        }

        public void Reset()
        {
            Error = "";
        }

        public bool Failed()
        {
            return Error.Length > 0;
        }

        public void Fail(string message)
        {
            if (Error.Length == 0) Error = message;
        }

        /// <summary>True for host objects, which tales can only use when they are exposed.</summary>
        public static bool IsObject(object value)
        {
            return value != null && !(value is bool) && !(value is long) && !(value is double) && !(value is string)
                && !(value is List<object>) && !(value is TaleDict);
        }

        /// <summary>Evaluates expr in frame.</summary>
        public async Task<object> Evaluate(TaleExpr expr, TaleFrame frame)
        {
            if (Failed()) return null;
            switch (expr.Kind)
            {
                case TaleExprKind.Literal:
                    return expr.Value;
                case TaleExprKind.Identifier:
                {
                    object found;
                    if (!_director.ResolveName(expr.Name, frame, out found))
                        Fail("Unknown name '" + expr.Name + "'.");
                    return found;
                }
                case TaleExprKind.Unary:
                {
                    object operand = await Evaluate(expr.Operands[0], frame);
                    return Unary(expr.Op, operand);
                }
                case TaleExprKind.Binary:
                    return await BinaryExpr(expr, frame);
                case TaleExprKind.Ternary:
                {
                    object condition = await Evaluate(expr.Operands[1], frame);
                    return await Evaluate(GdValue.Truthy(condition) ? expr.Operands[0] : expr.Operands[2], frame);
                }
                case TaleExprKind.Await:
                {
                    object value = await Evaluate(expr.Operands[0], frame);
                    try
                    {
                        var task = value as TaleTask;
                        if (task != null) return await task.Wait();
                        var plain = value as Task;
                        if (plain != null) return await TaleTask.Await(plain);
                    }
                    catch (Exception e)
                    {
                        Fail(e.Message);
                        return null;
                    }
                    return value;
                }
                case TaleExprKind.Call:
                    return await Call(expr, frame);
                case TaleExprKind.Attribute:
                {
                    var baseExpr = expr.Operands[0];
                    object ignored;
                    if (baseExpr.Kind == TaleExprKind.Identifier && Array.IndexOf(TaleCheckContext.Constructors, baseExpr.Name) >= 0
                        && !_director.ResolveName(baseExpr.Name, frame, out ignored))
                        return TypeConstant(baseExpr.Name, expr.Name);
                    object target = await Evaluate(baseExpr, frame);
                    return GetMember(target, expr.Name);
                }
                case TaleExprKind.Index:
                {
                    object container = await Evaluate(expr.Operands[0], frame);
                    object key = await Evaluate(expr.Operands[1], frame);
                    if (Failed()) return null;
                    if (IsObject(container)) return ObjectError();
                    try
                    {
                        return GdValue.Index(container, key);
                    }
                    catch (GdOpException)
                    {
                        Fail("Can't read index " + GdValue.Str(key) + ".");
                        return null;
                    }
                }
                case TaleExprKind.Array:
                {
                    var items = new List<object>();
                    foreach (var item in expr.Operands) items.Add(await Evaluate(item, frame));
                    return items;
                }
                case TaleExprKind.Dictionary:
                {
                    var dictionary = new TaleDict();
                    for (int i = 0; i + 1 < expr.Operands.Count; i += 2)
                    {
                        object key = await Evaluate(expr.Operands[i], frame);
                        dictionary[key] = await Evaluate(expr.Operands[i + 1], frame);
                    }
                    return dictionary;
                }
            }
            Fail("Unknown expression '" + expr.Kind + "'.");
            return null;
        }

        /// <summary>
        /// Stores value into place (an identifier, attribute, or index expression). For
        /// compound operators such as "+=", combines first.
        /// </summary>
        public async Task Assign(TaleExpr place, string op, object value, TaleFrame frame)
        {
            if (op != "=")
            {
                object current = await Evaluate(place, frame);
                if (Failed()) return;
                string binaryOp = op.EndsWith("=", StringComparison.Ordinal) ? op.Substring(0, op.Length - 1) : op;
                value = Binary(binaryOp, current, value);
            }
            if (!Failed()) await Store(place, value, frame);
        }

        /// <summary>Applies a binary operator with GDScript semantics.</summary>
        public object Binary(string op, object a, object b)
        {
            switch (op)
            {
                case "==":
                    return GdValue.Equal(a, b);
                case "!=":
                    return !GdValue.Equal(a, b);
                case "in":
                    return Contains(b, a);
                case "not in":
                    return !Contains(b, a);
                case "/":
                case "%":
                    if (b is long && (long)b == 0 && GdValue.IsNumber(a))
                    {
                        Fail("Division by zero.");
                        return null;
                    }
                    break;
            }
            if (Failed()) return null;
            try
            {
                return GdValue.Binary(op, a, b);
            }
            catch (GdOpException)
            {
                Fail("Can't use '" + op + "' with " + GdValue.TypeName(a) + " and " + GdValue.TypeName(b) + ".");
                return null;
            }
        }

        /// <summary>Reads a member of an object within the sandbox.</summary>
        public object GetMember(object target, string memberName)
        {
            if (Failed()) return null;
            var ns = target as TaleNamespace;
            if (ns != null)
            {
                object found;
                if (!_director.GetTaleVar(ns.TaleName, memberName, out found))
                    Fail("Tale '" + ns.TaleName + "' has no variable '" + memberName + "'.");
                return found;
            }
            var exposed = target as TaleExposed;
            if (exposed != null)
            {
                if (exposed.Properties.Contains(memberName))
                {
                    try
                    {
                        return exposed.GetProperty(memberName);
                    }
                    catch (Exception e)
                    {
                        if (e is GdOpException) Fail("'" + memberName + "' is not available to tales.");
                        else Fail(e.Message);
                        return null;
                    }
                }
                Fail("'" + memberName + "' is not available to tales.");
                return null;
            }
            if (IsObject(target)) return ObjectError();
            var dictionary = target as TaleDict;
            if (dictionary != null)
            {
                object value;
                if (!dictionary.TryGetValue(memberName, out value))
                {
                    Fail("The dictionary has no key '" + memberName + "'.");
                    return null;
                }
                return value;
            }
            Fail(GdValue.TypeName(target) + " has no property '" + memberName + "'.");
            return null;
        }

        // --- Internals ------------------------------------------------------------

        private async Task<object> BinaryExpr(TaleExpr expr, TaleFrame frame)
        {
            string op = expr.Op;
            object left = await Evaluate(expr.Operands[0], frame);
            if (op == "and")
                return GdValue.Truthy(left) && GdValue.Truthy(await Evaluate(expr.Operands[1], frame));
            if (op == "or")
                return GdValue.Truthy(left) || GdValue.Truthy(await Evaluate(expr.Operands[1], frame));
            object right = await Evaluate(expr.Operands[1], frame);
            if (Failed()) return null;
            return Binary(op, left, right);
        }

        private object Unary(string op, object operand)
        {
            if (Failed()) return null;
            if (op == "not") return !GdValue.Truthy(operand);
            if (op == "-" && operand is long) return unchecked(-(long)operand);
            if (op == "-" && operand is double) return -(double)operand;
            if (op == "+" && GdValue.IsNumber(operand)) return operand;
            if (op == "~" && operand is long) return ~(long)operand;
            Fail("Can't use '" + op + "' with " + GdValue.TypeName(operand) + ".");
            return null;
        }

        private bool Contains(object container, object item)
        {
            if (IsObject(container))
            {
                ObjectError();
                return false;
            }
            if (Failed()) return false;
            try
            {
                return GdValue.Contains(container, item);
            }
            catch (GdOpException)
            {
                Fail("Can't use 'in' with " + GdValue.TypeName(container) + ".");
                return false;
            }
        }

        private async Task<object> Call(TaleExpr expr, TaleFrame frame)
        {
            var callee = expr.Operands[0];
            var args = new List<object>();
            foreach (var argument in expr.Args) args.Add(await Evaluate(argument, frame));
            var named = new OrderedMap<object>();
            foreach (string key in expr.NamedArgs.Keys) named[key] = await Evaluate(expr.NamedArgs[key], frame);
            if (Failed()) return null;
            if (callee.Kind == TaleExprKind.Identifier)
                return _director.CallFunction(callee.Name, args, named, frame);
            if (callee.Kind == TaleExprKind.Attribute)
            {
                object target = await Evaluate(callee.Operands[0], frame);
                if (Failed()) return null;
                return CallMethod(target, callee.Name, args, named);
            }
            Fail("This value can't be called.");
            return null;
        }

        private object CallMethod(object target, string method, List<object> args, OrderedMap<object> named)
        {
            if (!named.IsEmpty)
            {
                Fail("Named arguments only work with actions.");
                return null;
            }
            if (target is TaleNamespace ns)
            {
                Fail("Beats can only be called on a line of their own, e.g. " + ns.TaleName + "." + method + "().");
                return null;
            }
            if (target is TaleExposed exposed)
            {
                if (!exposed.Methods.Contains(method))
                {
                    Fail("'" + method + "' is not available to tales.");
                    return null;
                }
                object[] values = args.ToArray();
                return _director.StartTask(() => exposed.Call(method, values));
            }
            if (IsObject(target)) return ObjectError();
            try
            {
                return GdMethods.Call(target, method, args.ToArray());
            }
            catch (GdOpException)
            {
                Fail("Can't call '" + method + "' on " + GdValue.TypeName(target) + ".");
                return null;
            }
        }

        private async Task Store(TaleExpr place, object value, TaleFrame frame)
        {
            switch (place.Kind)
            {
                case TaleExprKind.Identifier:
                {
                    string problem = _director.AssignName(place.Name, value, frame);
                    if (problem.Length > 0) Fail(problem);
                    break;
                }
                case TaleExprKind.Attribute:
                {
                    object target = await Evaluate(place.Operands[0], frame);
                    if (Failed()) return;
                    string member = place.Name;
                    if (target is TaleNamespace ns)
                    {
                        string problem = _director.SetTaleVar(ns.TaleName, member, value);
                        if (problem.Length > 0) Fail(problem);
                    }
                    else if (target is TaleExposed exposed)
                    {
                        if (exposed.Properties.Contains(member))
                        {
                            try
                            {
                                exposed.SetProperty(member, value);
                            }
                            catch (Exception e)
                            {
                                Fail(e is GdOpException ? "'" + member + "' can't be changed by tales." : e.Message);
                            }
                        }
                        else
                        {
                            Fail("'" + member + "' can't be changed by tales.");
                        }
                    }
                    else if (IsObject(target))
                    {
                        ObjectError();
                    }
                    else if (target is TaleDict dictionary)
                    {
                        dictionary[member] = value;
                    }
                    else
                    {
                        Fail("Can't change '" + member + "' of " + GdValue.TypeName(target) + ".");
                    }
                    break;
                }
                case TaleExprKind.Index:
                {
                    object container = await Evaluate(place.Operands[0], frame);
                    object key = await Evaluate(place.Operands[1], frame);
                    if (Failed()) return;
                    if (container is TaleDict dictionary)
                    {
                        dictionary[key] = value;
                    }
                    else if (container is List<object> list)
                    {
                        if (!(key is long index && index >= -list.Count && index < list.Count))
                        {
                            Fail("Index " + GdValue.Str(key) + " is outside the array (size " + list.Count + ").");
                            return;
                        }
                        list[(int)(index < 0 ? index + list.Count : index)] = value;
                    }
                    else
                    {
                        Fail("Can't change items of " + GdValue.TypeName(container) + ".");
                    }
                    break;
                }
                default:
                    Fail("Can't assign to this expression.");
                    break;
            }
        }

        /// <summary>Constants of value types such as Color.RED. The host supplies them with <see cref="TaleDirector.TypeConstants"/>.</summary>
        private object TypeConstant(string typeName, string constant)
        {
            object value;
            if (_director.TypeConstants != null && _director.TypeConstants(typeName, constant, out value)) return value;
            Fail(typeName + " has no constant '" + constant + "'.");
            return null;
        }

        private object ObjectError()
        {
            Fail("Tales can only use objects that game code exposes with Story.expose().");
            return null;
        }
    }
}
