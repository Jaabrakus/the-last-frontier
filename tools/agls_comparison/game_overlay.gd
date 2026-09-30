extends CanvasLayer
## Worktree controls for testing the approved movement and bow adapters in the real game.
var player: FrontierPlayer
var label: Label

static func install(target: FrontierPlayer) -> void:
	var overlay := new()
	overlay.player = target
	target.add_child(overlay)

func _ready() -> void:
	layer = 80
	label = Label.new()
	label.position = Vector2(20, 72)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.8, 0.94, 1.0))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	_refresh()
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(player): return
	if "--frontier-legacy" in OS.get_cmdline_user_args():
		player.switch_weapon("bow")
	elif not player.hands_free:
		player.toggle_hands_free()
	print("FRONTIER_LEGACY_GAME_PREVIEW_READY weapon=", player.weapon_key)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or player.traversal == null:
		return
	var key: int = event.physical_keycode
	if key in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		if player.traversal.set_legacy_vault_hand("left" if key == KEY_BRACKETLEFT else "right"):
			_refresh()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	var hand := player.traversal.legacy_vault_hand if player.traversal != null else "left"
	label.text = "Frontier Legacy — WORKTREE · 12 approved movement clips + 7 bow clips\nWASD move · Alt walk · Shift sprint · Space jump/vault · C crouch\n1 bow · hold LMB draw / release fire · RMB let down · R arrows · H holster\n[ left-hand vault · ] right-hand vault · selected: " + hand
