class_name SlingRig
extends Node3D
## Everything the player carries but does not hold, visible on the body where a 1750s carrier would
## have it (loadout_design.md, data/loadout/carry_gear.json), and the draw / put-away handoffs between
## the body and the hand.
##
##   var rig := SlingRig.install(player, Loadout.from_preset("musket_bow"))    # on a FrontierPlayer
##   var rig := SlingRig.new(); parent.add_child(rig); rig.setup(skeleton, body, loadout)   # preview/tests
##
## Stowed copies. Each carried item gets a copy on a BoneAttachment3D socket of its carrying bone
## (pelvis for belt items, spineb for the back, spinec for the horn, spined for the chest sling) at
## the design's stowed transform (carry_gear.json points.<point>.<kind>.stow.local), moved out along
## its outward normal by the outfit bulk (body_fit.json outfit_bulk) and, on the back, lifted so it
## rests on the items under it (back layering: _apply_layering / _layer_rest; the stacking order is
## chosen per loadout and re-solved when an item leaves the body for the hand or comes back). Each frame, after the
## skeleton update (with the helper bones driven), hanging items (two_anchor: belt pistols,
## tomahawks, atlatl; and the horn) follow the skin under them and yield to the limbs and the head;
## slung items yield a few degrees to a drawing arm. Counts: a spear pair shows its spears, the dart
## bundle its darts, the quiver its arrows, the belt its tomahawks, minus what is in the hand.
##
## Handoffs (loadout_design.md 5.1). begin_draw(item_id) / begin_holster(item_id) / sling_all() /
## unsling(). A draw is the draw set's grab clip then its equip clip: the copy stays on the body until
## the attach key, then moves to the hand prop socket keeping its world transform (no jump) and blends
## to the weapon's hand offset over the settle phase of the equip clip; at the settle end the copy
## hides and the weapon model shows at the identical pose. A holster is the mirror: the copy takes the
## model's place in the hand and blends to the live stowed pose over the end of the reversed equip
## clip; at the junction it parks on the body. Phases are clip phases: drive(item_id, role, phase)
## from the animation (preview, later PlayerAnim markers), or the rig's own timer (fallback) at the
## graph's quick rate. The musket off long_A follows the design's explicit world-space path (5.3).
##
## On a FrontierPlayer (install) the rig reads player.weapons / weapon_key / weapon.active /
## is_switching() and the weapon models' visibility, and only toggles model visibility; player.gd is
## unchanged. See source/graph_analysis/loadout/sling_runtime.md for the hooks the
## later integration needs.
##
## Provenance: stowed transforms, clip names and phases come from the Actor_B rig and clips.

signal handoff_event(item_id: String, event: StringName)
## The hands were freed for a climb / mount (true) or the weapon came back (false).
signal stowed_changed(stowed: bool)

enum Mode { STOWED, REACH, IN_HAND, HELD, HOLSTER }

const HAND_OFFSET := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
const PROPS := {"r": "r_hand_prop_attachment", "l": "l_hand_prop_attachment"}
## Limb capsules [from bone, to bone] (tools/loadout/measure_body_fit.gd LIMBS); radii from body_fit.json.
const LIMBS := {
	"r_upper_arm": ["r_shoulder", "r_elbow"], "r_forearm": ["r_elbow", "r_wrist"], "r_hand": ["r_wrist", "r_middlea"],
	"l_upper_arm": ["l_shoulder", "l_elbow"], "l_forearm": ["l_elbow", "l_wrist"], "l_hand": ["l_wrist", "l_middlea"],
	"r_thigh": ["r_upper_leg", "r_knee"], "r_shin": ["r_knee", "r_ankle"], "l_thigh": ["l_upper_leg", "l_knee"],
	"l_shin": ["l_knee", "l_ankle"], "head": ["neck", "headb"],
}
const LIMB_TRIM := {"r_thigh": 0.25, "l_thigh": 0.25}
const ARM_LIMBS := {"r": ["r_forearm", "r_hand"], "l": ["l_forearm", "l_hand"]}
const TIE_POINTS := {
	"spear_pair": {"upper": Vector3(0.018, 0.0, -0.35), "lower": Vector3(0.018, 0.0, 0.55)},
	"dart_bundle": {"upper": Vector3(0.0, 0.0, 1.155), "lower": Vector3(0.0, 0.0, 0.495)},
}


## One stowed placement (an item at one point; a tomahawk pair has two).
class Entry:
	extends RefCounted
	var item_id := ""
	var kind := ""
	var point := ""
	var key := ""
	var spec := {}
	var bone := ""
	var bone_i := -1
	var bind_bone := Transform3D()
	var bind := Transform3D()       ## model in skeleton space at the bind pose
	var adjust := Transform3D()     ## bulk + layering, applied in bind space
	var lay := Transform3D()        ## layering target (bind space)
	var lay_cur := Transform3D()    ## layering in use (blended toward lay)
	var attach := "rigid"
	var hook := Vector3.ZERO         ## pivot (bind): hook, first capsule origin
	var anchor_v := -1              ## second anchor (70 % down the item), carried by the skin
	var anchor_p := Vector3.ZERO
	var anchor_va := -1             ## first anchor (8 % down: at the hook), carried by the skin
	var anchor_pa := Vector3.ZERO
	var upper := Vector3.ZERO        ## upper contact (bind) of slung items
	var normal := Vector3.BACK       ## outward normal (bind)
	var region := ""
	var yield_deg := 0.0
	var arm_yield_deg := 0.0
	var yield_q := Quaternion.IDENTITY
	var yield_sig := PackedVector3Array()   ## solve inputs (carry frame) at the last yield solve
	var arm_q := Quaternion.IDENTITY
	var state_q := Quaternion.IDENTITY
	var state_t := Vector3.ZERO
	var caps: Array = []             ## [[a, b, r]] bind
	var socket: Node3D
	var holder: Node3D
	var root: Node3D
	var units: Array = []
	var shown := 1
	var mode := Mode.STOWED
	var hand := "r"                   ## the hand that draws (takes it off the body)
	var hold := "r"                   ## the hand that holds it drawn (the weapon's prop socket)
	var ds := {}
	var flyer: Node3D
	var flyer_socket: Node3D
	var offset0 := Transform3D()
	var hold_off := Transform3D()
	var contact_l := Vector3.ZERO     ## long-gun path: contact point in the left prop frame
	var contact_m := Vector3.ZERO     ## long-gun path: contact point in the model frame
	var path := ""
	var role := ""
	var phase := 0.0
	var t := 0.0
	var time_scale := 2.0
	var driven := false
	var skip_grab := false
	var attach_phase := -1.0          ## draw phase of a hand-timed attach (timer draws without a grab clip)
	var reach_min := INF              ## closest the drawing hand came to the item in this draw (m)
	var reach_t := 0.0                ## real seconds of this draw before the attach
	var reach_start := INF            ## the drawing hand's distance to the item when the draw began (m)
	var park_t := -1.0                ## timer put-away: seconds since the item left the hand for the body (-1: in the hand)
	var hol_min := INF                ## timer put-away: closest the hand came to the stowed place (m)
	var hol_start := INF              ## timer put-away: the hand's distance to it when the put-away began
	var park_from := Transform3D()    ## timer put-away: where the item was when it left the hand (skeleton space)
	var park_phase := 0.8             ## timer put-away: the phase it leaves the hand at if the hand never reaches the body
	var stance := "stand"
	var pend := 0.0
	var world := Transform3D()        ## stowed pose this frame (skeleton space)
	var visual := Transform3D()       ## where the item is shown this frame (skeleton space)
	var last_unit := Transform3D()    ## the moving unit's place in the stowed copy (a spear of the pair)
	var ik_w := 0.0
	var settle_min := 0.0             ## least settle length (equip phase) for the turn in the hand (review fix)
	var blend_q := Quaternion.IDENTITY  ## last hand-relative turn of the moving copy (coherent blend)
	var blend_q_ok := false
	var hidden_by_state := false
	var patch := false                ## the local body surface covers this hanging item (yield surface check)
	var yield_axis := Vector3.ZERO    ## last yield solution (search starts there next frame)
	var yield_ang := 0.0
	var yield_target := Quaternion.IDENTITY
	var slot := 0                     ## index for spreading yield solves over frames
	var surf_cache := 0.0             ## last body-surface clearance of the hanging pose


var data: LoadoutData
var loadout: Loadout
var skeleton: Skeleton3D
var body: CharacterBodyMesh
var surface: SlingBodySurface
var player: FrontierPlayer
var entries: Array = []
## The powder horn hangs on its strap over the left shoulder (false: tied on the belt, sling_runtime.json horn.place).
var horn_strapped := true
var straps: Array = []
## item id -> the in-hand weapon model (the player's weapon.model, or the preview's)
var hand_models := {}
## Timer rate (the graph's quick flag doubles the clip rate).
var rate := 2.0
var stance := "stand"
var yield_enabled := true
var smooth := true
var legacy_body := false
var reach_ik: ReachIK
var bulk := {"back": 0.0, "chest": 0.0, "waist_belt": 0.0}
var state := "stand"
var last_slung := ""
var _stowed_for := ""
## Diagnostics of the last update (tests): {item_id: {...}}
var debug := {}

var _bi := {}
var _bind: Array = []
var _limb_r := {}
var _garr: Array = []
var _gcache := {}
var _dt := 0.0
var _sockets := {}
var _hand_sockets := {}
var _anchor_cache := {}
var _hidden_mats: Array = []
var _state_w := 0.0
var _last_ms := -1
var _rt := {}
var _ap: AnimationPlayer
var _rel_cache := {}


# --- construction -----------------------------------------------------------------------------

## Adds a rig to a FrontierPlayer without touching player.gd: the stowed copies go on its skeleton,
## the in-hand models are the player's weapon models (visibility toggled during handoffs), and the
## player's own weapon switches drive the handoffs (timer mode; see _sync_player()).
static func install(p: FrontierPlayer, lo: Loadout = null, opts := {}) -> SlingRig:
	var existing := p.get_node_or_null("SlingRig") as SlingRig
	if existing:
		existing.free()
	var rig := SlingRig.new()
	rig.name = "SlingRig"
	rig.player = p
	p.add_child(rig)
	var body: CharacterBodyMesh = null
	for c in p.skeleton.get_children():
		if c is CharacterBodyMesh:
			body = c
	var use := lo if lo else Loadout.from_preset(LoadoutData.get_default().default_preset())
	rig.setup(p.skeleton, body, use, opts)
	for key: String in p.weapons:
		var id := rig.item_for_key(key)
		var w: Weapon = p.weapons[key]
		if id != "" and w and w.model:
			rig.hand_models[id] = w.model
	# setup() snapped the held item into the hand before the hand models were known, so it showed its stand-in
	# copy (the flyer) there; the weapon's own model stands in the hand instead (user 2026-09-28: "two musket
	# bug": after any weapon was put down or taken, set_carried reinstalls the rig, and the musket in the hand
	# showed twice)
	for e: Entry in rig.entries:
		if e.mode == Mode.HELD and e.flyer and rig._hand_model(e.item_id):
			e.flyer.visible = false
	rig._sync_player(0.0, true)
	return rig


func setup(sk: Skeleton3D, b: CharacterBodyMesh, lo: Loadout, opts := {}) -> void:
	data = LoadoutData.get_default()
	_rt = data.runtime
	skeleton = sk
	body = b
	loadout = lo
	rate = float(_rt.get("handoff", {}).get("quick_rate", 2.0))
	for i in sk.get_bone_count():
		_bi[sk.get_bone_name(i)] = i
	var ap: AnimationPlayer = null
	var aps := sk.get_parent().find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		ap = aps[0]
	_ap = ap
	if ap and ap.has_animation("actor_b/null-add"):
		_bind = CharacterBodyMesh.bind_pose_globals(sk, ap.get_animation("actor_b/null-add"))
	else:
		_bind = []
		for i in sk.get_bone_count():
			_bind.append(sk.get_bone_global_rest(i))
	_limb_r = data.limb_radii()
	surface = SlingBodySurface.from_body(body) if body else null
	legacy_body = _has_legacy_horn()
	if opts.has("sling_styles"):
		sling_styles = (opts.sling_styles as Dictionary).duplicate()
	if opts.has("outfit"):
		loadout.outfit_bulk = String(opts.outfit)
	set_outfit_bulk(loadout.outfit_bulk, false)
	rebuild()
	if bool(opts.get("reach_ik", false)):
		enable_reach_ik(true)
	if bool(opts.get("auto", true)) and not sk.skeleton_updated.is_connected(_on_skeleton_updated):
		sk.skeleton_updated.connect(_on_skeleton_updated)


func _exit_tree() -> void:
	if skeleton and is_instance_valid(skeleton) and skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
		skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
	_restore_legacy_horn()
	_clear()


## Rebuilds every stowed copy and strap from `loadout` (after a camp / chest change).
func rebuild() -> void:
	_clear()
	for it: Dictionary in loadout.items:
		for p: String in it.points:
			_make_entry(it, p)
	if loadout.gear.has("horn_strap"):
		_make_horn()
	elif legacy_body:
		# Review fix: without a horn strap in the gear (bow_darts, woodland_hunter) the legacy body's baked
		# right-hip horn (the "grenade" the user asked to move) stayed on, under the first pistol in
		# bow_darts. It is hidden in every loadout; the reshaped horn comes only with the horn strap.
		_hide_legacy_horn()
	_make_local_surface()
	_make_back_surface()
	_apply_counts()
	var ih := loadout.in_hand
	if ih != "":
		snap_held(ih)
	_apply_layering()
	_make_straps()
	update_now()


func set_loadout(lo: Loadout) -> void:
	loadout = lo
	for k in hand_models.keys():
		if _hand_model(String(k)) == null:
			hand_models.erase(k)
	set_outfit_bulk(lo.outfit_bulk, false)
	rebuild()


func _clear() -> void:
	_rest_body.clear()
	_layer_sig = ""
	_layer_cache.clear()
	for e: Entry in entries:
		if is_instance_valid(e.holder):
			e.holder.queue_free()
		if e.flyer and is_instance_valid(e.flyer):
			e.flyer.queue_free()
	entries.clear()
	for s in straps:
		if is_instance_valid(s.node):
			(s.node as Node).queue_free()
	straps.clear()
	for k in _sockets:
		if is_instance_valid(_sockets[k]):
			(_sockets[k] as Node).queue_free()
	_sockets.clear()
	for k in _hand_sockets:
		if is_instance_valid(_hand_sockets[k]):
			(_hand_sockets[k] as Node).queue_free()
	_hand_sockets.clear()


func _socket(bone: String) -> Node3D:
	if _sockets.has(bone) and is_instance_valid(_sockets[bone]):
		return _sockets[bone]
	var att := BoneAttachment3D.new()
	att.name = "Sling_" + bone
	att.bone_name = bone
	skeleton.add_child(att)
	_sockets[bone] = att
	return att


func _hand_socket(side: String) -> Node3D:
	if _hand_sockets.has(side) and is_instance_valid(_hand_sockets[side]):
		return _hand_sockets[side]
	var att := BoneAttachment3D.new()
	att.name = "SlingHand_" + side
	att.bone_name = PROPS[side]
	skeleton.add_child(att)
	_hand_sockets[side] = att
	return att


## Sling style per item kind (data/loadout/sling_styles.json; absent kinds keep carry_gear.json's placement).
## Set before setup() / install(), or change it live with set_sling_style().
var sling_styles := {}
static var _styles_cache := {}


## The style data of data/loadout/sling_styles.json ({} when missing).
static func style_data() -> Dictionary:
	if _styles_cache.is_empty():
		var f := FileAccess.open("res://data/loadout/sling_styles.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_styles_cache = d
	return _styles_cache


## The style in use for an item kind: sling_styles[kind], else the data's default ("" = none).
func sling_style(kind: String) -> String:
	var kd: Dictionary = style_data().get("kinds", {}).get(kind, {})
	var st := String(sling_styles.get(kind, kd.get("default", "")))
	return st if kd.get("styles", {}).has(st) else String(kd.get("default", ""))


## Switches the sling style of an item kind and rebuilds the stowed copies.
func set_sling_style(kind: String, style: String) -> void:
	sling_styles[kind] = style
	rebuild()


## Bind-space move of a stowed item for its kind's sling style: a slide along its own axis toward the
## butt (models: -Z = muzzle).
func _style_xf(kind: String, bind: Transform3D, point_spec := {}) -> Transform3D:
	var st := sling_style(kind)
	if st == "":
		return Transform3D.IDENTITY
	var spec: Dictionary = style_data().get("kinds", {}).get(kind, {}).get("styles", {}).get(st, {})
	var xf := Transform3D.IDENTITY
	# tilt_deg: turn the gun in the plane of the back about the point where it crosses the left shoulder
	# (the draw reaches for it there), toward the horizontal (flatter = the muzzle lower).
	var tilt := deg_to_rad(float(spec.get("tilt_deg", 0.0)))
	if absf(tilt) > 1e-5:
		var to_muzzle := (bind.basis * Vector3(0, 0, -1)).normalized()
		var sh := bind.origin
		if String(spec.get("pivot", "shoulder")) == "butt":
			# the butt end of the item's capsule (the end farthest from the muzzle)
			var cs: Array = point_spec.get("capsules_bind", [])
			if not cs.is_empty():
				var a := _v3(cs[0].from)
				var b := _v3(cs[0].to)
				sh = a if (a - b).dot(to_muzzle) < 0.0 else b
		else:
			var bi := int(_bi.get("l_shoulder", -1))
			if bi >= 0 and bi < _bind.size():
				var sp: Vector3 = (_bind[bi] as Transform3D).origin
				sh = bind.origin + to_muzzle * (sp - bind.origin).dot(to_muzzle)
		var q := Quaternion(Vector3(0, 0, 1), tilt)
		if (q * to_muzzle).y > (q.inverse() * to_muzzle).y:
			q = q.inverse()
		xf = Transform3D(Basis(q), sh - Basis(q) * sh)
	var slide := float(spec.get("slide_m", 0.0))
	if absf(slide) > 1e-5:
		var toward_butt := (xf.basis * bind.basis * Vector3(0, 0, 1)).normalized()
		xf = Transform3D(Basis.IDENTITY, toward_butt * slide) * xf
	return xf


func _make_entry(it: Dictionary, p: String) -> void:
	var k := String(it.kind)
	if data.kind_class(k) in ["tool", "worn"]:
		return   # the gathering tools on the pack's tool loop are drawn by GatherTools; worn gear (the climbing claws) shows only in use
	var spec := data.point(p, k)
	if spec.is_empty() or not spec.has("stow"):
		push_warning("SlingRig: no stowed placement for %s at %s" % [k, p])
		return
	var e := Entry.new()
	e.item_id = String(it.id)
	e.kind = k
	e.point = p
	e.key = "%s.%s" % [p, k]
	e.spec = spec
	e.bone = data.stow_bone(p, k)
	e.bone_i = int(_bi.get(e.bone, -1))
	if e.bone_i < 0:
		push_warning("SlingRig: bone %s missing" % e.bone)
		return
	e.bind_bone = _bind[e.bone_i]
	e.bind = data.stow_bind(p, k)
	var style_xf := _style_xf(k, e.bind, spec)
	e.bind = style_xf * e.bind
	e.attach = String(spec.get("attach", "rigid"))
	e.yield_deg = float(spec.get("yield_deg", 0.0))
	if p in ["chest_R", "chest_L"] and e.yield_deg <= 0.0:
		# the design's crouch / aim nudge (loadout_design.md 2.4): the chest pistols turn off a rising
		# thigh on their hook. The design kept them rigid only because the survey's solver had no head
		# capsule (it swung the butt into the chin); this solver has the head.
		e.yield_deg = float(_rt.get("yield", {}).get("chest_nudge_deg", 25.0))
	for c: Dictionary in spec.get("capsules_bind", []):
		e.caps.append([style_xf * _v3(c.from), style_xf * _v3(c.to), float(c.radius)])
	e.hook = (e.caps[0][0] as Vector3) if not e.caps.is_empty() else e.bind.origin
	if e.attach == "two_anchor" and surface:
		for c: Dictionary in spec.get("capsules_bind", []):
			if c.get("anchors") is Array:
				var an: Array = c.anchors
				var a := _v3(c.from)
				var b := _v3(c.to)
				e.anchor_p = a.lerp(b, float(an[1]))
				e.anchor_v = surface.nearest(e.anchor_p)
				e.anchor_pa = a.lerp(b, float(an[0]))
				e.anchor_va = surface.nearest(e.anchor_pa)
				break
	e.region = String(_rt.get("bulk_region", {}).get(p, "waist_belt"))
	# belt items: outward from the torso axis at the hook; back items: out of the back
	if LoadoutData.layer_of(p) > 0:
		e.normal = Vector3.FORWARD
	else:
		e.normal = surface.radial_normal(e.hook) if surface else _fallback_normal(p)
	var uc: Dictionary = _rt.get("upper_contact", {})
	if uc.has(p):
		e.upper = _nearest_on_axis(e, _v3(uc[p]))
	var ay: Dictionary = _rt.get("arm_yield", {}).get("max_deg", {})
	e.arm_yield_deg = float(ay.get(e.key, ay.get(p, 0.0)))
	e.ds = data.draw_set_of(p, k)
	e.hand = "l" if String(e.ds.get("hand", "right")).begins_with("left") else "r"
	e.hold = e.hand
	if String(e.ds.get("id", "")) == "long_gun_left":
		# taken off the back by the left hand, carried by the right (the source long-gun draw)
		e.path = "long_gun_left"
		e.hold = "r"
	e.socket = _socket(e.bone)
	e.holder = Node3D.new()
	e.holder.name = "Stowed_%s_%s" % [e.item_id, p]
	e.socket.add_child(e.holder)
	var n_units := int(it.get("count", 1))
	if k == "quiver":
		n_units = int(it.get("state", {}).get("arrows", 24))
	e.root = SlingModels.stowed(k, n_units, p, loadout.gear)
	e.holder.add_child(e.root)
	for c in e.root.get_children():
		if String(c.name).begins_with("Unit"):
			e.units.append(c)
	e.time_scale = rate
	e.slot = entries.size()
	entries.append(e)


func _make_horn() -> void:
	var h: Dictionary = _rt.get("horn", {})
	# a placement of its own (sling_runtime.json horn.place: "hip", on the belt at the right hip, as the old body's
	# horn sat, under the right-hip pistol's grip; the user 2026-09-29: "we had it both on the right hip before"): the
	# delivered horn and its capsules are carried there rigidly from the reference's points (horn.plug/bend/spout)
	var at: Dictionary = h.get(String(h.get("place", "")), {})
	# (unless an item rides where it would lie: then on its strap, at the reference placement)
	for it: Dictionary in loadout.items:
		for pt in it.get("points", []):
			if String(pt) in (at.get("unless_points", []) as Array):
				at = {}
	var src: Dictionary = at if not at.is_empty() else h
	var spec := data.point("horn", "powder_horn")
	var bone := String(src.get("bone", "spinec"))
	if not _bi.has(bone):
		return
	var plug := _v3(src.get("plug", [0.016, 1.15, -0.175]))
	var bend := _v3(src.get("bend", [-0.079, 1.13, -0.157]))
	var spout := _v3(src.get("spout", [-0.15, 1.09, -0.092]))
	var move := Transform3D.IDENTITY
	if not at.is_empty():
		move = _horn_frame(plug, bend, spout) * _horn_frame(_v3(h.get("plug", [0.016, 1.15, -0.175])),
				_v3(h.get("bend", [-0.079, 1.13, -0.157])), _v3(h.get("spout", [-0.15, 1.09, -0.092]))).affine_inverse()
	horn_strapped = bool(src.get("strap", true))
	var z := (spout - plug).normalized()
	var chord := plug.distance_to(spout)
	var bowv := (bend - plug) - z * (bend - plug).dot(z)
	var bow := bowv.length()
	var y := bowv.normalized() if bow > 1e-4 else Vector3.UP
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	var e := Entry.new()
	e.root = SlingModels.powder_horn(chord, bow)
	if e.root.has_meta("sling_gear"):
		# the delivered horn: its MANIFEST reference placement (model -> bind on spinec)
		var ref: Dictionary = SlingModels.gear_entry("powder_horn").get("reference_bind_placement", {})
		var v: Variant = str_to_var(String(ref.get("bind", "")))
		if v is Transform3D:
			var t := move * (v as Transform3D)
			x = t.basis.x
			y = t.basis.y
			z = t.basis.z
			plug = t.origin
	e.item_id = "powder_horn"
	e.kind = "powder_horn"
	e.point = "horn"
	e.key = "horn.powder_horn"
	e.spec = spec
	e.bone = bone
	e.bone_i = int(_bi[bone])
	e.bind_bone = _bind[e.bone_i]
	e.bind = Transform3D(Basis(x, y, z), plug)
	e.attach = "rigid"
	e.yield_deg = float(h.get("yield_deg", 30.0))
	for c: Dictionary in spec.get("capsules_bind", []):
		e.caps.append([move * _v3(c.from), move * _v3(c.to), float(c.radius)])
	if e.caps.is_empty():
		e.caps = [[plug, bend, 0.032], [bend, spout, 0.018]]
	e.hook = plug
	e.region = String(src.get("region", "back"))
	e.normal = surface.radial_normal(plug) if surface else Vector3.BACK
	e.socket = _socket(bone)
	e.holder = Node3D.new()
	e.holder.name = "Stowed_powder_horn"
	e.socket.add_child(e.holder)
	e.holder.add_child(e.root)
	e.units = [e.root]
	entries.append(e)
	_hide_legacy_horn()


## The body surface around the hanging items: the outer vertices within LOCAL_R of their capsules at
## the bind pose, skinned only in frames where a yield has to be solved, so the yield never turns an item
## deeper into the body (the survey's rule, measure_body_fit.gd _yield_pass) without skinning the whole
## outfit every frame. Same signed distance as the tests (SlingBodySurface.sdist).
## Radius (m) around the hanging items the local surface covers; 0 = the whole outer surface (a swung
## item can reach surface that was far from it at the bind pose: the thigh in a knee-up climb).
const LOCAL_R := 0.0
## Keep every n-th vertex of the local surface (the median of 5 still has neighbours within ~2 cm).
const LOCAL_STRIDE := 2
var _local: SlingBodySurface
var _local_bones := PackedInt32Array()
var _local_ready := false
## Per-update counters (profiling): yield solves, candidates tested, surface queries, local skin time (us).
var perf := {"solves": 0, "candidates": 0, "sdist": 0, "skin_us": 0}
var _frame := 0
var _solves_left := 0


func _make_local_surface() -> void:
	_local = null
	if surface == null:
		return
	var idx := PackedInt32Array()
	var any := false
	for e: Entry in entries:
		e.patch = e.yield_deg > 0.0 and not e.caps.is_empty()
		any = any or e.patch
	if not any:
		return
	for i in range(0, surface.sv.size(), LOCAL_STRIDE):
		var v := surface.sv[i]
		if LOCAL_R <= 0.0:
			idx.append(i)
			continue
		for e: Entry in entries:
			if not e.patch:
				continue
			var hit := false
			for c: Array in e.caps:
				if v.distance_to(_closest_on_seg(v, c[0], c[1])) - float(c[2]) < LOCAL_R:
					hit = true
					break
			if hit:
				idx.append(i)
				break
	_local = surface.subset(idx)
	_local_bones = _local.used_bones()


func _ensure_local() -> void:
	if _local_ready or _local == null:
		return
	var t0 := Time.get_ticks_usec()
	var g: Array = []
	g.resize(skeleton.get_bone_count())
	for b in _local_bones:
		g[b] = _g(b)
	_local.skin_all(g)
	_local_ready = true
	perf.skin_us += Time.get_ticks_usec() - t0


## Surface clearance of capsules (5 points along each, as the tests measure it).
func _patch_clear(_e: Entry, caps: Array) -> float:
	_ensure_local()
	var w := INF
	for c: Array in caps:
		for k in [0.0, 0.25, 0.5, 0.75, 1.0]:
			w = minf(w, float(_local.sdist((c[0] as Vector3).lerp(c[1], k))[0]) - float(c[2]))
	perf.sdist += caps.size() * 5
	return w


func _has_legacy_horn() -> bool:
	if body == null:
		return false
	for mi in body.meshes:
		if is_instance_valid(mi) and String(mi.name) == "Gear" and mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m and m.resource_name == "horn":
					return true
	return false


## The horn's frame from its plug, the bend of its curve and its spout (z along the chord, y toward the bend), at the plug.
static func _horn_frame(plug: Vector3, bend: Vector3, spout: Vector3) -> Transform3D:
	var z := (spout - plug).normalized()
	var bowv := (bend - plug) - z * (bend - plug).dot(z)
	var y := bowv.normalized() if bowv.length() > 1e-4 else Vector3.UP
	var x := y.cross(z).normalized()
	return Transform3D(Basis(x, z.cross(x).normalized(), z), plug)


## The legacy body's baked right-hip horn is the "grenade on the belt"; the rig hides it (a runtime
## surface override, the asset is untouched) and draws the reshaped horn in its new place.
func _hide_legacy_horn() -> void:
	if body == null or not _hidden_mats.is_empty():
		return
	var names: Array = _rt.get("horn", {}).get("legacy_hide_materials", ["horn", "wood", "horn_tip"])
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(1, 1, 1, 0)
	clear.shadow_to_opacity = false
	for mi in body.meshes:
		if not is_instance_valid(mi) or String(mi.name) != "Gear" or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m and m.resource_name in names:
				_hidden_mats.append([mi, s, mi.get_surface_override_material(s)])
				mi.set_surface_override_material(s, clear)


func _restore_legacy_horn() -> void:
	for h: Array in _hidden_mats:
		if is_instance_valid(h[0]):
			(h[0] as MeshInstance3D).set_surface_override_material(int(h[1]), h[2])
	_hidden_mats.clear()


func legacy_horn_hidden() -> bool:
	return not _hidden_mats.is_empty()


# --- outfit bulk and layering -----------------------------------------------------------------

## Outfit bulk from a body_fit.json outfit key ("" = the legacy coat, no offset).
func set_outfit_bulk(outfit: String, relayer := true) -> void:
	var lim: Array = _rt.get("bulk_limit_m", [-0.012, 0.12])
	for region: String in ["back", "chest", "waist_belt"]:
		bulk[region] = clampf(data.bulk_offset(outfit, region), float(lim[0]), float(lim[1]))
	if relayer and not entries.is_empty():
		_apply_layering()


## Outfit bulk from the customizer's worn items {"outer": id, "accessories.wrap": id, "vest": id, ...}.
func set_outfit_from_appearance(slots: Dictionary) -> String:
	var m: Dictionary = _rt.get("outfit_bulk_map", {})
	var key := ""
	var wrap := String(slots.get("accessories.wrap", ""))
	var outer := String(slots.get("outer", ""))
	if bool(slots.get("bare", false)):
		# the bare body v4 (PlayerAppearance, no garments until the garments pass): on the skin
		key = "bare"
	elif wrap != "" and m.get("wrap", {}).has(wrap):
		key = m.wrap[wrap]
	elif outer != "":
		key = String(m.get("outer", {}).get(outer, "coat_or_frock"))
	elif String(slots.get("vest", "")) != "":
		key = String(m.get("vest", "waistcoat"))
	elif String(slots.get("shirt", "")) != "":
		key = String(m.get("shirt", "shirt_only"))
	loadout.outfit_bulk = key
	set_outfit_bulk(key)
	return key


## Bulk translation plus the back layering: each back item (quiver, long_B, long_A, inner to outer)
## tilts out about its top end (at most layer_max_deg) and then moves out along the back normal until,
## where it crosses an item under it, it clears that item by `layer_margin_m` at the bind pose. The
## design turns items about their upper contact (the shoulder); on the rig that swings the 0.9 m of
## musket above the shoulder forward over the head, so the runtime pivots at the top end instead
## (the part above the shoulder stays where it is, the sling bridges the few cm at the shoulder).
## Runtime revision of the design's
## rule (see sling_runtime.md): the design stacks standoff(under) + (1 cm - worst walking-clip gap) at
## every crossing, which piles up to 18 cm on the back in musket_bow; items rigid on the same bone
## (quiver, bow, long guns: spineb) keep their relative pose in every clip, so their static overlap is the
## whole story, and the motion of the hanging items under them (belt items, horn) is taken by those
## items' own yield, which avoids the back items' capsules as well as the limbs.
## `use_design_extras` switches back to the design's rule for comparison.
##
## Review fix (2026-09-24): of the body items the back items clear only the powder horn (it lies
## under them on the back; loadout_design.md 2.6), at the bind pose; the belt items on the pelvis
## (pistols, tomahawks, atlatl) yield under the back items instead (their yield avoids the back items'
## capsules). Clearing every body item in the 11 LAYER_POSES pushed the musket's butt 27 cm off the
## back in musket_bow (nothing within 24 cm of the body: a floating gun). `layer_body_kinds` = [] and
## `layer_body_poses` = true with every kind listed restore the earlier rule.
var layer_margin_m := 0.01
var layer_max_deg := 12.0
var use_design_extras := false
var layer_body_kinds: Array = ["powder_horn", "atlatl", "tomahawk"]
## Body kinds the back items clear in the LAYER_POSES as well as at the bind pose (the atlatl board hangs
## stiffly behind the belt where the lower ends of the long items pass).
var layer_body_pose_kinds: Array = ["atlatl"]
var layer_body_poses := false
## Bind-pose height (m) up to which the layering measures an item's lift: the back and a hand above the
## shoulders (the shoulders are at about 1.45 m).
const LAYER_TOP_Y := 1.75


func _apply_layering(snap := true) -> void:
	for e: Entry in entries:
		e.adjust = Transform3D.IDENTITY
	# Review fix: the stacking order of the back items is chosen per loadout (the design's order
	# quiver, long_B, long_A first; another order only when it lifts the items clearly less). With the
	# bow slung string outward over the quiver, a musket laid over both had to clear the bow's string and
	# tips (about 15 cm out from its handle) and stood 25 cm off the back; laid under them it rests on
	# the back and the quiver and bow lift over it. The quiver always stays under the bow (the bow
	# hangs on the quiver strap).
	# Review fix: only the items on the body take part (an item in the hand leaves the stack and the
	# items over it settle down; it rejoins when its put-away starts, so the stack lifts before it
	# arrives), re-solved when that set changes and blended over LAYER_BLEND_S (update_now).
	var sig := _layer_signature()
	if _layer_cache.has(sig):
		# solved before for this set of items on the body (each draw / put-away changes the set): 2-5 ms
		# saved on the frame of the change
		var c: Dictionary = _layer_cache[sig]
		layer_stack = (c.stack as Array).duplicate()
		for e: Entry in entries:
			if (c.lay as Dictionary).has(e) or not _on_body(e) or LoadoutData.layer_of(e.point) == 0:
				e.lay = c.lay.get(e, Transform3D.IDENTITY)
			if snap:
				e.lay_cur = e.lay
		_layer_sig = sig
		_compose_adjust()
		return
	var back: Array = []
	for e: Entry in entries:
		if LoadoutData.layer_of(e.point) > 0 and not e.caps.is_empty() and _on_body(e):
			back.append(e)
	back.sort_custom(func(a: Entry, b: Entry) -> bool: return LoadoutData.layer_of(a.point) < LoadoutData.layer_of(b.point))
	var best_order: Array = back
	var best_cost := INF
	var best_adj := {}
	var orders: Array = [back]
	if layer_order == "auto" and not use_design_extras:
		orders = _layer_orders(back)
	for oi in orders.size():
		var order: Array = orders[oi]
		var cost := 0.0
		var peak := 0.0
		var adj := {}
		for e: Entry in entries:
			e.adjust = Transform3D.IDENTITY
		for i in order.size():
			var r: Array = _layer_place(order[i], order.slice(0, i))
			(order[i] as Entry).adjust = r[0]
			adj[order[i]] = r[0]
			cost += float(r[1])
			peak = maxf(peak, float(r[2]) if r.size() > 2 else float(r[1]))
		# the order whose stack stands least far off the back (its outermost surface), then the least
		# average lift; the design's order wins unless another is 2 cm thinner
		var score := peak + 0.1 * cost
		if oi == 0 or score < best_cost - 0.02:
			best_cost = score
			best_order = order
			best_adj = adj
	layer_stack = []
	for e: Entry in best_order:
		layer_stack.append(e.point)
	for e: Entry in entries:
		if best_adj.has(e) or not _on_body(e) or LoadoutData.layer_of(e.point) == 0:
			e.lay = best_adj.get(e, Transform3D.IDENTITY)
		if snap:
			e.lay_cur = e.lay
	_layer_sig = sig
	_layer_cache[sig] = {"stack": layer_stack.duplicate(), "lay": best_adj}
	_compose_adjust()


## Largest distance (m) the back layering may move any point of an item off where the data places it
## (user playtest 2026-09-25: "none of the back gear is on the back, it floats above it": the stack
## lifted the bow 22 cm and the quiver 10 cm off the back to clear each other's full width). Items that
## cross may then overlap a little where they pass behind one another, which the eye does not notice;
## gear standing off the back is what it notices. 0 = no cap.
var layer_max_lift_m := 0.05


## The layering transform of an entry scaled toward identity so no point of its main capsule moves more
## than layer_max_lift_m.
func _cap_lift(e: Entry, lay: Transform3D) -> Transform3D:
	if layer_max_lift_m <= 0.0 or e.caps.is_empty():
		return lay
	var worst := 0.0
	for c: Array in e.caps:
		for pt: Vector3 in [c[0], c[1]]:
			worst = maxf(worst, (lay * pt - pt).length())
	if worst <= layer_max_lift_m:
		return lay
	var k := layer_max_lift_m / worst
	var q := Quaternion.IDENTITY.slerp(lay.basis.get_rotation_quaternion(), k)
	return Transform3D(Basis(q), lay.origin * k)


## e.adjust = outfit bulk x the (blended, capped) layering, and the holder at the bind pose.
func _compose_adjust() -> void:
	for e: Entry in entries:
		var b := float(bulk.get(e.region, 0.0))
		e.adjust = Transform3D(Basis(), e.normal * b) * _cap_lift(e, e.lay_cur)
		if is_instance_valid(e.holder):
			e.holder.transform = e.bind_bone.affine_inverse() * e.adjust * e.bind


## Whether an entry is on the body for the layering: something of it shows there (a spear of the pair
## while the other is in the hand), or it is on its way back.
func _on_body(e: Entry) -> bool:
	return e.shown > 0 or e.mode == Mode.HOLSTER


func _layer_signature() -> String:
	var sig := ""
	for e: Entry in entries:
		if LoadoutData.layer_of(e.point) > 0 and _on_body(e):
			sig += e.key + ";"
	return sig


## Per frame: re-solve the layering when the set of back items on the body changed, and blend toward it.
func _update_layering(dt: float) -> void:
	if _layer_signature() != _layer_sig:
		_apply_layering(dt <= 0.0)
		return
	if dt <= 0.0:
		return
	var k := 1.0 - exp(-dt / LAYER_BLEND_S)
	var moved := false
	for e: Entry in entries:
		if not e.lay_cur.is_equal_approx(e.lay):
			e.lay_cur = _blend_xf(e.lay_cur, e.lay, k) if k < 0.999 else e.lay
			if e.lay_cur.origin.distance_to(e.lay.origin) < 1e-4 and e.lay_cur.basis.is_equal_approx(e.lay.basis):
				e.lay_cur = e.lay
			moved = true
	if moved:
		_compose_adjust()


## Seconds over which the back stack settles when an item leaves or rejoins it.
const LAYER_BLEND_S := 0.12
var _layer_sig := ""
var _layer_cache := {}
## Capsules of the weapon in the hand this frame (the hanging items' yield avoids them).
var _held_caps := {}


## "auto": the back stacking order is chosen per loadout (see _apply_layering); "design": always quiver,
## long_B, long_A from the body out.
var layer_order := "auto"
## The stacking order in use, inner to outer (points), for the readout and the tests.
var layer_stack: Array = []


## Stacking orders to try, the design's first: every permutation of the back items that keeps the quiver
## under the bow.
func _layer_orders(back: Array) -> Array:
	var out: Array = [back]
	var perms: Array = [[]]
	for e: Entry in back:
		var nxt: Array = []
		for p: Array in perms:
			for i in p.size() + 1:
				var q := p.duplicate()
				q.insert(i, e)
				nxt.append(q)
		perms = nxt
	for p: Array in perms:
		if p == back:
			continue
		var qi := -1
		var bi := -1
		for i in p.size():
			if (p[i] as Entry).kind == "quiver":
				qi = i
			elif (p[i] as Entry).kind == "bow":
				bi = i
		if qi >= 0 and bi >= 0 and qi > bi:
			continue
		out.append(p)
	return out


## Places entry e over the entries `under` (already placed): the least-lift of a tilt about its top end,
## about its bottom end, or a plain shift. Returns [adjust, average lift (m)].
func _layer_place(e: Entry, under: Array) -> Array:
	if layer_mode == "rest":
		var r := _layer_rest(e, under)
		if not r.is_empty():
			return r
	var ax := _main_cap(e)
	var ax_a: Vector3 = ax[0]
	var ax_b: Vector3 = ax[1]
	var top := ax_a if ax_a.y > ax_b.y else ax_b
	var bottom := ax_b if ax_a.y > ax_b.y else ax_a
	# Review fix: the item rests on what is under it and tilts about the end farther from the crossing
	# (the least lift of the item overall): the top end for a crossing low on the item, the bottom end
	# for a crossing high on it, a plain shift for an item lying along the one under it (the bow on the
	# quiver). A turn about either end moves every point outward, never over the head. `layer_pivot` =
	# "top" keeps the earlier rule.
	var best: Array = _layer_solve(e, under, top, bottom - top, layer_max_deg)
	if layer_pivot != "top":
		# in order of preference; a later one must lift clearly less (0.5 cm)
		for alt: Array in [_layer_solve(e, under, top, bottom - top, 0.0), _layer_solve(e, under, bottom, top - bottom, layer_max_deg)]:
			if float(alt[1]) < float(best[1]) - 0.005:
				best = alt
	return best


## "auto": the layering tilts each back item about whichever end lifts it least; "top": always the top end.
var layer_pivot := "auto"
## "rest" (default): each back item rests on what is under it (_layer_rest); "tilt": the end-tilt / shift
## candidates of _layer_solve.
var layer_mode := "rest"
## Above this bind height (the shoulders) the layering never moves an item toward the body (the head).
const LAYER_SHOULDER_Y := 1.45
const LAYER_BODY_MARGIN := 0.005
var _bind_surf: SlingBodySurface
var _rest_body := {}


## The outer body surface at the bind pose (for the layering's body constraint).
func _bind_surface() -> SlingBodySurface:
	if _bind_surf == null and surface != null:
		var idx := PackedInt32Array()
		for i in surface.sv.size():
			idx.append(i)
		_bind_surf = surface.subset(idx)
		_bind_surf.skin_all(_bind)
	return _bind_surf


## Review fix: a back item rests on what is under it. Its placement is a lift along the back normal
## that varies linearly along its main axis (a tilt of at most layer_max_deg plus a shift), chosen to
## minimise its average lift subject to: clearing every item under it by
## layer_margin_m (linearised at the closest points, re-solved 4 times), never nearer the body than the
## design placement (measured over the clips) and out of the bind-pose outer surface by 0.5 cm where the
## placement is in it. The solution is
## the line touching two supports: the musket on the horn and the shoulder, the bow on the quiver and
## the hip. Returns [adjust, average lift (m)], or [] when the item has no usable axis.
func _layer_rest(e: Entry, under: Array) -> Array:
	var ax := _main_cap(e)
	var top: Vector3 = ax[0] if (ax[0] as Vector3).y > (ax[1] as Vector3).y else ax[1]
	var bottom: Vector3 = ax[1] if (ax[0] as Vector3).y > (ax[1] as Vector3).y else ax[0]
	var L := top.distance_to(bottom)
	if L < 0.05:
		return []
	var u_ax := (bottom - top) / L
	var nl := (e.normal - u_ax * e.normal.dot(u_ax)).normalized()
	var rot_axis := u_ax.cross(nl).normalized()
	var S := L * sin(deg_to_rad(layer_max_deg))
	# samples of every capsule: [t along the main axis, bind point, radius]
	var samples: Array = []
	for c: Array in e.caps:
		for k in 5:
			var q := (c[0] as Vector3).lerp(c[1], k / 4.0)
			samples.append([(q - top).dot(u_ax) / L, q, float(c[2])])
	# objective: the average lift of the whole item (the part above the shoulders counts too: lifting it
	# far off the back reads as badly as a floating lower end)
	var wa := 0.0
	var wb := 0.0
	var n_obj := 0
	for sm: Array in samples:
		wa += 1.0 - float(sm[0])
		wb += float(sm[0])
		n_obj += 1
	# body constraints (static per entry)
	if not _rest_body.has(e):
		var bc: Array = []
		var bs := _bind_surface()
		for sm: Array in samples:
			var q: Vector3 = sm[1]
			var d := 9.99
			if bs != null and q.y <= LAYER_SHOULDER_Y:
				d = float(bs.sdist(q)[0])
			# never closer to the body than the design placement (it was measured over the clips; the
			# coat moves against spineb in motion), and out of the coat where the placement is in it
			if q.y > LAYER_SHOULDER_Y or d > 0.4:
				bc.append([float(sm[0]), 0.0])
			else:
				bc.append([float(sm[0]), maxf(0.0, LAYER_BODY_MARGIN - (d - float(sm[2])))])
		_rest_body[e] = bc
	var below: Array = under.duplicate()
	for u: Entry in entries:
		if LoadoutData.layer_of(u.point) == 0 and (use_design_extras or layer_body_kinds.has(u.kind)):
			below.append(u)
	var a := 0.0
	var b := 0.0
	for it in 4:
		var X := _rest_xf(top, nl, rot_axis, L, a, b)
		var Xi := X.affine_inverse()
		var cons: Array = (_rest_body[e] as Array).duplicate()
		for u: Entry in below:
			if u == e:
				continue
			var rels: Array = [Transform3D.IDENTITY]
			if e.bone_i != u.bone_i and (layer_body_poses or layer_body_pose_kinds.has(u.kind)) and _ap != null:
				rels.append_array(_rel_poses(e.bone_i, u.bone_i))
			for rel: Transform3D in rels:
				for ec: Array in e.caps:
					for uc: Array in u.caps:
						var r := _closest_seg_seg(X * (ec[0] as Vector3), X * (ec[1] as Vector3), rel * (u.adjust * (uc[0] as Vector3)), rel * (u.adjust * (uc[1] as Vector3)))
						var g := float(r[0]) - float(ec[2]) - float(uc[2])
						if g > layer_margin_m + 0.2:
							continue
						var pe: Vector3 = r[1]
						var pu: Vector3 = r[2]
						var dh := (pe - pu).normalized() if pe.distance_to(pu) > 1e-4 else nl
						var kk := maxf(dh.dot(nl), 0.3)
						var t := ((Xi * pe) - top).dot(u_ax) / L
						cons.append([t, a + (b - a) * t + (layer_margin_m - g) / kk])
		var sol := _lp2(cons, wa, wb, S)
		if sol.is_empty():
			break
		var done := absf(sol[0] - a) < 0.0005 and absf(sol[1] - b) < 0.0005
		a = sol[0]
		b = sol[1]
		if done:
			break
	var adj := _rest_xf(top, nl, rot_axis, L, a, b)
	var cost := 0.0
	var peak := 0.0
	for sm: Array in samples:
		var lift := a + (b - a) * float(sm[0])
		cost += absf(lift)
		peak = maxf(peak, lift + float(sm[2]))
	return [adj, cost / maxi(n_obj, 1), peak]


## The layering transform: the top end lifted by `a`, the bottom end by `b` along `nl` (bind space).
static func _rest_xf(top: Vector3, nl: Vector3, rot_axis: Vector3, L: float, a: float, b: float) -> Transform3D:
	var th := asin(clampf((b - a) / L, -1.0, 1.0))
	var R := Basis(rot_axis, th)
	return Transform3D(Basis(), nl * a) * Transform3D(R, top - R * top)


## Minimises wa*a + wb*b subject to a*(1-t) + b*t >= c for every [t, c] in `cons` and |b - a| <= S (a
## 2-variable linear programme: the best feasible intersection of two constraint lines). The
## constraints are binned in t (21 bins, the largest c kept). Returns [a, b] or [] when none is found.
static func _lp2(cons: Array, wa: float, wb: float, S: float) -> Array:
	if cons.is_empty():
		return [0.0, 0.0]
	var t0 := INF
	var t1 := -INF
	for c: Array in cons:
		t0 = minf(t0, float(c[0]))
		t1 = maxf(t1, float(c[0]))
	var bins := {}
	for c: Array in cons:
		var k := int(round((float(c[0]) - t0) / maxf(t1 - t0, 1e-4) * 20.0))
		if not bins.has(k) or float(c[1]) > float(bins[k][1]):
			bins[k] = c
	# rows [alpha, beta, c]: alpha*a + beta*b >= c
	var rows: Array = []
	for k in bins:
		var t := float(bins[k][0])
		rows.append([1.0 - t, t, float(bins[k][1])])
	rows.append([1.0, -1.0, -S])
	rows.append([-1.0, 1.0, -S])
	var best: Array = []
	var best_v := INF
	for i in rows.size():
		for j in range(i + 1, rows.size()):
			var ri: Array = rows[i]
			var rj: Array = rows[j]
			var det := float(ri[0]) * float(rj[1]) - float(rj[0]) * float(ri[1])
			if absf(det) < 1e-6:
				continue
			var a := (float(ri[2]) * float(rj[1]) - float(rj[2]) * float(ri[1])) / det
			var b := (float(ri[0]) * float(rj[2]) - float(rj[0]) * float(ri[2])) / det
			var ok := true
			for r: Array in rows:
				if float(r[0]) * a + float(r[1]) * b < float(r[2]) - 1e-5:
					ok = false
					break
			if ok:
				var v := wa * a + wb * b
				if v < best_v - 1e-7:
					best_v = v
					best = [a, b]
	return best


## One layering solution for entry e: tilt about `pivot` (toward the back normal, at most layer_max_deg),
## then shift, until it clears every item under it by layer_margin_m. Returns [adjust, average lift of the
## part of the item up to LAYER_TOP_Y (m)].
func _layer_solve(e: Entry, under: Array, pivot: Vector3, along: Vector3, max_deg: float) -> Array:
	var n := e.normal
	var axis := along.normalized().cross(n).normalized()
	if (Basis(axis, 0.1) * along).dot(n) < along.dot(n):
		axis = -axis
	var angle := 0.0
	var shift := 0.0
	var max_s := sin(deg_to_rad(max_deg))
	# fix the worst crossing first, re-measure, repeat (tilt up to the cap, the rest as a shift)
	for it in 8:
		var R := Transform3D(Basis(), n * shift) * Transform3D(Basis(axis, angle), pivot - Basis(axis, angle) * pivot)
		var worst_need := 0.0
		var worst_pe := Vector3.ZERO
		var below: Array = under.duplicate()
		for u: Entry in entries:
			if LoadoutData.layer_of(u.point) == 0 and (use_design_extras or layer_body_kinds.has(u.kind)):
				below.append(u)
		for u: Entry in below:
			if u == e:
				continue
			var need := 0.0
			var pe := Vector3.ZERO
			if use_design_extras:
				var extra := data.layering_extra(e.key, u.key)
				if extra <= 0.0:
					continue
				var r := _pair_gap(e, u, Transform3D.IDENTITY)
				pe = r[1]
				need = ((u.adjust * (r[2] as Vector3)) - (r[2] as Vector3)).dot(n) + extra
				need -= ((R * pe) - pe).dot(n)
			else:
				var r := _pair_gap_poses(e, u, R) if (LoadoutData.layer_of(u.point) > 0 or layer_body_poses or layer_body_pose_kinds.has(u.kind)) else _pair_gap(e, u, R)
				pe = R.affine_inverse() * (r[1] as Vector3)
				need = layer_margin_m - float(r[0])
			if need > worst_need:
				worst_need = need
				worst_pe = pe
		if worst_need <= 0.001:
			break
		var sv := worst_pe - pivot
		var lever := (sv - n * sv.dot(n)).length()
		var need2 := worst_need + 0.001
		if max_deg > 0.0 and sv.dot(along) > 0.02 and lever > 0.05 and sin(angle) < max_s - 1e-4:
			var want := clampf(sin(angle) + need2 / lever, 0.0, max_s)
			var got := (want - sin(angle)) * lever
			angle = asin(want)
			if got < need2 - 0.0005:
				shift += need2 - got
		else:
			shift += need2
	var rot := Transform3D(Basis(axis, angle), pivot - Basis(axis, angle) * pivot) if angle > 0.0 else Transform3D.IDENTITY
	var adj := Transform3D(Basis(), n * shift) * rot
	# the average lift of the part of the item on the back and just above the shoulder (bind y up to
	# LAYER_TOP_Y): what reads as floating is that part standing off the back. A tilt that keeps the
	# item on the shoulder and lifts only its lower end over a crossing beats a plain shift that lifts
	# the whole item by that need, and both beat a tilt that throws the top back.
	var ax := _main_cap(e)
	var disp := 0.0
	var n_on := 0
	for k in 21:
		var p := (ax[0] as Vector3).lerp(ax[1], k / 20.0)
		if p.y <= LAYER_TOP_Y or k == 0:
			disp += (adj * p).distance_to(p)
			n_on += 1
	return [adj, disp / n_on]


## Gap (m) at the bind pose between entry e (under the extra transform R, before its adjust) and entry u
## (with its adjust, then carried by `rel` into e's bind frame): [gap, point on e, point on u].
func _pair_gap(e: Entry, u: Entry, R: Transform3D, rel := Transform3D.IDENTITY) -> Array:
	var best := [INF, Vector3.ZERO, Vector3.ZERO]
	for ec: Array in e.caps:
		for uc: Array in u.caps:
			var r := _closest_seg_seg(R * (ec[0] as Vector3), R * (ec[1] as Vector3), rel * (u.adjust * (uc[0] as Vector3)), rel * (u.adjust * (uc[1] as Vector3)))
			var g := float(r[0]) - float(ec[2]) - float(uc[2])
			if g < float(best[0]):
				best = [g, r[1], r[2]]
	return best


## Poses the back layering checks for items carried by different bones (a back item on spineb over a
## belt item on the pelvis moves against it when the spine twists and bends): the bind pose and a few
## representative clips of ordinary play.
const LAYER_POSES := [["actor_b-p-stealth-idle", 0.0], ["actor_b-p-walk-fw", 0.3], ["actor_b-p-run-fw", 0.2],
		["actor_b-p-sprint-fw", 0.4], ["actor_b-p-crouch-idle", 0.0], ["actor_b-p-crouch-walk-fw", 1.0],
		["actor_b-p-rifle-idle-aim", 0.5], ["actor_b-p-pistol-aim-idle", 0.3], ["actor_b-p-bow-aim-idle", 0.3],
		["actor_b-p-bow-aim-walk-fw", 0.7], ["actor_b-p-1h-aim-throw-idle", 0.5]]


## The worst gap over LAYER_POSES (and the bind pose) when e and u ride different bones.
func _pair_gap_poses(e: Entry, u: Entry, R: Transform3D) -> Array:
	var best := _pair_gap(e, u, R)
	if e.bone_i == u.bone_i or _ap == null:
		return best
	for rel: Transform3D in _rel_poses(e.bone_i, u.bone_i):
		var r := _pair_gap(e, u, R, rel)
		if float(r[0]) < float(best[0]):
			# report the point on u in e's frame as the bind point (for the lever and the direction)
			best = r
	return best


## For each LAYER_POSES pose: bind(e bone) x G(e bone)^-1 x G(u bone) x bind(u bone)^-1, u's bind space
## carried into e's bind frame by that pose. Evaluated from the clips (the live skeleton is untouched).
func _rel_poses(be: int, bu: int) -> Array:
	var key := "%d_%d" % [be, bu]
	if _rel_cache.has(key):
		return _rel_cache[key]
	var out: Array = []
	for lp: Array in LAYER_POSES:
		var clip := "actor_b/" + String(lp[0])
		if not _ap.has_animation(clip):
			continue
		var anim := _ap.get_animation(clip)
		var cache := {}
		var ge := _clip_global(anim, float(lp[1]), be, cache)
		var gu := _clip_global(anim, float(lp[1]), bu, cache)
		out.append((_bind[be] as Transform3D) * ge.affine_inverse() * gu * (_bind[bu] as Transform3D).affine_inverse())
	_rel_cache[key] = out
	return out


func _clip_global(anim: Animation, t: float, b: int, cache: Dictionary) -> Transform3D:
	if cache.has(b):
		return cache[b]
	var rest := skeleton.get_bone_rest(b)
	var pos := rest.origin
	var rot := rest.basis.get_rotation_quaternion()
	var scl := rest.basis.get_scale()
	var path := "%s:%s" % [skeleton.name, skeleton.get_bone_name(b)]
	for kind in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
		var tr := _find_track(anim, b, kind)
		if tr < 0:
			continue
		match kind:
			Animation.TYPE_POSITION_3D:
				pos = anim.position_track_interpolate(tr, t)
			Animation.TYPE_ROTATION_3D:
				rot = anim.rotation_track_interpolate(tr, t).normalized()
			Animation.TYPE_SCALE_3D:
				scl = anim.scale_track_interpolate(tr, t)
	var local := Transform3D(Basis(rot).scaled(scl), pos)
	var p := skeleton.get_bone_parent(b)
	var g := local if p < 0 else _clip_global(anim, t, p, cache) * local
	cache[b] = g
	return g


var _track_idx := {}


func _find_track(anim: Animation, b: int, kind: int) -> int:
	var key := "%d|%d|%d" % [anim.get_instance_id(), b, kind]
	if _track_idx.has(key):
		return _track_idx[key]
	var found := -1
	var bn := skeleton.get_bone_name(b)
	for t in anim.get_track_count():
		if anim.track_get_type(t) == kind and str(anim.track_get_path(t).get_concatenated_subnames()) == bn:
			found = t
			break
	_track_idx[key] = found
	return found


func _main_cap(e: Entry) -> Array:
	var best: Array = e.caps[0]
	for c: Array in e.caps:
		if (c[0] as Vector3).distance_to(c[1]) > (best[0] as Vector3).distance_to(best[1]):
			best = c
	return best


## Turn (deg) and shift (m) the layering gave an entry, for the readout and the tests.
func layering_of(e: Entry) -> Vector2:
	var q := e.adjust.basis.get_rotation_quaternion()
	return Vector2(rad_to_deg(q.get_angle()), (e.adjust.origin - e.adjust.basis * Vector3.ZERO).length())


func _mid(e: Entry) -> Vector3:
	if e.caps.is_empty():
		return e.bind.origin
	var best: Array = e.caps[0]
	for c: Array in e.caps:
		if (c[0] as Vector3).distance_to(c[1]) > (best[0] as Vector3).distance_to(best[1]):
			best = c
	return ((best[0] as Vector3) + (best[1] as Vector3)) * 0.5


func _nearest_on_axis(e: Entry, p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for c: Array in e.caps:
		var q := _closest_on_seg(p, c[0], c[1])
		if q.distance_to(p) < bd:
			bd = q.distance_to(p)
			best = q
	return best


static func _fallback_normal(p: String) -> Vector3:
	match p:
		"R_hip": return Vector3.LEFT
		"L_hip": return Vector3.RIGHT
		"chest_R", "chest_L": return Vector3.BACK
	return Vector3.FORWARD


# --- counts and visibility ---------------------------------------------------------------------

## Carried count of an item (spears, darts, tomahawks; arrows for the quiver).
func set_count(item_id: String, n: int) -> void:
	var it := loadout.item(item_id)
	if it.is_empty():
		return
	if String(it.kind) == "quiver":
		(it.state as Dictionary)["arrows"] = n
	else:
		it.count = n
	_apply_counts()


## The unit in the hand counts toward the item's total: the body shows count - in hand, spread over the
## item's points in order (a second tomahawk at back_2 shows only while two are stowed).
func _apply_counts() -> void:
	var by_item := {}
	for e: Entry in entries:
		if not by_item.has(e.item_id):
			by_item[e.item_id] = []
		by_item[e.item_id].append(e)
	for id: String in by_item:
		var es: Array = by_item[id]
		var it := loadout.item(id)
		var in_hand := 0
		for e: Entry in es:
			if e.mode in [Mode.IN_HAND, Mode.HELD, Mode.HOLSTER]:
				in_hand = 1
		if (es[0] as Entry).kind == "quiver":
			var arrows := int(it.get("state", {}).get("arrows", 24)) if not it.is_empty() else 24
			SlingModels.set_quiver_arrows(es[0].root, arrows)
			(es[0] as Entry).shown = 1
			_show_units(es[0], 1)
			continue
		if (es[0] as Entry).kind == "powder_horn":
			_show_units(es[0], 1)
			continue
		var total := int(it.get("count", 1)) if not it.is_empty() else 1
		var left := maxi(total - in_hand, 0)
		for e: Entry in es:
			var cap := e.units.size() if e.kind in ["spear_pair", "dart_bundle"] else 1
			var n := mini(left, cap)
			e.shown = n
			left -= n
			_show_units(e, n)


## Display-only parts of the delivered gear (LoadoutModels.DISPLAY_NODES: a horn's full strap loop, a
## bundle's carrying thong, a musket's taut sling for racks and pickups); never shown on the body.
const DISPLAY_ONLY := ["StrapPreview", "ThongPreview", "SlingTaut"]


func _show_units(e: Entry, n: int) -> void:
	for i in e.units.size():
		(e.units[i] as Node3D).visible = i < n and not e.hidden_by_state
	# ties and hooks stay with the bundle while anything is in it
	for c in e.root.get_children():
		if String(c.name) in DISPLAY_ONLY:
			# Review fix: the horn's model is the entry's root, so its StrapPreview loop (display only) was
			# switched on here and hung from the horn into the right upper arm
			(c as Node3D).visible = false
		elif not String(c.name).begins_with("Unit"):
			(c as Node3D).visible = not e.hidden_by_state and (n > 0 or e.kind in ["spear_pair", "dart_bundle"])


# --- queries ----------------------------------------------------------------------------------

func entries_of(item_id: String) -> Array:
	var out: Array = []
	for e: Entry in entries:
		if e.item_id == item_id:
			out.append(e)
	return out


func entry_at(point: String) -> Entry:
	for e: Entry in entries:
		if e.point == point:
			return e
	return null


## Item id for a player.weapons key ("pistol" -> "pistol_1").
func item_for_key(key: String) -> String:
	var m: Dictionary = _rt.get("player_weapon_items", {})
	var id := String(m.get(key, key))
	if loadout.has_item(id):
		return id
	# a kind name: the first item of that kind
	for it: Dictionary in loadout.items:
		if String(it.kind) == key or String(it.kind) == id:
			return String(it.id)
	return ""


func mode_of(item_id: String) -> Mode:
	for e: Entry in entries_of(item_id):
		if e.mode != Mode.STOWED:
			return e.mode
	return Mode.STOWED


## The item currently in (or moving to / from) the hand, "" when hands are free.
func item_in_hand() -> String:
	for e: Entry in entries:
		if e.mode in [Mode.IN_HAND, Mode.HELD, Mode.HOLSTER, Mode.REACH]:
			return e.item_id
	return ""


func is_busy() -> bool:
	for e: Entry in entries:
		if e.mode in [Mode.REACH, Mode.IN_HAND, Mode.HOLSTER]:
			return true
	return false


# --- handoff API ------------------------------------------------------------------------------

## Starts drawing `item_id` from the body. opts: stance ("stand" / "crouch"), driven (true: phases come
## from drive()), skip_grab (the animation plays only the equip clip: attach at its start), duration
## (timer: seconds for the whole remaining sequence; default = clip lengths at `rate`). Returns the
## duration in seconds (0 when nothing can be drawn).
func begin_draw(item_id: String, opts := {}) -> float:
	var e := _entry_for_draw(item_id)
	if e == null:
		return 0.0
	e.mode = Mode.REACH
	e.stance = String(opts.get("stance", stance))
	e.driven = bool(opts.get("driven", false))
	e.skip_grab = bool(opts.get("skip_grab", false)) or _grab_s(e) <= 0.0
	e.attach_phase = -1.0
	e.reach_min = INF
	e.reach_t = 0.0
	e.reach_start = INF
	e.t = 0.0
	e.role = "draw" if e.skip_grab else "grab"
	e.phase = 0.0
	e.pend = 0.0
	var total := _equip_s(e) + (0.0 if e.skip_grab else _grab_s(e))
	var dur := float(opts.get("duration", -1.0))
	e.time_scale = total / dur if dur > 0.0 else rate
	var take := e.shown - 1
	e.last_unit = (e.units[take] as Node3D).transform if take >= 0 and take < e.units.size() else Transform3D.IDENTITY
	handoff_event.emit(item_id, &"reach")
	_apply_counts()
	return total / e.time_scale


## Starts putting `item_id` (in the hand) back on the body. opts as begin_draw. Returns the seconds of
## the reversed equip clip.
func begin_holster(item_id: String, opts := {}) -> float:
	var e := _entry_in_hand(item_id)
	if e == null:
		return 0.0
	var P := _prop(e.hand)
	e.hold_off = _hand_offset(item_id, e.hold)
	if e.mode == Mode.REACH:
		# never attached: nothing to put back
		e.mode = Mode.STOWED
		_apply_counts()
		return 0.0
	var start := _prop(e.hold) * e.hold_off
	if e.mode == Mode.IN_HAND and e.flyer:
		# cancelled mid-settle: continue from where the copy is
		start = e.visual
		e.hold_off = _prop(e.hold).affine_inverse() * start
	_ensure_flyer(e, e.hand)
	e.flyer.visible = true
	e.flyer.transform = P.affine_inverse() * start
	e.visual = start
	_hand_model_visible(item_id, false)
	e.mode = Mode.HOLSTER
	e.park_t = -1.0
	e.hol_min = INF
	e.hol_start = INF
	e.park_phase = float(opts.get("park_phase", PARK_PHASE_MAX))
	e.stance = String(opts.get("stance", stance))
	e.driven = bool(opts.get("driven", false))
	e.role = "holster"
	e.phase = 0.0
	e.t = 0.0
	var dur := float(opts.get("duration", -1.0))
	var total := _equip_s(e)
	e.time_scale = total / dur if dur > 0.0 else rate
	e.settle_min = _settle_need(e, _prop(e.hold).affine_inverse() * start, _prop(e.hold).affine_inverse() * e.world * e.last_unit)
	e.blend_q_ok = false
	last_slung = item_id
	handoff_event.emit(item_id, &"holster")
	return total / e.time_scale


## Hands free: puts whatever is in the hand on the body. Returns the seconds it takes.
func sling_all(opts := {}) -> float:
	var id := item_in_hand()
	if id == "":
		return 0.0
	return begin_holster(id, opts)


## Draws back the item put away last (after a climb, a mount...). Returns the seconds it takes.
func unsling(item_id := "", opts := {}) -> float:
	var id := item_id if item_id != "" else last_slung
	if id == "" or item_in_hand() != "":
		return 0.0
	return begin_draw(id, opts)


## Traversal and mounting (loadout_design.md 6.2; the traversal design's stow_for_traversal API): put
## the item in the hand on the body, by its put-away (clip or timer), or at once with `fast` (the first
## two-hand contact came before a put-away could play). Returns the seconds it takes. The player side
## (HandsFree, weapon input queued while traversing) is the LoadoutController's (sling_runtime.md).
func stow_for_traversal(fast := false, opts := {}) -> float:
	var id := item_in_hand()
	if id == "":
		return 0.0
	_stowed_for = id
	var d := 0.0
	if fast:
		snap_stowed(id)
		last_slung = id
	else:
		d = begin_holster(id, opts)
	stowed_changed.emit(true)
	return d


func is_stowed() -> bool:
	return _stowed_for != ""


## Draws back what stow_for_traversal() put away (on the first fire, aim, reload or weapon key after
## the hand-back: restore_on_input). Returns the seconds it takes.
func restore(opts := {}) -> float:
	if _stowed_for == "":
		return 0.0
	var id := _stowed_for
	_stowed_for = ""
	stowed_changed.emit(false)
	if item_in_hand() != "":
		return 0.0
	return begin_draw(id, opts)


## Clip-phase drive: role "grab" | "draw" | "holster" | "finish", phase 0..1 of that clip (for
## "holster", 0 = the start of the put-away, i.e. the end of the equip clip played backwards).
func drive(item_id: String, role: String, phase: float) -> void:
	for e: Entry in entries_of(item_id):
		if e.mode in [Mode.REACH, Mode.IN_HAND, Mode.HOLSTER]:
			e.driven = true
			e.role = role
			e.phase = clampf(phase, 0.0, 1.0)


## Instantly in the hand (model shown, copy gone from the body).
func snap_held(item_id: String) -> void:
	var e := _entry_for_draw(item_id)
	if e == null:
		return
	e.mode = Mode.HELD
	if _hand_model(item_id):
		if e.flyer:
			e.flyer.visible = false
		_hand_model_visible(item_id, true)
	else:
		_ensure_flyer(e, e.hold)
		e.flyer.transform = _hand_offset(item_id, e.hold)
		e.flyer.visible = true
	_apply_counts()


## Instantly back on the body.
func snap_stowed(item_id: String) -> void:
	for e: Entry in entries_of(item_id):
		if e.mode != Mode.STOWED:
			e.mode = Mode.STOWED
			if e.flyer:
				e.flyer.visible = false
	_hand_model_visible(item_id, false)
	_apply_counts()


func set_hand_model(item_id: String, model: Node3D) -> void:
	hand_models[item_id] = model
	var held := mode_of(item_id) == Mode.HELD
	if model:
		model.visible = held
	if held:
		# the model takes over from the stand-in copy shown while there was none
		for e: Entry in entries_of(item_id):
			if e.flyer and is_instance_valid(e.flyer):
				e.flyer.visible = false


# --- clip timing ------------------------------------------------------------------------------

func _grab_s(e: Entry) -> float:
	return float(e.ds.get("grab_s", 0.0)) if e.ds.has("grab") else 0.0


func _equip_s(e: Entry) -> float:
	if e.ds.has("equip_s"):
		return float(e.ds.equip_s)
	if e.ds.has("len_s"):
		var l: Variant = e.ds.len_s
		return float(l.get(e.stance, l.get("stand", 1.0))) if l is Dictionary else float(l)
	return 0.5


## Attach time (natural seconds) inside the grab clip, or inside the equip clip for grab-less sets.
func _attach_s(e: Entry) -> float:
	if e.ds.has("attach_s"):
		return float(e.ds.attach_s)
	if e.ds.has("take_s"):
		return float(e.ds.take_s)
	if e.ds.has("grab"):
		return _grab_s(e) * float(_rt.get("handoff", {}).get("default_attach_fraction_of_grab", 0.9))
	return 0.0


## Settle window of the equip clip (phase fractions) for the stance.
func _settle(e: Entry) -> Vector2:
	var ho: Dictionary = e.spec.get("handoff", {})
	var w: Array = _rt.get("handoff", {}).get("default_settle_phase", [0.0, 0.4])
	if ho.has("in_hand_settle_phase"):
		w = ho.in_hand_settle_phase
	if e.stance == "crouch" and ho.get("crouch", {}).has("settle_phase"):
		w = ho.crouch.settle_phase
	var s := Vector2(float(w[0]), float(w[1]))
	if not e.ds.has("grab") or e.skip_grab:
		var a := _attach_s(e) / maxf(_equip_s(e), 1e-4) if not e.skip_grab else 0.0
		if e.skip_grab and e.attach_phase >= 0.0:
			a = e.attach_phase    # a hand-timed attach: the settle starts where the hand took it
		s = Vector2(a, a + (1.0 - a) * (s.y - s.x))
	if e.settle_min > s.y - s.x:
		s.y = minf(1.0, s.x + e.settle_min)
	return s


## Review fix: the turn of the moving copy in the hand (from where it left the body to the hand offset)
## is spread over at least the settle length that keeps its average rate at SETTLE_MAX_DPS (real time),
## up to the end of the equip clip. With the data's default window (the first 40 % of the equip clip)
## the tomahawk turned about 160 deg in 0.1 s while the hand stood still (up to 42 deg a frame at 60
## frames/s). The design's own rate for the pistol (431 deg/s average, loadout_design.md 5.2) is kept.
const SETTLE_MAX_DPS := 450.0


func _settle_need(e: Entry, a: Transform3D, b: Transform3D) -> float:
	var th := rad_to_deg(a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()))
	var real := _equip_s(e) / maxf(e.time_scale, 0.01)
	return (th / SETTLE_MAX_DPS) / maxf(real, 0.01)


func _path_phases(e: Entry) -> Vector3:
	var ho: Dictionary = e.spec.get("handoff", {})
	var lift := float(ho.get("lift_phase", 0.13))
	var join := float(ho.get("join_phase", 0.33))
	var tail := float(ho.get("tail_phase", 0.15))
	return Vector3(lift, join, join + tail)


static func _ease(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# --- per-frame update -------------------------------------------------------------------------

## Full updates while nothing is being drawn or put away: every this many drawn frames (performance,
## 2026-09-25: 0.8-5.3 ms per update on the player). The stowed copies hang on bone sockets, so between
## full updates they ride their bones with the last yield and hang offsets; only those small offsets
## update less often. Handoffs update every frame.
const IDLE_UPDATE_EVERY := 2

var _last_pf := -1
var _skipped := 0
var _pending_dt := 0.0


func _on_skeleton_updated() -> void:
	# One update per drawn frame (the skeleton can update more than once per frame).
	var pf := Engine.get_process_frames()
	if pf == _last_pf:
		return
	_last_pf = pf
	# the game's frame time (the wall clock ran the handoffs at a third of the speed in fixed-step runs, and
	# would stretch them through a hitch)
	var dt := clampf(get_process_delta_time(), 0.0, 0.1) if is_inside_tree() else 0.0
	if _last_ms < 0:
		dt = 0.0
	_last_ms = 0
	_pending_dt += dt
	_skipped += 1
	if _skipped < IDLE_UPDATE_EVERY and not _handoff_active():
		return
	_skipped = 0
	update_now(minf(_pending_dt, 0.1))
	_pending_dt = 0.0


## True while an item is on its way between the body and a hand, or the player switches weapons or draws
## one (the draw's first frame: an idle-skipped update showed the drawn weapon's model in the hand for a
## frame, and its copy still on the body, before the rig began the reach; push n09).
func _handoff_active() -> bool:
	if player and is_instance_valid(player):
		if player.is_switching():
			return true
		var w: Weapon = player.weapon
		if w != null and w.active and w.is_equipping():
			return true
	for e: Entry in entries:
		if e.mode in [Mode.REACH, Mode.IN_HAND, Mode.HOLSTER]:
			return true
	return false


## One frame: player sync, handoff stepping, placement of every copy and strap. `g` = bone globals
## (tests pass body.skinning_globals() after posing by hand; empty = read the skeleton, which inside
## skeleton_updated includes the driven helper bones).
func update_now(dt := 0.0, g: Array = []) -> void:
	_dt = dt
	_garr = g
	_gcache.clear()
	_local_ready = false
	_back_ready = false
	_frame += 1
	_solves_left = int(_rt.get("yield", {}).get("searches_per_frame", 2))
	for k in perf:
		perf[k] = 0
	if player and is_instance_valid(player):
		_sync_player(dt)
	var target_w := 0.0 if state == "stand" else 1.0
	_state_w = move_toward(_state_w, target_w, dt / 0.2) if dt > 0.0 else target_w
	_update_layering(dt)
	# Review fix: the hanging items also give way to the weapon in the hand (the aimed musket's stock
	# went 2.4 cm into the right-chest pistol of two_braces)
	_held_caps = {}
	for e: Entry in entries:
		if e.mode == Mode.HELD and not e.caps.is_empty():
			_held_caps[e] = caps_at(e, _prop(e.hold) * _hand_offset(e.item_id, e.hold))
	var segs := _limb_segs()
	# back items first: the hanging body items yield away from them as well as from the limbs
	var obst: Array = []
	var backs: Array = []
	for e: Entry in entries:
		if LoadoutData.layer_of(e.point) > 0:
			backs.append(e)
			e.world = _stow_pose(e, segs, [])
			if e.mode in [Mode.STOWED, Mode.REACH] and e.shown > 0:
				obst.append_array(caps_at(e, e.world))
	# then the body items in order, each also keeping clear of the ones placed before it
	var placed: Array = obst.duplicate()
	var under: Array = []
	for e: Entry in entries:
		if LoadoutData.layer_of(e.point) == 0:
			e.world = _stow_pose(e, segs, placed)
			if e.mode in [Mode.STOWED, Mode.REACH] and e.shown > 0:
				placed.append_array(caps_at(e, e.world))
				under.append_array(caps_at(e, e.world))
	# last, the back hug, inner layers first: each back item pulled in over the coat, never deeper into the
	# body items as they were just placed, into the other back items (the inner ones as hugged, the outer
	# ones as they are yet: a tilted-in item swings its other end out) or into a limb (_hug_limit)
	if back_hug:
		backs.sort_custom(func(a: Entry, b: Entry) -> bool: return LoadoutData.layer_of(a.point) < LoadoutData.layer_of(b.point))
		for e: Entry in backs:
			if e.caps.is_empty():
				continue
			_hug_obst = under.duplicate()
			for u: Entry in backs:
				if u != e and u.mode in [Mode.STOWED, Mode.REACH] and u.shown > 0:
					_hug_obst.append_array(caps_at(u, u.world))
			e.world = _hug_limit(e, e.world, _back_hug(e, e.world, _carry(e)), segs)
		_hug_obst = []
	# dead: a handoff in progress stops where it is (the old weapon stays in the dead hand, plan 8.1)
	var sdt := 0.0 if player and is_instance_valid(player) and player.is_dead else dt
	for e: Entry in entries:
		_step(e, sdt)
	for e: Entry in entries:
		_place(e)
	_update_ik()
	_update_straps()
	_hide_held_elsewhere()
	_garr = []


## Items shown in the hand by something else (GatherTools.club: the gun clubbed, a copy of it held end for end): the
## rig keeps its own in-hand copies of them hidden, its hand model and a draw's stand-in (the flyer) alike, whatever
## its hand-offs do meanwhile. Item id -> true.
var _held_elsewhere := {}


## Keeps `item_id`'s in-hand copies hidden (`on`), or lets the rig show them again (the next frame's hand-offs decide).
func hold_elsewhere(item_id: String, on: bool) -> void:
	if on:
		_held_elsewhere[item_id] = true
	else:
		_held_elsewhere.erase(item_id)
	_hide_held_elsewhere()


func _hide_held_elsewhere() -> void:
	for id: String in _held_elsewhere:
		for e: Entry in entries_of(id):
			if e.flyer and is_instance_valid(e.flyer):
				e.flyer.visible = false
		var m := _hand_model(id)
		if m:
			m.visible = false


func _g(b: int) -> Transform3D:
	if not _garr.is_empty():
		return _garr[b]
	if not _gcache.has(b):
		_gcache[b] = skeleton.get_bone_global_pose(b)
	return _gcache[b]


func _prop(side: String) -> Transform3D:
	return _g(int(_bi[PROPS[side]]))


func _hand_offset(item_id: String, side: String) -> Transform3D:
	var m := _hand_model(item_id)
	if m:
		var par := m.get_parent()
		if par is BoneAttachment3D and String((par as BoneAttachment3D).bone_name) == PROPS[side]:
			return m.transform
	return HAND_OFFSET


func _hand_model_visible(item_id: String, v: bool) -> void:
	var m := _hand_model(item_id)
	if m:
		m.visible = v and not _held_elsewhere.has(item_id)


## The in-hand model of an item, or null (also when it has been freed).
func _hand_model(item_id: String) -> Node3D:
	var v: Variant = hand_models.get(item_id)
	if v == null or not is_instance_valid(v):
		return null
	return v as Node3D


func _limb_segs() -> Dictionary:
	var segs := {}
	for ln: String in LIMBS:
		var a := _g(int(_bi[LIMBS[ln][0]])).origin
		var b := _g(int(_bi[LIMBS[ln][1]])).origin
		segs[ln] = [a.lerp(b, float(LIMB_TRIM.get(ln, 0.0))), b]
	return segs


func _carry(e: Entry) -> Transform3D:
	return _g(e.bone_i) * e.bind_bone.affine_inverse()


## The stowed pose of an entry this frame (skeleton space): rigid carry of the adjusted bind pose,
## two-anchor direction from the skin, pendulum, state policy, yield to limbs, yield to a drawing arm.
func _stow_pose(e: Entry, segs: Dictionary, obst: Array = []) -> Transform3D:
	var C := _carry(e)
	var X := C * e.adjust * e.bind
	var hook := C * (e.adjust * e.hook)
	if e.attach == "two_anchor" and e.anchor_v >= 0 and surface:
		# the hook rides the belt (rigid on the pelvis); the item hangs along the coat under it: its
		# direction runs from the hook to the skin point at 70 % of its length (loadout_design.md 2.4)
		var b_now := surface.skin_point(e.anchor_v, e.adjust * e.anchor_p, Callable(self, "_g"))
		var d_r := (C.basis * (e.adjust.basis * (e.anchor_p - e.hook))).normalized()
		var d_s := (b_now - hook).normalized()
		X = _rot_about(X, hook, ReachIK._arc(d_r, d_s))
	if absf(e.pend) > 0.01:
		var nrm := (C.basis * e.normal).normalized()
		X = _rot_about(X, hook, Quaternion(nrm, deg_to_rad(e.pend)))
	X = _apply_state(e, X, C, hook)
	if yield_enabled and e.yield_deg > 0.0:
		var limbs: Array = _rt.get("yield", {}).get("limbs", [])
		if e.point in ["chest_R", "chest_L"]:
			limbs = _rt.get("yield", {}).get("chest_nudge_limbs", ["r_thigh", "l_thigh", "head"])
		var excl: Array = ARM_LIMBS[e.hand] if e.mode == Mode.REACH else []
		# every `every_frames` frames per item at run time (the smoothing bridges it); every call in tests
		var every := maxi(int(_rt.get("yield", {}).get("every_frames", 3)), 1)
		if _dt <= 0.0 or ((_frame + e.slot) % every == 0 and _solves_left > 0):
			if _dt <= 0.0 or _yield_inputs_moved(e, C, X, segs, limbs, obst):
				e.yield_target = _solve_yield(e, X, hook, segs, limbs, excl, e.yield_deg, true, obst)
		e.yield_q = _smooth_q(e.yield_q, e.yield_target)
		X = _rot_about(X, hook, e.yield_q)
	if yield_enabled and e.arm_yield_deg > 0.0:
		# slung items give way to the arm of a draw in progress (loadout_design.md 5.5), not to every swing
		var pivot := C * (e.adjust * e.upper)
		var target := Quaternion.IDENTITY
		var side := _drawing_side(e)
		if side != "" and _limb_clear(caps_at(e, X), segs, ARM_LIMBS[side], []) < float(_rt.get("arm_yield", {}).get("trigger_m", 0.1)):
			target = _solve_yield(e, X, pivot, segs, ARM_LIMBS[side], [], e.arm_yield_deg, true)
		e.arm_q = _smooth_q(e.arm_q, target)
		X = _rot_about(X, pivot, e.arm_q)
	return X


## Moves of the yield solve's inputs since the entry's last solve, in its carry frame, below which the
## last solve still holds (performance: a still pose re-solved the same answer every few frames).
const YIELD_RESOLVE_M := 0.004


## True when the item, the limbs it yields to, the obstacles or the held weapon moved by more than
## YIELD_RESOLVE_M relative to the item's carrying bone since the last solve (then the solve runs and
## the new inputs are kept).
func _yield_inputs_moved(e: Entry, C: Transform3D, X: Transform3D, segs: Dictionary, limbs: Array, obst: Array) -> bool:
	var inv := C.affine_inverse()
	var pts := PackedVector3Array()
	pts.append(inv * X.origin)
	pts.append(inv * (X.origin + X.basis.z * 0.3))
	pts.append(inv * (X.origin + X.basis.y * 0.3))
	for l in limbs:
		if segs.has(l):
			pts.append(inv * (segs[l][0] as Vector3))
			pts.append(inv * (segs[l][1] as Vector3))
	for c in obst:
		pts.append(inv * (c[0] as Vector3))
		pts.append(inv * (c[1] as Vector3))
	for h: Entry in _held_caps:
		if h.item_id != e.item_id:
			for c in _held_caps[h]:
				pts.append(inv * (c[0] as Vector3))
				pts.append(inv * (c[1] as Vector3))
	if e.yield_sig.size() == pts.size():
		var lim := YIELD_RESOLVE_M * YIELD_RESOLVE_M
		var moved := false
		for i in pts.size():
			if pts[i].distance_squared_to(e.yield_sig[i]) > lim:
				moved = true
				break
		if not moved:
			return false
	e.yield_sig = pts
	return true


## Back hug (user playtest 2026-09-25: "the arrow and quiver on crouch is not close to the body"): a back
## item rides spineb rigidly, so when the back curves (crouching; the crouch walk bends it almost flat) the
## coat under its lower part drifts away (11-17 cm off it crouched, 6-14 standing). Each update the item
## is pulled back to the gap it had over the coat at the bind pose it was fitted in: along the back
## normal by the least drift of its low / middle / high parts, then its end that drifted more tilted in
## about the other end. Only ever pulled in (to the fitted gap, never nearer), at most
## BACK_HUG_MAX_M. The coat is a thinned patch of the body surface around the back items (BACK_PATCH_R,
## every BACK_PATCH_STRIDE-th vertex), skinned once per update when a back item is on the body.
var back_hug := true
const BACK_HUG_MAX_M := 0.12
const BACK_PATCH_R := 0.18
const BACK_PATCH_STRIDE := 6
var _back_now: SlingBodySurface
var _back_bind: SlingBodySurface
var _back_bones := PackedInt32Array()
var _back_ready := false


func _make_back_surface() -> void:
	_back_now = null
	_back_bind = null
	if surface == null:
		return
	var idx := PackedInt32Array()
	for i in range(0, surface.sv.size(), BACK_PATCH_STRIDE):
		var v := surface.sv[i]
		for e: Entry in entries:
			if LoadoutData.layer_of(e.point) <= 0 or e.caps.is_empty():
				continue
			var c: Array = e.caps[0]
			if v.distance_to(_closest_on_seg(v, e.bind_bone * e.bind_bone.affine_inverse() * (c[0] as Vector3), c[1])) - float(c[2]) < BACK_PATCH_R:
				idx.append(i)
				break
	if idx.is_empty():
		return
	_back_now = surface.subset(idx)
	_back_bind = surface.subset(idx)
	_back_bones = _back_now.used_bones()
	_back_bind.skin_all(_bind)


func _ensure_back() -> bool:
	if _back_now == null:
		return false
	if not _back_ready:
		var t0 := Time.get_ticks_usec()
		var g: Array = []
		g.resize(skeleton.get_bone_count())
		for b in _back_bones:
			g[b] = _g(b)
		_back_now.skin_all(g)
		_back_ready = true
		perf.skin_us += Time.get_ticks_usec() - t0
	return true


func _back_hug(e: Entry, X: Transform3D, C: Transform3D) -> Transform3D:
	if not _ensure_back():
		return X
	var main: Array = e.caps[0]
	var a0: Vector3 = main[0]
	var b0: Vector3 = main[1]
	var r := float(main[2])
	var to_now := X * (e.adjust * e.bind).affine_inverse()   # bind space -> this frame
	var drift := PackedFloat64Array()
	var pts := PackedVector3Array()
	for t: float in [0.15, 0.5, 0.85]:
		var pb: Vector3 = e.adjust * a0.lerp(b0, t)
		var pn := to_now * pb
		pts.append(pn)
		var g_bind := float(_back_bind.sdist(pb)[0]) - r
		var g_now := float(_back_now.sdist(pn)[0]) - r
		# a part with no coat near it (above the shoulders) says nothing
		drift.append(g_now - g_bind if g_bind < 0.3 and g_now < 0.4 else INF)
	var m := INF
	for d in drift:
		m = minf(m, d)
	if m == INF:
		return X
	m = maxf(m, 0.0)
	var n := (C.basis * e.normal).normalized()
	var pull := minf(m, BACK_HUG_MAX_M)
	var out := Transform3D(X.basis, X.origin - n * pull)
	# the end that drifted more: tilt it in about the other end (never past the fitted gap)
	var d0 := drift[0] if drift[0] < INF else m
	var d2 := drift[2] if drift[2] < INF else m
	var far := 0 if d0 >= d2 else 2
	var near := 2 - far
	var extra := minf(maxf(d0, d2) - m, BACK_HUG_MAX_M - pull)
	if extra > 0.002:
		var piv := pts[near] - n * pull
		var arm := (pts[far] - n * pull) - piv
		var L := arm.length()
		if L > 0.05:
			var ax := n.cross(arm.normalized()).normalized()
			var q := Quaternion(ax, atan2(extra, L))
			if (q * arm - arm).dot(-n) < 0.0:
				q = q.inverse()
			out = _rot_about(out, piv, q)
	return out


## What the back hug of the item being placed keeps clear of (skeleton-space caps; set per back item by the update).
var _hug_obst: Array = []


## The back hug may not take an item deeper into any one of the items under it or any limb than its unhugged
## pose `X` has it (down to HUG_CLEAR_M when that one is clear: the body items swing and yield a little after
## this): the pull and tilt (`hugged`) are scaled back until it does not (the stow test: the spear pair into a
## climbing hand, the dart bundle into the atlatl). Each obstacle keeps its own floor.
const HUG_CLEAR_M := 0.015


func _hug_limit(e: Entry, X: Transform3D, hugged: Transform3D, segs: Dictionary) -> Transform3D:
	if hugged.is_equal_approx(X):
		return hugged
	var limbs: Array = _rt.get("yield", {}).get("limbs", [])
	var excl: Array = ARM_LIMBS[e.hand] if e.mode == Mode.REACH else []
	var floors := _hug_gaps(caps_at(e, X), segs, limbs, excl)
	for k in floors.size():
		floors[k] = minf(floors[k], HUG_CLEAR_M) - 0.001
	if _hug_ok(caps_at(e, hugged), segs, limbs, excl, floors):
		return hugged
	var lo := 0.0
	var hi := 1.0
	for i in 6:
		var mid := (lo + hi) * 0.5
		if _hug_ok(caps_at(e, X.interpolate_with(hugged, mid)), segs, limbs, excl, floors):
			lo = mid
		else:
			hi = mid
	return X.interpolate_with(hugged, lo)


## Gap from the item's caps to each obstacle of _hug_obst, then to each limb (in that order; INF for an
## excluded or missing limb).
func _hug_gaps(caps: Array, segs: Dictionary, limbs: Array, excl: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for o: Array in _hug_obst:
		var w := INF
		for c: Array in caps:
			w = minf(w, float(_closest_seg_seg(c[0], c[1], o[0], o[1])[0]) - float(c[2]) - float(o[2]))
		out.append(w)
	for ln: String in limbs:
		var w := INF
		if not excl.has(ln) and segs.has(ln):
			for c: Array in caps:
				w = minf(w, float(_closest_seg_seg(c[0], c[1], segs[ln][0], segs[ln][1])[0]) - float(c[2]) - float(_limb_r.get(ln, 0.05)))
		out.append(w)
	return out


func _hug_ok(caps: Array, segs: Dictionary, limbs: Array, excl: Array, floors: PackedFloat32Array) -> bool:
	var g := _hug_gaps(caps, segs, limbs, excl)
	for k in g.size():
		if g[k] < floors[k]:
			return false
	return true


## The hand side of a draw / put-away in progress of another item ("" when none).
func _drawing_side(e: Entry) -> String:
	for x: Entry in entries:
		if x != e and x.mode in [Mode.REACH, Mode.IN_HAND, Mode.HOLSTER]:
			return x.hand
	return ""


func _smooth_q(cur: Quaternion, target: Quaternion) -> Quaternion:
	if not smooth or _dt <= 0.0:
		return target
	var k := 1.0 - exp(-_dt / float(_rt.get("yield", {}).get("smooth_s", 0.08)))
	return cur.slerp(target, k)


static func _rot_about(X: Transform3D, p: Vector3, q: Quaternion) -> Transform3D:
	if q.is_equal_approx(Quaternion.IDENTITY):
		return X
	var R := Basis(q)
	return Transform3D(R * X.basis, p + R * (X.origin - p))


## Capsules of an entry for a pose X of its model (skeleton space): [[a, b, r]].
func caps_at(e: Entry, X: Transform3D) -> Array:
	var M := X * e.bind.affine_inverse()
	var out: Array = []
	for c: Array in e.caps:
		out.append([M * (c[0] as Vector3), M * (c[1] as Vector3), float(c[2])])
	return out


func _limb_clear(caps: Array, segs: Dictionary, limbs: Array, excl: Array, obst: Array = []) -> float:
	var w := INF
	for o: Array in obst:
		for c: Array in caps:
			w = minf(w, float(_closest_seg_seg(c[0], c[1], o[0], o[1])[0]) - float(c[2]) - float(o[2]))
	for ln: String in limbs:
		if excl.has(ln) or not segs.has(ln):
			continue
		for c: Array in caps:
			var d := float(_closest_seg_seg(c[0], c[1], segs[ln][0], segs[ln][1])[0]) - float(c[2]) - float(_limb_r.get(ln, 0.05))
			w = minf(w, d)
	return w


func _torso_dist(p: Vector3) -> float:
	var a := _g(int(_bi["pelvis"])).origin
	var b := _g(int(_bi["neck"])).origin
	return p.distance_to(_closest_on_seg(p, a, b))


## The smallest turn about `pivot` (5 deg steps, refined by half a step, 8 directions about the item's
## axis, up to max_deg) that clears the limbs (the survey's rule, measure_body_fit.gd _yield_pass); with
## `inward_check` never deeper into the body than it hangs (the local body surface, consulted only when
## a turn brings part of the item nearer the torso axis), and never deeper into the back items `obst`
## than it already is. The search starts from the item's previous solution (frame coherence).
func _solve_yield(e: Entry, X: Transform3D, pivot: Vector3, segs: Dictionary, limbs: Array, excl: Array,
		max_deg: float, inward_check: bool, obst: Array = []) -> Quaternion:
	var caps := caps_at(e, X)
	if caps.is_empty():
		return Quaternion.IDENTITY
	# the horn lies under the back items and gives way to them as to a limb; belt items only must not
	# be pushed deeper into them
	# (with the back items resting on the back, layer_max_lift_m, giving way to them too squeezed the horn
	# into the swinging right arm: it now gives way to the limbs and may pass under a back item instead)
	var obj_obst: Array = (obst if e.kind == "powder_horn" and layer_max_lift_m <= 0.0 else []).duplicate()
	for h: Entry in _held_caps:
		if h.item_id != e.item_id:
			obj_obst.append_array(_held_caps[h])
	var con_obst: Array = [] if e.kind == "powder_horn" else obst
	var ctx := {"segs": segs, "limbs": limbs, "excl": excl, "obj_obst": obj_obst, "con_obst": con_obst, "e": e}
	ctx["use_local"] = inward_check and e.patch and _local != null
	ctx["inward"] = inward_check
	var base := _limb_clear(caps, segs, limbs, excl, obj_obst)
	# belt items also give way to a back item that presses into them by more than 2 cm
	ctx["obst_obj"] = not con_obst.is_empty() and _limb_clear(caps, {}, [], [], con_obst) < -0.02
	if ctx.obst_obj:
		base = minf(base, _limb_clear(caps, {}, [], [], con_obst) + 0.02)
	# an item already pressed into the coat also gives way to it (a hanging item cannot be inside it);
	# the surface is consulted every 4th frame per item at run time
	ctx["surf_obj"] = false
	if ctx.use_local and not e.point in ["chest_R", "chest_L"]:
		if _dt <= 0.0 or (_frame + e.slot) % 4 == 0:
			e.surf_cache = _patch_clear(e, caps)
		if e.surf_cache < -0.01:
			ctx.surf_obj = true
			base = minf(base, e.surf_cache + 0.01)
	if base >= 0.0:
		e.yield_ang = 0.0
		return Quaternion.IDENTITY
	perf.solves += 1
	_solves_left -= 1
	ctx["r0"] = INF
	for c: Array in caps:
		ctx.r0 = minf(ctx.r0, minf(_torso_dist(c[0]), _torso_dist(c[1])))
	ctx["s0"] = INF
	ctx["o0"] = minf(_limb_clear(caps, {}, [], [], con_obst), 0.0) if not con_obst.is_empty() else INF
	var yc: Dictionary = _rt.get("yield", {})
	var step := maxf(float(yc.get("step_deg", 5.0)), 1.0)
	var dirs := int(yc.get("directions", 8))
	var u: Vector3 = ((caps[0][1] as Vector3) - (caps[0][0] as Vector3)).normalized()
	var p := u.cross(Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT).normalized()
	var q := u.cross(p)
	# frame coherence at run time: last solution, and half a step less, first (tests, dt = 0: the survey's
	# plain smallest-turn search)
	if _dt > 0.0 and e.yield_ang > 0.0 and e.yield_axis != Vector3.ZERO:
		for a: float in [maxf(e.yield_ang - step * 0.5, step * 0.5), e.yield_ang]:
			var r := _try_turn(ctx, caps, pivot, e.yield_axis, a)
			if r >= 0.0:
				e.yield_ang = a
				return Quaternion(e.yield_axis, deg_to_rad(a))
	# lazy validation (same pick as validating every candidate): rank the candidates of each angle by the
	# cheap limb objective, and ask the body surface / back items only for the best ones in turn
	var improving: Array = []   # [cl, axis, ang] that beat the hanging pose, over all angles so far
	var ang := step
	var pick: Array = []
	# run time: at most `validations_per_search` constraint checks (keeps a frame's cost bounded; the
	# previous target stays when none passes); tests validate everything
	var checks := int(_rt.get("yield", {}).get("validations_per_search", 6)) if _dt > 0.0 else 1 << 30
	while ang <= max_deg + 0.01 and pick.is_empty():
		var ring: Array = []
		for k in dirs:
			var az := TAU * float(k) / dirs
			var axis := (p * cos(az) + q * sin(az)).normalized()
			var cl := _turn_objective(ctx, caps, pivot, axis, ang)
			if cl > base + 0.002:
				ring.append([cl, axis, ang])
		ring.sort_custom(func(a, b) -> bool: return float(a[0]) > float(b[0]))
		for cand: Array in ring:
			if float(cand[0]) < 0.0 or checks <= 0:
				break
			checks -= 1
			var v := _try_turn(ctx, caps, pivot, cand[1], cand[2])
			if v >= 0.0:
				pick = cand
				break
		improving.append_array(ring)
		ang += step
	if pick.is_empty():
		improving.sort_custom(func(a, b) -> bool: return float(a[0]) > float(b[0]))
		for cand: Array in improving:
			if checks <= 0:
				return e.yield_target
			checks -= 1
			if _try_turn(ctx, caps, pivot, cand[1], cand[2]) > base + 0.002:
				pick = cand
				break
	if pick.is_empty():
		e.yield_ang = 0.0
		return Quaternion.IDENTITY
	e.yield_axis = pick[1]
	e.yield_ang = float(pick[2])
	return Quaternion(e.yield_axis, deg_to_rad(e.yield_ang))


## The limb (and horn: back item) objective of a candidate turn, without the surface and back-item
## constraints (cheap; _try_turn validates).
func _turn_objective(ctx: Dictionary, caps: Array, pivot: Vector3, axis: Vector3, ang: float) -> float:
	perf.candidates += 1
	var R := Basis(axis, deg_to_rad(ang))
	var rc: Array = []
	for c: Array in caps:
		rc.append([pivot + R * ((c[0] as Vector3) - pivot), pivot + R * ((c[1] as Vector3) - pivot), c[2]])
	var cl := _limb_clear(rc, ctx.segs, ctx.limbs, ctx.excl, ctx.obj_obst)
	if ctx.obst_obj:
		cl = minf(cl, _limb_clear(rc, {}, [], [], ctx.con_obst) + 0.02)
	return cl


## Clearance objective of a candidate turn, or -INF when it breaks a constraint.
func _try_turn(ctx: Dictionary, caps: Array, pivot: Vector3, axis: Vector3, ang: float) -> float:
	var R := Basis(axis, deg_to_rad(ang))
	var rc: Array = []
	for c: Array in caps:
		rc.append([pivot + R * ((c[0] as Vector3) - pivot), pivot + R * ((c[1] as Vector3) - pivot), c[2]])
	var cl := _limb_clear(rc, ctx.segs, ctx.limbs, ctx.excl, ctx.obj_obst)
	var e: Entry = ctx.e
	var tol := float(_rt.get("yield", {}).get("inward_tolerance_m", 0.005))
	if ctx.inward:
		if ctx.use_local:
			# the body surface: never deeper than the item hangs (the survey's rule)
			if float(ctx.s0) == INF:
				ctx.s0 = minf(_patch_clear(e, caps), 0.0)
			var sc := _patch_clear(e, rc)
			if sc < float(ctx.s0) - tol:
				return -INF
			if ctx.surf_obj:
				cl = minf(cl, sc + 0.01)
		else:
			var r1 := INF
			for c: Array in rc:
				r1 = minf(r1, minf(_torso_dist(c[0]), _torso_dist(c[1])))
			if r1 < float(ctx.r0) - tol:
				return -INF
	if not (ctx.con_obst as Array).is_empty():
		var oc := _limb_clear(rc, {}, [], [], ctx.con_obst)
		if oc < float(ctx.o0) - tol:
			return -INF
		if ctx.obst_obj:
			cl = minf(cl, oc + 0.02)
	return cl


# --- state policies (riding, prone, traversal) --------------------------------------------------

## "stand" | "mounted" | "prone" | "traversal": per-item policies of loadout_design.md 6.3-6.5
## (carry_gear.json points.*.ride_prone / traversal), blended in over 0.2 s by the frame update.
func set_state(s: String) -> void:
	state = s
	for e: Entry in entries:
		e.hidden_by_state = s == "mounted" and e.point in ["back", "back_2"]
	_apply_counts()


func _apply_state(e: Entry, X: Transform3D, C: Transform3D, hook: Vector3) -> Transform3D:
	if _state_w <= 0.0:
		return X
	var w := _state_w
	match state:
		"mounted":
			var rp: Dictionary = e.spec.get("ride_prone", {})
			var turn := absf(float(rp.get("turn_deg", 0.0)))
			if turn > 0.0 and e.upper != Vector3.ZERO:
				var pivot := C * (e.adjust * e.upper)
				var nrm := (C.basis * e.normal).normalized()
				var low := X.origin
				for c: Array in caps_at(e, X):
					for pt: Vector3 in [c[0], c[1]]:
						if pt.y < low.y:
							low = pt
				var q := Quaternion(nrm, deg_to_rad(turn * w))
				if (pivot + Basis(q) * (low - pivot)).y < low.y:
					q = q.inverse()
				return _rot_about(X, pivot, q)
		"prone":
			if e.point in ["chest_R", "chest_L"]:
				var fwd := (C.basis * Vector3.BACK).normalized()
				return _rot_about(X, hook, Quaternion(fwd, deg_to_rad(75.0 * w * (1.0 if e.point == "chest_R" else -1.0))))
		"traversal":
			var pol := String(e.spec.get("traversal", {}).get("policy", "stowed"))
			var nrm := (C.basis * e.normal).normalized()
			if pol.begins_with("push"):
				var cm := 10.0 if "10" in pol else 5.0
				return Transform3D(X.basis, X.origin + nrm * cm * 0.01 * w)
			if pol.begins_with("swing"):
				var ax := nrm.cross(Vector3.UP).normalized()
				return _rot_about(X, hook, Quaternion(ax, deg_to_rad(25.0 * w)))
	return X


# --- handoff stepping -------------------------------------------------------------------------

func _entry_for_draw(item_id: String) -> Entry:
	var es := entries_of(item_id)
	if es.is_empty():
		return null
	for e: Entry in es:
		if e.mode != Mode.STOWED:
			return e if e.mode == Mode.REACH else null
	# take from the outermost point that shows a unit (back_2 before back)
	for i in range(es.size() - 1, -1, -1):
		var e: Entry = es[i]
		if e.shown > 0:
			return e
	return null


func _entry_in_hand(item_id: String) -> Entry:
	for e: Entry in entries_of(item_id):
		if e.mode in [Mode.HELD, Mode.IN_HAND, Mode.REACH]:
			return e
	return null


func _step(e: Entry, dt: float) -> void:
	if not (e.mode in [Mode.REACH, Mode.IN_HAND, Mode.HOLSTER]):
		return
	if not e.driven:
		e.t += dt * e.time_scale
		if e.mode == Mode.HOLSTER:
			e.role = "holster"
			e.phase = clampf(e.t / maxf(_equip_s(e), 1e-4), 0.0, 1.0)
		else:
			var g := 0.0 if e.skip_grab else _grab_s(e)
			if e.t < g:
				e.role = "grab"
				e.phase = e.t / g
			else:
				e.role = "draw"
				e.phase = clampf((e.t - g) / maxf(_equip_s(e), 1e-4), 0.0, 1.0)
	match e.mode:
		Mode.REACH:
			var attach := false
			if e.role == "grab":
				attach = e.phase * _grab_s(e) >= _attach_s(e) - 1e-4
				_pendulum(e)
			elif e.role == "draw":
				if e.skip_grab and not e.driven:
					attach = _hand_reached(e, dt)
				else:
					attach = e.skip_grab or e.ds.has("grab") or e.phase * _equip_s(e) >= _attach_s(e) - 1e-4
			if attach:
				if e.skip_grab and not e.driven:
					e.attach_phase = e.phase
				_attach(e)
		Mode.IN_HAND:
			if _draw_weight(e) >= 1.0 - 1e-6:
				var P := _prop(e.hand)
				var target := P.affine_inverse() * _prop(e.hold) * _hand_offset(e.item_id, e.hold)
				var copy := _long_gun_draw(e) if e.path == "long_gun_left" and not e.skip_grab else P * _blend_xf(e.offset0, target, _draw_weight(e))
				debug[e.item_id + ":swap"] = _gap(copy, _prop(e.hold) * _hand_offset(e.item_id, e.hold))
				_swap_to_model(e)
		Mode.HOLSTER:
			if not e.driven:
				# timer put-away: the item stays with the hand until the hand reaches its place on the body
				# (closest approach), then settles there over PARK_BLEND_S (user playtest: the gear floated
				# back to the body 8-48 cm from the hand). A hand that starts at the place (the pistol's carry
				# holds it 0-5 cm from the belt pistol's place) has not put it away yet: that item leaves the
				# hand at its closest approach or the put-away's park_phase (push n09: the pistol flew to the
				# belt on the first frame of a switch's holster and the hand played the holster empty).
				if e.park_t < 0.0:
					var d := _hand_gap(e, e.hand, e.world * e.last_unit)
					if e.hol_start == INF:
						e.hol_start = d
					var reached := d <= REACH_ATTACH_M and e.hol_start > REACH_ATTACH_M
					if reached or e.role == "finish" or e.phase >= e.park_phase - 1e-6 \
							or (e.hol_min < e.hol_start - REACH_APPROACH_M and d > e.hol_min + 0.01):
						e.park_t = 0.0
						e.park_from = e.visual
					e.hol_min = minf(e.hol_min, d)
				else:
					e.park_t += dt
					if e.park_t >= PARK_BLEND_S:
						debug[e.item_id + ":junction"] = _gap(e.visual, e.world * e.last_unit)
						_park(e)
						return
				return
			if e.role == "finish" or _holster_weight(e) >= 1.0 - 1e-6:
				var P := _prop(e.hold)
				var stow := e.world * e.last_unit
				var copy := _long_gun_holster(e, stow) if e.path == "long_gun_left" else P * _blend_xf(e.hold_off, P.affine_inverse() * stow, 1.0 if e.role == "finish" else _holster_weight(e))
				debug[e.item_id + ":junction"] = _gap(copy, stow)
				_park(e)


## A draw on the rig's timer without a grab clip (the player today: the game plays the draw clip only)
## takes the item when the drawing hand gets to it, not on the draw's first frame (user playtest
## 2026-09-25: "the hand misses the gun": the musket left the back while the left hand was still
## 26-42 cm away and flew to it; the hand reaches it 0.3 s later, 4 cm from the barrel): within
## REACH_ATTACH_M, or at the hand's closest approach once it has come REACH_APPROACH_M nearer than
## where it started (the bow draw's hand passes 26 cm from the slung bow: it takes it there, not
## 76 cm away), else after REACH_TIMEOUT_S of real time.
const REACH_ATTACH_M := 0.05
const REACH_APPROACH_M := 0.05
const REACH_TIMEOUT_S := 0.9
## ... and no later than this phase of the draw clock (a draw whose hand never comes near the item: the
## left-hip pistols before their mirrored clips exist). On the player the hand reaches the item at
## phase 0.06-0.13; later leaves the in-hand settle too little of the clip (the turn in the hand spins).
const REACH_PHASE_MAX := 0.3
## A timer put-away whose hand never reaches the body starts settling the item there at this phase
## (begin_holster()'s `park_phase`; a weapon switch's holster uses 1.0, see _sync_player()).
const PARK_PHASE_MAX := 0.8


## Distance (m) from the palm of `side` to the surface of an entry's capsules at pose X.
func _hand_gap(e: Entry, side: String, X: Transform3D) -> float:
	var palm := int(_bi.get(side + "_palm", -1))
	var hp := _g(palm).origin if palm >= 0 else _prop(side).origin
	var d := INF
	for c: Array in caps_at(e, X):
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var ab := b - a
		var t := clampf((hp - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		d = minf(d, hp.distance_to(a + ab * t) - float(c[2]))
	return d


func _hand_reached(e: Entry, dt: float) -> bool:
	e.reach_t += dt
	var d := _hand_gap(e, e.hand, e.world)
	if d <= REACH_ATTACH_M:
		return true
	if e.reach_start == INF:
		e.reach_start = d
	if e.reach_min < e.reach_start - REACH_APPROACH_M and d > e.reach_min + 0.01:
		return true
	e.reach_min = minf(e.reach_min, d)
	return e.reach_t >= REACH_TIMEOUT_S or e.phase >= REACH_PHASE_MAX


## Pendulum before the attach (5.1.1): the hooked pistol may swing about the belt normal toward the
## source tilt, at most the data's swing, only while the reaching hand is within pendulum_hand_m.
func _pendulum(e: Entry) -> void:
	var pc: Dictionary = e.spec.get("handoff", {}).get("pre_contact", {})
	if pc.is_empty():
		e.pend = 0.0
		return
	var near := float(pc.get("only_while_hand_within_m", _rt.get("handoff", {}).get("pendulum_hand_m", 0.12)))
	var d := _prop(e.hand).origin.distance_to(e.world.origin)
	var k := clampf(1.0 - (d - 0.02) / maxf(near - 0.02, 1e-3), 0.0, 1.0)
	var sw := float(pc.get("swing_deg", 0.0))
	if e.stance == "crouch":
		sw = float(e.spec.get("handoff", {}).get("crouch", {}).get("pendulum_deg", sw))
	e.pend = clampf(sw * k, -absf(float(pc.get("max_deg", 20.0))), absf(float(pc.get("max_deg", 20.0))))


func _ensure_flyer(e: Entry, side := "") -> void:
	var sock := _hand_socket(e.hand if side == "" else side)
	if e.flyer == null or not is_instance_valid(e.flyer):
		var k := e.kind
		if k == "spear_pair":
			k = "spear"
		elif k == "dart_bundle":
			k = "dart"
		e.flyer = SlingModels.unit(k)
		e.flyer.name = "Flyer_" + e.item_id
		sock.add_child(e.flyer)
	elif e.flyer.get_parent() != sock:
		e.flyer.reparent(sock, false)
	e.flyer_socket = sock


func _attach(e: Entry) -> void:
	var X := e.world
	var unit_local := Transform3D.IDENTITY
	var take := e.shown - 1
	if take >= 0 and take < e.units.size():
		unit_local = (e.units[take] as Node3D).transform
	var src := X * unit_local
	e.last_unit = unit_local
	var P := _prop(e.hand)
	e.offset0 = P.affine_inverse() * src
	e.blend_q_ok = false
	e.settle_min = _settle_need(e, e.offset0, P.affine_inverse() * _prop(e.hold) * _hand_offset(e.item_id, e.hold))
	_ensure_flyer(e, e.hand)
	e.flyer.transform = e.offset0
	e.flyer.visible = true
	e.visual = src
	if e.path == "long_gun_left":
		var cz := float(_rt.get("handoff", {}).get("long_gun_contact_z", -0.25))
		e.contact_m = Vector3(0, 0, cz)
		e.contact_l = e.offset0 * e.contact_m
	e.mode = Mode.IN_HAND
	e.pend = 0.0
	_apply_counts()
	_hand_model_visible(e.item_id, false)
	handoff_event.emit(e.item_id, &"attach")


func _swap_to_model(e: Entry) -> void:
	e.mode = Mode.HELD
	if _hand_model(e.item_id):
		if e.flyer:
			e.flyer.visible = false
		_hand_model_visible(e.item_id, true)
	elif e.flyer:
		_ensure_flyer(e, e.hold)
		e.flyer.transform = _hand_offset(e.item_id, e.hold)
	handoff_event.emit(e.item_id, &"shown")


func _park(e: Entry) -> void:
	e.mode = Mode.STOWED
	if e.flyer:
		e.flyer.visible = false
	_hand_model_visible(e.item_id, false)
	_apply_counts()
	handoff_event.emit(e.item_id, &"junction")


## Settle weight of a draw (0 = the attach offset, 1 = the hand offset).
func _draw_weight(e: Entry) -> float:
	if e.role == "grab":
		return 0.0
	if e.path == "long_gun_left" and not e.skip_grab:
		return 1.0 if e.phase >= _path_phases(e).z else 0.0
	var s := _settle(e)
	return _ease((e.phase - s.x) / maxf(s.y - s.x, 1e-4))


## Holster weight toward the stowed pose (0 = in the hand, 1 = parked).
## Seconds a timer put-away takes to settle the item from the hand onto the body.
const PARK_BLEND_S := 0.12


## Timer put-away: how far the item has settled from the hand onto the body (0..1; 0 while in the hand).
func _park_u(e: Entry) -> float:
	return _ease(e.park_t / PARK_BLEND_S) if e.park_t >= 0.0 else 0.0


func _holster_weight(e: Entry) -> float:
	if not e.driven:
		return 0.0 if e.park_t < 0.0 else _park_u(e)
	if e.role == "finish":
		return 1.0
	var d := 1.0 - e.phase
	if e.path == "long_gun_left":
		return 1.0 if d <= 0.0 else 0.0
	var s := _settle(e)
	return 1.0 - _ease((d - s.x) / maxf(s.y - s.x, 1e-4))


## Where the moving copy is this frame (skeleton space) and its local transform in the hand socket.
func _place(e: Entry) -> void:
	match e.mode:
		Mode.STOWED, Mode.REACH:
			e.visual = e.world * e.last_unit if e.mode == Mode.REACH else e.world
			e.holder.transform = _g(e.bone_i).affine_inverse() * e.world
		Mode.HELD:
			e.holder.transform = _g(e.bone_i).affine_inverse() * e.world
			e.visual = _prop(e.hold) * _hand_offset(e.item_id, e.hold)
		Mode.IN_HAND:
			e.holder.transform = _g(e.bone_i).affine_inverse() * e.world
			var P := _prop(e.hand)
			var pose: Transform3D
			if e.path == "long_gun_left" and not e.skip_grab:
				pose = _long_gun_draw(e)
			else:
				var w := _draw_weight(e)
				var target := P.affine_inverse() * _prop(e.hold) * _hand_offset(e.item_id, e.hold)
				pose = P * _blend_xf_c(e, e.offset0, target, w)
			e.visual = pose
			if e.flyer:
				e.flyer.transform = P.affine_inverse() * pose
		Mode.HOLSTER:
			e.holder.transform = _g(e.bone_i).affine_inverse() * e.world
			var P := _prop(e.hand)
			var take := clampi(e.shown, 0, maxi(e.units.size() - 1, 0))
			var unit_local: Transform3D = (e.units[take] as Node3D).transform if take < e.units.size() else Transform3D.IDENTITY
			var stow := e.world * unit_local
			e.last_unit = unit_local
			var pose: Transform3D
			if not e.driven and e.park_t >= 0.0:
				# timer put-away: the hand has reached the body; settle from where the item left the hand
				pose = _blend_xf(e.park_from, stow, _park_u(e))
			elif e.path == "long_gun_left":
				pose = _long_gun_holster(e, stow)
			else:
				var w := _holster_weight(e)
				var Ph := _prop(e.hold)
				pose = Ph * _blend_xf_c(e, e.hold_off, Ph.affine_inverse() * stow, w)
			e.visual = pose
			if e.flyer:
				e.flyer.transform = P.affine_inverse() * pose


static func _gap(a: Transform3D, b: Transform3D) -> Vector2:
	return Vector2(a.origin.distance_to(b.origin), rad_to_deg(a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())))


## Review fix: the hand-relative blend of a moving copy keeps turning the way it turned the frame before.
## The shortest-arc slerp flips direction when the turn left passes 180 deg as the hand moves (the
## atlatl's put-away turned 92 deg in one frame). The two ways round end on the same rotation.
func _blend_xf_c(e: Entry, a: Transform3D, b: Transform3D, w: float) -> Transform3D:
	if w <= 0.0:
		e.blend_q = a.basis.get_rotation_quaternion()
		e.blend_q_ok = true
		return a
	if w >= 1.0:
		e.blend_q_ok = false
		return b
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	var q := qa.slerp(qb, w)
	if e.blend_q_ok:
		var q1 := qa.slerpni(qb, w)
		var q2 := qa.slerpni(-qb, w)
		q = q1 if absf(q1.dot(e.blend_q)) >= absf(q2.dot(e.blend_q)) else q2
	e.blend_q = q
	e.blend_q_ok = true
	return Transform3D(Basis(q), a.origin.lerp(b.origin, w))


static func _blend_xf(a: Transform3D, b: Transform3D, w: float) -> Transform3D:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	var qa := a.basis.get_rotation_quaternion()
	var qb := b.basis.get_rotation_quaternion()
	return Transform3D(Basis(qa.slerp(qb, w)), a.origin.lerp(b.origin, w))


## The musket off long_A (loadout_design.md 5.3): held rigid by the left hand at its fore-end contact,
## lifted out toward the character's left while it turns to a fixed muzzle-up pose V (lift), then V
## turns into the source gun's orientation while the lift returns (join), then the grip slides down the
## fore-end to the source grip (tail). The source gun = right prop x hand offset.
func _long_gun_draw(e: Entry) -> Transform3D:
	var ph := _path_phases(e)
	var Pl := _prop("l")
	var S := _prop(e.hold) * _hand_offset(e.item_id, e.hold)
	var A := Pl * e.offset0
	var hold := Pl * e.contact_l
	var left := (_g(int(_bi["pelvis"])).basis * Vector3.RIGHT).normalized()
	var out := float(e.spec.get("handoff", {}).get("hand_out_m", 0.3))
	var V := _v_pose(e, A.basis)
	if e.role == "grab":
		return A
	var p := e.phase
	var R: Basis
	var k := 0.0
	if p <= ph.x:
		var u := _ease(p / maxf(ph.x, 1e-4))
		R = Basis(A.basis.get_rotation_quaternion().slerp(V.get_rotation_quaternion(), u))
		k = u
	elif p <= ph.y:
		var u := _ease((p - ph.x) / maxf(ph.y - ph.x, 1e-4))
		R = Basis(V.get_rotation_quaternion().slerp(S.basis.get_rotation_quaternion(), u))
		k = 1.0 - u
	else:
		var u := _ease((p - ph.y) / maxf(ph.z - ph.y, 1e-4))
		var held := hold - S.basis * e.contact_m
		return Transform3D(S.basis, held.lerp(S.origin, u))
	var pos := hold + left * out * k - R * e.contact_m
	return Transform3D(R, pos)


## The mirror of _long_gun_draw for the holster, ending exactly at the live stowed pose.
func _long_gun_holster(e: Entry, stow: Transform3D) -> Transform3D:
	var ph := _path_phases(e)
	var Pl := _prop("l")
	var S := _prop(e.hold) * e.hold_off
	var hold := Pl.origin
	var left := (_g(int(_bi["pelvis"])).basis * Vector3.RIGHT).normalized()
	var out := float(e.spec.get("handoff", {}).get("hand_out_m", 0.3))
	var V := _v_pose(e, stow.basis)
	var cm := Vector3(0, 0, float(_rt.get("handoff", {}).get("long_gun_contact_z", -0.25)))
	var d := 1.0 - e.phase
	if d >= ph.z:
		return S
	if d >= ph.y:
		var u := _ease((ph.z - d) / maxf(ph.z - ph.y, 1e-4))
		return Transform3D(S.basis, S.origin.lerp(hold - S.basis * cm, u))
	if d >= ph.x:
		var u := _ease((ph.y - d) / maxf(ph.y - ph.x, 1e-4))
		var R := Basis(S.basis.get_rotation_quaternion().slerp(V.get_rotation_quaternion(), u))
		return Transform3D(R, hold + left * out * u - R * cm)
	var u := _ease((ph.x - d) / maxf(ph.x, 1e-4)) if e.driven else 0.0
	var from := Transform3D(V, hold + left * out - V * cm)
	return _blend_xf(from, stow, u)


## The muzzle-up transit pose V: muzzle up, leaning forward (lean_fwd) and to the side (lean_out),
## lock toward the character's right.
func _v_pose(e: Entry, ref := Basis()) -> Basis:
	var V := _v_pose_gun(e)
	if e.kind in ROUND_SHAFTS:
		# Review fix: a spear or a dart keeps its own roll through the transit (the gun's "lock to the
		# right" roll spun the spear about 60 deg a frame in the lift; a round shaft shows no roll)
		var a := (ref * Vector3.FORWARD).normalized()
		var b := (V * Vector3.FORWARD).normalized()
		if a.dot(b) > -0.999:
			return Basis(ReachIK._arc(a, b)) * ref.orthonormalized()
	return V


## Items whose roll about their long axis does not show (the long-gun path keeps their roll).
const ROUND_SHAFTS := ["spear_pair", "dart_bundle"]


func _v_pose_gun(e: Entry) -> Basis:
	var ho: Dictionary = e.spec.get("handoff", {})
	var pel := _g(int(_bi["pelvis"])).basis.orthonormalized()
	var up := Vector3.UP
	var fwd := (pel * Vector3.BACK)
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var left := up.cross(fwd).normalized()
	var m := (up + fwd * float(ho.get("lean_fwd", 0.9)) + left * float(ho.get("lean_out", -0.2))).normalized()
	var z := -m
	var x := -left
	x = (x - z * x.dot(z)).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


# --- reach IK -----------------------------------------------------------------------------------

func enable_reach_ik(on: bool) -> void:
	if on and reach_ik == null:
		reach_ik = ReachIK.new()
		reach_ik.name = "SlingReachIK"
		skeleton.add_child(reach_ik)
		var body_i := -1
		for i in skeleton.get_child_count():
			if skeleton.get_child(i) is CharacterBodyMesh:
				body_i = i
		if body_i >= 0:
			skeleton.move_child(reach_ik, body_i)
	elif not on and reach_ik:
		reach_ik.queue_free()
		reach_ik = null


## Reach IK weights (5.1.4): 0 -> 1 over the grab, 1 -> 0 over the first 35 % of the equip clip; for a
## holster the mirror. Only for placements whose handover asks for it (gap > 6 cm).
func _update_ik() -> void:
	if reach_ik == null:
		return
	var used := {"r": false, "l": false}
	for e: Entry in entries:
		if not bool(e.spec.get("handover", {}).get("reach_ik", false)):
			continue
		var w := 0.0
		var dec: Array = e.spec.get("handoff", {}).get("reach_ik_decay_phase", _rt.get("handoff", {}).get("reach_ik_decay_phase", [0.0, 0.35]))
		match e.mode:
			Mode.REACH:
				w = _ease(e.phase) if e.role == "grab" else 1.0
			Mode.IN_HAND:
				w = 1.0 - _ease((e.phase - float(dec[0])) / maxf(float(dec[1]) - float(dec[0]), 1e-4)) if e.role == "draw" else 1.0
			Mode.HOLSTER:
				w = _ease((e.phase - (1.0 - float(dec[1]))) / maxf(float(dec[1]) - float(dec[0]), 1e-4))
		if w > 0.0:
			used[e.hand] = true
			e.ik_w = w
			reach_ik.set_target(e.hand, Callable(self, "_ik_target").bind(e), w)
	for s: String in used:
		if not used[s]:
			reach_ik.clear(s)


## IK target for the hand prop: the stowed contact (grip, or the handover's contact point) of the entry
## being drawn, from the skeleton pose at modification time (the arm is not an input of it).
func _ik_target(side: String, e: Entry) -> Vector3:
	_gcache.clear()
	var ho: Dictionary = e.spec.get("handover", {})
	var st: Dictionary = ho.get("stances", {}).get(e.stance, ho.get("stances", {}).get("stand", {}))
	var X := _carry(e) * e.adjust * e.bind
	if st.has("contact_bind") and String(ho.get("draw_set", "")) != "pistol_no_pack":
		return X * (e.bind.affine_inverse() * _v3(st.contact_bind))
	return X.origin


# --- straps -----------------------------------------------------------------------------------

const ROUTES := "res://assets/loadout/strap_routes_bind.json"


## Straps: the asset workflow's measured routes (assets/loadout/strap_routes_bind.json: anchors on the
## legacy body, item markers, widths, layer order) where they exist, and data/loadout/sling_runtime.json
## for the rest (the mirrored slots, the horn ties on the legacy body, bodies without that file).
func _make_straps() -> void:
	if surface == null:
		return
	var covered := {}
	var routes: Dictionary = {}
	if FileAccess.file_exists(ROUTES):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
		if d is Dictionary:
			routes = d.get("straps", {})
	for rid: String in routes:
		var r: Dictionary = routes[rid]
		if rid == "horn_strap" and (legacy_body or not horn_strapped):
			continue   # the legacy body bakes its horn strap: the horn is tied to it (horn_ties); on the belt it has none
		if rid == "pistol_sling" and not loadout.gear.has("pistol_sling"):
			continue
		var anchors: Array = []
		var owner: Entry = null
		var ok := true
		for a: Dictionary in r.get("anchors", []):
			if String(a.get("kind", "")) == "item_marker":
				var ik := String(a.get("item", "")).split(".")
				var e: Entry = null
				for x: Entry in entries:
					if x.point == ik[0] and x.kind == ik[1]:
						e = x
				if e == null:
					if rid == "pistol_sling":
						continue   # a sling worn without that pistol: the band goes straight on
					ok = false
					break
				if owner == null and rid != "pistol_sling":
					owner = e
				anchors.append({"kind": "item", "entry": e, "p": SlingModels.marker(e.root, [String(a.marker)], Vector3.ZERO)})
			else:
				var vi := surface.nearest(_v3(a.bind), _v3(a.get("normal", [0, 0, 0])))
				if vi < 0:
					ok = false
					break
				anchors.append({"kind": "skin", "v": vi, "p": _v3(a.bind), "n": _v3(a.get("normal", [0, 0, 1])).normalized()})
		if not ok or anchors.size() < 2:
			continue
		if bool(r.get("closed", false)):
			anchors.append(anchors[0])
		var col := Color(0.3, 0.18, 0.09) if rid != "horn_strap" else Color(0.34, 0.24, 0.14)
		var node := _strap_node(rid, float(r.get("width_m", 0.03)), 0.003 + 0.0022 * float(r.get("layer_inner_to_outer", 0)), col)
		straps.append({"id": rid, "node": node, "anchors": anchors, "owner": owner, "source": "strap_routes_bind.json"})
		if owner:
			covered[owner] = true
		else:
			covered["gear:" + rid] = true
		if rid == "pistol_sling":
			_make_buckle(straps[straps.size() - 1])
	var lift_by: Dictionary = _rt.get("strap_order_lift_m", {})
	for spec: Dictionary in _rt.get("straps", []):
		var owner: Entry = null
		if spec.has("for_point"):
			owner = entry_at(String(spec.for_point))
			if owner == null or not (spec.get("kinds", []) as Array).has(owner.kind) or covered.has(owner):
				continue
		if spec.has("gear"):
			if not loadout.gear.has(String(spec.gear)) or covered.has("gear:" + String(spec.id)):
				continue
			if String(spec.id) == "horn_strap" and (covered.has("gear:horn_strap") or not horn_strapped):
				continue
		if spec.has("legacy_strap") and bool(spec.legacy_strap) != legacy_body:
			continue
		var paths: Array = spec.segments if spec.has("segments") else [spec.path]
		var col: Array = spec.get("color", [0.3, 0.18, 0.09])
		for pi in paths.size():
			var anchors: Array = []
			var ok := true
			for a: Dictionary in paths[pi]:
				var r := _resolve_anchor(a, owner)
				if r.is_empty():
					ok = false
					break
				anchors.append(r)
			if not ok:
				continue
			var node := _strap_node("%s_%d" % [spec.id, pi], float(spec.get("width", 0.03)), float(lift_by.get(String(spec.get("order", "")), 0.006)),
					Color(float(col[0]), float(col[1]), float(col[2])))
			straps.append({"id": String(spec.id), "node": node, "anchors": anchors, "owner": owner, "source": "sling_runtime.json"})


func _strap_node(id: String, width: float, lift: float, col: Color) -> SlingStrap:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.82
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := SlingStrap.new()
	node.name = "Strap_" + id
	node.width = width
	node.lift = lift
	node.material_override = m
	skeleton.add_child(node)
	return node


## The pistol sling's buckle on the back segment of the band (MANIFEST pistol_sling_buckle: +Z along
## the band, +Y away from the body), about 40 % up from the left hip.
func _make_buckle(strap: Dictionary) -> void:
	var b := SlingModels.gear("pistol_sling_buckle")
	if b == null:
		return
	skeleton.add_child(b)
	strap["buckle"] = b


func _resolve_anchor(a: Dictionary, owner: Entry) -> Dictionary:
	if a.has("item_marker"):
		if owner == null:
			return {}
		return {"kind": "item", "entry": owner, "p": SlingModels.marker(owner.root, [String(a.item_marker)], _v3(a.get("at", [0, 0, 0])))}
	if a.has("item"):
		return {"kind": "item", "entry": owner, "p": _v3(a.item)} if owner else {}
	if a.has("item_tie"):
		if owner == null:
			return {}
		var tp: Dictionary = TIE_POINTS.get(owner.kind, {})
		var mk := "ThongUpper" if String(a.item_tie) == "upper" else "ThongLower"
		return {"kind": "item", "entry": owner, "p": SlingModels.marker(owner.root, [mk], tp.get(String(a.item_tie), Vector3.ZERO))}
	if a.has("horn"):
		var names: Array = a.horn if a.horn is Array else [a.horn]
		for e: Entry in entries:
			if e.kind == "powder_horn":
				return {"kind": "item", "entry": e, "p": SlingModels.marker(e.root, names, Vector3.ZERO)}
		return {}
	if a.has("stow"):
		var pk := String(a.stow).split(".")
		var e := entry_at(pk[0])
		if e and e.kind == pk[1]:
			return {"kind": "item", "entry": e, "p": _v3(a.get("at", [0, 0, 0]))}
		var bind := data.stow_bind(pk[0], pk[1])
		var bone := data.stow_bone(pk[0], pk[1])
		return {"kind": "bone", "bone": int(_bi.get(bone, 0)), "p": bind * _v3(a.get("at", [0, 0, 0])), "n": surface.radial_normal(bind.origin)}
	var key := JSON.stringify(a)
	if _anchor_cache.has(key):
		return _anchor_cache[key]
	var vi := -1
	var spec := a
	if a.has("body"):
		spec = _rt.get("body_anchors", {}).get(String(a.body), {})
	if spec.has("shoulder"):
		vi = surface.shoulder_top(float(spec.shoulder))
	elif spec.has("label"):
		vi = surface.nearest_label(_v3(spec.p), String(spec.label))
	elif spec.has("a"):
		vi = surface.outer_at(float(spec.a), float(spec.y))
	elif spec.has("p"):
		vi = surface.nearest(_v3(spec.p))
	if vi < 0:
		return {}
	var r := {"kind": "skin", "v": vi, "p": surface.sv[vi], "n": surface.sn[vi]}
	_anchor_cache[key] = r
	return r


func _update_straps() -> void:
	var gl := Callable(self, "_g")
	for s: Dictionary in straps:
		var owner: Entry = s.owner
		var node: SlingStrap = s.node
		var show := owner == null or (owner.mode in [Mode.STOWED, Mode.REACH] and owner.shown > 0) or owner.kind == "quiver"
		if owner and owner.hidden_by_state:
			show = false
		node.visible = show
		if not show:
			continue
		var pts := PackedVector3Array()
		var nrs := PackedVector3Array()
		for a: Dictionary in s.anchors:
			match String(a.kind):
				"item":
					var e: Entry = a.entry
					pts.append(e.world * (a.p as Vector3))
					nrs.append((_carry(e).basis * e.normal).normalized())
				"bone":
					var M := _g(int(a.bone)) * (_bind[int(a.bone)] as Transform3D).affine_inverse()
					pts.append(M * (a.p as Vector3))
					nrs.append((M.basis * (a.n as Vector3)).normalized())
				"skin":
					var reg_b := float(bulk.get("chest", 0.0))
					var p := surface.skin_point(int(a.v), a.p, gl)
					var n := surface.skin_normal(int(a.v), a.n, gl)
					pts.append(p + n * maxf(reg_b, 0.0))
					nrs.append(n)
		node.set_path(pts, nrs)
		node.rebuild()
		if s.has("buckle") and is_instance_valid(s.buckle) and pts.size() >= 3:
			# back segment: the anchors after the left hip (hip_L -> back_L_low -> back_R_high)
			var i := maxi(pts.size() - 4, 0)
			var p0 := pts[i]
			var p1 := pts[mini(i + 1, pts.size() - 1)]
			var zt := (p1 - p0).normalized()
			var yn := (nrs[i] - zt * nrs[i].dot(zt)).normalized()
			var bpos := p0.lerp(p1, 0.4) + yn * (node.lift + 0.002)
			(s.buckle as Node3D).transform = Transform3D(Basis(yn.cross(zt).normalized(), yn, zt), bpos)
			(s.buckle as Node3D).visible = node.visible


# --- player sync (install) ----------------------------------------------------------------------

## Follows the player's own weapon switch (player.gd unchanged): the weapon it puts away during its
## holster phase goes back to the body over that phase, the weapon it draws comes off the body over its
## draw (the player plays only the graph's equip clip, so the copy attaches at its start). Instant
## switches snap. Counts follow the weapons (spears, tomahawks, arrows).
func _sync_player(_dt_s: float, first := false) -> void:
	var p := player
	if p == null or p.weapons.is_empty():
		return
	stance = "crouch" if p.is_crouching else "stand"
	var cur := p.weapon_key
	for key: String in p.weapons:
		var id := item_for_key(key)
		if id == "":
			continue
		var w: Weapon = p.weapons[key]
		# a weapon the player put down in the world (PlayerInteractor): nothing of it on the body
		if p.has_method("is_carried") and not p.is_carried(key):
			if mode_of(id) != Mode.STOWED:
				snap_stowed(id)
			_set_present(id, false)
			continue
		_set_present(id, true)
		if key == p.offhand_key:
			continue    # in the left hand beside a quick throwable (QuickOffhand, push n01c): held, not on the back
		var m := mode_of(id)
		if w is Throwable and not (m in [Mode.REACH, Mode.IN_HAND, Mode.HOLSTER]):
			# A thrown weapon shows its own model through a switch and the throw cycle (Throwable.switch_path,
			# THROW2: the spear on the long-gun draw's own object path, the tomahawk in the fist, stood up at the
			# back of the belt, the atlatl in the fist; tests/anim/test_throw_switch_grip.gd): the rig only takes
			# the one in the hand off the body while that model shows. Its own put-away and draw copies hid the
			# tomahawk's model through every switch (push n09). The hands-free and traversal stows (sling_all(),
			# unsling()) still carry it.
			_follow_model(id, w.model != null and w.model.visible)
		elif key == cur and w.active:
			if m == Mode.STOWED:
				if first or not w.is_equipping():
					snap_held(id)
				else:
					var left: Variant = w.get("_equip_left")
					begin_draw(id, {"skip_grab": true, "duration": float(left) if left != null else w.equip_time})
			elif m == Mode.HELD and w.model and not w.model.visible and not p.is_dead and not w is Throwable \
					and not w.clubbed:
				# (a thrown weapon shows its own: nothing in the hand after a throw or with none left; forcing
				# it here showed a phantom spear / tomahawk in the empty hand. A gun clubbed is hidden too:
				# GatherTools.club holds a copy of it end for end)
				w.model.visible = true
		elif key != cur or not w.active:
			if m == Mode.HELD or m == Mode.IN_HAND or m == Mode.REACH:
				if p.is_dead and m == Mode.HELD and w.model and w.model.visible:
					# died during a switch's holster before the put-away began (plan 8.1, FrontierPlayer._die():
					# the old weapon's model stays in the dead hand until respawn(); stowing it here put the
					# musket on the back of the corpse: test_contract's death during the holster)
					pass
				elif p.is_switching() and w.model and w.model.visible and not first:
					# the put-away's clock: what is left of the switch's holster (switch_timing(): the graph
					# holster over the old weapon's equip_time; holster_phase() alone is the
					# override_fast_weapon_switch timing, and parked the old weapon on the body 0.2-0.5 s
					# before the holster ended). The holster is the draw clip backwards, so the hand gets to
					# the body at its end: an item whose hand has not come within reach by then leaves it
					# there (park_phase 1.0; at 0.8 the musket left the hand 21 cm from the back and was on it
					# before the holster ended: test_contract's switch model checks, push n09)
					var h := 0.0
					var tm: Dictionary = p.switch_timing()
					if not tm.is_empty():
						h = float(tm.t_finish) - float(tm.t)
					elif p.anim and p.anim.data:
						h = FrontierPlayer.holster_phase(p.anim.data, key, cur, stance, p.weapon.equip_time)
					begin_holster(id, {"duration": h if h > 0.0 else 0.25, "park_phase": 1.0})
				elif key != cur:
					snap_stowed(id)
		# keep the hand model hidden while the copy does its job
		if mode_of(id) in [Mode.IN_HAND, Mode.HOLSTER, Mode.REACH] and w.model:
			w.model.visible = false
		# counts
		if w is Throwable:
			var it := loadout.item(id)
			var c := int((w as Throwable).count)
			if not it.is_empty() and int(it.count) != c:
				set_count(id, c)
		elif w is Bow:
			var qid := String(loadout.first_of_kind("quiver").get("id", ""))
			if qid != "":
				var b := w as Bow
				var arrows := b.quiver - (b.held + 1 if w.active else 0)
				var qit := loadout.item(qid)
				if int(qit.state.get("arrows", -1)) != maxi(arrows, 0):
					set_count(qid, maxi(arrows, 0))


## A thrown weapon's entry follows the weapon's own model (see _sync_player()): in the hand (HELD: one unit
## fewer on the body) while the model shows, on the body otherwise. The model's visibility stays the weapon's.
func _follow_model(item_id: String, held: bool) -> void:
	var m := mode_of(item_id)
	if held and m == Mode.STOWED:
		var e := _entry_for_draw(item_id)
		if e != null:
			e.mode = Mode.HELD
			if e.flyer:
				e.flyer.visible = false
			_apply_counts()
	elif not held and m == Mode.HELD:
		for e: Entry in entries_of(item_id):
			if e.mode != Mode.STOWED:
				e.mode = Mode.STOWED
				if e.flyer:
					e.flyer.visible = false
		_apply_counts()


## Items whose weapon the player put down (not carried): their copies are hidden.
var _absent := {}


## Hides an item's stowed copy while something else shows it (PlayerGrip: the climbing stakes in the hands), or shows
## it again.
func hide_stowed(item_id: String, hidden: bool) -> void:
	_set_present(item_id, not hidden)


func _set_present(item_id: String, on: bool) -> void:
	if on != _absent.has(item_id):
		return
	if on:
		_absent.erase(item_id)
	else:
		_absent[item_id] = true
	for e: Entry in entries_of(item_id):
		if is_instance_valid(e.holder):
			e.holder.visible = on


# --- helpers ----------------------------------------------------------------------------------

static func _v3(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func _closest_on_seg(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
	return a + ab * t


## [distance, closest point on p1-q1, closest point on p2-q2] between two segments.
static func _closest_seg_seg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-12 and e <= 1e-12:
		return [p1.distance_to(p2), p1, p2]
	if a <= 1e-12:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-12:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-12 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var c1 := p1 + d1 * s
	var c2 := p2 + d2 * t
	return [c1.distance_to(c2), c1, c2]


## The pose of the item this frame as shown (skeleton space): the stowed copy, the moving copy or the
## hand model. For tests and the preview's readout.
func visual_pose(item_id: String) -> Transform3D:
	for e: Entry in entries_of(item_id):
		if e.mode != Mode.STOWED:
			return e.visual
	var es := entries_of(item_id)
	return (es[0] as Entry).visual if not es.is_empty() else Transform3D()


## The pose of the in-hand model (prop x hand offset) of an item this frame.
func hand_pose(item_id: String) -> Transform3D:
	var es := entries_of(item_id)
	var side := (es[0] as Entry).hold if not es.is_empty() else "r"
	return _prop(side) * _hand_offset(item_id, side)
