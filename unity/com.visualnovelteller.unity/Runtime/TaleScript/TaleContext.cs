using System.Threading.Tasks;

namespace TaleScript
{
    /// <summary>Passed to every action. Gives access to the director and helpers that respect skipping.</summary>
    public class TaleContext
    {
        public TaleDirector Director { get; private set; }

        public TaleContext(TaleDirector director)
        {
            Director = director;
        }

        /// <summary>True while the player is skipping. Actions should finish instantly.</summary>
        public bool IsSkipping { get { return Director.Skipping; } }

        /// <summary>Waits the given seconds, or finishes at once while skipping.</summary>
        public Task Wait(double seconds)
        {
            if (seconds <= 0.0 || Director.Skipping) return Task.CompletedTask;
            if (Director.Waiter != null) return Director.Waiter(seconds);
            return Task.Delay((int)(seconds * 1000.0));
        }

        /// <summary>Reports a problem with the current line through RuntimeError. The tale continues.</summary>
        public void Fail(string message)
        {
            Director.ReportError(message);
        }
    }
}
