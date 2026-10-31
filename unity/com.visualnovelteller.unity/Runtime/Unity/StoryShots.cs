using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;
using UnityEngine.Playables;

namespace VisualNovelTeller
{
    /// <summary>A Timeline asset a tale can play by name.</summary>
    [Serializable]
    public class TimelineShot
    {
        public string name = "";
        public PlayableAsset asset;
        [Tooltip("Loop the timeline. A tale that plays a looping shot continues at once.")]
        public bool loop;
    }

    /// <summary>
    /// Plays a scene's animations for tales, one shot at a time, and remembers the shot
    /// showing so saves can include it. Made for stories told in your own 3D or 2D scene,
    /// such as characters rigged and animated in Blender, which pause for the player's
    /// choices.
    /// A shot is a state of the <see cref="Animator"/>, or a Timeline asset listed on this
    /// component for a <see cref="PlayableDirector"/>. Tales use it as <c>shots</c>:
    /// <code>
    /// await shots.play("approach")   # plays a shot and waits for its end
    /// shots.hold("idle_wait")        # starts a looping pose; the tale goes on
    /// if shots.has_shot("wave"):
    ///     shots.play("wave")
    /// </code>
    /// While the player skips, a shot jumps to its last frame.
    /// </summary>
    public class StoryShots : MonoBehaviour, ITaleObject, ITaleStateProvider
    {
        [Tooltip("The Animator whose states are the shots.")]
        [SerializeField] private Animator animator;
        [Tooltip("The animator layer the shots live on.")]
        [SerializeField] private int animatorLayer;
        [Tooltip("The PlayableDirector that plays the Timeline shots below.")]
        [SerializeField] private PlayableDirector playableDirector;
        [SerializeField] private List<TimelineShot> timelineShots = new List<TimelineShot>();

        private Story _story;
        private int _generation;

        /// <summary>Raised when a shot starts. The second value is true for a held pose.</summary>
        public event Action<string, bool> ShotStarted;

        /// <summary>The shot showing, or "".</summary>
        public string Current { get; private set; }
        /// <summary>True when <see cref="Current"/> is a held pose rather than a played shot.</summary>
        public bool Holding { get; private set; }

        private void Awake()
        {
            Current = "";
        }

        /// <summary>Connects the shots to a story. <see cref="Story"/> calls this.</summary>
        public void Attach(Story story)
        {
            _story = story;
        }

        /// <summary>Plays shots from this Animator from now on, and puts it in the state a restore asked for.</summary>
        public void Use(Animator newAnimator)
        {
            animator = newAnimator;
            ShowCurrent();
        }

        /// <summary>Plays Timeline shots from this director from now on, and puts it in the state a restore asked for.</summary>
        public void Use(PlayableDirector newDirector)
        {
            playableDirector = newDirector;
            ShowCurrent();
        }

        /// <summary>True when the Animator has a state called shot, or a Timeline shot has that name.</summary>
        public bool HasShot(string shot)
        {
            return HasState(shot) || FindTimeline(shot) != null;
        }

        /// <summary>
        /// Plays a shot and completes when it ends. A looping shot completes at once. A shot
        /// that does not exist is reported and skipped.
        /// </summary>
        public async Task Play(string shot)
        {
            int generation = ++_generation;
            EnsureStory();
            Current = shot;
            Holding = false;
            if (ShotStarted != null) ShotStarted(shot, false);
            bool skipping = _story != null && _story.Skipping;
            if (HasState(shot))
            {
                animator.Play(shot, animatorLayer, skipping ? 1f : 0f);
                animator.Update(0f);
                if (skipping) return;
                if (EnsureStory()) await WaitForState(shot, generation);
                return;
            }
            TimelineShot timeline = FindTimeline(shot);
            if (timeline != null && playableDirector != null)
            {
                if (skipping)
                {
                    StartTimeline(timeline, false);
                    playableDirector.time = timeline.asset.duration;
                    playableDirector.Evaluate();
                    return;
                }
                StartTimeline(timeline, timeline.loop);
                if (timeline.loop) return;
                if (EnsureStory()) await WaitForTimeline(generation);
                return;
            }
            Report("Shot '" + shot + "' was not found.");
        }

        /// <summary>Starts a shot, usually a looping pose, and returns at once.</summary>
        public void Hold(string shot)
        {
            ++_generation;
            Current = shot;
            Holding = true;
            if (ShotStarted != null) ShotStarted(shot, true);
            if (HasState(shot))
            {
                animator.Play(shot, animatorLayer, 0f);
                return;
            }
            TimelineShot timeline = FindTimeline(shot);
            if (timeline != null && playableDirector != null)
            {
                StartTimeline(timeline, true);
                return;
            }
            Report("Shot '" + shot + "' was not found.");
        }

        /// <summary>Forgets the current shot and stops the Timeline.</summary>
        public void Clear()
        {
            ++_generation;
            Current = "";
            Holding = false;
            if (playableDirector != null) playableDirector.Stop();
        }

        /// <summary>The key of the shots in a save.</summary>
        public string Name { get { return "Shots"; } }

        /// <summary>The state to keep in a save, as plain data with the keys "current" and "holding".</summary>
        public object Capture()
        {
            var data = new OrderedMap<object>();
            data["current"] = Current ?? "";
            data["holding"] = Holding;
            return data;
        }

        /// <summary>Puts the scene back from data made by <see cref="Capture"/>: a held pose plays again, and a played shot shows its last frame.</summary>
        public void Restore(object saved)
        {
            ++_generation;
            var data = saved as OrderedMap<object>;
            object value;
            Current = data != null && data.TryGetValue("current", out value) && value != null ? GdValue.Str(value) : "";
            Holding = data != null && data.TryGetValue("holding", out value) && GdValue.Truthy(value);
            ShowCurrent();
        }

        // --- ITaleObject: shots.play(), shots.hold(), shots.has_shot(), shots.current ---

        public bool TryGetProperty(string name, out object value)
        {
            if (name == "current")
            {
                value = Current ?? "";
                return true;
            }
            value = null;
            return false;
        }

        public bool TrySetProperty(string name, object value)
        {
            return false;
        }

        public object CallMethod(string name, object[] args)
        {
            string shot = args.Length > 0 && args[0] != null ? GdValue.Str(args[0]) : "";
            switch (name)
            {
                case "play":
                    return Play(shot);
                case "hold":
                    Hold(shot);
                    return null;
                case "has_shot":
                    return HasShot(shot);
            }
            throw new GdOpException();
        }

        // --- Helpers ------------------------------------------------------------

        private void ShowCurrent()
        {
            if (string.IsNullOrEmpty(Current)) return;
            if (HasState(Current))
            {
                animator.Play(Current, animatorLayer, Holding ? 0f : 1f);
                animator.Update(0f);
                return;
            }
            TimelineShot timeline = FindTimeline(Current);
            if (timeline != null && playableDirector != null)
            {
                StartTimeline(timeline, Holding);
                if (!Holding)
                {
                    playableDirector.time = timeline.asset.duration;
                    playableDirector.Evaluate();
                }
            }
        }

        private bool HasState(string shot)
        {
            return animator != null && animator.runtimeAnimatorController != null && !string.IsNullOrEmpty(shot)
                && animator.HasState(animatorLayer, Animator.StringToHash(shot));
        }

        private TimelineShot FindTimeline(string shot)
        {
            foreach (var entry in timelineShots)
                if (entry.name == shot && entry.asset != null) return entry;
            return null;
        }

        private void StartTimeline(TimelineShot timeline, bool loop)
        {
            playableDirector.playableAsset = timeline.asset;
            playableDirector.extrapolationMode = loop ? DirectorWrapMode.Loop : DirectorWrapMode.None;
            playableDirector.time = 0.0;
            if (!(_story != null && _story.Skipping && !loop)) playableDirector.Play();
        }

        private async Task WaitForState(string shot, int generation)
        {
            while (generation == _generation && animator != null)
            {
                AnimatorStateInfo info = animator.GetCurrentAnimatorStateInfo(animatorLayer);
                if (!info.IsName(shot)) return;
                if (info.loop) return;
                if (info.normalizedTime >= 1f) return;
                if (_story != null && _story.Skipping)
                {
                    animator.Play(shot, animatorLayer, 1f);
                    animator.Update(0f);
                    return;
                }
                await NextFrame();
            }
        }

        private async Task WaitForTimeline(int generation)
        {
            var finished = new TaskCompletionSource<bool>();
            Action<PlayableDirector> onStopped = delegate (PlayableDirector stopped)
            {
                finished.TrySetResult(true);
            };
            playableDirector.stopped += onStopped;
            try
            {
                while (generation == _generation && !finished.Task.IsCompleted && playableDirector != null)
                {
                    if (_story != null && _story.Skipping)
                    {
                        playableDirector.time = playableDirector.playableAsset.duration;
                        playableDirector.Evaluate();
                        return;
                    }
                    await NextFrame();
                }
            }
            finally
            {
                if (playableDirector != null) playableDirector.stopped -= onStopped;
            }
        }

        private Task NextFrame()
        {
            return _story.NextFrame();
        }

        /// <summary>Finds the Story in the scene when no one attached this component. Returns false when there is none.</summary>
        private bool EnsureStory()
        {
            if (_story == null) _story = FindFirstObjectByType<Story>();
            return _story != null;
        }

        private void Report(string message)
        {
            if (_story != null) _story.Director.ReportError(message);
            else Debug.LogError("StoryShots: " + message);
        }
    }
}
