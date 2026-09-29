class_name SnowPrints
extends Node
## Prints in the snow (SnowCover's): whoever walks the snow presses it down, and the snow that falls after fills the
## prints in. The trail map is an RG8 texture of the ground round the player (SIZE texels of TEXEL m; it moves with the
## player), each texel the snowfall total (SnowCover.total_units) when a foot pressed it, + 1 (0: untouched); the terrain
## shader (snow.gdshaderinc snow_pressed) shows a print as pressed until SNOW_FILL_UNITS of new snow have fallen on it.
## Walkers: the player (on foot), a companion or the spouse (boots), a horse (hooves), the wildlife by species (deer,
## wolf, fox, bison). Each leaves a print every stride of its kind, left and right of its line, only on snow (not under a
## roof, not in the air).
## The prints are also kept as records (where, when, whose, which way) for the game: prints_near() (tracking).
##
##   var prints := SnowCover.find(tree).prints
##   prints.prints_near(pos, 20.0, ["deer"])   # the deer prints within 20 m, newest first

const TEXEL := 0.1
const SIZE := 768
## The map moves with the player when they are this far from its middle (m).
const RECENTER_M := 16.0
const UPLOAD_S := 1.0 / 15.0
const MAX_RECORDS := 4000
const SCAN_S := 1.0
## A walker's print: stride (m between prints), half length along the way and half width (m), how far left or right of
## its line (m); `pairs`: two prints a stride (a horse's fore and hind), `apart` between them (m).
const KINDS := {
	"boot": {"stride": 0.72, "len": 0.14, "wid": 0.055, "spread": 0.11},
	"hoof": {"stride": 0.95, "len": 0.075, "wid": 0.07, "spread": 0.2, "pairs": true, "apart": 1.3},
	"deer": {"stride": 0.55, "len": 0.045, "wid": 0.035, "spread": 0.08, "pairs": true, "apart": 0.8},
	"wolf": {"stride": 0.62, "len": 0.055, "wid": 0.045, "spread": 0.06},
	"fox": {"stride": 0.42, "len": 0.035, "wid": 0.03, "spread": 0.03},
	"bison": {"stride": 0.8, "len": 0.085, "wid": 0.08, "spread": 0.22, "pairs": true, "apart": 1.6},
}
const SPECIES_KIND := {"deer": "deer", "wolf": "wolf", "fox": "fox", "bison": "bison"}

var cover: SnowCover
var image: Image
## The trail texture the shaders sample (a global uniform): kept for the whole run, as the canopy map's, so it is never freed
## while the renderer still holds it (a texture freed with the level crashed the quit).
static var texture: ImageTexture
## World x, z of the map's corner (texel 0, 0).
var origin := Vector2.ZERO
## The prints (for the game): {x, z, t (core minutes), kind, yaw}, oldest first.
var records: Array = []
## Prints pressed so far (tests).
var stamped := 0

var _walkers := {}          ## instance id -> {node, kind, last (Vector3), side, placed}
var _scan := 0.0
var _upload := 0.0
var _dirty := false
var _started := false


func _ready() -> void:
	image = Image.create(SIZE, SIZE, false, Image.FORMAT_RG8)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)


func _physics_process(delta: float) -> void:
	if cover == null or cover.depth_m <= 0.005:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	if not _started:
		_started = true
		_center_on(player.global_position)
		_publish()
	elif Vector2(player.global_position.x - (origin.x + SIZE * TEXEL * 0.5), player.global_position.z - (origin.y + SIZE * TEXEL * 0.5)).length() > RECENTER_M:
		_center_on(player.global_position)
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_S
		_find_walkers(player)
	for id: int in _walkers.keys():
		_walk(_walkers[id])
	_upload -= delta
	if _dirty and _upload <= 0.0:
		_upload = UPLOAD_S
		_dirty = false
		texture.update(image)
		_publish()


func _publish() -> void:
	SnowCover._global(&"snow_trail", texture)
	SnowCover._global(&"snow_trail_rect", Vector4(origin.x, origin.y, SIZE * TEXEL, SIZE * TEXEL))


## Who walks the snow now: the player on foot, the other people, the horses, the wildlife.
func _find_walkers(player: Node3D) -> void:
	var seen := {}
	var scene := get_tree().current_scene
	var cands: Array = [[player, "boot"]]
	if scene:
		for c in scene.get_children():
			if c is Horse:
				cands.append([c, "hoof"])
			elif (c is FrontierPlayer and c != player) or c is Spouse:
				cands.append([c, "boot"])
	for n in get_tree().get_nodes_in_group(Spouse.KEEP):
		cands.append([n, "boot"])
	for n in get_tree().get_nodes_in_group(&"wildlife"):
		if n is WildAnimal:
			var sp := String((n as WildAnimal).species)
			cands.append([n, String(SPECIES_KIND.get(sp, "deer"))])
	for pair: Array in cands:
		var n := pair[0] as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var id := n.get_instance_id()
		seen[id] = true
		if not _walkers.has(id):
			_walkers[id] = {"node": n, "kind": pair[1], "last": n.global_position, "side": 1.0, "placed": false}
	for id: int in _walkers.keys():
		if not seen.has(id):
			_walkers.erase(id)


## A walker's prints: one every stride along its way, left and right, while it is on the snow.
func _walk(w: Dictionary) -> void:
	var n := w.node as Node3D
	if n == null or not is_instance_valid(n):
		return
	var p := n.global_position
	if n is FrontierPlayer and (n as FrontierPlayer).riding != null:
		w.last = p                 # (in the saddle: the horse's hooves print, not the rider's boots)
		return
	var ground := FrontierTerrain.height_at(p.x, p.z)
	if p.y - ground > 0.35 or cover.depth_at(p) <= 0.005:
		w.last = p
		return
	var k: Dictionary = KINDS[w.kind]
	var d := Vector2(p.x - (w.last as Vector3).x, p.z - (w.last as Vector3).z)
	if d.length() < float(k.stride):
		return
	var dir := d.normalized()
	var side := Vector2(-dir.y, dir.x)
	var at := Vector2(p.x, p.z) + side * float(k.spread) * float(w.side)
	stamp(at, dir, w.kind)
	if bool(k.get("pairs", false)):
		stamp(at - dir * float(k.apart) - side * float(k.spread) * float(w.side) * 2.0, dir, w.kind)
	w.side = -float(w.side)
	w.last = p


## Presses a print of `kind` at world xz `at`, its long axis along `dir`.
func stamp(at: Vector2, dir: Vector2, kind: String) -> void:
	var k: Dictionary = KINDS.get(kind, KINDS.boot)
	var hl := float(k.len)
	var hw := float(k.wid)
	var v := (int(cover.total_units) % 65535) + 1
	var col := Color8(v >> 8, v & 255, 0)
	var r := maxf(hl, hw) + TEXEL
	var i0 := int(floor((at.x - r - origin.x) / TEXEL))
	var i1 := int(floor((at.x + r - origin.x) / TEXEL))
	var j0 := int(floor((at.y - r - origin.y) / TEXEL))
	var j1 := int(floor((at.y + r - origin.y) / TEXEL))
	var side := Vector2(-dir.y, dir.x)
	var hit := false
	for j in range(maxi(j0, 0), mini(j1, SIZE - 1) + 1):
		for i in range(maxi(i0, 0), mini(i1, SIZE - 1) + 1):
			var c := origin + Vector2(i + 0.5, j + 0.5) * TEXEL - at
			var a := c.dot(dir) / (hl + TEXEL * 0.5)
			var b := c.dot(side) / (hw + TEXEL * 0.5)
			if a * a + b * b <= 1.0:
				image.set_pixel(i, j, col)
				hit = true
	if not hit:
		# (a print smaller than a texel: its middle texel)
		var ic := int(floor((at.x - origin.x) / TEXEL))
		var jc := int(floor((at.y - origin.y) / TEXEL))
		if ic >= 0 and jc >= 0 and ic < SIZE and jc < SIZE:
			image.set_pixel(ic, jc, col)
	_dirty = true
	stamped += 1
	var core := cover._core()
	records.append({"x": at.x, "z": at.y, "t": float(core.state.minutes) if core else 0.0, "kind": kind, "yaw": atan2(-dir.x, -dir.y)})
	if records.size() > MAX_RECORDS:
		records = records.slice(records.size() - MAX_RECORDS)


## How pressed the snow is at world xz now (the texel's print, filling in with the snow since): 0..1 (tests, the game).
func pressed_at(xz: Vector2) -> float:
	var i := int(floor((xz.x - origin.x) / TEXEL))
	var j := int(floor((xz.y - origin.y) / TEXEL))
	if i < 0 or j < 0 or i >= SIZE or j >= SIZE:
		return 0.0
	var c := image.get_pixel(i, j)
	var stamp_v := roundf(c.r * 255.0) * 256.0 + roundf(c.g * 255.0)
	if stamp_v < 0.5:
		return 0.0
	var since := fposmod(cover.total_units - (stamp_v - 1.0), 65536.0)
	return clampf(1.0 - since / 60.0, 0.0, 1.0)


## The prints within `r` m of `pos` (of `kinds`, all when empty; younger than `max_age_min` game minutes), newest first.
func prints_near(pos: Vector3, r: float, kinds: Array = [], max_age_min := INF) -> Array:
	var out: Array = []
	var core := cover._core() if cover else null
	var now := float(core.state.minutes) if core else 0.0
	for i in range(records.size() - 1, -1, -1):
		var rec: Dictionary = records[i]
		if now - float(rec.t) > max_age_min:
			break
		if not kinds.is_empty() and not (rec.kind in kinds):
			continue
		if Vector2(float(rec.x) - pos.x, float(rec.z) - pos.z).length() <= r:
			out.append(rec)
	return out


## Moves the map so its middle is at `pos` (what is pressed stays where it is in the world).
func _center_on(pos: Vector3) -> void:
	var span := SIZE * TEXEL
	var o := Vector2(snappedf(pos.x - span * 0.5, TEXEL), snappedf(pos.z - span * 0.5, TEXEL))
	var shift := Vector2i(roundi((o.x - origin.x) / TEXEL), roundi((o.y - origin.y) / TEXEL))
	if shift == Vector2i.ZERO and _started:
		return
	var moved := Image.create(SIZE, SIZE, false, Image.FORMAT_RG8)
	if _started and absi(shift.x) < SIZE and absi(shift.y) < SIZE:
		var src := Rect2i(maxi(shift.x, 0), maxi(shift.y, 0), SIZE - absi(shift.x), SIZE - absi(shift.y))
		moved.blit_rect(image, src, Vector2i(maxi(-shift.x, 0), maxi(-shift.y, 0)))
	image = moved
	origin = o
	texture.update(image)
	_publish()
