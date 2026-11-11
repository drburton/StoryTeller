// Compile-only stand-ins for the parts of UnityEngine.UIElements that the
// Visual Novel Teller package uses. They exist so the package can be compiled
// without Unity (see csharp/UnityPackageCheck). This is not Unity's code and
// the members have no behavior. Each signature follows Unity 6.
//
// Add a member here only when the package starts to use it, and copy the real
// signature from the Unity scripting reference.

using System;
using UnityEngine;

namespace UnityEngine.UIElements
{
    // --- Enums ----------------------------------------------------------------

    public enum PickingMode
    {
        Position,
        Ignore
    }

    public enum DisplayStyle
    {
        Flex,
        None
    }

    public enum Visibility
    {
        Visible,
        Hidden
    }

    public enum Position
    {
        Absolute
    }

    public enum LengthUnit
    {
        Pixel
    }

    public enum StyleKeyword
    {
        Null
    }

    public enum TrickleDown
    {
        NoTrickleDown
    }

    public enum SliderDirection
    {
        Horizontal
    }

    public enum PanelScaleMode
    {
        ScaleWithScreenSize
    }

    public enum PanelScreenMatchMode
    {
        MatchWidthOrHeight
    }

    // --- Style values -----------------------------------------------------------

    public struct Length
    {
        public Length(float value)
        {
        }

        public Length(float value, LengthUnit unit)
        {
        }

        public static Length Percent(float value)
        {
            throw null;
        }
    }

    public struct Translate
    {
        public Translate(Length x, Length y)
        {
        }
    }

    public struct Scale
    {
        public Scale(Vector3 scale)
        {
        }
    }

    public struct TransformOrigin
    {
        public TransformOrigin(Length x, Length y)
        {
        }
    }

    public struct StyleLength
    {
        public static implicit operator StyleLength(StyleKeyword keyword)
        {
            throw null;
        }

        public static implicit operator StyleLength(float v)
        {
            throw null;
        }

        public static implicit operator StyleLength(Length v)
        {
            throw null;
        }
    }

    public struct StyleFloat
    {
        public static implicit operator StyleFloat(StyleKeyword keyword)
        {
            throw null;
        }

        public static implicit operator StyleFloat(float v)
        {
            throw null;
        }
    }

    public struct StyleColor
    {
        public static implicit operator StyleColor(StyleKeyword keyword)
        {
            throw null;
        }

        public static implicit operator StyleColor(Color v)
        {
            throw null;
        }
    }

    public struct StyleEnum<T> where T : struct, IConvertible
    {
        public static implicit operator StyleEnum<T>(StyleKeyword keyword)
        {
            throw null;
        }

        public static implicit operator StyleEnum<T>(T v)
        {
            throw null;
        }
    }

    public struct StyleTranslate
    {
        public static implicit operator StyleTranslate(StyleKeyword keyword)
        {
            throw null;
        }

        public static implicit operator StyleTranslate(Translate v)
        {
            throw null;
        }
    }

    public struct StyleScale
    {
        public static implicit operator StyleScale(StyleKeyword keyword)
        {
            throw null;
        }

        public static implicit operator StyleScale(Scale v)
        {
            throw null;
        }
    }

    public struct StyleTransformOrigin
    {
        public static implicit operator StyleTransformOrigin(StyleKeyword keyword)
        {
            throw null;
        }

        public static implicit operator StyleTransformOrigin(TransformOrigin v)
        {
            throw null;
        }
    }

    public interface IStyle
    {
        StyleEnum<Position> position { get; set; }
        StyleLength left { get; set; }
        StyleLength right { get; set; }
        StyleLength top { get; set; }
        StyleLength bottom { get; set; }
        StyleLength width { get; set; }
        StyleLength height { get; set; }
        StyleLength marginLeft { get; set; }
        StyleFloat opacity { get; set; }
        StyleColor backgroundColor { get; set; }
        StyleColor color { get; set; }
        StyleEnum<DisplayStyle> display { get; set; }
        StyleEnum<Visibility> visibility { get; set; }
        StyleTranslate translate { get; set; }
        StyleScale scale { get; set; }
        StyleTransformOrigin transformOrigin { get; set; }
    }

    // --- Events -----------------------------------------------------------------

    public delegate void EventCallback<in TEventType>(TEventType evt);

    public abstract class EventBase
    {
        public void StopPropagation()
        {
            throw null;
        }
    }

    public abstract class EventBase<T> : EventBase where T : EventBase<T>, new()
    {
    }

    public abstract class PointerEventBase<T> : EventBase<T> where T : PointerEventBase<T>, new()
    {
        public int button { get { throw null; } }
    }

    public sealed class PointerDownEvent : PointerEventBase<PointerDownEvent>
    {
    }

    public class ChangeEvent<T> : EventBase<ChangeEvent<T>>
    {
        public T previousValue { get { throw null; } }
        public T newValue { get { throw null; } }
    }

    public interface INotifyValueChanged<T>
    {
        T value { get; set; }
    }

    public static class INotifyValueChangedExtensions
    {
        public static bool RegisterValueChangedCallback<T>(this INotifyValueChanged<T> control, EventCallback<ChangeEvent<T>> callback)
        {
            throw null;
        }
    }

    // --- Scheduler --------------------------------------------------------------

    public struct TimerState
    {
    }

    public interface IVisualElementScheduledItem
    {
        IVisualElementScheduledItem ExecuteLater(long delayMs);
    }

    public interface IVisualElementScheduler
    {
        IVisualElementScheduledItem Execute(Action<TimerState> timerUpdateEvent);
        IVisualElementScheduledItem Execute(Action updateEvent);
    }

    // --- Elements ---------------------------------------------------------------

    public class VisualElementStyleSheetSet
    {
        public void Add(StyleSheet styleSheet)
        {
            throw null;
        }
    }

    public class VisualElement
    {
        public string name { get; set; }
        public IStyle style { get { throw null; } }
        public PickingMode pickingMode { get; set; }
        public bool focusable { get; set; }
        public IVisualElementScheduler schedule { get { throw null; } }
        public VisualElementStyleSheetSet styleSheets { get { throw null; } }

        public void Add(VisualElement child)
        {
            throw null;
        }

        public void Remove(VisualElement element)
        {
            throw null;
        }

        public void Clear()
        {
            throw null;
        }

        public void AddToClassList(string className)
        {
            throw null;
        }

        public void EnableInClassList(string className, bool enable)
        {
            throw null;
        }

        public void SetEnabled(bool value)
        {
            throw null;
        }

        public void Focus()
        {
            throw null;
        }

        public void RegisterCallback<TEventType>(EventCallback<TEventType> callback, TrickleDown useTrickleDown = TrickleDown.NoTrickleDown)
            where TEventType : EventBase<TEventType>, new()
        {
            throw null;
        }
    }

    public static class UQueryExtensions
    {
        public static T Q<T>(this VisualElement e, string name = null, string className = null) where T : VisualElement
        {
            throw null;
        }

        public static T Q<T>(this VisualElement e, string name = null, params string[] classes) where T : VisualElement
        {
            throw null;
        }
    }

    public class BindableElement : VisualElement
    {
    }

    public class TemplateContainer : BindableElement
    {
    }

    public class Image : VisualElement
    {
        public Sprite sprite { get; set; }
        public ScaleMode scaleMode { get; set; }
        public Color tintColor { get; set; }
    }

    public class TextElement : BindableElement
    {
        public string text { get; set; }
        public bool enableRichText { get; set; }
    }

    public class Label : TextElement
    {
        public Label()
        {
        }

        public Label(string text)
        {
        }
    }

    public class Button : TextElement
    {
        public Button()
        {
        }

        public event Action clicked
        {
            add { throw null; }
            remove { throw null; }
        }
    }

    public class Scroller : VisualElement
    {
        public float highValue { get; set; }
    }

    public class ScrollView : VisualElement
    {
        public ScrollView()
        {
        }

        public Vector2 scrollOffset { get; set; }
        public Scroller verticalScroller { get { throw null; } }
    }

    public abstract class BaseField<TValueType> : BindableElement, INotifyValueChanged<TValueType>
    {
        public TValueType value { get; set; }
    }

    public abstract class BaseSlider<TValueType> : BaseField<TValueType> where TValueType : IComparable<TValueType>
    {
    }

    public class Slider : BaseSlider<float>
    {
        public Slider(string label, float start, float end, SliderDirection direction = SliderDirection.Horizontal, float pageSize = 0f)
        {
        }
    }

    public class Toggle : BaseField<bool>
    {
        public Toggle(string label)
        {
        }
    }

    // --- Assets and documents ---------------------------------------------------

    public class StyleSheet : ScriptableObject
    {
    }

    public class ThemeStyleSheet : StyleSheet
    {
    }

    public class VisualTreeAsset : ScriptableObject
    {
        public TemplateContainer CloneTree()
        {
            throw null;
        }
    }

    public class PanelSettings : ScriptableObject
    {
        public PanelScaleMode scaleMode { get; set; }
        public Vector2Int referenceResolution { get; set; }
        public PanelScreenMatchMode screenMatchMode { get; set; }
        public float match { get; set; }
        public float sortingOrder { get; set; }
        public float scale { get; set; }
        public ThemeStyleSheet themeStyleSheet { get; set; }
    }

    public class UIDocument : MonoBehaviour
    {
        public PanelSettings panelSettings { get; set; }
        public VisualElement rootVisualElement { get { throw null; } }
    }
}
