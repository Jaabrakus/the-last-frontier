class_name PeopleEmblem
extends Control
## An original emblem for a people in the character creator: a plant, landscape or craft of
## the people's homeland (data/customizer/creator.json "emblems" names them), drawn as line
## art in one ink colour on the same roundel for every people. No flags, heraldry, religious
## or sacred symbols, clan emblems, wampum, regalia or depictions of people.
##
## Drawn in a 100 x 100 box scaled to the control; `selected` brightens the ring and disc,
## `hovered` a little.

const INK := Color(0.9, 0.86, 0.76)
const DISC := Color(0.085, 0.09, 0.1)
const DISC_SELECTED := Color(0.16, 0.14, 0.11)
const RING := Color(0.52, 0.42, 0.28)
const RING_SELECTED := Color(0.93, 0.76, 0.42)

var people_id := ""
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var hovered := false:
	set(v):
		hovered = v
		queue_redraw()
var _k := 1.0
var _o := Vector2.ZERO
var _bg := DISC


func _init(id := "") -> void:
	people_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x, size.y)
	_k = side / 100.0
	_o = (size - Vector2(side, side)) * 0.5
	_bg = DISC_SELECTED if selected else (DISC.lightened(0.06) if hovered else DISC)
	draw_circle(_p(50, 50), 48.0 * _k, RING_SELECTED if selected else RING.lightened(0.15 if hovered else 0.0))
	draw_circle(_p(50, 50), 44.5 * _k, _bg)
	draw_arc(_p(50, 50), 41.5 * _k, 0.0, TAU, 64, (RING_SELECTED if selected else RING) * Color(1, 1, 1, 0.45), maxf(1.0, 0.8 * _k))
	var f := "_e_" + people_id
	if has_method(f):
		call(f)


# --- drawing helpers (100 x 100 box) ----------------------------------------------------------

func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _k


func _pts(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(q[0], q[1]) if q is Array else _o + (q as Vector2) * _k)
	return out


func _poly(pts: Array, bg := false) -> void:
	var pv := _pts(pts)
	if Geometry2D.triangulate_polygon(pv).is_empty():
		return
	draw_colored_polygon(pv, _bg if bg else INK)


func _line(pts: Array, w: float, bg := false) -> void:
	draw_polyline(_pts(pts), _bg if bg else INK, w * _k, true)


func _circle(x: float, y: float, r: float, bg := false) -> void:
	draw_circle(_p(x, y), r * _k, _bg if bg else INK)


func _arc(x: float, y: float, r: float, a0: float, a1: float, w: float, bg := false) -> void:
	draw_arc(_p(x, y), r * _k, deg_to_rad(a0), deg_to_rad(a1), 32, _bg if bg else INK, w * _k, true)


func _half_disc(x: float, y: float, r: float, bg := false) -> void:
	var pts := []
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(Vector2(x + r * cos(a), y + r * sin(a)))
	_poly(pts, bg)


func _wave(x0: float, x1: float, y: float, amp: float, waves: float, w: float, bg := false) -> void:
	var pts := []
	for i in 25:
		var t := i / 24.0
		pts.append(Vector2(lerpf(x0, x1, t), y + amp * sin(t * TAU * waves)))
	_line(pts, w, bg)


func _leaf(base: Vector2, dir: Vector2, length: float, width: float) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var pts := []
	for i in 9:
		var t := i / 8.0
		pts.append(base + d * length * t + n * width * sin(t * PI))
	for i in range(7, 0, -1):
		var t := i / 8.0
		pts.append(base + d * length * t - n * width * sin(t * PI))
	_poly(pts)


func _bezier(a: Vector2, c: Vector2, b: Vector2, n := 10) -> Array:
	var out := []
	for i in n + 1:
		var t := float(i) / n
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return out


# --- emblems ------------------------------------------------------------------------------------

## Oak leaf.
func _e_english() -> void:
	_poly([[50, 84], [46, 78], [38, 77], [40, 70], [31, 67], [35, 60], [27, 55], [33, 50], [29, 42], [37, 40],
			[36, 32], [44, 32], [45, 24], [50, 18], [55, 24], [56, 32], [64, 32], [63, 40], [71, 42], [67, 50],
			[73, 55], [65, 60], [69, 67], [60, 70], [62, 77], [54, 78]])
	_line([[50, 84], [50, 24]], 2.0, true)
	for v: Array in [[66, 38, 60], [52, 36, 46], [40, 41, 35]]:
		_line([[50, v[0]], [v[1], v[2]]], 1.2, true)
		_line([[50, v[0]], [100 - v[1], v[2]]], 1.2, true)
	_line([[50, 82], [50, 90]], 3.0)


## Flax in flower.
func _e_scots_irish() -> void:
	_line([[50, 50], [50, 90]], 2.5)
	_poly([[50, 70], [38, 62], [35, 64], [50, 75]])
	_poly([[50, 79], [62, 71], [65, 73], [50, 84]])
	for k in 5:
		var a := deg_to_rad(-90.0 + 72.0 * k)
		_circle(50 + 12.5 * cos(a), 38 + 12.5 * sin(a), 9.5)
	for k in 5:
		var a := deg_to_rad(-54.0 + 72.0 * k)
		_line([[50, 38], [50 + 20 * cos(a), 38 + 20 * sin(a)]], 1.0, true)
	_circle(50, 38, 5.0, true)
	_circle(50, 38, 2.5)


## Wheat sheaf.
func _e_french() -> void:
	var tie := Vector2(50, 64)
	for top: Vector2 in [Vector2(30, 26), Vector2(40, 20), Vector2(50, 17), Vector2(60, 20), Vector2(70, 26)]:
		_line([tie, top], 2.0)
		for i in 5:
			var t := 0.04 + i * 0.075
			var p := top.lerp(tie, t)
			var d := (tie - top).normalized()
			var n := Vector2(-d.y, d.x) * (2.6 if i % 2 == 0 else -2.6)
			_circle(p.x + n.x, p.y + n.y, 2.8)
	for bot: Vector2 in [Vector2(38, 90), Vector2(45, 91), Vector2(52, 91), Vector2(59, 90)]:
		_line([tie, bot], 2.0)
	_poly([[41, 61], [59, 61], [59, 68], [41, 68]])
	_line([[41, 64.5], [59, 64.5]], 1.0, true)


## Grape vine.
func _e_palatine() -> void:
	_line([[50, 34], [54, 26], [60, 21]], 2.5)
	_leaf(Vector2(58, 24), Vector2(1.0, -0.5), 22.0, 8.0)
	_arc(38, 26, 6.0, 0.0, 250.0, 1.6)
	for g: Array in [[37, 41], [49, 40], [61, 41], [43, 52], [55, 52], [67, 51], [49, 63], [61, 62], [55, 73]]:
		_circle(g[0], g[1], 5.6)


## Windmill.
func _e_dutch() -> void:
	_poly([[42, 48], [58, 48], [63, 86], [37, 86]])
	_poly([[39, 49], [50, 37], [61, 49]])
	var hub := Vector2(50, 42)
	for k in 4:
		var a := deg_to_rad(45.0 + 90.0 * k)
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		_line([hub, hub + d * 34.0], 2.4)
		_poly([hub + d * 9.0, hub + d * 34.0, hub + d * 34.0 + n * 8.0, hub + d * 9.0 + n * 8.0])
		for t in [16.0, 23.0, 30.0]:
			_line([hub + d * t, hub + d * t + n * 8.0], 1.0, true)
		_line([hub + d * 10.0 + n * 4.0, hub + d * 33.0 + n * 4.0], 1.0, true)
	_circle(50, 42, 3.2)
	_poly([[47, 86], [53, 86], [53, 76], [47, 76]], true)
	_line([[26, 87], [74, 87]], 2.0)


## Longhouse (the bark house of the Six Nations' towns).
func _e_haudenosaunee() -> void:
	_poly([[12, 76], [12, 58], [15, 50], [22, 45], [78, 45], [85, 50], [88, 58], [88, 76]])
	for x in range(20, 84, 8):
		_line([[x, 47], [x, 76]], 1.1, true)
	_line([[12, 60], [88, 60]], 1.2, true)
	for x in [32, 50, 68]:
		_poly([[x - 3, 44], [x + 3, 44], [x + 3, 48], [x - 3, 48]], true)
		_line([[x, 41], [x - 2, 36], [x + 1, 31], [x - 1, 26]], 1.4)
	_poly([[46, 76], [54, 76], [54, 64], [46, 64]], true)
	_line([[6, 78], [94, 78]], 2.2)


## River through a gap in the ridges.
func _e_lenape() -> void:
	# one wooded ridge, the river cut through it as a band of the background
	var ridge := _bezier(Vector2(10, 70), Vector2(20, 34), Vector2(40, 38), 8) + _bezier(Vector2(40, 38), Vector2(50, 30), Vector2(60, 38), 6).slice(1) \
			+ _bezier(Vector2(60, 38), Vector2(80, 32), Vector2(90, 70), 8).slice(1)
	_poly(ridge)
	var river := _bezier(Vector2(52, 36), Vector2(40, 52), Vector2(50, 60), 8) + _bezier(Vector2(50, 60), Vector2(60, 66), Vector2(48, 76), 8).slice(1)
	_line(river, 7.0, true)
	_wave(18, 82, 80, 1.6, 3.0, 2.4)
	_wave(26, 74, 87, 1.4, 2.5, 2.2)


## Wooded hills of the Ohio country.
func _e_shawnee() -> void:
	_poly([[8, 76], [16, 60], [30, 50], [46, 50], [58, 58], [64, 76]])
	for t: Array in [[26, 44], [36, 41], [46, 44]]:
		_line([[t[0], t[1] + 4], [t[0], t[1] + 10]], 2.0)
		_circle(t[0], t[1], 5.2)
	_line([[36, 80], [48, 64], [64, 56], [80, 58], [92, 72]], 3.0, true)
	_poly([[36, 80], [48, 64], [64, 56], [80, 58], [92, 72], [92, 80]])
	for t: Array in [[66, 49], [78, 51]]:
		_line([[t[0], t[1] + 4], [t[0], t[1] + 8]], 2.0)
		_circle(t[0], t[1], 5.0)
	_wave(18, 82, 87, 1.5, 3.0, 2.2)


## Sunrise over the sea (the Dawnland).
func _e_wabanaki() -> void:
	_half_disc(50, 60, 15.0)
	for k in 7:
		var a := deg_to_rad(180.0 + 22.5 * (k + 1))
		_line([Vector2(50, 60) + Vector2(cos(a), sin(a)) * 20.0, Vector2(50, 60) + Vector2(cos(a), sin(a)) * 29.0], 2.6)
	_wave(18, 82, 66, 1.6, 3.0, 2.6)
	_wave(24, 76, 74, 1.5, 2.5, 2.4)
	_wave(32, 68, 82, 1.3, 2.0, 2.2)


## Baobab tree.
func _e_west_african() -> void:
	_poly([[39, 84], [41, 66], [39, 52], [43, 44], [57, 44], [61, 52], [59, 66], [61, 84]])
	for br: Array in [[[44, 46], [34, 36], [25, 33]], [[46, 45], [42, 30]], [[54, 45], [58, 30]], [[56, 46], [66, 36], [75, 33]]]:
		_line(br, 3.4)
		var e: Array = br[br.size() - 1]
		_circle(e[0], e[1] - 3, 5.5)
	_circle(33, 34, 4.0)
	_circle(67, 34, 4.0)
	_line([[22, 86], [78, 86]], 2.2)


## Rainforest and river.
func _e_central_african() -> void:
	for t: Array in [[28, 50], [50, 42], [72, 48]]:
		_line([[t[0], t[1]], [t[0], 76]], 3.0)
	for c: Array in [[24, 46, 10.0], [37, 38, 10.5], [50, 32, 11.0], [63, 38, 10.5], [76, 45, 10.0]]:
		_circle(c[0], c[1], c[2])
	for c: Array in [[31, 42], [44, 35], [57, 35], [70, 42]]:
		_circle(c[0], c[1], 1.4, true)
	_wave(16, 84, 80, 1.6, 3.0, 2.6)
	_wave(24, 76, 87, 1.4, 2.5, 2.4)


## Coiled basket.
func _e_african_american() -> void:
	var pts := []
	for i in 400:
		var th := i / 400.0 * TAU * 7.5
		var r := 2.5 + 29.0 * i / 400.0
		pts.append(Vector2(50 + r * cos(th), 50 + r * sin(th)))
	_line(pts, 2.8)
	for k in 12:
		var a := deg_to_rad(15.0 + 30.0 * k)
		_line([Vector2(50, 50) + Vector2(cos(a), sin(a)) * 6.0, Vector2(50, 50) + Vector2(cos(a), sin(a)) * 30.0], 1.0, true)
	_arc(50, 50, 33.5, 0.0, 360.0, 3.0)


## Waves (a textile pattern).
func _e_japanese() -> void:
	for row: Array in [[40.0, [26, 50, 74]], [53.0, [38, 62]], [66.0, [26, 50, 74]], [79.0, [38, 62]]]:
		for x: int in row[1]:
			_half_disc(x, row[0], 12.8, true)
			for r in [11.5, 7.7, 3.9]:
				_arc(x, row[0], r, 180.0, 360.0, 2.0)


## Bamboo.
func _e_chinese() -> void:
	_line([[42, 88], [44, 16]], 6.0)
	for y in [70, 50, 30]:
		_line([[38, y], [48, y]], 1.6, true)
	_line([[58, 88], [56, 32]], 5.0)
	for y in [72, 52]:
		_line([[53, y], [61, y]], 1.4, true)
	_leaf(Vector2(44, 42), Vector2(-1.0, -0.45), 22.0, 3.8)
	_leaf(Vector2(56, 46), Vector2(1.0, -0.35), 22.0, 3.8)
	_leaf(Vector2(43, 60), Vector2(-1.0, 0.35), 20.0, 3.5)
	_leaf(Vector2(56, 34), Vector2(0.6, -1.0), 18.0, 3.2)


## Tiled roof with curved eaves.
func _e_korean() -> void:
	var top := _bezier(Vector2(8, 44), Vector2(30, 40), Vector2(34, 34), 6) + _bezier(Vector2(66, 34), Vector2(70, 40), Vector2(92, 44), 6)
	var bottom := _bezier(Vector2(90, 49), Vector2(72, 46), Vector2(50, 48), 6) + _bezier(Vector2(50, 48), Vector2(28, 46), Vector2(10, 49), 6).slice(1)
	_poly(top + bottom)
	_line([[32, 35], [68, 35]], 3.2)
	for x in range(22, 80, 6):
		_line([[x, 41], [x, 46]], 1.0, true)
	for x in [28, 50, 72]:
		_line([[x, 50], [x, 77]], 3.0)
	_line([[24, 53], [76, 53]], 2.0)
	_poly([[18, 77], [82, 77], [85, 84], [15, 84]])


## Paisley (a textile motif).
func _e_south_asian() -> void:
	var c := Vector2(46, 60)
	var r := 20.0
	var pts := []
	for i in 25:
		var a := deg_to_rad(-40.0 + 240.0 * i / 24.0)
		pts.append(c + r * Vector2(cos(a), sin(a)))
	var a1 := deg_to_rad(200.0)
	var a0 := deg_to_rad(-40.0)
	pts += _bezier(c + r * Vector2(cos(a1), sin(a1)), Vector2(36, 22), Vector2(70, 18), 10).slice(1)
	pts += _bezier(Vector2(70, 18), Vector2(72, 34), c + r * Vector2(cos(a0), sin(a0)), 10).slice(1, 10)
	_poly(pts)
	var inner := []
	for p: Vector2 in pts:
		inner.append(c + (p - c) * 0.7 + Vector2(1, 0))
	inner.append(inner[0])
	_line(inner, 1.4, true)
	_circle(46, 62, 4.0, true)
	_circle(46, 62, 2.0)


## Outrigger boat.
func _e_filipino() -> void:
	_line([[51, 62], [51, 20]], 2.2)
	_poly([[53, 22], [77, 54], [53, 57]])
	_poly([[49, 28], [31, 52], [49, 56]])
	_poly([[14, 55], [22, 61], [78, 61], [86, 55], [80, 68], [20, 68]])
	for x in [28, 72]:
		_line([[x, 66], [x, 76]], 2.0)
	_line([[20, 77], [80, 77]], 3.0)
	_wave(16, 84, 86, 1.4, 3.0, 2.2)


## Rice seedlings in a flooded paddy (the Red River delta).
func _e_vietnamese() -> void:
	for cl: Array in [[30.0, 64.0, 0.85], [50.0, 62.0, 1.0], [70.0, 64.0, 0.85]]:
		var base := Vector2(cl[0], cl[1])
		var s: float = cl[2]
		for a: float in [-38.0, -18.0, 0.0, 16.0, 36.0]:
			var d := Vector2(sin(deg_to_rad(a)), -cos(deg_to_rad(a)))
			_leaf(base, d, (30.0 - absf(a) * 0.22) * s, 2.3)
		_line([[cl[0], cl[1] - 1.0], [cl[0], cl[1] + 5.0]], 2.0)
	_wave(16, 84, 71, 1.3, 3.0, 2.4)
	_wave(22, 78, 79, 1.2, 2.5, 2.2)
	_wave(30, 70, 86, 1.1, 2.0, 2.0)


## Stilt house by the river (the Chao Phraya, where Ayutthaya stood).
func _e_thai() -> void:
	var roof := _bezier(Vector2(22, 48), Vector2(38, 38), Vector2(50, 16), 8) \
			+ _bezier(Vector2(50, 16), Vector2(62, 38), Vector2(78, 48), 8).slice(1)
	_poly(roof)
	_line([[40, 44], [50, 26], [60, 44]], 1.2, true)
	_poly([[31, 48], [69, 48], [69, 63], [31, 63]])
	for x in [38, 45, 52, 59]:
		_line([[x, 50], [x, 61]], 1.0, true)
	_poly([[46, 52], [54, 52], [54, 63], [46, 63]], true)
	_line([[24, 64], [76, 64]], 2.6)
	for x in [30, 42, 58, 70]:
		_line([[x, 64], [x, 78]], 2.2)
	_wave(16, 84, 79, 1.3, 3.0, 2.4)
	_wave(26, 74, 87, 1.2, 2.5, 2.2)


## Bamboo-shoot triangles (pucuk rebung, a woven textile motif).
func _e_malay() -> void:
	_line([[14, 24], [86, 24]], 2.4)
	_line([[14, 78], [86, 78]], 2.4)
	for x: float in [28.0, 50.0, 72.0]:
		_poly([[x - 11.0, 74.0], [x, 29.0], [x + 11.0, 74.0]])
		_line([[x - 6.5, 74.0], [x, 46.0], [x + 6.5, 74.0]], 1.3, true)
		_line([[x, 58.0], [x, 74.0]], 1.2, true)
		_poly([[x, 36.0], [x + 2.2, 40.0], [x, 44.0], [x - 2.2, 40.0]], true)
	for x: float in [39.0, 61.0]:
		_poly([[x - 3.5, 28.0], [x + 3.5, 28.0], [x, 36.0]])


## Breadfruit leaf (the islands' staple tree), deeply lobed, the midrib and veins in the ground colour.
func _e_pacific_islander() -> void:
	_poly([[50, 88], [47, 78], [40, 77], [24, 70], [40, 64], [20, 54], [42, 50], [24, 38], [44, 36], [34, 22], [50, 12],
			[66, 22], [56, 36], [76, 38], [58, 50], [80, 54], [60, 64], [76, 70], [60, 77], [53, 78]])
	_line([[50, 86], [50, 18]], 1.4, true)
	for v: Array in [[[50, 72], [30, 69]], [[50, 58], [27, 53]], [[50, 44], [30, 38]], [[50, 30], [38, 23]],
			[[50, 72], [70, 69]], [[50, 58], [73, 53]], [[50, 44], [70, 38]], [[50, 30], [62, 23]]]:
		_line(v, 1.0, true)


## Olive branch.
func _e_levantine() -> void:
	var stem := _bezier(Vector2(26, 84), Vector2(40, 46), Vector2(76, 18), 14)
	_line(stem, 2.4)
	for i in range(2, 14, 2):
		var p: Vector2 = stem[i]
		var d := (stem[i + 1] as Vector2) - p
		var side := 1.0 if (i / 2) % 2 == 0 else -1.0
		_leaf(p, d.rotated(side * 0.95), 15.0, 3.4)
	_circle(46, 66, 4.2)
	_circle(58, 50, 4.2)


## Date palm over dunes.
func _e_north_african() -> void:
	_line([[52, 82], [50, 68], [49, 56], [50, 44], [53, 32]], 5.0)
	for y in [74, 64, 54, 44]:
		_line([[46, y], [55, y - 1]], 1.2, true)
	for fr: Array in [[[53, 30], [38, 26], [22, 38]], [[53, 30], [70, 26], [82, 38]], [[53, 30], [42, 18], [30, 20]],
			[[53, 30], [64, 18], [76, 20]], [[53, 30], [55, 18], [60, 12]]]:
		_line(_bezier(Vector2(fr[0][0], fr[0][1]), Vector2(fr[1][0], fr[1][1]), Vector2(fr[2][0], fr[2][1]), 8), 3.2)
	_poly([[10, 90], [10, 80], [30, 73], [50, 80], [70, 71], [90, 78], [90, 90]])


## Bitter oranges on a branch (the orange groves of Seville and Valencia).
func _e_spanish() -> void:
	_line(_bezier(Vector2(20, 32), Vector2(48, 28), Vector2(72, 50), 10), 2.4)
	_leaf(Vector2(32, 30), Vector2(-0.3, -1.0), 16.0, 5.0)
	_leaf(Vector2(46, 32), Vector2(0.6, -1.0), 18.0, 5.2)
	_leaf(Vector2(60, 38), Vector2(1.0, -0.4), 16.0, 4.8)
	_line([[40, 31], [38, 48]], 1.8)
	_line([[62, 42], [64, 58]], 1.8)
	_circle(38, 57, 10.0)
	_circle(34.5, 53.5, 2.4, true)
	_circle(64, 68, 11.0)
	_circle(60.0, 64.0, 2.6, true)


## Coffee branch (the Ethiopian highlands, where coffee first grew): paired leaves, clusters of
## cherries at the leaf joints.
func _e_ethiopian() -> void:
	var a := Vector2(24, 80)
	var b := Vector2(72, 22)
	_line([a, b], 2.4)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	for t: float in [0.3, 0.58, 0.84]:
		var p := a.lerp(b, t)
		var ln := 20.0 * (1.1 - t * 0.4)
		_leaf(p, (d * 0.6 + n).normalized(), ln, 5.0)
		_leaf(p, (d * 0.6 - n).normalized(), ln, 5.0)
		if t < 0.8:
			for c: Vector2 in [p - d * 4.5 + n * 3.2, p - d * 4.5 - n * 3.2, p - d * 8.5]:
				_circle(c.x, c.y, 3.3)
				_circle(c.x - 1.0, c.y - 1.0, 0.9, true)


## Tulip (the Tulip Era, a motif of Iznik tiles): the slender Ottoman flower with pointed petals.
func _e_ottoman_turkish() -> void:
	_line(_bezier(Vector2(50, 86), Vector2(46, 64), Vector2(50, 44), 10), 2.6)
	_leaf(Vector2(49, 80), Vector2(-0.55, -1.0), 30.0, 5.0)
	_leaf(Vector2(49, 74), Vector2(0.7, -1.0), 26.0, 4.6)
	_poly([[50, 46], [40, 38], [37, 26], [40, 14], [45, 26], [50, 12], [55, 26], [60, 14], [63, 26], [60, 38]])
	_line([[45, 27], [47, 40]], 1.0, true)
	_line([[55, 27], [53, 40]], 1.0, true)


## Cypress (the sarv of Persian gardens and carpets), its tip bent, over a garden channel.
func _e_persian() -> void:
	var left := _bezier(Vector2(50, 76), Vector2(26, 60), Vector2(46, 14), 12)
	var right := _bezier(Vector2(46, 14), Vector2(74, 54), Vector2(50, 76), 12).slice(1)
	_poly(left + right)
	_line(_bezier(Vector2(50, 72), Vector2(47, 44), Vector2(47, 22), 8), 1.0, true)
	for c: Array in [[29, 4.0], [40, 7.0], [51, 9.0], [62, 7.5]]:
		var y: float = c[0]
		var w: float = c[1]
		_line([[48 - w, y + 5], [48, y], [48 + w, y + 5]], 1.0, true)
	_line([[50, 76], [50, 82]], 3.0)
	_line([[30, 85], [70, 85]], 2.2)


## Dhow (the trading ship of the Red Sea and the Gulf): a raked bow, a high stern and the lateen
## sail under its long slanting yard.
func _e_arab() -> void:
	_poly([[16, 56], [28, 66], [72, 66], [82, 58], [84, 50], [78, 50], [74, 56], [26, 58]])
	_line([[52, 57], [52, 50]], 2.0)
	_line([[24, 50], [76, 16]], 2.2)
	_poly([[27, 48], [74, 18], [70, 53]])
	_line([[52, 50], [52, 32]], 1.2, true)
	_wave(24, 76, 75, 1.5, 3.0, 2.4)
	_wave(32, 68, 83, 1.3, 2.5, 2.2)


## Apricot branch (the apricot, the "Armenian plum"): broad leaves over three fruits, each with
## its groove.
func _e_armenian() -> void:
	_line(_bezier(Vector2(18, 36), Vector2(50, 22), Vector2(82, 34), 12), 2.4)
	_leaf(Vector2(30, 31), Vector2(-0.4, -1.0), 15.0, 7.0)
	_leaf(Vector2(68, 29), Vector2(0.5, -1.0), 15.0, 7.0)
	for s: Array in [[[40, 30], [38, 44]], [[56, 28], [57, 42]], [[48, 29], [47, 60]]]:
		_line(s, 1.6)
	for f: Array in [[38, 52, 9.5], [57, 50, 10.0], [47, 68, 9.5]]:
		_circle(f[0], f[1], f[2])
		_arc(f[0] - 2.5, f[1], f[2] - 3.0, -60.0, 60.0, 1.2, true)


## Snow peaks of the Zagros: three jagged peaks, a snow line under each summit.
func _e_kurdish() -> void:
	_poly([[18, 72], [32, 46], [40, 54], [52, 22], [64, 44], [70, 38], [82, 72]])
	_line([[47.5, 34], [50, 31], [52.5, 35], [55.5, 31], [58.5, 34]], 1.4, true)
	_line([[29, 52], [31, 49.5], [33, 52], [34.5, 49]], 1.2, true)
	_line([[67, 44], [69, 42], [71, 44.5], [72.5, 42]], 1.2, true)
	_line([[24, 78], [76, 78]], 2.2)


## Horseshoe arch (the gates of Morocco's towns): the arch wider than its jambs, the voussoirs and
## the rectangular frame around it in the ground colour.
func _e_moorish() -> void:
	_poly([[26, 82], [26, 22], [74, 22], [74, 82]])
	var c := Vector2(50, 50)
	var opening := [Vector2(c.x - 14.0 * cos(deg_to_rad(20.0)), 82)]
	for i in 23:
		var a := deg_to_rad(160.0 + 220.0 * i / 22.0)
		opening.append(c + Vector2(cos(a), sin(a)) * 14.0)
	opening.append(Vector2(c.x + 14.0 * cos(deg_to_rad(20.0)), 82))
	_poly(opening, true)
	_arc(c.x, c.y, 20.0, 160.0, 380.0, 1.2, true)
	for k in 12:
		var a := deg_to_rad(160.0 + 220.0 * (k + 0.5) / 12.0)
		_line([c + Vector2(cos(a), sin(a)) * 15.0, c + Vector2(cos(a), sin(a)) * 20.0], 1.0, true)
	_line([[29, 82], [29, 25], [71, 25], [71, 82]], 1.2, true)


## Papyrus (the reed of the Nile): three stalks, each crowned with its fan of rays, over the water.
func _e_egyptian() -> void:
	for st: Array in [[42.0, 36.0, 33.0], [50.0, 50.0, 26.0], [58.0, 64.0, 33.0]]:
		var base := Vector2(st[0], 78)
		var tip := Vector2(st[1], st[2])
		_line([base, tip], 2.2)
		var up := (tip - base).angle()
		var fan := [tip]
		for i in 9:
			var a := up - deg_to_rad(60.0) + deg_to_rad(120.0) * i / 8.0
			fan.append(tip + Vector2(cos(a), sin(a)) * 12.0)
		_poly(fan)
		for i in range(1, 8, 2):
			var a := up - deg_to_rad(60.0) + deg_to_rad(120.0) * i / 8.0
			_line([tip, tip + Vector2(cos(a), sin(a)) * 11.0], 1.0, true)
	_wave(26, 74, 79, 1.3, 3.0, 2.4)
	_wave(32, 68, 85, 1.2, 2.5, 2.2)


## Canoe and paddle.
func _e_metis() -> void:
	_line([[28, 22], [64, 50]], 2.6)
	_circle(27, 21, 3.0)
	var d := Vector2(64, 50) - Vector2(28, 22)
	_leaf(Vector2(62, 48.5), d, 17.0, 5.0)
	var top := _bezier(Vector2(12, 54), Vector2(24, 64), Vector2(50, 63), 8) + _bezier(Vector2(50, 63), Vector2(76, 64), Vector2(88, 54), 8).slice(1)
	var bottom := _bezier(Vector2(88, 54), Vector2(82, 74), Vector2(50, 75), 8) + _bezier(Vector2(50, 75), Vector2(18, 74), Vector2(12, 54), 8).slice(1)
	_poly(top + bottom.slice(1, bottom.size() - 1))
	_line(top, 1.2, true)
	_wave(18, 82, 84, 1.4, 3.0, 2.2)


## Two rivers meeting: two winding streams (background-coloured bands) through the land join
## and flow on as one.
func _e_afro_native() -> void:
	_circle(50, 50, 34.0)
	var a := _bezier(Vector2(22, 26), Vector2(40, 30), Vector2(32, 42), 10) + _bezier(Vector2(32, 42), Vector2(26, 54), Vector2(48, 56), 10).slice(1)
	var b := _bezier(Vector2(80, 24), Vector2(60, 28), Vector2(68, 40), 10) + _bezier(Vector2(68, 40), Vector2(74, 52), Vector2(52, 56), 10).slice(1)
	var c := _bezier(Vector2(50, 55), Vector2(38, 66), Vector2(52, 72), 10) + _bezier(Vector2(52, 72), Vector2(64, 78), Vector2(50, 88), 10).slice(1)
	_line(a, 4.5, true)
	_line(b, 4.5, true)
	_line(c, 7.0, true)


## Two-strand cord.
func _e_euro_african() -> void:
	var n := 60
	var a := []
	var b := []
	for i in n + 1:
		var t := i / float(n)
		var y := lerpf(14.0, 86.0, t)
		var x := 12.0 * sin(t * TAU * 2.5)
		a.append(Vector2(50 + x, y))
		b.append(Vector2(50 - x, y))
	_line(a, 6.0)
	_line(b, 6.0)
	# over and under: the strand on top changes at every crossing
	var per := n / 5
	for k in 5:
		var seg: Array = (a if k % 2 == 0 else b).slice(k * per + 2, (k + 1) * per - 1)
		_line(seg, 10.0, true)
		_line(seg, 6.0)
