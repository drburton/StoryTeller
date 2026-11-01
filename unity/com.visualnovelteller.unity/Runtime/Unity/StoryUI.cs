using UnityEngine;
using UnityEngine.UIElements;

namespace VisualNovelTeller
{
    /// <summary>Helpers shared by the components that draw with UI Toolkit.</summary>
    public static class StoryUI
    {
        /// <summary>
        /// Makes panel settings that scale with the screen from a 1920 by 1080 layout.
        /// A higher sorting order draws in front.
        /// </summary>
        public static PanelSettings CreatePanelSettings(ThemeStyleSheet theme, float sortingOrder)
        {
            var settings = ScriptableObject.CreateInstance<PanelSettings>();
            settings.name = "VisualNovelTeller Panel";
            settings.scaleMode = PanelScaleMode.ScaleWithScreenSize;
            settings.referenceResolution = new Vector2Int(1920, 1080);
            settings.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
            settings.match = 0.5f;
            settings.sortingOrder = sortingOrder;
            if (theme != null) settings.themeStyleSheet = theme;
            return settings;
        }

        /// <summary>
        /// Creates a child object with a UIDocument that uses the given panel settings and
        /// returns the document. The object starts inactive so the settings are in place
        /// before the document wakes up.
        /// </summary>
        public static UIDocument CreateDocument(Transform parent, string objectName, PanelSettings settings)
        {
            var child = new GameObject(objectName);
            child.transform.SetParent(parent, false);
            child.SetActive(false);
            var document = child.AddComponent<UIDocument>();
            document.panelSettings = settings;
            child.SetActive(true);
            return document;
        }

        /// <summary>Makes an element cover its parent and ignore clicks unless asked.</summary>
        public static void Fill(VisualElement element, bool receivesClicks)
        {
            element.style.position = Position.Absolute;
            element.style.left = 0;
            element.style.right = 0;
            element.style.top = 0;
            element.style.bottom = 0;
            element.pickingMode = receivesClicks ? PickingMode.Position : PickingMode.Ignore;
        }

        /// <summary>Escapes text so a rich text label shows it as written.</summary>
        public static string EscapeRichText(string text)
        {
            if (string.IsNullOrEmpty(text)) return "";
            return text.Replace("<", "<noparse><</noparse>");
        }
    }
}
