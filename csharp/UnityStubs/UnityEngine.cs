// Compile-only stand-ins for the parts of the UnityEngine namespaces that the
// Visual Novel Teller package uses. They exist so the package can be compiled
// without Unity (see csharp/UnityPackageCheck). This is not Unity's code and
// the members have no behavior. Each signature follows Unity 6.
//
// Add a member here only when the package starts to use it, and copy the real
// signature from the Unity scripting reference.

using System;

namespace UnityEngine
{
    // --- Attributes -----------------------------------------------------------

    [AttributeUsage(AttributeTargets.Field)]
    public sealed class SerializeField : Attribute
    {
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property | AttributeTargets.Class | AttributeTargets.Struct, Inherited = true, AllowMultiple = true)]
    public sealed class HeaderAttribute : Attribute
    {
        public readonly string header;

        public HeaderAttribute(string header)
        {
            this.header = header;
        }
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property | AttributeTargets.Class | AttributeTargets.Struct, Inherited = true, AllowMultiple = true)]
    public class TooltipAttribute : Attribute
    {
        public readonly string tooltip;

        public TooltipAttribute(string tooltip)
        {
            this.tooltip = tooltip;
        }
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property | AttributeTargets.Class | AttributeTargets.Struct, Inherited = true, AllowMultiple = true)]
    public sealed class RangeAttribute : Attribute
    {
        public readonly float min;
        public readonly float max;

        public RangeAttribute(float min, float max)
        {
            this.min = min;
            this.max = max;
        }
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property | AttributeTargets.Class | AttributeTargets.Struct, Inherited = true, AllowMultiple = true)]
    public sealed class MinAttribute : Attribute
    {
        public readonly float min;

        public MinAttribute(float min)
        {
            this.min = min;
        }
    }

    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property | AttributeTargets.Class | AttributeTargets.Struct, Inherited = true, AllowMultiple = true)]
    public sealed class TextAreaAttribute : Attribute
    {
        public readonly int minLines;
        public readonly int maxLines;

        public TextAreaAttribute()
        {
        }

        public TextAreaAttribute(int minLines, int maxLines)
        {
            this.minLines = minLines;
            this.maxLines = maxLines;
        }
    }

    [AttributeUsage(AttributeTargets.Class, Inherited = true, AllowMultiple = false)]
    public sealed class CreateAssetMenuAttribute : Attribute
    {
        public string menuName { get; set; }
        public string fileName { get; set; }
        public int order { get; set; }
    }

    [AttributeUsage(AttributeTargets.Class)]
    public class DefaultExecutionOrderAttribute : Attribute
    {
        public DefaultExecutionOrderAttribute(int order)
        {
            this.order = order;
        }

        public int order { get; private set; }
    }

    // --- Objects and components -----------------------------------------------

    public class Object
    {
        public string name { get; set; }

        public static void Destroy(Object obj)
        {
            throw null;
        }

        public static T FindAnyObjectByType<T>() where T : Object
        {
            throw null;
        }
    }

    public class Component : Object
    {
        public Transform transform { get { throw null; } }
        public GameObject gameObject { get { throw null; } }

        public T GetComponent<T>()
        {
            throw null;
        }

        public T GetComponentInChildren<T>()
        {
            throw null;
        }
    }

    public sealed class Transform : Component
    {
        public void SetParent(Transform p, bool worldPositionStays)
        {
            throw null;
        }
    }

    public sealed class GameObject : Object
    {
        public GameObject(string name)
        {
        }

        public Transform transform { get { throw null; } }

        public T AddComponent<T>() where T : Component
        {
            throw null;
        }

        public void SetActive(bool value)
        {
            throw null;
        }
    }

    public class Behaviour : Component
    {
        public bool enabled { get; set; }
        public bool isActiveAndEnabled { get { throw null; } }
    }

    public class MonoBehaviour : Behaviour
    {
    }

    public class ScriptableObject : Object
    {
        public static T CreateInstance<T>() where T : ScriptableObject
        {
            throw null;
        }
    }

    public static class Resources
    {
        public static T Load<T>(string path) where T : Object
        {
            throw null;
        }
    }

    public class Sprite : Object
    {
    }

    public class TextAsset : Object
    {
        public TextAsset()
        {
        }

        public TextAsset(string text)
        {
        }

        public string text { get { throw null; } }
    }

    // --- Static helpers ---------------------------------------------------------

    public static class Debug
    {
        public static void Log(object message)
        {
            throw null;
        }

        public static void Log(object message, Object context)
        {
            throw null;
        }

        public static void LogWarning(object message)
        {
            throw null;
        }

        public static void LogWarning(object message, Object context)
        {
            throw null;
        }

        public static void LogError(object message)
        {
            throw null;
        }

        public static void LogError(object message, Object context)
        {
            throw null;
        }

        public static void LogException(Exception exception)
        {
            throw null;
        }

        public static void LogException(Exception exception, Object context)
        {
            throw null;
        }
    }

    public static class Random
    {
        public static float Range(float minInclusive, float maxInclusive)
        {
            throw null;
        }
    }

    public enum TextureFormat
    {
        RGBA32
    }

    public enum TextureWrapMode
    {
        Clamp
    }

    public class Texture : Object
    {
        public TextureWrapMode wrapMode { get; set; }
    }

    public class Texture2D : Texture
    {
        public Texture2D(int width, int height, TextureFormat textureFormat, bool mipChain)
        {
        }

        public void SetPixel(int x, int y, Color color)
        {
            throw null;
        }

        public void Apply(bool updateMipmaps = true, bool makeNoLongerReadable = false)
        {
            throw null;
        }
    }

    public static class Time
    {
        public static float unscaledDeltaTime { get { throw null; } }
        public static int frameCount { get { throw null; } }
    }

    public static class Application
    {
        public static string persistentDataPath { get { throw null; } }
        public static string productName { get { throw null; } }
        public static string unityVersion { get { throw null; } }
        public static bool isEditor { get { throw null; } }
        public static SystemLanguage systemLanguage { get { throw null; } }
        public static RuntimePlatform platform { get { throw null; } }

        public static void Quit()
        {
            throw null;
        }
    }

    public enum SystemLanguage
    {
        Afrikaans, Arabic, Basque, Belarusian, Bulgarian, Catalan, Chinese, Czech, Danish, Dutch,
        English, Estonian, Faroese, Finnish, French, German, Greek, Hebrew, Hungarian, Icelandic,
        Indonesian, Italian, Japanese, Korean, Latvian, Lithuanian, Norwegian, Polish, Portuguese,
        Romanian, Russian, SerboCroatian, Slovak, Slovenian, Spanish, Swedish, Thai, Turkish,
        Ukrainian, Vietnamese, ChineseSimplified, ChineseTraditional, Hindi, Unknown,
    }

    public enum RuntimePlatform
    {
        OSXEditor, OSXPlayer, WindowsPlayer, WindowsEditor, IPhonePlayer, Android, LinuxPlayer, LinuxEditor, WebGLPlayer,
    }

    public static class Screen
    {
        public static bool fullScreen { get { throw null; } set { throw null; } }
    }

    public static class JsonUtility
    {
        public static string ToJson(object obj, bool prettyPrint)
        {
            throw null;
        }

        public static void FromJsonOverwrite(string json, object objectToOverwrite)
        {
            throw null;
        }
    }

    public struct Mathf
    {
        public const float PI = 3.14159274F;

        public static float Cos(float f)
        {
            throw null;
        }

        public static float Sqrt(float f)
        {
            throw null;
        }

        public static float Sin(float f)
        {
            throw null;
        }

        public static float Abs(float f)
        {
            throw null;
        }

        public static float Lerp(float a, float b, float t)
        {
            throw null;
        }

        public static float Clamp01(float value)
        {
            throw null;
        }

        public static float Clamp(float value, float min, float max)
        {
            throw null;
        }

        public static int Clamp(int value, int min, int max)
        {
            throw null;
        }

        public static float Max(float a, float b)
        {
            throw null;
        }

        public static int Max(int a, int b)
        {
            throw null;
        }

        public static float Min(float a, float b)
        {
            throw null;
        }

        public static int Min(int a, int b)
        {
            throw null;
        }

        public static float Round(float f)
        {
            throw null;
        }

        public static int RoundToInt(float f)
        {
            throw null;
        }
    }

    // --- Math types -----------------------------------------------------------

    public struct Vector2
    {
        public float x;
        public float y;

        public Vector2(float x, float y)
        {
            this.x = x;
            this.y = y;
        }

        public static Vector2 zero { get { throw null; } }
        public static Vector2 one { get { throw null; } }
        public static Vector2 left { get { throw null; } }
        public static Vector2 right { get { throw null; } }

        public static Vector2 Lerp(Vector2 a, Vector2 b, float t)
        {
            throw null;
        }
    }

    public struct Vector2Int
    {
        public Vector2Int(int x, int y)
        {
            throw null;
        }

        public int x { get { throw null; } set { throw null; } }
        public int y { get { throw null; } set { throw null; } }
    }

    public struct Vector3
    {
        public Vector3(float x, float y, float z)
        {
            throw null;
        }

        public static Vector3 zero { get { throw null; } }
        public static Vector3 one { get { throw null; } }
    }

    public struct Rect
    {
        public float width { get; set; }
        public float height { get; set; }

        public Rect(float x, float y, float width, float height)
        {
            throw null;
        }
    }

    public struct Color
    {
        public float r;
        public float g;
        public float b;
        public float a;

        public Color(float r, float g, float b, float a)
        {
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
        }

        public Color(float r, float g, float b)
        {
            this.r = r;
            this.g = g;
            this.b = b;
            a = 1F;
        }

        public static Color white { get { throw null; } }
        public static Color black { get { throw null; } }
        public static Color red { get { throw null; } }
        public static Color green { get { throw null; } }
        public static Color blue { get { throw null; } }
        public static Color yellow { get { throw null; } }
        public static Color cyan { get { throw null; } }
        public static Color magenta { get { throw null; } }
        public static Color gray { get { throw null; } }

        public static Color operator *(Color a, Color b)
        {
            throw null;
        }
    }

    public static class ColorUtility
    {
        public static bool TryParseHtmlString(string htmlString, out Color color)
        {
            throw null;
        }
    }

    // --- Enums ----------------------------------------------------------------

    public enum ScaleMode
    {
        StretchToFill,
        ScaleToFit,
        ScaleAndCrop
    }

    public enum TextAnchor
    {
        MiddleLeft
    }

    public enum KeyCode
    {
        PageUp,
        F5,
        F9
    }

    // --- Audio ----------------------------------------------------------------

    public class AudioClip : Object
    {
        public float length { get { throw null; } }
    }

    public sealed class AudioListener : Behaviour
    {
        public static float volume { get { throw null; } set { throw null; } }
    }

    public sealed class AudioSource : Behaviour
    {
        public bool playOnAwake { get; set; }
        public float volume { get; set; }
        public bool loop { get; set; }
        public AudioClip clip { get; set; }
        public bool isPlaying { get { throw null; } }

        public void Play()
        {
            throw null;
        }

        public void Stop()
        {
            throw null;
        }

        public void PlayOneShot(AudioClip clip, float volumeScale)
        {
            throw null;
        }
    }

    // --- Animation --------------------------------------------------------------

    public class RuntimeAnimatorController : Object
    {
    }

    public struct AnimatorStateInfo
    {
        public float normalizedTime { get { throw null; } }
        public bool loop { get { throw null; } }

        public bool IsName(string name)
        {
            throw null;
        }
    }

    public sealed class Animator : Behaviour
    {
        public RuntimeAnimatorController runtimeAnimatorController { get; set; }

        public static int StringToHash(string name)
        {
            throw null;
        }

        public bool HasState(int layerIndex, int stateID)
        {
            throw null;
        }

        public void Play(string stateName, int layer, float normalizedTime)
        {
            throw null;
        }

        public void Update(float deltaTime)
        {
            throw null;
        }

        public AnimatorStateInfo GetCurrentAnimatorStateInfo(int layerIndex)
        {
            throw null;
        }
    }

    // --- IMGUI (used by the editor tools) -------------------------------------

    public class GUIContent
    {
        public GUIContent(string text)
        {
        }

        public GUIContent(string text, string tooltip)
        {
        }
    }

    public sealed class GUIStyle
    {
        public GUIStyle(GUIStyle other)
        {
        }

        public TextAnchor alignment { get; set; }
        public bool wordWrap { get; set; }
    }

    public sealed class GUILayoutOption
    {
    }

    public class GUILayout
    {
        public static bool Button(string text, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static bool Button(GUIContent content, GUIStyle style, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static void Label(string text, GUIStyle style, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static GUILayoutOption Height(float height)
        {
            throw null;
        }

        public static GUILayoutOption MinHeight(float minHeight)
        {
            throw null;
        }

        public static GUILayoutOption MaxHeight(float maxHeight)
        {
            throw null;
        }
    }
}

namespace UnityEngine.Events
{
    [Serializable]
    public abstract class UnityEventBase
    {
    }

    [Serializable]
    public class UnityEvent : UnityEventBase
    {
        public void Invoke()
        {
            throw null;
        }
    }

    [Serializable]
    public class UnityEvent<T0, T1> : UnityEventBase
    {
        public void Invoke(T0 arg0, T1 arg1)
        {
            throw null;
        }
    }
}
