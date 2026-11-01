using System.Collections.Generic;
using System.Threading.Tasks;
using TaleScript;
using UnityEngine;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>
    /// A character at runtime. Tales reach it by its id: <c>mira.enter("smile", LEFT)</c>,
    /// <c>mira.mood = "worried"</c>, <c>await mira.move_to(CENTER, 0.6)</c>. The look on
    /// screen comes from <see cref="Stage2D"/>; without one the actor still gives the
    /// dialogue its name and color.
    /// </summary>
    public sealed class CastActor : ITaleObject, ITaleSignatures
    {
        private readonly Story _story;
        private string _nameOverride = "";
        private string _mood = "";

        /// <summary>The config entry this actor comes from.</summary>
        public CastMember Member { get; private set; }
        /// <summary>True between enter() and exit().</summary>
        public bool OnStage { get; internal set; }
        /// <summary>Mirrors the character horizontally.</summary>
        public bool Flip { get; set; }
        /// <summary>Higher numbers draw in front.</summary>
        public int DrawOrder { get; set; }
        /// <summary>Color multiplied over the sprite.</summary>
        public Color Tint { get; set; }

        // Layout state that Stage2D reads and writes.
        internal Image View;
        internal int FirstUse;
        internal bool Visible;
        internal bool Highlighted = true;
        internal Vector2 Position = new Vector2(0.5f, 0f);
        internal float Scale = 1f;
        internal float Alpha = 1f;
        internal Vector2 OffsetPixels;
        internal int AlphaToken;
        internal int MoveToken;
        internal int ScaleToken;
        internal int MotionToken;

        public CastActor(Story story, CastMember member)
        {
            _story = story;
            Member = member;
            Tint = Color.white;
            Scale = member.scale <= 0f ? 1f : member.scale;
        }

        /// <summary>The id tales use.</summary>
        public string Id { get { return Member.id; } }

        /// <summary>The name shown in the dialogue box.</summary>
        public string DisplayName
        {
            get
            {
                if (!string.IsNullOrEmpty(_nameOverride)) return _nameOverride;
                if (!string.IsNullOrEmpty(Member.displayName)) return Member.displayName;
                return GdMethods.Capitalize(Member.id);
            }
        }

        /// <summary>The current mood name.</summary>
        public string Mood { get { return _mood; } }

        /// <summary>The mood sprite to show, using the default or first mood when none is set.</summary>
        public Sprite CurrentSprite()
        {
            Sprite sprite = string.IsNullOrEmpty(_mood) ? null : Member.FindMood(_mood);
            if (sprite == null && !string.IsNullOrEmpty(Member.defaultMood)) sprite = Member.FindMood(Member.defaultMood);
            if (sprite == null && Member.moods.Count > 0) sprite = Member.moods[0].sprite;
            return sprite;
        }

        /// <summary>Changes the mood. A mood the cast member lacks is reported and ignored.</summary>
        public void SetMood(string mood)
        {
            if (string.IsNullOrEmpty(mood)) return;
            if (Member.moods.Count > 0 && Member.FindMood(mood) == null)
            {
                _story.Director.ReportError(Member.id + " has no mood '" + mood + "'.");
                return;
            }
            _mood = mood;
            Refresh();
        }

        /// <summary>Puts the actor back in its starting state, off stage, for a restore. Running motions stop.</summary>
        internal void ResetForRestore()
        {
            _nameOverride = "";
            _mood = "";
            OnStage = false;
            Visible = false;
            Flip = false;
            DrawOrder = 0;
            Tint = Color.white;
            Scale = Member.scale <= 0f ? 1f : Member.scale;
            Alpha = 1f;
            OffsetPixels = Vector2.zero;
            Position = new Vector2(0.5f, 0f);
            AlphaToken++;
            MoveToken++;
            ScaleToken++;
            MotionToken++;
        }

        /// <summary>Draws the actor again after a change.</summary>
        public void Refresh()
        {
            Stage2D stage = _story.Stage;
            if (stage != null) stage.Layout(this);
        }

        /// <summary>The object tales get when they use this actor's id.</summary>
        public TaleExposed MakeExposed()
        {
            return new CastExposed(this);
        }

        // --- ITaleSignatures: the same parameter names as the Godot cast member ---

        private static readonly Dictionary<string, string[]> Parameters = new Dictionary<string, string[]>
        {
            { "enter", new[] { "mood_name", "at", "time", "transition" } },
            { "exit", new[] { "time", "transition" } },
            { "move_to", new[] { "at", "time" } },
            { "scale_to", new[] { "factor", "time" } },
            { "hop", new[] { "height", "time" } },
            { "shake", new[] { "strength", "time" } },
            { "nod", new[] { "time" } },
            { "animate", new[] { "animation_name" } },
            { "to_front", new string[0] },
            { "to_back", new string[0] },
        };

        public IReadOnlyList<string> GetParameters(string method)
        {
            string[] names;
            return Parameters.TryGetValue(method, out names) ? names : null;
        }

        // --- ITaleObject --------------------------------------------------------

        public bool TryGetProperty(string name, out object value)
        {
            switch (name)
            {
                case "display_name": value = DisplayName; return true;
                case "draw_order": value = (long)DrawOrder; return true;
                case "flip": value = Flip; return true;
                case "mood": value = _mood; return true;
                case "on_stage": value = OnStage; return true;
                case "tint": value = Tint; return true;
            }
            value = null;
            return false;
        }

        public bool TrySetProperty(string name, object value)
        {
            switch (name)
            {
                case "display_name":
                    _nameOverride = value == null ? "" : GdValue.Str(value);
                    return true;
                case "draw_order":
                    DrawOrder = (int)GdValue.ToLong(value);
                    if (_story.Stage != null) _story.Stage.ReorderCast();
                    return true;
                case "flip":
                    Flip = GdValue.Truthy(value);
                    Refresh();
                    return true;
                case "mood":
                    SetMood(GdValue.Str(value));
                    return true;
                case "tint":
                    if (!(value is Color)) return false;
                    Tint = (Color)value;
                    Refresh();
                    return true;
            }
            return false;
        }

        public object CallMethod(string name, object[] args)
        {
            if (name == "animate")
            {
                _story.Director.ReportError("animate() is not available on the 2D stage. Use shots for animated scenes.");
                return Task.CompletedTask;
            }
            Stage2D stage = _story.Stage;
            if (stage == null)
            {
                _story.Director.ReportError(Member.id + "." + name + "() needs a Stage2D in the scene.");
                return Task.CompletedTask;
            }
            switch (name)
            {
                case "enter":
                    return stage.Enter(this, TaleValues.ToText(At(args, 0)),
                        TaleValues.ToPosition(At(args, 1), new Vector2(0.5f, 0f)),
                        TaleValues.ToFloat(At(args, 2), 0.4f), TaleValues.ToText(At(args, 3), "fade"));
                case "exit":
                    return stage.Exit(this, TaleValues.ToFloat(At(args, 0), 0.4f), TaleValues.ToText(At(args, 1), "fade"));
                case "move_to":
                    return stage.MoveTo(this, TaleValues.ToPosition(At(args, 0), Position), TaleValues.ToFloat(At(args, 1), 0.5f));
                case "scale_to":
                    return stage.ScaleTo(this, TaleValues.ToFloat(At(args, 0), 1f), TaleValues.ToFloat(At(args, 1), 0.3f));
                case "hop":
                    return stage.Hop(this, TaleValues.ToFloat(At(args, 0), 0.04f), TaleValues.ToFloat(At(args, 1), 0.35f));
                case "shake":
                    return stage.Shake(this, TaleValues.ToFloat(At(args, 0), 0.5f), TaleValues.ToFloat(At(args, 1), 0.4f));
                case "nod":
                    return stage.Nod(this, TaleValues.ToFloat(At(args, 0), 0.5f));
                case "to_front":
                    DrawOrder = stage.HighestOrder() + 1;
                    stage.ReorderCast();
                    return Task.CompletedTask;
                case "to_back":
                    DrawOrder = stage.LowestOrder() - 1;
                    stage.ReorderCast();
                    return Task.CompletedTask;
            }
            throw new GdOpException();
        }

        private static object At(object[] args, int index)
        {
            return index < args.Length ? args[index] : null;
        }
    }

    /// <summary>
    /// What a tale holds when it uses a cast id. It limits tales to the cast methods and
    /// properties, and gives the dialogue the name and color to show.
    /// </summary>
    public sealed class CastExposed : TaleExposed, ITaleSpeaker
    {
        private readonly CastActor _actor;

        public CastExposed(CastActor actor)
            : base(actor, TaleCheckContext.CastMethods, TaleCheckContext.CastProperties)
        {
            _actor = actor;
        }

        public string DisplayName { get { return _actor.DisplayName; } }
        public object NameColor { get { return _actor.Member.color; } }
    }
}
