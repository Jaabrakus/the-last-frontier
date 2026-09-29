extends StaticBody3D
## The river's ice underfoot (SnowCover's; user 2026-09-28: the ice "is visual only. You can't walk on it yet" - "fix
## these"): where the river shader draws ice thick enough to stand on (the water shallower than SnowCover.ice_m less
## FIRM_M: back from its thin, dark new edge), slabs at the water's surface the player, the horse and the rest walk on.
## Built round the player (REACH m of the river each way, again when they have gone REBUILD_M or the ice has grown or
## shrunk by REBUILD_ICE_M), in strips STEP m along the river, each strip's frozen spans across it (sampled every ACROSS
## m) a box. The rapids stay open. Not a roof (SnowCover.build_shelter skips GROUP), stone underfoot (Sfx surface).
## No class_name: SnowCover preloads it.

const GROUP := &"river_ice"
const STEP := 2.0
const ACROSS := 0.5
const REACH := 120.0
const REBUILD_M := 40.0
const REBUILD_ICE_M := 0.1
## Ice this much back from its edge (m of water depth) bears a man.
const FIRM_M := 0.12
const THICK := 0.12
## The rapids keep open water from this much white water (WorldRiver.rapid_at).
const OPEN_RAPID := 0.25

var cover: Node
## The ice the slabs were built for (m of water depth; 0 none) and where.
var built_ice := 0.0
var built_at := Vector3.INF
## Slabs now (tests).
var slabs := 0

var _check := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	set_meta(&"surface", "stone")
	collision_mask = 0


func _physics_process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or cover == null or not WorldRiver.has_water():
		return
	_check = 0.5
	var ice: float = cover.ice_m
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	if ice < FIRM_M + 0.02:
		if slabs > 0:
			clear()
		built_ice = 0.0
		return
	var p := player.global_position
	var moved := built_at == Vector3.INF or Vector2(p.x - built_at.x, p.z - built_at.z).length() > REBUILD_M
	if moved or absf(ice - built_ice) > REBUILD_ICE_M:
		build(p, ice)


func clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	slabs = 0


## The slabs within REACH of `at` for ice over `ice` m of water.
func build(at: Vector3, ice: float) -> void:
	clear()
	built_ice = ice
	built_at = at
	var zr := WorldRiver.z_range()
	var bank := WorldRiver.bank()
	var reach := ice - FIRM_M
	var z := maxf(zr.x, snappedf(at.z - REACH, STEP))
	var z1 := minf(zr.y, at.z + REACH)
	while z <= z1:
		var zc := z + STEP * 0.5
		var cx := WorldRiver.x_at(zc)
		if absf(cx - at.x) < REACH + bank and WorldRiver.rapid_at(zc) < OPEN_RAPID:
			var lv := WorldRiver.level_at(zc)
			var run_from := INF
			var x := cx - bank
			while x <= cx + bank + ACROSS:
				var d := WorldRiver.depth_at(Vector3(x, 0.0, zc)) if x <= cx + bank else 0.0
				var frozen := d > 0.005 and d < reach
				if frozen and run_from == INF:
					run_from = x
				elif not frozen and run_from != INF:
					_slab(run_from - ACROSS * 0.5, x - ACROSS * 0.5, z, lv)
					run_from = INF
				x += ACROSS
		z += STEP


func _slab(x0: float, x1: float, z: float, top: float) -> void:
	if x1 - x0 < 0.4:
		return
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, THICK, STEP + 0.05)
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3((x0 + x1) * 0.5, top - THICK * 0.5, z + STEP * 0.5)
	add_child(cs)
	slabs += 1
