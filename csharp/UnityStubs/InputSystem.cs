// Compile-only stand-ins for the parts of the Input System package
// (com.unity.inputsystem) that the Visual Novel Teller package uses. They
// exist so the package can be compiled without Unity (see
// csharp/UnityPackageCheck). This is not Unity's code and the members have no
// behavior. Each signature follows Input System 1.x.
//
// Add a member here only when the package starts to use it, and copy the real
// signature from the Input System scripting reference.

using UnityEngine.InputSystem.Controls;

namespace UnityEngine.InputSystem
{
    public abstract class InputControl
    {
    }

    public abstract class InputControl<TValue> : InputControl where TValue : struct
    {
        public TValue ReadValue()
        {
            throw null;
        }
    }

    public class InputDevice : InputControl
    {
    }

    public class Keyboard : InputDevice
    {
        public static Keyboard current { get { throw null; } }

        public KeyControl spaceKey { get { throw null; } }
        public KeyControl enterKey { get { throw null; } }
        public KeyControl numpadEnterKey { get { throw null; } }
        public KeyControl escapeKey { get { throw null; } }
        public KeyControl tabKey { get { throw null; } }
        public KeyControl aKey { get { throw null; } }
        public KeyControl hKey { get { throw null; } }
        public KeyControl f5Key { get { throw null; } }
        public KeyControl f9Key { get { throw null; } }
        public KeyControl pageUpKey { get { throw null; } }
        public KeyControl leftCtrlKey { get { throw null; } }
        public KeyControl rightCtrlKey { get { throw null; } }
    }

    public class Mouse : InputDevice
    {
        public static Mouse current { get { throw null; } }

        public Vector2Control scroll { get { throw null; } }
    }

    public class Gamepad : InputDevice
    {
        public static Gamepad current { get { throw null; } }

        public ButtonControl startButton { get { throw null; } }
        public ButtonControl buttonEast { get { throw null; } }
    }
}

namespace UnityEngine.InputSystem.Controls
{
    public class AxisControl : InputControl<float>
    {
    }

    public class ButtonControl : AxisControl
    {
        public bool isPressed { get { throw null; } }
        public bool wasPressedThisFrame { get { throw null; } }
    }

    public class KeyControl : ButtonControl
    {
    }

    public class Vector2Control : InputControl<Vector2>
    {
    }
}
