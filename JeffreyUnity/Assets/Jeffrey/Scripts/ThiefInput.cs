using System;
using System.Collections.Generic;
using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace Jeffrey
{
    /// Every action on the Thief 2 key list. "Lean forward" (Alt + W) and
    /// "previous inventory item" (Shift + Tab) are combinations of these,
    /// worked out by the movement and inventory code.
    public enum ThiefAction
    {
        Forward,
        Backward,
        StrafeLeft,
        StrafeRight,
        TurnLeft,
        TurnRight,
        SpeedToggle,
        Crouch,
        Jump,
        Slide,
        LeanLeft,
        LeanRight,
        Attack,
        Block,
        Use,
        Drop,
        NextItem,
        ClearItem,
        NextWeapon,
        PreviousWeapon,
        PutAwayWeapon,
        ZoomIn,
        ZoomOut,
        ResetZoom,
        FreeMouse,
        DebugReadout,
        Help,
    }

    [Serializable]
    public class KeyBinding
    {
        public ThiefAction action;
        public KeyCode[] keys;

        public KeyBinding(ThiefAction action, params KeyCode[] keys)
        {
            this.action = action;
            this.keys = keys;
        }
    }

    /// Reads the keyboard and mouse once per frame. The bindings are in the
    /// Inspector, so any key can be changed without code. Works with either
    /// of Unity's input backends (the Input System package or the old Input
    /// Manager), whichever the project has switched on.
    [DefaultExecutionOrder(-100)]
    public class ThiefInput : MonoBehaviour
    {
        [Tooltip("The Thief 2 default keys. Edit freely.")]
        public KeyBinding[] bindings = DefaultBindings();

        [Header("Mouse")]
        [Tooltip("Degrees of turn per pixel of mouse movement.")]
        public float mouseSensitivity = 0.12f;
        public bool invertMouseY = false;

        static readonly int ActionCount = Enum.GetValues(typeof(ThiefAction)).Length;
        bool[] held = new bool[ActionCount];
        bool[] wasHeld = new bool[ActionCount];

        /// Mouse movement this frame, in degrees (x = yaw, y = pitch, up is positive).
        public Vector2 LookDelta { get; private set; }

        /// True while the game has the mouse. Actions are ignored while it is free.
        public bool MouseCaptured => Cursor.lockState == CursorLockMode.Locked;

        public static KeyBinding[] DefaultBindings()
        {
            return new[]
            {
                new KeyBinding(ThiefAction.Forward, KeyCode.W),
                new KeyBinding(ThiefAction.Backward, KeyCode.S),
                new KeyBinding(ThiefAction.StrafeLeft, KeyCode.A),
                new KeyBinding(ThiefAction.StrafeRight, KeyCode.D),
                new KeyBinding(ThiefAction.TurnLeft, KeyCode.LeftArrow),
                new KeyBinding(ThiefAction.TurnRight, KeyCode.RightArrow),
                new KeyBinding(ThiefAction.SpeedToggle, KeyCode.LeftShift, KeyCode.RightShift),
                new KeyBinding(ThiefAction.Crouch, KeyCode.C),
                new KeyBinding(ThiefAction.Jump, KeyCode.Space),
                new KeyBinding(ThiefAction.Slide, KeyCode.LeftAlt, KeyCode.RightAlt),
                new KeyBinding(ThiefAction.LeanLeft, KeyCode.Q),
                new KeyBinding(ThiefAction.LeanRight, KeyCode.E),
                new KeyBinding(ThiefAction.Attack, KeyCode.Mouse0),
                new KeyBinding(ThiefAction.Block, KeyCode.B, KeyCode.Mouse2),
                new KeyBinding(ThiefAction.Use, KeyCode.Mouse1, KeyCode.Return),
                new KeyBinding(ThiefAction.Drop, KeyCode.R),
                new KeyBinding(ThiefAction.NextItem, KeyCode.Tab),
                new KeyBinding(ThiefAction.ClearItem, KeyCode.Backspace),
                new KeyBinding(ThiefAction.NextWeapon, KeyCode.KeypadPlus),
                new KeyBinding(ThiefAction.PreviousWeapon, KeyCode.KeypadMinus),
                new KeyBinding(ThiefAction.PutAwayWeapon, KeyCode.BackQuote),
                new KeyBinding(ThiefAction.ZoomIn, KeyCode.RightBracket),
                new KeyBinding(ThiefAction.ZoomOut, KeyCode.LeftBracket),
                new KeyBinding(ThiefAction.ResetZoom, KeyCode.P),
                new KeyBinding(ThiefAction.FreeMouse, KeyCode.Escape),
                new KeyBinding(ThiefAction.DebugReadout, KeyCode.F3),
                new KeyBinding(ThiefAction.Help, KeyCode.F1),
            };
        }

        public bool Held(ThiefAction a) => held[(int)a];
        public bool Pressed(ThiefAction a) => held[(int)a] && !wasHeld[(int)a];
        public bool Released(ThiefAction a) => !held[(int)a] && wasHeld[(int)a];

        void Start()
        {
            Capture(true);
        }

        void Update()
        {
            var swap = wasHeld;
            wasHeld = held;
            held = swap;
            Array.Clear(held, 0, held.Length);

            if (bindings != null)
            {
                foreach (var b in bindings)
                {
                    if (b == null || b.keys == null) continue;
                    foreach (var k in b.keys)
                    {
                        if (KeyHeld(k)) { held[(int)b.action] = true; break; }
                    }
                }
            }

            // Escape frees the mouse; a click takes it back (and that click
            // does nothing else).
            if (MouseCaptured && Pressed(ThiefAction.FreeMouse))
            {
                Capture(false);
            }
            else if (!MouseCaptured && (KeyHeld(KeyCode.Mouse0) || KeyHeld(KeyCode.Mouse1)))
            {
                Capture(true);
                SwallowUntilReleased();
            }

            if (!MouseCaptured)
            {
                // Keep the debug and help keys working with the mouse free.
                bool dbg = held[(int)ThiefAction.DebugReadout], help = held[(int)ThiefAction.Help];
                Array.Clear(held, 0, held.Length);
                held[(int)ThiefAction.DebugReadout] = dbg;
                held[(int)ThiefAction.Help] = help;
                LookDelta = Vector2.zero;
                return;
            }

            var raw = MouseDeltaPixels();
            LookDelta = new Vector2(raw.x, invertMouseY ? -raw.y : raw.y) * mouseSensitivity;
        }

        void SwallowUntilReleased()
        {
            // Mark everything as already held so nothing reads as "pressed"
            // on the frame the mouse is recaptured.
            Array.Copy(held, wasHeld, held.Length);
            wasHeld[(int)ThiefAction.Attack] = true;
            wasHeld[(int)ThiefAction.Use] = true;
        }

        public static void Capture(bool on)
        {
            Cursor.lockState = on ? CursorLockMode.Locked : CursorLockMode.None;
            Cursor.visible = !on;
        }

        // ---- backends -------------------------------------------------

        static Vector2 MouseDeltaPixels()
        {
#if ENABLE_INPUT_SYSTEM
            var m = Mouse.current;
            return m != null ? m.delta.ReadValue() : Vector2.zero;
#elif ENABLE_LEGACY_INPUT_MANAGER
            // The old Input Manager scales pixels by 0.1 by default.
            return new Vector2(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y")) * 10f;
#else
            return Vector2.zero;
#endif
        }

        public static bool KeyHeld(KeyCode k)
        {
#if ENABLE_INPUT_SYSTEM
            if (k == KeyCode.Mouse0 || k == KeyCode.Mouse1 || k == KeyCode.Mouse2)
            {
                var m = Mouse.current;
                if (m == null) return false;
                if (k == KeyCode.Mouse0) return m.leftButton.isPressed;
                if (k == KeyCode.Mouse1) return m.rightButton.isPressed;
                return m.middleButton.isPressed;
            }
            var kb = Keyboard.current;
            if (kb == null) return false;
            var key = ToKey(k);
            return key != Key.None && kb[key].isPressed;
#elif ENABLE_LEGACY_INPUT_MANAGER
            return Input.GetKey(k);
#else
            return false;
#endif
        }

#if ENABLE_INPUT_SYSTEM
        static readonly Dictionary<KeyCode, Key> KeyCache = new Dictionary<KeyCode, Key>();

        /// The Input System names a few keys differently from KeyCode.
        public static Key ToKey(KeyCode k)
        {
            if (KeyCache.TryGetValue(k, out var cached)) return cached;
            Key key;
            switch (k)
            {
                case KeyCode.Return: key = Key.Enter; break;
                case KeyCode.KeypadEnter: key = Key.NumpadEnter; break;
                case KeyCode.KeypadPlus: key = Key.NumpadPlus; break;
                case KeyCode.KeypadMinus: key = Key.NumpadMinus; break;
                case KeyCode.KeypadMultiply: key = Key.NumpadMultiply; break;
                case KeyCode.KeypadDivide: key = Key.NumpadDivide; break;
                case KeyCode.BackQuote: key = Key.Backquote; break;
                case KeyCode.LeftControl: key = Key.LeftCtrl; break;
                case KeyCode.RightControl: key = Key.RightCtrl; break;
                case KeyCode.LeftCommand: key = Key.LeftMeta; break;
                case KeyCode.RightCommand: key = Key.RightMeta; break;
                case KeyCode.Alpha0: key = Key.Digit0; break;
                case KeyCode.Alpha1: key = Key.Digit1; break;
                case KeyCode.Alpha2: key = Key.Digit2; break;
                case KeyCode.Alpha3: key = Key.Digit3; break;
                case KeyCode.Alpha4: key = Key.Digit4; break;
                case KeyCode.Alpha5: key = Key.Digit5; break;
                case KeyCode.Alpha6: key = Key.Digit6; break;
                case KeyCode.Alpha7: key = Key.Digit7; break;
                case KeyCode.Alpha8: key = Key.Digit8; break;
                case KeyCode.Alpha9: key = Key.Digit9; break;
                default:
                    if (!Enum.TryParse(k.ToString(), out key)) key = Key.None;
                    break;
            }
            KeyCache[k] = key;
            return key;
        }
#endif
    }
}
