using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>emit(name, value = null): tells game code that something happened. Game code listens to <see cref="TaleDirector.StorySignal"/>.</summary>
    public class EmitAction : TaleAction
    {
        public EmitAction() : base("emit", new[] { "signal_name", "value" }, 1, new object[] { null })
        {
        }

        public override void Run(TaleContext context, object[] args)
        {
            context.Director.RaiseSignal(GdValue.Str(args[0]), args[1]);
        }
    }

    /// <summary>wait(seconds): pauses for a number of seconds. Use with await to hold the tale, or without it to delay the next dialogue line.</summary>
    public class WaitAction : TaleAction
    {
        public WaitAction() : base("wait", new[] { "seconds" }, 1)
        {
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            await context.Wait(GdValue.ToDouble(args[0]));
            return null;
        }
    }
}
