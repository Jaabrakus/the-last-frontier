class_name RingReplay
extends Node
## THE SPLASH CAM (round 4 VIRAL; the owner, 2026-10-06: "do what you think would make a viral round 4"): the % ring's
## recorder and its replay player. Every number in data/ring/replay.json.
##   THE GATE      it records and replays only while RingRules.stock_on() (a stock-rules ring match); install() puts it, and
##                 the round's other VIRAL parts (RingHighlights, Callouts, PhotoMode, BendClash), under RingMode
##   the buffer    the last buffer_s, written every physics tick (after the bodies, the rules and the mode: priority 30):
##                 each competitor's skeleton's global transform, its skeleton's pose (every bone's rotation and position:
##                 the body's driven twist helpers too), the clip its AnimationPlayer plays and its time, his %, and his
##                 state (shown, tumbling, guarding, hanging); the effects in flight as PROPS (bolts, guards, stones, walls: each one's look copied
##                 once as a template of its meshes and particles, then its transform every tick); EVENTS (hits, launches,
##                 guards, catches, splashes, clashes: kind, tick, place, way, element, who). Every array is allocated when
##                 its slot is first used and never grows (bytes() is the metric: fixed after warm-up)
##   a fall        RingRules.ko queues a replay (the setting allows it: Every fall / Last life only / Off, GameSettings
##                 section "ring" key "replays"; no replays in Practice, nor with bots on both sides or in a script run
##                 unless the user arg replays=on). It starts when IMPACT's RingMoment is no longer busy (when that class is
##                 there), else wait_s after the fall: the last replay_s up to the splash and tail_s after it
##   the replay    a cut-away, never the player's camera: the tree paused (the live match held exactly where it was), the
##                 live competitors and effects hidden, GHOST PUPPETS (their meshes on a copy of their skeleton, no physics,
##                 no scripts) posed from the buffer, the recorded effects shown again and the events' bursts re-made at
##                 their ticks, a side dolly that keeps the thrower and the faller in frame, slowed to slow.rate for the
##                 window_s around the decisive hit (the faller's last launch), the screens' layers hidden but the REPLAY tag
##                 (ReplayOverlay). Any key or button skips. At its end the camera, the layers and the hidden things are as
##                 they were and the tree goes on. Nothing is drawn on anyone: the camera frames the play
##   clips         snapshot(t0, t1) copies a window of the buffer out as a Clip (RingHighlights keeps its plays' 4 s that
##                 way); play(clip) plays any Clip the same way (the match screen's Watch)
## Statics: install(mode), find(tree), data(), setting() / set_setting() / cycle_setting(), row_text(), row_line(),
## force ("on" | "off" | "": tests), playing_now(). Signals: started(clip), finished(skipped).

signal started(clip: Clip)
signal finished(skipped: bool)

const NODE_NAME := "RingReplay"
const GROUP := &"ring_replay"
const DATA_PATH := "res://data/ring/replay.json"
const SETTINGS := ["every", "last", "off"]
## The groups whose members are the props (effects in flight with a look of their own).
const PROP_GROUPS := [&"bend_bolts", &"bend_zones", &"form_stones", &"form_raised", &"bend_hurls", &"bend_strikes"]
## Events' kinds.
enum Ev { HIT, LAUNCH, GUARD, CATCH, SPLASH, CLASH }
## The state flags recorded each tick.
const F_SHOWN := 1
const F_TUMBLE := 2
const F_GUARD := 4
const F_HANG := 8
const ELS := ["earth", "water", "fire", "air", "stone", "ice", "lightning", "steam"]

static var _data := {}
## Tests: "on" replays every fall even in a script run, "off" never; "" the setting and the run's kind decide.
static var force := ""
static var _now_playing: RingReplay = null

var mode: Node
## The recorder's rate (rec_hz: every _every-th physics tick), its ticks held (buffer_s), a pose every _pose_every of them.
var tps := 60
var cap := 480
var _every := 1
var _pose_every := 2
## The ticks written so far (absolute; the newest is _tick - 1), and how many of the buffer hold data.
var _tick := 0
var _filled := 0
## Competitor slots: Array of Dictionary (see _slot_for), by body instance id -> index.
var _slots: Array = []
var _slot_of := {}
## Slot index -> the body instance id it holds now (a recycled slot's old skeleton's updates are not its).
var _slot_body := {}
## Props: Array of Dictionary {id, tpl, born, died, xf}; by node instance id -> index while alive.
var _props: Array = []
var _prop_of := {}
## Events: parallel arrays, a ring of max_events.
var _ev_k := PackedInt32Array()
var _ev_t := PackedInt32Array()
var _ev_pos := PackedVector3Array()
var _ev_dir := PackedVector3Array()
var _ev_el := PackedInt32Array()
var _ev_a := PackedInt32Array()
var _ev_b := PackedInt32Array()
var _ev_n := 0
## Clip names (the AnimationPlayers'), each once.
var _names: Array = []
var _name_i := {}
## The faller's last launch (slot index -> absolute tick).
var _last_launch := {}
var _guard_owners := {}
var _hooked := {}
## Pending replays: [{ko, slot, by, waited (s, unscaled frame time), left}].
var _pending: Array = []
## The replay playing: its clip, the ghosts' root, the camera, what was hidden, the clock.
var _clip: Clip = null
var _root3: Node3D = null
var _cam: Camera3D = null
var _prev_cam: Camera3D = null
var _ghosts: Array = []
var _prop_ghosts: Array = []
var _hidden: Array = []
var _layers: Array = []
var _was_paused := false
var _mouse := Input.MOUSE_MODE_VISIBLE
var _pt := 0.0
var _ev_next := 0
var _cam_side := 1.0
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _cam_snap := true
var _overlay: Node = null
var _pool_mode := -1
var _voices_mode := -1
var _skip := false
## The replay held where it is (its clock stopped: seek() moves it; tests and the review strip).
var held := false
## Tests: how many replays started and ended.
var replays_started := 0
var replays_finished := 0


## The Splash Cam and the round's other VIRAL parts under the match `m` (RingMode): RingHighlights, Callouts, PhotoMode,
## BendClash. Once per mode.
static func install(m: Node) -> RingReplay:
	if m == null:
		return null
	var have := m.get_node_or_null(NODE_NAME) as RingReplay
	if have != null:
		return have
	var r := RingReplay.new()
	r.name = NODE_NAME
	r.mode = m
	m.add_child(r)
	RingHighlights.install(m, r)
	Callouts.install(m)
	PhotoMode.install(m)
	BendClash.install(m)
	return r


static func find(tree: SceneTree) -> RingReplay:
	return tree.get_first_node_in_group(GROUP) as RingReplay if tree != null else null


## Round 4's merge: a fall's replay is playing or waiting to (the game's and the match's screens and RingMode's "Over"
## wait for it, as they wait for RingMoment's slow beat, so a screen never flashes up under the cut-away).
static func holding() -> bool:
	if playing_now() != null:
		return true
	var r := find(Engine.get_main_loop() as SceneTree)
	return r != null and r.pending() > 0


## The replay playing now, if any.
static func playing_now() -> RingReplay:
	return _now_playing if _now_playing != null and is_instance_valid(_now_playing) and _now_playing.is_playing() else null


static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = d if d is Dictionary else {}
	return _data


static func num(key: String, def := 0.0) -> float:
	return float(data().get(key, def))


static func sub(blk: String, key: String, def := 0.0) -> float:
	var b: Variant = data().get(blk, {})
	return float((b as Dictionary).get(key, def)) if b is Dictionary else def


static func word(blk: String, key: String, def := "") -> String:
	var b: Variant = data().get(blk, {})
	return String((b as Dictionary).get(key, def)) if b is Dictionary else def


# ---------------------------------------------------------------- the setting (GameSettings [ring])
## A value of GameSettings' [ring] section (its own: GameSettings.get_value knows only its DEFAULTS' sections).
static func ring_setting(key: String, def: Variant) -> Variant:
	var cf := ConfigFile.new()
	cf.load(GameSettings.file())
	return cf.get_value("ring", key, def)


static func set_ring_setting(key: String, v: Variant) -> void:
	GameSettings.set_value("ring", key, v)


## "every" | "last" | "off" (the Esc row's).
static func setting() -> String:
	var s := String(ring_setting("replays", "every"))
	return s if s in SETTINGS else "every"


static func set_setting(s: String) -> void:
	if s in SETTINGS:
		set_ring_setting("replays", s)


static func cycle_setting() -> String:
	var s: String = SETTINGS[(SETTINGS.find(setting()) + 1) % SETTINGS.size()]
	set_setting(s)
	return s


## "Replays: Every fall".
static func row_text() -> String:
	return word("row", "label", "Replays: %s") % word("row", setting(), setting())


static func row_line() -> String:
	return word("row", "line")


# ---------------------------------------------------------------- set-up
func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 30                # (after the bodies, RingRules (15) and RingMode (20): this tick's places)
	tps = maxi(int(num("rec_hz", 60.0)), 1)
	_every = maxi(int(round(float(Engine.physics_ticks_per_second) / float(tps))), 1)
	tps = maxi(int(round(float(Engine.physics_ticks_per_second) / float(_every))), 1)
	cap = maxi(int(round(num("buffer_s", 8.0) * tps)), 2)
	_pose_every = maxi(int(num("pose_every", 2.0)), 1)
	var ne := int(num("max_events", 160.0))
	_ev_k.resize(ne)
	_ev_t.resize(ne)
	_ev_pos.resize(ne)
	_ev_dir.resize(ne)
	_ev_el.resize(ne)
	_ev_a.resize(ne)
	_ev_b.resize(ne)
	_ev_t.fill(-1)
	for k in int(num("max_props", 24.0)):
		var p := Prop.new()
		p.xf = _floats(cap * 12)
		_props.append(p)
	_overlay = ReplayOverlay.new()
	_overlay.name = "ReplayOverlay"
	add_child(_overlay)


func _exit_tree() -> void:
	if is_playing():
		_finish(true)
	for s: Slot in _slots:
		_free_node(s.tpl)
	for p: Prop in _props:
		_free_node(p.tpl)
	_slots.clear()
	_props.clear()
	if _now_playing == self:
		_now_playing = null


static func _free_node(n: Variant) -> void:
	if n is Node and is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
		if (n as Node).get_parent() != null:
			(n as Node).queue_free()
		else:
			(n as Node).free()


func _rules() -> RingRules:
	return RingRules.current()


## The competitors on the rules' books now.
func _bodies() -> Array:
	var out: Array = []
	var r := _rules()
	if r == null:
		return out
	for t in 2:
		for b in r.sides[t]:
			if b is Node3D and is_instance_valid(b) and (b as Node3D).is_inside_tree():
				out.append(b)
	return out


# ---------------------------------------------------------------- recording
func _physics_process(_dt: float) -> void:
	if get_tree().paused or is_playing() or not RingRules.stock_on():
		return
	if Engine.get_physics_frames() % _every != 0:
		return
	_record()


func _record() -> void:
	var r := _rules()
	var i := _tick % cap
	_guard_owners.clear()
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and is_instance_valid(bz.owner_node) and (bz.kind in BendZone.GUARDS or bz.kind == "air_shield"):
			_guard_owners[bz.owner_node.get_instance_id()] = true
	for b: Node3D in _bodies():
		var si := _slot_for(b)
		if si < 0:
			continue
		var s := _slots[si] as Slot
		var f := 0
		if b.visible and (r == null or not r.is_away(b)):
			f |= F_SHOWN                       # (in play and drawn: a faller out of play is not, wherever he is kept)
		var kn := BendKnock.peek(b)
		if kn != null and kn.is_launched():
			f |= F_TUMBLE
		if _guard_owners.has(b.get_instance_id()):
			f |= F_GUARD
		var rm := RingMoves.of(b)
		if rm != null and rm.on_ledge():
			f |= F_HANG
		var ci := -1
		var ct := 0.0
		if s.ap != null and is_instance_valid(s.ap) and s.ap.current_animation != "":
			ci = _name_index(String(s.ap.current_animation))
			ct = float(s.ap.current_animation_position)
		elif rm != null:
			var cs := rm.clip_state()                 # (the player's AnimationTree plays no named clip: the ring move's)
			if cs != "":
				ci = _name_index(cs)
		s.write(i, f, r.pct_of(b) if r != null else 0.0, ci, ct)
		s.last = _tick
	_record_props(i)
	_tick += 1
	_filled = mini(_filled + 1, cap)


## The slot of competitor `b` (made the first time: its arrays, its ghost's template); -1 when it has no skeleton or no
## slot is left.
func _slot_for(b: Node3D) -> int:
	var id := b.get_instance_id()
	if _slot_of.has(id):
		var have := _slots[int(_slot_of[id])] as Slot
		if is_instance_valid(have.sk):
			return int(_slot_of[id])
		_slot_of.erase(id)                     # (its skeleton gone: a new look; a new slot)
	var sk := _skeleton_of(b)
	if sk == null:
		return -1
	var reuse := -1
	if _slots.size() >= int(num("max_slots", 6.0)):
		# (all in use: the one whose body is gone, or not written since before the buffer's window, is taken)
		for k in _slots.size():
			var old := _slots[k] as Slot
			if not is_instance_valid(old.sk) or old.last < _tick - cap:
				reuse = k
				break
		if reuse < 0:
			return -1
		var old := _slots[reuse] as Slot
		_free_node(old.tpl)
		_slot_of.erase(old.body_id)
	var s := Slot.new()
	s.body_id = id
	s.sk = sk
	s.from = _tick
	s.team = _rules().team_of(b) if _rules() != null else -1
	s.el = _element_of(b)
	s.ap = _anim_player_of(b)
	s.tpl = _ghost_template(b, sk)
	s.alloc(cap, _pose_every, sk)
	var si := reuse
	if si < 0:
		_slots.append(s)
		si = _slots.size() - 1
	else:
		_slots[si] = s
	_slot_of[id] = si
	_slot_body[si] = id
	_last_launch.erase(si)
	# (the pose read as the skeleton finishes its update, its modifiers applied: the casts' arms, the lean, the IK)
	sk.skeleton_updated.connect(_on_pose.bind(si, id))
	_hook(b, si)
	return si


## A skeleton's final pose this frame, and its place as it is drawn, into the tick the recorder last wrote (a later frame in
## the same tick overwrites it: the newest).
func _on_pose(si: int, id: int) -> void:
	if _tick <= 0 or is_playing() or si >= _slots.size() or Engine.is_in_physics_frame():
		return                                 # (an update inside the physics step is not the frame drawn)
	if int(_slot_body.get(si, -1)) != id:
		return                                 # (a recycled slot: this skeleton is no longer its)
	var s := _slots[si] as Slot
	s.write_xf((_tick - 1) % cap)
	s.write_pose(_tick - 1)


static func _element_of(b: Node) -> String:
	if b == null or not is_instance_valid(b):
		return "air"
	var el := BendPoses.element_of(b)
	if el == "" and b is NpcFighter:
		el = String((b as NpcFighter).get(&"element"))
	return el if el in Bending.ELEMENTS else "earth"


## The body's skeleton (the one its visible skinned meshes follow; else its first).
static func _skeleton_of(b: Node) -> Skeleton3D:
	var first: Skeleton3D = null
	for n in b.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		if first == null:
			first = sk
		for c in sk.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).visible:
				return sk
	return first


static func _anim_player_of(b: Node) -> AnimationPlayer:
	var list := b.find_children("*", "AnimationPlayer", true, false)
	return list[0] as AnimationPlayer if not list.is_empty() else null


## The ghost's template: a copy of the skeleton (its bones, no children, no script) with a copy of every visible mesh
## skinned to it (no script, no children) and the meshes riding its bones (BoneAttachment3D), nothing that collides, nothing
## that thinks. Kept out of the tree.
static func _ghost_template(b: Node3D, sk: Skeleton3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Ghost_" + String(b.name)
	var gsk := sk.duplicate(0) as Skeleton3D
	for c in gsk.get_children():
		gsk.remove_child(c)
		c.free()
	gsk.name = "Skeleton"
	gsk.transform = Transform3D.IDENTITY
	root.add_child(gsk)
	var inv := sk.global_transform.affine_inverse()
	for n in b.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var att := _attachment_of(mi, sk)
		var on_sk := att == null and mi.get_node_or_null(mi.skeleton) == sk
		if not on_sk and att == null:
			continue
		var g := mi.duplicate(0) as MeshInstance3D
		for c in g.get_children():
			g.remove_child(c)
			c.free()
		if on_sk:
			g.transform = inv * mi.global_transform
			gsk.add_child(g)
			g.skeleton = NodePath("..")
		else:
			var ga := BoneAttachment3D.new()
			ga.bone_name = att.bone_name
			gsk.add_child(ga)
			g.transform = att.global_transform.affine_inverse() * mi.global_transform
			g.skeleton = NodePath("")
			ga.add_child(g)
	return root


static func _attachment_of(n: Node, sk: Skeleton3D) -> BoneAttachment3D:
	var p := n.get_parent()
	while p != null and p != sk:
		if p is BoneAttachment3D and p.get_parent() == sk:
			return p as BoneAttachment3D
		p = p.get_parent()
	return null


## Its caster's guards heard (perfect, late; a catch when an earth guard now holds a stone), and the rules' launches, hits and
## falls (once).
func _hook(b: Node3D, si: int) -> void:
	var r := _rules()
	if r != null and not _hooked.has(r.get_instance_id()):
		_hooked[r.get_instance_id()] = true
		r.launched.connect(_on_launched)
		r.pct_changed.connect(_on_pct)
		r.ko.connect(_on_ko)
	var bc := BendCaster.of(b)
	if bc == null or _hooked.has(bc.get_instance_id()):
		return
	_hooked[bc.get_instance_id()] = true
	bc.guarded.connect(func(result: String, what: String) -> void:
		if not is_instance_valid(b) or result == "whiff":
			return
		var caught := what == "stone" and BendZone.held_stone(b) != null
		note_event(Ev.CATCH if caught else Ev.GUARD, b.global_position + Vector3.UP * 1.1, -b.global_basis.z, _element_of(b), si, -1))


func _name_index(n: String) -> int:
	if _name_i.has(n):
		return int(_name_i[n])
	if _names.size() >= 512:
		return -1
	_names.append(n)
	_name_i[n] = _names.size() - 1
	return _names.size() - 1


## A transform out of 12 floats at `o`.
static func get_xf(a: PackedFloat32Array, o: int) -> Transform3D:
	return Transform3D(Basis(Vector3(a[o], a[o + 1], a[o + 2]), Vector3(a[o + 3], a[o + 4], a[o + 5]),
			Vector3(a[o + 6], a[o + 7], a[o + 8])), Vector3(a[o + 9], a[o + 10], a[o + 11]))


# ---------------------------------------------------------------- props
func _record_props(i: int) -> void:
	# (those gone since the last tick: their end noted)
	for id in _prop_of.keys():
		var p := _props[int(_prop_of[id])] as Prop
		var n: Object = instance_from_id(int(id))
		if n == null or not is_instance_valid(n) or not (n as Node).is_inside_tree() or (n is BendBolt and (n as BendBolt).spent):
			p.died = _tick - 1
			_prop_of.erase(id)
		elif n is BendBolt and (n as BendBolt).kind != p.kind:
			p.died = _tick - 1                   # (its kind made anew in flight: a Turn's ice lance; a new prop from its new look)
			_prop_of.erase(id)
	for g: StringName in PROP_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if not (n is Node3D) or not (n as Node3D).is_visible_in_tree():
				continue
			var id := n.get_instance_id()
			if not _prop_of.has(id):
				var pi := _new_prop(n as Node3D)
				if pi < 0:
					continue
				_prop_of[id] = pi
			(_props[int(_prop_of[id])] as Prop).put(i, (n as Node3D).global_transform)


## A slot for a new prop (one free: never used, or ended before the buffer's window; else the one ended longest ago): its
## template made from its look now. -1 when every slot holds a live one, or it has nothing to show.
func _new_prop(n: Node3D) -> int:
	var tpl := _prop_template(n)
	if tpl == null:
		return -1
	var best := -1
	var oldest := 1 << 62
	for k in _props.size():
		var p := _props[k] as Prop
		if p.tpl == null:
			best = k                           # (never used)
			break
		if p.died < 0:
			continue
		if p.died < oldest:
			oldest = p.died
			best = k
	if best < 0:
		_free_node(tpl)
		return -1
	var q := _props[best] as Prop
	_free_node(q.tpl)
	q.tpl = tpl
	q.born = _tick
	q.died = -1
	q.kind = _prop_kind(n)
	return best


static func _floats(n: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	return a


static func _prop_kind(n: Node) -> String:
	if n is BendBolt:
		return (n as BendBolt).kind
	if n is BendZone:
		return (n as BendZone).kind
	return String(n.get_class())


## A prop's look: each visible mesh, particle or multimesh under it, copied flat (no script, no children) at its place
## relative to the prop. Null when it has none.
static func _prop_template(n: Node3D) -> Node3D:
	var root: Node3D = null
	var inv := n.global_transform.affine_inverse()
	var list: Array = n.find_children("*", "GeometryInstance3D", true, false)
	if n is GeometryInstance3D:
		list.push_front(n)
	for c in list:
		var gi := c as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi.top_level:
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh == null:
			continue
		var g := gi.duplicate(0) as GeometryInstance3D
		if g == null:
			continue
		for cc in g.get_children():
			g.remove_child(cc)
			cc.free()
		if root == null:
			root = Node3D.new()
			root.name = "PropGhost"
		g.transform = inv * gi.global_transform
		if g is MeshInstance3D:
			(g as MeshInstance3D).skeleton = NodePath("")
		root.add_child(g)
	return root


# ---------------------------------------------------------------- events
## An event at this tick (kind Ev, where, which way, its element, the slots of who did it and to whom (-1 none); a clash's
## `b` is the other element's index in ELS).
func note_event(k: int, at: Vector3, dir: Vector3, el: String, a := -1, b := -1) -> void:
	if not RingRules.stock_on() or is_playing():
		return
	var n := _ev_k.size()
	if n == 0:
		return
	var i := _ev_n % n
	_ev_k[i] = k
	_ev_t[i] = _tick                         # (this physics frame's: the recorder writes it last in the frame)
	_ev_pos[i] = at
	_ev_dir[i] = dir
	_ev_el[i] = ELS.find(el)
	_ev_a[i] = a
	_ev_b[i] = b
	_ev_n += 1


func slot_index(b: Variant) -> int:
	if not (b is Node) or not is_instance_valid(b):
		return -1
	return int(_slot_of.get((b as Node).get_instance_id(), -1))


## The competitor at slot `si` (null: none, or gone).
func body_of(si: int) -> Node3D:
	if si < 0 or si >= _slots.size():
		return null
	var o: Object = instance_from_id((_slots[si] as Slot).body_id)
	return o as Node3D if o != null and is_instance_valid(o) else null


func _on_launched(b: Node3D, v: Vector3, _hs: float, by: Node, _tag: String) -> void:
	if b == null or not is_instance_valid(b):
		return
	var si := slot_index(b)
	note_event(Ev.LAUNCH, b.global_position + Vector3.UP * 1.0, v, _element_of(by), slot_index(by), si)
	if si >= 0:
		_last_launch[si] = _tick


func _on_pct(b: Node3D, _pct: float, delta: float) -> void:
	if delta <= 0.0 or b == null or not is_instance_valid(b):
		return
	var r := _rules()
	var by: Variant = r._sk(b).get("last_by") if r != null else null
	note_event(Ev.HIT, b.global_position + Vector3.UP * 1.1, Vector3.UP, _element_of(by as Node) if by is Node else "air",
			slot_index(by), slot_index(b))


## A clash (BendClash.clashed): its event (the two kinds; who sent the first).
func on_clash(at: Vector3, ka: String, kb: String, dir: Vector3, by_a: Node, _by_b: Node) -> void:
	note_event(Ev.CLASH, at, dir, ka if ka in ELS else "stone", slot_index(by_a), ELS.find(kb))


func _on_ko(b: Node3D, by: Node, _pct: float, _tag: String, left: int) -> void:
	if b == null or not is_instance_valid(b):
		return
	var si := slot_index(b)
	note_event(Ev.SPLASH, b.global_position, Vector3.UP, "water", slot_index(by), si)
	if not wants_replay(left):
		return
	_pending.append({"ko": _tick, "slot": si, "by": slot_index(by), "waited": 0.0, "left": left})
	if _pending.size() > 2:
		_pending.pop_front()


## Whether a fall that left `left` lives gets a replay: the setting (every / last / off), Practice (data practice), bots on
## both sides (the player not on the rules' books, spectate) and script runs only with the user arg replays=on (or force).
func wants_replay(left: int) -> bool:
	if force == "off":
		return false
	if not bool(data().get("enabled", true)):
		return false
	var arg := ""
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--")
		if kv.begins_with("replays="):
			arg = kv.get_slice("=", 1)
	if arg in ["off", "false", "0"]:
		return false
	var s := setting()
	if s == "off":
		return false
	var r := _rules()
	if s == "last" and not (left <= 0 or (r != null and r.sudden)):
		return false
	if r != null and not r.lives_on and not bool(data().get("practice", false)):
		return false
	if force == "on" or arg in ["on", "true", "1"]:
		return true
	var args := OS.get_cmdline_args()
	if "-s" in args or "--script" in args:
		return false
	var p: Variant = mode.get(&"player") if mode != null else null
	if MatchSetup.spectate or not (p is Node) or not is_instance_valid(p) or r == null or r.team_of(p as Node) < 0:
		return false
	return true


# ---------------------------------------------------------------- the clock between the fall and its replay
func _process(delta: float) -> void:
	if is_playing():
		_play_step(delta)
		return
	if _pending.is_empty() or get_tree().paused or not RingRules.stock_on():
		return
	var p := _pending[0] as Dictionary
	p["waited"] = float(p.waited) + delta / maxf(Engine.time_scale, 0.01)
	var waited := float(p.waited)
	var busy := moment_busy()
	# (round 4's merge: the live splash is always seen first (wait_s real), the slow beat runs out (RingMoment), and the
	# clip's tail after the splash is in the buffer (tail_s of game ticks) before the cut-away)
	var tail_due := _tick - int(p.ko) < int(round(num("tail_s", 0.6) * tps))
	if waited < num("wait_max_s", 3.0) and (busy or waited < num("wait_s", 0.6) or tail_due):
		return
	_pending.pop_front()
	var clip := ko_clip(int(p.ko), int(p.slot), int(p.by))
	if clip != null:
		play(clip)


## Replays waiting for their fall's moment to end.
func pending() -> int:
	return _pending.size()


## IMPACT's ring-out moment still under way (round 4's merge: RingMoment called directly).
static func moment_busy() -> bool:
	return RingMoment.busy()


# ---------------------------------------------------------------- clips
## A window of the buffer (absolute ticks t0..t1, clamped to what it holds) copied out: every competitor's arrays, the
## props alive in it (their templates copied), its events. Null when the buffer holds none of it.
func snapshot(t0: int, t1: int) -> Clip:
	var lo := maxi(_tick - _filled, 0)
	t0 = maxi(t0, lo)
	t1 = mini(t1, _tick - 1)
	if t1 <= t0:
		return null
	var c := Clip.new()
	c.n = t1 - t0 + 1
	c.tps = tps
	c.t0 = t0
	c.names = _names.duplicate()
	for si in _slots.size():
		var s := _slots[si] as Slot
		var a := maxi(t0, s.from)
		if a > t1 or s.tpl == null or not is_instance_valid(s.tpl):
			c.bodies.append({})
			continue
		# (its pose samples within the window, oldest first, each with its tick in the clip)
		var pticks := PackedInt32Array()
		var prot := PackedInt32Array()
		var ppos := PackedFloat32Array()
		var rs := s.bones * 2
		var ps := s.pos_idx.size() * 3
		for k in range(maxi(a - s.pose_every, 0) / s.pose_every, t1 / s.pose_every + 1):
			var j := k % s.pcap
			var pt := s.ptick[j]
			if pt < a - s.pose_every or pt > t1 or pt / s.pose_every != k:
				continue
			pticks.append(pt - t0)
			prot.append_array(s.prot.slice(j * rs, (j + 1) * rs))
			ppos.append_array(s.ppos.slice(j * ps, (j + 1) * ps))
		var d := {"tpl": s.tpl.duplicate(), "bones": s.bones, "pos_idx": s.pos_idx.duplicate(), "from": a - t0, "team": s.team,
				"el": s.el, "body_id": s.body_id, "xf": _ring_slice(s.xf, 12, a, t1), "pticks": pticks, "prot": prot, "ppos": ppos,
				"pct": _ring_slice(s.pct, 1, a, t1), "flags": _ring_bytes(s.flags, a, t1), "clip": _ring_ints(s.clip, a, t1),
				"clip_t": _ring_slice(s.clip_t, 1, a, t1)}
		c.nodes.append(d.tpl)
		c.bodies.append(d)
	for p: Prop in _props:
		var died := p.died if p.died >= 0 else _tick - 1
		var a := maxi(p.born, t0)
		var b := mini(died, t1)
		if b < a or p.tpl == null or not is_instance_valid(p.tpl):
			continue
		var tpl := p.tpl.duplicate() as Node3D
		c.nodes.append(tpl)
		c.props.append({"tpl": tpl, "from": a - t0, "to": b - t0, "xf": _ring_slice(p.xf, 12, a, b), "kind": p.kind})
	for k in mini(_ev_n, _ev_k.size()):
		var t := _ev_t[k]
		if t < t0 or t > t1:
			continue
		c.events.append({"k": _ev_k[k], "t": t - t0, "pos": _ev_pos[k], "dir": _ev_dir[k], "el": _ev_el[k], "a": _ev_a[k], "b": _ev_b[k]})
	c.events.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.t) < int(y.t))
	return c


## A fall's clip: replay_s before the fall's tick to tail_s after it (as far as recorded), focused on the faller and whoever
## sent him (else the nearest other competitor), slowed around his last launch.
func ko_clip(ko_tick: int, faller: int, by: int) -> Clip:
	var t0 := ko_tick - int(round(num("replay_s", 3.5) * tps))
	var t1 := ko_tick + int(round(num("tail_s", 0.6) * tps))
	var c := snapshot(t0, t1)
	if c == null:
		return null
	c.faller = faller
	c.thrower = by if by != faller else -1
	c.splash_t = ko_tick - c.t0
	var ll := int(_last_launch.get(faller, -1))
	c.hit_t = ll - c.t0 if ll >= c.t0 and ll <= ko_tick else -1
	c.why = "fall"
	return c


## Elements t0..t1 (absolute ticks) of a ring buffer of `stride` floats a tick.
func _ring_slice(a: PackedFloat32Array, stride: int, t0: int, t1: int) -> PackedFloat32Array:
	if stride <= 0:
		return PackedFloat32Array()
	var i0 := t0 % cap
	var n := t1 - t0 + 1
	if i0 + n <= cap:
		return a.slice(i0 * stride, (i0 + n) * stride)
	var out := a.slice(i0 * stride, cap * stride)
	out.append_array(a.slice(0, (n - (cap - i0)) * stride))
	return out


func _ring_bytes(a: PackedByteArray, t0: int, t1: int) -> PackedByteArray:
	var i0 := t0 % cap
	var n := t1 - t0 + 1
	if i0 + n <= cap:
		return a.slice(i0, i0 + n)
	var out := a.slice(i0, cap)
	out.append_array(a.slice(0, n - (cap - i0)))
	return out


func _ring_ints(a: PackedInt32Array, t0: int, t1: int) -> PackedInt32Array:
	var i0 := t0 % cap
	var n := t1 - t0 + 1
	if i0 + n <= cap:
		return a.slice(i0, i0 + n)
	var out := a.slice(i0, cap)
	out.append_array(a.slice(0, n - (cap - i0)))
	return out


## The newest absolute tick written (-1 none), and the next one to be written (this frame's events' tick).
func newest_tick() -> int:
	return _tick - 1


func next_tick() -> int:
	return _tick


## The buffer's bytes now (every array's): fixed once each slot and prop is in use.
func bytes() -> int:
	var n := 0
	for s: Slot in _slots:
		n += s.bytes()
	for p: Prop in _props:
		n += p.xf.size() * 4
	n += _ev_k.size() * (4 * 5 + 12 * 2)
	return n


## The buffer's sample for a competitor at absolute tick t: {xf (its skeleton's), rot (bone `bone`'s rotation), pct} ({}:
## not held) (tests).
func buffer_at(b: Node, t: int, bone := 0) -> Dictionary:
	var si := slot_index(b)
	if si < 0 or t < _tick - _filled or t >= _tick:
		return {}
	var s := _slots[si] as Slot
	var i := t % cap
	var out := {"xf": get_xf(s.xf, i * 12), "pct": s.pct[i]}
	var j := (t / s.pose_every) % s.pcap
	if s.ptick[j] == t:
		out["rot"] = unpack_q(s.prot, (j * s.bones + bone) * 2)
	return out


# ---------------------------------------------------------------- the player
func is_playing() -> bool:
	return _clip != null


## Plays `clip` through the Splash Cam (see the header). False when it cannot (one is playing, no clip, nothing to show).
func play(clip: Clip) -> bool:
	if clip == null or is_playing() or not is_inside_tree():
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	_clip = clip
	_now_playing = self
	_skip = false
	_was_paused = get_tree().paused
	get_tree().paused = true
	_mouse = Input.mouse_mode
	_root3 = Node3D.new()
	_root3.name = "SplashCam"
	_root3.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(_root3)
	_ghosts.clear()
	for d: Dictionary in clip.bodies:
		if d.is_empty():
			_ghosts.append(null)
			continue
		var g := (d.tpl as Node3D).duplicate() as Node3D
		g.process_mode = Node.PROCESS_MODE_ALWAYS
		_root3.add_child(g)
		g.top_level = true
		_ghosts.append(g)
	_prop_ghosts.clear()
	for p: Dictionary in clip.props:
		var g := (p.tpl as Node3D).duplicate() as Node3D
		g.process_mode = Node.PROCESS_MODE_ALWAYS
		g.visible = false
		_root3.add_child(g)
		g.top_level = true
		_prop_ghosts.append(g)
	_hide_live()
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.name = "SplashCamCamera"
	_cam.fov = sub("camera", "fov", 46.0)
	if _prev_cam != null:
		_cam.environment = _prev_cam.environment
		_cam.attributes = _prev_cam.attributes
		_cam.cull_mask = _prev_cam.cull_mask
		_cam.near = _prev_cam.near
		_cam.far = _prev_cam.far
	_root3.add_child(_cam)
	_cam.top_level = true
	_cam.make_current()
	_cam_snap = true
	_cam_side = _pick_side()
	_pt = 0.0
	_ev_next = 0
	_set_always(true)
	_hide_layers(true)
	if _overlay != null and _overlay.has_method(&"show_tag"):
		_overlay.call(&"show_tag", true)
	replays_started += 1
	_pose(0.0)
	_frame_cam(0.0, 0.0)
	started.emit(clip)
	return true


## Ends the replay now (a key, or its end): everything as it was, the tree going on.
func skip() -> void:
	if is_playing():
		_skip = true


func _play_step(delta: float) -> void:
	var c := _clip
	if _skip or _pt >= float(c.n - 1):
		_finish(_skip)
		return
	var real := delta / maxf(Engine.time_scale, 0.01)        # (a replay runs on the wall clock)
	if held:
		return
	var rate := rate_at(_pt)
	var was := _pt
	_pt = minf(_pt + real * float(c.tps) * rate, float(c.n - 1))
	_fire_events(was, _pt)
	_pose(_pt)
	_frame_cam(_pt, real)


## The replay's speed at clip tick `t`: slow.rate within window_s / 2 of the decisive hit, eased over ease_s, else 1.
func rate_at(t: float) -> float:
	var c := _clip
	if c == null or c.hit_t < 0:
		return 1.0
	var half := sub("slow", "window_s", 0.5) * 0.5 * float(c.tps)
	var ease := maxf(sub("slow", "ease_s", 0.12) * float(c.tps), 0.001)
	var d := absf(t - float(c.hit_t))
	var k := clampf((d - half) / ease, 0.0, 1.0)
	return lerpf(sub("slow", "rate", 0.4), 1.0, k * k * (3.0 - 2.0 * k))


## The ghosts and props at clip tick `t` (between ticks: transforms lerped, bones slerped).
func _pose(t: float) -> void:
	var c := _clip
	var i0 := clampi(floori(t), 0, c.n - 1)
	var i1 := mini(i0 + 1, c.n - 1)
	var f := t - float(i0)
	for gi in _ghosts.size():
		var g := _ghosts[gi] as Node3D
		if g == null:
			continue
		var d := c.bodies[gi] as Dictionary
		var from := int(d.from)
		if i0 < from:
			g.visible = false
			continue
		var j0 := i0 - from
		var j1 := i1 - from
		var fl := (d.flags as PackedByteArray)
		g.visible = (fl[j0] & F_SHOWN) != 0
		var xa := get_xf(d.xf, j0 * 12)
		var xb := get_xf(d.xf, j1 * 12)
		g.global_transform = xa.interpolate_with(xb, f)
		_pose_bones(g.get_child(0) as Skeleton3D, d, t)
	for pi in _prop_ghosts.size():
		var g := _prop_ghosts[pi] as Node3D
		var p := c.props[pi] as Dictionary
		var a := int(p.from)
		var b := int(p.to)
		if i0 < a or i0 > b:
			g.visible = false
			continue
		g.visible = true
		var j0 := i0 - a
		var j1 := mini(i1, b) - a
		g.global_transform = get_xf(p.xf, j0 * 12).interpolate_with(get_xf(p.xf, j1 * 12), f)


## A ghost's skeleton at clip tick `t`: between the two pose samples around it (rotations slerped, the bones' places
## lerped); before the first, the first.
func _pose_bones(gsk: Skeleton3D, d: Dictionary, t: float) -> void:
	var pt := d.pticks as PackedInt32Array
	var n := pt.size()
	if n == 0:
		return
	var k0 := 0
	var lo := 0
	var hi := n - 1
	while lo <= hi:                          # (the last sample at or before t)
		var mid := (lo + hi) / 2
		if float(pt[mid]) <= t:
			k0 = mid
			lo = mid + 1
		else:
			hi = mid - 1
	var k1 := mini(k0 + 1, n - 1)
	var f := 0.0
	if k1 != k0 and pt[k1] > pt[k0]:
		f = clampf((t - float(pt[k0])) / float(pt[k1] - pt[k0]), 0.0, 1.0)
	var nb := mini(int(d.bones), gsk.get_bone_count())
	var prot := d.prot as PackedInt32Array
	var rs := int(d.bones) * 2
	for k in nb:
		var qa := unpack_q(prot, k0 * rs + k * 2)
		gsk.set_bone_pose_rotation(k, qa if f < 0.001 else qa.slerp(unpack_q(prot, k1 * rs + k * 2), f))
	var pidx := d.pos_idx as PackedInt32Array
	var pos := d.ppos as PackedFloat32Array
	var ps := pidx.size() * 3
	for m in pidx.size():
		var oa := k0 * ps + m * 3
		var va := Vector3(pos[oa], pos[oa + 1], pos[oa + 2])
		if f >= 0.001:
			var ob := k1 * ps + m * 3
			va = va.lerp(Vector3(pos[ob], pos[ob + 1], pos[ob + 2]), f)
		gsk.set_bone_pose_position(pidx[m], va)


## The replay held at clip tick `t` (tests and the review strip: the ghosts and props posed there, the camera framed).
func seek(t: float) -> void:
	if not is_playing():
		return
	_pt = clampf(t, 0.0, float(_clip.n - 1))
	_pose(_pt)
	_frame_cam(_pt, 1.0)


## The clip tick the replay is at, the clip, the ghost of body slot `si` (null none), the replay's camera.
func clip_tick() -> float:
	return _pt


func clip() -> Clip:
	return _clip


func ghost(si: int) -> Node3D:
	return _ghosts[si] as Node3D if si >= 0 and si < _ghosts.size() else null


func camera() -> Camera3D:
	return _cam


## The events between clip ticks a (exclusive) and b (inclusive) made again: bursts, a splash, a clash's moment.
func _fire_events(a: float, b: float) -> void:
	var c := _clip
	while _ev_next < c.events.size() and float((c.events[_ev_next] as Dictionary).t) <= b:
		var e := c.events[_ev_next] as Dictionary
		_ev_next += 1
		if float(e.t) < a - 0.5:
			continue
		var el := String(ELS[int(e.el)]) if int(e.el) >= 0 and int(e.el) < ELS.size() else "air"
		var mat := {"earth": "stone", "water": "water", "fire": "fire", "air": "air"}.get(el, el) as String
		match int(e.k):
			Ev.HIT:
				BendLooks.burst(e.pos, mat, 16)
			Ev.LAUNCH:
				BendLooks.burst(e.pos, mat, 34, (e.dir as Vector3).normalized(), 70.0, 7.0, 0.4)
				BendSounds.event("knock", e.pos, 2.0)
			Ev.GUARD:
				BendLooks.burst(e.pos, mat, 14, Vector3.UP, 180.0, 3.0, 0.3)
			Ev.CATCH:
				BendLooks.burst(e.pos, "stone", 20, Vector3.UP, 160.0, 3.0, 0.35)
				BendSounds.event("catch", e.pos, 1.0)
			Ev.SPLASH:
				var r := RingArena.find(get_tree())
				var at := e.pos as Vector3
				if r != null and r.water != null:
					var wy := Vector3(at.x, r.water.level_y, at.z)
					if r.water.has_method(&"ko_splash"):
						r.water.call(&"ko_splash", wy, 12.0)
					else:
						r.water.splash(wy, 12.0)
					BendLooks.burst(wy + Vector3.UP * 0.3, "water", 60, Vector3.UP, 50.0, 9.0, 0.9)   # (the pool runs on: it shows)
				BendSounds.event("ringout", at, 2.0)
			Ev.CLASH:
				var kb := int(e.b)
				BendClash.effect(e.pos, mat, String(ELS[kb]) if kb >= 0 and kb < ELS.size() else mat, e.dir)


## The camera's side of the pair (+1 / -1): the one nearer the camera that was in use (the view keeps its way round).
func _pick_side() -> float:
	var c := _clip
	var pa := _subject(c.faller, 0.0)
	var pb := _subject(c.thrower, 0.0) if c.thrower >= 0 else _other_subject(0.0)
	var line := Vector3(pa.x - pb.x, 0.0, pa.z - pb.z)
	if line.length() < 0.5:
		var r := RingArena.find(get_tree())
		line = r.axis() if r != null else Vector3.RIGHT
	var side := line.normalized().cross(Vector3.UP)
	if _prev_cam != null and is_instance_valid(_prev_cam):
		var to := _prev_cam.global_position - (pa + pb) * 0.5
		return 1.0 if side.dot(to) >= 0.0 else -1.0
	return 1.0


## Where body slot `si` stands at clip tick t (its skeleton's place, held at the water's height once under it).
func _subject(si: int, t: float) -> Vector3:
	var c := _clip
	if si < 0 or si >= c.bodies.size() or (c.bodies[si] as Dictionary).is_empty():
		return Vector3.ZERO
	var d := c.bodies[si] as Dictionary
	var fl := d.flags as PackedByteArray
	var j := clampi(floori(t) - int(d.from), 0, fl.size() - 1)
	var j0 := j
	while j > 0 and (fl[j] & F_SHOWN) == 0 and j0 - j < 4 * c.tps:
		j -= 1                                 # (out of play: where he was last seen, the splash)
	var p := get_xf(d.xf, j * 12).origin
	var r := RingArena.find(get_tree())
	if r != null and r.water != null:
		p.y = maxf(p.y, r.water.level_y + sub("camera", "water_y_pad", 0.8))
	return p


## The nearest other competitor to the faller at t (no thrower: a fall of his own).
func _other_subject(t: float) -> Vector3:
	var c := _clip
	var pf := _subject(c.faller, t)
	var best := pf
	var bd := INF
	for si in c.bodies.size():
		if si == c.faller or (c.bodies[si] as Dictionary).is_empty():
			continue
		var p := _subject(si, t)
		var d := p.distance_to(pf)
		if d < bd:
			bd = d
			best = p
	return best


## The side dolly (see the header): both in frame, the line between them across the screen.
func _frame_cam(t: float, real: float) -> void:
	var c := _clip
	var pa := _subject(c.faller, t)
	var pb := _subject(c.thrower, t) if c.thrower >= 0 else _other_subject(t)
	var mid := (pa + pb) * 0.5
	var line := Vector3(pa.x - pb.x, 0.0, pa.z - pb.z)
	var sep := line.length()
	if sep < 0.5:
		var r := RingArena.find(get_tree())
		line = r.axis() if r != null else Vector3.RIGHT
	line = line.normalized()
	var side := line.cross(Vector3.UP) * _cam_side
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0) if vp.y > 0.0 else 16.0 / 9.0
	var hfov := 2.0 * atan(tan(deg_to_rad(_cam.fov) * 0.5) * aspect)
	var spread := maxf(sep, absf(pa.y - pb.y) * aspect)
	var dist := clampf((spread * 0.5 + sub("camera", "margin_m", 3.0)) / tan(hfov * 0.5), sub("camera", "min_dist_m", 7.5),
			sub("camera", "max_dist_m", 32.0))
	var secs := t / float(maxi(c.tps, 1))
	var want := mid + side * dist + Vector3.UP * sub("camera", "height_m", 2.6) + line * sub("camera", "dolly_mps", 0.7) * (secs - 1.5)
	var look := mid + Vector3.UP * sub("camera", "look_up_m", 0.9)
	if _cam_snap:
		_cam_pos = want
		_cam_look = look
		_cam_snap = false
	else:
		var k := 1.0 - exp(-sub("camera", "smooth", 5.0) * real)
		_cam_pos = _cam_pos.lerp(want, k)
		_cam_look = _cam_look.lerp(look, k)
	_cam.global_position = _cam_pos
	if _cam_pos.distance_to(_cam_look) > 0.01:
		_cam.look_at(_cam_look, Vector3.UP)


func _hide_live() -> void:
	_hidden.clear()
	for b: Node3D in _bodies():
		if b.visible:
			_hidden.append(b)
			b.visible = false
	for g: StringName in PROP_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and (n as Node3D).visible:
				_hidden.append(n)
				(n as Node3D).visible = false


## Every other screen layer hidden (the HUD, the ring's words, the screens) while it plays; shown again after.
func _hide_layers(on: bool) -> void:
	if on:
		_layers.clear()
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			var cl := n as CanvasLayer
			if cl == _overlay or not cl.visible:
				continue
			_layers.append(cl)
			cl.visible = false
		return
	for cl in _layers:
		if is_instance_valid(cl):
			(cl as CanvasLayer).visible = true
	_layers.clear()


## The effects' pool and the sounds' voices go on while the tree is held (the replay's bursts and sounds).
func _set_always(on: bool) -> void:
	var pool := ToonFxPool.of(get_tree().current_scene) if BendLooks.live() else null
	var voices: Node = BendSounds._get_runner()
	if on:
		if pool != null:
			_pool_mode = pool.process_mode
			pool.process_mode = Node.PROCESS_MODE_ALWAYS
		if voices != null:
			_voices_mode = voices.process_mode
			voices.process_mode = Node.PROCESS_MODE_ALWAYS
		return
	if pool != null and _pool_mode >= 0:
		pool.process_mode = _pool_mode as Node.ProcessMode
	if voices != null and is_instance_valid(voices) and _voices_mode >= 0:
		voices.process_mode = _voices_mode as Node.ProcessMode
	_pool_mode = -1
	_voices_mode = -1


func _finish(skipped: bool) -> void:
	if _clip == null:
		return
	for n in _hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden.clear()
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_prev_cam = null
	if is_instance_valid(_root3):
		_root3.queue_free()
	_root3 = null
	_cam = null
	_ghosts.clear()
	_prop_ghosts.clear()
	_set_always(false)
	_hide_layers(false)
	if _overlay != null and _overlay.has_method(&"show_tag"):
		_overlay.call(&"show_tag", false)
	_clip = null
	if _now_playing == self:
		_now_playing = null
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse
	replays_finished += 1
	finished.emit(skipped)


## A window of the buffer copied out (snapshot): what the Splash Cam plays. Owns its nodes (the ghosts' and props'
## templates): freed with it.
class Clip extends RefCounted:
	## Ticks, the rate they were written at, the first's absolute tick.
	var n := 0
	var tps := 60
	var t0 := 0
	## Per competitor slot ({} none in this window): tpl, bones, pos_idx, from (its first tick in the clip), team, el,
	## body_id, xf, rot, pos, pct, flags, clip, clip_t.
	var bodies: Array = []
	## {tpl, from, to, xf, kind}
	var props: Array = []
	## {k (Ev), t, pos, dir, el, a, b}
	var events: Array = []
	var names: Array = []
	var nodes: Array = []
	## The framing: the faller's and the thrower's slots (-1 none), the decisive hit's and the splash's clip ticks.
	var faller := -1
	var thrower := -1
	var hit_t := -1
	var splash_t := -1
	var why := ""

	func secs() -> float:
		return float(n) / float(maxi(tps, 1))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			for nd in nodes:
				if nd is Node and is_instance_valid(nd) and (nd as Node).get_parent() == null:
					(nd as Node).free()
			nodes.clear()


## A competitor's place in the buffer: its arrays (a tick each: its skeleton's transform, %, state, clip; its pose: every
## bone's rotation and position, with the tick each pose was read at) and its ghost's template. Written in
## place (its own methods), never grown.
class Slot extends RefCounted:
	var body_id := 0
	var sk: Skeleton3D
	## The last tick written.
	var last := -1
	var bones := 0
	var pos_idx := PackedInt32Array()
	var from := 0
	var team := -1
	var el := ""
	var ap: AnimationPlayer
	var tpl: Node3D
	var cap := 0
	var xf := PackedFloat32Array()
	var pct := PackedFloat32Array()
	var flags := PackedByteArray()
	var clip := PackedInt32Array()
	var clip_t := PackedFloat32Array()
	## The pose ring: a sample every pose_every ticks (the newest of its ticks): each bone's rotation as two int32s (x|y,
	## z|w at 16 bits each), every bone's position (pos_idx: all of them), the tick it was read at (-1 none).
	var pose_every := 2
	var pcap := 0
	var prot := PackedInt32Array()
	var ppos := PackedFloat32Array()
	var ptick := PackedInt32Array()

	func alloc(p_cap: int, p_every: int, p_sk: Skeleton3D) -> void:
		cap = p_cap
		pose_every = p_every
		bones = p_sk.get_bone_count()
		for k in bones:
			# (every bone's place, not only the roots' and their children's: the body's twist and skirt helpers
			# (CharacterBodyMesh) are driven to new places every frame several bones deep, and a ghost holding their rest
			# places drew the arms as rubber bands, up to 0.87 m off; the owner 2026-10-11: "the replay element it shoulds
			# body parts like rubberbands")
			pos_idx.append(k)
		xf.resize(cap * 12)
		pct.resize(cap)
		flags.resize(cap)
		clip.resize(cap)
		clip_t.resize(cap)
		pcap = ceili(float(cap) / float(pose_every)) + 1
		prot.resize(pcap * bones * 2)
		ppos.resize(pcap * pos_idx.size() * 3)
		ptick.resize(pcap)
		ptick.fill(-1)

	## Tick slot `i`: the skeleton's transform, the %, the state, the clip.
	func write(i: int, f: int, p: float, ci: int, ct: float) -> void:
		if not is_instance_valid(sk) or not sk.is_inside_tree():
			return
		write_xf(i)
		pct[i] = p
		flags[i] = f
		clip[i] = ci
		clip_t[i] = ct

	## Tick slot `i`'s skeleton transform: where it stands now.
	func write_xf(i: int) -> void:
		if not is_instance_valid(sk) or not sk.is_inside_tree():
			return
		var t := sk.global_transform
		var o := i * 12
		xf[o] = t.basis.x.x
		xf[o + 1] = t.basis.x.y
		xf[o + 2] = t.basis.x.z
		xf[o + 3] = t.basis.y.x
		xf[o + 4] = t.basis.y.y
		xf[o + 5] = t.basis.y.z
		xf[o + 6] = t.basis.z.x
		xf[o + 7] = t.basis.z.y
		xf[o + 8] = t.basis.z.z
		xf[o + 9] = t.origin.x
		xf[o + 10] = t.origin.y
		xf[o + 11] = t.origin.z

	## The skeleton's pose now, as absolute tick `t`'s (its sample: t / pose_every; once a sample, its first frame).
	func write_pose(t: int) -> void:
		if not is_instance_valid(sk):
			return
		var j := (t / pose_every) % pcap
		if ptick[j] >= 0 and ptick[j] / pose_every == t / pose_every:
			return
		var o := j * bones * 2
		for k in bones:
			var q := sk.get_bone_pose_rotation(k)
			prot[o] = (roundi(q.x * 32767.0) & 0xFFFF) | (roundi(q.y * 32767.0) << 16)
			prot[o + 1] = (roundi(q.z * 32767.0) & 0xFFFF) | (roundi(q.w * 32767.0) << 16)
			o += 2
		o = j * pos_idx.size() * 3
		for k in pos_idx:
			var v := sk.get_bone_pose_position(k)
			ppos[o] = v.x
			ppos[o + 1] = v.y
			ppos[o + 2] = v.z
			o += 3
		ptick[j] = t

	func bytes() -> int:
		return (xf.size() + pct.size() + clip_t.size() + ppos.size()) * 4 + (clip.size() + prot.size() + ptick.size()) * 4 + flags.size()


## A packed rotation (two int32s at `o`: x|y, z|w at 16 bits each) back to a quaternion.
static func unpack_q(a: PackedInt32Array, o: int) -> Quaternion:
	var v0 := a[o]
	var v1 := a[o + 1]
	var x := v0 & 0xFFFF
	var z := v1 & 0xFFFF
	if x >= 32768:
		x -= 65536
	if z >= 32768:
		z -= 65536
	return Quaternion(float(x) / 32767.0, float(v0 >> 16) / 32767.0, float(z) / 32767.0, float(v1 >> 16) / 32767.0).normalized()


## An effect's place in the buffer: its template (its look), the ticks it lived (died -1: alive), its transform a tick.
class Prop extends RefCounted:
	var tpl: Node3D
	var born := 0
	var died := -1
	var kind := ""
	var xf := PackedFloat32Array()

	func put(i: int, t: Transform3D) -> void:
		var o := i * 12
		xf[o] = t.basis.x.x
		xf[o + 1] = t.basis.x.y
		xf[o + 2] = t.basis.x.z
		xf[o + 3] = t.basis.y.x
		xf[o + 4] = t.basis.y.y
		xf[o + 5] = t.basis.y.z
		xf[o + 6] = t.basis.z.x
		xf[o + 7] = t.basis.z.y
		xf[o + 8] = t.basis.z.z
		xf[o + 9] = t.origin.x
		xf[o + 10] = t.origin.y
		xf[o + 11] = t.origin.z
