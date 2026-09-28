class_name ThrowableKit
## Builds the thrown weapons for a FrontierPlayer without touching player.gd, the
## way player._build_weapons() builds the bow and the flintlocks: one weapon node,
## a BoneAttachment3D on the right-hand prop bone and the model under it. The model
## is placed by the weapon itself each frame (Throwable._place_held).
##
##   ThrowableKit.install(player)                   weapons only (tests, preview): they
##                                                  live under player/Throwables and are
##                                                  NOT in player.weapons / weapon_order
##   ThrowableKit.install(player, KEYS, true)       also add them to player.weapons and
##                                                  player.weapon_order (after the anim
##                                                  rebuild knows their profiles)
##
## Keys: "spear", "tomahawk" (trade tomahawk, spike on the poll), "tomahawk_pipe" (the
## pipe tomahawk variant; same weapon, ammo kind "tomahawk") and "atlatl".
##
## Also adds to the player, once: a ThrowableAudio (placeholder sounds, no gunshot) and, for
## weapons outside the roster (register = false: tests, previews), a ThrowableArc. Registered
## weapons use the player's own TrajectoryPreview, which draws the arc of any weapon with
## trajectory_params() (one arc; THROW). Registering also applies the weapon balance
## (WeaponBalance.apply, weapons balance hook H2).

const KEYS: Array[String] = ["spear", "tomahawk", "atlatl"]


static func create(key: String) -> Throwable:
	match key:
		"spear": return ThrowableSpear.new()
		"tomahawk": return ThrowableTomahawk.new()
		"tomahawk_pipe":
			var t := ThrowableTomahawk.new()
			t.pipe = true
			return t
		"atlatl": return ThrowableAtlatl.new()
	push_error("Unknown throwable " + key)
	return null


static func install(player: FrontierPlayer, keys: Array[String] = KEYS, register := false) -> Dictionary:
	var out := {}
	var holder := player.get_node_or_null("Throwables")
	if holder == null:
		holder = Node.new()
		holder.name = "Throwables"
		player.add_child(holder)
	var audio := player.get_node_or_null("ThrowableAudio") as ThrowableAudio
	if audio == null:
		audio = ThrowableAudio.new()
		audio.name = "ThrowableAudio"
		audio.player = player
		player.add_child(audio)
	for key in keys:
		# Installed already (install called again): reuse it. A second weapon of the same
		# ammo kind outside the roster would take pickups that the roster one never sees.
		var have := holder.get_node_or_null(NodePath(key.to_pascal_case())) as Throwable
		if have:
			out[key] = have
			_register(player, key, have, register)
			continue
		var w := create(key)
		if w == null:
			continue
		w.name = key.to_pascal_case()
		w.player = player
		holder.add_child(w)
		var att := BoneAttachment3D.new()
		att.name = key + "_socket"
		att.bone_name = "l_hand_prop_attachment" if w.hand == Weapon.Hand.LEFT else "r_hand_prop_attachment"
		player.skeleton.add_child(att)
		var model := ThrowableModels.build(w.model_kind)
		model.visible = false
		att.add_child(model)
		w.model = model
		w.socket = att
		w.muzzle = model.get_node_or_null("Muzzle") as Marker3D
		w._setup_model()
		audio.watch(w, key)
		out[key] = w
		_register(player, key, w, register)
	if not register and player.get_node_or_null("ThrowableArc") == null:
		var arc := ThrowableArc.new()
		arc.name = "ThrowableArc"
		arc.player = player
		player.add_child(arc)
	return out


static func _register(player: FrontierPlayer, key: String, w: Throwable, register: bool) -> void:
	if not register:
		return
	WeaponBalance.apply(w, key)   # data/weapons/ballistics.json (weapons balance hook H2)
	player.weapons[key] = w
	if not key in player.weapon_order:
		player.weapon_order.append(key)
