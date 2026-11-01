using System.Threading.Tasks;
using TaleScript;

namespace VisualNovelTeller
{
    /// <summary>
    /// The actions that come with the Unity layer, with the names and parameters of the
    /// Godot version so the same tales run in both: backdrop, exit_all, music,
    /// stop_music, and sound. The core adds emit and wait.
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
}
