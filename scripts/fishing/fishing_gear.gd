class_name FishingGear
extends Node
## Fishing (user 2026-09-28: "for fishing have all those options": the rod and line, the spear, the weir; the fish are
## FishLife's, each with its own mind). The gear the player owns (the pack's fishing_rod, fish_spear) comes out on one
## button, as the tools do (GatherTools):
##   8            the gear button: rod -> spear -> put away (a weapon in the hands is put away first, the hands go free;
##                a tool in the hands goes back; a torch in the hand is set down)
## The rod (1765: a long ash rod with the line tied to its tip and a quill float, no reel): ROD_M of rod and LINE_M of
## line; a worm hangs under the float (FLOAT_DEPTH, less in the shallows).
##   LMB hold, release   cast (user 2026-09-28: "the fishing cast is the attack musket animations left right up and then
##                       held in the up attack two hands lower"; "should be a throw cast arc for fishing"): the musket
##                       club's swings with the rod in both hands (CASTS: overhead (W, or no key), from the left (A),
##                       from the right (D), the key held as the button goes down; the move keys still move: the
##                       rod out, the player walks and strafes with it): the hold winds the rod back, the release
##                       swings it through and the line goes out, to where the crosshair falls on the water (CAST_MIN
##                       to the rod and line's reach). Where it goes is the angler's skill ("it should be skill based
##                       on where to cast as well"): while it is held an arc of dots shows the float's flight and a
##                       ring the float comes down within (gold on water, grey on the bank), wide as the rod goes
##                       back and closing in as it is held steady, wider on the move and the farther out; and the
##                       float's splash puts down the fish near where it lands (SPLASH_M): cast above a fish's lie and
##                       let the current bring the worm down to it
##   (drift)             the float goes down with the current, the worm with it: a natural drift (FishLife.Bait.natural
##                       1) until the line comes tight; then the float swings across the current, dragging (natural
##                       SWING_NATURAL: the fish look and turn away). The player may walk down the bank with it
##   LMB tap             lift the float out (to cast again)
##   (a bite)            the float bobs, then goes under: a fish has the worm (FishLife's bite)
##   LMB tap             strike: in its time (the species' hold_s) the hook holds; late, it has spat the worm out
##   (hooked)            the rod comes up and bows toward the fish (the rod held up and back only now: user 2026-09-28,
##                       "it should only be like that when we have a fish on the line where it can bend the pole").
##                       The mouse pulls the rod ("the user uses the mouse to pull the tension", "the user will pull the
##                       tip of the rod closer to them"): drawn back, toward you, the tip comes up and back over the
##                       shoulder and leads the fish in; pushed forward, the rod is lowered toward it and gives (LMB
##                       held draws it back too). The line is tied to the tip (no reel): past its length the rod bends
##                       (ROD_GIVE of give at the tip), past that the line stretches and the tension climbs to its
##                       break; held there LINE_GIVE s, or yanked far past it, it snaps. The fish pulls away, the
##                       harder the fresher and heavier it is, and the pressure tires it. Walk with it ("i want the
##                       user to be able to walk or move when fishing"): the line comes along, and the fish with it
##                       the more it has tired. Trout and salmon leap on the line
##   (landing)           a tired fish (stamina under LAND_STAMINA) led within LAND_M: the player kneels and takes it
##                       (FishCatch.to_pack: into the pack by the pound)
## The angler's skill (user 2026-09-28): the survival rules' Trapping and Fishing (0-100: SurvivalSkills) closes the
## cast's ring (to SKILL_SPREAD of it at 100) and lets the line take more before it breaks (SKILL_LINE times at 100);
## it grows from the rod, a strike that holds and a fish landed (the heavier the more: SurvivalSkills.record_fish),
## a toast at each whole level. With the rod or the spear out, the river's "Drink" is not offered (RiverWater: E's
## prompt stays off the screen while fishing).
## On the screen only while a fish is on: the line's tension and the fish's strength, two slim bars under the centre
## (FishFightGauge; user: "a stamina gauge"). Otherwise the float, the rod's bend and the line are the signs.

signal cast_landed(at: Vector3, in_water: bool)
signal struck(ok: bool)
signal line_broke
signal fish_landed(info: Dictionary)

const ACTION := &"fish_gear"
const KEY := KEY_8
const ORDER := ["fishing_rod", "fish_spear"]
const ROD_M := 3.8
const LINE_M := 5.5
const FLOAT_DEPTH := 0.5
const TAP_S := 0.22
const WINDUP_S := 0.35
const SWING_S := 0.22
const FLIGHT_S := 0.7
## The cast: to where the crosshair falls (CAST_MIN to CAST_MAX out over the ground, LOOK_M along the view at most), and
## down within `spread` of it: SPREAD_BASE and SPREAD_PER_M a metre out, SPREAD_START times that as the wind-up begins,
## closing to it over SETTLE_S held, and (1 + SPREAD_MOVE) times at a run (in proportion walking). Its splash puts down
## the fish within SPLASH_M of where the float lands (FishLife.alarm).
const CAST_MIN := 2.5
const CAST_MAX := ROD_M + LINE_M - 0.6
const LOOK_M := 30.0
const SPREAD_BASE := 0.15
const SPREAD_PER_M := 0.05
const SPREAD_START := 2.2
const SETTLE_S := 0.9
const SPREAD_MOVE := 1.6
const SPLASH_M := 1.2
## The float's drift, of the top water's speed (the line holds it back a little).
const DRIFT_K := 0.85
const SWING_NATURAL := 0.3
## A fish on: the pull (lift, 0 lowered toward the fish .. 1 drawn up and back) by the mouse, per pixel drawn back; LMB
## held draws it back at LIFT_HOLD a second; the arms follow at LIFT_FOLLOW a second.
const LIFT_PX := 0.0035
const LIFT_HOLD := 0.9
const LIFT_FOLLOW := 1.6
## The strike's pull (the rod snapped up).
const LIFT_STRIKE := 0.45
## The rod's give: its tip bows this far toward the fish (m) before the line itself takes the pull, and the line
## stretches up to LINE_STRETCH more. The tension (1: the break) is TENSION_ROD at the rod's full bend and 1 half way
## into the stretch; over 1 for LINE_GIVE s, or at SNAP_NOW (the stretch all taken), the line snaps.
const ROD_GIVE := 1.2
const LINE_STRETCH := 0.3
const TENSION_ROD := 0.72
const LINE_GIVE := 0.5
const SNAP_NOW := 1.3
## How hard the bent rod and the line draw the fish toward the tip: m/s over the ground per metre past the line's
## length, over the fish's heft (fish_heft: a heavy fish is moved less, and pulls the rod over further).
const PULL_K := 4.0
## Trapping and Fishing at 100: the cast's ring this much of a novice's, the line this many times as strong.
const SKILL_SPREAD := 0.55
const SKILL_LINE := 1.35
const SKILL := "trapping"
const LAND_STAMINA := 0.15
const LAND_M := 3.2
const LAND_S := 1.6
## The rod held with no pose on the body (landing a fish; its pitch over the level, rad): ready, back over the
## shoulder, cast out.
const PITCH_READY := 0.55
const PITCH_BACK := 1.75
const PITCH_OUT := 0.2
## The body's poses (the upper body over its own: ToolPose, mask "upper"), our own clips (animations_extra/
## Frontier_Own.res, keyed by hand: tools/anim_author/author_fishing.gd): "hold" the rod out over the water in both
## hands, low (a slow breath, looped); "fight" a fish on, the clip's time the pull (lift).
const OWN_PATH := "res://animations_extra/Frontier_Own.res"
const POSES := {"hold": "own-rod-hold", "fight": "own-rod-fight"}
## The casts: the club's swing clips; the wind-up plays to `peak` (the rod back) and holds there while the button is
## held; let go, the swing plays on, the line goes out at `release` and the swing runs `follow` s into its strike clip,
## then the body eases back to the hold (CAST_EASE s).
const CASTS := {
	"W": {"intro": "own-axe-w-intro", "hit": "own-axe-w", "peak": 0.5, "release": 0.57, "follow": 0.06},
	"A": {"intro": "own-axe-a-intro", "hit": "own-axe-a", "peak": 0.31, "release": 0.4, "follow": 0.12},
	"D": {"intro": "own-axe-d-intro", "hit": "own-axe-d", "peak": 0.31, "release": 0.4, "follow": 0.12},
}
const CAST_EASE := 0.35
## The cast arc's gold; the line's dots in a fight go from it through TAUT to BREAKING as the tension climbs.
const ARC_GOLD := Color(1.0, 0.78, 0.42, 0.85)
const TAUT := Color(1.0, 0.52, 0.22, 0.9)
const BREAKING := Color(0.95, 0.18, 0.12, 0.95)
## The rod in the two-handed frame the right hand's prop bone carries (GatherTools.two_hand_offset: the haft +Y from
## its knob; the club's swings and our rod clips alike): its butt at the knob (a hand below the lower hand), its length
## up the haft.
const ROD_IN_HANDS := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
## The rod's curve at full bend: the turn at its tip (rad; shaders/fishing/rod.gdshader TIP_ANGLE).
const TIP_ANGLE := 1.45
## The pose now and the one fading out, and the fade.
var _pose_now := "hold"
var _pose_was := "hold"
var _pose_fade := 1.0
const LIB := "actor_b"

enum Rod { OFF, READY, WINDUP, SWING, FLIGHT, DRIFT, BITE, FIGHT, LAND, ASHORE }

var player: FrontierPlayer
var life: FishLife
## The gear in the hand ("" none).
var gear := ""
var rod_state := Rod.OFF
var bait: FishLife.Bait
## The float on the water (or in the air, or ashore), and where it is bound.
var float_pos := Vector3.ZERO
var rod_pitch := PITCH_READY
## The rod's curve (0..1, toward _bend_dir: the rod's own frame, square to its length).
var bend := 0.0
## A fish on: the pull asked (the mouse, LMB) and the arms' (the pose's time); the line's tension (1: its break) and
## how long it has been over.
var lift := 0.0
var lift_shown := 0.0
var tension := 0.0
var strain := 0.0
## The cast held: how wide its landing is (m, the ring's radius).
var spread := 0.0
## Tests, tools: set to drive the rod without the mouse (the fire button held).
var fire_override := -1
## Tests, tools: the cast to play ("W", "A", "D") instead of the move key held ("": the key's).
var cast_override := ""
## Tests, tools: the angler's Trapping and Fishing (0-100) instead of the survival rules' (-1: theirs).
var skill_override := -1.0
## Tests, tools: where a cast goes instead of along the camera (Vector3.INF: the camera's).
var aim_override := Vector3.INF
var rng := RandomNumberGenerator.new()

var _rod: Node3D
var _rod_mat: ShaderMaterial
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _float: Node3D
var _pose: ToolPose
var _pose_w := 0.0
var _anims := {}
var _hand: BoneAttachment3D
var _t := 0.0
var _press_t := -1.0
var _was_fire := false
## The cast aimed at its let-go, and the float's flight's height over its line.
var _aim := Vector3.INF
var _arc_h := 1.2
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _fish = null
var _bite_t := 0.0
var _kneel_ap: AnimationPlayer
var _own: AnimationLibrary
## The cast playing: {dir, intro, hit, peak, release, follow, u, done_t}; {} none.
var _cast := {}
var _arc: MultiMeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _arc_mat: StandardMaterial3D
## The fight's dots along the line: how far they have flowed.
var _flow := 0.0
var _blender: HorsePhaseBlender
var _bend_dir := Vector2(0.0, -1.0)
var _hold_t := 0.0
var _gauge: FishFightGauge
var _stance: RodStance


static func install(p: FrontierPlayer) -> FishingGear:
	var g := FishingGear.new()
	g.name = "FishingGear"
	g.player = p
	p.add_child(g)
	return g


static func find(p: Node) -> FishingGear:
	return p.get_node_or_null("FishingGear") as FishingGear if p else null


## True while `p` has fishing gear out (the rod or the spear): the river does not offer a drink then.
static func gear_out(p: Node) -> bool:
	var g := find(p)
	return g != null and g.gear != ""


static func ensure_input() -> void:
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY
		InputMap.action_add_event(ACTION, ev)


func _ready() -> void:
	ensure_input()
	rng.seed = 1765
	_build()


## The angler's Trapping and Fishing, 0..1 (the survival rules' skill; 0 without them).
func skill01() -> float:
	if skill_override >= 0.0:
		return clampf(skill_override / 100.0, 0.0, 1.0)
	var core := _core()
	return clampf(SurvivalSkills.level(core, SKILL) / 100.0, 0.0, 1.0) if core else 0.0


## How much the line takes before it breaks, of a novice's.
func line_strength() -> float:
	return lerpf(1.0, SKILL_LINE, skill01())


func _core() -> SurvivalCore:
	var b := SurvivalBridge.find(get_tree()) if is_inside_tree() else null
	return b.core if b else null


## The skill grows from the rod (SurvivalSkills.record_fish); a toast at each whole level.
func _train(event: String, lb := 0.0) -> void:
	var core := _core()
	if core == null:
		return
	var was := SurvivalSkills.level(core, SKILL)
	var tier_was := SurvivalSkills.tier_of_level(core, was)
	SurvivalSkills.record_fish(core, event, lb)
	var now := SurvivalSkills.level(core, SKILL)
	if int(now) > int(was):
		var tier := SurvivalSkills.tier_of_level(core, now)
		var nm := String(core.data.skill(SKILL).get("name", "Trapping and Fishing"))
		var line := "%s %d" % [nm, int(now)]
		if tier != tier_was:
			line += "  ·  " + tier.capitalize()
		var h: Variant = player.get("hud")
		if h != null and is_instance_valid(h) and (h as Node).has_method("toast"):
			(h as Node).call("toast", line, "ui:skill_" + SKILL, "level:" + SKILL)


func owns(kind: String) -> bool:
	return player != null and InventoryState.from_player(player).pack_count(kind) > 0


## Gives `kind` (tests, the bench).
func give(kind: String, n := 1) -> void:
	var inv := InventoryState.from_player(player)
	inv.add(kind, n)
	player.inventory_pack = inv.pack.duplicate(true)


# --- The rod, the line, the float -------------------------------------------------------------------------------

func _build() -> void:
	_rod = FishModels.build("fishing_rod")
	_rod.visible = false
	add_child(_rod)
	var mi := _rod.get_child(0) as MeshInstance3D
	_rod_mat = mi.material_override as ShaderMaterial if mi else null
	if mi:
		# (bent, it leaves its straight bounds)
		mi.extra_cull_margin = ROD_M * 0.6
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.name = "Line"
	_line.mesh = _line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.2, 0.19, 0.16, 0.75)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.top_level = true
	add_child(_line)
	_float = FishModels.build("quill_float")
	_float.visible = false
	_float.top_level = true
	add_child(_float)


func _skeleton() -> Skeleton3D:
	return player.skeleton if player else null


## The right hand's grip (world), where the rod is held: the hand's prop bone as posed (after the arm's pose, a
## BoneAttachment3D: the skeleton's last update).
func hand_point() -> Vector3:
	var sk := _skeleton()
	if sk and _hand == null:
		_hand = BoneAttachment3D.new()
		_hand.name = "FishingHand"
		_hand.bone_name = "r_hand_prop_attachment"
		sk.add_child(_hand)
	if _hand and _hand.is_inside_tree():
		return _hand.global_position
	return player.global_position + Vector3.UP * 1.1


## The rod's place (its butt at the origin, along +Z to the tip): in both hands as the swing clips hold it (the right
## hand's prop bone in their two-handed frame), or, while the body is not posed (landing a fish), the player's facing
## pitched up by rod_pitch from the right hand.
func rod_transform() -> Transform3D:
	var hp := hand_point()
	var yaw := player.rotation.y
	var f := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var d := (f * cos(rod_pitch) + Vector3.UP * sin(rod_pitch)).normalized()
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var free := Transform3D(Basis.looking_at(-d, up), hp - d * 0.3)
	if _hand == null or not _hand.is_inside_tree():
		return free
	var two := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0, -0.035))
	var held := _hand.global_transform * two * ROD_IN_HANDS
	var k := smoothstep(0.0, 1.0, _pose_w if rod_state != Rod.LAND else 0.0)
	return free.interpolate_with(held.orthonormalized(), k)


## The way the rod points (its butt's way, as the hands hold it; the curve bows it from there).
func rod_dir() -> Vector3:
	return rod_transform().basis.z.normalized()


## A point `s` m up the rod from its butt, on its curve (world): the same arc as shaders/fishing/rod.gdshader bends it,
## `bend` toward _bend_dir, the curvature growing along it to TIP_ANGLE at the tip at full bend.
func bent_point(s: float, rt := Transform3D()) -> Vector3:
	if rt == Transform3D():
		rt = rod_transform()
	var k := 2.0 * bend * TIP_ANGLE / ROD_M
	var c := Vector2.ZERO
	var ds := s / 10.0
	for i in 10:
		var sm := (float(i) + 0.5) * ds
		var a := k * sm * sm / (2.0 * ROD_M)
		c += Vector2(cos(a), sin(a)) * ds
	var n := Vector3(_bend_dir.x, _bend_dir.y, 0.0).normalized()
	return rt * (Vector3(0.0, 0.0, c.x) + n * c.y)


## The rod's tip on its curve, where the line is tied.
func tip_point() -> Vector3:
	return bent_point(ROD_M)


## The tip as the rod would hold it unbent (where the pull is measured from).
func straight_tip() -> Vector3:
	var rt := rod_transform()
	return rt.origin + rt.basis.z.normalized() * ROD_M


## Which way the rod bows: toward `pull` (world), in the rod's own frame, square to its length.
func _aim_bend(pull: Vector3) -> void:
	var rt := rod_transform()
	var l := rt.basis.orthonormalized().inverse() * pull
	var v := Vector2(l.x, l.y)
	if v.length() > 1e-3:
		_bend_dir = v.normalized()


# --- The gear button ---------------------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if Input.is_action_just_pressed(ACTION) and not get_tree().paused:
		cycle()
	_guard()
	if gear == "fishing_rod":
		_rod_step(dt)


## A fish on, the mouse pulls the rod (user 2026-09-28: "the user uses the mouse to pull the tension", "the user will
## pull the tip of the rod closer to them"): drawn back (toward you, down the mat) the rod comes up and back, pushed
## forward it is lowered toward the fish; its side to side still turns the view (the camera's pitch stays).
func _input(event: InputEvent) -> void:
	if rod_state != Rod.FIGHT or player == null or not player.is_local or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		pull_by(m.relative.y * LIFT_PX)
		var k := deg_to_rad(player.cs_sensitivity * 0.022) * player.camera.fov / player.fov
		player.yaw -= m.relative.x * k
		get_viewport().set_input_as_handled()


## Draws the rod back (+) or lowers it toward the fish (-), of its whole pull (tests, tools: the mouse's way).
func pull_by(d: float) -> void:
	lift = clampf(lift + d, 0.0, 1.0)


func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_pose_w = move_toward(_pose_w, 1.0 if gear != "" and rod_state != Rod.LAND else 0.0, dt / 0.25)
	_hold_t += dt
	_apply_pose()
	_draw_rod()


## The next of the gear owned, or put away.
func cycle() -> void:
	var owned: Array[String] = []
	for k: String in ORDER:
		if owns(k):
			owned.append(k)
	if owned.is_empty():
		return
	var i := owned.find(gear)
	if i < 0:
		take_out(owned[0])
	elif i + 1 < owned.size():
		take_out(owned[i + 1])
	else:
		put_away()


func take_out(kind: String) -> bool:
	if player.is_dead or player.riding != null or player.kneeling != null or not owns(kind):
		return false
	if gear != "":
		put_away()
	# the hands free: a tool back, a weapon put away, a torch set down
	if player.gather and player.gather.in_hand() != "":
		player.gather.drop_now()
	if player.torch != null and player.torch.holding():
		player.torch.drop("reload")
	if not player.hands_free and not player.is_switching():
		player.toggle_hands_free()
	gear = kind
	if kind == "fishing_rod":
		rod_state = Rod.READY
		rod_pitch = PITCH_READY
		_rod.visible = true
	return true


func put_away() -> void:
	_end_bait()
	gear = ""
	rod_state = Rod.OFF
	_cast = {}
	_aim = Vector3.INF
	_show_arc(false)
	_rod.visible = false
	_float.visible = false
	_line_mesh.clear_surfaces()


func _guard() -> void:
	if gear == "":
		return
	var gone := player.is_dead or player.riding != null
	gone = gone or (not player.hands_free and not player.is_switching())
	gone = gone or (player.gather != null and player.gather.in_hand() != "")
	gone = gone or (player.torch != null and player.torch.holding())
	gone = gone or (player.kneeling != null and player.kneeling != self)
	if gone:
		put_away()


func _fire() -> bool:
	if fire_override >= 0:
		return fire_override > 0
	return InputMap.has_action(&"fire") and Input.is_action_pressed(&"fire") and not get_tree().paused


# --- The rod -----------------------------------------------------------------------------------------------------

func _rod_step(dt: float) -> void:
	_t += dt
	var fire := _fire()
	var pressed := fire and not _was_fire
	var released := not fire and _was_fire
	_was_fire = fire
	if pressed:
		_press_t = 0.0
	elif fire and _press_t >= 0.0:
		_press_t += dt
	var tap := released and _press_t >= 0.0 and _press_t < TAP_S
	if released:
		_press_t = -1.0
	match rod_state:
		Rod.READY:
			rod_pitch = move_toward(rod_pitch, PITCH_READY, dt * 3.0)
			if fire and _press_t > 0.08:
				rod_state = Rod.WINDUP
				_t = 0.0
				_begin_cast(_cast_key())
		Rod.WINDUP:
			rod_pitch = lerpf(PITCH_READY, PITCH_BACK, smoothstep(0.0, WINDUP_S, _t))
			spread = _spread_now()
			_show_arc(true)
			if not fire:
				rod_state = Rod.SWING
				_t = 0.0
				_aim = cast_target()
				_face_cast()
				_show_arc(false)
		Rod.SWING:
			rod_pitch = lerpf(PITCH_BACK, PITCH_OUT, smoothstep(0.0, SWING_S, _t))
			if (_cast.is_empty() or float(_cast.u) >= float(_cast.release)) and _from == Vector3.ZERO:
				_launch()
		Rod.FLIGHT:
			rod_pitch = move_toward(rod_pitch, PITCH_OUT, dt * 2.0)
			var k := clampf(_t / FLIGHT_S, 0.0, 1.0)
			float_pos = _from.lerp(_to, k) + Vector3.UP * sin(PI * k) * _arc_h
			if k >= 1.0:
				_land_cast()
		Rod.DRIFT:
			rod_pitch = move_toward(rod_pitch, PITCH_READY * 0.8, dt)
			_drift(dt)
			if tap:
				_lift_out()
		Rod.BITE:
			_drift(dt)
			_bite_t += dt
			if pressed:
				var ok := life != null and bait != null and life.set_hook(bait)
				struck.emit(ok)
				if ok:
					_train("strike")
					_fish = bait.fish
					rod_state = Rod.FIGHT
					strain = 0.0
					tension = 0.0
					lift = LIFT_STRIKE
					lift_shown = minf(lift_shown, 0.1)
					_t = 0.0
				else:
					rod_state = Rod.DRIFT
			elif bait == null or bait.fish == null:
				# spat out before the strike
				rod_state = Rod.DRIFT
		Rod.FIGHT:
			_fight(dt, fire)
		Rod.LAND:
			_landing(dt)
		Rod.ASHORE:
			if tap or pressed:
				_lift_out()
	_step_cast(dt)
	if rod_state != Rod.FIGHT:
		# no fish on: the rod's own weight bows it a little
		_aim_bend(Vector3.DOWN)
		bend = move_toward(bend, 0.04, dt * 3.0)
		tension = 0.0
		lift = 0.0
		lift_shown = move_toward(lift_shown, 0.0, dt * LIFT_FOLLOW)
	if rod_state in [Rod.READY, Rod.WINDUP, Rod.SWING]:
		float_pos = tip_point() + Vector3.DOWN * 0.9


## The cast for the move key held as the button goes down: from the left (A), from the right (D), else overhead (W).
func _cast_key() -> String:
	if cast_override != "":
		return cast_override
	if InputMap.has_action(&"move_left") and Input.is_action_pressed(&"move_left"):
		return "A"
	if InputMap.has_action(&"move_right") and Input.is_action_pressed(&"move_right"):
		return "D"
	return "W"


func _begin_cast(dir: String) -> void:
	var c: Dictionary = CASTS.get(dir, CASTS["W"])
	var intro := _own_anim(String(c.intro))
	var hit := _own_anim(String(c.hit))
	if intro == null or hit == null:
		_cast = {}
		return
	_cast = {"dir": dir, "intro": intro, "hit": hit, "peak": float(c.peak), "release": float(c.release),
			"end": intro.length + float(c.follow), "u": 0.0, "done_t": -1.0}


## The cast's clock: the wind-up to its peak (held there while the button is), then on through the swing to its end;
## done, the body eases back to the hold over CAST_EASE.
func _step_cast(dt: float) -> void:
	if _cast.is_empty():
		return
	var u := float(_cast.u)
	if rod_state == Rod.WINDUP:
		u = minf(u + dt, float(_cast.peak))
	elif float(_cast.done_t) < 0.0:
		u += dt
		if u >= float(_cast.end):
			u = float(_cast.end)
			_cast.done_t = 0.0
	else:
		_cast.done_t = float(_cast.done_t) + dt
		if float(_cast.done_t) >= CAST_EASE:
			_cast = {}
			return
	_cast.u = u


func _own_anim(clip: String) -> Animation:
	if _own == null and ResourceLoader.exists(OWN_PATH):
		_own = load(OWN_PATH) as AnimationLibrary
	return _own.get_animation(clip) if _own and _own.has_animation(clip) else null


## Where the cast is aimed: the crosshair's point on the water (or the bank), brought within CAST_MIN..CAST_MAX of the
## player over the ground (aim_override instead, tests and tools).
func cast_target() -> Vector3:
	var me := player.global_position
	var at := aim_override if aim_override != Vector3.INF else _look_point()
	var flat := Vector2(at.x - me.x, at.z - me.z)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector2(-sin(player.yaw), -cos(player.yaw))
	var d := clampf(flat.length(), CAST_MIN, CAST_MAX)
	at = Vector3(me.x + dir.x * d, 0.0, me.z + dir.y * d)
	at.y = _top_at(at)
	return at


## Where the crosshair falls: along the camera's line, the first point under the water's top or the ground (LOOK_M at
## most; looking up over it, the reach along the view).
func _look_point() -> Vector3:
	var me := player.global_position
	var ahead := me + Vector3(-sin(player.yaw), 0.0, -cos(player.yaw)) * CAST_MAX
	var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	if cam == null:
		return ahead
	var o := cam.global_position
	var f := -cam.global_transform.basis.z
	var s := 0.0
	while s < LOOK_M:
		s += 0.25
		var p := o + f * s
		if p.y <= _top_at(p):
			return p
	return ahead


## The water's top at p, or the ground's.
func _top_at(p: Vector3) -> float:
	var sy := _surface_at(p)
	return sy if sy > -INF else FrontierTerrain.height_at(p.x, p.z)


func _wet(p: Vector3) -> bool:
	var sy := _surface_at(p)
	return sy > -INF and WorldRiver.depth_at(Vector3(p.x, sy, p.z)) > 0.12


## How wide the cast held now would land: wide as the rod goes back, closing in as it is held (SETTLE_S), the farther
## out the wider, and wider on the move.
func _spread_now() -> float:
	var me := player.global_position
	var at := cast_target()
	var d := Vector2(at.x - me.x, at.z - me.z).length()
	var v := Vector2(player.velocity.x, player.velocity.z).length() / maxf(player.run_speed, 0.1)
	return (SPREAD_BASE + SPREAD_PER_M * d) * lerpf(SPREAD_START, 1.0, smoothstep(0.0, SETTLE_S, _t)) \
			* (1.0 + SPREAD_MOVE * clampf(v, 0.0, 1.5)) * lerpf(1.0, SKILL_SPREAD, skill01())


## Where a cast let go now is aimed, and the float's flight there (as _launch and FLIGHT fly it): {from, to, wet,
## path, spread} (it comes down within `spread` of `to`).
func cast_preview() -> Dictionary:
	var at := cast_target()
	var from := tip_point()
	var h := _flight_h(at)
	var path := PackedVector3Array()
	for i in 25:
		var k := float(i) / 24.0
		path.append(from.lerp(at, k) + Vector3.UP * sin(PI * k) * h)
	return {"from": from, "to": at, "wet": _wet(at), "path": path, "spread": spread}


## The float's flight's height over its line to `at`: higher the farther.
func _flight_h(at: Vector3) -> float:
	return 0.8 + 0.2 * Vector2(at.x - player.global_position.x, at.z - player.global_position.z).length()


## The cast arc's dots and ring (made once; the fight's line shows its tension with the same dots).
func _ensure_arc() -> void:
	if _arc != null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ARC_GOLD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 8
	dot.rings = 4
	dot.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = 64
	_arc = MultiMeshInstance3D.new()
	_arc.name = "CastArc"
	_arc.multimesh = mm
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc.top_level = true
	add_child(_arc)
	_ring_mat = mat.duplicate() as StandardMaterial3D
	var ring := TorusMesh.new()
	ring.inner_radius = 0.26
	ring.outer_radius = 0.32
	ring.material = _ring_mat
	_ring = MeshInstance3D.new()
	_ring.name = "CastRing"
	_ring.mesh = ring
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	add_child(_ring)
	_arc_mat = mat


## The cast's arc while it is held: gold dots along the float's flight and a ring it comes down within (its spread;
## grey on the bank: a float there would lie on the grass). As the torch's throw shows it (PlayerInteractor._show_arc).
func _show_arc(on: bool) -> void:
	if not on:
		if _arc:
			_arc.visible = false
			_ring.visible = false
		return
	_ensure_arc()
	_arc_mat.albedo_color = ARC_GOLD
	var pv := cast_preview()
	var path: PackedVector3Array = pv.path
	var mm := _arc.multimesh
	var n := 0
	var run := 0.0
	for i in range(1, path.size()):
		var seg := path[i].distance_to(path[i - 1])
		var steps := maxi(int(seg / 0.35), 1)
		for j in steps:
			run += seg / steps
			if run >= 0.35 and n < mm.instance_count:
				run = 0.0
				mm.set_instance_transform(n, Transform3D(Basis(), path[i - 1].lerp(path[i], float(j + 1) / steps)))
				n += 1
	mm.visible_instance_count = n
	_arc.global_transform = Transform3D()
	_arc.visible = true
	_ring.global_position = (pv.to as Vector3) + Vector3.UP * 0.04
	var tm := _ring.mesh as TorusMesh
	var r := maxf(float(pv.spread), 0.1)
	if absf(tm.outer_radius - (r + 0.03)) > 0.01:
		tm.inner_radius = r - 0.03
		tm.outer_radius = r + 0.03
	_ring_mat.albedo_color = ARC_GOLD if bool(pv.wet) else Color(0.7, 0.7, 0.68, 0.7)
	_ring.visible = true


## The cast goes where it was aimed: the player turns to it.
func _face_cast() -> void:
	var dir := _cast_dir()
	player.rotation.y = atan2(-dir.x, -dir.z)


func _cast_dir() -> Vector3:
	var at := _aim if _aim != Vector3.INF else cast_target()
	var d := at - player.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3(-sin(player.yaw), 0.0, -cos(player.yaw))


## The line goes out: the float flies to where the cast was aimed, coming down somewhere within its spread.
func _launch() -> void:
	var at := _aim if _aim != Vector3.INF else cast_target()
	var a := rng.randf() * TAU
	var r := spread * sqrt(rng.randf())
	at += Vector3(cos(a) * r, 0.0, sin(a) * r)
	at.y = _top_at(at)
	_arc_h = _flight_h(at)
	_aim = Vector3.INF
	_from = tip_point()
	_to = at
	float_pos = _from
	rod_state = Rod.FLIGHT
	_t = 0.0


## The water's top at p (-INF: none).
func _surface_at(p: Vector3) -> float:
	return WorldRiver.surface_at(p.x, p.z)


func _land_cast() -> void:
	_from = Vector3.ZERO
	var sy := _surface_at(float_pos)
	var wet := sy > -INF and WorldRiver.depth_at(float_pos) > 0.12
	cast_landed.emit(float_pos, wet)
	if not wet:
		rod_state = Rod.ASHORE
		float_pos.y = FrontierTerrain.height_at(float_pos.x, float_pos.z) + 0.02
		return
	float_pos.y = sy
	life = FishLife.find(get_tree()) if life == null else life
	bait = FishLife.Bait.new()
	bait.kind = "worm"
	bait.natural = 1.0
	_place_bait()
	if life:
		life.add_bait(bait)
		life._ring(float_pos, 0.45, 0.35)
		# the splash: the fish near where it came down are put down
		life.alarm(float_pos, SPLASH_M)
		if not life.bite.is_connected(_on_bite):
			life.bite.connect(_on_bite)
	rod_state = Rod.DRIFT
	_t = 0.0


## The worm under the float (less deep in the shallows, above the bottom).
func _place_bait() -> void:
	if bait == null:
		return
	var d := WorldRiver.depth_at(float_pos)
	bait.pos = float_pos + Vector3.DOWN * clampf(minf(FLOAT_DEPTH, d - 0.12), 0.05, FLOAT_DEPTH)


## Down with the current, held by the line: tight, the float swings across and the worm drags.
func _drift(dt: float) -> void:
	if bait == null:
		return
	var tip := tip_point()
	var p := float_pos
	if life:
		p += life.drift_at(p) * DRIFT_K * dt
	var reach := LINE_M
	var flat := Vector2(p.x - tip.x, p.z - tip.z)
	var tight := flat.length() > reach
	if tight:
		flat = flat.normalized() * reach
		p = Vector3(tip.x + flat.x, p.y, tip.z + flat.y)
	var sy := _surface_at(p)
	if sy == -INF or WorldRiver.depth_at(p) < 0.05:
		# into the shallows, onto the bank: the float grounds there
		rod_state = Rod.ASHORE if rod_state == Rod.DRIFT else rod_state
		return
	p.y = sy + (0.0 if rod_state == Rod.DRIFT else -0.06 * (1.0 + sin(_bite_t * 23.0)))
	float_pos = p
	bait.natural = SWING_NATURAL if tight else 1.0
	_place_bait()


func _on_bite(fish, b) -> void:
	if b != bait or rod_state != Rod.DRIFT:
		return
	rod_state = Rod.BITE
	_bite_t = 0.0


func _lift_out() -> void:
	_end_bait()
	rod_state = Rod.READY
	_t = 0.0


func _end_bait() -> void:
	if bait and life:
		if bait.hooked or bait.fish:
			life.release(bait)
		life.remove_bait(bait)
	bait = null
	_fish = null
	strain = 0.0


# --- A fish on ---------------------------------------------------------------------------------------------------

## A fish on. The line is tied to the rod's tip and is LINE_M long: while the fish (its mouth, the bait) is no farther
## from the tip, straight, the line hangs slack; past it the rod bows toward the fish, taking up to ROD_GIVE, and past
## that the line itself stretches toward its break. How far past is the tension: the rod's pull, and so the fish drawn
## toward the tip at PULL_K a metre over its heft (a fresh fish swims away against it: the harder and heavier, the
## further it pulls the rod over), and the pressure tires it (FishLife: its stamina runs down with the pull). The
## angler's pull (lift) moves the tip: drawn back, up and back over the shoulder, toward the angler; lowered, out toward
## the fish. Walking moves it too: away from the fish the line comes tight and drags it along.
func _fight(dt: float, pulling: bool) -> void:
	if bait == null or bait.fish == null or not bait.hooked:
		# it came off
		_end_bait()
		rod_state = Rod.READY
		return
	var fish = bait.fish
	if pulling:
		lift = move_toward(lift, 1.0, dt * LIFT_HOLD)
	lift_shown = move_toward(lift_shown, lift, dt * LIFT_FOLLOW)
	var at: Vector3 = bait.pos
	var tip := straight_tip()
	var past := tip.distance_to(at) - LINE_M
	var give := clampf(past, 0.0, ROD_GIVE)
	var over := maxf(past - ROD_GIVE, 0.0)
	tension = (TENSION_ROD * give / ROD_GIVE + (1.0 - TENSION_ROD) * over / (LINE_STRETCH * 0.5)) / line_strength()
	var flat := Vector3(tip.x - at.x, 0.0, tip.z - at.z)
	bait.pull = flat.normalized() * PULL_K * maxf(past, 0.0) / fish_heft(fish) if flat.length() > 0.05 else Vector3.ZERO
	# the rod bows toward it, as far as it gives (a little when slack: its own weight)
	_aim_bend(at - tip if past > -0.3 else Vector3.DOWN)
	bend = move_toward(bend, clampf(give / ROD_GIVE * 0.9 + over / LINE_STRETCH * 0.1, 0.04, 1.0), dt * 5.0)
	strain = strain + dt if tension >= 1.0 else maxf(strain - dt, 0.0)
	var sy := _surface_at(at)
	float_pos = Vector3(at.x, (sy if sy > -INF else at.y) - 0.05, at.z)
	if strain > LINE_GIVE or tension > SNAP_NOW:
		life.release(bait)
		life.remove_bait(bait)
		bait = null
		_fish = null
		line_broke.emit()
		_note("The line snaps")
		rod_state = Rod.READY
		bend = 0.0
		tension = 0.0
		return
	var me := player.global_position
	if float(fish.stamina) < LAND_STAMINA and Vector2(me.x - at.x, me.z - at.z).length() < LAND_M:
		_begin_land()


## How hard a fish is to move on the line (about 0.55 a one-pound trout, 1.9 a ten-pound salmon, 5.9 a fifty-pound
## sturgeon): a small one can be led in firmly; a fresh big one running away pulls the rod over into the line's
## stretch and has to be given line (the rod lowered, the angler going with it).
static func fish_heft(fish) -> float:
	return 0.25 + 0.3 * pow(maxf(float(fish.lb), 0.05), 0.75)


func _begin_land() -> void:
	rod_state = Rod.LAND
	_t = 0.0
	tension = 0.0
	bait.pull = Vector3.ZERO
	var fish = bait.fish
	_kneel_ap = player.begin_kneel(self, fish.pos)
	if _kneel_ap:
		_blender = HorsePhaseBlender.new(_kneel_ap, player, LIB)
		_blender.show_clip(CampCooking.CLIP_IN, 0.0, 0.0)
		_blender.update(0.0)


func _landing(dt: float) -> void:
	if _blender:
		_blender.update(dt)
	if _t < LAND_S:
		return
	var info := {}
	if life and bait:
		info = life.land_fish(bait)
		life.remove_bait(bait)
	bait = null
	_fish = null
	if player.kneeling == self:
		player.end_kneel()
	_blender = null
	rod_state = Rod.READY
	bend = 0.0
	tension = 0.0
	lift = 0.0
	if not info.is_empty():
		FishCatch.to_pack(player, info)
		_train("landed", float(info.get("lb", 0.0)))
		fish_landed.emit(info)


func _note(text: String) -> void:
	var h: Variant = player.get("hud")
	if h != null and is_instance_valid(h) and (h as Node).has_method("toast"):
		(h as Node).call("toast", text, "")


# --- Pose and drawing --------------------------------------------------------------------------------------------

func _anim(clip: String) -> Animation:
	if not _anims.has(clip):
		_anims[clip] = _own_anim(clip)
	return _anims[clip]


## The body's pose for the rod's state (the wind-up and the swing are the cast's layer over it).
func _want_pose() -> String:
	return "fight" if rod_state == Rod.FIGHT else "hold"


func _apply_pose() -> void:
	var sk := _skeleton()
	if sk == null:
		return
	if _pose == null:
		_pose = ToolPose.new()
		_pose.name = "FishingPose"
		sk.add_child(_pose)
		# the upper body kept facing the view over the legs' steps (strafing with the rod out)
		_stance = RodStance.new()
		_stance.name = "FishingStance"
		_pose.add_sibling(_stance)
	var want := _want_pose()
	if want != _pose_now:
		_pose_was = _pose_now
		_pose_now = want
		_pose_fade = 0.0
	_pose_fade = minf(_pose_fade + get_process_delta_time() / 0.2, 1.0)
	if _pose_w <= 0.0 or rod_state == Rod.LAND:
		_pose.layers = []
		_stance.weight = 0.0
		return
	var layers: Array = []
	var root_q := Quaternion.IDENTITY
	for pair in [[_pose_was, _pose_w], [_pose_now, _pose_w * _pose_fade]]:
		var a := _anim(String(POSES[pair[0]]))
		if a:
			var t := lift_shown * a.length if pair[0] == "fight" else fmod(_hold_t, a.length)
			layers.append({"anim": a, "time": t, "weight": float(pair[1]), "mask": "upper"})
			root_q = _clip_root(a, t)
	# the cast over the hold: the club's swing, both arms; eased back to the hold when it is done
	if not _cast.is_empty():
		var cw := _pose_w
		if float(_cast.done_t) >= 0.0:
			cw *= 1.0 - smoothstep(0.0, CAST_EASE, float(_cast.done_t))
		elif float(_cast.u) < 0.12:
			cw *= smoothstep(0.0, 0.12, float(_cast.u))
		var cl := AxeMelee.clip_at(_cast, float(_cast.u))
		layers.append({"anim": cl[0], "time": cl[1], "weight": cw, "mask": "upper"})
		root_q = root_q.slerp(_clip_root(cl[0], float(cl[1])), clampf(cw / maxf(_pose_w, 1e-3), 0.0, 1.0))
	_pose.layers = layers
	_stance.root_q = root_q
	_stance.weight = _pose_w


## A clip's root turn at `t` (the body's facing the clip's upper body was keyed over; the rest's without a root track).
func _clip_root(a: Animation, t: float) -> Quaternion:
	var sk := _skeleton()
	for i in a.get_track_count():
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D and String(a.track_get_path(i).get_concatenated_subnames()) == "root":
			return a.rotation_track_interpolate(i, clampf(t, 0.0, a.length))
	var r := sk.find_bone("root") if sk else -1
	return sk.get_bone_rest(r).basis.get_rotation_quaternion() if r >= 0 else Quaternion.IDENTITY


func _draw_rod() -> void:
	if gear != "fishing_rod":
		return
	# the rod's model lies along +Z from its butt: in both hands as the clips hold it (rod_transform), bowed
	var rt := rod_transform()
	_rod.global_transform = rt
	if _rod_mat:
		_rod_mat.set_shader_parameter("bend", bend)
		_rod_mat.set_shader_parameter("bend_dir", _bend_dir)
	var tip := bent_point(ROD_M, rt)
	var show_float := rod_state in [Rod.FLIGHT, Rod.DRIFT, Rod.BITE, Rod.FIGHT, Rod.ASHORE]
	_float.visible = show_float and rod_state != Rod.FIGHT
	_float.global_position = float_pos
	# the line: tip to float (to the fish's mouth, a fish on), sagging as it is slack
	_line_mesh.clear_surfaces()
	var end := float_pos if show_float else tip + Vector3.DOWN * 0.9
	if rod_state == Rod.FIGHT and bait:
		end = bait.pos
	var slack := clampf(1.0 - tip.distance_to(end) / (LINE_M + 0.5), 0.0, 1.0)
	if rod_state == Rod.FIGHT:
		slack = clampf((LINE_M - straight_tip().distance_to(end)) / LINE_M, 0.0, 1.0)
	var pts := PackedVector3Array()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var k := float(i) / 12.0
		pts.append(tip.lerp(end, k) + Vector3.DOWN * sin(PI * k) * slack * 0.8)
		_line_mesh.surface_add_vertex(pts[i])
	_line_mesh.surface_end()
	if rod_state == Rod.FIGHT:
		_line_dots(pts)
	elif rod_state != Rod.WINDUP and _arc and _arc.visible:
		_arc.visible = false
	if _gauge == null and is_inside_tree():
		_gauge = FishFightGauge.new()
		_gauge.gear = self
		add_child(_gauge)


## A fish on: the line's tension shown as the cast's arc was (user 2026-09-28: "it should be the using the cast effect
## animation to show tension as well"): the same dots along the line from the rod's tip to the fish, flowing toward the
## angler, the faster the harder it pulls; gold while it is easy, orange coming tight, red toward the break, and beating
## over it; faint while the line is slack.
func _line_dots(pts: PackedVector3Array) -> void:
	_ensure_arc()
	_ring.visible = false
	var dt := get_process_delta_time()
	_flow = fmod(_flow + dt * (0.35 + 2.2 * minf(tension, 1.3)), 1.0)
	var col := ARC_GOLD.lerp(TAUT, smoothstep(0.35, 0.7, tension)).lerp(BREAKING, smoothstep(0.8, 1.0, tension))
	col.a *= lerpf(0.35, 1.0, smoothstep(0.0, 0.25, tension))
	var big := lerpf(1.3, 2.4, smoothstep(0.3, 1.0, tension))
	if tension >= 1.0:
		var beat := absf(sin(Time.get_ticks_msec() * 0.014))
		col.a *= 0.55 + 0.45 * beat
		big *= 1.0 + 0.3 * beat
	_arc_mat.albedo_color = col
	var step := 0.32
	var lens := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := lens[lens.size() - 1]
	var mm := _arc.multimesh
	var n := 0
	# from the fish's end toward the tip, offset by the flow: they run in along the line
	var d := step * (1.0 - _flow)
	var j := pts.size() - 1
	while d < total and n < mm.instance_count:
		var at := total - d
		while j > 1 and lens[j - 1] > at:
			j -= 1
		var k := (at - lens[j - 1]) / maxf(lens[j] - lens[j - 1], 1e-4)
		mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3.ONE * big), pts[j - 1].lerp(pts[j], k)))
		n += 1
		d += step
	mm.visible_instance_count = n
	_arc.global_transform = Transform3D()
	_arc.visible = true
