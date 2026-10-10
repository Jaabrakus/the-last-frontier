extends SceneTree
## Review round 1 probe (read-only): does every entry of data/bending/sb_fx/*.json END when its seam lets go of it?
## Each entry is played the way its seam plays it (held roles through SbFx.start + stop after 2 s, the others through the
## fire() path, their node freed after 2 s as a bolt or zone would be), 12 s of frames, then any handle still playing is
## reported with its effect and particle count. Every element is forced on (the shipped switches are all off).
##   zsh tools/loop/godot_run.sh --headless --fixed-fps 60 --path . -s tools/fx/review_r1_lifecycle.gd
## Last line "LIFECYCLE n entries, m never ended".

## Roles the game plays through start()/sustain() and ends with stop() (grep SbFx.start in scripts/).
const HELD := ["zone", "stand", "hang", "flight", "return_flight", "held", "charge", "grow", "idle", "ride", "dash_trail",
		"dash_flames", "charged", "roll", "air_trail"]
const BATCH := 24
const RUN_FRAMES := 60 * 18
const LET_GO_FRAME := 60 * 2

var stage: Node3D
var bodies := {}
var never: Array = []
var entries_n := 0


func _initialize() -> void:
	_run.call_deferred()


func _body(el: String, at: Vector3) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	b.name = "Caster_" + el
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	cs.position = Vector3.UP * 0.9
	b.add_child(cs)
	stage.add_child(b)
	b.global_position = at
	Bending.of(b).element = el
	return b


func _run() -> void:
	SbFx.allow_headless = true
	SbFx.reload_data()
	SbFx.force_on = true
	SbFx.force_elements = {"earth": true, "water": true, "fire": true, "air": true}
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.global_position = Vector3(0, 3, 10)
	cam.current = true
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(80, 1, 80)
	cs.shape = bx
	ground.add_child(cs)
	stage.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)
	var i := 0
	for el in SbFx.ELEMENTS:
		bodies[el] = _body(el, Vector3(float(i) * 3.0, 0, 0))
		i += 1
	await physics_frame
	var player := SpellFx.of(stage)
	await physics_frame

	var todo: Array = []
	for el: String in SbFx.ELEMENTS:
		var t := SbFx.table(el)
		for key: String in t:
			for role: String in t[key]:
				if (t[key][role] is Dictionary) and not String(role).begins_with("_"):
					todo.append([el, key, role])
	print("REVIEW lifecycle: %d entries" % todo.size())
	var b0 := 0
	while b0 < todo.size():
		var batch := todo.slice(b0, b0 + BATCH)
		b0 += BATCH
		var recs: Array = []
		var nodes: Array = []
		for k in batch.size():
			var el: String = batch[k][0]
			var key: String = batch[k][1]
			var role: String = batch[k][2]
			var pos := Vector3(float(k % 8) * 2.0 - 7.0, 0.0, -float(k / 8) * 3.0 - 3.0)
			var node := Node3D.new()
			stage.add_child(node)
			node.global_position = pos
			nodes.append(node)
			var ctx := {"node": node, "at": pos + Vector3.UP * 0.2, "dir": Vector3.FORWARD, "to": pos + Vector3.FORWARD * 6.0,
					"size": Vector3(4, 2, 0.5), "radius": 2.0, "normal": Vector3.UP, "el": el}
			var held := role in HELD
			var handles: Array = []
			if held:
				SbFx.start(node, "s", bodies[el], key, role, ctx)
				for h in (SbFx._held.get(node.get_instance_id(), {}) as Dictionary).get("s", []):
					if h is SpellFx.Handle:
						handles.append(h)
			else:
				var r := SbFx._play(bodies[el], key, role, ctx)
				handles = r.handles
			entries_n += 1
			recs.append({"el": el, "key": key, "role": role, "held": held, "handles": handles, "node": node,
					"effect": String(SbFx.entry(el, key, role).get("effect", ""))})
		for f in RUN_FRAMES:
			await physics_frame
			if f == LET_GO_FRAME:
				for r in recs:
					if r.held:
						SbFx.stop(r.node, "s")
					if is_instance_valid(r.node):
						(r.node as Node).queue_free()
		for r in recs:
			var alive := 0
			var parts := 0
			for h: SpellFx.Handle in r.handles:
				if h.is_playing():
					alive += 1
					parts += h.particle_count()
			if alive > 0:
				never.append(r)
				var why := ""
				for h: SpellFx.Handle in r.handles:
					if h.is_playing():
						var lives: Array = []
						var spawning := 0
						for e in h.fx.emitters:
							if e.spawning and not e.killed and h.fx.active:
								spawning += 1
							for p in e.particles:
								lives.append("%.0f/%s" % [p.age, "inf" if p.life == INF else "%.0f" % p.life])
						why = "age %.1f stopping %s stop_age %.1f spawning emitters %d particles(age/life) %s" % [h.age, h.stopping, h.stop_age,
								spawning, ",".join(PackedStringArray(lives.slice(0, 4)))]
						break
				print("  NEVER ENDED  %-6s %-34s %-12s %s  (%d of %d handles, %d particles, held=%s) %s" % [r.el, r.key, r.role,
						String(r.effect).get_file(), alive, r.handles.size(), parts, r.held, why])
		player.kill_all()
		await physics_frame
	print("LIFECYCLE %d entries, %d never ended" % [entries_n, never.size()])
	SbFx.allow_headless = false
	SbFx.force_on = null
	SbFx.force_elements = {}
	quit(0)
