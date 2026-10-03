class_name GatherTools
extends Node
## Gathering with tools (user roadmap 2026-09-26: "tree cutting ... with a axe so they can build ... logs forts
## and etc? mining rocks for stone and etc"): the felling axe and the mattock, the strokes, what they cut and
## break, and the Woodcutting / Mining skills (GatherSkills) that grow from it. data/gathering/gathering.json.
##
## Controls:
##   7            the tool button: felling axe -> mattock -> put away (a weapon in the hands is put away first:
##                the hands go free, H or a weapon key draws the weapon again and the tool goes back); the mouse
##                wheel cycles the weapons and then the tools
##   LMB (hold)   with a tool out and something it works in front of you: swing, and keep swinging while held
##   E (tap)      at a tree, sapling, felled trunk or rock (the prompt says what): takes out the right tool if it
##                is not in the hand and swings it once
## The torch (PlayerTorch, T): the tools take both hands. Taking one out with a torch in a hand tosses the
## torch down first (it keeps burning on the ground and lights the work; E picks it up); a torch taken into the
## hand while a tool is out (T, E on a dropped one) sends the tool back.
## What the strokes do:
##   standing tree  work into the trunk until it is cut through (strokes by the trunk's diameter, the species'
##                  hardness and the skill); it falls away from you (FelledTree; a Novice's fall wanders up to
##                  30 deg, from Apprentice it goes where you mean it to), leaving a stump
##   sapling        one or two strokes: a pole and branches
##   felled trunk   bucked into logs where it lies (one per 2.4 m of clear bole, fewer good logs for a Novice:
##                  the rest split into firewood), then limbed: firewood and branches
##   felled crown   limbed where it lies (user 2026-09-27: "cut the branches off trees to make it into a log"):
##                  strokes by the crown's spread, then its firewood and branches go into the pack and the trunk
##                  lies bare, a log (SkidLoad) to buck, to drag on foot (LogPull) or behind the horse, or to lay
##                  in a barricade
##   rock           broken into stone (and chert from the limestone), the rock shrinking as it goes until it is
##                  gone (VegHarvest)
##   ground         (the hoe, or the digging stick standing in for it; farming, FarmField) open ground broken out into
##                  a bed, a growing bed's weeds hoed out; open ground is only a target with the hoe in the hand
## Everything gathered goes into the pack (InventoryState pack; every item stacks) with a notice at the top of
## the screen; each new level of a skill has one too (and the tier's line at 20, 40, 60, 80).
##
## Animation (ToolPose, clips of animations_extra/Actor_B_from_A.res): the draw and the put-away are the machete's
## draw and stow from the pack (the tool rides head down in the pack's tool loop, its haft up behind the right
## shoulder, where the draw's hand closes on it); in the hand it is carried like the machete after its draw; a
## felling stroke is the two-handed level swing (atk-pipe-2-side-swing), bucking and breaking stone the
## two-handed overhead blow (atk-pipe-1-chop). Standing still the whole body plays the swing (its footwork too),
## moving only the upper body. The tool sits in the prop bone's own frame of each clip family (the blade frame
## of the machete clips, the two-handed frame of the pipe clips) and moves between them with the blend.
##
## The musket as a club (user 2026-09-27: "make it where we can turn muskets into clubs"; picked: a key flips it,
## held by the barrel): middle mouse with a long gun out (loaded or not; not while aiming, firing or reloading)
## turns it end for end in the hands, the barrel a hand's breadth behind the muzzle in both hands and the butt out
## as the head (the tool CLUB here: a copy of the gun's model, the gun's own hidden); LMB then attacks with WASD as
## with the felling axe (AxeMelee, data/melee/musket_club.json: blunt, nothing cut in to), from a two-handed guard;
## middle mouse again turns it back to shoot. The gun stays the weapon out: Weapon.clubbed keeps its fire, aim and
## reload keys off meanwhile; putting it away, another weapon or mounting ends the club at once.

signal stroke_landed(kind: String, info: Dictionary)
signal gathered(item: String, count: int)
signal felled(tree: FelledTree)
## A felled tree limbed where it lay: the bare log left (SkidLoad).
signal limbed(log: SkidLoad)

## One tool button (user 2026-09-26: "i think a single button works"): 7 cycles felling axe -> mattock -> put away
## (tools_cycle()); the mouse wheel's weapon cycle goes on through the tools too (FrontierPlayer). The per-tool actions
## stay for remapping, without a default key.
const CYCLE_ACTION := &"tool_cycle"
const CYCLE_KEY := KEY_7
const ACTIONS := {"felling_axe": &"tool_axe", "mattock": &"tool_mattock", "hoe": &"tool_hoe"}
const KEYS := {}
## The tools in the button's and the wheel's order.
const ORDER := ["felling_axe", "mattock", "hoe", "saber"]
const AXE := "felling_axe"
const STONE_AXE := "stone_axe"
const SKILL_OF := {"felling_axe": "woodcutting", "mattock": "mining", "hoe": "husbandry", "saber": "woodcutting"}
## Target types each tool works on.
const WORKS := {"felling_axe": ["tree", "sapling", "trunk", "crown", "wall", "carcass", "stump"], "mattock": ["rock", "stump"], "hoe": ["ground"]}
## The swing each target type takes.
## The musket as a club (see the top).
const CLUB := "musket_club"
const CLUB_ACTION := &"club_grip"
const CLUB_WEAPONS := ["musket", "over_under"]
const FLIP_S := 0.35
## The tools that attack on LMB when there is nothing to work in front (AxeMelee; data/melee/<tool>.json).
const MELEE_TOOLS := ["felling_axe", "musket_club", "saber"]
## Fought one-handed on the axe's two-handed swings: their left arm left out (ToolPose mask "upper_one_hand").
const ONE_HANDED := ["saber"]
## Where the axe's two-handed swings have the right fist on the haft (m up from the knob, measured with tools/perf/saber_grip_probe.gd).
const SWING_GRIP_M := 0.22
const SWING_OF := {"tree": "side", "sapling": "side", "trunk": "chop", "crown": "side", "rock": "chop", "wall": "side",
		"carcass": "chop", "ground": "chop", "stump": "chop"}
## Seconds after a draw starts before the hand closes on the tool (clip time), the draw's play rate.
const DRAW_RATE := 1.35
const STOW_RATE := 1.4
const FADE_IN_S := 0.12
const FADE_OUT_S := 0.3
const CHAIN_FADE_S := 0.14
## Seconds to wait for a weapon's holster before the draw.
const HOLSTER_S := 0.42
## Target search every n physics ticks.
const SEARCH_EVERY := 3
const VIEW_ANGLE_DEG := 60.0
const SOUND_PATH := "res://audio/sfx/gathering/%s_%02d.wav"

enum Phase { IDLE, HOLSTER, DRAW_GRAB, DRAW_OUT, READY, SWING, STOW_BACK, STOW_PLACE }

var player: FrontierPlayer
var data: GatherData
var skills: GatherSkills
var harvest: VegHarvest
var pose: ToolPose
var gather_target: GatherTarget
## The tool in the hand, being drawn or put away ("" none).
var tool := ""
## The tool riding the pack's tool loop ("" none), from the worn loadout (point tool_loop).
var on_loop := ""
var phase := Phase.IDLE
## The gatherable in front of the player ({} none): type, src, i, pos, radius, dist, point, normal, name
## (+ felled for a trunk, left / total for a rock).
var target := {}
## Yield rolls (log quality, a second stone, chert).
var rng := RandomNumberGenerator.new()

var _clips: AnimationLibrary
var _clip_path := ""
var _t := 0.0                  ## clip time of the draw / stow phases
var _w := 0.0                  ## weight of the draw / stow layer
var _carry_w := 0.0
var _pending := ""             ## tool to draw once the current put-away (or holster) is done
var _pending_stroke := false
var _auto_stroke := false      ## one stroke as soon as the tool is out (E)
var _queued := 0               ## strokes asked for by E during a swing
var _swing := {}               ## the current swing
var _prev_swing := {}          ## the swing fading out under it (a chained stroke)
var _work := {}                ## "tree:i" / "sap:src:i" -> stroke power so far
var _cut := {}                 ## "tree:i" -> the height (world y) the last stroke went in at: where it is cut through
var _rock := {}                ## prop index -> {total, left, work}
var _tick := 0
var _socket_hand: BoneAttachment3D
var _palm_att: BoneAttachment3D
var _socket_back: BoneAttachment3D
var _model_hand: Node3D
var _model_back: Node3D
var _model_hand_kind := ""
var _model_back_kind := ""
var _back_xf := {}             ## tool kind -> Transform3D on the pack (spined frame)
var _was_keys := {}
var _was_fire := false
var _notes: PackedStringArray = []
var _last_prompt := ""
var _last_loadout: Loadout
## Tools lost (knocked out of the hands and lying somewhere, DroppedItem; user 2026-09-27: "tools can be losable"): not
## given back by _ensure_owned until found again.
var lost := {}
var _pipe_w := 0.0
var _one_hand_shift := 0.0       ## a one-handed grip's place along the hand, measured at the carry
## Directional attacks with the felling axe when there is nothing to work in front (AxeMelee).
var melee: AxeMelee
var _melee_next := ""          ## an attack asked for during a swing, begun at its chain time
var _melee_next_button := "L"   ## the button that asked for it
var _club_key := ""            ## the weapon clubbed ("" none)
var _club_flip := 0.0          ## 0 the shooting grip .. 1 held as a club
var _club_to := 0.0            ## where the flip is going
var _club_start := Transform3D()   ## the gun's own place on the prop bone, in the club's (two-handed) frame
var _streams := {}             ## sound id -> [AudioStream]


static func install(p: FrontierPlayer) -> GatherTools:
	var g := GatherTools.new()
	g.name = "GatherTools"
	g.player = p
	p.add_child(g)
	return g


static func ensure_input() -> void:
	for kind: String in ACTIONS:
		var a: StringName = ACTIONS[kind]
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a)
		if KEYS.has(kind):
			var e := InputEventKey.new()
			e.physical_keycode = KEYS[kind]
			InputMap.action_add_event(a, e)
	if not InputMap.has_action(CYCLE_ACTION):
		InputMap.add_action(CYCLE_ACTION)
		var c := InputEventKey.new()
		c.physical_keycode = CYCLE_KEY
		InputMap.action_add_event(CYCLE_ACTION, c)
	if not InputMap.has_action(CLUB_ACTION):
		InputMap.add_action(CLUB_ACTION)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_MIDDLE
		InputMap.action_add_event(CLUB_ACTION, mb)


func _ready() -> void:
	ensure_input()
	rng.seed = 1765
	_give_from_args.call_deferred()
	data = GatherData.get_default()
	var headless_test := DisplayServer.get_name() == "headless"
	skills = GatherSkills.new() if headless_test else GatherSkills.for_player()
	skills.leveled.connect(_on_leveled)
	_clip_path = String(data.clips.get("library", "res://animations_extra/Actor_B_from_A.res"))
	if ResourceLoader.exists(_clip_path):
		ResourceLoader.load_threaded_request(_clip_path, "AnimationLibrary")
	gather_target = GatherTarget.new()
	gather_target.name = "GatherTarget"
	gather_target.tools = self
	add_child(gather_target)
	_build_rig.call_deferred()


## The sockets, the pose modifier and the pack's tool (once the player's skeleton is up).
func _build_rig() -> void:
	var sk := player.skeleton
	if sk == null:
		return
	pose = ToolPose.new()
	pose.name = "ToolPose"
	sk.add_child(pose)
	melee = AxeMelee.new(self)
	_socket_hand = BoneAttachment3D.new()
	_socket_hand.name = "gather_tool_socket"
	_socket_hand.bone_name = "r_hand_prop_attachment"
	sk.add_child(_socket_hand)
	# the right palm, as the pose leaves it: where a one-handed blade's grip goes along the haft (ONE_HANDED)
	_palm_att = BoneAttachment3D.new()
	_palm_att.name = "gather_palm"
	_palm_att.bone_name = "r_palm"
	sk.add_child(_palm_att)
	_socket_back = BoneAttachment3D.new()
	_socket_back.name = "gather_pack_socket"
	_socket_back.bone_name = String(data.carry.get("bone", "spined"))
	sk.add_child(_socket_back)
	_ensure_owned(true)
	_refresh_models()


# --- Owned tools, the pack loop, the pack --------------------------------------------------------------

## Every tool is the player's from the start (user: everything unlocked): at the start (`first`) the felling axe
## goes on the pack's tool loop and the mattock into the pack (the pack, InventoryState, is materialized then);
## after a change of the worn gear (a kit, the inventory screen) a tool that is neither worn nor in the pack is
## put back into the pack.
func _ensure_owned(first := false) -> void:
	# a start with nothing: no tool is handed out (the stone axe is made; the steel ones are traded for)
	if SurvivalBridge.bare_of(get_tree()):
		_last_loadout = player.loadout
		_read_loop()
		return
	var inv := InventoryState.from_player(player)
	var worn := false
	for kind: String in data.tools:
		if bool(data.tools[kind].get("crafted", false)):
			continue                 # (made or bought, never handed out: the hoe)
		if player.loadout and player.loadout.has_kind(kind):
			worn = true
			continue
		if inv.pack_count(kind) <= 0 and not lost.has(kind):
			inv.add(kind, 1)
	if first and player.loadout and not worn and inv.pack_count("felling_axe") > 0:
		var p := String(data.carry.get("point", "tool_loop"))
		if LoadoutRules.gear_points(player.loadout.gear, player.loadout.shoulder_ew_sash).points.has(p):
			player.loadout.add_item("felling_axe", [p], 1)
			inv.take("felling_axe", 1)
	player.inventory_pack = inv.pack.duplicate(true)
	_last_loadout = player.loadout
	_read_loop()


func _read_loop() -> void:
	on_loop = ""
	if player.loadout == null:
		return
	var p := String(data.carry.get("point", "tool_loop"))
	for it: Dictionary in player.loadout.items:
		if (it.points as Array).has(p) and data.is_tool(String(it.kind)):
			on_loop = String(it.kind)


## Whether the player has `kind` (worn on the loop or in the pack).
func owns(kind: String) -> bool:
	if on_loop == kind:
		return true
	if _in_pack(kind):
		return true
	# a stone axe is the felling axe's stand-in (the start with nothing), a digging stick the hoe's
	return stand_in(kind) != ""


## The stand-in the player works `kind` with when they have no `kind` itself (data stone_tools: stands_for): "" none.
func stand_in(kind: String) -> String:
	for s: String in data.stone_tools:
		if String(data.stone_tools[s].get("stands_for", "")) == kind and _in_pack(s):
			return s
	return ""


## The player has only the stand-in of `kind` (none of the tool itself on the loop or in the pack).
func stand_in_only(kind: String) -> bool:
	return on_loop != kind and not _in_pack(kind) and stand_in(kind) != ""


func _in_pack(kind: String) -> bool:
	for e: Dictionary in player.inventory_pack:
		if String(e.get("kind", "")) == kind and int(e.get("count", 0)) > 0:
			return true
	return false


## The felling axe the player works with is the stone one (no steel felling axe on the loop or in the pack).
func stone_only() -> bool:
	return on_loop != AXE and not _in_pack(AXE) and _in_pack(STONE_AXE)


## What a stroke of `kind` (the tool in the hand) is worth against a steel felling axe's: the stone axe's share.
func stroke_mult(kind: String) -> float:
	if stand_in_only(kind):
		return float(data.stone_tools.get(stand_in(kind), {}).get("power", 0.45))
	return 1.0


## The model drawn for the tool in the hand: the stone axe's for the felling axe stood in for.
func _model_kind(kind: String) -> String:
	return stand_in(kind) if stand_in_only(kind) else kind


## Puts `n` of `item` into the pack (stacking) and notes it.
func give(item: String, n: int) -> void:
	if n <= 0:
		return
	var inv := InventoryState.from_player(player)
	inv.add(item, n)
	player.inventory_pack = inv.pack.duplicate(true)
	var nm := data.name_of(item)
	# (the HUD shows it as a toast with the item's picture, FrontierHUD.toast)
	if not _hud_toasts():
		_note("+%d %s" % [n, nm if n == 1 else _plural(nm)])
	gathered.emit(item, n)


func _hud_toasts() -> bool:
	var h: Variant = player.get("hud") if player else null
	return h != null and is_instance_valid(h) and (h as Node).has_method("toast")


static func _plural(nm: String) -> String:
	if nm.ends_with("s") or nm in ["Firewood", "Flint", "Stone"]:
		return nm
	if nm.ends_with("ch"):
		return nm + "es"
	return nm + "s"


# --- Frame --------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or pose == null:
		return
	if _clips == null:
		_try_clips()
	if player.loadout != _last_loadout:
		_ensure_owned()
		_refresh_models()
	_tick += 1
	if _tick % SEARCH_EVERY == 0 or target.is_empty():
		_find_target()
	_read_keys()
	_guard()
	_step(delta)
	_apply_layers()
	_update_prompt()
	if not _notes.is_empty():
		if player.interactor:
			player.interactor.notice("   ".join(_notes), 3.5 if _notes.size() > 1 else 2.5)
		_notes.clear()


func _try_clips() -> void:
	if _clip_path == "" or not ResourceLoader.exists(_clip_path):
		return
	var st := ResourceLoader.load_threaded_get_status(_clip_path)
	if st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_clips = ResourceLoader.load_threaded_get(_clip_path) if st == ResourceLoader.THREAD_LOAD_LOADED else load(_clip_path)
		_refresh_models()


## The clips, loading them now if the background load is not done (the first draw).
func _need_clips() -> bool:
	if _clips == null and ResourceLoader.exists(_clip_path):
		_clips = ResourceLoader.load_threaded_get(_clip_path) as AnimationLibrary
		if _clips == null:
			_clips = load(_clip_path) as AnimationLibrary
		_refresh_models()
	return _clips != null


func _clip(key: String) -> Animation:
	if _clips == null:
		return null
	var nm := String(data.clips.get(key, key))
	return _clips.get_animation(nm) if _clips.has_animation(nm) else null


func _read_keys() -> void:
	if player.is_dead or player.riding != null:
		return
	var ctl := player.controls
	var cyc := ctl.pressed(CYCLE_ACTION)
	if cyc and not bool(_was_keys.get("_cycle", false)):
		tools_cycle()
	_was_keys["_cycle"] = cyc
	var cl := ctl.pressed(CLUB_ACTION)
	if cl and not bool(_was_keys.get("_club", false)):
		club_toggle()
	_was_keys["_club"] = cl
	for kind: String in ACTIONS:
		var down := ctl.pressed(ACTIONS[kind])
		if down and not bool(_was_keys.get(kind, false)) and Hotbar.allows_tool_of(player, kind):
			toggle(kind)          # (a remapped tool key: the hotbar's tools only, Hotbar)
		_was_keys[kind] = down


## The one tool button: the next tool the player owns after the one in the hand (felling axe -> mattock), or put
## away after the last.
func tools_cycle() -> void:
	var owned: Array = []
	for k: String in ORDER:
		if data.is_tool(k) and owns(k) and Hotbar.allows_tool_of(player, k):     # (the hotbar's tools only: Hotbar)
			owned.append(k)
	if owned.is_empty():
		return
	var cur := tool if phase in [Phase.DRAW_GRAB, Phase.DRAW_OUT, Phase.READY, Phase.SWING] else ""
	var i := owned.find(cur)
	if i == owned.size() - 1:
		put_away()
	else:
		take_out(owned[i + 1])


## Middle mouse: the long gun out turned into a club, or back to shoot.
func club_toggle() -> void:
	if tool == CLUB:
		if _club_to > 0.0:
			unclub()
		return
	if can_club():
		club()


## Whether the weapon out can be turned into a club now: a long gun in the hands, not being aimed, fired, reloaded
## or drawn, and no tool out.
func can_club() -> bool:
	var w := player.weapon
	if tool != "" or w == null or not (player.weapon_key in CLUB_WEAPONS) or player.hands_free or not w.active \
			or w.model == null or player.is_switching() or player.is_dead or player.riding != null \
			or player.get("climbing") == true or not _need_clips():
		return false
	if w is Firearm:
		return (w as Firearm).state in [Firearm.State.READY, Firearm.State.EMPTY]
	return false


## Turns the gun out into a club (the flip over FLIP_S: the copy starts where the gun is in the hand).
func club() -> void:
	_club_key = player.weapon_key
	player.weapon.clubbed = true
	tool = CLUB
	phase = Phase.READY
	_carry_w = 1.0
	_club_to = 1.0
	_club_flip = 0.0
	_club_start = two_hand_offset(CLUB).affine_inverse() * player.weapon.model.transform
	_refresh_models()
	if _model_hand:
		_model_hand.visible = true
	# (a draw just done may still have the sling rig's stand-in copy in a hand, the gun handed across: it is held
	# now, the copy gone; then the gun's own model hides for the club's)
	var rig = player.get("gear")
	if rig != null and rig.has_method(&"snap_held") and rig.has_method(&"item_for_key"):
		var id: String = rig.item_for_key(_club_key)
		if id != "":
			rig.snap_held(id)
			if rig.has_method(&"hold_elsewhere"):
				rig.hold_elsewhere(id, true)     # (and kept so, whatever its hand-offs do while clubbed)
	player.weapon.model.visible = false


## Turns it back to shoot (an attack playing is broken off; the flip back, then the gun is itself again).
func unclub() -> void:
	if tool != CLUB:
		return
	if not _swing.is_empty() and bool(_swing.get("melee", false)) and not bool(_swing.get("cancel", false)):
		_cancel_melee()
	_melee_next = ""
	_club_to = 0.0


## The club over: the gun back in the hand as itself (`show_gun`: it is still the weapon out), the tool gone.
func _club_end(show_gun: bool) -> void:
	var rig = player.get("gear")
	if rig != null and rig.has_method(&"hold_elsewhere") and rig.has_method(&"item_for_key") and _club_key != "":
		var id: String = rig.item_for_key(_club_key)
		if id != "":
			rig.hold_elsewhere(id, false)
	var w: Weapon = (player.weapons as Dictionary).get(_club_key) if player.get("weapons") != null else null
	if w:
		w.clubbed = false
		if show_gun and w.active and not player.hands_free and w.model:
			w.model.visible = true
	_club_key = ""
	_club_flip = 0.0
	_club_to = 0.0
	drop_now()


## A stroke or an attack is under way (the legs walk at Player.swing_walk_speed meanwhile).
func swinging() -> bool:
	return phase == Phase.SWING


## The tool in the hand now ("" none, or while it goes away).
func in_hand() -> String:
	return tool if phase in [Phase.DRAW_GRAB, Phase.DRAW_OUT, Phase.READY, Phase.SWING] else ""


## Takes out `kind` (putting away what is in the hand first), or puts it away when it is out.
func toggle(kind: String) -> void:
	if not data.is_tool(kind) or not owns(kind):
		return
	if tool == kind and phase in [Phase.DRAW_GRAB, Phase.DRAW_OUT, Phase.READY, Phase.SWING]:
		put_away()
		return
	take_out(kind)


## Takes out `kind`; `stroke`: one stroke as soon as it is out (E at a target).
func take_out(kind: String, stroke := false) -> void:
	if player.is_dead or player.riding != null or not owns(kind) or not _need_clips():
		return
	if tool != "" and phase != Phase.IDLE:
		if tool == kind:
			return
		_pending = kind
		_pending_stroke = stroke
		put_away()
		return
	tool = kind
	_auto_stroke = stroke
	_refresh_models()
	if _torch_held():
		player.torch.drop("reload")   # the gentle toss: down beside the work, still burning
		phase = Phase.HOLSTER
		_t = 0.0
		if not player.hands_free and not player.is_switching():
			player.toggle_hands_free()
		return
	if not player.hands_free:
		if player.is_switching():
			phase = Phase.HOLSTER
			_t = 0.0
			return
		player.toggle_hands_free()
		phase = Phase.HOLSTER
		_t = 0.0
		return
	_begin_draw()


func put_away() -> void:
	if tool == CLUB:
		unclub()           # (the gun is turned back, not stowed: it stays the weapon out)
		return
	if tool == "" or phase in [Phase.IDLE, Phase.STOW_BACK, Phase.STOW_PLACE, Phase.HOLSTER]:
		if phase == Phase.HOLSTER:
			phase = Phase.IDLE
			tool = ""
		return
	_swing = {}
	_prev_swing = {}
	_queued = 0
	if phase in [Phase.DRAW_GRAB]:
		# the hand never reached it: back down from as far up as it got (the stow's place-to-idle mirrors the reach)
		var reach := _clip("draw_grab")
		var sp := _clip("stow_place")
		var frac := clampf(_t / reach.length, 0.0, 1.0) if reach else 1.0
		phase = Phase.STOW_PLACE
		_t = sp.length * (1.0 - frac) if sp else 0.0
		_show_hand(false)
		return
	phase = Phase.STOW_BACK
	var out := _clip("draw_out")
	_t = out.length if out else 0.0
	_w = maxf(_w, _carry_w)
	_carry_w = 0.0


func _begin_draw() -> void:
	phase = Phase.DRAW_GRAB
	_t = 0.0
	_w = 0.0


## The tool in the hand is lost (knocked out of it: PlayerRagdoll): the hand empties and the player no longer has it
## (off the loop, or one out of the pack) until it is found again (found()). Its kind ("" when none was in the hand).
func lose_in_hand() -> String:
	var kind := in_hand()
	if kind == "":
		return ""
	if kind == CLUB:
		# the club is the gun: it is the gun again in the hand, and whether that flies is the weapon's own chance
		# (PlayerRagdoll.knock)
		_club_end(true)
		return ""
	drop_now()
	if on_loop == kind and player.loadout:
		var it := player.loadout.first_of_kind(kind)
		if not it.is_empty():
			player.loadout.remove_item(String(it.id))
		_read_loop()
	else:
		var inv := InventoryState.from_player(player)
		inv.take(kind, 1)
		player.inventory_pack = inv.pack.duplicate(true)
	lost[kind] = true
	_refresh_models()
	return kind


## A lost tool picked up again (DroppedItem: it is in the pack now).
func found(kind: String) -> void:
	lost.erase(kind)


## Drops the tool at once (a weapon drawn, mounting, death): the hand empties, the tool is back on the loop.
func drop_now() -> void:
	tool = ""
	phase = Phase.IDLE
	_swing = {}
	_prev_swing = {}
	_w = 0.0
	_carry_w = 0.0
	_pipe_w = 0.0
	_queued = 0
	_auto_stroke = false
	_pending = ""
	_show_hand(false)
	if pose:
		pose.layers = []


func _guard() -> void:
	if tool == "":
		return
	if tool == CLUB:
		# the gun put away or switched, mounting, death: the club goes with it at once
		if player.is_dead or player.riding != null or player.hands_free or player.weapon_key != _club_key \
				or player.weapon == null or not player.weapon.active:
			_club_end(false)
		return
	var gone := player.is_dead or player.riding != null
	# a weapon drawn (a weapon key, H) while the tool is out: the tool goes back
	if not gone and phase != Phase.HOLSTER and not player.hands_free:
		gone = true
	if gone:
		drop_now()
		return
	# a torch into a hand (T, E on a dropped one): the tool goes back over the shoulder
	if _torch_held() and phase in [Phase.DRAW_GRAB, Phase.DRAW_OUT, Phase.READY, Phase.SWING]:
		put_away()


## A torch is in a hand (PlayerTorch; also while it is being tossed).
func _torch_held() -> bool:
	return player.torch != null and player.torch.holding()


func _step(delta: float) -> void:
	var trav := player.traversal != null and player.traversal.showing
	# LMB with the felling axe and nothing to fell or buck in front: an attack (AxeMelee), in the way the move keys say
	if tool == CLUB:
		_club_flip = move_toward(_club_flip, _club_to, delta / FLIP_S)
		if _club_to <= 0.0 and _club_flip <= 0.0:
			_club_end(true)
			return
	if melee != null:
		melee.tick(delta)
	# (struck a moment ago: the flinch, no attack; AxeMelee._on_hurt)
	# LMB attacks as the move keys say, RMB the reverse of it (user 2026-10-03: "right click is the reverse attack",
	# every melee weapon: AxeMelee.REVERSE)
	var lmb := melee != null and melee.pressed(_fire_held())
	var rmb := melee != null and melee.alt_pressed()
	var can_attack := melee != null and tool in MELEE_TOOLS and not _valid_for_tool() \
			and (tool != CLUB or _club_to > 0.0 and _club_flip >= 0.8) and not melee.flinching()
	# no attack is a lock (user 2026-09-27: "make sure none of the attacks are on a animation lock", "be able to move
	# ... right click to cancel", "juke move like in jedi academy"): the body moves as ever under the swing, and the
	# other button (2026-10-03: RMB breaks off a LMB attack, LMB a RMB one), a jump or a sprint breaks it off at once (a
	# feint); the next attack can begin straight away (a feint costs stamina: too little, the attack goes on: AxeMelee.pay)
	var swinging := phase == Phase.SWING and bool(_swing.get("melee", false)) and not bool(_swing.get("cancel", false))
	var btn := String(_swing.get("button", "L"))
	var feinted := false
	if swinging and melee.cancel_asked(btn) and melee.pay("feint"):
		_cancel_melee()
		feinted = true
	# (the press that broke an attack off begins nothing; during an attack only its own button chains the next)
	var press := ""
	if can_attack and not feinted:
		if lmb and (not swinging or btn == "L"):
			press = "L"
		elif rmb and (not swinging or btn == "R"):
			press = "R"
	var attack := press != ""
	var attack_dir := ""
	if attack:
		attack_dir = melee.direction() if press == "L" else AxeMelee.reverse_of(melee.direction())
	if attack and phase == Phase.SWING:
		# (broken off, or stopped by what it met and done holding there: the next begins at once)
		if bool(_swing.get("cancel", false)) or bool(_swing.get("free", false)):
			_start_melee(attack_dir, press)
		else:
			_melee_next = attack_dir
			_melee_next_button = press
	match phase:
		Phase.HOLSTER:
			_t += delta
			if _torch_held():
				if _t > 2.0:
					drop_now()   # the torch would not leave the hand
			elif _t >= HOLSTER_S and not player.is_switching():
				if not player.hands_free:
					player.toggle_hands_free()
				if player.hands_free:
					_begin_draw()
				elif _t > 2.0:
					drop_now()   # the weapon would not go away (nothing to do but give up)
		Phase.DRAW_GRAB:
			var a := _clip("draw_grab")
			_w = move_toward(_w, 1.0, delta / FADE_IN_S)
			_t += delta * DRAW_RATE * skills.speed(SKILL_OF[tool])
			if a == null or _t >= a.length:
				_show_hand(true)
				phase = Phase.DRAW_OUT
				_t = 0.0
		Phase.DRAW_OUT:
			var a := _clip("draw_out")
			_w = 1.0
			_t += delta * DRAW_RATE * skills.speed(SKILL_OF[tool])
			if a == null or _t >= a.length:
				phase = Phase.READY
				_carry_w = 1.0
				_w = 0.0
				if _auto_stroke:
					_auto_stroke = false
					_queued = 1
		Phase.READY:
			_carry_w = 1.0
			if trav:
				return
			if _wants_stroke():
				_start_swing()
			elif attack:
				_start_melee(attack_dir, press)
		Phase.SWING:
			_carry_w = 1.0
			_advance_swing(delta, trav)
		Phase.STOW_BACK:
			var a := _clip("draw_out")
			_t -= delta * STOW_RATE * skills.speed(SKILL_OF.get(tool, "woodcutting"))
			_pipe_w = move_toward(_pipe_w, 0.0, delta / FADE_OUT_S)
			if a == null or _t <= 0.0:
				_show_hand(false)
				phase = Phase.STOW_PLACE
				_t = 0.0
		Phase.STOW_PLACE:
			var a := _clip("stow_place")
			_t += delta * STOW_RATE
			var left := (a.length - _t) if a else 0.0
			_w = clampf(left / 0.15, 0.0, 1.0)
			if a == null or _t >= a.length:
				_w = 0.0
				phase = Phase.IDLE
				tool = ""
				if _pending != "":
					var k := _pending
					_pending = ""
					take_out(k, _pending_stroke)


func _wants_stroke() -> bool:
	if _queued > 0:
		_queued -= 1
		return _valid_for_tool()
	return _fire_held() and _valid_for_tool()


func _fire_held() -> bool:
	if not player.controls.from_input:
		return player.controls.pressed(&"fire")       # (driven by an AI or the network: no mouse to capture)
	if not InputMap.has_action(&"fire"):
		return false
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or player.ignore_mouse_capture
	return captured and Input.is_action_pressed(&"fire")


func _valid_for_tool() -> bool:
	return not target.is_empty() and tool != "" and String(target.type) in WORKS.get(tool, [])


# --- Swings --------------------------------------------------------------------------------------------

## Starts a stroke at `target` (`force`: that swing, "side" or "chop", whatever the target; the pose shots).
func _start_swing(force := "") -> void:
	var name := force if force != "" else String(SWING_OF.get(String(target.type), "side"))
	# (a piece of wall low down is chopped at like a log on the ground)
	if force == "" and String(target.get("type", "")) == "wall" \
			and (target.get("point", Vector3.ZERO) as Vector3).y - player.global_position.y < 0.8:
		name = "chop"
	var spec: Dictionary = data.clips.get("swings", {}).get(name, {})
	var intro := _clips.get_animation(String(spec.get("intro", ""))) if _clips else null
	var hit := _clips.get_animation(String(spec.get("hit", ""))) if _clips else null
	if intro == null or hit == null:
		# no clips (a stripped build): the stroke still lands
		_impact(target.duplicate())
		return
	if not _swing.is_empty():
		_prev_swing = _swing
	_swing = {"name": name, "intro": intro, "hit": hit, "u": 0.0, "w": 0.0,
			"impact": intro.length + float(spec.get("impact_s", 0.05)),
			"chain": intro.length + float(spec.get("chain_s", 0.35)),
			"end": intro.length + float(spec.get("end_s", 0.9)), "done": false, "target": target.duplicate(),
			"rate": skills.speed(SKILL_OF[tool])}
	phase = Phase.SWING


## Breaks the attack off: it fades out fast and strikes nothing more.
func _cancel_melee() -> void:
	var s := _swing
	s["cancel"] = true
	s["damage"] = 0.0
	s["fading"] = true
	s["fade_s"] = AxeMelee.CANCEL_FADE_S
	_melee_next = ""


## An attack (AxeMelee) in `dir`: its clips as a swing, chained over the one playing; `button` the mouse button that
## began it ("L", "R": the other one breaks it off).
func _start_melee(dir: String, button := "L") -> void:
	# (too tired for it: nothing begins; AxeMelee.pay)
	if not melee.can_pay(dir):
		_melee_next = ""
		return
	var s := melee.make_swing(dir, _clips)
	if s.is_empty():
		return
	s["button"] = button
	melee.pay(dir)
	if not _swing.is_empty():
		if not _prev_swing.is_empty() and bool(_prev_swing.get("melee", false)):
			melee.finish(_prev_swing)
		_prev_swing = _swing
	_swing = s
	_melee_next = ""
	phase = Phase.SWING


func _advance_swing(delta: float, trav: bool) -> void:
	if _swing.is_empty():
		phase = Phase.READY
		return
	var s := _swing
	var rate := float(s.rate)
	s.u = float(s.u) + delta * rate
	if bool(s.get("melee", false)):
		melee.step(s, delta)
		if _melee_next != "" and (float(s.u) >= float(s.chain) or bool(s.get("free", false))) and not trav:
			_start_melee(_melee_next, _melee_next_button)
			return
	var fade_in := FADE_IN_S if _prev_swing.is_empty() else CHAIN_FADE_S
	s.w = move_toward(float(s.w), 0.0 if trav else 1.0, delta / fade_in)
	if not _prev_swing.is_empty():
		_prev_swing.u = float(_prev_swing.u) + delta * float(_prev_swing.rate)
		if float(s.w) >= 1.0:
			_prev_swing = {}
	if not bool(s.done) and float(s.u) >= float(s.impact):
		s.done = true
		if not trav:
			_impact(s.target)
	if float(s.u) >= float(s.chain) and bool(s.done) and not trav:
		if (_queued > 0 or _fire_held()) and _valid_for_tool():
			if _queued > 0:
				_queued -= 1
			_start_swing()
			return
	if float(s.u) >= float(s.end):
		# recover: the swing fades back to the carry while its clip plays on
		s.fading = true
	if bool(s.get("fading", false)):
		s.w2 = move_toward(float(s.get("w2", 1.0)), 0.0, delta / float(s.get("fade_s", FADE_OUT_S)))
		if float(s.w2) <= 0.0:
			if bool(s.get("melee", false)):
				melee.finish(s)
			if not _prev_swing.is_empty() and bool(_prev_swing.get("melee", false)):
				melee.finish(_prev_swing)
			_swing = {}
			_prev_swing = {}
			phase = Phase.READY


func _swing_clip(s: Dictionary) -> Array:
	var intro: Animation = s.intro
	var u := float(s.u)
	if u < intro.length:
		return [intro, u]
	var hit: Animation = s.hit
	return [hit, minf(u - intro.length, hit.length)]


func _apply_layers() -> void:
	var layers: Array = []
	var carry := _clip("carry")
	var guard_w := 0.0
	if tool == CLUB:
		# the club's two-handed guard, in as the gun turns
		var g := melee.guard() if melee else []
		guard_w = smoothstep(0.0, 1.0, _club_flip)
		if not g.is_empty() and guard_w > 0.0:
			layers.append({"anim": g[0], "time": g[1], "weight": guard_w, "mask": "upper"})
	elif carry and _carry_w > 0.0:
		layers.append({"anim": carry, "time": carry.length, "weight": _carry_w, "mask": "arm_r"})
	match phase:
		Phase.DRAW_GRAB:
			layers.append({"anim": _clip("draw_grab"), "time": _t, "weight": smoothstep(0.0, 1.0, _w), "mask": "arm_r"})
		Phase.DRAW_OUT, Phase.STOW_BACK:
			layers.append({"anim": _clip("draw_out"), "time": _t, "weight": smoothstep(0.0, 1.0, _w), "mask": "arm_r"})
		Phase.STOW_PLACE:
			layers.append({"anim": _clip("stow_place"), "time": _t, "weight": smoothstep(0.0, 1.0, _w), "mask": "arm_r"})
	# the swings are upper body only, standing too (user 2026-09-30: felling and combat "lock it to the torso like aim down
	# sights, lower half body"): the legs keep the locomotion, at the swing walk pace (Player.swing_walk_speed), as
	# aiming a gun does
	var still := false
	var mask := "upper"
	var pw := 0.0
	var bw := 0.0                  ## (the club: how much a one-handed attack holds it in the blade frame)
	# the saber is one-handed (user 2026-10-01): the axe's two-handed swings drive the right arm and the body, not the left arm
	var one_hand := tool in ONE_HANDED
	# the swing fading out under a chained one stays at full weight; the new one fades in over it
	for pair: Array in [[_prev_swing, true], [_swing, false]]:
		var s: Dictionary = pair[0]
		if s.is_empty():
			continue
		var w := float(s.get("w2", 1.0)) * (1.0 if bool(pair[1]) else smoothstep(0.0, 1.0, float(s.w)))
		var cl := _swing_clip(s)
		if bool(s.get("melee", false)):
			# an attack: the upper body swings; the legs take its footwork only standing, eased in and out as the
			# player stops and moves (no pop when a juke starts mid-swing)
			var sw := move_toward(float(s.get("still_w", 1.0 if still else 0.0)), 1.0 if still else 0.0,
					get_physics_process_delta_time() / 0.2)
			s["still_w"] = sw
			layers.append({"anim": cl[0], "time": cl[1], "weight": w, "mask": "upper_one_hand" if one_hand else "upper"})
			if sw > 0.0:
				layers.append({"anim": cl[0], "time": cl[1], "weight": w * sw, "mask": "full_one_hand" if one_hand else "full"})
		else:
			layers.append({"anim": cl[0], "time": cl[1], "weight": w, "mask": "upper_one_hand" if one_hand else mask})
		# (a one-handed attack's clip holds the tool in the blade frame)
		var pipe := 0.0 if str(s.get("frame", "pipe")) == "blade" else 1.0
		pw = 1.0 - (1.0 - pw) * (1.0 - w * pipe)
		bw = 1.0 - (1.0 - bw) * (1.0 - w * (1.0 - pipe))
	# the right hand's fist on the tool, eased off its clip (HeldFist.CURL; user 2026-10-03, "how come the knuckles look
	# crazy": closed all the way the knuckles' skin pinched): over the carry, and for a one-handed grip through the swings
	# too (the hand holding the grip throughout the motion: the carry's fingers over whatever the swing's clips do)
	if carry and tool != CLUB:
		var fw := _carry_w if not one_hand else maxf(_carry_w, maxf(pw, bw))
		if fw > 0.0:
			layers.append({"anim": carry, "time": carry.length, "weight": fw, "mask": "fingers_r", "curl": HeldFist.CURL})
	if tool == CLUB:
		pw = 1.0 - bw                # (the club is two-handed but in a one-handed attack)
	if phase != Phase.STOW_BACK:
		_pipe_w = pw
	pose.layers = layers
	# the saber's high block across to the left (turn_blade): the right hand reversed as an IK target, the blade level
	# across to the left, the grip seated in the fist as ever (user 2026-10-03: "just reverse the hand right on IK";
	# turning the blade in the fist instead left the fingers mangled)
	pose.hand_reverse = _blade_turn()
	_place_hand_model()


# --- Impacts ---------------------------------------------------------------------------------------------

## A stroke lands on `t` (the target as it was when the swing began, checked again now).
func _impact(t: Dictionary) -> void:
	var cur := _refresh(t)
	if cur.is_empty():
		return
	var sk := String(SKILL_OF[tool])
	var mult := stroke_mult(tool)
	var power := skills.power(sk) * mult
	var point: Vector3 = cur.get("point", cur.pos)
	var normal: Vector3 = cur.get("normal", Vector3.UP)
	var scene := get_tree().current_scene
	match String(cur.type):
		"tree":
			var key := "tree:%d" % int(cur.i)
			var need := strokes_to_fell(cur)
			_work[key] = float(_work.get(key, 0.0)) + power
			skills.award(sk, skills.xp(sk, "stroke"))
			_cut[key] = point.y          # (the height of the last stroke: the cut, CUT_REACH)
			GatherFx.wood_chips(scene, point, normal)
			_rec_or(GatherSfx.chop(point, 2.0 * float(cur.get("radius", 0.3))), "axe_chop", point, 0.0, &"ball_hit_wood")
			if float(_work[key]) >= need:
				_fell(cur)
		"stump":
			var sk_key := "stump:%d" % int(cur.i)
			_work[sk_key] = float(_work.get(sk_key, 0.0)) + power
			skills.award(sk, skills.xp(sk, "stroke"))
			GatherFx.wood_chips(scene, point, normal)
			_rec_or(GatherSfx.chop(point, 2.0 * float(cur.get("radius", 0.3))), "axe_chop", point, 0.0, &"ball_hit_wood")
			if float(_work[sk_key]) >= stump_work(cur):
				_work.erase(sk_key)
				remove_stump(int(cur.i), true)
				target = {}
		"sapling":
			var key := "sap:%s:%d" % [cur.src, int(cur.i)]
			_work[key] = float(_work.get(key, 0.0)) + mult
			GatherFx.wood_chips(scene, point, normal, 6)
			_rec_or(GatherSfx.sapling(point), "axe_buck", point, -4.0, &"arrow_hit_wood")
			if float(_work[key]) >= float(sapling_strokes()):
				harvest.remove_sapling(String(cur.src), int(cur.i))
				NetSession.world_event(get_tree(), "sapling", {"src": String(cur.src), "i": int(cur.i)})   # (the others' too)
				_work.erase(key)
				var y: Dictionary = data.saplings.get("yield", {})
				for item: String in y:
					give(item, int(y[item]))
				skills.award(sk, skills.xp(sk, "sapling"))
		"trunk":
			var ft: FelledTree = cur.felled
			var res := ft.buck(power)
			skills.award(sk, skills.xp(sk, "stroke"))
			GatherFx.wood_chips(scene, point, normal)
			_rec_or(GatherSfx.buck(point, 2.0 * float(ft.info.get("radius", 0.25))), "axe_buck", point, 0.0, &"ball_hit_wood")
			var cut: Array = res.get("cut_off", [])
			if not cut.is_empty():
				# a limbed trunk: the length lies there as its own log
				skills.award(sk, skills.xp(sk, "log") * cut.size())
				_note("A log bucked off the %s: about %d kg" % [ft.species_name(), roundi((cut[-1] as SkidLoad).mass_kg)])
				target = {}
			var logs := 0
			var split := 0
			for n in int(res.logs):
				# the butt log (the first length off) is the best of the tree; the rest may split or check
				if ft.logs_total - ft.logs_left - int(res.logs) + n == 0 or rng.randf() < log_quality():
					logs += 1
				else:
					split += 1
			if logs > 0:
				give("log", logs)
				skills.award(sk, skills.xp(sk, "log") * logs)
			if split > 0:
				give("firewood", split * 2)
			if bool(res.limbed):
				var cy := ft.crown_yield()
				for item: String in cy:
					give(item, int(cy[item]))
				skills.award(sk, skills.xp(sk, "limbed"))
				target = {}
		"crown":
			var ft: FelledTree = cur.felled
			var key := "limb:%d" % ft.get_instance_id()
			_work[key] = float(_work.get(key, 0.0)) + power
			skills.award(sk, skills.xp(sk, "stroke"))
			GatherFx.wood_chips(scene, point, normal, 8)
			_rec_or(GatherSfx.sapling(point), "axe_buck", point, -2.0, &"arrow_hit_wood")
			if float(_work[key]) >= limb_work(ft):
				_work.erase(key)
				limb(ft)
		"rock":
			_break_stone(cur, power, point, normal)
		"ground":
			_work_ground(cur, power, point, normal)
		"carcass":
			var wn: Variant = cur.get("work")
			if wn is Node and is_instance_valid(wn):
				skills.award(sk, skills.xp(sk, "stroke"))
				MeleeSweep.crunch("flesh", point)
				var sp := scene.get_node_or_null(^"Wildlife") if scene else null
				if sp and sp.has_method(&"blood_splash"):
					sp.call(&"blood_splash", point, -normal)
				if float((wn as Node).call(&"axe_strike", cur, power)) >= 1.0:
					target = {}
		"wall":
			var bw := BuildWorld.of(get_tree(), false)
			if bw:
				skills.award(sk, skills.xp(sk, "stroke"))
				GatherFx.wood_chips(scene, point, normal)
				_rec_or(GatherSfx.chop(point, 0.4), "axe_chop", point, 0.0, &"ball_hit_wood")
				if PalisadeCuts.strike(bw, cur, power) >= 1.0:
					GatherFx.wood_chips(scene, point, normal, 28)
					_rec_or(GatherSfx.buck(point, 0.4), "axe_buck", point, 2.0, &"ball_hit_wood")
					give("firewood", 2)
					_note("A piece of the %s is chopped out" % String(cur.get("name", "palisade")))
					target = {}
	stroke_landed.emit(String(cur.type), cur)


## A stroke of the hoe at a bed or open ground (FarmField.strike): ground broken, a bed worked, weeds hoed out.
func _work_ground(cur: Dictionary, power: float, point: Vector3, normal: Vector3) -> void:
	var farm := FarmField.find(get_tree())
	if farm == null:
		return
	var res := farm.strike(String(cur.key), power)
	var ev := String(res.get("event", ""))
	var sk := "husbandry"
	match ev:
		"frozen":
			_note("The ground is frozen hard: nothing grows till spring")
			target = {}
			return
		"blocked":
			_note("No room for a bed here: roots, rock, water or a building")
			target = {}
			return
		"":
			return
	GatherFx.soil(get_tree().current_scene, point, normal)
	_sound("hoe", point, -3.0, &"arrow_hit_wood")
	skills.award(sk, skills.xp(sk, "stroke"))
	if ev == "tilled":
		skills.award(sk, skills.xp(sk, "tilled"))
		_note("The bed is worked: sow it (E)")
		target = {}
	elif ev == "weeded":
		skills.award(sk, skills.xp(sk, "weeded"))
		_note("Weeds hoed out")
		target = {}


func _break_stone(cur: Dictionary, power: float, point: Vector3, normal: Vector3) -> void:
	var i := int(cur.i)
	var st := rock_state(i)
	var rk := String(cur.get("name", ""))
	var info: Dictionary = data.rocks.get("kinds", {}).get(rk, {})
	var per := float(data.rocks.get("strikes_ref", 2.6)) * float(info.get("hardness", 1.0))
	st.work = float(st.work) + power
	skills.award("mining", skills.xp("mining", "strike"))
	GatherFx.stone_chips(get_tree().current_scene, point, normal)
	_rec_or(GatherSfx.mining_strike(point, power), "mattock_stone", point, -2.0, &"ball_hit_stone")
	var stones := 0
	var flint := 0
	while float(st.work) >= per and int(st.left) > 0:
		st.work = float(st.work) - per
		st.left = int(st.left) - 1
		stones += 1
		# a skilled hand gets a second piece now and then
		if rng.randf() < 0.35 * skills.yield_bonus("mining"):
			stones += 1
		var fc := float(info.get("flint", 0.0))
		if fc > 0.0 and rng.randf() < fc + float(data.rocks.get("flint_skill_add", 0.12)) * skills.yield_bonus("mining"):
			flint += 1
	if stones > 0:
		# a piece breaks off (the last one: the outcrop gives way)
		GatherSfx.stone_breaks(point, int(st.left) <= 0)
		give("stone", stones)
		skills.award("mining", skills.xp("mining", "stone") * stones)
	if flint > 0:
		give("flint", flint)
		skills.award("mining", skills.xp("mining", "flint") * flint)
	if stones > 0:
		var frac := float(st.left) / maxf(float(st.total), 1.0)
		if int(st.left) <= 0:
			harvest.shrink_rock(i, 0.0)
			NetSession.world_event(get_tree(), "rock", {"i": i, "f": 0.0})
			skills.award("mining", skills.xp("mining", "exhausted"))
			_note("Nothing left of the %s" % String(info.get("name", "rock")))
			target = {}
		else:
			var ms := float(data.rocks.get("min_scale", 0.4))
			harvest.shrink_rock(i, lerpf(ms, 1.0, pow(frac, 1.0 / 3.0)))
			NetSession.world_event(get_tree(), "rock", {"i": i, "f": float(harvest.rock_size.get(i, 1.0))})


## A rock's quarrying state: {total stones, left, work into the next}.
func rock_state(i: int) -> Dictionary:
	if not _rock.has(i):
		var d := harvest.describe("rock", "prop", i) if harvest else {}
		var sz: Vector3 = d.get("size", Vector3.ONE)
		var vol := sz.x * sz.y * sz.z * 0.5
		var n := clampi(roundi(vol / float(data.rocks.get("stone_volume_m3", 0.14))), int(data.rocks.get("min_stones", 2)),
				int(data.rocks.get("max_stones", 24)))
		_rock[i] = {"total": n, "left": n, "work": 0.0}
	return _rock[i]


## The tree comes down: its instances and collider go (VegHarvest), a FelledTree topples away from the player,
## a stump stays.
func _fell(cur: Dictionary) -> void:
	var key := "tree:%d" % int(cur.i)
	fell_tree(int(cur.i), player.global_position, player.global_basis.z * -1.0, true, float(_cut.get(key, INF)))
	_cut.erase(key)


## Tree `i` comes down away from `from` (where the feller stands; `ahead` when they stand on it): its instances and collider go
## (VegHarvest), a FelledTree topples, a stump stays. `award` is the player's own felling (his woodcutting grows, he is told);
## a worker's (RtsFell) is not. Returns the felled tree (null: it was gone already).
func fell_tree(i: int, from: Vector3, ahead := Vector3.FORWARD, award := false, cut_y := INF, fall := Vector3.ZERO) -> FelledTree:
	var d := harvest.remove_tree(i)
	if d.is_empty():
		return null
	# the cut where the strokes went in (`cut_y`, world): the stump that tall, the tree that much shorter; else the usual stump
	var cfg: Dictionary = data.felling.duplicate()
	if cut_y != INF:
		cfg["stump_height_m"] = clampf(cut_y - float(d.pos.y), 0.15, 2.4)
	_work.erase("tree:%d" % i)
	var sp: Dictionary = data.species.get(String(d.species), {})
	d["name"] = String(sp.get("name", String(d.species).replace("_", " ")))
	var away := Vector3(d.pos.x - from.x, 0.0, d.pos.z - from.z)
	if away.length() < 0.05:
		away = ahead
	away = away.normalized()
	if fall != Vector3.ZERO:
		away = fall           # (the way it fell on the feller's machine: the same for everyone)
	else:
		var safe := String(skills.tier("woodcutting").id) != "novice"
		var scatter := float(data.felling.get("scatter_deg_safe" if safe else "scatter_deg_novice", 30.0))
		away = away.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-scatter, scatter)))
	# (the others see it come down too, the same way: NetSession)
	NetSession.world_event(get_tree(), "fell", {"i": i, "from": from, "ahead": ahead, "cut": cut_y, "dir": away})
	var visuals := DisplayServer.get_name() != "headless"
	var ft := FelledTree.create(d, away, cfg, visuals)
	var scene := get_tree().current_scene
	scene.add_child(ft)
	ft.landed.connect(_on_tree_landed)
	# the hinge cracks now; the crown's swish is started so its peak meets the ground
	var fall_id := GatherSfx.tree_falls(ft.hinge, ft.fall_dir, ft.length, GatherSfx.fall_time(ft.length, data.felling))
	if not Sfx.has(fall_id):
		ft.landing_soon.connect(func(f: FelledTree) -> void: _sound("tree_fall", f.hinge + f.axis() * f.length * 0.5, 6.0, &"land_dirt"))
		_sound("tree_crack", d.pos + Vector3.UP * 1.5, 2.0, &"land_wood")
	harvest.stump_h[i] = float(cfg.get("stump_height_m", 0.45))
	var stump := FelledTree.make_stump(d, float(cfg.get("stump_height_m", 0.45)), visuals)
	scene.add_child(stump)
	if award:
		var diam := 2.0 * float(d.radius)
		var sk := "woodcutting"
		skills.award(sk, maxf(skills.xp(sk, "felled_per_m") * diam, skills.xp(sk, "felled_min")))
		_note("The %s comes down" % d.name)
		target = {}
	felled.emit(ft)
	return ft


func _on_tree_landed(ft: FelledTree) -> void:
	var p := ft.hinge + ft.axis() * ft.length * 0.6
	GatherFx.fall_dust(get_tree().current_scene, p, float(ft.info.get("crown_radius", 3.0)) * 0.6)
	GatherSfx.tree_lands(p, ft.length)


## Strokes of power 1 to fell a tree (gathering.json felling): the diameter's power law times the hardness.
func strokes_to_fell(d: Dictionary) -> float:
	var f := data.felling
	var diam := 2.0 * float(d.get("radius", 0.3))
	var sp: Dictionary = data.species.get(String(d.get("species", "")), {})
	return maxf(float(f.get("strokes_ref", 5.0)) * pow(diam / float(f.get("diameter_ref_m", 0.3)), float(f.get("exponent", 1.3)))
			* float(sp.get("hardness", 1.0)), 1.0)


func sapling_strokes() -> int:
	var s := data.saplings
	return int(s.get("strokes_skilled", 1)) if skills.level("woodcutting") >= int(s.get("skilled_level", 20)) \
			else int(s.get("strokes", 2))


## Stroke power to limb felled tree `ft` (gathering.json felling: limb_work_per_crown_m of its crown's spread).
func limb_work(ft: FelledTree) -> float:
	var f := data.felling
	return maxf(float(f.get("limb_work_min", 3.0)), float(ft.info.get("crown_radius", 3.0)) * float(f.get("limb_work_per_crown_m", 1.3)))


## How far `p` is from the reach of a felled tree's limbs (its crown's stem, less most of its spread; m, 0 inside).
func crown_distance(ft: FelledTree, p: Vector3) -> float:
	var cp := ft.crown_point(p)
	var spread := float(ft.info.get("crown_radius", 3.0)) * 0.6
	return maxf(Vector2(cp.x - p.x, cp.z - p.z).length() - spread, 0.0)


## Limbs felled tree `ft` where it lies: its crown's firewood and branches into the pack, the bare trunk (what is
## left of its clear bole) a log lying loose (SkidLoad). Returns the log.
func limb(ft: FelledTree) -> SkidLoad:
	if ft == null or not is_instance_valid(ft) or ft is SkidLoad or not ft.is_down():
		return null
	var visuals := DisplayServer.get_name() != "headless"
	var s := SkidLoad.from_felled(ft, HorseHaul.data(), float(data.felling.get("log_length_m", 2.4)), visuals)
	ft.get_parent().add_child(s)
	var cy := ft.crown_yield()
	for item: String in cy:
		give(item, int(cy[item]))
	skills.award("woodcutting", skills.xp("woodcutting", "limbed"))
	if visuals and is_inside_tree():
		GatherFx.wood_chips(get_tree().current_scene, ft.top(), Vector3.UP, 14)
	if target.get("felled") == ft:
		target = {}
	ft.queue_free()
	_note("The %s is limbed: a log of about %d kg" % [s.species_name(), roundi(s.mass_kg)])
	limbed.emit(s)
	return s


## The chance a bucked length comes off as a good log (the rest splits into firewood).
func log_quality() -> float:
	var q0 := float(data.felling.get("log_quality_novice", 0.7))
	return lerpf(q0, 1.0, skills.yield_bonus("woodcutting"))


# --- Targets ---------------------------------------------------------------------------------------------

func _find_target() -> void:
	if harvest == null:
		harvest = VegHarvest.find(get_tree())
	var p := player.global_position
	var view := _view_dir()
	var best := {}
	var best_s := INF
	var cands: Array = harvest.near(p, 2.2) if harvest else []
	for n in get_tree().get_nodes_in_group(FelledTree.GROUP):
		var ft := n as FelledTree
		if ft and ft.is_down() and ft.distance_from(p) < 2.2:
			var bp := ft.bole_point(p)
			cands.append({"type": "trunk", "src": "felled", "i": ft.get_instance_id(), "felled": ft, "pos": bp,
					"radius": float(ft.info.get("radius", 0.3)), "dist": ft.distance_from(p)})
		if ft and not (ft is SkidLoad) and ft.is_down():
			var cd := crown_distance(ft, p)
			if cd < 2.2:
				cands.append({"type": "crown", "src": "felled", "i": ft.get_instance_id(), "felled": ft,
						"pos": ft.crown_point(p), "radius": 0.15, "dist": cd})
	# A piece of a built palisade where the camera aims (PalisadeCuts: from belly height up, measured from the feet), with
	# the axe in the hand only (the wall is everywhere).
	if tool == "felling_axe" and in_hand() == "felling_axe":
		var bw := BuildWorld.of(get_tree(), false)
		var cam := player.get_viewport().get_camera_3d() if bw and player.is_inside_tree() else null
		if cam:
			var wcand := PalisadeCuts.aim(bw, cam.global_position, -cam.global_basis.z, p, [player.get_rid()])
			if not wcand.is_empty():
				cands.append(wcand)
	# a carcass butchered with the axe (group "axe_work": MammothButchery; user 2026-09-27: "use the axe to butcher"):
	# its parts in reach, the one the crosshair lands on first (its "aim")
	var awork := get_tree().get_nodes_in_group(&"axe_work")
	if not awork.is_empty() and player.is_inside_tree():
		var cam2 := player.get_viewport().get_camera_3d()
		var eye := cam2.global_position if cam2 else p + Vector3.UP * 1.6
		var look := -cam2.global_basis.z if cam2 else view
		for wn in awork:
			if wn.has_method(&"axe_candidates"):
				cands.append_array(wn.axe_candidates(p + Vector3.UP * 1.0, eye, look, [player.get_rid()]))
	# stumps (user 2026-10-01: "we need to be able to remove the tree stump"): chopped out with the axe or grubbed out with the mattock
	for sn in get_tree().get_nodes_in_group(FelledTree.STUMP_GROUP):
		var sb := sn as Node3D
		if sb == null or sb.is_queued_for_deletion():
			continue
		var sr := float(sb.get_meta(&"radius", 0.3))
		var sdist := Vector2(sb.global_position.x - p.x, sb.global_position.z - p.z).length() - sr
		if sdist < 2.0:
			cands.append({"type": "stump", "src": "stump", "i": int(sb.get_meta(&"tree_i", -1)), "node": sb,
					"pos": sb.global_position + Vector3.UP * minf(float(sb.get_meta(&"height", 0.45)) * 0.5, 0.6), "radius": sr, "dist": sdist,
					"species": String(sb.get_meta(&"species", "")), "height": float(sb.get_meta(&"height", 0.45))})
	# the ground the hoe works (farming, FarmField): beds that want breaking or weeding; open ground with the hoe out
	var farm := FarmField.find(get_tree())
	if farm and owns("hoe"):
		cands.append_array(farm.ground_candidates(p, view, in_hand() == "hoe"))
	for c0: Dictionary in cands:
		var c := c0
		var reach := _reach_of(String(c.type))
		if String(c.type) == "rock":
			c = _rock_contact(c)
			if c.is_empty():
				continue
		if float(c.dist) > reach:
			continue
		var to := Vector3(c.pos.x - p.x, 0.0, c.pos.z - p.z)
		var ang := 0.0
		if to.length() > 0.2:
			ang = rad_to_deg(view.angle_to(to.normalized()))
		if ang > VIEW_ANGLE_DEG:
			continue
		var sc := ang / VIEW_ANGLE_DEG + float(c.dist) / reach - float(c.get("aim", 0.0))
		if tool != "" and String(c.type) in WORKS.get(tool, []):
			sc -= 0.6
		if sc < best_s:
			best_s = sc
			best = c
	if not best.is_empty():
		_finish_target(best)
	target = best


func _reach_of(type: String) -> float:
	match type:
		"tree":
			return float(data.felling.get("reach_m", 1.55))
		"sapling":
			return float(data.saplings.get("reach_m", 1.35))
		"rock":
			return float(data.rocks.get("reach_m", 1.35))
		"trunk":
			return 1.6
		"crown":
			return 1.4
		"wall":
			return PalisadeCuts.REACH
		"carcass":
			return 2.4
		"ground":
			return 2.2
		"stump":
			return 1.5
	return 1.5


## A rock is in reach when a ray from the player's hips toward its middle hits its own collider close enough;
## the hit gives the stroke's point and normal. {} when not.
func _rock_contact(c: Dictionary) -> Dictionary:
	var p := player.global_position
	var from := p + Vector3.UP * 0.55
	var h := float(c.get("height", 1.0))
	var aim: Vector3 = c.pos + Vector3.UP * clampf(h * 0.45, 0.15, 0.9)
	var to := from + (aim - from).normalized() * 3.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		# a low rock under the ray: straight down onto it from in front
		return {}
	var col := hit.collider as Node
	if col == null or not col.is_in_group(&"rocks"):
		return {}
	var hp: Vector3 = hit.position
	if hp.distance_to(aim) > float(c.radius) + 1.2:
		return {}
	var out := c.duplicate()
	out["dist"] = Vector2(hp.x - p.x, hp.z - p.z).length() - 0.3
	out["point"] = hp
	out["normal"] = hit.normal
	return out


func _finish_target(c: Dictionary) -> void:
	var p := player.global_position
	match String(c.type):
		"stump":
			var sax: Vector3 = c.pos
			var sto := Vector3(p.x - sax.x, 0.0, p.z - sax.z)
			var sn2 := sto.normalized() if sto.length() > 1e-3 else -player.global_basis.z
			c["point"] = sax + sn2 * float(c.radius)
			c["normal"] = sn2
		"tree", "sapling", "trunk":
			var ax: Vector3 = c.pos
			var to := Vector3(p.x - ax.x, 0.0, p.z - ax.z)
			var n := to.normalized() if to.length() > 1e-3 else -player.global_basis.z
			var y := p.y + (0.95 if String(c.type) == "tree" else 0.6)
			if String(c.type) == "tree":
				y = _aim_height(ax, float(c.radius), p)   # (where the crosshair is on the trunk: the cut goes there)
			if String(c.type) == "trunk":
				var ft: FelledTree = c.felled
				y = ft.bole_point(p).y + 0.05
			c["point"] = Vector3(ax.x, y, ax.z) + n * float(c.radius)
			c["normal"] = n
		"crown":
			# the limbs on the near side of the stem, at about knee to hip height
			var ax: Vector3 = c.pos
			var to := Vector3(p.x - ax.x, 0.0, p.z - ax.z)
			var n := to.normalized() if to.length() > 1e-3 else -player.global_basis.z
			var reach := minf(to.length() * 0.6, 1.2)
			c["point"] = Vector3(ax.x, clampf(ax.y, p.y + 0.3, p.y + 1.0), ax.z) + n * reach
			c["normal"] = n
	var nm := ""
	match String(c.type):
		"tree":
			nm = String(data.species.get(String(c.species), {}).get("name", String(c.species).replace("_", " ")))
		"sapling":
			nm = String(data.saplings.get(String(c.species), {}).get("name", "sapling"))
		"trunk", "crown":
			nm = (c.felled as FelledTree).species_name()
		"rock":
			nm = String(data.rocks.get("kinds", {}).get(String(c.name), {}).get("name", "rock"))
		"wall":
			nm = String(c.get("name", "palisade"))
		"ground":
			nm = "ground"
		"carcass":
			nm = String(c.get("name", "carcass"))
			var to_p := p + Vector3.UP * 1.0 - (c.pos as Vector3)
			c["point"] = c.pos
			c["normal"] = to_p.normalized() if to_p.length() > 1e-3 else Vector3.UP
	c["name_disp"] = nm


## The target again, as it is now (gone, out of reach: {}).
func _refresh(t: Dictionary) -> Dictionary:
	if t.is_empty():
		return {}
	var p := player.global_position
	match String(t.type):
		"stump":
			var sn: Variant = t.get("node")
			if not (sn is Node3D) or not is_instance_valid(sn) or (sn as Node).is_queued_for_deletion():
				return {}
			var sb := sn as Node3D
			if Vector2(sb.global_position.x - p.x, sb.global_position.z - p.z).length() - float(t.radius) > _reach_of("stump") + 0.4:
				return {}
			var os := t.duplicate()
			_finish_target(os)
			return os
		"trunk":
			var ft: Variant = t.get("felled")
			if not (ft is FelledTree) or not is_instance_valid(ft) or not (ft as FelledTree).is_down():
				return {}
			if (ft as FelledTree).distance_from(p) > _reach_of("trunk") + 0.4:
				return {}
			var out := t.duplicate()
			out.pos = (ft as FelledTree).bole_point(p)
			_finish_target(out)
			return out
		"crown":
			var fc: Variant = t.get("felled")
			if not (fc is FelledTree) or not is_instance_valid(fc) or not (fc as FelledTree).is_down() or fc is SkidLoad:
				return {}
			var cd := crown_distance(fc, p)
			if cd > _reach_of("crown") + 0.4:
				return {}
			var oc := t.duplicate()
			oc.pos = (fc as FelledTree).crown_point(p)
			oc.dist = cd
			_finish_target(oc)
			return oc
		"carcass":
			var wn: Variant = t.get("work")
			if not (wn is Node) or not is_instance_valid(wn):
				return {}
			var dc: Dictionary = (wn as Node).call(&"axe_describe", String(t.key), p + Vector3.UP * 1.0)
			if dc.is_empty() or float(dc.dist) > _reach_of("carcass") + 0.4:
				return {}
			_finish_target(dc)
			return dc
		"wall":
			var dw := PalisadeCuts.describe(BuildWorld.of(get_tree(), false), String(t.key), p)
			if dw.is_empty() or float(dw.dist) > _reach_of("wall") + 0.4:
				return {}
			_finish_target(dw)
			return dw
		"ground":
			var fm := FarmField.find(get_tree())
			var dg := fm.describe(String(t.key), p) if fm else {}
			if dg.is_empty() or float(dg.dist) > _reach_of("ground") + 0.4:
				return {}
			if t.has("point") and bool(dg.get("fresh", false)):
				dg["point"] = t.point
			_finish_target(dg)
			return dg
		_:
			if harvest == null:
				return {}
			var d := harvest.describe(String(t.type), String(t.src), int(t.i))
			if d.is_empty():
				return {}
			d["dist"] = Vector2(d.pos.x - p.x, d.pos.z - p.z).length() - float(d.radius)
			if String(t.type) == "rock":
				d = _rock_contact(d)
				if d.is_empty():
					return {}
			if float(d.dist) > _reach_of(String(t.type)) + 0.4:
				return {}
			_finish_target(d)
			return d


func target_point() -> Vector3:
	if target.is_empty():
		return Vector3.INF
	return target.get("point", target.pos)


func _view_dir() -> Vector3:
	var cam := player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	var f := -cam.global_transform.basis.z if cam else -player.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 1e-4 else Vector3.FORWARD


## The tool a target needs.
static func tool_for(type: String) -> String:
	for k: String in WORKS:
		if type in WORKS[k]:
			return k
	return ""


## E at the target: the right tool out (if it is not in the hand) and one stroke.
func use_target() -> void:
	if target.is_empty() or player.is_dead or player.riding != null:
		return
	var need := tool_for(String(target.type))
	if need == "" or not owns(need):
		_note("You have no %s" % data.name_of(need).to_lower())
		return
	if not Hotbar.allows_tool_of(player, need):
		# (a tool off the hotbar is in the pack: only the bar's are taken out; Hotbar)
		_note("The %s is not on the hotbar: Tab, and drag it onto a slot" % data.name_of(need).to_lower())
		return
	if tool == need and phase in [Phase.READY, Phase.SWING]:
		_queued = mini(_queued + 1, 2)
		return
	take_out(need, true)


## The bottom prompt for the target ("" none).
func prompt() -> String:
	if target.is_empty() or player.riding != null:
		return ""
	var nm := String(target.get("name_disp", ""))
	match String(target.type):
		"tree":
			var need := strokes_to_fell(target)
			var done := float(_work.get("tree:%d" % int(target.i), 0.0))
			var pct := "" if done <= 0.0 else "  %d%%" % int(clampf(done / need, 0.0, 0.99) * 100.0)
			return "Fell the %s%s" % [nm, pct]
		"sapling":
			return "Cut the %s" % nm
		"trunk":
			if not is_instance_valid(target.felled):
				return ""                    # gone under us (chained to a horse: HorseHaul)
			var ft: FelledTree = target.felled
			if ft is SkidLoad and ft.logs_left >= 2:
				return "Buck a log off the %s  (%d lengths)" % [nm, ft.logs_left]
			if ft is SkidLoad:
				return "Buck the %s log into the pack" % nm
			return "Buck the %s into logs  %d/%d" % [nm, ft.logs_total - ft.logs_left, ft.logs_total]
		"crown":
			if not is_instance_valid(target.felled):
				return ""
			var fc: FelledTree = target.felled
			var lw := float(_work.get("limb:%d" % fc.get_instance_id(), 0.0))
			return "Limb the %s%s" % [nm, "" if lw <= 0.0 else "  %d%%" % int(clampf(lw / limb_work(fc), 0.0, 0.99) * 100.0)]
		"rock":
			var st := rock_state(int(target.i))
			return "Break stone from the %s  (%d left)" % [nm, int(st.left)]
		"carcass":
			var wn: Variant = target.get("work")
			return String((wn as Node).call(&"axe_prompt", String(target.key))) if wn is Node and is_instance_valid(wn) else ""
		"wall":
			var done := PalisadeCuts.progress(BuildWorld.of(get_tree(), false), String(target.key))
			return "Chop through the %s%s" % [nm, "" if done <= 0.0 else "  %d%%" % int(done * 100.0)]
		"ground":
			var fm := FarmField.find(get_tree())
			return fm.hoe_prompt(String(target.key)) if fm else ""
		"stump":
			var sd := float(_work.get("stump:%d" % int(target.i), 0.0))
			return "%s the stump%s" % ["Grub out" if tool == "mattock" else "Chop out", "" if sd <= 0.0 else "  %d%%" % int(clampf(sd / stump_work(target), 0.0, 0.99) * 100.0)]
	return ""


func _update_prompt() -> void:
	var p := prompt()
	if p == _last_prompt:
		return
	_last_prompt = p
	var it := player.interactor
	if it == null or it.target != gather_target:
		return
	# the interactor refreshes its prompt only when its target changes: the gathering target stays one node
	if p == "" and it.has_method(&"_set_target"):
		it.call(&"_set_target", null)
	elif it.has_method(&"_update_label"):
		it.call(&"_update_label")


# --- Models ----------------------------------------------------------------------------------------------

func _refresh_models() -> void:
	if _socket_hand == null:
		return
	var shown := _model_kind(tool) if tool != "" else ""
	if _model_hand_kind != shown:
		if _model_hand:
			_model_hand.queue_free()
		_model_hand = (_club_model() if tool == CLUB else GatherModels.build(shown)) if tool != "" else null
		_model_hand_kind = shown
		if _model_hand:
			_model_hand.visible = false
			_socket_hand.add_child(_model_hand)
			if melee != null and tool in MELEE_TOOLS:
				melee.weapon_body()      # (another weapon's swing can meet it: AxeMelee.clash)
	if _model_back_kind != on_loop:
		if _model_back:
			_model_back.queue_free()
		_model_back = GatherModels.build(on_loop) if on_loop != "" else null
		_model_back_kind = on_loop
		if _model_back:
			_socket_back.add_child(_model_back)
	if _model_back:
		var xf := _pack_xf(on_loop)
		_model_back.transform = xf
		_model_back.visible = xf != Transform3D() and not (tool == on_loop and phase in [Phase.DRAW_OUT, Phase.READY, Phase.SWING, Phase.STOW_BACK])


func _show_hand(on: bool) -> void:
	if _model_hand:
		_model_hand.visible = on
	if _model_back:
		_model_back.visible = _pack_xf(on_loop) != Transform3D() and not (on and tool == on_loop)


## The tool's place on the pack: the hand's prop bone at the draw's grab (the draw clip's last frame) in the
## upper spine's frame, times the tool's one-hand grip. Identity until the clips are in.
func _pack_xf(kind: String) -> Transform3D:
	if kind == "" or _clips == null or player.skeleton == null:
		return Transform3D()
	if not _back_xf.has(kind):
		var a := _clip("draw_grab")
		if a == null:
			return Transform3D()
		var prop := ToolPose.clip_relative(player.skeleton, a, a.length, "r_hand_prop_attachment", String(data.carry.get("bone", "spined")))
		_back_xf[kind] = prop * blade_offset(kind)
	return _back_xf[kind]


## The tool in the machete clips' blade frame (the prop bone's +Y from the fist along the blade, the edge -Z):
## the haft along +Y with the carry grip at the fist.
func blade_offset(kind: String) -> Transform3D:
	var g := float(data.tool(kind).get("carry_grip_m", 0.46))
	return Transform3D(Basis(), Vector3(0, -g, 0))


## The tool in the pipe clips' two-handed frame (+Z from the lower hand along the haft to the working end, the
## striking face +Y): the knob just below the lower hand.
func two_hand_offset(_kind: String) -> Transform3D:
	return Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0, -0.035))


## How far the blade is turned across now (0..1): the playing attacks whose swing has "turn_blade" (the saber's high
## block: the axe's block holds the head to the right, user 2026-10-03 "the block s is having the sword at right when
## it needs to be left"), by their weight (it turns as the swing blends in and back as it fades out).
func _blade_turn() -> float:
	if melee == null:
		return 0.0
	var k := 0.0
	# (weighted as the pose weighs them: the one fading out under a chained one at full weight, the new one by its blend in;
	# both by w2, the fade out)
	for pair: Array in [[_prev_swing, true], [_swing, false]]:
		var s: Dictionary = pair[0]
		if s.is_empty() or not bool(s.get("melee", false)):
			continue
		if not bool(melee.spec(String(s.get("dir", ""))).get("turn_blade", false)):
			continue
		k = maxf(k, float(s.get("w2", 1.0)) * (1.0 if bool(pair[1]) else smoothstep(0.0, 1.0, float(s.get("w", 0.0)))))
	return smoothstep(0.0, 1.0, k)


func _place_hand_model() -> void:
	if _model_hand == null or tool == "":
		return
	var a := blade_offset(tool)
	var b := two_hand_offset(tool)
	_model_hand.transform = a.interpolate_with(b, clampf(_pipe_w, 0.0, 1.0))
	if tool in ONE_HANDED:
		# held in the fist all through, as at the carry (user 2026-10-03: the hand holding the grip throughout the motion):
		# never on the two-handed swings' haft line between the hands, where the grip floated off the palm; the grip's place
		# along the hand measured at the carry only (the palm's attachment lags a frame, by a hand's breadth in a fast swing),
		# and held
		if phase != Phase.SWING and _palm_att != null and _socket_hand != null:
			var at := (_socket_hand.global_transform * a).affine_inverse() * _palm_att.global_position
			_one_hand_shift = clampf(at.y - GatherModels.SABER_GRIP_M, -0.15, 0.15)
		_model_hand.transform = a * Transform3D(Basis(), Vector3(0, _one_hand_shift, 0))
	if tool == CLUB:
		# the gun turning end for end in the hands, from where it was held to shoot
		var gun := _model_hand.get_node_or_null("Gun") as Node3D
		if gun:
			var k := smoothstep(0.0, 1.0, _club_flip)
			gun.transform = _club_start.interpolate_with(gun.get_meta(&"club_xf"), k)


## The gun out as a club: a copy of its model held by the barrel a hand's breadth behind the muzzle, the butt out as
## the head. The node is the tool's frame (the knob at the origin, the haft +Y, the edge -Z, as GatherModels makes the
## tools); the gun ("Gun") hangs in it end for end: its muzzle end at the knob, its butt up the haft, the heel of the
## butt toward the edge. Markers Butt (the knob), Grip, Head and Edge (the butt's heel) for the sweep
## (AxeMelee._points, WeaponBody).
func _club_model() -> Node3D:
	var root := Node3D.new()
	root.name = "MusketClub"
	var gun := WeaponModels.build(_club_key if _club_key != "" else "musket")
	gun.name = "Gun"
	root.add_child(gun)
	var mz := gun.get_node_or_null("Muzzle") as Node3D
	var muzzle_z := mz.position.z if mz else -1.25
	# (its +Z, toward the butt, up the haft; its +Y, the sights, the edge's back; across, its -X)
	var b := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	var xf := Transform3D(b, -(b * Vector3(0.0, 0.035, muzzle_z + 0.1)))
	gun.transform = xf
	gun.set_meta(&"club_xf", xf)
	var box := _box_in(root, gun)
	var top := box.end.y
	var heel := box.position.z
	for pair: Array in [["Butt", Vector3.ZERO], ["Grip", Vector3(0, 0.46, 0)],
			["Head", Vector3(0, top - 0.12, heel * 0.5)], ["Edge", Vector3(0, top - 0.03, heel + 0.02)]]:
		var m := Marker3D.new()
		m.name = pair[0]
		m.position = pair[1]
		root.add_child(m)
	return root


## The meshes under `n` as one box in `root`'s frame (the nodes need not be in the tree).
static func _box_in(root: Node3D, n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var rel := Transform3D()
		var c: Node = mi
		while c != null and c != root:
			rel = (c as Node3D).transform * rel
			c = c.get_parent()
		var bb := rel * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


# --- Notices, sounds ---------------------------------------------------------------------------------

func _note(text: String) -> void:
	if not _notes.has(text):
		_notes.append(text)


func _on_leveled(id: String, lvl: int, tier: Dictionary) -> void:
	var nm := String(data.skill(id).get("name", id.capitalize()))
	if _hud_toasts() and tier.is_empty():
		return
	if tier.is_empty():
		_note("%s %d" % [nm, lvl])
	else:
		var line := skills.tier_text(id, String(tier.id))
		_note("%s %d: %s. %s" % [nm, lvl, tier.name, line])


## Falls back to this push's synthesized sound (_sound) when GatherSfx's recorded one (`id`, which it has just
## played; audio/sfx/gathering_rec/) is missing.
func _rec_or(id: StringName, synth: String, pos: Vector3, gain_db: float, fallback: StringName) -> void:
	if not Sfx.has(id):
		_sound(synth, pos, gain_db, fallback)


## Plays a gathering sound (audio/sfx/gathering/<id>_NN.wav, tools/sfx/gathering.py: a random variant, a
## little pitch spread) at `pos`, on the World bus like the impacts; the Sfx manifest's `fallback` when the
## files are missing.
func _sound(id: String, pos: Vector3, gain_db: float, fallback: StringName) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if not _streams.has(id):
		var list: Array = []
		for v in range(1, 9):
			var path := SOUND_PATH % [id, v]
			if not ResourceLoader.exists(path):
				break
			list.append(load(path))
		_streams[id] = list
	var list: Array = _streams[id]
	if list.is_empty():
		if Sfx.has(fallback):
			Sfx.play_3d(fallback, pos, gain_db, rng.randf_range(0.65, 0.8))
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = list[rng.randi() % list.size()]
	p.volume_db = gain_db + rng.randf_range(-1.0, 1.0)
	p.pitch_scale = rng.randf_range(0.94, 1.06)
	p.unit_size = 8.0
	p.max_distance = 150.0
	p.attenuation_filter_cutoff_hz = 6000.0
	if AudioServer.get_bus_index(&"World") >= 0:
		p.bus = &"World"
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## FELLING WHERE THE AXE IS (user 2026-10-01: "where ever the axe is at it cuts only to that point"): the height on a standing trunk
## (axis `ax`, radius `r`) the crosshair points at, within the axe's reach from the feet at `p` (CUT_REACH); the strokes go in there
## and the tree comes down from there, leaving a stump that tall.
const CUT_REACH := Vector2(0.25, 1.85)


func _aim_height(_ax: Vector3, _r: float, p: Vector3) -> float:
	# by the look's pitch, not the crosshair's ray: the third-person camera climbs as it looks down, so the ray would want a
	# player staring at their feet for a low cut. Level: waist height (as before); down to the root; up to over the head.
	var pitch := float(player.get("pitch")) if player.get("pitch") != null else 0.0
	return p.y + clampf(1.0 + pitch * 0.75, CUT_REACH.x, CUT_REACH.y)


## STUMPS (user 2026-10-01: "we need to be able to remove the tree stump"): a stump is chopped out with the axe or grubbed out with
## the mattock: the work of felling a tree its size, less for a low stump, more for a tall one (STUMP_WORK of the felling at a
## knee-high stump); out, it gives its wood (a log from one cut a man's height or more, else firewood) and leaves the ground
## clear for good (VegHarvest.stump_gone, saved; the others in a shared world see it go).
const STUMP_WORK := 0.6


func stump_work(c: Dictionary) -> float:
	var h := float(c.get("height", 0.45))
	return maxf(strokes_to_fell(c) * STUMP_WORK * clampf(0.6 + h * 0.6, 0.6, 2.0), 2.0)


func remove_stump(i: int, award := false) -> void:
	for sn in get_tree().get_nodes_in_group(FelledTree.STUMP_GROUP):
		if int(sn.get_meta(&"tree_i", -1)) != i:
			continue
		var h := float(sn.get_meta(&"height", 0.45))
		(sn as Node).queue_free()
		if harvest:
			harvest.stump_gone[i] = true
		NetSession.world_event(get_tree(), "stump", {"i": i})
		if award:
			if h >= 1.2:
				give("log", 1)
			else:
				give("firewood", clampi(roundi(h * 6.0), 1, 4))
			_note("The stump is out")
		return


## A launch's things to try (the user arg give=<kind>[,<kind>...], e.g. give=saber): into the pack once the level is up.
func _give_from_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if not s.begins_with("give="):
			continue
		# after a continued save has put its pack in (it applies some frames in, and the first frames are long): frames, not seconds
		for i in 240:
			await get_tree().process_frame
		var sg := SaveGame.find(get_tree())
		while sg != null and sg.loading:
			await get_tree().process_frame
		if player == null or not is_instance_valid(player):
			return
		var inv := InventoryState.from_player(player)
		for k in s.get_slice("=", 1).split(",", false):
			if SwayCaster.give_arg(player, String(k)):
				continue                          # (a spell, give=form: granted to the Sway caster, not put in the pack)
			inv.add(String(k), 1)
		player.inventory_pack = inv.pack.duplicate(true)
		_note("Given: %s" % s.get_slice("=", 1))
