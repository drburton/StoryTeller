using System.Threading.Tasks;
using TaleScript;
using UnityEngine;

namespace VisualNovelTeller
{
    /// <summary>
    /// Plays music and sound effects for tales. Music crossfades between two AudioSources.
    /// Tales use <c>music(track, volume, fade, loop)</c>, <c>stop_music(fade)</c>, and
    /// <c>sound(name, volume)</c>, naming clips from the Story Config.
    /// </summary>
    public class StoryAudio : MonoBehaviour, ITaleStateProvider
    {
        [Tooltip("Multiplier for all music, from 0 to 1.")]
        [Range(0f, 1f)] [SerializeField] private float musicVolume = 1f;
        [Tooltip("Multiplier for all sound effects, from 0 to 1.")]
        [Range(0f, 1f)] [SerializeField] private float soundVolume = 1f;

        private readonly StoryTweens _tweens = new StoryTweens();
        private readonly AudioSource[] _music = new AudioSource[2];
        private readonly int[] _fadeTokens = new int[2];
        private readonly float[] _levels = new float[2];
        private AudioSource _sound;
        private Story _story;
        private int _current;
        private string _track = "";
        private float _trackVolume = 1f;
        private bool _trackLoop = true;

        /// <summary>The name of the music playing, or "".</summary>
        public string CurrentTrack { get { return _track; } }

        /// <summary>Multiplier for all music.</summary>
        public float MusicVolume
        {
            get { return musicVolume; }
            set
            {
                musicVolume = Mathf.Clamp01(value);
                ApplyVolume(0);
                ApplyVolume(1);
            }
        }

        /// <summary>Multiplier for all sound effects.</summary>
        public float SoundVolume
        {
            get { return soundVolume; }
            set { soundVolume = Mathf.Clamp01(value); }
        }

        /// <summary>Connects the audio to a story. <see cref="Story"/> calls this.</summary>
        public void Attach(Story story)
        {
            _story = story;
        }

        private void Awake()
        {
            for (int i = 0; i < _music.Length; i++)
            {
                _music[i] = gameObject.AddComponent<AudioSource>();
                _music[i].playOnAwake = false;
                _music[i].volume = 0f;
            }
            _sound = gameObject.AddComponent<AudioSource>();
            _sound.playOnAwake = false;
        }

        private void Update()
        {
            _tweens.Tick(Time.unscaledDeltaTime, _story != null && _story.Skipping);
        }

        /// <summary>
        /// Plays a music track, crossfading from the current one over the given seconds. The
        /// track that is already playing only changes volume. Returns an error message or "".
        /// </summary>
        public string PlayMusic(string track, float volume, float fade, bool loop)
        {
            AudioSource current = _music[_current];
            if (_track == track && current.isPlaying)
            {
                _trackVolume = volume;
                _trackLoop = loop;
                current.loop = loop;
                Fade(_current, volume, fade, false);
                return "";
            }
            AudioClip clip = Find(track);
            if (clip == null) return "Music '" + track + "' was not found in the Story Config.";
            Fade(_current, 0f, fade, true);
            _current = 1 - _current;
            AudioSource next = _music[_current];
            next.clip = clip;
            next.loop = loop;
            _levels[_current] = 0f;
            ApplyVolume(_current);
            next.Play();
            Fade(_current, volume, fade, false);
            _track = track;
            _trackVolume = volume;
            _trackLoop = loop;
            return "";
        }

        /// <summary>Fades out the music over the given seconds.</summary>
        public void StopMusic(float fade)
        {
            _track = "";
            Fade(0, 0f, fade, true);
            Fade(1, 0f, fade, true);
        }

        /// <summary>
        /// Plays a sound effect and completes when it ends. Returns an error message or "".
        /// While the player skips, the sound is not played.
        /// </summary>
        public async Task<string> PlaySound(string soundName, float volume)
        {
            AudioClip clip = Find(soundName);
            if (clip == null) return "Sound '" + soundName + "' was not found in the Story Config.";
            if (_story != null && _story.Skipping) return "";
            _sound.PlayOneShot(clip, Mathf.Clamp01(volume) * soundVolume);
            if (_story != null) await _story.Wait(clip.length);
            return "";
        }

        /// <summary>Stops all music and sounds at once.</summary>
        public void Clear()
        {
            _track = "";
            _fadeTokens[0]++;
            _fadeTokens[1]++;
            _tweens.FinishAll();
            for (int i = 0; i < _music.Length; i++)
            {
                _music[i].Stop();
                _levels[i] = 0f;
                ApplyVolume(i);
            }
            _sound.Stop();
        }

        // --- Saves --------------------------------------------------------------

        /// <summary>The key of the audio in a save.</summary>
        public string Name { get { return "Audio"; } }

        /// <summary>The music playing as plain data with the keys "track", "volume", and "loop".</summary>
        public object Capture()
        {
            var data = new OrderedMap<object>();
            data["track"] = _track;
            data["volume"] = (double)_trackVolume;
            data["loop"] = _trackLoop;
            return data;
        }

        /// <summary>Stops all audio and starts the saved music again, without a fade.</summary>
        public void Restore(object data)
        {
            Clear();
            var map = data as OrderedMap<object>;
            object value;
            if (map == null || !map.TryGetValue("track", out value) || value == null) return;
            string track = GdValue.Str(value);
            if (track.Length == 0) return;
            float volume = map.TryGetValue("volume", out value) && GdValue.IsNumber(value) ? (float)GdValue.ToDouble(value) : 1f;
            bool loop = !map.TryGetValue("loop", out value) || GdValue.Truthy(value);
            string problem = PlayMusic(track, volume, 0f, loop);
            if (problem.Length > 0 && _story != null) _story.Director.ReportError(problem);
        }

        private AudioClip Find(string clipName)
        {
            return _story != null && _story.Config != null ? _story.Config.FindClip(clipName) : null;
        }

        private void ApplyVolume(int index)
        {
            if (_music[index] != null) _music[index].volume = _levels[index] * musicVolume;
        }

        private void Fade(int index, float level, float seconds, bool stopAfter)
        {
            int token = ++_fadeTokens[index];
            float from = _levels[index];
            bool instant = _story != null && _story.Skipping;
            // The fade needs no waiting: it ends by itself, so the task is dropped.
            _tweens.Run(seconds, delegate (float t)
            {
                if (token != _fadeTokens[index]) return;
                _levels[index] = Mathf.Lerp(from, level, t);
                ApplyVolume(index);
                if (t >= 1f && stopAfter) _music[index].Stop();
            }, instant);
        }
    }
}
