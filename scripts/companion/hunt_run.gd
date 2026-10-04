class_name HuntRun
extends Node
## A household hunter's body on the hunt (HuntJob is the logic; data/companion/hunt.json): a child of her Spouse body that drives
## it through the body's errand hook (Spouse.errand: [direction, speed] each physics frame while she hunts; null while she kneels
## over the sign, the core's hunt.track, and whenever she is not hunting) and puts the hunt's clips on it.
##
##   stalk      upright towards the quarry, then crouched (the rifle / bow aimed crouch walk) from stalk.walk_until_m, on the
##              downwind side when her Hunting finds it; the animals notice her as they notice the player (_notice: sight,
##              footfall, scent down the wind; crouched and still she is harder to see, her Hunting makes it harder still): she
##              freezes while the quarry is alert, and one that bolts is lost (she reads sign again)
##   aim        from her shot distance (HuntJob.shot_distance) with a clear line: crouched, the gun or bow up, aim_s, then the shot
##   the shot   HuntJob.fire rolls it (shot_odds) and spends the ammunition; the ball or arrow is then a real ray from the muzzle
##              through the animal's hit zones to the heart and lungs (a clean roll), the gut or the haunch (a hit), or past it (a
##              miss), and Hit.deliver gives the zone it met the damage, so the wound is where it went through (WildAnimal
##              .wound_at) and the animal dies, runs wounded or runs unhurt by the wildlife's own rules; the report is heard
##              (WildlifeSpawner.shot: the herd bolts), the smoke and the sound as the player's
##   after      reloading and watching: dead, she goes to it; wounded, she follows it (a finishing shot where it lies up); missed,
##              she reads sign again
##   the kill   hauled home on a rope (HuntDrag, CarcassLoad) to be butchered at home, or field-dressed where it lies (kneeling,
##              HuntJob.dress_minutes of game time) and the meat and hide carried home into the store
##   safety     wolves near (HuntJob.must_stop): she hurries home, lets go of a carcass when one is close, and fires at one that
##              closes while she has a shot; dusk: home
##   the kill home  HuntHaul (the household's horse, cart or wheelbarrow, when she is smart enough and it is free), else by hand
##   the horse  free at home as her stalk begins and the quarry far enough off, she rides it out (HuntRide; the young lead it)
##              and leaves it standing out of the quarry's sight and hearing (HuntRide.park_distance), goes on on foot, and comes
##              back to it for the kill (_horse_first; HuntHaul: the kill across the saddle and the horse led home)
## The weapon: slung on her back while she walks (WorkerGear, the game's SlingRig: the household's gun she took from the rack),
## in her hands while she stalks crouched, aims and fires (off its sling: WorkerGear.hold), aimed as the player aims (HuntAim:
## the aim clip's two-hand hold, stock at the shoulder, the left hand on the fore-end, the upper body turned to lay the barrel on
## the animal's chest), standing in the open and crouched close in or behind cover (_stance); the muzzle's smoke and flash from
## the gun's own Muzzle. Without her gear (her own kit, no pool) a model is laid in her hands and slung on her back here.
## Walking is the body's own (Spouse.walk_to: the NavMover path on the navigation mesh, else straight with its steering), with a
## sidestep when she makes no headway.

const LIB := "actor_b"
const KNEEL := "actor_b-cap-ambi-search-low-in-place"
const ARRIVE := 1.4
## A carcass is reached within this (m).
const AT_CARCASS := 1.9
## Her walk behind the wheelbarrow.
const PUSH := "actor_b-p-push-fw"
## The way she came: a point each this far (m); a loop cut when she comes within TRAIL_LOOP_M of an earlier point; at most
## TRAIL_MAX points (thinned); used when the goal is within TRAIL_NEAR_M of it and she within TRAIL_JOIN_M; a point is
## reached within TRAIL_AT_M, passed when she makes no headway to it for TRAIL_SKIP_S; rejoined after TRAIL_STUCK_S.
const TRAIL_STEP_M := 2.0
const TRAIL_LOOP_M := 1.2
const TRAIL_MAX := 800
const TRAIL_NEAR_M := 10.0
const TRAIL_JOIN_M := 14.0
const TRAIL_AT_M := 1.3
const TRAIL_SKIP_S := 4.0
const TRAIL_STUCK_S := 4.0

var body: Spouse
var sc: SpouseCore
var ground: Ground
var rng := RandomNumberGenerator.new()
var _cb := Callable()
var _gun: Node3D
var _gun_kind := ""
## The gun is this node's own model (laid in her hands each frame), not her gear's; the gear's weapon is in her hands.
var _own_gun := false
var _gear_on := false
## The knife in her hand while she dresses a kill.
var _knife_on := false
var _drag: HuntDrag
## The household's transport for the kill (the horse, the cart, the wheelbarrow): HuntHaul.
var haul: HuntHaul
## Her seat on the horse and its steering (HuntRide).
var ride: HuntRide
## The aim: the upper body turned to put the weapon on the animal, the weapon laid in the aim clip's two-hand hold (HuntAim).
var aim: HuntAim
## The stance of the aim: "stand" in the open, "crouch" close in or behind cover (_stance).
var _stance_now := "stand"
## The slung weapon (on her back while she walks, not aiming) and its kind.
var _sling: Node3D
var _sling_kind := ""
## Seconds in the phase; the phase they count.
var _t := 0.0
var _ph := ""
var _reload_t := 0.0
## The clip that stands for her walk while she moves (the crouched walk), and its pace's reference speed.
var _move_clip := ""
var _move_ref := 1.0
var _speed := 0.0
var _face_to := Vector3.INF
## A shot at a wolf closing in: the wolf, and the aim's seconds.
var _wolf: WildAnimal = null
var _wolf_t := 0.0
## Where she drops the carcass (by the hearth), and the stuck watch on her way.
var _drop := Vector3.INF
var _best_d := INF
var _best_t := 0.0
var _detour_t := 0.0
var _detour := Vector3.ZERO
var _prog_at := Vector3.ZERO
var _prog_t := 0.0
var _prog_f := 0
var _approach := Vector3.INF
var _was_hunting := false
var _last_shot := {}
## The animal she has marked as hers (meta hunted_by: another hunter leaves it), unmarked when the hunt ends.
var _marked: WildAnimal = null
## The way she came (user 2026-09-29: "for the hunting trail it should really be the way they came back, and if it gets
## stuck on something"): where her feet went from where the hunt began, a point each TRAIL_STEP_M (a loop she walked cut
## out: the shortest way she knows). She walks it back home, out again to the kill with the horse or the barrow and back
## with the kill (walk(), the haul's), carrying the meat home and back for more; and in any walk she rejoins it when she
## makes no headway (a post, a trunk, a thicket the mesh does not know) for TRAIL_STUCK_S. Not while she follows it.
var trail := PackedVector3Array()
var _trail_i := -1                 ## the point of it she walks to now (-1: not on it)
var _trail_end := -1               ## the point nearest the goal: she leaves it there
var _trail_goal := Vector3.INF     ## the goal the trail walk is for
var _trail_t := 0.0                ## no headway at the point she walks to (s)
var _trail_best := INF
var _no_way_t := 0.0               ## no headway in a walk, through the sidesteps (s)
var _way := PackedVector3Array()   ## the stretch of the trail she rides now (to the goal), and for which goal and frame
var _way_goal := Vector3.INF
var _way_f := -100
var _way_used_f := -100
## Where she was as she set off for the horse (the side she gets up on, chosen once from there).
var _mount_from := Vector3.INF


## Puts a HuntRun on a worker's body (Spouse._ready, HUNT) and the "game" finder on her core.
static func attach(b: Spouse) -> HuntRun:
	var r := HuntRun.new()
	r.name = "HuntRun"
	r.body = b
	r.sc = b.sc
	b.add_child(r)
	return r


func _ready() -> void:
	process_physics_priority = 5            # after her body has moved (the clip and the facing are put over its own)
	process_priority = 100                  # the weapon laid in her hands after the frame's pose
	rng.seed = hash(sc.name + "hunt") if sc else 7
	ground = Ground.new()
	ground.run = self
	_drag = HuntDrag.new()
	_drag.name = "HuntDrag"
	_drag.body = body
	add_child(_drag)
	haul = HuntHaul.new()
	haul.name = "HuntHaul"
	haul.run = self
	haul.body = body
	haul.sc = sc
	add_child(haul)
	ride = HuntRide.new()
	ride.name = "HuntRide"
	ride.run = self
	ride.body = body
	add_child(ride)
	if body.sk:
		aim = HuntAim.attach(body.sk)
	_cb = Callable(self, "_errand")
	if sc:
		sc.finders["game"] = func() -> Object: return ground if ground.spawner() != null else null


func hunting() -> bool:
	return sc != null and sc.task == HuntJob.JOB and not sc.hunt.is_empty()


# ---------------------------------------------------------------- the errand
## Spouse.errand: [direction, speed] while she hunts, null while she reads sign (the body kneels) or is not hunting.
func _errand(dt: float) -> Variant:
	if not hunting():
		return null
	var ph := HuntJob.phase(sc)
	if ph == "track" or ph == "":
		_move_clip = ""
		_ph = ph
		return null
	if ph != _ph:
		_ph = ph
		_t = 0.0
		_best_d = INF
		_best_t = 0.0
	_t += dt
	_reload_t = maxf(_reload_t - dt, 0.0)
	_move_clip = ""
	_face_to = Vector3.INF
	var out: Array = _safety(dt)
	if out.is_empty():
		out = _step(HuntJob.phase(sc), dt)     # (the safety may have changed the phase: home, for the wolves)
	_speed = float(out[1]) if out.size() > 1 else 0.0
	_aim_update()
	return out


## The aim follows the weapon in her hands: on the quarry (a wolf closing) while the gun is up.
func _aim_update() -> void:
	if aim == null:
		return
	var on := _gun != null and is_instance_valid(_gun) and _gun.visible
	var q: WildAnimal = _wolf if _wolf != null and is_instance_valid(_wolf) else _quarry()
	aim.want = on and q != null and not q.is_dead()
	aim.target = chest_of(q) if q != null else Vector3.INF
	aim.gun = _gun if on else null
	var wp := _wp()
	aim.mode = "body" if bool(wp.get("throwable", false)) else "line"
	aim.grip_left = String(wp.get("hand", "right")) == "left"


## The point she aims at: the middle of the animal's body (its Hit_body), else its chest height over it.
static func chest_of(q: WildAnimal) -> Vector3:
	if q == null or not is_instance_valid(q):
		return Vector3.INF
	var sb := q.get_node_or_null("Hit_body") as Node3D
	if sb != null and _flat(sb.global_position, q.global_position) < 3.0:
		return sb.global_position
	return q.global_position + Vector3.UP * float(q.data.body[2]) * 0.7


## How she aims: crouched when the animal is close (stalk.crouch_aim_m) or a trunk stands just before her on its line (cover:
## she aims from behind it), standing in the open.
func _stance(q: WildAnimal) -> String:
	if q == null:
		return _stance_now
	var d := _flat(body.global_position, q.global_position)
	if d <= float(_scfg().get("crouch_aim_m", 22.0)):
		return "crouch"
	var to := q.global_position - body.global_position
	to.y = 0.0
	var from := body.global_position + Vector3.UP * 0.9
	var ex: Array[RID] = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + to.normalized() * 1.8, 1, ex))
	if not hit.is_empty() and not _is_body(hit.collider):
		return "crouch"
	return "stand"


## The aim clip for the stance (hunt.json weapons' clips: "aim" crouched, "stand_aim" standing).
func _aim_clip() -> String:
	var c := _clip("stand_aim") if _stance_now == "stand" else ""
	return c if c != "" and body.ap and body.ap.has_animation("%s/%s" % [LIB, c]) else _clip("aim")


func _physics_process(_dt: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var on := hunting()
	if on and not body.errand.is_valid():
		body.errand = _cb                   # (a baby errand of the mother's ended: the hunt goes on)
	if not on:
		if _was_hunting:
			_stop()
		return
	if not _was_hunting:
		trail = PackedVector3Array([body.global_position])   # (a new hunt: the way starts here)
		_trail_i = -1
		_trail_goal = Vector3.INF
	_was_hunting = true
	_trail_note()
	if ride.on:
		return                               # (in the saddle: the riding clips are the horse's, HuntRide)
	# her walk as the stalk's crouched walk (over the body's own walk clip)
	var ap := body.ap
	var moving := Vector2(body.velocity.x, body.velocity.z).length() > 0.08
	if haul.pushing and _move_clip == "" and ap and ap.has_animation("%s/%s" % [LIB, PUSH]):
		_move_clip = PUSH                    # (the barrow's handles in both hands)
		_move_ref = 1.1
	if ap and _move_clip != "" and moving:
		var full := "%s/%s" % [LIB, _move_clip]
		if ap.has_animation(full):
			if ap.current_animation != full or not ap.is_playing():
				ap.play(full, 0.25)
			ap.speed_scale = clampf(_speed / _move_ref, 0.4, 1.6)
	if _face_to != Vector3.INF and not moving:
		var to := _face_to - body.global_position
		if Vector2(to.x, to.z).length() > 0.05:
			body.set("_face", atan2(-to.x, -to.z))


## The hunt is over (or taken from her): the carcass let go, the weapon put away, her own clips back.
func _stop() -> void:
	_was_hunting = false
	_drag.let_go()
	if haul.kind != "" or haul.pushing or haul.barrow_out != null or haul.horse_out != null or ride.on:
		var left := haul.abort("the hunt is over")
		if left != null and left.has_meta(&"hunted_by"):
			left.remove_meta(&"hunted_by")
	_show_gun(false)
	_knife(false)
	_gear_on = false
	if body.idle_clip in [KNEEL] or body.idle_clip.contains("-aim-"):
		body.idle_clip = ""
	if body.errand == _cb:
		body.errand = Callable()
	_move_clip = ""
	_ph = ""
	_wolf = null
	if _marked != null and is_instance_valid(_marked):
		_marked.remove_meta(&"hunted_by")
	_marked = null


# ---------------------------------------------------------------- safety
## Wolves and dusk, ahead of the phase: [dir, speed] when they take over this frame, [] when not.
func _safety(dt: float) -> Array:
	var ph := HuntJob.phase(sc)
	if _wolf != null:
		return _defend(dt)
	var why := HuntJob.must_stop(sc)
	if why == "wolves":
		var wolf := ground.nearest_wolf(body.global_position)
		var dw := body.global_position.distance_to(wolf.global_position) if wolf else INF
		if _drag.load != null and dw < float(_dcfg().get("let_go_m", 30.0)):
			_drag.let_go()
			sc._note("%s lets go of the %s: wolves." % [sc.name, String(sc.hunt.get("species", "carcass"))])
		if haul.kind != "" and haul.carcass != null and dw < float(_dcfg().get("let_go_m", 30.0)):
			haul.let_go_load("wolves")          # (the horse, the cart, the barrow come home with her)
			sc._note("%s leaves the %s where it is: wolves." % [sc.name, String(sc.hunt.get("species", "carcass"))])
		if wolf and dw < float(_dcfg().get("defend_m", 18.0)) and _reload_t <= 0.0 and not ride.on \
				and HuntJob.kit_shots(sc, HuntJob.weapon_cfg(String(sc.hunt.weapon))) > 0:
			_wolf = wolf
			_wolf_t = 0.0
			return _defend(dt)
		if ph != "retreat" and ph != "haul" and not (ph == "transport" and (haul.carcass != null or sc.hunt.has("end_after"))):
			HuntJob.go_home(sc, HuntJob.line("wolves") % sc.name, true)
	elif why == "dusk" and ph in ["stalk", "aim", "after", "follow", "to_carcass", "back"]:
		HuntJob.go_home(sc, HuntJob.line("dusk") % [sc.name, ""])
	return []


func _dcfg() -> Dictionary:
	return HuntJob.cfg().get("danger", {})


## A wolf closing: she stops, turns to it, and fires when the aim is done.
func _defend(dt: float) -> Array:
	if _wolf == null or not is_instance_valid(_wolf) or _wolf.is_dead():
		_wolf = null
		return []
	_wolf_t += dt
	_show_gun(true)
	_face_to = _wolf.global_position
	_stance_now = "stand"
	body.idle_clip = _aim_clip()
	if _wolf_t >= 1.0:
		var d := body.global_position.distance_to(_wolf.global_position)
		var res := HuntJob.fire(sc, d, HuntJob.animal_state(_wolf), rng)
		if bool(res.get("ok", false)):
			_shoot(_wolf, res)
			sc._note("%s fires at a wolf%s." % [sc.name, " and drops it" if _wolf.is_dead() else ""])
			HuntJob.settle(sc, rng, "miss")         # (no time to look for an arrow with wolves about)
		_wolf = null
		HuntJob.go_home(sc, HuntJob.line("wolves") % sc.name, true)
	return [Vector3.ZERO, 0.0]


# ---------------------------------------------------------------- the phases
func _step(ph: String, dt: float) -> Array:
	match ph:
		"stalk":
			return _stalk(dt)
		"aim":
			return _aim(dt)
		"after":
			return _after()
		"follow":
			return _follow()
		"to_carcass":
			return _to_carcass()
		"dress", "dress_home":
			return _dressing(ph)
		"haul":
			return _haul()
		"transport":
			return _transport(dt)
		"back":
			return _back_to_cache()
		"carry", "home", "retreat":
			return _homeward(ph)
	return [Vector3.ZERO, 0.0]


func _quarry() -> WildAnimal:
	var q: Variant = sc.hunt.get("quarry")
	# (freed first: `is` on a freed instance is an error, the quarry freed under her when it was taken off the ground)
	if q == null or not is_instance_valid(q):
		return null
	return q as WildAnimal if q is WildAnimal and not (q as Node).is_queued_for_deletion() else null


func _scfg() -> Dictionary:
	return HuntJob.cfg().get("stalk", {})


func _wp() -> Dictionary:
	return HuntJob.weapon_cfg(String(sc.hunt.get("weapon", "")))


func _clip(which: String) -> String:
	return String((_wp().get("clips", {}) as Dictionary).get(which, ""))


func _stalk(dt: float) -> Array:
	var q := _quarry()
	if q == null or q.is_dead():
		_approach = Vector3.INF
		HuntJob.track_again(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	q.set_meta(&"hunted_by", sc.worker_id)
	_marked = q
	if q.state == WildAnimal.State.FLEE:
		sc._note(HuntJob.line("spooked") % [String(sc.hunt.species), sc.name])
		_approach = Vector3.INF
		HuntJob.track_again(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	if _t > float(_scfg().get("give_up_s", 150.0)):
		_approach = Vector3.INF
		HuntJob.track_again(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	var me := body.global_position
	var d := _flat(me, q.global_position)
	var shot_d := HuntJob.shot_distance(sc)
	if _approach == Vector3.INF:
		_approach = _approach_point(q, shot_d)
	var mount := _horse_first(q, d, shot_d)
	if not mount.is_empty():
		return mount
	var fetch := _barrow_first(d, shot_d)
	if not fetch.is_empty():
		return fetch
	if d <= shot_d and _clear(q) and _flat(me, sc.hunt.get("blocked_at", Vector3.INF)) > 2.5:
		_approach = Vector3.INF
		HuntJob.set_phase(sc, "aim", "Taking aim at a %s" % String(sc.hunt.species))
		return [Vector3.ZERO, 0.0]
	# (upright and at a walk until she is within her shot and a margin: a crouched stalk from further off never closes on a
	# herd on the move)
	var crouched := d <= minf(float(_scfg().get("walk_until_m", 90.0)), shot_d + float(_scfg().get("crouch_margin_m", 20.0)))
	if crouched and haul.pushing_out():
		haul.leave_barrow()                  # (left here: she comes back for it with the kill)
	_show_gun(crouched)
	body.idle_clip = _clip("aim") if crouched else ""
	_face_to = q.global_position
	# alert: she keeps still until it settles
	if crouched and q.awareness >= float(_scfg().get("freeze_alert", 0.3)):
		_notice(dt, false)
		return [Vector3.ZERO, 0.0]
	# (to the approach point on the downwind side, then straight in; closer when the line is blocked)
	var goal := _approach if _flat(me, _approach) > 3.0 and d > shot_d * 0.7 else q.global_position
	_notice(dt, true, not crouched)
	if crouched:
		_move_clip = _clip("stalk")
		_move_ref = float(_scfg().get("crouch_ref", 0.9))
		return _walk(goal, float(_scfg().get("speed", 0.55)), 0.3)
	return _walk(goal, Spouse.WALK_SPEED, 0.3)


## RIDING (user 2026-09-29: "if the horse is available they should ride the horse for the hunt"; "the hunter should bring the
## horse if available or ride"; "park it far enough out of the animal's sight"): the household's horse free at home and near
## her as her stalk begins, and the quarry far enough off, she takes it: rides it (a grown worker: HuntRide) toward the quarry
## until she is HuntRide.park_distance off it (out of its sight of a rider, and of the sound of the horse), or leads it (the
## young) to where her crouched stalk begins; there it is left standing (HuntHaul.park_horse: the horse keeps who left it,
## where, when and why) and she goes on on foot. [] when she goes on with the stalk on foot this frame.
func _horse_first(q: WildAnimal, d: float, shot_d: float) -> Array:
	var plan := String(sc.hunt.get("horse_plan", ""))
	var walk_until := minf(float(_scfg().get("walk_until_m", 90.0)), shot_d + float(_scfg().get("crouch_margin_m", 20.0)))
	var park := HuntRide.park_distance(q)
	var sp := String(sc.hunt.get("species", "game"))
	if plan == "":
		plan = "no"
		if ride.on:
			plan = "ride"
		elif haul.horse_out != null and is_instance_valid(haul.horse_out):
			plan = "parked"
		else:
			var rc: Dictionary = HuntHaul.tcfg().get("ride", {})
			var rides := HuntRide.can_ride(sc)
			var far := d > (park + float(rc.get("ride_min_m", 40.0)) if rides else walk_until + 25.0)
			var h: Horse = haul.available().get("horse")
			if far and h != null and _flat(h.global_position, body.global_position) <= float(HuntHaul.tcfg().get("near_home_m", 70.0)) \
					and haul.take_horse_out(h):
				plan = "fetch_ride" if rides else "fetch_lead"
				sc._note(("%s rides out after the %s." if rides else "%s takes the horse along for the %s.") % [sc.name, sp])
		sc.hunt["horse_plan"] = plan
	match plan:
		"fetch_ride", "fetch_lead":
			var h := haul.horse_out
			if h == null or not is_instance_valid(h) or haul.why_not_horse(h) != "":
				sc.hunt["horse_plan"] = "no"
				return []
			_t = 0.0                             # (the stalk's clock waits while she saddles up)
			sc.task_text = "Fetching the horse"
			if plan == "fetch_ride":
				if _mount_from == Vector3.INF:
					_mount_from = body.global_position
				var at := HuntRide.mount_point(h, _mount_from)
				if HuntRide.at_saddle(h, body.global_position):
					_mount_from = Vector3.INF
					sc.hunt["horse_plan"] = "ride" if ride.mount(h) else "no"
					return [Vector3.ZERO, 0.0]
				return _walk(at, Spouse.WALK_SPEED, 0.5)
			var hf := -h.global_basis.z
			hf.y = 0.0
			var head := h.global_position + hf.normalized() * 1.7
			if _flat(body.global_position, head) <= 0.9:
				var l := h.get_node_or_null("Lead") as HorseLead
				if l == null:
					sc.hunt["horse_plan"] = "no"
					return []
				l.start(body)
				sc.hunt["horse_plan"] = "lead"
				return [Vector3.ZERO, 0.0]
			return _walk(head, Spouse.WALK_SPEED, 0.8)
		"ride":
			if not ride.on:
				sc.hunt["horse_plan"] = "parked" if haul.horse_out != null else "no"
				return []
			_t = 0.0
			_face_to = Vector3.INF
			if d <= park:
				# (reined in, then down: the horse stands here)
				sc.task_text = "Leaving the horse"
				if absf(ride.horse.speed) < 0.35:
					ride.dismount(_approach if _approach != Vector3.INF else q.global_position)
					haul.park_horse("the %s" % sp)
					sc.hunt["horse_plan"] = "parked"
					sc._note("%s leaves the horse %d m off the %s and goes on on foot." % [sc.name, roundi(d), sp])
				return [Vector3.ZERO, 0.0]
			sc.task_text = "Riding out after a %s" % sp
			ride.to(_approach if _approach != Vector3.INF else q.global_position, 1.0, HuntRide.TROT)
			return [Vector3.ZERO, 0.0]
		"lead":
			if d <= walk_until:
				haul.park_horse("the %s" % sp)
				sc.hunt["horse_plan"] = "parked"
				sc._note("%s leaves the horse standing and goes on crouched." % sc.name)
				return []
			if haul._horse_lag() > HuntHaul.HORSE_WAIT_M:
				_t = 0.0
				return [Vector3.ZERO, 0.0]       # (she waits for the horse to come up)
	return []


## A smart hunter takes the wheelbarrow out with her as her stalk begins (HuntHaul.plans_barrow; free and near her): she
## walks to it and pushes it along while she walks upright, and leaves it where she crouches. [] when she goes on with the
## stalk this frame.
func _barrow_first(d: float, shot_d: float) -> Array:
	var plan := String(sc.hunt.get("barrow_plan", ""))
	if plan == "":
		plan = "no"
		var near := float(HuntHaul.tcfg().get("near_home_m", 70.0))
		var walk_until := minf(float(_scfg().get("walk_until_m", 90.0)), shot_d + float(_scfg().get("crouch_margin_m", 20.0)))
		if d > walk_until + 25.0 and HuntHaul.plans_barrow(HuntHaul.smart(sc)):
			var b: Wheelbarrow = haul.available().get("barrow")
			if b != null and _flat(b.global_position, body.global_position) <= near and haul.take_barrow_out(b):
				plan = "fetch"
				sc._note("%s takes the wheelbarrow along for the %s." % [sc.name, String(sc.hunt.get("species", "game"))])
		sc.hunt["barrow_plan"] = plan
	if plan != "fetch":
		return []
	var b := haul.barrow_out
	if b == null or not is_instance_valid(b):
		sc.hunt["barrow_plan"] = "no"
		return []
	_t = 0.0                                 # (the stalk's clock waits while she fetches it)
	sc.task_text = "Fetching the wheelbarrow"
	if _flat(body.global_position, b.grips_point()) <= 1.2:
		sc.hunt["barrow_plan"] = "push" if haul.take_handles() else "no"
		return [Vector3.ZERO, 0.0]
	return _walk(b.grips_point(), Spouse.WALK_SPEED, 1.0)


## Where she comes in from: `shot_d` off the quarry on the downwind side (the wind carries her scent away from it) when she
## reads the wind (her Hunting), else straight from where she is.
func _approach_point(q: WildAnimal, shot_d: float) -> Vector3:
	var sp := ground.spawner()
	var wind := sp.wind if sp else Vector2.ZERO
	var from := body.global_position - q.global_position
	from.y = 0.0
	var dir := from.normalized() if from.length() > 0.1 else Vector3.FORWARD
	if wind.length_squared() > 1e-4 and rng.randf() < 0.3 + SurvivalSkills.level(sc.core, "hunting") / 100.0:
		var down := Vector3(wind.x, 0.0, wind.y).normalized()
		# (not round the far side of it: the downwind side nearest her)
		dir = (down + dir * 0.35).normalized()
	var p := q.global_position + dir * shot_d * 0.95
	p.y = FrontierTerrain.height_at(p.x, p.z)
	return p


func _aim(dt: float) -> Array:
	var q := _quarry()
	if q == null or q.is_dead():
		HuntJob.set_phase(sc, "after")
		return [Vector3.ZERO, 0.0]
	if _t <= dt * 1.5:
		_stance_now = _stance(q)
	_show_gun(true)
	body.idle_clip = _aim_clip()
	_face_to = q.global_position
	_notice(dt, false)
	var st := HuntJob.animal_state(q)
	if st == "running" and not q.lame():
		sc._note(HuntJob.line("spooked") % [String(sc.hunt.species), sc.name])
		HuntJob.track_again(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	var d := _flat(body.global_position, q.global_position)
	if d > float(_wp().get("max_m", 100.0)):
		HuntJob.set_phase(sc, "stalk")
		return [Vector3.ZERO, 0.0]
	if _t < float(_wp().get("aim_s", 2.5)) or _reload_t > 0.0:
		return [Vector3.ZERO, 0.0]
	# (a walking animal, or a poor chance of a clean kill: she holds her fire a while for it to stand)
	var odds := HuntJob.shot_odds(HuntJob.shot_skill(sc, _wp()), d, _wp(), st)
	if (st == "moving" or float(odds.clean) < float(_scfg().get("min_clean", 0.2))) \
			and _t < float(_wp().get("aim_s", 2.5)) + float(_scfg().get("hold_fire_s", 8.0)):
		return [Vector3.ZERO, 0.0]
	# (a trunk on the line from the muzzle: she holds her fire for the animal to step clear, then moves for a clear line)
	if not _clear(q, _muzzle()):
		if _t < float(_wp().get("aim_s", 2.5)) + float(_scfg().get("hold_fire_s", 8.0)) * 0.5:
			return [Vector3.ZERO, 0.0]
		sc.hunt["blocked_at"] = body.global_position   # (not from here again: she moves on for a clear line)
		HuntJob.set_phase(sc, "stalk", "Stalking a %s" % String(sc.hunt.species))
		return [Vector3.ZERO, 0.0]
	var res := HuntJob.fire(sc, d, st, rng)
	if not bool(res.get("ok", false)):
		HuntJob.go_home(sc, HuntJob.line("out_of_shot") % sc.name)
		return [Vector3.ZERO, 0.0]
	var was_unaware := st == "unaware"
	_shoot(q, res)
	var sp := String(sc.hunt.species)
	if q.is_dead():
		sc._note(HuntJob.line("shot_kill") % [sc.name, sp, roundi(d)])
		HuntJob.killed(sc)
		if was_unaware:
			HuntJob.clean_kill(sc)
		HuntJob.settle(sc, rng, "kill")        # (an arrow or spear in the kill is found again; a lost one is spent)
	elif bool(_last_shot.get("hit_quarry", false)):
		sc._note(HuntJob.line("shot_hit") % [sc.name, sp, roundi(d)])
		HuntJob.settle(sc, rng, "wounded")
	else:
		sc._note(HuntJob.line("shot_miss") % [sc.name, sp, roundi(d)])
		HuntJob.settle(sc, rng, "miss")
	HuntJob.set_phase(sc, "after", "Reloading")
	return [Vector3.ZERO, 0.0]


func _after() -> Array:
	var q := _quarry()
	_face_to = q.global_position if q else Vector3.INF
	body.idle_clip = _aim_clip()
	if q != null and q.is_dead():
		if _t < 1.5:
			return [Vector3.ZERO, 0.0]
		_show_gun(false)
		HuntJob.set_phase(sc, "to_carcass", "Going to the %s" % String(sc.hunt.species))
		return [Vector3.ZERO, 0.0]
	if _t < float((HuntJob.cfg().get("after", {}) as Dictionary).get("wait_s", 6.0)):
		return [Vector3.ZERO, 0.0]
	if q != null and bool(_last_shot.get("hit_quarry", false)):
		HuntJob.set_phase(sc, "follow", "Following the wounded %s" % String(sc.hunt.species))
		return [Vector3.ZERO, 0.0]
	HuntJob.track_again(sc, HuntJob.line("nothing") % sc.name)
	return [Vector3.ZERO, 0.0]


## A wounded animal: she follows it; lying up or standing within her shot distance, she shoots again; lost, she reads sign.
func _follow() -> Array:
	var q := _quarry()
	var ac: Dictionary = HuntJob.cfg().get("after", {})
	if q != null and q.is_dead():
		HuntJob.set_phase(sc, "to_carcass", "Going to the %s" % String(sc.hunt.species))
		return [Vector3.ZERO, 0.0]
	var sp := String(sc.hunt.get("species", "game"))
	if q == null or _t > float(ac.get("follow_s", 100.0)) or _flat(body.global_position, q.global_position) > float(ac.get("lost_m", 160.0)):
		sc._note(HuntJob.line("lost") % [sc.name, sp])
		HuntJob.track_again(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	var d := _flat(body.global_position, q.global_position)
	var still := HuntJob.animal_state(q) != "running"
	if still and d <= HuntJob.shot_distance(sc) and _reload_t <= 0.0 and _clear(q) \
			and int(sc.hunt.get("shots", 0)) < int(HuntJob.cfg().get("max_shots", 3)):
		HuntJob.set_phase(sc, "aim", "Taking aim at the wounded %s" % sp)
		return [Vector3.ZERO, 0.0]
	_show_gun(true)
	_face_to = q.global_position
	if d < 8.0:
		return [Vector3.ZERO, 0.0]
	return _walk(q.global_position, Spouse.WALK_SPEED, 6.0)


## To the kill; there, how it comes home (HuntHaul.choose: her smarts, its weight, how far home is, what transport is free):
## the horse, the cart or the wheelbarrow fetched (phase "transport"), dragged by hand ("haul"), or dressed where it lies and
## carried home, a quarter a trip for a big one ("dress", "carry", "back").
func _to_carcass() -> Array:
	var q := _quarry()
	if q == null or q.meat_left <= 0.02:
		HuntJob.go_home(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	var d := _flat(body.global_position, q.global_position)
	if d > AT_CARCASS:
		return _walk(q.global_position, Spouse.WALK_SPEED, AT_CARCASS * 0.8)
	_face_to = q.global_position
	var sp := String(sc.hunt.species)
	var kg := HuntHaul.kg_of(sp, q)
	var dist := _flat(q.global_position, body.hearth)
	var av := haul.available() if not bool(sc.hunt.get("no_transport", false)) else {}
	for k: String in sc.hunt.get("failed_ways", []):
		av.erase(k)                          # (a way that failed her this hunt is not tried again)
		if k == "horse":
			av.erase("cart")
			av.erase("horse_out")
		if k == "barrow":
			av.erase("barrow_out")
	var smart := HuntHaul.smart(sc)
	var how := HuntHaul.choose(smart, kg, dist, HuntHaul.flags(av))
	sc.hunt["how"] = how
	print_verbose("hunt: %s %.0f kg %.0f m from home, smart %.2f, free %s: %s" % [sp, kg, dist, smart, HuntHaul.flags(av), how])
	if how in ["horse", "cart", "barrow"] and haul.begin(how, q, av):
		sc.hunt["transport"] = how
		HuntJob.set_phase(sc, "transport")
		return [Vector3.ZERO, 0.0]
	if how in ["horse", "cart", "barrow"]:
		how = HuntHaul.choose(0.0, kg, dist, {})
	if how in ["dress", "quarter"] and not HuntKit.has_knife(sc) and kg <= float(HuntHaul.tcfg().get("drag_max_kg", 90.0)) * 1.5:
		how = "drag"                          # (no knife to dress it: dragged home whatever the distance)
	if how == "drag" and _drag.start(q):
		_drop = Vector3.INF
		HuntJob.set_phase(sc, "haul", "Hauling the %s home" % sp)
		return [Vector3.ZERO, 0.0]
	sc.hunt["trips"] = HuntHaul.dress_trips(kg) if how == "quarter" else 1
	sc.hunt["trips_all"] = int(sc.hunt.trips)
	_start_dress("dress")
	return [Vector3.ZERO, 0.0]


## The trip with the household's transport (HuntHaul.step); the carcass home, it is left for the butcher (or dressed); a trip
## that cannot go on leaves the carcass where it is (near home: for the butcher; else she goes back to it and drags or dresses
## it); a return trip for the barrow she took out ends the hunt with the words kept for it.
func _transport(dt: float) -> Array:
	var r := haul.step(dt)
	if r.is_empty() or not (r[0] is String):
		if haul.pushing and haul.barrow and _move_clip == "":
			_face_to = Vector3.INF
		return r
	var how := String(sc.hunt.get("transport", ""))
	sc.hunt.erase("transport")
	if sc.hunt.has("end_after"):
		HuntJob.finish(sc, String(sc.hunt.end_after))
		return [Vector3.ZERO, 0.0]
	var q := _quarry()
	if String(r[0]) == "done":
		return _left_home(q, how)
	sc._note("%s cannot bring the %s home that way (%s)." % [sc.name, String(sc.hunt.get("species", "carcass")), String(r[1])])
	var hc: Dictionary = HuntJob.cfg().get("haul", {})
	if q != null and q.meat_left > 0.02 and _flat(q.global_position, body.hearth) <= float(hc.get("butcher_range_m", 28.0)):
		return _left_home(q)
	sc.hunt["failed_ways"] = (sc.hunt.get("failed_ways", []) as Array) + [how]
	HuntJob.set_phase(sc, "to_carcass", "Going back to the %s" % String(sc.hunt.get("species", "carcass")))
	return [Vector3.ZERO, 0.0]


func _start_dress(ph: String) -> void:
	sc.hunt["until"] = -1.0                  # (the dressing's clock starts when she kneels at it)
	HuntJob.set_phase(sc, ph, "Field-dressing the %s" % String(sc.hunt.get("species", "carcass")) if ph == "dress" \
			else "Dressing the %s at home" % String(sc.hunt.get("species", "carcass")))


## Kneeling at the carcass for the dressing's game minutes; then its yields are hers to carry (or, at home, put by). A big
## kill is carried home in trips (hunt.trips): the rest waits by the carcass (hunt.cache) until she comes back for it.
func _dressing(ph: String) -> Array:
	var q := _quarry()
	_show_gun(false)
	if float(sc.hunt.get("until", 0.0)) < 0.0:
		if q and _flat(body.global_position, q.global_position) > AT_CARCASS + 0.6 and _t < 60.0:
			body.idle_clip = ""
			return _walk(q.global_position, Spouse.WALK_SPEED, AT_CARCASS * 0.8)
		sc.hunt["until"] = sc.core.state.minutes + HuntJob.dress_minutes(sc)
	body.idle_clip = KNEEL
	_knife(true)
	if q:
		_face_to = q.global_position
	if sc.core.state.minutes < float(sc.hunt.get("until", 0.0)):
		return [Vector3.ZERO, 0.0]
	body.idle_clip = ""
	_knife(false)
	var got := HuntJob.dress(sc, q)
	var sp := String(sc.hunt.get("species", "carcass"))
	if ph == "dress_home":
		_end(HuntJob.line("hauled_self") % [sc.name, sp, HuntJob.carry_text(sc)])
		return [Vector3.ZERO, 0.0]
	if got.is_empty():
		HuntJob.go_home(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	if int(sc.hunt.get("trips", 1)) > 1:
		sc.hunt["cache"] = sc.hunt.carry
		sc.hunt["carry"] = []
		sc.hunt["cache_at"] = q.global_position if q else body.global_position
		_load_share()
	HuntJob.set_phase(sc, "carry", "Carrying the meat home")
	return [Vector3.ZERO, 0.0]


## A trip's share of what waits by the carcass into what she carries.
func _load_share() -> void:
	var left := maxi(int(sc.hunt.get("trips", 1)), 1)
	var carry := []
	var rest := []
	for e: Dictionary in sc.hunt.get("cache", []):
		var n := ceili(float(e.count) / float(left))
		carry.append({"kind": String(e.kind), "count": n})
		if int(e.count) - n > 0:
			rest.append({"kind": String(e.kind), "count": int(e.count) - n})
	sc.hunt["carry"] = carry
	sc.hunt["cache"] = rest
	sc.hunt["trips"] = left - 1


## Back out to the carcass for the next quarter.
func _back_to_cache() -> Array:
	var at: Vector3 = sc.hunt.get("cache_at", body.global_position)
	if _flat(body.global_position, at) <= AT_CARCASS + 0.5:
		_load_share()
		HuntJob.set_phase(sc, "carry", "Carrying the meat home (%d of %d)" % [int(sc.hunt.trips_all) - int(sc.hunt.trips), int(sc.hunt.trips_all)])
		return [Vector3.ZERO, 0.0]
	return _walk(at, Spouse.WALK_SPEED, AT_CARCASS, true)


## The carcass on her rope, home to a spot by the hearth; caught for good, left where it is when that is near enough home for
## the butcher, else dressed there.
func _haul() -> Array:
	var hc: Dictionary = HuntJob.cfg().get("haul", {})
	var sp := String(sc.hunt.get("species", "carcass"))
	if _drag.load == null:
		# (let go for the wolves, or gone from under the rope)
		var q := _quarry()
		if q != null and q.meat_left > 0.02 and _flat(q.global_position, body.hearth) <= float(hc.get("butcher_range_m", 28.0)):
			return _left_home(q)
		HuntJob.go_home(sc, HuntJob.line("nothing") % sc.name)
		return [Vector3.ZERO, 0.0]
	if _drop == Vector3.INF:
		_drop = drop_point()
	var d := _flat(body.global_position, _drop)
	var home_d := _flat(body.global_position, body.hearth)
	var stuck := _watch(d, float(hc.get("stuck_s", 7.0)))
	if d <= ARRIVE or home_d <= float(hc.get("drop_ring_m", 5.0)) or (stuck and home_d <= float(hc.get("butcher_range_m", 28.0))):
		var a := _drag.let_go()
		return _left_home(a as WildAnimal if a is WildAnimal else _quarry())
	if stuck:
		_drag.let_go()
		sc._note("%s cannot drag the %s further: she dresses it where it is." % [sc.name, sp])
		sc.hunt["trips"] = 1
		sc.hunt["trips_all"] = 1
		_start_dress("dress")
		return [Vector3.ZERO, 0.0]
	return _walk(_drop, minf(Spouse.WALK_SPEED, _drag.cap()), ARRIVE * 0.7, true)


## Where a kill is left at home: on the ring round the hearth on the side she comes from.
func drop_point() -> Vector3:
	var hc: Dictionary = HuntJob.cfg().get("haul", {})
	var from := body.global_position - body.hearth
	from.y = 0.0
	return body.hearth + (from.normalized() if from.length() > 0.1 else Vector3.BACK) * float(hc.get("drop_ring_m", 5.0))


## The carcass is at home (`how` it came: "" dragged by hand, "horse", "cart", "barrow"): the butcher at home takes it; with
## nobody to butcher it, she dresses it herself.
func _left_home(q: WildAnimal, how := "") -> Array:
	var sp := String(sc.hunt.get("species", "carcass"))
	if q != null:
		q.remove_meta(&"hunted_by")
	var key := String({"horse": "horse", "cart": "cart", "barrow": "barrow"}.get(how, "hauled"))
	if HuntJob.home_butcher(sc) or q == null:
		_end(HuntJob.line(key) % [sc.name, sp])
		return [Vector3.ZERO, 0.0]
	_start_dress("dress_home")
	return [Vector3.ZERO, 0.0]


## The hunt ends with `text`, once the wheelbarrow she took out is back in its place (a trip for it first).
func _end(text := "") -> void:
	if haul.has_out() and haul.kind == "" and haul.begin_stow():
		sc.hunt["end_after"] = text if text != "" else String(sc.hunt.get("end_text", HuntJob.line("nothing") % sc.name))
		HuntJob.set_phase(sc, "transport")
		return
	if haul.barrow_out != null and is_instance_valid(haul.barrow_out) and haul.begin_return():
		sc.hunt["end_after"] = text if text != "" else String(sc.hunt.get("end_text", HuntJob.line("nothing") % sc.name))
		HuntJob.set_phase(sc, "transport")
		return
	HuntJob.finish(sc, text)


## Home (carrying the meat, coming home, hurrying from wolves): to the hearth, and the hunt ends there (a quarter carried,
## she goes back for the next).
func _homeward(ph: String) -> Array:
	_show_gun(ph == "retreat" and _wolf != null)
	body.idle_clip = ""
	var pick := _pick_up_horse(ph == "retreat")
	if not pick.is_empty():
		return pick
	var goal := body.hearth
	var d := _flat(body.global_position, goal)
	var stuck := _watch(d, 8.0)
	if d <= 3.0 or (stuck and d <= 14.0):
		var sp := String(sc.hunt.get("species", "carcass"))
		if ph == "carry" and not (sc.hunt.get("cache", []) as Array).is_empty() and int(sc.hunt.get("trips", 0)) > 0:
			var put := HuntJob.deposit(sc)
			sc.hunt["brought"] = (sc.hunt.get("brought", []) as Array) + [put]
			HuntJob.set_phase(sc, "back", "Going back for more of the %s" % sp)
			return [Vector3.ZERO, 0.0]
		if ph == "carry":
			var all := ", ".join((sc.hunt.get("brought", []) as Array) + [HuntJob.carry_text(sc)])
			if int(sc.hunt.get("trips_all", 1)) > 1:
				_end(HuntJob.line("quartered") % [sc.name, sp, int(sc.hunt.trips_all), all])
			else:
				_end(HuntJob.line("dressed") % [sc.name, sp, HuntJob.carry_text(sc)])
		elif ph == "retreat":
			_end()
		else:
			_end()
		return [Vector3.ZERO, 0.0]
	return _walk(goal, Spouse.RUN_SPEED if ph == "retreat" else Spouse.WALK_SPEED, 2.5, true)


## RIDING (user 2026-09-29: "park the horse ... in locations they remember where they put it, pick it up and go home"): the
## horse she left standing on the way out is picked up on her way home: to it (the horse keeps where she left it: meta
## left_by), up into the saddle (the young take its lead), and home on it; at home the trip that puts it back (_end,
## HuntHaul.begin_stow) has her ride it to its place. [] when she has no horse out to pick up.
func _pick_up_horse(hurry: bool) -> Array:
	var h := haul.horse_out
	if h == null or not is_instance_valid(h) or ride.on or haul.kind != "":
		return []
	var l := h.get_node_or_null("Lead") as HorseLead
	if l != null and l.leading and l.leader == body:
		return []                                   # (on her lead already)
	if haul.why_not_horse(h) != "":
		return []
	sc.task_text = "Going back to the horse"
	var speed := Spouse.RUN_SPEED if hurry else Spouse.WALK_SPEED
	if HuntRide.can_ride(sc):
		if _mount_from == Vector3.INF:
			_mount_from = body.global_position
		var at := HuntRide.mount_point(h, _mount_from)
		if HuntRide.at_saddle(h, body.global_position):
			_mount_from = Vector3.INF
			ride.mount(h)
			return [Vector3.ZERO, 0.0]
		return _walk(at, speed, 0.5, true)
	var hf := -h.global_basis.z
	hf.y = 0.0
	var head := h.global_position + hf.normalized() * 1.7
	if _flat(body.global_position, head) <= 0.9:
		if l != null:
			l.start(body)
		return [Vector3.ZERO, 0.0]
	return _walk(head, speed, 0.8, true)


# ---------------------------------------------------------------- the shot
## The shot `res` (HuntJob.fire) made real at animal `q`: a ray from the muzzle to a point in it (the heart or lungs for a
## vital hit, the gut or haunch for a hit, off it for a miss); the first hit zone it meets takes the weapon's damage through
## Hit.deliver (a trunk or the ground first: the shot is spent there). The smoke, the sound and the report to the wildlife.
func _shoot(q: WildAnimal, res: Dictionary) -> void:
	_last_shot = {"hit_quarry": false, "roll_hit": bool(res.get("hit", false)), "roll_vital": bool(res.get("vital", false)), "odds": res.get("odds", {}), "ray": "none"}
	_reload_t = float(_wp().get("reload_s", 10.0))
	var muzzle := _muzzle()
	var target := _aim_point(q, bool(res.get("hit", false)), bool(res.get("vital", false)))
	var dir := (target - muzzle).normalized()
	var space := body.get_world_3d().direct_space_state
	var ex: Array[RID] = [body.get_rid()]
	var from := muzzle
	var to := muzzle + dir * (muzzle.distance_to(target) + 150.0)
	for _i in 8:
		var qp := PhysicsRayQueryParameters3D.create(from, to, 1 | WildAnimal.HIT_LAYER, ex)
		var hit := space.intersect_ray(qp)
		if hit.is_empty():
			break
		var col: Object = hit.collider
		_last_shot["ray"] = String((col as Node).name) if col is Node else "?"
		# (an animal's walking body: the hit zones inside it decide the wound)
		if col is WildAnimal or (col is Node and (col as Node).get_meta("hit_part", "") == "" and _is_body(col)):
			ex.append(hit.rid)
			continue
		if col is Node and (col as Node).has_meta("hit_part"):
			var owner_a := (col as Node).get_parent()
			# (what struck: a ball, or the bow's arrow; the quarry's body works out its path, Anatomy)
			Hit.deliver(col, float(res.get("damage", 100.0)), hit.position, dir, body, true,
					{"kind": "arrow" if String(_wp().get("id", "")) == "bow" else "ball"})
			_last_shot["hit_quarry"] = owner_a == q
			_last_shot["part"] = String((col as Node).get_meta("hit_part", ""))
			if String(_wp().get("id", "")) == "bow":
				Sfx.play_3d(&"arrow_hit_flesh", hit.position)
		elif String(_wp().get("id", "")) != "bow" and DisplayServer.get_name() != "headless":
			Fx.dust_puff(body.get_tree().current_scene, hit.position, hit.normal)
		break
	_last_shot["wound"] = q.last_wound
	var scene := body.get_tree().current_scene
	if bool(res.get("loud", false)):
		if DisplayServer.get_name() != "headless" and _gun:
			var m := _gun.get_node_or_null("Muzzle") as Node3D
			Fx.muzzle_blast(scene, m.global_transform if m else Transform3D(Basis.looking_at(dir), muzzle), 1.0)
		Sfx.play_3d(StringName(String(_wp().get("sound", "musket_shot"))), muzzle)
	else:
		Sfx.play_3d(StringName(String(_wp().get("sound", "bow_release"))), muzzle)
	var sp := ground.spawner()
	if sp:
		sp.shot(muzzle, WildlifeSpawner.SHOT_LOUD_M if bool(res.get("loud", false)) else WildlifeSpawner.SHOT_QUIET_M)


static func _is_body(col: Object) -> bool:
	var n := col as Node
	while n != null:
		if n is WildAnimal:
			return true
		n = n.get_parent()
	return false


func _muzzle() -> Vector3:
	if _gun and _gun.visible:
		var m := _gun.get_node_or_null("Muzzle") as Node3D
		if m:
			return m.global_position
	return body.global_position + Vector3.UP * 1.05


## The point she puts the shot on: the heart or lungs (vital), else the gut or the haunch (a hit), else a way off the body.
func _aim_point(q: WildAnimal, hit: bool, vital: bool) -> Vector3:
	var sb := q.get_node_or_null("Hit_body") as Node3D
	if sb == null:
		return q.global_position + Vector3.UP * 0.6
	var cs := sb.get_child(0) as CollisionShape3D if sb.get_child_count() > 0 else null
	var cap := cs.shape as CapsuleShape3D if cs else null
	var r := cap.radius if cap else 0.2
	var half := cap.height * 0.5 if cap else 0.5
	var c := sb.global_position
	var axis := sb.global_basis.y.normalized()
	var head := q.get_node_or_null("Hit_head") as Node3D
	if head and (head.global_position - c).dot(axis) < 0.0:
		axis = -axis
	var up := Vector3.UP - axis * Vector3.UP.dot(axis)
	up = up.normalized() if up.length_squared() > 1e-4 else Vector3.UP
	var side := axis.cross(up).normalized()
	if vital:
		var o: Array = WildlifeSpecies.HEART if rng.randf() < 0.5 else WildlifeSpecies.LUNGS
		return c + axis * half * float(o[0]) + up * r * float(o[1]) + side * rng.randf_range(-0.05, 0.05)
	if hit:
		var along := rng.randf_range(-0.8, 0.2) if rng.randf() < 0.7 else rng.randf_range(0.7, 0.95)
		return c + axis * half * along + up * r * rng.randf_range(-0.2, 0.4)
	var off := side * rng.randf_range(-1.0, 1.0) + Vector3.UP * rng.randf_range(0.2, 0.9)
	return c + off.normalized() * rng.randf_range(r + 0.45, r + 1.3)


## A clear line from her eye to the quarry's chest (nothing on the world layer between).
func _clear(q: WildAnimal, from := Vector3.INF) -> bool:
	var eye := from if from != Vector3.INF else body.global_position + Vector3.UP * (1.45 if _stance_now == "stand" else 1.05)
	var at := chest_of(q)
	var ex: Array[RID] = [body.get_rid(), q.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, at, 1, ex))
	return hit.is_empty() or _is_body(hit.collider)


# ---------------------------------------------------------------- being noticed
## The prey near her notice her as they notice the player (WildAnimal._sense_player): in sight (a crouched, still hunter is
## seen closer; her Hunting shortens it: notice_skill), heard (a crouched step), or scented down the wind. It raises their
## awareness: alert at 0.45, bolting at 1, as their own senses would.
func _notice(dt: float, moving: bool, upright := false) -> void:
	var sp := ground.spawner()
	if sp == null:
		return
	var me := body.global_position
	var skill := clampf(SurvivalSkills.level(sc.core, "hunting") / 100.0, 0.0, 1.0)
	var hide := 1.0 - float(_scfg().get("notice_skill", 0.6)) * skill
	var pv := (Spouse.WALK_SPEED if upright else float(_scfg().get("speed", 0.55))) if moving else 0.0
	for a in sp.animals():
		if a.is_dead() or not a.is_prey() or not a.active:
			continue
		var to := me - a.global_position
		to.y = 0.0
		var d := to.length()
		if d > 90.0:
			continue
		var gain := 0.0
		var sight := float(a.data.sight) * a._sight_mult() * (1.0 if upright else 0.55) * (1.0 if moving else 0.65) * hide
		if d < sight:
			var fwd := -a.global_basis.z
			if absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))) < float(a.data.fov) * 0.5:
				gain += (1.0 - d / sight) * (1.2 + 0.35 * pv) * 0.6
		var noise := ((7.0 if upright else 3.5) if moving else 0.0) * float(a.data.hearing)
		if d < noise:
			gain += (1.0 - d / noise) * 1.5 * hide
		if d < float(a.data.scent) and d > 0.01 and sp.wind.length_squared() > 1e-4:
			var k := Vector2(-to.x, -to.z).normalized().dot(sp.wind.normalized())
			if k > 0.8:
				gain += (1.0 - d / float(a.data.scent)) * (k - 0.8) * 5.0 * (0.5 + sp.wind_strength) * hide
		if gain > 0.0:
			a.awareness = minf(a.awareness + gain * dt, 1.3)
			a.threat_pos = me


# ---------------------------------------------------------------- walking
static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## [direction, speed] to `goal`: along her path on the navigation mesh (Spouse.walk_to: NavMover, round trunks and walls,
## through the gate) where there is one; else straight at it (the body steers round what is close ahead), with a sidestep for
## a while when she has made no headway (_watch).
## (HuntHaul walks her through this)
func walk(goal: Vector3, speed: float, arrive := 0.8) -> Array:
	return _walk(goal, speed, arrive, true)   # (the haul's: to the horse or the barrow at home and out again, the kill home)


# ---------------------------------------------------------------- the way she came
## A point on the way she came when she has gone TRAIL_STEP_M from the last (not while she walks it); back within
## TRAIL_LOOP_M of an earlier point, the loop since is cut out.
func _trail_note() -> void:
	if _trail_i >= 0 or trail.is_empty() or (ride.on and not _way.is_empty() and Engine.get_physics_frames() - _way_used_f < 5):
		return
	var p := body.global_position
	if _flat(p, trail[trail.size() - 1]) < TRAIL_STEP_M:
		return
	for i in range(0, trail.size() - 3):
		if _flat(p, trail[i]) < TRAIL_LOOP_M:
			trail.resize(i + 1)
			break
	trail.append(p)
	if trail.size() > TRAIL_MAX:
		var thin := PackedVector3Array()
		for i in trail.size():
			if i % 2 == 0 or i == trail.size() - 1:
				thin.append(trail[i])
		trail = thin


## The stretch of the way she came from the point nearest her to the point nearest `goal`, and the goal (empty when it does
## not serve, as _trail_walk): the way a rider goes by (HuntRide.to). Kept for a second for the same goal.
func _trail_way(goal: Vector3) -> PackedVector3Array:
	var f := Engine.get_physics_frames()
	if _way_goal != Vector3.INF and _flat(_way_goal, goal) < 1.0 and f - _way_f < 60:
		_way_used_f = f
		return _way
	_way_goal = goal
	_way_f = f
	_way_used_f = f
	_way = PackedVector3Array()
	if trail.size() < 3:
		return _way
	var gi := _trail_nearest(goal)
	var bi := _trail_nearest(body.global_position)
	if gi < 0 or _flat(trail[gi], goal) > TRAIL_NEAR_M or _flat(trail[bi], body.global_position) > TRAIL_JOIN_M or absi(gi - bi) <= 1:
		return _way
	var i := bi
	var st := signi(gi - bi)
	while true:
		_way.append(trail[i])
		if i == gi:
			break
		i += st
	_way.append(goal)
	return _way


func _trail_nearest(p: Vector3) -> int:
	var best := -1
	var bd := INF
	for i in trail.size():
		var d := _flat(p, trail[i])
		if d < bd:
			bd = d
			best = i
	return best


func _following_trail(goal: Vector3) -> bool:
	return _trail_i >= 0 and _trail_goal != Vector3.INF and _flat(goal, _trail_goal) < 1.5


## A step along the way she came toward `goal` ([] when it does not serve: the goal off it, she far from it, or the
## goal at hand): from the point nearest her to the point nearest the goal, then the goal. `use`: she may take it now.
func _trail_walk(goal: Vector3, speed: float, use: bool) -> Array:
	if not use or trail.size() < 3:
		_trail_i = -1
		return []
	if not _following_trail(goal):
		var gi := _trail_nearest(goal)
		var bi := _trail_nearest(body.global_position)
		if gi < 0 or _flat(trail[gi], goal) > TRAIL_NEAR_M or _flat(trail[bi], body.global_position) > TRAIL_JOIN_M \
				or absi(gi - bi) <= 1:
			_trail_i = -1
			return []
		_trail_i = bi
		_trail_end = gi
		_trail_goal = goal
		_trail_t = 0.0
		_trail_best = INF
	var dt := get_physics_process_delta_time()
	var p := trail[_trail_i]
	var d := _flat(body.global_position, p)
	if d < _trail_best - 0.3:
		_trail_best = d
		_trail_t = 0.0
	else:
		_trail_t += dt
	if d <= TRAIL_AT_M or _trail_t > TRAIL_SKIP_S:
		if _trail_i == _trail_end:
			# (the trail's end by the goal: the last stretch as any walk; the trail not taken up again for this goal)
			_trail_i = -1
			_prog_t = 0.0
			_no_way_t = 0.0
			return []
		_trail_i += signi(_trail_end - _trail_i)
		_trail_t = 0.0
		_trail_best = INF
		p = trail[_trail_i]
	var r: Array = body.call("walk_to", p, speed, 0.4) if body.has_method("walk_to") else []
	var nav: Variant = body.get("nav")
	if not r.is_empty() and nav != null and bool(nav.get("on_path")):
		return r
	var to := p - body.global_position
	to.y = 0.0
	return [to.normalized() if to.length() > 0.01 else Vector3.ZERO, speed]


func _walk(goal: Vector3, speed: float, arrive := 0.8, by_trail := false) -> Array:
	var dt := get_physics_process_delta_time()
	if ride.on:
		# (in the saddle: the horse is ridden there, at a trot, a canter to hurry, by the way she came when it serves)
		var way := _trail_way(goal) if by_trail or _following_trail(goal) else PackedVector3Array()
		ride.to(goal, maxf(arrive, 1.0), HuntRide.CANTER if speed > Spouse.WALK_SPEED + 0.5 else HuntRide.TROT, way)
		return [Vector3.ZERO, 0.0]
	var to := goal - body.global_position
	to.y = 0.0
	if to.length() <= arrive:
		_trail_i = -1
		return [Vector3.ZERO, 0.0]
	# the way she came: back home, out to the kill and back with it; any walk that has made no headway for a while (not
	# the last TRAIL_NEAR_M to the goal: there she goes straight to it, not along a stretch of the way that passes by)
	var tw := _trail_walk(goal, speed, (by_trail or _no_way_t > TRAIL_STUCK_S or _following_trail(goal)) and to.length() > TRAIL_NEAR_M)
	if not tw.is_empty():
		return tw
	# no headway for a while (a path through something the mesh does not know, a post, a trunk): a sidestep, off the path
	var f := Engine.get_physics_frames()
	if _prog_at.distance_to(body.global_position) > 0.4 or f - _prog_f > 5:
		_prog_at = body.global_position
		_prog_t = 0.0
		_no_way_t = 0.0
	else:
		_prog_t += dt
		_no_way_t += dt   # (not reset by a sidestep: the way she came, after TRAIL_STUCK_S of it)
	_prog_f = f
	if _prog_t > 2.0 and _detour_t <= 0.0:
		var side := to.normalized().cross(Vector3.UP) * (1.0 if rng.randf() < 0.5 else -1.0)
		_detour = (side * 0.85 - to.normalized() * 0.15).normalized()
		_detour_t = 1.8
		_prog_t = 0.0
	if _detour_t > 0.0:
		_detour_t -= dt
		return [(to.normalized() * 0.25 + _detour).normalized(), maxf(speed, 0.8)]
	if body.has_method("walk_to"):
		var r: Array = body.call("walk_to", goal, speed, arrive)
		var nav: Variant = body.get("nav")
		if nav != null and bool(nav.get("on_path")):
			return r
	return [to.normalized(), speed]


## Headway to a goal `d` m off: true when she has not got 0.5 m nearer in `secs` (a sidestep is tried meanwhile).
func _watch(d: float, secs: float) -> bool:
	var dt := get_physics_process_delta_time()
	if d < _best_d - 0.5:
		_best_d = d
		_best_t = 0.0
		return false
	_best_t += dt
	return _best_t > secs


# ---------------------------------------------------------------- the weapon in her hand
## The weapon in her hands (aiming, stalking crouched, firing) or not. With her worn gear (WorkerGear: the household's gun
## slung on her back) it comes off its sling into her hands at the player's grip and goes back after; without (her own
## kit, no pool) a model is laid in her hands from where the aim clip puts them (_process).
func _show_gun(on: bool) -> void:
	var pk := HuntKit.weapon_held(sc)
	var g := WorkerGear.of(body)
	if g != null and pk != "" and pk != "kit" and g.wears(pk):
		if on != _gear_on or (on and (_gun == null or not is_instance_valid(_gun))):
			_gear_on = on
			if on:
				_gun = g.hold(pk, true)
				_own_gun = false
				if _gun and aim:
					_gun.top_level = true        # (HuntAim lays it on the aim line)
			else:
				if _gun and is_instance_valid(_gun) and not _own_gun:
					_gun.top_level = false
					_gun.transform = SlingRig.HAND_OFFSET
				g.hold(pk, false)
				_gun = null
		return
	var kind := model_of(_wp(), pk)
	if on and kind != "" and (_gun == null or not is_instance_valid(_gun) or _gun_kind != kind or not _own_gun):
		_build_gun(kind)
	if _gun and is_instance_valid(_gun):
		_gun.visible = on


## The weapon laid in her hands each frame after the pose: the musket from the right hand's grip (the wrist of the stock) along
## to the left hand under the fore-end, the bow upright in the left hand toward where she looks (the aim clips put the hands; the
## prop bones' own turn differs from the player's rig, so the hold is made from where the hands are).
func _process(_dt: float) -> void:
	_sling_update()
	# (her gear's gun as well as this node's own: the Spouse's aim clips turn the prop bone off the player's hold, which
	# stands the gun on end; the hold is made from where the clip puts her two hands)
	if _gun == null or not (_own_gun or _gear_on) or not is_instance_valid(_gun) or not _gun.visible or body == null or body.sk == null:
		return
	if aim != null and aim.weight > 0.0:
		return                              # (HuntAim lays it)
	var r := _bone("r_hand_prop_attachment")
	var l := _bone("l_hand_prop_attachment")
	var fwd := -body.global_basis.z
	if _face_to != Vector3.INF:
		var f := _face_to - body.global_position
		f.y = 0.0
		if f.length() > 0.1:
			fwd = f.normalized()
	if r == Vector3.INF or l == Vector3.INF:
		return
	if String(_wp().get("hand", "right")) == "left":
		var up := Vector3.UP.lerp(fwd.cross(Vector3.UP), 0.12).normalized()
		_gun.global_transform = Transform3D(Basis.looking_at(fwd, up), l)
		return
	var along := l - r
	var dir := along.normalized() if along.length() > 0.12 and along.normalized().dot(fwd) > 0.2 else fwd
	_gun.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), r)


func _bone(nm: String) -> Vector3:
	var i := body.sk.find_bone(nm)
	return body.sk.global_transform * body.sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.INF


func _build_gun(kind: String) -> void:
	if _gun and _own_gun and is_instance_valid(_gun):
		_gun.queue_free()
	_gun = null
	if body.sk == null:
		return
	_gun = make_model(kind)
	_own_gun = true
	_gun.name = "HuntWeapon"
	_gun.top_level = true
	body.add_child(_gun)
	_gun_kind = kind
	_process(0.0)


## Her knife out of its sheath into her hand while she dresses the kill (WorkerGear), and back.
func _knife(on: bool) -> void:
	if on == _knife_on:
		return
	var g := WorkerGear.of(body)
	if g == null:
		return
	var p := ToolPool.of(sc)
	var k := ""
	if p != null:
		for kn: String in WorkerGear.KNIVES:
			if int(p.held_by(sc).get(kn, 0)) > 0:
				k = kn
				break
	if on and k == "":
		return
	_knife_on = on
	g.hold(k if k != "" else "trade_knife", on)


## The model of weapon `wp` as the pool kind `kind` she has (the over-and-under has its own).
static func model_of(wp: Dictionary, kind: String) -> String:
	if kind == "over_under" and WeaponModels.has_glb("over_under"):
		return "over_under"
	return String(wp.get("model", ""))


static func make_model(kind: String) -> Node3D:
	if kind in ThrowableModels.KINDS:
		return ThrowableModels.build(kind)
	return WeaponModels.build(kind)


## The weapon she carries and is not aiming: slung on her back, muzzle up over her right shoulder (the bow across her back),
## while she hunts, and while she holds one of the household's hunting arms (walking to the rack for it and back with it).
func _sling_want() -> String:
	if body == null or body.sk == null:
		return ""
	var g := WorkerGear.of(body)
	if g != null and g.rig != null:
		return ""                           # (her worn gear shows it: WorkerGear)
	if hunting():
		return model_of(_wp(), HuntKit.weapon_held(sc))
	var p := ToolPool.of(sc)
	if p == null:
		return ""
	var h := p.held_by(sc)
	for wp: Dictionary in HuntJob.weapons():
		for k: String in wp.get("pool", []):
			if int(h.get(ToolPool.resolve(k), 0)) > 0:
				return model_of(wp, ToolPool.resolve(k))
	return ""


func _sling_update() -> void:
	var want := _sling_want()
	if want != _sling_kind:
		if _sling != null and is_instance_valid(_sling):
			_sling.queue_free()
		_sling = null
		_sling_kind = want
		if want != "":
			_sling = make_model(want)
			_sling.name = "HuntSling"
			_sling.top_level = true
			body.add_child(_sling)
	if _sling == null:
		return
	_sling.visible = not (_gun != null and is_instance_valid(_gun) and _gun.visible)
	if not _sling.visible:
		return
	# (her frame from her collarbones: the right one to the left one across, her back behind them)
	var rc := _bone("r_clavicle")
	var lc := _bone("l_clavicle")
	var right := -body.global_basis.x
	var c := body.global_position + Vector3.UP * 1.4
	if rc != Vector3.INF and lc != Vector3.INF:
		var across := rc - lc
		across.y = 0.0
		if across.length() > 0.05:
			right = across.normalized()
		c = (rc + lc) * 0.5
	right.y = 0.0
	right = right.normalized()
	var back := right.cross(Vector3.UP).normalized()
	if want == "bow":
		_sling.global_transform = Transform3D(Basis.looking_at(right, (Vector3.UP - right * 0.6).normalized()), c + back * 0.2 - Vector3.UP * 0.2)
		return
	var dir := (Vector3.UP * 0.85 + right * 0.4).normalized()
	var at := c + back * 0.18 - Vector3.UP * (0.25 if want in ThrowableModels.KINDS else 0.55) - right * 0.12
	_sling.global_transform = Transform3D(Basis.looking_at(dir, back), at)


# ---------------------------------------------------------------- the ground
## The "game" site (SpouseCore.finders): the wildlife round the hunter's body.
class Ground extends RefCounted:
	var run: HuntRun

	func spawner() -> WildlifeSpawner:
		return WildlifeSpawner.find(run.get_tree()) if run and run.is_inside_tree() else null

	func pos() -> Vector3:
		return run.body.global_position

	## The live animal of the quarry species (`weights`: species -> how much she wants it) nearest her for its weight within
	## `radius` m, not running, and not another hunter's; null none.
	func pick_quarry(radius: float, weights: Dictionary) -> Object:
		var sp := spawner()
		if sp == null:
			return null
		var me := pos()
		var best: WildAnimal = null
		var bs := INF
		for a in sp.animals():
			if a.is_dead() or not weights.has(a.species) or a.state == WildAnimal.State.FLEE:
				continue
			var by: Variant = a.get_meta(&"hunted_by", -1)
			if int(by) >= 0 and int(by) != run.sc.worker_id:
				continue
			var d := HuntRun._flat(me, a.global_position)
			if d > radius:
				continue
			var s := d / maxf(float(weights[a.species]), 0.01)
			if s < bs:
				bs = s
				best = a
		return best

	func nearest_wolf(at: Vector3) -> WildAnimal:
		var sp := spawner()
		if sp == null:
			return null
		var best: WildAnimal = null
		var bd := INF
		for w in sp.wolves_now():
			if w.is_dead():
				continue
			var d := at.distance_to(w.global_position)
			if d < bd:
				bd = d
				best = w
		return best

	## Wolves within danger.wolf_m of her.
	func danger() -> bool:
		var w := nearest_wolf(pos())
		return w != null and w.global_position.distance_to(pos()) < float((HuntJob.cfg().get("danger", {}) as Dictionary).get("wolf_m", 55.0))
