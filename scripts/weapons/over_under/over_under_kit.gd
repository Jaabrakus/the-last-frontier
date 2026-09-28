class_name OverUnderKit
## Installs the over-under on a FrontierPlayer without touching player.gd, the way
## player._build_weapons() builds the musket: one weapon node under player/Weapons, a
## BoneAttachment3D on the right-hand prop bone and the model under it with the musket's attach
## transform (player.musket_offset: the fixed half turn, prop +Z = barrel, +Y = up), then the
## balance row (WeaponBalance.apply(w, "over_under"), and the row's mechanism block).
##
##   OverUnderKit.install(player)          build it, add it to player.weapons and append
##                                         "over_under" to player.weapon_order (idempotent)
##   OverUnderKit.install(player, false)   build it only (not in the roster)
##   OverUnderKit.select(player)           switch to it (player.switch_weapon("over_under"))
##
## Integration (weapons_balance_design.md 3.3): hook H4 calls install(self) in
## player._build_weapons(), after the throwables are registered and before anim.setup(), so
## PlayerAnim and WeaponAudio connect it like any other weapon. H5 adds its number key, H6 the
## graph alias "over_under" -> "musket" in PlayerAnim, H9 the WeaponAudio alias.
##
## Until those hooks land (dev builds, tests, the preview), the kit bridges what is missing, each
## part switching itself off once its hook is in:
##   * the number key of its slot is added to the InputMap when absent (H5)
##   * PlayerAnim: the weapon's signals are connected with the graph key "musket", and on each
##     draw the weapon asks PlayerAnim for the musket's rows (OverUnderMusket._on_equip), while
##     PlayerAnim has no GRAPH_ALIAS (H6) and does not know "over_under"
##   * WeaponAudio (added by the level after the player): its handlers are connected with the
##     musket's sound key (H9)
## Either order works (ensure_routing): installed after PlayerAnim.setup / WeaponAudio._ready the
## kit connects the gun; installed before them (hook H4 landing ahead of H6 / H9) they connect it
## under the roster key "over_under", which has no graph rows and no sounds (no fire kick, no
## reload or turnover clips, a silent shot), so the kit re-binds those connections to the musket's
## keys at the end of the install frame and again on every draw.

const KEY := "over_under"
const GRAPH_KEY := "musket"
const NODE_NAME := "OverUnder"
const SOCKET := "over_under_socket"


static func install(player: FrontierPlayer, register := true) -> OverUnderMusket:
	var w := player.weapons.get(KEY) as OverUnderMusket
	if w == null:
		w = player.get_node_or_null("Weapons/" + NODE_NAME) as OverUnderMusket
	if w == null:
		w = OverUnderMusket.new()
		w.name = NODE_NAME
		w.player = player
		var holder := player.get_node_or_null("Weapons")
		if holder == null:
			holder = Node.new()
			holder.name = "Weapons"
			player.add_child(holder)
		holder.add_child(w)
		var att := BoneAttachment3D.new()
		att.name = SOCKET
		att.bone_name = "l_hand_prop_attachment" if w.hand == Weapon.Hand.LEFT else "r_hand_prop_attachment"
		player.skeleton.add_child(att)
		var model := OverUnderModel.build()
		model.transform = player.musket_offset
		model.visible = false
		att.add_child(model)
		w.bind_model(model)
		apply_balance(w)
		w.reserve = int(w.mechanism.get("start_reserve", w.reserve))
	if register:
		_register(player, w)
	return w


## Switches the player to the over-under (installing it first when needed).
static func select(player: FrontierPlayer) -> OverUnderMusket:
	var w := install(player, true)
	player.switch_weapon(KEY)
	return w


## WeaponBalance.apply(w, "over_under") and the row's mechanism block, when the balance loader
## exists (script defaults otherwise; they equal the row). Returns apply()'s report, or {}.
static func apply_balance(w: OverUnderMusket) -> Dictionary:
	var bal: Variant = _balance_script()
	if bal == null:
		return {}
	var report: Dictionary = bal.call("apply", w, KEY)
	var r: Dictionary = bal.call("row", KEY)
	if r.get("mechanism") is Dictionary:
		w.apply_mechanism(r.mechanism)
	return report


## The graph weapon key the over-under plays: PlayerAnim.GRAPH_ALIAS once hook H6 is in,
## "over_under" if the graph ever gets rows of its own, "musket" before.
static func graph_key(player: FrontierPlayer) -> String:
	var alias: Variant = _anim_alias(player)
	if alias != null:
		return String(alias.get(KEY, KEY))
	return KEY if _anim_knows(player, KEY) else GRAPH_KEY


## True while PlayerAnim runs but knows neither "over_under" nor the alias (before hook H6):
## the weapon then asks it for the musket's rows on every draw.
static func anim_needs_alias(player: FrontierPlayer) -> bool:
	if player == null or player.anim == null or not player.anim.is_ready():
		return false
	if _anim_alias(player) != null:
		return false
	return not _anim_knows(player, KEY)


## PlayerAnim's graph index has rows for weapon `key`.
static func _anim_knows(player: FrontierPlayer, key: String) -> bool:
	if player == null or player.anim == null:
		return false
	var idx: Variant = player.anim.get("index")
	return idx != null and idx.get("weapons") is Dictionary and (idx.weapons as Dictionary).has(key)


## Makes PlayerAnim and WeaponAudio hear the over-under under the keys they have rows and sounds
## for, whichever was set up first (see the header). Idempotent and cheap: _register calls it,
## once more at the end of the frame the gun was installed in (after player._ready and the
## level's WeaponAudio), and OverUnderMusket._on_equip on every draw.
static func ensure_routing(player: FrontierPlayer, w: OverUnderMusket) -> void:
	if player == null or w == null or not is_instance_valid(player) or not is_instance_valid(w):
		return
	_bridge_anim(player, w)
	_bridge_audio(player, w)


## The key a signal's connection to target.method is bound with ([] when unbound, null when
## there is no such connection). Godot keeps one connection per target method, whatever it binds.
static func bound_key(sig: Signal, target: Object, method: String) -> Variant:
	for c: Dictionary in sig.get_connections():
		var cb: Callable = c.callable
		if cb.get_object() == target and cb.get_method() == method:
			var args := cb.get_bound_arguments()
			return args[0] if args.size() == 1 else args
	return null


## Connects `sig` to target.method bound with `key`, replacing a connection bound with another key.
static func _rebind(sig: Signal, target: Object, method: String, key: String) -> void:
	for c: Dictionary in sig.get_connections():
		var cb: Callable = c.callable
		if cb.get_object() == target and cb.get_method() == method:
			if cb.get_bound_arguments() == [key]:
				return
			sig.disconnect(cb)
	sig.connect(Callable(target, method).bind(key))


static func _anim_alias(player: FrontierPlayer) -> Variant:
	if player == null or player.anim == null:
		return null
	var s := player.anim.get_script() as Script
	var consts: Dictionary = s.get_script_constant_map() if s else {}
	return consts.get("GRAPH_ALIAS") if consts.get("GRAPH_ALIAS") is Dictionary else null


static func _register(player: FrontierPlayer, w: OverUnderMusket) -> void:
	player.weapons[KEY] = w
	if not KEY in player.weapon_order:
		player.weapon_order.append(KEY)
	_ensure_number_keys(player.weapon_order.size())
	ensure_routing(player, w)
	if not w.has_meta(&"routing_deferred"):
		# Hook H4 installs the gun inside player._ready, before PlayerAnim.setup and before the
		# level adds WeaponAudio: check their connections once both exist.
		w.set_meta(&"routing_deferred", true)
		(func() -> void: ensure_routing(player, w)).call_deferred()


## player._unhandled_input asks is_action_pressed("weapon_%d") for every slot; an action missing
## from the InputMap logs an error on every event (hook H5 adds it to InputSetup).
static func _ensure_number_keys(slots: int) -> void:
	for i in range(1, mini(slots, 9) + 1):
		var action := "weapon_%d" % i
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_0 + i
		InputMap.action_add_event(action, e)


## PlayerAnim connects weapon signals once, in setup(): a weapon installed later is connected here
## with its graph key (the musket's rows before H6); one PlayerAnim.setup already connected under
## the roster key "over_under" that the graph does not know (H4 before H6) is re-bound to it.
static func _bridge_anim(player: FrontierPlayer, w: OverUnderMusket) -> void:
	var anim := player.anim
	if anim == null or not anim.is_ready():
		return
	var gk := graph_key(player)
	for pair: Array in [[w.fired, "_on_fired"], [w.action_started, "_on_action"],
			[w.action_cancelled, "_on_action_cancelled"]]:
		if anim.has_method(pair[1]):
			_rebind(pair[0], anim, pair[1], gk)
	w.set_meta(&"anim_bridged", true)


## WeaponAudio connects in its _ready (the level adds it after the player): a weapon installed
## later is connected here with the musket's sound key; one its _ready already connected under
## the roster key (H4 before H9: no "over_under_*" sounds exist, a silent shot) is voiced as the
## musket, which is what H9's alias does (left alone once the sound manifest has an "over_under_shot" entry).
static func _bridge_audio(player: FrontierPlayer, w: OverUnderMusket) -> void:
	var wa := player.get_node_or_null("WeaponAudio")
	if wa == null or not ("_key_of" in wa):
		return
	var keys: Dictionary = wa.get("_key_of")
	if keys.has(w):
		if String(keys[w]) == KEY and Sfx.config(StringName(KEY + "_shot")).is_empty():
			keys[w] = GRAPH_KEY
		return
	if w.has_meta(&"audio_bridged"):
		return
	w.set_meta(&"audio_bridged", true)
	keys[w] = GRAPH_KEY
	for pair: Array in [[w.fired, "_on_fired"], [w.action_started, "_on_action"],
			[w.action_cancelled, "_on_cancelled"], [w.sfx, "_on_sfx"]]:
		if wa.has_method(pair[1]):
			(pair[0] as Signal).connect(Callable(wa, pair[1]).bind(w))


static func _balance_script() -> Variant:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "WeaponBalance":
			return load(String(c.get("path", "")))
	return null
