using UnityEngine;

namespace Jeffrey
{
    public enum MoveState { Grounded, Airborne, Mantling }

    /// Thief 2 style body movement: walk by default and hold Shift to run,
    /// toggle crouch, a short jump, mantling onto ledges by holding Jump,
    /// keyboard turning with Slide (Alt) turning it into strafing, and
    /// Alt + W to lean forward. The camera, leaning and zoom are in
    /// ThiefCamera.
    ///
    /// The transform's origin is at Jeffrey's feet.
    [RequireComponent(typeof(CharacterController))]
    [RequireComponent(typeof(ThiefInput))]
    [DefaultExecutionOrder(-50)]
    public class ThiefMovement : MonoBehaviour
    {
        [Header("Speed (m/s)")]
        public float walkSpeed = 2.6f;
        public float runSpeed = 5.2f;
        [Tooltip("Speed while crouched, as a fraction of walk or run speed (Thief's creep).")]
        [Range(0.1f, 1f)] public float crouchMultiplier = 0.5f;
        [Range(0.1f, 1f)] public float backwardMultiplier = 0.7f;
        [Range(0.1f, 1f)] public float strafeMultiplier = 0.85f;
        [Tooltip("Thief's 'always run'. Shift then switches to walking.")]
        public bool alwaysRun = false;

        [Header("Acceleration (m/s²)")]
        public float groundAcceleration = 28f;
        public float groundDeceleration = 22f;
        [Tooltip("Thief gives you very little steering in the air.")]
        public float airAcceleration = 3f;

        [Header("Jump and gravity")]
        public float jumpHeight = 0.8f;
        public float gravity = 20f;
        public float maxFallSpeed = 40f;

        [Header("Keyboard turning (arrow keys)")]
        public float keyboardTurnSpeed = 130f;

        [Header("Body")]
        public float standHeight = 1.8f;
        public float crouchHeight = 1.05f;
        public float radius = 0.3f;
        [Tooltip("Metres per second the body grows or shrinks when crouching.")]
        public float crouchTransitionSpeed = 5f;
        [Tooltip("C toggles crouch, as in Thief. Off: hold C.")]
        public bool crouchIsToggle = true;
        public float stepOffset = 0.35f;
        public float slopeLimit = 46f;

        [Header("Mantle (hold Jump at a ledge)")]
        [Tooltip("Lowest ledge, above the feet, worth mantling (lower ones are just steps).")]
        public float mantleMinHeight = 0.45f;
        [Tooltip("Highest ledge you can mantle from standing.")]
        public float mantleMaxHeightGrounded = 1.9f;
        [Tooltip("Highest ledge above your feet you can catch in mid-air.")]
        public float mantleMaxHeightAirborne = 1.6f;
        [Tooltip("How far in front of the body a ledge can be.")]
        public float mantleReach = 0.6f;
        [Tooltip("Seconds to pull up a ledge of the highest height.")]
        public float mantleRiseTime = 0.7f;
        [Tooltip("Seconds to roll forward onto the ledge.")]
        public float mantleForwardTime = 0.3f;

        // ---- state, read by the camera, HUD and anything else ----
        public MoveState State { get; private set; }
        public Vector3 Velocity => horizontal + Vector3.up * vertical;
        public float HorizontalSpeed => horizontal.magnitude;
        public bool IsCrouched => wantCrouch || currentHeight < standHeight - 0.01f;
        public bool IsRunning { get; private set; }
        public bool IsLeaningForward { get; private set; }
        public float CurrentHeight => currentHeight;
        /// 0..1 through a mantle, or -1 when not mantling.
        public float MantleProgress { get; private set; } = -1f;
        /// Set by ThiefCamera: how far into a lean we are (0..1), for slowing down.
        public float LeanSlowdown { get; set; } = 1f;
        public bool JustLanded { get; private set; }
        public float LastLandingSpeed { get; private set; }

        public const int PlayerLayer = 2; // "Ignore Raycast": our own probes skip the player.
        public static int EnvironmentMask => Physics.DefaultRaycastLayers & ~(1 << PlayerLayer);

        CharacterController body;
        ThiefInput input;
        Vector3 horizontal;
        float vertical;
        bool wantCrouch;
        float currentHeight;

        // mantle
        Vector3 mantleStart, mantleTop, mantleEnd;
        float mantleTime, mantleRise, mantleTotal;
        bool mantleEndsCrouched;

        void Awake()
        {
            body = GetComponent<CharacterController>();
            input = GetComponent<ThiefInput>();
            SetLayerRecursively(transform, PlayerLayer);
            body.radius = radius;
            body.stepOffset = stepOffset;
            body.slopeLimit = slopeLimit;
            body.skinWidth = 0.04f;
            body.minMoveDistance = 0f;
            currentHeight = standHeight;
            ApplyHeight(currentHeight);
        }

        static void SetLayerRecursively(Transform t, int layer)
        {
            t.gameObject.layer = layer;
            foreach (Transform c in t) SetLayerRecursively(c, layer);
        }

        void Update()
        {
            float dt = Time.deltaTime;
            JustLanded = false;
            if (dt <= 0f) return;

            if (State == MoveState.Mantling)
            {
                UpdateMantle(dt);
                return;
            }

            bool grounded = body.isGrounded;
            bool slide = input.Held(ThiefAction.Slide);

            // Arrow keys turn; with Slide held they strafe instead.
            float turn = Axis(ThiefAction.TurnRight, ThiefAction.TurnLeft);
            float strafe = Axis(ThiefAction.StrafeRight, ThiefAction.StrafeLeft);
            if (slide)
            {
                strafe = Mathf.Clamp(strafe + turn, -1f, 1f);
                turn = 0f;
            }
            if (turn != 0f) transform.Rotate(0f, turn * keyboardTurnSpeed * dt, 0f);

            float forward = Axis(ThiefAction.Forward, ThiefAction.Backward);
            // Alt + W leans forward instead of walking.
            IsLeaningForward = slide && input.Held(ThiefAction.Forward) && grounded;
            if (IsLeaningForward) forward = input.Held(ThiefAction.Backward) ? -1f : 0f;

            // Crouch.
            if (crouchIsToggle)
            {
                if (input.Pressed(ThiefAction.Crouch)) wantCrouch = !wantCrouch;
            }
            else
            {
                wantCrouch = input.Held(ThiefAction.Crouch);
            }
            UpdateCrouch(dt);

            // Speed.
            bool run = alwaysRun != input.Held(ThiefAction.SpeedToggle);
            IsRunning = run && !IsCrouched && (forward != 0f || strafe != 0f);
            float speed = run ? runSpeed : walkSpeed;
            if (IsCrouched) speed *= crouchMultiplier;
            speed *= LeanSlowdown;

            var wishLocal = new Vector3(strafe, 0f, forward);
            if (wishLocal.sqrMagnitude > 1f) wishLocal.Normalize();
            wishLocal.x *= strafeMultiplier;
            if (wishLocal.z < 0f) wishLocal.z *= backwardMultiplier;
            Vector3 wish = transform.TransformDirection(wishLocal) * speed;
            wish.y = 0f;

            if (grounded)
            {
                float accel = wish.sqrMagnitude > 0.0001f ? groundAcceleration : groundDeceleration;
                horizontal = Vector3.MoveTowards(horizontal, wish, accel * dt);
            }
            else if (wish.sqrMagnitude > 0.0001f)
            {
                // Air control can steer but never speed you past what you had or your run speed.
                float cap = Mathf.Max(horizontal.magnitude, speed);
                horizontal = Vector3.ClampMagnitude(
                    Vector3.MoveTowards(horizontal, horizontal + wish, airAcceleration * dt), cap);
            }

            // Jump and mantle. Holding Jump keeps looking for a ledge, on the
            // ground and in the air; pressing it jumps if there isn't one.
            if (input.Held(ThiefAction.Jump))
            {
                if (TryStartMantle(grounded)) return;
                if (grounded && input.Pressed(ThiefAction.Jump))
                {
                    vertical = Mathf.Sqrt(2f * gravity * jumpHeight);
                    grounded = false;
                }
            }

            if (grounded && vertical <= 0f) vertical = -2f; // stick to slopes and steps
            else vertical = Mathf.Max(vertical - gravity * dt, -maxFallSpeed);

            float fallSpeed = -vertical;
            var flags = body.Move((horizontal + Vector3.up * vertical) * dt);
            if ((flags & CollisionFlags.Above) != 0 && vertical > 0f) vertical = 0f;

            bool nowGrounded = body.isGrounded;
            if (nowGrounded)
            {
                // Walls stop you: take the speed the controller actually managed.
                var v = body.velocity;
                var flat = new Vector3(v.x, 0f, v.z);
                if (flat.sqrMagnitude < horizontal.sqrMagnitude) horizontal = flat;
                if (State == MoveState.Airborne)
                {
                    JustLanded = true;
                    LastLandingSpeed = fallSpeed;
                }
            }
            else if ((flags & CollisionFlags.Sides) != 0)
            {
                var v = body.velocity;
                var flat = new Vector3(v.x, 0f, v.z);
                if (flat.sqrMagnitude < horizontal.sqrMagnitude) horizontal = flat;
            }
            State = nowGrounded ? MoveState.Grounded : MoveState.Airborne;
        }

        float Axis(ThiefAction positive, ThiefAction negative)
        {
            return (input.Held(positive) ? 1f : 0f) - (input.Held(negative) ? 1f : 0f);
        }

        // ---- crouch ---------------------------------------------------

        void UpdateCrouch(float dt)
        {
            float target = wantCrouch ? crouchHeight : standHeight;
            if (target > currentHeight && !HasHeadroom(transform.position, target)) target = currentHeight;
            float h = Mathf.MoveTowards(currentHeight, target, crouchTransitionSpeed * dt);
            if (!Mathf.Approximately(h, currentHeight))
            {
                currentHeight = h;
                ApplyHeight(h);
            }
        }

        void ApplyHeight(float h)
        {
            body.height = h;
            body.center = new Vector3(0f, h * 0.5f, 0f);
        }

        /// Is there room for a body of this height standing at these feet?
        public bool HasHeadroom(Vector3 feet, float height)
        {
            float r = radius - 0.02f;
            var bottom = feet + Vector3.up * (r + 0.06f);
            var top = feet + Vector3.up * Mathf.Max(height - r, r + 0.07f);
            return !Physics.CheckCapsule(bottom, top, r, EnvironmentMask, QueryTriggerInteraction.Ignore);
        }

        // ---- mantle ---------------------------------------------------

        static readonly float[] ProbeDistances = { 0.15f, 0.35f, 0.6f };

        bool TryStartMantle(bool grounded)
        {
            Vector3 feet = transform.position;
            Vector3 fwd = transform.forward;
            fwd.y = 0f;
            if (fwd.sqrMagnitude < 0.001f) return false;
            fwd.Normalize();

            float maxH = grounded ? mantleMaxHeightGrounded : mantleMaxHeightAirborne;
            float minH = grounded ? mantleMinHeight : 0.25f;
            float minNormalY = Mathf.Cos(slopeLimit * Mathf.Deg2Rad);

            foreach (float d in ProbeDistances)
            {
                if (d > mantleReach + 0.001f) break;
                Vector3 probe = feet + fwd * (radius + d);
                Vector3 origin = probe + Vector3.up * (maxH + 0.05f);
                float length = maxH + 0.05f - minH;
                if (!Physics.Raycast(origin, Vector3.down, out var hit, length, EnvironmentMask, QueryTriggerInteraction.Ignore))
                    continue;
                if (hit.normal.y < minNormalY) continue;

                float ledgeHeight = hit.point.y - feet.y;
                if (ledgeHeight < minH || ledgeHeight > maxH) continue;

                // Room to rise straight up, crouched, beside the ledge.
                var top = new Vector3(feet.x, hit.point.y, feet.z);
                if (!HasHeadroom(top + Vector3.up * 0.02f, crouchHeight)) continue;
                // Room on top of the ledge, at least crouched.
                Vector3 end = hit.point + fwd * (radius + 0.05f);
                end.y = hit.point.y + 0.02f;
                if (!HasHeadroom(end, crouchHeight)) continue;

                StartMantle(feet, top + Vector3.up * 0.02f, end, ledgeHeight, !HasHeadroom(end, standHeight));
                return true;
            }
            return false;
        }

        void StartMantle(Vector3 start, Vector3 top, Vector3 end, float height, bool endCrouched)
        {
            State = MoveState.Mantling;
            mantleStart = start;
            mantleTop = top;
            mantleEnd = end;
            mantleEndsCrouched = endCrouched;
            float maxH = Mathf.Max(mantleMaxHeightGrounded, 0.01f);
            mantleRise = mantleRiseTime * Mathf.Clamp(height / maxH, 0.35f, 1f);
            mantleTotal = mantleRise + mantleForwardTime;
            mantleTime = 0f;
            MantleProgress = 0f;
            horizontal = Vector3.zero;
            vertical = 0f;
            // Pull the legs up while climbing so the body fits over the lip.
            currentHeight = crouchHeight;
            ApplyHeight(currentHeight);
            body.enabled = false;
        }

        void UpdateMantle(float dt)
        {
            mantleTime += dt;
            Vector3 pos;
            if (mantleTime < mantleRise)
            {
                float t = Smooth(mantleTime / mantleRise);
                pos = Vector3.Lerp(mantleStart, mantleTop, t);
            }
            else
            {
                float t = Smooth(Mathf.Clamp01((mantleTime - mantleRise) / Mathf.Max(mantleForwardTime, 0.01f)));
                pos = Vector3.Lerp(mantleTop, mantleEnd, t);
            }
            transform.position = pos;
            MantleProgress = Mathf.Clamp01(mantleTime / mantleTotal);

            if (mantleTime >= mantleTotal)
            {
                transform.position = mantleEnd;
                body.enabled = true;
                // Stand up afterwards unless the space on top is too low,
                // in which case stay crouched (as in Thief).
                wantCrouch = mantleEndsCrouched || wantCrouch;
                State = MoveState.Grounded;
                MantleProgress = -1f;
            }
        }

        static float Smooth(float t)
        {
            t = Mathf.Clamp01(t);
            return t * t * (3f - 2f * t);
        }

        /// Move Jeffrey somewhere (respawn, teleport) without the controller fighting it.
        public void Teleport(Vector3 feet, float yaw)
        {
            body.enabled = false;
            transform.SetPositionAndRotation(feet, Quaternion.Euler(0f, yaw, 0f));
            body.enabled = true;
            horizontal = Vector3.zero;
            vertical = 0f;
            State = MoveState.Airborne;
        }
    }
}
