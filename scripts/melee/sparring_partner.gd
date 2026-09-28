class_name SparringPartner
extends Node3D
## A stand-in opponent to try melee contact against (user 2026-09-27: "if two weapons collide they both bounce back"):
## Actor_B with the felling axe in both hands, swinging our own D (animations_extra/Frontier_Own.res) when swing() is
## called (or A, W, S). Its axe's path is swept a tick ahead like the player's (MeleeSweep), the whole swing: it stops
## on what it meets and runs back, and a defender it meets (the player's body, or the axe held to defend) turns it
## aside by what they are doing (block_power: stopped short, both bouncing back, or glancing on); it blocks by the same
## rules, only with its counter to the blow (in time: all of it, late: half; nothing else blocks), and has no parry (its
## axe is never there to meet: guarding). It has a body to strike (a torso and a head on its bones:
## flesh) that takes the hits and counts them (and the damage; it takes no harm), and its blows land (Hit.deliver: the
## swing's damage, less what a late counter took) and go on through the body, as the player's. Struck, it flinches (user 2026-09-27: "if the other user hits the
## user [first] then a hit animation happens and it restarts the persons hit swing"; "its more about timing and who
## can win the exchange"): the game's full-body hit reaction from the side the blow came (actor_b-p-hr-*, as the
## player's heavy hit), its swing lost; then back on guard. It eases between poses (a swing begun, the flinch in and
## out: FADE_S). Not an enemy: no AI; tests and films drive it. Faces its +Z.

## The partner's look (a people preset; bare, as everyone until the garments pass).
const LOOK := "scots_irish_m_a"
const OWN_PATH := "res://animations_extra/Frontier_Own.res"
const PIPE := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0, -0.035))
## The one-handed clips' blade frame (the stab: GatherTools.blade_offset, the axe's carry grip).
const BLADE := Transform3D(Basis(), Vector3(0, -0.46, 0))
const FRAME_S := 0.15
## The hit reaction by the side the blow came from (the graph's runtime_clips.hit_full, standing), in Actor_B's library.
const HIT_CLIP := "actor_b/actor_b-p-hr-%s"
## The flinch ends this far into its clip at most (the graph's hit exit), sooner as the player's (AxeMelee.FLINCH_S,
## FLINCH_HEAVY_S: a blow of HEAVY_HIT or more, the player's heavy_hit_damage), then eases back to the guard.
const HIT_EXIT := 0.9
const HEAVY_HIT := 40.0
const FADE_S := 0.12
const BACK_S := 0.3
const PROP := "r_hand_prop_attachment"
const RETURN_RATE := 1.2

## The swing ("D" in data/melee/felling_axe.json: clips, strike window).
var dir := "D"
var state := ""                  ## "" (on guard), "swing", "stop", "recoil", "return", "flinch" (struck)
var u := 0.0
var clashed := 0                 ## times another weapon met its swing
var struck := 0                  ## times its body was struck
var damage_taken := 0.0          ## the damage of those blows (it takes no harm)
var last_contact := {}

var sk: Skeleton3D
var ap: AnimationPlayer
var axe: Node3D
var weapon: WeaponBody
var _intro: Animation
var _hit: Animation
var _names := ["own-axe-d-intro", "own-axe-d"]   ## the clips it shows (its swing's, as its sweep follows)
var _strike := [0.28, 0.52]
var _rate := 1.0
var _left := 0.0
var _prm := {}
var _torso: StaticBody3D
var _head: StaticBody3D
var _pts := {}
var _own: AnimationLibrary
var _data := {}
var _glanced: Array = []          ## weapons its swing glanced off (gone past)
var _blocks := {}                 ## defenders its swing has met (instance id -> how much they turned it aside)
var _passed: Array = []           ## bodies its swing has gone through
var _damage := 0.0                ## its swing's ("damage" in the data)
var _swing_rate := 1.0            ## its swing's pace ("rate" in the data, the tool's and the swing's own)
var _chain := 0.8                 ## from here in its swing the next may begin ("chain_s" in the data)
var _flinch_s := 0.0              ## how long this flinch holds it (AxeMelee.FLINCH_S, FLINCH_HEAVY_S)
var _frame := "pipe"              ## the hold its swing's clips have the axe in ("frame" in the data)
var _frame_w := 1.0               ## 1 the pipe frame, 0 the blade frame (eased: FRAME_S)
var _flinch_anim: Animation
var _flinch_nm := ""
var _flinch_t := 0.0
var _from_pose: Array = []        ## the pose it eases from ([position, rotation, scale] a bone), and how
var _fade_left := 0.0
var _fade_s := 0.0


func _ready() -> void:
	var n := (load("res://characters/Actor_B.tscn") as PackedScene).instantiate() as Node3D
	add_child(n)
	sk = n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	add_to_group(&"melee_defender")
	var aps := n.find_children("*", "AnimationPlayer", true, false)
	ap = aps[0] if not aps.is_empty() else null
	# the bare body v4 as the player's (PlayerAppearance.dress; the legacy outfit only gives the binds)
	var body := CharacterBodyMesh.attach(sk, ap, "res://assets/character/actor_b_body.glb")
	if body:
		PlayerAppearance.dress(body, AppearanceStore.validate(CharacterPeoples.preset_look(LOOK)))
	var own := load(OWN_PATH) as AnimationLibrary
	_own = own
	var data = JSON.parse_string(FileAccess.get_file_as_string(MeleeSweep.DATA_PATH))
	_data = data if data is Dictionary else {}
	_use(dir)
	if ap:
		ap.add_animation_library("own", own)
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var att := BoneAttachment3D.new()
	att.bone_name = PROP
	sk.add_child(att)
	axe = GatherModels.build("felling_axe")
	att.add_child(axe)
	axe.transform = PIPE
	weapon = WeaponBody.attach(axe, self)
	_torso = _part("body", 1.0, _capsule(0.17, 0.62))
	# (a head: the bonus for shots; a melee blow takes it as the body, as on the player, who has none: Hit.deliver
	# head_bonus, user 2026-09-27)
	_head = _part("head", 2.0, _sphere(0.12))
	_show()


## Swings `d` ("D", "A", "W", "STAB": our own clips; "S" the high block; from the guard, or chained on from its swing past that swing's
## chain time, as the player's).
func swing(d := "D") -> void:
	if state == "" or state == "swing" and u >= _chain:
		_use(d)
		state = "swing"
		u = 0.0
		_rate = _swing_rate
		_glanced = []
		_blocks = {}
		_passed = []
		_ease_from(FADE_S)


func _use(d: String) -> void:
	var sp: Dictionary = (_data.get("swings", {}) as Dictionary).get(d, {})
	if not _own.has_animation(String(sp.get("intro", ""))):
		return
	dir = d
	_intro = _own.get_animation(String(sp.intro))
	_hit = _own.get_animation(String(sp.hit))
	_names = [String(sp.intro), String(sp.hit)]
	_damage = float(sp.get("damage", 0.0))
	_swing_rate = float(_data.get("rate", 1.0)) * float(sp.get("rate", 1.0))
	_chain = float(sp.get("chain_s", 0.8))
	_frame = String(sp.get("frame", "pipe"))
	_strike = sp.get("strike", _strike)


## How strongly it turns a blow aside (the player's AxeMelee.block_power, the same rules): only its counter to that
## blow, in time all of it, too late or early half; anything else (on guard, another attack, held stopped) nothing.
func block_power(attacker_dir: String, _point: Vector3, _way: Vector3) -> float:
	if state != "swing" or String((_data.get("counters", {}) as Dictionary).get(attacker_dir, "")) != dir:
		return 0.0
	return 1.0 if u >= float(_strike[0]) - AxeMelee.COUNTER_LEAD and u <= float(_strike[1]) else AxeMelee.BLOCK_SWING


## Its axe is never there for a blow to meet (WeaponBody): blocks are met in the space between (MeleeSweep.near_defender).
func guarding() -> bool:
	return false


## How strongly `foe` turns its blow aside, the first time it meets them (0 after); partly: a glancing ring.
func _block(foe: Object, point: Vector3, way: Vector3) -> float:
	var id := foe.get_instance_id()
	if _blocks.has(id):
		return 0.0
	var b := clampf(float(foe.block_power(dir, point, way)), 0.0, 1.0)
	_blocks[id] = b
	if b > 0.0 and b < AxeMelee.BLOCK_FULL:
		last_contact = {"surface": "weapon", "point": point, "u": u, "glance": b}
		MeleeSweep.sound("weapon", point, 0.6)
	return b


## Another weapon met this one's swing: it stops and bounces back.
func clash(point: Vector3, from_dir: Vector3, _by: WeaponBody) -> void:
	if state == "swing":
		_stop("weapon", point, -from_dir, null, false)


## A blow on its body (Hit.deliver): counted, and its damage (it takes no harm); a real blow (AxeMelee.INTERRUPT_DAMAGE)
## and it flinches, its swing lost, as the player does.
func apply_hit(damage: float, _point: Vector3, dir: Vector3, _source: Node, _part: String) -> void:
	struck += 1
	damage_taken += damage
	if damage >= AxeMelee.INTERRUPT_DAMAGE:
		_flinch(dir, AxeMelee.FLINCH_HEAVY_S if damage >= HEAVY_HIT else AxeMelee.FLINCH_S)


## Struck (the blow travelling `dir`): the hit reaction from that side, whatever it was doing, for `hold` s (then eased
## back to the guard).
func _flinch(dir: Vector3, hold: float) -> void:
	var from := -dir
	var fwd := global_basis.z
	var right := -global_basis.x
	var a := rad_to_deg(atan2(from.dot(right), from.dot(fwd)))
	var side := "fw" if absf(a) <= 45.0 else ("bw" if absf(a) >= 135.0 else ("rt" if a > 0.0 else "lt"))
	var nm := HIT_CLIP % side
	if ap == null or not ap.has_animation(nm):
		state = ""
		u = 0.0
		return
	_ease_from(FADE_S)
	_flinch_anim = ap.get_animation(nm)
	_flinch_nm = nm
	_flinch_s = minf(hold, _flinch_anim.length * HIT_EXIT)
	_flinch_t = 0.0
	state = "flinch"
	u = 0.0


func _physics_process(delta: float) -> void:
	if sk == null:
		return
	_place_body()
	match state:
		"swing":
			var u_new := u + delta * _rate
			_ahead(u_new)
			if state == "swing" and u >= _intro.length + _hit.length:
				_on_guard()
		"stop":
			_left -= delta
			if _left <= 0.0:
				state = "recoil"
				_left = float(_prm.recoil_s)
				_rate = -float(_prm.recoil_rate)
		"recoil":
			u = maxf(u + delta * _rate, 0.0)
			_left -= delta
			if _left <= 0.0 or u <= 0.0:
				state = "return"
		"return":
			u = maxf(u - delta * RETURN_RATE, 0.0)
			if u <= 0.0:
				_on_guard()
		"flinch":
			_flinch_t += delta
			if _flinch_t >= _flinch_s:
				_on_guard()
	_frame_w = move_toward(_frame_w, 0.0 if _frame == "blade" and state != "" else 1.0, delta / FRAME_S)
	axe.transform = BLADE.interpolate_with(PIPE, _frame_w)
	_fade_left = maxf(_fade_left - delta, 0.0)
	_show()


## The path to u_new swept; met something: held back at the moment it met it.
func _ahead(u_new: float) -> void:
	if _fade_left > 0.0:
		# (still easing in from the pose before: not yet its swing's own path, and not hot; as the player's)
		u = u_new
		return
	var n := 3
	var frames: Array = []
	for k in n + 1:
		var c := _clip(lerpf(u, u_new, float(k) / n))
		# (the axe as its swing's clips hold it, not as it shows easing between the holds)
		frames.append(sk.global_transform * MeleeSweep.clip_bone(sk, c[0], c[1], PROP) * (BLADE if _frame == "blade" else PIPE))
	var pts := _points()
	var skip_areas: Array = [weapon.get_rid()]
	skip_areas.append_array(_glanced)
	var skip: Array = [_torso.get_rid(), _head.get_rid()]
	skip.append_array(_passed)
	var c := MeleeSweep.first_contact(get_world_3d().direct_space_state, frames, pts, skip, skip_areas)
	# (a defender's block, met in the space between them before the blow reaches anything; as the player's)
	var near := MeleeSweep.near_defender(get_world_3d().direct_space_state, frames, pts, self)
	if not near.is_empty() and (c.is_empty() or int(near.k) < int(c.k) or int(near.k) == int(c.k) and float(near.f) <= float(c.f)):
		var nway := (near.motion as Vector3).normalized()
		var nb := _block(near.foe, near.point, nway)
		if nb >= AxeMelee.BLOCK_FULL:
			var nk: int = near.k
			u = lerpf(lerpf(u, u_new, float(nk - 1) / n), lerpf(u, u_new, float(nk) / n), float(near.f))
			_stop("weapon", near.point, -nway, null, true)
			last_contact["blocked"] = nb
			if near.foe.has_method(&"clash"):
				near.foe.clash(near.point, nway, weapon)
			return
	if c.is_empty():
		u = u_new
		return
	var k: int = c.k
	var hit_u := lerpf(lerpf(u, u_new, float(k - 1) / n), lerpf(u, u_new, float(k) / n), float(c.f))
	var col: Object = c.collider
	var w: WeaponBody = c.weapon
	var way := ((c.to as Vector3) - (c.from as Vector3)).normalized()
	# (a defender: its weapon held to defend, or its body, turns the blow aside by what it is doing)
	var foe: Object = w.holder if w else MeleeSweep.defender_of(col)
	var motion: Vector3 = (frames[k] as Transform3D) * (pts.head as Vector3) - (frames[k - 1] as Transform3D) * (pts.head as Vector3)
	if w and not MeleeSweep.coming_at(foe, c.position, motion):
		# (drawn back past the other's parry, not coming at them: it passes)
		_glanced.append(w.get_rid())
		u = u_new
		return
	var b := 1.0 if w and (foe == null or not foe.has_method(&"block_power")) else 0.0
	if foe != null and foe != self and foe.has_method(&"block_power"):
		b = _block(foe, c.position, way)
	if b >= AxeMelee.BLOCK_FULL:
		u = maxf(hit_u - AxeMelee.BLOCK_BACK_S * _rate, 0.0)
		_stop("weapon", c.position, -way, col, true)
		last_contact["blocked"] = b
		if foe != null and foe.has_method(&"clash"):
			foe.clash(c.position, way, weapon)
		return
	if w:
		# turned only partly aside: it glances off and goes on
		_glanced.append(w.get_rid())
		u = u_new
		return
	var surface := "flesh" if col is CharacterBody3D else Sfx.surface_of(col, c.position, c.normal)
	var glance: float = last_contact.get("glance", 0.0) if b > 0.0 else 0.0
	if surface in AxeMelee.THROUGH and AxeMelee._takes_hits(col):
		# its blow lands (the first to land wins the exchange: the one struck flinches, its own swing lost) and goes on
		# through the body (user 2026-09-27: "have the strike if hit go thru the body"), as the player's
		var landed := false
		if _damage > 0.0 and (col as CollisionObject3D).get_rid() not in _passed:
			landed = Hit.deliver(col, _damage * (1.0 - glance), c.position, way, self, false)
			if landed and surface == "flesh":
				BloodFx.hit(get_tree().current_scene, c.position, way, c.normal, _damage * (1.0 - glance) / 40.0,
						AxeMelee._receiver(col))
		_passed.append((col as CollisionObject3D).get_rid())
		last_contact = {"surface": surface, "point": c.position, "collider": col, "u": hit_u, "through": true, "landed": landed}
		if glance > 0.0:
			last_contact["glance"] = glance
		MeleeSweep.sound(surface, c.position)
		u = u_new
		return
	u = hit_u
	_stop(surface, c.position, c.normal, col, true)
	if glance > 0.0:
		last_contact["glance"] = glance


func _stop(surface: String, point: Vector3, normal: Vector3, col: Object, loud: bool) -> void:
	_prm = MeleeSweep.params(surface)
	state = "stop"
	_left = float(_prm.stop_s)
	last_contact = {"surface": surface, "point": point, "collider": col, "u": u}
	if surface == "weapon":
		clashed += 1
	if loud:
		MeleeSweep.sound(surface, point)
	if surface in ["weapon", "stone"]:
		MeleeSweep.spark(get_tree().current_scene, point, normal)


func _clip(at: float) -> Array:
	if at < _intro.length:
		return [_intro, maxf(at, 0.0)]
	return [_hit, minf(at - _intro.length, _hit.length)]


func _show() -> void:
	if ap == null:
		return
	var nm := ""
	var t := 0.0
	if state == "flinch":
		nm = _flinch_nm
		t = _flinch_t
	else:
		var c := _clip(u)
		nm = "own/" + String(_names[0] if c[0] == _intro else _names[1])
		t = float(c[1])
	if ap.current_animation != nm:
		ap.play(nm)
	ap.seek(t, true)
	# (easing from the pose it was in: a swing begun, the flinch in and out)
	if _fade_left > 0.0 and _from_pose.size() == sk.get_bone_count():
		var k := smoothstep(0.0, 1.0, 1.0 - _fade_left / maxf(_fade_s, 1e-4))
		for i in sk.get_bone_count():
			var f: Array = _from_pose[i]
			sk.set_bone_pose_position(i, (f[0] as Vector3).lerp(sk.get_bone_pose_position(i), k))
			sk.set_bone_pose_rotation(i, (f[1] as Quaternion).slerp(sk.get_bone_pose_rotation(i), k))
			sk.set_bone_pose_scale(i, (f[2] as Vector3).lerp(sk.get_bone_pose_scale(i), k))


## Back on guard (the D swing's first pose, whatever it did: a swing's own first pose is not the guard, the stab's
## and A's least of all), eased there from the pose it is in.
func _on_guard() -> void:
	state = ""
	u = 0.0
	_use("D")
	_ease_from(BACK_S)


## Eases from the pose shown now over `s` s.
func _ease_from(s: float) -> void:
	if sk == null:
		return
	_from_pose = []
	for i in sk.get_bone_count():
		_from_pose.append([sk.get_bone_pose_position(i), sk.get_bone_pose_rotation(i), sk.get_bone_pose_scale(i)])
	_fade_s = s
	_fade_left = s


func _points() -> Dictionary:
	if _pts.is_empty():
		var inv := axe.global_transform.affine_inverse()
		for pair: Array in [["edge", "Edge", Vector3(0, 0.8, -0.17)], ["head", "Head", Vector3(0, 0.8, 0)],
				["grip", "Grip", Vector3(0, 0.46, 0)]]:
			var mk := axe.get_node_or_null(String(pair[1])) as Node3D
			_pts[pair[0]] = inv * mk.global_position if mk else pair[2]
		_pts["butt"] = Vector3.ZERO
	return _pts


# --- its body -----------------------------------------------------------------------------------------------------

func _part(part: String, mult: float, shape: Shape3D) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Hit_" + part
	b.top_level = true
	b.set_meta("hit_part", part)
	b.set_meta("damage_mult", mult)
	b.set_meta("surface", "flesh")
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	add_child(b)
	return b


## The torso along the spine (the pelvis to the neck), the head on the head bone.
func _place_body() -> void:
	var g := sk.global_transform
	var a := g * sk.get_bone_global_pose(sk.find_bone("pelvis")).origin
	var b := g * sk.get_bone_global_pose(sk.find_bone("neck")).origin
	var up := (b - a).normalized()
	var x := up.cross(Vector3.FORWARD)
	x = x.normalized() if x.length_squared() > 1e-4 else Vector3.RIGHT
	_torso.global_transform = Transform3D(Basis(x, up, x.cross(up)), (a + b) * 0.5)
	_head.global_position = g * (sk.get_bone_global_pose(sk.find_bone("headb")).origin + Vector3(0, 0.08, 0))


static func _capsule(r: float, h: float) -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = h
	return c


static func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s
