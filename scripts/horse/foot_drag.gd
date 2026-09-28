class_name FootDrag
extends Node
## Dragging a dead animal on foot (user 2026-09-27: dragging game on foot, "allow the ability to hold a torch"): E at a
## carcass's neck -- "Drag the deer" -- and a short rope from the left hand to a loop round its neck drags it head
## first behind the player, who walks forward. It is the horse's carcass rope (CarcassLoad on SkidLoad's rod: the
## ground, friction, trunks and rocks, a trail of blood) with the hand in place of the singletree. The right hand
## stays free: T takes a torch into it (PlayerTorch, the hands-free hold). The gun goes on the back for the drag and
## comes back to the hands when E lets go.
##
## The pull (SkidLoad.pull_kgf: the carcass's friction and the slope) caps the walk (haul.json "foot"): a fox at a
## jog, a wolf or a doe at a slow walk, a buck slower; heavier or up a steep bank slower still, down to an extreme crawl
## (nothing is refused). No sprint. Caught on a trunk, the rope holds the player (they cannot walk off from it): step round it, or
## it is worked free after a moment. The left arm reaches back along the rope (a ReachIK on the left hand).
##
## E again, a jump, drawing a weapon, a heavy hit, mounting, kneeling to work, a vault or death let it go: it lies
## where it stopped, to be skinned or dragged again. When the horse's hitch is within reach of the neck, E there is
## the horse's (HorseHaul.offers). Every player has one (FrontierPlayer: foot_drag).
##
## Its E (PlayerInteractor's "any other interactable"): the offer at the neck and, while dragging, "Let go of the
## deer" at the chest (the carcass is behind the player, out of the view cone).
## The animals are CC0 stand-in models (assets/wildlife/quaternius/SOURCE.md); the rope is drawn here.

## Seconds for the arm to reach back along the rope, or to come back.
const ARM_FADE_S := 0.25
## The hand this far from the shoulder toward the rope (m; ReachIK keeps it within the arm's reach) and this far out
## from the body (skeleton space +X is the character's left), so the arm does not go through the hip.
const ARM_REACH_M := 0.7
const ARM_OUT_M := 0.1
## The rope grabbed at arm's length is taken up to rope_m at this rate (m/s).
const REEL_MPS := 0.8
## An E waits this long for the gun to go on the back (s).
const PENDING_S := 1.5
## Added to the offer's E score (PlayerInteractor: 0..1 off the view, plus 0..1 of the reach): an item as much in view
## and in reach wins.
const OFFER_BIAS := 0.35

var player: FrontierPlayer
## The carcass on the rope, or null.
var load: CarcassLoad = null
var interact_reach := 2.2
## The walk cap the pull gives (m/s; INF with nothing on the rope).
var cap := INF
## Seconds the load has been caught.
var jam_t := 0.0
## Why the last drag ended ("e", "jump", "weapon", "hit", "died", "mounted", "kneeling", "vault", "gone"; tests).
var last_let_go := ""

var _offer := {}
## An E whose gun is still going on the back (the hands were busy, a torch passing): taken when the hands are free.
var _pending: Node3D = null
var _pending_t := 0.0
var _gun := ""             ## the weapon put on the back for the drag (drawn again when E lets go)
var _ik: ReachIK
var _ik_w := 0.0
var _last_target := Vector3.INF
var _mi: MeshInstance3D
var _mesh: ImmediateMesh
var _hand := -1
var _shoulder := -1
## The left palm after every modifier (global; Skeleton3D.skeleton_updated): outside the update the skeleton gives the
## pose before the modifiers, which is not where the reach put the hand.
var hand_final := Vector3.INF
var _exceptions: Array[PhysicsBody3D] = []


static func install(p: FrontierPlayer) -> FootDrag:
	var f := FootDrag.new()
	f.name = "FootDrag"
	f.player = p
	p.add_child(f)
	return f


static func cfg() -> Dictionary:
	return HorseHaul.data().get("foot", {})


## Walk cap (m/s) for a pull of `kgf` (haul.json "foot"). Never 0: past max_kgf it falls as max_kgf / kgf toward
## extreme_mps (user 2026-09-27: too heavy "just make it where it is extreme slow").
static func cap_for(kgf: float) -> float:
	var c := cfg()
	var easy := float(c.get("easy_kgf", 6.0))
	var walk := float(c.get("walk_kgf", 15.0))
	var hard := float(c.get("hard_kgf", 30.0))
	var mx := float(c.get("max_kgf", 45.0))
	var jog_v := float(c.get("cap_jog_mps", 2.4))
	var walk_v := float(c.get("cap_walk_mps", 1.5))
	var hard_v := float(c.get("cap_hard_mps", 1.0))
	var crawl := float(c.get("cap_crawl_mps", 0.45))
	if kgf <= easy:
		return jog_v
	if kgf <= walk:
		return lerpf(jog_v, walk_v, (kgf - easy) / (walk - easy))
	if kgf <= hard:
		return lerpf(walk_v, hard_v, (kgf - walk) / (hard - walk))
	if kgf <= mx:
		return lerpf(hard_v, crawl, (kgf - hard) / (mx - hard))
	return maxf(crawl * mx / kgf, float(c.get("extreme_mps", 0.05)))


## A carcass of `kg` past max_kgf on the level: dragged at a crawl or slower (the prompt says so).
static func very_heavy(kg: float) -> bool:
	var mu := float((HorseHaul.data().get("carcass", {}) as Dictionary).get("mu_axial", 0.5))
	return kg * mu > float(cfg().get("max_kgf", 45.0))


func _ready() -> void:
	add_to_group(PlacedWeapon.GROUP)
	process_physics_priority = 5            # after the player has moved, before the load
	interact_reach = float(cfg().get("reach_m", 2.2))
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "Rope"
	_mi.mesh = _mesh
	_mi.top_level = true
	_mi.visible = false
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	if player:
		player.hurt.connect(_on_hurt)
		player.died.connect(func(_d: Vector2) -> void: let_go("died"))
	_setup_ik.call_deferred()


## The left arm's reach along the rope: a ReachIK on the skeleton, after the arm poses and the torch's hold.
func _setup_ik() -> void:
	var sk := player.skeleton if player else null
	if sk == null:
		return
	_ik = PalmReachIK.new()
	_ik.name = "DragGripIK"
	sk.add_child(_ik)
	# before the props' last placement and the body mesh (which keeps itself last)
	for i in sk.get_child_count():
		var c := sk.get_child(i)
		if c is CharacterBodyMesh or String(c.name) == "HandPropsFinal":
			sk.move_child(_ik, i)
			break
	_ik.set_target("l", Callable(self, "_ik_target"), 0.0)
	_hand = sk.find_bone("l_palm")
	_shoulder = sk.find_bone("l_shoulder")
	sk.skeleton_updated.connect(_on_skeleton_updated)


func _on_skeleton_updated() -> void:
	var sk := player.skeleton
	if sk and _hand >= 0:
		hand_final = sk.global_transform * sk.get_bone_global_pose(_hand).origin


# --- What pulls (SkidLoad's side) ----------------------------------------------------------------------------

## The rope's end in the left hand (the palm; global); the left hip without the rig.
func hitch_point() -> Vector3:
	if hand_final != Vector3.INF and hand_final.distance_to(player.global_position) < 2.5:
		return hand_final
	return player.global_position + Vector3.UP * 0.85 + player.global_basis.x * -0.25


func puller() -> CollisionObject3D:
	return player


func puller_speed() -> float:
	return player.horizontal_speed()


## The load went from under the rope (CarcassLoad: its animal was cleaned up).
func unhitch() -> Node3D:
	return let_go("gone")


# --- Dragging ------------------------------------------------------------------------------------------------

## Takes dead animal `a` (CarcassLoad.haulable) on the rope. False when it cannot be taken now.
func start(a: Node3D) -> bool:
	if load != null or player == null or player.is_dead or player.riding != null or player.kneeling != null or player.pushing != null:
		return false
	if not CarcassLoad.haulable(a):
		return false
	if not player.hands_free:
		if _pending == null and player.weapon and player.weapon.active and player.is_carried(player.weapon_key):
			_gun = player.weapon_key
			player.toggle_hands_free()
		if not player.hands_free:
			if _pending == null and player._held_switch != "":
				_pending = a                     # the gun goes on the back as soon as the hands are ready
				_pending_t = PENDING_S
				return true
			if _pending == null:
				_gun = ""
				_notice("Your hands are busy")
			return false
	_pending = null
	var s := CarcassLoad.from_carcass(a, HorseHaul.data(), DisplayServer.get_name() != "headless")
	a.get_parent().add_child(s)
	var rope := float(cfg().get("rope_m", 1.2))
	s.hitch(self, clampf(hitch_point().distance_to(s.front), rope, rope + 1.5))
	load = s
	jam_t = 0.0
	_exceptions.clear()
	for b in [s.body] + a.find_children("*", "PhysicsBody3D", true, false) + ([a] if a is PhysicsBody3D else []):
		if b is PhysicsBody3D and is_instance_valid(b) and b != player:
			player.add_collision_exception_with(b)
			_exceptions.append(b)
	_notice("Dragging the %s (E lets go)" % s.load_name())
	return true


## Lets the load go (why: see last_let_go): it lies where it stopped. After E the gun put away for it comes back.
## Returns the animal (null when there was none).
func let_go(why := "") -> Node3D:
	var s := load
	load = null
	cap = INF
	jam_t = 0.0
	if player:
		player.drag_speed_cap = INF
	if s == null:
		return null
	last_let_go = why
	for b in _exceptions:
		if is_instance_valid(b) and player:
			player.remove_collision_exception_with(b)
	_exceptions.clear()
	var a: Node3D = null
	if is_instance_valid(s):
		a = s.release()
		s.queue_free()
	var gun := _gun
	_gun = ""
	if why == "e" and gun != "" and player and player.hands_free and player.weapon_key == gun and not player.is_dead:
		player.toggle_hands_free()          # the gun back to the hands
	return a


func _on_hurt(_dir: Vector2, _amount: float, heavy: bool) -> void:
	if heavy and load != null:
		let_go("hit")


## What ends a drag now ("" = nothing).
func _let_go_reason() -> String:
	if player.is_dead:
		return "died"
	if player.riding != null:
		return "mounted"
	if player.kneeling != null:
		return "kneeling"
	if not player.hands_free:
		return "weapon"
	if player.traversal and player.traversal.showing:
		return "vault"
	if Input.is_action_just_pressed("jump"):
		return "jump"
	return ""


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if load != null and not is_instance_valid(load):
		load = null
		let_go("gone")
	if load != null:
		var why := _let_go_reason()
		if why != "":
			let_go(why)
	if _pending != null:
		_pending_t -= delta
		if not is_instance_valid(_pending) or _pending_t <= 0.0 or player.is_dead:
			_pending = null
			_gun = ""
		elif player.hands_free:
			start(_pending)
	if load != null:
		# the rope taken up to its length (as long as the reach when it was grabbed)
		load.chain_len = move_toward(load.chain_len, float(cfg().get("rope_m", 1.2)), REEL_MPS * delta)
		_update_cap(delta)
		_offer = {}
	else:
		_offer = _find_offer()
	_ik_w = move_toward(_ik_w, 1.0 if load != null else 0.0, delta / ARM_FADE_S)
	if _ik:
		_ik.set_target("l", Callable(self, "_ik_target"), _ik_w)


func _process(_delta: float) -> void:
	_draw_rope()


func _update_cap(delta: float) -> void:
	var c := cfg()
	var nm := load.load_name()
	cap = cap_for(load.pull_kgf)
	var js := float(c.get("jam_stretch_m", 0.35))
	var after := float(c.get("jam_free_after_s", 1.5))
	if load.stretch > js:
		if jam_t <= 0.0:
			_notice("The %s is caught: step round to free it" % nm)
		if jam_t + delta > after:
			load.work_free(float(c.get("jam_free_for_s", 1.0)), jam_t <= after)
		jam_t += delta
		_hold_player(js)
	else:
		jam_t = maxf(jam_t - delta * 4.0, 0.0)
	player.drag_speed_cap = cap


## Caught: the rope holds the player within its length (and `slack`) of the load (they cannot walk off from it).
func _hold_player(slack: float) -> void:
	var d := hitch_point() - load.front
	d.y = 0.0
	var over := d.length() - (load.chain_len + slack)
	if over <= 0.0 or d.length() < 1e-4:
		return
	var n := d.normalized()
	player.global_position -= n * over
	var away := player.velocity.dot(n)
	if away > 0.0:
		player.velocity -= n * away


# --- E -------------------------------------------------------------------------------------------------------

## On foot by a dead animal's neck, nothing on the rope: {kind "drag", point, animal, text}, or {}.
func _find_offer() -> Dictionary:
	var p := player
	if p.is_dead or p.riding != null or p.kneeling != null or p.pushing != null:
		return {}
	var best := {}
	var bd := INF
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		var a := n as Node3D
		if a == null or _flat(a.global_position, p.global_position) > interact_reach + 2.5 or not CarcassLoad.haulable(a):
			continue
		var pt := CarcassLoad.neck_point(a)
		var d := _flat(pt, p.global_position)
		if d > interact_reach or d >= bd or _horse_offers(a):
			continue
		bd = d
		best = {"point": pt, "animal": a}
	if best.is_empty():
		return {}
	var kg := CarcassLoad.mass_of_animal(best.animal, HorseHaul.data())
	var nm := CarcassLoad.name_of(best.animal)
	best["kind"] = "drag"
	best["text"] = "Drag the %s" % nm if not very_heavy(kg) else "Drag the %s (about %d kg: very slow)" % [nm, roundi(kg)]
	return best


## A horse whose hitch is within reach offers `a` now (E at the neck is then the horse's).
func _horse_offers(a: Node) -> bool:
	for n in get_tree().get_nodes_in_group(PlacedWeapon.GROUP):
		if n is HorseHaul and (n as HorseHaul).offers(a):
			return true
	return false


func interact_point() -> Vector3:
	if load != null:
		return _chest()
	return _offer.get("point", Vector3.INF)


## Dragging, "Let go" is the one thing E does (0 at the chest); else the flat distance to the neck.
func distance_from(pt: Vector3) -> float:
	if load != null:
		return 0.0
	if _offer.is_empty():
		return INF
	return _flat(pt, _offer.point)


## The offer scores behind the items in reach (PlayerInteractor): a tomahawk or an arrow stuck in the carcass is
## picked up first, looked at; dragging, "Let go" is not.
func interact_bias() -> float:
	return 0.0 if load != null else OFFER_BIAS


func interact_prompt(_p: Node) -> String:
	if load != null:
		return "Let go of the %s" % load.load_name()
	return String(_offer.get("text", ""))


## Nothing glows (as the horse's hitch): the same interactable goes on to "Let go", so a glow put on the animal for the
## offer would stay on it through the drag; the prompt says what E does.
func highlight_targets() -> Array:
	return []


func interact(_p: Node) -> bool:
	if load != null:
		let_go("e")
		return true
	match String(_offer.get("kind", "")):
		"drag":
			return start(_offer.animal)
	return false


# --- The arm and the rope ------------------------------------------------------------------------------------

## The left hand's target (skeleton space): from the shoulder toward the rope's end at the neck, a little out
## from the body. Letting go, the last target while the arm comes back.
func _ik_target(_side: String) -> Vector3:
	var sk := player.skeleton
	if load == null or not is_instance_valid(load) or sk == null or _shoulder < 0:
		return _last_target
	var a := sk.get_bone_global_pose(_shoulder).origin
	var to := sk.global_transform.affine_inverse() * load.chain_point() - a
	if to.length() < 1e-4:
		return _last_target
	_last_target = a + to.normalized() * ARM_REACH_M + Vector3(ARM_OUT_M, 0.0, 0.0)
	return _last_target


func _draw_rope() -> void:
	var on := load != null and is_instance_valid(load) and DisplayServer.get_name() != "headless"
	_mi.visible = on
	if not on:
		return
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, CarcassLoad.rope_material())
	HorseHaul.ribbon(_mesh, HorseHaul.sag(hitch_point(), load.chain_point(), load.chain_len + 0.01, 14), 0.02, 0.01)
	_mesh.surface_end()


func _chest() -> Vector3:
	return player.global_position + Vector3.UP * 1.3 - player.global_basis.z * 0.2


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _notice(text: String) -> void:
	var it: Node = player.get("interactor") if player else null
	if it and it.has_method(&"notice"):
		it.call(&"notice", text, 2.5)

