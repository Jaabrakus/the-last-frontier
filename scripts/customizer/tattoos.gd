class_name Tattoos
extends RefCounted
## Tattoos on the skin: the look's list of designs laid on the body by place (the creator's Tattoos row, TattooPanel;
## skin.gdshader through tattoo.gdshaderinc). Pure data and look logic plus the shader's uniforms: no nodes.
##
##   Tattoos.add(look, "anchor", "forearm_l")                 # -> index (or -1: full, unknown)
##   Tattoos.move(look, 0, 0.0, 0.01)                          # 1 cm up the arm
##   Tattoos.set_ink(look, 0, "red"); Tattoos.set_fade(look, 0, 0.6)
##   Tattoos.apply(skin_material, look)                        # BodyMaterials.skin_material calls it
##
## The look's "tattoos" key (AppearanceStore keeps it, validate() cleans it): at most max_count() entries
##   {design, place, x, y, scale, rotation, ink, fade}
## design / place / ink: data/customizer/tattoos.json ids; x, y: the offset (m) from the place's centre, right and up as
## a viewer facing that skin sees them (round the limb and along it, for an arm), within the place's `reach`; scale: of
## the design's size at the place (SCALE_RANGE); rotation: degrees, anticlockwise as seen; fade 0 (fresh) .. 1 (old,
## spread and greyed). Everyone may wear every design from the start (the owner, 2026-10-03); a few plain designs (bands,
## dots) go only round a limb or the neck (their "places").
##
## The designs are our own line art (tools/character/tattoos, assets/character/tattoos/SOURCE.md); the places' frames are
## measured on body.glb (tools/character/tattoos/build_tattoos.gd -> tattoo_map.json). A tattoo is skin: under clothes
## its regions collapse with the rest (hide_mask), and a tattoo whose regions are all covered is not sent at all.

const DATA := "res://data/customizer/tattoos.json"
const MAP := "res://assets/character/tattoos/tattoo_map.json"
const ATLAS := "res://assets/character/tattoos/tattoo_atlas.png"
## The creator row (CreatorOptions.ROWS).
const ROW := "tattoos"
## The shader's arrays (tattoo.gdshaderinc).
const SHADER_MAX := 8
const SPACES := {"uv": 0, "front": 1, "back": 2, "mh": 3}
## The creator's nudges: a move (m), a size step (factor), a turn (degrees).
const MOVE_STEP := 0.004
const SCALE_STEP := 1.1
const TURN_STEP := 15.0
const SCALE_RANGE := [0.35, 2.5]
## The atlas's cell (px): the ink's spread is set in texels of it.
const CELL_PX := 256.0
## The ink's spread under the skin (m): fresh .. old.
const SPREAD := [0.00022, 0.0009]

static var _data := {}
static var _map := {}
static var _atlas: Texture2D
static var _arc_tex: ImageTexture


static func data() -> Dictionary:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		_data = d if d is Dictionary else {}
	return _data


static func map() -> Dictionary:
	if _map.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(MAP)) if FileAccess.file_exists(MAP) else null
		_map = d if d is Dictionary else {}
	return _map


static func max_count() -> int:
	return mini(int(data().get("max", SHADER_MAX)), SHADER_MAX)


static func designs() -> Array:
	return data().get("designs", [])


static func places() -> Array:
	return data().get("places", [])


static func inks() -> Array:
	return data().get("inks", [])


static func _by_id(list: Array, id: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e.get("id", "")) == id:
			return e
	return {}


static func design(id: String) -> Dictionary:
	return _by_id(designs(), id)


static func place(id: String) -> Dictionary:
	return _by_id(places(), id)


static func ink(id: String) -> Dictionary:
	return _by_id(inks(), id)


static func _ids(list: Array) -> Array:
	return list.map(func(e: Dictionary) -> String: return String(e.id))


## The places a design may go: its "places", else every place.
static func design_places(design_id: String) -> Array:
	var d := design(design_id)
	var all := _ids(places())
	if d.get("places") is Array:
		return (d.places as Array).filter(func(p) -> bool: return String(p) in all)
	return all


## Where Add puts a design first: its "place" (an anchor on the forearm, a compass rose on the chest), else the first
## place it may go.
static func default_place(design_id: String) -> String:
	var ps := design_places(design_id)
	var own := String(design(design_id).get("place", ""))
	if own in ps:
		return own
	return String(ps[0]) if not ps.is_empty() else ""


static func is_repeat(design_id: String) -> bool:
	return design(design_id).has("repeat")


# ---------------------------------------------------------------------------------------------
# The look
# ---------------------------------------------------------------------------------------------

## The look's tattoos (the live array when the look has one).
static func list(look: Dictionary) -> Array:
	return look.tattoos if look.get("tattoos") is Array else []


static func _arr(look: Dictionary) -> Array:
	if not look.get("tattoos") is Array:
		look["tattoos"] = []
	return look.tattoos


static func make(design_id: String, place_id := "") -> Dictionary:
	var df: Dictionary = data().get("defaults", {})
	var pl := place_id if not place_id.is_empty() and place_id in design_places(design_id) else default_place(design_id)
	return {"design": design_id, "place": pl, "x": 0.0, "y": 0.0, "scale": 1.0, "rotation": 0.0,
			"ink": String(df.get("ink", "blue_black")), "fade": float(df.get("fade", 0.15))}


## Adds a tattoo; its index, or -1 (the list is full, or the design unknown).
static func add(look: Dictionary, design_id: String, place_id := "") -> int:
	var a := _arr(look)
	if a.size() >= max_count() or design(design_id).is_empty():
		return -1
	a.append(make(design_id, place_id))
	return a.size() - 1


static func remove(look: Dictionary, i: int) -> bool:
	var a := _arr(look)
	if i < 0 or i >= a.size():
		return false
	a.remove_at(i)
	return true


static func _entry(look: Dictionary, i: int) -> Dictionary:
	var a := list(look)
	return a[i] if i >= 0 and i < a.size() and a[i] is Dictionary else {}


## Another design; it moves to the design's first place when it may not go where it was.
static func set_design(look: Dictionary, i: int, design_id: String) -> void:
	var t := _entry(look, i)
	if t.is_empty() or design(design_id).is_empty():
		return
	t["design"] = design_id
	if not String(t.get("place", "")) in design_places(design_id):
		t["place"] = default_place(design_id)
		t["x"] = 0.0
		t["y"] = 0.0
	if is_repeat(design_id):
		t["rotation"] = 0.0
		t["x"] = 0.0


## Another place: the offset starts again from its centre.
static func set_place(look: Dictionary, i: int, place_id: String) -> void:
	var t := _entry(look, i)
	if t.is_empty() or not place_id in design_places(String(t.get("design", ""))):
		return
	t["place"] = place_id
	t["x"] = 0.0
	t["y"] = 0.0


static func set_ink(look: Dictionary, i: int, ink_id: String) -> void:
	var t := _entry(look, i)
	if not t.is_empty() and not ink(ink_id).is_empty():
		t["ink"] = ink_id


static func set_fade(look: Dictionary, i: int, fade: float) -> void:
	var t := _entry(look, i)
	if not t.is_empty():
		t["fade"] = clampf(fade, 0.0, 1.0)


## Moves by (dx, dy) metres (right, up as seen), kept within the place's reach.
static func move(look: Dictionary, i: int, dx: float, dy: float) -> void:
	var t := _entry(look, i)
	if t.is_empty():
		return
	var r := _reach(String(t.place))
	t["x"] = clampf(float(t.get("x", 0.0)) + dx, -r.x, r.x)
	t["y"] = clampf(float(t.get("y", 0.0)) + dy, -r.y, r.y)


static func resize(look: Dictionary, i: int, factor: float) -> void:
	var t := _entry(look, i)
	if not t.is_empty():
		t["scale"] = clampf(float(t.get("scale", 1.0)) * factor, SCALE_RANGE[0], SCALE_RANGE[1])


static func turn(look: Dictionary, i: int, degrees: float) -> void:
	var t := _entry(look, i)
	if not t.is_empty() and not is_repeat(String(t.get("design", ""))):
		t["rotation"] = wrapf(float(t.get("rotation", 0.0)) + degrees, -180.0, 180.0)


static func _step_id(ids: Array, cur: String, d: int) -> String:
	if ids.is_empty():
		return cur
	var k := ids.find(cur)
	if k < 0:
		return String(ids[0 if d > 0 else ids.size() - 1])
	return String(ids[posmod(k + d, ids.size())])


static func step_design(look: Dictionary, i: int, d: int) -> void:
	var t := _entry(look, i)
	if not t.is_empty():
		set_design(look, i, _step_id(_ids(designs()), String(t.get("design", "")), d))


static func step_place(look: Dictionary, i: int, d: int) -> void:
	var t := _entry(look, i)
	if not t.is_empty():
		set_place(look, i, _step_id(design_places(String(t.get("design", ""))), String(t.get("place", "")), d))


static func step_ink(look: Dictionary, i: int, d: int) -> void:
	var t := _entry(look, i)
	if not t.is_empty():
		set_ink(look, i, _step_id(_ids(inks()), String(t.get("ink", "")), d))


static func _reach(place_id: String) -> Vector2:
	var r: Array = place(place_id).get("reach", [0.05, 0.05])
	return Vector2(float(r[0]), float(r[1]))


## A saved list made safe: dictionaries of known designs at places they may go, the numbers clamped, at most
## max_count(). Anything else is dropped.
static func validate(v) -> Array:
	var out := []
	if not v is Array:
		return out
	for e in v:
		if out.size() >= max_count():
			break
		if not e is Dictionary:
			continue
		var d := String(e.get("design", "")) if e.get("design") is String else ""
		if design(d).is_empty():
			continue
		var t := make(d, String(e.get("place", "")) if e.get("place") is String else "")
		if t.place == "":
			continue
		var r := _reach(String(t.place))
		t["x"] = clampf(_num(e.get("x"), 0.0), -r.x, r.x)
		t["y"] = clampf(_num(e.get("y"), 0.0), -r.y, r.y)
		t["scale"] = clampf(_num(e.get("scale"), 1.0), SCALE_RANGE[0], SCALE_RANGE[1])
		t["rotation"] = 0.0 if is_repeat(d) else wrapf(_num(e.get("rotation"), 0.0), -180.0, 180.0)
		if e.get("ink") is String and not ink(String(e.ink)).is_empty():
			t["ink"] = String(e.ink)
		t["fade"] = clampf(_num(e.get("fade"), float(t.fade)), 0.0, 1.0)
		out.append(t)
	return out


static func _num(v, fallback: float) -> float:
	return float(v) if v is float or v is int else fallback


## "Anchor, left forearm".
static func label_of(t: Dictionary) -> String:
	var d := design(String(t.get("design", "")))
	var p := place(String(t.get("place", "")))
	return "%s, %s" % [String(d.get("label", t.get("design", "?"))), String(p.get("label", t.get("place", "?"))).to_lower()]


## The creator row's value: "None", "Anchor, left forearm", "Anchor, left forearm and 2 more".
static func summary(look: Dictionary) -> String:
	var a := list(look)
	if a.is_empty():
		return "None"
	var s := label_of(a[-1])
	return s if a.size() == 1 else "%s and %d more" % [s, a.size() - 1]


# ---------------------------------------------------------------------------------------------
# Visibility (clothes) and the shader
# ---------------------------------------------------------------------------------------------

## True when some skin of the tattoo's place shows (not every region of it in `hide_regions`).
static func visible(t: Dictionary, hide_regions: Array) -> bool:
	for r: String in place(String(t.get("place", ""))).get("regions", []):
		if not r in hide_regions:
			return true
	return false


## The regions of the places the look's tattoos (and `extra_place`) are at.
static func regions_of(look: Dictionary, extra_place := "") -> Array:
	var out := []
	var ps := list(look).map(func(t: Dictionary) -> String: return String(t.get("place", "")))
	if not extra_place.is_empty():
		ps.append(extra_place)
	for p: String in ps:
		for r: String in place(p).get("regions", []):
			if not r in out:
				out.append(r)
	return out


## How the creator shows a place while its tattoo is edited (tattoos.json "view", the centre and normal measured in
## tattoo_map.json): {bone, dist, frame, yaw, at, normal} (CreatorStage.focus_skin; frame and yaw without the bone).
static func view_of(place_id: String) -> Dictionary:
	var v: Dictionary = (place(place_id).get("view", {}) as Dictionary).duplicate()
	var mp: Dictionary = (map().get("places", {}) as Dictionary).get(place_id, {})
	if mp.get("pos") is Array and mp.get("normal") is Array:
		v["at"] = Vector3(float(mp.pos[0]), float(mp.pos[1]), float(mp.pos[2]))
		v["normal"] = Vector3(float(mp.normal[0]), float(mp.normal[1]), float(mp.normal[2]))
	return v


## True when one of the places is on the torso (the creator takes the upper garments off to show it).
static func on_torso(place_ids: Array) -> bool:
	for p in place_ids:
		if bool(place(String(p)).get("torso", false)):
			return true
	return false


static func atlas() -> Texture2D:
	if _atlas == null and ResourceLoader.exists(ATLAS):
		_atlas = load(ATLAS) as Texture2D
	return _atlas


## The torso's arc map (tattoo_map.json "arc") as a float texture: R from the front centre, G from the back centre.
static func arc_texture() -> ImageTexture:
	if _arc_tex == null:
		var a: Dictionary = map().get("arc", {})
		var nu := int(a.get("nu", 0))
		var nv := int(a.get("nv", 0))
		if nu < 2 or nv < 2:
			return null
		var fl := PackedFloat32Array()
		fl.resize(nu * nv * 2)
		for j in nv:
			for i in nu:
				fl[(j * nu + i) * 2] = float(a.front[j][i])
				fl[(j * nu + i) * 2 + 1] = float(a.back[j][i])
		_arc_tex = ImageTexture.create_from_image(Image.create_from_data(nu, nv, false, Image.FORMAT_RGF, fl.to_byte_array()))
	return _arc_tex


## The shader's rows of the look's visible tattoos (at most SHADER_MAX): {m, b, p, s, ink, e} (Vector4 each, the
## tattoo.gdshaderinc arrays), plus "index" (into the look's list).
static func shader_rows(look: Dictionary) -> Array:
	var hidden: Array = look.get("hide_regions", []) if look.get("hide_regions") is Array else []
	var ids := BodyMaterials.region_ids()
	var mp: Dictionary = map().get("places", {})
	var out := []
	var a := validate(list(look))
	for k in a.size():
		var t: Dictionary = a[k]
		if out.size() >= SHADER_MAX:
			break
		var pl := place(String(t.place))
		var pm: Dictionary = mp.get(String(t.place), {})
		var d := design(String(t.design))
		if pm.is_empty() or not visible(t, hidden):
			continue
		# the place's regions that show (a covered region's skin collapses anyway: the bits say what is drawn)
		var lo := 0
		var hi := 0
		for r: String in pl.get("regions", []):
			if r in hidden:
				continue
			var rid := int(ids.get(r, -1))
			if rid >= 0 and rid < 16:
				lo |= 1 << rid
			elif rid >= 16 and rid < 32:
				hi |= 1 << (rid - 16)
		var size := float(pl.get("size", 0.06)) * float(d.get("size", 1.0)) * float(t.scale)
		var th := deg_to_rad(float(t.rotation))
		# q = R(-th) (A dc - off) / size: the design's square from the place's coordinates
		var A: Array = pm.get("a", [1.0, 0.0, 0.0, 1.0])
		var c := cos(th)
		var s := sin(th)
		var m00 := (c * float(A[0]) + s * float(A[2])) / size
		var m01 := (c * float(A[1]) + s * float(A[3])) / size
		var m10 := (-s * float(A[0]) + c * float(A[2])) / size
		var m11 := (-s * float(A[1]) + c * float(A[3])) / size
		var ox := float(t.x)
		var oy := float(t.y)
		var bx := -(c * ox + s * oy) / size
		var by := -(-s * ox + c * oy) / size
		var ctr: Array = pm.get("centre", [0.0, 0.0])
		var wrap := float(pl.get("wrap", 0.0))
		# a repeating design: whole tiles round the limb, each `repeat` of the design's width
		var tiles := 0.0
		var crop := 1.0
		if is_repeat(String(t.design)) and wrap > 0.0:
			crop = float(d.get("repeat", 1.0))
			var round_m := wrap * Vector2(float(A[0]), float(A[2])).length()
			tiles = maxf(1.0, roundf(round_m / (size * crop)))
		var ik := ink(String(t.ink))
		var col: Array = ik.get("color", [0.1, 0.15, 0.25])
		var faded: Array = data().get("faded_color", [0.34, 0.45, 0.48])
		var f := float(t.fade)
		var rgb := Vector3(col[0], col[1], col[2]).lerp(Vector3(faded[0], faded[1], faded[2]), f * 0.5)
		var density := lerpf(0.97, 0.6, f)
		var spread := lerpf(SPREAD[0], SPREAD[1], f) * CELL_PX / size
		out.append({"index": k,
				"m": Vector4(m00, m01, m10, m11), "b": Vector4(bx, by, float(ctr[0]), float(ctr[1])),
				"p": Vector4(float(SPACES.get(String(pm.get("space", "uv")), 0)), wrap, float(lo), float(hi)),
				"s": Vector4(float(d.get("cell", 0)), float(pm.get("side", 0)), tiles, crop),
				"ink": Vector4(rgb.x, rgb.y, rgb.z, density), "e": Vector4(log(maxf(spread, 1.0)) / log(2.0), 0.0, 0.0, 0.0)})
	return out


## Sets the skin material's tattoo uniforms for the look (its visible tattoos).
static func apply(m: ShaderMaterial, look: Dictionary) -> void:
	var rows := shader_rows(look)
	m.set_shader_parameter("tat_count", rows.size())
	if rows.is_empty():
		return
	for key: String in ["m", "b", "p", "s", "ink", "e"]:
		var arr := PackedVector4Array()
		arr.resize(SHADER_MAX)
		for i in rows.size():
			arr[i] = rows[i][key]
		m.set_shader_parameter("tat_" + key, arr)
	m.set_shader_parameter("tattoo_atlas", atlas())
	m.set_shader_parameter("tattoo_arc", arc_texture())
	var a: Dictionary = map().get("arc", {})
	if not a.is_empty():
		m.set_shader_parameter("tattoo_arc_rect", Vector4(float(a.u0), float(a.u_span), float(a.v0), float(a.v1)))
		m.set_shader_parameter("tattoo_arc_n", Vector2(float(a.nu), float(a.nv)))


# ---------------------------------------------------------------------------------------------
# The creator's row (CreatorOptions): "<  Tattoos  value  >"
# ---------------------------------------------------------------------------------------------
# The row steps the design of the newest tattoo (the last in the list): from None, the first step adds one at the
# design's first place; stepping back to None takes the newest off. A click on the value opens TattooPanel (every
# tattoo, place, size, turn, ink, fade).

static func row_options(_look: Dictionary) -> Array:
	var out := [{"id": "none", "label": "None", "note": String(data().get("row_note",
			"Tattoos: our own period sailors' and sky crews' marks. Click to add, place, size and ink them."))}]
	for d: Dictionary in designs():
		out.append({"id": String(d.id), "label": String(d.label), "note": String(d.get("note", ""))})
	return out


static func row_current(look: Dictionary, opts: Array) -> int:
	var a := list(look)
	if a.is_empty():
		return 0
	var id := String((a[-1] as Dictionary).get("design", ""))
	for i in opts.size():
		if String(opts[i].id) == id:
			return i
	return -1


static func row_select(look: Dictionary, i: int, opts: Array) -> bool:
	if i < 0 or i >= opts.size():
		return false
	var a := _arr(look)
	if i == 0:
		if not a.is_empty():
			a.remove_at(a.size() - 1)
		return true
	var id := String(opts[i].id)
	if a.is_empty():
		return add(look, id) >= 0
	set_design(look, a.size() - 1, id)
	return true
