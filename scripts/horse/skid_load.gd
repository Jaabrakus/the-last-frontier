class_name SkidLoad
extends FelledTree
## A load a horse drags on a chain (HorseHaul): the limbed bole of a felled tree, chained by one end, or a
## bundle of logs from the pack with the chain round it. Log skidding, the period's way of getting timber out
## of the woods where there is no road for a cart and no snow for a sled (user 2026-09-26: "we need a wagon or
## a AI where we can get the horse to pull a chopped tree").
##
## The load is a rigid rod between its two ends, moved by position Verlet at the physics rate:
##  - the chain holds the front end within chain_len of the horse's hitch point (Horse.get_hitch_point());
##    it goes slack when the horse stops or backs toward the load;
##  - gravity, and the ground under each end and three points between (a ray down: the terrain, stumps, the
##    vegetation's logs, low rocks, a floor; FrontierTerrain where the ray finds nothing): the log rides up
##    over a stump or a rock and drops off it, so it bumps and hops over rough ground;
##  - Coulomb friction where it lies on the ground, less along the log than across it (haul.json mu_axial,
##    mu_lateral): it slides end first, so on a turn the tail cuts the corner and swings behind (it snakes);
##  - standing trees, rocks and buildings push it out sideways (a shape query each tick): it slides round a
##    trunk, and pulled square into one it is caught (stretch > 0: HorseHaul stops the horse).
## pull_kgf is what it takes to drag it now (friction across and along the log, and the slope), which
## HorseHaul turns into the horse's speed cap.
##
## It is a FelledTree (group felled_trees), so a bole lying unhitched is bucked into logs with the axe as
## before (GatherTools): each log bucked off shortens it from the far end. It was limbed when it was
## chained, so the last log leaves no crown. A bundle is not bucked; unhitched it is laid down as a LogPile.
## The models are the project's own (the vegetation's bark textures, the gathering's end grain).

const SAMPLES := [0.0, 0.25, 0.5, 0.75, 1.0]
## The choker (the chain's loop round the log) sits this far from the chained end (m).
const CHOKER_M := 0.3
## A ray down from this far over the log's axis finds the ground: anything higher is an obstacle, not ground.
const STEP_UP := 0.6
## Lifted by the ground (a stump's edge, a rock) an end keeps at most this upward speed (m/s): it hops a
## little over a bump instead of flying off it.
const HOP_V := 1.2
## Worked free after a jam: the load is moved sideways at this speed (m/s), off the line of the pull.
const FREE_V := 0.45
## At most this much push across the log out of an obstacle per pass (m): a deep contact resolves over a
## few passes.
const MAX_PUSH := 0.08
## The chain draws the end at most this far per pass (m).
const CHAIN_STEP := 0.05

## haul.json (HorseHaul.data()).
var cfg := {}
## 0: the bole of a felled tree; n > 0: a bundle of n logs from the pack.
var bundle := 0
var hitched := false
## The HorseHaul that has it on its chain (null: lying loose).
var haul: Node = null
var chain_len := 2.4
## The ends of the rod (the log's axis, global): the chained end and the far end.
var front := Vector3.ZERO
var back := Vector3.ZERO
var r_front := 0.3
var r_back := 0.25
var mass_kg := 500.0
## What it takes to drag it now (kgf), smoothed.
var pull_kgf := 0.0
## How far the chain is drawn past its length (m): > 0 while the load is held (caught on a tree).
var stretch := 0.0
var grounded := false
## Turn about its own axis (rad): a log dragged sideways rolls.
var roll := 0.0
## Contacts with standing obstacles in the last tick (tests).
var obstacle_hits := 0
## Microseconds the last step took (tests, the cost of a load).
var sim_usec := 0
var body: AnimatableBody3D
## Laid down as a barricade log (LogPull; user 2026-09-27: "a wall against a raid"): set straight and level where it
## was put, on the ground or on another laid log, and no longer simulated (a stack stays put). Dragging, hitching or
## bucking it wakes it, and whatever rests on it.
var laid := false

var _log_len := 2.4
var _prev := [Vector3.ZERO, Vector3.ZERO]
var _mesh_root: Node3D
var _visuals := true
var _rest_ticks := 0
var _free_t := 0.0
var _query: PhysicsShapeQueryParameters3D
var _qshape: CylinderShape3D
var _ray: PhysicsRayQueryParameters3D
var _hs: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _hs_last: Array[float] = [INF, INF, INF, INF, INF]
var _lift: Array[float] = [0.0, 0.0]
var _push: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _free_side := 1.0
var _last_lat := Vector3.ZERO
static var _bark_mats := {}


## The bole of a felled tree (DOWN), limbed and topped: what is left of its clear bole after the logs bucked
## off it (logs_left x log_len), tapering from the butt. Not in the tree yet; the caller adds it and frees `ft`.
static func from_felled(ft: FelledTree, c: Dictionary, log_len: float, visuals: bool) -> SkidLoad:
	var s := SkidLoad.new()
	s.name = "SkidLog_%d" % int(ft.info.get("i", 0))
	s.info = ft.info.duplicate()
	s._cfg = ft._cfg
	s.cfg = c
	s._log_len = log_len
	s._visuals = visuals
	s.cut_work = ft.cut_work
	s.hardness = ft.hardness
	s.logs_total = maxi(ft.logs_left, 1)
	s.logs_left = s.logs_total
	s.state = State.DOWN
	var L := float(s.logs_left) * log_len
	var radii := bole_radii(ft.info, L, c)
	s.r_front = radii.x
	s.r_back = radii.y
	s.front = ft.hinge
	s.back = ft.hinge + ft.axis() * L
	s._setup(L)
	return s


## A bundle of `n` logs from the pack (haul.json pack_log), its chained end at `at`, lying toward `dir`.
static func make_bundle(n: int, at: Vector3, dir: Vector3, c: Dictionary, visuals: bool) -> SkidLoad:
	var s := SkidLoad.new()
	s.name = "LogBundle"
	var pl: Dictionary = c.get("pack_log", {})
	var L := float(pl.get("length_m", 2.4))
	var r := float(pl.get("radius_m", 0.15))
	s.bundle = maxi(n, 1)
	s.cfg = c
	s._log_len = L
	s._visuals = visuals
	s.info = {"species": String(pl.get("species", "white_pine")), "name": "logs", "radius": r}
	s.logs_total = s.bundle
	s.logs_left = s.bundle
	s.state = State.DOWN
	s.r_front = r
	s.r_back = r
	var d := Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 1e-4 else Vector3.BACK
	s.front = at
	s.back = at + d * L
	s._setup(L)
	return s


## Butt and top radius of a bole of length L (m): the trunk's radius at the butt, tapering by taper_m_per_m.
static func bole_radii(tree_info: Dictionary, L: float, c: Dictionary) -> Vector2:
	var r0 := float(tree_info.get("radius", 0.3)) * 0.95
	var r1 := maxf(r0 - float(c.get("taper_m_per_m", 0.007)) * L, r0 * float(c.get("top_radius_min_frac", 0.55)))
	return Vector2(r0, r1)


## Green weight (kg) of a bole: a frustum of the species' green density.
static func bole_mass(tree_info: Dictionary, L: float, c: Dictionary) -> float:
	var r := bole_radii(tree_info, L, c)
	var v := PI * L / 3.0 * (r.x * r.x + r.x * r.y + r.y * r.y)
	return v * density(c, String(tree_info.get("species", "")))


static func density(c: Dictionary, species: String) -> float:
	var t: Dictionary = c.get("density_kg_m3", {})
	return float(t.get(species, t.get("default", 800.0)))


func _setup(L: float) -> void:
	add_to_group(GROUP)
	process_physics_priority = 10       # after the horse has moved this tick
	length = L
	info["crown_bottom"] = L
	_compute_mass()
	_prev = [front, back]
	chain_len = float(cfg.get("chain_m", 2.4))
	body = AnimatableBody3D.new()
	body.name = "Body"
	body.sync_to_physics = false
	body.add_to_group(FrontierVegetation.LOW_GROUP)
	body.set_meta(&"surface", "wood")
	add_child(body)
	_build_shape()
	if _visuals:
		_build_mesh()
	_apply_skid_pose()


func _compute_mass() -> void:
	if bundle > 0:
		mass_kg = float(bundle) * PI * r_front * r_front * length * density(cfg, String(info.get("species", "")))
		info["radius"] = r_front
	else:
		mass_kg = PI * length / 3.0 * (r_front * r_front + r_front * r_back + r_back * r_back) * density(cfg, String(info.get("species", "")))
		info["radius"] = (r_front + r_back) * 0.5


## "white pine", "6 logs".
func load_name() -> String:
	if bundle > 0:
		return "%d logs" % bundle if bundle > 1 else "log"
	return species_name()


# --- Chain -------------------------------------------------------------------------------------------

## On the chain of `h`, `len_m` long: a HorseHaul, or a FootDrag (the player's hand). What pulls gives hitch_point(),
## puller() (its body, not ground under the load) and puller_speed() (m/s), and has `load` and unhitch().
func hitch(h: Node, len_m: float) -> void:
	if laid:
		unlay()
	haul = h
	hitched = true
	chain_len = len_m
	_rest_ticks = 0
	_jam_reset()
	pull_kgf = mass_kg * float(cfg.get("mu_axial", 0.4))     # it takes the start of the pull at once


func unhitch() -> void:
	haul = null
	hitched = false
	stretch = 0.0
	_rest_ticks = 0


## Chain the other end: the far end becomes the front.
func swap_ends() -> void:
	var t := front
	front = back
	back = t
	_prev = [_prev[1], _prev[0]]
	var r := r_front
	r_front = r_back
	r_back = r
	if _visuals:
		_build_mesh()
	_build_shape()
	_apply_skid_pose()


## Where the chain meets the load (the top of the choker round the chained end).
func chain_point() -> Vector3:
	var d := axis()
	var up := _up_of(d)
	var top := r_front
	if bundle > 0:
		top = _bundle_height() - r_front
	return front + d * CHOKER_M + up * (top + 0.02)


## For a jam: the load is worked free for `secs`: moved sideways off the line of the pull (FREE_V), so the
## chain draws it round what holds it. Each new jam (`fresh`) tries the other side.
func work_free(secs: float, fresh := true) -> void:
	if fresh:
		# away from what it was last pushed off (else the other side from last time)
		var side := axis().cross(Vector3.UP)
		var k := _last_lat.dot(side)
		_free_side = signf(k) if absf(k) > 1e-4 else -_free_side
	_free_t = secs


func _jam_reset() -> void:
	_free_t = 0.0


# --- FelledTree -----------------------------------------------------------------------------------------

func axis() -> Vector3:
	var d := back - front
	return d / d.length() if d.length() > 1e-5 else Vector3.FORWARD


func top() -> Vector3:
	return back


## A loose bole takes the axe; a bundle, a load on the chain and a log riding in a wheelbarrow do not.
func is_down() -> bool:
	return state == State.DOWN and bundle == 0 and not hitched and not has_meta(&"in_barrow")


## Bucking shortens it from the far end. A trunk of two lengths or more drops each length bucked off as its own log
## beside it (out.cut_off: the new logs; user 2026-09-27: logs for a barricade, to drag on foot); the last length
## goes to the pack (out.logs, GatherTools), as a bundle's logs and a felled tree's do.
func buck(power: float) -> Dictionary:
	if laid:
		unlay()
	if bundle == 0 and logs_left >= 2:
		var cut := {"logs": 0, "limbed": false, "cut_off": []}
		work += power
		while work >= cut_work and logs_left >= 2:
			work -= cut_work
			(cut.cut_off as Array).append(_cut_off_far_log())
		return cut
	var out := super.buck(power)
	if state == State.GONE:
		if body:
			body.queue_free()
			body = null
	elif int(out.logs) > 0:
		var L := float(logs_left) * _log_len
		back = front + axis() * L
		_prev[1] = back
		r_back = bole_radii({"radius": r_front / 0.95}, L, cfg).y
		length = L
		info["crown_bottom"] = L
		_compute_mass()
		_build_shape()
		if _visuals:
			_build_mesh()
		_apply_skid_pose()
		_rest_ticks = 0
	return out


# --- The barricade ----------------------------------------------------------------------------------------

## Laid as a barricade log with its ends at `p_front` / `p_back` (the caller puts them level, on the ground or on
## the log under it).
func lay_at(p_front: Vector3, p_back: Vector3) -> void:
	front = p_front
	back = p_back
	_prev = [front, back]
	laid = true
	grounded = true
	pull_kgf = 0.0
	stretch = 0.0
	_rest_ticks = 0
	_apply_skid_pose()


## Off the barricade: loose again (it settles), and so is whatever rests on it.
func unlay() -> void:
	if not laid:
		return
	for s in resting_on_me():
		s.unlay()
	laid = false
	_rest_ticks = 0


func mid() -> Vector3:
	return (front + back) * 0.5


func mean_radius() -> float:
	return (r_front + r_back) * 0.5


## Whether laid log `upper` rests on laid log `lower`: over its length, beside its axis by less than the two
## together, and about the two radii above it.
static func rests(upper: SkidLoad, lower: SkidLoad) -> bool:
	if upper == lower or not upper.laid or not lower.laid:
		return false
	var m := upper.mid()
	var a := lower.front
	var ax := lower.back - lower.front
	var axh := Vector3(ax.x, 0.0, ax.z)
	if axh.length() < 0.1:
		return false
	var t := (Vector3(m.x - a.x, 0.0, m.z - a.z)).dot(axh) / axh.length_squared()
	if t < -0.15 or t > 1.15:
		return false
	var on := a + ax * clampf(t, 0.0, 1.0)
	var rr := upper.mean_radius() + lower.mean_radius()
	var side := Vector2(m.x - on.x, m.z - on.z).length()
	var up := m.y - on.y
	return side <= rr * 0.8 + 0.1 and up > rr * 0.6 and up < rr * 1.4


## The laid logs resting on this one.
func resting_on_me() -> Array[SkidLoad]:
	var out: Array[SkidLoad] = []
	if not laid or not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group(GROUP):
		var s := n as SkidLoad
		if s and s != self and s.laid and not s.is_queued_for_deletion() and rests(s, self):
			out.append(s)
	return out


## The laid log this one rests on (null: on the ground).
func rests_on() -> SkidLoad:
	if not laid or not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group(GROUP):
		var s := n as SkidLoad
		if s and s != self and s.laid and not s.is_queued_for_deletion() and rests(self, s):
			return s
	return null


## Its course in a stack: 1 on the ground.
func stack_level() -> int:
	var n := 1
	var s := rests_on()
	while s != null and n < 10:
		n += 1
		s = s.rests_on()
	return n


## The far length cut off as its own log (one log's length, lying on where it was; a hand's breadth of saw kerf between),
## this one shortened by it. Returns the new log (in the tree beside this one).
func _cut_off_far_log() -> SkidLoad:
	var d := axis()
	var L0 := length
	logs_left -= 1
	var L := float(logs_left) * _log_len
	var cut_at := front + d * L
	var r_cut := bole_radii({"radius": r_front / 0.95}, L, cfg).y
	var p := SkidLoad.new()
	p.info = info.duplicate()
	p.name = "%s_cut%d" % [name, logs_left]
	p._cfg = _cfg
	p.cfg = cfg
	p._log_len = _log_len
	p._visuals = _visuals
	p.cut_work = cut_work
	p.hardness = hardness
	p.logs_total = 1
	p.logs_left = 1
	p.state = State.DOWN
	p.r_front = r_cut
	p.r_back = r_back
	p.front = cut_at + d * 0.06
	p.back = back
	p._setup(maxf(L0 - L - 0.06, 0.3))
	back = cut_at
	_prev[1] = back
	r_back = r_cut
	length = L
	info["crown_bottom"] = L
	_compute_mass()
	_build_shape()
	if _visuals:
		_build_mesh()
	_apply_skid_pose()
	_rest_ticks = 0
	if is_inside_tree():
		get_parent().add_child(p)
	return p


## Limbed when it was chained: no crown is left.
func crown_yield() -> Dictionary:
	return {}


# --- Simulation -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.GONE:
		if _sink_t >= 0.0:
			_sink_t += delta
			global_position = front + Vector3.DOWN * minf(_sink_t, 1.2) * 0.6
			if _sink_t >= 1.2:
				queue_free()
		return
	if not is_inside_tree():
		return
	if hitched and (haul == null or not is_instance_valid(haul)):
		unhitch()
	if laid and not hitched:
		return                          # a barricade log: where it was put
	if not hitched and _rest_ticks > 90:
		return                          # lying still
	var t0 := Time.get_ticks_usec()
	simulate(delta)
	sim_usec = Time.get_ticks_usec() - t0


## One step of the load (see the class notes).
func simulate(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var g := G
	var dt2 := delta * delta
	var L := length
	var d0 := axis()
	var axh := Vector3(d0.x, 0.0, d0.z)
	axh = axh.normalized() if axh.length() > 1e-3 else Vector3.FORWARD
	var mu_a := float(cfg.get("mu_axial", 0.4))
	var mu_l := float(cfg.get("mu_lateral", 0.8))
	var pts: Array[Vector3] = [front, back]
	var mid0 := (front + back) * 0.5
	for i in 2:
		var p: Vector3 = pts[i]
		var v: Vector3 = p - _prev[i]
		if grounded:
			# Coulomb friction on the ground: along the log and across it
			var vh := Vector3(v.x, 0.0, v.z)
			var va := axh * vh.dot(axh)
			var vl := vh - va
			va = _shrink(va, mu_a * g * dt2)
			vl = _shrink(vl, mu_l * g * dt2)
			v = Vector3(va.x + vl.x, v.y * (0.55 if v.y > 0.0 else 1.0), va.z + vl.z)
		_prev[i] = p
		pts[i] = p + v * 0.998 + Vector3.DOWN * g * dt2
	var hp := Vector3.INF
	if hitched:
		hp = haul.hitch_point()
	# the ground under the samples, once per tick (at the predicted pose); no more than STEP_UP over the
	# ground it had there (a face the chain draws the nose up is not a floor)
	for k in SAMPLES.size():
		_hs[k] = _ground_h(space, pts[0].lerp(pts[1], SAMPLES[k]), _hs_last[k])
		_hs_last[k] = _hs[k]
	var touch := false
	_lift[0] = 0.0
	_lift[1] = 0.0
	_push[0] = Vector3.ZERO
	_push[1] = Vector3.ZERO
	if _free_t > 0.0:
		_free_t -= delta
		var side := d0.cross(Vector3.UP)
		side = side.normalized() if side.length() > 1e-3 else Vector3.RIGHT
		for i in 2:
			pts[i] += side * _free_side * FREE_V * delta
	obstacle_hits = 0
	for it in 4:
		_rod(pts, L)
		touch = _ground(pts) or touch
		if hitched:
			# the chain draws the end toward the hook, CHAIN_STEP at a time (held by something, the load does
			# not go into it: the chain is drawn out, which is the jam); it does not lift the nose (a log's
			# weight holds its end down far more than a low chain can raise it), so pressed against a face it
			# does not climb it
			var d: Vector3 = pts[0] - hp
			if d.length() > chain_len:
				var corr: Vector3 = (hp + d.normalized() * chain_len - pts[0]).limit_length(CHAIN_STEP)
				corr.y = minf(corr.y, 0.0)
				pts[0] += corr
		if _obstacles(space, pts):
			obstacle_hits += 1
	touch = _ground(pts) or touch
	grounded = touch
	# no faster than the horse (and a little): a chain drawn tight against something that gives way does
	# not fling the load
	var vmax := (float(haul.call(&"puller_speed")) if hitched else 0.0) + 2.5
	for i in 2:
		var step: Vector3 = pts[i] - _prev[i]
		var sh := Vector2(step.x, step.z)
		if sh.length() > vmax * delta:
			sh = sh.normalized() * vmax * delta
			pts[i] = Vector3(_prev[i].x + sh.x, pts[i].y, _prev[i].z + sh.y)
	# what the ground and the obstacles did is not a throw: a lift keeps at most HOP_V upward, and an end
	# pushed off something keeps none of its speed away from it (it does not bounce off a trunk)
	for i in 2:
		var dv: Vector3 = pts[i] - _prev[i]
		if _lift[i] > 0.0:
			dv.y = minf(_lift[i], HOP_V * delta)
		if _push[i].length() > 1e-5:
			var n: Vector3 = _push[i].normalized()
			var away := dv.dot(n)
			if away > 0.0:
				dv -= n * away
		_prev[i] = pts[i] - dv
	front = pts[0]
	back = pts[1]
	stretch = maxf((front - hp).length() - chain_len, 0.0) if hitched else 0.0
	# roll: a log dragged across itself turns over
	var mid := (front + back) * 0.5
	var dm := mid - mid0
	var d1 := axis()
	if bundle == 0 and grounded:
		var lat := Vector3(dm.x, 0.0, dm.z) - axh * Vector3(dm.x, 0.0, dm.z).dot(axh)
		var side := d1.cross(Vector3.UP)
		roll += lat.dot(side.normalized() if side.length() > 1e-3 else Vector3.RIGHT) / maxf(float(info.get("radius", 0.2)), 0.05) * 0.6
	# the pull it takes: friction (more of the across-the-log friction the more it is dragged sideways) and slope
	var raw := 0.0
	if hitched:
		var pull_dir := hp - front
		pull_dir.y = 0.0
		var sin_lat := 0.0
		if pull_dir.length() > 0.1:          # (a hook right over the end: the pull is along the log)
			sin_lat = absf(pull_dir.normalized().cross(axh).y)
		var slope := clampf((front.y - back.y) / maxf(L, 0.1), -1.0, 1.0)
		# (a hop off a bump does not lighten it: the horse feels the load, not the tick)
		var mu := lerpf(mu_a, mu_l, sin_lat)
		raw = maxf(mass_kg * (mu * sqrt(1.0 - slope * slope) + slope), 0.0)
	pull_kgf = lerpf(pull_kgf, raw, 1.0 - exp(-delta / 0.3))
	# lying still (loose): stop simulating until it is chained again
	if not hitched and dm.length() < 2e-4 and (front - _prev[0]).length() < 2e-4:
		_rest_ticks += 1
	else:
		_rest_ticks = 0
	_apply_skid_pose()


static func _shrink(v: Vector3, by: float) -> Vector3:
	var l := v.length()
	if l <= by:
		return Vector3.ZERO
	return v * ((l - by) / l)


func _rod(pts: Array[Vector3], L: float) -> void:
	var a: Vector3 = pts[1] - pts[0]
	var la := a.length()
	if la < 1e-5:
		pts[1] = pts[0] + Vector3.FORWARD * L
		return
	var corr := a * ((la - L) / la * 0.5)
	pts[0] += corr
	pts[1] -= corr


## Lifts the rod where a sample is below the ground (+ its radius); true when any sample touches.
func _ground(pts: Array[Vector3]) -> bool:
	var touch := false
	for k in SAMPLES.size():
		var t: float = SAMPLES[k]
		var p: Vector3 = pts[0].lerp(pts[1], t)
		var need: float = _hs[k] + lerpf(r_front, r_back, t) - p.y
		if need > -0.015:
			touch = true
		if need <= 0.0:
			continue
		if t <= 0.0:
			pts[0].y += need
			_lift[0] += need
		elif t >= 1.0:
			pts[1].y += need
			_lift[1] += need
		else:
			var w := 1.0 / ((1.0 - t) * (1.0 - t) + t * t)
			pts[0].y += need * (1.0 - t) * w
			pts[1].y += need * t * w
			_lift[0] += need * (1.0 - t) * w
			_lift[1] += need * t * w
	return touch


## Height of the ground under `p`: a ray down from STEP_UP over it (the horse, people and standing trunks do
## not count), else the terrain's height field.
func _ground_h(space: PhysicsDirectSpaceState3D, p: Vector3, last := INF) -> float:
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
	_ray.from = Vector3(p.x, minf(p.y, last) + STEP_UP, p.z)
	_ray.to = Vector3(p.x, p.y - 4.0, p.z)
	var ex: Array[RID] = _own_exclude()
	for _try in 3:
		_ray.exclude = ex
		var hit := space.intersect_ray(_ray)
		if hit.is_empty():
			break
		var col := hit.collider as Node
		if col is CharacterBody3D or (col != null and col.is_in_group(&"trees")):
			ex.append(hit.rid)
			continue
		return (hit.position as Vector3).y
	return FrontierTerrain.height_at(p.x, p.z)


func _own_exclude() -> Array[RID]:
	var ex: Array[RID] = []
	if body:
		ex.append(body.get_rid())
	var pb: Variant = haul.call(&"puller") if hitched and haul else null
	if pb is CollisionObject3D:
		ex.append((pb as CollisionObject3D).get_rid())
	return ex


## Pushes the rod out of the deepest standing obstacle it is in (sideways only); false when it is in none.
func _obstacles(space: PhysicsDirectSpaceState3D, pts: Array[Vector3]) -> bool:
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		_query.collide_with_areas = false
	var ax: Vector3 = pts[1] - pts[0]
	var L := ax.length()
	if L < 0.1:
		return false
	if _qshape == null:
		_qshape = CylinderShape3D.new()
	var r := (r_front + r_back) * 0.5
	if bundle > 0:
		r = _bundle_width() * 0.5
	_qshape.radius = r
	_qshape.height = L
	_query.shape = _qshape
	_query.transform = Transform3D(_basis_for(ax / L), (pts[0] + pts[1]) * 0.5)
	var ex := _own_exclude()
	_query.exclude = ex
	var hits := space.intersect_shape(_query, 12)
	var any := false
	for h: Dictionary in hits:
		if _is_obstacle(h.collider as Node):
			any = true
		else:
			ex.append(h.rid)
	if not any:
		return false
	_query.exclude = ex
	var pairs := space.collide_shape(_query, 8)
	var best := Vector3.ZERO
	var best_t := 0.5
	for k in range(0, pairs.size() - 1, 2):
		var a: Vector3 = pairs[k]
		var b: Vector3 = pairs[k + 1]
		var c := b - a
		c.y = 0.0
		if c.length() > 1e-5:
			c += c.normalized() * 0.01          # out to a hair clear of it
		if c.length() > best.length():
			best = c
			best_t = clampf((a - pts[0]).dot(ax) / (L * L), 0.0, 1.0)
	if best.length() < 1e-4:
		return false
	# across the log the push turns it about its far end (at the contact); along it (an end run into a rock
	# face) it moves the whole log back, which the chain feels as a jam
	var t := best_t
	var w := 1.0 / ((1.0 - t) * (1.0 - t) + t * t)
	var an := Vector3(ax.x, 0.0, ax.z)
	an = an.normalized() if an.length() > 1e-4 else Vector3.FORWARD
	var along := an * best.dot(an)
	var lat := (best - along).limit_length(MAX_PUSH)
	var p0 := lat * (1.0 - t) * w + along
	var p1 := lat * t * w + along
	pts[0] += p0
	pts[1] += p1
	_push[0] += p0
	_push[1] += p1
	if lat.length() > 1e-4:
		_last_lat = lat
	return true


static func _is_obstacle(col: Node) -> bool:
	if col == null or col is CharacterBody3D or col is AnimatableBody3D:
		return false
	if col.is_in_group(&"terrain") or col.is_in_group(FrontierVegetation.LOW_GROUP):
		return false
	return col is StaticBody3D


# --- Pose and models ---------------------------------------------------------------------------------

## A frame with +Y along `d` and +Z as near the world's up as it can be (X horizontal).
static func _basis_for(d: Vector3) -> Basis:
	var x := d.cross(Vector3.UP)
	if x.length() < 1e-3:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(d).normalized()
	return Basis(x, d, z)


static func _up_of(d: Vector3) -> Vector3:
	return _basis_for(d).z


func _apply_skid_pose() -> void:
	hinge = front
	if is_inside_tree():
		global_transform = Transform3D(_basis_for(axis()), front)
	else:
		transform = Transform3D(_basis_for(axis()), front)
	if _mesh_root and bundle == 0:
		_mesh_root.rotation = Vector3(0.0, roll, 0.0)


func _enter_tree() -> void:
	_apply_skid_pose()


func _build_shape() -> void:
	if body == null:
		return
	for c in body.get_children():
		c.queue_free()
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	if bundle > 0:
		var box := BoxShape3D.new()
		box.size = Vector3(_bundle_width(), length, _bundle_height())
		cs.shape = box
		cs.position = Vector3(0.0, length * 0.5, _bundle_height() * 0.5 - r_front)
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf((r_front + r_back) * 0.5, 0.06)
		cyl.height = length
		cs.shape = cyl
		cs.position = Vector3(0.0, length * 0.5, 0.0)
	body.add_child(cs)


## Cross-section of a bundle: log centres (x across, z up) on the bottom row's middle, rows of a pile.
func bundle_offsets() -> Array[Vector2]:
	return pile_offsets(bundle, r_front)


## A pile of n logs of radius r, as a woodsman stacks them: rows of w, w - 1, ... (w the least with
## w(w + 1)/2 >= n), each upper log in a groove of the row under it.
static func pile_offsets(n: int, r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var w := 1
	while w * (w + 1) / 2 < n:
		w += 1
	var xs: Array[float] = []
	for i in mini(w, n):
		xs.append((float(i) - float(mini(w, n) - 1) * 0.5) * 2.0 * r)
	var left := n
	var z := 0.0
	while left > 0 and not xs.is_empty():
		var k := mini(xs.size(), left)
		var start := (xs.size() - k) / 2
		for i in k:
			out.append(Vector2(xs[start + i], z))
		left -= k
		var grooves: Array[float] = []
		for i in xs.size() - 1:
			grooves.append((xs[i] + xs[i + 1]) * 0.5)
		xs = grooves
		z += sqrt(3.0) * r
	return out


func _bundle_width() -> float:
	var w := 0.0
	for o in bundle_offsets():
		w = maxf(w, absf(o.x))
	return 2.0 * (w + r_front)


func _bundle_height() -> float:
	var h := 0.0
	for o in bundle_offsets():
		h = maxf(h, o.y)
	return h + 2.0 * r_front


func _build_mesh() -> void:
	if _mesh_root:
		_mesh_root.queue_free()
	_mesh_root = Node3D.new()
	_mesh_root.name = "Model"
	add_child(_mesh_root)
	var sp := String(info.get("species", "white_pine"))
	if bundle > 0:
		for o in bundle_offsets():
			log_model(_mesh_root, r_front, r_front, length, sp, Vector3(o.x, 0.0, o.y))
		var hw := _bundle_width() * 0.5 + 0.03
		var hh := _bundle_height() * 0.5 + 0.03
		for y: float in [CHOKER_M, length - 0.35]:
			var ring := _wrap(_mesh_root, y, hw, Vector3(0.0, 0.0, _bundle_height() * 0.5 - r_front))
			ring.scale = Vector3(1.0, 1.0, hh / hw)
	else:
		log_model(_mesh_root, r_front, r_back, length, sp, Vector3.ZERO)
		_wrap(_mesh_root, CHOKER_M, r_front + 0.012, Vector3.ZERO)


## A log along +Y of `parent` from `at` (bark round, end grain at both ends).
static func log_model(parent: Node3D, r0: float, r1: float, L: float, species: String, at: Vector3) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = r0
	cyl.top_radius = r1
	cyl.height = L
	cyl.radial_segments = 16
	cyl.rings = maxi(1, int(L / 2.5))
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.name = "Log"
	mi.mesh = cyl
	mi.material_override = _bark_for(species, (r0 + r1) * 0.5, L)
	mi.position = at + Vector3(0.0, L * 0.5, 0.0)
	mi.visibility_range_end = 140.0
	parent.add_child(mi)
	for e in 2:
		var cap := CylinderMesh.new()
		cap.top_radius = r0 if e == 0 else r1
		cap.bottom_radius = cap.top_radius
		cap.height = 0.006
		cap.radial_segments = 16
		var ci := MeshInstance3D.new()
		ci.mesh = cap
		ci.material_override = GatherModels.end_grain_material()
		ci.position = at + Vector3(0.0, 0.0 if e == 0 else L, 0.0)
		ci.visibility_range_end = 60.0
		parent.add_child(ci)


## The species' bark tiled for a log of radius r and length L (the vegetation's bark textures).
static func _bark_for(species: String, r: float, L: float) -> StandardMaterial3D:
	var u := maxf(roundf(TAU * r / 0.9), 1.0)
	var v := maxf(roundf(L / 1.2), 1.0)
	var key := "%s:%d:%d" % [species, int(u), int(v)]
	if not _bark_mats.has(key):
		var m := GatherModels.bark_material(species).duplicate() as StandardMaterial3D
		m.uv1_scale = Vector3(u, v, 1.0)
		_bark_mats[key] = m
	return _bark_mats[key]


## The chain's loop round the log (or the bundle) at `y` along it.
static func _wrap(parent: Node3D, y: float, radius: float, centre: Vector3) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius
	t.outer_radius = radius + 0.022
	t.rings = 20
	t.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.name = "Choker"
	mi.mesh = t
	mi.material_override = HorseHaul.iron_material()
	mi.position = centre + Vector3(0.0, y, 0.0)
	mi.visibility_range_end = 60.0
	parent.add_child(mi)
	return mi


## The load's meshes (the interactor's highlight).
func highlight_targets() -> Array:
	return _mesh_root.find_children("*", "GeometryInstance3D", true, false) if _mesh_root else []
