using System;
using System.Reflection;
using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>
    /// A running action or function call that may finish later. Host code can
    /// return a Task or Task&lt;T&gt;; the director wraps one that has not finished.
    /// </summary>
    public class TaleTask
    {
        private readonly Task _task;

        public TaleTask(Task task)
        {
            _task = task;
        }

        public bool IsDone { get { return _task.IsCompleted; } }

        /// <summary>Waits until the task finishes and returns its result.</summary>
        public async Task<object> Wait()
        {
            await _task;
            return ResultOf(_task);
        }

        /// <summary>Waits for any task and returns its value, or null for a plain Task.</summary>
        public static async Task<object> Await(Task task)
        {
            await task;
            return ResultOf(task);
        }

        /// <summary>The result of a finished task, as a tale value. A plain Task gives null.</summary>
        public static object ResultOf(Task task)
        {
            Type type = task.GetType();
            if (!type.IsGenericType) return null;
            PropertyInfo property = type.GetProperty("Result");
            if (property == null || property.PropertyType.Name == "VoidTaskResult") return null;
            return GdValue.Normalize(property.GetValue(task, null));
        }

        /// <summary>Wraps a host return value. A Task that has finished gives its result at once.</summary>
        public static object FromReturn(object value)
        {
            Task task = value as Task;
            if (task == null) return GdValue.Normalize(value);
            if (task.IsCompleted)
            {
                if (task.IsFaulted) throw task.Exception.InnerException ?? task.Exception;
                if (task.IsCanceled) throw new OperationCanceledException();
                return ResultOf(task);
            }
            return new TaleTask(task);
        }
    }
}
