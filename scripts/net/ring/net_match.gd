class_name NetMatch
extends RefCounted
## The match online (docs/tidebreak/ring_netcode.md, "The match"): one referee, the host; every other machine's RingMode and
## RingRules a mirror of the host's. Static; NetSpells.net is the session.
##   the referee  referee(mode): offline, or the host. Only the referee moves the match on: the countdown's end, the clock,
##                a round's end (a side out of lives, the bell), sudden death, the next round, the match's end. Each is
##                told the others as it happens (told(): "m_fight", "m_end", "m_sudden", "m_next", "m_done"), and they run
##                the same RingMode step (apply_word, inside a verdict: their own match the host's, side for side in their
##                own numbering: local_team)
##   the %        each body's % is its owner's (RingRules.on_hit runs on his machine): it goes with his state (NetBody's pct
##                slot) and every other machine shows it (RingRules.mirror_pct: the HUD's numbers)
##   falls        a body's owner sees it fall into the water (RingRules._stock_frame) and tells the host (report_fall: who
##                knocked him in, his %, the hit's tag); the host takes the life on its books (RingRules.take_ko: the
##                ko signal, RingMode._on_ko: the line, the body hidden, its respawn's timer) and tells every machine
##                ("m_ko": the lives left), each taking it on its own books the same way; on its owner's machine the body is
##                put back on its spout when its time comes (RingMode._do_respawn)
## A machine that is no referee waits for the host's words; offline everything here is a no-op.

## Whether this machine moves match `m` on (offline, the host).
static func referee(m: RingMode) -> bool:
	return m == null or m.net == null or not is_instance_valid(m.net) or m.net.role != RingNet.Role.CLIENT


## Whether a host's word is being applied here now (its RingMode steps run on a client then).
static func applying() -> bool:
	return NetSpells.inside()


## The referee's step `w` of the match told the others (nothing offline or on a client).
static func told(m: RingMode, w: Array) -> void:
	if m != null and m.net != null and is_instance_valid(m.net) and m.net.is_host():
		NetSpells.word(w)


## Team `host_team` of the host's numbering as `m`'s machine numbers it (its own side 0), and back (the same swap).
static func local_team(m: RingMode, host_team: int) -> int:
	if host_team < 0 or m == null or m.net == null:
		return host_team
	return m.net.local_team(host_team)


## A host's match word `a` (decoded) here: its RingMode step run on this machine.
static func apply_word(a: Array) -> void:
	var m := RingMode.find(NetSpells.net.get_tree()) if NetSpells.net != null else null
	if m == null or a.is_empty():
		return
	match String(a[0]):
		"m_fight":
			if m.phase == "COUNTDOWN":
				m._fight()
		"m_end":
			m._end_round(local_team(m, int(a[1])), String(a[2]))
		"m_sudden":
			m.net_sudden()
		"m_next":
			var r := int(a[1])
			if m.round < r:
				m.round = r - 1
				m.next_round()
		"m_done":
			if m.phase != "DONE":
				m._done()
		"m_ko":
			var b := a[1] as Node3D
			if b != null and m.rules != null:
				m.rules.take_ko(b, a[2] as Node, float(a[3]), String(a[4]), int(a[5]))


## Body `b` (this machine's own) fell into the water (RingRules._stock_frame, a client's): the host told (who knocked him in,
## his %, the hit's tag), once until the host's word comes back.
static func report_fall(b: Node3D, by: Node, pct: float, tag: String) -> void:
	var net := NetSpells.net
	if net == null or not net.is_client() or b.has_meta(&"net_fell"):
		return
	b.set_meta(&"net_fell", true)
	net.send_report(NetSpells.enc(["fell", b, by, pct, tag]) as Array)


## A client's report `r` (decoded) from peer `from`, on the host: a fall of his own body taken on the host's books (its word
## to every machine follows from RingRules.take_ko).
static func on_report(r: Array, from: int) -> void:
	var net := NetSpells.net
	if net == null or not net.is_host() or r.is_empty():
		return
	match String(r[0]):
		"fell":
			var b := r[1] as Node3D
			if b == null or net.owner_of(b) != from:
				return                                  # (a fall is told by its own body's machine only)
			var rules := RingRules.current()
			if rules != null:
				rules.take_ko(b, r[2] as Node, float(r[3]), String(r[4]))
