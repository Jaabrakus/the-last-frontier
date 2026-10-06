class_name AxeMelee
extends RefCounted
## Directional melee with the felling axe (user 2026-09-27: "i like the idea of W a s d that decides the direction and
## the aimer is where, but i also like the idea of opposite forces counter attack ... A will be left to right and aimer
## decides where on the body ... WD or WA or SA or SD is a stab to block stabbs users have to do AD left click";
## "attacks only for now"). GatherTools drives it: with the felling axe out and nothing to fell or buck in front, LMB
## is an attack in the way the move keys held at the click say (data/melee/felling_axe.json):
##   D           right to left              A        left to right (D mirrored)
##   W           overhead, down             S        the high block (no attack: the haft held up across against W)
##   S + A/D     the stab, for a tool that has one (the club; the felling axe has none since 2026-09-30: S + A / S + D
##               swing A / D like W + A / W + D) (our own thrust, keyed by hand: tools/anim_author/author_thrust.gd)
##   A + D       the parry sweep against a stab (no damage: counters come with opponents)
##   none        the data's default (D)
## RMB is the reverse of the same keys' attack (user 2026-10-03, every melee weapon: REVERSE): D right-click cuts left to
## right as A does, A right to left, W rises into the high block (S) and S comes down overhead (W); the parry and the
## stab are their own. The other button breaks an attack off (RMB a LMB one, LMB a RMB one), as a jump or a sprint does.
## Nothing locks the player into an attack (user 2026-09-27: "make sure none of the attacks are on a animation lock",
## "be able to move ... right click to cancel", "juke move like in jedi academy"): the body moves as ever under the
## swing (the upper body swings, the legs take its footwork only standing, eased as the player stops and moves); RMB,
## a jump or a sprint breaks it off at once (CANCEL_FADE_S; it strikes nothing more) and LMB begins the next straight
## away; LMB during a swing that is not broken off begins the next at its chain time.
## The crosshair decides where it lands: the body leans the swing up or down toward the aim point (ToolPose.lean,
## aim_lean_deg at the pitch's limits) and the edge's path is what hits: through the strike window of the swing (where
## its hands move fastest) the edge, the haft and the edge's travel since the last tick are swept against the world,
## and whatever it passes through takes the damage once (Hit.deliver: the part it struck and its damage_mult).
## Nothing is passed through (user 2026-09-27: "we need a collision thing where it doesnt go thru the target", "if two
## weapons collide they both bounce back"): the whole swing (the whole weapon is hot: FULL_SPEED)
## the axe's path over the next tick is swept before the pose is shown (MeleeSweep: where the clip will put it), and
## on meeting something the swing goes back to the moment it met it (a soft thing lets the edge bite in a little),
## holds there a moment and runs back (pulled out, or bounced off: by surface, "contact" in the data), then fades to
## the guard; LMB begins the next attack from the moment the hold ends. A blow into something soft (flesh, straw) cuts
## in instead (user 2026-09-27: "i still want the crunch maybe go all the way to the spine"): the swing slows as the
## edge goes in, and where it reaches the core (MeleeSweep.core_of: a torso's spine, a head's middle, a dummy's post;
## or the deepest its path goes, if it only cuts across) comes the crunch (a crunch of bone, a jolt of the view); then
## it goes on through (user 2026-09-27: "have the strike if hit go thru the
## body"): a blow that lands on a body (THROUGH: flesh, straw) is not stopped by it, slowed only while the edge is in
## it, and the swing plays out; a blunt one (the club, the haft) goes on through at once. Hard things (wood, stone)
## still stop it and it bounces back. A defender met (its body, or its weapon in the parry) turns
## the blow aside only with its counter (the block by reaction, block_power; user 2026-09-27: "ad should only parry
## thrusts and [the] users should only block by counters and thats it"): the cut that meets it head on in time (facing
## each other the side cuts are mirrored: D meets D, A meets A; W meets S), or the parry (AD)
## against a stab, stops it short, both swings bouncing back (clash); the counter late or early, it glances on,
## weaker. Nothing else blocks (not the guard). Attacks do not meet in the air.
## The reach past the steel (reach_m) still lands damage without stopping anything (the axe passed in front of it).
## The swing's state: s.contact "stop" | "recoil" | "done", s.free once the next attack may begin.
## Struck first, the attack is lost (user 2026-09-27: "if the other user hits the user [first] then a hit animation
## happens and it restarts the persons hit swing"): a blow landing on the player (their hurt: the hit reaction plays,
## light or heavy) breaks their attack off as RMB would, and no attack begins for the flinch (FLINCH_S, FLINCH_HEAVY_S);
## then LMB swings again from the start. Blows traded, the first to land wins.

const DATA_PATH := "res://data/melee/felling_axe.json"
## Each melee tool's own data (the same shape): the felling axe's and the saber's.
const DATA_PATHS := {"felling_axe": DATA_PATH, "saber": "res://data/melee/saber.json"}
## This project's own clips (tools/anim_author/): a swing's clip is looked for here first, then in GatherTools's.
const OWN_PATH := "res://animations_extra/Frontier_Own.res"
## A broken-off attack fades out this fast.
const CANCEL_FADE_S := 0.1
## An edge meeting something this fast (m/s) is a blow even just outside the strike window.
const HIT_SPEED := 3.5
## The whole weapon is hot the whole swing (user 2026-09-27: "the whole part of the weapon swing and thrust be a hot
## weapon so any point of the animation does damage"), from when it has blended in (s.w: the blend from the pose before
## is not the swing's path): a blow's damage is the swing's times how fast the part that met
## it was moving (full from FULL_SPEED m/s, never under MIN_POWER), and a blunt part (the haft, the grip, the butt
## end) gives BLUNT_PART of it; the head, the edge and the blade all of it. Cutting in still wants a blow (HIT_SPEED).
const FULL_SPEED := 6.0
const MIN_POWER := 0.2
const BLUNT_PART := 0.6
## The block by reaction (user 2026-09-27: "the block system is based on there reaction disrupts how much damage they
## take if it meets there body"; "we dont need collision detection beside only the parry and blocks"; "ad should only
## parry thrusts and [the] users should only block by counters and thats it"; "the thrust parry is weird"): a blow
## coming within BLOCK_STOP_M of a defender (MeleeSweep.near_defender: the space between them, where the counter or the
## parry meets it; at 1.1 m the two guards' axes all but touch, so the axes themselves are not what meets), or its body
## if it gets there first, is turned aside only by the defender's counter to it ("counters" in
## the data: the same side cut, D against D and A against A, mirrored as they face each other; W and S; the parry AD
## a stab's), 0..1 (block_power), once a swing. From BLOCK_FULL
## on it is stopped short (BLOCK_BACK_S back along its path) and both swings bounce back; under it the blow glances
## off and goes on, its damage cut by that much. Two attacks do not meet in the air: blows traded both land, unless
## one is the other's counter.
const BLOCK_FULL := 0.95
## The counter to the blow begun too late (still winding up) or too early (past its strike) turns it this much aside;
## in time (from COUNTER_LEAD s before its strike window to its end: the parry's is its sweep; wide enough for a
## reaction and some lag: user 2026-09-27, the fairness pass), all of it.
const BLOCK_SWING := 0.5
const COUNTER_LEAD := 0.25
## Struck: no attack begins for this long (a heavy hit: the longer; the player's hurt, heavy_hit_damage). Shorter than
## any attack's chain on to its next blow landing (D: 0.7 s + 0.4 s), so a blow landed is not a sure second one: the
## one struck has time to counter it (user 2026-09-27, the fairness pass: "end the stunlock").
const FLINCH_S := 0.3
const FLINCH_HEAVY_S := 0.45
## Only a real blow breaks an attack off (this much damage; a graze does not: "raise the interrupt bar").
const INTERRUPT_DAMAGE := 15.0
const BLOCK_BACK_S := 0.03
## How far out from a defender's middle a blow meets its block (stopped there, whole; or glancing on, weaker).
const BLOCK_STOP_M := 0.42
## The bodies a blow that lands goes on through (the rest stop it).
const THROUGH := ["flesh", "straw"]

signal struck(target: Object, dir: String, part: String, damage: float)
signal swung(dir: String)
## The swing met something and stopped (surface as MeleeSweep.params has it, "weapon" for another weapon).
signal contacted(surface: String, point: Vector3)
## Struck mid-attack: the attack `dir` broken off.
signal interrupted(dir: String)
## A blow of this weapon partly blocked (its damage cut by `power`: block_power), glancing off.
signal glanced(power: float, point: Vector3)

var gather: GatherTools
var player: FrontierPlayer
## The data of the tool in the hand (the felling axe's when none).
var data: Dictionary:
	get:
		return _data_of(gather.tool if gather else "")
var _datas := {}
## The last attack begun ("" none) and its hits, for tests.
var last_dir := ""
var last_hits: Array = []
var _was_fire := false
var _own: AnimationLibrary
## The last contact ({"surface", "point", "collider", "u"}), for tests.
var last_contact := {}
var _pts := {}                   ## model instance id -> its local {"edge", "head", "grip"}
var _flinch_left := 0.0          ## s of the flinch left (struck: no attack begins)


func _init(g: GatherTools) -> void:
	gather = g
	player = g.player
	for k: String in DATA_PATHS:
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATHS[k])) if FileAccess.file_exists(DATA_PATHS[k]) else null
		_datas[k] = d if d is Dictionary else {}
	if ResourceLoader.exists(OWN_PATH):
		_own = load(OWN_PATH) as AnimationLibrary
	if player:
		player.hurt.connect(_on_hurt)
		player.add_to_group(&"melee_defender")
		# (a player's body is flesh to another's blow: cut into, gone through; untagged, Sfx.surface_of had it wood)
		if not player.has_meta(&"surface"):
			player.set_meta(&"surface", "flesh")


## Struck (the player's hurt, its hit reaction playing) by a real blow (INTERRUPT_DAMAGE): the attack going is broken
## off, and none begins for the flinch.
func _on_hurt(_local_dir: Vector2, amount: float, heavy: bool) -> void:
	if amount < INTERRUPT_DAMAGE:
		return
	_flinch_left = maxf(_flinch_left, FLINCH_HEAVY_S if heavy else FLINCH_S)
	var s := gather._swing
	if not s.is_empty() and bool(s.get("melee", false)) and not bool(s.get("cancel", false)):
		var d := String(s.dir)
		gather._cancel_melee()
		interrupted.emit(d)


## Every tick (GatherTools._step): the flinch runs down.
func tick(delta: float) -> void:
	_flinch_left = maxf(_flinch_left - delta, 0.0)


## Struck a moment ago: no attack begins yet.
func flinching() -> bool:
	return _flinch_left > 0.0


func _data_of(tool: String) -> Dictionary:
	return _datas.get(tool, _datas.get("felling_axe", {}))


## The tool's guard between attacks, [Animation, time] ([] none: "guard" in its data; the club's two-handed guard).
func guard() -> Array:
	var g: Dictionary = data.get("guard", {})
	if g.is_empty() or gather._clips == null:
		return []
	var a := _anim(gather._clips, String(g.get("clip", "")))
	return [a, float(g.get("time", 0.0))] if a else []


## The attack the move keys held now ask for.
static func direction_of(w: bool, a: bool, s: bool, d: bool, default := "D", stab := true) -> String:
	if a and d:
		return "AD"
	# (the stab is back + a side key only, and only for a tool that has one (the club): W + A / W + D swing A / D, walking
	# forward into the cut, and the felling axe has no stab at all; user 2026-09-30: "no thrust for WA and WD", "remove
	# thrust all together for axe")
	if stab and s and (a or d):
		return "STAB"
	if a:
		return "A"
	if d:
		return "D"
	if w:
		return "W"
	if s:
		return "S"
	return default


func direction() -> String:
	var c := player.controls
	return direction_of(c.pressed(&"move_forward"), c.pressed(&"move_left"), c.pressed(&"move_back"), c.pressed(&"move_right"),
			str(data.get("default", "D")), (data.get("swings", {}) as Dictionary).has("STAB"))


## The reverse of each attack (user 2026-10-03: "right click is the reverse attack so if d left click is right to left d
## right click is [left to right]", for every melee weapon; W's reverse rises, "rising cut is block"): RMB plays the
## move keys' attack reversed. The parry and the stab have none (they are their own).
const REVERSE := {"D": "A", "A": "D", "W": "S", "S": "W"}


static func reverse_of(dir: String) -> String:
	return String(REVERSE.get(dir, dir))


## The attack's button: "L" (LMB, `fire`) or "R" (RMB, `aim`: the reverse).
static func button_action(button: String) -> StringName:
	return &"aim" if button == "R" else &"fire"


## The other button, a jump or a sprint: the attack is broken off (a feint; nothing locks the player into an attack).
## (user 2026-10-03: with RMB the reverse attack, "other button cancels": RMB breaks off a LMB attack and LMB a RMB one)
func cancel_asked(button := "L") -> bool:
	return player.controls.just_pressed(button_action("L" if button == "R" else "R")) \
			or player.controls.just_pressed(&"jump") or player.is_sprinting


## Stamina (user 2026-09-27, the fairness pass: "attacks, feints and parries cost stamina"): the player's own, the
## climbing grip's (PlayerGrip.stamina, its ring by the crosshair), spent by each attack and the parry as it begins
## and by a feint ("stamina" in the data); none comes back for a moment after (PlayerGrip.REST_S). Too little: the
## attack does not begin, the feint is not made (the attack goes on).
func cost(what: String) -> float:
	return float((data.get("stamina", {}) as Dictionary).get(what, 0.0))


func can_pay(what: String) -> bool:
	var gr: PlayerGrip = player.grip if player else null
	return gr == null or gr.stamina >= cost(what)


func pay(what: String) -> bool:
	var gr: PlayerGrip = player.grip if player else null
	return gr == null or gr.spend(cost(what))


## LMB pressed since the last call (a fresh press: holding it does not repeat the attack).
func pressed(fire_held: bool) -> bool:
	var p := fire_held and not _was_fire
	_was_fire = fire_held
	return p


## RMB went down this tick (the reverse attack, or the feint of a LMB one).
func alt_pressed() -> bool:
	return player.controls.just_pressed(&"aim")


func spec(dir: String) -> Dictionary:
	return (data.get("swings", {}) as Dictionary).get(dir, {})


## The swing GatherTools plays for `dir` ({} when its clips are missing).
func make_swing(dir: String, clips: AnimationLibrary) -> Dictionary:
	var sp := spec(dir)
	if sp.is_empty() or clips == null:
		return {}
	var intro := _anim(clips, String(sp.get("intro", "")))
	var hit := _anim(clips, String(sp.get("hit", "")))
	if intro == null or hit == null:
		return {}
	var strike: Array = sp.get("strike", [0.0, 0.0])
	last_dir = dir
	last_hits = []
	swung.emit(dir)
	var s := {"name": "melee_" + dir, "melee": true, "dir": dir, "intro": intro, "hit": hit, "u": 0.0, "w": 0.0,
			"impact": INF, "chain": float(sp.get("chain_s", 0.8)), "end": float(sp.get("end_s", 1.0)), "done": true,
			"target": {}, "rate": float(data.get("rate", 1.0)) * float(sp.get("rate", 1.0)),
			"strike": [float(strike[0]), float(strike[1])],
			"damage": float(sp.get("damage", 0.0)), "frame": str(sp.get("frame", "pipe")), "hits": {}}
	return s


func _anim(clips: AnimationLibrary, nm: String) -> Animation:
	if _own and _own.has_animation(nm):
		return _own.get_animation(nm)
	return clips.get_animation(nm) if clips.has_animation(nm) else null


## Every physics tick of a melee swing (GatherTools._advance_swing, s.u just advanced): the lean, the path ahead swept
## (the swing held back where it meets something).
func step(s: Dictionary, delta: float) -> void:
	_lean(s)
	if s.has("contact"):
		_contact_step(s, delta)
	elif not bool(s.get("fading", false)) and not bool(s.get("cancel", false)):
		_ahead(s, delta)
	s["shown_u"] = float(s.u)


## Another's blow met this one's block (its counter cut: it stops and bounces back too; the parry and the high block,
## no attacks, go on, knocking it aside).
func clash(point: Vector3, dir: Vector3, _by: WeaponBody) -> void:
	var s := gather._swing
	if s.is_empty() or not bool(s.get("melee", false)) or s.has("contact") or bool(s.get("cancel", false)) \
			or float(s.damage) <= 0.0:
		return
	_stop(s, "weapon", point, -dir, null, false)


## The axe's WeaponBody (on the model in the hand), made when first wanted.
func weapon_body() -> WeaponBody:
	var m := gather._model_hand
	if m == null or not is_instance_valid(m):
		return null
	return WeaponBody.attach(m, self, _points(m).head.y)


## The swing's clip and time at u (GatherTools._swing_clip, for any u).
static func clip_at(s: Dictionary, u: float) -> Array:
	var intro: Animation = s.intro
	if u < intro.length:
		return [intro, maxf(u, 0.0)]
	var hit: Animation = s.hit
	return [hit, minf(u - intro.length, hit.length)]


## The path from the pose shown to the one s.u will show, swept; met something: s.u put back to the moment it met it.
func _ahead(s: Dictionary, delta: float) -> void:
	var st: Array = s.strike
	var u_new := float(s.u)
	var u_old := float(s.get("shown_u", u_new - delta * float(s.rate)))
	var cut: Dictionary = s.get("cut", {})
	# (the whole weapon, the whole swing: what it meets is met, and struck by how fast it was going)
	var strike := u_new >= float(st[0]) and u_old <= float(st[1]) and float(s.damage) > 0.0
	var m := gather._model_hand
	var sock := gather._socket_hand
	if m == null or sock == null or not is_instance_valid(m) or not m.is_inside_tree() or u_new <= u_old:
		return
	# (still blending in from the pose before (the guard, the swing before): not yet the swing's own path, and not hot.
	# A begins with the axe on the left, the guard holds it on the right: the blend carries it across the front)
	if float(s.get("w", 1.0)) < 1.0:
		return
	var pts := _points(m)
	var n := 3
	var frames := _frames(s, u_old, u_new, n)
	var space := player.get_world_3d().direct_space_state
	var own := weapon_body()
	var skip: Array = [player.get_rid()]
	if not cut.is_empty() and is_instance_valid(cut.collider):
		skip.append((cut.collider as CollisionObject3D).get_rid())     # (going through what it cuts)
	skip.append_array(s.get("passed", []))          # (bodies it has gone through)
	var skip_areas: Array = [own.get_rid()] if own else []
	skip_areas.append_array(s.get("glanced", []))      # (weapons it glanced off: gone past)
	var c := MeleeSweep.first_contact(space, frames, pts, skip, skip_areas)
	# (a defender's block, met in the space between them before the blow reaches anything)
	var near := MeleeSweep.near_defender(space, frames, pts, self) if cut.is_empty() else {}
	if not near.is_empty() and (c.is_empty() or int(near.k) < int(c.k) or int(near.k) == int(c.k) and float(near.f) <= float(c.f)):
		var way := (near.motion as Vector3).normalized()
		var nb := _block(s, near.foe, near.point, way)
		if nb >= BLOCK_FULL:
			var nk: int = near.k
			s.u = lerpf(lerpf(u_old, u_new, float(nk - 1) / n), lerpf(u_old, u_new, float(nk) / n), float(near.f))
			_stop(s, "weapon", near.point, -way, null, true)
			last_contact["blocked"] = nb
			if near.foe.has_method(&"clash"):
				near.foe.clash(near.point, way, own)
			return
	if not cut.is_empty():
		cut.t = float(cut.t) + delta
		var core := _core_meet(s, frames, pts)
		if not core.is_empty() and (c.is_empty() or int(core.k) < int(c.k) or int(core.k) == int(c.k) and float(core.f) <= float(c.f)):
			var ck: int = core.k
			s.u = lerpf(lerpf(u_old, u_new, float(ck - 1) / n), lerpf(u_old, u_new, float(ck) / n), float(core.f))
			_crunch(s, core.point)
			return
	if not c.is_empty():
		var k: int = c.k
		var u0 := lerpf(u_old, u_new, float(k - 1) / n)
		var u1 := lerpf(u_old, u_new, float(k) / n)
		var col: Object = c.collider
		var weapon: WeaponBody = c.weapon
		var dir := ((c.to as Vector3) - (c.from as Vector3)).normalized()
		var surface := "weapon" if weapon else Sfx.surface_of(col, c.position, c.normal)
		var f := float(c.f)
		if c.line in ["edge", "head"]:
			# (something soft lets the edge in a little further along its path)
			var span := maxf(((c.to as Vector3) - (c.from as Vector3)).length(), 1e-3)
			f = minf(f + float(MeleeSweep.params(surface).bite_m) / span, 1.0)
		var motion := _motion_at(c, frames, pts)
		var speed := motion.length() / maxf(delta / n, 1e-4)
		# (a defender: its weapon held to defend, or its body, turns the blow aside by what it is doing)
		var foe: Object = weapon.holder if weapon else MeleeSweep.defender_of(col)
		if weapon and not MeleeSweep.coming_at(foe, c.position, motion):
			# (drawn back past the other's parry, not coming at them: it passes)
			_glance(s, weapon, 0.0, c.position, c.normal)
			return
		if weapon == null and foe != null and foe != self and float(s.damage) <= 0.0:
			# (the parry is no blow: it does not stop on the other's body)
			return
		var b := _block(s, foe, c.position, dir) if foe != null and foe != self else 0.0
		if b >= BLOCK_FULL:
			s.u = maxf(lerpf(u0, u1, float(c.f)) - BLOCK_BACK_S * float(s.rate), 0.0)
			_stop(s, "weapon", c.position, -dir, col, true)
			last_contact["blocked"] = b
			if foe.has_method(&"clash"):
				foe.clash(c.position, dir, own)
			return
		if weapon:
			_glance(s, weapon, b, c.position, c.normal)
			return
		s.u = lerpf(u0, u1, f)
		# a blow, whatever the moment: as hard as the part that met it was moving
		var power := clampf(speed / FULL_SPEED, MIN_POWER, 1.0) * (1.0 if c.line in ["edge", "head", "blade"] else BLUNT_PART)
		var landed := weapon == null and float(s.damage) > 0.0
		if landed and not (s.hits as Dictionary).has(_receiver_id(col)):
			(s.hits as Dictionary)[_receiver_id(col)] = true
			_land(s, col, c.position, dir, power)
		var cs := MeleeSweep.cut()
		cs.merge(data.get("cut", {}), true)       # (a blunt weapon cuts into nothing: the club)
		if landed and speed >= HIT_SPEED and cut.is_empty() and surface in cs.surfaces and c.line in ["edge", "head", "blade"]:
			# a blow into something soft: in it goes, slowed, to its core
			var core_of := MeleeSweep.core_of(col, int(c.get("shape", 0)))
			if not core_of.is_empty():
				s.u = lerpf(u0, u1, float(c.f))
				s["cut"] = {"collider": col, "core": core_of, "surface": surface, "t": 0.0, "normal": c.normal,
						"rate0": float(s.rate), "dir": dir}
				s.rate = float(s.rate) * float(cs.rate)
				last_contact = {"surface": surface, "point": c.position, "collider": col, "u": float(s.u), "cut": true}
				if s.has("glance"):
					last_contact["glance"] = s.glance
				MeleeSweep.sound(surface, c.position)
				return
		if weapon == null and surface in THROUGH and _takes_hits(col):
			# a body struck (or struck again, another part of it): the blow goes on through it
			_pass(s, col)
			last_contact = {"surface": surface, "point": c.position, "collider": col, "u": float(s.u), "through": true,
					"line": c.line, "landed": landed, "speed": speed, "power": power}
			if s.has("glance"):
				last_contact["glance"] = s.glance
			if landed:
				MeleeSweep.sound(surface, c.position)
			return
		_stop(s, surface, c.position, c.normal, col, true)
		last_contact["line"] = c.line
		last_contact["landed"] = landed
		last_contact["speed"] = speed
		last_contact["power"] = power
		if weapon and weapon.holder and weapon.holder.has_method(&"clash"):
			weapon.holder.clash(c.position, dir, own)
		return
	if strike:
		_reach(s, frames, pts)


## How fast the part of the weapon that met something was moving there (m/s): along its path for a point of it (the
## edge, the head, the grip, the butt end), between its two ends' for a place along the haft or the blade.
func _speed_at(c: Dictionary, frames: Array, pts: Dictionary, dt: float) -> float:
	return _motion_at(c, frames, pts).length() / dt


## How the part of the weapon that met something moved over its step (m): along its path for a point of it, as its two
## ends' moved for a place along the haft or the blade.
func _motion_at(c: Dictionary, frames: Array, pts: Dictionary) -> Vector3:
	if c.line in ["edge", "head", "grip", "butt"]:
		return (c.to as Vector3) - (c.from as Vector3)
	var a: Transform3D = frames[int(c.k) - 1]
	var b: Transform3D = frames[int(c.k)]
	var p0: Vector3 = pts.butt if c.line == "haft" else pts.head
	var p1: Vector3 = pts.head if c.line == "haft" else pts.edge
	var span := maxf(((c.to as Vector3) - (c.from as Vector3)).length(), 1e-4)
	var frac := clampf(((c.position as Vector3) - (c.from as Vector3)).length() / span, 0.0, 1.0)
	return (b * p0 - a * p0).lerp(b * p1 - a * p1, frac)


## How strongly `foe` (block_power; null: a weapon on its own, which stops what hits it) turns this blow aside, the
## first time the blow meets it (its weapon or its body); a partial block cuts the blow's damage then, with a glancing
## ring. Met again: 0 (already taken).
func _block(s: Dictionary, foe: Object, point: Vector3, way: Vector3) -> float:
	if foe == null or not foe.has_method(&"block_power"):
		return 1.0
	var met: Dictionary = s.get("blocks", {})
	s["blocks"] = met
	var id := foe.get_instance_id()
	if met.has(id):
		return 0.0
	var b := clampf(float(foe.block_power(String(s.dir), point, way)), 0.0, 1.0)
	met[id] = b
	if b > 0.0 and b < BLOCK_FULL:
		s["damage"] = float(s.damage) * (1.0 - b)
		s["glance"] = b
		last_contact = {"surface": "weapon", "point": point, "u": float(s.u), "glance": b}
		MeleeSweep.sound("weapon", point, 0.6)
		MeleeSweep.spark(player.get_tree().current_scene, point, -way)
		glanced.emit(b, point)
	return b


## The blow glanced off a weapon held to defend (its damage already cut: _block): it goes on past it.
func _glance(s: Dictionary, w: WeaponBody, _b: float, _point: Vector3, _normal: Vector3) -> void:
	var passed: Array = s.get("glanced", [])
	passed.append(w.get_rid())
	s["glanced"] = passed


## How strongly the player turns aside a blow (`attacker_dir`) meeting them now (the block by reaction): only their
## counter to it ("counters" in the data: the cut that meets it head on, D for D, A for A, S for W and W for S; the
## parry AD for a stab, and for nothing else)
##   1           that counter in time (the parry: its sweep)
##   BLOCK_SWING that counter too late or too early
##   0           anything else: on guard, another attack (blows traded both land), no melee weapon in hand
func block_power(attacker_dir: String, _point: Vector3, _way: Vector3) -> float:
	if gather.tool not in GatherTools.MELEE_TOOLS or gather.phase not in [GatherTools.Phase.READY, GatherTools.Phase.SWING]:
		return 0.0
	var s := gather._swing
	if s.is_empty() or not bool(s.get("melee", false)) or bool(s.get("cancel", false)) or bool(s.get("fading", false)) \
			or s.has("contact"):
		return 0.0
	if String((data.get("counters", {}) as Dictionary).get(attacker_dir, "")) != String(s.dir):
		return 0.0
	var st: Array = s.strike
	return 1.0 if float(s.u) >= float(st[0]) - COUNTER_LEAD and float(s.u) <= float(st[1]) else BLOCK_SWING


## Its weapon is never there for another's blow to meet (WeaponBody): blocks are met in the space between (block_power
## at BLOCK_STOP_M), the parry's too.
func guarding() -> bool:
	return false


## Where the edge, cutting in, reaches the core of what it cuts (within cut().core_m of it), or where its path goes no
## deeper (it cuts across rather than in: it stops at the deepest), or the cut has gone on max_s: {"k", "f", "point"}
## (the step and how far along it), or {}.
func _core_meet(s: Dictionary, frames: Array, pts: Dictionary) -> Dictionary:
	var cut: Dictionary = s.cut
	var cs := MeleeSweep.cut()
	var core_m := float(cs.core_m)
	var prev: Array = MeleeSweep.to_core(cut.core, (frames[0] as Transform3D) * (pts.edge as Vector3))
	if float(prev[0]) == INF:
		return {"k": 1, "f": 0.0, "point": (frames[0] as Transform3D) * (pts.edge as Vector3)}
	for k in range(1, frames.size()):
		var e: Vector3 = (frames[k] as Transform3D) * (pts.edge as Vector3)
		var now: Array = MeleeSweep.to_core(cut.core, e)
		if float(now[0]) <= core_m:
			var f := clampf((float(prev[0]) - core_m) / maxf(float(prev[0]) - float(now[0]), 1e-5), 0.0, 1.0)
			return {"k": k, "f": f, "point": now[1]}
		if float(now[0]) > float(prev[0]) + 0.002:
			return {"k": k, "f": 0.0, "point": (frames[k - 1] as Transform3D) * (pts.edge as Vector3)}
		prev = now
	if float(cut.t) >= float(cs.max_s):
		return {"k": frames.size() - 1, "f": 1.0, "point": (frames[frames.size() - 1] as Transform3D) * (pts.edge as Vector3)}
	return {}


## The edge at the core: the crunch (the crunch of bone, a jolt of the view), and on through: the swing back to its
## pace, the body gone past.
func _crunch(s: Dictionary, point: Vector3) -> void:
	var cut: Dictionary = s.cut
	var surface := String(cut.surface)
	# (the part it cut may be gone already, freed with the body the blow killed, 2026-10-03: what is passed on is checked)
	var col: Variant = cut.collider
	var alive := is_instance_valid(col)
	last_contact = {"surface": surface, "point": point, "collider": col if alive else null, "u": float(s.u), "through": true}
	if s.has("glance"):
		last_contact["glance"] = s.glance
	s.rate = float(cut.get("rate0", s.rate))
	if alive:
		_pass(s, col)
	s.erase("cut")
	contacted.emit("core_" + surface, point)
	last_contact["core"] = true
	var cn: Variant = (cut.core as Dictionary).get("node")
	last_contact["core_part"] = String((cn as Node).name) if is_instance_valid(cn) else ""
	MeleeSweep.crunch(surface, point)
	if surface == "flesh":
		BloodFx.hit(player.get_tree().current_scene, point, cut.get("dir", -(cut.normal as Vector3)), cut.normal, 1.6,
				_receiver(col) if alive else null)
	player.add_recoil(0.7, randf_range(-0.35, 0.35))


## A body gone through: not met again this swing.
func _pass(s: Dictionary, col: Object) -> void:
	var passed: Array = s.get("passed", [])
	if col is CollisionObject3D and is_instance_valid(col):
		passed.append((col as CollisionObject3D).get_rid())
	s["passed"] = passed


## The model's transforms from the pose shown (u_old) to u_new, n steps: where the clip will put the prop bone,
## from where the pose shown has it.
func _frames(s: Dictionary, u_old: float, u_new: float, n: int) -> Array:
	var m := gather._model_hand
	var sock := gather._socket_hand
	var shown := sock.global_transform * m.transform
	var out: Array = [shown]
	var sk := player.skeleton
	# (standing, the clip moves the whole body, its root too; moving, only above the hips)
	var frame := "" if float(s.get("still_w", 0.0)) > 0.5 else "upper_base"
	var c0 := clip_at(s, u_old)
	var base := sock.global_transform * MeleeSweep.clip_bone(sk, c0[0], c0[1], "r_hand_prop_attachment", frame).affine_inverse()
	for k in range(1, n + 1):
		var ck := clip_at(s, lerpf(u_old, u_new, float(k) / n))
		out.append(base * MeleeSweep.clip_bone(sk, ck[0], ck[1], "r_hand_prop_attachment", frame) * m.transform)
	return out


## Held where it met something, then run back, then faded to the guard.
func _stop(s: Dictionary, surface: String, point: Vector3, normal: Vector3, col: Object, loud: bool) -> void:
	var prm := MeleeSweep.params(surface)
	s["contact"] = "stop"
	s["contact_prm"] = prm
	s["contact_left"] = float(prm.stop_s)
	s["rate"] = 0.0
	last_contact = {"surface": surface, "point": point, "collider": col, "u": float(s.u)}
	if s.has("glance"):
		last_contact["glance"] = s.glance
	if loud:
		MeleeSweep.sound(surface, point, 1.0, String((data.get("sounds", {}) as Dictionary).get(surface, "")))
	if surface in ["weapon", "stone"]:
		MeleeSweep.spark(player.get_tree().current_scene, point, normal)
	contacted.emit(surface, point)


func _contact_step(s: Dictionary, delta: float) -> void:
	var prm: Dictionary = s.contact_prm
	s.contact_left = float(s.contact_left) - delta
	match String(s.contact):
		"stop":
			if float(s.contact_left) <= 0.0:
				s.contact = "recoil"
				s.contact_left = float(prm.recoil_s)
				s.rate = -float(prm.recoil_rate)
				s["free"] = true
		"recoil":
			if float(s.contact_left) <= 0.0 or float(s.u) <= 0.0:
				s.contact = "done"
				s.rate = 0.0
				s.fading = true
				s["fade_s"] = float(prm.fade_s)


## The swing is over (faded out, or replaced).
func finish(_s: Dictionary) -> void:
	if gather.pose:
		gather.pose.lean = 0.0


## The crosshair's height: the body leans the swing down toward a low aim, back for a high one.
func _lean(s: Dictionary) -> void:
	if gather.pose == null:
		return
	var max_lean := deg_to_rad(float(data.get("aim_lean_deg", 20.0)))
	var k := clampf(-player.pitch / deg_to_rad(player.pitch_limit_deg * 0.6), -1.0, 1.0)
	var fade := float(s.get("w", 1.0)) * float(s.get("w2", 1.0))
	gather.pose.lean = k * max_lean * fade


## A little more reach than the steel (reach_m out past the edge, level from the chest): the clips were made for a foe
## at arm's length, and a hit that looked like it landed should. Damage only: the swing goes on (it passed in front).
func _reach(s: Dictionary, frames: Array, pts: Dictionary) -> void:
	var space := player.get_world_3d().direct_space_state
	var hits: Dictionary = s.hits
	var chest := player.global_position + Vector3.UP * 1.3
	# (the swing's own, else the data's)
	var reach := float(spec(String(s.dir)).get("reach_m", data.get("reach_m", 0.0)))
	if reach <= 0.0:
		return
	var prev_far := Vector3.ZERO
	for k in frames.size():
		var edge: Vector3 = (frames[k] as Transform3D) * (pts.edge as Vector3)
		var out := edge - chest
		out.y = 0.0
		var far := edge + (out.normalized() if out.length_squared() > 1e-4 else Vector3.ZERO) * reach
		var lines: Array = [[edge, far]]
		if k > 0:
			lines.append([prev_far, far])
		prev_far = far
		for ln: Array in lines:
			var q := PhysicsRayQueryParameters3D.create(ln[0], ln[1])
			q.exclude = [player.get_rid()]
			var r := space.intersect_ray(q)
			if r.is_empty():
				continue
			var col: Object = r.collider
			var key := _receiver_id(col)
			if hits.has(key) or not _takes_hits(col):
				continue
			hits[key] = true
			_land(s, col, r.position, ((ln[1] as Vector3) - (ln[0] as Vector3)).normalized())


## The model's own points: its edge, head and grip (the markers, as the model's local places).
func _points(m: Node3D) -> Dictionary:
	var id := m.get_instance_id()
	if not _pts.has(id):
		var inv := m.global_transform.affine_inverse()
		_pts.clear()
		_pts[id] = {"edge": inv * _marker(m, "Edge", Vector3(0.0, 0.8, -0.17)),
				"head": inv * _marker(m, "Head", Vector3(0.0, 0.8, 0.0)),
				"grip": inv * _marker(m, "Grip", Vector3(0.0, 0.46, 0.0)), "butt": Vector3.ZERO}
	return _pts[id]


static func _takes_hits(col: Object) -> bool:
	var n := col as Node
	while n != null:
		if n.has_method(&"apply_hit"):
			return true
		n = n.get_parent()
	return false


func _land(s: Dictionary, col: Object, point: Vector3, dir: Vector3, power := 1.0) -> void:
	var part := str((col as Node).get_meta("hit_part", "body")) if col is Node else "body"
	var dmg := float(s.damage) * power
	player.get_tree().call_group("hit_listeners", "on_projectile_hit", col, point)
	# (a melee blow: no head bonus, that is for shots)
	var took := Hit.deliver(col, dmg, point, dir, player, false)
	var surface := Sfx.surface_of(col, point, -dir)
	var snd := &"arrow_hit_flesh" if surface == "flesh" else (&"arrow_hit_straw" if surface == "straw" else &"arrow_hit_wood")
	if Sfx.has(snd):
		Sfx.play_3d(snd, point, 2.0, randf_range(0.8, 0.9))
	if took and surface == "flesh":
		# blood: the spray on along the blade, the splash on the ground, the wound's mark (BloodFx)
		BloodFx.hit(player.get_tree().current_scene, point, dir, -dir, dmg / 40.0, _receiver(col))
	last_hits.append({"target": col, "part": part, "damage": dmg if took else 0.0, "surface": surface})
	struck.emit(col, String(s.dir), part, dmg if took else 0.0)


## What takes the hits `col` is part of (the node with apply_hit), or null.
static func _receiver(col: Object) -> Node:
	var n := col as Node
	while n != null:
		if n.has_method(&"apply_hit"):
			return n
		n = n.get_parent()
	return null


## One key per damage taker (a dummy's or an animal's zones all count as the one body).
static func _receiver_id(col: Object) -> int:
	var n := col as Node
	while n != null:
		if n.has_method(&"apply_hit"):
			return n.get_instance_id()
		n = n.get_parent()
	return col.get_instance_id()


static func _marker(m: Node3D, nm: String, fallback: Vector3) -> Vector3:
	var mk := m.get_node_or_null(nm) as Node3D
	return mk.global_position if mk else m.global_transform * fallback
