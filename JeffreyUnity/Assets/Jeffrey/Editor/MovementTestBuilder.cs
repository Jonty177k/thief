using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Jeffrey.EditorTools
{
    /// Builds the greybox movement test scene from code, so it can always be
    /// rebuilt from scratch: menu Jeffrey → Build Movement Test Scene.
    /// The first time the project is opened it is built automatically.
    [InitializeOnLoad]
    public static class MovementTestBuilder
    {
        const string Root = "Assets/Jeffrey";
        const string ScenePath = Root + "/Scenes/MovementTest.unity";
        const string MaterialDir = Root + "/Generated";

        static Material stone, wood, floorMat, marker, glass;

        static MovementTestBuilder()
        {
            EditorApplication.delayCall += () =>
            {
                if (Application.isBatchMode || File.Exists(ScenePath)) return;
                if (SessionState.GetBool("Jeffrey.AutoBuilt", false)) return;
                SessionState.SetBool("Jeffrey.AutoBuilt", true);
                Build();
            };
        }

        [MenuItem("Jeffrey/Build Movement Test Scene")]
        public static void BuildFromMenu()
        {
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            Build();
        }

        [MenuItem("Jeffrey/Open Movement Test Scene")]
        public static void OpenScene()
        {
            if (!File.Exists(ScenePath)) { BuildFromMenu(); return; }
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            EditorSceneManager.OpenScene(ScenePath);
        }

        public static void Build()
        {
            EnsureFolder(Root, "Scenes");
            EnsureFolder(Root, "Generated");
            stone = MakeMaterial("Stone", new Color(0.45f, 0.45f, 0.48f));
            wood = MakeMaterial("Wood", new Color(0.45f, 0.3f, 0.18f));
            floorMat = MakeMaterial("Floor", new Color(0.28f, 0.3f, 0.26f));
            marker = MakeMaterial("Marker", new Color(0.8f, 0.15f, 0.12f));
            glass = MakeMaterial("Ledge", new Color(0.6f, 0.55f, 0.4f));

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            // Light, ambience and a little fog.
            var sun = new GameObject("Sun").AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.intensity = 1.0f;
            sun.shadows = LightShadows.Soft;
            sun.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.32f, 0.33f, 0.38f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.Linear;
            RenderSettings.fogStartDistance = 25f;
            RenderSettings.fogEndDistance = 90f;
            RenderSettings.fogColor = new Color(0.45f, 0.47f, 0.52f);

            var course = new GameObject("Course").transform;
            Box(course, "Ground", new Vector3(0, -0.5f, 0), new Vector3(90, 1, 90), floorMat);

            BuildMantleRow(course);
            BuildLowLedge(course);
            BuildCrouchTunnel(course);
            BuildStairsAndRamps(course);
            BuildJumpGaps(course);
            BuildLeanCorner(course);
            BuildBalcony(course);
            BuildDoors(course);

            BuildPlayer(new Vector3(0, 0.05f, 0), 0f);

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
            AssetDatabase.SaveAssets();
            Debug.Log("Jeffrey: built " + ScenePath + ". Press Play.");
        }

        // ---- the player ---------------------------------------------

        public static GameObject BuildPlayer(Vector3 feet, float yaw)
        {
            var go = new GameObject("Jeffrey");
            go.transform.SetPositionAndRotation(feet, Quaternion.Euler(0, yaw, 0));
            var cc = go.AddComponent<CharacterController>();
            cc.height = 1.8f;
            cc.radius = 0.3f;
            cc.center = new Vector3(0, 0.9f, 0);
            go.AddComponent<ThiefInput>();
            go.AddComponent<ThiefMovement>();
            var view = go.AddComponent<ThiefCamera>();
            go.AddComponent<ThiefActions>();
            go.AddComponent<ThiefHud>();

            var eye = new GameObject("Eye").transform;
            eye.SetParent(go.transform, false);
            eye.localPosition = new Vector3(0, 1.68f, 0);
            var camGo = new GameObject("Camera");
            camGo.tag = "MainCamera";
            camGo.transform.SetParent(eye, false);
            var cam = camGo.AddComponent<Camera>();
            cam.nearClipPlane = 0.05f;
            cam.farClipPlane = 300f;
            cam.fieldOfView = 75f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = RenderSettings.fogColor;
            camGo.AddComponent<AudioListener>();

            view.eye = eye;
            view.cam = cam;
            return go;
        }

        // ---- stations -----------------------------------------------

        // Straight ahead: blocks of rising height. Walk up, hold Space.
        static void BuildMantleRow(Transform parent)
        {
            var root = Group(parent, "Mantle row");
            float[] heights = { 0.5f, 0.9f, 1.3f, 1.7f, 2.1f, 2.8f };
            string[] notes = { "", "", "", "", "jump, then hold Space", "too high" };
            for (int i = 0; i < heights.Length; i++)
            {
                float x = -7.5f + i * 3f;
                float hgt = heights[i];
                Box(root, "Ledge " + hgt, new Vector3(x, hgt / 2, 9), new Vector3(1.8f, hgt, 1.8f), glass);
                string text = hgt.ToString("0.0") + " m" + (notes[i].Length > 0 ? "\n" + notes[i] : "");
                Label(root, text, new Vector3(x, hgt + 0.45f, 8.0f), Vector3.zero);
            }
            Label(root, "MANTLE: walk up to a ledge and hold Space", new Vector3(0, 3.6f, 9), Vector3.zero, 0.14f);
        }

        // Behind the mantle row: a ledge with a low roof. You end up crouched.
        static void BuildLowLedge(Transform parent)
        {
            var root = Group(parent, "Low ledge");
            Box(root, "Ledge", new Vector3(0, 0.6f, 15), new Vector3(3, 1.2f, 3), glass);
            Box(root, "Roof", new Vector3(0, 1.2f + 1.3f + 0.15f, 15f), new Vector3(3, 0.3f, 3f), stone);
            Box(root, "Roof post L", new Vector3(-1.4f, 1.85f, 16.4f), new Vector3(0.2f, 1.3f, 0.2f), stone);
            Box(root, "Roof post R", new Vector3(1.4f, 1.85f, 16.4f), new Vector3(0.2f, 1.3f, 0.2f), stone);
            Label(root, "Low roof: mantle and you stay crouched", new Vector3(0, 3.2f, 13.4f), Vector3.zero);
        }

        // Right: a tunnel too low to stand in.
        static void BuildCrouchTunnel(Transform parent)
        {
            var root = Group(parent, "Crouch tunnel");
            float x = 13f, z0 = 3f, len = 8f, gap = 1.4f, roofBottom = 1.25f;
            Box(root, "Wall L", new Vector3(x - gap / 2 - 0.3f, 1.25f, z0 + len / 2), new Vector3(0.6f, 2.5f, len), stone);
            Box(root, "Wall R", new Vector3(x + gap / 2 + 0.3f, 1.25f, z0 + len / 2), new Vector3(0.6f, 2.5f, len), stone);
            Box(root, "Roof", new Vector3(x, roofBottom + 0.625f, z0 + len / 2), new Vector3(gap + 1.2f, 1.25f, len), stone);
            Label(root, "CROUCH (C)\n1.25 m tunnel", new Vector3(x, 3.0f, z0 - 0.1f), Vector3.zero);
        }

        // Far right: stairs, a walkable ramp and one too steep to climb.
        static void BuildStairsAndRamps(Transform parent)
        {
            var root = Group(parent, "Stairs and ramps");
            float x = 21f;
            int steps = 10;
            float rise = 0.2f, run = 0.35f;
            for (int i = 0; i < steps; i++)
            {
                float top = (i + 1) * rise;
                Box(root, "Step " + (i + 1), new Vector3(x, top / 2, 2 + i * run + run / 2), new Vector3(2, top, run), stone);
            }
            Box(root, "Landing", new Vector3(x, 1f, 2 + steps * run + 1.5f), new Vector3(2, 2, 3), stone);
            Label(root, "Stairs (0.2 m steps)", new Vector3(x, 1.2f, 1.8f), Vector3.zero);

            Ramp(root, "Ramp 25", new Vector3(x + 4, 0, 2), 25f, 2f, 6f, glass);
            Label(root, "25° ramp", new Vector3(x + 4, 1.2f, 1.8f), Vector3.zero);
            Ramp(root, "Ramp 55", new Vector3(x + 8, 0, 2), 55f, 2f, 4f, marker);
            Label(root, "55°: too steep", new Vector3(x + 8, 1.2f, 1.8f), Vector3.zero);
        }

        // Behind the start: raised platforms with growing gaps.
        static void BuildJumpGaps(Transform parent)
        {
            var root = Group(parent, "Jump gaps");
            float h = 1f;
            Ramp(root, "Up ramp", new Vector3(0, 0, -4), 20f, 2.4f, h / Mathf.Sin(20f * Mathf.Deg2Rad), glass, faceBack: true);
            float z = -4f - h / Mathf.Tan(20f * Mathf.Deg2Rad);
            float[] gaps = { 1.5f, 2.5f, 3.5f };
            Box(root, "Platform 0", new Vector3(0, h / 2, z - 2f), new Vector3(2.4f, h, 4f), stone);
            z -= 4f;
            for (int i = 0; i < gaps.Length; i++)
            {
                z -= gaps[i];
                Box(root, "Platform " + (i + 1), new Vector3(0, h / 2, z - 2f), new Vector3(2.4f, h, 4f), stone);
                Label(root, "gap " + gaps[i].ToString("0.0") + " m" + (i == 1 ? " (run)" : i == 2 ? " (run, hold Space)" : ""),
                    new Vector3(1.6f, h + 0.6f, z + gaps[i] / 2), new Vector3(10, 0, z + gaps[i] / 2));
                z -= 4f;
            }
            Label(root, "JUMP GAPS (turn around)", new Vector3(0, 2.6f, -4.5f), new Vector3(0, 0, 10));
        }

        // Left: a wall corner with a red 'guard' behind it. Lean to see it.
        static void BuildLeanCorner(Transform parent)
        {
            var root = Group(parent, "Lean corner");
            Box(root, "Wall", new Vector3(-12f, 1.5f, 6f), new Vector3(0.5f, 3f, 8f), stone);
            Box(root, "Back wall", new Vector3(-16f, 1.5f, 10.25f), new Vector3(8.5f, 3f, 0.5f), stone);
            Box(root, "Guard", new Vector3(-15.5f, 0.9f, 5f), new Vector3(0.6f, 1.8f, 0.6f), marker);
            Box(root, "Stand here", new Vector3(-11.4f, 0.01f, 1.7f), new Vector3(0.6f, 0.02f, 0.6f), wood);
            Label(root, "LEAN (Q / E)\nstand on the square,\nface forward, lean left (Q)", new Vector3(-10.6f, 2.4f, 1.6f), new Vector3(0, 0, 0));
        }

        // Far left: a balcony with a parapet. Lean forward over it (Alt + W).
        static void BuildBalcony(Transform parent)
        {
            var root = Group(parent, "Balcony");
            float x = -21f, h = 2.5f;
            Box(root, "Balcony", new Vector3(x, h / 2, 6f), new Vector3(4f, h, 6f), stone);
            Ramp(root, "Balcony ramp", new Vector3(x, 0, -6f), 18f, 2.4f, h / Mathf.Sin(18f * Mathf.Deg2Rad), glass,
                customEnd: new Vector3(x, h, 3f));
            Box(root, "Parapet", new Vector3(x + 1.95f, h + 0.5f, 6f), new Vector3(0.1f, 1f, 6f), wood);
            Box(root, "Coin below", new Vector3(x + 2.25f, 0.1f, 6f), new Vector3(0.3f, 0.2f, 0.3f), marker);
            Label(root, "LEAN FORWARD (Alt + W)\nover the parapet\nto see what's below", new Vector3(x, h + 2f, 6f), new Vector3(0, h, 6f));
        }

        // Back left: a door that opens and a locked one.
        static void BuildDoors(Transform parent)
        {
            var root = Group(parent, "Doors");
            Doorway(root, "Door", new Vector3(-8f, 0, -6f), false);
            Doorway(root, "Locked door", new Vector3(-14f, 0, -6f), true);
            Label(root, "USE (right mouse / Enter)", new Vector3(-11f, 3.4f, -5.8f), new Vector3(-11f, 0, 0));
        }

        static void Doorway(Transform parent, string name, Vector3 c, bool locked)
        {
            var root = Group(parent, name);
            float w = 1.2f, hgt = 2.2f, wall = 4.5f;
            Box(root, "Left", c + new Vector3(-(w / 2 + wall / 4), 1.5f, 0), new Vector3(wall / 2, 3f, 0.3f), stone);
            Box(root, "Right", c + new Vector3(w / 2 + wall / 4, 1.5f, 0), new Vector3(wall / 2, 3f, 0.3f), stone);
            Box(root, "Lintel", c + new Vector3(0, hgt + (3f - hgt) / 2, 0), new Vector3(w, 3f - hgt, 0.3f), stone);
            var hinge = new GameObject("Hinge").transform;
            hinge.SetParent(root, false);
            hinge.position = c + new Vector3(-w / 2, 0, 0);
            var door = hinge.gameObject.AddComponent<ThiefDoor>();
            door.locked = locked;
            var slab = Box(hinge, "Slab", Vector3.zero, new Vector3(w - 0.04f, hgt - 0.02f, 0.08f), wood);
            slab.transform.position = c + new Vector3(0, hgt / 2, 0);
            slab.isStatic = false; // it moves
        }

        // ---- helpers ------------------------------------------------

        static Transform Group(Transform parent, string name)
        {
            var t = new GameObject(name).transform;
            t.SetParent(parent, false);
            return t;
        }

        static GameObject Box(Transform parent, string name, Vector3 centre, Vector3 size, Material mat)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.position = centre;
            go.transform.localScale = size;
            go.GetComponent<Renderer>().sharedMaterial = mat;
            go.isStatic = true;
            return go;
        }

        /// A ramp rising from `foot` towards +Z (or -Z with faceBack) at `angle`.
        static void Ramp(Transform parent, string name, Vector3 foot, float angle, float width, float length, Material mat,
            bool faceBack = false, Vector3? customEnd = null)
        {
            float a = angle * Mathf.Deg2Rad;
            float dz = Mathf.Cos(a) * length, dy = Mathf.Sin(a) * length;
            float dir = faceBack ? -1f : 1f;
            Vector3 end = customEnd ?? foot + new Vector3(0, dy, dz * dir);
            Vector3 along = end - foot;
            var go = Box(parent, name, Vector3.zero, new Vector3(width, 0.2f, along.magnitude), mat);
            go.transform.rotation = Quaternion.LookRotation(along.normalized, Vector3.up);
            // Sink it by half its thickness so the top surface runs foot to end.
            go.transform.position = (foot + end) / 2 - go.transform.up * 0.1f;
        }

        static void Label(Transform parent, string text, Vector3 pos, Vector3 readFrom, float size = 0.09f)
        {
            var go = new GameObject("Label");
            go.transform.SetParent(parent, false);
            go.transform.position = pos;
            var look = pos - readFrom;
            look.y = 0;
            if (look.sqrMagnitude > 0.001f) go.transform.rotation = Quaternion.LookRotation(look.normalized);
            var tm = go.AddComponent<TextMesh>();
            tm.text = text;
            tm.characterSize = size;
            tm.fontSize = 48;
            tm.anchor = TextAnchor.MiddleCenter;
            tm.alignment = TextAlignment.Center;
            tm.color = new Color(1f, 0.95f, 0.8f);
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (font != null)
            {
                tm.font = font;
                go.GetComponent<MeshRenderer>().sharedMaterial = font.material;
            }
        }

        static Material MakeMaterial(string name, Color color)
        {
            string path = MaterialDir + "/" + name + ".mat";
            var existing = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (existing != null) return existing;
            var shader = Shader.Find("Universal Render Pipeline/Lit");
            if (shader == null || GraphicsSettings.currentRenderPipeline == null) shader = Shader.Find("Standard");
            var mat = new Material(shader) { color = color };
            if (mat.HasProperty("_Glossiness")) mat.SetFloat("_Glossiness", 0.05f);
            if (mat.HasProperty("_Smoothness")) mat.SetFloat("_Smoothness", 0.05f);
            AssetDatabase.CreateAsset(mat, path);
            return mat;
        }

        static void EnsureFolder(string parent, string child)
        {
            if (!AssetDatabase.IsValidFolder(parent + "/" + child)) AssetDatabase.CreateFolder(parent, child);
        }
    }
}
