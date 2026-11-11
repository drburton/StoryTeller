using System.Threading.Tasks;
using TaleScript;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// The actions that come with the Unity layer, with the names and parameters of the
    /// Godot version so the same tales run in both: backdrop, exit_all, music,
    /// stop_music, sound, fade_out, fade_in, flash, shake, filter, and weather. The core
    /// adds emit and wait.
    /// </summary>
    public static class StoryActions
    {
        /// <summary>
        /// Adds the actions to a director. Pass null for the story to register the
        /// signatures only, which is enough for checking tales.
        /// </summary>
        public static void Register(TaleDirector director, Story story)
        {
            director.AddAction(new BackdropAction(story));
            director.AddAction(new ExitAllAction(story));
            director.AddAction(new MusicAction(story));
            director.AddAction(new StopMusicAction(story));
            director.AddAction(new SoundAction(story));
            director.AddAction(new FadeOutAction(story));
            director.AddAction(new FadeInAction(story));
            director.AddAction(new FlashAction(story));
            director.AddAction(new ShakeAction(story));
            director.AddAction(new FilterAction(story));
            director.AddAction(new WeatherAction(story));
        }
    }

    /// <summary>backdrop(name, transition = "fade", time = 1.0, mask = ""): shows a backdrop from the Story Config, or a Color such as Color.BLACK. Color.TRANSPARENT removes it. The mask is ignored on the 2D stage.</summary>
    public class BackdropAction : TaleAction
    {
        private readonly Story _story;

        public BackdropAction(Story story)
            : base("backdrop", new[] { "name", "transition", "time", "mask" }, 1, new object[] { "fade", 1.0, "" })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            Stage2D stage = _story.Stage;
            if (stage == null)
            {
                context.Fail("backdrop() needs a Stage2D in the scene.");
                return null;
            }
            await stage.ShowBackdrop(args[0], TaleValues.ToText(args[1], "fade"), TaleValues.ToFloat(args[2], 1f));
            return null;
        }
    }

    /// <summary>exit_all(time = 0.4): every cast member on stage exits.</summary>
    public class ExitAllAction : TaleAction
    {
        private readonly Story _story;

        public ExitAllAction(Story story)
            : base("exit_all", new[] { "time" }, 0, new object[] { 0.4 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            Stage2D stage = _story.Stage;
            if (stage == null)
            {
                context.Fail("exit_all() needs a Stage2D in the scene.");
                return null;
            }
            await stage.ExitAll(TaleValues.ToFloat(args[0], 0.4f));
            return null;
        }
    }

    /// <summary>music(track, volume = 1.0, fade = 1.0, loop = true): plays a music track from the Story Config, crossfading from the current one.</summary>
    public class MusicAction : TaleAction
    {
        private readonly Story _story;

        public MusicAction(Story story)
            : base("music", new[] { "track", "volume", "fade", "loop" }, 1, new object[] { 1.0, 1.0, true })
        {
            _story = story;
        }

        public override void Run(TaleContext context, object[] args)
        {
            StoryAudio audio = _story.Audio;
            if (audio == null)
            {
                context.Fail("music() needs a StoryAudio in the scene.");
                return;
            }
            string problem = audio.PlayMusic(TaleValues.ToText(args[0]), TaleValues.ToFloat(args[1], 1f),
                TaleValues.ToFloat(args[2], 1f), GdValue.Truthy(args[3]));
            if (problem.Length > 0) context.Fail(problem);
        }
    }

    /// <summary>stop_music(fade = 1.0): fades out the music.</summary>
    public class StopMusicAction : TaleAction
    {
        private readonly Story _story;

        public StopMusicAction(Story story)
            : base("stop_music", new[] { "fade" }, 0, new object[] { 1.0 })
        {
            _story = story;
        }

        public override void Run(TaleContext context, object[] args)
        {
            StoryAudio audio = _story.Audio;
            if (audio != null) audio.StopMusic(TaleValues.ToFloat(args[0], 1f));
        }
    }

    /// <summary>sound(name, volume = 1.0): plays a sound effect from the Story Config. Use await to wait until it ends.</summary>
    public class SoundAction : TaleAction
    {
        private readonly Story _story;

        public SoundAction(Story story)
            : base("sound", new[] { "name", "volume" }, 1, new object[] { 1.0 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            StoryAudio audio = _story.Audio;
            if (audio == null)
            {
                context.Fail("sound() needs a StoryAudio in the scene.");
                return null;
            }
            string problem = await audio.PlaySound(TaleValues.ToText(args[0]), TaleValues.ToFloat(args[1], 1f));
            if (problem.Length > 0) context.Fail(problem);
            return null;
        }
    }

    /// <summary>fade_out(color = Color.BLACK, time = 0.5): fades the whole screen, dialogue box included, to a color. fade_in() brings it back.</summary>
    public class FadeOutAction : TaleAction
    {
        private readonly Story _story;

        public FadeOutAction(Story story)
            : base("fade_out", new[] { "color", "time" }, 0, new object[] { Color.black, 0.5 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            StoryEffects effects = _story.Effects;
            if (effects == null)
            {
                context.Fail("fade_out() needs a StoryEffects in the scene.");
                return null;
            }
            await effects.FadeOut(EffectArgs.ToColor(args[0], Color.black), TaleValues.ToFloat(args[1], 0.5f));
            return null;
        }
    }

    /// <summary>fade_in(time = 0.5): fades the screen back in after fade_out().</summary>
    public class FadeInAction : TaleAction
    {
        private readonly Story _story;

        public FadeInAction(Story story)
            : base("fade_in", new[] { "time" }, 0, new object[] { 0.5 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            StoryEffects effects = _story.Effects;
            if (effects == null)
            {
                context.Fail("fade_in() needs a StoryEffects in the scene.");
                return null;
            }
            await effects.FadeIn(TaleValues.ToFloat(args[0], 0.5f));
            return null;
        }
    }

    /// <summary>flash(color = Color.WHITE, time = 0.3): flashes the whole screen.</summary>
    public class FlashAction : TaleAction
    {
        private readonly Story _story;

        public FlashAction(Story story)
            : base("flash", new[] { "color", "time" }, 0, new object[] { Color.white, 0.3 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            StoryEffects effects = _story.Effects;
            if (effects == null)
            {
                context.Fail("flash() needs a StoryEffects in the scene.");
                return null;
            }
            await effects.Flash(EffectArgs.ToColor(args[0], Color.white), TaleValues.ToFloat(args[1], 0.3f));
            return null;
        }
    }

    /// <summary>shake(strength = 0.5, time = 0.4): shakes the stage.</summary>
    public class ShakeAction : TaleAction
    {
        private readonly Story _story;

        public ShakeAction(Story story)
            : base("shake", new[] { "strength", "time" }, 0, new object[] { 0.5, 0.4 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            StoryEffects effects = _story.Effects;
            if (effects == null)
            {
                context.Fail("shake() needs a StoryEffects in the scene.");
                return null;
            }
            await effects.Shake(TaleValues.ToFloat(args[0], 0.5f), TaleValues.ToFloat(args[1], 0.4f));
            return null;
        }
    }

    /// <summary>filter(name, strength = 1.0, time = 0.5): recolors the stage with "grayscale", "sepia", "night", "warm", "cold", or "vignette". filter("none") removes it. "blur" is not available in Unity yet.</summary>
    public class FilterAction : TaleAction
    {
        private readonly Story _story;

        public FilterAction(Story story)
            : base("filter", new[] { "name", "strength", "time" }, 1, new object[] { 1.0, 0.5 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            StoryEffects effects = _story.Effects;
            if (effects == null)
            {
                context.Fail("filter() needs a StoryEffects in the scene.");
                return null;
            }
            string problem = await effects.SetFilter(TaleValues.ToText(args[0]), TaleValues.ToFloat(args[1], 1f), TaleValues.ToFloat(args[2], 0.5f));
            if (problem.Length > 0) context.Fail(problem);
            return null;
        }
    }

    /// <summary>weather(kind, strength = 1.0, fade = 1.0): starts "rain" or "snow" over the stage, or stops it with "none".</summary>
    public class WeatherAction : TaleAction
    {
        private readonly Story _story;

        public WeatherAction(Story story)
            : base("weather", new[] { "kind", "strength", "fade" }, 1, new object[] { 1.0, 1.0 })
        {
            _story = story;
        }

        public override async Task<object> RunAsync(TaleContext context, object[] args)
        {
            StoryEffects effects = _story.Effects;
            if (effects == null)
            {
                context.Fail("weather() needs a StoryEffects in the scene.");
                return null;
            }
            string problem = await effects.SetWeather(TaleValues.ToText(args[0]), TaleValues.ToFloat(args[1], 1f), TaleValues.ToFloat(args[2], 1f));
            if (problem.Length > 0) context.Fail(problem);
            return null;
        }
    }

    internal static class EffectArgs
    {
        public static Color ToColor(object value, Color fallback)
        {
            return value is Color ? (Color)value : fallback;
        }
    }
}
