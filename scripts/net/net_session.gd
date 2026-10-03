class_name NetSession
extends Node
## Playing together (user 2026-10-01: "do we have co-op set up yet?", "lets do both pvp and co-op like arc raiders";
## docs/multiplayer_readiness.md, phase P1: two players see each other). One machine hosts, the others join it by
## address (ENet; Steam later swaps the peer, nothing else). Each machine runs its own player as ever and sends that
## player's state 20 times a second; every other machine shows it as a remote player: a FrontierPlayer with
## is_local false (no camera, HUD or keyboard: the duel's second player), its controls held from the state (the move
## keys, sprint, walk, aim), so it walks, runs and animates by the same code, and its place drawn toward the one sent.
## Its look is the sender's own (sent once, reliably, as it arrives).
##
## Shots (P2): a shot fired here flies here for real (its hits decided here, Hit.deliver as ever) and is sent to the
## others, who see and hear a ghost of it (Projectile.ghost: hurts nothing). A shot or blow from this machine's player
## that lands on a remote player goes to that player's machine (FrontierPlayer.apply_hit -> forward_hit), which takes it
## on its own player: the same wounds, bleeding, head shots and death. A death and a respawn travel in the state.
## Squads (Arc Raiders' way, docs/multiplayer_readiness.md): the same squad is co-op, no friendly fire; another squad
## can be fought. Name tags are gold for your squad, red for the others.
##
## One world (P3): the host's. A joiner connects from the main menu, asks the host for its world (the save's world parts:
## the sky, the felled trees and quarried rocks, every built piece, the fort, things lying about, the forage) and loads
## into it with its own character (its save's survival and player parts; its own homestead stays in its save, untouched:
## SaveGame.build_doc keeps it). From then on felling, cutting, quarrying, building and taking down are sent as they
## happen (world_event) and done the same way on every machine, and the host's clock is everyone's.
## Each survival core stays its own machine's (P4): hunger, warmth, rest per player.
##
## Not yet: the animals (P5: each machine still has its own), a felled trunk's limbing and logs, fires lit, doors and
## chests.
##
## The session lives at the root (/root/Net) so a join can be made from the menu and outlast the level's loading; the
## level attaches its player (install).
##
## Started by the main menu's Co-op (NetSession.incoming) or the user arg net=host / net=join:<address> (tools, tests).

const GROUP := &"net_session"
const PORT := 24565
const MAX_PEERS := 15                ## 16 players (docs/multiplayer_readiness.md)
const SEND_HZ := 20.0
const SNAP_M := 4.0                  ## further off than this the remote player is put straight there
const PULL := 10.0                   ## 1/s: how fast a remote player is drawn to its sent place
const SQUADS := 8
const OWN_SQUAD := Color(0.96, 0.85, 0.5)
const OTHER_SQUAD := Color(0.95, 0.45, 0.38)
const HELD := [&"move_left", &"move_right", &"move_forward", &"move_back", &"sprint", &"walk", &"aim"]

## How the next level starts: {} alone, {"mode": "host"}, {"mode": "join", "address": "1.2.3.4"}, and "squad" (taken once).
static var incoming := {}

signal peers_changed

var player: FrontierPlayer
var remotes := {}                    ## peer id -> FrontierPlayer
var names := {}                      ## peer id -> the name they gave
var squads := {}                     ## peer id -> their squad
var squad := 1                       ## this machine's player's squad
var friendly_fire := false
var hits_taken := 0                  ## hits from other machines' players this session (tests, the HUD later)
var _sources := {}                   ## damage kind -> the stand-in source of hits from another machine
var looks := {}                      ## peer id -> the look they sent
var level: Node
## Applying another machine's change: what it does here is not sent again (world_event).
var applying := false
var _world_in := {}                  ## the host's world, come in before the level was built: applied on install
var _events: Array = []              ## world events come in while there is no level yet
var _clock_t := 0.0
## The joiner's own save's world parts (its homestead), kept in its saves while it plays in the host's world.
static var own_world := {}
## Parts of a save that are the world (the host's in a session), not the character.
const WORLD_PARTS := ["sky", "vegetation", "building", "fort", "fire", "items", "forage"]
const ALL_WORLD := ["sky", "vegetation", "building", "fort", "fire", "items", "wildlife", "horse", "wheelbarrow", "cart", "forage",
		"household", "story", "death"]
const CLOCK_S := 2.0
var _target := {}                    ## peer id -> the last state they sent
var _send_t := 0.0
var _jumps := 0
var _was_floor := true
var status := ""


static func find(tree: SceneTree) -> NetSession:
	return tree.get_first_node_in_group(GROUP) as NetSession if tree else null


## The session this launch starts ({} alone): the menu's, else the user arg net=host / net=join:<address>.
static func incoming_mode() -> Dictionary:
	if not incoming.is_empty():
		return incoming
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if s.begins_with("squad="):
			continue
		if s == "net=host":
			return {"mode": "host", "squad": _arg_squad()}
		if s.begins_with("net=join"):
			var addr := s.get_slice(":", 1) if s.contains(":") else "127.0.0.1"
			return {"mode": "join", "address": addr, "squad": _arg_squad()}
	return {}


static func _arg_squad() -> int:
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("squad="):
			return int(a.get_slice("=", 1))
	return 1


## The session (made at the root the first time).
static func ensure(tree: SceneTree) -> NetSession:
	var n := tree.root.get_node_or_null("Net") as NetSession
	if n == null:
		n = NetSession.new()
		n.name = "Net"
		tree.root.add_child(n)
	return n


## The level attaches its player; a launch with net=host / net=join (or the menu's Host) starts the session here. A
## world from the host that came in before the level is applied now.
static func install(lv: Node, p: FrontierPlayer) -> NetSession:
	var n := ensure(lv.get_tree())
	n.level = lv
	n.player = p
	for id: int in n.remotes.keys():          # (the old level's remote players went with it)
		n.remotes.erase(id)
	n._target.clear()
	var m := incoming_mode()
	incoming = {}
	if m.has("squad"):
		n.squad = clampi(int(m.get("squad", 1)), 1, SQUADS)
	if not n.in_session():
		match String(m.get("mode", "")):
			"host":
				n.host()
			"join":
				n.join(String(m.get("address", "127.0.0.1")))
	else:
		for id: int in n.multiplayer.get_peers():
			n._hello.rpc_id(id, n._my_name(), n._my_look(), n.squad)
	if not n._world_in.is_empty():
		n._apply_world.call_deferred(n._world_in)
		n._world_in = {}
	return n


## The main menu's Join: connect, ask for the host's world, then load into it (the latest save's character with it).
static func join_from_menu(tree: SceneTree, address: String, sq: int) -> NetSession:
	var n := ensure(tree)
	n.level = null
	n.player = null
	n.squad = clampi(sq, 1, SQUADS)
	n.join(address)
	return n


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS     # (it keeps the session going under any menu)
	wild = NetWildlife.new()
	wild.name = "Wild"
	wild.net = self
	add_child(wild)
	process_physics_priority = -10       # (before the players: a jump held from here is just_pressed in their frame)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void:
		_say("Joined the game.")
		_want_world.rpc_id(1))
	multiplayer.connection_failed.connect(func() -> void: _say("Could not reach the host."); _close())
	multiplayer.server_disconnected.connect(func() -> void: _say("The host left."); _close())


func in_session() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
			and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


func is_host() -> bool:
	return in_session() and multiplayer.is_server()


func host(port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		_say("Could not host on port %d (%s)." % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_say("Hosting on port %d. Others join with this machine's address." % port)
	return OK


func join(address: String, port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_say("Could not join %s (%s)." % [address, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	_say("Joining %s ..." % address)
	return OK


func leave() -> void:
	_close()
	_say("Left the game.")


func _close() -> void:
	for id: int in remotes.keys():
		_drop(id)
	names.clear()
	squads.clear()
	looks.clear()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peers_changed.emit()


# --- Peers ---------------------------------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if player != null:
		_hello.rpc_id(id, _my_name(), _my_look(), squad)
	peers_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	_say("%s left." % String(names.get(id, "A player")))
	_drop(id)
	peers_changed.emit()


func _my_name() -> String:
	var n := OS.get_environment("USER")
	return n if n != "" else "Player %d" % multiplayer.get_unique_id()


func _my_look() -> Dictionary:
	var pa := player.get_node_or_null("Appearance") as PlayerAppearance if player else null
	return pa.look if pa and not pa.look.is_empty() else AppearanceStore.load_current()


@rpc("any_peer", "reliable")
func _hello(who: String, look: Dictionary, their_squad := 1) -> void:
	var id := multiplayer.get_remote_sender_id()
	var known := names.has(id)
	names[id] = who
	squads[id] = their_squad
	looks[id] = look
	if level != null:
		_dress(_spawn(id), id)
	if known:
		return
	_say("%s joined%s." % [who, " your squad" if their_squad == squad else ", squad %d" % their_squad])


## The remote player for peer `id` (made on first word from them).
func _spawn(id: int) -> FrontierPlayer:
	if remotes.has(id) and is_instance_valid(remotes[id]):
		return remotes[id]
	var r := FrontierPlayer.new()
	r.name = "Peer_%d" % id
	r.is_local = false
	r.controls = PlayerControls.new(false)
	r.demo_horse = false
	r.demo_wheelbarrow = false
	r.ignore_mouse_capture = true
	r.set_meta(&"net_peer", id)          # (FrontierPlayer.apply_hit sends what lands on it to its machine)
	level.add_child(r)
	r.global_position = player.global_position + Vector3(2, 0.5, 0) if player else Vector3(2, 0.5, 6)
	var tag := Label3D.new()
	tag.name = "NameTag"
	tag.text = String(names.get(id, "Player"))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0009
	tag.font_size = 28
	tag.outline_size = 8
	tag.modulate = Color(0.96, 0.9, 0.76)
	tag.position = Vector3(0, 2.15, 0)
	r.add_child(tag)
	remotes[id] = r
	_dress.call_deferred(r, id)
	return r


## A remote player's look and name tag, as its machine sent them.
func _dress(r: FrontierPlayer, id: int) -> void:
	if not is_instance_valid(r):
		return
	var look: Dictionary = looks.get(id, {})
	var pa := r.get_node_or_null("Appearance") as PlayerAppearance
	if pa and not look.is_empty():
		pa.apply(look)
	var tag := r.get_node_or_null("NameTag") as Label3D
	if tag:
		tag.text = String(names.get(id, "Player"))
		tag.modulate = OWN_SQUAD if int(squads.get(id, 1)) == squad else OTHER_SQUAD


func _drop(id: int) -> void:
	var r: Variant = remotes.get(id)
	if r != null and is_instance_valid(r):
		(r as Node).queue_free()
	remotes.erase(id)
	_target.erase(id)
	names.erase(id)
	squads.erase(id)
	looks.erase(id)


# --- State ---------------------------------------------------------------------------------------------------

## A shared world does not stop for one player's menu or card (the pause menu, the pack, a chest, a story card): with
## others in it the game runs on under them, as in other online games.
func _process(_delta: float) -> void:
	if get_tree().paused and in_session() and not multiplayer.get_peers().is_empty() and level != null:
		get_tree().paused = false


func _physics_process(delta: float) -> void:
	if not in_session() or player == null:
		return
	# a jump is counted on this machine, so the others jump on theirs
	var fl := player.is_on_floor()
	if _was_floor and not fl and player.velocity.y > 1.0:
		_jumps += 1
	_was_floor = fl
	if is_host():
		_world_clock(delta)
		_clock_t -= delta
		if _clock_t <= 0.0:
			_clock_t = CLOCK_S
			_send_clock()
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = 1.0 / SEND_HZ
		_state.rpc(_my_state())
	for id: int in remotes:
		_follow(id, delta)


func _my_state() -> Dictionary:
	var held := 0
	for i in HELD.size():
		if player.controls.pressed(HELD[i]):
			held |= 1 << i
	return {"p": player.global_position, "v": player.velocity, "y": player.yaw, "x": player.pitch, "h": held,
			"c": player.is_crouching, "j": _jumps, "w": String(player.weapon_key), "f": player.hands_free, "d": player.is_dead, "s": _sleeping(),
			"t": Time.get_ticks_msec()}


@rpc("any_peer", "unreliable_ordered")
func _state(s: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if level == null:
		return
	if not remotes.has(id) or not is_instance_valid(remotes[id]):
		_spawn(id)
	s["at"] = Time.get_ticks_msec()
	var old: Dictionary = _target.get(id, {})
	s["jumped"] = int(s.get("j", 0)) > int(old.get("j", s.get("j", 0)))
	_target[id] = s


## Drives remote player `id` from its last state: the keys held, the turn, crouch and jumps, the weapon; its place
## drawn toward the sent one (ahead by its speed for the time since).
func _follow(id: int, delta: float) -> void:
	var r: FrontierPlayer = remotes[id]
	if not is_instance_valid(r):
		return
	var s: Dictionary = _target.get(id, {})
	if s.is_empty() or not is_instance_valid(r):
		return
	var held := int(s.get("h", 0))
	for i in HELD.size():
		r.controls.set_held(HELD[i], (held & (1 << i)) != 0)
	r.yaw = float(s.get("y", r.yaw))
	r.pitch = float(s.get("x", r.pitch))
	r.controls.set_held(&"crouch", bool(s.get("c", false)) != r.is_crouching)    # (a toggle: pressed till it matches)
	r.controls.set_held(&"jump", bool(s.get("jumped", false)))
	s["jumped"] = false
	# a death and a respawn on its machine
	var dead := bool(s.get("d", false))
	if dead and not r.is_dead:
		r.health = 0.0
		r._die(Vector2.ZERO)
	elif not dead and r.is_dead:
		r.global_position = s.get("p", r.global_position)
		r.respawn()
	if r.is_dead:
		return
	var wk := String(s.get("w", ""))
	if wk != "" and wk != String(r.weapon_key) and r.weapons.has(wk):
		r.switch_weapon(wk)
	var age := float(Time.get_ticks_msec() - int(s.get("at", 0))) / 1000.0
	var want: Vector3 = (s.get("p", r.global_position) as Vector3) + (s.get("v", Vector3.ZERO) as Vector3) * clampf(age, 0.0, 0.25)
	var off := want - r.global_position
	if off.length() > SNAP_M:
		r.global_position = want
	else:
		r.global_position += off * clampf(PULL * delta, 0.0, 1.0)


func _say(text: String) -> void:
	status = text
	print("Net: ", text)
	var hud: Variant = player.get("hud") if player else null
	if hud is FrontierHUD and is_instance_valid(hud):
		(hud as FrontierHUD).toast(text)


# --- Shots and hits (P2) ---------------------------------------------------------------------------------------

## A shot `p` just fired by `shooter` (Weapon._launch, Throwable._launch_thrown): sent to the others when it is this
## machine's player's.
static func shot(shooter: FrontierPlayer, p: Node3D, thrown: bool) -> void:
	if shooter == null or not shooter.is_local or p == null:
		return
	var n := find(shooter.get_tree())
	if n == null or not n.in_session():
		return
	var kind := int(p.get("kind")) if not thrown else int(Projectile.Kind.ARROW)
	n._shot.rpc({"o": p.global_position, "v": p.get("velocity"), "g": float(p.get("gravity")), "dr": float(p.get("drag")),
			"k": kind, "w": String(shooter.weapon_key), "t": thrown})


@rpc("any_peer", "unreliable_ordered")
func _shot(d: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if level == null:
		return
	var from: FrontierPlayer = remotes.get(id) if is_instance_valid(remotes.get(id)) else null
	var g := Projectile.new()
	g.ghost = true
	g.kind = int(d.get("k", 0)) as Projectile.Kind
	g.velocity = d.get("v", Vector3.FORWARD)
	g.gravity = float(d.get("g", 4.0))
	g.drag = float(d.get("dr", 0.0))
	g.damage = 0.0
	if from and is_instance_valid(from):
		g.exclude = [from.get_rid()]
		g.shooter = from
	get_tree().current_scene.add_child(g)
	var o: Vector3 = d.get("o", Vector3.ZERO)
	g.global_position = o
	var v: Vector3 = g.velocity
	if v.length_squared() > 0.01:
		g.look_at(o + v, Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
	# its sound where it left from (what WeaponAudio plays for this machine's own)
	var w := String(d.get("w", ""))
	if bool(d.get("t", false)):
		Sfx.play_3d(&"arrow_whoosh", o, -10.0, 0.55)
	elif w == "bow":
		Sfx.play_3d(&"bow_release", o)
	elif w != "":
		Sfx.play_3d(StringName(w + "_shot"), o)
		get_tree().call_group(&"ambience", &"scare")


## Whether `source` (what hit) is this machine's player's own doing: the player, or a shot or a blow it made.
func _from_me(source: Node) -> bool:
	if source == null or player == null:
		return false
	if source == player:
		return true
	if source is WildAnimal and is_host() and not (source as WildAnimal).mirrored:
		return true                                  # (the host's animals are the world's: their bites count)
	var sh: Variant = source.get("shooter")
	if sh != null and sh == player:
		return true
	return player.is_ancestor_of(source)          # (a blow: the axe or knife in the player's hands)


## A hit on remote player `r` here (FrontierPlayer.apply_hit): this machine's own shots and blows go to its machine, in
## its body's frame (its place there differs a little from here); anything else (this machine's own animals and trees,
## not shared yet) does nothing to it.
static func forward_hit(r: FrontierPlayer, damage: float, point: Vector3, direction: Vector3, source: Node, part: String) -> void:
	var n := find(r.get_tree())
	if n == null or not n.in_session() or not n._from_me(source):
		return
	var id := int(r.get_meta(&"net_peer", 0))
	if id == 0:
		return
	if int(n.squads.get(id, 1)) == n.squad and not n.friendly_fire:
		return                                       # (the same squad: co-op)
	var inv := r.global_transform.affine_inverse()
	n._hit.rpc_id(id, {"dmg": damage, "lp": inv * point, "ld": inv.basis * direction, "part": part,
			"kind": PlayerWounds.kind_of(source)})


@rpc("any_peer", "reliable")
func _hit(d: Dictionary) -> void:
	if player == null or player.is_dead:
		return
	var id := multiplayer.get_remote_sender_id()
	var xf := player.global_transform
	var src := _source(String(d.get("kind", "bleed")), id)
	var was_alive := not player.is_dead
	hits_taken += 1
	player.apply_hit(float(d.get("dmg", 0.0)), xf * (d.get("lp", Vector3.ZERO) as Vector3),
			xf.basis * (d.get("ld", Vector3.ZERO) as Vector3), src, String(d.get("part", "body")))
	if was_alive and player.is_dead:
		_killed.rpc(id)
		_say("Killed by %s." % String(names.get(id, "a player")))


## Everyone hears who killed whom.
@rpc("any_peer", "reliable")
func _killed(killer: int) -> void:
	var victim := multiplayer.get_remote_sender_id()
	var me := multiplayer.get_unique_id()
	var kn := "You" if killer == me else String(names.get(killer, "A player"))
	_say("%s killed %s." % [kn, String(names.get(victim, "a player"))])


## The stand-in for what hit, from another machine: its damage kind (PlayerWounds.kind_of), not this machine's player
## (whose own shots never hurt it).
func _source(kind: String, _peer: int) -> Node:
	if not _sources.has(kind):
		var s := Node.new()
		s.name = "HitFrom_%s" % kind
		s.set_meta(&"damage_kind", kind)
		add_child(s)
		_sources[kind] = s
	return _sources[kind]


# --- The world (P3) ------------------------------------------------------------------------------------------

## The host's world as a save's world parts, and what the joiner needs round it (the fort or not, the clock).
func world_doc() -> Dictionary:
	var lv := level
	var parts := {}
	for part: String in WORLD_PARTS:
		match part:
			"sky": parts[part] = SaveParts.save_sky(lv)
			"vegetation": parts[part] = SaveParts.save_vegetation(lv)
			"building": parts[part] = SaveParts.save_building(lv)
			"fort": parts[part] = SaveParts.save_fort(lv)
			"fire": parts[part] = SaveParts.save_fire(lv)
			"items": parts[part] = SaveParts.save_items(lv)
			"forage": parts[part] = SaveParts.save_forage(lv)
	return SaveParts.plain({"parts": parts, "bare": SurvivalBridge.bare_of(get_tree()), "clock": _clock()})


@rpc("any_peer", "reliable")
func _want_world() -> void:
	if not is_host() or level == null:
		return
	_world.rpc_id(multiplayer.get_remote_sender_id(), world_doc())


## The host's world comes in. From the menu (no level yet): load into it, with the latest save's character; with a
## level already (a launch with net=join): applied over it now.
@rpc("authority", "reliable")
func _world(doc: Dictionary) -> void:
	if level != null and is_instance_valid(level):
		_apply_world(doc)
		return
	_world_in = doc
	var own := {}
	var slot := SaveGame.latest_slot()
	if slot != "":
		own = SaveGame.read_slot(slot)
	var parts: Dictionary = (own.get("parts", {}) as Dictionary).duplicate()
	own_world = {}
	for part: String in ALL_WORLD:
		if parts.has(part):
			own_world[part] = parts[part]
			parts.erase(part)
	var meta: Dictionary = (own.get("meta", {}) as Dictionary).duplicate()
	meta["bare"] = bool(doc.get("bare", false))          # (the host's world: its fort or its open ground)
	SaveGame.pending = {"format": SaveParts.FORMAT, "version": SaveParts.VERSION, "meta": meta, "parts": parts}
	SaveGame.pending_slot = slot if slot != "" else "auto"
	SaveGame._launched = true
	MainMenu.new_game = parts.is_empty()
	StoryDirector.incoming = ""
	LoadingScreen.go(get_tree(), MainMenu.GAME_SCENE, not parts.is_empty())


func _apply_world(doc: Dictionary) -> void:
	# (after the level and any save have settled: the host's world goes over them)
	for i in SaveGame.APPLY_AFTER_FRAMES + 4:
		await get_tree().process_frame
	if level == null or not is_instance_valid(level):
		return
	var parts: Dictionary = doc.get("parts", {})
	var notes: Array = []
	applying = true
	if parts.has("sky"):
		SaveParts.load_sky(level, parts.sky)
	if parts.has("vegetation"):
		SaveParts.load_vegetation(level, parts.vegetation, notes)
	if parts.has("building"):
		SaveParts.load_building(level, parts.building)
	if parts.has("fort"):
		SaveParts.load_fort(level, parts.fort)
	if parts.has("fire"):
		SaveParts.load_fire(level, parts.fire)       # (the host's fires and ruins, after its pieces)
	if parts.has("items"):
		SaveParts.load_items(level, parts.items)
	if parts.has("forage"):
		SaveParts.load_forage(level, parts.forage)
	_set_clock(doc.get("clock", {}))
	applying = false
	world_ready = true
	for n in notes:
		_say(String(n))
	_say("In the host's world.")
	var queued := _events
	_events = []
	for e: Array in queued:
		_do_event(String(e[0]), e[1])


var world_ready := false
var wild: NetWildlife


## Whether this machine plays in another's world (a joiner): asked by the level as it builds (its animals mirrored).
static func is_guest(tree: SceneTree) -> bool:
	var n := tree.root.get_node_or_null("Net") as NetSession
	return n != null and n.in_session() and not n.is_host()


## A change to the world made here (felling, cutting, quarrying, building, taking down): done the same on every other
## machine. Not when it is another machine's change being done here (applying), nor alone.
static func world_event(tree: SceneTree, kind: String, d: Dictionary) -> void:
	if tree == null:
		return
	var n := tree.root.get_node_or_null("Net") as NetSession
	if n == null or n.applying or not n.in_session():
		return
	if not n.is_host() and not n.world_ready:
		return                                     # (a joiner's level before the host's world is in: its own start)
	n._event.rpc(kind, SaveParts.plain(d))


@rpc("any_peer", "reliable")
func _event(kind: String, d: Dictionary) -> void:
	if level == null or not is_instance_valid(level) or (not is_host() and not world_ready and not _world_in.is_empty()):
		_events.append([kind, d])
		return
	_do_event(kind, d)


func _do_event(kind: String, d: Dictionary) -> void:
	applying = true
	match kind:
		"fell":
			var g: GatherTools = player.gather if player else null
			if g:
				g.fell_tree(int(d.i), SaveParts.to_v3(d.from), SaveParts.to_v3(d.ahead, Vector3.FORWARD), false, float(d.get("cut", INF)), SaveParts.to_v3(d.get("dir"), Vector3.ZERO))
		"stump":
			var gs: GatherTools = player.gather if player else null
			if gs:
				gs.remove_stump(int(d.i), false)
		"sapling":
			var h := VegHarvest.find(get_tree())
			if h:
				h.remove_sapling(String(d.src), int(d.i))
		"rock":
			var h := VegHarvest.find(get_tree())
			if h:
				h.shrink_rock(int(d.i), float(d.f))
		"build":
			var w := BuildWorld.of(get_tree(), true)
			if w and _piece(String(d.key)) == null:
				var g := PackedFloat32Array()
				for x in d.get("ground", []):
					g.append(float(x))
				var sup := _piece(String(d.get("support", "")))
				var p := w.add_piece(String(d.type), SaveParts.to_xf(d.xf), bool(d.grounded), sup.piece_id if sup else -1, g)
				p.set_meta(&"net_key", String(d.key))
		"unbuild":
			var w := BuildWorld.of(get_tree(), false)
			var p := _piece(String(d.key))
			if w and p:
				w.remove_piece(p)
		"ignite":
			# a piece caught fire there (FireSpread): alight here too (it burns, spreads and falls here on its own)
			var f := FireSpread.of(get_tree())
			var p := _piece(String(d.key))
			if f and p:
				f.ignite(p, SaveParts.to_v3(d.get("at"), Vector3.INF))
		"put_out":
			# beaten out there (FireSpread.put_out): out here too
			var fo := FireSpread.find(get_tree())
			var po := _piece(String(d.key))
			if fo and po:
				fo.put_out(po, true)
	applying = false


## A built piece's key across machines: "<the peer that built it>:<its id there>" (pieces of the host's world before
## the session: "1:<id>", their ids the same on every machine from the join's snapshot).
static func piece_key(p: BuiltPiece) -> String:
	return String(p.get_meta(&"net_key")) if p.has_meta(&"net_key") else "1:%d" % p.piece_id


func _piece(key: String) -> BuiltPiece:
	if key == "":
		return null
	var w := BuildWorld.of(get_tree(), false)
	if w == null:
		return null
	for p in w.pieces():
		if piece_key(p) == key:
			return p
	return null


## A piece just built here (BuildWorld.add_piece): keyed, and sent.
static func built(w: BuildWorld, p: BuiltPiece, support: int) -> void:
	var n := w.get_tree().root.get_node_or_null("Net") as NetSession if w.is_inside_tree() else null
	if n == null or n.applying or not n.in_session() or (not n.is_host() and not n.world_ready):
		return
	p.set_meta(&"net_key", "%d:%d" % [n.multiplayer.get_unique_id(), p.piece_id])
	var sup := ""
	if support >= 0:
		var sp := w.by_id(support)
		sup = piece_key(sp) if sp else ""
	world_event(w.get_tree(), "build", {"key": piece_key(p), "type": p.type, "xf": SaveParts.xf(p.global_transform),
			"grounded": p.grounded, "support": sup, "ground": Array(p.ground)})


static func unbuilt(w: BuildWorld, p: BuiltPiece) -> void:
	if not w.is_inside_tree():
		return
	world_event(w.get_tree(), "unbuild", {"key": piece_key(p)})


# --- The clock ---------------------------------------------------------------------------------------------

func _clock() -> Dictionary:
	var b := SurvivalBridge.find(get_tree())
	if b == null or b.core == null:
		return {}
	return {"m": world_minutes(), "y": b.core.state.base_year}


func _send_clock() -> void:
	var c := _clock()
	if not c.is_empty():
		_clock_in.rpc(c)


@rpc("authority", "unreliable_ordered")
func _clock_in(c: Dictionary) -> void:
	_set_clock(c)


## Whether this machine's player is asleep (the survival rules' sleep).
func _sleeping() -> bool:
	var b := SurvivalBridge.find(get_tree())
	return b != null and b.sleeper != null and b.sleeper.sleeping


## The world's time in a session (the host's): a sleep passes the hours quickly for the sleeper (their rest, their
## hunger), but the world's clock skips on only while everyone sleeps; one who sleeps alone wakes to the world's hour
## (survival games' rule). `_world_m` runs at the clock's own rate while someone is awake.
var _world_m := -1.0


func everyone_asleep() -> bool:
	if not _sleeping():
		return false
	for id: int in _target:
		if not bool((_target[id] as Dictionary).get("s", false)):
			return false
	return true


func _world_clock(delta: float) -> void:
	var b := SurvivalBridge.find(get_tree())
	if b == null or b.core == null:
		return
	var asleep := _sleeping()
	if multiplayer.get_peers().is_empty() or everyone_asleep() or _world_m < 0.0 or not asleep and not _slept_alone:
		_world_m = b.core.state.minutes
		_slept_alone = false
		return
	# asleep while someone is awake: the world's hour runs at the clock's rate; on waking the host comes back to it
	_world_m += delta * SurvivalClock.game_minutes_per_real_second(b.core)
	if asleep:
		_slept_alone = true
	else:
		if b.core.state.minutes > _world_m:
			b.core.state.minutes = _world_m
		_slept_alone = false


var _slept_alone := false


## The world's clock as the host sends it: its own while it sleeps alone.
func world_minutes() -> float:
	var b := SurvivalBridge.find(get_tree())
	if _world_m >= 0.0 and _sleeping() and not everyone_asleep():
		return _world_m
	return b.core.state.minutes if b and b.core else 0.0


## The host's time is everyone's (a sleep here passes the hours only for this sleeper: the host's clock comes back).
func _set_clock(c: Dictionary) -> void:
	var b := SurvivalBridge.find(get_tree())
	if b == null or b.core == null or c.is_empty():
		return
	b.core.state.base_year = int(c.get("y", b.core.state.base_year))
	var m := float(c.get("m", b.core.state.minutes))
	if _sleeping() and m < b.core.state.minutes:
		return                                       # (asleep here: this sleeper's hours run on till they wake)
	if absf(b.core.state.minutes - m) > 0.5:
		b.core.state.minutes = m
