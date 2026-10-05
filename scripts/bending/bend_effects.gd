class_name BendEffects
extends RefCounted
## What a bending move does when cast (docs/bending_design.md; data/sway/moves.json, a move's "bend": a spec for each of its
## modes, by "do"). FormEffects.apply hands a move's mode here when the move has a spec for it; the lock is SwayCaster's as
## for every spell (the circle at the caster's feet: "self_lock"), the aim taken at the release (aim: the crosshair, or a
## fighter near it: FormEffects.assist_target).
##   bolt        BendBolt(s) from the chest along the aim: count, every_s apart, spread_deg; mps, gravity, damage, knock_mps,
##               up_mps, radius_m, range_m, long, erode (on earth walls), root_s / slow_s on whom it strikes; low: along
##               the ground
##   cone, ring  whoever is within range_m in deg before the caster (a ring: all round): damage, knock (up_mps), root_s,
##               slow_s; put_out (fire walls and burning ground in it go out), melt (ice walls in it crumble)
##   dash        the caster thrown: fwd_mps along the aim (back: behind, side: to a side), up_mps; burn: the ground left
##               alight; shove: whoever is near knocked aside
##   buff        on the caster for s: anchor (no knockback), hover / glide (a slow fall), run / scooter (a fast pace),
##               redirect_lightning (lightning that strikes is sent back)
##   zone        a BendZone (kind `zone`) at "self", "front" (ahead_m) or "aim" (range_m): barriers, the ground, guards
##   status_at   at the aim's place (radius_m): root_s, slow_s, damage, up_mps (a knock-up); hollow: a hollow left
##   lightning   from the caster's hand along the aim at once; a fighter or player guarding with redirect_lightning sends
##               it back
##   heal, cleanse, draw (water back), grab (pulled to the caster), kick_up (a rock up before the caster), column (a pillar
##   under the aim's place, throwing whoever stands there), shell (walls all round), ramp (a slope), ice_wall, freeze_water
##   (a wall of water turned to ice), thaw / melt (ice gone), brace (one's wall takes the next hit free), shove (earth:
##   push, pull, split a stone or a raised wall)
## `water` in a spec: what it spends of a waterbender's meter (Bending.spend; not enough: nothing, a notice).

const FormMatter := preload("res://scripts/sway/form_matter.gd")

## What the last cast did (the tests): {do, mode, ...}.
static var last := {}


static func apply(c: SwayCaster, m: String, mode: String, spec: Dictionary, t: Node3D, at: Vector3) -> void:
	if c == null or c.player == null:
		return
	var p := c.player
	var cost := float(spec.get("water", 0.0))
	if cost > 0.0 and not Bending.of(p).spend(cost):
		if p.interactor != null and p.is_local:
			p.interactor.notice("Not enough water: stand by water, or Flow (draw)", 1.6)
		last = {"do": "dry", "mode": mode}
		return
	var a := aim(c)
	last = {"do": String(spec.get("do", "")), "mode": mode, "move": m, "aim": a.point}
	var kind := String(spec.get("kind", "stone"))
	BendLooks.sound(kind, "cast", p.global_position + Vector3.UP, -4.0)
	match String(spec.get("do", "")):
		"bolt":
			bolts(p, a, spec)
		"cone":
			cone(p, a.from, a.flat, spec)
		"ring":
			cone(p, p.global_position + Vector3.UP, a.flat, spec, true)
		"dash":
			dash(p, a.flat, spec)
		"buff":
			buff(p, spec)
		"zone":
			zone(p, a, spec)
		"status_at":
			status_at(p, _ground_at(p, a, spec), spec)
		"lightning":
			lightning(p, a, spec)
		"heal":
			BendStatus.heal(p, float(spec.get("amount", 15.0)))
			BendLooks.burst(p.global_position + Vector3.UP, "water" if kind == "water" else "air", 20, Vector3.UP, 60.0, 1.5)
		"cleanse":
			for k: StringName in [&"bend_root", &"bend_slow"]:
				if p.has_meta(k):
					p.set_meta(k, 0.0)
					BendStatus._end_timed(p, k, 0.0 if k == &"bend_root" else BendStatus.SLOW_MPS)
			BendLooks.burst(p.global_position + Vector3.UP, "water", 18)
		"draw":
			var b := Bending.of(p)
			var dr: Array = (SwayMoves.data().get("water_meter", {}) as Dictionary).get("draw", [10.0, 60.0])
			b.water = minf(b.water + float(dr[1] if b.near_water() else dr[0]), b.water_max)
			BendLooks.burst(p.global_position + Vector3.UP * 0.5, "water", 24, Vector3.UP, 40.0, 3.0)
		"grab":
			grab(p, a, spec)
		"kick_up":
			kick_up(p, a.flat, spec)
		"column":
			column(p, _ground_at(p, a, spec), spec)
		"shell":
			shell(p, spec)
		"ramp":
			ramp(p, a.flat)
		"ice_wall":
			ice_wall(p, a.flat)
		"freeze_water":
			freeze_water(p, _ground_at(p, a, spec), a.flat)
		"thaw":
			melt(p, _ground_at(p, a, spec), 6.0)
		"melt":
			melt(p, p.global_position, float(spec.get("radius_m", 6.0)))
		"brace":
			brace(p, float(spec.get("range_m", 12.0)))
		"shove":
			shove(c, a, String(spec.get("how", "push")), spec)


# ---------------------------------------------------------------- the aim
## {from (the chest), dir (to the point), flat (level), point (the crosshair's, or a fighter's chest near it), target}.
static func aim(c: SwayCaster) -> Dictionary:
	var p := c.player
	var chest := p.global_position + Vector3.UP * 1.35
	var cam := p.camera
	var point := FormEffects.aim_point(c)
	var target: Node3D = null
	if cam != null and cam.is_inside_tree():
		target = FormEffects.assist_target(c, cam.global_position, -cam.global_basis.z)
		if target != null:
			point = NpcSenses.chest_of(target)
	if point == Vector3.INF:
		point = chest - p.global_basis.z * 20.0
	var flat := point - p.global_position
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 1e-4 else -p.global_basis.z
	var from := chest + flat * 0.6
	return {"from": from, "dir": (point - from).normalized(), "flat": flat, "point": point, "target": target}


## The ground at the aim's place, no further than spec.range_m from the caster.
static func _ground_at(p: Node3D, a: Dictionary, spec: Dictionary) -> Vector3:
	var pt: Vector3 = a.point
	var r := float(spec.get("range_m", 20.0))
	var v := pt - p.global_position
	v.y = 0.0
	if v.length() > r:
		pt = p.global_position + v.normalized() * r
	return FormEffects.ground_at(p, pt)


# ---------------------------------------------------------------- the kinds
static func bolts(p: FrontierPlayer, a: Dictionary, spec: Dictionary) -> void:
	var n := int(spec.get("count", 1))
	var every := float(spec.get("every_s", 0.0))
	var spread := deg_to_rad(float(spec.get("spread_deg", 0.0)))
	var low := bool(spec.get("low", false))
	for i in n:
		var fire := func() -> void:
			if not is_instance_valid(p):
				return
			var a2 := a
			if every > 0.0 and i > 0:
				a2 = aim(SwayCaster.of(p)) if SwayCaster.of(p) != null else a
			var dir: Vector3 = a2.dir
			if low:
				dir = Vector3(a2.flat.x, -0.02, a2.flat.z).normalized()
			if spread > 0.0 and n > 1:
				var off := (float(i) - float(n - 1) * 0.5) / maxf(float(n - 1) * 0.5, 1.0)
				dir = dir.rotated(Vector3.UP, off * spread + randf_range(-0.2, 0.2) * spread)
				dir = dir.rotated(dir.cross(Vector3.UP).normalized(), randf_range(-0.5, 0.5) * spread)
			var from: Vector3 = a2.from
			if low:
				from = Vector3(from.x, p.global_position.y + 0.45, from.z)
			BendBolt.launch(p, from, dir, spec)
		if every > 0.0 and i > 0:
			p.get_tree().create_timer(every * i, false).timeout.connect(fire)
		else:
			fire.call()


## A cone (or, `ring`, all round) before the caster from `from` along `flat`.
static func cone(p: Node3D, from: Vector3, flat: Vector3, spec: Dictionary, ring := false) -> void:
	var r := float(spec.get("radius_m", spec.get("range_m", 5.0)))
	var deg := 360.0 if ring else float(spec.get("deg", 60.0))
	var kind := String(spec.get("kind", "air"))
	var hit := 0
	for e in BendStatus.near(p, p.global_position, r):
		var n: Node3D = e[0]
		var to := n.global_position - p.global_position
		to.y = 0.0
		if not ring and to.length() > 0.3 and rad_to_deg(to.normalized().angle_to(flat)) > deg * 0.5:
			continue
		var away := to.normalized() if to.length_squared() > 1e-4 else flat
		BendStatus.hurt(n, float(spec.get("damage", 0.0)), n.global_position + Vector3.UP, away, p)
		BendStatus.knock(n, away * float(spec.get("knock_mps", 0.0)) + Vector3.UP * float(spec.get("up_mps", 0.0)), p)
		if float(spec.get("root_s", 0.0)) > 0.0:
			BendStatus.root(n, float(spec.root_s))
		if float(spec.get("slow_s", 0.0)) > 0.0:
			BendStatus.slow(n, float(spec.slow_s))
		hit += 1
	last["hit"] = hit
	if bool(spec.get("put_out", false)) or bool(spec.get("melt", false)):
		for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
			var bz := z as BendZone
			var to := bz.global_position - p.global_position
			if to.length() > r + 2.0:
				continue
			if bool(spec.get("put_out", false)) and bz.kind in ["fire_wall", "burn"]:
				BendLooks.burst(bz.global_position + Vector3.UP, "steam", 30, Vector3.UP, 90.0, 2.5, 1.0)
				bz.end()
			if bool(spec.get("melt", false)) and bz.kind == "ice_patch":
				bz.end()
		if bool(spec.get("melt", false)):
			melt(p, p.global_position + flat * r * 0.5, r * 0.7)
	BendLooks.blast(p.global_position + Vector3.UP * 1.1, flat, deg, r, kind)


static func dash(p: FrontierPlayer, flat: Vector3, spec: Dictionary) -> void:
	var dir := flat
	if bool(spec.get("back", false)):
		dir = -flat
	elif bool(spec.get("side", false)):
		var right := flat.cross(Vector3.UP).normalized()
		var lr := Input.get_axis(&"move_left", &"move_right") if InputMap.has_action(&"move_left") else 0.0
		dir = right * (signf(lr) if absf(lr) > 0.1 else (1.0 if randf() < 0.5 else -1.0))
	var kind := String(spec.get("kind", "air"))
	var v := dir * float(spec.get("fwd_mps", 10.0)) + Vector3.UP * float(spec.get("up_mps", 0.0))
	p.velocity = Vector3(v.x, maxf(p.velocity.y, 0.0) + v.y, v.z)
	BendMotion.of(p).carry(dir * float(spec.get("fwd_mps", 10.0)), 0.25)
	BendLooks.burst(p.global_position + Vector3.UP * 0.3, "stone" if bool(spec.get("dust", false)) else kind, 22, -dir + Vector3.UP * 0.3, 50.0, 4.0, 0.4)
	if bool(spec.get("burn", false)):
		var start := p.global_position
		BendZone.make(p, "burn", start + dir * 3.0, {"width_m": 1.4, "height_m": 0.4, "thick_m": 6.0, "life_s": 3.0, "damage_s": 10.0}, dir)
	if bool(spec.get("shove", false)):
		for e in BendStatus.near(p, p.global_position + dir * 2.0, 3.0):
			var n: Node3D = e[0]
			var side := (n.global_position - p.global_position).cross(Vector3.UP).normalized()
			BendStatus.knock(n, side * 6.0 + Vector3.UP * 1.0, p)


static func buff(p: FrontierPlayer, spec: Dictionary) -> void:
	var s := float(spec.get("s", 2.0))
	var kind := String(spec.get("kind", "air"))
	match String(spec.get("buff", "")):
		"anchor":
			BendStatus.anchor(p, s)
			BendLooks.burst(p.global_position, "stone", 16, Vector3.UP, 70.0, 2.0)
		"hover", "glide":
			BendMotion.of(p).fall(float(spec.get("fall_mps", 2.0)), s, kind)
		"run", "scooter":
			BendMotion.of(p).run(float(spec.get("mps", 10.0)), s, kind)
		"redirect_lightning":
			p.set_meta(&"bend_redirect_lightning", BendStatus.now() + s)
			BendLooks.burst(p.global_position + Vector3.UP * 1.2, "lightning", 10, Vector3.UP, 180.0, 1.0, 0.2)


static func zone(p: FrontierPlayer, a: Dictionary, spec: Dictionary) -> BendZone:
	var where := String(spec.get("at", "self"))
	var at := p.global_position
	match where:
		"front":
			at = FormEffects.ground_at(p, p.global_position + (a.flat as Vector3) * float(spec.get("ahead_m", 2.0)))
		"aim":
			at = _ground_at(p, a, spec)
	var z := BendZone.make(p, String(spec.get("zone", "bubble")), at, spec, a.flat)
	last["zone"] = z
	last["zone_kind"] = z.kind
	return z


static func status_at(p: Node3D, at: Vector3, spec: Dictionary) -> void:
	var r := float(spec.get("radius_m", 1.5))
	var kind := String(spec.get("kind", "stone"))
	var n_hit := 0
	for e in BendStatus.near(p, at, r):
		var n: Node3D = e[0]
		BendStatus.hurt(n, float(spec.get("damage", 0.0)), n.global_position + Vector3.UP * 0.3, Vector3.UP, p)
		if float(spec.get("up_mps", 0.0)) > 0.0:
			BendStatus.knock(n, Vector3.UP * float(spec.up_mps), p)
		if float(spec.get("root_s", 0.0)) > 0.0:
			BendStatus.root(n, float(spec.root_s))
		if float(spec.get("slow_s", 0.0)) > 0.0:
			BendStatus.slow(n, float(spec.slow_s))
		n_hit += 1
	last["hit"] = n_hit
	BendLooks.burst(at + Vector3.UP * 0.1, kind, 26, Vector3.UP, 50.0, 4.0 if float(spec.get("up_mps", 0.0)) > 0.0 else 2.0, 0.4)
	if bool(spec.get("hollow", false)):
		FormHollow.dig(p.get_tree().current_scene, at, Vector3.FORWARD, r * 2.0, r * 2.0, 20.0)
	BendLooks.sound(kind, "hit", at, -3.0)


static func lightning(p: FrontierPlayer, a: Dictionary, spec: Dictionary) -> void:
	var from: Vector3 = a.from
	var r := float(spec.get("range_m", 45.0))
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + (a.dir as Vector3) * r, 0xFFFFFFFF, [p.get_rid()])
	var h := space.intersect_ray(q)
	var end: Vector3 = h.position if not h.is_empty() else from + (a.dir as Vector3) * r
	BendLooks.lightning(from, end)
	BendLooks.sound("lightning", "cast", from)
	var who := BendBolt._taker(h.collider as Node) if not h.is_empty() else null
	last["hit"] = 0
	if who == null or not BendStatus.can_take(who, p):
		return
	if BendStatus.until(who, &"bend_redirect_lightning") > 0.0:
		# (sent back: it strikes its caster)
		var back := (who as Node3D).global_position + Vector3.UP * 1.3
		BendLooks.lightning(back, p.global_position + Vector3.UP * 1.3)
		BendStatus.hurt(p, float(spec.get("damage", 50.0)), p.global_position + Vector3.UP, -(a.dir as Vector3), who)
		last["redirected"] = true
		return
	BendStatus.hurt(who, float(spec.get("damage", 50.0)), end, a.dir, p)
	BendStatus.knock(who, (a.flat as Vector3) * float(spec.get("knock_mps", 6.0)) + Vector3.UP * 2.0, p)
	last["hit"] = 1


static func grab(p: FrontierPlayer, a: Dictionary, spec: Dictionary) -> void:
	var t: Node3D = a.target
	if t == null:
		var near := BendStatus.near(p, _ground_at(p, a, spec), 2.0)
		t = near[0][0] if not near.is_empty() else null
	var tip: Vector3 = (a.point as Vector3)
	BendBolt.launch(p, a.from, a.dir, {"kind": "water", "mps": 40.0, "damage": 0.0, "knock_mps": 0.0, "radius_m": 0.12, "range_m": 3.0})
	if t == null or t.global_position.distance_to(p.global_position) > float(spec.get("range_m", 14.0)):
		return
	var to := p.global_position - t.global_position
	to.y = 0.0
	BendStatus.hurt(t, float(spec.get("damage", 4.0)), t.global_position + Vector3.UP, to.normalized(), p)
	BendStatus.knock(t, to.normalized() * float(spec.get("pull_mps", 10.0)) + Vector3.UP * 2.0, p)
	BendLooks.burst(t.global_position + Vector3.UP, "water", 20)
	last["hit"] = 1
	tip = tip


static func kick_up(p: FrontierPlayer, flat: Vector3, spec: Dictionary) -> FormStone:
	var foot := FormEffects.ground_at(p, p.global_position + flat * 1.2)
	var s := FormStone.ball(p.get_tree().current_scene, foot, {"radius_m": float(spec.get("radius_m", 0.32)), "mass_kg": 30.0,
			"rise_s": 0.25, "life_s": 30.0, "sink_s": 1.0}, randi() % 97, FormMatter.of_ground(p.get_tree(), foot))
	BendLooks.burst(foot + Vector3.UP * 0.2, "stone", 16)
	last["stone"] = s
	return s


static func column(p: FrontierPlayer, at: Vector3, spec: Dictionary) -> FormRaised:
	var pd: Dictionary = (SwayMoves.move("pillar").get("pillar", {}) as Dictionary)
	var matter := FormMatter.of_ground(p.get_tree(), at)
	if matter == "wood":
		matter = "earth"
	var wn := FormMatter.numbers(pd, FormMatter.entry("pillar", matter), matter)
	var r := FormRaised.raise(p.get_tree().current_scene, "pillar", Transform3D(Basis.IDENTITY, at), wn, absi(hash(at)) % 97)
	r.set_meta(&"bend_by", p.get_instance_id())
	status_at(p, at, {"radius_m": float(spec.get("radius_m", 1.3)), "up_mps": float(spec.get("up_mps", 11.0)),
			"damage": float(spec.get("damage", 10.0)), "kind": "stone"})
	return r


static func _wall(p: Node3D, xf: Transform3D, matter: String, life := -1.0, w := -1.0) -> FormRaised:
	var wd: Dictionary = (SwayMoves.move("earth_wall").get("wall", {}) as Dictionary)
	var wn := FormMatter.numbers(wd, FormMatter.entry("earth_wall", matter), matter)
	if life > 0.0:
		wn["life_s"] = life
	if w > 0.0:
		wn["width_m"] = w
	var r := FormRaised.raise(p.get_tree().current_scene, "wall", xf, wn, absi(hash(xf.origin)) % 97)
	r.set_meta(&"bend_by", p.get_instance_id())
	return r


static func shell(p: FrontierPlayer, spec: Dictionary) -> void:
	var matter := FormMatter.of_ground(p.get_tree(), p.global_position)
	if matter == "wood":
		matter = "earth"
	for i in 4:
		var way := Vector3.FORWARD.rotated(Vector3.UP, i * PI * 0.5)
		var foot := FormEffects.ground_at(p, p.global_position + way * 1.4)
		var x := Vector3.UP.cross(way).normalized()
		_wall(p, Transform3D(Basis(x, Vector3.UP, way), foot), matter, float(spec.get("life_s", 3.0)), 2.9)
	BendLooks.burst(p.global_position, "stone", 30, Vector3.UP, 80.0, 3.0)


static func ramp(p: FrontierPlayer, flat: Vector3) -> void:
	var foot := FormEffects.ground_at(p, p.global_position + flat * 2.5)
	var x := Vector3.UP.cross(flat).normalized()
	var tilt := Basis(x, deg_to_rad(-62.0))
	var b := tilt * Basis(x, Vector3.UP, flat)
	var matter := FormMatter.of_ground(p.get_tree(), foot)
	_wall(p, Transform3D(b, foot), "earth" if matter == "wood" else matter, 20.0, 2.0)


static func ice_wall(p: FrontierPlayer, flat: Vector3) -> FormRaised:
	var foot := FormEffects.ground_at(p, p.global_position + flat * 1.8)
	var x := Vector3.UP.cross(flat).normalized()
	var r := _wall(p, Transform3D(Basis(x, Vector3.UP, flat), foot), "snow")
	r.set_meta(&"bend_ice", true)
	BendLooks.burst(foot + Vector3.UP, "ice", 24)
	return r


static func freeze_water(p: FrontierPlayer, at: Vector3, flat: Vector3) -> void:
	for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz.kind == "water_wall" and bz.global_position.distance_to(at) < 8.0:
			var xf := bz.global_transform
			bz.end()
			var r := _wall(p, Transform3D(xf.basis.orthonormalized(), xf.origin), "snow")
			r.set_meta(&"bend_ice", true)
			BendLooks.burst(xf.origin + Vector3.UP, "ice", 30)
			last["froze"] = r
			return
	BendZone.make(p, "ice_patch", at, {"radius_m": 3.0, "life_s": 8.0}, flat)


## Ice within `r` of `at` gone: ice walls crumble (to water), ice patches end.
static func melt(p: Node3D, at: Vector3, r: float) -> int:
	var n := 0
	for w in p.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr != null and fr.is_up() and (fr.has_meta(&"bend_ice") or fr.matter == "snow") and fr.global_position.distance_to(at) <= r:
			BendLooks.burst(fr.global_position + Vector3.UP, "water", 30)
			fr.crumble("melted")
			n += 1
	for z in p.get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz.kind == "ice_patch" and bz.global_position.distance_to(at) <= r + bz.radius:
			bz.end()
			n += 1
	last["melted"] = n
	return n


static func brace(p: FrontierPlayer, r: float) -> void:
	var best: FormRaised = null
	var bd := r
	for w in p.get_tree().get_nodes_in_group(FormRaised.GROUP):
		var fr := w as FormRaised
		if fr == null or not fr.is_up() or int(fr.get_meta(&"bend_by", -1)) != p.get_instance_id():
			continue
		var d := fr.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = fr
	if best != null:
		best.set_meta(&"bend_brace", true)
		BendLooks.burst(best.global_position + Vector3.UP, "stone", 14)
	last["braced"] = best


## Earth Shove: a stone (held by the caster first: a Catch's; else the one the aim is on, or the nearest) or a raised wall
## or pillar on the aim: push (hurled along the aim; a wall's chunk torn out and fired through it), pull (to the caster's
## feet), split (a chunk broken into three flying in a spread).
static func shove(c: SwayCaster, a: Dictionary, how: String, spec: Dictionary) -> void:
	var p := c.player
	var r := float(spec.get("range_m", 20.0))
	var thing := _shove_target(p, a, r)
	last["target"] = thing
	if thing == null:
		if p.interactor != null and p.is_local:
			p.interactor.notice("Nothing of stone there to shove", 1.4)
		return
	var feet := FormEffects.ground_at(p, p.global_position + (a.flat as Vector3) * 1.5) + Vector3.UP * 0.4
	if thing is FormRaised:
		var w := thing as FormRaised
		var hit_at := _face_point(w, p)
		var dir := ((a.point as Vector3) - hit_at).normalized()
		match how:
			"push":
				FormEffects.gust_chunk(c, w, hit_at, dir)
			"pull":
				var s := FormEffects.gust_chunk(c, w, hit_at, dir)
				_fix_throw(s, feet)
			"split":
				for i in 3:
					var s := FormEffects.gust_chunk(c, w, hit_at + Vector3.UP * (i - 1) * 0.3, dir)
					if s != null:
						_fix_throw(s, (a.point as Vector3) + dir.cross(Vector3.UP).normalized() * (float(i) - 1.0) * 2.5)
		return
	var st := thing as Node3D
	if st.has_meta(&"bend_held_by"):
		st.remove_meta(&"bend_held_by")
	var td: Dictionary = (SwayMoves.move("stone_form").get("throw", {}) as Dictionary).duplicate(true)
	var gs: Dictionary = (SwayMoves.move("gust").get("stone", {}) as Dictionary).get("hurl", {})
	td["hurl"] = gs
	td["rise_s"] = 0.2
	if st is FormStone and (st as FormStone).state == FormStone.State.RISING:
		(st as FormStone).state = FormStone.State.RESTING
	var th := FormEffects.Throw.start(c, st as FormStone, td) if st is FormStone else null
	if th == null:
		if st is RigidBody3D:
			(st as RigidBody3D).freeze = false
			SwayEffects.push_prop(st as RigidBody3D, (a.dir as Vector3) * 14.0, st.global_position, 400.0)
		return
	if how == "pull":
		th.fixed = feet
	elif how == "split":
		th.fixed = Vector3.INF


static func _fix_throw(s: FormStone, toward: Vector3) -> void:
	if s == null:
		return
	for t in s.get_tree().get_nodes_in_group(FormEffects.Throw.GROUP):
		var th := t as FormEffects.Throw
		if th != null and th.stone == s:
			th.fixed = toward


## The thing to shove: a stone the caster holds; else what the aim's ray meets (a stone, a raised wall or pillar) within
## `r`; else the nearest stone to the aim's line within 3 m.
static func _shove_target(p: FrontierPlayer, a: Dictionary, r: float) -> Node3D:
	for s in p.get_tree().get_nodes_in_group(FormStone.GROUP):
		if int((s as Node).get_meta(&"bend_held_by", -1)) == p.get_instance_id():
			return s
	var cam := p.camera
	if cam != null and cam.is_inside_tree():
		var from := cam.global_position
		var h := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * (r + 6.0), 0xFFFFFFFF, [p.get_rid()]))
		if not h.is_empty():
			var n := h.collider as Node
			for i in 4:
				if n == null:
					break
				if n is FormRaised or GustLift.is_stone(n):
					return n as Node3D
				n = n.get_parent()
	var best: Node3D = null
	var bd := 3.0
	for s in p.get_tree().get_nodes_in_group(FormStone.GROUP):
		var q := (s as Node3D).global_position
		if q.distance_to(p.global_position) > r:
			continue
		var line := Geometry3D.get_closest_point_to_segment(q, a.from, (a.from as Vector3) + (a.dir as Vector3) * r)
		var d := q.distance_to(line)
		if d < bd:
			bd = d
			best = s
	return best


static func _face_point(w: FormRaised, p: Node3D) -> Vector3:
	var to := p.global_position - w.global_position
	to.y = 0.0
	var c := w.global_position + Vector3.UP * minf(1.0, w.size.y * 0.5)
	return c + to.normalized() * (w.size.z * 0.5 if w.kind == "wall" else w.size.x * 0.5)
