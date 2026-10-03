class_name SkyBattle
extends Node3D
## The second fire (docs/main_story.md v5, mission 11, Two Fires; the owner, 2026-10-02: "the scene should be two air
## ships fighting, they break the sky and one crashes down"): at night two sky ships fight high in the camp's north-east
## sky; the fight strikes the sky open (the decisive shot misses and breaks it: SkyTear starts there); Captain Ithel's
## cutter (Rook aboard) is struck hard, burns and falls on a curve into the pines (WreckFall.begin_from: the existing
## fall and wreck); the hunter turns and climbs back up into the break and is gone. Staged to be seen from the camp; the
## player keeps control throughout (nothing here holds the player, the camera or the clock).
##   var sb := SkyBattle.begin(level, camp, crash_at, {"heading": yaw})
##   sb.tear_point.connect(f)     # f(dir): unit, world, from the camp to where the sky was struck (also sb.tear_at)
##   sb.cutter_falling.connect(g) # g(wf): the WreckFall that has the cutter now (its own `landed` follows)
##   sb.sky_flash.connect(h)      # h(amount 0..1, dir): each hit's flash, for the sky (SkyTear.flash(rig, amount, dir))
##   sb.focus()                   # where the fight is now (for the camp's eyes)
##   sb.tear_aim()                # where the sky will be (or was) struck: the tear's point (world)
##   sb.skip()                    # all of it over at once: the wreck down, the hunter gone (the signals still in order)
##   SkyBattle.preload_models()   # the ships' and the wreck's models on a worker thread ahead of it (StorySlice: the march)
##   SkyBattle.prepare(level)     # that, and the wreck's two people built ahead, hidden (Two Fires begins: its fire talk)
## Signals, always in this order: opened_fire, tear_point(dir), cutter_hit, cutter_falling(wf), hunter_gone, finished
## (finished: the wreck is down and the hunter gone; the battle then frees itself once its last sparks are out); and
## sky_flash(amount, dir) at every flash (a ball's hit 0.2, the cutter struck ~0.45, the sky struck 1; dir from the camp).
## opts: heading (radians: the wreck's, as WreckFall's; default WreckFall.DEFAULT_HEADING), speed (the clock x this:
## tests), seed, quality (default the level's settings), sky_mark (a world direction from the camp: the wonder's giant,
## WonderLook.giant_dir; the sky is struck TEAR_BESIDE_DEG beside it, toward the fight, so the break opens over it).
##
## THE STAGE, from the camp and the crash point with its heading: the circle (CIRCLE_R, CIRCLE_ALT over the higher of the
## camp's and the crash's ground) round a middle near FIGHT_M off the camp toward FIGHT_BEARING (north-north-east, toward
## the pole where the giant wheels: a grid searched round it); the cutter leaves it where its tangent leads, after a run out (climbing RUN_CLIMB m) and the
## stagger (struck, losing way), to the fall's start about FALL_RUN m short of the crash over the ground, its course at
## most FALL_BEND deg off the way to the crash and that at most FALL_TURN deg off the heading (WreckFall's curve bends it
## onto it); the turning way and the times round make the circling nearest CIRCLE_AIM_S (within CIRCLE_S). Both ships
## run in from the far side (ENTER_S, higher), heading for the camp; the cutter swings into the circle, the hunter peels
## off onto a wider one (HUNTER_R) LAG behind and above it, and drops under it near the end. The paths are curves in time
## (Hermite pieces and the circle, its radius and height breathing in the middle), the ships' bows along their way,
## banked into the turns. TIMES (the run in ENTER_S, the circling nearest CIRCLE_AIM_S, within CIRCLE_S): for the 1757
## layer's wreck site (heading 150 deg) the hard hit comes ~30 s in, the hand-over ~33 s, the cutter is down ~42 s, the
## hunter gone ~46 s.
## THE FIGHT: volleys every ~3.5 s round the circle, the two ships by turns (the hunter: two balls and a boulder; the
## cutter: three balls), some striking (sparks, splinters, the one light's flash, a jolt), most passing; then, on the
## cutter's run, its stern guns answer, the hunter's GREAT shot climbs away from the fight and strikes the sky
## (tear_point: with a sky_mark beside the giant, TEAR_M out; else GREAT_OVER over the cutter and on), and the hunter's
## hard volley lands all at once (cutter_hit): the cutter lists, burns (a FireFx) and loses way, and is handed to
## WreckFall at the end of its stagger. The hunter turns TURN_AFTER s later and climbs CLIMB_S to where the sky was
## struck, fading over its last FADE_S (hunter_gone). The cutter down: the one light's flash and a burst of sparks over
## the pines (the wreck's own light is too small to be seen from the camp).
## THE SHOT (no Projectile physics, no powder smoke): balls driven by Gust (white-hot, cold-edged; a ring of wind at the
## muzzle) and boulders thrown by the Sway (gold, as the keelstone's glow); each a bright core (a billboard, its size kept
## for the eye at any distance) and a short trail (one quad along its way, turned to the eye), sagging a little; aimed
## where the target will be (the paths are known), hits on the hull, misses passing 14-30 m off and fading. Sounds by the
## existing Sfx (a deep boom and a gust at the guns, heavy thuds and cracking wood at the hits, a great crack at the sky),
## each arriving after the distance's delay (343 m/s) and carried far (its voice's reach opened up). The sky struck: the
## great flash and the shot's embers falling; the first crack itself (SkyTear) is the shock.
## BUDGET (the owner, 2026-10-02: "the sky galleon fighting is laggy"): one light (the flashes' OmniLight3D, no shadow,
## moved to each flash; out between them), one flash glow, at most MAX_SHOTS shots (a core and a trail each), at most
## MAX_FX effects (rings, sparks, splinters); small GPU particle bursts. Everything it shows is made ONCE as it is made
## (POOLS: the shots' cores and trails, the rings, the spark and splinter systems, each with its own process material
## and the one shared colour ramp; meshes, materials and textures shared) and reused: a hit makes no node, material or
## texture (a burst takes the pool's free system, or its oldest); each kind is played once unseen in front of the camera
## as the battle is made (_warm_up, as Fx.warm_up: the shaders compiled before the first volley; windowed only). The
## ships draw their far mesh (Galleon_LOD1) past LOD_M (from the camp they are 450-1000 m off: always), never cast
## shadows; their meshes are listed once. The models come through BackgroundLoad (preload_models: no load as it begins
## or as the cutter lands), and the wreck's two people are built ahead (prepare, during the fire talk; else while the
## ships come in, PEOPLE_AT), hidden and at rest, and handed to the fall: not built on the landing's frame. Our own designs: the ships are the project's
## galleon (assets/sky/sky_galleon.glb) and hunter (assets/sky/sky_hunter.glb; until it exists, the galleon tinted dark
## with a cold keel glow).

signal opened_fire
signal tear_point(dir: Vector3)
signal cutter_hit
signal cutter_falling(wf: WreckFall)
signal hunter_gone
signal finished
## A flash in the fight (0..1: the sky struck is 1) toward `dir` (world, unit, from the camp): for the sky's impact flash.
signal sky_flash(amount: float, dir: Vector3)

enum Phase { ENTER, CIRCLE, RUN, STRICKEN, FALLING, DONE }
enum Kind { BALL, BOULDER, GREAT }

const GROUP := &"sky_battle"
const CUTTER_MODEL := "res://assets/sky/sky_galleon.glb"
const HUNTER_MODEL := "res://assets/sky/sky_hunter.glb"
## The fallback hunter: the galleon's paint times this, its keel glow this colour.
const HUNTER_TINT := Color(0.3, 0.29, 0.33)
const HUNTER_GLOW := Color(0.55, 0.62, 1.0)

## The stage (m, m/s, s; heights over the higher of the camp's and the crash's ground).
const FALL_RUN := 200.0
const FALL_MIN := 140.0
const FALL_BEND := 50.0
const FALL_TURN := 60.0
const FIGHT_M := 460.0
const FIGHT_BEARING := 25.0
const CIRCLE_ALT := 265.0
const RUN_CLIMB := 40.0
const STAGGER_DIP := 6.0
const CIRCLE_R := 100.0
const HUNTER_R := 1.25
const HUNTER_UP := 30.0
const LAG := 0.5 * PI
const V_CIRCLE := 20.0
const V_ENTER := 42.0
const V_RUN := 22.0
const V_FALL := 9.0
const ENTER_S := 6.0
const ENTER_UP := 70.0
const HUNTER_BEHIND := 90.0
const CIRCLE_S := Vector2(14.0, 20.0)
const CIRCLE_AIM_S := 16.0
const RUN_S := 3.5
const STAGGER_S := 3.0
const FALL_S := 9.0
const TURN_AFTER := 0.5
const CLIMB_S := 12.0
const FADE_S := 2.5
const LIST_RAD := 0.28
## The ships' near meshes only within this of the camera (m); their far mesh (Galleon_LOD1) past it.
const LOD_M := 150.0

## The shot, by Kind: speed (m/s), sag (m/s² down: the Sway holds them up), core size (x the eye's size).
const SHOT_SPEED := [135.0, 90.0, 150.0]
const SHOT_SAG := [3.0, 6.0, 0.0]
const SHOT_SIZE := [1.0, 1.5, 2.6]
const MISS_ON := 1.8
const SHOT_FADE := 0.4
const GREAT_ON := 1.7
const GREAT_OVER := 38.0
const MAX_SHOTS := 16
const MAX_FX := 20
## The pools: spark and splinter systems (each burst emits its share of the system's most: amount_ratio), rings.
const SPARK_POOL := 6
const SPLINTER_POOL := 5
const RING_POOL := 8
const SPARK_MAX := 62
const SPARK_MAX_LOW := 34
const SPLINTER_MAX := 18
## When the wreck's people are built ahead (battle clock, s; WreckFall.PEOPLE) when prepare() has not made them.
const PEOPLE_AT := [1.2, 2.4]
## prepare()'s people wait under the level in this node (hidden) for the battle to take.
const PEOPLE_NODE := "SkyBattlePeople"
## The warm-up: frames each kind plays unseen as the battle is made, this far out along the camera's view (out where the
## fight is, away from the camp's lights: drawn as they will be, not as something lit at the fire).
const WARM_FRAMES := 4
const WARM_M := 250.0
const VOLLEY_GAP := 3.5
## A core for the eye: this x its distance from the camera (m), within CORE_M; its trail TRAIL_S of its flight long.
const EYE := 0.018
const CORE_M := Vector2(1.6, 16.0)
const TRAIL_S := 0.28
const BALL_COLOR := Color(0.72, 0.86, 1.0)
const BOULDER_COLOR := Color(1.0, 0.72, 0.34)
const RING_COLOR := Color(0.7, 0.82, 1.0)
const FLASH_COLOR := Color(1.0, 0.72, 0.42)
const FLASH_ENERGY := 12.0
const FLASH_RANGE := 110.0
const TICK_S := 0.25
## With a sky mark: the sky struck this far (deg) beside it toward the fight, this far (m) from the camp, its height
## over the horizon held within TEAR_ALT (deg).
const TEAR_BESIDE_DEG := 15.0
const TEAR_M := 950.0
const TEAR_ALT := Vector2(22.0, 70.0)
## The cutter down: the flash this high over where it lies (over the pines' tops, seen from the camp).
const LAND_FLASH_UP := 16.0

## The clock x this (tests).
var speed := 1.0
var camp := Vector3.ZERO
var crash_at := Vector3.ZERO
var heading := WreckFall.DEFAULT_HEADING
var quality := "medium"
var phase := Phase.ENTER
## Seconds since begin (x speed).
var clock := 0.0
var cutter: Node3D
var hunter: Node3D
## The hunter's model (HUNTER_MODEL, or CUTTER_MODEL tinted when there is none yet).
var hunter_model := ""
var wreck_fall: WreckFall
## Where the sky was struck (world) and the way to it from the camp (unit); ZERO until then.
var tear_at := Vector3.ZERO
var tear_dir := Vector3.ZERO
## The way from the camp to the wonder's giant (opts sky_mark; ZERO: none).
var sky_mark := Vector3.ZERO
## The one light.
var light: OmniLight3D
## The beats' times (battle clock): the circle's start and end, the hard hit, the hand-over, the hunter's turn, its going.
var t_circle := 0.0
var t_run := 0.0
var t_hit := 0.0
var t_fall := 0.0
var t_turn := 0.0
var t_gone := 0.0
var stats := {"volleys": 0, "shots": 0, "hits_cutter": 0, "hits_hunter": 0, "max_shot_nodes": 0, "max_fx": 0}

var _level: Node
var _rng := RandomNumberGenerator.new()
var _shots_root: Node3D
var _fx_root: Node3D
var _shots: Array[_Shot] = []
var _fx: Array[Dictionary] = []
var _volleys: Array[Dictionary] = []
var _vi := 0
var _sounds: Array = []                  ## [seconds left (real), id, at, gain_db, pitch, unit size]
var _sent := {}
var _landed := false
var _gone := false
var _climb_set := false
var _flash_glow: MeshInstance3D
var _flash := 0.0
var _flash_size := 10.0
var _flash_rate := 7.0                  ## the flash's decay (1/s): a hit's quick, the landing's slow
var _tick := 0.0
var _dim := 1.0
var _cutter_fire: FireFx
var _roll := [0.0, 0.0]
var _last_roll := [0.0, 0.0]
var _shake := [0.0, 0.0]
var _vel := [Vector3.ZERO, Vector3.ZERO]
var _geos := [[], []]
var _glow_mats := [[], []]
var _has_lod := [false, false]
var _near := [[], []]                   ## each ship's near meshes, and its far one (Galleon_LOD1): listed once
var _far := [[], []]
var _lod_far := [-1, -1]                ## which shows now (-1: not yet set)
# the pools (made once in _ready): idle ones hidden; _busy: a pooled node in use -> the clock it was taken at
var _spark_pool: Array[GPUParticles3D] = []
var _splinter_pool: Array[GPUParticles3D] = []
var _ring_pool: Array[MeshInstance3D] = []
var _core_pool: Array[MeshInstance3D] = []
var _trail_pool: Array[MeshInstance3D] = []
var _busy := {}
var _warm_left := 0
var _warm: Array[Node] = []
## The wreck's two people (Rook, Ithel) built ahead while the ships come in (PEOPLE_AT s: one in a frame, before the first
## volley), hidden, for the fall (WreckFall.begin_from's people): not built as the cutter lands.
var _people := {}
## Each ship's guns (its Muzzle_P* / Muzzle_S* empties, port and starboard, local, bow to stern), when its model has them.
var _muzzles := [{"P": [], "S": []}, {"P": [], "S": []}]
# the plan
var _y0 := 0.0
var _fwd := Vector3.FORWARD
var _g := Vector3.FORWARD               ## the cutter's course into its fall (from the fall's start toward the crash)
var _c := Vector3.ZERO
var _s := 1.0
var _r := CIRCLE_R
var _omega := 0.1
var _phi_i := 0.0
var _tc := 38.0
var _to_camp := Vector3.BACK
var _e := Vector3.ZERO
var _ve := Vector3.ZERO
var _h := Vector3.ZERO
var _vh := Vector3.ZERO
var _k := Vector3.ZERO
var _vk := Vector3.ZERO
var _s0c := Vector3.ZERO
var _v0c := Vector3.ZERO
var _pc_in := Vector3.ZERO
var _vc_in := Vector3.ZERO
var _s0h := Vector3.ZERO
var _v0h := Vector3.ZERO
var _ph_in := Vector3.ZERO
var _vh_in := Vector3.ZERO
var _climb := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _tear_plan := Vector3.ZERO           ## where the great shot will strike (with a sky mark), ZERO otherwise


## One shot in flight: where and when it left, its velocity and sag; whether it strikes its mark at `arrive` (seconds
## after it left) or passes and fades at `life`; "tear" (the great shot: it strikes the sky at `life`), "hard" (the
## cutter's ruin).
class _Shot:
	var core: MeshInstance3D
	var trail: MeshInstance3D
	var kind := 0
	var p0 := Vector3.ZERO
	var v := Vector3.ZERO
	var sag := 0.0
	var t0 := 0.0
	var arrive := 1.0
	var life := 1.0
	var hits := false
	var target := 0
	var mark := Vector3.ZERO
	var event := ""

	func at(tau: float) -> Vector3:
		return p0 + v * tau + Vector3.DOWN * (0.5 * sag * tau * tau)

	func vel(tau: float) -> Vector3:
		return v + Vector3.DOWN * (sag * tau)


# --- The API ----------------------------------------------------------------------------------------------------

## The battle over `level`, seen from `camp`, the cutter coming down at `crash_at` (on the ground there). One at a time:
## one there already is taken away.
static func begin(level: Node, p_camp: Vector3, p_crash: Vector3, opts := {}) -> SkyBattle:
	if level == null or not level.is_inside_tree():
		push_warning("SkyBattle: no level")
		return null
	var old := find(level.get_tree())
	if old != null:
		old.remove_from_group(GROUP)
		old.queue_free()
	var sb := SkyBattle.new()
	sb.name = "SkyBattle"
	sb._level = level
	sb.camp = p_camp
	sb.crash_at = p_crash
	var h := float(opts.get("heading", NAN))
	sb.heading = h if not is_nan(h) else WreckFall.DEFAULT_HEADING
	sb.speed = maxf(float(opts.get("speed", 1.0)), 0.01)
	sb._rng.seed = int(opts.get("seed", 1757))
	var s: Variant = level.get("settings")
	if s is WorldSettings:
		sb.quality = (s as WorldSettings).quality
	sb.quality = String(opts.get("quality", sb.quality))
	var mk: Variant = opts.get("sky_mark")
	if mk is Vector3 and (mk as Vector3).length_squared() > 0.5:
		sb.sky_mark = (mk as Vector3).normalized()
	level.add_child(sb)
	return sb


static func find(tree: SceneTree) -> SkyBattle:
	return tree.get_first_node_in_group(GROUP) as SkyBattle if tree else null


## The ships' and the wreck's models loading on a worker thread now (BackgroundLoad: once; nothing when loaded), so the
## battle's begin and the cutter's landing do not load them.
static func preload_models() -> void:
	for p: String in [CUTTER_MODEL, HUNTER_MODEL, WreckFall.WRECK_MODEL]:
		if ResourceLoader.exists(p):
			BackgroundLoad.request(p)


## The battle to come made ready while nothing moves (Two Fires begins: the fire talk is open): its models on their way
## (preload_models) and the wreck's two people (WreckFall.PEOPLE) built, one now and one the next frame, hidden and at
## rest under the level (PEOPLE_NODE), for the battle to take as it begins. Once (nothing while they wait).
static func prepare(level: Node) -> void:
	preload_models()
	if level == null or not level.is_inside_tree() or level.get_node_or_null(PEOPLE_NODE) != null:
		return
	var holder := Node3D.new()
	holder.name = PEOPLE_NODE
	level.add_child(holder)
	_prepare_one(holder.get_instance_id(), 0)


static func _prepare_one(holder_id: int, i: int) -> void:
	var holder := instance_from_id(holder_id) as Node3D
	if holder == null or not holder.is_inside_tree() or i >= WreckFall.PEOPLE.size():
		return
	var nm: String = WreckFall.PEOPLE[i]
	if holder.get_node_or_null(nm) == null:
		WreckFall.prebuild_body(holder, nm, Vector3(0.0, -60.0, 0.0))
	holder.get_tree().process_frame.connect(_prepare_one.bind(holder_id, i + 1), CONNECT_ONE_SHOT)


## Where the fight is now: between the two ships, the falling one, the hunter, the wreck.
func focus() -> Vector3:
	if wreck_fall != null and is_instance_valid(wreck_fall):
		if wreck_fall.ship != null and is_instance_valid(wreck_fall.ship):
			return wreck_fall.ship.global_position
	if cutter != null and hunter != null:
		return (cutter.global_position + hunter.global_position) * 0.5
	if hunter != null:
		return hunter.global_position
	if wreck_fall != null and is_instance_valid(wreck_fall):
		return wreck_fall.frame.origin
	return _c


## Where the sky is struck (the tear's point, world): where it was, else where the great shot will strike it.
func tear_aim() -> Vector3:
	if tear_at != Vector3.ZERO:
		return tear_at
	return _default_tear()


## Live shot nodes (cores and trails) and effects now (the pools' idle ones not counted).
func shot_nodes() -> int:
	return _shots.size() * 2


func fx_nodes() -> int:
	return _fx.size()


## The pools' sizes (made once as the battle is made: tests).
func pool_sizes() -> Dictionary:
	return {"sparks": _spark_pool.size(), "splinters": _splinter_pool.size(), "rings": _ring_pool.size(),
			"cores": _core_pool.size(), "trails": _trail_pool.size()}


## All of it over at once: whatever has not happened yet happens now, in order (the sky struck, the cutter hit and
## fallen, the wreck down, the hunter gone).
func skip() -> void:
	if phase == Phase.DONE:
		return
	while not _shots.is_empty():
		_drop_shot(_shots.size() - 1)
	_vi = _volleys.size()
	_send(&"opened_fire")
	if not _sent.has(&"tear_point"):
		_strike_at(_default_tear(), false)
	if not _sent.has(&"cutter_hit"):
		_send(&"cutter_hit")
	if phase < Phase.FALLING:
		clock = maxf(clock, t_fall)
		_hand_over()
	if wreck_fall != null and is_instance_valid(wreck_fall):
		wreck_fall.skip()
	_landed = true
	if not _gone:
		_vanish()
	_check_done()


# --- Making it ----------------------------------------------------------------------------------------------------

func _ready() -> void:
	add_to_group(GROUP)
	_shots_root = Node3D.new()
	_shots_root.name = "Shots"
	add_child(_shots_root)
	_fx_root = Node3D.new()
	_fx_root.name = "Fx"
	add_child(_fx_root)
	_plan()
	_make_ships()
	light = OmniLight3D.new()
	light.name = "BattleLight"
	light.light_color = FLASH_COLOR
	light.light_energy = 0.0
	light.omni_range = FLASH_RANGE
	light.omni_attenuation = 1.0
	light.shadow_enabled = false
	light.light_specular = 0.2
	light.light_volumetric_fog_energy = 0.0
	light.visible = false
	add_child(light)
	_flash_glow = MeshInstance3D.new()
	_flash_glow.name = "FlashGlow"
	_flash_glow.mesh = _quad()
	_flash_glow.material_override = _mat("flash")
	_flash_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_glow.visible = false
	add_child(_flash_glow)
	_make_pools()
	_take_people()
	if ResourceLoader.exists(WreckFall.WRECK_MODEL):
		BackgroundLoad.request(WreckFall.WRECK_MODEL)  # (for the landing: WreckFall takes it there)
	_dim = Fx._fire_dim(self)
	_warm_up()
	_colors()
	if cutter:
		_pose_ship(0, 0.0)
	if hunter:
		_pose_ship(1, 0.0)
	_lods(true)


## The stage from the crash point back (see the header): the fall's start K, the hit H, the way out of the circle E, the
## circle, the two entries, the run and the stagger; then the volleys.
func _plan() -> void:
	_fwd = Vector3(-sin(heading), 0.0, -cos(heading))
	var gc := FrontierTerrain.height_at(crash_at.x, crash_at.z)
	_y0 = maxf(gc, FrontierTerrain.height_at(camp.x, camp.z))
	crash_at.y = gc
	var flat := Vector3(crash_at.x, 0.0, crash_at.z)
	var ey := _y0 + CIRCLE_ALT
	var stagger := (V_RUN + V_FALL) * 0.5 * STAGGER_S
	var run := (V_CIRCLE + V_RUN) * 0.5 * RUN_S
	# the fight's circle round a middle near FIGHT_M off the camp toward FIGHT_BEARING (north-east); the way out of it
	# where its tangent, run on for the run and the stagger, ends at the fall's start: FALL_RUN or so short of the crash
	# over the ground (at least FALL_MIN), its course at most FALL_BEND off the way to the crash and that at most FALL_TURN
	# off the heading (WreckFall's curve bends it in); the circling nearest CIRCLE_AIM_S
	var best := INF
	var sweep_all := TAU
	var chain := stagger + run
	for dm in range(-6, 7):
		var m := FIGHT_M + 20.0 * dm
		for db in range(-4, 5):
			var b := deg_to_rad(FIGHT_BEARING + 5.0 * db)
			var c := Vector3(camp.x + sin(b) * m, 0.0, camp.z - cos(b) * m)
			var tc := Vector3(camp.x - c.x, 0.0, camp.z - c.z).normalized()
			var near := absf(5.0 * db) / 8.0 + absf(20.0 * dm) / 50.0
			for s: float in [1.0, -1.0]:
				var phi := atan2(-s * tc.x, s * tc.z)
				for pe in 36:
					var ph := TAU * pe / 36.0
					var g := Vector3(-sin(ph), 0.0, cos(ph)) * s
					var k := c + Vector3(cos(ph), 0.0, sin(ph)) * CIRCLE_R + g * chain
					var to := flat - k
					var hd := to.length()
					if hd < FALL_MIN:
						continue
					var b1 := g.angle_to(to)
					var b2 := to.angle_to(_fwd)
					if b1 > deg_to_rad(FALL_BEND) or b2 > deg_to_rad(FALL_TURN):
						continue
					var place := near + rad_to_deg(b1) / 20.0 + rad_to_deg(b2) / 30.0 + absf(hd - FALL_RUN) / 60.0
					if place >= best:
						continue
					var d := fposmod(s * (ph - phi), TAU)
					for n in 3:
						var sweep := d + TAU * n
						var score := place + absf(sweep / (V_CIRCLE / CIRCLE_R) - CIRCLE_AIM_S) / 6.0
						if score < best:
							best = score
							_g = g
							_k = k
							_e = k - g * chain
							_s = s
							_c = c
							_phi_i = phi
							_to_camp = tc
							sweep_all = sweep
	if best == INF:
		# (a crash the fight cannot lead into from the camp's north-east: straight in along the heading, the circle behind)
		_g = _fwd
		_k = flat - _fwd * FALL_RUN
		_e = _k - _g * chain
		_s = 1.0
		var phe := atan2(-_g.x, _g.z)
		_c = _e - Vector3(cos(phe), 0.0, sin(phe)) * CIRCLE_R
		_to_camp = Vector3(camp.x - _c.x, 0.0, camp.z - _c.z)
		_to_camp = _to_camp.normalized() if _to_camp.length() > 1.0 else -_fwd
		_phi_i = atan2(-_to_camp.x, _to_camp.z)
		sweep_all = fposmod(phe - _phi_i, TAU) + TAU
	_k.y = ey + RUN_CLIMB - STAGGER_DIP
	_h = _k - _g * stagger
	_h.y = ey + RUN_CLIMB
	_e.y = ey
	_c.y = ey
	_r = CIRCLE_R
	_plan_tear()
	_tc = clampf(sweep_all / (V_CIRCLE / CIRCLE_R), CIRCLE_S.x, CIRCLE_S.y)
	_omega = sweep_all / _tc
	t_circle = ENTER_S
	t_run = t_circle + _tc
	t_hit = t_run + RUN_S
	t_fall = t_hit + STAGGER_S
	t_turn = t_fall + TURN_AFTER
	t_gone = t_turn + CLIMB_S
	# the entries: both from the far side, heading for the camp; the hunter behind, turning onto its own circle
	var v_circ := _r * _omega
	_pc_in = _cutter_circle(t_circle)
	_vc_in = _to_camp * v_circ
	var enter_from := (V_ENTER + v_circ) * 0.5 * ENTER_S * 1.05
	_s0c = _pc_in - _to_camp * enter_from + Vector3.UP * ENTER_UP
	_v0c = _to_camp * V_ENTER + Vector3.DOWN * (ENTER_UP / ENTER_S)
	_ph_in = _hunter_circle(t_circle)
	var phh := _phi_i - _s * LAG
	_vh_in = Vector3(-sin(phh), 0.0, cos(phh)) * (_s * _r * HUNTER_R * _omega)
	_s0h = _ph_in - _to_camp * (enter_from + HUNTER_BEHIND) + Vector3.UP * (ENTER_UP + 30.0)
	_v0h = _to_camp * V_ENTER * 1.1 + Vector3.DOWN * ((ENTER_UP + 30.0) / ENTER_S)
	# the run out of the circle (climbing) and the stagger after the hit (losing way, dipping)
	_ve = _g * v_circ
	_vh = _g * V_RUN + Vector3.UP * (RUN_CLIMB / RUN_S * 0.8)
	_vk = _g * V_FALL + Vector3.DOWN * 3.0
	_plan_volleys()


## Where the great shot will strike the sky: with a sky mark (the giant), TEAR_BESIDE_DEG off it toward the fight and TEAR_M
## from the camp, its height over the horizon within TEAR_ALT (the break opens beside the giant: the shards fall away over
## it first); without one nothing is planned (the shot passes over the cutter and strikes where it gets to).
func _plan_tear() -> void:
	_tear_plan = Vector3.ZERO
	if sky_mark.length_squared() < 0.5:
		return
	var m := sky_mark.normalized()
	var fight := (_c - camp).normalized()
	var ang := m.angle_to(fight)
	var dir := m
	if ang > 0.001:
		dir = m.slerp(fight, minf(deg_to_rad(TEAR_BESIDE_DEG) / ang, 1.0)).normalized()
	var el := clampf(asin(clampf(dir.y, -1.0, 1.0)), deg_to_rad(TEAR_ALT.x), deg_to_rad(TEAR_ALT.y))
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3(fight.x, 0.0, fight.z)
	flat = flat.normalized()
	_tear_plan = camp + (flat * cos(el) + Vector3.UP * sin(el)) * TEAR_M


## The volleys: a ranging pair in the chase; round the circle by turns; on the run the cutter's stern guns, the hunter's
## great shot (over the cutter, into the sky) and its hard volley (timed to land at t_hit).
func _plan_volleys() -> void:
	_volleys.clear()
	_volleys.append({"t": ENTER_S * 0.6, "from": 1, "kinds": [Kind.BALL, Kind.BALL], "hits": [false, false]})
	var a := t_circle + 2.5
	var b := t_run - 1.5
	var n := maxi(int((b - a) / VOLLEY_GAP), 4)
	for i in n + 1:
		var t := lerpf(a, b, float(i) / n) + _rng.randf_range(-0.5, 0.5)
		var from := 1 if i % 2 == 0 else 0
		var kinds: Array = [Kind.BALL, Kind.BOULDER, Kind.BALL] if from == 1 else [Kind.BALL, Kind.BALL, Kind.BALL]
		var hits: Array = []
		for j in kinds.size():
			hits.append(_rng.randf() < (0.4 if from == 1 else 0.33))
		if i == 2 or i == 3 or i == n - 1:
			hits[1] = true                      # (each ship struck a few times for sure: sparks to see)
		_volleys.append({"t": t, "from": from, "kinds": kinds, "hits": hits})
	# the great shot: fired so it strikes the sky a second before the hard volley lands (the break first, then the ruin)
	var tg := t_hit - 1.0
	var t_great := 0.0
	if _tear_plan != Vector3.ZERO:
		var fly := _hunter_pos(tg - 3.5).distance_to(_tear_plan) / float(SHOT_SPEED[Kind.GREAT])
		fly = _hunter_pos(tg - fly).distance_to(_tear_plan) / float(SHOT_SPEED[Kind.GREAT])
		t_great = maxf(tg - fly, t_run - 6.0)
	else:
		var reach := _hunter_pos(tg - GREAT_ON - 2.5).distance_to(_cutter_pos(tg - GREAT_ON) + Vector3.UP * GREAT_OVER)
		t_great = maxf(tg - GREAT_ON - reach / float(SHOT_SPEED[Kind.GREAT]), t_run - 1.0)
	_volleys.append({"t": t_great, "from": 1, "kinds": [Kind.BALL, Kind.GREAT, Kind.BALL], "hits": [false, false, false]})
	_volleys.append({"t": t_run + 2.2, "from": 0, "kinds": [Kind.BALL, Kind.BALL], "hits": [true, false]})
	var lead := _hunter_pos(t_hit - 1.6).distance_to(_cutter_pos(t_hit)) / float(SHOT_SPEED[Kind.BALL])
	_volleys.append({"t": t_hit - clampf(lead, 0.8, 3.0), "from": 1, "kinds": [Kind.BALL, Kind.BOULDER, Kind.BALL, Kind.BALL],
			"hits": [true, true, true, true], "arrive": t_hit, "hard": true})
	_volleys.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.t) < float(y.t))


func _make_ships() -> void:
	var cs := BackgroundLoad.take(CUTTER_MODEL) as PackedScene if ResourceLoader.exists(CUTTER_MODEL) else null
	if cs != null:
		cutter = cs.instantiate() as Node3D
		cutter.name = "Cutter"
		add_child(cutter)
		_dress(cutter, 0, false)
	var hs := BackgroundLoad.take(HUNTER_MODEL) as PackedScene if ResourceLoader.exists(HUNTER_MODEL) else null
	hunter_model = HUNTER_MODEL
	if hs == null:
		hs = cs
		hunter_model = CUTTER_MODEL
	if hs != null:
		hunter = hs.instantiate() as Node3D
		hunter.name = "Hunter"
		add_child(hunter)
		_dress(hunter, 1, hunter_model != HUNTER_MODEL)
	if cutter == null or hunter == null:
		push_warning("SkyBattle: no %s; the fight goes on without its ships" % CUTTER_MODEL)


## A ship's meshes: no shadows (too high to shade the valley), its keel glow its own to breathe; the fallback hunter's
## paint darkened and its glow cold.
func _dress(n: Node3D, i: int, tint: bool) -> void:
	var dup := {}
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(_geos[i] as Array).append(g)
		var m := g as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		if "LOD1" in String(m.name):
			_has_lod[i] = true
			(_far[i] as Array).append(m)
		else:
			(_near[i] as Array).append(m)
		for si in m.mesh.get_surface_count():
			var mat := m.get_active_material(si) as StandardMaterial3D
			if mat == null:
				continue
			var glow := String(mat.resource_name).begins_with("EtheriumGlow")
			if not glow and not tint:
				continue
			if not dup.has(mat):
				var d := mat.duplicate() as StandardMaterial3D
				if tint and glow:
					d.emission = HUNTER_GLOW
					d.albedo_color = d.albedo_color * HUNTER_GLOW
				elif tint:
					d.albedo_color = d.albedo_color * HUNTER_TINT
				dup[mat] = d
				if glow:
					(_glow_mats[i] as Array).append(d)
			m.set_surface_override_material(si, dup[mat])
	for c in n.find_children("Muzzle_*", "Node3D", true, false):
		var sd := String(c.name).substr(7, 1)
		if (_muzzles[i] as Dictionary).has(sd):
			((_muzzles[i] as Dictionary)[sd] as Array).append(n.to_local((c as Node3D).global_position))
	for sd: String in ["P", "S"]:
		((_muzzles[i] as Dictionary)[sd] as Array).sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z < b.z)


# --- The paths ------------------------------------------------------------------------------------------------------

static func _hermite(p0: Vector3, v0: Vector3, p1: Vector3, v1: Vector3, dur: float, x: float) -> Vector3:
	var x2 := x * x
	var x3 := x2 * x
	return p0 * (2.0 * x3 - 3.0 * x2 + 1.0) + v0 * (dur * (x3 - 2.0 * x2 + x)) + p1 * (3.0 * x2 - 2.0 * x3) \
			+ v1 * (dur * (x3 - x2))


## 0 at the circling's ends (and outside it), 1 in its middle, flat at the ends: the breathing's weight.
static func _window(u: float) -> float:
	if u <= 0.0 or u >= 1.0:
		return 0.0
	var s := sin(PI * u)
	return s * s


func _cutter_circle(t: float) -> Vector3:
	var u := (t - t_circle) / _tc
	var w := _window(u)
	var ph := _phi_i + _s * _omega * (t - t_circle)
	var rr := _r * (1.0 + 0.12 * sin(TAU * u * 1.5) * w)
	return Vector3(_c.x + rr * cos(ph), _e.y + 18.0 * sin(TAU * u * 2.0) * w, _c.z + rr * sin(ph))


func _hunter_circle(t: float) -> Vector3:
	var u := (t - t_circle) / _tc
	var w := _window(u)
	var ph := _phi_i + _s * (_omega * (t - t_circle) - LAG)
	var rr := _r * HUNTER_R * (1.0 + 0.1 * sin(TAU * u * 1.2 + 2.0) * w)
	var y := _e.y + HUNTER_UP * (1.0 - 2.0 * smoothstep(0.7, 1.0, u)) + 15.0 * sin(TAU * u * 2.0 + 1.7) * w
	return Vector3(_c.x + rr * cos(ph), y, _c.z + rr * sin(ph))


## The cutter at `t` (battle clock): the run in, the circle, the run out, the stagger (held at its end after).
func _cutter_pos(t: float) -> Vector3:
	if t < t_circle:
		return _hermite(_s0c, _v0c, _pc_in, _vc_in, ENTER_S, t / ENTER_S)
	if t < t_run:
		return _cutter_circle(t)
	if t < t_hit:
		return _hermite(_e, _ve, _h, _vh, RUN_S, (t - t_run) / RUN_S)
	return _hermite(_h, _vh, _k, _vk, STAGGER_S, minf((t - t_hit) / STAGGER_S, 1.0))


## The hunter at `t`: the run in, its circle (on past the cutter's way out), its climb once planned.
func _hunter_pos(t: float) -> Vector3:
	if t < t_circle:
		return _hermite(_s0h, _v0h, _ph_in, _vh_in, ENTER_S, t / ENTER_S)
	if t < t_turn or not _climb_set:
		return _hunter_circle(t)
	return _hermite(_climb[0], _climb[1], _climb[2], _climb[3], CLIMB_S, minf((t - t_turn) / CLIMB_S, 1.0))


func _pos(i: int, t: float) -> Vector3:
	return _cutter_pos(t) if i == 0 else _hunter_pos(t)


## A ship's frame at `t` from its path alone (its bow along its way, no roll): for aiming.
func _pose_at(i: int, t: float) -> Transform3D:
	var p := _pos(i, t)
	var d := _pos(i, t + 0.1) - _pos(i, t - 0.1)
	d.y *= 0.7
	return Transform3D(Basis.looking_at(d.normalized() if d.length() > 0.001 else _fwd, Vector3.UP), p)


func _ship_xf(i: int) -> Transform3D:
	var n := cutter if i == 0 else hunter
	return n.global_transform if n != null and is_instance_valid(n) else _pose_at(i, clock)


## The ship on its path now: bow along its way (its pitch softened), banked into the turn (eased), the cutter listing to
## port once struck, jolted by hits.
func _pose_ship(i: int, dt: float) -> void:
	var n := cutter if i == 0 else hunter
	var hh := 0.12
	var pa := _pos(i, clock - hh)
	var pb := _pos(i, clock)
	var pc := _pos(i, clock + hh)
	var v := (pc - pa) / (2.0 * hh)
	var acc := (pc - pb * 2.0 + pa) / (hh * hh)
	_vel[i] = v
	var dir := v
	dir.y *= 0.7
	dir = dir.normalized() if dir.length() > 0.001 else _fwd
	var b := Basis.looking_at(dir, Vector3.UP)
	var want := clampf(-atan(acc.dot(b.x) / 9.8), -0.5, 0.5)
	if i == 0 and _sent.has(&"cutter_hit"):
		want += LIST_RAD * smoothstep(t_hit, t_hit + 1.5, clock)
	_roll[i] = lerpf(float(_roll[i]), want, 1.0 - exp(-dt * 2.5)) if dt > 0.0 else want
	_shake[i] = move_toward(float(_shake[i]), 0.0, dt * 1.6)
	var sh := float(_shake[i])
	var roll := float(_roll[i]) + 0.025 * sin(clock * 0.7 + i * 2.0) + 0.08 * sh * sin(clock * 21.0)
	_last_roll[i] = roll
	b = b * Basis(Vector3.RIGHT, 0.06 * sh * sin(clock * 17.0 + 1.0)) * Basis(Vector3(0, 0, 1), roll)
	if i == 1 and clock > t_gone - FADE_S:
		b = b * Basis.from_scale(Vector3.ONE * lerpf(1.0, 0.55, clampf((clock - (t_gone - FADE_S)) / FADE_S, 0.0, 1.0)))
	if n != null:
		n.global_transform = Transform3D(b, pb)


# --- Running it ---------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var dt := delta * speed
	clock += dt
	if _warm_left > 0:
		_warm_left -= 1
		if _warm_left == 0:
			_warm_done()
	if phase < Phase.FALLING and _people.size() < WreckFall.PEOPLE.size() and clock >= float(PEOPLE_AT[_people.size()]):
		for nm: String in WreckFall.PEOPLE:
			if not _people.has(nm):
				_people[nm] = WreckFall.prebuild_body(self, nm, crash_at + Vector3.DOWN * 2.0)
				break
	_sound_queue(delta)
	while _vi < _volleys.size() and float(_volleys[_vi].t) <= clock:
		_fire(_volleys[_vi])
		_vi += 1
	if phase < Phase.FALLING:
		phase = Phase.ENTER if clock < t_circle else (Phase.CIRCLE if clock < t_run else
				(Phase.RUN if not _sent.has(&"cutter_hit") else Phase.STRICKEN))
		if cutter != null:
			_pose_ship(0, dt)
		if clock >= t_fall:
			_hand_over()
	if not _climb_set and clock >= t_turn:
		_plan_climb()
	if hunter != null:
		_pose_ship(1, dt)
		if clock >= t_gone - FADE_S:
			var f := clampf((clock - (t_gone - FADE_S)) / FADE_S, 0.0, 1.0)
			for g: GeometryInstance3D in _geos[1]:
				if is_instance_valid(g):
					g.transparency = f
	if not _gone and clock >= t_gone:
		_vanish()
	_update_shots()
	_update_fx()
	_update_flash(dt)
	_tick -= dt
	if _tick <= 0.0:
		_tick = TICK_S
		_slow_tick()
	if phase == Phase.FALLING and not _landed:
		if wreck_fall == null or not is_instance_valid(wreck_fall) or wreck_fall.is_landed():
			_landed = true
	_check_done()
	if phase == Phase.DONE and _shots.is_empty() and _fx.is_empty() and _sounds.is_empty() and _flash <= 0.01:
		remove_from_group(GROUP)
		queue_free()


## A volley from one ship at the other: each shot from a gun on the side facing it (the model's Muzzle_* empties, else
## along its waist), aimed where the target will be (a
## hit on its hull, a miss passing off it, the great shot over it), a ring of wind at each muzzle, the guns' boom.
func _fire(vo: Dictionary) -> void:
	var from := int(vo.from)
	var target := 1 - from
	if (from == 0 or target == 0) and phase >= Phase.FALLING:
		return
	if (from == 1 or target == 1) and clock >= t_turn:
		return
	stats["volleys"] = int(stats["volleys"]) + 1
	_send(&"opened_fire")
	var xf := _ship_xf(from)
	var tp := _pos(target, clock)
	var side := signf(xf.basis.x.dot(tp - xf.origin))
	if side == 0.0:
		side = 1.0
	var kinds: Array = vo.kinds
	var hits: Array = vo.hits
	for j in kinds.size():
		if _shots.size() >= MAX_SHOTS:
			break
		var kind := int(kinds[j])
		var guns: Array = (_muzzles[from] as Dictionary)["S" if side > 0.0 else "P"]
		var gun: Vector3 = guns[mini(int((j + 0.5) / kinds.size() * guns.size()), guns.size() - 1)] if not guns.is_empty() \
				else Vector3(side * 3.9, 3.0, lerpf(-7.0, 7.0, (j + 0.5) / kinds.size()))
		var muzzle: Vector3 = xf * gun
		var tt := 0.0
		if vo.has("arrive"):
			tt = maxf(float(vo.arrive) + 0.14 * j - clock, 0.3)
		elif kind == Kind.GREAT and _tear_plan != Vector3.ZERO:
			tt = maxf(muzzle.distance_to(_tear_plan) / float(SHOT_SPEED[kind]), 0.3)   # (straight to the sky's point)
		else:
			tt = _lead(muzzle, target, float(SHOT_SPEED[kind]))
		var ta := clock + tt
		var hit := bool(hits[j])
		var event := ""
		var mark: Vector3
		if kind == Kind.GREAT:
			mark = _tear_plan if _tear_plan != Vector3.ZERO else _pos(target, ta) + Vector3.UP * GREAT_OVER
			event = "tear"
		elif hit:
			mark = _pose_at(target, ta) * Vector3(_rng.randf_range(-2.5, 2.5), _rng.randf_range(1.5, 5.0), _rng.randf_range(-9.0, 9.0))
			event = "hard" if vo.has("hard") else ""
		else:
			var base := _pos(target, ta)
			var los := (base - muzzle).normalized()
			var across := los.cross(Vector3.UP)
			across = across.normalized() if across.length() > 0.01 else Vector3.RIGHT
			var up := _rng.randf_range(8.0, 25.0) * (1.0 if _rng.randf() < 0.7 else -0.6)
			mark = base + across * (_rng.randf_range(-1.0, 1.0) * _rng.randf_range(14.0, 30.0)) + Vector3.UP * up
		_launch(kind, muzzle, mark, tt, hit, target, event)
	_sound(&"musket_tail_fort", xf.origin, 12.0, 0.32, 160.0)
	_sound(&"arrow_whoosh", xf.origin, 14.0, 0.42, 120.0)


## Seconds a shot from `muzzle` at `spd` takes to meet the target (where it will be by then).
func _lead(muzzle: Vector3, target: int, spd: float) -> float:
	var tt := _pos(target, clock).distance_to(muzzle) / spd
	for k in 3:
		tt = _pos(target, clock + tt).distance_to(muzzle) / spd
	return maxf(tt, 0.2)


func _launch(kind: int, p0: Vector3, mark: Vector3, tt: float, hits: bool, target: int, event: String) -> void:
	var s := _Shot.new()
	s.kind = kind
	s.p0 = p0
	s.t0 = clock
	s.arrive = tt
	s.hits = hits
	s.target = target
	s.mark = mark
	s.event = event
	s.sag = float(SHOT_SAG[kind])
	s.v = (mark - p0) / tt + Vector3.UP * (0.5 * s.sag * tt)
	var on := GREAT_ON if _tear_plan == Vector3.ZERO else 0.0     # (planned: it strikes the sky's point itself)
	s.life = tt + (on if event == "tear" else (0.0 if hits else MISS_ON))
	s.core = _take(_core_pool) as MeshInstance3D
	s.trail = _take(_trail_pool) as MeshInstance3D
	if s.core == null or s.trail == null:
		_release(s.core)
		_release(s.trail)
		return
	s.core.material_override = _mat("core%d" % mini(kind, 1))
	s.trail.material_override = _mat("trail%d" % mini(kind, 1))
	for m: MeshInstance3D in [s.core, s.trail]:
		m.transparency = 0.0
		m.global_transform = Transform3D(Basis.IDENTITY, p0)
		m.visible = true
	_shots.append(s)
	stats["shots"] = int(stats["shots"]) + 1
	stats["max_shot_nodes"] = maxi(int(stats["max_shot_nodes"]), shot_nodes())
	_ring(p0, s.v.normalized())


func _drop_shot(i: int) -> void:
	var s: _Shot = _shots[i]
	_release(s.core)
	_release(s.trail)
	_shots.remove_at(i)


## The shots on their way: the cores sized for the eye, the trails along their way and turned to it; arrivals struck,
## misses faded, the great shot breaking the sky.
func _update_shots() -> void:
	var cam := _cam_pos()
	for i in range(_shots.size() - 1, -1, -1):
		var s: _Shot = _shots[i]
		var tau := clock - s.t0
		if s.hits and tau >= s.arrive:
			_impact(s)
			_drop_shot(i)
			continue
		if tau >= s.life:
			if s.event == "tear":
				_strike_at(s.at(s.life), true)
			_drop_shot(i)
			continue
		var p := s.at(tau)
		var vel := s.vel(tau)
		var size := clampf(cam.distance_to(p) * EYE, CORE_M.x, CORE_M.y) * float(SHOT_SIZE[s.kind])
		var fade := 0.0
		if not s.hits and s.event == "":
			fade = clampf((tau - (s.life - SHOT_FADE)) / SHOT_FADE, 0.0, 1.0)
		s.core.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * size), p)
		s.core.transparency = fade
		var spd := vel.length()
		var dirv := vel / maxf(spd, 0.01)
		var length := minf(spd * TRAIL_S * (1.0 if s.kind == Kind.BALL else 1.6), spd * tau + 0.01)
		var to_cam := cam - p
		var across := dirv.cross(to_cam)
		if across.length() < 0.001:
			across = dirv.cross(Vector3.UP if absf(dirv.y) < 0.9 else Vector3.RIGHT)
		across = across.normalized()
		var x := -dirv
		var z := x.cross(across).normalized()
		s.trail.global_transform = Transform3D(Basis(x * length, across * (size * 0.45), z), p - dirv * (length * 0.5))
		s.trail.transparency = fade


## A shot on its mark: sparks back off the hull, splinters, the flash, a jolt, the thud and the crack of wood; the hard
## volley's first: the cutter struck.
func _impact(s: _Shot) -> void:
	var p := s.mark
	var key := "hits_cutter" if s.target == 0 else "hits_hunter"
	stats[key] = int(stats[key]) + 1
	var big := 1.0 if s.kind == Kind.BALL else 1.5
	_shake[s.target] = maxf(float(_shake[s.target]), 0.5 * big)
	var eye := _cam_pos().distance_to(p)
	var back := -s.vel(s.arrive).normalized()
	_sparks(p, back, eye, big)
	if quality != "low":
		_splinters(p, back, eye, big)
	_flash_at(p, big, eye)
	_sound(&"ball_hit_wood", p, 10.0, 0.5 if s.kind == Kind.BALL else 0.38, 90.0)
	if s.kind != Kind.BALL or _rng.randf() < 0.5:
		_sound(&"gather_rec_tree_crack", p, 6.0, 0.85, 120.0)
	if s.event == "hard" and not _sent.has(&"cutter_hit"):
		_stricken()


## The hard volley has struck: the cutter jolts and lists, burns (a FireFx along its waist, its flames made big), its
## timbers go with a roar.
func _stricken() -> void:
	_send(&"cutter_hit")
	phase = Phase.STRICKEN
	_shake[0] = 1.0
	if cutter != null:
		var box := AABB(cutter.global_position + Vector3(-3.0, 0.5, -7.0), Vector3(6.0, 6.0, 14.0))
		_cutter_fire = FireFx.make(cutter, box, quality)
		_cutter_fire.name = "StruckFire"
		var fpm := _cutter_fire.flames.process_material as ParticleProcessMaterial
		fpm.scale_min *= 4.0
		fpm.scale_max *= 4.0
		fpm.initial_velocity_max *= 2.0
		for p: GPUParticles3D in [_cutter_fire.flames, _cutter_fire.smoke, _cutter_fire.embers]:
			if p != null:
				p.visibility_aabb = AABB(Vector3(-300, -300, -300), Vector3(600, 600, 600))
		_cutter_fire.strength = 0.6
	var at := _cutter_pos(clock)
	_flash_at(at, 2.2, _cam_pos().distance_to(at))
	_sound(&"gather_rec_tree_fall", at, 10.0, 0.6, 200.0)
	_sound(&"musket_tail_fort", at, 14.0, 0.4, 200.0)


## The great shot strikes the sky at `p`: a great flash, the shot's embers falling, the sky's crack (heard late, from far
## up; the first crack itself, SkyTear, is the shock); tear_point with the way to it from the camp.
func _strike_at(p: Vector3, show: bool) -> void:
	if _sent.has(&"tear_point"):
		return
	tear_at = p
	tear_dir = (p - camp).normalized()
	if show:
		var eye := _cam_pos().distance_to(p)
		_flash_at(p, 5.0, eye)
		_sparks(p, Vector3.DOWN, eye, 1.6, 30.0, 0.45)
		_sound(&"musket_tail_fort", p, 16.0, 0.2, 500.0)
		_sound(&"gather_rec_tree_crack", p, 14.0, 0.3, 400.0)
	_send(&"tear_point", tear_dir)


## Where the sky is struck when the great shot never flew (a skip): the planned point (beside the giant), else high over
## the fight.
func _default_tear() -> Vector3:
	if _tear_plan != Vector3.ZERO:
		return _tear_plan
	var out := Vector3(_c.x - camp.x, 0.0, _c.z - camp.z).normalized()
	return _c + out * 200.0 + Vector3.UP * 450.0


## The stagger is over: the cutter (its own fire put out: WreckFall lights its own) handed to the existing fall, from
## where it is at the speed and roll it has.
func _hand_over() -> void:
	if phase >= Phase.FALLING:
		return
	phase = Phase.FALLING
	if _cutter_fire != null and is_instance_valid(_cutter_fire):
		for p: GPUParticles3D in [_cutter_fire.flames, _cutter_fire.smoke, _cutter_fire.embers]:
			if p != null:
				p.emitting = false
		_cutter_fire.reparent(_fx_root)
		_fx.append({"node": _cutter_fire, "t0": clock, "life": FireFx.SMOKE_LIFE + 0.5, "kind": "free"})
	_cutter_fire = null
	var from: Variant = cutter if cutter != null else _pose_at(0, clock)
	var v: Vector3 = _vel[0]
	cutter = null
	wreck_fall = WreckFall.begin_from(_level, crash_at, from, {"heading": heading, "fall_s": FALL_S, "speed": v.length(),
			"roll": float(_last_roll[0]), "people": _people})
	_people = {}
	if wreck_fall != null:
		wreck_fall.speed = speed
		wreck_fall.landed.connect(_on_landed)
	else:
		_landed = true
		if from is Node3D and is_instance_valid(from):
			(from as Node3D).queue_free()
	_send(&"cutter_falling", wreck_fall)


## The cutter down in the pines: the one light's flash over where it lies (lighting the pines round it, seen from the
## camp), a burst of sparks over the treetops, the sky's flash toward it.
func _on_landed() -> void:
	_landed = true
	if wreck_fall == null or not is_instance_valid(wreck_fall):
		return
	var at := wreck_fall.frame.origin + Vector3.UP * LAND_FLASH_UP
	var eye := _cam_pos().distance_to(at)
	_flash_at(at, 3.0, eye, true, 1.3)          # (slow: the pines lit up round it for a second or two)
	_sparks(at, Vector3.UP, eye, 2.4, 30.0)


## The hunter turns from its circle and climbs to where the sky was struck (the tear's point, so from the camp it goes
## into the break), quickening.
func _plan_climb() -> void:
	_climb_set = true
	if tear_at == Vector3.ZERO:
		tear_at = _default_tear()
	var p0 := _hunter_circle(t_turn)
	var v0 := (_hunter_circle(t_turn + 0.1) - _hunter_circle(t_turn - 0.1)) / 0.2
	var to := tear_at - p0
	var v1 := maxf(2.0 * to.length() / CLIMB_S - v0.length(), 20.0)
	_climb = [p0, v0, tear_at, to.normalized() * v1]


## The hunter gone into the break: a pale flash where it went, a far rush of wind.
func _vanish() -> void:
	_gone = true
	var at := hunter.global_position if hunter != null else tear_at
	if hunter != null:
		_flash_at(at, 1.4, _cam_pos().distance_to(at), false)
		_sound(&"arrow_whoosh", at, 14.0, 0.25, 300.0)
		hunter.queue_free()
		hunter = null
	_geos[1] = []
	_glow_mats[1] = []
	_send(&"hunter_gone")


func _check_done() -> void:
	if phase == Phase.DONE or not _landed or not _gone:
		return
	phase = Phase.DONE
	_send(&"finished")


## Each signal once, in its order: any beat before it not yet sent is sent first (a skip, a lost shot).
func _send(sig: StringName, arg: Variant = null) -> void:
	if _sent.has(sig):
		return
	var order: Array[StringName] = [&"opened_fire", &"tear_point", &"cutter_hit", &"cutter_falling", &"hunter_gone", &"finished"]
	var at := order.find(sig)
	for k in at:
		if not _sent.has(order[k]):
			match String(order[k]):
				"tear_point":
					_strike_at(_default_tear(), false)
				"cutter_falling":
					_hand_over()
				"hunter_gone":
					_vanish()
				_:
					_sent[order[k]] = true
					emit_signal(order[k])
	if _sent.has(sig):
		return
	_sent[sig] = true
	if arg != null or sig == &"cutter_falling":
		emit_signal(sig, arg)
	else:
		emit_signal(sig)


# --- Effects --------------------------------------------------------------------------------------------------------

## A ring of wind at a muzzle, along the shot: it widens, runs a few metres on and is gone.
func _ring(at: Vector3, dir: Vector3) -> void:
	if _fx.size() >= MAX_FX:
		return
	var m := _take_fx(_ring_pool) as MeshInstance3D
	if m == null:
		return
	m.visible = true
	var size := clampf(_cam_pos().distance_to(at) * 0.012, 2.5, 12.0)
	_fx.append({"node": m, "t0": clock, "life": 0.7, "kind": "ring", "at": at, "dir": dir, "size": size})
	_ring_pose(m, at, dir, size, 0.0)
	stats["max_fx"] = maxi(int(stats["max_fx"]), _fx.size())


func _ring_pose(m: MeshInstance3D, at: Vector3, dir: Vector3, size: float, k: float) -> void:
	var y := dir
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var r := size * lerpf(0.25, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
	m.global_transform = Transform3D(Basis(x * r, y * r, z * r), at + dir * (6.0 * k))
	m.transparency = lerpf(0.15, 1.0, k)


## Sparks off a hit: streaks along their way (a pooled GPU particle system, a one-shot burst: its own process material set
## for it, no new one), sized for the eye; `spread` (deg) round `back`, their speed x `pace`.
func _sparks(at: Vector3, back: Vector3, eye: float, big: float, spread := 75.0, pace := 1.0) -> void:
	var p := _take_fx(_spark_pool) as GPUParticles3D
	if p == null:
		return
	var k := clampf(eye * 0.0035, 1.0, 4.0)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = back
	pm.spread = spread
	pm.initial_velocity_min = 18.0 * big * pace
	pm.initial_velocity_max = 45.0 * big * pace
	pm.scale_min = 0.8 * k
	pm.scale_max = 1.3 * k
	p.amount_ratio = clampf((26.0 if quality != "low" else 14.0) * big / p.amount, 0.05, 1.0)
	_burst(p, at, 3.0)


## Splinters off a hit: dark shards tumbling down (a pooled system as the sparks').
func _splinters(at: Vector3, back: Vector3, eye: float, big: float) -> void:
	var p := _take_fx(_splinter_pool) as GPUParticles3D
	if p == null:
		return
	var k := clampf(eye * 0.003, 0.6, 3.0)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = (back + Vector3.UP * 0.6).normalized()
	pm.initial_velocity_min = 6.0 * big
	pm.initial_velocity_max = 16.0 * big
	pm.scale_min = 0.6 * k
	pm.scale_max = 1.4 * k
	p.amount_ratio = clampf(12.0 * big / p.amount, 0.05, 1.0)
	_burst(p, at, 3.5)


## A pooled system's burst at `at`: shown, started again from nothing, an effect for `life` s (then hidden, idle).
func _burst(p: GPUParticles3D, at: Vector3, life: float) -> void:
	p.global_position = at
	p.visible = true
	p.restart()
	_fx.append({"node": p, "t0": clock, "life": life, "kind": "pool"})
	stats["max_fx"] = maxi(int(stats["max_fx"]), _fx.size())


# --- The pools ------------------------------------------------------------------------------------------------------

## The wreck's people prepare() made, taken from under the level (the rest are built as the ships come in).
func _take_people() -> void:
	var holder := _level.get_node_or_null(PEOPLE_NODE) if _level != null else null
	if holder == null:
		return
	for c in holder.get_children():
		if c is NpcBody and WreckFall.PEOPLE.has(String(c.name)) and not _people.has(String(c.name)):
			var nm := String(c.name)
			c.reparent(self, true)
			_people[nm] = c
	holder.queue_free()


## The pools, made once: MAX_SHOTS cores and trails, RING_POOL rings, SPARK_POOL spark and SPLINTER_POOL splinter systems
## (none on low), all hidden; the systems each with their own process material (set per burst: only its values change,
## so no shader is made again) and the one colour ramp.
func _make_pools() -> void:
	for i in MAX_SHOTS:
		_core_pool.append(_pooled_mesh("Core%d" % i, _quad(), _mat("core0"), _shots_root))
		_trail_pool.append(_pooled_mesh("Trail%d" % i, _quad(), _mat("trail0"), _shots_root))
	for i in RING_POOL:
		_ring_pool.append(_pooled_mesh("Ring%d" % i, _torus(), _mat("ring"), _fx_root))
	for i in SPARK_POOL:
		_spark_pool.append(_pooled_system("Sparks%d" % i, true))
	if quality != "low":
		for i in SPLINTER_POOL:
			_splinter_pool.append(_pooled_system("Splinters%d" % i, false))


func _pooled_mesh(nm: String, mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nm
	m.mesh = mesh
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	m.extra_cull_margin = 2.0
	m.visible = false
	parent.add_child(m)
	return m


## A spark system (streaks along their way, white-hot to red, the shared ramp) or a splinter one (dark shards tumbling).
func _pooled_system(nm: String, spark: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nm
	p.emitting = false
	p.one_shot = true
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -9.8, 0)
	if spark:
		p.amount = SPARK_MAX if quality != "low" else SPARK_MAX_LOW
		p.lifetime = 0.9
		p.explosiveness = 0.95
		p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
		p.visibility_aabb = AABB(Vector3(-90, -90, -90), Vector3(180, 180, 180))
		pm.spread = 75.0
		pm.damping_min = 2.0
		pm.damping_max = 4.0
		pm.color_ramp = _spark_ramp()
		p.draw_pass_1 = _streak()
	else:
		p.amount = SPLINTER_MAX
		p.lifetime = 2.4
		p.explosiveness = 1.0
		p.visibility_aabb = AABB(Vector3(-90, -120, -90), Vector3(180, 180, 180))
		pm.spread = 60.0
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.angular_velocity_min = -360.0
		pm.angular_velocity_max = 360.0
		p.draw_pass_1 = _shard()
	p.process_material = pm
	p.visible = false
	_fx_root.add_child(p)
	return p


## A pooled node for an effect (null when MAX_FX are live).
func _take_fx(pool: Array) -> Node3D:
	if _fx.size() >= MAX_FX:
		return null
	return _take(pool)


## The pool's first idle node, else the one taken longest ago (its effect cut short); null for an empty pool.
func _take(pool: Array) -> Node3D:
	if pool.is_empty():
		return null
	var oldest: Node3D = null
	var t := INF
	for n: Node3D in pool:
		if not _busy.has(n):
			_busy[n] = clock
			return n
		if float(_busy[n]) < t:
			t = float(_busy[n])
			oldest = n
	for i in range(_fx.size() - 1, -1, -1):
		if _fx[i].node == oldest:
			_fx.remove_at(i)
	for i in range(_shots.size() - 1, -1, -1):
		if _shots[i].core == oldest or _shots[i].trail == oldest:
			var s: _Shot = _shots[i]
			_shots.remove_at(i)
			_release(s.trail if s.core == oldest else s.core)
	_busy[oldest] = clock
	return oldest


## Back to its pool: hidden (a system stopped), idle.
func _release(n: Variant) -> void:
	if n == null or not is_instance_valid(n):
		return
	_busy.erase(n)
	(n as Node3D).visible = false
	if n is GPUParticles3D:
		(n as GPUParticles3D).emitting = false


## Each kind played once where the camera looks (WARM_M out), unseen (the additive materials' alpha 0 for WARM_FRAMES
## frames: _colors; the opaque shards and the struck fire's flames at a thousandth of their size), so their particle and
## draw shaders are made as the battle is (as Fx.warm_up does for the level's effects), not at the first volley, the
## first hit or the cutter struck. Windowed only (headless draws nothing).
func _warm_up() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_transform * Vector3(0.0, 0.0, -WARM_M)
	_warm_left = WARM_FRAMES
	var meshes: Array = [[_core_pool, "core0"], [_core_pool, "core1"], [_trail_pool, "trail0"], [_trail_pool, "trail1"],
			[_ring_pool, "ring"]]
	for e: Array in meshes:
		var m := _take(e[0]) as MeshInstance3D
		if m == null:
			continue
		m.material_override = _mat(String(e[1]))
		m.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * 0.5), at)
		m.transparency = 0.0
		m.visible = true
		_warm.append(m)
	for pool: Array in [_spark_pool, _splinter_pool]:
		var p := _take(pool) as GPUParticles3D
		if p == null:
			continue
		var pm := p.process_material as ParticleProcessMaterial
		pm.scale_min = 0.001
		pm.scale_max = 0.001
		p.amount_ratio = 0.2
		p.global_position = at
		p.visible = true
		p.restart()
		_warm.append(p)
	var fire := FireFx.make(self, AABB(at - Vector3.ONE * 0.05, Vector3.ONE * 0.1), quality)
	fire.name = "WarmFire"
	for p: GPUParticles3D in [fire.flames, fire.smoke, fire.embers]:
		if p != null:
			var fpm := p.process_material as ParticleProcessMaterial
			fpm.scale_min = 0.001
			fpm.scale_max = 0.001
	fire.strength = 1.0
	_warm.append(fire)
	_flash_glow.global_position = at
	_flash_glow.visible = true
	_flash_glow.transparency = 0.0


func _warm_done() -> void:
	for n in _warm:
		if not is_instance_valid(n):
			continue
		if n is FireFx:
			n.queue_free()
		else:
			_release(n)
	_warm.clear()
	_flash_glow.visible = _flash > 0.0
	_colors()


func _update_fx() -> void:
	for i in range(_fx.size() - 1, -1, -1):
		var f: Dictionary = _fx[i]
		var n: Variant = f.node
		var k := (clock - float(f.t0)) / float(f.life)
		if not is_instance_valid(n):
			_fx.remove_at(i)
			continue
		if k >= 1.0:
			if String(f.kind) == "free":
				(n as Node).queue_free()
			else:
				_release(n)
			_fx.remove_at(i)
			continue
		if String(f.kind) == "ring":
			_ring_pose(n as MeshInstance3D, f.at, f.dir, float(f.size), k)


## The one light and the one glow to a flash at `at` (`strength` 1: a ball's hit), sized for the eye at `eye` m, dying
## at `rate` (1/s).
func _flash_at(at: Vector3, strength: float, eye: float, lit := true, rate := 7.0) -> void:
	sky_flash.emit(clampf(strength * 0.2, 0.0, 1.0), (at - camp).normalized())
	if strength < _flash * 0.6:
		return                                  # (a bigger flash still burning: it keeps the light)
	_flash = strength
	_flash_rate = rate
	_flash_size = clampf(eye * 0.05, 6.0, 90.0) * sqrt(strength)
	_flash_glow.global_position = at
	_flash_glow.visible = true
	if lit:
		light.global_position = at
	light.set_meta(&"lit", lit)


func _update_flash(dt: float) -> void:
	if _flash <= 0.0:
		return
	_flash *= exp(-dt * _flash_rate)
	if _flash < 0.01:
		_flash = 0.0
	var on := _flash > 0.0
	_flash_glow.visible = on
	var f := minf(_flash, 1.0)
	_flash_glow.scale = Vector3.ONE * (_flash_size * (0.6 + 0.4 * f))
	_flash_glow.transparency = 1.0 - f
	light.visible = on and bool(light.get_meta(&"lit", true))
	light.light_energy = FLASH_ENERGY * _flash


## Every TICK_S: the effects' brightness for the eye (the night's exposure), the ships' far meshes, their keel glows
## breathing (brighter in the dark), the cutter's fire growing.
func _slow_tick() -> void:
	_dim = Fx._fire_dim(self)
	_colors()
	var cam := _cam_pos()
	var night := 3.0 if _dim < 0.5 else 1.0
	_lods(false, cam)
	for i in 2:
		var n := cutter if i == 0 else hunter
		if n == null:
			continue
		var e := (1.2 + 0.4 * sin(clock * 1.3 + i * 2.0)) * night
		for m: StandardMaterial3D in _glow_mats[i]:
			m.emission_energy_multiplier = e
	if _cutter_fire != null and is_instance_valid(_cutter_fire):
		_cutter_fire.strength = lerpf(0.6, 1.0, clampf((clock - t_hit) / STAGGER_S, 0.0, 1.0))
		FireFx.flame_material().set_shader_parameter(&"intensity", 2.0 * _dim)


## Each ship's far mesh past LOD_M from the camera, its near ones within it (switched only when that changes; `force`:
## set now).
func _lods(force: bool, cam := Vector3.INF) -> void:
	if cam == Vector3.INF:
		cam = _cam_pos()
	for i in 2:
		var n := cutter if i == 0 else hunter
		if n == null or not is_instance_valid(n) or not _has_lod[i]:
			continue
		var far := 1 if cam.distance_to(n.global_position) > LOD_M else 0
		if far == int(_lod_far[i]) and not force:
			continue
		_lod_far[i] = far
		for g: MeshInstance3D in _far[i]:
			if is_instance_valid(g):
				g.visible = far == 1
		for g: MeshInstance3D in _near[i]:
			if is_instance_valid(g):
				g.visible = far == 0


func _colors() -> void:
	var d := _dim
	var a := 0.0 if _warm_left > 0 else 1.0         # (warming up: unseen)
	_mat("core0").albedo_color = Color(2.4 * d, 2.4 * d, 2.4 * d, a)
	_mat("core1").albedo_color = Color(2.2 * d, 2.2 * d, 2.2 * d, a)
	_mat("trail0").albedo_color = Color(1.7 * d, 1.7 * d, 1.7 * d, a)
	_mat("trail1").albedo_color = Color(1.6 * d, 1.6 * d, 1.6 * d, a)
	var rc := RING_COLOR * (1.5 * d)
	_mat("ring").albedo_color = Color(rc.r, rc.g, rc.b, 0.6 * a)
	_mat("flash").albedo_color = Color(3.2 * d, 3.2 * d, 3.2 * d, a)
	_mat("spark").albedo_color = Color(1.6 * d, 1.6 * d, 1.6 * d, a)
	var sc := Color(0.42, 0.28, 0.16) * maxf(d, 0.25)
	_mat("shard").albedo_color = Color(sc.r, sc.g, sc.b, 1.0)


# --- Sound ------------------------------------------------------------------------------------------------------------

## `id` at `at`, heard after the distance's delay (at the speed of sound), carried far (its voice's reach opened up to
## `unit`, no cut-off).
func _sound(id: StringName, at: Vector3, gain_db: float, pitch: float, unit: float) -> void:
	if not Sfx.has(id):
		return
	_sounds.append([_cam_pos().distance_to(at) / Sfx.SPEED_OF_SOUND, id, at, gain_db, pitch, unit])


func _sound_queue(delta: float) -> void:
	for i in range(_sounds.size() - 1, -1, -1):
		var e: Array = _sounds[i]
		e[0] = float(e[0]) - delta
		if float(e[0]) > 0.0:
			continue
		_sounds.remove_at(i)
		var v := Sfx.play_3d(e[1], e[2], float(e[3]), float(e[4]), {"delay": 0.0})
		if v != null:
			v.unit_size = float(e[5])
			v.max_distance = 0.0


func _cam_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else camp


# --- Shared meshes, materials and textures ----------------------------------------------------------------------------

static var _mats := {}
static var _meshes := {}


## The last battle leaving the tree lets go of the shared materials, meshes and textures (the next makes them again).
func _exit_tree() -> void:
	for n in get_tree().get_nodes_in_group(GROUP):
		if n != self:
			return
	_mats.clear()
	_meshes.clear()


## The sparks' colour ramp: white-hot, orange, dying red (one texture for every system).
static func _spark_ramp() -> Texture2D:
	if not _meshes.has("spark_ramp"):
		_meshes["spark_ramp"] = FireFx._ramp_tex([[0.0, Color(1.0, 0.95, 0.8, 1.0)], [0.3, Color(1.0, 0.6, 0.22, 0.9)],
				[1.0, Color(0.5, 0.12, 0.03, 0.0)]])
	return _meshes["spark_ramp"]


static func _quad() -> QuadMesh:
	if not _meshes.has("quad"):
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_meshes["quad"] = q
	return _meshes["quad"]


static func _torus() -> TorusMesh:
	if not _meshes.has("torus"):
		var t := TorusMesh.new()
		t.inner_radius = 0.86
		t.outer_radius = 1.0
		t.rings = 28
		t.ring_segments = 6
		_meshes["torus"] = t
	return _meshes["torus"]


## A spark: a thin quad, long along its way (the particles align its Y to their velocity).
static func _streak() -> QuadMesh:
	if not _meshes.has("streak"):
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 1.8)
		q.material = _mat("spark")
		_meshes["streak"] = q
	return _meshes["streak"]


static func _shard() -> QuadMesh:
	if not _meshes.has("shard"):
		var q := QuadMesh.new()
		q.size = Vector2(0.35, 1.0)
		q.material = _mat("shard")
		_meshes["shard"] = q
	return _meshes["shard"]


static func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_receive_shadows = true
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match key:
		"core0", "core1":
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
			m.albedo_texture = _core_tex(key == "core1")
		"trail0", "trail1":
			m.albedo_texture = _trail_tex(key == "trail1")
		"ring":
			pass
		"flash":
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
			m.albedo_texture = _core_tex(true)
		"spark":
			m.vertex_color_use_as_albedo = true
			m.albedo_texture = Fx._soft_dot()
		"shard":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mats[key] = m
	return m


## A shot's core: white-hot in the middle, its halo the shot's colour (cold for a ball, gold for a boulder, lumpier).
static func _core_tex(boulder: bool) -> Texture2D:
	var key := "core_tex%d" % int(boulder)
	if _meshes.has(key):
		return _meshes[key]
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var halo := BOULDER_COLOR if boulder else BALL_COLOR
	var n := FastNoiseLite.new()
	n.frequency = 0.12
	n.seed = 1758
	for y in sz:
		for x in sz:
			var u := (x + 0.5) / sz * 2.0 - 1.0
			var v := (y + 0.5) / sz * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			if boulder:
				r *= 1.0 + 0.18 * n.get_noise_2d(x, y)
			var core := 1.0 - smoothstep(0.08, 0.3, r)
			var glow := exp(-r * r * 7.0) * (1.0 - smoothstep(0.8, 1.0, r))
			var c := halo.lerp(Color(1, 1, 1), core)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(core + glow * 0.85, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_meshes[key] = t
	return t


## A trail: bright at its head (u 0), fading to nothing at its tail, soft across; white toward the head, the shot's colour
## behind.
static func _trail_tex(boulder: bool) -> Texture2D:
	var key := "trail_tex%d" % int(boulder)
	if _meshes.has(key):
		return _meshes[key]
	var w := 64
	var h := 16
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint := BOULDER_COLOR if boulder else BALL_COLOR
	for y in h:
		for x in w:
			var u := (x + 0.5) / w
			var v := absf((y + 0.5) / h * 2.0 - 1.0)
			var a := pow(1.0 - u, 1.4) * (1.0 - v * v) * smoothstep(0.0, 0.04, u)
			var c := Color(1, 1, 1).lerp(tint, sqrt(u))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_meshes[key] = t
	return t
