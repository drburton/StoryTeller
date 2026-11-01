using System.Collections.Generic;
using System.Threading.Tasks;

namespace TaleScript.Tests
{
    /// <summary>
    /// A presenter that records lines and choices. With <see cref="Manual"/> set it holds each
    /// line or choice until the test calls <see cref="Continue"/> or <see cref="Pick"/>, which
    /// lets a test act while the story waits for the player.
    /// </summary>
    internal class Player : TalePresenter
    {
        public readonly List<string> Lines = new List<string>();
        public readonly List<string> Choices = new List<string>();
        public bool Manual;
        /// <summary>Index picked by Choose when not manual.</summary>
        public int AutoPick;
        /// <summary>Called inside ShowLine, while the line is on screen.</summary>
        public System.Action<OrderedMap<object>> OnLine;

        private TaskCompletionSource<int> _gate;

        public string Current { get; private set; }

        public override Task ShowLine(OrderedMap<object> line)
        {
            string text = GdValue.Str(line["text"]);
            Lines.Add(text);
            Current = text;
            if (OnLine != null) OnLine(line);
            if (!Manual) return Task.CompletedTask;
            _gate = new TaskCompletionSource<int>();
            return _gate.Task;
        }

        public override Task<int> Choose(List<OrderedMap<object>> options, OrderedMap<object> settings)
        {
            var texts = new List<string>();
            foreach (var option in options) texts.Add(GdValue.Str(option["text"]));
            string joined = string.Join(" | ", texts);
            Choices.Add(joined);
            Current = joined;
            if (!Manual) return Task.FromResult(AutoPick);
            _gate = new TaskCompletionSource<int>();
            return _gate.Task;
        }

        /// <summary>Lets the player move past the line on screen.</summary>
        public void Continue()
        {
            Release(0);
        }

        /// <summary>Picks an option of the choice on screen.</summary>
        public void Pick(int index)
        {
            Release(index);
        }

        public override void Cancel()
        {
            Release(-1);
        }

        private void Release(int value)
        {
            var gate = _gate;
            _gate = null;
            if (gate != null) gate.TrySetResult(value);
        }
    }
}
