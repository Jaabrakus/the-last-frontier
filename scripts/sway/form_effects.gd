class_name FormEffects
extends RefCounted
## What a Form cast does (SwayEffects.apply hands the art "form" here; SwayCaster's cast; data/sway/moves.json). The matter
## comes from the place: what is raised leaves a hollow where its earth came from (FormHollow), mending takes wood from the
## pack. Static.
##
##   earth_wall    a wall of packed earth and stone (FormRaised "wall") rises across the caster's line just past the circle,
##                 the hollow where the circle was
##   stone_form    by the spell's mode (SwayCaster.mode_of): "spike", a jagged spike bursts up at the circle (a FormStone that
##                 stays, FormSpikes' burst round it: who stands there is struck and knocked off their feet); "cannonball", a
##                 round stone ball rises out of the ground there and rests on it (a FormStone in the physics). A hollow under
##                 each; both are stones for Gust to lift and hurl (GustLift)
##   pillar        a column (FormRaised "pillar"), by the mode: "self" rises under the caster and carries them up; cast in
##                 stride while running (launch.run_mps; practised and up: the untrained floor cast holds the caster still)
##                 a quick short one launches them up and forward, a boost when the cast falls within plant_window_s (0.045 s)
##                 before a foot plant or plant_after_s (0.02 s) after one (plant_times: the step cycle; the ring beats on
##                 each plant); cast in the air it rises where
##                 they will land (landing_point). "free": at the aimed circle (mode_range_m). A ring of hollow round its foot
##   mend          the piece back one stage (mend_stage): a ruin stands again (charred), a piece alight is put out, a charred
##                 one made whole, a raised wall worn by shot packed again; wood from the pack for each (not the earth wall)
## Dust, stone chips and a grinding of stone with each (Sfx ids from moves.json form_sfx, when they exist).

const MOVES := ["earth_wall", "stone_form", "pillar", "mend"]


static func handles(m: String) -> bool:
	return m in MOVES


static func apply(c: SwayCaster, m: String, t: Node3D, at: Vector3) -> void:
	if c == null or c.player == null:
		return
	var d := SwayMoves.move(m)
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
static func earth_wall(c: SwayCaster, at: Vector3, d: Dictionary) -> FormRaised:
	var w: Dictionary = d.get("wall", {})
	var way := way_to(c, at)
	var foot := ground_at(c, at + way * float(w.get("ahead_m", 0.75)))
	var across := Vector3.UP.cross(way).normalized()
	var xf := Transform3D(Basis(across, Vector3.UP, way), foot)
	var scn := c.get_tree().current_scene
	var r := FormRaised.raise(scn, "wall", xf, w, absi(hash(foot)) % 97)
	var h: Dictionary = d.get("hollow", {})
	FormHollow.dig(scn, ground_at(c, at - way * 0.15), way, float(h.get("width_m", 3.0)), float(h.get("depth_m", 1.5)), float(h.get("fade_s", 600.0)))
	_raised_fx(c, foot, float(w.get("width_m", 3.0)))
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
			# (where they come down; its top rising to just under their feet now, so they land on it, never thrown by it)
			how = "air"
			foot = landing_point(c)
			pd["rise_s"] = float(ld.get("air_rise_s", 0.45))
			pd["height_m"] = clampf(p.global_position.y - foot.y - 0.15, 0.4, float(pd.get("height_m", 3.0)))
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
	var r := FormRaised.raise(scn, "pillar", xf, pd, absi(hash(foot)) % 97)
	r.set_meta(&"pillar_mode", how)
	var h: Dictionary = d.get("hollow", {})
	FormHollow.dig(scn, foot, way, float(h.get("width_m", 2.1)), float(h.get("depth_m", 2.1)), float(h.get("fade_s", 600.0)))
	_raised_fx(c, foot, float(pd.get("radius_m", 0.55)) * 2.0)
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


## Where a player in the air will come down (world): their fall followed from their velocity (the player's gravity) until it
## meets something fixed; under them when it meets nothing within 4 s.
static func landing_point(c: SwayCaster) -> Vector3:
	var p := c.player
	var pos := p.global_position
	var v := p.velocity
	var g := float(p.get(&"_gravity")) if p.get(&"_gravity") != null else 9.8
	var space := p.get_world_3d().direct_space_state
	var dt := 1.0 / 30.0
	for i in 120:
		var nxt := pos + v * dt
		v.y -= g * dt
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.05, nxt, 1, [p.get_rid()])
		var h := space.intersect_ray(q)
		if not h.is_empty() and not (h.collider is CharacterBody3D or h.collider is RigidBody3D):
			return h.position
		pos = nxt
	return ground_at(c, pos)


# ---------------------------------------------------------------- stone form
## Stone Form of `mode` ("spike" or "cannonball") at `at`: the stone it leaves (a FormStone).
static func stone_form(c: SwayCaster, at: Vector3, d: Dictionary, mode := "spike") -> FormStone:
	var way := way_to(c, at)
	var foot := ground_at(c, at)
	var scn := c.get_tree().current_scene
	var seed := absi(hash(Vector3i(roundi(foot.x * 10.0), roundi(foot.y * 10.0), roundi(foot.z * 10.0)))) % 97
	var s: FormStone
	if mode == "cannonball":
		s = FormStone.ball(scn, foot, d.get("cannonball", {}), seed)
		GatherFx.soil(scn, foot, Vector3.UP, 10)
		GatherFx.stone_chips(scn, foot + Vector3.UP * 0.1, Vector3.UP, 8)
		sfx("rise", foot, -2.0, 0.8)
	else:
		var sd: Dictionary = d.get("spike", {})
		s = FormStone.spike(scn, foot, way, sd, seed)
		FormSpikes.burst(scn, c, foot, way, sd, s)
	var h: Dictionary = d.get("hollow", {})
	FormHollow.dig(scn, foot, way, float(h.get("width_m", 1.3)), float(h.get("depth_m", 1.3)), float(h.get("fade_s", 600.0)))
	sfx("rumble", foot, -4.0, 1.1)
	return s


static func _raised_fx(c: SwayCaster, foot: Vector3, width: float) -> void:
	var scn := c.get_tree().current_scene
	GatherFx.fall_dust(scn, foot, width * 0.5)
	GatherFx.soil(scn, foot, Vector3.UP, 14)
	GatherFx.stone_chips(scn, foot + Vector3.UP * 0.2, Vector3.UP, 10)
	sfx("rise", foot, 0.0, 0.55)
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
			_tell(c, "The earth packed again")
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
## The ground under `p` (world): a ray down through fixed bodies (not people, things in the physics, raised earth); the
## terrain's height where it finds nothing.
static func ground_at(n: Node, p: Vector3) -> Vector3:
	var w := (n as Node3D).get_world_3d() if n is Node3D else null
	if w == null and n is SwayCaster and (n as SwayCaster).player != null:
		w = (n as SwayCaster).player.get_world_3d()
	if w != null:
		var space := w.direct_space_state
		var from := p + Vector3.UP * 1.5
		var ex: Array[RID] = []
		for i in 6:
			var q := PhysicsRayQueryParameters3D.create(from, p + Vector3.DOWN * 4.0, 1, ex)
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
