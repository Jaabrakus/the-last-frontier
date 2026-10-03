class_name BagUI
extends RefCounted
## The rules and the look of the bag windows (the owner 2026-10-03: "can we do the inventory similar to world of warcraft
## with the bags and etc?", then "WoW-style bags ... i just need you to do these"), one set for the HUD's windows
## (BagWindows) and the character screen's bag grids (InventoryScreen): what a drag dropped on a slot, a bag, the hotbar or
## the ground does, and whether it may (the verdicts never change anything, so a slot can light green or red under a drag),
## the tooltip's lines, the slot's drawing. The bags themselves are PlayerBags' (a slot layout over the pack); this only
## calls its API.
##
## The drags (Godot's drag and drop; every widget makes and takes these):
##   a slot's stack       {from: "pack", kind, count, bag, slot}; a garment carried {from: "cloth", id, kind: "cloth:<id>",
##                        count, bag, slot} (the Tab screen's figure wears it); a loose stack {from, kind, count, loose}
##   a socket's bag       {from: "socket", socket, kind} (the bag bar's socket, a window's title icon)
##   a hotbar slot        {from: "hotbar", slot} (the HUD's action bar, the Tab screen's HotbarRow)
##   a spell              {from: "spell", id} (the Tab screen's Spells list)
## Where they go:
##   a slot               onto an empty slot that may hold it, onto its kind (as many as fit), onto another kind (they change
##                        places; a specialty bag refuses with its reason); a hotbar slot comes off the bar into that slot;
##                        a socket's bag comes off into it ("Empty the bag first" unless empty)
##   a bag (a window's title, the pack button)   into that bag's first free slot
##   a bag-bar socket     a bag item is put on there (the bag there must be empty: it comes off where the new one lay);
##                        another socket's bag: they change places; anything else: into that bag
##   the hotbar           a weapon, a tool or a spell onto that slot (what was there goes off the bar into the pack); a
##                        hotbar slot onto another: they swap
##   the ground           (the HUD's WorldDrop) "Drop 12 Venison?", then dropped (DroppedItem, E takes it back); not a
##                        weapon (E puts one down), the torches (T) or a garment

const CLOTH := PlayerBags.CLOTH
## The HUD windows' slot and the character screen's.
const SLOT_HUD := 36.0
const SLOT_TAB := 52.0
const GOOD := Color(0.5, 0.88, 0.42)
const BAD := Color(0.95, 0.34, 0.28)
## A specialty bag's empty slots, faintly: the shot pouch's lead, the game bag's green, the simples bag's herb.
const HOLDS_TINT := {"shot": Color(0.55, 0.6, 0.7), "game": Color(0.45, 0.62, 0.32), "simples": Color(0.62, 0.7, 0.36)}


static func _yes(what := "") -> Dictionary:
	return {"ok": true, "reason": what}


static func _no(why: String) -> Dictionary:
	return {"ok": false, "reason": why}


# --- the drags ------------------------------------------------------------------------------------------------------

static func slot_payload(bags: PlayerBags, b: int, i: int) -> Dictionary:
	var e := bags.slot(b, i)
	if e.is_empty():
		return {}
	return _stack_payload(String(e.kind), int(e.count), {"bag": b, "slot": i})


static func loose_payload(bags: PlayerBags, li: int) -> Dictionary:
	if li < 0 or li >= bags.loose.size():
		return {}
	return _stack_payload(String(bags.loose[li].kind), int(bags.loose[li].count), {"loose": li})


static func _stack_payload(k: String, n: int, where: Dictionary) -> Dictionary:
	var d := {"from": "pack", "kind": k, "count": n}
	if k.begins_with(CLOTH):
		d["from"] = "cloth"
		d["id"] = k.trim_prefix(CLOTH)
	d.merge(where)
	return d


static func socket_payload(bags: PlayerBags, socket: int) -> Dictionary:
	if socket < 0 or socket >= PlayerBags.SOCKETS or bags.sockets[socket] == "":
		return {}
	return {"from": "socket", "socket": socket, "kind": bags.sockets[socket]}


## The bag kind a drag carries ("cloth:<id>" a garment; "" none: a hotbar slot, a spell).
static func kind_of(d: Variant) -> String:
	if not (d is Dictionary):
		return ""
	match String((d as Dictionary).get("from", "")):
		"pack", "socket":
			return String(d.get("kind", ""))
		"cloth":
			return CLOTH + String(d.get("id", ""))
	return ""


## Where a drag's stack lies now: [b, i], [-1, li] loose, [] gone. The slot it came from when it still holds its kind,
## else the first of its kind (a drag from the Tab screen's Clothes list has no slot).
static func source_of(bags: PlayerBags, d: Dictionary) -> Array:
	var k := kind_of(d)
	if k == "" or String(d.get("from", "")) == "socket":
		return []
	if d.has("loose"):
		var li := int(d.loose)
		if li >= 0 and li < bags.loose.size() and String(bags.loose[li].kind) == k:
			return [-1, li]
	elif d.has("bag"):
		if String(bags.slot(int(d.bag), int(d.slot)).get("kind", "")) == k:
			return [int(d.bag), int(d.slot)]
	for b in bags.bag_count():
		for i in bags.bag_size(b):
			if String(bags.slot(b, i).get("kind", "")) == k:
				return [b, i]
	for li in bags.loose.size():
		if String(bags.loose[li].kind) == k:
			return [-1, li]
	return []


static func _src_kind(bags: PlayerBags, src: Array) -> String:
	if src.is_empty():
		return ""
	if int(src[0]) < 0:
		return String(bags.loose[int(src[1])].kind)
	return String(bags.slot(int(src[0]), int(src[1])).get("kind", ""))


static func _src_count(bags: PlayerBags, src: Array) -> int:
	if src.is_empty():
		return 0
	if int(src[0]) < 0:
		return int(bags.loose[int(src[1])].count)
	return int(bags.slot(int(src[0]), int(src[1])).get("count", 0))


# --- onto a slot ----------------------------------------------------------------------------------------------------

## What dropping `d` on slot (b, i) would do: {ok, reason}.
static func verdict_slot(p: Node, bags: PlayerBags, b: int, i: int, d: Variant) -> Dictionary:
	if not (d is Dictionary) or b < 0 or i < 0 or i >= bags.bag_size(b):
		return _no("")
	var dd := d as Dictionary
	var dst := bags.slot(b, i)
	match String(dd.get("from", "")):
		"socket":
			var s := int(dd.get("socket", -1))
			var k := bags.bag_kind(s + 1)
			if s < 0 or k == "":
				return _no("")
			var n := bags.used_slots(s + 1)
			if n > 0:
				return _no("Empty the %s first" % bags.bag_name(s + 1).to_lower())
			if b == s + 1:
				return _no("A bag does not go inside itself")
			if not dst.is_empty():
				return _no("That slot is taken")
			var r := bags.can_hold(b, k)
			return r if not bool(r.ok) else _yes("Take the %s off" % bags.bag_name(s + 1).to_lower())
		"hotbar":
			var hb := Hotbar.find(p)
			var slot := int(dd.get("slot", -1))
			if hb == null or not hb.filled(slot):
				return _no("")
			if String(hb.entry(slot).kind) == Hotbar.SPELL:
				return _yes("Off the hotbar")
			var pk := hb.pack_kind(slot)
			if dst.is_empty() and pk != "":
				var r2 := bags.can_hold(b, pk)
				if not bool(r2.ok):
					return r2
			return _yes("Off the hotbar, into the bag")
		"pack", "cloth":
			var src := source_of(bags, dd)
			var k := kind_of(dd)
			if src.is_empty():
				return _no("It is not in your bags any more")
			if int(src[0]) == b and int(src[1]) == i:
				return _yes()
			if dst.is_empty() or String(dst.kind) == k:
				return bags.can_hold(b, k)
			# another kind there: they change places (a loose stack: that one rides loose)
			var r3 := bags.can_hold(b, k)
			if not bool(r3.ok):
				return r3
			if int(src[0]) >= 0:
				return bags.can_hold(int(src[0]), String(dst.kind))
			return _yes()
	return _no("")


## Drops `d` on slot (b, i). {ok, reason}.
static func drop_slot(p: Node, bags: PlayerBags, b: int, i: int, d: Variant) -> Dictionary:
	var v := verdict_slot(p, bags, b, i, d)
	if not bool(v.ok):
		return v
	var dd := d as Dictionary
	match String(dd.get("from", "")):
		"socket":
			return bags.unequip(int(dd.socket), b, i)
		"hotbar":
			return _off_bar_into(p, bags, int(dd.slot), b, i)
		"pack", "cloth":
			var src := source_of(bags, dd)
			if int(src[0]) < 0:
				return bags.place(int(src[1]), b, i)
			return bags.move(int(src[0]), int(src[1]), b, i)
	return _no("")


## Hotbar slot `slot` emptied (its thing off the bar, into the pack: Hotbar.clear) and laid in slot (b, i) when that is
## empty (else where the bags put it: onto its stack, its old slot, the first free one).
static func _off_bar_into(p: Node, bags: PlayerBags, slot: int, b: int, i: int) -> Dictionary:
	var hb := Hotbar.find(p)
	var pk := hb.pack_kind(slot)
	var before := _counts_of(bags, pk)
	hb.clear(slot)
	bags.sync()
	if pk == "" or not bags.slot(b, i).is_empty():
		return _yes()
	# the slot the thing came into (it was empty before): moved where it was dropped
	var after := _counts_of(bags, pk)
	for key: String in after:
		if not before.has(key):
			var at := key.split(",")
			bags.move(int(at[0]), int(at[1]), b, i)
			break
	return _yes()


## "b,i" -> count of `k`'s stacks.
static func _counts_of(bags: PlayerBags, k: String) -> Dictionary:
	var out := {}
	if k == "":
		return out
	for b in bags.bag_count():
		for i in bags.bag_size(b):
			var e := bags.slot(b, i)
			if String(e.get("kind", "")) == k:
				out["%d,%d" % [b, i]] = int(e.count)
	return out


# --- into a bag, onto a socket --------------------------------------------------------------------------------------

## Where `d` would go in bag b: the slot ([b, i]; onto a stack of its kind with room first, else the first empty slot), []
## none.
static func _slot_in(bags: PlayerBags, b: int, k: String, n: int) -> Array:
	var st := PlayerBags.stack_of(k)
	for i in bags.bag_size(b):
		var e := bags.slot(b, i)
		if String(e.get("kind", "")) == k and int(e.count) + n <= st:
			return [b, i]
	for i in bags.bag_size(b):
		if bags.slot(b, i).is_empty():
			return [b, i]
	return []


## What dropping `d` into bag b (its window's title, the pack button) would do.
static func verdict_into(p: Node, bags: PlayerBags, b: int, d: Variant) -> Dictionary:
	if not (d is Dictionary) or b < 0 or b >= bags.bag_count():
		return _no("")
	var dd := d as Dictionary
	if bags.bag_kind(b) == "":
		return _no("No bag in that socket")
	var k := kind_of(dd)
	var n := 1
	match String(dd.get("from", "")):
		"hotbar":
			var hb := Hotbar.find(p)
			if hb == null or not hb.filled(int(dd.get("slot", -1))):
				return _no("")
			k = hb.pack_kind(int(dd.slot))
			if k == "":
				return _yes("Off the hotbar")
		"pack", "cloth":
			var src := source_of(bags, dd)
			if src.is_empty():
				return _no("It is not in your bags any more")
			if int(src[0]) == b:
				return _yes()
			n = _src_count(bags, src)
		"socket":
			if int(dd.get("socket", -1)) + 1 == b:
				return _no("A bag does not go inside itself")
		_:
			return _no("")
	var r := bags.can_hold(b, k)
	if not bool(r.ok):
		return r
	if _slot_in(bags, b, k, n).is_empty():
		return _no("The %s is full" % bags.bag_name(b).to_lower())
	return _yes("Into the %s" % bags.bag_name(b).to_lower())


static func drop_into(p: Node, bags: PlayerBags, b: int, d: Variant) -> Dictionary:
	var v := verdict_into(p, bags, b, d)
	if not bool(v.ok):
		return v
	var dd := d as Dictionary
	var k := kind_of(dd)
	var n := 1
	if String(dd.get("from", "")) == "hotbar":
		k = Hotbar.find(p).pack_kind(int(dd.slot))
	elif String(dd.get("from", "")) != "socket":
		var src := source_of(bags, dd)
		if int(src[0]) == b:
			return _yes()
		n = _src_count(bags, src)
	var at := _slot_in(bags, b, k, n) if k != "" else [b, 0]
	if at.is_empty():
		return _no("The %s is full" % bags.bag_name(b).to_lower())
	return drop_slot(p, bags, int(at[0]), int(at[1]), d)


## What dropping `d` on bag-bar socket `s` would do: a bag item put on there, another socket's bag changing places,
## anything else into the bag there.
static func verdict_socket(p: Node, bags: PlayerBags, s: int, d: Variant) -> Dictionary:
	if not (d is Dictionary) or s < 0 or s >= PlayerBags.SOCKETS:
		return _no("")
	var dd := d as Dictionary
	var k := kind_of(dd)
	if String(dd.get("from", "")) == "socket":
		return _yes() if int(dd.socket) == s else _yes("The bags change places")
	if PlayerBags.is_bag(k) and String(dd.get("from", "")) == "pack":
		var old := bags.sockets[s]
		if old != "" and bags.used_slots(s + 1) > 0:
			return _no("Empty the %s first" % PlayerBags.name_of(old).to_lower())
		if source_of(bags, dd).is_empty():
			return _no("It is not in your bags any more")
		return _yes("Put the %s on: bag %d" % [PlayerBags.name_of(k).to_lower(), s + 1])
	if bags.sockets[s] == "":
		return _no("No bag in bag %d: drag a bag here" % (s + 1))
	return verdict_into(p, bags, s + 1, d)


static func drop_socket(p: Node, bags: PlayerBags, s: int, d: Variant) -> Dictionary:
	var v := verdict_socket(p, bags, s, d)
	if not bool(v.ok):
		return v
	var dd := d as Dictionary
	var k := kind_of(dd)
	if String(dd.get("from", "")) == "socket":
		bags.swap_sockets(int(dd.socket), s)
		return _yes()
	if PlayerBags.is_bag(k) and String(dd.get("from", "")) == "pack":
		var src := source_of(bags, dd)
		var r := bags.equip(k, s, int(src[0]) if int(src[0]) >= 0 else -1, int(src[1]) if int(src[0]) >= 0 else -1)
		return {"ok": bool(r.ok), "reason": String(r.reason) if not bool(r.ok) else "The %s is on: bag %d." % [PlayerBags.name_of(k).to_lower(), s + 1]}
	return drop_into(p, bags, s + 1, d)


# --- onto the hotbar ------------------------------------------------------------------------------------------------

## The hotbar entry a drag would put on the bar ({} none): a weapon's or a tool's from a bag, a spell.
static func bar_entry(p: Node, d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return {}
	var dd := d as Dictionary
	if String(dd.get("from", "")) == "spell":
		return Hotbar.make(Hotbar.SPELL, String(dd.get("id", "")))
	if String(dd.get("from", "")) != "pack":
		return {}
	var k := String(dd.get("kind", ""))
	return Hotbar.entry_for_kind(p, k) if k != "" and not PlayerBags.is_bag(k) else {}


static func verdict_bar(p: Node, slot: int, d: Variant) -> Dictionary:
	var hb := Hotbar.find(p)
	if hb == null or not (d is Dictionary):
		return _no("")
	if String((d as Dictionary).get("from", "")) == "hotbar":
		return _yes() if int(d.slot) == slot else _yes("Slots %d and %d swap" % [int(d.slot) + 1, slot + 1])
	var e := bar_entry(p, d)
	var nm := InventoryState.name_of(kind_of(d)) if kind_of(d) != "" else Hotbar.spell_label(String(d.get("id", "")))
	if e.is_empty():
		return _no("The %s does not go on the hotbar" % nm.to_lower()) if kind_of(d) != "" else _no("")
	if not hb.has_thing(e):
		return _no("You do not have the %s" % nm.to_lower())
	return _yes("Onto the hotbar: %d" % (slot + 1))


## Drops `d` on hotbar slot `slot`: {ok, reason} (`reason` the line said: "Musket on the hotbar: 3.").
static func drop_bar(p: Node, slot: int, d: Variant) -> Dictionary:
	var v := verdict_bar(p, slot, d)
	if not bool(v.ok):
		return v
	var hb := Hotbar.find(p)
	if String((d as Dictionary).get("from", "")) == "hotbar":
		if int(d.slot) != slot:
			hb.swap(int(d.slot), slot)
		return _yes()
	var e := bar_entry(p, d)
	var was := hb.entry(slot)
	var was_name := hb.label(slot)
	if not hb.assign(slot, e):
		return _no("That does not go on the hotbar")
	var off := not was.is_empty() and hb.slot_of(String(was.kind), String(was.id)) < 0
	return _yes("%s on the hotbar: %d.%s" % [hb.label(slot), slot + 1, (" The %s goes into the pack." % was_name.to_lower()) if off else ""])


# --- onto the ground ------------------------------------------------------------------------------------------------

## Whether `d` can be dropped on the ground: {ok, reason} (`reason` the question: "Drop 12 Venison?").
static func verdict_ground(bags: PlayerBags, d: Variant) -> Dictionary:
	if not (d is Dictionary):
		return _no("")
	var dd := d as Dictionary
	match String(dd.get("from", "")):
		"socket":
			return _no("Take the bag off first: drag it into a slot")
		"pack", "cloth":
			pass
		_:
			return _no("")
	var k := kind_of(dd)
	var src := source_of(bags, dd)
	if src.is_empty():
		return _no("It is not in your bags any more")
	var nm := bags.kind_name(k)
	if k.begins_with(CLOTH):
		return _no("A garment is not dropped from a bag: the Clothes tab (Tab) has your clothes")
	if InventoryState._derived(k):
		return _no("The %s is put down with E, not dropped from a bag" % nm.to_lower())
	if k == InventoryState.TORCH:
		return _no("A torch is set down from the hand (double-tap T)")
	var n := _src_count(bags, src)
	return _yes("Drop %s?" % (nm if n <= 1 else "%d %s" % [n, nm]))


## Drops `d` on the ground in front of the player (DroppedItem: E takes it back into the pack). {ok, reason, item}.
static func drop_ground(p: Node, bags: PlayerBags, d: Variant) -> Dictionary:
	var v := verdict_ground(bags, d)
	if not bool(v.ok):
		return v
	var src := source_of(bags, d as Dictionary)
	var r := bags.take_out_loose(int(src[1])) if int(src[0]) < 0 else bags.take_out(int(src[0]), int(src[1]))
	if not bool(r.ok):
		return r
	var k := String(r.kind)
	var n := int(r.count)
	var nm := bags.kind_name(k)
	var item := DroppedItem.make(k, n, nm.to_lower())
	item.state = (r.get("state", {}) as Dictionary).duplicate(true)
	if not GatherModels.has(k) and p.is_inside_tree():
		var m := ItemIcons.shared(p.get_tree()).model_of(k)
		if m != null:
			item.remove_child(item.model)
			item.model.free()
			item.model = m
			item.add_child(m)
	var scene := p.get_tree().current_scene if p.is_inside_tree() else null
	if scene == null:
		item.free()
		return _no("Not here")
	scene.add_child(item)
	item.global_position = ground_point(p)
	item.rotation.y = randf() * TAU
	return {"ok": true, "reason": "You drop %s." % (nm.to_lower() if n <= 1 else "%d %s" % [n, nm.to_lower()]), "item": item}


## The ground a little in front of the player (where the camera looks, along the ground; down onto what is there).
static func ground_point(p: Node) -> Vector3:
	var body := p as Node3D
	var fwd := -body.global_transform.basis.z
	var cam := body.get_viewport().get_camera_3d()
	if cam != null:
		fwd = -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at := body.global_position + fwd * 0.9
	var ex: Array[RID] = []
	if p is CollisionObject3D:
		ex.append((p as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 3.0, 0xFFFFFFFF, ex)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	return Vector3(hit.position) if not hit.is_empty() else at


# --- a right-click --------------------------------------------------------------------------------------------------

## A right-click on a bag slot in play (the HUD's windows): a bag put on (the first empty socket), a garment worn, a torch
## taken in hand, else the character screen's use on the body (ItemUse.on_body: eat, apply, drink, smoke, rope gear put on,
## a weapon or a tool onto the hotbar), the pack written back. {ok, reason}.
static func use_stack(p: Node, bags: PlayerBags, k: String) -> Dictionary:
	if k == "":
		return _no("")
	if PlayerBags.is_bag(k):
		var r := bags.equip(k)
		return {"ok": bool(r.ok), "reason": ("The %s is on: bag %d." % [PlayerBags.name_of(k).to_lower(), int(r.socket) + 1]) if bool(r.ok) else String(r.reason)}
	if k.begins_with(CLOTH):
		var br := ItemUse.bridge(p)
		var id := k.trim_prefix(CLOTH)
		if br == null or br.core == null:
			return _no("Not now")
		if not ClothesSlots.wear(br, id):            # (the look follows: ClothesSlots.sync_look)
			return _no("The %s will not go on" % ClothesSlots.name_of(br.core, id).to_lower())
		bags.sync()
		return _yes("%s on." % ClothesSlots.name_of(br.core, id))
	if k == InventoryState.TORCH:
		var t: Variant = p.get("torch")
		if not (t is PlayerTorch):
			return _no("")
		if (t as PlayerTorch).holding():
			return _no("A torch is already in your hand")
		return _yes("A torch in your left hand.") if (t as PlayerTorch).take_out() else _no("No torch to take")
	var inv := InventoryState.from_player(p)
	var r2 := ItemUse.on_body(p, inv, k)
	if bool(r2.gear):
		p.call(&"apply_loadout", inv.worn, inv.pack)
	else:
		p.set("inventory_pack", inv.pack.duplicate(true))
	bags.sync()
	return {"ok": bool(r2.ok), "reason": String(r2.text)}


## What a right-click on `k` would do, for the tooltip ("" nothing).
static func use_hint(p: Node, k: String) -> String:
	if k == "":
		return ""
	if PlayerBags.is_bag(k):
		return "Right-click: put it on (or drag it onto the bag bar)"
	if k.begins_with(CLOTH):
		return "Right-click: wear it"
	if k == InventoryState.TORCH:
		return "Right-click: a torch in your left hand"
	if InventoryState.GEAR_KINDS.has(k):
		return "Right-click: put it on"
	var br := ItemUse.bridge(p)
	if br and br.can_eat(k):
		return "Right-click: eat"
	if ForageUse.can_use(k) or Remedies.can_use(k):
		return "Right-click: use it on a wound"
	if Vices.can_use(k):
		return "Right-click: take it"
	if Vices.DRINKS.has(k):
		return "Right-click: drink a gill"
	if Vices.FILLS.has(k) or k == "clay_pipe":
		return "Right-click: smoke a pipeful"
	if not Hotbar.entry_for_kind(p, k).is_empty():
		return "Right-click or drag onto the action bar: onto the hotbar"
	return ""


# --- the tooltip ----------------------------------------------------------------------------------------------------

## A stack's tooltip: {name, tag, text, rows: [[label, value, tone]]} (ItemInfo's, a bag's slots and what it holds; a loose
## stack's slow-down; how to use it, split it, drop it).
static func tip(p: Node, bags: PlayerBags, k: String, n: int, loose := false) -> Dictionary:
	var out := {"name": bags.kind_name(k), "tag": "", "text": "", "rows": []}
	var rows: Array = []
	if k.begins_with(CLOTH):
		var br := ItemUse.bridge(p)
		var id := k.trim_prefix(CLOTH)
		out.tag = "Garment"
		if br != null and br.core != null:
			rows.append(["Worn", ClothesSlots.zone_name(ClothesSlots.zone_of(br.core, id)).to_lower(), ""])
	else:
		var info := ItemInfo.of(k, p, n)
		out.name = PlayerBags.name_of(k) if PlayerBags.is_bag(k) else String(info.name)
		out.tag = String(info.tag)
		out.text = String(info.text)
		rows.append_array(info.rows)
	if n > 1:
		rows.push_front(["Stack", "%d (a slot holds %d)" % [n, PlayerBags.stack_of(k)], ""])
	if loose:
		rows.append(["Loose", "it fits in no bag: it slows you", ItemInfo.WARN])
	var hint := use_hint(p, k)
	if hint != "":
		rows.append(["", hint, ItemInfo.USE])
	if n > 1:
		rows.append(["", "Shift-click: split the stack", ItemInfo.USE])
	out.rows = rows
	return out


# --- drawing --------------------------------------------------------------------------------------------------------

## A bag slot in `r`: the socket sunk in the leather (a specialty bag's empty ones faintly tinted: `holds`), the thing on
## its paper bed (`tex`; none yet: a garment's mark or its initials), its count bottom right in outlined white; the rims:
## `state` "ok" green / "no" red (a drag over it), `hover` brass, `picked` gold, `loose` red.
static func draw_slot(ci: CanvasItem, r: Rect2, k: String, n: int, tex: Texture2D, holds := "", state := "", hover := false,
		picked := false, loose := false, count_size := 12) -> void:
	ClassicSkin.socket(ci, r)
	if k == "" and HOLDS_TINT.has(holds):
		var t: Color = HOLDS_TINT[holds]
		ci.draw_rect(r.grow(-2.0), Color(t.r, t.g, t.b, 0.13))
	if k != "":
		ClassicActionBar.ActionButton.parchment(ci, r.grow(-2.0))
		if tex != null:
			ClassicSkin.fit_texture(ci, tex, r, maxf(3.0, r.size.x * 0.08))
		elif k.begins_with(CLOTH):
			garment(ci, r.get_center(), r.size.x * 0.3)
		else:
			var s := InventoryState.name_of(k).substr(0, 3)
			ClassicSkin.text_centred(ci, r, s, int(r.size.x * 0.3), ClassicSkin.INK)
		if n > 1:
			ClassicSkin.text_right(ci, Vector2(r.end.x - 3.0, r.end.y - 3.0), str(n), count_size, Color.WHITE)
	if loose:
		ci.draw_rect(r.grow(-0.5), Color(BAD.r, BAD.g, BAD.b, 0.75), false, 1.5)
	if picked:
		ci.draw_rect(r.grow(-1.0), ClassicSkin.GOLD, false, 2.0)
	if hover and state == "":
		ci.draw_rect(r.grow(-0.5), Color(ClassicSkin.BRASS_HI.r, ClassicSkin.BRASS_HI.g, ClassicSkin.BRASS_HI.b, 0.8), false, 1.0)
		ci.draw_rect(r.grow(-2.0), Color(1, 0.95, 0.8, 0.08))
	if state == "ok":
		ci.draw_rect(r.grow(-1.0), GOOD, false, 2.0)
	elif state == "no":
		ci.draw_rect(r.grow(-2.0), Color(BAD.r, BAD.g, BAD.b, 0.18))
		ci.draw_rect(r.grow(-1.0), BAD, false, 2.0)


## A garment carried (no picture of its own): a coat's shape in linen with an ink edge, about `k` px from `c` to its edge.
static func garment(ci: CanvasItem, c: Vector2, k: float) -> void:
	var pts := PackedVector2Array([Vector2(-0.28, -0.85), Vector2(-0.72, -0.62), Vector2(-1.0, 0.18), Vector2(-0.74, 0.28),
			Vector2(-0.6, -0.12), Vector2(-0.58, 0.9), Vector2(0.58, 0.9), Vector2(0.6, -0.12), Vector2(0.74, 0.28),
			Vector2(1.0, 0.18), Vector2(0.72, -0.62), Vector2(0.28, -0.85), Vector2(0.0, -0.5)])
	for j in pts.size():
		pts[j] = c + pts[j] * k
	ci.draw_colored_polygon(pts, Color(0.86, 0.8, 0.66))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.13, 0.07, 0.9), 1.4, true)
	ci.draw_line(c + Vector2(0.0, -0.5) * k, c + Vector2(0.0, 0.9) * k, Color(0.2, 0.13, 0.07, 0.6), 1.0, true)


## A small leather button with its word on it (the split box's, the drop question's).
class LeatherButton:
	extends Control
	var text := ""
	var action: Callable
	var _hover := false

	func _init(t := "", a := Callable()) -> void:
		text = t
		action = a
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func press() -> void:
		if action.is_valid():
			action.call()

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			accept_event()
			press()
		elif mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		ClassicSkin.panel(self, r, false)
		if _hover:
			ClassicSkin.edge(self, r.grow(-2.5), 1.0, 1.4)
		ClassicSkin.text_centred(self, r, text, 14, ClassicSkin.BRASS_HI if _hover else ClassicSkin.INK)


## The stack split (shift-click): "Split off [ 6 ] of 12" with - and +, the wheel or the keys for the number; Enter or Split
## does it (`on_split`(n)), Escape or Cancel closes it.
class SplitBox:
	extends Control
	const W := 214.0
	const H := 92.0
	var n := 1
	var most := 1
	var on_split: Callable
	var field: LineEdit
	var title := ""

	func _init() -> void:
		name = "SplitBox"
		size = Vector2(W, H)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		field = LineEdit.new()
		field.name = "Count"
		field.alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.position = Vector2(W * 0.5 - 26.0, 30.0)
		field.size = Vector2(52, 26)
		field.max_length = 3
		field.add_theme_font_size_override("font_size", 15)
		field.text_changed.connect(func(t: String) -> void:
			var digits := ""
			for ch in t:
				if ch >= "0" and ch <= "9":
					digits += ch
			if digits != t:
				field.text = digits
				field.caret_column = digits.length()
			if digits != "":
				n = clampi(int(digits), 1, most))
		field.text_submitted.connect(func(_t: String) -> void: confirm())
		add_child(field)
		for pair: Array in [["-", -1, Vector2(W * 0.5 - 56.0, 30.0)], ["+", 1, Vector2(W * 0.5 + 30.0, 30.0)]]:
			var step := int(pair[1])
			var bt := BagUI.LeatherButton.new(String(pair[0]), func() -> void: set_n(n + step))
			bt.position = pair[2]
			bt.size = Vector2(26, 26)
			add_child(bt)
		var ok := BagUI.LeatherButton.new("Split", confirm)
		ok.name = "Split"
		ok.position = Vector2(14.0, H - 32.0)
		ok.size = Vector2(88, 24)
		add_child(ok)
		var no := BagUI.LeatherButton.new("Cancel", close)
		no.position = Vector2(W - 102.0, H - 32.0)
		no.size = Vector2(88, 24)
		add_child(no)

	## Opens for a stack of `count` (its name `nm`) at `at` (screen px; kept on the screen), `done`(n) to split off n.
	func open_for(at: Vector2, count: int, nm: String, done: Callable) -> void:
		most = maxi(count - 1, 1)
		on_split = done
		title = "Split the %s" % nm.to_lower()
		set_n(maxi(count / 2, 1))
		var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
		position = Vector2(clampf(at.x, 8.0, vp.x - W - 8.0), clampf(at.y, 8.0, vp.y - H - 8.0))
		visible = true
		queue_redraw()
		if is_inside_tree():
			field.grab_focus()
			field.select_all()

	func set_n(v: int) -> void:
		n = clampi(v, 1, most)
		field.text = str(n)
		field.caret_column = field.text.length()

	func confirm() -> void:
		if not visible:
			return
		visible = false
		if on_split.is_valid():
			on_split.call(n)

	func close() -> void:
		visible = false

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_n(n + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1))
			accept_event()

	func _input(e: InputEvent) -> void:
		if not visible or not (e is InputEventKey) or not e.pressed or e.echo:
			return
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif k == KEY_ENTER or k == KEY_KP_ENTER:
			confirm()
			get_viewport().set_input_as_handled()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		ClassicSkin.panel(self, r)
		ClassicSkin.text_centred(self, Rect2(0, 4, W, 20), title, 14, ClassicSkin.GOLD)
		ClassicSkin.text(self, Vector2(W * 0.5 + 62.0, 48.0), "of %d" % (most + 1), 12, ClassicSkin.DIM)
