class_name TandemCrawlHold
extends Node
## The stealth crawl hold. The player holds the all-fours crawl, and holding it costs
## stamina. While held the crawl idle plays; as stamina runs low the strained idle blends in
## over it (faster breathing, the back sagging, the shoulders shaking), so the body shows what
## is left. An action done to the character (struck, shoved, startled: flinch()) plays the
## flinch over whatever it is doing and costs a little stamina. Only actions flinch: stamina
## running out never does, the hold just breaks (released "stamina") and the game decides
## what comes next (stand, collapse, get caught).
## Modelled on Frontier's PlayerGrip (the climbing grip's stamina, its released(reason)).
##
## Give it the AnimationPlayer of actor_b_crawl.glb (the Actor_B skeleton and the crawl
## clips). It builds its own AnimationTree over that player's clips:
##   output <- state  Transition, cross-fading from whatever the body is doing:
##     hold     <- tired  Blend2 (synced, the two loops share their timing): the crawl idle
##                        -> the strained idle, by stamina
##     flinch   <- the flinch, from the base pose
##     again_a  <- struck again mid-flinch: the re-hit clip, which starts from the flinch's
##     again_b  <-   hold; two lanes, so each new hit cross-fades from the last one
## (A OneShot can't chain hits: firing it again restarts the shot from its base-pose first
## frame and snaps the body back.)

const CLIPS = preload("res://features/tandem/frontier_tandem_clips.gd")

signal hold_started
## The hold ended: "let_go" (the player let go) or "stamina" (it ran out).
signal released(reason: String)
## An action done to the character made it flinch (cause as given to flinch()).
signal flinched(cause: String)
signal stamina_changed(value: float, max_value: float)

const IDLE := "actor_b-crawl-idle"
const STRAIN := "actor_b-crawl-strain"
const FLINCH := "actor_b-crawl-flinch"
const FLINCH_AGAIN := "actor_b-crawl-flinch-again"

@export var anim_player: AnimationPlayer
@export var library: StringName = &""
## Optional separately authored backward reaction for the crawling player.
@export var backward_clip: Animation

@export_group("Stamina")
@export var stamina_max := 100.0
@export var drain_hold := 4.0          ## stamina / s holding the crawl (25 s from full)
@export var recover_while_holding := false ## Tandem poses recover while idle.
@export var regain := 25.0             ## stamina / s coming back once the hold has ended
@export var rest_s := 1.0              ## s after the hold ends before stamina comes back
@export var min_to_start := 15.0       ## a hold can't begin with less than this
@export var flinch_cost := 10.0        ## stamina each flinch costs (0: flinches are free)

@export_group("Strain")
## The strained idle starts blending in below this fraction of stamina and is full at zero.
@export var strain_from := 0.6
@export var strain_rate := 1.5         ## blend / s the strain follows stamina at

@export_group("Flinch")
@export var flinch_fade_in := 0.05     ## s: short, so the hit reads at once
@export var rehit_fade_in := 0.08      ## s into a re-hit, from wherever the last flinch is
@export var flinch_fade_out := 0.25    ## s from the flinch's end back into the idle

var stamina := 100.0
var holding := false
var strain := 0.0                      ## the strained idle's blend weight now (0..1)
var tree: AnimationTree
var _state: AnimationNodeTransition
var _rest := 0.0                       ## s till stamina comes back
var _flinch_left := 0.0                ## s of the current flinch clip still to play
var _flinch_len := 1.2
var _lane := ""                        ## the flinch lane last played ("flinch", "again_a", "again_b")
var _in_flinch := false                ## the tree is on a flinch lane (not yet fading back to hold)


func _ready() -> void:
	stamina = stamina_max
	if anim_player != null:
		_build_tree()


func _physics_process(delta: float) -> void:
	tick(delta)


## Starts holding the crawl. False (and nothing starts) with too little stamina.
func start_hold() -> bool:
	if holding:
		return true
	if stamina < min_to_start:
		return false
	holding = true
	hold_started.emit()
	return true


## The player lets go of the hold.
func let_go() -> void:
	if holding:
		_release("let_go")


## Something was done to the character (struck, shoved, startled): it flinches, whatever
## the idle was doing, and pays flinch_cost. Struck again mid-flinch, it jolts deeper (the
## re-hit clip, cross-faded from where the body is). If stamina runs out during a flinch, the
## hold breaks once the flinch has played. False when not holding.
## `fullness` is the flinch gauge: how full the flinch plays (1: as authored; see TandemClips.variant).
func flinch(cause := "hit", fullness := 1.0) -> bool:
	if not holding:
		return false
	if _flinch_left > 0.0:
		_lane = "again_b" if _lane == "again_a" else "again_a"
		_set_fullness(_lane, fullness)
		_play(_lane, rehit_fade_in)
	else:
		_lane = "flinch"
		_set_fullness(_lane, fullness)
		_play(_lane, flinch_fade_in)
	_in_flinch = true
	_flinch_left = _flinch_len
	_spend(flinch_cost)
	pause_recovery()
	flinched.emit(cause)
	return true


## The crawling player's own backward reaction; repeat presses retrigger immediately.
func flinch_backward() -> bool:
	if not holding or backward_clip == null or stamina <= 0.0:
		return false
	_lane = "back_b" if _lane == "back_a" else "back_a"
	_play(_lane, flinch_fade_in)
	_in_flinch = true
	_flinch_left = backward_clip.length
	_spend(flinch_cost)
	pause_recovery()
	flinched.emit("backward")
	return true


## Frontier's Player.hurt(local_dir, amount, heavy), connected directly: any hit flinches.
func on_hurt(_local_dir: Vector2, _amount: float, _heavy: bool) -> void:
	flinch("hit")


func is_flinching() -> bool:
	return _flinch_left > 0.0


func tick(delta: float) -> void:
	_flinch_left = maxf(_flinch_left - delta, 0.0)
	if _in_flinch and _flinch_left <= flinch_fade_out:
		_in_flinch = false
		_play("hold", flinch_fade_out)            # the flinch's tail cross-fades into the idle
	if holding:
		_spend(drain_hold * delta)
		if stamina <= 0.0 and _flinch_left <= 0.0:
			_release("stamina")
		elif recover_while_holding and not is_flinching():
			_recover(delta)
	else:
		if not is_flinching():
			_recover(delta)
	var frac := stamina / stamina_max
	var target := smoothstep(0.0, 1.0, clampf(1.0 - frac / strain_from, 0.0, 1.0))
	strain = move_toward(strain, target, strain_rate * delta)
	if tree != null:
		tree.set("parameters/tired/blend_amount", strain)


func pause_recovery() -> void:
	_rest = rest_s


func _recover(delta: float) -> void:
	_rest = maxf(_rest - delta, 0.0)
	if _rest <= 0.0 and stamina < stamina_max:
		stamina = move_toward(stamina, stamina_max, regain * delta)
		stamina_changed.emit(stamina, stamina_max)


func _play(state: String, fade: float) -> void:
	if tree == null:
		return
	_state.xfade_time = fade
	tree.set("parameters/state/transition_request", state)


## The lane about to play uses the clip at this fullness (the other lanes are not touched: one may be playing).
func _set_fullness(lane: String, fullness: float) -> void:
	var node := (tree.tree_root as AnimationNodeBlendTree).get_node(lane) as AnimationNodeAnimation
	var want := CLIPS.variant(anim_player, library, FLINCH if lane == "flinch" else FLINCH_AGAIN, fullness)
	if node.animation != want:
		node.animation = want


func _spend(amount: float) -> void:
	if amount <= 0.0:
		return
	stamina = maxf(stamina - amount, 0.0)
	stamina_changed.emit(stamina, stamina_max)


func _release(reason: String) -> void:
	holding = false
	_rest = rest_s
	released.emit(reason)


func _clip(anim: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = _qualified(anim)
	return n


func _build_tree() -> void:
	for nm in [IDLE, STRAIN]:
		anim_player.get_animation(_qualified(nm)).loop_mode = Animation.LOOP_LINEAR
	for nm in [FLINCH, FLINCH_AGAIN]:
		anim_player.get_animation(_qualified(nm)).loop_mode = Animation.LOOP_NONE
	_flinch_len = anim_player.get_animation(_qualified(FLINCH)).length

	var bt := AnimationNodeBlendTree.new()
	var tired := AnimationNodeBlend2.new()
	tired.sync = true                  # both loops keep running, so the blend stays in step
	_state = AnimationNodeTransition.new()
	for input in ["hold", "flinch", "again_a", "again_b"]:
		_state.add_input(input)
	for i in [1, 2, 3]:
		_state.set_input_reset(i, true)    # each flinch lane starts its clip from the top
	bt.add_node("idle", _clip(IDLE), Vector2(-500, -80))
	bt.add_node("strain", _clip(STRAIN), Vector2(-500, 40))
	bt.add_node("tired", tired, Vector2(-300, -20))
	bt.add_node("flinch", _clip(FLINCH), Vector2(-300, 120))
	bt.add_node("again_a", _clip(FLINCH_AGAIN), Vector2(-300, 240))
	bt.add_node("again_b", _clip(FLINCH_AGAIN), Vector2(-300, 360))
	bt.add_node("state", _state, Vector2(-60, 60))
	bt.connect_node("tired", 0, "idle")
	bt.connect_node("tired", 1, "strain")
	bt.connect_node("state", 0, "tired")
	bt.connect_node("state", 1, "flinch")
	bt.connect_node("state", 2, "again_a")
	bt.connect_node("state", 3, "again_b")
	if backward_clip != null:
		var library := AnimationLibrary.new()
		library.add_animation("backward", backward_clip)
		if anim_player.has_animation_library("crawl_reactions"):
			anim_player.remove_animation_library("crawl_reactions")
		anim_player.add_animation_library("crawl_reactions", library)
		for lane: String in ["back_a", "back_b"]:
			var index := _state.get_input_count()
			_state.add_input(lane)
			_state.set_input_reset(index, true)
			bt.add_node(lane, _clip("crawl_reactions/backward"))
			bt.connect_node("state", index, lane)
	bt.connect_node("output", 0, "state")

	tree = AnimationTree.new()
	tree.name = "CrawlHoldTree"
	tree.tree_root = bt
	add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	# The clips' tracks are relative to the player's root node (the glb scene's root).
	tree.root_node = tree.get_path_to(anim_player.get_node(anim_player.root_node))
	tree.active = true
	_play("hold", 0.0)        # a new Transition has no current state (it would leave the rest pose)


func _qualified(clip: String) -> StringName:
	if clip.contains("/") or library == &"":
		return StringName(clip)
	return StringName(String(library) + "/" + clip)
