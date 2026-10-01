class_name RtsOrders
extends RefCounted
## What a right click means (RtsMode): `command(mode, screen_pos, queue)` looks at what is under the cursor and gives the selection
## the order for it:
##   the ground   go there, spread in a formation
##   a tree       fell it (RtsFell): each worker takes the nearest tree not taken yet, round the one clicked; Shift queues
##                the tree after the ones she has
## (More kinds follow as the household can do them: a beast to hunt, a foe to attack.)

const TREE_PICK_M := 1.1            ## how far from a trunk's surface the click still means the tree
const SPREAD_M := 14.0              ## how far from the tree clicked the others look for one each


## What is under the screen point: {kind: "ground", at} or {kind: "tree", at, tree: describe()}.
static func pick(mode: RtsMode, p: Vector2) -> Dictionary:
	var at := mode.ground_at(p)
	if not at.is_finite():
		return {}
	var h := _harvest(mode)
	if h != null:
		for d: Dictionary in h.near(at, TREE_PICK_M):
			if String(d.type) == "tree" and float(d.dist) <= TREE_PICK_M:
				return {"kind": "tree", "at": at, "tree": d}
	return {"kind": "ground", "at": at}


static func _harvest(mode: RtsMode) -> VegHarvest:
	return VegHarvest.find(mode.get_tree()) if mode != null and mode.is_inside_tree() else null


static func command(mode: RtsMode, p: Vector2, queue := false) -> int:
	var t := pick(mode, p)
	if t.is_empty():
		return 0
	match String(t.kind):
		"ground":
			return mode.order_to(t.at, queue)
		"tree":
			return fell(mode, t.tree, queue)
	return 0


## The selection fells: the first the tree `d`, the others the nearest trees round it, not one taken twice; with fewer trees than
## workers the rest work on `d` with the first (their strokes add up).
static func fell(mode: RtsMode, d: Dictionary, queue := false) -> int:
	var h := _harvest(mode)
	var g := mode.player.gather if mode.player != null else null
	if h == null or g == null:
		return 0
	var taken := {int(d.i): true}
	var pool: Array = []
	for o: Dictionary in h.near(d.pos as Vector3, SPREAD_M):
		if String(o.type) == "tree" and int(o.i) != int(d.i) and float(o.radius) > 0.12:
			pool.append(o)
	var n := 0
	for k in mode.selected.size():
		var w := mode.selected[k]
		if not is_instance_valid(w):
			continue
		var mine := d
		if k > 0:
			mine = d
			for o: Dictionary in pool:
				if not taken.has(int(o.i)):
					mine = o
					taken[int(o.i)] = true
					break
		RtsFell.assign(w, g, mine, queue)
		n += 1
	mode._pulse_at(d.pos)
	return n
