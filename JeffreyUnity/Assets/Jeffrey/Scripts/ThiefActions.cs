using System;
using System.Collections.Generic;
using UnityEngine;

namespace Jeffrey
{
    /// Anything the Use key (right mouse / Enter) can work: doors, levers, pickups.
    public interface IThiefUsable
    {
        string UsePrompt { get; }
        void Use(GameObject user);
    }

    [Serializable]
    public class InventoryItem
    {
        public string name;
        public int count;
        public Color dropColor = Color.gray;

        public InventoryItem(string name, int count, Color dropColor)
        {
            this.name = name;
            this.count = count;
            this.dropColor = dropColor;
        }
    }

    /// The rest of the Thief 2 key list, wired up as placeholders so the
    /// keys all do something visible: weapons (numpad + / -, ~), attack and
    /// block, the inventory (Tab, Shift + Tab, Backspace), Use and Drop.
    /// Real sword, bow and items come later; this is the plumbing.
    [RequireComponent(typeof(ThiefInput))]
    public class ThiefActions : MonoBehaviour
    {
        public string[] weapons = { "Sword", "Bow (rope arrows)" };
        public List<InventoryItem> items = new List<InventoryItem>
        {
            new InventoryItem("Water bomb", 3, new Color(0.3f, 0.5f, 0.9f)),
            new InventoryItem("Fire bomb", 3, new Color(0.9f, 0.35f, 0.15f)),
            new InventoryItem("Glider", 1, new Color(0.7f, 0.6f, 0.4f)),
        };

        [Tooltip("How far the Use key reaches.")]
        public float useDistance = 2.5f;
        [Tooltip("Seconds Attack must be held for a charged attack (Thief's overhead swing / full draw).")]
        public float chargeTime = 0.6f;

        /// -1 = weapon put away.
        public int WeaponIndex { get; private set; } = -1;
        /// -1 = no item selected.
        public int ItemIndex { get; private set; } = -1;
        public bool Blocking { get; private set; }
        public bool Charging => attackHeld >= 0f;
        public float Charge => attackHeld < 0f ? 0f : Mathf.Clamp01(attackHeld / Mathf.Max(chargeTime, 0.01f));
        public string WeaponName => WeaponIndex >= 0 && WeaponIndex < weapons.Length ? weapons[WeaponIndex] : "";
        public InventoryItem SelectedItem => ItemIndex >= 0 && ItemIndex < items.Count ? items[ItemIndex] : null;
        public string LookTarget { get; private set; }
        public string Message { get; private set; }

        ThiefInput input;
        ThiefCamera view;
        float attackHeld = -1f;
        float messageTimer;

        void Awake()
        {
            input = GetComponent<ThiefInput>();
            view = GetComponent<ThiefCamera>();
        }

        void Update()
        {
            float dt = Time.deltaTime;
            messageTimer -= dt;
            if (messageTimer <= 0f) Message = null;

            UpdateWeapons(dt);
            UpdateInventory();
            UpdateUse();
        }

        public void Say(string text, float seconds = 2f)
        {
            Message = text;
            messageTimer = seconds;
        }

        // ---- weapons, attack, block ----------------------------------

        void UpdateWeapons(float dt)
        {
            int n = weapons != null ? weapons.Length : 0;
            if (n > 0 && input.Pressed(ThiefAction.NextWeapon))
                SelectWeapon(WeaponIndex < 0 ? 0 : (WeaponIndex + 1) % n);
            if (n > 0 && input.Pressed(ThiefAction.PreviousWeapon))
                SelectWeapon(WeaponIndex < 0 ? n - 1 : (WeaponIndex - 1 + n) % n);
            if (input.Pressed(ThiefAction.PutAwayWeapon) && WeaponIndex >= 0)
            {
                Say("Put away the " + WeaponName.ToLowerInvariant());
                WeaponIndex = -1;
                attackHeld = -1f;
            }

            bool sword = WeaponIndex == 0;
            Blocking = sword && input.Held(ThiefAction.Block) && attackHeld < 0f;

            if (WeaponIndex < 0 || Blocking)
            {
                attackHeld = -1f;
                return;
            }
            if (input.Pressed(ThiefAction.Attack)) attackHeld = 0f;
            if (attackHeld >= 0f && input.Held(ThiefAction.Attack)) attackHeld += dt;
            if (attackHeld >= 0f && input.Released(ThiefAction.Attack))
            {
                bool charged = attackHeld >= chargeTime;
                if (sword) Say(charged ? "Overhead swing" : "Quick slash", 0.8f);
                else Say(charged ? "Loosed a rope arrow (full draw)" : "Loosed a rope arrow (weak)", 0.8f);
                attackHeld = -1f;
            }
        }

        void SelectWeapon(int index)
        {
            WeaponIndex = index;
            attackHeld = -1f;
            Say("Drew the " + WeaponName.ToLowerInvariant());
        }

        // ---- inventory -----------------------------------------------

        void UpdateInventory()
        {
            if (items.Count == 0) return;
            if (input.Pressed(ThiefAction.NextItem))
            {
                // Shift + Tab goes backwards.
                int step = input.Held(ThiefAction.SpeedToggle) ? -1 : 1;
                ItemIndex = ItemIndex < 0
                    ? (step > 0 ? 0 : items.Count - 1)
                    : (ItemIndex + step + items.Count) % items.Count;
            }
            if (input.Pressed(ThiefAction.ClearItem)) ItemIndex = -1;
            if (input.Pressed(ThiefAction.Drop)) DropSelected();
        }

        void DropSelected()
        {
            var item = SelectedItem;
            if (item == null) return;

            var eyeT = view != null && view.eye != null ? view.eye : transform;
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = "Dropped " + item.name;
            go.transform.localScale = Vector3.one * 0.2f;
            go.transform.position = eyeT.position + eyeT.forward * 0.6f;
            var r = go.GetComponent<Renderer>();
            if (r != null) r.material.color = item.dropColor;
            var rb = go.AddComponent<Rigidbody>();
            rb.mass = 0.5f;
            var pickup = go.AddComponent<DroppedItem>();
            pickup.itemName = item.name;
            pickup.dropColor = item.dropColor;

            item.count--;
            Say("Dropped a " + item.name.ToLowerInvariant());
            if (item.count <= 0)
            {
                items.RemoveAt(ItemIndex);
                ItemIndex = items.Count == 0 ? -1 : Mathf.Min(ItemIndex, items.Count - 1);
            }
        }

        public void AddItem(string itemName, int count, Color color)
        {
            foreach (var it in items)
            {
                if (it.name == itemName) { it.count += count; return; }
            }
            items.Add(new InventoryItem(itemName, count, color));
        }

        // ---- use -----------------------------------------------------

        void UpdateUse()
        {
            LookTarget = null;
            var eyeT = view != null && view.eye != null ? view.eye : transform;
            IThiefUsable usable = null;
            if (Physics.Raycast(eyeT.position, eyeT.forward, out var hit, useDistance,
                    ThiefMovement.EnvironmentMask, QueryTriggerInteraction.Collide))
            {
                usable = hit.collider.GetComponentInParent<IThiefUsable>();
                if (usable != null) LookTarget = usable.UsePrompt;
            }

            if (!input.Pressed(ThiefAction.Use)) return;
            if (usable != null)
            {
                usable.Use(gameObject);
            }
            else if (SelectedItem != null)
            {
                Say("Used the " + SelectedItem.name.ToLowerInvariant() + " (not built yet)");
            }
        }
    }

    /// An item dropped with R. Use it to pick it back up.
    public class DroppedItem : MonoBehaviour, IThiefUsable
    {
        public string itemName;
        public Color dropColor = Color.gray;

        public string UsePrompt => "Pick up " + itemName.ToLowerInvariant();

        public void Use(GameObject user)
        {
            var actions = user.GetComponent<ThiefActions>();
            if (actions == null) return;
            actions.AddItem(itemName, 1, dropColor);
            actions.Say("Picked up a " + itemName.ToLowerInvariant());
            Destroy(gameObject);
        }
    }
}
