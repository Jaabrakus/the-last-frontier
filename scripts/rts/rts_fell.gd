class_name RtsFell
extends RefCounted
## A worker told to fell trees (RtsMode: a right click on a tree; Shift queues the next): walks to the tree, takes the felling axe in
## hand, swings it at the trunk (the sparring stand-ins' own swing clips), and when the strokes are done the tree comes down as the
## player's does (GatherTools.fell_tree: the same FelledTree and stump), then the next tree in her queue, or she is done.
## It runs as Spouse.rts_task. The strokes a tree takes are the player's (GatherTools.strokes_to_fell: the diameter and the wood)
## times WORKER_SLOW (she is no woodcutter); workers on the same tree add their strokes (SHARED: tree -> strokes so far).

const STROKE_S := 1.2
const WORKER_SLOW := 1.35
const REACH := 0.55                  ## from the trunk's surface when she stands to it (m)
const OWN_PATH := "res://animations_extra/Frontier_Own.res"
const SWING := "own/own-axe-d"
const AXE := "axe"

## tree index -> the stroke power put in by everyone so far.
static var shared := {}

var body: Spouse
var gather: GatherTools
var tree: Dictionary
var queue: Array = []                ## trees (describe dictionaries) after this one
var state := "walk"                  ## "walk", "chop", "done"
var felled: FelledTree
var _t := 0.0
var _stroke_t := 0.0
var _need := 1.0
var _stand := Vector3.INF
var _best_d := INF
var _stuck_t := 0.0
var _side := 0                        ## the side of the tree she has tried to stand on


## Gives `w` the tree `d` (VegHarvest.describe) to fell; with `queue_it`, after the trees she has. Returns the task.
static func assign(w: Spouse, g: GatherTools, d: Dictionary, queue_it := false) -> RtsFell:
	var cur := w.get_meta(&"rts_fell", null) as RtsFell
	if queue_it and cur != null and cur.state != "done" and w.rts_task.is_valid():
		cur.queue.append(d)
		return cur
	cancel(w)
	var t := RtsFell.new()
	t.body = w
	t.gather = g
	t.tree = d
	w.orders.clear()
	w.order_ways.clear()
	w.order_acts.clear()
	w._order_set = false
	if w.nav != null:
		w.nav.reset()
	if w.sc != null:
		w.sc.cancel("told to fell")
	w.set_meta(&"rts_fell", t)
	w.rts_task = t.step
	return t


## Stops what `w` is felling and puts the axe away.
static func cancel(w: Spouse) -> void:
	var cur := w.get_meta(&"rts_fell", null) as RtsFell
	if cur != null:
		cur._put_away()
	w.set_meta(&"rts_fell", null)
	w.rts_task = Callable()


func tree_index() -> int:
	return int(tree.get("i", -1))


func _tree_pos() -> Vector3:
	return tree.pos as Vector3


func step(dt: float) -> Variant:
	if body == null or not is_instance_valid(body) or gather == null or not is_instance_valid(gather):
		return null
	var h := gather.harvest
	if h == null or h.describe("tree", "tree", tree_index()).is_empty():
		return _next()          # (already down: someone else's work)
	match state:
		"walk":
			var tp := _tree_pos()
			if _stand == Vector3.INF:
				var from := body.global_position - tp
				from.y = 0.0
				from = from.normalized() if from.length() > 0.05 else Vector3.RIGHT
				_stand = tp + from * (float(tree.radius) + REACH + 0.35)
				_stand.y = FrontierTerrain.height_at(_stand.x, _stand.z)
			var d := Vector2(_stand.x - body.global_position.x, _stand.z - body.global_position.z).length()
			if d <= 0.8:
				_begin_chop()
				return [Vector3.ZERO, 0.0]
			# no nearer in a few seconds: the other side of the tree (a quarter turn), and after the fourth the tree is let go
			if d < _best_d - 0.8:
				_best_d = d
				_stuck_t = 0.0
			else:
				_stuck_t += dt
				if _stuck_t > 6.0:
					_stuck_t = 0.0
					_best_d = INF
					_side += 1
					if _side >= 4:
						return _next()
					var ang := _side * PI * 0.5
					var off := (_stand - tp)
					off.y = 0.0
					_stand = tp + off.rotated(Vector3.UP, ang)
					_stand.y = FrontierTerrain.height_at(_stand.x, _stand.z)
					if body.nav != null:
						body.nav.reset()
			return body.walk_to(_stand, Spouse.WALK_SPEED, 0.7)
		"chop":
			_chop(dt)
			return [Vector3.ZERO, 0.0]
	return null


func _begin_chop() -> void:
	state = "chop"
	_t = 0.0
	_stroke_t = STROKE_S * 0.5
	_need = gather.strokes_to_fell(tree) * WORKER_SLOW
	var g := WorkerGear.of(body)
	if g != null:
		g.hold(AXE, true)
	if body.ap != null and not body.ap.has_animation_library("own"):
		var own := load(OWN_PATH) as AnimationLibrary
		if own != null:
			body.ap.add_animation_library("own", own)
	body._phase = ""
	body._look_on = true
	body._look_at = _tree_pos()


func _chop(dt: float) -> void:
	var to := _tree_pos() - body.global_position
	body._face = atan2(-to.x, -to.z)
	_stroke_t += dt
	if _stroke_t >= STROKE_S:
		_stroke_t = 0.0
		var i := tree_index()
		shared[i] = float(shared.get(i, 0.0)) + 1.0
		if body.ap != null and body.ap.has_animation(SWING):
			body.ap.speed_scale = 1.0
			body.ap.play(SWING, 0.1)
			body._clip = "own"
		if DisplayServer.get_name() != "headless" and body.is_inside_tree():
			GatherFx.wood_chips(body.get_tree().current_scene, _tree_pos() + Vector3.UP * 1.1, -Vector3(to.x, 0.0, to.z).normalized(), 5)
		if float(shared[i]) >= _need:
			felled = gather.fell_tree(i, body.global_position, -body.global_basis.z, false)
			shared.erase(i)
			_next()


## The next queued tree, or done (null: the task ends).
func _next() -> Variant:
	_put_away()
	if queue.is_empty():
		state = "done"
		body.set_meta(&"rts_fell", null)
		return null
	tree = queue.pop_front()
	state = "walk"
	_stand = Vector3.INF
	_best_d = INF
	_stuck_t = 0.0
	_side = 0
	return [Vector3.ZERO, 0.0]


func _put_away() -> void:
	if body == null or not is_instance_valid(body):
		return
	var g := WorkerGear.of(body)
	if g != null:
		g.hold(AXE, false)
	body._look_on = false
	if body.ap != null:
		body._clip = ""
		body._show(Spouse.CLIP_IDLE)
