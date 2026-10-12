class_name RingNet
extends Node
## THE RING ONLINE (docs/tidebreak/ring_netcode.md; the owner, 2026-10-11, after Spellbreak's community server kit: "we can copy
## to use for our community servers or player run servers", "make sure its the best code"): the session of a Tidebreak match
## played over the network, at /root/RingNet so it outlasts the ring's loading. Phase R1 a: the session, the people and
## their slots, the clock, the bodies; R1 b: the casts (NetCasts) and the spells' words and hits (NetSpells).
##   the session   one machine hosts (ENet, PORT; host(port)), the others join it by address (join(address, port)); the
##                 menu's choice in `incoming`, or the user arg ring_net=host[:port] / ring_net=join:<address>[:port] (tools,
##                 tests). A dedicated server is a host with no fighter of its own (phase R3)
##   the roster    the host's word on who plays: peer id -> {team (the host's numbering), slot, name, element, look}; its own
##                 under id 1. A joiner says hello (name, element, look); the host gives it the first free slot (1v1: team 1,
##                 slot 0) and sends the roster to all; a machine that leaves is taken off it. Every machine sees its own
##                 side as team 0 (local_team(): the HUD, the screens and RingMode's words all stay "you" = team 0)
##   the clock     clock (NetClock): a client pings the host every PING_S; every state carries the host's time
##   the bodies    each machine sends its own fighter's state SEND_HZ a second (NetBody.capture; unreliable, ordered, on
##                 STATE_CHANNEL, relayed by the host); every other fighter is a PUPPET here: a FrontierPlayer like the
##                 player (no camera, keys or HUD), PUPPET_META its owner's peer, its RingMoves in puppet mode, put where its
##                 owner's body was NetBody.INTERP_S ago each physics frame before the bodies move (process_physics_priority)
##   the casts     send_cast / send_lock (NetCasts: this machine's player's casts and lock, to every other machine: _cast,
##                 _lock run them on his puppet there); send_word (the host's words about spells to every other machine:
##                 _word, NetSpells.apply_word); send_hit (the host's effect on a body to its owner: _hit, NetSpells.apply_hit).
##                 A puppet casts through a NetBendCaster (bound at its making) and wears its owner's loadout (his hello's
##                 picks and style). net_id_of(body) / body_by_net_id(id): a body's name on the wire (its owner's peer)
##   the match     RingMode asks: human_at(team, slot) (a remote human holds that slot: no bot is made there),
##                 place_humans() (the puppets on the rules' books at their spawns), flipped() (this machine's side is the
##                 host's team 1: its ends swap); a roster change restarts the match on every machine
## Offline nothing here runs: RingMode's seams ask RingNet.attach(), which is null with no session.

signal roster_changed
## A tests' and tools' word from another machine (note()).
signal noted(peer: int, tag: String, data: Variant)

const NODE_NAME := "RingNet"
const GROUP := &"ring_net"
const PORT := 24570
const MAX_PEERS := 15
const SEND_HZ := 30.0
const PING_S := 1.0
## A join not reached is tried again this often, this many times (a host still loading its ring).
const JOIN_RETRY_S := 1.0
const JOIN_TRIES := 30
## The channel the bodies' states travel on (unreliable): the events' reliable channel 0 never waits behind them.
const STATE_CHANNEL := 1
## A puppet's meta: the peer id of the machine that owns the body (RingMoves.puppet's gate; set before it enters the tree).
const PUPPET_META := &"ring_net_owner"

enum Role { OFF, HOST, CLIENT }

## How the next ring starts online ({} offline): {"role": "host", "port"} or {"role": "join", "address", "port"}.
static var incoming := {}

var role := Role.OFF
var clock := NetClock.new()
## The ring's match on this machine (attach()).
var mode: RingMode
## Who plays: peer id -> {team, slot, name, element, look} (the host's word).
var roster := {}
## The fighter each peer owns here: this machine's player under its own id, a puppet for every other.
var bodies := {}
## Words for the player ("" none): the last thing the session did ("Joined.", "Could not reach the host.").
var status := ""
var _buffers := {}              # peer id -> NetBody
var _send_t := 0.0
var _ping_t := 0.0
var _my_hello := {}
var _join_to: Array = []        # [address, port] of the join under way
var _join_tries := 0


# ---------------------------------------------------------------- finding it, starting it
static func find(tree: SceneTree) -> RingNet:
	return tree.root.get_node_or_null(NODE_NAME) as RingNet if tree != null else null


## The session (made at the root the first time).
static func ensure(tree: SceneTree) -> RingNet:
	var n := find(tree)
	if n == null:
		n = RingNet.new()
		n.name = NODE_NAME
		tree.root.add_child(n)
	return n


## The ring online this launch ({} offline): `incoming`, else the user arg ring_net=host[:port] / ring_net=join:<addr>[:port].
static func incoming_mode() -> Dictionary:
	if not incoming.is_empty():
		return incoming
	for a in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if not s.begins_with("ring_net="):
			continue
		var parts := s.trim_prefix("ring_net=").split(":")
		if parts[0] == "host":
			return {"role": "host", "port": int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else PORT}
		if parts[0] == "join":
			return {"role": "join", "address": parts[1] if parts.size() > 1 else "127.0.0.1",
					"port": int(parts[2]) if parts.size() > 2 and parts[2].is_valid_int() else PORT}
	return {}


## The match `m` online when a session is up or asked for (it starts here then): the session, else null (offline: every seam
## of RingMode's is a no-op).
static func attach(m: RingMode) -> RingNet:
	if m == null or not m.is_inside_tree():
		return null
	var n := find(m.get_tree())
	var want := incoming_mode()
	if n == null and want.is_empty():
		return null
	n = ensure(m.get_tree())
	n.mode = m
	if n.role == Role.OFF and not want.is_empty():
		incoming = {}
		if String(want.role) == "host":
			n.host(int(want.get("port", PORT)))
		else:
			n.join(String(want.get("address", "127.0.0.1")), int(want.get("port", PORT)))
	if n.role == Role.OFF:
		n.mode = null
		return null
	n._sync_puppets()
	return n


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -20              # (before the bodies: a puppet stands where it should when they move)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(func() -> void:
		_say("The host left.")
		_close())


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func my_id() -> int:
	return multiplayer.get_unique_id() if role != Role.OFF else 1


func host(port := PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		_say("Could not host on port %d (%s)." % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	NetSpells.net = self
	clock.be_host()
	roster = {1: _hello_of()}
	roster[1]["team"] = 0
	roster[1]["slot"] = 0
	_say("Hosting on port %d." % port)
	roster_changed.emit()
	return OK


func join(address: String, port := PORT) -> Error:
	_join_to = [address, port]
	_join_tries = 0
	return _try_join()


func _try_join() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(String(_join_to[0]), int(_join_to[1]))
	if err != OK:
		_say("Could not join %s (%s)." % [_join_to[0], error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	role = Role.CLIENT
	NetSpells.net = self
	_say("Joining %s:%d ..." % [_join_to[0], _join_to[1]])
	return OK


## Not reached: tried again every JOIN_RETRY_S, JOIN_TRIES times (a host still loading its ring), then given up.
func _on_connect_failed() -> void:
	_join_tries += 1
	if _join_tries < JOIN_TRIES and not _join_to.is_empty():
		_say("Waiting for the host ...")
		get_tree().create_timer(JOIN_RETRY_S, true, false, true).timeout.connect(func() -> void:
			if role == Role.CLIENT:
				_try_join())
		return
	_say("Could not reach the host.")
	_close()


func leave() -> void:
	_close()
	_say("Left.")


func _close() -> void:
	for id: int in bodies.keys():
		if id != my_id():
			_drop(id)
	roster.clear()
	_buffers.clear()
	_join_to = []
	role = Role.OFF
	NetSpells.reset()
	NetCasts.reset()
	NetSpells.net = null
	clock = NetClock.new()
	if is_inside_tree():
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster_changed.emit()


func _say(text: String) -> void:
	status = text
	print("RingNet: ", text)


# ---------------------------------------------------------------- the people
## This machine's word about its own fighter: its name, element and look (the host's own: under id 1).
func _hello_of() -> Dictionary:
	var nm := ""
	for a in OS.get_cmdline_user_args():
		if a.trim_prefix("--").begins_with("name="):
			nm = a.trim_prefix("--").get_slice("=", 1)
	if nm == "":
		nm = OS.get_environment("USER")
	if nm == "":
		nm = "Player"
	var look := {}
	var p := mode.player if mode != null else null
	var pa := p.get_node_or_null("Appearance") as PlayerAppearance if p != null else null
	if pa != null and not pa.look.is_empty():
		look = pa.look
	else:
		look = AppearanceStore.load_current()
	var el := MatchSetup.element if MatchSetup.element in Bending.ELEMENTS else "earth"
	var worn := BendLoadout.worn(el)               # (his skill tree's picks and fighting style: his puppets wear them)
	return {"name": nm, "element": el, "look": look, "picks": worn.picks, "style": String(worn.style)}


func _on_connected() -> void:
	_say("Joined.")
	_my_hello = _hello_of()
	_hello.rpc_id(1, _my_hello)
	_ping_t = 0.0


func _on_peer_connected(_id: int) -> void:
	pass                                    # (a joiner speaks first: _hello)


func _on_peer_disconnected(id: int) -> void:
	if not roster.has(id):
		return
	_say("%s left." % String((roster[id] as Dictionary).get("name", "A player")))
	roster.erase(id)
	_drop(id)
	if is_host():
		_roster.rpc(roster)
	_after_roster()


## A joiner's hello (the host's): its slot, the first free one on the side with fewer humans; then the roster to all.
@rpc("any_peer", "reliable")
func _hello(h: Dictionary) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	var e := {"name": String(h.get("name", "Player")), "element": String(h.get("element", "earth")), "look": h.get("look", {}),
			"picks": h.get("picks", []), "style": String(h.get("style", ""))}
	var slot := _free_slot()
	e["team"] = slot.x
	e["slot"] = slot.y
	roster[id] = e
	_say("%s joined (side %d)." % [e.name, slot.x])
	_roster.rpc(roster)
	_after_roster()


## The first free (team, slot) in the host's numbering: the side with fewer humans first, its lowest free slot.
func _free_slot() -> Vector2i:
	var n := mode.team_n() if mode != null else 1
	var counts := [0, 0]
	for e: Dictionary in roster.values():
		counts[int(e.team)] += 1
	var t := 1 if counts[1] <= counts[0] else 0
	for s in n:
		var taken := false
		for e: Dictionary in roster.values():
			taken = taken or (int(e.team) == t and int(e.slot) == s)
		if not taken:
			return Vector2i(t, s)
	return Vector2i(1 - t, n - 1)


@rpc("authority", "reliable")
func _roster(r: Dictionary) -> void:
	roster = r
	_after_roster()


func _after_roster() -> void:
	_sync_puppets()
	roster_changed.emit()
	if mode != null and is_instance_valid(mode):
		mode.restart()                        # (the sides changed: the match from its start on every machine)


## This machine's side in the host's numbering (0 until the roster has it).
func my_team() -> int:
	var e: Dictionary = roster.get(my_id(), {})
	return int(e.get("team", 0))


## This machine's side is the host's team 1 (its ends swap: every machine sees its own side as team 0).
func flipped() -> bool:
	return my_team() == 1


## Team `host_team` (the host's numbering) as this machine numbers it.
func local_team(host_team: int) -> int:
	return host_team if not flipped() else 1 - host_team


## The peer holding slot `slot` of side `team` (this machine's numbering), another machine's (0: none, or this machine's own).
func human_at(team: int, slot: int) -> int:
	for id: int in roster:
		if id == my_id():
			continue
		var e: Dictionary = roster[id]
		if local_team(int(e.team)) == team and int(e.slot) == slot:
			return id
	return 0


# ---------------------------------------------------------------- the puppets
## A puppet for every other peer in the roster, none for one gone (made once the ring's level is here).
func _sync_puppets() -> void:
	if mode == null or not is_instance_valid(mode) or mode.level == null:
		return
	if mode.player != null:
		bodies[my_id()] = mode.player
		NetCasts.watch(SwayCaster.of(mode.player))     # (its lock's course to the others: NetCasts)
	for id: int in roster:
		if id != my_id() and not _live(bodies.get(id)):
			bodies[id] = _make_puppet(id)
	for id: int in bodies.keys():
		if id != my_id() and not roster.has(id):
			_drop(id)


func _live(b: Variant) -> bool:
	return b != null and is_instance_valid(b) and (b as Node).is_inside_tree()


## Peer `id`'s puppet: a FrontierPlayer as the ring's own (RingLevel), not this machine's (no camera, keys or HUD), its
## element and look its owner's.
func _make_puppet(id: int) -> FrontierPlayer:
	var e: Dictionary = roster.get(id, {})
	var p := FrontierPlayer.new()
	p.name = "Net_%d" % id
	p.is_local = false
	p.controls = PlayerControls.new(false)
	p.demo_horse = false
	p.demo_wheelbarrow = false
	p.ignore_mouse_capture = true
	p.set(&"arena", true)
	p.set_meta(PUPPET_META, id)
	mode.level.add_child(p)
	p.no_death = true
	SwayCaster.install_free(p)
	NetBendCaster.new(SwayCaster.of(p)).bind()        # (his casts run here ask it: NetCasts)
	Bending.of(p).element = String(e.get("element", "earth"))
	_dress.call_deferred(p, e)
	_buffers[id] = NetBody.new()
	return p


func _dress(p: FrontierPlayer, e: Dictionary) -> void:
	if not is_instance_valid(p):
		return
	var look: Dictionary = e.get("look", {})
	var pa := p.get_node_or_null("Appearance") as PlayerAppearance
	if pa != null and not look.is_empty():
		pa.apply(look)


## Peer `id`'s puppet gone (it left; the match restarts after, its books made again without it).
func _drop(id: int) -> void:
	var b: Variant = bodies.get(id)
	if id != my_id() and b != null and is_instance_valid(b):
		(b as Node).queue_free()
	bodies.erase(id)
	_buffers.erase(id)


## Peer `id`'s fighter here (its puppet, or this machine's player), null none.
func body_of(id: int) -> Node3D:
	var b: Variant = bodies.get(id)
	return b as Node3D if _live(b) else null


## The peer owning body `b` here (0: none online; this machine's own player: its id).
func owner_of(b: Node) -> int:
	if b == null or not is_instance_valid(b):
		return 0
	if b.has_meta(PUPPET_META):
		return int(b.get_meta(PUPPET_META))
	return my_id() if mode != null and b == mode.player else 0


## Body `b`'s name on the wire (NetSpells.enc: its owner's peer; 0 none: not a fighter of the match online).
func net_id_of(b: Node) -> int:
	return owner_of(b)


## The body named `id` on the wire here (null none).
func body_by_net_id(id: int) -> Node3D:
	return body_of(id) if id != 0 else null


## Every human of the match on the rules' books at his side's spawn (RingMode.next_round, after its own and its bots).
func place_humans() -> void:
	_sync_puppets()
	if mode == null or mode.rules == null:
		return
	for id: int in roster:
		if id == my_id():
			continue
		var p := body_of(id)
		if p == null:
			continue
		var e: Dictionary = roster[id]
		var t := local_team(int(e.team))
		mode.make_whole(p)
		RingLevel.place(p, mode.ring.spawn(mode.end_of_team(t), int(e.slot)))
		Bending.of(p).element = String(e.get("element", "earth"))
		BendLoadout.wear(p, e.get("picks", []) as Array, String(e.get("style", "")), String(e.get("element", "earth")))
		mode.rules.add(p, t)


# ---------------------------------------------------------------- each frame
func _physics_process(delta: float) -> void:
	if role == Role.OFF:
		return
	if is_client():
		_ping_t -= delta
		if _ping_t <= 0.0:
			_ping_t = PING_S if clock.answers() >= NetClock.QUICK_N else NetClock.QUICK_S
			_ping.rpc_id(1, NetClock.local())
	var now := clock.now()
	for id: int in bodies:
		if id == my_id():
			continue
		var p := body_of(id)
		var buf: NetBody = _buffers.get(id)
		if p == null or buf == null:
			continue
		buf.apply(p, now - NetBody.INTERP_S)
		if p is FrontierPlayer:
			(p as FrontierPlayer).fall_safe_m = 1e6      # (its owner's machine judges its falls)
		var nbc := BendCaster.of(p) as NetBendCaster
		if nbc != null:
			nbc.streamed_aim = buf.aim                     # (his crosshair's point: what a cast of his asks after its run)
	_send_t -= delta
	if _send_t <= 0.0:
		_send_t = 1.0 / SEND_HZ
		var me := body_of(my_id())
		if me != null and clock.synced:
			_state.rpc(NetBody.capture(me, now))


@rpc("any_peer", "unreliable_ordered", "call_remote", 1)
func _state(s: Array) -> void:
	var id := multiplayer.get_remote_sender_id()
	var buf: NetBody = _buffers.get(id)
	if buf != null:
		buf.push(s)


@rpc("any_peer", "reliable")
func _ping(sent: float) -> void:
	if is_host():
		_pong.rpc_id(multiplayer.get_remote_sender_id(), sent, clock.now())


@rpc("authority", "reliable")
func _pong(sent: float, host_t: float) -> void:
	clock.pong(sent, host_t)


# ---------------------------------------------------------------- the casts (NetCasts, NetSpells)
## This machine's player's cast `ev` to every other machine (NetCasts.end).
func send_cast(ev: Dictionary) -> void:
	if role != Role.OFF:
		_cast.rpc(ev)


## This machine's player's lock event `e` to every other machine (NetCasts.watch).
func send_lock(e: Array) -> void:
	if role != Role.OFF:
		_lock.rpc(e)


## The host's word `w` about spells to every other machine (NetSpells.word).
func send_word(w: Array) -> void:
	if is_host():
		_word.rpc(w)


## The host's effect `h` on a body to its owner, peer `peer` (NetSpells.forward).
func send_hit(peer: int, h: Array) -> void:
	if role != Role.OFF and peer != my_id():
		_hit.rpc_id(peer, h)


@rpc("any_peer", "reliable")
func _cast(ev: Dictionary) -> void:
	NetCasts.run(ev, multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func _lock(e: Array) -> void:
	NetCasts.lock_event(e, multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func _word(w: Array) -> void:
	NetSpells.apply_word(w)


@rpc("authority", "reliable")
func _hit(h: Array) -> void:
	NetSpells.apply_hit(h)


## A client's report to the host (NetMatch.report_fall: a fall of his own body).
func send_report(r: Array) -> void:
	if is_client():
		_report.rpc_id(1, r)


@rpc("any_peer", "reliable")
func _report(r: Array) -> void:
	if is_host():
		NetMatch.on_report(NetSpells.dec(r) as Array, multiplayer.get_remote_sender_id())


# ---------------------------------------------------------------- the tests' and tools' word
## A word `tag` with `data` to every other machine (reliable; noted on theirs).
func note(tag: String, data: Variant = null) -> void:
	if role != Role.OFF:
		_note.rpc(tag, data)


@rpc("any_peer", "reliable")
func _note(tag: String, data: Variant) -> void:
	noted.emit(multiplayer.get_remote_sender_id(), tag, data)
