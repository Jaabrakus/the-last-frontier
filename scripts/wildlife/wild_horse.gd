class_name WildHorse
extends WildAnimal
## A wild horse (WildlifeSpecies "horse" and "stallion", rig "horse"; user 2026-09-28: "use the bison or deer logic to
## build a herd of wild horses that can be tamed"): the herd animal of WildAnimal (its senses, the band's brain, the
## flight, the stallion's defence, wounds and the carcass) in the project's own horse (assets/horse/horse.glb, the
## rideable Horse's model) with its coat (HorseLook; one of the species' "coats") and no tack.
##   gaits    a walk or a run is shown as the horse's gait for its speed (walk, trot, canter, gallop, sprint: shifting
##            as the Horse does, UP / DOWN), its clip at speed / the clip's own no-slip speed (horse_meta design_speed)
##   head     grazing, dozing and the alert are the idle with the head carried (WildHorsePose): to the grass, low, high
##   rear     its strike (the stallion's charge, a cornered mare's): the Horse's rear clip
##   death    the horse has no death clip: it goes over onto its side (DEATH_S), legs out
## Caught (HorseBreaking.try_grab: G at its side, on foot or from the saddle alongside) it leaves its band as a Horse to
## be ridden out; one that threw its rider comes back here (WildlifeSpawner.release) a little gentled (`gentled`, the
## share of its spirit already taken: the next ride is that much shorter).

const HorseLook := preload("res://scripts/horse/horse_look.gd")
const META_PATH := "res://assets/horse/horse_meta.json"
## The horse model's tack meshes (all off on a wild one; a broken horse keeps HEADSTALL, the bridle and bit, for the
## reins).
const TACK := ["Bit", "Bridle", "Girth", "Saddle", "SaddleCloth", "StirrupIron_l", "StirrupIron_r", "StirrupLeather_l",
		"StirrupLeather_r"]
const HEADSTALL := ["Bit", "Bridle"]
const GAITS := ["idle", "walk", "trot", "canter", "gallop", "sprint"]
## The speed (m/s) at which each gait hands over to the next, and below which the next drops back (Horse.UP_SHIFT /
## DOWN_SHIFT; the walk a little later, so a grazing step is a walk).
const UP := [0.15, 2.2, 4.6, 8.3, 12.0]
const DOWN := [0.08, 1.9, 4.2, 7.7, 11.5]
## The clips' playback-rate band (the stride's no-slip rate, kept within it).
const RATE := Vector2(0.55, 1.35)
## How fast the head eases to its carriage (1/s).
const HEAD_RATE := 4.0
## Going over when it dies (s), and the lie of the body on its side: the barrel's height off the ground (m) and its
## height standing (the body turns about the ground under its middle, then is set down on its side there).
const DEATH_S := 0.9
const LIE_H := 0.3
const BARREL_H := 1.05
## How near (m, from the body's line, chest to rump) a G takes hold: on foot, and from the saddle alongside (the
## horses' middles apart). Its body's line: CHEST m before its middle, RUMP behind.
const GRAB_FOOT := 1.7
const GRAB_SADDLE := 2.8
const CHEST := 0.9
const RUMP := 0.8

var coat := "bay"
## How much of its spirit a rider has already taken out of it (0 wild .. 1: HorseBreaking).
var gentled := 0.0

var _gait := 0
var _pose: WildHorsePose
var _head_want := Vector2.ZERO
var _dying := -1.0
var _lie_side := 1.0

static var _meta := {}
static var _looped := false


func setup(p_species: String, p_spawner: WildlifeSpawner, p_group: WildGroup, seed_: int) -> void:
	super.setup(p_species, p_spawner, p_group, seed_)
	var cs: Array = data.get("coats", ["bay"])
	coat = String(cs[rng.randi() % cs.size()])
	_lie_side = 1.0 if rng.randf() < 0.5 else -1.0


func _ready() -> void:
	super._ready()
	HorseLook.apply(_model, coat)
	dress(_model, [])
	if not _looped:
		_looped = true
		var clips: Dictionary = meta().get("clips", {})
		for a in _ap.get_animation_list():
			var loops: bool = (clips.get(String(a), {}) as Dictionary).get("loop", false)
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	_pose = WildHorsePose.new()
	_pose.name = "HeadCarriage"
	_skel.add_child(_pose)


## The horse's asset data (horse_meta.json: the clips' speeds and loops), read once.
static func meta() -> Dictionary:
	if _meta.is_empty():
		var m = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		_meta = m if m is Dictionary else {"clips": {}}
	return _meta


## A clip's no-slip ground speed at rate 1 (m/s).
static func clip_speed(c: String) -> float:
	return float(((meta().get("clips", {}) as Dictionary).get(c, {}) as Dictionary).get("design_speed", 1.0))


## Shows only the tack meshes named in `keep` on a horse model (a Horse's visual or a wild one's).
static func dress(visual: Node3D, keep: Array) -> void:
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		if TACK.has(String(mi.name)):
			(mi as MeshInstance3D).visible = keep.has(String(mi.name))


func set_active(on: bool) -> void:
	super.set_active(on)
	if _pose:
		_pose.active = on or state == State.DEAD


# --- Clips ---------------------------------------------------------------------------------------

## The stand-ins' clip names (WildlifeSpecies "clips": walk, run, graze, alert, rest, rear, death, idle) played as the
## horse's: a walk or a run as the gait for its speed now, the head carried for grazing, dozing and the alert.
func _play(clip: String, blend := 0.3, speed := 1.0) -> void:
	match clip:
		"walk", "run":
			_head_want = Vector2.ZERO
			_gait = _gait_for(_speed)
			if _gait == 0:
				super._play("idle", blend, 1.0)
			else:
				var g: String = GAITS[_gait]
				super._play(g, 0.25, clampf(_speed / clip_speed(g), RATE.x, RATE.y))
		"graze":
			_head_want = WildHorsePose.GRAZE
			super._play("idle", blend, 0.8)
		"alert":
			_head_want = WildHorsePose.ALERT
			super._play("idle", blend, 1.0)
		"rest":
			_head_want = WildHorsePose.DOZE
			super._play("idle", blend, 0.5)
		"rear":
			_head_want = Vector2.ZERO
			super._play("rear", 0.15, 1.0)
		"death":
			_head_want = Vector2.ZERO
			if _dying < 0.0:
				_dying = 0.0
			super._play("idle", 0.2, 0.0)
		_:
			_head_want = Vector2.ZERO
			super._play("idle", blend, speed if speed > 0.0 else 1.0)


## The gait for speed `v` from the one it is in (one shift point up, another down: no flicker between two).
func _gait_for(v: float) -> int:
	var g := _gait
	while g < GAITS.size() - 1 and v > float(UP[g]):
		g += 1
	while g > 0 and v < float(DOWN[g - 1]):
		g -= 1
	return g


func _process(delta: float) -> void:
	if _pose and (active or _dying >= 0.0):
		var k := 1.0 - exp(-HEAD_RATE * delta)
		_pose.neck_deg = lerpf(_pose.neck_deg, _head_want.x, k)
		_pose.head_deg = lerpf(_pose.head_deg, _head_want.y, k)
	if _dying >= 0.0 and _dying < DEATH_S:
		_dying = minf(_dying + delta, DEATH_S)
		_lay_over(_dying / DEATH_S)


## Dead already (a save's carcass): lying on its side at once.
func lie_dead(by: String) -> void:
	super.lie_dead(by)
	_dying = DEATH_S
	_lay_over(1.0)


## Over onto its side (k 0 standing .. 1 down; falling faster as it goes): turned about its length and set down so the
## barrel lies where it stood.
func _lay_over(k: float) -> void:
	if _visual == null:
		return
	var phi := _lie_side * PI * 0.5 * k * k
	var s := sin(phi)
	var b := Basis(Vector3.BACK, phi) * Basis(Vector3.UP, PI) * Basis.from_scale(Vector3.ONE * _base_scale)
	_visual.transform = Transform3D(b, Vector3(BARREL_H * s, LIE_H * absf(s) - 0.04, 0.0))


# --- The catch -----------------------------------------------------------------------------------

## Flat distance (m) from `p` to its body's line, chest to rump.
func grab_distance(p: Vector3) -> float:
	var f := _flat_fwd()
	var a := global_position + f * CHEST
	var b := global_position - f * RUMP
	var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, a.y, p.z), a, b)
	return Vector2(q.x - p.x, q.z - p.z).length()


## Where `p` is about it: "front" (before its chest, within 45 deg of its nose), "back" (behind its rump, within 35
## deg of its tail), else "side".
func side_of(p: Vector3) -> String:
	var f := _flat_fwd()
	var to := p - global_position
	to.y = 0.0
	if to.length_squared() < 1e-4:
		return "side"
	var along := to.dot(f)
	var ang := rad_to_deg(f.angle_to(to.normalized()))
	if along > CHEST * 0.8 and ang < 45.0:
		return "front"
	if along < -RUMP * 0.75 and ang > 145.0:
		return "back"
	return "side"


func _flat_fwd() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 1e-6 else Vector3.FORWARD


## G within reach of it (HorseBreaking.try_grab): at its side a fistful of mane and up onto its back (HorseBreaking);
## before its nose it throws up its head and bolts (a stallion, crowded, rears and strikes instead: its "defend");
## behind it, unless it is winded or dozing, it kicks. True: the G was taken (whatever came of it).
func grabbed(p: FrontierPlayer) -> bool:
	match side_of(p.global_position):
		"front":
			_start_flee(p.global_position)
			_say(p, "It throws up its head: come at its side")
			return true
		"back":
			if winded() < 0.5 and state != State.REST:
				threat_pos = p.global_position
				awareness = 1.3
				_enter(State.ATTACK, 0.9)
				_bit = false
				_say(p, "Never behind a horse")
				return true
	return HorseBreaking.begin(self, p)


static func _say(p: FrontierPlayer, text: String) -> void:
	if p and p.interactor:
		p.interactor.notice(text, 3.0)
