class_name PlayerInteractor
extends Node
## E is the interact key (user 2026-09-25: "e will be our interact button ... we need a item to highlight
## and we press e to know what we are interacting with"). Nothing is picked up by walking over it any more.
##
## Each frame the interactor finds ONE target in front of the player within reach:
##  - an item: a PlacedWeapon (take / swap) or a ThrownPickup (a thrown spear, tomahawk or dart: pick up);
##    it glows (shaders/interact/highlight.gdshader as material_overlay);
##  - HOLDING E (HOLD_S) with a weapon in the hands: a place to put it instead (user 2026-09-25: "the user has
##    to hold e for it to highlight the drop area not whenever i look down"): a WeaponRack slot, a wall / rock /
##    tree trunk to lean it against, or the ground to lay it on; a translucent copy shows where it will go and
##    letting go of E puts it there. Items near it do not get in the way, and a weapon put down where another
##    already lies or leans goes beside it ("allow items to be droped next to each other").
## A prompt at the bottom of the screen says what E does ("E  Take Brown Bess (loaded)", "Release E  Lean
## Brown Bess against the tree", ...). A tap of E takes / swaps / picks up the highlighted item (on release:
## a longer hold is the placement); the item highlighted when E went down, so a target that changes under the tap
## (an offer that turns up a frame later) does not take it. An interactable may score itself behind the items with
## interact_bias() (FootDrag: dragging the carcass gives way to a tomahawk stuck in it).
##
## Torches (user 2026-09-27: "places to set a lit torch", then the keys: "double t to turn on placement in this mode
## we click t to toggle to throw and then hold to cancel", left click sets or throws; "left click to fire is off" only
## while the mode is on): a double tap of T (PlayerTorch) opens the torch mode, begin_torch_place(), setting it first:
## a ghost torch where the crosshair is, pushed upright into the ground (soil, not rock, a floor or water) or wedged
## at a slant into a wall, the palisade or a tree trunk at shoulder height, the head out and up. A tap of T turns it
## to throwing it and back: an arc of dots to where the crosshair lands (at most PlayerTorch.THROW_MAX) and a ring
## where it comes down. A left click sets it (PlayerTorch.set_down: a DroppedTorch standing, frozen) or throws it
## (PlayerTorch.throw_at: it lands and burns on where it lies); holding T keeps it in the hand. The weapon takes no
## fire while the mode is up (PlayerTorch.blocks_fire). A tap of E takes a set torch up again; standing, it is a
## fixture and does not highlight first as a dropped one does. The long gun (gripped in its middle while the torch
## is held) is not put down with E meanwhile.
##
## Items highlight first (user 2026-09-27: "make highlighting a item take priority if we are next to a e"): next to
## an item to pick up (a weapon put down, a thrown spear or tomahawk, a dropped torch, the dropped pack) it is the
## one highlighted, ITEM_LEAD ahead of the rest in reach, and so the one a tap takes: the spear lying on a plantain
## patch, not the leaves. What the crosshair is on can still be highlighted over it.
##
## Look to pick (user 2026-09-27): what the crosshair is on (its point within LOOK_NEAR of the crosshair's line, or
## the crosshair landing on its body near its point; the nearer the more) scores up to LOOK_BONUS ahead of the rest, so of a carcass, the barrow beside it and the tomahawk in
## it, the one looked at glows and a tap takes it.
##
## Hold E for the list (user 2026-09-27: "the hold interact button for multiple events"): held past HOLD_S with
## anything to do in reach, a short list of everything there comes up in place of the prompt: each interactable in
## reach, best first, and each of its actions (interact_actions(): a lit fire both takes firewood and can be
## smothered). The mouse wheel moves along it, the chosen one glows, and letting go of E does it; the right mouse
## button puts the list away (letting go then does nothing). With a weapon in the hands the first row, chosen at
## first, puts it down: the hold's old meaning, the placement showing while that row is chosen. With nothing to do
## in reach a hold is the placement as before. "Hold E: 2 more" under the prompt says when there is more than the tap.
## What an interactable may add for the list: interact_actions(player) -> [{id, text}] (the first is the tap's) and
## interact_action(player, id); interact_hold_only() -> true: it is never the tap's, only in the list (the river's drink).
##
## The player's side: FrontierPlayer.is_carried() / set_carried() (a weapon put down is not carried until it
## is taken again) and the hands-free state.

const REACH := 2.3            ## m from the chest to an item
const PLACE_REACH := 2.5      ## m from the player to a placement point
const MAX_ANGLE := 55.0       ## deg off the view direction for an item
const RAY_LEN := 12.0          ## the camera stands 3.6 m behind and 2.3 m above the player
const DROP_DIST := 1.2        ## m in front of the player a weapon dropped on ground out of reach lands
const LAY_HEIGHT := Vector2(-0.9, 1.7)   ## m below / above the feet a surface can take a weapon laid on it
const LEAN_REST := 0.62       ## fraction of its length from the butt where a weapon rests on a low edge
const DISMOUNT_HOLD_S := 0.5  ## s E is held on horseback to get off
const HOLD_S := 0.3           ## s E is held before the placement shows (a shorter press is a tap: the item)
const SIDE_GAP := 0.09        ## m between a weapon put down and one already lying or leaning there
const LOOK_BONUS := 1.0       ## taken off the score of what the crosshair is on
const ITEM_LEAD := 1.0        ## taken off the score of an item to pick up (a weapon, a spear, a torch, the pack)
const PLANT_DEPTH := 0.12     ## m of a torch's butt pushed into the ground
const PLANT_LEAN := 5.0       ## deg a torch in the ground leans away from the player
const WEDGE_TILT := 35.0      ## deg off upright a torch wedged in a wall stands out from it
const WEDGE_H := Vector2(1.0, 1.9)   ## m above the feet a torch's butt is wedged into a wall (the crosshair's height, kept to this)
const LOOK_NEAR := 0.6        ## m from the crosshair's line to a thing's point that counts as looking at it
const LOOK_BODY := 1.5        ## m from where the crosshair lands on a thing's body to its point that counts
const LOOK_BEYOND := 1.0      ## m past a thing the crosshair may land and still count as on it (less after, none at 2x)
const MENU_MAX := 6           ## rows in the hold-E list
const GAP := "      "         ## a prompt's extra (a fire's "F  Cook ..."): the list keeps the action before it

## Each notice() as it is shown (the classic HUD's chat log: HudClassicMap).
signal noticed(text: String, secs: float)
## The prompt, its "Hold E: 2 more" line and the hold-E list raised this many px (the classic HUD's action bar and renown
## bar under them: ClassicFrames sets PROMPT_LIFT; 0 the minimal HUD's places).
var prompt_lift := 0.0:
	set(v):
		prompt_lift = v
		_lay_prompt()

var player: FrontierPlayer
var target: Node = null            ## the targeted item (PlacedWeapon / ThrownPickup), or null
var place := {}                    ## the placement {kind: "rack"|"lean"|"lay", xf, rack, slot, what}, or {}
var menu: Array = []               ## the hold-E list, [{node, id, text}] ({node: null, id: "place"}: put the weapon down); [] when shut
var menu_i := 0                    ## the chosen row

var _cands: Array = []             ## this frame's interactables in reach, [score, node], best first
var _menu_off := false             ## the list was put away (the right mouse button): letting go of E does nothing
var _menu_box: PanelContainer
var _menu_rows: VBoxContainer
var _more: Label

var _hl_mat: ShaderMaterial
var _ghost_mat: ShaderMaterial
var _hl_nodes: Array = []          ## [GeometryInstance3D, previous material_overlay]
var _ghost: Node3D
var _ghost_key := ""
var _label: Label
var _layer: CanvasLayer
var _notice: Label
var _notice_t := 0.0
var _press_t := -1.0               ## seconds E has been held (-1: not held)
var _press_target: Node = null     ## the target when E went down (a tap acts on it)
var _placing := false              ## E held long enough with a weapon in the hands: the placement is up
var _place_kind := "weapon"        ## what the placement puts down: "weapon" (hold E) or "torch" (double tap T)
## The torch mode (a double tap of T): "set" or "throw" ("" when off); torch_placing while it is up. T's and the
## left button's last states (a press held into the mode is not one), how long T has been held in it (-1: not
## pressed in it), and the throw shown (throw: {at, land, vel}).
var torch_mode := ""
var torch_placing := false
var throw := {}
var _t_was := true
var _t_down := -1.0
var _fire_was := true
var _arc: MultiMeshInstance3D
var _ring: MeshInstance3D
var _was_down := false


static func install(p: FrontierPlayer) -> PlayerInteractor:
	var it := PlayerInteractor.new()
	it.name = "Interactor"
	it.player = p
	p.add_child(it)
	return it


func _ready() -> void:
	ThrownPickup.ensure_input()
	_hl_mat = ShaderMaterial.new()
	_hl_mat.shader = load("res://shaders/interact/highlight.gdshader")
	var outline := ShaderMaterial.new()
	outline.shader = load("res://shaders/interact/highlight_outline.gdshader")
	_hl_mat.next_pass = outline
	_ghost_mat = ShaderMaterial.new()
	_ghost_mat.shader = load("res://shaders/interact/ghost.gdshader")
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# the HUD's lettering (FrontierHUD: serif, a soft shadow, no heavy outline)
	_label.add_theme_font_override("font", FrontierHUD.serif())
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.add_theme_constant_override("shadow_outline_size", 4)
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.position = Vector2(-300, -120)
	_label.size = Vector2(600, 40)
	_layer.add_child(_label)
	_notice = _label.duplicate() as Label
	_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice.position = Vector2(-300, 96)          # under the compass and the date
	_notice.size = Vector2(600, 40)
	_layer.add_child(_notice)
	_more = _label.duplicate() as Label
	_more.add_theme_font_size_override("font_size", 16)
	_more.add_theme_color_override("font_color", Color(0.9, 0.84, 0.7, 0.7))
	_more.position = Vector2(-300, -86)
	_more.size = Vector2(600, 24)
	_layer.add_child(_more)
	_build_menu()
	call_deferred(&"_ensure_demo_props")


## The hold-E list: rows of the HUD's lettering on its soft shade (no box), to the right of the player.
func _build_menu() -> void:
	_menu_box = PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = FrontierHUD.shade()
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 18
	sb.content_margin_bottom = 16
	_menu_box.add_theme_stylebox_override("panel", sb)
	_menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box.anchor_left = 0.5
	_menu_box.anchor_right = 0.5
	_menu_box.anchor_top = 1.0
	_menu_box.anchor_bottom = 1.0
	# beside the player, not over them (the player stands at the bottom middle), and above the weapon slots
	_menu_box.offset_left = 70
	_menu_box.offset_right = 70
	_menu_box.offset_top = -104
	_menu_box.offset_bottom = -104
	_menu_box.grow_horizontal = Control.GROW_DIRECTION_END
	_menu_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu_box.visible = false
	_layer.add_child(_menu_box)
	_menu_rows = VBoxContainer.new()
	_menu_rows.add_theme_constant_override("separation", 6)
	_menu_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box.add_child(_menu_rows)


## The prompt's lines at their places, `prompt_lift` px up (the "Hold E" line a few px more: closer under the prompt).
func _lay_prompt() -> void:
	if _label == null or _more == null or _menu_box == null:
		return
	var up := prompt_lift
	var more_up := up + 4.0 if up > 0.0 else 0.0
	_label.offset_top = -120.0 - up
	_label.offset_bottom = -80.0 - up
	_more.offset_top = -86.0 - more_up
	_more.offset_bottom = -62.0 - more_up
	_menu_box.offset_top = -104.0 - up
	_menu_box.offset_bottom = -104.0 - up


## A short message at the top of the screen for a couple of seconds ("Kit: Musket and spears").
func notice(text: String, secs := 2.5) -> void:
	noticed.emit(text, secs)                 # (the classic HUD's chat log writes it too: HudClassicMap)
	_notice.text = text
	_notice_t = secs
	_notice.modulate.a = 1.0


func _process(delta: float) -> void:
	if _notice_t > 0.0:
		_notice_t -= delta
		_notice.modulate.a = clampf(_notice_t / 0.5, 0.0, 1.0)
		if _notice_t <= 0.0:
			_notice.text = ""


func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
		# freed under us (taken by someone else, or directly by a script): forget it and its prompt
		target = null
		_hl_nodes.clear()
		_update_label()
	# E's own edges from its held state (the "just" flags of an action pressed from script can lag the held
	# state by a physics frame)
	var down := Input.is_action_pressed(ThrownPickup.INTERACT)
	var pressed := down and not _was_down
	var released := _was_down and not down
	_was_down = down
	# riding: holding E (DISMOUNT_HOLD_S) gets off the horse (user 2026-09-25: "should be hold e to dismount");
	# a tap does what the horse offers from the saddle (HorseHaul: hitch the log behind it, unhitch the load)
	if player.get("riding") != null:
		var st := _saddle_item()
		if pressed:
			_press_t = 0.0
		elif down and _press_t >= 0.0:
			_press_t += _delta
			if _press_t >= DISMOUNT_HOLD_S:
				_press_t = -1.0
				player.dismount()
				st = null
		elif not down:
			if released and _press_t >= 0.0 and st != null:
				st.interact(player)
			_press_t = -1.0
		_close_menu()
		if torch_placing:
			_end_torch_place()
		_set_target(st)
		_set_place({})
		_set_more("")
		return
	if torch_placing:
		_torch_place_frame(_delta)
		return
	if released and _press_t >= 0.0:
		# let go: a tap takes the highlighted item; after a hold, the list's chosen row is done, or the weapon put
		# where the placement showed it (this frame's target and placement are still the last frame's)
		var tap := _press_t < HOLD_S
		_press_t = -1.0
		if tap:
			if is_instance_valid(_press_target) and not _press_target.is_queued_for_deletion():
				_set_target(_press_target)
			_do_item()
		elif not menu.is_empty():
			_do_row()
		elif _placing and not place.is_empty() and not _menu_off:
			_do_place()
		_close_menu()
		_menu_off = false
		_press_target = null
		_placing = false
		_set_place({})
		_set_target(_find_item())
		_update_more()
		return
	if pressed:
		_press_t = 0.0
		_press_target = target
		_menu_off = false
	elif down and _press_t >= 0.0:
		_press_t += _delta
	elif not down:
		_press_t = -1.0
		_press_target = null
		_menu_off = false
		_close_menu()
	var held := down and _press_t >= HOLD_S and not _menu_off
	if held and menu.is_empty() and not _placing:
		_open_menu()   # nothing to do in reach: no list, the placement as before
	if not menu.is_empty():
		var row: Dictionary = menu[menu_i]
		_place_kind = "weapon"
		_placing = row.id == "place" and _can_place()
		_set_target(null if _placing else _row_node(row))
		_set_place(_find_place() if _placing else {})
		_menu_text()
		return
	_place_kind = "weapon"
	_placing = held and _can_place()
	_set_target(null if (_placing or player.get("riding") != null) else _find_item())
	_set_place(_find_place() if _placing else {})
	_update_more()


## The mouse wheel moves along the hold-E list (the weapons are not switched under it); the right mouse button
## puts it away.
func _unhandled_input(event: InputEvent) -> void:
	if menu.is_empty():
		return
	if event.is_action_pressed(&"weapon_next") or event.is_action_pressed(&"weapon_prev"):
		menu_i = wrapi(menu_i + (1 if event.is_action_pressed(&"weapon_next") else -1), 0, menu.size())
		_menu_style()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"aim"):
		_menu_off = true
		_close_menu()
		_placing = false
		_set_place({})
		get_viewport().set_input_as_handled()


func _chest() -> Vector3:
	return player.global_position + Vector3.UP * 1.0


func _view_dir() -> Vector3:
	var cam := player.get_viewport().get_camera_3d()
	return -cam.global_transform.basis.z if cam else -player.global_transform.basis.z


## The best interactable in reach (null when none); all of them, best first, in _cands.
func _find_item() -> Node:
	_cands.clear()
	if player.is_dead:
		return null
	var chest := _chest()
	var fwd := _view_dir()
	var fwd_h := Vector3(fwd.x, 0, fwd.z).normalized()
	var look := _look_hit()
	for n in get_tree().get_nodes_in_group(PlacedWeapon.GROUP):
		var pw := n as PlacedWeapon
		if pw == null:
			# any other interactable (a horse to mount, later a carcass): interact_point(), interact_prompt(),
			# interact(), highlight_targets(), and optionally interact_reach and distance_from()
			if not n.has_method("interact_point") or not n.has_method("interact") or n.interact_prompt(player) == "":
				continue
			var reach_n := float(n.get("interact_reach")) if n.get("interact_reach") != null else REACH
			var pt: Vector3 = n.interact_point()
			var dn: float = n.distance_from(chest) if n.has_method("distance_from") else chest.distance_to(pt)
			if dn > reach_n:
				continue
			var sn := _score(pt, chest, fwd_h, dn, reach_n) + (float(n.interact_bias()) if n.has_method("interact_bias") else 0.0)
			if sn < INF:
				_cands.append([sn - LOOK_BONUS * _look_at(n, pt, look) - (ITEM_LEAD if ((n is DroppedTorch and not (n as DroppedTorch).standing()) or n is PackDrop) else 0.0), n])
			continue
		var d := pw.distance_from(chest)
		if d > REACH:
			continue
		var s := _score(pw.interact_point(), chest, fwd_h, d, REACH)
		if s < INF:
			_cands.append([s - LOOK_BONUS * _look_at(pw, pw.interact_point(), look) - ITEM_LEAD, pw])
	for n in get_tree().get_nodes_in_group(ThrownPickup.GROUP):
		var pk := n as ThrownPickup
		if pk == null or not pk.is_armed() or pk.prompt(player) == "":
			continue
		var d := pk.distance_from(chest)
		if d > pk.interact_radius:
			continue
		var s := _score(pk.global_position, chest, fwd_h, d, pk.interact_radius)
		if s < INF:
			_cands.append([s - LOOK_BONUS * _look_at(pk, pk.global_position, look) - ITEM_LEAD, pk])
	_cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	# the tap's is the best that is not for the hold alone (an interactable's interact_hold_only(): the river's drink, user 2026-09-29: "i always
	# wanted that to be a hold E interaction"); those are only in the list a hold brings up
	for c: Array in _cands:
		var n: Node = c[1]
		if not (n.has_method("interact_hold_only") and bool(n.interact_hold_only())):
			return n
	return null


## The crosshair's line: {from, to} (the camera to where it lands, or RAY_LEN on), and where it lands {position,
## collider, ...} as `hit` ({} on nothing); {} without a camera.
func _look_hit() -> Dictionary:
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * RAY_LEN
	var hit := _ray(from, to)
	return {"from": from, "to": hit.position if not hit.is_empty() else to, "hit": hit}


## How much the crosshair is on `n` (point `pt`), 0..1, by how near its line passes before it lands (1 through the
## point, 0 at LOOK_NEAR or beyond: the camera stands high behind, so a crosshair on a carcass in reach goes on to the
## ground just beyond it; landing much farther on, LOOK_BEYOND, it is looking past it); landing on its body (it, one of its parts, or the body it is part of: a horse's lead and its
## saddle, a barrow's handles and its bed), by how near where it lands is to its point, LOOK_BODY or less, so of the
## things on one body the one looked at counts most. A long thing (a weapon lying or leaning, a thrown spear, a
## dropped torch, a log) counts along its length.
func _look_at(n: Node, pt: Vector3, look: Dictionary) -> float:
	if look.is_empty():
		return 0.0
	var long := n is PlacedWeapon or n is ThrownPickup or n is DroppedTorch or n is LogPile
	var from: Vector3 = look.from
	var to: Vector3 = look.to
	var q := Geometry3D.get_closest_point_to_segment(pt, from, to)
	# (to its point in the round: some distance_from() are flat, for reach, and would take a line high over it)
	var d := q.distance_to(pt)
	if long:
		var dir := (to - from).normalized()
		for k in range(-8, 9):
			d = minf(d, float(n.distance_from(q + dir * 0.25 * float(k))))
	# a line passing near it on its way to land well beyond (over a horse's head to the ground past its saddle) is
	# not looking at it: full within LOOK_BEYOND of where it lands, nothing at twice that
	var beyond := q.distance_to(to)
	var g := clampf(1.0 - d / LOOK_NEAR, 0.0, 1.0) * clampf(2.0 - beyond / LOOK_BEYOND, 0.0, 1.0)
	var hit := look.hit as Dictionary
	var col := hit.get("collider") as Node
	if col != null and (col == n or n.is_ancestor_of(col) or n.get_parent() == col
			or (n.get_parent() != null and n.get_parent().get_parent() == col)):
		var at: Vector3 = hit.position
		var hd: float = float(n.distance_from(at)) if long else at.distance_to(pt)
		g = maxf(g, clampf(1.0 - hd / LOOK_BODY, 0.0, 1.0))
	return g


## Riding: the interactable offering something from the saddle (saddle_prompt() not empty), or null.
func _saddle_item() -> Node:
	for n in get_tree().get_nodes_in_group(PlacedWeapon.GROUP):
		if n.has_method(&"saddle_prompt") and n.saddle_prompt(player) != "":
			return n
	return null


## Lower is better: how far off the view direction (0..1 over MAX_ANGLE) plus how far away (0..1); INF when
## outside the view cone (items right at the feet always count).
func _score(point: Vector3, chest: Vector3, fwd_h: Vector3, d: float, reach: float) -> float:
	var to := point - chest
	var to_h := Vector3(to.x, 0, to.z)
	var ang := 0.0
	if to_h.length() > 0.35:
		ang = rad_to_deg(fwd_h.angle_to(to_h.normalized()))
		if ang > MAX_ANGLE:
			return INF
	return ang / MAX_ANGLE + d / reach


## A weapon in the hands that can be put down now. Not with a torch in the other hand (the long gun is gripped in its
## middle then, and the hand it would go to next holds the torch): the torch is set first.
func _can_place() -> bool:
	var pt: PlayerTorch = player.get("torch")
	if pt != null and (pt.holding() or pt.pending):
		return false
	return player.get("riding") == null and not (player.is_dead or player.hands_free or player.is_switching() or player.weapon == null
			or player.weapon.model == null or not player.is_carried(player.weapon_key))


## The torch mode (PlayerTorch: a double tap of T), setting it first. False when there is no torch in the hand.
func begin_torch_place() -> bool:
	if not _can_set_torch():
		return false
	_close_menu()
	_press_t = -1.0
	_press_target = null
	_placing = false
	_set_target(null)
	torch_placing = true
	torch_mode = "set"
	_place_kind = "torch"
	_t_was = true
	_t_down = -1.0
	_fire_was = true
	var pt: PlayerTorch = player.get("torch")
	pt.placing = true
	_torch_frame_view()
	return true


func _end_torch_place() -> void:
	torch_placing = false
	torch_mode = ""
	throw = {}
	_t_down = -1.0
	var pt: PlayerTorch = player.get("torch")
	if pt:
		pt.placing = false
	_set_more("")
	_set_place({})
	_show_arc({})
	_update_label()


func _torch_place_frame(delta: float) -> void:
	if not _can_set_torch() or player.is_dead:
		_end_torch_place()
		return
	var pt: PlayerTorch = player.get("torch")
	# T: a tap turns setting to throwing and back, a hold keeps it in the hand (the mode off)
	var down := Input.is_action_pressed(PlayerTorch.ACTION)
	if down and not _t_was:
		_t_down = 0.0
	elif down and _t_down >= 0.0:
		_t_down += delta
		if _t_down >= PlayerTorch.HOLD_S:
			_t_was = down
			_end_torch_place()
			return
	elif not down and _t_was and _t_down >= 0.0:
		torch_mode = "throw" if torch_mode == "set" else "set"
		_t_down = -1.0
	_t_was = down
	# the left button: set it, or throw it
	var fire := Input.is_action_pressed(&"fire")
	var click := fire and not _fire_was
	_fire_was = fire
	_set_target(null)
	_torch_frame_view()
	if not click:
		return
	if torch_mode == "set" and not place.is_empty():
		var xf: Transform3D = place.xf
		pt.hold_fire = true
		_end_torch_place()
		pt.set_down(xf)
	elif torch_mode == "throw" and not throw.is_empty():
		var at: Vector3 = throw.at
		pt.hold_fire = true
		_end_torch_place()
		pt.throw_at(at)


## The torch mode's ghost or arc and its words, for this frame.
func _torch_frame_view() -> void:
	var t := OS.get_keycode_string(PlayerTorch.KEY)
	if torch_mode == "set":
		throw = {}
		_show_arc({})
		_set_place(_find_torch_place())
		_set_more("%s: throw it instead  ·  hold %s: keep it" % [t, t])
	else:
		_set_place({})
		throw = _find_throw()
		_show_arc(throw)
		_set_more("%s: set it instead  ·  hold %s: keep it" % [t, t])
	_update_label()


## Where a throw of the torch goes: to where the crosshair lands, at most PlayerTorch.THROW_MAX away (farther, the
## ground under that far along it); {at, land, vel, path} with where it really comes down (the path cut at what it
## meets first), or {} with nothing to aim at.
func _find_throw() -> Dictionary:
	var pt: PlayerTorch = player.get("torch")
	var cam := player.get_viewport().get_camera_3d()
	if pt == null or cam == null:
		return {}
	var from := pt.flame_position() + Vector3.DOWN * 0.4      # (about the fist)
	var dir := -cam.global_transform.basis.z
	var hit := _ray(cam.global_position, cam.global_position + dir * (PlayerTorch.THROW_MAX + 6.0))
	var at: Vector3
	var flat := func(p: Vector3) -> float: return Vector2(p.x - from.x, p.z - from.z).length()
	if not hit.is_empty() and flat.call(hit.position) <= PlayerTorch.THROW_MAX:
		at = hit.position
	else:
		var dh := Vector3(dir.x, 0, dir.z).normalized()
		var far := from + dh * PlayerTorch.THROW_MAX
		var g := _ray(far + Vector3.UP * 6.0, far + Vector3.DOWN * 12.0)
		if g.is_empty():
			return {}
		at = g.position
	if flat.call(at) < 1.0:
		return {}
	var vel := PlayerTorch.throw_velocity(from, at)
	var path := PlayerTorch.throw_path(from, vel, at.y - 2.0)
	var land := at
	for i in range(1, path.size()):
		var h := _ray(path[i - 1], path[i])
		if not h.is_empty():
			land = h.position
			path = path.slice(0, i)
			path.append(land)
			break
	return {"at": at, "land": land, "vel": vel, "path": path}


## The throw's arc (dots along it) and the ring where it comes down; hidden with {}.
func _show_arc(th: Dictionary) -> void:
	if th.is_empty():
		if _arc:
			_arc.visible = false
			_ring.visible = false
		return
	if _arc == null or not is_instance_valid(_arc):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.78, 0.42, 0.85)
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
		_arc.multimesh = mm
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc.top_level = true
		add_child(_arc)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.26
		ring.outer_radius = 0.32
		ring.material = mat
		_ring = MeshInstance3D.new()
		_ring.mesh = ring
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.top_level = true
		add_child(_ring)
	# a dot every ~0.35 m along the path
	var path: PackedVector3Array = th.path
	var mm := _arc.multimesh
	var n := 0
	var run := 0.0
	for i in range(1, path.size()):
		run += path[i].distance_to(path[i - 1])
		if run >= 0.35 and n < mm.instance_count:
			run = 0.0
			mm.set_instance_transform(n, Transform3D(Basis(), path[i]))
			n += 1
	mm.visible_instance_count = n
	_arc.global_transform = Transform3D()
	_arc.visible = true
	_ring.global_position = (th.land as Vector3) + Vector3.UP * 0.04
	_ring.visible = true


## A torch in the hand that can be set down now.
func _can_set_torch() -> bool:
	var pt: PlayerTorch = player.get("torch")
	return pt != null and pt.holding() and not pt.tossing() and player.get("riding") == null and not player.is_dead


## Where the torch in the hand would stand: where the crosshair is within PLACE_REACH, pushed upright into the ground
## (soil) or wedged into a wall, the palisade or a tree at WEDGE_H; nothing under the crosshair in reach, into the
## ground at arm's length in front. {kind: "ground"|"wall", xf, what, torch: true}, or {} where it cannot stand
## (rock, a floor, a roof, water).
func _find_torch_place() -> Dictionary:
	if not _can_set_torch():
		return {}
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var hit := _ray(cam.global_position, cam.global_position - cam.global_transform.basis.z * RAY_LEN)
	var dist := INF
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		dist = Vector2(hp.x - player.global_position.x, hp.z - player.global_position.z).length()
	if dist > PLACE_REACH:
		var d := _drop_point()
		if d.is_empty() or not _soil(d):
			return {}
		return _torch_in_ground(d.position)
	var nrm: Vector3 = hit.normal
	if nrm.y >= 0.7:
		var up := (hit.position as Vector3).y - player.global_position.y
		if up < LAY_HEIGHT.x or up > 0.6 or not _soil(hit):
			return {}
		return _torch_in_ground(hit.position)
	if nrm.y > 0.45:
		return {}
	var col: Node = hit.collider
	if Sfx.surface_of(col, hit.position, nrm) == "stone":
		return {}   # (no crack in the rock to take it)
	var out := Vector3(nrm.x, 0, nrm.z).normalized()
	# at the crosshair's height, kept between the knee and over the head: the wall found again there
	var h := clampf((hit.position as Vector3).y - player.global_position.y, WEDGE_H.x, WEDGE_H.y)
	var at := Vector3((hit.position as Vector3).x, player.global_position.y + h, (hit.position as Vector3).z) + out * 0.4
	var c := _ray(at, at - out * 0.9)
	if c.is_empty() or absf((c.normal as Vector3).y) > 0.45 or Sfx.surface_of(c.collider, c.position, c.normal) == "stone":
		return {}
	col = c.collider
	out = Vector3((c.normal as Vector3).x, 0, (c.normal as Vector3).z).normalized()
	var t := deg_to_rad(WEDGE_TILT)
	var head := (Vector3.UP * cos(t) + out * sin(t)).normalized()
	return {"kind": "wall", "torch": true, "xf": _torch_xf((c.position as Vector3) - out * 0.03, head),
			"what": "Wedge the torch in the %s" % _surface_name(col)}


## Upright in the ground at `p`, the butt PLANT_DEPTH in, leaning PLANT_LEAN away from the player.
func _torch_in_ground(p: Vector3) -> Dictionary:
	var away := p - player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -player.global_basis.z
	var t := deg_to_rad(PLANT_LEAN)
	var head := (Vector3.UP * cos(t) + away * sin(t)).normalized()
	return {"kind": "ground", "torch": true, "xf": _torch_xf(p - Vector3.UP * PLANT_DEPTH, head),
			"what": "Push the torch into the ground"}


## The torch model's transform (origin at the grip, the head toward -Z) with its butt at `butt`, the head along
## `head`.
func _torch_xf(butt: Vector3, head: Vector3) -> Transform3D:
	var z := -head.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = player.global_basis.x
	x = x.normalized()
	var b := Basis(x, z.cross(x).normalized(), z)
	return Transform3D(b, butt - b.z * TorchModels.GRIP_FROM_BUTT)


## Ground a torch can be pushed into: the terrain's soil (grass or dirt), not its rock, a built floor or water.
func _soil(hit: Dictionary) -> bool:
	var col := hit.get("collider") as Node
	if col == null or not col.is_in_group(&"terrain"):
		return false
	if Sfx.surface_of(col, hit.position, hit.normal) == "stone":
		return false
	return not TorchState.under_water(player.get_world_3d(), get_tree(), (hit.position as Vector3) + Vector3.UP * 0.3)


func _find_place() -> Dictionary:
	if _place_kind == "torch":
		return _find_torch_place()
	if not _can_place():
		return {}
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var hit := _ray(cam.global_position, cam.global_position - cam.global_transform.basis.z * RAY_LEN)
	var key := player.weapon_key
	var ext := PlacedWeapon.z_extent(player.weapon.model)
	var what := player.weapon.display_name
	var dist := INF
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		dist = Vector2(hp.x - player.global_position.x, hp.z - player.global_position.z).length()
	if dist > PLACE_REACH:
		# out of reach, or nothing under the crosshair (E is held to put it down: the camera sits behind the
		# player, so the ground right in front is seldom under the crosshair): dropped at arm's length in
		# front. Walk up to a wall or tree to lean it there.
		var d := _drop_point()
		if d.is_empty():
			return {}
		return {"kind": "lay", "xf": _spaced("lay", d.position, d.normal, ext), "what": "Drop %s" % what}
	var pos: Vector3 = hit.position
	var nrm: Vector3 = hit.normal
	# a rack (the collider or its parent)
	var col: Node = hit.collider
	var rack: WeaponRack = col as WeaponRack
	if rack == null and col and col.get_parent() is WeaponRack:
		rack = col.get_parent() as WeaponRack
	if rack:
		if not rack.accepts(key):
			return {}
		var slot := rack.free_slot_near(pos)
		if slot < 0:
			return {}
		return {"kind": "rack", "xf": rack.slot_pose(slot, ext), "rack": rack, "slot": slot,
				"what": "Place %s in the %s" % [what, "barrel" if rack.style == "barrel" else "rack"]}
	if nrm.y < 0.45:
		var xf := _spaced("lean", pos, nrm, ext)
		if xf == Transform3D():
			return {}
		return {"kind": "lean", "xf": xf, "what": "Lean %s against the %s" % [what, _surface_name(col)]}
	var up := pos.y - player.global_position.y
	if up < LAY_HEIGHT.x or up > LAY_HEIGHT.y:
		return {}   # a roof, the top of the palisade, the bottom of a ditch: out of reach
	return {"kind": "lay", "xf": _spaced("lay", pos, nrm, ext),
			"what": ("Drop %s" if up < 0.3 else "Set %s down here") % what}


## Where a weapon dropped at arm's length lands: DROP_DIST in front of the player along the view, on
## whatever is under that point ({} when nothing is).
func _drop_point() -> Dictionary:
	var fwd := _view_dir()
	var fh := Vector3(fwd.x, 0, fwd.z).normalized()
	var at := player.global_position + fh * DROP_DIST
	var g := _ray(at + Vector3.UP * 1.0, at + Vector3.DOWN * 1.5)
	if g.is_empty() or (g.normal as Vector3).y < 0.45:
		return {}
	return g


## Leaning against a vertical surface at `pos` (normal `nrm`), butt on the ground in front of it. Against a
## wall or trunk taller than the weapon it stands nearly upright with its top on the surface; on something
## lower (a rock, a log, a crate) it rests over the edge at LEAN_REST of its length from the butt, flatter
## the lower the edge. Identity when there is no ground in front of it or nothing to rest on.
func _lean_pose(pos: Vector3, nrm: Vector3, ext: Vector2) -> Transform3D:
	var out := Vector3(nrm.x, 0, nrm.z)
	if out.length() < 0.1:
		return Transform3D()
	out = out.normalized()
	var length := ext.y - ext.x
	var ground := _ground_at(pos + out * 0.3)
	if ground == INF:
		return Transform3D()
	var d := clampf(length * 0.22, 0.15, 0.45)
	var h_full := sqrt(maxf(length * length - d * d, 0.01))
	# the highest point of the surface, up to the upright weapon's top, it can rest against
	var contact := Vector3.INF
	var h := h_full
	while h >= 0.2:
		var at := Vector3(pos.x, ground + h, pos.z) + out * 0.5
		var c := _ray(at, at - out * 0.9)
		if not c.is_empty() and absf((c.normal as Vector3).y) < 0.7:
			contact = c.position
			break
		h -= 0.1
	if contact == Vector3.INF:
		return Transform3D()
	var hc := contact.y - ground
	var rest := clampf(hc * length / h_full, length * LEAN_REST, length)   # butt -> contact along it
	var sin_t := clampf(hc / rest, 0.15, 1.0)
	var run := rest * sqrt(1.0 - sin_t * sin_t)
	var foot := contact + out * run
	var gb := _ground_at(foot)
	if gb == INF:
		return Transform3D()
	var butt := Vector3(foot.x, gb + 0.02, foot.z)
	var z := -(contact + out * 0.025 - butt).normalized()   # model -Z = muzzle / point end (up)
	var y := out                                             # the lock / top of the weapon faces out
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	var b := Basis(x, y, z)
	return Transform3D(b, butt - b * Vector3(0, 0, ext.y))


## The lying or leaning pose at `pos` (see _lay_pose / _lean_pose), moved beside the weapons already put down
## there when it would lie in one of them: shifted across its length in SIDE_GAP steps to either side, onto
## the first spot clear of them (the ground found again under it). Identity when there is no pose.
func _spaced(kind: String, pos: Vector3, nrm: Vector3, ext: Vector2) -> Transform3D:
	var xf := _lean_pose(pos, nrm, ext) if kind == "lean" else _lay_pose(pos, nrm, ext)
	if xf == Transform3D():
		return xf
	var others: Array = []
	for n in get_tree().get_nodes_in_group(PlacedWeapon.GROUP):
		var pw := n as PlacedWeapon
		if pw and pw.rack == null and pw.model and pw.global_position.distance_to(pos) < 3.0:
			others.append(pw)
	if others.is_empty() or _clear_of(xf, ext, others):
		return xf
	var side := xf.basis.x.normalized()
	for k in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
		var p2 := pos + side * SIDE_GAP * float(k)
		if kind == "lay":
			var g := _ray(p2 + nrm * 0.4, p2 - nrm * 0.8)
			if g.is_empty() or (g.normal as Vector3).y < 0.45:
				continue
			p2 = g.position
		var c := _lean_pose(p2, nrm, ext) if kind == "lean" else _lay_pose(p2, nrm, ext)
		if c != Transform3D() and _clear_of(c, ext, others):
			return c
	return xf


## Whether a weapon of z-extent `ext` at `xf` keeps SIDE_GAP (less a little) from the weapons `others`, along
## their whole lengths.
func _clear_of(xf: Transform3D, ext: Vector2, others: Array) -> bool:
	var a := xf * Vector3(0, 0, ext.x)
	var b := xf * Vector3(0, 0, ext.y)
	for pw: PlacedWeapon in others:
		var e2 := PlacedWeapon.z_extent(pw.model)
		var c := pw.global_transform * Vector3(0, 0, e2.x)
		var d := pw.global_transform * Vector3(0, 0, e2.y)
		var cl := Geometry3D.get_closest_points_between_segments(a, b, c, d)
		if cl[0].distance_to(cl[1]) < SIDE_GAP * 0.75:
			return false
	return true


## Height of the ground under `p` near the player's own level (INF when there is none: a drop, a ledge).
func _ground_at(p: Vector3) -> float:
	var base := player.global_position.y
	var g := _ray(Vector3(p.x, base + 1.0, p.z), Vector3(p.x, base - 1.5, p.z))
	if g.is_empty() or (g.normal as Vector3).y < 0.6:
		return INF
	return (g.position as Vector3).y


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)


## Lying on the ground at `pos`, across the view, top up.
func _lay_pose(pos: Vector3, nrm: Vector3, ext: Vector2) -> Transform3D:
	var fwd := _view_dir()
	var y := nrm.normalized()
	var z := y.cross(Vector3(fwd.x, 0, fwd.z).normalized()).normalized()   # across the view
	var x := y.cross(z).normalized()
	var b := Basis(x, y, z)
	var mid := Vector3(0, 0, (ext.x + ext.y) * 0.5)
	return Transform3D(b, pos + y * 0.03 - b * mid)


func _surface_name(col: Node) -> String:
	if col == null:
		return "wall"
	if col.is_in_group(&"trees"):
		return "tree"
	if col.is_in_group(&"rocks"):
		return "rock"
	var n := (String(col.name) + " " + (String(col.get_parent().name) if col.get_parent() else "")).to_lower()
	for k in [["tree", "tree"], ["trunk", "tree"], ["rock", "rock"], ["stone", "rock"], ["boulder", "rock"],
			["stump", "stump"], ["palisade", "palisade"], ["wall", "wall"], ["cabin", "wall"], ["log", "log"],
			["crate", "crate"], ["barrel", "barrel"], ["post", "post"]]:
		if n.contains(k[0]):
			return k[1]
	return "wall"


func _set_target(t: Node) -> void:
	if t == target:
		return
	for pair: Array in _hl_nodes:
		if is_instance_valid(pair[0]):
			(pair[0] as GeometryInstance3D).material_overlay = pair[1]
	_hl_nodes.clear()
	target = t
	if t == null:
		_update_label()
		return
	var geoms: Array = []
	if t.has_method("highlight_targets"):
		geoms = t.highlight_targets()
	elif t is ThrownPickup and (t as ThrownPickup).item:
		geoms = (t as ThrownPickup).item.find_children("*", "GeometryInstance3D", true, false)
	for g in geoms:
		var gi := g as GeometryInstance3D
		_hl_nodes.append([gi, gi.material_overlay])
		gi.material_overlay = _hl_mat
	_update_label()


func _set_place(pl: Dictionary) -> void:
	place = pl
	if pl.is_empty():
		if _ghost:
			_ghost.visible = false
		_update_label()
		return
	var gk := "~torch" if bool(pl.get("torch", false)) else player.weapon_key
	if _ghost == null or _ghost_key != gk or not is_instance_valid(_ghost):
		if _ghost and is_instance_valid(_ghost):
			_ghost.queue_free()
		_ghost = TorchModels.build() if gk == "~torch" else PlacedWeapon.build_model(player.weapon, player.weapon_key)
		_ghost_key = gk
		for g in _ghost.find_children("*", "GeometryInstance3D", true, false):
			(g as GeometryInstance3D).material_override = _ghost_mat
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_tree().current_scene.add_child(_ghost)
	_ghost.visible = true
	for c in _ghost.find_children("*", "Node3D", true, false):
		(c as Node3D).visible = true
	_ghost.global_transform = pl.xf
	_update_label()


func _update_label() -> void:
	var key_name := OS.get_keycode_string(ThrownPickup.INTERACT_KEY)
	if not menu.is_empty():
		_label.text = ""   # the list says it
	elif target is PlacedWeapon:
		_label.text = "%s  %s" % [key_name, (target as PlacedWeapon).interact_prompt(player)]
	elif target is ThrownPickup:
		_label.text = (target as ThrownPickup).prompt(player)
	elif target != null and target.has_method("interact_prompt"):
		_label.text = "%s  %s" % [key_name, target.interact_prompt(player)]
	elif player.get("riding") != null:
		_label.text = ""   # (hold E to get off: the player knows; user 2026-09-25)
	elif torch_placing:
		if torch_mode == "throw":
			_label.text = ("Click  Throw the torch (%d m)" % roundi(Vector2((throw.land as Vector3).x - player.global_position.x,
					(throw.land as Vector3).z - player.global_position.z).length())) if not throw.is_empty() else "Look where to throw the torch"
		else:
			_label.text = ("Click  %s" % place.what) if not place.is_empty() else _place_hint()
	elif target == null and not _cands.is_empty() and not _placing and place.is_empty():
		# only things for the hold in reach (the river's drink): say so
		var hn: Node = _cands[0][1]
		_label.text = "Hold %s  %s" % [key_name, hn.interact_prompt(player)] if hn != null and hn.has_method("interact_prompt") else ""
	elif not place.is_empty():
		_label.text = "Release %s  %s" % [key_name, place.what]
	elif _placing:
		_label.text = _place_hint()
	else:
		_label.text = ""


## A tap of E: takes / swaps / picks up the highlighted item (or mounts a horse).
func _do_item() -> void:
	if target != null:
		_act(target)


## Does `n`'s action `id` ("": what a tap on it does).
func _act(n: Node, id := "") -> void:
	if id != "" and n.has_method("interact_action"):
		n.interact_action(player, id)
		_set_target(null)
		return
	if not (n is PlacedWeapon) and not (n is ThrownPickup) and n.has_method("interact"):
		n.interact(player)
		_set_target(null)
		return
	if n is PlacedWeapon:
		(n as PlacedWeapon).interact(player)
		_set_target(null)
		return
	if n is ThrownPickup:
		var pk := n as ThrownPickup
		var taker := ThrownPickup.find_taker(player, pk.kind, pk.model_kind)
		if pk.try_give(player) and taker:
			var k: Variant = player.weapons.find_key(taker)
			if k != null:
				var key := String(k)
				if not player.is_carried(key):
					player.set_carried(key, true)
				if player.hands_free and not player.is_usable(player.weapon_key):
					player.switch_weapon(key)   # hands empty for want of anything to hold: it is drawn
		_set_target(null)


# --- The hold-E list ------------------------------------------------------------------------------------------

## What `n` can do now, [{id, text}], the first what a tap does: its interact_actions() when it has them, else its
## prompt (each without a prompt's extra after GAP).
func _actions(n: Node) -> Array:
	if not is_instance_valid(n) or n.is_queued_for_deletion():
		return []
	var out: Array = []
	if n.has_method("interact_actions"):
		for a: Dictionary in n.interact_actions(player):
			var t := String(a.get("text", "")).get_slice(GAP, 0)
			if t != "":
				out.append({"id": String(a.get("id", "")), "text": t})
		if not out.is_empty():
			return out
	var t := _prompt_of(n).get_slice(GAP, 0)
	return [] if t == "" else [{"id": "", "text": t}]


## `n`'s prompt without the key ("Pick up Throwing Spear", "Skin the deer").
func _prompt_of(n: Node) -> String:
	if n is ThrownPickup:
		var s := (n as ThrownPickup).prompt(player)
		var k := OS.get_keycode_string(ThrownPickup.INTERACT_KEY) + "  "
		if s.begins_with(k):
			s = s.substr(k.length())
		return s.left(1).to_upper() + s.substr(1)
	if n.has_method("interact_prompt"):
		return String(n.interact_prompt(player))
	return ""


## E held past HOLD_S: the list of everything to do in reach (the highlighted first), headed by putting the weapon
## in the hands down. Stays shut when there is nothing to do in reach (a hold is then the placement) and in build
## mode (its E is its own).
func _open_menu() -> void:
	if is_instance_valid(BuildMode.current) and BuildMode.current.active:
		return
	var nodes: Array = []
	for c: Array in _cands:
		nodes.append(c[1])
	if nodes.has(_press_target):
		nodes.erase(_press_target)
		nodes.push_front(_press_target)
	var rows: Array = []
	if _can_place():
		rows.append({"node": null, "id": "place", "text": "Put %s down" % player.weapon.display_name})
	var acts := 0
	for n: Node in nodes:
		for a: Dictionary in _actions(n):
			if rows.size() >= MENU_MAX:
				break
			rows.append({"node": n, "id": a.id, "text": a.text})
			acts += 1
	if acts == 0:
		return
	menu = rows
	menu_i = 0
	_clear_rows()
	for r: Dictionary in menu:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rule := ColorRect.new()
		rule.custom_minimum_size = Vector2(3, 24)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(rule)
		var l := Label.new()
		l.text = String(r.text)
		l.add_theme_font_override("font", FrontierHUD.serif())
		l.add_theme_font_size_override("font_size", 21)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		_menu_rows.add_child(h)
	var foot := Label.new()
	foot.text = "Scroll to choose  ·  let go of %s" % OS.get_keycode_string(ThrownPickup.INTERACT_KEY)
	foot.add_theme_font_override("font", FrontierHUD.serif())
	foot.add_theme_font_size_override("font_size", 15)
	foot.add_theme_color_override("font_color", Color(0.9, 0.84, 0.7, 0.6))
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_rows.add_child(foot)
	_menu_style()
	_menu_box.visible = true
	_set_more("")
	_update_label()


## The chosen row in the HUD's gold with its rule, the rest dimmer.
func _menu_style() -> void:
	for i in mini(menu.size(), _menu_rows.get_child_count()):
		var h := _menu_rows.get_child(i) as HBoxContainer
		var on := i == menu_i
		(h.get_child(0) as ColorRect).color = FrontierHUD.GOLD if on else Color(0, 0, 0, 0)
		(h.get_child(1) as Label).add_theme_color_override("font_color",
				Color(0.98, 0.86, 0.56) if on else Color(0.9, 0.85, 0.75, 0.72))


## The put-down row says where it goes while chosen ("Lean Brown Bess against the tree").
func _menu_text() -> void:
	for i in mini(menu.size(), _menu_rows.get_child_count()):
		var id := String(menu[i].id)
		if id != "place":
			continue
		var t := String(menu[i].text)
		if i == menu_i and _placing:
			t = String(place.what) if not place.is_empty() else _place_hint()
		var l := (_menu_rows.get_child(i) as HBoxContainer).get_child(1) as Label
		if l.text != t:
			l.text = t


## What to look at while the placement has nowhere to put it.
func _place_hint() -> String:
	if _place_kind == "torch":
		return "Look at the ground, a wall or a tree to set the torch"
	return "Look at the ground, a wall, a tree or a rack to put it down"


func _close_menu() -> void:
	if menu.is_empty():
		return
	menu = []
	menu_i = 0
	_menu_box.visible = false
	_clear_rows()
	_update_label()


func _clear_rows() -> void:
	for c in _menu_rows.get_children():
		_menu_rows.remove_child(c)
		c.queue_free()


## A row's interactable while it still stands (null once taken or freed).
func _row_node(row: Dictionary) -> Node:
	var n: Variant = row.get("node")
	if typeof(n) != TYPE_OBJECT or not is_instance_valid(n) or (n as Node).is_queued_for_deletion():
		return null
	return n as Node


## E let go on the list: its chosen row is done, if it is still on offer (the carcass not taken, the fire not out).
func _do_row() -> void:
	var row: Dictionary = menu[menu_i]
	if row.id == "place":
		if _placing and not place.is_empty():
			_do_place()
		return
	var n := _row_node(row)
	if n == null:
		return
	for a: Dictionary in _actions(n):
		if a.id == row.id:
			_act(n, String(row.id))
			return


## "Hold E: 2 more" under the prompt when there is more to do in reach than the tap.
func _update_more() -> void:
	var n := 0
	if target != null and menu.is_empty() and not _placing:
		for c: Array in _cands:
			n += _actions(c[1]).size()
	_set_more("" if n < 2 else "Hold %s: %d more" % [OS.get_keycode_string(ThrownPickup.INTERACT_KEY), n - 1])


func _set_more(t: String) -> void:
	if _more and _more.text != t:
		_more.text = t


## E let go after holding it: the weapon in the hands goes where the placement shows.
func _do_place() -> void:
	if place.is_empty():
		return
	if bool(place.get("torch", false)):
		var pt: PlayerTorch = player.get("torch")
		if pt:
			pt.set_down(place.xf)
		_set_place({})
		return
	var key := player.weapon_key
	var w := player.weapon
	var pw := PlacedWeapon.from_weapon(w, key)
	get_tree().current_scene.add_child(pw)
	if place.kind == "rack":
		(place.rack as WeaponRack).place(pw, int(place.slot))
	else:
		pw.global_transform = place.xf
	if w.has_signal(&"sfx"):
		w.emit_signal(&"sfx", &"holster", pw.global_position)
	if w is Throwable and (w as Throwable).count > 1:
		# one spear / tomahawk / dart is put down; the rest stay in hand
		pw.state.count = 1
		(w as Throwable).count -= 1
	else:
		if w is Throwable:
			(w as Throwable).count = 0   # the last one is the placed one (a pickup must not add to a stale count)
		player.set_carried(key, false)
	_set_place({})


## The demo's rack of three loaded muskets and barrel of three spears beside the spawn (user 2026-09-25:
## "place rifles in bins ... for quick equip without reloading"), unless the level has racks of its own.
func _ensure_demo_props() -> void:
	if not get_tree().get_nodes_in_group(WeaponRack.GROUP).is_empty() or player == null or SurvivalBridge.bare_of(get_tree()):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fwd := -player.global_transform.basis.z
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	for spec in [["rack", "musket", right * 2.4 + fwd * 1.6], ["barrel", "spear", -right * 2.4 + fwd * 1.6]]:
		var w: Weapon = player.weapons.get(String(spec[1]))
		if w == null:
			continue
		var r := WeaponRack.new()
		r.style = String(spec[0])
		r.slots = 3 if r.style == "rack" else 3
		r.name = "Demo" + r.style.capitalize()
		scene.add_child(r)
		var at: Vector3 = player.global_position + spec[2]
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			at.y = (hit.position as Vector3).y
		r.global_transform = Transform3D(Basis.looking_at(-(player.global_position - at) * Vector3(1, 0, 1), Vector3.UP), at)
		for i in r.slots:
			var pw := PlacedWeapon.from_weapon(w, String(spec[1]))
			pw.state = WeaponState.capture(w)
			if w is Throwable:
				pw.state.count = 1
			scene.add_child(pw)
			r.place(pw, i)
