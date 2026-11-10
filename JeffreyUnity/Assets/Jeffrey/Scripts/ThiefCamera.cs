using UnityEngine;

namespace Jeffrey
{
    /// Mouse look, eye height, Thief leaning (Q / E, and Alt + W forward),
    /// head bob and the zoom (] / [ / P).
    ///
    /// Expects a child "Eye" transform (the pivot) holding the Camera.
    [RequireComponent(typeof(ThiefMovement))]
    [DefaultExecutionOrder(-40)]
    public class ThiefCamera : MonoBehaviour
    {
        public Transform eye;
        public Camera cam;

        [Header("Look")]
        public float maxPitch = 85f;
        [Tooltip("Eye height below the top of the body.")]
        public float eyeBelowTop = 0.12f;
        [Tooltip("How quickly the eye follows the body's height when crouching.")]
        public float eyeHeightSpeed = 8f;

        [Header("Lean (Q / E)")]
        public float leanDistance = 0.6f;
        [Tooltip("Degrees the view tilts at a full lean.")]
        public float leanRoll = 12f;
        [Tooltip("Leans per second (1 = a full lean takes a second).")]
        public float leanSpeed = 4f;
        [Tooltip("Speed multiplier while fully leaning.")]
        [Range(0f, 1f)] public float leanMoveMultiplier = 0.4f;

        [Header("Lean forward (Alt + W)")]
        public float leanForwardDistance = 0.45f;
        [Tooltip("Degrees the view tips down at a full forward lean.")]
        public float leanForwardPitch = 6f;

        [Tooltip("Keeps the eye this far from walls when leaning.")]
        public float eyeCollisionRadius = 0.15f;

        [Header("Head bob")]
        public float bobWalk = 0.025f;
        public float bobRun = 0.045f;
        [Tooltip("Metres travelled per full bob cycle (two footsteps).")]
        public float bobStride = 1.6f;
        public float landingDip = 0.08f;

        [Header("Zoom (] / [ / P)")]
        public float baseFieldOfView = 75f;
        public float[] zoomLevels = { 1f, 2f, 4f, 8f };
        public float zoomSpeed = 10f;

        public float Pitch { get; private set; }
        public float Lean { get; private set; }          // -1 left .. +1 right
        public float LeanForward { get; private set; }   // 0..1
        public int ZoomIndex { get; private set; }
        public float Zoom => zoomLevels != null && zoomLevels.Length > 0 ? zoomLevels[ZoomIndex] : 1f;

        ThiefMovement move;
        ThiefInput input;
        float eyeHeight;
        float bobPhase;
        float dip;

        void Awake()
        {
            move = GetComponent<ThiefMovement>();
            input = GetComponent<ThiefInput>();
            if (eye == null) eye = transform.Find("Eye");
            if (cam == null && eye != null) cam = eye.GetComponentInChildren<Camera>();
            eyeHeight = move.standHeight - eyeBelowTop;
            if (cam != null) cam.fieldOfView = baseFieldOfView;
        }

        void Update()
        {
            float dt = Time.deltaTime;
            if (eye == null) return;

            UpdateZoom(dt);

            // Mouse: yaw turns the body, pitch tips the eye. Slower when zoomed.
            var look = input.LookDelta / Zoom;
            transform.Rotate(0f, look.x, 0f);
            Pitch = Mathf.Clamp(Pitch - look.y, -maxPitch, maxPitch);

            // Leaning, on the ground only.
            bool canLean = move.State == MoveState.Grounded;
            float leanTarget = 0f;
            if (canLean)
            {
                if (input.Held(ThiefAction.LeanRight)) leanTarget += 1f;
                if (input.Held(ThiefAction.LeanLeft)) leanTarget -= 1f;
            }
            Lean = Mathf.MoveTowards(Lean, leanTarget, leanSpeed * dt);
            LeanForward = Mathf.MoveTowards(LeanForward, canLean && move.IsLeaningForward ? 1f : 0f, leanSpeed * dt);
            move.LeanSlowdown = Mathf.Lerp(1f, leanMoveMultiplier, Mathf.Max(Mathf.Abs(Lean), LeanForward));

            // Eye height follows the body (crouching, mantling).
            float targetEye = move.CurrentHeight - eyeBelowTop;
            eyeHeight = Mathf.MoveTowards(eyeHeight, targetEye, eyeHeightSpeed * dt);

            // Head bob and landing dip.
            float bob = 0f;
            if (move.State == MoveState.Grounded && move.HorizontalSpeed > 0.2f)
            {
                bobPhase += move.HorizontalSpeed * dt / Mathf.Max(bobStride, 0.1f) * Mathf.PI * 2f;
                float amp = move.IsRunning ? bobRun : bobWalk;
                amp *= 1f - Mathf.Max(Mathf.Abs(Lean), LeanForward);
                bob = Mathf.Abs(Mathf.Sin(bobPhase)) * amp - amp * 0.5f;
            }
            if (move.JustLanded && move.LastLandingSpeed > 3f)
                dip = Mathf.Min(landingDip, landingDip * move.LastLandingSpeed / 8f);
            dip = Mathf.MoveTowards(dip, 0f, 0.4f * dt);

            // Mantling: the view tips down a little as you haul yourself up.
            float mantlePitch = move.MantleProgress >= 0f ? Mathf.Sin(move.MantleProgress * Mathf.PI) * 12f : 0f;

            // Where the eye wants to be, in world space, then pulled in so it never goes through a wall.
            Vector3 basePos = transform.position + Vector3.up * (eyeHeight + bob - dip);
            Vector3 offset = transform.right * (Lean * leanDistance) + transform.forward * (LeanForward * leanForwardDistance);
            Vector3 eyePos = basePos;
            float len = offset.magnitude;
            if (len > 0.001f)
            {
                Vector3 dir = offset / len;
                if (Physics.SphereCast(basePos, eyeCollisionRadius, dir, out var hit, len,
                        ThiefMovement.EnvironmentMask, QueryTriggerInteraction.Ignore))
                    len = Mathf.Max(0f, hit.distance - 0.01f);
                eyePos = basePos + dir * len;
            }

            eye.position = eyePos;
            eye.localRotation = Quaternion.Euler(Pitch + LeanForward * leanForwardPitch + mantlePitch, 0f, -Lean * leanRoll);
        }

        void UpdateZoom(float dt)
        {
            int count = zoomLevels != null ? zoomLevels.Length : 0;
            if (count > 0)
            {
                if (input.Pressed(ThiefAction.ZoomIn)) ZoomIndex = Mathf.Min(ZoomIndex + 1, count - 1);
                if (input.Pressed(ThiefAction.ZoomOut)) ZoomIndex = Mathf.Max(ZoomIndex - 1, 0);
                if (input.Pressed(ThiefAction.ResetZoom)) ZoomIndex = 0;
            }
            if (cam == null) return;
            float z = Mathf.Max(Zoom, 0.01f);
            float targetFov = 2f * Mathf.Atan(Mathf.Tan(baseFieldOfView * 0.5f * Mathf.Deg2Rad) / z) * Mathf.Rad2Deg;
            cam.fieldOfView = Mathf.Lerp(cam.fieldOfView, targetFov, 1f - Mathf.Exp(-zoomSpeed * dt));
        }
    }
}
