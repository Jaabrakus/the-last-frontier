class_name DeathRule
extends Node
## What dying costs (user 2026-09-27: "drop the pack"; come back "where you last slept"): the player comes back after
## DEATH_S at their home (where they last slept, SurvivalSleep; the fort's yard until they have slept anywhere) with
## what they wear (the Loadout: clothes, slung weapons) and their skills; the pack's contents and the torches carried
## are left where they fell, in a PackDrop, unmarked (user 2026-09-27: "it should be on the user to remember"; the
## on-screen marker with its distance is gone). The survival core comes back with the player (SurvivalBridge.revive). A save follows the respawn
## (SaveGame). DeathRule saves its part: the home and the drops (SaveParts calls save_data / load_data).

signal respawned

const DEATH_S := 5.0
## The fort's yard, where a player who has not slept anywhere comes back.
const FORT_HOME := Vector3(0.0, 0.1, 6.0)

var player: FrontierPlayer
## Where the player comes back (the last sleep), and facing.
var home := FORT_HOME
var home_yaw := 0.0
var has_home := false

var _dead_t := -1.0
var _death_at := Vector3.ZERO
var _was_sleeping := false
var _layer: CanvasLayer
var _msg: Label


func _ready() -> void:
	add_to_group(&"death_rule")
	if player:
		player.died.connect(_on_died)
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_msg = Label.new()
	_msg.set_anchors_preset(Control.PRESET_CENTER)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 22)
	_msg.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	_msg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_msg.add_theme_constant_override("shadow_offset_x", 1)
	_msg.add_theme_constant_override("shadow_offset_y", 1)
	_msg.position = Vector2(-320, 40)
	_msg.size = Vector2(640, 60)
	_msg.visible = false
	_layer.add_child(_msg)


static func find(tree: SceneTree) -> DeathRule:
	return tree.get_first_node_in_group(&"death_rule") as DeathRule if tree else null


func _process(delta: float) -> void:
	if player == null:
		return
	# home: where the player lies down to sleep
	var b := SurvivalBridge.find(get_tree())
	var sleeping := b != null and b.sleeper != null and b.sleeper.sleeping
	if sleeping and not _was_sleeping:
		home = player.global_position
		home_yaw = player.yaw
		has_home = true
	_was_sleeping = sleeping
	if _dead_t >= 0.0:
		_dead_t += delta
		if _dead_t >= DEATH_S:
			respawn()


func _on_died(_dir: Vector2) -> void:
	if _dead_t >= 0.0:
		return
	_dead_t = 0.0
	_death_at = player.global_position
	var b := SurvivalBridge.find(get_tree())
	var cause := b.death_cause if b else ""
	var how: String = {"starvation": "You starved to death", "cold": "You froze to death", "bleeding": "You bled to death"}.get(cause, "You died")
	_msg.text = "%s.\nYou will wake %s; your pack lies where you fell." % [how, "where you last slept" if has_home else "at the fort"]
	_msg.visible = true


## Back from the dead: the pack left where the player fell, the player at home with what they wear.
func respawn() -> void:
	_dead_t = -1.0
	_msg.visible = false
	drop_pack(_death_at)
	player.respawn()
	var at := home
	at.y = FrontierTerrain.height_at(at.x, at.z) + 0.1 if not has_home else home.y + 0.1
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.yaw = home_yaw
	player.rotation.y = home_yaw
	respawned.emit()
	var sg := SaveGame.find(get_tree())
	if sg:
		sg.save_soon("auto")


## Leaves the pack's contents and the torches carried where the player fell (nothing: no drop).
func drop_pack(at: Vector3) -> PackDrop:
	var items: Array = (player.inventory_pack as Array).duplicate(true)
	var torches: Array = []
	if player.torch:
		for bl in player.torch.pack:
			torches.append(float(bl))
		if player.torch.held != null:
			torches.append(player.torch.held.burn_left)
	if items.is_empty() and torches.is_empty():
		return null
	var pd := PackDrop.new()
	pd.name = "PackDrop"
	pd.items = items
	pd.torches = torches
	var b := SurvivalBridge.find(get_tree())
	pd.dropped_min = b.core.state.minutes if b and b.core else 0.0
	pd.scavenged_to = pd.dropped_min
	get_tree().current_scene.add_child(pd)
	pd.global_position = Vector3(at.x, FrontierTerrain.height_at(at.x, at.z), at.z) if absf(at.y - FrontierTerrain.height_at(at.x, at.z)) < 1.5 else at
	player.inventory_pack = []
	if player.torch:
		var none: Array[float] = []
		player.torch.pack = none
		if player.torch.held != null:
			player.torch._unhold()            # (death usually lets it fall already: a DroppedTorch where they fell)
	return pd


# --- Its part of a save ------------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var drops := []
	for n in get_tree().get_nodes_in_group(PackDrop.GROUP):
		drops.append((n as PackDrop).to_dict())
	return {"home": SaveParts.v3(home), "home_yaw": home_yaw, "has_home": has_home, "drops": drops}


func load_data(d: Dictionary) -> void:
	home = SaveParts.to_v3(d.get("home"), FORT_HOME)
	home_yaw = float(d.get("home_yaw", 0.0))
	has_home = bool(d.get("has_home", false))
	for n in get_tree().get_nodes_in_group(PackDrop.GROUP):
		n.queue_free()
	for e in d.get("drops", []):
		get_tree().current_scene.add_child(PackDrop.from_dict(e))
