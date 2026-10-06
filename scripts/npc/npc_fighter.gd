class_name NpcFighter
extends CharacterBody3D
## A human fighter (audit item 1: "nobody in the game can patrol, notice the player, fight, flee or be talked to"): a French
## marine, a Canadian militiaman, a valley militiaman, a tough, a watchman (data/npc/factions.json). Its body is NpcBody (Actor_B
## in its faction's garments, a few clips by AnimationPlayer, animation level of detail); its mind NpcBrain (patrol, notice,
## suspect, fight, flee, surrender); NpcSquad spawns and orders them. Group FIGHTERS ("npc_fighters"); `tag` for the story's
## kill counts (StoryObjectives reads tag, state_name(), is_dead(), health and target).
##
##   walking    on the walk grid (NavMover with use_grid: WalkGrid plans the way once, WalkPath walks it, rays adjusting it a few
##              times a second), straight at the goal with a light probe where there is no way; a step up on a log (BodyStep).
##              A plan costs a few ms on the main thread, so a goal that moves (a foe it chases) is planned for again only when
##              it has moved well off the last plan's (GOAL_SNAP_M, GOAL_SNAP_FRAC of the way) and at most once each REPLAN_S
##              (each man's clock staggered); a new errand (a jump much bigger than that) is planned at once; a foe in sight
##              within STRAIGHT_M is run at straight (the brain says so: go(..., straight)), the grid left out until it is held up
##   the musket to the shoulder and on the foe (HuntAim, the rifle aim clip), aimed as a person aims (the user, 2026-10-04:
##              "npc can find cover aim and etc"; begin_aim, aim_cfg by the skill: SKILLS, apply_skill): a REACTION when the foe
##              has just come into sight (the brain says), then the aim SETTLING on him (the barrel comes up off to one side
##              by err0_deg and closes in over settle_s: the faction's aim_s for a line fighter), laid on his chest or, when
##              only his head shows over his cover, his head, AHEAD of him as he moves by his pace over the ball's flight (as
##              much of it as its lead says); out of its sight it holds the aim where he went (hold_s) and fires once he is back
##              (reacquire_s), else puts it down. Then the game's own ball (NpcBall: a Projectile; aimed by
##              Weapon.ballistic_dir; a skill preset's line scattered about the aim by spread_deg, one sigma: more at a moving
##              foe or a hurried shot, less crouched; a line fighter's in a disc about it by its skill and the range, as it
##              always was: the raid's and the squads' fights go as they did), the muzzle's fire and smoke (Fx.muzzle_blast, the one shared light:
##              NpcSenses), the report (Sfx musket_shot), heard by the fighters (NpcSenses.noise) and the wildlife
##              (WildlifeSpawner.shot); each shot's error kept (last_shot, shot_errs); then the long reload (the rifle reload
##              clips over the stance, the faction's reload_s x the skill's reload_mult), paused by moving or a flinch, kept
##              where it got to
##   tactics    "line" (the raid's and the squads': it fires where it has a shot and goes behind cover to load) or "cover"
##              (NpcSkirmish: it fights from cover, peeking out to fire and back to load, cover to cover; the duel's
##              opponent, DuelMode); a side-step out to peek keeps it facing the foe (face_lock: the aimed side-steps), a
##              dash in his sight is a sprint (SPRINT_SPEED)
##   blows      the musket's butt or an axe (our own club stab and axe swing clips), struck through Hit.deliver as the
##              player's (no head bonus for a blow); the butt bruises the player, the axe cuts (SWINGS' kind: the damage_kind
##              meta PlayerWounds reads, on it for the blow only). A man with a musket clubs; the axe is for one without
##   hits       Hit.deliver finds apply_hit from its walking body (a capsule to the shoulders) or its hit parts (the torso and
##              the head on its bones, NpcBody): those only catch the round; its path through his fitted body (Anatomy: the
##              bones, organs, vessels and cord; the user 2026-10-03, "how our game detects hits") decides what it does: a line
##              past his body is a miss, else HURT_MULT of what the hunt's numbers do to a beast x what it tore through, BLEED_NOW
##              of it at once and the rest bled over the next minute (the pool, at the wound's pace: an artery fast); the brain,
##              the brainstem or the cord at the neck kill at once, the heart, the aorta, a carotid or the cord to T6 in seconds
##              (the mortal clock); the cord below the shoulders or both legs broken and he goes down for good (down: alive,
##              out of the fight); a leg's bone broken and he limps (no running: limp), a lung and he cannot run; an arm's bone
##              broken and he drops his weapon and runs (arm_broken). Struck it flinches, the blood (BloodFx)
##   death      the death clip by the side the blow came from (or the crouched fall; played to its end even when the budget
##              had him frozen), its hit parts gone, a loot pack where it lies (NpcLoot: the faction's loot and its weapon),
##              died emitted; the player's kills counted by tag (kills). Settled, his body rests (NpcBody.rest) and he is
##              one of NpcSenses' dead; long after, unseen, his body is cleared (clear_away; the node stays for the story).
##              A man run off and far away a while leaves the field the same way (leave_field)
##   surrender  on its knees, its weapon laid down in a loot pack at its feet; E: "Let him go" (it walks off, out of the fight)
##   inspect    dead, E (or M) on him: "Inspect the body" (InspectView: every shot's path through him); alive too with
##              InspectView.debug_living
##   talk       a fighter not hostile to the player, not fighting: E talks (the faction's talk barks); barks over the head when
##              the player is near (alert, combat, flee, surrender)

signal died(fighter: NpcFighter, killer: Node)
signal state_changed(fighter: NpcFighter, state: String)
## no_death (the ring: winded, never killed): what would have killed left him at 1 health instead; `by` who did it.
signal winded(by: Node)

const GROUP := &"npc_fighters"
const WALK_SPEED := 1.3
const RUN_SPEED := 3.4
const CROUCH_SPEED := 0.85
## A dash between covers in the foe's sight, and the aimed side-step out to peek and back (the aim walks' own pace is
## 0.55 m/s: played a little fast).
const SPRINT_SPEED := 4.4
const STRAFE_SPEED := 0.85
const GRAVITY := 18.0
const ACCEL := 4.5
const DECEL := 7.0
const RADIUS := 0.3
## The walking capsule's height standing and crouched: to the shoulders, so a shot at the head meets the head part above it.
const STAND_H := 1.45
const CROUCH_H := 1.0
const HEALTH := 100.0
## What a hit does to a man against the hunt's numbers for a beast (as the player's HUMAN_RANGED_MULT, a little harder).
const HURT_MULT := 0.7
## A blow or a ball of less than this does not make him flinch.
const FLINCH_MIN := 8.0
## A knock (BendKnock) this hard (m/s, flat) or more makes him flinch (and loses a cast's lock); under it he only reels.
const FLINCH_KNOCK_MPS := 7.0
## A bleeding wound: this much of the hit comes off at once, the rest is the pool, bled at DRAIN of it a second (x the wound's
## drain) while CLOT of it closes (as the player's PlayerWounds, without the rest and the dressings).
const BLEED_NOW := 0.5
const DRAIN := 0.04
const CLOT := 0.02
## The musket's ball: the player's Musket's numbers.
const BALL_SPEED := 320.0
const BALL_GRAVITY := 9.8
const BALL_DRAG := 0.25
const BALL_DAMAGE := 120.0
## The aim by skill (apply_skill; the duel's difficulty, DuelMode; a squad's opts "skill"; the user, 2026-10-04: "errors by a
## SKILL value"): skill (0..1, as a faction's), the reaction to a foe newly in sight before the musket comes up (s), how long
## the aim takes to settle on him (s), its error as it comes up and the ball's spread once settled (deg, one sigma of its
## line), how much of a moving foe's lead it takes (1 all), how long it holds the aim where he went out of sight (s), how long
## he must be back in sight before it fires (s), the reload's pace (x the faction's reload_s). A fighter with no preset
## aims by its faction's numbers (FACTION_AIM).
const SKILLS := {
	"easy": {"skill": 0.3, "reaction_s": 0.85, "settle_s": 1.7, "err0_deg": 7.0, "spread_deg": 1.2, "lead": 0.45,
			"hold_s": 0.7, "reacquire_s": 0.45, "reload_mult": 1.15},
	"normal": {"skill": 0.6, "reaction_s": 0.5, "settle_s": 1.15, "err0_deg": 4.5, "spread_deg": 0.6, "lead": 0.8,
			"hold_s": 1.5, "reacquire_s": 0.3, "reload_mult": 1.0},
	"hard": {"skill": 0.85, "reaction_s": 0.28, "settle_s": 0.75, "err0_deg": 3.0, "spread_deg": 0.38, "lead": 0.95,
			"hold_s": 2.4, "reacquire_s": 0.18, "reload_mult": 0.85},
}
## A line fighter's aim by its faction (no preset): no reaction beyond its aim_s (the settling), its ball in the disc it always
## had (_fire: (0.12 + 0.02 d) (1.5 - skill) m about the aim; spread_deg the like spread for the record, SPREAD_K x (1.5 -
## skill) deg), the lead half its skill and a half.
const FACTION_AIM := {"reaction_s": 0.0, "settle_s": -1.0, "err0_deg": 3.5, "hold_s": 0.5, "reacquire_s": 0.2, "reload_mult": 1.0}
const SPREAD_K := 0.48
## How far the blows reach (m) and each kind's clips, damage, strike time into its swing clip (s) and the wound it makes on the
## player (PlayerWounds.kind_of reads the striker's damage_kind meta: the musket's butt is blunt force, the axe cuts).
const REACH := 1.9
const SWINGS := {
	"axe": {"intro": "axe_intro", "hit": "axe", "damage": 40.0, "strike": 0.36, "kind": "bleed"},
	"club": {"intro": "club_intro", "hit": "club", "damage": 30.0, "strike": 0.22, "kind": "blunt"},
}
## The walk's plans (see walking above): a foe seen within STRAIGHT_M is run at straight; a moving goal is planned for again when
## it has moved more than GOAL_SNAP_M or GOAL_SNAP_FRAC of the way off the last plan's, at most once each REPLAN_S.
const STRAIGHT_M := 12.0
const GOAL_SNAP_M := 3.0
## On a deck (on_deck): how far ahead it looks for the floor before it steps.
const DECK_LOOK_M := 0.8
const GOAL_SNAP_FRAC := 0.3
const REPLAN_S := 1.0
const RECOIL_S := 0.6
const THINK_S := 0.25
const BARK_S := 2.5
const BARK_M := 35.0
## What it gets over on its walk (WalkGrid `can`): a person's step and wading, but no vault or mantle (it has no traversal
## moves yet), and a log lying about no higher than its step assist takes it (BodyStep): what is higher it walks round.
const CAN := {"step_m": 0.45, "low_step_m": 0.55, "climb_m": 0.0, "wade_m": 0.6, "slope_max": 38.0}
## The felling axe in the hand (SparringPartner.PIPE: the pipe grip our own swings hold it in).
const AXE_GRIP := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0, -0.035))

## Fighters the player has killed, by tag (the story's counts).
static var kills := {}

## Set before it enters the tree (NpcSquad does): its faction, tag, look ({}: one of the faction's), weapon and sidearm
## ("default": the faction's), and a seed for its choices (0: random).
var faction := "militia"
var tag := ""
var look := {}
var weapon := "default"
var sidearm := "default"
var rng_seed := 0
var label := "fighter"
var health := HEALTH
var health_max := HEALTH
## 0..1: how close its ball goes to where it aims; how much it takes before it runs (the faction's).
var skill := 0.5
var courage := 0.5
## How it fights (set before it enters the tree; NpcSquad's opts "tactics"): "line" or "cover" (NpcSkirmish; see tactics above).
var tactics := "line"
## Its aim's skill preset ("" its faction's numbers; "easy", "normal", "hard": SKILLS; NpcSquad's opts "skill"); apply_skill
## sets it and aim_cfg, the numbers it aims by (reaction_s, settle_s, err0_deg, spread_deg, lead, hold_s, reacquire_s,
## reload_mult).
var skill_preset := ""
var aim_cfg := {}
## It runs when hurt past its courage (false: the duel's opponent falls back to cover further off and fights on; an arm's bone
## broken, it still drops its weapon and runs).
var flees := true
## The foe it fights, out of its sight this long (s), is given up (NpcBrain.CALM_S; the duel's opponent never gives him up).
var calm_s := NpcBrain.CALM_S
## Held where it stands (the duel's countdown): its brain does not think, it does nothing.
var held := false
## Its feet held (a bend's root, BendStatus.root): it does not walk, its brain still thinks and it still casts.
var feet_held := false
## A jump asked for this frame (jump(): an element bot over a wave along the deck), m/s up; 0 none.
var _jump_v := 0.0
## Never killed (Tidebreak's ring, RingRules; set on its competitors): every death (a blow, a mortal wound, a bleed-out, a
## script's die()) leaves him at 1 health, his wounds stopped, and emits winded(by) instead.
var no_death := false
## Its brain's thoughts so far (NpcBrain.think: tests, a rooted fighter still thinking).
var thinks := 0
## Its element ("" none; "earth", "water", "fire", "air": an element bot, NpcBending; set before it enters the tree: NpcSquad's
## opts "element"). BendPoses.element_of reads it for its cast poses.
var element := ""
## On a raised deck (Tidebreak's ring; an element bot with the ring's edge_fn sets it): it walks straight (the walk grid does not
## see a deck), and stops short of where the floor ends ahead (_straight_to's look down).
var on_deck := false
## What a hit does to it against the hunt's numbers (HURT_MULT; an element bot takes the player's whole: the same blow, the same
## hurt, either way).
var hurt_mult := HURT_MULT
## Moving, it keeps facing this point (a side-step out past cover to peek and back: the aimed side-steps), INF: the way it goes.
var face_lock := Vector3.INF
## Its shots (tests, the debug view): the last {at, mark, err_deg, d, spread_deg, part, react} and the last few errors (deg).
var last_shot := {}
var shot_errs: Array[float] = []
var loaded := true
var squad: NpcSquad
## Where it stands when it has nothing to do; its patrol's points; its order ("attack": `order` a Node3D or a Vector3,
## "hold": `order` the place, "patrol").
var home := Vector3.INF
var patrol := PackedVector3Array()
var order_kind := ""
var order: Variant = null
var brain: NpcBrain
var body: NpcBody
var nav: NavMover
var gun: Node3D
var axe: Node3D
var loot: NpcLoot
var is_crouching := false
## Frozen by the frame budget (NpcSenses: more than MAX_ANIMATED about): its pose stepped seldom, its brain slower.
var frozen := false
var killed_by: Node = null
## The foe it is after (NpcBrain's), for the story.
var target: Node3D = null
## What it is doing with its hands: "", "aim", "recoil", "reload", "swing", "flinch", "dead".
var action := ""
## Counters for the tests and the debug view.
var shots := 0
var blows := 0
var hits_taken := 0
var last_bark := ""
var interact_reach := 2.6
var rng := RandomNumberGenerator.new()
## Seconds it has lain settled dead, or been out of the fight (routed, let go) and far off: NpcSenses counts them to clear the
## field (clear_away, leave_field).
var away_t := 0.0
## Gone from the field (leave_field: run off or let go, far from everyone): no body, no frame, out of NpcSenses' lists; the
## node stays for the story (alive, routed).
var left_field := false
## His wounds (Anatomy.effect): the blood still to lose and how fast it goes, a mortal wound's clock (s; 0 none), what is left of
## his walk (1 whole: a broken leg's bone, a lung: no running), the arm's bone broken ("" none: it cannot hold or aim), down for
## good (the cord below the shoulders, both legs: alive, out of the fight).
var pool := 0.0
var drain_mult := 1.0
var mortal_left := 0.0
var limp := 1.0
var arm_broken := ""
var down := false
var _hurt_by: Node = null
## The legs whose bone is broken badly enough to give under him ("Left", "Right"): both, and he is down.
var _legs_broken := {}
## The packs it left (its loot where it fell, its weapon laid down when it gave up): NpcSenses clears the untouched ones long
## after, when no one is near.
var packs: Array[NpcLoot] = []

var _act_t := 0.0
var _aim_at: Node3D
## The aim under way (begin_aim): what it aims at, the time since it began, the reaction and the settling, the hurried shot;
## where it lays it on him (seen: his part, led), the first error's way across the line (a unit Vector2) and size (rad), how
## long he has been out of its sight and back in it, and whether he went out of it during this aim.
var _aim_part := "chest"
var _aim_t := 0.0
var _aim_react := 0.0
var _aim_settle := 1.0
## (the settling its error closes in over: the whole of it, also for a hurried shot fired halfway, its error still large)
var _aim_settle_full := 1.0
var _aim_hurry := false
var _aim_spot := Vector3.ZERO
var _aim_err_dir := Vector2.RIGHT
var _aim_err0 := 0.0
var _aim_unseen := 0.0
var _aim_seen_for := 0.0
var _aim_lost := false
var _reload_left := 0.0
var _reload_total := 0.0
var _swing: Dictionary = {}
var _swing_t := 0.0
var _swing_intro := 0.0
var _swing_len := 0.0
var _swing_struck := false
var _swing_hit_on := false
var _swing_at: Node3D
var _goal := Vector3.INF
var _speed := 0.0
var _arrive := 0.8
## Run straight at the goal (a foe in sight near: go's `straight`); the goal the walk grid last planned for, and the time since.
var _straight := false
var _nav_goal := Vector3.INF
var _replan_t := 0.0
var _face := 0.0
var _think_t := 0.0
var _dead := false
var _settle_t := 0.0
var _surrendered := false
var _released := false
var _dropped := false
var _steer_t := 0.0
## The turn off the straight line its probe last chose (rad: 0 the line itself), kept between probes while the line itself
## follows the goal each frame.
var _steer_k := 0.0
## On a deck: the floor found ahead at the last probe (_floor_at).
var _floor_ahead := true
var _stuck_t := 0.0
var _last := Vector3.ZERO
var _dt := 0.0
var _step: BodyStep
var _cap: CapsuleShape3D
var _col: CollisionShape3D
var _bark: Label3D
var _bark_t := 0.0
## Tidebreak's % ring (round 3, smash_r3 spec §9.1, §4.9): its RingMoves while a stock-rules ring installed one (it sets this
## itself), else null; and the pad its mind fills (NpcPad: the same intent as the player's keys). With a RingMoves the body
## moves only through RingMoves.pre(pad.intent(), dt): it never writes its own velocity. With none, exactly as before.
var ring_moves: RingMoves = null
var pad := NpcPad.new()
var _ring_lean := false


func _enter_tree() -> void:
	if left_field:
		return
	var list := NpcSenses.corpses if settled() else NpcSenses.fighters
	if not list.has(self):
		list.append(self)


func _exit_tree() -> void:
	if brain != null and brain.bending != null:
		brain.bending.on_exit()                    # (its lock's circle and the zones it holds round itself go with it)
	NpcSenses.fighters.erase(self)
	NpcSenses.corpses.erase(self)
	NpcSenses.forget(self)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(WildlifeSpawner.PEOPLE)   # PEOPLE: the wild keeps off them as off the player
	add_to_group(PlacedWeapon.GROUP)       # (E: talk, let go)
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.4
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var f := NpcFactions.get_faction(faction)
	label = String(f.get("label", faction))
	skill = float(f.get("skill", skill))
	courage = float(f.get("courage", courage))
	apply_skill(skill_preset)
	if weapon == "default":
		weapon = String(f.get("weapon", "musket"))
	if sidearm == "default":
		sidearm = String(f.get("sidearm", ""))
	# (one weapon in the hands: a man with a musket clubs with its butt; the axe is the sidearm of a man without one)
	_col = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cap.radius = RADIUS
	_cap.height = STAND_H
	_col.shape = _cap
	_col.position.y = STAND_H * 0.5
	add_child(_col)
	body = NpcBody.new()
	body.name = "Body"
	add_child(body)
	body.build(look if not look.is_empty() else NpcFactions.look_for(faction, rng))
	if weapon == "musket":
		gun = WeaponModels.build("musket")
		body.hold(gun, SlingRig.HAND_OFFSET)     # (at the player's grip: his musket_offset)
	elif sidearm == "axe":
		axe = GatherModels.build("felling_axe")
		body.hold(axe, AXE_GRIP)
	# the walk: planned on the walk grid and walked by rays (no navigation mesh baked round it: NavMover is not registered)
	nav = NavMover.new(null, RADIUS)
	nav.body = self
	nav.use_grid = true
	nav.landmarks = false
	nav.can = CAN.duplicate()
	_step = BodyStep.new(self, TravStepAssist.MAX_RISE)
	brain = NpcBrain.new(self)
	if home == Vector3.INF:
		home = global_position
	_face = rotation.y
	_last = global_position
	_think_t = rng.randf() * THINK_S
	_replan_t = rng.randf() * REPLAN_S        # (each man's replans at his own time, not all in one frame)
	NpcSenses.of(get_tree())


# ---------------------------------------------------------------- what the story and the others read
func is_dead() -> bool:
	return _dead


## Out of the fight: on its knees, let go, or down (the cord, both legs).
func surrendered() -> bool:
	return (_surrendered or _released or down) and not _dead


## On its knees now (surrendered, not let go yet).
func kneeling() -> bool:
	return _surrendered and not _dead


## Dead and lying still (its death clip played out).
func settled() -> bool:
	return _dead and _settle_t <= 0.0


func state_name() -> String:
	return NpcBrain.NAMES[brain.state] if brain != null else "IDLE"


func eye() -> Vector3:
	return global_position + Vector3.UP * (1.05 if is_crouching else 1.6)


func forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


## Its own bodies (its walking capsule and its hit parts): left out of its rays and its shots.
func ray_exclude() -> Array[RID]:
	var ex: Array[RID] = [get_rid()]
	if body != null:
		ex.append_array(body.part_rids())
	return ex


# ---------------------------------------------------------------- orders (NpcSquad)
## Attack `t`: a Node3D (the player, a fighter) it goes after, or a place (Vector3) it goes to and holds.
func order_attack(t: Variant) -> void:
	order_kind = "attack"
	order = t


func order_hold(at: Vector3) -> void:
	order_kind = "hold"
	order = at
	home = at


func order_patrol(points: PackedVector3Array) -> void:
	order_kind = "patrol"
	patrol = points


## A loud noise heard (NpcSenses.noise).
func hear(pos: Vector3, radius: float, source: Node) -> void:
	if brain != null and not _dead:
		brain.heard(pos, radius, source)


# ---------------------------------------------------------------- the brain's hands and feet
## Walk (or run, by `speed`) to `to`, there within `arrive`; `straight`: run straight at it (a foe in sight near: no plan on
## the walk grid while nothing holds it up). Moving puts a reload by (kept where it got to) and lowers an aim.
func go(to: Vector3, speed: float, arrive := 0.8, straight := false) -> void:
	if action == "reload" or action == "aim":
		_put_by()
	_goal = to
	_speed = speed
	_arrive = arrive
	_straight = straight


func halt() -> void:
	_goal = Vector3.INF
	if ring_moves != null:
		pad.move = Vector3.ZERO


func arrived() -> bool:
	return _goal == Vector3.INF or _flat(global_position, _goal) <= _arrive + 0.05


## Its way is lost: the walk grid found none, or it has made no headway a while.
func way_blocked() -> bool:
	return (nav != null and nav.status == NavMover.FAILED) or _stuck_t > 2.5


func crouch(on: bool) -> void:
	if on == is_crouching or _cap == null:
		return
	is_crouching = on
	_cap.height = CROUCH_H if on else STAND_H
	_col.position.y = _cap.height * 0.5


func face_point(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.05:
		_face = atan2(-d.x, -d.z)


## Busy with its hands (it holds still meanwhile; "knocked": reeling from a knock, BendKnock's window).
func busy() -> bool:
	return action in ["aim", "recoil", "reload", "swing", "flinch", "down", "cast", "knocked"]


## The knock it is taking (BendKnock; for the pose layer: a knocked slide, an airborne clip): seconds left of its reaction
## window (0: none).
func knock_t() -> float:
	var kn := BendKnock.peek(self)
	return kn.knock_t if kn != null else 0.0


## A jump off the floor at `mps` up (an element bot jumping a wave along the deck: NpcBending; Tidebreak's floor rule, the
## player's Space). Its lock goes on (a jump never gates one). False when it is not on the floor, dead, held, or its feet are.
func jump(mps: float) -> bool:
	if _dead or held or feet_held or not is_on_floor() or mps <= 0.0:
		return false
	if ring_moves != null:
		pad.press("jump")                           # (the % ring: Space on its pad, the ring's full jump)
		return true
	_jump_v = mps
	return true


## In the air from a knock-up (BendKnock), until back on the floor.
func is_launched() -> bool:
	var kn := BendKnock.peek(self)
	return kn != null and kn.is_launched()


## Knocked along `v` (m/s; its up part lifts it) by `by`, through BendStatus.knock (an anchor holds it; the same knock as the
## player's: BendKnock). True when it was knocked.
func launch(v: Vector3, by: Node) -> bool:
	if _dead or v.length_squared() < 1e-4:
		return false
	var kn := BendKnock.of(self)
	var n0 := kn.knocks
	BendStatus.knock(self, v, by)
	return kn.knocks > n0


## Thrown back by `push` and staggered (SwayEffects.shove_fighter: Gust's push, a spike's shove): the knock (launch), and
## the stagger always, as before BendKnock.
func shove(push: Vector3, by: Node) -> void:
	if launch(Vector3(push.x, 0.0, push.z), by) and push.length_squared() > 1e-6 and action != "flinch":
		_flinch(push.normalized())


## BendKnock's word of a knock taken: its brain told who did it; FLINCH_KNOCK_MPS or more a flinch, under it it reels
## ("knocked", busy until the knock's window is over); a body that has a knock clip plays it.
func on_bend_knock(v: Vector3, by: Node) -> void:
	if _dead:
		return
	var flat := Vector3(v.x, 0.0, v.z)
	if brain != null:
		brain.hurt(by, flat.normalized() if flat.length_squared() > 1e-6 else Vector3.ZERO)
	if brain != null and brain.bending != null:
		brain.bending.on_knocked(v, by)             # (a knock loses a lock under way)
	if flat.length() >= FLINCH_KNOCK_MPS:
		_flinch(flat.normalized())
	elif action == "":
		action = "knocked"
	if body != null and body.has_method(&"play_knock"):
		body.call(&"play_knock", v)


## The aim's numbers for `preset` (SKILLS; "" or none of them: its faction's, FACTION_AIM with the spread from its skill and
## its aim_s for the settling); _ready sets them, the duel's difficulty again (DuelMode.set_difficulty).
func apply_skill(preset := skill_preset) -> void:
	skill_preset = preset if SKILLS.has(preset) else ""
	if skill_preset != "":
		aim_cfg = (SKILLS[skill_preset] as Dictionary).duplicate()
		skill = float(aim_cfg.skill)
	else:
		aim_cfg = FACTION_AIM.duplicate()
		aim_cfg["skill"] = skill
		aim_cfg["spread_deg"] = SPREAD_K * (1.5 - clampf(skill, 0.0, 1.0))
		aim_cfg["lead"] = 0.5 + 0.5 * clampf(skill, 0.0, 1.0)


## The musket to the shoulder and laid on `t` (false: it cannot now): `react` s for the foe newly in sight (the brain's call:
## aim_cfg.reaction_s), then the aim settles on him over settle_s (the faction's aim_s when it has no preset; longer past
## 50 m, halved when `hurry`: a foe on it, a snap shot), at his chest or his head (`part` "head": all of him that shows), led
## as he moves; fired once settled with him in sight (see the header).
func begin_aim(t: Node3D, part := "chest", react := 0.0, hurry := false) -> bool:
	if gun == null or not gun.visible or not loaded or busy() or not NpcSenses.can_fight(t) or arm_broken != "":
		return false
	action = "aim"
	_aim_at = t
	_aim_part = part
	var d := global_position.distance_to(t.global_position)
	var settle := float(aim_cfg.get("settle_s", -1.0))
	settle = NpcFactions.pick(faction, "aim_s", Vector2(1.0, 1.5), rng) if settle <= 0.0 else settle * rng.randf_range(0.85, 1.15)
	_aim_settle_full = settle * (1.3 if d > 50.0 else 1.0)
	_aim_settle = _aim_settle_full * (0.5 if hurry else 1.0)
	_aim_react = maxf(react, 0.0)
	_aim_hurry = hurry
	_aim_t = 0.0
	_aim_unseen = 0.0
	_aim_seen_for = 0.0
	_aim_lost = false
	# (most of a man's first error is across, less up and down; a line fighter's drawn from no die of its own: its choices
	# fall as they always did)
	var a := rng.randf() * TAU if skill_preset != "" else float((get_instance_id() + shots * 7919) % 6283) * 0.001
	_aim_err_dir = Vector2(cos(a), sin(a) * 0.6)
	_aim_err0 = deg_to_rad(float(aim_cfg.get("err0_deg", 3.5)) * (rng.randf_range(0.7, 1.15) if skill_preset != "" else 1.0))
	_aim_spot = _lead_point(t, part)
	halt()
	face_lock = Vector3.INF
	face_point(t.global_position)
	return true


## The aim's error now (rad): the first error closing in over the settling, after the reaction (tests, the debug view).
func aim_error_now() -> float:
	return _aim_err0 * exp(-3.0 * maxf(_aim_t - _aim_react, 0.0) / maxf(_aim_settle_full, 0.05)) if action == "aim" else 0.0


## Seconds into the aim under way, and when it may fire (its reaction and its settling), for the tests.
func aim_clock() -> Vector2:
	return Vector2(_aim_t, _aim_react + _aim_settle) if action == "aim" else Vector2(-1.0, -1.0)


## The reload begun, or taken up again where it was put by.
func begin_reload() -> void:
	if gun == null or not gun.visible or loaded or busy() or arm_broken != "":
		return
	if _reload_left <= 0.0:
		_reload_total = NpcFactions.pick(faction, "reload_s", Vector2(8.0, 9.0), rng) * float(aim_cfg.get("reload_mult", 1.0))
		_reload_left = _reload_total
	action = "reload"
	halt()


## How much of the reload is done (0..1; 1 loaded).
func reload_done() -> float:
	if loaded:
		return 1.0
	return clampf(1.0 - _reload_left / maxf(_reload_total, 0.01), 0.0, 1.0) if _reload_left > 0.0 else 0.0


## Put the reload by (a foe on it): it keeps where it got to.
func cancel_reload() -> void:
	if action == "reload":
		action = ""


## A blow at `t` (the musket's butt, or the axe; false: busy).
func swing_at(t: Node3D) -> bool:
	if (action != "" and action != "reload") or arm_broken != "":
		return false
	_put_by()
	var kind := "axe" if axe != null else "club"
	_swing = SWINGS[kind]
	_swing_at = t
	_swing_t = 0.0
	_swing_struck = false
	_swing_hit_on = false
	_swing_intro = body.play_once(String(_swing.intro), 0.12)
	_swing_len = body.clip_length(String(_swing.hit))
	body.set_arms("")
	action = "swing"
	halt()
	if t != null:
		face_point(t.global_position)
	return true


## On its knees, out of the fight: its weapon laid at its feet.
func surrender() -> void:
	if _surrendered or _dead or down:
		return
	_surrendered = true
	_put_by()
	action = ""
	halt()
	crouch(true)
	_lay_down_weapon()
	bark("surrender")


## Let go (E on one who surrendered): it walks off, out of the fight for good.
func release() -> void:
	if not _surrendered or _dead:
		return
	_surrendered = false
	_released = true
	crouch(false)
	var from := NpcSenses.player.global_position if NpcSenses.player != null and is_instance_valid(NpcSenses.player) else global_position + forward()
	brain.release(from)


func _put_by() -> void:
	if (action == "aim" or action == "recoil") and body != null:
		body.aim_off(gun)
	if action in ["aim", "reload"]:
		action = ""


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	_dt = dt
	if _dead:
		_dead_step(dt)
		return
	if pool > 0.0 or mortal_left > 0.0:
		_bleed(dt)
		if _dead:
			return
	_think_t -= dt
	if held:
		# (the duel's countdown: it stands where it was put, its mind still)
		halt()
		face_lock = Vector3.INF
	elif _think_t <= 0.0:
		var st := THINK_S * (2.0 if frozen else 1.0)
		_think_t = st
		thinks += 1
		brain.think(st)
		target = brain.target
	if brain != null and brain.bending != null:
		brain.bending.tick(dt)                      # (an element bot's lock filled each frame; held, a lock is let go)
	_act(dt)
	_move(dt)
	_pose()
	if _bark != null:
		_bark_t -= dt
		if _bark_t <= 0.0:
			_bark.visible = false


func _act(dt: float) -> void:
	match action:
		"aim":
			if not NpcSenses.can_fight(_aim_at):
				_put_by()
				return
			_aim_t += dt
			# (in its sight, by the brain's own look at him: NpcBrain.seen_now; out of it, the aim held where he went)
			if _aim_sees():
				_aim_unseen = 0.0
				_aim_seen_for += dt
				_aim_spot = _lead_point(_aim_at, _aim_part)
			else:
				_aim_unseen += dt
				_aim_seen_for = 0.0
				_aim_lost = true
				if _aim_unseen > float(aim_cfg.get("hold_s", 0.5)):
					_put_by()
					return
			var p := _aim_spot + _aim_offset()
			face_point(p)
			body.aim_at(p, gun)
			var ready_t := _aim_react + _aim_settle
			var back_for := float(aim_cfg.get("reacquire_s", 0.2)) if _aim_lost else 0.0
			if _aim_t >= ready_t and _aim_unseen <= 0.0 and _aim_seen_for >= back_for:
				var why := _shot_clear(p)
				if why == "":
					_fire(p)
					action = "recoil"
					_act_t = RECOIL_S
				else:
					_put_by()
					brain.shot_blocked(why)
		"recoil":
			_act_t -= dt
			if _act_t <= 0.0:
				body.aim_off(gun)
				action = ""
		"reload":
			_reload_left -= dt
			if _reload_left <= 0.0:
				_reload_left = 0.0
				loaded = true
				action = ""
		"swing":
			_swing_t += dt
			if not _swing_hit_on and _swing_t >= _swing_intro:
				_swing_hit_on = true
				body.play_once(String(_swing.hit), 0.05)
			if not _swing_struck and _swing_t >= _swing_intro + float(_swing.strike):
				_swing_struck = true
				_strike()
			if _swing_t >= _swing_intro + maxf(_swing_len, float(_swing.strike) + 0.2):
				action = ""
		"flinch":
			_act_t -= dt
			if _act_t <= 0.0:
				action = ""
		"knocked":
			if knock_t() <= 0.0 and not is_launched():
				action = ""


## The ball's way to `p` from the muzzle: "" clear (or only the foe's body in it), "friend" one of its own side in the way,
## "cover" something solid.
func _shot_clear(p: Vector3) -> String:
	var from := _muzzle()
	var q := PhysicsRayQueryParameters3D.create(from, p, 1, ray_exclude())
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	var c := hit.collider as Node
	for i in 4:
		if c == null:
			break
		if c == _aim_at:
			return ""
		if c is NpcFighter:
			return "friend" if not NpcFactions.hostile(faction, (c as NpcFighter).faction) else ""
		if c is FrontierPlayer:
			return "friend" if not NpcFactions.hostile(faction, NpcFactions.PLAYER) else ""
		c = c.get_parent()
	return "cover"


func _muzzle() -> Vector3:
	var m := gun.get_node_or_null("Muzzle") as Node3D if gun else null
	var origin := m.global_position if m else (gun.global_position - gun.global_basis.z * 0.8 if gun else eye())
	# (kept on its side of a wall, as the player's shot is: Weapon.shot_origin)
	var chest := global_position + Vector3.UP * (0.9 if is_crouching else 1.35)
	var q := PhysicsRayQueryParameters3D.create(chest, origin, 1, ray_exclude())
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return origin if hit.is_empty() else (hit.position as Vector3) + (chest - origin).normalized() * 0.05


## Whether the foe it aims at is in its sight now (its brain's look at him; not the brain's foe, or no brain: as before, yes).
func _aim_sees() -> bool:
	if brain == null or brain.target != _aim_at:
		return true
	return brain.seen_now


## Where to lay the musket on `t` now: his chest, or his head (`part`), ahead of him by his pace over the ball's flight, as
## much of that as its lead says (aim_cfg.lead).
func _lead_point(t: Node3D, part: String) -> Vector3:
	var p := NpcSenses.head_of(t) if part == "head" else NpcSenses.chest_of(t)
	var v := NpcSenses.velocity_of(t)
	v.y = 0.0
	var tof := eye().distance_to(p) / BALL_SPEED * 1.03         # (the drag slows the ball a little over the way)
	return p + v * tof * float(aim_cfg.get("lead", 0.7))


## How far off its mark the barrel lies now: the first error closing in as the aim settles (aim_error_now), and a little
## sway of the arms.
func _aim_offset() -> Vector3:
	var to := _aim_spot - eye()
	var d := to.length()
	if d < 0.1:
		return Vector3.ZERO
	var side := to.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-6 else Vector3.RIGHT
	var up := side.cross(to / d).normalized()
	var ang := aim_error_now() + deg_to_rad(0.12) * sin(_aim_t * 2.3 + float(get_instance_id() % 7))
	return (side * _aim_err_dir.x + up * _aim_err_dir.y) * tan(ang) * d


## The ball's spread for a shot now (deg, one sigma): its skill's (aim_cfg.spread_deg), a quarter more at a foe on the move
## (> 2.5 m/s), a third more hurried, less crouched (steadier).
func shot_spread_deg(moving := false, hurried := false, crouched := false) -> float:
	return float(aim_cfg.get("spread_deg", 0.75)) * (1.25 if moving else 1.0) * (1.35 if hurried else 1.0) * (0.85 if crouched else 1.0)


## A point about `p` (seen from `origin`) where a ball aimed there goes: its line off by a normal error of `sigma_deg` each
## way across (Box-Muller: most shots near, a few far).
func scatter(origin: Vector3, p: Vector3, sigma_deg: float) -> Vector3:
	var to := p - origin
	var d := to.length()
	if d < 0.01:
		return p
	var dir := to / d
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 1e-6 else dir.cross(Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var r := deg_to_rad(sigma_deg) * sqrt(-2.0 * log(maxf(rng.randf(), 1e-6)))
	var a := rng.randf() * TAU
	return p + (side * cos(a) + up * sin(a)) * tan(r) * d


## The shot at `p` (where the barrel lies: its mark, led, and what is left of the aim's settling): the ball's line scattered
## by its spread (shot_spread_deg), the fire and smoke, the report; its error from his part where he stands kept (last_shot,
## shot_errs).
func _fire(p: Vector3) -> void:
	loaded = false
	shots += 1
	var origin := _muzzle()
	var d := origin.distance_to(p)
	var moving := NpcSenses.speed_of(_aim_at) > 2.5
	var sigma := shot_spread_deg(moving, _aim_hurry, is_crouching)
	var aim_p: Vector3
	if skill_preset != "":
		aim_p = scatter(origin, p, sigma)
	else:
		# a line fighter's ball as it always was: in a disc about the aim, most near the middle
		var spread := (0.12 + 0.02 * d) * (1.5 - skill) * (1.3 if moving else 1.0) * (0.85 if is_crouching else 1.0)
		aim_p = p + _disk((p - origin).normalized()) * spread
	var mark := (NpcSenses.head_of(_aim_at) if _aim_part == "head" else NpcSenses.chest_of(_aim_at)) if is_instance_valid(_aim_at) else p
	var err := rad_to_deg((aim_p - origin).angle_to(mark - origin))
	last_shot = {"at": aim_p, "mark": mark, "err_deg": err, "d": d, "spread_deg": sigma, "part": _aim_part, "react": _aim_react,
			"aim_s": _aim_t, "moving": moving}
	shot_errs.append(err)
	if shot_errs.size() > 32:
		shot_errs.remove_at(0)
	var dir := Weapon.ballistic_dir(origin, aim_p, BALL_SPEED, BALL_GRAVITY, BALL_DRAG)
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var ball := NpcBall.new()
	ball.velocity = dir * BALL_SPEED
	ball.gravity = BALL_GRAVITY
	ball.drag = BALL_DRAG
	ball.damage = BALL_DAMAGE
	ball.shooter = self
	ball.exclude = ray_exclude()
	var scene := get_tree().current_scene
	scene.add_child(ball)
	ball.global_position = origin
	ball.look_at(origin + dir, up)
	var senses := NpcSenses.of(get_tree())
	if senses != null:
		senses.muzzle_blast(Transform3D(Basis.looking_at(dir, up), origin))
	Sfx.play_3d(&"musket_shot", origin)
	NpcSenses.noise(origin, WildlifeSpawner.SHOT_LOUD_M, self)
	var wild := scene.get_node_or_null("Wildlife") as WildlifeSpawner
	if wild != null:
		wild.shot(origin, WildlifeSpawner.SHOT_LOUD_M)


## A point in the disc across `dir`, most near the middle (as Weapon.apply_spread: most shots near, a few at the edge).
func _disk(dir: Vector3) -> Vector3:
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 1e-4:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var r := rng.randf()
	var a := rng.randf() * TAU
	return side * cos(a) * r + up * sin(a) * r


## The blow lands: along its swing at the foe's chest (or straight ahead), the first body within reach takes it (Hit.deliver,
## no head bonus: a blow), or the foe itself when it stands in reach before it.
func _strike() -> void:
	var t := _swing_at
	var from := global_position + Vector3.UP * (0.9 if is_crouching else 1.3)
	var fwd := forward()
	var aim_p := NpcSenses.chest_of(t) if NpcSenses.can_fight(t) else from + fwd * REACH
	var dir := (aim_p - from).normalized()
	if Vector2(dir.x, dir.z).normalized().dot(Vector2(fwd.x, fwd.z)) < 0.5:
		dir = fwd
	var dmg := float(_swing.damage)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (REACH + 0.3), 0xFFFFFFFF & ~WeaponBody.LAYER, ray_exclude())
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var landed := false
	var at := aim_p
	# (the wound the blow makes, said by the striker for this blow only: its shots and the axe's cuts bleed, the butt bruises)
	set_meta(&"damage_kind", String(_swing.get("kind", "bleed")))
	if not hit.is_empty():
		at = hit.position
		landed = Hit.deliver(hit.collider, dmg, at, dir, self, false)
	if not landed and NpcSenses.can_fight(t) and _flat(global_position, t.global_position) <= REACH + 0.25:
		var to_t := t.global_position - global_position
		if Vector2(to_t.x, to_t.z).normalized().dot(Vector2(fwd.x, fwd.z)) > 0.4:
			landed = Hit.deliver(t, dmg, aim_p, dir, self, false)
	remove_meta(&"damage_kind")
	if landed:
		blows += 1
		if Sfx.has(&"arrow_hit_flesh"):
			Sfx.play_3d(&"arrow_hit_flesh", at, 2.0, rng.randf_range(0.8, 0.9))


# ---------------------------------------------------------------- moving
func _move(dt: float) -> void:
	if ring_moves != null and _ring_move(dt):
		return                                      # (the % ring: RingMoves owns the body)
	# A knock (BendKnock, the same model as the player's): its own velocity taken out of the body's first, the steering eased
	# on what is left (none through the knock's reaction window), the knock's decayed velocity added back before the move;
	# launched, the floor clamp skipped and the player's gravity (so a knock-up lifts it as high and as long as him). A bend's
	# carry (BendMotion: a dash) is left to it, no steering. Its feet held (a root): no steering, no speed.
	var kn := BendKnock.peek(self)
	var launched := kn != null and kn.is_launched()
	var reeling := kn != null and kn.knock_t > 0.0
	var bm := get_node_or_null(^"BendMotion")
	var carried := bm != null and bm.has_method(&"active") and bool(bm.call(&"active"))
	var dir := Vector3.ZERO
	var speed := 0.0
	if _goal != Vector3.INF and not busy() and not _surrendered and not reeling and not feet_held and not carried:
		var w := _walk_to(_goal, _speed, _arrive)
		dir = w[0]
		speed = w[1]
	if is_crouching:
		speed = minf(speed, CROUCH_SPEED)
	if limp < 0.999:
		# (a broken leg's bone: a limp at a part of the walk; short of breath: no running)
		speed = minf(speed, WALK_SPEED * limp if limp < 0.95 else WALK_SPEED)
	var v := velocity if kn == null else kn.base_of(velocity)
	if _jump_v > 0.0:
		v.y = _jump_v                               # (a jump begun this frame: off the floor, its own gravity from here)
		_jump_v = 0.0
	elif launched:
		v.y -= BendKnock.launch_gravity() * dt
	elif not is_on_floor():
		v.y -= (RingMoves.gravity() if ring_moves != null else GRAVITY) * dt
	else:
		v.y = -0.5
	var hv := Vector2(v.x, v.z)
	var moving := dir != Vector3.ZERO and speed > 0.0
	if feet_held:
		hv = Vector2.ZERO
	elif carried:
		pass
	elif moving:
		hv = hv.move_toward(Vector2(dir.x, dir.z) * speed, ACCEL * dt * (1.6 if speed > WALK_SPEED + 0.5 else 1.0))
		if face_lock != Vector3.INF:
			# (a side-step out to peek, or back: facing the foe, the aimed side-step clips)
			face_point(face_lock)
		else:
			_face = lerp_angle(_face, atan2(-dir.x, -dir.z), clampf(dt * 8.0, 0.0, 1.0))
	else:
		hv = hv.move_toward(Vector2.ZERO, DECEL * dt)
	v.x = hv.x
	v.z = hv.y
	if kn != null:
		var ex := kn.extra_velocity(dt)
		v.x += ex.x
		v.z += ex.z
	velocity = v
	rotation.y = lerp_angle(rotation.y, _face, clampf(dt * 9.0, 0.0, 1.0))
	# STEP: up on to a log in its way (its probes only once something holds it up, and while it steps: not every tick)
	if moving and not frozen and (_stuck_t > 0.0 or _step.stepping()):
		_step.step(Vector3(v.x, 0.0, v.z), speed, dt)
	move_and_slide()
	if kn != null:
		kn.after_slide()
	if moving and global_position.distance_to(_last) < speed * dt * 0.25:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)
	_last = global_position


## The % ring's frame (spec §9.1): a go() order's way written on the pad (pad.move, a share of the run; sprint past the
## run), the pad's intent handed to RingMoves (its body moved there, the player's own mover), the body turned to its facing
## (RingMoves turns it to the deck on the edge). False: not this frame (RingMoves did not take it).
func _ring_move(dt: float) -> bool:
	var kn := BendKnock.peek(self)
	var reeling := kn != null and kn.knock_t > 0.0
	var dir := Vector3.ZERO
	var speed := 0.0
	if _goal != Vector3.INF:
		if not busy() and not _surrendered and not reeling and not feet_held:
			var w := _walk_to(_goal, _speed, _arrive)
			dir = w[0]
			speed = w[1]
		pad.move = Vector3(dir.x, 0.0, dir.z).normalized() * clampf(speed / RUN_SPEED, 0.0, 1.0) if speed > 0.0 else Vector3.ZERO
		pad.hold("sprint", speed > RUN_SPEED + 0.45)
	if not _ring_lean and body != null and body.sk != null:
		_ring_lean = true
		RingMoves.lean_on(body.sk, ring_moves)
	if not ring_moves.pre(pad.intent(), dt):
		return false
	var moving := pad.move.length() > 0.05
	if moving and face_lock == Vector3.INF:
		_face = lerp_angle(_face, atan2(-pad.move.x, -pad.move.z), clampf(dt * 8.0, 0.0, 1.0))
	elif face_lock != Vector3.INF:
		face_point(face_lock)
	if ring_moves.body_yaw() == INF:
		rotation.y = lerp_angle(rotation.y, _face, clampf(dt * 9.0, 0.0, 1.0))
	if moving and global_position.distance_to(_last) < RingMoves.num("physics", "run", 5.0) * pad.move.length() * dt * 0.25:
		_stuck_t += dt
	else:
		_stuck_t = maxf(_stuck_t - dt, 0.0)
	_last = global_position
	return true


## Which way to go to `to` now: [direction, speed] along the walk grid's plan (NavMover), or straight at it, turned aside by a
## light probe a few times a second, where there is no plan or the brain said straight (a foe in sight near, nothing holding
## it up). The plan is for _nav_goal: `to` itself, kept while `to` moves only a little (see walking in the header).
func _walk_to(to: Vector3, speed: float, arrive: float) -> Array:
	_replan_t += _dt
	var flat_d := _flat(global_position, to)
	if on_deck or (_straight and _stuck_t < 0.8 and flat_d < STRAIGHT_M):
		return _straight_to(to, speed, arrive)
	var moved := _flat(_nav_goal, to) if _nav_goal != Vector3.INF else INF
	var need := maxf(GOAL_SNAP_M, flat_d * GOAL_SNAP_FRAC)
	if moved > need and (_replan_t >= REPLAN_S or moved > need * 2.0 + 4.0):
		_nav_goal = to
		_replan_t = 0.0
	var d := nav.steer(_nav_goal, _dt, arrive)
	if nav.on_path:
		if nav.status == NavMover.ARRIVED and flat_d > arrive + 0.05:
			# (at the goal it planned for, the goal itself moved on from it: planned for where it is now, next frame; not
			# while it waits at a door, which stops it too)
			_nav_goal = Vector3.INF
		return [d, speed if d != Vector3.ZERO else 0.0]
	return _straight_to(to, speed, arrive)


## Straight at `to` (within `arrive`: there), the line to it followed each frame, turned aside by what the probe found a few
## times a second.
func _straight_to(to: Vector3, speed: float, arrive: float) -> Array:
	var st := to - global_position
	st.y = 0.0
	if st.length() <= arrive:
		return [Vector3.ZERO, 0.0]
	var line := st.normalized()
	_steer_t -= _dt
	if _steer_t <= 0.0:
		_steer_t = 0.2
		_steer_k = _probe(line)
		_floor_ahead = not on_deck or _floor_at(line.rotated(Vector3.UP, _steer_k))
	if not _floor_ahead:
		return [Vector3.ZERO, 0.0]                 # (the deck ends ahead: it stops there)
	return [line.rotated(Vector3.UP, _steer_k), speed]


## Whether there is floor DECK_LOOK_M ahead along `dir` (a ray down from a little above it, at most 1.2 m below its feet).
func _floor_at(dir: Vector3) -> bool:
	var ahead := global_position + dir.normalized() * DECK_LOOK_M
	var q := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.5, ahead + Vector3.DOWN * 1.2, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## How far to turn off `dir` (rad) for what is solid close ahead (five rays, a few times a second; the foe it is after is no
## obstacle to it).
func _probe(dir: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.6
	var ex: Array[RID] = [get_rid()]
	if is_instance_valid(target) and target is CollisionObject3D:
		ex.append((target as CollisionObject3D).get_rid())
	for k: float in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir.rotated(Vector3.UP, k) * 1.2, 1, ex)
		if space.intersect_ray(q).is_empty():
			return k
	return PI * 0.5


## The clip for what it is doing now (the actions that play their own keep theirs).
## The % ring's body-state clip (RingMoves.clip_state: its own clip when it is in, else its stand-in; a loop played again as
## it ends), the same as the player's SwayPose plays. False: none now (its own locomotion and casts).
func _ring_pose() -> bool:
	var st := ring_moves.clip_state()
	if st == "":
		return false
	var c := RingMoves.clip_for(st)
	var nm := String(c[0])
	if nm == "" or not (body.has_clip(nm) or (NpcBody._add_pose(nm) and body.has_clip(nm))):
		return false
	var loop := bool(RingMoves.clip_spec(st).get("loop", false))
	if body.clip != nm or (loop and body.ap != null and not body.ap.is_playing()):
		body.set_arms("")
		body.play_once(nm, 0.1)
	return true


func _pose() -> void:
	if body == null or action in ["swing", "flinch", "dead", "down", "cast"]:
		return
	if ring_moves != null and _ring_pose():
		return                                      # (the % ring's body-state clip: the hang, a roll, the Rise...)
	if (knock_t() > 0.0 or is_launched()) and body.clip.begins_with(NpcBody.KNOCK_PREFIX):
		return                                      # (a knock's own clip plays while the knock lasts: NpcBody.play_knock)
	var has_gun := gun != null and gun.visible
	if action == "aim" or action == "recoil":
		body.set_arms("")
		body.play("aim_crouch" if is_crouching else "aim", 0.25)
		return
	if action == "reload":
		body.set_arms("")
		var done := _reload_total - _reload_left
		var c := "_crouch" if is_crouching else ""
		var begin := body.clip_length("reload_begin" + c)
		var end := body.clip_length("reload_end" + c)
		if done < begin:
			body.play("reload_begin" + c, 0.2)
		elif _reload_left < end:
			body.play("reload_end" + c, 0.15)
		else:
			body.play("reload_mid" + c, 0.15)
		return
	if _surrendered:
		body.set_arms("")
		body.play("crouch", 0.4)
		return
	var alert := brain != null and brain.state in [NpcBrain.State.SUSPICIOUS, NpcBrain.State.COMBAT]
	var hs := Vector2(velocity.x, velocity.z).length()
	var key := "idle"
	var arms := ""
	var rate := 1.0
	if hs > 0.25 and face_lock != Vector3.INF and has_gun:
		# a step out to peek and back, facing the foe: the aimed side-steps (left, right) and the step back, at their own pace
		var fwd := forward()
		var v := Vector3(velocity.x, 0.0, velocity.z)
		var along := v.dot(fwd)
		var across := v.dot(fwd.cross(Vector3.UP))
		var c := "aim_crouch_walk" if is_crouching else "aim_walk"
		key = c + ("_rt" if across > 0.0 else "_lt") if absf(across) >= absf(along) else (c + "_bw" if along < 0.0 else c)
		rate = hs / 0.55
	elif hs > 0.25:
		if is_crouching:
			key = "aim_crouch_walk" if alert and has_gun else "crouch_walk"
			arms = "carry_crouch" if has_gun and key == "crouch_walk" else ""
			rate = hs / CROUCH_SPEED
		elif hs > RUN_SPEED + 0.45:
			# (a dash between covers in the foe's sight)
			key = "sprint"
			arms = "carry" if has_gun else ""
			rate = hs / 4.24
		elif hs > WALK_SPEED + 0.6:
			key = "run"
			arms = "carry" if has_gun else ""
			rate = hs / RUN_SPEED
		else:
			key = "aim_walk" if alert and has_gun else "walk"
			arms = "carry" if has_gun and key == "walk" else ""
			rate = hs / WALK_SPEED
	elif is_crouching:
		key = "aim_crouch" if alert and has_gun else "crouch"
		arms = "carry_crouch_idle" if has_gun and key == "crouch" else ""
	else:
		key = "aim" if alert and has_gun else "idle"
		arms = "carry" if has_gun and key == "idle" else ""
	body.play(key, 0.25, clampf(rate, 0.5, 1.6))
	body.set_arms(arms)


# ---------------------------------------------------------------- hits and death
## Struck (Hit.deliver): the round's path through his fitted body (Anatomy) decides it (see hits above): a miss goes by; else
## HURT_MULT of the blow x what it tore through, a bleeding wound's BLEED_NOW of it now and the rest in the pool; maimed by what
## it broke or cut (_maim); it flinches from the side it came, or goes down.
func apply_hit(damage: float, point: Vector3, dir: Vector3, source: Node, part: String) -> void:
	if _dead or damage <= 0.0 or source == self:
		return
	# (no_death, the ring's competitors: a sport's blunt blow, no anatomy: no instant winding from the head, no wound or maim)
	var bleeding := PlayerWounds.kind_of(source) == "bleed" and not no_death
	var fx := {}
	if bleeding and body != null and body.sk != null and dir.length_squared() > 1e-8:
		var an := Anatomy.attach_to(body.sk)
		if an != null:
			an.add_wound(point, dir, damage)
			if not an.last_shot.is_empty():
				fx = an.last_shot.fx
				if bool(fx.missed):
					return                      # (the coarse part caught it; his body was not there: it went by)
	var dmg := damage * hurt_mult * float(fx.get("dmg_mult", 1.0))
	hits_taken += 1
	if source != null and is_instance_valid(source):
		_hurt_by = source
	if brain != null and brain.bending != null:
		brain.bending.on_hurt(dmg, source)         # (any hurt loses a bender's lock, as a hit breaks the player's)
	if DisplayServer.get_name() != "headless":
		BloodFx.hit(get_tree().current_scene, point, dir, -dir, clampf(dmg / 40.0, 0.4, 2.0), self)
	if brain != null:
		brain.hurt(source, dir)
	if bool(fx.get("lethal", false)):
		die(source, dir, part)
		return
	var now := dmg
	if bleeding:
		now = dmg * BLEED_NOW
		var add := dmg * (1.0 - BLEED_NOW) * float(fx.get("bleed_mult", 1.0))
		var dr := float(fx.get("drain_mult", 1.0))
		drain_mult = (drain_mult * pool + dr * add) / maxf(pool + add, 0.001) if pool > 0.0 else dr
		pool += add
	health -= now
	if health <= 0.0:
		die(source, dir, part)
		return
	_maim(fx, dir)
	if dmg >= FLINCH_MIN:
		_flinch(dir)


## What the wound broke or cut does to him (Anatomy.effect): a mortal clock, a limp, the arm that cannot hold (his weapon dropped,
## he runs: NpcBrain._should_flee), down for good.
func _maim(fx: Dictionary, dir: Vector3) -> void:
	if fx.is_empty():
		return
	if float(fx.get("mortal_s", 0.0)) > 0.0:
		mortal_left = float(fx.mortal_s) if mortal_left <= 0.0 else minf(mortal_left, float(fx.mortal_s))
	limp = minf(limp, float(fx.get("limp", 1.0)))
	if bool(fx.get("breath", false)):
		limp = minf(limp, 0.9)
	if String(fx.get("leg", "")) != "" and float(fx.get("limp", 1.0)) <= 0.6:
		_legs_broken[String(fx.leg).get_slice(" ", 0)] = true
	if String(fx.get("arm", "")) != "" and arm_broken == "":
		arm_broken = String(fx.arm)
		_put_by()
		if action == "reload":
			action = ""
		_lay_down_weapon()
	if (bool(fx.get("down", false)) or _legs_broken.size() >= 2) and not down:
		_go_down(dir)


## Down for good (the cord below the shoulders, both legs broken): he falls where he stands and lies there alive, out of the
## fight (surrendered(): no one's foe), bleeding as he was; his walking body low.
func _go_down(dir: Vector3) -> void:
	down = true
	_put_by()
	halt()
	action = "down"
	if _cap != null:
		_cap.height = 0.62
		_col.position.y = 0.31
	if body != null:
		body.aim_off(gun)
		body.set_arms("")
		var key := "death_crouch"
		if not is_crouching:
			key = "death_back" if dir == Vector3.ZERO or dir.dot(forward()) < 0.0 else "death_front"
		body.play_once(key, 0.08)
		body.animate = true


## The blood running out of his wounds (the pool) and a mortal wound's clock: dead when either runs out.
func _bleed(dt: float) -> void:
	if mortal_left > 0.0:
		mortal_left = maxf(mortal_left - dt, 0.0)
		if mortal_left <= 0.0:
			die(_hurt_by if is_instance_valid(_hurt_by) else null, Vector3.ZERO)
			return
	if pool <= 0.0:
		return
	var lost := minf(pool * DRAIN * drain_mult * dt, pool)
	pool = maxf(pool - lost - pool * CLOT * dt, 0.0)
	if pool < 0.25:
		pool = 0.0
	health -= lost
	if health <= 0.0:
		die(_hurt_by if is_instance_valid(_hurt_by) else null, Vector3.ZERO)


## The hit reaction from the side the blow came from (the aim lowered, a reload put by).
func _flinch(dir: Vector3) -> void:
	if action == "swing" or body == null or down:
		return                              # (a blow under way goes on: who strikes first)
	_put_by()
	var from := -dir
	var fwd := forward()
	var right := fwd.cross(Vector3.UP)
	var a := rad_to_deg(atan2(from.dot(right), from.dot(fwd)))
	var side := "fw" if absf(a) <= 45.0 else ("bw" if absf(a) >= 135.0 else ("rt" if a > 0.0 else "lt"))
	var key := ("hit_crouch_" if is_crouching else "hit_") + side
	body.set_arms("")
	var l := body.play_once(key, 0.08)
	if l <= 0.0:
		return
	action = "flinch"
	_act_t = minf(l * 0.6, 0.9)


## Down: the death clip, its parts gone, its things left where it lies, died emitted.
func die(killer: Node = null, dir := Vector3.ZERO, _part := "body") -> void:
	if _dead:
		return
	if no_death:
		# (the ring: winded, not killed; the wounds stop bleeding so it is once)
		health = maxf(health, 1.0)
		pool = 0.0
		mortal_left = 0.0
		winded.emit(killer if killer != null and is_instance_valid(killer) else null)
		return
	var kn := BendKnock.peek(self)
	if kn != null:
		kn.reset()
	_dead = true
	health = 0.0
	killed_by = killer if killer != null and is_instance_valid(killer) else null
	action = "dead"
	halt()
	collision_layer = 0                     # (no more in anyone's way, nor a target)
	remove_from_group(WildlifeSpawner.PEOPLE)
	_settle_t = 0.3
	pool = 0.0
	mortal_left = 0.0
	InspectView.ensure_hotkey(get_tree())
	if body != null and down:
		# (down already: he lies where he fell, his fall played out)
		_settle_t = maxf(body.clip_length(body.clip) - body.ap.current_animation_position, 0.0) + 0.3 if body.ap != null else 0.3
		body.drop_parts()
	elif body != null:
		body.aim_off(gun)
		body.set_arms("")
		var key := "death_crouch"
		if not is_crouching:
			# struck from the front it falls on its back, from behind on its face
			key = "death_back" if dir == Vector3.ZERO or dir.dot(forward()) < 0.0 else "death_front"
		_settle_t = body.play_once(key, 0.08) + 0.3
		# (its fall is played whether the budget had it frozen or not: NpcSenses.budget leaves the falling animated)
		body.animate = true
		body.drop_parts()
	if brain != null:
		brain.on_died()
	_leave_loot()
	if killed_by is FrontierPlayer and tag != "":
		kills[tag] = int(kills.get(tag, 0)) + 1
	# its side close by saw it fall: they turn on whoever did it
	for a in NpcSenses.allies_of(self, 30.0):
		a.brain.told(killed_by as Node3D if NpcSenses.can_fight(killed_by) else null, killed_by.global_position if killed_by is Node3D else global_position)
	if body == null:
		# (no body to fall: gone from the field already, killed by a script)
		_settle_t = 0.0
		set_physics_process(false)
		NpcSenses.settle(self)
	died.emit(self, killed_by)


func _dead_step(dt: float) -> void:
	if _settle_t > 0.0:
		_settle_t -= dt
		var v := velocity
		v.x = move_toward(v.x, 0.0, DECEL * dt)
		v.z = move_toward(v.z, 0.0, DECEL * dt)
		v.y = -0.5 if is_on_floor() else v.y - GRAVITY * dt
		velocity = v
		move_and_slide()
		return
	# settled: its fall shown to its end (stepped seldom far off: it lies down all the same), then nothing runs for it again;
	# out of the fighters' lists (no one's foe, ally or listener) into NpcSenses' dead
	if body != null:
		body.finish_clip()
		body.rest()
	set_physics_process(false)
	NpcSenses.settle(self)


## The settled corpse cleared from the field long after (NpcSenses.budget: CORPSE_S, out of sight): its body freed (the node
## stays: the story still counts it dead).
func clear_away() -> void:
	if body == null:
		return
	body.queue_free()
	body = null
	gun = null
	axe = null
	visible = false


## Gone from the field (NpcSenses.budget: run off or let go, and far from everyone a while): its body freed, its frame off,
## out of the fighters' lists; the node stays for the story (alive and out of the fight: routed()).
func leave_field() -> void:
	if left_field or _dead:
		return
	left_field = true
	halt()
	NpcSenses.fighters.erase(self)
	NpcSenses.forget(self)
	remove_from_group(WildlifeSpawner.PEOPLE)
	remove_from_group(PlacedWeapon.GROUP)
	collision_layer = 0
	visible = false
	set_physics_process(false)
	if body != null:
		body.queue_free()
		body = null
		gun = null
		axe = null


## What it carried (the faction's loot and its weapon when not laid down already), in a pack where it lies.
func _leave_loot() -> void:
	var items := _loot_items(not _dropped)
	if items.is_empty():
		return
	loot = _pack(items, global_position + forward() * 0.35)


func _lay_down_weapon() -> void:
	if _dropped:
		return
	_dropped = true
	var items := []
	if gun != null and gun.visible:
		items.append({"kind": "musket", "count": 1})
		gun.visible = false
	if axe != null and axe.visible:
		items.append({"kind": "felling_axe", "count": 1})
		axe.visible = false
	if not items.is_empty():
		_pack(items, global_position + forward() * 0.8)


func _loot_items(with_weapon: bool) -> Array:
	var items := []
	var table: Dictionary = NpcFactions.get_faction(faction).get("loot", {})
	for k: String in table:
		items.append({"kind": k, "count": int(table[k])})
	if with_weapon:
		if gun != null and gun.visible:
			items.append({"kind": "musket", "count": 1})
		if axe != null and axe.visible:
			items.append({"kind": "felling_axe", "count": 1})
	return items


func _pack(items: Array, at: Vector3) -> NpcLoot:
	var l := NpcLoot.new()
	l.name = "NpcLoot"
	l.label = label
	l.items = items
	get_tree().current_scene.add_child(l)
	l.global_position = Vector3(at.x, global_position.y, at.z)
	l.dropped_min = l._now_min()
	l.scavenged_to = l.dropped_min
	l.taken.connect(_on_loot_taken)
	packs.append(l)
	return l


func _on_loot_taken(_l: NpcLoot) -> void:
	if is_instance_valid(gun):
		gun.visible = false
	if is_instance_valid(axe):
		axe.visible = false


# ---------------------------------------------------------------- words
## A line of its faction's for `what` over its head (when the player is near enough to hear), kept in last_bark.
func bark(what: String) -> void:
	var line := NpcFactions.bark(faction, what, rng)
	if line == "":
		return
	last_bark = line
	if DisplayServer.get_name() == "headless":
		return
	var p := NpcSenses.player
	if p == null or not is_instance_valid(p) or p.global_position.distance_to(global_position) > BARK_M:
		return
	if _bark == null:
		_bark = Label3D.new()
		_bark.name = "Bark"
		_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bark.font_size = 40
		_bark.pixel_size = 0.004
		_bark.outline_size = 10
		_bark.no_depth_test = true
		_bark.position = Vector3.UP * 2.05
		add_child(_bark)
	_bark.text = line
	_bark.visible = true
	_bark_t = BARK_S


# ---------------------------------------------------------------- E
func interact_point() -> Vector3:
	if (_dead or down) and body != null:
		return body.bone_pos("spined")         # (lying: his chest)
	return global_position + Vector3.UP * 1.2


func distance_from(p: Vector3) -> float:
	return p.distance_to(interact_point())


func interact_prompt(_p: Node) -> String:
	if _dead:
		return InspectView.ROW if body != null else ""
	if _released or down:
		return InspectView.ROW if InspectView.debug_living and body != null else ""
	if _surrendered:
		return "Let the %s go" % label.to_lower()
	if NpcFactions.hostile(faction, NpcFactions.PLAYER) or (brain != null and brain.state == NpcBrain.State.COMBAT):
		return InspectView.ROW if InspectView.debug_living and body != null else ""
	return "Talk to the %s" % label.to_lower()


## The hold-E list (PlayerInteractor): what a tap does (talk, let go; dead: inspect), and with InspectView.debug_living a look
## inside the living.
func interact_actions(p: Node) -> Array:
	var out := []
	var t := interact_prompt(p)
	if t != "":
		out.append({"id": "", "text": t})
	if not _dead and InspectView.debug_living and body != null and t != InspectView.ROW:
		out.append({"id": "inspect", "text": InspectView.ROW})
	return out


func interact_action(_p: Node, id: String) -> void:
	if id == "inspect":
		InspectView.open_on(self)


## Dead (and the debug view's living), scored behind what lies by him (his pack: a tap takes that first; the hold list has both).
func interact_bias() -> float:
	return 0.6 if _dead or down else 0.0


## The body's skeleton InspectView looks into.
func inspect_skeleton() -> Skeleton3D:
	return body.sk if body != null else null


## The name the inspect view gives him ("Marine").
func inspect_title() -> String:
	return label.capitalize()


func interact(p: Node) -> void:
	if _dead or ((down or _released) and InspectView.debug_living):
		InspectView.open_on(self)
		return
	var it: Node = p.get("interactor") if p != null else null
	if _surrendered:
		release()
		if it and it.has_method(&"notice"):
			it.call(&"notice", "You let the %s go" % label.to_lower())
		return
	if InspectView.debug_living and interact_prompt(p) == InspectView.ROW:
		InspectView.open_on(self)
		return
	var line := NpcFactions.bark(faction, "talk", rng)
	if p is Node3D:
		face_point((p as Node3D).global_position)
	last_bark = line
	if it and it.has_method(&"notice") and line != "":
		it.call(&"notice", "%s: \"%s\"" % [label, line], 3.0)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
