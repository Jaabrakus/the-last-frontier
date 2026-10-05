class_name FormEffects
extends RefCounted
## What a Form cast does (SwayEffects.apply hands the art "form" here; SwayCaster's cast; data/sway/moves.json). The matter
## comes from the place: what is raised leaves a hollow where its earth came from (FormHollow), mending takes wood from the
## pack. Static.
##
##   earth_wall    a wall (FormRaised "wall") rises across the caster's line just past the circle, the hollow where the circle
##                 was; of the matter it is raised from (FormMatter; the user, 2026-10-03: "it should be earth wall where if the
##                 terrain is mud its a mud wall if its a tree i can make a tree wall you know"): packed earth, wet mud, grey
##                 fieldstones, packed snow, its look, strength and size the matter's (earth_wall.wall.materials). The lock on a
##                 standing tree's trunk: a palisade of its split logs just past its foot, the tree gone into it (tree_wall:
##                 out of the forest as felling takes it, a stump left; the save keeps it)
##   stone_form    thrown (the user, 2026-10-03: "Stone Form throws itself"): the stone of the spell's mode (SwayCaster.mode_of:
##                 "spike" a jagged spike, "cannonball" a round stone ball; a FormStone) bursts up out of the ground a step in
##                 front of the caster toward the aim (its hollow there), rises to chest height and flies at the crosshair
##                 (Throw, GustLift's flight): the spike a lance through people, sticking where it meets the world; the ball
##                 heavier, knocking people and things aside, rolling on. Both then lie as stones for Gust to lift and hurl.
##                 Each in the look of a stone of the ground it came from (FormMatter.rock_material: stone_form.looks)
##   pillar        a column (FormRaised "pillar"), by the mode: "self" rises under the caster and carries them up; cast in
##                 stride while running (launch.run_mps; practised and up: the untrained floor cast holds the caster still)
##                 a quick short one launches them up and forward, a boost when the cast falls within plant_window_s (0.045 s)
##                 before a foot plant or plant_after_s (0.02 s) after one (plant_times: the step cycle; the ring beats on
##                 each plant); cast in the air it rises fast (air.rise_s) under where they will be by then, just tall enough
##                 for its top to meet their feet (air_catch; the user, 2026-10-03: "the pillar should match the height so if
##                 im jumping and cast a pillar underneath me it should quickly make a pillar just as big to catch me").
##                 "free": at the aimed circle (mode_range_m). A ring of hollow round its foot. Its matter the ground's under
##                 it (its look the wall's, its strength pillar.materials)
##   mend          the piece back one stage (mend_stage): a ruin stands again (charred), a piece alight is put out, a charred
##                 one made whole, a raised wall worn by shot packed again; wood from the pack for each (not the earth wall)
## Dust, stone chips and a grinding of stone with each (Sfx ids from moves.json form_sfx, when they exist).

const FormMatter := preload("res://scripts/sway/form_matter.gd")
const MOVES := ["earth_wall", "stone_form", "pillar", "mend"]


static func handles(m: String) -> bool:
	return m in MOVES or SwayMoves.move(m).has("bend")


static func apply(c: SwayCaster, m: String, t: Node3D, at: Vector3) -> void:
	if c == null or c.player == null:
		return
	var d := SwayMoves.move(m)
	# (a bending move's mode: BendEffects; docs/bending_design.md)
	var mode := c.mode_of(m)
	var bd: Dictionary = d.get("bend", {})
	if bd.has(mode):
		BendEffects.apply(c, m, mode, bd[mode], t, at)
		return
	match m:
		"earth_wall":
			earth_wall(c, at, d)
		"stone_form":
			stone_form(c, at, d, c.mode_of(m))
		"pillar":
			pillar(c, at, d, c.mode_of(m))
		"mend":
			mend(c, t, d)


## The caster's flat way to `at` (their facing when it is under them).
static func way_to(c: SwayCaster, at: Vector3) -> Vector3:
	var v := at - c.player.global_position
	v.y = 0.0
	if v.length_squared() < 0.04:
		v = c.player.skeleton.global_basis.z if c.player.skeleton != null else -c.player.global_basis.z
		v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-6 else Vector3.FORWARD


# ---------------------------------------------------------------- the earth
## The Earth Wall at `at` (the circle's middle) of `matter` ("": the lock's, FormCast.lock_matter, what the circle showed;
## else the ground's there), or from tree `tree_i` (-1: the lock's tree, FormCast.lock_tree): see the header.
static func earth_wall(c: SwayCaster, at: Vector3, d: Dictionary, matter := "", tree_i := -1) -> FormRaised:
	var w: Dictionary = d.get("wall", {})
	if matter == "" and tree_i < 0 and c.form != null and c.form.lock_matter != "":
		matter = c.form.lock_matter
		tree_i = c.form.lock_tree
	if tree_i >= 0:
		var tw := tree_wall(c, tree_i, d)
		if tw != null:
			return tw
		matter = ""                                     # (the tree gone meanwhile: the ground at its foot)
	if matter == "" or matter == "wood":
		matter = FormMatter.of_ground(c.get_tree(), at)
	var wn := FormMatter.numbers(w, FormMatter.entry("earth_wall", matter), matter)
	var way := way_to(c, at)
	var foot := ground_at(c, at + way * float(wn.get("ahead_m", 0.75)))
	var across := Vector3.UP.cross(way).normalized()
	var xf := Transform3D(Basis(across, Vector3.UP, way), foot)
	var scn := c.get_tree().current_scene
	var r := FormRaised.raise(scn, "wall", xf, wn, absi(hash(foot)) % 97)
	var h: Dictionary = d.get("hollow", {})
	FormHollow.dig(scn, ground_at(c, at - way * 0.15), way, float(h.get("width_m", 3.0)), float(h.get("depth_m", 1.5)), float(h.get("fade_s", 600.0)))
	_raised_fx(c, foot, float(wn.get("width_m", 3.0)), matter)
	return r


## The Earth Wall from standing tree `i` (the lock on its trunk): a palisade of its split logs (matter "wood",
## earth_wall.wall.materials.wood; its bark the species') standing across the caster's line just past the tree's foot (the
## stump, tree.gap_m clear of it), and the tree gone into it (FormMatter.take_tree: out of the forest as felling takes it, a
## stump left, the save's vegetation part keeps it; drawn, it shrinks into its stump as the wall rises). Null when the
## tree is gone already.
static func tree_wall(c: SwayCaster, i: int, d: Dictionary) -> FormRaised:
	var hv := VegHarvest.find(c.get_tree())
	var td := hv.describe("tree", "tree", i) if hv != null else {}
	if td.is_empty():
		return null
	var wn := FormMatter.numbers(d.get("wall", {}), FormMatter.entry("earth_wall", "wood"), "wood")
	var root := ground_at(c, td.pos)
	var way := way_to(c, root)
	var past := float(td.radius) + float(wn.get("thick_m", 0.4)) * 0.5 + float((d.get("tree", {}) as Dictionary).get("gap_m", 0.06))
	var foot := ground_at(c, root + way * past)
	var across := Vector3.UP.cross(way).normalized()
	wn["species"] = String(td.species)
	var scn := c.get_tree().current_scene
	var r := FormRaised.raise(scn, "wall", Transform3D(Basis(across, Vector3.UP, way), foot), wn, absi(hash(foot)) % 97)
	r.set_meta(&"tree_i", i)
	FormMatter.take_tree(c.get_tree(), i, float(wn.get("rise_s", 0.7)))
	GatherFx.fall_dust(scn, root, float(td.get("crown_radius", 3.0)) * 0.5)
	for k in 3:
		GatherFx.wood_chips(scn, root + Vector3.UP * (0.4 + 0.5 * k), -way, 12)
	sfx("tree", root, 0.0, 1.0)
	sfx("rumble", foot, -3.0, 0.9)
	return r


## The pillar of `mode` ("self" or "free"); see the header. The launch's numbers in c.last_launch ({} when none).
static func pillar(c: SwayCaster, at: Vector3, d: Dictionary, mode := "self") -> FormRaised:
	var pd: Dictionary = (d.get("pillar", {}) as Dictionary).duplicate()
	var ld: Dictionary = pd.get("launch", {})
	var p := c.player
	var way := way_to(c, at)
	var foot := ground_at(c, at)
	var how := "free"
	var run := Vector3(p.velocity.x, 0.0, p.velocity.z)
	c.last_launch = {}
	if mode == "self":
		if not p.is_on_floor():
			# (fast, under where they will be by then, its top meeting their feet: they land on it, never thrown by it)
			how = "air"
			var air := air_catch(c, pd.get("air", {}))
			foot = air.foot
			pd["rise_s"] = air.rise_s
			pd["height_m"] = air.height_m
		elif run.length() >= float(ld.get("run_mps", 2.6)) and c.tier("pillar") >= 1:        # (untrained: rooted, no launch)
			how = "run"
			way = run.normalized()
			foot = ground_at(c, p.global_position + way * 0.2)
			pd["rise_s"] = float(ld.get("rise_s", 0.3))
			pd["height_m"] = float(ld.get("height_m", 1.3))
		else:
			how = "stand"
			foot = ground_at(c, p.global_position)
	var xf := Transform3D(Basis(Vector3.UP.cross(way).normalized(), Vector3.UP, way), foot)
	var scn := c.get_tree().current_scene
	var matter := FormMatter.of_ground(c.get_tree(), foot)
	var r := FormRaised.raise(scn, "pillar", xf, FormMatter.numbers(pd, FormMatter.entry("pillar", matter), matter), absi(hash(foot)) % 97)
	r.set_meta(&"pillar_mode", how)
	var h: Dictionary = d.get("hollow", {})
	FormHollow.dig(scn, foot, way, float(h.get("width_m", 2.1)), float(h.get("depth_m", 2.1)), float(h.get("fade_s", 600.0)))
	_raised_fx(c, foot, float(pd.get("radius_m", 0.55)) * 2.0, matter)
	if how == "run":
		# launched up and forward off the column coming up under the stride; on a foot plant, a boost
		var gap := plant_gap(p)
		var pt := plant_times(p)
		var boost := pt.y <= float(ld.get("plant_window_s", 0.045)) or pt.x <= float(ld.get("plant_after_s", 0.02))
		var k := float(ld.get("boost", 1.3)) if boost else 1.0
		p.velocity = run * float(ld.get("carry", 0.85)) + way * float(ld.get("fwd_mps", 3.0)) * k + Vector3.UP * float(ld.get("up_mps", 6.0)) * k
		c.last_launch = {"boost": boost, "gap": gap, "velocity": p.velocity, "k": k}
		if boost:
			_tell(c, "On the step: a boost")
	return r


## Seconds since the last foot plant of the player's stride and to the next (x, y; INF both when not striding): the step
## cycle as Footsteps counts it (its strides by gait: STRIDE; the distance walked since the last step, _acc), so the boost
## falls on the step that is heard. The boost wants the coming plant within plant_window_s, or the last one only
## plant_after_s ago (the step just heard): a timing, not a coin toss (about a fifth of a run's stride, a quarter of a
## sprint's).
static func plant_times(p: Node) -> Vector2:
	var fs := p.get_node_or_null(^"Footsteps") as Footsteps if p != null else null
	var body := p as FrontierPlayer
	if fs == null or body == null or not body.is_on_floor():
		return Vector2(INF, INF)
	var speed := body.horizontal_speed()
	if speed < Footsteps.MIN_SPEED or not bool(fs.get(&"_moving")):
		return Vector2(INF, INF)
	var stride := float(Footsteps.STRIDE.get(fs._gait(speed), 1.15))
	var acc := float(fs.get(&"_acc"))
	return Vector2(acc, maxf(stride - acc, 0.0)) / speed


## Seconds from now to the nearest foot plant of the player's stride (INF when not striding): plant_times' nearer.
static func plant_gap(p: Node) -> float:
	var fs := p.get_node_or_null(^"Footsteps") as Footsteps if p != null else null
	var body := p as FrontierPlayer
	if fs == null or body == null or not body.is_on_floor():
		return INF
	var speed := body.horizontal_speed()
	if speed < Footsteps.MIN_SPEED or not bool(fs.get(&"_moving")):
		return INF
	var stride := float(Footsteps.STRIDE.get(fs._gait(speed), 1.15))
	var acc := float(fs.get(&"_acc"))
	return minf(acc, maxf(stride - acc, 0.0)) / speed


## Where a pillar cast in the air catches the player (pillar.pillar.air): rise_s on along their flight (their velocity and
## the player's gravity: where their feet will be when it is up), the ground under that point, and the height that brings
## its top to their feet then (less gap_m, within min_m..max_m): {foot, feet, rise_s, height_m}.
static func air_catch(c: SwayCaster, ad: Dictionary) -> Dictionary:
	var p := c.player
	var t := float(ad.get("rise_s", 0.2))
	var g := float(p.get(&"_gravity")) if p.get(&"_gravity") != null else 9.8
	var v := p.velocity
	var feet := p.global_position + Vector3(v.x, 0.0, v.z) * t + Vector3.UP * (v.y * t - 0.5 * g * t * t)
	var foot := ground_at(c, feet, 30.0)
	var hgt := clampf(feet.y - foot.y - float(ad.get("gap_m", 0.03)), float(ad.get("min_m", 1.0)), float(ad.get("max_m", 8.0)))
	return {"foot": foot, "feet": feet, "rise_s": t, "height_m": hgt}


# ---------------------------------------------------------------- stone form
## Stone Form of `mode` ("spike" or "cannonball"), thrown (the user, 2026-10-03, after raising a spike and then locking Gust on
## it proved hard and not fun: "Stone Form throws itself": one spell, one aim): the stone bursts up out of the ground
## throw.ahead_m in front of the caster toward the aim (its small hollow there), rises to throw.chest_m over their feet in
## throw.rise_s (a spike turning its point toward the crosshair as it comes), then flies at the crosshair's point at that
## moment (aim_point: the camera's ray past the stone; a man it is on, not the circle on the ground; far along the ray at the
## sky) on a little arc for its drop: GustLift's flight (throw.hurl.<mode>: a spike a lance, fast and flat, through people
## and sticking where it meets the world; a cannonball heavier, knocking people aside, rolling on), a thing it meets knocked
## on (Throw). It lies its life_s after, a stone for Gust to lift. In the look of a stone of the ground it came out of. `at`
## (the lock's circle) gives the way when there is no camera.
static func stone_form(c: SwayCaster, at: Vector3, d: Dictionary, mode := "spike") -> FormStone:
	var td: Dictionary = d.get("throw", {})
	var aim := aim_point(c)
	var way := way_to(c, aim if aim != Vector3.INF else at)
	var foot := ground_at(c, c.player.global_position + way * float(td.get("ahead_m", 1.4)))
	var scn := c.get_tree().current_scene
	var seed := absi(hash(Vector3i(roundi(foot.x * 10.0), roundi(foot.y * 10.0), roundi(foot.z * 10.0)))) % 97
	var matter := FormMatter.of_ground(c.get_tree(), foot)
	var s: FormStone
	if mode == "cannonball":
		s = FormStone.ball(scn, foot, d.get("cannonball", {}), seed, matter)
	else:
		s = FormStone.spike(scn, foot, way, d.get("spike", {}), seed, matter)
	var h: Dictionary = d.get("hollow", {})
	FormHollow.dig(scn, foot, way, float(h.get("width_m", 1.3)), float(h.get("depth_m", 1.3)), float(h.get("fade_s", 600.0)))
	sfx("rise", foot, -2.0, 0.9)
	sfx("rumble", foot, -4.0, 1.1)
	Throw.start(c, s, td)
	return s


## Gust on a raised wall or pillar (the user, 2026-10-04: "we should be able to use gust to push certain parts of the rock wall
## and pillar"): the piece the aim is on torn out of it, a ball of its matter (gust.raised.chunk_r) at the face the caster
## sees, and hurled along the aim (Throw: the crosshair, the aim's help) through the wall it came from; the wall takes a hit
## for it (FormRaised.apply_hit: wearing, and at its hits_max it crumbles). The thrown chunk; null when none.
static func gust_chunk(c: SwayCaster, r: FormRaised, at: Vector3, dir: Vector3) -> FormStone:
	if c == null or r == null or not is_instance_valid(r) or not r.is_up():
		return null
	var gd: Dictionary = SwayMoves.move("gust").get("raised", {})
	var rad := float(gd.get("chunk_r", 0.3))
	var scn := c.get_tree().current_scene
	var p := at - dir * (rad + 0.05)
	var seed := absi(hash(Vector3i(roundi(p.x * 10.0), roundi(p.y * 10.0), roundi(p.z * 10.0)))) % 97
	var matter := r.matter if r.matter != "wood" else "earth"
	var s := FormStone.ball(scn, p, {"radius_m": rad, "mass_kg": float(gd.get("mass_kg", 25.0)), "life_s": float(gd.get("life_s", 20.0)),
			"sink_s": 1.0, "rise_s": 0.05}, seed, matter)
	s.base = Transform3D(Basis.IDENTITY, p)
	s.global_transform = s.base
	s.state = FormStone.State.RESTING
	r.apply_hit(maxf(r.hit_min, 1.0), at, dir)
	sfx("hurl", at, 0.0, 0.8)
	GatherFx.stone_chips(scn, at, -dir, 12)
	var td := {"rise_s": float(gd.get("rise_s", 0.06)), "chest_m": p.y - c.player.global_position.y, "tremble_deg": 0.2,
			"knock_mps": {"cannonball": float(gd.get("knock_mps", 5.0))},
			"hurl": {"cannonball": {"mps": [float(gd.get("mps", 26.0)), float(gd.get("mps", 26.0))], "gravity": float(gd.get("gravity", 4.0)),
					"damage": [float(gd.get("damage", 45.0)), float(gd.get("damage", 45.0))], "roll": true}}}
	var th := Throw.start(c, s, td)
	if th != null and th.lift != null:
		th.lift._ex.append(r.get_rid())        # (out through the wall it was torn from)
	return s


## The aim's help for a thrown stone (the user, 2026-10-04: "its hard to aim the stone spike"): a fighter who can still fight
## within ASSIST_DEG of the camera's ray (from `from`) and ASSIST_M, in plain sight of it (nothing solid between), the nearest
## the ray's line; null none. Nothing is drawn for it (no target cues: the owner's rule).
const ASSIST_DEG := 6.0
const ASSIST_M := 45.0


static func assist_target(c: SwayCaster, from: Vector3, dir: Vector3, ex: Array = []) -> Node3D:
	if c == null or c.player == null or dir.length_squared() < 1e-6:
		return null
	var best: Node3D = null
	var best_a := deg_to_rad(ASSIST_DEG)
	var space := c.player.get_world_3d().direct_space_state
	for n in c.get_tree().get_nodes_in_group(NpcFighter.GROUP):
		var f := n as NpcFighter
		if f == null or not NpcSenses.can_fight(f):
			continue
		var to := NpcSenses.chest_of(f) - from
		var dist := to.length()
		if dist < 1.0 or dist > ASSIST_M:
			continue
		var a := to.angle_to(dir)
		if a >= best_a:
			continue
		var exl: Array[RID] = [c.player.get_rid(), f.get_rid()]
		for r in ex:
			exl.append(r)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + to, 1, exl)).is_empty():
			continue
		best = f
		best_a = a
	return best


## The crosshair's point now (world): the camera's ray (from `from`, else the camera) past the player and `ex` (RIDs: the
## stone thrown), its hit, else 80 m along it; INF with no camera.
static func aim_point(c: SwayCaster, ex: Array = [], from := Vector3.INF) -> Vector3:
	var cam := c.player.camera if c != null and c.player != null else null
	if cam == null or not cam.is_inside_tree():
		return Vector3.INF
	if from == Vector3.INF:
		from = cam.global_position
	var dir := -cam.global_basis.z
	var exl: Array[RID] = [c.player.get_rid()]
	for r in ex:
		exl.append(r)
	var h := c.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, 0xFFFFFFFF, exl))
	return h.position if not h.is_empty() else from + dir * 80.0


## A Stone Form stone thrown (stone_form): held up by a GustLift (its hold: from where it lies in the ground to chest height
## over rise_s, a spike's point turning to the crosshair) and hurled at the crosshair as it is up, aimed a little high for its
## drop on the way; GustLift flies it, strikes whom it meets (Hit.deliver) and lands it. The crosshair is followed live, from
## where the camera stood over the shoulder as the spell was let go (its ray's way the camera's now, its start kept with the
## player: the aim's view, though the camera eases back to its own as the aim is let go). A thing in the physics it meets is
## knocked on (knock_mps.<kind> along its flight: SwayEffects.push_prop) and struck when it takes hits; a spike that met
## one falls (nothing to stick in). Group GROUP while it runs (the tests: target, struck, knocked).
class Throw:
	extends Node

	signal thrown(stone: FormStone, toward: Vector3)

	const GROUP := &"form_throws"

	var caster: SwayCaster
	var lift: GustLift
	var stone: FormStone
	var td := {}
	var rise_s := 0.25
	var t := 0.0
	var is_thrown := false
	## Where it was hurled at (the crosshair then), whom it struck ([who, damage]) and what it knocked on.
	var target := Vector3.INF
	var struck: Array = []
	var knocked: Array = []
	## The aim camera's place from the player's as the spell was let go (INF: no camera).
	var cam_off := Vector3.INF
	## A place it goes to instead of the crosshair (INF: the crosshair): Earth Shove's pull (the caster's feet), split.
	var fixed := Vector3.INF

	static func start(c: SwayCaster, s: FormStone, p_td: Dictionary) -> Throw:
		var th := Throw.new()
		th.name = "FormThrow"
		th.caster = c
		th.stone = s
		th.td = p_td
		th.rise_s = maxf(float(p_td.get("rise_s", 0.25)), 0.05)
		th.add_to_group(GROUP)
		if c.player.camera != null and c.player.camera.is_inside_tree():
			th.cam_off = c.player.camera.global_position - c.player.global_position
		var scn := c.get_tree().current_scene
		scn.add_child(th)
		# (from where it lies buried to chest height over the caster's feet; no strain, no draw to wait for)
		var rise_m := c.player.global_position.y + float(p_td.get("chest_m", 1.3)) - s.global_position.y
		var md := {"hold": {"tear_s": 0.0, "rise_m": rise_m, "draw_s": th.rise_s, "strain_start_s": 1000.0, "break_s": 1001.0,
				"tremble_deg": float(p_td.get("tremble_deg", 0.3))}, "hurl": p_td.get("hurl", {}), "mass_kg": 1000.0}
		th.lift = GustLift.begin(c, s, md)
		th.lift.aim = th._aim()
		th.lift.struck.connect(func(who: Node, dmg: float) -> void: th.struck.append([who, dmg]))
		th.lift.landed.connect(th._on_landed)
		return th

	func _physics_process(dt: float) -> void:
		if lift == null or not is_instance_valid(lift) or stone == null or not is_instance_valid(stone):
			queue_free()
			return
		t += dt
		if is_thrown:
			return                                # (GustLift flies it: _on_landed)
		var aim := _aim()
		if aim != Vector3.INF:
			lift.aim = aim
		if t >= rise_s:
			is_thrown = true
			target = lift.aim
			lift.hurl(_arced(target))
			thrown.emit(stone, target)

	## The crosshair's point now, from the aim's view (cam_off); a fighter near the crosshair (FormEffects.assist_target): his
	## chest, ahead of him by his pace over the flight.
	func _aim() -> Vector3:
		if fixed != Vector3.INF:
			return fixed
		var from := caster.player.global_position + cam_off if cam_off != Vector3.INF else Vector3.INF
		var cam := caster.player.camera
		if cam != null and cam.is_inside_tree():
			var f := FormEffects.assist_target(caster, from if from != Vector3.INF else cam.global_position, -cam.global_basis.z, [stone.get_rid()])
			if f != null:
				var chest := NpcSenses.chest_of(f)
				var hd: Dictionary = lift._hurl_d() if lift != null else {}
				var mps: Array = hd.get("mps", [30.0, 30.0])
				var tf := stone.global_position.distance_to(chest) / maxf(float(mps[mps.size() - 1]), 0.1)
				var v := NpcSenses.velocity_of(f)
				return chest + Vector3(v.x, 0.0, v.z) * tf
		return FormEffects.aim_point(caster, [stone.get_rid()], from)

	## `p` raised by the drop the flight's gravity gives it on the way there (so it arrives at `p`).
	func _arced(p: Vector3) -> Vector3:
		if p == Vector3.INF:
			return p
		var hd: Dictionary = lift._hurl_d()
		var mps: Array = hd.get("mps", [20.0, 20.0])
		var tf := stone.global_position.distance_to(p) / maxf(float(mps[mps.size() - 1]), 0.1)
		return p + Vector3.UP * 0.5 * float(hd.get("gravity", 6.0)) * tf * tf

	## It met the world at `at`: what is in the physics there is knocked on along its flight (and struck when it takes hits).
	func _on_landed(at: Vector3) -> void:
		var v := lift.velocity if is_instance_valid(lift) else Vector3.ZERO
		if v.length_squared() > 1e-4 and stone != null and is_instance_valid(stone):
			var q := PhysicsShapeQueryParameters3D.new()
			var sph := SphereShape3D.new()
			sph.radius = stone.radius + 0.35
			q.shape = sph
			q.transform = Transform3D(Basis.IDENTITY, at)
			q.exclude = [stone.get_rid(), caster.player.get_rid()]
			var kind := stone.kind
			var k := float((td.get("knock_mps", {}) as Dictionary).get(kind, 4.0))
			for hit in stone.get_world_3d().direct_space_state.intersect_shape(q, 8):
				var b := hit.get("collider") as RigidBody3D
				if b == null or b is FormStone or knocked.has(b):
					continue
				knocked.append(b)
				SwayEffects.push_prop(b, v.normalized() * k + Vector3.UP * k * 0.25, at, 400.0)
				if b.has_method(&"apply_hit"):
					Hit.deliver(b, lift.damage_now(), at, v.normalized(), caster.player)
					struck.append([b, lift.damage_now()])
			if kind == "spike" and not knocked.is_empty():
				stone.freeze = false              # (it met a thing that went on: nothing to stick in, it falls)
				stone.sleeping = false
		queue_free()


## The ground breaking as it rises, by its matter: dust and clods and stones (earth), mud thrown up, stone chips, a white
## cloud (snow).
static func _raised_fx(c: SwayCaster, foot: Vector3, width: float, matter := "earth") -> void:
	var scn := c.get_tree().current_scene
	match matter:
		"mud":
			GatherFx._dust(scn, foot + Vector3.UP * 0.1, Vector3.UP, 18, Vector2(0.08, 0.24), 1.0, Color(0.16, 0.11, 0.07, 0.75))
		"snow":
			GatherFx._dust(scn, foot + Vector3.UP * 0.2, Vector3.UP, 26, Vector2(0.25, 0.7), 1.8, Color(0.9, 0.93, 0.97, 0.5))
			GatherFx.soil(scn, foot, Vector3.UP, 6)
		"stone":
			GatherFx.fall_dust(scn, foot, width * 0.5)
			GatherFx.stone_chips(scn, foot + Vector3.UP * 0.2, Vector3.UP, 18)
		_:
			GatherFx.fall_dust(scn, foot, width * 0.5)
			GatherFx.soil(scn, foot, Vector3.UP, 14)
			GatherFx.stone_chips(scn, foot + Vector3.UP * 0.2, Vector3.UP, 10)
	sfx("rise", foot, 0.0, 0.55 if matter != "mud" else 0.45)
	sfx("rumble", foot, -2.0, 0.7)


# ---------------------------------------------------------------- mend
## What mend would do to `t` now: "ruin" (a built piece's ruin: stood up again, charred), "alight" (a piece burning: put out),
## "charred" (a piece standing charred: made whole), "worn" (a raised wall or pillar worn by shot: packed again), "" nothing.
static func mend_stage(t: Node) -> String:
	if t == null or not is_instance_valid(t):
		return ""
	if t is FireRuin:
		return "ruin" if (t as FireRuin).in_place == null and String((t as FireRuin).data.get("type", "")) != "" else ""
	if t is FormRaised:
		return "worn" if (t as FormRaised).worn() else ""
	if t is BuiltPiece:
		var fs := FireSpread.find(t.get_tree()) if t.is_inside_tree() else null
		if fs != null and fs.stage_of(t) != "":
			return "alight"
		return "charred" if charred(t as BuiltPiece) else ""
	return ""


## The piece shows charred wood (the fire's material on its look).
static func charred(p: BuiltPiece) -> bool:
	var m := FireRuin.material()
	for g in p.highlight_targets():
		if is_instance_valid(g) and (g as GeometryInstance3D).material_override == m:
			return true
	return false


## The wood mend wants for `stage` (0 for a raised wall).
static func wood_need(stage: String, d: Dictionary) -> int:
	var wd: Dictionary = d.get("wood", {})
	match stage:
		"ruin":
			return int(wd.get("ruin", 2))
		"alight", "charred":
			return int(wd.get("per_stage", 1))
	return 0


## The first of `kinds` the pack holds `n` of ("" none).
static func wood_kind(p: Node, kinds: Array, n: int) -> String:
	var inv := InventoryState.from_player(p)
	for k in kinds:
		if inv.pack_count(String(k)) >= n:
			return String(k)
	return ""


static func take_wood(p: Node, kind: String, n: int) -> bool:
	var inv := InventoryState.from_player(p)
	if inv.take(kind, n) < n:
		return false
	p.set(&"inventory_pack", inv.pack.duplicate(true))
	return true


static func mend(c: SwayCaster, t: Node3D, d: Dictionary) -> String:
	var stage := mend_stage(t)
	if stage == "":
		_tell(c, "Nothing to mend there")
		return ""
	var need := wood_need(stage, d)
	if need > 0:
		var kinds: Array = (d.get("wood", {}) as Dictionary).get("kinds", ["log"])
		var k := wood_kind(c.player, kinds, need)
		if k == "" or not take_wood(c.player, k, need):
			_tell(c, "No wood in the pack to mend with")
			return ""
	var at := t.global_position
	match stage:
		"worn":
			(t as FormRaised).mend()
			_tell(c, (t as FormRaised).mended_line)       # (by its matter: "The stones set again", "The logs set again")
		"alight":
			var fs := FireSpread.find(t.get_tree())
			if fs != null:
				fs.put_out(t, true)
			_tell(c, "The fire drawn out of the %s" % _name(t))
		"charred":
			var p := t as BuiltPiece
			p.dress(p.ctx)
			_tell(c, "The %s made whole" % _name(t))
		"ruin":
			var r := t as FireRuin
			var rd := r.data
			var w := BuildWorld.of(c.get_tree())
			var type := String(rd.get("type", ""))
			var xf := SaveParts.to_xf(rd.get("xf"))
			var g := PackedFloat32Array()
			for x in rd.get("ground", []):
				g.append(float(x))
			var fs := FireSpread.find(c.get_tree())
			if fs != null:
				fs.clear_ruin(r)
			else:
				r.queue_free()
			if w != null and type != "":
				var p := w.add_piece(type, xf, true, -1, g)
				if p != null:
					FireRuin.char_geometry(p.highlight_targets(), INF, 0.0)
					at = p.global_position
			_tell(c, "The %s stands again, charred" % BuildData.get_default().name_of(type).to_lower())
	var scn := c.get_tree().current_scene
	GatherFx.wood_chips(scn, at + Vector3.UP * 1.0, Vector3.UP, 10)
	sfx("mend", at, -2.0, 1.25)
	return stage


static func _name(t: Node) -> String:
	if t is BuiltPiece:
		var nm := BuildData.get_default().name_of((t as BuiltPiece).type)
		return nm.to_lower() if nm != "" else "piece"
	return "wall"


# ---------------------------------------------------------------- shared
## The ground under `p` (world): a ray down (to `down` m under it) through fixed bodies (not people, things in the physics,
## raised earth); the terrain's height where it finds nothing.
static func ground_at(n: Node, p: Vector3, down := 4.0) -> Vector3:
	var w := (n as Node3D).get_world_3d() if n is Node3D else null
	if w == null and n is SwayCaster and (n as SwayCaster).player != null:
		w = (n as SwayCaster).player.get_world_3d()
	if w != null:
		var space := w.direct_space_state
		var from := p + Vector3.UP * 1.5
		var ex: Array[RID] = []
		for i in 6:
			var q := PhysicsRayQueryParameters3D.create(from, p + Vector3.DOWN * down, 1, ex)
			var h := space.intersect_ray(q)
			if h.is_empty():
				break
			var col := h.collider as Object
			if col is CharacterBody3D or col is RigidBody3D or col is FormRaised or col is PhysicalBone3D:
				ex.append(h.rid)
				continue
			return h.position
	return Vector3(p.x, FrontierTerrain.height_at(p.x, p.z), p.z)


static func sfx(key: String, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	var id := StringName(String((SwayMoves.data().get("form_sfx", {}) as Dictionary).get(key, "")))
	if id == &"" or not Sfx.has(id):
		return
	Sfx.play_3d(id, at, db, pitch)


static func _tell(c: SwayCaster, text: String) -> void:
	if c != null and c.player != null and c.player.interactor != null and c.player.is_local:
		c.player.interactor.notice(text, 2.5)
