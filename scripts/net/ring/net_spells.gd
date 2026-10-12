class_name NetSpells
extends RefCounted
## The spells online (docs/tidebreak/ring_netcode.md: "Ghost mode", "The host's words about spells", "Hits"): which machine
## decides what a spell does, the names its things go by on every machine, and the words that carry the host's decisions.
## Static; the session (RingNet) sets `net` while it is on. Offline every gate says yes, nothing is named, nothing is sent:
## the game as it always was.
##   who decides      decides(): offline, or the host. The host decides every meeting of a spell with a body or with another
##                    spell: hits, guards, catches, clashes, wear. A machine that does not decide runs every spell as a
##                    GHOST: it flies, grows, lights and sounds as offline and keeps its colliders, but decides nothing and
##                    waits for the host's word
##   bodies           on_body(n): what an effect of a spell on body `n` does here: APPLY (offline; the host on its own
##                    bodies; any machine applying the host's word, inside()), FORWARD (the host on a puppet: sent to the
##                    body's owner, forward()), SKIP (a ghost's). here(n, op, args) is that gate at the top of each effect
##                    (BendR3.deliver, BendStatus' effects, a guard's whiff); owns(n): the body is this machine's (a self
##                    effect: a heal, a dash's own motion)
##   things           decide(thing, op, args): a decision about a spell thing (an end, a wall worn) made here now: done here
##                    offline, inside a host's word, inside a cast's run (every machine runs a cast alike: what it does to
##                    the things it finds is the same everywhere) and on the host (its word `op` sent to the others then);
##                    never on a ghost outside those (it waits for the word)
##   the names        every spell thing made while a cast runs is named "<cast id>:<n>" in the order it is made (tag(): the
##                    same code with the same inputs makes the same things in the same order on every machine); a thing the
##                    host makes by a decision outside a cast (steam where two met, a puddle) is named in a decision run of
##                    its own, "h<seq>:<n>", and made on the others by its word (spawned()). find(id) a thing by its name
##   the host's words word(w) to every other machine, apply_word(w) there (inside a verdict): "end" a thing ended (BendBolt,
##                    BendZone), "bolt" a bolt turned or changed (its state), "guard" a guard's result (BendZone.report on
##                    every machine), "wall_hit" a raised wall worn, "zone" a zone made by a decision
##   hits             forward(op, n, args): the host's effect on a puppet sent to its owner; apply_hit(h) there runs it on
##                    his own body inside a verdict (BendR3.take, BendStatus' effects); "hit_by" and "jab_guarded" go to
##                    the attacker's owner (his jab string, SwayCaster.note_hit)
## Values on the wire: a body by its net id ({"@b": id}: RingNet.net_id_of), a spell thing by its name ({"@e": name}), any
## other node as null (enc, dec).

enum { APPLY, SKIP, FORWARD }

const ID_META := &"net_id"
## A thing's ends that are its own (its range, the deck's lip, the world, its life, its owner gone: the same on every
## machine; a guard its owner drops: his machine's), never a word.
const OWN_ENDS := ["range", "lip", "world", "life", "owner", "drop"]

## The session while it is on (RingNet), else null.
static var net: RingNet = null
## The run naming the things made now ({} none): {id, n}.
static var _ctx := {}
## How deep this machine is in applying the host's words (inside()).
static var _verdict := 0
## name -> WeakRef of the thing.
static var _things := {}
static var _seq := 0
## Tests: the words and hits sent and applied here (newest last, at most 64 each).
static var sent: Array = []
static var applied: Array = []


# ---------------------------------------------------------------- who decides
static func online() -> bool:
	return net != null and is_instance_valid(net) and net.role != RingNet.Role.OFF


static func decides() -> bool:
	return not online() or net.is_host()


## Whether body `n` is this machine's own (offline: every body).
static func owns(n: Node) -> bool:
	return not online() or n == null or not is_instance_valid(n) or not n.has_meta(RingNet.PUPPET_META)


## Whether this machine is applying the host's word now.
static func inside() -> bool:
	return _verdict > 0


static func on_body(n: Node) -> int:
	if not online() or _verdict > 0:
		return APPLY
	if not net.is_host():
		return SKIP
	return FORWARD if n != null and is_instance_valid(n) and n.has_meta(RingNet.PUPPET_META) else APPLY


## The gate of effect `op` of a spell on body `n` (see the header): true when it is done here now; false when it is not (a
## ghost's, or sent to the body's owner with `args`).
static func here(n: Node, op: String, args: Array = []) -> bool:
	match on_body(n):
		APPLY:
			return true
		FORWARD:
			forward(op, n, args)
	return false


## The gate of a decision `op` about spell thing `thing` (see the header): true when it is made here now.
static func decide(thing: Node, op: String, args: Array = []) -> bool:
	if not online() or _verdict > 0 or not _ctx.is_empty():
		return true
	if not net.is_host():
		return false
	var id := id_of(thing)
	if id != "":
		word([op, id] + (enc(args) as Array))
	return true


# ---------------------------------------------------------------- the names
## A run that names what it makes begins (a cast's: its id; the host's decision: "" for a fresh one): the run before it,
## for run_end.
static func run_begin(id := "") -> Dictionary:
	var keep := _ctx
	if id == "":
		_seq += 1
		id = "h%d" % _seq
	_ctx = {"id": id, "n": 0}
	return keep


static func run_end(keep: Dictionary) -> void:
	_ctx = keep


## The run naming things now ({} none): kept by a cast's later parts (a volley's later bolts) and run again with it (with()).
static func ctx() -> Dictionary:
	return _ctx


## `f` called with `c` the run naming things (a cast's later part, made in its own run).
static func with(c: Dictionary, f: Callable) -> Variant:
	var keep := _ctx
	_ctx = c
	var out: Variant = f.call()
	_ctx = keep
	return out


## Spell thing `n` named in the run making it (none outside one, or offline).
static func tag(n: Node) -> void:
	if n == null or _ctx.is_empty() or not online():
		return
	var id := "%s:%d" % [String(_ctx.id), int(_ctx.n)]
	_ctx["n"] = int(_ctx.n) + 1
	n.set_meta(ID_META, id)
	_things[id] = weakref(n)
	if _things.size() > 512:
		for k: String in _things.keys():
			if (_things[k] as WeakRef).get_ref() == null:
				_things.erase(k)


static func id_of(n: Object) -> String:
	if n == null or not is_instance_valid(n) or not (n is Node) or not (n as Node).has_meta(ID_META):
		return ""
	return String((n as Node).get_meta(ID_META))


## The spell thing named `id` here (null: none, or gone).
static func find(id: String) -> Node:
	var w: Variant = _things.get(id)
	var n: Variant = (w as WeakRef).get_ref() if w is WeakRef else null
	return n as Node if n != null and is_instance_valid(n) else null


## A thing the host made by a decision, outside any run (`n`, made by `kind`'s maker with `args`): named in a decision run of
## its own and its word sent, so the others make it too (apply_word "zone"). Nothing offline, inside a run or on a ghost.
static func spawned(n: Node, kind: String, args: Array) -> void:
	if n == null or not online() or not net.is_host() or not _ctx.is_empty() or _verdict > 0:
		return
	var keep := run_begin()
	var run_id := String(_ctx.id)
	tag(n)
	run_end(keep)
	word([kind, run_id] + (enc(args) as Array))


# ---------------------------------------------------------------- the words
## The host's word `w` ([kind, ...]) to every other machine.
static func word(w: Array) -> void:
	if not online() or not net.is_host():
		return
	var e: Array = enc(w)
	_log(sent, e)
	net.send_word(e)


## The host's word `w` here (RingNet's): run inside a verdict.
static func apply_word(w: Array) -> void:
	if w.is_empty():
		return
	_log(applied, w)
	_verdict += 1
	var a: Array = dec(w) as Array
	match String(a[0]):
		"end":
			_end(String(a[1]), String(a[2]), a[3] as Vector3)
		"bolt":
			var b := find(String(a[1])) as BendBolt
			if b != null and not b.spent:
				b.net_state(a[2] as Dictionary)
		"guard":
			var owner := a[1] as Node
			if owner != null:
				BendZone.report(owner, String(a[2]), String(a[3]), String(a[4]))
		"wall_hit":
			var w2 := find(String(a[1])) as FormRaised
			if w2 != null:
				w2.apply_hit(float(a[2]), a[3] as Vector3, a[4] as Vector3)
		"zone":
			var by := a[2] as Node3D
			if by != null:
				var keep := run_begin(String(a[1]))
				BendZone.make(by, String(a[3]), a[4] as Vector3, a[5] as Dictionary, a[6] as Vector3)
				run_end(keep)
	_verdict -= 1


## A thing ended by the host's word: a bolt played out where the host ended it (BendBolt.net_end), a zone ended.
static func _end(id: String, why: String, at: Vector3) -> void:
	var n := find(id)
	if n is BendBolt:
		(n as BendBolt).net_end(why, at)
	elif n is BendZone:
		(n as BendZone).end()


# ---------------------------------------------------------------- hits
## The host's effect `op` on puppet `n` (its args `args`) sent to the body's owner (apply_hit there).
static func forward(op: String, n: Node, args: Array) -> void:
	if not online() or n == null or not is_instance_valid(n):
		return
	var peer := net.owner_of(n)
	if peer == 0 or peer == net.my_id():
		return
	var h := [op, enc(n)] + (enc(args) as Array)
	_log(sent, h)
	net.send_hit(peer, h)


## The host's word to attacker `by`'s owner (`op` with `args`): his jab string, his note of a hit (apply_hit "hit_by").
static func to_attacker(op: String, by: Node, args: Array) -> void:
	forward(op, by, args)


## An effect the host sent this machine for one of its own bodies (forward): run on it inside a verdict.
static func apply_hit(h: Array) -> void:
	if h.size() < 2:
		return
	_log(applied, h)
	var a: Array = dec(h) as Array
	var n := a[1] as Node
	if n == null or not is_instance_valid(n) or not owns(n):
		return
	_verdict += 1
	match String(a[0]):
		"hit":
			BendR3.take(n, float(a[2]), a[3] as Vector3, a[4] as Vector3, a[5] as Node, float(a[6]), a[7] as Vector3,
					a[8] as Dictionary)
		"hurt":
			BendStatus.hurt(n, float(a[2]), a[3] as Vector3, a[4] as Vector3, a[5] as Node, float(a[6]), a[7] as Dictionary)
		"knock":
			BendStatus.knock(n, a[2] as Vector3, a[3] as Node, a[4] as Dictionary)
		"root":
			BendStatus.root(n, float(a[2]))
		"slow":
			BendStatus.slow(n, float(a[2]))
		"rescue":
			BendStatus.rescue(n, a[2] as Node)
		"cast_mult":
			BendStatus.give_cast_mult(n, float(a[2]))
		"carry":
			BendZone.carry_wind(n)
		"whiff":
			BendZone.whiffed(n)
		"imprison":
			BendZone.imprison(n, float(a[2]))
		"hit_by":
			BendR3.hit_by(n, a[2] as Node, a[3] as Dictionary, a[4] as Dictionary)
		"jab_guarded":
			BendR3.jab_guarded(n)
	_verdict -= 1


# ---------------------------------------------------------------- the wire
## `v` for the wire: a body by its net id, a spell thing by its name, any other node null; arrays and dictionaries through.
static func enc(v: Variant) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			if v == null or not is_instance_valid(v) or not (v is Node):
				return null
			var bid := net.net_id_of(v as Node) if online() else 0
			if bid != 0:
				return {"@b": bid}
			var eid := id_of(v as Node)
			return {"@e": eid} if eid != "" else null
		TYPE_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(enc(x))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k: Variant in v:
				d[k] = enc((v as Dictionary)[k])
			return d
	return v


## The wire's `v` here (enc's back): a body by its net id, a thing by its name (null when there is none here).
static func dec(v: Variant) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(dec(x))
			return out
		TYPE_DICTIONARY:
			var d := v as Dictionary
			if d.size() == 1 and d.has("@b"):
				return net.body_by_net_id(int(d["@b"])) if online() else null
			if d.size() == 1 and d.has("@e"):
				return find(String(d["@e"]))
			var out := {}
			for k: Variant in d:
				out[k] = dec(d[k])
			return out
	return v


static func _log(into: Array, w: Array) -> void:
	into.append(w)
	if into.size() > 64:
		into.pop_front()


## Everything of a session gone (RingNet when it closes; the tests).
static func reset() -> void:
	_ctx = {}
	_verdict = 0
	_things.clear()
	sent.clear()
	applied.clear()
