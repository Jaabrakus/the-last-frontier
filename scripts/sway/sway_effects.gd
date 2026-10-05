class_name SwayEffects
extends RefCounted
## What a Sway cast does (SwayCaster._cast; data/sway/moves.json; docs/main_story.md 11.2, 11.8: "Gust and Draw are
## impulses"). Static.
##
##   gust        a push from the caster's chest at the locked point, full within near_full_m and down to far_share at
##               the move's range:
##                 a fighter (NpcFighter) is thrown back people_mps and staggers (its hit reaction from the side the gust
##                 came; NpcFighter.shove(push, by) when it has one), and turns on whoever did it (its brain's hurt)
##                 an animal (WildAnimal) is shoved animal_mps (a skid) and runs from the caster (prey bolt, a pack flees)
##                 a prop (RigidBody3D) is pushed prop_mps and up_mps (less when heavier than heavy_kg; a frozen one
##                 woken, unless meta sway_fixed); a dropped torch's flame goes out
##                 a lit campfire is blown out (Campfire.smother), a torch's flame snuffed, a built piece still catching
##                 put out (FireSpread.put_out); and every other flame within snuff_m of the point (not the caster's own)
##   first_lock  the target lifted up_m and set aside_m to the caster's right (or to its meta sway_lift_to, world) over
##               lift.s, turning a little, then let fall (a rigid body unfrozen, unless meta sway_keep_frozen); the
##               caster's `lifted` signal at the end. Costs nothing.
##   form moves  FormEffects (earth_wall, stone_form, pillar, mend). Gust on a stone or a sail is a hold, not a push here
##               (SwayCaster's HOLDING: GustLift lifts and hurls the stone).


static func apply(c: SwayCaster, m: String, t: Node3D, at: Vector3) -> void:
	if c == null or t == null or not is_instance_valid(t):
		return
	match m:
		"gust":
			gust(c, t, at)
		"first_lock":
			lift(c, t)
		_:
			if FormEffects.handles(m):
				FormEffects.apply(c, m, t, at)       # (the art "form": the earth wall, stone form, the pillar, mend)


# ---------------------------------------------------------------- gust
static func gust(c: SwayCaster, t: Node3D, at: Vector3) -> void:
	var d := SwayMoves.move("gust")
	var push: Dictionary = d.get("push", {})
	var from := c.chest()
	var to := at - from
	var dist := to.length()
	var flat := Vector3(to.x, 0.0, to.z)
	flat = flat.normalized() if flat.length_squared() > 1e-4 else -c.player.global_basis.z
	var dir := to.normalized() if dist > 0.01 else flat
	var gm := c.mode_of("gust")
	if gm == "pull":
		flat = -flat                             # (the user, 2026-10-04: gust "can be push or pull")
	elif gm == "lift" and (t is NpcFighter or t is FrontierPlayer or t is WildAnimal):
		BendStatus.knock(t, Vector3.UP * float(push.get("lift_mps", 9.0)) + flat * 1.5, c.player)
		return
	if t is FormRaised:
		FormEffects.gust_chunk(c, t as FormRaised, at, dir)
		return
	var near := float(push.get("near_full_m", 8.0))
	var reach := float(d.get("range_m", 25.0))
	var k := lerpf(1.0, float(push.get("far_share", 0.45)), clampf((dist - near) / maxf(reach - near, 0.1), 0.0, 1.0))
	if t is NpcFighter:
		shove_fighter(t as NpcFighter, flat * float(push.get("people_mps", 5.0)) * k, c.player)
	elif t is WildAnimal:
		shove_animal(t as WildAnimal, flat * float(push.get("animal_mps", 4.5)) * k, from)
	elif t is Campfire:
		(t as Campfire).smother()
	elif t is TorchFire:
		snuff(t as TorchFire)
	elif t is BuiltPiece or t.is_in_group(FireSpread.BURNABLE_GROUP):
		var fs := FireSpread.find(t.get_tree())
		if fs != null:
			fs.put_out(t)
	if t is RigidBody3D:
		push_prop(t as RigidBody3D, dir * float(push.get("prop_mps", 6.5)) * k + Vector3.UP * float(push.get("up_mps", 1.6)) * k,
				at, float(push.get("heavy_kg", 120.0)))
		if t is DroppedTorch and (t as DroppedTorch).state != null:
			(t as DroppedTorch).state.snuff("gust")
	blow_out_near(c, at, float(push.get("snuff_m", 1.4)))


## Thrown back by `push` (m/s, flat) and staggered; the brain told who did it.
static func shove_fighter(f: NpcFighter, push: Vector3, by: Node) -> void:
	if f == null or f.is_dead():
		return
	if f.has_method(&"shove"):
		f.call(&"shove", push, by)
		return
	f.velocity.x = push.x
	f.velocity.z = push.z
	if push.length_squared() > 1e-6:
		f._flinch(push.normalized())        # (its hit reaction from the side the gust came, the aim lowered)
	if f.brain != null:
		f.brain.hurt(by, push.normalized() if push.length_squared() > 1e-6 else Vector3.ZERO)


## A skid of `push` (m/s) over SKID_S, and away from `from` at a run.
static func shove_animal(a: WildAnimal, push: Vector3, from: Vector3) -> void:
	if a == null or a.is_dead() or a.mirrored:
		return
	a._start_flee(from)
	var m := Motion.new()
	m.name = "SwaySkid"
	m.kind = "skid"
	m.body = a
	m.v = push
	m.dur = Motion.SKID_S
	a.add_child(m)


static func push_prop(b: RigidBody3D, dv: Vector3, at: Vector3, heavy_kg: float) -> void:
	if b.freeze:
		if b.has_meta(&"sway_fixed"):
			return
		b.freeze = false
	b.sleeping = false
	var m := maxf(b.mass, 0.05)
	b.apply_impulse(dv * m * minf(1.0, heavy_kg / m), at - b.global_position)


static func snuff(tf: TorchFire) -> void:
	if tf == null or tf.state == null or not tf.state.lit:
		return
	var cf := tf.get_parent() as Campfire
	if cf != null:
		cf.smother()
	else:
		tf.state.snuff("gust")
		if Sfx.has(&"torch_snuff"):
			Sfx.play_3d(&"torch_snuff", tf.global_position, -4.0)


## Every lit campfire and flame within `r` of `at`, not the caster's own torch.
static func blow_out_near(c: SwayCaster, at: Vector3, r: float) -> void:
	if r <= 0.0:
		return
	var tree := c.get_tree()
	for f in tree.get_nodes_in_group(Campfire.GROUP):
		if f is Campfire and (f as Campfire).is_lit() and (f as Node3D).global_position.distance_to(at) <= r:
			(f as Campfire).smother()
	for f in tree.get_nodes_in_group(TorchFire.GROUP):
		var tf := f as TorchFire
		if tf != null and not c.own_torch(tf) and tf.global_position.distance_to(at) <= r:
			snuff(tf)


# ---------------------------------------------------------------- first_lock
static func lift(c: SwayCaster, t: Node3D) -> void:
	var l: Dictionary = SwayMoves.move("first_lock").get("lift", {})
	var start := t.global_position
	var line := start - c.player.global_position
	line.y = 0.0
	if line.length_squared() < 1e-4:
		line = -c.player.global_basis.z
	var right := line.normalized().cross(Vector3.UP).normalized()
	var dest := start + right * float(l.get("aside_m", 1.7))
	if t.has_meta(&"sway_lift_to"):
		dest = t.get_meta(&"sway_lift_to")
	var m := Motion.new()
	m.name = "SwayLift"
	m.kind = "lift"
	m.body = t
	m.caster = c
	m.start = t.global_transform
	m.dest = dest
	m.up = float(l.get("up_m", 1.3))
	m.dur = float(l.get("s", 1.8))
	m.roll_axis = line.normalized()
	t.add_child(m)


## A move a cast leaves running on its target: "skid" (a CharacterBody3D slid by `v`, slowing to rest over `dur`), "lift"
## (`body` raised `up` and carried from `start` to `dest` over `dur`, kinematic meanwhile when it is a rigid body, then
## let fall; the caster's lifted signal).
class Motion:
	extends Node

	const SKID_S := 0.4
	const ROLL_DEG := 14.0

	var kind := "skid"
	var body: Node3D
	var caster: SwayCaster
	var v := Vector3.ZERO
	var dur := 0.4
	var start := Transform3D.IDENTITY
	var dest := Vector3.ZERO
	var up := 1.3
	var roll_axis := Vector3.FORWARD
	var _t := 0.0
	var _was_frozen := false
	var _mode := RigidBody3D.FREEZE_MODE_STATIC

	func _ready() -> void:
		if kind == "lift" and body is RigidBody3D:
			var rb := body as RigidBody3D
			_was_frozen = rb.freeze
			_mode = rb.freeze_mode
			rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			rb.freeze = true

	func _physics_process(dt: float) -> void:
		if body == null or not is_instance_valid(body):
			queue_free()
			return
		_t += dt
		var u := clampf(_t / maxf(dur, 0.01), 0.0, 1.0)
		if kind == "skid":
			if body is CharacterBody3D:
				(body as CharacterBody3D).move_and_collide(v * (1.0 - u) * dt)
		else:
			# up first, then across, held up to the end
			var rise := smoothstep(0.0, 0.45, u) * up
			var across := smoothstep(0.2, 0.95, u)
			var p := start.origin.lerp(dest, across) + Vector3.UP * rise
			var roll := Basis(roll_axis, deg_to_rad(ROLL_DEG) * smoothstep(0.1, 0.9, u))
			body.global_transform = Transform3D(roll * start.basis, p)
		if u >= 1.0:
			_finish()

	func _finish() -> void:
		if kind == "lift":
			if body is RigidBody3D:
				var rb := body as RigidBody3D
				rb.freeze_mode = _mode
				rb.freeze = _was_frozen if body.has_meta(&"sway_keep_frozen") else false
				rb.sleeping = false
			if caster != null and is_instance_valid(caster):
				caster.lifted.emit(body)
		set_physics_process(false)
		queue_free()
