using UnityEngine;

namespace Jeffrey
{
    /// A plain on-screen HUD for the movement prototype: crosshair, use
    /// prompt, weapon and item, messages, the F3 debug readout and the F1
    /// controls card. Drawn with IMGUI so it needs no canvas or assets.
    public class ThiefHud : MonoBehaviour
    {
        public bool showDebug = true;
        public bool showHelp = true;

        ThiefInput input;
        ThiefMovement move;
        ThiefCamera view;
        ThiefActions actions;
        GUIStyle label, box, centre, right;

        static readonly string[] HelpLines =
        {
            "W / S          forward / back",
            "A / D          strafe",
            "Arrows         turn (Alt + arrows: strafe)",
            "Shift (hold)   run",
            "C              crouch (toggle)",
            "Space          jump; hold at a ledge to mantle",
            "Q / E          lean left / right",
            "Alt + W        lean forward",
            "Left mouse     attack (hold to charge)",
            "B / mid mouse  block (sword)",
            "Right mouse / Enter   use",
            "R              drop item",
            "Tab / Shift+Tab   next / previous item",
            "Backspace      clear item",
            "Numpad + / -   next / previous weapon",
            "~              put away weapon",
            "] / [ / P      zoom in / out / reset",
            "Esc            free the mouse (click to return)",
            "F3 debug   F1 this card",
        };

        void Awake()
        {
            input = GetComponent<ThiefInput>();
            move = GetComponent<ThiefMovement>();
            view = GetComponent<ThiefCamera>();
            actions = GetComponent<ThiefActions>();
        }

        void Update()
        {
            if (input == null) return;
            if (input.Pressed(ThiefAction.DebugReadout)) showDebug = !showDebug;
            if (input.Pressed(ThiefAction.Help)) showHelp = !showHelp;
        }

        void OnGUI()
        {
            if (label == null)
            {
                label = new GUIStyle(GUI.skin.label) { fontSize = 14 };
                label.normal.textColor = Color.white;
                box = new GUIStyle(GUI.skin.box) { alignment = TextAnchor.UpperLeft, fontSize = 13 };
                box.normal.textColor = Color.white;
                centre = new GUIStyle(label) { alignment = TextAnchor.MiddleCenter };
                right = new GUIStyle(label) { alignment = TextAnchor.UpperRight };
            }

            float w = Screen.width, h = Screen.height;

            // Crosshair.
            GUI.Label(new Rect(w / 2 - 10, h / 2 - 11, 20, 20), "+", centre);

            if (actions != null)
            {
                if (!string.IsNullOrEmpty(actions.LookTarget))
                    GUI.Label(new Rect(w / 2 - 200, h / 2 + 20, 400, 24), actions.LookTarget, centre);
                if (!string.IsNullOrEmpty(actions.Message))
                    GUI.Label(new Rect(w / 2 - 300, h * 0.72f, 600, 24), actions.Message, centre);

                string weapon = actions.WeaponIndex < 0 ? "(no weapon)" : actions.WeaponName;
                if (actions.Blocking) weapon += "  [blocking]";
                else if (actions.Charging) weapon += "  " + new string('|', Mathf.RoundToInt(actions.Charge * 10));
                GUI.Label(new Rect(16, h - 34, 400, 24), weapon, label);

                var item = actions.SelectedItem;
                string itemText = item == null ? "(no item)" : item.name + " x" + item.count;
                GUI.Label(new Rect(w - 316, h - 34, 300, 24), itemText, right);
            }

            if (!input.MouseCaptured)
                GUI.Label(new Rect(w / 2 - 200, 20, 400, 24), "Mouse free. Click to play.", centre);

            if (showDebug && move != null)
            {
                string s =
                    "State      " + move.State + "\n" +
                    "Speed      " + move.HorizontalSpeed.ToString("0.00") + " m/s" + (move.IsRunning ? "  running" : "") + "\n" +
                    "Crouched   " + (move.IsCrouched ? "yes" : "no") + "  height " + move.CurrentHeight.ToString("0.00") + "\n" +
                    "Fall       " + (-move.Velocity.y).ToString("0.0") + " m/s\n";
                if (view != null)
                    s += "Lean       " + view.Lean.ToString("+0.00;-0.00;0.00") + "  forward " + view.LeanForward.ToString("0.00") + "\n" +
                         "Zoom       " + view.Zoom.ToString("0") + "x\n";
                if (move.MantleProgress >= 0f)
                    s += "Mantling   " + Mathf.RoundToInt(move.MantleProgress * 100) + "%\n";
                GUI.Box(new Rect(w - 276, 16, 260, 120), s, box);
            }

            if (showHelp)
            {
                GUI.Box(new Rect(16, 16, 360, HelpLines.Length * 17 + 14), string.Join("\n", HelpLines), box);
            }
        }
    }
}
