class_name ToolCarry
extends Node
## A worker's borrowed tools on her body (scripts/companion/tool_pool.gd): she walks to the chest, rack or barrel for what her
## plan has claimed before she goes to the work, and back with what is due (another job's tools, the end of her day), through
## the body's errand hook (Spouse.errand: [direction, speed] each physics frame; null when there is nothing to fetch or put
## back). What she holds rides on her body as the player's gear does (WorkerGear: the SlingRig's slings and belt hooks, the
## knife in its sheath); only while she is at the work does its tool go to her right hand (WorkerGear.hold: the weapon's own
## grip, the gathering tools' one-hand grip), and back after. The hunt puts its own weapon in her hand (HuntRun).
## Household._spawn attaches it (TOOLS).

const PROP := "r_hand_prop_attachment"
## The model's own +Y along the fist, blade out (SparringPartner.PIPE).
const PIPE := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3(0, 0, -0.035))
## At the chest within this (m); gives up walking after this long (s) and takes or puts it there and then.
const REACH := 1.5
const GIVE_UP_S := 150.0

var body: Spouse
var sc: SpouseCore
var _cb := Callable()
var _t := 0.0
var gear: WorkerGear
var _shown := ""
var _pause := 0.0


static func attach(b: Spouse) -> ToolCarry:
	var c := ToolCarry.new()
	c.name = "ToolCarry"
	c.body = b
	c.sc = b.sc
	b.add_child(c)
	c.gear = WorkerGear.attach(b)
	return c


func _ready() -> void:
	process_physics_priority = -2           # before her body decides (the errand is set for this frame)
	process_priority = 100
	_cb = Callable(self, "_errand")


func _exit_tree() -> void:
	var p := ToolPool.of(sc)
	if p != null and p.walkers.get(sc.worker_id) == self:
		p.walkers.erase(sc.worker_id)


func pool() -> ToolPool:
	return ToolPool.of(sc) if sc != null else null


func _physics_process(_dt: float) -> void:
	var p := pool()
	if p == null or body == null or not is_instance_valid(body):
		return
	p.walkers[sc.worker_id] = self
	if not sc.busy() and not _next(p).is_empty() and not body.errand.is_valid():
		body.errand = _cb


## The next thing to do: [kind, fetch] (put back what is due first, then fetch what is claimed), or [].
func _next(p: ToolPool) -> Array:
	var id := sc.worker_id
	for k: String in p.due.get(id, []):
		return [k, false]
	for k: String in p.claims.get(id, {}):
		if int(p.claims[id][k]) > 0:
			return [k, true]
	return []


func _errand(dt: float) -> Variant:
	var p := pool()
	if p == null or sc.busy() or sc.core.is_dead():
		_release()
		return null
	if _pause > 0.0:
		_pause -= dt
		return [Vector3.ZERO, 0.0]
	var nx := _next(p)
	if nx.is_empty():
		_release()
		return null
	var kind := String(nx[0])
	var fetch := bool(nx[1])
	var s := p.stock()
	var spot: Node3D = s.spot_for(kind, fetch) if s != null else null
	var at := spot.global_position if spot != null else Vector3.INF
	var flat := Vector2(at.x - body.global_position.x, at.z - body.global_position.z).length() if spot != null else 0.0
	if spot == null or flat <= REACH or _t > GIVE_UP_S:
		_do(p, kind, fetch)
		_t = 0.0
		if spot != null:
			_pause = 0.6                    # a moment at the lid
			var to := at - body.global_position
			body.set("_face", atan2(-to.x, -to.z))
		return [Vector3.ZERO, 0.0]
	_t += dt
	return body.walk_to(at, Spouse.WALK_SPEED, REACH * 0.8)


func _do(p: ToolPool, kind: String, fetch: bool) -> void:
	if fetch:
		p.collect(sc.worker_id, [kind])
		var c: Dictionary = p.claims.get(sc.worker_id, {})
		c.erase(kind)                        # none there after all: begin() says so
		if c.is_empty():
			p.claims.erase(sc.worker_id)
	else:
		p._return_due(sc.worker_id, kind)
		var d: Array = p.due.get(sc.worker_id, [])
		d.erase(kind)
		if d.is_empty():
			p.due.erase(sc.worker_id)


func _release() -> void:
	_t = 0.0
	_pause = 0.0
	if body != null and body.errand == _cb:
		body.errand = Callable()


# ---------------------------------------------------------------- in her hand
## The tool of her job in her hand while she is at the work (kneeling, chopping: the body's work phase), on her body
## otherwise; the hunt's weapon is the hunt's to show (HuntRun).
func _process(_dt: float) -> void:
	var p := pool()
	if p == null or body == null or body.sk == null or gear == null:
		return
	if sc.task == "hunt" or not sc.hunt.is_empty():
		_shown = ""
		return
	var want := ""
	var at_work := sc.busy() and String(body.get("_phase")) in ["in", "work", "out"]
	if at_work and body.idle_clip == "":
		want = _hand_kind(p)
	if want == _shown:
		return
	if _shown != "":
		gear.hold(_shown, false)
	_shown = want
	if want != "":
		gear.hold(want, true)


## The tool she works with: one of her job's kit she holds that has a model (a tool first).
func _hand_kind(p: ToolPool) -> String:
	var h := p.held_by(sc)
	var best := ""
	var bs := -1
	var kit: Dictionary = sc._run.get("tools", {}) if sc.busy() else {}
	for k: String in h:
		var m: Array = ToolPool.kind_row(k).get("model", [])
		if (m.size() < 2 and not WorkerGear.KIND_MAP.has(k)) or ToolPool.is_consumable(k) or not kit.has(k):
			continue
		var s := (2 if kit.has(k) else 0) + (1 if ToolPool.kind_row(k).get("class", "") == "tool" else 0)
		if s > bs:
			bs = s
			best = k
	return best


## The hand model of pool kind `kind` (tools.json model [library, kind], grip), placed for her fist; null when it has none.
static func build(kind: String) -> Node3D:
	var row := ToolPool.kind_row(kind)
	var m: Array = row.get("model", [])
	if m.size() < 2:
		return null
	var lib := String(m[0])
	var k := String(m[1])
	var n: Node3D = null
	match lib:
		"gather":
			n = GatherModels.build(k)
		"wildlife":
			n = WildlifeModels.build(k)
		"throwable":
			n = ThrowableModels.build(k)
		"weapon":
			n = WeaponModels.build(k)
	if n == null:
		return null
	n.name = "Held_" + kind
	n.transform = PIPE * Transform3D(Basis(), Vector3(0, -float(row.get("grip", 0.0)), 0))
	return n
