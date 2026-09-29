class_name HorseBreaking
extends Node
## Catching and breaking a wild horse (user 2026-09-28: "a herd of wild horses that can be tamed, we use g to grip and
## i dunno how to tame or a good system?"). One on a Horse while it is being ridden out.
##
##   catch    G beside a wild horse (WildHorse, try_grab: from PlayerGrip on foot, from the saddle riding alongside it)
##            takes a fistful of mane and swings up bareback: the wild one leaves its band (which bolts) as a Horse and
##            the player is seated on it (FrontierPlayer.mount; from the saddle, off his own horse onto it). Not before
##            its nose (it wheels away), nor behind it unless it is winded or dozing (it kicks: WildHorse.grabbed). Run
##            down first (WildAnimal.winded), it is caught more easily and bucks less.
##   ride     it bucks, crow-hops, rears, spins and bolts (MOVES), each throwing the rider one way: his balance, a dot in
##            a ring by the crosshair (BreakingHud; the throw to come shown on the ring's edge), is pushed off centre.
##            The move keys shift his weight and move the dot back (W forward, S back, A / D to the sides: against the
##            throw; a buck throws him forward, S; a rear back, W; a spin outward, lean into it). Out of the ring he is
##            thrown. Holding on spends the grip's stamina (PlayerGrip.stamina, its ring: more the further off balance
##            he is); spent, he is thrown. G lets go (off on his feet), as does getting off (hold E).
##   spirit   each move ridden out takes some of its spirit (SPIRIT_MOVE, more the better he sat it), and a little every
##            second (SPIRIT_S); it starts at its species' "tame" spirit, less the more winded, hurt and already gentled
##            it is (start_spirit). None left: broken.
##   broken   it stands, head low, and is the player's: a Horse with its HorseMount (ride it, lead it, haul with it),
##            the bridle and bit on it for the reins, no saddle; kept in the save (SaveParts.save_horse "tamed").
##   thrown   (or let go) it is wild again, back in the wildlife as it was (in its band when that is near), bolting,
##            its gentling kept (WildHorse.gentled). Thrown, the rider lands hard (knocked down, THROWN_DAMAGE).
## The bucks tip the horse's body about its fore or hind hooves (its Visual node: the rider on the saddle goes with it)
## with a hop, the rider leaning with it (HorseTerrain.body_pitch_deg: HorseRiderLink's incline); the rear is the Horse's
## own (its clip and the rider's); the spins and the bolt go through Horse.drive. The view jolts on each (CameraShake).

## The moves: how long (s), how hard and which way they throw the rider at their height (push: x to his right, y
## forward), the body's pitch (deg, + nose up) and hop (m), and how often each is picked (w).
const MOVES := {
	"buck": {"s": 0.8, "push": Vector2(0.0, 1.0), "pitch": -30.0, "hop": 0.22, "w": 3.0},
	"crow": {"s": 1.6, "push": Vector2(0.0, 0.6), "pitch": -12.0, "hop": 0.3, "w": 2.0},
	"rear": {"s": 3.0, "push": Vector2(0.0, -1.0), "w": 1.3},
	"spin_l": {"s": 1.7, "push": Vector2(1.0, 0.0), "spin": 3.4, "hop": 0.1, "w": 1.4},
	"spin_r": {"s": 1.7, "push": Vector2(-1.0, 0.0), "spin": -3.4, "hop": 0.1, "w": 1.4},
	"bolt": {"s": 3.2, "push": Vector2(0.0, -0.8), "w": 1.0},
}
## The balance: how fast a throw at its height moves it (per s), how fast the rider's weight moves it back, how fast he
## settles to the middle of his own accord, and his wobble (all in rings: 1 is out).
const PUSH := 2.4
const LEAN := 2.2
const SETTLE := 1.0
const WOBBLE := 0.35
## Stamina a second (PlayerGrip's, of its 100): holding on, more off balance (x the balance squared), more in a throw.
const HOLD_DRAIN := 2.2
const OFF_DRAIN := 7.0
const THROW_DRAIN := 2.0
## A catch needs this much stamina.
const START_STAMINA := 25.0
## Spirit taken: every second of it, and for each move ridden out (the base, and more the better it was sat: x 1 less
## the furthest off balance it put him).
const SPIRIT_S := 0.8
const SPIRIT_MOVE := Vector2(4.0, 6.0)
## The least spirit a catch starts with; how much less a winded horse has (x its winded()), a hurt one (at no health
## left, x its health's share), and one ridden before (1 - gentled).
const MIN_SPIRIT := 10.0
const WINDED_OFF := 0.55
const HURT_OFF := 0.4
## Rests between moves (s): with all its spirit and with none; how much of the spirit taken it keeps once it throws
## its rider (WildHorse.gentled).
const GAP := Vector2(0.45, 1.0)
const GENTLED_KEEP := 0.6
## Thrown: away at this speed (m/s) and up, and the fall's damage.
const THROW_V := 5.5
const THROW_UP := 3.2
const THROWN_DAMAGE := 8.0
## Wild again, it only runs this long (s): no strike at the rider it threw (WildAnimal._cornered_attack).
const LEAVE_S := 10.0
## The hooves the body tips about (the Horse's own frame: -Z forward; the fore hooves' and the hind's, horse.glb).
const FORE_Z := -0.61
const HIND_Z := 0.5

var horse: Horse
var player: FrontierPlayer
var spawner: WildlifeSpawner
## The wild one it was: its species, band and state (health, hunger, fatigue, coat, gentled) for its going back.
var species := "horse"
var group: WildGroup
var was := {}
var spirit := 70.0
var spirit_max := 70.0
## The rider's balance (x right, y forward; 1 out of the ring) and the throw on it now.
var balance := Vector2.ZERO
var push := Vector2.ZERO
## The move now ("" resting between moves), how long into it, and the furthest off balance it has put him.
var move := ""
var move_t := 0.0
var moves_ridden := 0
## How it ended: "", "broken", "thrown", "let_go".
var outcome := ""

var _len := 1.0
## The move before (never the same one twice running).
var _last := ""
var _gap := 1.0
var _peak := 0.0
var _t_in := 0.0
var _reared := false
var _bolt_steer := 0.0
var _seed := 0.0
var _pitch := 0.0
var _hop := 0.0
var _own_stamina := 100.0
var _rng := RandomNumberGenerator.new()
var _hud: BreakingHud


# --- The catch -----------------------------------------------------------------------------------

## G near a wild horse (PlayerGrip on foot; FrontierPlayer._ride from the saddle): the nearest within reach
## (WildHorse.GRAB_FOOT, GRAB_SADDLE) takes it (WildHorse.grabbed). True when the G was taken.
static func try_grab(p: FrontierPlayer) -> bool:
	if p == null or p.is_dead:
		return false
	if p.riding != null and p.riding.get_node_or_null(^"Breaking") != null:
		return false
	var sp := WildlifeSpawner.find(p.get_tree())
	if sp == null:
		return false
	var reach := WildHorse.GRAB_SADDLE if p.riding != null else WildHorse.GRAB_FOOT
	var best: WildHorse = null
	var bd := reach
	for a in sp.animals():
		var h := a as WildHorse
		if h == null or h.is_dead():
			continue
		var d := h.grab_distance(p.global_position)
		if d < bd:
			bd = d
			best = h
	if best == null:
		return false
	if p.riding != null:
		# alongside it: the two going together, not one passing the other
		var own := -p.riding.global_basis.z * p.riding.speed
		if Vector2(own.x - best.velocity.x, own.z - best.velocity.z).length() > 6.0:
			WildHorse._say(p, "Too fast past it: ride alongside")
			return true
	return best.grabbed(p)


## The catch of wild horse `w` by `p` (WildHorse.grabbed): it becomes a Horse under him, to be ridden out. True: the G
## was taken.
static func begin(w: WildHorse, p: FrontierPlayer) -> bool:
	if p.grip and p.grip.stamina < START_STAMINA:
		WildHorse._say(p, "Too spent to hold on")
		return true
	# knocked down (a kick, a throw): the grab gets him up and onto it (user 2026-09-28: "grabbing while down should be
	# okay to mount")
	# (his long gun, kept on the body while he was down, stays slung till he is off the horse, as on any mount)
	var gun := ""
	var rd := PlayerRagdoll.of(p)
	if rd.is_down() and not p.is_dead:
		gun = p._pose_gun
		p._pose_gun = ""
		rd.recover_now()
	if p.is_switching() or p.climbing != null or p.kneeling != null or (p.traversal and p.traversal.showing):
		return false
	var scene := p.get_tree().current_scene
	var sp := w.spawner
	var h := Horse.new()
	h.name = "Horse_%s_%d" % [w.coat.capitalize(), w.get_instance_id() % 100000]
	h.coat = w.coat
	h.set_meta(&"breaking", true)
	h.set_meta(&"wild_species", w.species)
	scene.add_child(h)
	h.global_transform = Transform3D(Basis(Vector3.UP, w.rotation.y), w.global_position)
	h.speed = minf(Vector2(w.velocity.x, w.velocity.z).length(), Horse.CRUISE[Horse.Gait.CANTER])
	WildHorse.dress(h.visual, [])
	var reins := h.get_node_or_null(^"Reins") as Node3D
	if reins:
		reins.visible = false
	h.terrain.enabled = false
	var b := HorseBreaking.new()
	b.name = "Breaking"
	b.horse = h
	b.player = p
	b.spawner = sp
	b.species = w.species
	b.group = w.group
	b.was = {"health": w.health, "hunger": w.hunger, "fatigue": minf(w.fatigue + 0.15, 1.0), "coat": w.coat,
			"gentled": w.gentled}
	b.spirit_max = start_spirit(w)
	b.spirit = b.spirit_max
	b._rng.seed = w.get_instance_id()
	b._seed = b._rng.randf() * TAU
	# (before the rider's link: this runs first each tick, so the rider sits the body as it is tipped)
	h.add_child(b)
	if sp:
		sp.take_alive(w)
	else:
		w.queue_free()
	# from the saddle: off his own horse onto it (his long gun stays slung till he is off this one)
	var own := p.riding
	if own != null:
		gun = p._ride_gun
		p._ride_gun = ""
		p.dismount()
		own.drive(0.0, 0.0)
	if not p.mount(h):
		b._end("let_go")
		return true
	if gun != "":
		p._ride_gun = gun
	h.player_input = false
	b._start()
	return true


## The spirit a catch of `w` starts with: its species' "tame" spirit, less for a winded, hurt or gentled one.
static func start_spirit(w: WildAnimal) -> float:
	var base := float((w.data.get("tame", {}) as Dictionary).get("spirit", 70.0))
	var hp := clampf(w.health / float(w.data.health), 0.0, 1.0)
	var s := base * (1.0 - float(w.get("gentled") if w.get("gentled") != null else 0.0)) \
			* (1.0 - WINDED_OFF * w.winded()) * (1.0 - HURT_OFF * (1.0 - hp))
	return maxf(s, MIN_SPIRIT)


func _start() -> void:
	_gap = 0.35
	if player.is_local:
		var layer := CanvasLayer.new()
		layer.name = "BreakingHUD"
		layer.layer = 4
		add_child(layer)
		_hud = BreakingHud.new()
		_hud.breaking = self
		layer.add_child(_hud)
	_say("Ride it out: keep the dot in the ring with W A S D, against the throw. G lets go", 5.0)
	if player.camera:
		CameraShake.of(player.camera).add(0.3, 0.4)


# --- The ride ------------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if outcome != "":
		return
	if not is_instance_valid(horse) or not is_instance_valid(player):
		queue_free()
		return
	if player.is_dead or player.riding != horse:
		_end("let_go")
		return
	_t_in += dt
	# (the G that caught it is still down in its first moments)
	if _t_in > 0.3 and player.controls.just_pressed(&"grip"):
		_end("let_go")
		return
	_advance(dt)
	var mv := player.controls.move_vector()
	var lean := Vector2(mv.x, -mv.y)
	var wob := Vector2(sin(_t_in * 2.3 + _seed), sin(_t_in * 1.7 + _seed * 2.0)) * WOBBLE
	balance += (push * PUSH + lean * LEAN + wob) * dt
	balance -= balance * minf(SETTLE * dt, 1.0)
	_peak = maxf(_peak, balance.length())
	_spend((HOLD_DRAIN + OFF_DRAIN * balance.length_squared() + THROW_DRAIN * push.length()) * dt)
	spirit -= SPIRIT_S * dt
	if balance.length() >= 1.0 or stamina() <= 0.0:
		_end("thrown")
		return
	_pose()


## The grip's stamina (the player's PlayerGrip; else this ride's own).
func stamina() -> float:
	return player.grip.stamina if player.grip else _own_stamina


func stamina_max() -> float:
	return player.grip.stamina_max if player.grip else 100.0


func _spend(amount: float) -> void:
	if player.grip:
		player.grip.stamina = maxf(player.grip.stamina - amount, 0.0)
	else:
		_own_stamina = maxf(_own_stamina - amount, 0.0)


## The moves in turn, with a rest between: the throw on the rider (push), the body's tip and hop, the horse driven.
func _advance(dt: float) -> void:
	push = Vector2.ZERO
	_pitch = 0.0
	_hop = 0.0
	if move == "":
		horse.drive(0.0, 0.0)
		_gap -= dt
		if _gap <= 0.0:
			_begin_move(_pick())
		return
	move_t += dt
	var m: Dictionary = MOVES[move]
	var s := clampf(move_t / _len, 0.0, 1.0)
	var k := sin(PI * s)
	var done := move_t >= _len
	match move:
		"buck":
			horse.drive(0.12, 0.0)
			push = (m.push as Vector2) * k
			_pitch = float(m.pitch) * k
			_hop = float(m.hop) * k
		"crow":
			# three hops going forward at a trot, nose down, then up
			horse.set_cruise_gait(Horse.Gait.TROT)
			horse.drive(0.7, sin(move_t * 1.7 + _seed) * 0.4)
			var ph := s * 3.0
			var hk := sin(PI * fposmod(ph, 1.0))
			push = Vector2(sin(ph * 2.1 + _seed) * 0.3, (m.push as Vector2).y * hk)
			_pitch = float(m.pitch) * hk * (1.0 if int(ph) % 2 == 0 else -0.6)
			_hop = float(m.hop) * hk
		"rear":
			if not _reared:
				horse.drive(-1.0, 0.0)
				if horse.speed < 0.5 and horse.request_rear():
					_reared = true
					move_t = 0.0
					_jolt(0.35)
				done = move_t > 2.0
			else:
				var L := horse.clip_length("rear")
				var rs := clampf(horse.one_shot_time / maxf(L, 0.01), 0.0, 1.0)
				push = (m.push as Vector2) * sin(PI * rs)
				done = horse.one_shot != "rear"
		"spin_l", "spin_r":
			var sgn := signf(float(m.spin))
			horse.drive(0.0, sgn)
			horse.rotate_y(float(m.spin) * k * dt)
			push = (m.push as Vector2) * k
			_hop = float(m.hop) * absf(sin(PI * s * 3.0))
		"bolt":
			horse.set_cruise_gait(Horse.Gait.GALLOP)
			_bolt_steer = clampf(_bolt_steer + _rng.randf_range(-1.5, 1.5) * dt, -0.5, 0.5)
			horse.drive(1.0, _bolt_steer)
			var jerk := smoothstep(0.15, 0.35, s) * sin(move_t * 4.7 + _seed) * 0.45
			push = (m.push as Vector2) * (1.0 - smoothstep(0.0, 0.3, s)) + Vector2(jerk, 0.0)
			_pitch = 4.0 * sin(move_t * 9.0)
	if done:
		_end_move()


## A move by its weight: a rear only from a stand, a bolt only while it has spirit, never the same spin twice.
func _pick() -> String:
	var total := 0.0
	var opts := {}
	for k: String in MOVES:
		if k == "rear" and horse.speed > 2.0:
			continue
		if k == "bolt" and spirit < spirit_max * 0.3:
			continue
		if k == _last:
			continue
		opts[k] = float(MOVES[k].w)
		total += float(MOVES[k].w)
	var r := _rng.randf() * total
	for k: String in opts:
		r -= float(opts[k])
		if r <= 0.0:
			return k
	return "buck"


func _begin_move(m: String) -> void:
	move = m
	_last = m
	move_t = 0.0
	_len = float(MOVES[m].s)
	_peak = balance.length()
	_reared = false
	if m != "rear":
		_jolt(0.25 if m == "crow" else 0.4)


func _end_move() -> void:
	spirit -= SPIRIT_MOVE.x + SPIRIT_MOVE.y * (1.0 - clampf(_peak, 0.0, 1.0))
	moves_ridden += 1
	move = ""
	_gap = lerpf(GAP.x, GAP.y, 1.0 - clampf(spirit / maxf(spirit_max, 1.0), 0.0, 1.0)) + _rng.randf() * 0.3
	if spirit <= 0.0:
		_end("broken")


func _jolt(amount: float) -> void:
	if player.camera:
		CameraShake.of(player.camera).add(amount, 0.35)


## The body tipped about the fore hooves (nose down) or the hind (nose up) and lifted by the hop; the rider leans with
## the pitch (HorseRiderLink's incline reads it).
func _pose() -> void:
	var pz := FORE_Z if _pitch < 0.0 else HIND_Z
	var p := Vector3(0.0, 0.0, pz)
	var r := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_pitch)), Vector3.ZERO)
	horse.visual.transform = Transform3D(Basis(), p + Vector3.UP * _hop) * r * Transform3D(Basis(), -p) \
			* Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	if horse.terrain:
		horse.terrain.body_pitch_deg = _pitch


func _unpose() -> void:
	if is_instance_valid(horse):
		horse.visual.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		horse.terrain.enabled = true


# --- The end -------------------------------------------------------------------------------------

## Broken (the horse is the player's), thrown, or let go (both: it is wild again).
func _end(how: String) -> void:
	if outcome != "":
		return
	outcome = how
	_unpose()
	if _hud:
		_hud.get_parent().queue_free()
		_hud = null
	match how:
		"broken":
			_broken()
		"thrown":
			_thrown()
		_:
			_off()
			_wild_again()


func _broken() -> void:
	horse.drive(0.0, 0.0)
	horse.remove_meta(&"breaking")
	horse.set_meta(&"tamed", true)
	WildHorse.dress(horse.visual, WildHorse.HEADSTALL)
	var reins := horse.get_node_or_null(^"Reins") as Node3D
	if reins:
		reins.visible = true
	HorseInput.ensure()
	var m := HorseMount.attach_to(horse)
	m.rider = player
	horse.player_input = true
	var who := "stallion" if species == "stallion" else "mare"
	_say("Broken. The %s %s is yours" % [String(was.get("coat", horse.coat)), who], 5.0)
	queue_free()


func _thrown() -> void:
	var fwd := -horse.global_basis.z
	var right := horse.global_basis.x
	var dir := right * balance.x + fwd * balance.y
	dir.y = 0.0
	if dir.length_squared() < 1e-4:
		dir = right
	dir = dir.normalized()
	_off()
	if player.has_method("knock_down"):
		player.knock_down(dir * THROW_V + Vector3.UP * THROW_UP)
	player.apply_hit(THROWN_DAMAGE, player.global_position + Vector3.UP * 0.9, dir + Vector3.DOWN, horse, "body")
	_say("Thrown", 2.5)
	_wild_again()


## The rider off it (on his feet: the dismount) if he is still on.
func _off() -> void:
	if is_instance_valid(player) and player.riding == horse:
		player.dismount()


## Back to the wildlife as it was, a little gentled, bolting from the player; the Horse goes.
func _wild_again() -> void:
	if spawner and is_instance_valid(spawner) and is_instance_valid(horse):
		var st := was.duplicate()
		var taken := 1.0 - clampf(spirit / maxf(spirit_max, 1.0), 0.0, 1.0)
		st["gentled"] = clampf(float(was.get("gentled", 0.0)) + taken * GENTLED_KEEP * (1.0 - float(was.get("gentled", 0.0))), 0.0, 0.9)
		var from := player.global_position if is_instance_valid(player) else horse.global_position
		var a := spawner.release(species, horse.global_transform, st, group, from)
		# (it runs from the man it threw: no turning on him while he is down, a stallion's charge)
		a._bite_cd = LEAVE_S
	if is_instance_valid(horse):
		horse.queue_free()


func _say(text: String, secs := 3.0) -> void:
	if is_instance_valid(player) and player.interactor:
		player.interactor.notice(text, secs)
