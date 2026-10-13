class_name SpellFx
extends Node3D
## Plays the rebuilt Spellbreak effects (Spellbreak by Proletariat; Cascade particle systems rebuilt from the
## source data, provenance in res://assets/fx/spellbreak/SOURCE.md) in the game. One player per scene (of), made
## under it the first time; it steps every playing effect (CascadeFx) each frame, follows nodes, keeps finished
## effects for reuse and gets effects ready before their first use (prewarm). Visual only: nothing here touches
## gameplay, collision, timing or aim.
##
## An effect is named by its source package path (its stable id), e.g.
##   "g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP"
## Imported effects are listed in res://assets/fx/spellbreak/index.json (tools/fx/import_spellbreak_fx.py).
##
##   var h := SpellFx.spawn(FIREBALL, bolt_node)                  # follows the bolt; its trail stays in the world
##   h.stop()                                                     # bolt gone: the trail plays out, then it is freed
##   SpellFx.spawn(FIREBALL_HIT, Transform3D(basis, hit_point))   # one-shot: frees itself when done
##   await SpellFx.prewarm(ids, camera)                           # behind the loading screen

## Kept for reuse per effect once finished (more are freed).
const POOL_PER_EFFECT := 4
## After stop(), an effect still showing particles this long is removed (Cascade particles can be immortal).
const MAX_TAIL_S := 10.0
## The longest step one frame feeds an effect: after a stall (a window drag, a pause, a loading hitch) a long step would
## spawn that whole span's particles at once.
const MAX_STEP_S := 0.1
const SPECS := "res://assets/fx/spellbreak/specs/"
const INDEX := "res://assets/fx/spellbreak/index.json"

static var _inst: SpellFx
static var _specs: Dictionary = {}
static var _index: Dictionary = {}
static var _warned: Dictionary = {}
## effect id -> whether its spec file exists (has_effect is asked at every play)
static var _present: Dictionary = {}

## Playing effects (Handle).
var _active: Array = []
## effect id -> Array of idle CascadeFx, ready to replay
var _idle: Dictionary = {}
## Microseconds the last frame's step of every playing effect took (the runtime is CPU: GDScript).
var last_step_usec := 0
## The last warm's steps: [[ids, ms from the step's start to its second frame], ...] (the slowest show what stalls).
var warm_steps: Array = []
## The scene this player belongs to (of()).
var _scene: Node
## [Handle, where, opts] spawned before this player entered the tree; started in _ready.
var _pending: Array = []


## One playing effect. Hold it to stop, move or kill the effect; it is safe to keep after the effect ended (every
## call then does nothing).
class Handle:
	extends RefCounted
	## The effect ended (finished, stopped and played out, or killed) and its node went back to the pool.
	signal finished
	var id := ""
	## The effect's node while it plays, else null.
	var fx: CascadeFx
	var player: SpellFx
	## The node followed (null: placed in the world, or attached as its child).
	var follow: Node3D
	## (a freed node reads as null, so whether one is followed is kept apart)
	var following := false
	var offset := Transform3D.IDENTITY
	var scale := 1.0
	## Free itself once every emitter has finished (looping effects never finish: stop() them, or give `life`).
	var one_shot := true
	## Seconds after which stop() is called (0: none).
	var life := 0.0
	var age := 0.0
	var time_scale := 1.0
	var stopping := false
	var stop_age := 0.0
	var camera: Camera3D
	## How a followed effect turns (opts follow_basis): 0 with its node ("node"), 1 kept as it started ("fixed"),
	## 2 along the node's motion ("motion": a tumbling stone's trail faces its flight, not its spin).
	var basis_mode := 0
	var basis := Basis.IDENTITY
	var last_pos := Vector3.INF
	## Attached as its node's child (opts attach): it ends if that node leaves the tree.
	var attached := false
	## Gone back to the pool: the frame's remaining ticks of it do nothing.
	var released := false

	func is_playing() -> bool:
		return is_instance_valid(fx)

	## No new particles (UE Deactivate: emitters marked kill-on-deactivate clear at once); the rest play out, then
	## the effect is freed.
	func stop() -> void:
		if is_playing() and not stopping:
			stopping = true
			fx.deactivate()

	## Gone now, every particle with it.
	func kill() -> void:
		if is_playing() and player != null and is_instance_valid(player):
			player._release(self)

	## Plays it again from the start (a pooled node keeps its materials).
	func restart() -> void:
		if is_playing():
			stopping = false
			stop_age = 0.0
			age = 0.0
			fx.activate()

	## Places an effect that follows nothing (world space). A followed effect takes its node's place every frame.
	func set_transform(xf: Transform3D) -> void:
		if is_playing():
			fx.global_transform = (xf * offset).scaled_local(Vector3.ONE * scale)

	func set_position(p: Vector3) -> void:
		if is_playing():
			set_transform(Transform3D(fx.global_basis.orthonormalized(), p) * offset.affine_inverse())

	func particle_count() -> int:
		return fx.particle_count() if is_playing() else 0


## The player of `scene` (made under it the first time). A scene still building its children (a spawn from some
## child's _ready) gets it at the end of the frame: effects spawned before then start as it enters the tree.
static func of(scene: Node) -> SpellFx:
	if scene == null:
		return null
	if _inst != null and is_instance_valid(_inst) and not _inst.is_queued_for_deletion() and _inst._scene == scene:
		return _inst
	var p := scene.get_node_or_null("SpellFx") as SpellFx
	if p == null:
		p = SpellFx.new()
		p.name = "SpellFx"
		if scene.is_node_ready():
			scene.add_child(p)
		else:
			scene.add_child.call_deferred(p)
	p._scene = scene
	_inst = p
	return p


## Plays effect `effect_id` (a source package path). `where`:
##   Node3D       follows the node: its place each frame (scale stripped), world-space emitters leaving trails
##                behind, local-space ones moving with it; if the node leaves the tree the effect stops and plays out
##   Transform3D  placed there, in the world
##   Vector3      placed there, unrotated
## opts (all optional):
##   follow: bool      with a Node3D: false = only start where it is (default true)
##   follow_basis: String  a followed effect's turn: "node" (default: the node's), "fixed" (`basis`, else the node's
##                     at the start, kept), "motion" (faces where the node moves; `basis` until it moves)
##   basis: Basis      with follow_basis "fixed" / "motion": the starting turn
##   attach: bool      with a Node3D: be its child instead (local space: moves, hides and is freed with it; its
##                     handle then ends, also when the node is taken out of the tree)
##   offset: Transform3D  relative to `where` (default identity)
##   scale: float      uniform: positions, speeds, sizes, ribbon widths, light ranges (default 1)
##   tint: Color       multiplies every particle's colour and alpha (default none: the source colours)
##   one_shot: bool    free when every emitter has finished (default true; looping effects need stop() or life)
##   life: float       stop() after this many seconds (default 0: never)
##   time_scale: float (default 1)
##   ground_y: float   height of the plane the source's Collision modules bounce on (default 0)
##   hide: Array       emitters left out of this play, by name or "#<index>" (one that draws broken; default none)
##   camera: Camera3D  facing camera (default the viewport's)
##   scene: Node       whose player plays it (default the current scene)
## Returns null when the effect is not imported.
static func spawn(effect_id: String, where: Variant = null, opts: Dictionary = {}) -> Handle:
	var scene: Node = opts.get("scene") as Node
	if scene == null:
		scene = _scene_of(where)
	var p := of(scene)
	return p.play(effect_id, where, opts) if p != null else null


## Gets `ids` ready before their first use: loads each effect's spec, textures and meshes, builds its materials and
## draws it for two frames (tiny and transparent, 3 m in front of `cam`) so every shader is compiled, then keeps the
## built node for the first spawn. Await it behind a loading screen; `progress` gets 0..1.
static func prewarm(ids: Array, cam: Camera3D = null, progress: Callable = Callable(), per_frame := 4) -> void:
	var p := of(_scene_of(cam))
	if p != null:
		await p.warm(ids, cam, progress, per_frame)


## The effect's spec (parsed once), or {} when it is not imported.
static func spec(effect_id: String) -> Dictionary:
	if _specs.has(effect_id):
		return _specs[effect_id]
	var path := SPECS + effect_id + ".json"
	var d: Dictionary = {}
	if FileAccess.file_exists(path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		if j is Dictionary:
			d = j
	if d.is_empty() and not _warned.has(effect_id):
		_warned[effect_id] = true
		push_warning("SpellFx: effect not imported: " + effect_id)
	_specs[effect_id] = d
	return d


static func has_effect(effect_id: String) -> bool:
	if not _present.has(effect_id):
		_present[effect_id] = FileAccess.file_exists(SPECS + effect_id + ".json")
	return _present[effect_id]


## Forgets what was read from the disk (specs, the index, which effects exist): for a tool that imports while it runs.
static func forget_cache() -> void:
	_specs.clear()
	_index.clear()
	_present.clear()
	_warned.clear()


## index.json's effects: id -> {spec, source_index, source, materials, textures, meshes, uses: [{element, move_id,
## role, slot}]}.
static func catalogue() -> Dictionary:
	if _index.is_empty():
		var j = JSON.parse_string(FileAccess.get_file_as_string(INDEX)) if FileAccess.file_exists(INDEX) else null
		_index = j.get("effects", {}) if j is Dictionary else {}
	return _index


static func effect_ids() -> PackedStringArray:
	return PackedStringArray(catalogue().keys())


static func _scene_of(where: Variant) -> Node:
	var tree: SceneTree = null
	if where is Node and (where as Node).is_inside_tree():
		tree = (where as Node).get_tree()
	else:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	process_priority = 100            # (after the nodes the effects follow have moved this frame)
	var pending := _pending
	_pending = []
	for q: Array in pending:
		_start(q[0], q[1], q[2])


## See spawn().
func play(effect_id: String, where: Variant = null, opts: Dictionary = {}) -> Handle:
	var fx := _take(effect_id)
	if fx == null:
		return null
	var h := Handle.new()
	h.id = effect_id
	h.fx = fx
	h.player = self
	h.offset = opts.get("offset", Transform3D.IDENTITY)
	h.scale = maxf(float(opts.get("scale", 1.0)), 0.001)
	h.one_shot = bool(opts.get("one_shot", true))
	h.life = float(opts.get("life", 0.0))
	h.time_scale = float(opts.get("time_scale", 1.0))
	h.camera = opts.get("camera") as Camera3D
	fx.fx_scale = h.scale
	fx.use_tint = opts.has("tint")
	fx.tint = opts.get("tint", Color(1, 1, 1, 1))
	fx.ground_y = float(opts.get("ground_y", 0.0))
	fx.set_hidden(PackedStringArray(opts.get("hide", [])))
	if is_inside_tree():
		_start(h, where, opts)
	else:
		_pending.append([h, where, opts])
	return h


## Places and activates a handle's effect (play(), or _ready for one spawned before the player was in the tree).
func _start(h: Handle, where: Variant, opts: Dictionary) -> void:
	if not h.is_playing():
		return                         # (killed before it started)
	var fx := h.fx
	fx.camera = h.camera if h.camera != null else _camera()
	var base := Transform3D.IDENTITY
	if typeof(where) == TYPE_OBJECT and not is_instance_valid(where):
		where = null                   # (a node freed before a pending spawn started)
	if where is Node3D and (where as Node3D).is_inside_tree():
		var n := where as Node3D
		if bool(opts.get("attach", false)):
			h.attached = true
			fx.get_parent().remove_child(fx)
			n.add_child(fx)
			fx.transform = h.offset.scaled_local(Vector3.ONE * h.scale)
			base = Transform3D()
		else:
			if bool(opts.get("follow", true)):
				h.follow = n
				h.following = true
			var fb := String(opts.get("follow_basis", "node"))
			h.basis_mode = 1 if fb == "fixed" else (2 if fb == "motion" else 0)
			h.basis = n.global_basis.orthonormalized()
			if h.basis_mode != 0 and opts.get("basis") is Basis:
				h.basis = opts.basis
			h.last_pos = n.global_position
			base = Transform3D(h.basis, n.global_position)
	elif where is Transform3D:
		base = where
	elif where is Vector3:
		base = Transform3D(Basis.IDENTITY, where)
	if fx.get_parent() == self:
		fx.global_transform = (base * h.offset).scaled_local(Vector3.ONE * h.scale)
	fx.visible = true
	fx.activate()
	_active.append(h)


## Every playing effect gone now (a round reset, a replay cut).
func kill_all() -> void:
	for h: Handle in _active.duplicate():
		_release(h)


func playing_count() -> int:
	return _active.size()


func idle_count() -> int:
	var n := 0
	for id: String in _idle:
		for fx in _idle[id]:
			n += 1 if is_instance_valid(fx) else 0
	return n


## See prewarm().
func warm(ids: Array, cam: Camera3D = null, progress: Callable = Callable(), per_frame := 4) -> void:
	var tree := get_tree()
	var at := cam.global_transform * Vector3(0.0, 0.0, -3.0) if cam != null else global_position
	var todo: Array = []
	for id in ids:
		if not String(id) in todo and not (_idle.get(String(id), []) as Array).any(func(f): return is_instance_valid(f)):
			todo.append(String(id))
	var done := 0
	warm_steps = []
	for i in range(0, todo.size(), maxi(per_frame, 1)):
		var ts := Time.get_ticks_usec()
		var made: Array = []
		var c: Camera3D = cam if is_instance_valid(cam) else null     # (it may be freed while this awaits)
		for id: String in todo.slice(i, i + maxi(per_frame, 1)):
			var fx := _build(id)
			if fx == null:
				continue
			fx.camera = c
			fx.fx_scale = 0.01
			fx.use_tint = true
			fx.tint = Color(1, 1, 1, 0)
			fx.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01), at)
			fx.visible = true
			fx.activate()
			fx.step(1.0 / 60.0)
			_force_draw(fx)
			made.append(fx)
		await tree.process_frame
		await tree.process_frame
		warm_steps.append([todo.slice(i, i + maxi(per_frame, 1)), (Time.get_ticks_usec() - ts) / 1000.0])
		for fx in made:                # (untyped: a freed node cannot be read into a typed variable)
			if is_instance_valid(fx):
				fx.clear()
				fx.use_tint = false
				fx.fx_scale = 1.0
				_park(fx)
		done = mini(i + maxi(per_frame, 1), todo.size())
		if progress.is_valid():
			progress.call(float(done) / float(maxi(todo.size(), 1)))
	if progress.is_valid():
		progress.call(1.0)


func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	var cam := _camera()
	for h: Handle in _active.duplicate():
		_tick(h, dt, cam)
	last_step_usec = Time.get_ticks_usec() - t0


func _tick(h: Handle, dt: float, cam: Camera3D) -> void:
	if h.released:
		return                         # (killed earlier in this pass, by another handle's finished handler: already ended)
	if not is_instance_valid(h.fx):
		# (freed with the node it was attached to: checked before any typed read, which would fail on a freed node)
		h.released = true
		_active.erase(h)
		h.fx = null
		h.follow = null
		h.following = false
		h.finished.emit()
		return
	var fx := h.fx
	if h.attached and not fx.is_inside_tree():
		_release(h)                    # (its node was taken out of the tree, not freed: an effect out of the tree cannot step)
		return
	if h.following:
		if is_instance_valid(h.follow) and h.follow.is_inside_tree():
			var n := h.follow
			var b := n.global_basis.orthonormalized()
			if h.basis_mode != 0:
				var d := n.global_position - h.last_pos if h.last_pos.is_finite() else Vector3.ZERO
				if h.basis_mode == 2 and d.length_squared() > 1e-6:
					var f := d.normalized()
					h.basis = Basis.looking_at(f, Vector3.UP if absf(f.y) < 0.98 else Vector3.RIGHT)
				h.last_pos = n.global_position
				b = h.basis
			fx.global_transform = (Transform3D(b, n.global_position) * h.offset).scaled_local(Vector3.ONE * h.scale)
		else:
			h.following = false
			h.follow = null
			h.stop()
	var sdt := minf(dt, MAX_STEP_S) * h.time_scale
	h.age += sdt
	if h.life > 0.0 and h.age >= h.life:
		h.stop()
	if h.stopping:
		h.stop_age += sdt
		if h.stop_age > MAX_TAIL_S or _only_immortal(fx):
			_release(h)
			return
	fx.camera = h.camera if h.camera != null and is_instance_valid(h.camera) else cam
	fx.step(sdt)
	if fx.is_finished() and (h.one_shot or h.stopping):
		_release(h)


## Every live particle has an endless lifetime (Cascade lifetime 0) and nothing can spawn: after stop() it would
## never end.
func _only_immortal(fx: CascadeFx) -> bool:
	var any := false
	for e in fx.emitters:
		if e.spawning and not e.killed and fx.active:
			return false
		for p in e.particles:
			if p.life < INF:
				return false
			any = true
	return any


func _camera() -> Camera3D:
	var vp := get_viewport()
	return vp.get_camera_3d() if vp != null else null


func _take(effect_id: String) -> CascadeFx:
	var idle: Array = _idle.get(effect_id, [])
	while not idle.is_empty():
		var fx = idle.pop_back()
		if is_instance_valid(fx):
			return fx
	return _build(effect_id)


func _build(effect_id: String) -> CascadeFx:
	var sp := SpellFx.spec(effect_id)
	if sp.is_empty():
		return null
	var fx := CascadeFx.new()
	fx.name = "Fx_" + effect_id.get_file()
	fx.effect_id = effect_id
	add_child(fx)
	fx.setup(sp, CascadeMaterials.shared(), _camera())
	return fx


## Back to the pool (or freed when the pool for this effect is full).
func _release(h: Handle) -> void:
	var fx = h.fx                      # (untyped: it may be a node freed with its attach parent)
	h.released = true
	h.fx = null
	h.follow = null
	h.following = false
	_active.erase(h)
	if is_instance_valid(fx):
		fx.clear()
		fx.use_tint = false
		_park(fx)
	h.finished.emit()


func _park(fx: CascadeFx) -> void:
	fx.visible = false
	if fx.get_parent() != self:
		if fx.get_parent() != null:
			fx.get_parent().remove_child(fx)
		add_child(fx)
	var idle: Array = _idle.get(fx.effect_id, [])
	if idle.size() < POOL_PER_EFFECT:
		idle.append(fx)
		_idle[fx.effect_id] = idle
	else:
		fx.queue_free()


## Every emitter drawn once (warm-up): one particle for each that has none yet, two for ribbons.
func _force_draw(fx: CascadeFx) -> void:
	for e in fx.emitters:
		if e.particles.is_empty():
			var at: Vector3 = e.loc_now()
			e._spawn_one(at, 0.0, {})
			if e.s.type in ["ribbon", "beam", "anim_trail"]:
				e._spawn_one(at + fx.global_basis.x * 0.01, 0.0, {})
		e.render()
