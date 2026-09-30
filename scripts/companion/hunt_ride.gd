class_name HuntRide
extends Node
## A household hunter in the saddle (user 2026-09-29: "if the horse is available they should ride the horse for the hunt";
## "the npc should ride a horse in, park it far enough out of the animal's sight"; "the horse needs to be smart enough to
## avoid things"). A child of her HuntRun.
##
##   seat     her own Actor_B rig on the saddle by the player's HorseRiderLink (the riding clips at the horse's phase, the
##            feet in the stirrups, the hands on the reins); her body carried with the horse (Spouse.riding: her own walk,
##            clips and collider off; the wildlife see a rider as they see the player on a horse: WildAnimal._sense_body)
##   the way  the horse steered as a rider steers it: toward a point RIDE_AHEAD_M along her way (the navigation mesh's path
##            for the horse's own body, NavMover, or the way she came, HuntRun.trail), with the lead's feelers
##            (HorseLead.drive_to: round trunks, rocks and walls, slower where they are close, a turn to the freer side when
##            it is held up); slower into a sharp bend and as it comes up to the goal
##   stood    a frame nobody asks it to go (the hunt's phase has her doing something else), the horse is reined in
## Only a grown worker rides (can_ride); the young lead the horse.
##   ride.mount(h) -> bool           (from beside it)
##   ride.to(goal, arrive, pace, way) -> true when there and the horse has stopped
##   ride.dismount(toward)           (on its side nearer `toward`, where she goes next; the horse left standing where it is)

## A point this far along the way is what she steers for (m).
const RIDE_AHEAD_M := 4.5
## Paces (m/s): a trot on the way, a canter to hurry (the wolves).
const TROT := 3.0
const CANTER := 6.0
## Into a bend sharper than this (deg) she slows to a walk.
const BEND_DEG := 55.0
## The horse's own way on the navigation mesh keeps this far off walls and trunks (m).
const HORSE_R := 0.7
## After she gets down her body and the horse's do not collide for this long (s): she steps off and away, not into it.
const CLEAR_S := 2.5
## A gate is opened from the saddle this far off (m), and held open till she is through.
const GATE_OPEN_M := 7.0
## She gets up from within this of a mount point (m), on either side, or when she is up against the horse (within AT_HORSE_M
## of its middle: at its head or its rump, the mesh not knowing a standing horse, she cannot walk round it).
const MOUNT_AT_M := 1.0
const AT_HORSE_M := 1.7

var run: HuntRun
var body: Spouse
var horse: Horse = null
## In the saddle.
var on := false
var _link: HorseRiderLink
var _nav: NavMover
var _model: Node3D
var _model_local := Transform3D()
var _mods: Array = []
var _layers := [1, 1]
var _drove := -1
var _trip := LandmarkTrip.new()


## Whether worker `w` rides (a grown worker; the young lead the horse).
static func can_ride(w: SpouseCore) -> bool:
	if w == null:
		return false
	var st := String(w.body_look.get("stage", "")) if not w.body_look.is_empty() else ""
	return st == "" or st == "adult"


## How far from `q` a rider stops (m): out of its sight when it is most watchful (a sentry's, WildAnimal._sight_mult 1.5) of
## a rider (1.4), and of the sound of the horse (35 m, by its hearing), with transport.ride.park_margin_m more.
static func park_distance(q: WildAnimal) -> float:
	var c: Dictionary = HuntHaul.tcfg().get("ride", {})
	var sight := 60.0
	var hearing := 1.3
	if q != null and is_instance_valid(q) and q.data is Dictionary:
		sight = float(q.data.get("sight", sight))
		hearing = float(q.data.get("hearing", hearing))
	return maxf(sight * 1.5 * 1.4, 35.0 * hearing) + float(c.get("park_margin_m", 15.0))


func _ready() -> void:
	process_physics_priority = 8        # after the horse has moved: her body where the horse is


## Where she gets up on `h` coming from `from`: the nearer of its two mount points (a trunk or a thicket on one side, the
## other).
static func mount_point(h: Horse, from: Vector3) -> Vector3:
	var l := h.get_mount_point(Horse.LEFT).origin
	var r := h.get_mount_point(Horse.RIGHT).origin
	return l if _flat(l, from) <= _flat(r, from) else r


## Whether a worker at `p` is where she gets up on `h`.
static func at_saddle(h: Horse, p: Vector3) -> bool:
	return _flat(mount_point(h, p), p) <= MOUNT_AT_M or _flat(h.global_position, p) <= AT_HORSE_M


## Up into the saddle of `h` (free: nobody on it, not ridden by the player). False: she cannot.
func mount(h: Horse) -> bool:
	if on or h == null or not is_instance_valid(h) or body == null or body.ap == null:
		return false
	var m := h.get_node_or_null("Mount") as HorseMount
	if m == null or m.rider != null or h.player_input:
		return false
	var l := h.get_node_or_null("Lead") as HorseLead
	if l != null and l.leading:
		l.stop()
	horse = h
	m.rider = body
	body.riding = h
	_layers = [body.collision_layer, body.collision_mask]
	body.collision_layer = 0
	body.collision_mask = 0
	body.velocity = Vector3.ZERO
	_model = body._model
	_model_local = _model.transform
	body.ap.stop()
	body.ap.active = false
	_mods.clear()
	for c in body.sk.get_children():
		if c is SkeletonModifier3D and not (c is CharacterBodyMesh) and not (c is ChildProportion) and (c as SkeletonModifier3D).active:
			(c as SkeletonModifier3D).active = false
			_mods.append(c)
	_link = HorseRiderLink.new()
	_link.name = "RiderLink_%d" % body.get_instance_id()
	h.add_child(_link)
	_link.attach(h, _model, body.ap)
	_nav = NavMover.new(h, HORSE_R)
	on = true
	return true


## Down on the side of it nearer `toward` (where she goes next; its left when that is not given); the horse stands where it
## is, and for CLEAR_S her body passes it (she steps away from it, not into it: the mesh does not know a standing horse).
func dismount(toward := Vector3.INF) -> void:
	if not on:
		return
	on = false
	var h := horse
	horse = null
	if _nav != null:
		_nav.release()
		_nav = null
	if _link:
		_link.horse = null   # (no last sync onto the saddle)
		_link.set_physics_process(false)
		if _link.blender and _link.blender.tree and is_instance_valid(_link.blender.tree):
			_link.blender.tree.active = false
			_link.blender.tree.queue_free()
		_link.queue_free()
		_link = null
	if _model != null and is_instance_valid(_model):
		_model.top_level = false
		_model.transform = _model_local
	body.ap.active = true
	body.set("_clip", "")                    # (her own clip put back on at the next step)
	for c in _mods:
		if is_instance_valid(c):
			(c as SkeletonModifier3D).active = true
	_mods.clear()
	body.riding = null
	body.collision_layer = int(_layers[0])
	body.collision_mask = int(_layers[1])
	body.velocity = Vector3.ZERO
	if h != null and is_instance_valid(h):
		h.drive(0.0, 0.0)
		var m := h.get_node_or_null("Mount") as HorseMount
		if m != null and m.rider == body:
			m.rider = null
		var side := Horse.LEFT
		if toward != Vector3.INF and _flat(h.get_dismount_point(Horse.RIGHT).origin, toward) < _flat(h.get_dismount_point(Horse.LEFT).origin, toward):
			side = Horse.RIGHT
		var at := h.get_dismount_point(side).origin
		body.global_position = at + Vector3.UP * 0.05
		var f := -h.global_basis.z
		body.rotation.y = atan2(-f.x, -f.z)
		body.set("_face", body.rotation.y)
		body.add_collision_exception_with(h)
		var b := body
		get_tree().create_timer(CLEAR_S, false, true).timeout.connect(func() -> void:
			if is_instance_valid(b) and is_instance_valid(h) and b.riding != h:
				b.remove_collision_exception_with(h))


## Rides toward `goal` this frame at `pace` (m/s) along `way` (points to go by, the way she came) or the navigation mesh's
## way. True when the horse is within `arrive` of it and has stopped.
func to(goal: Vector3, arrive: float, pace := TROT, way := PackedVector3Array()) -> bool:
	if not on or horse == null:
		return false
	_drove = Engine.get_physics_frames()
	var dt := get_physics_process_delta_time()
	var me := horse.global_position
	var d := _flat(me, goal)
	var l := horse.get_node_or_null("Lead") as HorseLead
	if d <= arrive:
		horse.drive(0.0, 0.0)
		return absf(horse.speed) < 0.35
	# LANDMARKS: out of the fort (or in) by the gate (NavLandmarks); each leg on the mesh's path for the horse's body
	var leg := _trip.next(horse.get_tree(), me, goal)
	var aim := leg
	if way.size() >= 2:
		aim = carrot(way, me, RIDE_AHEAD_M)
	elif _nav != null:
		_nav.steer(goal, dt, arrive)
		if _nav.on_path and _nav.path.size() >= 2:
			aim = carrot(_nav.path, me, RIDE_AHEAD_M)
	if (_flat(aim, goal) < 0.5 or d < RIDE_AHEAD_M) and leg == goal:
		aim = goal
	# (a shut gate before her: opened from the saddle, and shut again behind once she is through: NavWorld)
	var gate := NavLandmarks.gate_near(horse.get_tree(), me, GATE_OPEN_M)
	if gate != null:
		var nw := NavWorld.of(horse.get_tree())
		if nw != null:
			nw.open_door(gate, GATE_OPEN_M + 1.0)   # (held open while she is this near: shut again once she is through)
		elif not gate.is_open:
			gate.set_open(true)
	var want := minf(pace, maxf(1.0, (d - arrive) * 0.9))
	var fwd := -horse.global_basis.z
	var to_aim := aim - me
	to_aim.y = 0.0
	if to_aim.length() > 0.3 and absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to_aim.x, to_aim.z)))) > BEND_DEG:
		want = minf(want, 1.4)
	if l != null:
		l.drive_to(aim, want, dt)
	else:
		horse.drive(want / Horse.CRUISE[Horse.Gait.CANTER], 0.0)
	return false


## The point `ahead` m along polyline `way` from the point of it nearest `at` (the pursuit point a rider steers for).
static func carrot(way: PackedVector3Array, at: Vector3, ahead: float) -> Vector3:
	var best := INF
	var bi := 0
	var bp := way[0]
	for i in way.size() - 1:
		var a := way[i]
		var b := way[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var t := 0.0
		if ab.length_squared() > 1e-6:
			t = clampf(Vector2(at.x - a.x, at.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var p := a.lerp(b, t)
		var d := _flat(p, at)
		if d < best:
			best = d
			bi = i
			bp = p
	var left := ahead
	var p0 := bp
	for i in range(bi + 1, way.size()):
		var seg := _flat(p0, way[i])
		if seg >= left:
			return p0.lerp(way[i], left / maxf(seg, 1e-4))
		left -= seg
		p0 = way[i]
	return way[way.size() - 1]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _physics_process(_dt: float) -> void:
	if not on:
		return
	if horse == null or not is_instance_valid(horse) or body == null or not is_instance_valid(body):
		dismount()
		return
	# a frame no one rode it on: reined in
	if _drove != Engine.get_physics_frames():
		horse.drive(0.0, 0.0)
	body.global_position = horse.global_position
	body.velocity = horse.velocity
	body.rotation.y = horse.rotation.y


func _exit_tree() -> void:
	if on:
		dismount()
