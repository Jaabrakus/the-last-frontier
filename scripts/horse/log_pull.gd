class_name LogPull
extends Node
## Dragging a log on foot with both hands, walking backward, and laying it as a barricade log (user 2026-09-27:
## "allow to drag fallen trees as well and the ability to cut the branches off trees to make it into a log so if
## they have to make a wall against a raid"; "Log barricade": lay cut logs down as a breastwork, stacked 2-3 high).
##
## E at either end of a loose log (a limbed trunk, GatherTools' Limb, or a bole a horse left) with no horse by it:
## "Drag the white pine log (about 140 kg)". The gun or the axe goes on the back (a torch back into the pack: both
## hands are on the log), the player turns to the log's end, takes hold (actor_b-p-idle^push-pull-idle) and pulls it walking
## backward, the source's push-pull clips over the kneeling hand-off (FrontierPlayer.begin_kneel: the camera turns
## freely, the body keeps facing the log):
##   S          back, away from the log (actor_b-p-pull-bw)
##   A / D      sideways, the log swinging round after (actor_b-p-pull-bw-lt / -rt, blended with it by the direction)
##   W          nothing: a log is not pushed
## The pull (SkidLoad.pull_kgf: its weight on the ground and the slope; haul.json "foot_log", game values) sets the
## pace: a light log a little over the clip's own step, one 2.4 m length of a middling pine at a crawl, anything heavier
## slower still, down to an extreme crawl (nothing is refused; the prompt says "very slow"). A limbed trunk bucks into
## 2.4 m lengths (SkidLoad.buck); the horse drags a whole trunk far quicker.
##
## E lays it: straight and level where it is ("Lay the log down"), or, against a laid log, on top of it and parallel
## ("Stack the log on the barricade"), up to BARRICADE_MAX high (crouch behind two, stand and shoot over three). A
## laid log stays put (SkidLoad.laid; saved); E at an end of the top one drags it again. A jump, a weapon key, a heavy
## hit or death let go: the log lies loose where it is.
## Every player has one (FrontierPlayer: log_pull). The logs are the project's own models.

const LIB := "actor_b"
const CLIP_TAKE := "actor_b-p-idle^push-pull-idle"
const CLIP_IDLE := "actor_b-p-push-pull-idle"
const CLIP_PULL := "actor_b-p-pull-bw"
const CLIP_LET_GO := "actor_b-p-push-pull-idle^idle"
## The pull clips' own body speeds (m/s; foot contacts, measured as tools/anim_graph/measure_clips.gd method A):
## straight back, and the sideways steps.
const PULL_BW_MPS := 0.52
const PULL_SIDE_MPS := 0.64
## Seconds of the take-hold and let-go clips played.
const TAKE_S := 0.9
const LET_GO_S := 0.45
## The body turns to face the log's end at this rate (1/s).
const TURN_RATE := 5.0
## Logs in a barricade stack at most.
const BARRICADE_MAX := 3
## The rope grabbed at arm's length is taken up to rope_m at this rate (m/s).
const REEL_MPS := 0.8
## An E waits this long for busy hands (s).
const PENDING_S := 1.5
## At a log's end this near (m) E is the pull's, not the axe's Buck.
const END_M := 1.2
## Ends further off the view than this (deg) are not offered (the interactor's cone is 55).
const VIEW_DEG := 60.0

var player: FrontierPlayer
## The log in the hands, or null.
var load: SkidLoad = null
var interact_reach := 1.8
## The pace the pull gives (m/s; INF with no log).
var cap := INF
## "take", "pull", "let_go" ("" when not pulling); tests.
var phase := ""
## Why the last pull ended ("lay", "stack", "jump", "weapon", "hit", "died", "kneeling", "gone"); tests.
var last_let_go := ""
## This tick's move (x sideways right, y back, 0..1); tests.
var moving := Vector2.ZERO
## The laid log E would stack this one on now (null: lay it on the ground).
var stack_on: SkidLoad = null
## Both palms after every modifier (global; Skeleton3D.skeleton_updated).
var hands_final := Vector3.INF

var _offer := {}
## An E while the hands were busy (a gun being drawn): {log, end, t}, taken when they are free.
var _pending := {}
var _ap: AnimationPlayer
var _blender: HorsePhaseBlender
var _t := 0.0
var _pt := 0.0
var _it := 0.0
var _vy := 0.0
var _lp := -1
var _rp := -1
var _mi: MeshInstance3D
var _mesh: ImmediateMesh
var _exceptions: Array[PhysicsBody3D] = []


static func install(p: FrontierPlayer) -> LogPull:
	var l := LogPull.new()
	l.name = "LogPull"
	l.player = p
	p.add_child(l)
	return l


static func cfg() -> Dictionary:
	return HorseHaul.data().get("foot_log", {})


## The pace (m/s) for a pull of `kgf` with both hands (haul.json "foot_log"). Never 0: past max_kgf it falls as
## max_kgf / kgf toward extreme_mps (user 2026-09-27: too heavy "just make it where it is extreme slow").
static func cap_for(kgf: float) -> float:
	var c := cfg()
	var easy := float(c.get("easy_kgf", 40.0))
	var walk := float(c.get("walk_kgf", 80.0))
	var hard := float(c.get("hard_kgf", 130.0))
	var mx := float(c.get("max_kgf", 170.0))
	var e_v := float(c.get("cap_easy_mps", 0.65))
	var w_v := float(c.get("cap_walk_mps", 0.52))
	var h_v := float(c.get("cap_hard_mps", 0.36))
	var crawl := float(c.get("cap_crawl_mps", 0.2))
	if kgf <= easy:
		return e_v
	if kgf <= walk:
		return lerpf(e_v, w_v, (kgf - easy) / (walk - easy))
	if kgf <= hard:
		return lerpf(w_v, h_v, (kgf - walk) / (hard - walk))
	if kgf <= mx:
		return lerpf(h_v, crawl, (kgf - hard) / (mx - hard))
	return maxf(crawl * mx / kgf, float(c.get("extreme_mps", 0.05)))


## A log of `kg` past max_kgf on the level (along it, haul.json mu_axial): pulled at a crawl or slower (the prompt
## says so).
static func very_heavy(kg: float) -> bool:
	return kg * float(HorseHaul.data().get("mu_axial", 0.4)) > float(cfg().get("max_kgf", 170.0))


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	process_physics_priority = 5            # after the player (kneeling: it stands still), before the log
	interact_reach = float(cfg().get("reach_m", 1.8))
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "Rope"
	_mi.mesh = _mesh
	_mi.top_level = true
	_mi.visible = false
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	if player:
		player.hurt.connect(_on_hurt)
	_hook_skeleton.call_deferred()


func _hook_skeleton() -> void:
	var sk := player.skeleton if player else null
	if sk == null:
		return
	_lp = sk.find_bone("l_palm")
	_rp = sk.find_bone("r_palm")
	sk.skeleton_updated.connect(_on_skeleton_updated)


func _on_skeleton_updated() -> void:
	var sk := player.skeleton
	if sk and _lp >= 0 and _rp >= 0:
		hands_final = sk.global_transform * ((sk.get_bone_global_pose(_lp).origin + sk.get_bone_global_pose(_rp).origin) * 0.5)


# --- What pulls (SkidLoad's side) ----------------------------------------------------------------------------

## The rope's end in both hands (global); in front of the chest without the rig.
func hitch_point() -> Vector3:
	if hands_final != Vector3.INF and hands_final.distance_to(player.global_position) < 2.0:
		return hands_final
	return player.global_position + Vector3.UP * 0.9 - player.global_basis.z * 0.4


func puller() -> CollisionObject3D:
	return player


func puller_speed() -> float:
	return player.horizontal_speed()


func unhitch() -> Node3D:
	_drop("gone")
	return null


# --- Pulling -------------------------------------------------------------------------------------------------

## Takes log `s` by end `end` (0 front, 1 back). False when it cannot be taken now.
func start(s: SkidLoad, end := 0) -> bool:
	if load != null or phase != "" or s == null or not is_instance_valid(s) or player.pushing != null:
		return false
	if s.hitched or s.bundle > 0 or s is CarcassLoad or (s.laid and not s.resting_on_me().is_empty()):
		return false
	if player.gather and player.gather.in_hand() != "":
		player.gather.drop_now()             # the axe onto the back: both hands on the log
	var torch := player.torch
	if torch and torch.holding():
		torch.put_away()
		_notice("Both hands on the log: the torch goes back in the pack")
	var face := s.front if end == 0 else s.back
	_ap = player.begin_kneel(self, face)
	if _ap == null:
		if player.is_switching() and _pending.is_empty():
			_pending = {"log": s, "end": end, "t": PENDING_S}   # a gun still coming to the hands: taken after it
			return true
		if _pending.is_empty():
			_notice("Your hands are busy")
		return false
	_pending = {}
	if end == 1:
		s.swap_ends()
	# taut from the start (as long as the reach, taken up to rope_m if longer): a heavy log at a crawl moves at once
	var rope := float(cfg().get("rope_m", 0.9))
	s.hitch(self, clampf(hitch_point().distance_to(s.front), 0.6, rope + 1.2))
	load = s
	_exceptions.clear()
	if s.body:
		player.add_collision_exception_with(s.body)
		_exceptions.append(s.body)
	_blender = HorsePhaseBlender.new(_ap, player, LIB)
	_blender.turn_suffix = ["-lt", "-rt"]
	phase = "take"
	_t = 0.0
	_pt = 0.0
	_it = 0.0
	_vy = 0.0
	_blender.show_clip(CLIP_TAKE, 0.0, 0.2)
	_blender.update(0.0)
	_notice("Pulling the %s: S back, A / D sideways, E lays it down" % s.load_name())
	return true


## E: lays the log where it is, or on the barricade log beside it (stack_on).
func lay() -> void:
	var s := load
	if s == null or not is_instance_valid(s):
		return
	var under := stack_on
	var L := s.length
	var ax := s.back - s.front
	var dir := Vector3(ax.x, 0.0, ax.z)
	dir = dir.normalized() if dir.length() > 1e-4 else -player.global_basis.z
	var f: Vector3
	var b: Vector3
	if under != null and is_instance_valid(under):
		var u3 := (under.back - under.front).normalized()
		if Vector3(u3.x, 0.0, u3.z).dot(dir) < 0.0:
			u3 = -u3
		var m := s.mid()
		var uax := under.back - under.front
		var uaxh := Vector3(uax.x, 0.0, uax.z)
		var t := clampf(Vector3(m.x - under.front.x, 0.0, m.z - under.front.z).dot(uaxh) / maxf(uaxh.length_squared(), 1e-6), 0.0, 1.0)
		var c := under.front + uax * t + Vector3.UP * (under.mean_radius() + s.mean_radius()) * 0.95
		f = c - u3 * L * 0.5
		b = c + u3 * L * 0.5
	else:
		var space := s.get_world_3d().direct_space_state
		var m := s.mid()
		f = m - dir * L * 0.5
		b = m + dir * L * 0.5
		f.y = s._ground_h(space, f) + s.r_front
		b.y = s._ground_h(space, b) + s.r_back
	var why := "stack" if under != null else "lay"
	_release()
	s.lay_at(f, b)
	last_let_go = why
	_let_go_anim()


## Lets the log go where it is (loose: it settles).
func _drop(why: String) -> void:
	if load == null:
		return
	last_let_go = why
	_release()
	if why in ["died", "kneeling", "gone"]:
		_end()
	else:
		_let_go_anim()


func _release() -> void:
	var s := load
	load = null
	cap = INF
	stack_on = null
	moving = Vector2.ZERO
	for b in _exceptions:
		if is_instance_valid(b):
			player.remove_collision_exception_with(b)
	_exceptions.clear()
	if s and is_instance_valid(s):
		s.unhitch()


func _let_go_anim() -> void:
	phase = "let_go"
	_t = 0.0
	if _blender:
		_blender.show_clip(CLIP_LET_GO, 0.0, 0.2)


## Up from the log: the player's own animation back (and the gun, FrontierPlayer.end_kneel).
func _end() -> void:
	phase = ""
	if _blender and is_instance_valid(_blender.tree):
		_blender.tree.active = false
		_blender.tree.queue_free()
	_blender = null
	if player and player.kneeling == self:
		player.end_kneel()


func _on_hurt(_dir: Vector2, _amount: float, heavy: bool) -> void:
	if heavy and load != null:
		_drop("hit")


func _let_go_reason() -> String:
	if player.is_dead:
		return "died"
	if player.kneeling != self:
		return "kneeling"
	if not player.hands_free:
		return "weapon"
	if Input.is_action_just_pressed("jump"):
		return "jump"
	return ""


func _physics_process(dt: float) -> void:
	if player == null:
		return
	if load != null and not is_instance_valid(load):
		load = null
		_drop("gone")
	if load != null:
		var why := _let_go_reason()
		if why != "":
			_drop(why)
	match phase:
		"":
			if not _pending.is_empty():
				_pending.t = float(_pending.t) - dt
				var pl: Variant = _pending.get("log")
				if float(_pending.t) <= 0.0 or not is_instance_valid(pl) or player.is_dead:
					_pending = {}
				elif not player.is_switching():
					var pe := int(_pending.end)
					_pending = {}
					start(pl, pe)
					return
			_offer = _find_offer()
			return
		"take":
			_t += dt
			_blender.show_clip(CLIP_TAKE, minf(_t, _len(CLIP_TAKE)), 0.2)
			_face(dt)
			if load != null:
				# the rope kept just taut while the hands come to it (the rope sim measures to the log's end)
				load.chain_len = clampf(hitch_point().distance_to(load.front), 0.6, float(cfg().get("rope_m", 0.9)) + 1.2)
			if _t >= TAKE_S:
				phase = "pull"
		"pull":
			_pull(dt)
		"let_go":
			_t += dt
			_blender.show_clip(CLIP_LET_GO, minf(_t, _len(CLIP_LET_GO)), 0.2)
			if _t >= LET_GO_S or player.is_dead or player.kneeling != self:
				_end()
				return
	if load != null:
		var rope := float(cfg().get("rope_m", 0.9))
		if load.chain_len > rope:
			load.chain_len = move_toward(load.chain_len, rope, REEL_MPS * dt)
		cap = cap_for(load.pull_kgf)
		stack_on = _find_stack()
	if _blender:
		_blender.update(dt)


## The body turns toward the log's end (the camera does not: kneeling's orbit).
func _face(dt: float) -> void:
	if load == null:
		return
	var d := load.front - player.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var want := atan2(-d.x, -d.z)
	player.rotation.y = lerp_angle(player.rotation.y, want, 1.0 - exp(-TURN_RATE * dt))


func _pull(dt: float) -> void:
	_face(dt)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Basis(Vector3.UP, player.yaw) * Vector3(input.x, 0.0, input.y)
	var bf := -player.global_basis.z
	bf.y = 0.0
	bf = bf.normalized()
	var br := player.global_basis.x
	br.y = 0.0
	br = br.normalized()
	var back := maxf(-wish.dot(bf), 0.0)
	var side := wish.dot(br)
	var mv := Vector2(side, back).limit_length(1.0)
	moving = mv
	var n := mv.length()
	var sidew := absf(side) / maxf(n, 1e-3)
	var nat := lerpf(PULL_BW_MPS, PULL_SIDE_MPS, sidew)
	var v := cap * n if n > 0.05 else 0.0
	var dir := (-bf * back + br * side)
	dir = dir.normalized() if dir.length() > 1e-4 else Vector3.ZERO
	if player.is_on_floor():
		_vy = -0.5
	else:
		_vy -= 9.8 * dt
	player.velocity = Vector3(dir.x * v, _vy, dir.z * v)
	player.move_and_slide()
	if v < 0.03:
		_it += dt
		_blender.show_clip(CLIP_IDLE, fposmod(_it, _len(CLIP_IDLE)), 0.3)
	else:
		var rate := v / nat
		_pt += dt * rate
		# Blend3's +1 is the left step (-lt), -1 the right (-rt)
		_blender.show_clip(CLIP_PULL, fposmod(_pt, _len(CLIP_PULL)), 0.3, rate, "", 0.0, clampf(-side / maxf(n, 1e-3), -1.0, 1.0))


func _len(clip: String) -> float:
	var full := "%s/%s" % [LIB, clip]
	return _ap.get_animation(full).length if _ap and _ap.has_animation(full) else 1.0


func _process(_delta: float) -> void:
	_draw_rope()


# --- The barricade -------------------------------------------------------------------------------------------

## The laid log beside the one in the hands that it would go on top of (null: none, or its stack is full): the log
## in the hands lies along it (within 35 deg), over its length, less than the two radii and a little apart beside it.
func _find_stack() -> SkidLoad:
	if load == null:
		return null
	var m := load.mid()
	var ax := load.back - load.front
	var axh := Vector3(ax.x, 0.0, ax.z).normalized()
	var best: SkidLoad = null
	var bd := INF
	for n in get_tree().get_nodes_in_group(FelledTree.GROUP):
		var u := n as SkidLoad
		if u == null or u == load or not u.laid or u.is_queued_for_deletion():
			continue
		var ua := u.back - u.front
		var uah := Vector3(ua.x, 0.0, ua.z)
		if uah.length() < 0.1 or absf(uah.normalized().dot(axh)) < cos(deg_to_rad(35.0)):
			continue
		var t := Vector3(m.x - u.front.x, 0.0, m.z - u.front.z).dot(uah) / uah.length_squared()
		if t < -0.1 or t > 1.1:
			continue
		var on := u.front + ua * clampf(t, 0.0, 1.0)
		var side := Vector2(m.x - on.x, m.z - on.z).length()
		if side > u.mean_radius() + load.mean_radius() + 0.6 or side >= bd:
			continue
		if u.stack_level() >= BARRICADE_MAX or not u.resting_on_me().is_empty():
			continue
		bd = side
		best = u
	return best


# --- E -------------------------------------------------------------------------------------------------------

## On foot at an end of a loose log (or the top log of a barricade), nothing in the hands: {kind, point, log, end,
## text}, or {}.
func _find_offer() -> Dictionary:
	var p := player
	if p.is_dead or p.riding != null or p.kneeling != null or p.pushing != null:
		return {}
	var best := {}
	var bd := INF
	var view := _view_dir()
	for n in get_tree().get_nodes_in_group(FelledTree.GROUP):
		var s := n as SkidLoad
		if s == null or s is CarcassLoad or s.bundle > 0 or s.hitched or s.state != FelledTree.State.DOWN or s.is_queued_for_deletion() \
				or s.has_meta(&"in_barrow"):
			continue
		for e in 2:
			var pt: Vector3 = s.front if e == 0 else s.back
			var flat := _flat(pt, p.global_position)
			if flat > interact_reach:
				continue
			# the end looked at, as the interactor scores (off the view, then how far); of a stack's ends one over
			# another, the top one (the one that can be taken)
			var to := Vector3(pt.x - p.global_position.x, 0.0, pt.z - p.global_position.z)
			var ang := rad_to_deg(view.angle_to(to.normalized())) if to.length() > 0.35 else 0.0
			if ang > VIEW_DEG:
				continue
			var d := flat / interact_reach + ang / VIEW_DEG - 0.1 * (pt.y - p.global_position.y)
			if d >= bd:
				continue
			if _horse_offers(s):
				continue
			bd = d
			best = {"point": pt, "log": s, "end": e}
	if best.is_empty():
		return {}
	var s: SkidLoad = best.log
	var nm := s.load_name()
	best["horse"] = _horse_offering()
	if s.laid and not s.resting_on_me().is_empty():
		best["kind"] = "blocked"
		best["text"] = "Take the top log off first"
	else:
		best["kind"] = "drag"
		best["text"] = "Drag the %s log (about %d kg%s)" % [nm, roundi(s.mass_kg), ": very slow" if very_heavy(s.mass_kg) else ""]
	return best


func _horse_offering() -> bool:
	for n in get_tree().get_nodes_in_group(PlacedWeapon.GROUP):
		if n is HorseHaul and (n as HorseHaul).offering():
			return true
	return false


func _horse_offers(s: Node) -> bool:
	for n in get_tree().get_nodes_in_group(PlacedWeapon.GROUP):
		if n is HorseHaul and (n as HorseHaul).offers(s):
			return true
	return false


func interact_point() -> Vector3:
	if load != null:
		return player.global_position + Vector3.UP * 1.3 - player.global_basis.z * 0.2
	return _offer.get("point", Vector3.INF)


## In the hands, E is this (0 at the chest); within END_M of an end a drag wins over the axe's Buck at the same log
## (as the horse's hitch does); along the log the axe's does. Only telling (logs on it), or with the horse offering
## something here (its Unhitch by a load), it does not push anything else aside.
func distance_from(pt: Vector3) -> float:
	if load != null:
		return 0.0
	if _offer.is_empty():
		return INF
	var d := _flat(pt, _offer.point)
	if String(_offer.get("kind", "")) != "drag" or bool(_offer.get("horse", false)):
		return d                             # the horse's E here comes first (its unhitch by a load)
	return maxf(d - END_M, 0.0)


func interact_prompt(_p: Node) -> String:
	if load != null:
		if phase != "pull":
			return ""
		return "Stack the log on the barricade" if stack_on != null else "Lay the log down"
	return String(_offer.get("text", ""))


func highlight_targets() -> Array:
	return []


func interact(_p: Node) -> bool:
	if load != null:
		if phase == "pull":
			lay()
			return true
		return false
	match String(_offer.get("kind", "")):
		"drag":
			return start(_offer.log, int(_offer.end))
		"blocked":
			_notice(String(_offer.text))
	return false


func _draw_rope() -> void:
	var on := load != null and is_instance_valid(load) and DisplayServer.get_name() != "headless"
	_mi.visible = on
	if not on:
		return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, CarcassLoad.rope_material())
	HorseHaul.ribbon(_mesh, HorseHaul.sag(hitch_point(), load.chain_point(), load.chain_len + 0.01, 12), 0.022, 0.011)
	_mesh.surface_end()


func _view_dir() -> Vector3:
	var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	var f := -cam.global_basis.z if cam else -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 1e-4 else Vector3.FORWARD


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _notice(text: String) -> void:
	var it: Node = player.get("interactor") if player else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 2.5)
