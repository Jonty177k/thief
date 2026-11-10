using UnityEngine;

namespace Jeffrey
{
    /// A door on a hinge. Put this on the hinge object; the door slab is its child.
    /// Use (right mouse / Enter) opens and closes it.
    public class ThiefDoor : MonoBehaviour, IThiefUsable
    {
        public float openAngle = 100f;
        public float degreesPerSecond = 160f;
        public bool locked = false;

        public bool IsOpen { get; private set; }
        public string UsePrompt => locked ? "Locked" : (IsOpen ? "Close door" : "Open door");

        float angle;
        Quaternion closedRotation;

        void Awake()
        {
            closedRotation = transform.localRotation;
        }

        public void Use(GameObject user)
        {
            if (locked)
            {
                var a = user.GetComponent<ThiefActions>();
                if (a != null) a.Say("It's locked.");
                return;
            }
            IsOpen = !IsOpen;
        }

        void Update()
        {
            float target = IsOpen ? openAngle : 0f;
            if (Mathf.Approximately(angle, target)) return;
            angle = Mathf.MoveTowards(angle, target, degreesPerSecond * Time.deltaTime);
            transform.localRotation = closedRotation * Quaternion.Euler(0f, angle, 0f);
        }
    }
}
