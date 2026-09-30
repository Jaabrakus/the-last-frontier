class_name BoatRider
extends Node
## Getting into a boat and paddling it (a child of every Boat; user 2026-09-29: "do the boarding and paddling, the oars will be left
## inside the boat"; paddling is plain controls, only the building is a puzzle). E at the boat (PlayerInteractor: it glows and says
## "Get in the canoe") puts the player into it, kneeling (the player's own kneel: FrontierPlayer.begin_kneel, this node the owner that
## drives the body and the pose), and takes up one of the boat's paddles or oars from where it lay inside. While aboard:
##   W / S     the crew strokes ahead / backs water (Boat.drive throttle)
##   A / D     steers left / right
##   C         crouches low in the boat (the game's own crouch: the paddle laid back where it lay): they can equip weapons and hold aim to
##             shoot from the boat, hidden below the gunwale as a crouched player is (the wild sees them less); the boat drifts. They are
##             free to move about the floor as in any crouch (the boat carries them: their place is kept in its frame), jump out over the
##             gunwale (Space at the edge), or stand (C again) to kneel to the paddle again.
##   E         gets out, on the bank side if there is one, the paddle laid back where it was
## The camera goes on orbiting the player as when they kneel. The boat carries them; nothing else about them changes.
## The paddle: in the hand (a BoneAttachment3D on the right palm), swung with the boat's stroke so the blade dips as it pulls.

const GROUP := &"interactables"
const SEAT_Z := -0.18      ## along the hull from its middle, as a fraction of its length (a kneeling paddler's place, aft of the middle)
## The paddler's own clips (tools/anim_author/author_paddle.gd, baked into animations_extra/Frontier_Own.res): crouched with the paddle
## ready (a loop), and one stroke raised out of the crouch (the boat's stroke phase is its time: the drive is the first two fifths).
const OWN_PATH := "res://animations_extra/Frontier_Own.res"
const CLIP_LIB := "frontier_own"
## (Each has a mirrored twin for a stroke on the left, "-l": the right hand then the top hand.)
const READY := "own-paddle-crouch"
const READY_LEN := 3.0
const STROKE := "own-paddle-stroke"
const STROKE_LEN := 1.6

var boat: Boat
var rider: FrontierPlayer
var interact_reach := 3.2
var _ap: AnimationPlayer
var _blender: HorsePhaseBlender
var _t := 0.0
var _paddle: Node3D
var _paddle_home := Transform3D()
var _attach: BoneAttachment3D
var _inert := false
## "paddle": kneeling with the paddle; "crouch": crouched in the game's own pose, carried by the boat.
var mode := "paddle"
var _crouch_t := 0.0
## The side paddled on ("" right, "-l" left), chosen at the start of each stroke: to turn right they paddle on the left, to turn left on
## the right; going straight they keep the side they have.
var side := ""
var _last_ph := 0.0
var _moving := false
## Crouched: their place in the boat's frame, carried as it moves and turns; the last world place set (their own walking is what moved them since).
var _local := Vector3.ZERO
var _last_world := Vector3.ZERO
const EDGE_M := 0.1     ## how near the gunwale counts as at the edge (jumping out)
const JUMP_OUT := Vector3(2.6, 3.6, 0.0)


static func attach_to(b: Boat) -> BoatRider:
	var r := BoatRider.new()
	r.name = "Rider"
	r.boat = b
	b.add_child(r)
	return r


func _ready() -> void:
	add_to_group(GROUP)
	process_physics_priority = 6   # after the boat has moved


func aboard() -> bool:
	return rider != null and is_instance_valid(rider)


# ---------------------------------------------------------------- E
func interact_prompt(player: Node) -> String:
	if aboard():
		return "Get out" if player == rider else ""
	if player == null or bool(player.get("is_dead")) or player.get("riding") != null or player.get("kneeling") != null:
		return ""
	return "Get in the %s" % String(boat.spec.get("name", "boat")).to_lower()


func interact_point() -> Vector3:
	# aboard: at the player, so "Get out" is always in reach whichever way they look (the interactor counts what is at the feet)
	if aboard():
		return rider.global_position + Vector3.UP * 0.9
	return boat.global_position + Vector3.UP * 0.5


## How far the point is from the hull: from its middle line, less its half beam.
func distance_from(p: Vector3) -> float:
	if aboard() and rider != null:
		return 0.0
	var l := boat.global_transform.affine_inverse() * p
	var half := boat.num("length", 4.0) * 0.5
	var z := clampf(l.z, -half, half)
	return maxf(Vector2(l.x, l.z - z).length() - boat.num("beam", 1.0) * 0.5, 0.0)


func highlight_targets() -> Array:
	var out: Array = []
	if boat.hull_mesh != null:
		for m in boat.hull_mesh.find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).visible:
				out.append(m)
	return out


func interact(player: Node) -> void:
	if aboard():
		if player == rider:
			leave()
	elif player is FrontierPlayer:
		board(player as FrontierPlayer)


# ---------------------------------------------------------------- in and out
func seat_position() -> Vector3:
	return boat.to_global(Vector3(0.0, floor_y_local(), boat.num("length", 4.0) * SEAT_Z))


## The boat floor where a kneeling paddler is, in the boat's frame.
func floor_y_local() -> float:
	return boat.floor_y()


## Puts the player into the boat, kneeling, with the paddle in hand. False when they cannot (dead, riding, climbing, kneeling).
func board(player: FrontierPlayer) -> bool:
	if aboard() or player == null:
		return false
	rider = player
	if not _enter_paddle():
		rider = null
		return false
	player.aboard = self
	_t = 0.0
	boat.crew_on = 1
	return true


## Kneels to the paddle (from the bank, or up out of the crouch): the player's body is the rider's, the paddle in the hands.
func _enter_paddle() -> bool:
	var player := rider
	var ahead := boat.to_global(Vector3(0.0, 0.0, 5.0))
	_ap = player.begin_kneel(self, ahead)
	if _ap == null:
		return false
	player._set_body_collision(false)
	player.aboard = self
	player.velocity = Vector3.ZERO
	player.global_position = seat_position()
	_face(true)
	if not _ap.has_animation_library(CLIP_LIB) and ResourceLoader.exists(OWN_PATH):
		_ap.add_animation_library(CLIP_LIB, load(OWN_PATH) as AnimationLibrary)
	_blender = HorsePhaseBlender.new(_ap, player, CLIP_LIB)
	_blender.show_clip(READY, 0.0, 0.0)
	_blender.update(0.0)
	_take_paddle()
	mode = "paddle"
	return true


func _drop_blender() -> void:
	if _blender != null and _blender.tree != null and is_instance_valid(_blender.tree):
		_blender.tree.active = false
		_blender.tree.queue_free()
	_blender = null


## The floor a crouched player moves about, half its width and length (the boat's frame).
func floor_half() -> Vector2:
	return Vector2(maxf(boat.num("beam", 1.0) * 0.5 - 0.2, 0.18), boat.num("length", 4.0) * 0.5 - 0.5)


## Down into the game's own crouch, low in the boat: the paddle back where it lay, the player's own animation, weapons and walking.
func _enter_crouch() -> void:
	var p := rider
	boat.drive(0.0, 0.0)
	_put_paddle_back()
	_drop_blender()
	p.end_kneel()
	p.aboard = null                     # free to move about the boat
	p._set_body_collision(true)
	p.set_crouched(true)
	p.global_position = seat_position()
	_local = boat.to_local(p.global_position)
	_last_world = p.global_position
	mode = "crouch"
	_crouch_t = 0.0


func leave() -> void:
	if not aboard():
		return
	boat.drive(0.0, 0.0)
	_put_paddle_back()
	var p := rider
	rider = null
	_drop_blender()
	if is_instance_valid(p):
		p.aboard = null
		p.global_position = _bank_point()
		p.velocity = Vector3.ZERO
		p._set_body_collision(true)
		p.end_kneel()
	mode = "paddle"


## Where the player steps out: to the side of the boat nearest the bank (the one with the shallower water).
func _bank_point() -> Vector3:
	var best := boat.global_position
	var bd := INF
	for side in [1.0, -1.0]:
		var q := boat.to_global(Vector3(side * (boat.num("beam", 1.0) * 0.5 + 0.8), 0.0, boat.num("length", 4.0) * SEAT_Z))
		var h := FrontierTerrain.height_at(q.x, q.z)
		var depth := WaterSurface.depth_at(q.x, q.z)
		if depth < bd:
			bd = depth
			best = Vector3(q.x, h + 0.05, q.z)
	return best


func _face(sync_camera := false) -> void:
	# a rower with oars faces aft (pulling), a paddler ahead; the player's own forward is -Z
	var f := boat.forward() * (-1.0 if String(boat.spec.get("kind", "paddle")) == "oars" else 1.0)
	rider.rotation.y = atan2(-f.x, -f.z)
	if sync_camera:
		rider.yaw = rider.rotation.y   # the camera behind them at first; after that they look about as they like


# ---------------------------------------------------------------- the paddle in hand
func _take_paddle() -> void:
	if boat.paddles.is_empty() or rider == null:
		return
	_paddle = boat.paddles[0]
	_paddle_home = _paddle.transform
	var sk := rider.skeleton
	if sk == null or sk.find_bone("r_hand_prop_attachment") < 0:
		return
	_attach = BoneAttachment3D.new()
	_attach.name = "PaddleAttach"
	_attach.bone_name = "r_hand_prop_attachment"
	sk.add_child(_attach)
	_paddle.get_parent().remove_child(_paddle)
	_attach.add_child(_paddle)
	_paddle.transform = BoatGear.PIPE * BoatGear.PADDLE_IN_HANDS   # in the hands as the authored clips hold it


func _put_paddle_back() -> void:
	if _paddle != null and is_instance_valid(_paddle):
		if _paddle.get_parent() != null:
			_paddle.get_parent().remove_child(_paddle)
		boat.add_child(_paddle)
		_paddle.transform = _paddle_home
	if _attach != null and is_instance_valid(_attach):
		_attach.queue_free()
	_paddle = null
	_attach = null


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	if not aboard():
		return
	var p := rider
	if p.is_dead:
		leave()
		return
	if Input.is_action_just_pressed("interact") and not _just_boarded():
		leave()
		return
	_t += dt
	if mode == "crouch":
		_crouch_t += dt
		boat.drive(0.0, 0.0)
		_carry(p)
		# Space at the gunwale: over the side and out (anywhere else it stands them, which is the paddle again below)
		if Input.is_action_just_pressed("jump") and _at_edge():
			_jump_out(p)
			return
		# stood up (C again, or a jump inboard): back to the paddle
		if not p.is_crouching and _crouch_t > 0.25:
			p.set_crouched(false)
			if not _enter_paddle():
				p.set_crouched(true)
				_crouch_t = 0.0
		return
	if p.kneeling != self:
		leave()
		return
	if Input.is_action_just_pressed("crouch") and not _just_boarded():
		_enter_crouch()
		return
	var thr := Input.get_axis("move_back", "move_forward")
	var st := Input.get_axis("move_left", "move_right")
	boat.drive(thr, st)
	p.global_position = seat_position()
	p.velocity = Vector3.ZERO
	_face()
	if _blender != null:
		if absf(boat.throttle) > 0.01:
			# raised out of the crouch, the stroke at the boat's own stroke phase (backing water plays it backward)
			var ph := boat.stroke_phase() if boat.throttle > 0.0 else 1.0 - boat.stroke_phase()
			if not _moving or absf(ph - _last_ph) > 0.5:
				_choose_side(st)   # a new stroke
			_moving = true
			_last_ph = ph
			_blender.show_clip(STROKE + side, clampf(ph, 0.0, 0.999) * STROKE_LEN, 0.4)
		else:
			_moving = false
			_blender.show_clip(READY + side, fposmod(_t, READY_LEN), 0.5)
		_blender.update(dt)


## The side for the next stroke from the steering: paddling on the left turns the boat right, on the right turns it left.
func _choose_side(steer: float) -> void:
	if steer > 0.3:
		side = "-l"
	elif steer < -0.3:
		side = ""


## Carries the player with the boat: what their own walking did since last frame is kept (in the boat's frame), the rest of their place
## goes with the boat as it moves and turns, and they stay on the floor (a step out over the edge is held at it).
func _carry(p: FrontierPlayer) -> void:
	var walked := p.global_position - _last_world
	walked.y = 0.0
	_local += boat.basis.inverse() * walked
	var half := floor_half()
	_local.x = clampf(_local.x, -half.x, half.x)
	_local.z = clampf(_local.z, -half.y, half.y)
	_local.y = boat.floor_y()
	p.global_position = boat.to_global(_local)
	p.velocity = Vector3(0.0, 0.0, 0.0) if not p.is_on_floor() else Vector3(p.velocity.x, 0.0, p.velocity.z)
	_last_world = p.global_position


func _at_edge() -> bool:
	var half := floor_half()
	return absf(_local.x) >= half.x - EDGE_M or absf(_local.z) >= half.y - EDGE_M


## Over the gunwale and out: on the side they are nearest, with a hop.
func _jump_out(p: FrontierPlayer) -> void:
	var out := signf(_local.x) if absf(_local.x) >= floor_half().x - EDGE_M else 0.0
	if out == 0.0:
		out = 1.0
	var side := boat.right() * out
	boat.drive(0.0, 0.0)
	var q := boat.to_global(Vector3(out * (boat.num("beam", 1.0) * 0.5 + 0.35), boat.floor_y() + 0.3, _local.z))
	leave()
	p.global_position = q
	p.velocity = side * JUMP_OUT.x + Vector3.UP * JUMP_OUT.y


func _just_boarded() -> bool:
	return _t < 0.25
