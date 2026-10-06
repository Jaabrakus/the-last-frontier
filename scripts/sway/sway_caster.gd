class_name SwayCaster
extends Node
## The Sway on the player (docs/main_story.md section 11; the owner's v2 rules, 11.9-11.10, 2026-10-02; data/sway/moves.json):
## the timed lock-on. Installed by the level (or the story) once: SwayCaster.install(player); found again with SwayCaster.of(player).
##
##   spells     every move one keeps is a spell, cast ONLY while it is the readied one (readied_spell: the hotbar's selected
##              entry, ready_spell(id)); with none readied the aim does nothing (a weapon's aim never locks: the pistol + RMB
##              Gust of v1 is gone). The one exception is a scripted lock that needs no spell (a target whose meta sway_move
##              names a move with needs_grant false: the wreck's first lock), taken with the hands free
##   mastery    each spell grows by use (uses: casts landed, saved with the motes; tier(id): 0 untrained, 1 practised, 2 expert
##              at mastery.uses, or the move's mastery_uses). The tier sets the hands, the clip and the lock time:
##                untrained  both hands empty; the floor cast (SwayPose: own-form-clap-press) for every spell, Gust too; x1.4
##                practised  both hands empty; a two-handed standing push (own-sway-push-two); x1.0
##                expert     the left palm alone (own-sway-push-one); the right hand may hold one of one_hand_weapons (the
##                           pistol, the tomahawk, the saber: keeps_weapon, the hotbar keeps it in hand). Cast and shoot in
##                           the same breath: while the spell is readied the LMB still fires or swings it, the RMB is the
##                           spell's lock, not the weapon's aim (the player's meta SPELL_META: Weapon._aim_input_enabled);
##                           a shot breaks a lock that is on ("fired"); x0.8
##   modes      a spell's modes (moves.json modes; mode_of / set_mode / flip_mode; the action MODE_ACTION, middle mouse,
##              rebindable, flips the readied spell's): stone_form spike / cannonball, pillar self / free; saved
##   quick      the quick spell on the left button (the owner, 2026-10-05: "the user needs to be able to put hot spells on left
##              click ... this action can be right after"): wherever the player has an element (the ring, the duel:
##              quick_element), one move of it at one variation, frozen ({id, mode}: quick_spell; the element's default
##              until set, MatchSetup.quick_of: earth rock_jab/pebbles, water water_jet/splash, fire fire_jab/jab, air
##              air_palm/palm; remembered per element, MatchSetup.set_quick). QUICK_BIND (Q, rebindable) sets it to the
##              readied skill at its variation now (bind_quick; "Left click: Rock Jab (pebbles)"). Held (QUICK, "fire"), it
##              locks exactly as the aim locks the readied spell (the same lock time, circle, pose, aim and aim help), let go
##              casts; the readied key and its variation are never touched (mode_of answers the frozen variation for its
##              move only while the quick lock runs or lands: _pin_*; base_mode_of is the key's). One lock at a time
##              (lock_src: SRC_AIM or SRC_QUICK, picked while IDLE by _pick_src): the other button is ignored until the lock
##              ends; a lock can start on either the frame after the other's cast. Without an element LMB is not read here
##   schemes    how the aim's lock picks its move with an element (MatchSetup.scheme(), data/bending/schemes.json; the
##              owner, 2026-10-05: "still difficult for a human to switch spells" -> every scheme an option): "keys" the
##              readied spell as ever; "direction" the direction held (held_dir: forward W, back S, side A/D) picks the
##              element's attack, defence or dodge at its own variation (MatchSetup.direction_move), none the readied
##              spell; "first_moves" (once "simple": round 2 cut its distance band) and "radial" the readied spell
##              (RadialWheel, Tab, readies it). The pick (scheme_pick: _sch_id at _sch_mode, which mode_of answers for its
##              move while the aim is held) is taken at the press and kept for the lock (_scheme_follow; round 2: no
##              switching mid-lock). The quick spell, the keys and their variations are never touched; bots never have a
##              scheme
##   the aim    the aim held (PlayerControls "aim") with a spell readied and its hands: the camera over the shoulder as a
##              weapon's aim does. What the crosshair is on (the camera's ray, as get_aim_point()): a node in group
##              sway_targets (or with meta sway_move), an NpcFighter, a WildAnimal, a RigidBody3D prop (a dropped torch too), a
##              lit campfire or torch near where the ray lands, a built piece still catching fire (FireSpread), a sail (group
##              SAIL_GROUP), a stone (GustLift.is_stone: a raised spike or cannonball, a boulder, a small rock); a Form spell's
##              own target (FormCast.pick: the ground, a piece to mend)
##   the lock   fills over the move's lock time (x the tier's, stretched up to far_stretch at the end of its range, slower
##              while running: moving_mult); the aim off the target more than grace_s (0.15 s; a 2 deg cone round the
##              crosshair still counts) breaks it, the ring flickering meanwhile and not filling. A move may have its own
##              rules (moves.json lock_rules: Gust's wider cone that also catches a target near the crosshair, a longer
##              grace and no fizzle: rule_of, release_window, _cone_pick). Full: a click (locked); let go
##              of the aim within release_s (1 s) and it casts (cast; the motes spent, a use counted), held longer it fizzles
##              (fizzled; the motes kept, and the aim must be let go before the next lock). Let go before it is full: no cast
##   holds      a lock that holds at full (state HOLDING, hold_started; the motes spent as it begins). Both are Gust's (the
##              owner folded Levitate into it, 2026-10-02: "i dont think we should have a levitate i think it should be the gust"):
##                gust on a stone GustLift (moves.json gust.stone: its own reach and lock time; heavier than its mass_kg it
##                                wants two casters, the hint "heavy"): the stone tears free and rises while the aim is held,
##                                drawn like a bowstring; let go: hurled along the aim (hurled, cast; a spike flies like a
##                                lance, a cannonball heavier, rolling); held past its break: the power breaks, it drops,
##                                the caster staggers, the motes are lost (overstrained)
##                gust on a sail  the wind kept in it while the lock holds (sail_wind on / off: for the ship code; the
##                                sail's own sway_wind(on, caster) when it has one); a mote every sail.drain_s; the aim kept
##                                on it (the grace); let go, the motes out, a hit: slack
##   breaks     sprinting (not the pillar's self mode, practised and up: cast in stride), climbing (a grip, a perch, a vault), riding, knocked
##              down, dead, a weapon drawn the tier does not allow, firing, building; any hit taken (FrontierPlayer.hurt); bound
##              (a captive, Captivity.bound: nothing locks, a spell readied or not, "Your hands are bound"; the user,
##              2026-10-03, free use put every spell in a captive's reach)
##   motes      a belt of `motes` (belt_max 3 under our sky); the free floor: below floor_max (2) the tinderbox coal breathes
##              one back every floor_s (90 s). Saved with the player (SaveParts' player part: save_of / load_of)
##   free use   ONE switch, moves.json's free_use (free_use(); the user, 2026-10-03: "lets make the spells free use right
##              now"), so the story's gating can come back by setting it false. True:
##                known     every spell in every game from the start, story on or off, a new game or a load (has(): the
##                          level installs the caster, install_free; the Tab screen's Spells list has them all). Nothing is
##                          put on the hotbar or readied by it (the owner: "pickups shouldnt auto fill"; dragged on, readied
##                          from the bar). A grant (the story's sway_grant, give=) still works: kept and saved for when the
##                          switch is off again, without its line (the spell is known already; nor the story's own say
##                          line: StoryEffects.say_line); the scripted lock unchanged. The aim held with nothing readied
##                          says "No spell readied" only once a spell is on the bar (_hint_unreadied)
##                no motes  cost_of() is 0: a cast, Gust's holds (a stone's, a sail's drain) and the Form spells spend
##                          nothing, a cast is never refused for motes (no "motes" hint), an overstrain loses none (it
##                          still drops the stone and staggers). The belt is hidden (SwayRing; the HUD's spell line and the
##                          Tab card say nothing of motes): a belt that never changes would only be noise
##              The lock, its times and ranges, the hands, mastery, modes and breaks are the same either way. False: a
##              spell only once granted (grant), the caster only from the story or give=, the motes spent as the lock and
##              the holds above say
##   on screen  SwayRing round the crosshair (the art's colour and ring shape; a hold's draw and strain), SwayThread from the
##              palms to the target from half the lock (Breath: in the world, seen by everyone), SwayPose (the body's clip by
##              mastery), SwayTone (a soft rising tone); the first lock: SwayArm (the arm pointed at the target)
##   effects    SwayEffects: gust (a push: fighters staggered and thrown back, animals shoved and put to flight, props pushed,
##              torches and campfires blown out, a piece still catching put out; a stone is held instead), first_lock (the target lifted up and
##              aside, then let fall; lifted); Form's FormEffects. A target with sway_cast(move, caster) is told too, and one
##              with sway_lockable(move) -> bool may refuse a lock
## Form       the fifth art (FormCast, the child `form`; FormEffects): the lock is a circle drawn on the ground at the target
##            instead of the thread; its reach flat from the feet (reach_to)
## The strike (the bending game: effects leave on the pose's strike frame): a cast whose pose has a strike time
## (SwayPose.strike_wait: element mode's poses, data/bending/poses.json) and whose bend spec throws something (STRIKE_DOS:
## bolt, throw, cone, ring, shove) lands as SwayPose says `struck`, or by a fallback timer (the wait + STRIKE_SLACK_S) when
## it never does; the rest (guard and other zones, dashes, buffs, ...) land on the release as ever, the pose following, so a
## Catch stands the very frame the lock lets go. One mechanism: whatever SwayEffects starts (a BendThrow) launches at once.
## A spent cast always lands, a hit taken in between or not; a cast still waiting lands as the next one is cast.
## The hotbar: spells() (static: every spell, {kind "spell", id, label, art, motes, lock_s, range_m, icon, modes}),
## known_spells() (those granted, every one with free use: the Tab screen's Spells list, dragged onto the bar),
## ready_spell(id) (spell_readied), readied_spell, spell_icon(id) (its SVG), spell_label(id) (with its mode). The launch
## arg give=form (give=sway, or give=earth_wall,...) grants them (give_arg, from GatherTools' give=).
## The story: grant(move) / has(move) (the story's sway_grant: First Lesson's Gust, into the Spells list); the signals; casts
## counted by the target's tag (tag_of: meta sway_tag, an NpcFighter's tag, a WildAnimal's species, else its name) in the
## statics `casts` / `casts_by_move`, read by cast_count(tag, move) and by lock_cast_begin / lock_cast_check
## (StoryObjectives' "lock_cast" kind). `enabled` false (a cutscene) and nothing locks; bound hands (Captivity) the same
## (blocked: "bound").
## ROUND 2 (Tidebreak's shared cast rules: skills_r2 spec §2.1-2.4, §8.2; the owner's answers, 2026-10-05). With an element
## only (elem(): the ring, the duel); the open world's locks stay exactly as above:
##   the guard   a third lock source, SRC_GUARD, on GUARD (E and mouse button 4, rebindable: bend_guard), no readying: the
##               element's guard (Bending.guard), or with a caught stone held (BendZone.held_stone) the throw back. Its
##               press takes over any lock running (dropped: free before the click, a raised stone left loose; the dropped
##               button must be let go before it locks again). Its lock: BendZone.guard_lock_s (the whiff's, the return's)
##   the click   a press let go within click_s before the lock is full is a click: the lock runs on and the move goes the
##               moment it is full, aimed where the crosshair is then (_queued); pressed again meanwhile it is a hold again,
##               the time kept. A hold let go before full is called off, nothing spent (a raised stone drops loose)
##   the keys    Hotbar's taps (a tap the key's first move, a double tap its other: Hotbar.select) come here while a lock
##               runs (key_tap): the same key moves the lock to its other move with the time kept (_switch_lock; the new
##               pose shown switch_hold_s before it may go, taps within double_tap_s of a switch ignored, a raised spike
##               turned to a boulder); another key ends the lock, readies its first move and, the button still held, locks it
##               from nothing
##   direction   the direction scheme's pick is taken at the press and kept for the lock (no switching mid-lock)
##   a hit       pushes the lock back by what the blow cost (BendStatus.setback_s: the hitter's lock time, at least
##               hit_setback_min_s; never wiped); a dash's or a guard's lock is never pushed; lightning's charge breaks
##   grow (▲)    a mode whose spec has `grow`: held on past the click by grow_after_s, a second click, and it grows (the
##               caster's BendCaster.grown at the cast: BendEffects merges the grow); at release_s it casts itself. Others
##               sputter on the hands from sputter_s and fizzle at release_s as before
##   the stone   a mode with raise_at_fill (Spike, Boulder): at that fill its stone rises before the caster and hangs, its
##               point on the aim (FormEffects.raise_stone); the cast throws it; called off, emptied by a hit, or E: it
##               drops as a loose stone (FormStone.make_loose)
##   Q held      quick_reset_s: the left button back to the element's jab; a tap of Q with the readied move already there
##               puts the jab back too (next_q says which)
##   passives    Rooted (earth, still: the fill x fill_mult), Footwork (fire: moving_mult); the charge of lightning seen and
##               heard on the hands while it locks (BendLooks.Charge)
## ROUND 3 (smash_r3 spec §6, §14.3; SEAMS added the seams, AIR fills them; all of it behind the gate RingRules.stock_on() /
## RingMoves.of(player)): guard_up() (a round-2 guard of his stands), ready_default() (key 1's first move readied: RingMode
## at the countdown and each respawn), drop_all() (every lock and held stone dropped: a fall), and the signals
## lock_started (already round 1's: (move, target), at every lock's start, the guard's included, and at a same-key switch),
## cast_released(move, mode) at every release, air_cast(move, mode) (an airborne cast; not emitted until AIR).

## A lock began on `target` (every lock: the aim's, the quick spell's, the guard's; and the new move of a same-key switch).
## Round 3's RingRules.note_lock_started takes it (its second argument is the target, not the mode: mode_of(move)).
signal lock_started(move: String, target: Node3D)
## Round 3: a cast let go (the effect on its way: _cast, a hold's let go), `mode` its variation then.
signal cast_released(move: String, mode: String)
## Round 3: a cast let go in the air (AIR emits it; MOVE plays the air legs on it). Never emitted before AIR.
signal air_cast(move: String, mode: String)
## Full lock (the click): let go within release_s to cast (a hold begins at once instead: hold_started).
signal locked(move: String, target: Node3D)
## Cast (after the move's effect was applied; a hold's let go: the hurl, the sail let slack).
signal cast(move: String, target: Node3D)
signal lock_broken(move: String, target: Node3D, why: String)
signal fizzled(move: String, target: Node3D)
signal motes_changed(motes: int)
## first_lock's lift is over (the target let fall where it was set aside).
signal lifted(target: Node3D)
## A spell readied for the next lock ("" none): the hotbar's slot.
signal spell_readied(id: String)
## A spell's mode changed (the mode key: flip_mode, set_mode).
signal mode_changed(id: String, mode: String)
## A spell grew a tier by use (1 practised, 2 expert).
signal mastered(id: String, tier: int)
## A hold began at Gust's full lock (a stone torn free: GustLift; the wind in a sail); the motes are spent.
signal hold_started(move: String, target: Node3D)
## Gust held on a sail: the wind in it (on) while the lock holds, slack (off) as it ends. For the ship code (11.9).
signal sail_wind(sail: Node3D, on: bool)
## A stone Gust held hurled along the aim (GustLift flies it).
signal hurled(move: String, stone: Node3D)
## A stone held too long broke the hold (its strain): the stone dropped, the caster staggered, the motes lost.
signal overstrained(move: String, target: Node3D)
## A lock running moved to another move (the same key tapped while it ran, a wheel step: key_tap, step_other).
signal lock_switched(move: String, target: Node3D)
## A grow (▲) move's second click: held on past grow_after_s, it grows.
signal grew(move: String)
## A lock pushed back by a hit (by `back` s; `emptied` when it went back to nothing).
signal set_back(move: String, back: float, emptied: bool)

enum State { IDLE, LOCKING, FULL, HOLDING }

const NODE_NAME := &"SwayCaster"
const TARGET_GROUP := &"sway_targets"
const SAIL_GROUP := &"sway_sails"
const AIM := &"aim"
## The mode key (rebindable; the middle mouse button by default: ensure_input).
const MODE_ACTION := &"sway_mode"
## The quick spell's button (the left one: PlayerControls "fire") and the key that sets it (rebindable; Q by default:
## ensure_input). See the header's quick spell.
const QUICK := &"fire"
const QUICK_BIND := &"bend_quick_bind"
const QUICK_BIND_KEY := KEY_Q
## The button a lock is taken on (lock_src): the aim's (RMB, the readied spell) or the quick spell's (LMB).
const SRC_AIM := "aim"
const SRC_QUICK := "quick"
## The guard's button (E and mouse button 4 by default, rebindable; InputSetup and ensure_input) and its lock source.
const GUARD := &"bend_guard"
const SRC_GUARD := "guard"
## The control schemes' data (MatchSetup.schemes_data; see the header's schemes).
const SCHEMES_DATA := "res://data/bending/schemes.json"
## The set key's line with nothing readied (the quick spell as it stays).
const NOTHING_READIED := "Ready a move first (1-5); left click stays %s"
## The player's meta while a spell is readied with its hands right: the RMB is the spell's, not the weapon's aim (an expert's
## pistol or tomahawk still fires, the saber still swings: Weapon._aim_input_enabled).
const SPELL_META := &"sway_spell"
## The aim camera's ease (s), as the weapons' (FrontierPlayer.aim_camera_s).
const AIM_CAM_S := 0.15
## A lit campfire or torch this near where the crosshair's ray lands is what it is on (m).
const FIRE_NEAR_M := 1.3
## A locked target may get this much further than the move's range before the lock breaks.
const RANGE_SLACK := 1.15
## The hold shown on the arm before the lock fills (s to ease in / out).
const ARM_IN_S := 0.18
const ARM_OUT_S := 0.3
const SHOVE_S := 0.32
const TIERS := ["untrained", "practised", "expert"]
## The untrained floor cast holds the caster where they knelt (the owner's rule, docs/main_story.md 11.10: "kneel and press
## the palms to the floor while the ring fills"): FrontierPlayer.drag_speed_cap at this while its clip plays (rooted).
const ROOT_CAP := 0.0
## The bend specs whose effect leaves on the pose's strike (the header's strike); every other lands on the release.
const STRIKE_DOS := ["bolt", "throw", "cone", "ring", "shove"]
## A cast waiting on its strike lands this long after the strike was due if SwayPose never says struck (s).
const STRIKE_SLACK_S := 0.1

## Casts landed per target tag (all moves) and per move ({move: {tag: n}}), for lock_cast objectives (not saved: a story
## step counts from its begin and keeps its own count across a load, as NpcFighter.kills).
static var casts := {}
static var casts_by_move := {}
## Tests only: true or false stands for moves.json's free_use (null: the file's). The game never sets it.
static var free_override: Variant = null

var player: FrontierPlayer
var enabled := true
var granted: Array[String] = []
var motes := 3
var belt_max := 3
var floor_max := 2
var floor_s := 90.0
## The tinderbox coal breathes motes back (the free floor).
var floor_on := true
## Practice beyond mastery (later): the lock times multiplied by this too.
var lock_mult := 1.0
## Casts landed per spell (mastery), and each spell's mode (none: its first).
var uses := {}
var modes := {}

var grace_s := 0.15
var release_s := 1.0
var cone_deg := 2.0
var moving_mps := 2.2

var state := State.IDLE
var move := ""
var target: Node3D = null
## 0..1 of the lock.
var fill := 0.0
## Seconds the aim has been off the target (the grace).
var off_t := 0.0
## Seconds since the lock was full.
var full_t := 0.0
## Seconds a hold has run.
var hold_t := 0.0
## This lock's time (s): the move's, stretched by the range, times the tier's and lock_mult.
var lock_s := 0.0
## The casting arm of the first lock (SwayArm): "r", "l", "" (no hand free now).
var side := ""
## Why the last lock ended without a cast: "off", "let go", "far", "gone", "hit", "sprint", "climbing", "weapon", "strain", ...
var last_break := ""
## Why the crosshair's target takes no lock now ("" when it does, or there is none): "motes", "far", "hands", "weapon",
## "heavy" (a stone for two casters).
var hint := ""
## A spell readied, the aim held with its hands (the ring shows its track and the belt).
var readied := false
## Not null: stands for the aim button (tests, films).
var held_override: Variant = null

var arm: SwayArm
var ring: SwayRing
var thread: SwayThread
var tone: SwayTone
## The Form art's side of a lock (the circle, the target on the ground).
var form: FormCast
## The body's cast clip (by mastery).
var pose: SwayPose
## The spell the next held aim locks with ("" none).
var readied_spell := ""
## The stone held (GustLift; null for a sail, or none).
var hold: GustLift
## The pillar's last launch ({boost, gap, velocity, k}; {} none): FormEffects.pillar.
var last_launch := {}
## The untrained floor cast is holding the caster still (ROOT_CAP).
var rooted := false

var _floor_t := 0.0
var _local_at := Vector3.ZERO        ## the locked point in the target's frame
var _wait_release := false
var _cam_w := 0.0
var _arm_w := 0.0
var _shove_t := -1.0
var _q := {}                          ## this frame's crosshair query
var _hinted := ""
var _drain_t := 0.0
var _tremble := Vector2.ZERO          ## the strain's tremble added to the view (yaw, pitch), taken out again after
var _spell_free := false              ## the hands have been right for the readied spell since it was readied
var _hold_stone := false              ## the hold running is a stone's (GustLift), not a sail's
var _pending := {}                    ## a cast waiting on its strike: {m, t, at, n, pin} ({} none)
var _pending_n := 0
## The button the lock on now (or the one being tried) is taken on: SRC_AIM or SRC_QUICK (the quick spell's).
var lock_src := SRC_AIM
## Tests only: true or false stands for the quick spell's button held (null: PlayerControls' "fire").
var quick_override: Variant = null
var _quick := {}                      ## element -> {id, mode}: the quick spells read (MatchSetup.quick_of) or set this run
var _wait_src := SRC_AIM              ## the button _wait_release waits on
var _quick_spoiled := false           ## the LMB press now began (or ran) while LMB was not the game's: _track_quick
var _quick_down_was := false
var _quick_ok_was := false
var _pin_id := ""                     ## the quick spell's move while its lock runs: mode_of(_pin_id) is _pin_mode
var _pin_mode := ""
var _pin_on := false                  ## the quick spell's button is the one held or locking now
var _pinning := false                 ## a quick cast landing (its effect, its strike wait)
## Tests only: not null stands for the direction held ("forward", "back", "side", "" none) and the nearest opponent's
## distance (m) for the control schemes.
var dir_override: Variant = null
var dist_override: Variant = null
## The control scheme's pick for the aim's lock now (see the header's schemes; "" none: the readied spell as it is).
var _sch_id := ""
var _sch_mode := ""
## The move wheel (RadialWheel: the radial scheme), the local player's.
var radial: RadialWheel
## Round 2 (see the header). Tests only: not null stands for the guard's button held.
var guard_override: Variant = null
## A click let go before the lock was full: it goes the moment it is (or once a switch's hold has shown).
var _queued := false
## How long the button of the lock now has been held since its press (s; the click's test), and whether it was last frame.
var _press_t := 0.0
var _held_was := false
var _guard_was := false
## The last mid-lock switch (BendStatus.now()) and when its new pose may go.
var _switch_at := -INF
var _switch_hold_until := -INF
## The lock grew (▲, the second click), the sputter began (its sound once), the lock's grow is known.
var grown := false
var _sputtered := false
## The stone raised by this lock (FormEffects.raise_stone's Throw, waiting; null none).
var raised: Node = null
## Q held since (s; -1 not held): quick_reset_s puts the jab back.
var _q_held_t := -1.0
## Lightning's charge on the hands while it locks (BendLooks.Charge; null none).
var charge: Node = null
## The last lock's start (BendStatus.now()) and its source, for the tests.
var lock_began_at := -INF
var _rooted_t := 0.0


## The player's caster, made on first call (the level or the story calls it once; it is safe to call again).
static func install(p: FrontierPlayer) -> SwayCaster:
	var c := of(p)
	if c != null:
		return c
	c = SwayCaster.new()
	c.name = NODE_NAME
	c.player = p
	p.add_child(c)
	return c


static func of(p: Node) -> SwayCaster:
	return p.get_node_or_null(NodePath(String(NODE_NAME))) as SwayCaster if p != null else null


## The level's call (FrontierLevel, the player just added): with free use the caster installed from the start, every spell
## known (the user, 2026-10-03: "lets make the spells free use right now"); without, nothing (the story's grant or give=
## installs it, as before). The caster, or null when none was installed.
static func install_free(p: FrontierPlayer) -> SwayCaster:
	if p == null or not free_use():
		return null
	return install(p)


## moves.json's free_use (see the header; free_override in tests): every spell known, no motes spent.
static func free_use() -> bool:
	if free_override != null:
		return bool(free_override)
	return bool(SwayMoves.data().get("free_use", false))


## The motes a lock of `m` spends (at its cast, or as its hold begins): moves.json's motes, 0 with free use (a sail's drain
## too is off then: _tick_hold).
static func cost_of(m: String) -> int:
	return 0 if free_use() else int(SwayMoves.move(m).get("motes", 0))


## The mode key: MODE_ACTION on the middle mouse button, made when missing (the player may rebind it). Safe to call again.
static func ensure_input() -> void:
	if not InputMap.has_action(QUICK_BIND):
		InputMap.add_action(QUICK_BIND)
		var k := InputEventKey.new()
		k.physical_keycode = QUICK_BIND_KEY
		InputMap.action_add_event(QUICK_BIND, k)
	InputSetup.ensure_guard()
	if InputMap.has_action(MODE_ACTION):
		return
	InputMap.add_action(MODE_ACTION)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event(MODE_ACTION, mb)


## The quick spell's set key as the player sees it ("Q"; its first binding, whatever it was rebound to; "" when it has
## none: the player unbound it).
static func quick_bind_key() -> String:
	return key_name(QUICK_BIND)


## Action `a`'s first binding as the player sees it ("Q", "F", "Middle Mouse Button"; "" when it has none).
static func key_name(a: StringName) -> String:
	if not InputMap.has_action(a):
		return ""
	for e in InputMap.action_get_events(a):
		var k := e as InputEventKey
		if k != null:
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
		if e != null:
			return e.as_text()
	return ""


func _ready() -> void:
	if player == null:
		player = get_parent() as FrontierPlayer
	ensure_input()
	grace_s = SwayMoves.lock_rule("grace_s", grace_s)
	release_s = SwayMoves.lock_rule("release_s", release_s)
	cone_deg = SwayMoves.lock_rule("cone_deg", cone_deg)
	moving_mps = SwayMoves.lock_rule("moving_mps", moving_mps)
	belt_max = int(SwayMoves.motes_rule("belt_max", belt_max))
	motes = clampi(int(SwayMoves.motes_rule("start", belt_max)), 0, belt_max)
	floor_max = int(SwayMoves.motes_rule("floor_max", floor_max))
	floor_s = SwayMoves.motes_rule("floor_s", floor_s)
	if player == null:
		return
	if player.has_meta(&"sway_save"):
		load_data(player.get_meta(&"sway_save"))
		player.remove_meta(&"sway_save")
	player.hurt.connect(func(_d: Vector2, _a: float, _h: bool) -> void: _on_hurt())
	player.died.connect(func(_d: Vector2) -> void: _end_on("dead"))
	for k in player.weapons:
		var w: Weapon = player.weapons[k]
		if w != null and not w.fired.is_connected(_on_fired):
			w.fired.connect(_on_fired)
	if player.skeleton != null:
		arm = SwayArm.new()
		arm.name = "SwayArm"
		player.skeleton.add_child(arm)        # (CharacterBodyMesh keeps itself behind it, last)
	thread = SwayThread.new()
	thread.name = "SwayThread"
	add_child(thread)
	form = FormCast.new()                   # (before the pose: it tells where the circle is, on an upright or not)
	form.name = "FormCast"
	form.caster = self
	add_child(form)
	pose = SwayPose.new()
	pose.name = "SwayPose"
	pose.caster = self
	add_child(pose)
	pose.struck.connect(_on_struck)
	if player.is_local:
		var layer := CanvasLayer.new()
		layer.name = "SwayHUD"
		layer.layer = 4
		add_child(layer)
		ring = SwayRing.new()
		ring.caster = self
		layer.add_child(ring)
		radial = RadialWheel.install(self)
		if DisplayServer.get_name() != "headless":
			tone = SwayTone.new()
			tone.name = "SwayTone"
			add_child(tone)


## The mode key flips the readied spell's mode (a spell with modes readied; the key is the player's). The quick spell's
## set key (an element: the ring, the duel) puts the readied move on LMB; with nothing readied it says how.
func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_local:
		return
	if InputMap.has_action(QUICK_BIND) and event.is_action_pressed(QUICK_BIND) and not event.is_echo() \
			and quick_element() != "":
		tap_q()
		get_viewport().set_input_as_handled()
		return
	if readied_spell == "":
		return
	if my_modes(readied_spell).is_empty():
		return
	if InputMap.has_action(MODE_ACTION) and event.is_action_pressed(MODE_ACTION):
		flip_mode()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- the story's
## Grants move `m` (a spell goes to the Tab screen's Spells list, the player drags it onto the bar). Nothing is readied by a
## grant (spells only from the bar: ready_spell): `tell` (the story's grant; not a load) says where it went and how to ready
## it (Rook's lesson: drag Gust onto a slot, then its key). `m` may name several moves, comma-separated, or an art ("form":
## every spell of it), as give= does (grant_ids): the story's grant of the Form spells at the crash (two_fires.json, Two
## Fires' lock step). Several are granted together: one line names them (a story effect's own `say` line takes their names
## too: StoryEffects.say). With free use the spell is known already: the grant is only kept (saved, for when the gating is
## back), no line (the user, 2026-10-03: "lets make the spells free use right now").
func grant(m: String, tell := true) -> void:
	if "," in m or (SwayMoves.move(m).is_empty() and not SwayMoves.art(m).is_empty()):
		_grant_several(grant_ids(m), tell)
		return
	if SwayMoves.move(m).is_empty() or granted.has(m):
		return
	var known := has(m)                      # (free use: every spell is)
	granted.append(m)
	if known or not tell or not is_spell(m):
		return
	if player != null and player.is_local and player.interactor != null:
		player.interactor.notice("%s learned: Tab, drag it from the Spells list onto the hotbar (1-9); its key readies it" % spell_label(m), 4.5)


## The moves a grant of `m` names: `m` itself, each of a comma-separated list, or every spell of the art `m` ("form").
static func grant_ids(m: String) -> Array[String]:
	var out: Array[String] = []
	for part in m.split(",", false):
		var id := part.strip_edges()
		if not SwayMoves.move(id).is_empty():
			if not out.has(id):
				out.append(id)
		elif not SwayMoves.art(id).is_empty():
			for e: Dictionary in spells():
				if String(e.art) == id and not out.has(String(e.id)):
					out.append(String(e.id))
	return out


func _grant_several(ids: Array[String], tell: bool) -> void:
	var names: Array[String] = []
	for id in ids:
		if granted.has(id):
			continue
		var known := has(id)                 # (free use: kept, not told)
		granted.append(id)
		if is_spell(id) and not known:
			names.append(String(SwayMoves.move(id).get("label", id.capitalize())))
	if tell and not names.is_empty() and player != null and player.is_local and player.interactor != null:
		player.interactor.notice("%s learned: Tab, drag them from the Spells list onto the hotbar (1-9)" % ", ".join(names), 4.5)


## Whether move `m` is known: granted, or any spell with free use (the user, 2026-10-03: "lets make the spells free use right
## now"; a scripted lock is never "known": can_use).
func has(m: String) -> bool:
	return granted.has(m) or (free_use() and is_spell(m))


func revoke(m: String) -> void:
	granted.erase(m)
	if readied_spell == m:
		ready_spell("")


func set_motes(n: int) -> void:
	n = clampi(n, 0, belt_max)
	if n == motes:
		return
	motes = n
	motes_changed.emit(motes)
	if ring:
		ring.show_belt()


## Motes added (a keelstone shard ground, a lit beacon): how many went into the belt.
func add_motes(n: int) -> int:
	var before := motes
	set_motes(motes + n)
	return motes - before


## Whether `m` can be cast by this caster now on a target that names it (granted, or a scripted move needing no grant).
func can_use(m: String) -> bool:
	var d := SwayMoves.move(m)
	return not d.is_empty() and (has(m) or not bool(d.get("needs_grant", true)))


## A spell: a move one keeps and readies (not a scripted lock: needs_grant, not named_only).
static func is_spell(m: String) -> bool:
	var d := SwayMoves.move(m)
	return not d.is_empty() and bool(d.get("needs_grant", true)) and not bool(d.get("named_only", false))


## A scripted lock that needs no spell (the wreck's first lock).
static func scripted(m: String) -> bool:
	var d := SwayMoves.move(m)
	return not d.is_empty() and not bool(d.get("needs_grant", true))


func is_locking() -> bool:
	return state != State.IDLE


## Round 3: a round-2 guard of his stands now (BendZone.R2_GUARDS, his own; MOVE's roll and duck read it).
func guard_up() -> bool:
	if not is_inside_tree():
		return false
	for z in get_tree().get_nodes_in_group(BendZone.GROUP):
		var bz := z as BendZone
		if bz != null and bz.r2 and bz.owner_node == player and BendZone.R2_GUARDS.has(bz.kind) and not bz.is_queued_for_deletion():
			return true
	return false


## Round 3: key 1's first move readied (RingMode at the countdown and each respawn). A no-op until AIR.
func ready_default() -> void:
	pass


## Round 3: every lock and held stone dropped (RingMode on a fall). A no-op until AIR.
func drop_all() -> void:
	pass


# ---------------------------------------------------------------- mastery
## Casts landed with spell `id`.
func uses_of(id: String) -> int:
	return int(uses.get(id, 0))


## Sets the casts landed with `id` (a trainer, a test); the tier follows.
func set_uses(id: String, n: int) -> void:
	uses[id] = maxi(n, 0)
	_sync_meta()                        # (an expert keeps the one-handed weapon held, not used)


## The casts each tier of `id` wants ([untrained, practised, expert]).
static func tier_uses(id: String) -> Array:
	var u: Variant = SwayMoves.move(id).get("mastery_uses", (SwayMoves.data().get("mastery", {}) as Dictionary).get("uses", [0, 8, 30]))
	return u if u is Array and (u as Array).size() >= 3 else [0, 8, 30]


## The mastery of spell `id`: 0 untrained, 1 practised, 2 expert. With free use every spell is an expert's (the user,
## 2026-10-03, who saw "untrained" on the free spells: free use is the spell at its best, one palm, no floor cast, not rooted,
## the shortest lock); its casts are still counted (uses), so the mastery stands where it was when the switch goes off.
func tier(id: String) -> int:
	if free_use() and is_spell(id):
		return 2
	var u := tier_uses(id)
	var n := uses_of(id)
	return 2 if n >= int(u[2]) else (1 if n >= int(u[1]) else 0)


func tier_name(id: String) -> String:
	return String(TIERS[tier(id)])


## The lock time's factor at `id`'s tier (mastery.lock_mult).
func tier_mult(id: String) -> float:
	if not is_spell(id):
		return 1.0
	var lm: Array = (SwayMoves.data().get("mastery", {}) as Dictionary).get("lock_mult", [1.4, 1.0, 0.8])
	return float(lm[clampi(tier(id), 0, lm.size() - 1)]) if not lm.is_empty() else 1.0


func _count_use(m: String) -> void:
	if not is_spell(m):
		return
	var was := tier(m)
	uses[m] = uses_of(m) + 1
	var now := tier(m)
	if now > was:
		mastered.emit(m, now)
		if player.is_local and player.interactor != null:
			player.interactor.notice("%s: %s (%s)" % [spell_label(m), String(TIERS[now]),
					"a two-handed push" if now == 1 else "one palm: the other hand may hold a pistol, a tomahawk or a saber"], 3.5)


## The torch's hand ("" none, "l", "r").
func torch_side() -> String:
	var p := player
	if p.torch != null and p.torch.holding():
		return p.anim.holds.torch_side() if p.anim != null and p.anim.holds != null else "l"
	return ""


## Whether the right hand holds one of one_hand_weapons now (a pistol or a tomahawk drawn, the saber out).
func one_hand_held() -> bool:
	var p := player
	var oh := SwayMoves.one_hand_weapons()
	var tool := p.gather.in_hand() if p.gather != null else ""
	if tool != "":
		return tool in oh
	return not p.hands_free and p.weapon != null and (p.weapon.active or p.weapon.is_equipping()) and p.weapon_key in oh


## The hands spell `id` wants at its tier ("" they are right): untrained and practised both empty (no weapon, no torch, no
## tool, no fishing gear); expert the left empty (no torch there, no long gun beside), the right free or one of
## one_hand_weapons (or the torch). "hands" or "weapon" when not.
func hands_rule(id: String) -> String:
	var p := player
	var torch := torch_side()
	var tool := p.gather.in_hand() if p.gather != null else ""
	var fg := FishingGear.find(p)
	if fg != null and fg.gear != "":
		return "hands"
	var drawn := not p.hands_free and p.weapon != null and (p.weapon.active or p.weapon.is_equipping())
	if tier(id) >= 2:
		if torch == "l" or p.offhand_key != "":
			return "hands"
		if tool != "" and not tool in SwayMoves.one_hand_weapons():
			return "hands"
		if drawn and not p.weapon_key in SwayMoves.one_hand_weapons():
			return "weapon"
		return ""
	if drawn:
		return "weapon"
	if tool != "" or torch != "" or not p.hands_free:
		return "hands"
	return ""


## Whether readying `id` keeps what the right hand holds (expert, a one-handed weapon or the saber in it): the hotbar does not
## free the hands for it.
func keeps_weapon(id: String) -> bool:
	return id != "" and has(id) and tier(id) >= 2 and one_hand_held()


# ---------------------------------------------------------------- modes
## Move `id`'s modes as the ring's kits offer them (moves.json "modes": the element's keys, Bending, the HUD, the bots).
static func modes_of(id: String) -> Array:
	return SwayMoves.move(id).get("modes", [])


## Move `id`'s modes in the open world: "world_modes" where round 2's kits offer fewer of a spell the open world shares
## (Stone Form's disc, the earth wall's column and shell, the pillar's free and ramp), else modes_of.
static func world_modes_of(id: String) -> Array:
	var d := SwayMoves.move(id)
	var w: Variant = d.get("world_modes")
	return w if w is Array else d.get("modes", [])


## This caster's modes of `id`: the ring's (modes_of) with an element, the open world's (world_modes_of) without.
func my_modes(id: String) -> Array:
	return modes_of(id) if elem() else world_modes_of(id)


## Spell `id`'s mode now ("" when it has none; its first by default). While the quick spell is held, locking or landing,
## its own frozen variation for its move (the lock's reach and time, the pose, the effect); else the key's (base_mode_of).
func mode_of(id: String) -> String:
	if id != "" and id == _pin_id and (_pin_on or _pinning) and _pin_mode in my_modes(id):
		return _pin_mode
	if id != "" and id == _sch_id and not _pin_on and _sch_mode in my_modes(id):
		return _sch_mode                       # (the control scheme's pick while the aim is held: a direction's, a band's)
	return base_mode_of(id)


## Spell `id`'s mode as its key has it (what the wheel steps and the strip shows; never the quick spell's frozen one).
func base_mode_of(id: String) -> String:
	var ms := my_modes(id)
	if ms.is_empty():
		return ""
	var m := String(modes.get(id, ""))
	return m if m in ms else String(ms[0])


func set_mode(id: String, m: String) -> bool:
	if not m in my_modes(id):
		return false
	if base_mode_of(id) == m:
		return true
	modes[id] = m
	if state != State.IDLE and move == id and lock_src == SRC_AIM:     # (the quick spell's and the guard's keep their own)
		if state == State.HOLDING:
			_end_hold("mode")
		else:
			_break("mode")                   # (a lock with the old mode ends: the circle was drawn for it)
	mode_changed.emit(id, m)
	return true


## The next mode of `id` (the readied spell by default): the mode key. "" when it has none.
func flip_mode(id := "") -> String:
	if id == "":
		id = readied_spell
	var ms := my_modes(id)
	if ms.is_empty():
		return ""
	var nxt := String(ms[(ms.find(base_mode_of(id)) + 1) % ms.size()])
	set_mode(id, nxt)
	if player != null and player.is_local and player.interactor != null:
		player.interactor.notice(spell_label(id), 1.6)
	return nxt


## The wheel (the user, 2026-10-04: "roll the wheel to change that spell"): the readied spell's next (`dir` 1) or earlier
## (-1) mode. "" when it has fewer than two.
func step_mode(dir: int) -> String:
	var id := readied_spell
	var ms := my_modes(id)
	if ms.size() < 2:
		return ""
	var nxt := String(ms[posmod(ms.find(base_mode_of(id)) + dir, ms.size())])
	set_mode(id, nxt)
	return nxt


static func mode_label(id: String, m: String) -> String:
	return String((SwayMoves.move(id).get("mode_labels", {}) as Dictionary).get(m, m))


## Mode `m`'s name in the open world ("world_mode_labels" where it has its own: "boulder", "free"), else mode_label.
static func world_mode_label(id: String, m: String) -> String:
	var w: Variant = SwayMoves.move(id).get("world_mode_labels")
	if w is Dictionary and (w as Dictionary).has(m):
		return String(w[m])
	return mode_label(id, m)


## The spell's name, with its mode as its key has it ("Stone Form (cannonball)"; base_mode_of: the HUD's readied line, the
## hotbar's and the Tab screen's never take the quick spell's frozen variation while its lock runs; a lock's own is
## label_with(id, mode_of(id))).
func spell_label(id: String) -> String:
	return label_with(id, base_mode_of(id), not elem())


## Move `id`'s name with mode `m` ("Stone Form (Spike)"; the name alone when `m` is "" or is called as the move is: round
## 2's one-mode moves, "Pebbles", never "Pebbles (Pebbles)"; `world`: the open world's words).
static func label_with(id: String, m: String, world := false) -> String:
	var lb := String(SwayMoves.move(id).get("label", id.capitalize()))
	if m == "":
		return lb
	var ml := world_mode_label(id, m) if world else mode_label(id, m)
	return lb if ml.to_lower() == lb.to_lower() else "%s (%s)" % [lb, ml]


# ---------------------------------------------------------------- the quick spell (LMB)
## The element the quick spell is for ("" none: the open world without one, a caster that is not the player's).
func quick_element() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	return BendPoses.element_of(player)


## The quick spell of the player's element now: {id, mode} (its remembered one, MatchSetup.quick_of: the element's default
## until one is set); {} with no element.
func quick_spell() -> Dictionary:
	var el := quick_element()
	if el == "":
		return {}
	if not _quick.has(el):
		_quick[el] = MatchSetup.quick_of(el)
	return _quick[el]


## The quick spell's move ("" none).
func quick_id() -> String:
	return String(quick_spell().get("id", ""))


## The quick spell's variation, frozen at the bind ("" none).
func quick_mode() -> String:
	return String(quick_spell().get("mode", ""))


## "Rock Jab (pebbles)" ("" none).
func quick_label() -> String:
	var id := quick_id()
	return label_with(id, quick_mode()) if id != "" else ""


## Whether the quick spell can be held now: an element, its move a spell this caster has.
func quick_ready() -> bool:
	var id := quick_id()
	return id != "" and is_spell(id) and has(id)


## The quick spell set to `id` in `mode` for the player's element (remembered: MatchSetup.set_quick). False when there is no
## element, or `id` is not one of the element's moves, or `mode` not one of its variations.
func set_quick(id: String, mode: String) -> bool:
	var el := quick_element()
	if el == "" or not MatchSetup.quick_ok(el, id, mode):
		return false
	_quick[el] = {"id": id, "mode": mode}
	MatchSetup.set_quick(el, id, mode)
	return true


## The bind key: the readied skill at its variation now becomes the quick spell (frozen: the wheel stepping the key later
## leaves it), said on the screen "Left click: Rock Jab (pebbles)". False when nothing could be bound (nothing readied:
## the screen says to ready a move first, NOTHING_READIED).
func bind_quick() -> bool:
	var id := readied_spell
	if id == "":
		if player.is_local and player.interactor != null and quick_element() != "":
			player.interactor.notice(NOTHING_READIED % quick_label(), 2.4)
		return false
	if not set_quick(id, base_mode_of(id)):
		return false
	if player.is_local and player.interactor != null:
		player.interactor.notice("Left click: %s" % quick_label(), 1.8)
	return true


## Q's tap (spec §2.1): the readied move at its variation onto the left button, or, when it is there already, the
## element's jab back (next_q says which). True when the left button changed.
func tap_q() -> bool:
	if String(next_q().get("do", "")) == "back":
		return reset_quick()
	return bind_quick()


## What the next tap of Q does: {do "bind" (the readied move onto the left button) | "back" (the jab back) | "" (nothing
## readied), label (the move's name)}. The strip's chip says it.
func next_q() -> Dictionary:
	var id := readied_spell
	var jb := Bending.jab(quick_element())
	if id == "":
		return {"do": "", "label": ""}
	if id == quick_id() and base_mode_of(id) == quick_mode() and not jb.is_empty() \
			and (String(jb.id) != id or String(jb.mode) != quick_mode()):
		return {"do": "back", "label": label_with(String(jb.id), String(jb.mode))}
	return {"do": "bind", "label": spell_label(id)}


## The left button back to the element's jab (Bending.jab; Q held quick_reset_s, or tapped with the readied move on it). True
## when it changed.
func reset_quick() -> bool:
	var el := quick_element()
	var jb := Bending.jab(el)
	if el == "" or jb.is_empty() or (quick_id() == String(jb.id) and quick_mode() == String(jb.mode)):
		return false
	_quick[el] = {"id": String(jb.id), "mode": String(jb.mode)}
	MatchSetup.set_quick(el, String(jb.id), String(jb.mode))
	if player.is_local and player.interactor != null:
		player.interactor.notice("Left click: %s" % quick_label(), 1.8)
	return true


## Whether the lock's moves follow the element's rules (round 2: the header): the player has an element (the ring, the duel).
func elem() -> bool:
	return quick_element() != ""


## The guard's move now: {id, mode} (Bending.guard of the element; {} none).
func guard_spell() -> Dictionary:
	var el := quick_element()
	return Bending.guard(el) if el != "" else {}


## Whether the guard can be held now: an element, its guard a spell this caster has.
func guard_ready() -> bool:
	var id := String(guard_spell().get("id", ""))
	return id != "" and is_spell(id) and has(id)


## The spell the button being held (or locking) casts: the quick spell on LMB, the guard on E, else the readied one.
func lock_spell() -> String:
	if lock_src == SRC_QUICK:
		return quick_id()
	if lock_src == SRC_GUARD:
		return String(guard_spell().get("id", ""))
	return _sch_id if _sch_id != "" else readied_spell


## The move and variation of the lock's own button when it is not the aim's: the quick spell's (LMB), the guard's (E).
func _src_spell(src: String) -> Dictionary:
	if src == SRC_QUICK:
		return {"id": quick_id(), "mode": quick_mode()}
	if src == SRC_GUARD:
		return guard_spell()
	return {}


# ---------------------------------------------------------------- the hotbar's spells
## Every spell one can ready from the hotbar (granted or not: known_spells are the player's), in the file's order:
## [{kind "spell", id, label, art, motes, lock_s, range_m, icon (the HUD's SVG: spell_<id>; "" none), modes}].
static func spells() -> Array:
	var out: Array = []
	for id: String in SwayMoves.ids():
		if not is_spell(id):
			continue
		var d := SwayMoves.move(id)
		var icon := "spell_" + id
		out.append({"kind": "spell", "id": id, "label": String(d.get("label", id.capitalize())), "art": String(d.get("art", "")),
				"motes": int(d.get("motes", 0)), "lock_s": float(d.get("lock_s", 1.0)), "range_m": float(d.get("range_m", 0.0)),
				"icon": icon if ResourceLoader.exists(FrontierHUD.ICON_DIR + icon + ".svg") else "", "modes": world_modes_of(id)})
	return out


## The spells this caster knows (spells()' entries): those granted, every one with free use (has).
func known_spells() -> Array:
	return spells().filter(func(e: Dictionary) -> bool: return has(String(e.id)))


## Readies spell `id` for the next held aim (the hotbar's slot chosen); "" readies none. False when it is not a spell this
## caster has, or it is not on the player's hotbar (spells only from the bar, the owner's rule: a story's grant, give= or
## any other caller cannot ready one off it; a player with no bar, any). A lock on with another move is broken ("switch").
## It stays readied until another (or "") is; the bar follows it (Hotbar.spell) and puts it down as a weapon or a tool is
## taken from it, or the hands are freed.
func ready_spell(id: String) -> bool:
	if id != "" and (not is_spell(id) or not has(id) or not on_bar(id)):
		return false
	if id == readied_spell:
		return true
	readied_spell = id
	_spell_free = id != "" and hands_rule(id) == ""
	if lock_src in [SRC_QUICK, SRC_GUARD]:
		pass                                  # (the quick spell's and the guard's locks are their own: a key readied leaves them)
	elif state == State.HOLDING and move != id:
		_end_hold("switch")
	elif state != State.IDLE and move != id:
		_break("switch")
	_sync_meta()
	spell_readied.emit(id)
	return true


## Whether spell `id` is on the player's hotbar (true with no bar: a stand-in, a caster that is not a player's).
func on_bar(id: String) -> bool:
	var hb := Hotbar.find(player) if player != null else null
	return hb == null or hb.slot_of(Hotbar.SPELL, id) >= 0


## The player's meta SPELL_META while the readied spell has its hands (hands_rule ""): an expert's pistol or tomahawk in the
## other hand fires but does not aim (the RMB is the spell's: Weapon._aim_input_enabled). A spell readied while the
## hands hold what its tier does not allow (a story's grant with the musket out) leaves that weapon its own (it fires, and
## the aim is its own) until the hands are right for the spell. Kept each physics frame, and as a spell is readied or grows.
func _sync_meta() -> void:
	if player == null or not is_instance_valid(player):
		return
	if readied_spell != "" and hands_rule(readied_spell) == "":
		if String(player.get_meta(SPELL_META, "")) != readied_spell:
			player.set_meta(SPELL_META, readied_spell)
	elif player.has_meta(SPELL_META):
		player.remove_meta(SPELL_META)


## The spell's picture for the hotbar (its SVG, assets/ui/icons/spell_<id>.svg; null when it has none).
static func spell_icon(id: String, _tree: SceneTree = null) -> Texture2D:
	var path := FrontierHUD.ICON_DIR + "spell_" + id + ".svg"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The launch arg give=<kind>,... (GatherTools' give=): "form" grants every Form spell, "sway" every spell, a spell's id that
## one; the caster installed, the belt filled; none put on the hotbar and none readied (the Spells list has them: dragged on,
## its key readies it). False when `kind` is no spell (an item: the pack's).
static func give_arg(p: Node, kind: String) -> bool:
	var ids: Array = []
	for e: Dictionary in spells():
		if kind == "sway" or (kind == "form" and String(e.art) == "form") or kind == String(e.id):
			ids.append(String(e.id))
	if ids.is_empty() or not (p is FrontierPlayer):
		return false
	var c := install(p as FrontierPlayer)
	for id: String in ids:
		c.grant(id, false)
	c.set_motes(c.belt_max)
	# not onto the hotbar (the owner, 2026-10-02: "pickups shouldnt auto fill"): a spell granted goes to the Tab screen's
	# Spells list and the player drags it onto a slot (Hotbar, InventoryScreen); readied only from there
	return true


# ---------------------------------------------------------------- each frame
func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_tick_floor(dt)
	_spell_hands()
	_sync_meta()
	_root()
	_plant_cue()
	_track_quick()
	_track_q(dt)
	_track_guard()
	if _wait_release and not _src_held(_wait_src):
		_wait_release = false                 # (the button a fizzle waited on is let go)
	if state == State.IDLE:
		_pick_src()
		if lock_src != SRC_AIM or not _src_held(SRC_AIM):
			_sch_id = ""                          # (the scheme's pick lives while the aim is held)
			_sch_mode = ""
	var held := _src_held(lock_src)
	var waiting := _wait_release and _wait_src == lock_src
	if _track_press(held, dt) and _queued and state != State.IDLE:
		_queued = false                       # (a click waiting on its lock pressed again: a hold again, the time kept)
	_pin_on = lock_src in [SRC_QUICK, SRC_GUARD] and (held or state != State.IDLE)
	var own := _src_spell(lock_src)
	if _pin_on and String(own.get("id", "")) != "" and (state == State.IDLE or _pin_id == ""):
		_pin_id = String(own.id)
		_pin_mode = String(own.mode)
	if not held and _queued and state in [State.LOCKING, State.FULL]:
		held = true                           # (the click's lock runs on as if held: it goes the moment it may)
	var why := blocked()
	if not enabled:
		why = "off"
	var new_side := cast_side() if why == "" else ""
	if state != State.IDLE and not is_spell(move) and side != "" and new_side != side and why == "":
		why = "weapon"                        # (the first lock: the hand that cast is not the one free now)
	readied = why == "" and held and not waiting and lock_spell() != ""
	_camera(dt, held and why == "" and player.is_local and readied)
	if why != "":
		if state == State.HOLDING:
			_end_hold(why)
		elif state != State.IDLE:
			_break(why)
		_hint_hands(why if held and lock_spell() != "" and why in ["hands", "weapon", "bound"] else "")
		return
	side = new_side
	if not held:
		match state:
			State.FULL:
				if elem() and BendStatus.now() < _switch_hold_until:
					_queued = true                # (a switch's new pose shows its hold first: it goes then)
				else:
					_cast()
			State.LOCKING:
				if elem() and _press_t < Bending.rule("click_s", 0.2):
					_queued = true                # (a click: it goes the moment the lock is full)
				else:
					_break("let go")
			State.HOLDING:
				_release_hold()
		if not _queued or state == State.IDLE:
			hint = ""
			_hinted = ""
			_why_key = ""
			return
	if waiting:
		return
	_q = _query()
	if lock_src == SRC_AIM:
		_scheme_follow()
	match state:
		State.IDLE:
			_try_begin(_q)
		State.LOCKING, State.FULL:
			_hold(dt, _q)
		State.HOLDING:
			_tick_hold(dt, _q)


func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	# the arm (the first lock only): in while a lock is on, the shove after a cast, out after. A spell's body is SwayPose's
	# clip; Form's lock is the circle and its crackle, no thread
	var on := state != State.IDLE and _alive(target)
	var posed := (state != State.IDLE and is_spell(move)) or (pose != null and pose.posing())
	var formy := FormCast.is_form(move)
	if posed:
		_arm_w = 0.0
		_shove_t = -1.0
	_arm_w = move_toward(_arm_w, 1.0 if on and not posed else 0.0, dt / (ARM_IN_S if on else ARM_OUT_S))
	if _shove_t >= 0.0:
		_shove_t += dt
		if _shove_t >= SHOVE_S:
			_shove_t = -1.0
	if arm != null:
		arm.side = side if side != "" else arm.side
		var shove := sin(clampf(_shove_t / SHOVE_S, 0.0, 1.0) * PI) if _shove_t >= 0.0 else 0.0
		arm.shove = shove
		arm.weight = maxf(_arm_w, shove)
		arm.tremble = smoothstep(0.7, 1.0, fill) if state != State.IDLE else 0.0
		if on and not posed:
			arm.target = player.skeleton.global_transform.affine_inverse() * locked_point()
	# the thread, from half the lock (Breath: from the palms)
	if thread != null:
		var s := 0.0
		if on and not formy:
			s = 0.75 if state in [State.FULL, State.HOLDING] else smoothstep(0.5, 1.0, fill) * 0.6
			if off_t > 0.0:
				s *= 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() * 0.06))
		thread.color = SwayMoves.art_color(art())
		thread.set_line(hand_point(), _thread_end() if on else thread.to, s)
	if tone != null:
		tone.on = state == State.LOCKING and off_t <= 0.0
		tone.level = fill
	_strain_tremble(dt)


func _held() -> bool:
	if held_override != null:
		return bool(held_override)
	return player.controls.pressed(AIM)


## Whether button `src` is held: the aim (RMB: _held) or the quick spell's (LMB; only while there is a quick spell to cast:
## the open world without an element keeps its LMB as it was; and only a press that began on the game: _track_quick).
func _src_held(src: String) -> bool:
	if radial != null and is_instance_valid(radial) and radial.is_open:
		return false                              # (the move wheel open: the mouse is its; casting waits for it to close)
	if src == SRC_QUICK:
		if not quick_ready():
			return false
		if quick_override != null:
			return bool(quick_override)
		return player.controls.pressed(QUICK) and not _quick_spoiled
	if src == SRC_GUARD:
		if not guard_ready():
			return false
		if guard_override != null:
			return bool(guard_override)
		return player.controls != null and player.controls.pressed(GUARD)
	return _held()


## Whether LMB is the game's now (the player's own mouse): the mouse captured (or a test's ignore_mouse_capture), no
## equip wheel open nor its pick click held, no torch mode (Weapon._fire_input_enabled's checks). Another's controls
## (an AI's, the network's) have no mouse: always.
func _quick_input_ok() -> bool:
	if player.controls == null or not player.controls.from_input:
		return true
	if not (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.ignore_mouse_capture):
		return false
	if player.get("equip_wheel") != null and player.equip_wheel.blocks_fire():
		return false
	if radial != null and is_instance_valid(radial) and radial.blocks_fire():
		return false                              # (the move wheel open, or its pick click still held)
	if player.get("torch") != null and player.torch.blocks_fire():
		return false
	return true


## Once a tick (_physics_process), before the lock reads LMB: a press that began while LMB was not the game's (the click
## that takes the mouse back, Esc's free mouse; the click that picks on the equip wheel) or that ran into such a moment
## is spoiled, ignored until it is let go (Weapon._fire_input_steady: the input on since the tick before the press).
func _track_quick() -> void:
	var ok := _quick_input_ok()
	var down := player.controls != null and player.controls.pressed(QUICK)
	if not down:
		_quick_spoiled = false
	elif not _quick_down_was:
		_quick_spoiled = not (ok and _quick_ok_was)
	elif not ok:
		_quick_spoiled = true
	_quick_down_was = down
	_quick_ok_was = ok


## The button a new lock is tried on (IDLE only): the guard's when it is held (E always works), else the one already held
## keeps it (one lock at a time: a button pressed while the other is held waits until that one is let go), else the aim,
## else the quick spell's; a button whose fizzle is still waiting on its let go is passed over.
func _pick_src() -> void:
	var guard := _src_held(SRC_GUARD) and not (_wait_release and _wait_src == SRC_GUARD)
	if guard:
		lock_src = SRC_GUARD
		return
	var aim := _src_held(SRC_AIM) and not (_wait_release and _wait_src == SRC_AIM)
	var quick := _src_held(SRC_QUICK) and not (_wait_release and _wait_src == SRC_QUICK)
	if (lock_src == SRC_QUICK and quick) or (lock_src == SRC_AIM and aim):
		return
	lock_src = SRC_AIM if aim or not quick else SRC_QUICK


## The lock's button pressed (true the frame it goes down) and how long it has been held (_press_t: the click's test). A
## lock moved to another button counts from that one's press.
var _press_src := ""
func _track_press(held: bool, dt: float) -> bool:
	if lock_src != _press_src:
		_press_src = lock_src
		_held_was = false
	var edge := held and not _held_was
	if edge:
		_press_t = 0.0
	elif held:
		_press_t += dt
	_held_was = held
	return edge


## E pressed (with an element): it takes over any lock running on another button (spec §2.3: dropped, free before the
## click, a raised stone left loose; that button must be let go before it locks again); the guard's lock then begins as
## the frame goes on (_pick_src).
func _track_guard() -> void:
	var g := _src_held(SRC_GUARD)
	var edge := g and not _guard_was
	_guard_was = g
	if not edge or state == State.IDLE or lock_src == SRC_GUARD:
		return
	var was := lock_src
	if state == State.HOLDING:
		_end_hold("guard")
	else:
		_break("guard")
	if _src_held(was):
		_wait_release = true
		_wait_src = was
	lock_src = SRC_GUARD


## Q held (with an element): past quick_reset_s the left button is the jab again (reset_quick), once a hold.
func _track_q(dt: float) -> void:
	var down := elem() and player.controls != null and InputMap.has_action(QUICK_BIND) \
			and player.controls.pressed(QUICK_BIND)
	if not down:
		_q_held_t = -1.0
		return
	if _q_held_t < 0.0:
		_q_held_t = 0.0
		return
	var was := _q_held_t
	_q_held_t += dt
	if was < Bending.rule("quick_reset_s", 0.5) and _q_held_t >= Bending.rule("quick_reset_s", 0.5):
		reset_quick()


## A weapon or a tool taken into the hands after they were right for the readied spell, one its tier does not let it keep
## (keeps_weapon): the spell is put down (the weapon is the player's again; the hotbar's own readied spell the same way).
func _spell_hands() -> void:
	if readied_spell == "":
		_spell_free = false
		return
	if hands_rule(readied_spell) == "":
		_spell_free = true
		return
	var in_hand := not player.hands_free or (player.gather != null and player.gather.in_hand() != "")
	if _spell_free and in_hand and not keeps_weapon(readied_spell):
		if state == State.HOLDING:
			_end_hold("weapon")
		elif state != State.IDLE:
			_break("weapon")
		ready_spell("")


## The spell (or the scripted lock) a hold of the aim is about now: the one locking, else the readied one.
func _about() -> String:
	return move if state != State.IDLE else lock_spell()


## Why no lock can be held now ("" when one can): see the header's breaks. "bound": a captive's hands are tied (Captivity
## bound on this player; the user, 2026-10-03: "lets make the spells free use right now" put every spell in a captive's
## reach, so the bonds hold them, the scripted lock too).
func blocked() -> String:
	var p := player
	if p.is_dead:
		return "dead"
	if _bound():
		return "bound"
	if p.riding != null:
		return "riding"
	if p.kneeling != null:
		return "down"
	if p.climbing != null or p.perch != null or (p.grip != null and p.grip.state != PlayerGrip.OFF) \
			or (p.traversal != null and p.traversal.showing):
		return "climbing"
	var m := _about()
	if p.is_sprinting and not sprint_ok(m):
		return "sprint"
	if p.is_switching():
		return "weapon"
	if (p.building != null and p.building.active) or (p.rts != null and p.rts.active):
		return "building"
	if m != "" and is_spell(m):
		return hands_rule(m)
	# (the scripted lock, or nothing readied: the hands free, a casting hand)
	if cast_side() == "" or not p.hands_free:
		return "weapon" if not p.hands_free and p.weapon != null and (p.weapon.active or p.weapon.is_equipping()) else "hands"
	return ""


## Whether this caster's player is a bound captive (Captivity: its hands tied until end(), an escape or the bonds coming off).
func _bound() -> bool:
	var cap := Captivity.find(get_tree()) if is_inside_tree() else null
	return cap != null and cap.bound and cap.player == player


## Whether a lock of `m` holds while sprinting: the pillar in its self mode (cast in stride), practised and up (untrained,
## the floor cast holds the caster still: rooted).
func sprint_ok(m: String) -> bool:
	return m == "pillar" and mode_of(m) == "self" and tier(m) >= 1


## The untrained floor cast (SwayPose at tier 0: the clap, the squat, the palms on the ground, the stand) holds the caster
## still while it plays: no step, no sprint (drag_speed_cap at ROOT_CAP; a lower cap of another is left; ours let go after).
## In element mode a pose that says root does the same (SwayPose.rooting: the floor cast's squat, the palms on a wall).
func _root() -> void:
	var on := pose != null and is_instance_valid(pose) and pose.rooting() and not player.is_dead
	if on:
		if player.drag_speed_cap > ROOT_CAP:
			player.drag_speed_cap = ROOT_CAP
	elif rooted and player.drag_speed_cap == ROOT_CAP:
		player.drag_speed_cap = INF
	rooted = on


var _plant_acc := -1.0

## The self pillar's lock on while running (practised and up: the launch): a beat in the ring on each foot plant (Footsteps'
## stride wrapping, as its step is heard), the moment the boost wants (FormEffects.plant_gap).
func _plant_cue() -> void:
	if not (state in [State.LOCKING, State.FULL] and move == "pillar" and _self_cast(move) and tier(move) >= 1):
		_plant_acc = -1.0
		return
	var fs := player.get_node_or_null(^"Footsteps")
	var acc: Variant = fs.get(&"_acc") if fs != null else null
	if not (acc is float) or not player.is_on_floor() or player.horizontal_speed() < 2.0:
		_plant_acc = -1.0
		return
	if _plant_acc >= 0.0 and float(acc) < _plant_acc - 0.05:
		if ring != null:
			ring.pulse()                       # (the plant itself is heard: the step, Footsteps)
	_plant_acc = float(acc)


## The arm the first lock points: "r" with the hands free ("l" with the torch in the right hand); "" when no hand is free.
func cast_side() -> String:
	var p := player
	if p.gather != null and p.gather.in_hand() != "":
		return ""
	if p.hands_free:
		return "l" if torch_side() == "r" else "r"
	return ""


func _knows_spells() -> bool:
	if free_use():
		return true                            # (every spell known: free use)
	for id in granted:
		if is_spell(id):
			return true
	return false


## The aim held with the hands free, spells known, none readied (a spell is readied only from the bar): said once a hold.
## Not said (the user, 2026-10-03: "lets make the spells free use right now": with free use every player knows every spell,
## so the aim with the hands free is not a sign of wanting one): with free use while no spell is on the bar (the player has
## not taken one up: the Tab screen lists them), nor near a scripted lock (_scripted_near: the wreck's spar, where the hold
## may be for the first lock, which wants no spell).
## Why the aim held with a spell readied takes no lock, said once a hold (the user, 2026-10-03: "i use right click and
## nothing happens": a far aim, or the crosshair on nothing the spell works on, had said nothing). `hint` is set either way.
func _say_why(key: String, text: String) -> void:
	hint = key
	# (said only once it has held WHY_DELAY_S: not for the crosshair passing over the ground on its way to a target)
	if key != _why_key:
		_why_key = key
		_why_t = 0.0
	_why_t += get_physics_process_delta_time()
	if _why_t < WHY_DELAY_S:
		return
	if lock_spell() == "" or _hinted == key or player.interactor == null or not player.is_local:
		return
	_hinted = key
	player.interactor.notice(text, 1.8)


var _why_key := ""
var _why_t := 0.0
## How long the aim must stay on nothing (or too far) before the reason is said.
const WHY_DELAY_S := 0.35


## Where the thread ends: the crosshair's own point on the target while it is on it, else the locked point (the user,
## 2026-10-03: "the gust line is off aim": it ended where the lock first caught, 16-29 px off the crosshair once the camera
## had come in over the shoulder).
func _thread_end() -> Vector3:
	if _q.has("point") and _alive(target):
		var n: Variant = _q.get("node")
		if n is Node and (n == target or target.is_ancestor_of(n)):
			return _q.point
	return locked_point()


## The readied spell's crosshair on nothing it works on (Gust: someone, an animal, a thing, a fire or a stone).
func _say_none() -> void:
	if lock_spell() == "" or FormCast.is_form(lock_spell()):
		return
	_say_why("none", "%s: aim at someone, an animal, a thing, a fire or a stone" % spell_label(lock_spell()))


func _hint_unreadied() -> void:
	hint = "unreadied"
	if _hinted == "unreadied" or player.interactor == null or not player.is_local or not player.hands_free:
		return
	_hinted = "unreadied"
	var hb := Hotbar.find(player)
	var on := -1
	if hb != null:
		for i in Hotbar.SLOTS:
			if String(hb.entry(i).get("kind", "")) == Hotbar.SPELL:
				on = i
				break
	if (on < 0 and free_use()) or _scripted_near():
		return
	if on >= 0:
		player.interactor.notice("No spell readied: press its key (%d)" % (on + 1), 2.0)
	else:
		player.interactor.notice("No spell readied: Tab, drag a spell from the Spells list onto 1-9, then its key", 2.5)


## A scripted lock within its reach (a node in TARGET_GROUP whose meta sway_move needs no spell and that it would lock now,
## move_for; out to the lock's own RANGE_SLACK): the wreck's spar.
func _scripted_near() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group(TARGET_GROUP):
		var t := n as Node3D
		if t == null or not t.has_meta(&"sway_move"):
			continue
		var m := String(t.get_meta(&"sway_move"))
		if scripted(m) and move_for(t) == m and reach_to(t.global_position, m) <= range_of(m, t) * RANGE_SLACK:
			return true
	return false


func _hint_hands(why: String) -> void:
	if why == "":
		if hint in ["hands", "weapon", "bound"]:
			hint = ""
		if _hinted in ["hands", "weapon", "bound"]:
			_hinted = ""
		return
	hint = why
	if _hinted == why or player.interactor == null or not player.is_local:
		return
	_hinted = why
	var id := lock_spell()
	if why == "bound":
		player.interactor.notice("Your hands are bound", 2.0)          # (Captivity's own words)
	elif tier(id) >= 2:
		player.interactor.notice("%s: the left hand must be empty (the right may hold a pistol, a tomahawk or a saber)" % spell_label(id), 2.0)
	else:
		player.interactor.notice("%s (%s): both hands must be empty" % [spell_label(id), tier_name(id)], 2.0)


# ---------------------------------------------------------------- the target
## What the crosshair is on: {from, dir} and, when it hits, {point, collider, node (the target or null)}.
func _query() -> Dictionary:
	var cam := player.camera
	if cam == null or not cam.is_inside_tree():
		return {}
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var reach := _max_range() + player.cam_distance_now() + 2.0
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	var ex: Array[RID] = [player.get_rid()]
	if hold != null and is_instance_valid(hold) and hold.stone is CollisionObject3D and is_instance_valid(hold.stone):
		ex.append((hold.stone as CollisionObject3D).get_rid())     # (the stone held up: the aim goes past it)
	q.exclude = ex
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"from": from, "dir": dir}
	return {"from": from, "dir": dir, "point": hit.position, "collider": hit.collider, "node": resolve(hit.collider, hit.position)}


## Where the crosshair is (world): its ray's hit, else far along it (INF: no camera).
func aim_point(q: Dictionary) -> Vector3:
	if q.has("point"):
		return q.point
	if q.has("from"):
		return (q.from as Vector3) + (q.dir as Vector3) * 80.0
	return Vector3.INF


## The Sway target behind collider `c` hit at `point` (null: none): a scripted target, a sail or a stone up its parents first, then
## a fighter, an animal (alive), a campfire, a rigid body; else a lit fire or a catching piece where it landed.
func resolve(c: Object, point: Vector3) -> Node3D:
	var chain: Array[Node] = []
	var n := c as Node
	while n != null and chain.size() < 7:
		if n == player:
			return null
		chain.append(n)
		n = n.get_parent()
	for x in chain:
		if x is Node3D and (x.is_in_group(TARGET_GROUP) or x.has_meta(&"sway_move") or x.is_in_group(SAIL_GROUP)
				or x.is_in_group(GustLift.BOULDERS) or x.has_meta(&"sway_stone")):
			return x
	for x in chain:
		if x is FormRaised:
			return x if (x as FormRaised).is_up() else null
		if x is NpcFighter:
			return null if (x as NpcFighter).is_dead() else x
		if x is WildAnimal:
			return null if (x as WildAnimal).is_dead() else x
		if x is Campfire or x is RigidBody3D:
			return x
	return fire_at(point, c)


## A lit campfire or a torch's flame (not this player's own) within FIRE_NEAR_M of `point`, or the built piece `c` is
## part of while it is still catching (a gust puts that out); null when none.
func fire_at(point: Vector3, c: Object = null) -> Node3D:
	var best: Node3D = null
	var bd := FIRE_NEAR_M
	for f in get_tree().get_nodes_in_group(Campfire.GROUP):
		if f is Campfire and (f as Campfire).is_lit():
			var d := (f as Node3D).global_position.distance_to(point)
			if d < bd:
				best = f
				bd = d
	for f in get_tree().get_nodes_in_group(TorchFire.GROUP):
		var tf := f as TorchFire
		if tf == null or tf.state == null or not tf.state.lit or own_torch(tf) or tf.get_parent() is Campfire:
			continue
		var d := tf.global_position.distance_to(point)
		if d < bd:
			best = tf
			bd = d
	if best != null:
		return best
	var fs := FireSpread.find(get_tree())
	if fs != null and c is Node and fs.stage_of(c) == "catching":
		return fs.burnable_at(point, 0.4)
	return null


func own_torch(tf: TorchFire) -> bool:
	return player.torch != null and player.torch.fire == tf


## The kind of target `t` is for a move's `targets`: "scripted", "sail", "stone", "raised", "fighter", "animal", "fire", "prop" (""
## none).
static func kind_of(t: Node) -> String:
	if t == null:
		return ""
	if t.is_in_group(TARGET_GROUP) or t.has_meta(&"sway_move"):
		return "scripted"
	if t.is_in_group(SAIL_GROUP):
		return "sail"
	if GustLift.is_stone(t):
		return "stone"
	if t is FormRaised:
		return "raised"                          # (a raised wall or pillar: Gust tears a piece out of it, FormEffects.gust_chunk)
	if t is NpcFighter:
		return "fighter"
	if t is WildAnimal:
		return "animal"
	if t is Campfire or t is TorchFire or t is BuiltPiece or t.is_in_group(FireSpread.BURNABLE_GROUP):
		return "fire"
	if t is RigidBody3D:
		return "prop"
	return ""


## The move a lock on `t` would be ("" none): a scripted lock it names that needs no spell (the wreck's spar), else the
## readied spell when the target names it or the spell takes its kind (a stone only while it can be lifted: not held or
## flying, risen). Nothing readied: no spell.
func move_for(t: Node3D) -> String:
	if t == null:
		return ""
	var m := ""
	if t.has_meta(&"sway_move"):
		m = String(t.get_meta(&"sway_move"))
		if not scripted(m) and m != lock_spell():
			return ""                             # (a target naming a spell takes only that spell, readied)
		if not can_use(m):
			return ""
	elif lock_spell() != "" and not FormCast.is_form(lock_spell()):
		var k := kind_of(t)
		if k in (SwayMoves.move(lock_spell()).get("targets", []) as Array) and (k != "stone" or GustLift.liftable(t)):
			m = lock_spell()
	if m != "" and t.has_method(&"sway_lockable") and not bool(t.call(&"sway_lockable", m)):
		return ""
	return m


## The tag a cast on `t` is counted under (see the header).
static func tag_of(t: Node) -> String:
	if t == null or not is_instance_valid(t):
		return ""
	if t.has_meta(&"sway_tag"):
		return String(t.get_meta(&"sway_tag"))
	var tg: Variant = t.get(&"tag")
	if tg is String and String(tg) != "":
		return String(tg)
	if t is WildAnimal:
		return (t as WildAnimal).species
	return String(t.name)


func _max_range() -> float:
	var r := 0.0
	for id: String in SwayMoves.ids():
		r = maxf(r, float(SwayMoves.move(id).get("range_m", 0.0)))
		for v in (SwayMoves.move(id).get("mode_range_m", {}) as Dictionary).values():
			r = maxf(r, float(v))
	return r


## The player's chest (ranges are measured from it).
func chest() -> Vector3:
	return player.global_position + Vector3.UP * (0.95 if player.is_crouching else 1.35)


## How far `point` is for move `m`'s range: from the chest; a Form move's flat from the feet (the hands reach the ground).
func reach_to(point: Vector3, m: String) -> float:
	if FormCast.is_form(m):
		var f := player.global_position
		return Vector2(point.x - f.x, point.z - f.z).length()
	return chest().distance_to(point)


## Where the lock is on the target (world), riding on it as it moves.
func locked_point() -> Vector3:
	if _alive(target):
		return target.global_transform * _local_at
	return thread.to if thread != null else chest()


## The casting hand (world): the palms of the cast's clip (SwayPose), else the first lock's arm's palm.
func hand_point() -> Vector3:
	if pose != null and pose.posing() and pose.palms != Vector3.INF:
		return pose.palms
	if arm != null and player.skeleton != null:
		var p := arm.hand_pos(player.skeleton, side if side != "" else "r")
		if p != Vector3.INF:
			return player.skeleton.global_transform * p
	return chest()


## The art of the move locking now ("breath" none).
func art() -> String:
	return String(SwayMoves.move(move).get("art", "breath")) if move != "" else "breath"


func _alive(t: Node) -> bool:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree() or t.is_queued_for_deletion():
		return false
	if t is NpcFighter:
		return not (t as NpcFighter).is_dead()
	if t is WildAnimal:
		return not (t as WildAnimal).is_dead()
	if t is Campfire:
		return (t as Campfire).is_lit()
	if t is TorchFire:
		return (t as TorchFire).state != null and (t as TorchFire).state.lit
	return true


# ---------------------------------------------------------------- the lock
func _try_begin(q: Dictionary) -> void:
	var t: Node3D = null
	var m := ""
	var point := Vector3.ZERO
	var rs := lock_spell()                     # (the readied spell on the aim; the quick spell on its own button)
	if rs == "" and _knows_spells():
		var t0: Node3D = q.get("node")
		if t0 == null or move_for(t0) == "":
			_hint_unreadied()                    # (the aim with spells known and none readied: where to ready one)
			return
	if rs != "" and FormCast.is_form(rs):
		# (Form: the circle's place, the ground, the piece or the stone under the crosshair: FormCast)
		var pk := form.pick(rs, q)
		t = pk.get("node")
		if t == null:
			hint = String(pk.get("hint", ""))
			if hint == "":                     # (FormCast says its own hints; with none, nothing in reach to work on)
				_say_why("none", "%s: aim at %s" % [spell_label(rs),
						"something built that is damaged, within %d m" % roundi(range_of(rs)) if rs == "mend" else "the ground"])
			return
		m = rs
		point = pk.point
	else:
		t = q.get("node")
		if (t == null or move_for(t) == "") and rs != "":
			# (a move with a wider aim zone, Gust's: the nearest target within its cone of the crosshair, not only under it)
			var near := _cone_pick(q, rs)
			if not near.is_empty():
				t = near.node
				q = near
		if t == null:
			hint = ""
			_say_none()
			return
		m = move_for(t)
		if m == "":
			hint = ""
			_say_none()
			return
		point = q.point
		if holds_stone(m, t) and GustLift.casters_needed(t) > 1:
			hint = "heavy"                       # (two casters lift it: GustLift.casters_needed, the assist a hook)
			if _hinted != "heavy" and player.interactor != null and player.is_local:
				player.interactor.notice("Too heavy for one: it needs two casters", 1.5)
			_hinted = "heavy"
			return
	var dist := reach_to(point, m)
	var r := range_of(m, t)
	if dist > r and not _self_cast(m):
		_say_why("far", "Too far: %s reaches %d m" % [spell_label(m) if is_spell(m) else "it", roundi(r)])
		return
	if cost_of(m) > motes:                     # (never with free use: it costs nothing)
		hint = "motes"
		if _hinted != "motes" and player.interactor != null:
			player.interactor.notice("No keelstone left in the belt", 1.5)
		_hinted = "motes"
		return
	hint = ""
	_why_key = ""
	state = State.LOCKING
	move = m
	target = t
	fill = 0.0
	off_t = 0.0
	full_t = 0.0
	hold_t = 0.0
	_local_at = t.global_transform.affine_inverse() * point
	lock_s = _lock_time(m, t, dist, r)
	_began()
	if ring:
		ring.begin()
	lock_started.emit(m, t)


## A new lock's round-2 state (see the header): no click waiting, not grown, nothing raised yet; lightning's charge on the
## hands.
func _began() -> void:
	_queued = false
	grown = false
	_sputtered = false
	_switch_hold_until = -INF
	lock_began_at = BendStatus.now()
	_end_charge()
	if elem() and String(spec_of(move).get("do", "")) == "lightning":
		charge = BendLooks.charge(player, self)


func _end_charge() -> void:
	if charge != null and is_instance_valid(charge):
		charge.call(&"end")
	charge = null


## A lock's time (s) of `m` on `t` at `dist` of its reach `r`: the move's (a stone's, a variation's own), stretched toward the
## end of its range, times the tier's and lock_mult.
func _lock_time(m: String, t: Node3D, dist: float, r: float) -> float:
	var d := SwayMoves.move(m)
	var stretch := lerpf(1.0, float(d.get("far_stretch", 1.0)), smoothstep(r * 0.5, r, dist)) if not _self_cast(m) else 1.0
	var base := float((d.get("stone", {}) as Dictionary).get("lock_s", d.get("lock_s", 1.0))) if holds_stone(m, t) else float(d.get("lock_s", 1.0))
	var mlk: Dictionary = d.get("mode_lock_s", {})
	if mlk.has(mode_of(m)) and not holds_stone(m, t):
		base = float(mlk[mode_of(m)])              # (a variation's own lock: the fireball's, lightning's)
	if elem() and lock_src == SRC_GUARD:
		# (the guard's own: the throw back of a stone held, or a whiffed guard's slower one: BendZone.guard_lock_s)
		return maxf(BendZone.guard_lock_s(player, base * lock_mult * tier_mult(m)), 0.05)
	return maxf(base * stretch * lock_mult * tier_mult(m), 0.05)


## Move `m`'s bend spec at its mode now ({} none: an old mode, a scripted lock).
func spec_of(m: String) -> Dictionary:
	var b: Variant = SwayMoves.move(m).get("bend", {})
	var s: Variant = (b as Dictionary).get(mode_of(m), {}) if b is Dictionary else {}
	return s if s is Dictionary else {}


## Whether move `m` at its mode now grows (▲: its spec's grow).
func grows(m: String) -> bool:
	return elem() and spec_of(m).get("grow") is Dictionary


## A key of `m`'s spec at its mode, else of the move (raise_at_fill, self_lock, place ...): `def` when neither has it.
func spec_key(m: String, key: String, def: Variant = null) -> Variant:
	var s := spec_of(m)
	if s.has(key):
		return s[key]
	return SwayMoves.move(m).get(key, def)


# ---------------------------------------------------------------- the control schemes (see the header)
## The control scheme the aim's lock follows: MatchSetup's with an element (the ring, the duel), else "keys" (the open world).
func scheme() -> String:
	return MatchSetup.scheme() if quick_element() != "" else "keys"


## The direction the move keys hold now: "forward" (W), "back" (S), "side" (A or D), "" none (under the dead zone).
## Forward or back wins a diagonal.
func held_dir() -> String:
	if dir_override != null:
		return String(dir_override)
	if player == null or player.controls == null:
		return ""
	var v := player.controls.move_vector()
	if v.length() < MatchSetup.direction_dead_zone():
		return ""
	if absf(v.y) >= absf(v.x):
		return "forward" if v.y < 0.0 else "back"
	return "side"


## The nearest opponent's distance (m; INF none): a fighter or another player who can still fight.
func foe_distance() -> float:
	if dist_override != null:
		return float(dist_override)
	if player == null or not is_inside_tree():
		return INF
	var best := INF
	var pool: Array = get_tree().get_nodes_in_group(NpcFighter.GROUP)
	pool.append_array(get_tree().get_nodes_in_group(&"player"))
	for n in pool:
		if n == player or not n is Node3D or not NpcSenses.can_fight(n):
			continue
		best = minf(best, (n as Node3D).global_position.distance_to(player.global_position))
	return best


## What the aim's lock casts under the scheme now: {id, mode} ({} nothing readied and no direction). "direction": the
## direction held's move at its own variation (one this caster has), else the readied spell; every other scheme ("keys",
## "radial", "first_moves", a saved "simple"): the readied spell as it is.
func scheme_pick() -> Dictionary:
	var el := quick_element()
	var s := scheme()
	if s == "direction":
		var dir := held_dir()
		if dir != "":
			var dm := MatchSetup.direction_move(el, dir)
			if not dm.is_empty() and has(String(dm.id)):
				return dm
	if readied_spell == "":
		return {}
	# (round 2: "first moves" (once "simple") has no distance band, spec §6: the readied spell as it is)
	return {"id": readied_spell, "mode": base_mode_of(readied_spell)}


## The scheme's pick taken for the aim while no lock runs (the move the lock begins with: the direction held at the press)
## and kept for the whole lock (round 2, spec §6: moving afterwards changes nothing, so strafing never switches a lock).
## Nothing with the keys, the radial or the first-moves scheme (the readied spell as ever).
func _scheme_follow() -> void:
	if not scheme() in ["direction"]:
		_sch_id = ""
		_sch_mode = ""
		return
	if state != State.IDLE:
		return
	var want := scheme_pick()
	_sch_id = String(want.get("id", ""))
	_sch_mode = String(want.get("mode", ""))


## A tap of the hotbar's key `key` (Bending.keys' place) while a lock runs on the aim (Hotbar.select; spec §2.3): the same
## key moves the lock to its other move with the time kept (switch_other), its taps within double_tap_s of a switch
## ignored; another key ends the lock (its first move is the Hotbar's to ready, and with the aim still held it locks
## from nothing). Returns "switch", "ignored", "ended" or "" (no lock of the aim's running: the Hotbar's tap as ever).
func key_tap(key: int) -> String:
	if not elem() or state == State.IDLE or lock_src != SRC_AIM or state == State.HOLDING:
		return ""
	var el := quick_element()
	if Bending.key_of(el, move) == key:
		if BendStatus.now() - _switch_at < Bending.rule("double_tap_s", 0.3):
			return "ignored"
		return "switch" if step_other() else "ignored"
	_break("switch")
	return "ended"


## The running lock (the aim's) moved to its key's other move (Bending.other_move: the mode flipped, or the partner), the
## time kept; a wheel step and the same key mid-lock (key_tap). The new pose's hold shows switch_hold_s before it may go;
## a raised spike turns into a boulder (FormEffects.reshape_raised). False when the key has no other move.
func step_other() -> bool:
	if not elem() or not state in [State.LOCKING, State.FULL] or lock_src != SRC_AIM:
		return false
	var el := quick_element()
	var k := Bending.key_of(el, move)
	if k < 0:
		return false
	var nxt := Bending.other_move(Bending.keys(el)[k] as Array, move, mode_of(move))
	if nxt.is_empty():
		return false
	var keep := [readied_spell, String(modes.get(String(nxt.id), ""))]
	modes[String(nxt.id)] = String(nxt.mode)  # (the key's own variation follows: the strip, the next lock)
	if String(nxt.id) != readied_spell:
		_hotbar_turn(k, String(nxt.id))
	if not _switch_lock(String(nxt.id), String(nxt.mode)):
		modes[String(nxt.id)] = String(keep[1])
		if String(keep[0]) != readied_spell:
			_hotbar_turn(k, String(keep[0]))
		return false
	mode_changed.emit(String(nxt.id), String(nxt.mode))
	_switch_at = BendStatus.now()
	_switch_hold_until = _switch_at + Bending.rule("switch_hold_s", 0.2)
	if raised != null and is_instance_valid(raised):
		raised = FormEffects.reshape_raised(raised, String(nxt.mode))
	return true


## The hotbar's key `k` turned to move `id` (its partner) without ending the lock: the readied spell is it now.
func _hotbar_turn(k: int, id: String) -> void:
	var hb := Hotbar.find(player)
	readied_spell = id
	if hb != null:
		hb.spell = id                         # (first: the key's old move going off the bar is not the readied one)
		hb.assign(k, Hotbar.make(Hotbar.SPELL, id))
	_sync_meta()
	spell_readied.emit(id)


## The lock running moved to `id` at `mode`, the time locked so far kept: its target picked again for it (left as it was
## when the new move takes none here: out of reach, nothing it works on), its lock time, the fill from the time so far
## (back to LOCKING when the new move wants longer, FULL at once when it is past it), the circle and pose begun again.
func _switch_lock(id: String, mode: String) -> bool:
	var keep := [_sch_id, _sch_mode]
	var spent := fill * lock_s
	_sch_id = id
	_sch_mode = mode
	var pk := _lock_target(id, _q)
	if pk.is_empty():
		_sch_id = String(keep[0])
		_sch_mode = String(keep[1])
		return false
	var t: Node3D = pk.node
	var point: Vector3 = pk.point
	var dist := reach_to(point, id)
	var r := range_of(id, t)
	if dist > r and not _self_cast(id):
		_sch_id = String(keep[0])
		_sch_mode = String(keep[1])
		return false
	move = id
	target = t
	_local_at = t.global_transform.affine_inverse() * point
	lock_s = _lock_time(id, t, dist, r)
	off_t = 0.0
	fill = clampf(spent / lock_s, 0.0, 1.0)
	full_t = 0.0
	grown = false
	_sputtered = false
	_end_charge()
	if elem() and String(spec_of(id).get("do", "")) == "lightning":
		charge = BendLooks.charge(player, self)
	var was_full := state == State.FULL
	state = State.LOCKING
	if ring:
		ring.begin()
	lock_started.emit(id, t)                    # (the circle and the pose for the new move)
	lock_switched.emit(id, t)
	if fill >= 1.0:
		if was_full:
			state = State.FULL                   # (no second click: it was full already)
			locked.emit(move, target)
		else:
			_full()
	return true


## Where a lock of `id` would be taken now ({node, point}; {} none), as _try_begin picks it, without its hints.
func _lock_target(id: String, q: Dictionary) -> Dictionary:
	if FormCast.is_form(id):
		var pk := form.pick(id, q)
		var n: Node3D = pk.get("node")
		return {"node": n, "point": pk.point} if n != null else {}
	var t: Node3D = q.get("node")
	if t == null or move_for(t) != id:
		var near := _cone_pick(q, id)
		if near.is_empty():
			return {}
		return {"node": near.node, "point": near.point}
	return {"node": t, "point": q.point}


## Move `m`'s reach on `t` (m): its range_m, or its mode's (mode_range_m: the pillar's free mode); Gust on a stone its
## stone.range_m (the lift's reach).
func range_of(m: String, t: Node = null) -> float:
	var d := SwayMoves.move(m)
	if holds_stone(m, t):
		return float((d.get("stone", {}) as Dictionary).get("range_m", d.get("range_m", 14.0)))
	var mr: Dictionary = d.get("mode_range_m", {})
	var md := mode_of(m)
	if md != "" and mr.has(md):
		return float(mr[md])
	return float(d.get("range_m", 20.0))


## The pillar's self mode: the lock is under the caster (no range, the aim free); Stone Form's too (its circle where the stone
## rises, before the caster: aimed once, at the release; the user, 2026-10-04: "its hard to aim the stone spike").
func _self_cast(m: String) -> bool:
	return self_lock_of(m)


## Whether a lock of `m` is taken under the caster (its circle at the feet, the aim free: _self_cast): the self pillar,
## Stone Form, a move or mode with self_lock; with an element the earth wall and the Column too, wherever KITS keys it (spec
## §2.7: moving the crosshair never breaks its lock; its place is taken from the crosshair at the release,
## FormEffects.place_point, the column's from the aim then).
func self_lock_of(m: String) -> bool:
	if (m == "pillar" and mode_of(m) == "self") or m == "stone_form" or bool(spec_key(m, "self_lock", false)):
		return true
	return elem() and (m in SELF_LOCK_ELEMENT or String(spec_of(m).get("do", "")) == "column")


## Moves whose lock is the caster's own with an element (self_lock_of).
const SELF_LOCK_ELEMENT := ["earth_wall"]


func _moving_mult(m: String) -> float:
	var d := SwayMoves.move(m)
	var mm: Dictionary = d.get("mode_moving_mult", {})
	var k := float(mm.get(mode_of(m), d.get("moving_mult", 0.6)))
	if elem() and quick_element() == "fire":
		k = maxf(k, float(Bending.passive("fire").get("moving_mult", 1.0)))     # (Footwork: full speed on the move)
	return k


## The fill's rate from the element's passive now: Rooted (earth, standing still on the ground: fill_mult), else 1.
func passive_fill() -> float:
	if not elem() or quick_element() != "earth" or not player.is_on_floor():
		return 1.0
	var pv := Bending.passive("earth")
	return float(pv.get("fill_mult", 1.2)) if player.horizontal_speed() < float(pv.get("still_mps", 0.3)) else 1.0


func _hold(dt: float, q: Dictionary) -> void:
	if not _alive(target):
		_break("gone")
		return
	var on := _on_target(q)
	off_t = 0.0 if on else off_t + dt
	if off_t > rule_of(move, "grace_s", grace_s):
		_break("off")
		return
	if not _self_cast(move) and reach_to(locked_point(), move) > range_of(move, target) * RANGE_SLACK:
		_break("far")
		return
	if state == State.LOCKING:
		if not on:
			return                            # (the grace: the ring flickers and waits)
		var rate := 1.0 / lock_s
		if player.horizontal_speed() > moving_mps:
			rate *= _moving_mult(move)
		var pf := passive_fill()
		rate *= pf
		if pf > 1.0:
			_rooted_t -= dt
			if _rooted_t <= 0.0:
				_rooted_t = 0.6
				BendLooks.rooted_dust(player)      # (Rooted: a faint dust at his own feet while it helps)
		fill = minf(fill + rate * dt, 1.0)
		_raise_at_fill()
		_charge_level()
		if fill >= 1.0:
			_full()
	else:
		full_t += dt
		_charge_level()
		if _queued:
			if BendStatus.now() >= _switch_hold_until:
				_cast()                       # (a click, or a let go while a switch's pose showed: it goes now)
			return
		var rw := release_window()
		if elem() and grows(move):
			if not grown and full_t >= Bending.rule("grow_after_s", 0.45):
				_grow()
			if rw > 0.0 and full_t >= rw:
				_cast()                       # (a grown move goes by itself: it never fizzles)
				_wait_release = true          # (the button still held: let go before the next lock)
				_wait_src = lock_src
			return
		if elem() and not _sputtered and full_t >= Bending.rule("sputter_s", 0.7):
			_sputter()
		if rw > 0.0 and full_t > rw:
			_fizzle()


## The second click of a grow (▲) move held on (spec §2.3): it grows; the cast takes its spec's grow.
func _grow() -> void:
	grown = true
	if ring:
		ring.click()
	_sfx("click", -1.0)
	BendLooks.grow_click(self)
	grew.emit(move)


## Held on past sputter_s (a move that does not grow): a fizz on the caster's own hands, the fizzle coming.
func _sputter() -> void:
	_sputtered = true
	BendLooks.sputter(self, Bending.element_of(move))


## Spike's and Boulder's stone (raise_at_fill): at that share of the lock it rises before the caster and hangs, its point on
## the aim (FormEffects.raise_stone); the cast throws it.
func _raise_at_fill() -> void:
	if not elem() or raised != null:
		return
	var at: Variant = spec_key(move, "raise_at_fill", null)
	if at == null or fill < float(at):
		return
	raised = FormEffects.raise_stone(self, move, mode_of(move))


## The stone raised by this lock let go loose (a lock called off, emptied by a hit, or E): FormEffects.drop_raised.
func _drop_raised() -> void:
	if raised != null and is_instance_valid(raised):
		FormEffects.drop_raised(raised)
	raised = null
	FormEffects.drop_raised_of(player)        # (and any other this caster's body still holds up)


## Lightning's charge on the hands (BendLooks.Charge) while its lock runs: louder and brighter as it fills, fullest at the
## click.
func _charge_level() -> void:
	if charge == null or not is_instance_valid(charge):
		return
	charge.set(&"level", 1.0 if state == State.FULL else fill)


## The crosshair still on the locked target: its ray on it, or within the grace cone of the locked point with nothing
## in the way.
func _on_target(q: Dictionary) -> bool:
	if form != null and FormCast.is_form(move):
		return form.on_target(q)
	if q.is_empty():
		return false
	if q.get("node") == target:
		return true
	var c := locked_point()
	var from: Vector3 = q.from
	var to := c - from
	if to.length() < 0.05 or rad_to_deg((q.dir as Vector3).angle_to(to)) > rule_of(move, "cone_deg", cone_deg):
		return false
	var ray := PhysicsRayQueryParameters3D.create(from, c + to.normalized() * 0.05)
	ray.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return h.is_empty() or (h.position as Vector3).distance_to(c) < 0.35 or resolve(h.collider, h.position) == target


## A lock rule of move `m`: its own (moves.json "lock_rules": Gust's easier cone, grace and release window; the user,
## 2026-10-03, "gust its hard and unenjoyable") over the art's (lock: cone_deg, grace_s, release_s).
func rule_of(m: String, key: String, def: float) -> float:
	var r: Variant = SwayMoves.move(m).get("lock_rules", {})
	return float((r as Dictionary).get(key, def)) if r is Dictionary else def


## The seconds after the click within which letting go casts (0: no limit, no fizzle; Gust's).
func release_window() -> float:
	return rule_of(move, "release_s", release_s)


## The nearest target for `m` within its cone of the crosshair when the crosshair's own ray is on none (the aim zone):
## rays in two rings round the aim (half the cone, then the cone), the nearest to the crosshair first. The query as
## _query's ({from, dir, point, collider, node}) of the one found, or {}. Only for a move with its own wider cone.
const CONE_RAYS := 8
func _cone_pick(q: Dictionary, m: String) -> Dictionary:
	var cone := rule_of(m, "cone_deg", cone_deg)
	if cone <= cone_deg + 0.01 or not q.has("from"):
		return {}
	var from: Vector3 = q.from
	var dir: Vector3 = q.dir
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var reach := range_of(m) + player.cam_distance_now() + 2.0
	var space := player.get_world_3d().direct_space_state
	var ex: Array[RID] = [player.get_rid()]
	for ring in [0.5, 1.0]:
		var a := deg_to_rad(cone * ring)
		var best := {}
		var best_off := INF
		for i in CONE_RAYS:
			var th := TAU * float(i) / CONE_RAYS
			var d := (dir * cos(a) + (side * cos(th) + up * sin(th)) * sin(a)).normalized()
			var r := PhysicsRayQueryParameters3D.create(from, from + d * reach)
			r.exclude = ex
			var hit := space.intersect_ray(r)
			if hit.is_empty():
				continue
			var n := resolve(hit.collider, hit.position)
			if n == null or move_for(n) != m:
				continue
			var off := dir.angle_to((hit.position as Vector3) - from)
			if off < best_off:
				best_off = off
				best = {"from": from, "dir": dir, "point": hit.position, "collider": hit.collider, "node": n}
		if not best.is_empty():
			return best
	return {}


## Whether a full lock of `m` on `t` holds instead of casting at the let go: Gust on a sail or on a stone.
static func holds(m: String, t: Node) -> bool:
	return m == "gust" and t != null and (t.is_in_group(SAIL_GROUP) or GustLift.is_stone(t))


## Whether a lock of `m` on `t` is Gust's on a stone (lifted and hurled: GustLift).
static func holds_stone(m: String, t: Node) -> bool:
	return m == "gust" and t != null and is_instance_valid(t) and not t.is_in_group(SAIL_GROUP) and GustLift.is_stone(t)


func _full() -> void:
	state = State.FULL
	fill = 1.0
	full_t = 0.0
	if ring:
		ring.click()
	_sfx("click", -4.0)
	locked.emit(move, target)
	if holds(move, target):
		_begin_hold()
	elif _queued and BendStatus.now() >= _switch_hold_until:
		_cast()                                   # (a click: the move goes the moment its lock is full)


# ---------------------------------------------------------------- holds
func _begin_hold() -> void:
	state = State.HOLDING
	hold_t = 0.0
	_drain_t = 0.0
	set_motes(motes - cost_of(move))        # (paid now: lost if it breaks; none with free use)
	_hold_stone = holds_stone(move, target)
	if _hold_stone:
		hold = GustLift.begin(self, target, SwayMoves.move(move).get("stone", {}))
		hold.aim = aim_point(_q)
	else:
		_sail(target, true)
	hold_started.emit(move, target)


func _tick_hold(dt: float, q: Dictionary) -> void:
	hold_t += dt
	if not _alive(target):
		_end_hold("gone")
		return
	if _hold_stone:
		if hold == null or not is_instance_valid(hold):
			_end_hold("gone")
			return
		hold.aim = aim_point(q)
		if hold.broken():
			_overstrain()
			return
		if reach_to(hold.at(), move) > range_of(move, target) * RANGE_SLACK * 1.4:
			_end_hold("far")
		return
	# a sail: the aim kept on it, a mote every drain_s (none with free use: the wind kept while the lock holds)
	var on := _on_target(q)
	off_t = 0.0 if on else off_t + dt
	if off_t > grace_s:
		_end_hold("off")
		return
	if free_use():
		_drain_t = 0.0
		return
	_drain_t += dt
	var drain := maxf(float((SwayMoves.move(move).get("sail", {}) as Dictionary).get("drain_s", 2.0)), 0.1)
	if _drain_t >= drain:
		_drain_t -= drain
		if motes <= 0:
			_end_hold("motes")
			return
		set_motes(motes - 1)


## The aim let go in a hold: the stone hurled along the aim, the sail let slack. A use counted, `cast`.
func _release_hold() -> void:
	var m := move
	var t := target
	if _hold_stone and hold != null and is_instance_valid(hold):
		hold.hurl(aim_point(_query()))
		hurled.emit(m, t)
	else:
		_sail(t, false)
	_count_use(m)
	var tag := tag_of(t)
	casts[tag] = int(casts.get(tag, 0)) + 1
	if not casts_by_move.has(m):
		casts_by_move[m] = {}
	casts_by_move[m][tag] = int(casts_by_move[m].get(tag, 0)) + 1
	if ring:
		ring.end("cast")
	hold = null
	_hold_stone = false
	_end_lock()
	if player.is_local:
		player.add_recoil(0.7, 0.0)
	_sfx("cast", -2.0, t.global_position if is_instance_valid(t) else chest())
	if is_instance_valid(t) and t.has_method(&"sway_cast"):
		t.call(&"sway_cast", m, self)
	cast_released.emit(m, mode_of(m))
	cast.emit(m, t)


## A hold broken (a hit, a sprint, the aim off the sail ...): the stone drops, the sail goes slack; the motes stay spent.
func _end_hold(why: String) -> void:
	if _hold_stone:
		if hold != null and is_instance_valid(hold):
			hold.drop()
	else:
		_sail(target, false)
	hold = null
	_hold_stone = false
	_break(why)


## Held too long: the power breaks. The stone drops, the caster staggers, the motes are lost (spent as it began).
func _overstrain() -> void:
	var m := move
	var t := target
	if hold != null and is_instance_valid(hold):
		hold.drop()                              # (its break heard at the stone: one break, not two)
	hold = null
	_hold_stone = false
	if player.anim != null and player.anim.has_method(&"play_hit"):
		player.anim.play_hit(Vector2(0.0, 1.0), true)
	if player.is_local:
		player.add_recoil(2.4, 0.8)
		if player.interactor != null:
			player.interactor.notice("Held too long: the hold broke", 2.0)
	overstrained.emit(m, t)
	_break("strain")
	_wait_release = true


func _sail(s: Node3D, on: bool) -> void:
	if s == null or not is_instance_valid(s):
		return
	if s.has_method(&"sway_wind"):
		s.call(&"sway_wind", on, self)
	sail_wind.emit(s, on)


## The strain's tremble in the view (yaw, pitch), as the bow's at full draw held too long; taken out again after.
func _strain_tremble(dt: float) -> void:
	var want := Vector2.ZERO
	if state == State.HOLDING and hold != null and is_instance_valid(hold) and hold.strain > 0.0 and player.is_local:
		var tt := Time.get_ticks_msec() * 0.001
		var a := deg_to_rad(float((hold.d.get("hold", {}) as Dictionary).get("tremble_deg", 1.2))) * hold.strain
		want = Vector2(sin(tt * 23.0) * 0.6 + sin(tt * 37.0) * 0.4, sin(tt * 19.0 + 1.3) * 0.6 + sin(tt * 31.0) * 0.4) * a
	elif _tremble != Vector2.ZERO:
		want = _tremble.move_toward(Vector2.ZERO, deg_to_rad(4.0) * dt)
	var d := want - _tremble
	_tremble = want
	if d != Vector2.ZERO:
		player.yaw += d.x
		player.pitch += d.y


func _cast() -> void:
	var m := move
	var t := target
	var at := locked_point()
	# (the cast's own variation, the quick spell's frozen one or the key's, through its landing and its strike wait,
	# whatever lock runs by then: a quick lock of the same move must not land an RMB cast at its own variation)
	var pin := [m, mode_of(m)]
	var keep := [_pin_id, _pin_mode]
	var grew_now := grown
	_pin_id = m
	_pin_mode = String(pin[1])
	_pinning = true
	grown = false
	set_motes(motes - cost_of(m))             # (none with free use)
	_count_use(m)
	var tag := tag_of(t)
	casts[tag] = int(casts.get(tag, 0)) + 1
	if not casts_by_move.has(m):
		casts_by_move[m] = {}
	casts_by_move[m][tag] = int(casts_by_move[m].get(tag, 0)) + 1
	if ring:
		ring.end("cast")
	_end_lock()
	_shove_t = 0.0
	if player.is_local:
		player.add_recoil(0.7, 0.0)
	_sfx("cast", -2.0, at)
	_land_pending()                           # (one still waiting on its strike lands first)
	var wait := strike_wait(m)
	if wait > 0.0:
		# (the effect leaves on the pose's strike: SwayPose's struck, or the fallback; the release below starts the clip)
		_pending_n += 1
		_pending = {"m": m, "t": t, "at": at, "n": _pending_n, "pin": pin, "grown": grew_now}
		get_tree().create_timer(wait + STRIKE_SLACK_S, false).timeout.connect(_land_pending.bind(_pending_n))
	else:
		_apply_grown(m, t, at, grew_now)
	if is_instance_valid(t) and t.has_method(&"sway_cast"):
		t.call(&"sway_cast", m, self)
	cast_released.emit(m, String(pin[1]))
	cast.emit(m, t)
	_pinning = false
	_pin_id = String(keep[0])
	_pin_mode = String(keep[1])


## Seconds a cast of `m` let go now waits for its pose's strike before its effect lands (0: at once). Only a bend spec in
## STRIKE_DOS (the mode's) whose pose has a strike time; never a guard, a zone, a dash or a buff.
func strike_wait(m: String) -> float:
	if pose == null or not is_instance_valid(pose) or not is_inside_tree():
		return 0.0
	var b: Variant = SwayMoves.move(m).get("bend", {})
	var spec: Variant = (b as Dictionary).get(mode_of(m), {}) if b is Dictionary else {}
	if not (spec is Dictionary) or not String((spec as Dictionary).get("do", "")) in STRIKE_DOS:
		return 0.0
	return maxf(pose.strike_wait(), 0.0)


## A cast waiting on its strike lands now (`n` its number: the fallback timer's, or any with -1). Once.
func _land_pending(n := -1) -> void:
	if _pending.is_empty() or (n >= 0 and int(_pending.n) != n):
		return
	var d := _pending
	_pending = {}
	var t: Variant = d.t
	if player == null or not is_instance_valid(player) or not is_inside_tree() or not is_instance_valid(t):
		return                                  # (the caster gone, or what it was cast at: nothing to land on)
	var pin: Array = d.get("pin", [])
	if pin.is_empty():
		_apply_grown(String(d.m), t as Node3D, d.at, bool(d.get("grown", false)))
		return
	# (a quick cast: its own variation while it lands, whatever lock runs now)
	var keep := [_pin_id, _pin_mode, _pinning]
	_pin_id = String(pin[0])
	_pin_mode = String(pin[1])
	_pinning = true
	_apply_grown(String(d.m), t as Node3D, d.at, bool(d.get("grown", false)))
	_pin_id = String(keep[0])
	_pin_mode = String(keep[1])
	_pinning = bool(keep[2])


## The cast's effect (SwayEffects.apply), grown (▲: the caster's BendCaster.grown while it lands, BendEffects merging the
## spec's grow) when its lock grew. A stone this lock raised and the cast did not throw lies loose after.
func _apply_grown(m: String, t: Node3D, at: Vector3, grew_now: bool) -> void:
	var bc := BendCaster.of(player)
	if bc != null:
		bc.grown = grew_now
	SwayEffects.apply(self, m, t, at)
	if bc != null:
		bc.grown = false
	FormEffects.drop_raised_of(player)


func _on_struck(m: String) -> void:
	if not _pending.is_empty() and String(_pending.m) == m:
		_land_pending()


func _break(why: String) -> void:
	var m := move
	var t := target
	last_break = why
	_drop_raised()                            # (called off: the stone it raised lies loose)
	if ring:
		ring.end("break")
	_end_lock()
	_sfx("break", -6.0)
	lock_broken.emit(m, t, why)


func _fizzle() -> void:
	var m := move
	var t := target
	last_break = "fizzled"
	_drop_raised()
	if ring:
		ring.end("fizzle")
	_end_lock()
	_wait_release = true
	_wait_src = lock_src
	_sfx("fizzle", -8.0)
	fizzled.emit(m, t)


func _end_lock() -> void:
	state = State.IDLE
	_pin_on = false                           # (the key's own variation again; a cast landing keeps it: _pinning)
	fill = 0.0
	off_t = 0.0
	full_t = 0.0
	hold_t = 0.0
	_queued = false
	_sputtered = false
	_switch_hold_until = -INF
	raised = null                             # (thrown by the cast, or dropped loose by _break / _fizzle first)
	_end_charge()
	if thread != null:
		thread.to = locked_point()
	target = null
	move = ""


## A hit taken (the player's hurt). The open world: the lock breaks ("hit"). With an element (spec §2.3): pushed back by
## what the blow cost (BendStatus.setback_s), never wiped; a dash's or a guard's lock is not touched; lightning's charge
## breaks; a hold (Gust's stone) ends as ever.
func _on_hurt() -> void:
	var back := BendStatus.setback_s(player)      # (read once, whatever the lock: the blow's cost is not left for a later one)
	if not elem() or state == State.HOLDING:
		_end_on("hit")
		return
	if state == State.IDLE:
		return
	var sp := spec_of(move)
	if String(sp.get("do", "")) == "lightning":
		var src := lock_src
		_break("hit")
		if _src_held(src):
			_wait_release = true                  # (the charge is lost: let go before it charges again)
			_wait_src = src
		return
	if lock_src == SRC_GUARD or String(sp.get("do", "")) == "dash" or Bending.is_guard(move):
		return
	hit_setback(back)


## The running lock pushed back by `back` s of its time (a hit: _on_hurt; the tests). Back to nothing: the lock runs on from
## nothing while held (its raised stone dropped loose). A full lock is locking again; a grow is undone.
func hit_setback(back: float) -> void:
	if not state in [State.LOCKING, State.FULL]:
		return
	var spent := fill * lock_s - back
	var emptied := spent <= 0.0
	fill = clampf(spent / maxf(lock_s, 0.001), 0.0, 1.0)
	if state == State.FULL and fill < 1.0:
		state = State.LOCKING
		full_t = 0.0
		grown = false
		_sputtered = false
		if ring:
			ring.begin()
	if emptied:
		_drop_raised()
	set_back.emit(move, back, emptied)


func _end_on(why: String) -> void:
	if state == State.HOLDING:
		_end_hold(why)
	elif state != State.IDLE:
		_break(why)


func _on_fired() -> void:
	_end_on("fired")


func _sfx(key: String, db: float, at := Vector3.INF) -> void:
	var id := SwayMoves.sfx(key)
	if id == &"" or not Sfx.has(id):
		return
	Sfx.play_3d(id, at if at != Vector3.INF else hand_point(), db)


# ---------------------------------------------------------------- motes, the camera
func _tick_floor(dt: float) -> void:
	if not floor_on or motes >= floor_max:
		_floor_t = 0.0
		return
	_floor_t = minf(_floor_t + dt, floor_s)        # (one grain a breath, also when floor_s is shortened)
	if _floor_t >= floor_s:
		_floor_t = 0.0
		set_motes(motes + 1)


## With a spell readied the aim held took the camera over the shoulder as a weapon's aim does (FrontierPlayer's own
## aim camera is the weapon's: it eases back each frame, and is set again here after it). Off now (AIM_CAMERA; the user,
## 2026-10-04: "remove the right click zoom"): the view stays where it is while a spell locks.
const AIM_CAMERA := false


func _camera(dt: float, on: bool) -> void:
	_cam_w = move_toward(_cam_w, 1.0 if on and AIM_CAMERA else 0.0, dt / AIM_CAM_S)
	if _cam_w <= 0.0 or player.riding != null or player.spring_arm == null or not (&"_aim_cam_w" in player):
		return
	if float(player.get(&"_aim_cam_w")) < _cam_w:
		player.set(&"_aim_cam_w", _cam_w)
		player.spring_arm.spring_length = player.cam_distance_now()
		player.spring_arm.position.x = player.cam_shoulder_now()


func _exit_tree() -> void:
	if rooted and player != null and is_instance_valid(player) and player.drag_speed_cap == ROOT_CAP:
		player.drag_speed_cap = INF
	rooted = false
	_pending = {}                             # (a strike still to come goes with the caster)


# ---------------------------------------------------------------- saves
func save_data() -> Dictionary:
	return {"motes": motes, "floor_t": _floor_t, "moves": granted.duplicate(), "uses": uses.duplicate(), "modes": modes.duplicate()}


func load_data(d: Dictionary) -> void:
	if d.is_empty():
		return
	for m in d.get("moves", []):
		grant(String(m), false)
	var u: Variant = d.get("uses", {})
	if u is Dictionary:
		for k in u:
			uses[String(k)] = int(u[k])
	var md: Variant = d.get("modes", {})
	if md is Dictionary:
		for k in md:
			if String(md[k]) in world_modes_of(String(k)):       # (the open world's: every mode either way)
				modes[String(k)] = String(md[k])
	_floor_t = float(d.get("floor_t", 0.0))
	set_motes(int(d.get("motes", motes)))


## For SaveParts' player part: the caster's state ({} with none).
static func save_of(p: Node) -> Dictionary:
	var c := of(p)
	if c != null:
		return c.save_data()
	return p.get_meta(&"sway_save", {}) if p != null else {}


## For SaveParts' player part: applied now, or kept until install() when there is no caster yet.
static func load_of(p: Node, d: Dictionary) -> void:
	if p == null or d.is_empty():
		return
	var c := of(p)
	if c != null:
		c.load_data(d)
	else:
		p.set_meta(&"sway_save", d)


# ---------------------------------------------------------------- the story's counts
## Casts landed on targets tagged `tag` ("" any) with `move` ("" any).
static func cast_count(tag := "", m := "") -> int:
	if m != "":
		var by: Dictionary = casts_by_move.get(m, {})
		if tag != "":
			return int(by.get(tag, 0))
		var n := 0
		for k in by:
			n += int(by[k])
		return n
	if tag != "":
		return int(casts.get(tag, 0))
	var all := 0
	for k in casts:
		all += int(casts[k])
	return all


static func reset_counts() -> void:
	casts.clear()
	casts_by_move.clear()


## StoryObjectives' "lock_cast" step ({"kind": "lock_cast", "move": "gust", "target": "<tag>", "count": 1}): begin().
static func lock_cast_begin(step: Dictionary) -> Dictionary:
	return {"had": cast_count(String(step.get("target", "")), String(step.get("move", "")))}


## ... and check(): {done, have, need, at} (at: the first node in group sway_targets with that tag, or null).
static func lock_cast_check(step: Dictionary, base: Dictionary, tree: SceneTree) -> Dictionary:
	var tag := String(step.get("target", ""))
	var need := int(step.get("count", 1))
	var have := cast_count(tag, String(step.get("move", ""))) - int(base.get("had", 0)) + int(base.get("carried", 0))
	var at: Variant = null
	if tag != "" and tree != null:
		for n in tree.get_nodes_in_group(TARGET_GROUP):
			if n is Node3D and tag_of(n) == tag:
				at = (n as Node3D).global_position
				break
	return {"done": have >= need, "have": have, "need": need, "at": at}
