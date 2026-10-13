class_name StoryActor
extends NpcFighter
## A fighter the story plays, not his brain (docs/main_story.md 10.1, missions 9 and 10; 15 item 1: "a staged capture", "the
## march behind a scripted Leclerc with two guards ... sight cones, no brain"): an NpcFighter (his body in his faction's
## garments, his musket carried low, his hit parts, his barks) whose NpcBrain does not think while `scripted` (the retired
## Two Fires stages' capturing party and guards were these; Captivity's captor can be one).
##
##   var a := StoryActor.make(level, "canadian_militia", at, {"name": "Toussaint Leclerc", "tag": "leclerc", "face": p})
##   a.walk_to(p, StoryActor.JOG)      walks (or runs, by the pace) there on the walk grid; a.arrived()
##   a.walk_to(p, pace, arrive, true)  straight at it (a short dash over open ground: the camp breaking for the pines)
##   a.stand(face)                     stands, facing a point
##   a.captive_lead / a.captive_wait   Captivity's captor hooks: it walks the forced march itself (standing, it looks at
##                                     `look_over` while that is set: a sight the story has it watch, not the captive)
##   a.gaze(p, true)                   its eyes up on `p` (the sky battle): the musket levelled at it (HuntAim on the aim
##                                     clip) or, without the gun, the chest turned up toward it; gaze(Vector3.INF) off
##   a.carry_torch()                   a lit torch in the right hand (a man without a musket: opts weapon "")
##   a.watch = true                    its sight cone on the player: sees_player(), `spotted` as he comes into it
##   a.alert(player)                   it has seen him where he should not be: SUSPICIOUS, its musket up, aware of him as a
##                                     brain would be (StoryObjectives.seen_by finds it, a stay_unseen fails); calm() back
##   a.wake()                          its own brain from now (an NpcFighter as ever: it fights)
## While scripted, nothing a brain hears or is told moves it (ScriptedBrain: another fighter's alarm, a shot heard); struck by
## a foe of its side or by the player it wakes at once and fights back (`woke`: a story's resist).
##
## THE CONE (watch): within cone_deg of where it faces, as far as cone_m by day, NIGHT_SHARE of that in the dark (NpcSenses
## daylight), all of it where a fire or a torch lights the one it looks at, CROUCH_SHARE for one crouched; always within
## CLOSE_M whichever way it faces; a clear line from its eyes to his chest. Looked at every WATCH_S, not each frame.

signal woke(actor: StoryActor, by: Node)
## The player came into its cone (watch on).
signal spotted(actor: StoryActor)

## A jog: the party coming in, a guard catching up (between the walk and the run).
const JOG := 2.6
const WATCH_S := 0.2
const CONE_DEG := 110.0
const CONE_M := 30.0
const NIGHT_SHARE := 0.55
const CROUCH_SHARE := 0.6
const CLOSE_M := 2.5
## A fire or a lit torch within this lights a man as by day.
const LIT_M := 8.0

## Its name on the prompt and in the story's text (over the faction's label), when set.
var display_name := ""
## Played by the story's script (its brain does not think).
var scripted := true
var watch := false
var cone_deg := CONE_DEG
var cone_m := CONE_M
## The player in its cone at the last look.
var sees := false
## It has seen the player where he should not be (alert).
var alerted := false
var torch_model: Node3D
var torch_fire: TorchFire
## Captivity's captor standing looks here instead of at the captive while set.
var look_over := Vector3.INF
## Where it gazes up (gaze()), INF none; with its musket levelled there (gaze_gun) or its chest turned up to it.
var gaze_at := Vector3.INF
var gaze_gun := false
## The chest turned up at most this far toward the gaze (the head goes the rest: a man looking up, not lying back).
const GAZE_PITCH_MAX := deg_to_rad(24.0)
const GAZE_PITCH_SHARE := 0.6

var _order_at := Vector3.INF
var _order_pace := NpcFighter.WALK_SPEED
var _order_arrive := 0.6
var _order_straight := false
var _order_face := Vector3.INF
var _watch_t := 0.0


## A brain that keeps still while its fighter is scripted: no alarm heard or told moves it; a blow from a foe wakes it.
class ScriptedBrain extends NpcBrain:
	func heard(pos: Vector3, radius: float, source: Node) -> void:
		if (me as StoryActor).scripted:
			return
		super.heard(pos, radius, source)

	func told(foe: Node3D, at: Vector3) -> void:
		if (me as StoryActor).scripted:
			return
		super.told(foe, at)

	func hurt(source: Node, dir: Vector3) -> void:
		var a := me as StoryActor
		if a.scripted:
			if source == null or not _is_foe(source):
				return
			a.wake(source)
		super.hurt(source, dir)


## A story's fighter of `p_faction` standing on the ground at `at`, under `parent` (a plain Node or the level: its place is
## the world's). opts: name (display_name), tag, weapon / sidearm (over the faction's: weapon "" for a man with none), seed,
## face (a point), node_name, watch (bool). A tag with a costume (data/story/costumes.json: Leclerc's) wears it over one of
## the faction's looks; any other is dressed as the faction's fighters are.
static func make(parent: Node, p_faction: String, at: Vector3, opts := {}) -> StoryActor:
	var a := StoryActor.new()
	a.faction = p_faction
	a.tag = String(opts.get("tag", ""))
	a.display_name = String(opts.get("name", ""))
	a.weapon = String(opts.get("weapon", "default"))
	a.sidearm = String(opts.get("sidearm", "default"))
	a.rng_seed = int(opts.get("seed", 0))
	a.watch = bool(opts.get("watch", false))
	if not StoryWalker.costume(a.tag).is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = a.rng_seed if a.rng_seed != 0 else hash(a.tag)
		a.look = StoryWalker.in_costume(NpcFactions.look_for(p_faction, rng), a.tag)
	var nm := String(opts.get("node_name", a.tag if a.tag != "" else p_faction))
	a.name = "StoryActor_" + nm.validate_node_name()
	var g := Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z)
	a.home = g
	# (placed before it enters the tree, as NpcSquad does: under a plain Node or the level its place is the world's)
	a.position = g + Vector3.UP * 0.1
	var face: Variant = opts.get("face")
	if face is Vector3:
		var d := (face as Vector3) - g
		if Vector2(d.x, d.z).length() > 0.05:
			a.rotation.y = atan2(-d.x, -d.z)
	parent.add_child(a)
	return a


func _ready() -> void:
	super._ready()
	brain = ScriptedBrain.new(self)
	if display_name != "":
		label = display_name


## Its own brain from now (it fights as any fighter does). `by`: who woke it (a blow), for `woke`.
func wake(by: Node = null) -> void:
	if not scripted:
		return
	scripted = false
	_order_at = Vector3.INF
	woke.emit(self, by)


# ---------------------------------------------------------------- the script's orders
## Walks (WALK_SPEED), jogs (JOG) or runs (RUN_SPEED) to `to`, there within `arrive`; `straight`: straight at it, turned
## aside by the light probe only (no walk-grid plan: a short dash over open ground).
func walk_to(to: Vector3, pace := NpcFighter.WALK_SPEED, arrive := 0.6, straight := false) -> void:
	_order_at = to
	_order_pace = pace
	_order_arrive = arrive
	_order_straight = straight
	_order_face = Vector3.INF


## Stands where it is (facing `face` when given).
func stand(face := Vector3.INF) -> void:
	_order_at = Vector3.INF
	_order_face = face
	_goal = Vector3.INF
	if face != Vector3.INF:
		face_point(face)


## Turned to `p` at once (a story's placing).
func face_now(p: Vector3) -> void:
	face_point(p)
	rotation.y = _face


## Captivity's captor: lead the march to `to` at `pace`.
func captive_lead(to: Vector3, pace: float, _delta: float) -> void:
	walk_to(to, pace, 0.5)


## Captivity's captor: stand and look at the captive (or at `look_over` while the story has it watch something).
func captive_wait(face: Vector3) -> void:
	stand(look_over if look_over != Vector3.INF else face)


## Its eyes up on `p` (a sight in the sky): with `with_gun` the musket levelled at it (the aim clip, HuntAim laying it
## on the point), else the chest turned up toward it, its musket carried. INF: back to its own pose. Walking or running,
## or busy with its hands, it is not held in the gaze (the pose of the walk); it takes it up again standing.
func gaze(p: Vector3, with_gun := false) -> void:
	gaze_at = p
	gaze_gun = with_gun
	if p == Vector3.INF:
		_gaze_off()


## A lit torch in the right hand (true), or put out and gone (false). A man with a musket in that hand lays it by (hidden).
func carry_torch(on := true) -> void:
	if not on:
		if torch_model != null and is_instance_valid(torch_model):
			torch_model.queue_free()
		torch_model = null
		torch_fire = null
		return
	if torch_model != null or body == null:
		return
	if gun != null:
		gun.visible = false
	torch_model = TorchModels.build()
	body.hold(torch_model, NpcFighter.AXE_GRIP)
	var flame := torch_model.get_node_or_null("Flame") as Node3D
	torch_fire = TorchFire.new()
	torch_fire.name = "TorchFire"
	(flame if flame != null else torch_model).add_child(torch_fire)


func holding_torch() -> bool:
	return torch_model != null and is_instance_valid(torch_model)


# ---------------------------------------------------------------- the cone
func sees_player() -> bool:
	return sees


## Whether it sees `n` now: in its cone (or within CLOSE_M), within sight_m(n), a clear line from its eyes to his chest.
func can_see(n: Node3D) -> bool:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree() or is_dead():
		return false
	var to := n.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d > sight_m(n):
		return false
	if d > CLOSE_M and rad_to_deg(forward().angle_to(to.normalized())) > cone_deg * 0.5:
		return false
	return NpcSenses.clear_line(get_world_3d().direct_space_state, eye(), NpcSenses.chest_of(n), n, ray_exclude())


## How far it sees `n` now (m): cone_m by day, NIGHT_SHARE of it in the dark, all of it where a fire or a torch lights him;
## less for one crouched.
func sight_m(n: Node3D) -> float:
	var day := NpcSenses.daylight(get_tree())
	var k := clampf((day - NpcSenses.NIGHT) / maxf(1.0 - NpcSenses.NIGHT, 0.01), 0.0, 1.0)
	var r := cone_m * lerpf(NIGHT_SHARE, 1.0, k)
	if lit_at(get_tree(), n.global_position) or NpcSenses.torch_lit(n):
		r = cone_m
	if NpcSenses.crouched(n):
		r *= CROUCH_SHARE
	return r


## Whether a lit fire or torch (TorchFire.GROUP: a campfire's, a torch in a hand or on the ground) is within LIT_M of `p`.
static func lit_at(tree: SceneTree, p: Vector3) -> bool:
	if tree == null:
		return false
	for f in tree.get_nodes_in_group(TorchFire.GROUP):
		var tf := f as TorchFire
		if tf != null and tf.is_inside_tree() and (tf.state == null or tf.state.lit) and tf.global_position.distance_to(p) <= LIT_M:
			return true
	return false


## It has seen `n` where `n` should not be: aware of him as its brain would be (SPOT), SUSPICIOUS, its musket up, a shout.
func alert(n: Node3D) -> void:
	if is_dead() or n == null or not is_instance_valid(n):
		return
	gaze(Vector3.INF)
	alerted = true
	brain.target = n
	target = n
	brain.last_seen = n.global_position
	brain.aware[n.get_instance_id()] = NpcBrain.SPOT
	if brain.state != NpcBrain.State.SUSPICIOUS and brain.state != NpcBrain.State.COMBAT:
		brain._to(NpcBrain.State.SUSPICIOUS)
		bark("alert")
	stand(n.global_position)


## Back at ease (no longer alerted).
func calm() -> void:
	alerted = false
	brain.target = null
	target = null
	brain.aware.clear()
	if scripted and brain.state != NpcBrain.State.DEAD:
		brain._to(NpcBrain.State.IDLE)


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	if not scripted or is_dead():
		super._physics_process(dt)
		return
	_dt = dt
	# the script's order each frame (whatever stopped it since: a flinch, a blow)
	if _order_at != Vector3.INF:
		go(_order_at, _order_pace, _order_arrive, _order_straight)
	elif _order_face != Vector3.INF and _goal == Vector3.INF:
		face_point(_order_face)
	_act(dt)
	_move(dt)
	if not _gaze_pose():
		_pose()
	if _bark != null:
		_bark_t -= dt
		if _bark_t <= 0.0:
			_bark.visible = false
	if watch:
		_watch_t -= dt
		if _watch_t <= 0.0:
			_watch_t = WATCH_S
			var p := NpcSenses.player
			if p == null or not is_instance_valid(p):
				p = get_tree().current_scene.get_node_or_null("Player") as FrontierPlayer if get_tree().current_scene else null
			var now := can_see(p)
			if now and not sees:
				spotted.emit(self)
			sees = now
	elif sees:
		sees = false


# ---------------------------------------------------------------- the gaze
## The gaze's pose in place of the fighter's own (false: none now, the fighter's pose): standing, its hands free, facing
## the point, the musket levelled at it on the aim clip or the chest turned up toward it.
func _gaze_pose() -> bool:
	if gaze_at == Vector3.INF or body == null or body.aim == null:
		return false
	var moving := Vector2(velocity.x, velocity.z).length() > 0.25 or _order_at != Vector3.INF
	if moving or action != "" or alerted or _surrendered:
		if body.aim.want:
			_gaze_off()
		return false
	face_point(gaze_at)
	var has_gun := gun != null and gun.visible
	if gaze_gun and has_gun:
		body.aim.mode = "line"
		body.play("aim_crouch" if is_crouching else "aim", 0.3)
		body.set_arms("")
		body.aim_at(gaze_at, gun)
		return true
	# the chest turned up a share of the way (at most GAZE_PITCH_MAX): the point brought down for the spine's solve
	var to := gaze_at - eye()
	var flat := Vector2(to.x, to.z).length()
	var pitch := minf(atan2(to.y, maxf(flat, 0.01)) * GAZE_PITCH_SHARE, GAZE_PITCH_MAX)
	var fl := Vector3(to.x, 0.0, to.z).normalized() if flat > 0.01 else forward()
	body.play("crouch" if is_crouching else "idle", 0.3)
	body.set_arms(("carry_crouch_idle" if is_crouching else "carry") if has_gun else "")
	body.aim.mode = "body"
	body.aim.gun = null
	body.aim.target = eye() + (fl * cos(pitch) + Vector3.UP * sin(pitch)) * 50.0
	body.aim.want = true
	return true


## The gaze's turn let go: the musket back in the hand, the aim's own way again (a line along the hands).
func _gaze_off() -> void:
	if body == null or body.aim == null:
		return
	body.aim_off(gun)
	body.aim.mode = "line"
