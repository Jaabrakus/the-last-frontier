class_name RingBoard
extends RefCounted
## The Tidebreak ring's scoreboard tower (RingDressing builds it behind the middle of one stand): a stone tower with a
## timber head, the sport's name over a lacquered board in our own block lettering (a 5 x 7 cell font, solid gold
## cells, lit at night), the two sides' scores under it in the same lettering between their element plaques, a hipped
## tile roof with a gold finial and a pennant. The score digits are one MultiMesh of cells (set_score moves cells in or
## out of sight: no mesh rebuilt). The rest goes into the dressing's kit (one mesh for the whole dressing).

## The block font: 7 rows of 5 cells, "#" lit.
const FONT := {
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
}
const TITLE := "TIDEBREAK"

## The score cells: [panel][digit 0..1][row][col] -> instance index.
var digits: MultiMesh
var digit_cell := 0.16
var _origin: Array[Vector3] = []     ## each digit's top-left cell centre (the board's local frame)
var _frame := Transform3D.IDENTITY
var score := Vector2i(-1, -1)


## Text in block cells into `kit` under `key`: its left top cell's centre at `at` in the frame `xf` (x right, y up,
## z out of the board), cell `c` m, `depth` m proud. Returns the width (m).
static func letters(kit: StructureMeshKit, key: StringName, xf: Transform3D, at: Vector3, text: String, c: float, depth: float,
		col: Color) -> float:
	var x := 0.0
	for ch in text:
		var g: Array = FONT.get(ch, FONT["-"])
		for r in 7:
			var row: String = g[r]
			for k in 5:
				if row[k] == "#":
					var p := at + Vector3(x + float(k) * c, -float(r) * c, depth * 0.5)
					kit.box(key, xf * Transform3D(Basis(), p), Vector3(c * 0.98, c * 0.98, depth), StructureMeshKit.GRAIN_X, 0, 0.0, col,
							StructureMeshKit.KIND_TEX)
		x += 6.0 * c
	return x - c


## The tower, its foot centred at `foot` (local to the dressing), its board facing `facing` (+Z or -Z).
func build(d: RingDressing, kit: StructureMeshKit, foot: Vector3, facing: float) -> void:
	var b := Basis(Vector3.UP, 0.0 if facing > 0.0 else PI)
	_frame = Transform3D(b, foot)
	var f := _frame
	var stone := Color(0.84, 0.8, 0.74)
	var timber := Color(0.42, 0.13, 0.08)
	var gold := RingDressing.GOLD
	# the stone shaft, a plinth course and a band at its head
	RingDressing.pbox(kit, &"ring_walk", f * Vector3(0.0, 4.6, 0.0), Vector3(4.6, 9.2, 4.6), stone, b, true)
	RingDressing.pbox(kit, &"ring_walk", f * Vector3(0.0, 0.5, 0.0), Vector3(5.2, 1.0, 5.2), stone * 0.9, b, true)
	RingDressing.pbox(kit, &"ring_walk", f * Vector3(0.0, 9.0, 0.0), Vector3(5.2, 0.5, 5.2), stone * 0.92, b, true)
	# the head: a lacquered timber frame cantilevered toward the ring, the board in it
	var hy := 9.25
	var bw := 11.6                       # the board's width
	var bh := 5.6                        # and height
	RingDressing.pbox(kit, &"paint", f * Vector3(0.0, hy + bh * 0.5, 0.6), Vector3(bw + 0.6, bh, 1.4), timber, b)
	RingDressing.pbox(kit, &"paint", f * Vector3(0.0, hy + bh * 0.5, 1.32), Vector3(bw, bh - 0.6, 0.06), Color(0.05, 0.045, 0.045), b)
	for sx: float in [-1.0, 1.0]:
		RingDressing.pbox(kit, &"gold", f * Vector3(sx * (bw * 0.5 + 0.08), hy + bh * 0.5, 1.34), Vector3(0.12, bh - 0.5, 0.12), gold, b)
	for sy: float in [0.0, bh]:
		RingDressing.pbox(kit, &"gold", f * Vector3(0.0, hy + sy, 1.34), Vector3(bw + 0.6, 0.14, 0.14), gold, b)
	# brackets under the head
	for sx: float in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		RingDressing.pbox(kit, &"paint", f * Vector3(sx, hy - 0.3, 0.9), Vector3(0.34, 0.6, 1.0), timber * 0.8, b)
	# the name, gold block letters
	var c := 0.19
	var w := 53.0 * c
	letters(kit, &"glow_gold", f, Vector3(-w * 0.5 + c * 0.5, hy + bh - 0.55, 1.35), TITLE, c, 0.08, gold)
	# a gold rule under it
	RingDressing.pbox(kit, &"gold", f * Vector3(0.0, hy + bh - 2.05, 1.38), Vector3(bw - 0.8, 0.07, 0.04), gold, b)
	# the two sides' panels: a plaque each, the digits between them (set_score)
	for s in 2:
		var sx := -1.0 if s == 0 else 1.0
		RingDressing.pbox(kit, &"gold", f * Vector3(sx * 2.3, hy + 1.75, 1.36), Vector3(3.3, 2.3, 0.04), gold * 0.75, b)
		RingDressing.pbox(kit, &"paint", f * Vector3(sx * 2.3, hy + 1.75, 1.38), Vector3(3.1, 2.1, 0.04), Color(0.03, 0.03, 0.035), b)
		d.plaque(s, f * Transform3D(Basis(), Vector3(sx * 4.75, hy + 1.75, 1.42)), 1.3)
	# the roof: a hip of glazed tile, a gold finial, a pennant on a staff
	var ry := hy + bh
	RingDressing.pbox(kit, &"paint", f * Vector3(0.0, ry + 0.15, 0.4), Vector3(bw + 1.4, 0.3, 3.2), timber, b)
	RingDressing.hip_roof(kit, &"tile", f, Vector3(0.0, ry + 0.3, 0.4), Vector2(bw + 2.4, 4.4), 2.0, Color(0.14, 0.32, 0.34))
	RingDressing.prism(kit, &"gold", f * Vector3(0.0, ry + 2.3, 0.4), 0.2, 0.0, 1.0, 8, gold)
	RingDressing.prism(kit, &"metal", f * Vector3(0.0, ry + 2.3, 0.4), 0.05, 0.05, 4.6, 6, Color(0.2, 0.2, 0.2))
	d.pennant_staff(f * Vector3(0.0, ry + 6.8, 0.4), 5.0, 1.6)
	# the score cells
	digit_cell = 0.24
	digits = MultiMesh.new()
	digits.transform_format = MultiMesh.TRANSFORM_3D
	var cell := BoxMesh.new()
	cell.size = Vector3(digit_cell * 0.96, digit_cell * 0.96, 0.06)
	digits.mesh = cell
	digits.instance_count = 4 * 35
	_origin.clear()
	for s in 2:
		var sx := -1.0 if s == 0 else 1.0
		for k in 2:
			var dx := sx * 2.3 - 5.0 * digit_cell + float(k) * 6.0 * digit_cell
			_origin.append(Vector3(dx, hy + 1.75 + 3.0 * digit_cell, 1.43))
	var mi := MultiMeshInstance3D.new()
	mi.name = "ScoreCells"
	mi.multimesh = digits
	mi.material_override = d.mats[&"glow_gold"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(mi)
	set_score(0, 0)


## The two sides' scores (0..99) on the board.
func set_score(a: int, b: int) -> void:
	if digits == null or Vector2i(a, b) == score:
		return
	score = Vector2i(a, b)
	var text := ["%02d" % clampi(a, 0, 99), "%02d" % clampi(b, 0, 99)]
	for s in 2:
		for k in 2:
			var g: Array = FONT.get(String(text[s])[k], FONT["0"])
			var o := _origin[s * 2 + k]
			for r in 7:
				for col in 5:
					var idx := ((s * 2 + k) * 35) + r * 5 + col
					var on := String(g[r])[col] == "#"
					var p := o + Vector3(float(col) * digit_cell, -float(r) * digit_cell, 0.0)
					var bs := Basis() if on else Basis().scaled(Vector3.ONE * 0.0001)
					digits.set_instance_transform(idx, _frame * Transform3D(bs, p))
