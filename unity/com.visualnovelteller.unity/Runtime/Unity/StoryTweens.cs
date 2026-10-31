using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace VisualNovelTeller
{
    /// <summary>
    /// Runs short timed changes, such as a fade, and hands back a Task that completes when
    /// the change ends. The owner calls <see cref="Tick"/> from its Update, so everything
    /// runs on Unity's main thread.
    /// </summary>
    public class StoryTweens
    {
        private class Tween
        {
            public float Duration;
            public float Elapsed;
            public Action<float> Apply;
            public TaskCompletionSource<bool> Done;
        }

        private readonly List<Tween> _tweens = new List<Tween>();

        /// <summary>True while some change is still running.</summary>
        public bool IsRunning { get { return _tweens.Count > 0; } }

        /// <summary>
        /// Calls <paramref name="apply"/> with a value from 0 to 1 over the given seconds. The
        /// last call always has 1. With no time, or while <paramref name="instant"/> is true,
        /// it applies 1 at once and returns a finished task.
        /// </summary>
        public Task Run(float seconds, Action<float> apply, bool instant = false)
        {
            if (seconds <= 0f || instant)
            {
                apply(1f);
                return Task.CompletedTask;
            }
            apply(0f);
            var tween = new Tween
            {
                Duration = seconds,
                Apply = apply,
                Done = new TaskCompletionSource<bool>(),
            };
            _tweens.Add(tween);
            return tween.Done.Task;
        }

        /// <summary>Moves every running change forward. With <paramref name="finishAll"/> they all end now.</summary>
        public void Tick(float deltaTime, bool finishAll)
        {
            if (_tweens.Count == 0) return;
            var snapshot = _tweens.ToArray();
            foreach (var tween in snapshot)
            {
                tween.Elapsed += deltaTime;
                bool finished = finishAll || tween.Elapsed >= tween.Duration;
                if (finished)
                {
                    _tweens.Remove(tween);
                    tween.Apply(1f);
                    tween.Done.TrySetResult(true);
                }
                else
                {
                    tween.Apply(tween.Elapsed / tween.Duration);
                }
            }
        }

        /// <summary>Ends every running change at its final value.</summary>
        public void FinishAll()
        {
            Tick(0f, true);
        }
    }
}
