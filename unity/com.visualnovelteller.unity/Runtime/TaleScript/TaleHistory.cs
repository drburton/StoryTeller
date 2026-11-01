using System;
using System.Collections.Generic;

namespace TaleScript
{
    /// <summary>
    /// Lets the player step back to earlier lines and choices. A snapshot of the whole story
    /// (<see cref="TaleDirector.Capture"/>) is kept each time a line or choice appears.
    /// Rewinding loads an earlier snapshot. Lines marked @no_rewind clear the snapshots, so
    /// the player can't go back past them.
    /// </summary>
    public class TaleHistory
    {
        /// <summary>Emitted after a rewind restored the story, before it resumes.</summary>
        public event Action Rewound;

        /// <summary>Most snapshots kept besides the current one.</summary>
        public int Depth;

        private readonly TaleDirector _director;
        private readonly List<OrderedMap<object>> _snapshots = new List<OrderedMap<object>>();
        private bool _rewinding;

        public TaleHistory(TaleDirector director, int depth = 50)
        {
            _director = director;
            Depth = depth;
            director.LineStarted += OnShown;
            director.ChoiceStarted += OnChoice;
            director.RewindBarrier += Clear;
            director.StoryStarted += OnStarted;
        }

        /// <summary>Stops listening to the director.</summary>
        public void Detach()
        {
            _director.LineStarted -= OnShown;
            _director.ChoiceStarted -= OnChoice;
            _director.RewindBarrier -= Clear;
            _director.StoryStarted -= OnStarted;
        }

        public void Clear()
        {
            _snapshots.Clear();
        }

        public bool CanRewind { get { return _snapshots.Count >= 2 && _director.IsPlaying; } }

        /// <summary>Number of steps back that are possible.</summary>
        public int AvailableSteps { get { return Math.Max(_snapshots.Count - 1, 0); } }

        /// <summary>Snapshots kept now, oldest first, for tests and tools.</summary>
        public IReadOnlyList<OrderedMap<object>> Snapshots { get { return _snapshots; } }

        /// <summary>Goes back <paramref name="steps"/> lines or choices and resumes play. Returns false if that is not possible.</summary>
        public bool Rewind(int steps = 1)
        {
            if (steps < 1 || _snapshots.Count <= steps || _rewinding) return false;
            _rewinding = true;
            for (int i = 0; i < steps; i++) _snapshots.RemoveAt(_snapshots.Count - 1);
            // The target is shown again, which takes a new snapshot of it.
            OrderedMap<object> target = _snapshots[_snapshots.Count - 1];
            _snapshots.RemoveAt(_snapshots.Count - 1);
            _director.Restore(target);
            _rewinding = false;
            if (Rewound != null) Rewound();
            Ignore(_director.Resume());
            return true;
        }

        private static void Ignore(System.Threading.Tasks.Task task)
        {
            // The run loop reports its own errors; nothing to await here.
            GC.KeepAlive(task);
        }

        private void OnStarted(string taleName, string beat)
        {
            Clear();
        }

        private void OnShown(OrderedMap<object> line)
        {
            Snapshot();
        }

        private void OnChoice(List<OrderedMap<object>> options)
        {
            Snapshot();
        }

        private void Snapshot()
        {
            if (_rewinding) return;
            // A round trip through JSON makes an independent copy.
            _snapshots.Add((OrderedMap<object>)GdJson.Parse(GdJson.Stringify(_director.Capture())));
            while (_snapshots.Count > Depth + 1) _snapshots.RemoveAt(0);
        }
    }
}
