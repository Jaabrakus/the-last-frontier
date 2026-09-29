class_name WorkerGear
extends Node
## What a household worker carries of the household's things, worn on her body as the player wears his (user 2026-09-29:
## "why doesn't the NPC sling the weapon properly"): the game's own slinging (SlingRig, scripts/loadout/sling_rig.gd) on her
## Actor_B skeleton and CharacterBodyMesh, from a Loadout made of what she holds from the tool pool (ToolPool.held_by):
##   musket, over-and-under, spear pair, bow (and its quiver, with her arrows)   slung on the back (long_A / long_B, quiver)
##   pistol, tomahawk (the hatchet rides as one)                                  on the belt or sash hooks (LoadoutRules)
##   powder                                                                       the powder horn on its strap
##   knife                                                                        in its sheath on the left hip (the rig
##                                                                                has no stowed placement for a knife: the
##                                                                                sheath is drawn here on the pelvis, where
##                                                                                carry_gear.json's L_hip.knife hangs)
## The waist gear is her outfit's (LoadoutRules.gear_from_appearance; a plain tied belt when she wears none) and the bulk
## is her outermost garment's (PlayerOutfit.bulk_key), as the player's. It is rebuilt when she checks things out or brings
## them back (the pool's ledger changes).
##
## Only while she works with it or aims it does a thing go to her hand: hold(kind, true) puts the rig's item in the hand
## (SlingRig.snap_held) as the weapon's own model on her hand's prop socket at the player's grip (SlingRig.HAND_OFFSET: the
## player's weapon offsets); a tool with no place on the body (the felling axe, an awl) is shown in the hand at the gathering
## tools' one-hand grip (GatherTools.blade_offset: its carry grip at the fist). hold(kind, false) puts it back.
## ToolCarry makes one on every worker body (Household._spawn, TOOLS).

## Pool kinds and the loadout kinds they are carried as.
const KIND_MAP := {"musket": "musket", "over_under": "over_under", "bow": "bow", "spear_pair": "spear_pair",
		"pistol": "pistol", "tomahawk": "tomahawk", "hatchet": "tomahawk"}
## The order they are put on (the long weapons first: LoadoutRules gives them their slots).
const ORDER := ["musket", "over_under", "spear_pair", "bow", "pistol", "tomahawk", "hatchet"]
const KNIVES := ["trade_knife", "flint_knife"]
## carry_gear.json points."L_hip.knife" capsule (bind space): the sheath hangs along it.
const KNIFE_FROM := Vector3(0.1819, 1.002, 0.0743)
const KNIFE_TO := Vector3(0.2376, 0.692, 0.0849)

var body: Spouse
var sc: SpouseCore
var rig: SlingRig
var loadout: Loadout
## What the loadout was made of ("" nothing yet).
var signature := ""
var _slots := {}
var _t := 0.0
## item id -> the weapon's own model on her hand's prop socket.
var _hand := {}
var _sockets := {}
## The kind in her hand now ("" none), and a tool shown there that has no place on the body.
var in_hand := ""
var _tool_model: Node3D
var _tool_kind := ""
var _sheath: Node3D


static func attach(b: Spouse) -> WorkerGear:
	var g := WorkerGear.new()
	g.name = "WorkerGear"
	g.body = b
	g.sc = b.sc
	b.add_child(g)
	return g


static func of(b: Node) -> WorkerGear:
	return b.get_node_or_null("WorkerGear") as WorkerGear if b else null


func _ready() -> void:
	process_priority = 90


func pool() -> ToolPool:
	return ToolPool.of(sc) if sc != null else null


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or body == null or body.sk == null:
		return
	_t = 0.25
	refresh()


## Rebuilds the worn loadout when what she holds has changed.
func refresh(force := false) -> void:
	var p := pool()
	var held: Dictionary = p.held_by(sc) if p != null else {}
	var keys := held.keys()
	keys.sort()
	var sig := ""
	for k: String in keys:
		sig += "%s:%d," % [k, int(held[k])]
	if sig == signature and not force:
		return
	signature = sig
	var was := in_hand
	if was != "":
		hold(was, false)
	_build(held)
	if was != "" and held.has(was):
		hold(was, true)


# ---------------------------------------------------------------- the loadout
## Her outfit's worn slots (as PlayerOutfit.dress gives them: slot -> garment id; {"bare": true} when none).
static func outfit_slots(look: Dictionary) -> Dictionary:
	var outfit: Dictionary = look.get("outfit", {}) if look.get("outfit") is Dictionary else {}
	var eff := PlayerOutfit.effective(outfit, float(look.get("sex", 0.0)))
	var worn := {}
	for slot: String in PlayerOutfit.SLOTS:
		var v: Variant = eff.get(slot, {})
		var id := String((v as Dictionary).get("id", "")) if v is Dictionary else ""
		if id != "" and not PlayerOutfit.entry(id).is_empty():
			worn[slot] = id
	return worn if not worn.is_empty() else {"bare": true}


## The Loadout for what she holds ({pool kind: n}) over her outfit (`slots`).
static func loadout_for(held: Dictionary, slots: Dictionary) -> Loadout:
	var lo := Loadout.new()
	var g := LoadoutRules.gear_from_appearance(slots, false)
	lo.gear = PackedStringArray(g.get("gear", []))
	lo.shoulder_ew_sash = bool(g.get("shoulder_ew_sash", false))
	var waist := false
	for id: String in lo.gear:
		if id != "back_slings" and id != "ew_sash" and id != "horn_strap" and id != "shot_pouch_strap" and id != "pistol_sling":
			waist = true
	if not waist:
		lo.gear.append("belt_tied_behind")      # (a plain belt tied behind: something for the hooks)
	if int(held.get("powder", 0)) > 0 and not lo.gear.has("horn_strap"):
		lo.gear.append("horn_strap")
	lo.outfit_bulk = PlayerOutfit.bulk_key(slots)
	for pk: String in ORDER:
		var n := int(held.get(pk, 0))
		var k := String(KIND_MAP.get(pk, ""))
		if n <= 0 or k == "":
			continue
		for i in (n if k in ["pistol", "tomahawk"] else 1):
			var r := LoadoutRules.can_carry(lo, k)
			if not bool(r.get("ok", false)):
				break
			match String(r.get("action", "")):
				"count":
					var it := lo.first_of_kind(k)
					it.count = int(it.count) + 1
					if String(r.point) != "" and not (it.points as Array).has(String(r.point)):
						(it.points as Array).append(String(r.point))
				"stow":
					var pts: Array = r.get("points", [])
					if pts.is_empty():
						pts = [String(r.point)]
					var count := mini(2 * n, 2) if k == "spear_pair" else 1
					lo.add_item(k, pts, count, Loadout._state_for(k, {"loaded": false}))
					if k == "bow" and not lo.has_kind("quiver"):
						lo.add_item("quiver", ["quiver"], 1, {"arrows": int(held.get("arrows", 0))})
				_:
					break
	return lo


## The loadout item id a pool kind is carried as ("" none).
func item_of(kind: String) -> String:
	var k := String(KIND_MAP.get(ToolPool.resolve(kind), ""))
	if k == "" or loadout == null:
		return ""
	var it := loadout.first_of_kind(k)
	return String(it.get("id", ""))


func _build(held: Dictionary) -> void:
	if _slots.is_empty():
		var look: Dictionary = sc.body_look if not sc.body_look.is_empty() else sc.look
		var st := String(sc.body_look.get("stage", "")) if not sc.body_look.is_empty() else ""
		if st != "" and st != "adult":
			look = ChildLook.dress_look(ChildLook.young(sc.body_look, st), float(sc.look.get("sex", 0.0)), st)
		_slots = outfit_slots(AppearanceStore.validate(look))
	loadout = loadout_for(held, _slots)
	for id: String in _hand:
		if is_instance_valid(_hand[id]):
			(_hand[id] as Node).queue_free()
	_hand.clear()
	var bm: CharacterBodyMesh = body.get("_body") as CharacterBodyMesh
	if loadout.items.is_empty() and not loadout.gear.has("horn_strap"):
		if rig != null and is_instance_valid(rig):
			rig.queue_free()
		rig = null
	elif rig == null or not is_instance_valid(rig):
		rig = SlingRig.new()
		rig.name = "SlingRig"
		body.add_child(rig)
		rig.setup(body.sk, bm, loadout, {})
	else:
		rig.set_loadout(loadout)
	if rig != null:
		for it: Dictionary in loadout.items:
			var id := String(it.id)
			var m := _weapon_model(String(it.kind))
			if m == null:
				continue
			var es := rig.entries_of(id)
			var side := String((es[0] as SlingRig.Entry).hold) if not es.is_empty() else "r"
			_hand_socket(side).add_child(m)
			m.transform = SlingRig.HAND_OFFSET
			m.visible = false
			_hand[id] = m
			rig.set_hand_model(id, m)
	_knife_sheath(KNIVES.any(func(k: String) -> bool: return int(held.get(k, 0)) > 0))


static func _weapon_model(kind: String) -> Node3D:
	match kind:
		"musket", "bow", "pistol", "over_under":
			if kind == "over_under" and not WeaponModels.has_glb("over_under"):
				return WeaponModels.build("musket")
			return WeaponModels.build(kind)
		"spear_pair":
			return ThrowableModels.build("spear")
		"tomahawk":
			return ThrowableModels.build("tomahawk")
	return null


func _hand_socket(side: String) -> BoneAttachment3D:
	var bone := String(SlingRig.PROPS.get(side, SlingRig.PROPS.r))
	if _sockets.has(bone) and is_instance_valid(_sockets[bone]):
		return _sockets[bone]
	var att := BoneAttachment3D.new()
	att.name = "GearHand_" + side
	att.bone_name = bone
	body.sk.add_child(att)
	_sockets[bone] = att
	return att


## The sheathed knife on her left hip (pelvis), along carry_gear.json's L_hip.knife line: a leather sheath and the handle
## out of it, the handle up.
func _knife_sheath(on: bool) -> void:
	if not on:
		if _sheath != null and is_instance_valid(_sheath):
			_sheath.queue_free()
		_sheath = null
		return
	if _sheath != null and is_instance_valid(_sheath):
		return
	var pel := body.sk.find_bone("pelvis")
	if pel < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "GearKnife"
	att.bone_name = "pelvis"
	body.sk.add_child(att)
	var down := (KNIFE_TO - KNIFE_FROM).normalized()
	var out := Vector3(KNIFE_FROM.x, 0.0, KNIFE_FROM.z).normalized()
	var y := -down
	var x := y.cross(out).normalized()
	var z := x.cross(y).normalized()
	var top := KNIFE_FROM + down * 0.06 + out * 0.03       # (on the belt's outside, a little under its top edge)
	var bind := Transform3D(Basis(x, y, z), top)
	att.add_child(_sheath_model())
	var holder := att.get_child(0) as Node3D
	holder.transform = body.sk.get_bone_global_rest(pel).affine_inverse() * bind
	_sheath = att


static func _sheath_model() -> Node3D:
	var root := Node3D.new()
	root.name = "KnifeSheath"
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.33, 0.21, 0.12)
	leather.roughness = 0.85
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.17)
	wood.roughness = 0.7
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.58, 0.3)
	brass.metallic = 0.6
	brass.roughness = 0.4
	for spec: Array in [[Vector3(0.045, 0.2, 0.014), Vector3(0, -0.1, 0), leather], [Vector3(0.022, 0.1, 0.018), Vector3(0, 0.055, 0), wood],
			[Vector3(0.03, 0.012, 0.02), Vector3(0, 0.004, 0), brass]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[0]
		mi.mesh = bm
		mi.position = spec[1]
		mi.material_override = spec[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


# ---------------------------------------------------------------- in the hand
## Puts pool kind `kind` in her hand (`on`) or back where it rides. A weapon or tomahawk comes off its sling or hook (the
## rig's own item, the weapon's own model at the player's grip); a knife or a tool with no place on the body is shown in the
## hand (the knife's sheath stays on the belt). Returns the model in the hand (null none).
func hold(kind: String, on: bool) -> Node3D:
	kind = ToolPool.resolve(kind)
	var id := item_of(kind)
	if not on:
		if id != "" and rig != null:
			rig.snap_stowed(id)
		if _tool_model != null and is_instance_valid(_tool_model):
			_tool_model.queue_free()
		_tool_model = null
		_tool_kind = ""
		if in_hand == kind:
			in_hand = ""
		return null
	if in_hand != "" and in_hand != kind:
		hold(in_hand, false)
	in_hand = kind
	if id != "" and rig != null:
		rig.snap_held(id)
		return _hand.get(id) as Node3D
	if _tool_kind != kind:
		if _tool_model != null and is_instance_valid(_tool_model):
			_tool_model.queue_free()
		_tool_model = tool_model(kind)
		_tool_kind = kind
		if _tool_model != null:
			_hand_socket("r").add_child(_tool_model)
	return _tool_model


## The hand model of a tool at the one-hand grip (the prop bone's +Y from the fist along the haft, the carry grip at the
## fist: GatherTools.blade_offset; the gathering tools' own grip, else tools.json's).
static func tool_model(kind: String) -> Node3D:
	var row := ToolPool.kind_row(kind)
	var m: Array = row.get("model", [])
	if m.size() < 2:
		return null
	var n := ToolCarry.build(kind)
	if n == null:
		return null
	var g := float(row.get("grip", 0.0))
	if String(m[0]) == "gather":
		g = float(GatherData.get_default().tool(String(m[1])).get("carry_grip_m", g))
	n.transform = Transform3D(Basis(), Vector3(0.0, -g, 0.0))
	return n


## The model in her hand for `kind` now (the weapon's, with its Muzzle), or null.
func hand_model(kind: String) -> Node3D:
	var id := item_of(kind)
	if id != "":
		return _hand.get(id) as Node3D
	return _tool_model if _tool_kind == ToolPool.resolve(kind) else null


## Whether she wears `kind` on her body now.
func wears(kind: String) -> bool:
	var id := item_of(kind)
	return id != "" and rig != null and not rig.entries_of(id).is_empty()
