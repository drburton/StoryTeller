// Compile-only stand-ins for the parts of the UnityEditor namespaces that the
// Visual Novel Teller editor tools use. They exist so the package can be
// compiled without Unity (see csharp/UnityPackageCheck). This is not Unity's
// code and the members have no behavior. Each signature follows Unity 6.
//
// Add a member here only when the package starts to use it, and copy the real
// signature from the Unity scripting reference.

using System;
using UnityEngine;
using Object = UnityEngine.Object;

namespace UnityEditor
{
    // --- Attributes -----------------------------------------------------------

    [AttributeUsage(AttributeTargets.Method, AllowMultiple = true)]
    public sealed class MenuItem : Attribute
    {
        public MenuItem(string itemName)
        {
        }

        public MenuItem(string itemName, bool isValidateFunction)
        {
        }

        public MenuItem(string itemName, bool isValidateFunction, int priority)
        {
        }
    }

    [AttributeUsage(AttributeTargets.Class, AllowMultiple = true)]
    public sealed class CustomEditorAttribute : Attribute
    {
        public CustomEditorAttribute(Type inspectedType)
        {
        }
    }

    public enum MessageType
    {
        Info,
        Warning,
        Error
    }

    // --- Editor classes ---------------------------------------------------------

    public class Editor : ScriptableObject
    {
        public Object target { get; set; }

        public virtual void OnInspectorGUI()
        {
            throw null;
        }
    }

    public class EditorWindow : ScriptableObject
    {
        public GUIContent titleContent { get; set; }
        public Vector2 minSize { get; set; }

        public static T GetWindow<T>() where T : EditorWindow
        {
            throw null;
        }

        public void Repaint()
        {
            throw null;
        }
    }

    public static class EditorApplication
    {
        public delegate void CallbackFunction();

        public static CallbackFunction update;

        public static void Exit(int returnValue)
        {
            throw null;
        }
    }

    public static class Selection
    {
        public static Object activeObject { get { throw null; } set { throw null; } }
        public static GameObject activeGameObject { get { throw null; } set { throw null; } }
    }

    public static class Undo
    {
        public static void RegisterCreatedObjectUndo(Object objectToUndo, string name)
        {
            throw null;
        }
    }

    public static class AssetDatabase
    {
        public static void ImportAsset(string path)
        {
            throw null;
        }

        public static string[] FindAssets(string filter)
        {
            throw null;
        }

        public static string GUIDToAssetPath(string guid)
        {
            throw null;
        }

        public static string GetAssetPath(Object assetObject)
        {
            throw null;
        }

        public static T LoadAssetAtPath<T>(string assetPath) where T : Object
        {
            throw null;
        }

        public static void CreateAsset(Object asset, string path)
        {
            throw null;
        }

        public static string GenerateUniqueAssetPath(string path)
        {
            throw null;
        }

        public static void SaveAssets()
        {
            throw null;
        }

        public static bool OpenAsset(Object target, int lineNumber)
        {
            throw null;
        }
    }

    public class SerializedProperty
    {
        public Object objectReferenceValue { get { throw null; } set { throw null; } }
        public int arraySize { get { throw null; } set { throw null; } }

        public SerializedProperty GetArrayElementAtIndex(int index)
        {
            throw null;
        }
    }

    public class SerializedObject
    {
        public SerializedObject(Object obj)
        {
        }

        public SerializedProperty FindProperty(string propertyPath)
        {
            throw null;
        }

        public bool ApplyModifiedProperties()
        {
            throw null;
        }
    }

    public static class EditorUtility
    {
        public static void SetDirty(UnityEngine.Object target)
        {
            throw null;
        }
    }

    public class EditorGUIUtility
    {
        public static void PingObject(Object obj)
        {
            throw null;
        }
    }

    public sealed class EditorStyles
    {
        public static GUIStyle boldLabel { get { throw null; } }
        public static GUIStyle miniLabel { get { throw null; } }
        public static GUIStyle miniButton { get { throw null; } }
        public static GUIStyle wordWrappedLabel { get { throw null; } }
        public static GUIStyle wordWrappedMiniLabel { get { throw null; } }
    }

    public sealed class EditorGUI
    {
        public static int indentLevel { get { throw null; } set { throw null; } }

        public static void BeginChangeCheck()
        {
            throw null;
        }

        public static bool EndChangeCheck()
        {
            throw null;
        }

        public static void BeginDisabledGroup(bool disabled)
        {
            throw null;
        }

        public static void EndDisabledGroup()
        {
            throw null;
        }
    }

    public sealed class EditorGUILayout
    {
        public static void Space()
        {
            throw null;
        }

        public static void LabelField(string label, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static void LabelField(string label, string label2, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static void LabelField(string label, GUIStyle style, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static void HelpBox(string message, MessageType type)
        {
            throw null;
        }

        public static Vector2 BeginScrollView(Vector2 scrollPosition, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static void EndScrollView()
        {
            throw null;
        }

        public static Rect BeginHorizontal(params GUILayoutOption[] options)
        {
            throw null;
        }

        public static void EndHorizontal()
        {
            throw null;
        }

        public static Object ObjectField(string label, Object obj, Type objType, bool allowSceneObjects, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static string TextField(string label, string text, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static int IntField(string label, int value, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static float FloatField(string label, float value, params GUILayoutOption[] options)
        {
            throw null;
        }

        public static bool Foldout(bool foldout, string content, bool toggleOnLabelClick)
        {
            throw null;
        }
    }

    public class AssetImporter : Object
    {
    }
}

namespace UnityEditor.AssetImporters
{
    [AttributeUsage(AttributeTargets.Class)]
    public sealed class ScriptedImporterAttribute : Attribute
    {
        public ScriptedImporterAttribute(int version, string ext)
        {
        }

        public ScriptedImporterAttribute(int version, string[] exts)
        {
        }
    }

    public abstract class ScriptedImporter : AssetImporter
    {
        public abstract void OnImportAsset(AssetImportContext ctx);
    }

    public class AssetImportContext
    {
        public string assetPath { get { throw null; } }

        public void AddObjectToAsset(string identifier, Object obj)
        {
            throw null;
        }

        public void SetMainObject(Object obj)
        {
            throw null;
        }

        public void DependsOnSourceAsset(string path)
        {
            throw null;
        }

        public void LogImportError(string msg, Object obj = null)
        {
            throw null;
        }

        public void LogImportWarning(string msg, Object obj = null)
        {
            throw null;
        }
    }
}
