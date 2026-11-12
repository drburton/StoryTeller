// Compile-only stand-ins for the parts of UnityEngine.Playables (the Director
// module, which Timeline builds on) that the Visual Novel Teller package uses.
// They exist so the package can be compiled without Unity (see
// csharp/UnityPackageCheck). This is not Unity's code and the members have no
// behavior. Each signature follows Unity 6.
//
// Add a member here only when the package starts to use it, and copy the real
// signature from the Unity scripting reference.

using System;

namespace UnityEngine.Playables
{
    public enum DirectorWrapMode
    {
        Hold,
        Loop,
        None
    }

    public abstract class PlayableAsset : ScriptableObject
    {
        public virtual double duration { get { throw null; } }
    }

    public class PlayableDirector : Behaviour
    {
        public PlayableAsset playableAsset { get; set; }
        public DirectorWrapMode extrapolationMode { get; set; }
        public double time { get; set; }

        public event Action<PlayableDirector> stopped
        {
            add { throw null; }
            remove { throw null; }
        }

        public void Play()
        {
            throw null;
        }

        public void Stop()
        {
            throw null;
        }

        public void Evaluate()
        {
            throw null;
        }
    }
}
