class_name ItemIcons
extends Node
## Icons for the inventory grid, rendered from the items' own models (WeaponModels, ThrowableModels,
## LoadoutModels) in an off-screen viewport, once per kind, and kept for the session. Some kinds render from a
## photoscanned model instead when its file is in the project (SCANNED: Poly Haven, CC0; user 2026-09-27: "there are
## some free good looking realistic ones for items"; assets/models/polyhaven/SOURCE.md); the icon only, the game's
## own model stays in the world.
##
##   var icons := ItemIcons.shared(tree)      # a node under the tree's root (processes while paused)
##   var tex := icons.get_icon("musket")      # null until rendered; `ready_icon` fires when it is

signal ready_icon(kind: String)

const SIZE := 192
## How the icons look: "sketch", each item drawn in ink and watercolour on a scrap of parchment (user 2026-09-27:
## "making the items in paintings would be amazing like sketches"; shaders/ui/icon_sketch.gdshader); "render", the
## studio render with a dark edge.
const STYLE := "sketch"
const SKETCH_SHADER := "res://shaders/ui/icon_sketch.gdshader"
## Room round the item in a sketch, for its glow.
const SKETCH_MARGIN := 1.06
## Framing closer than the whole model: the dart bundle's five thin 1.65 m darts come out as hairlines across
## the square, so its icon frames the tied middle (the darts about twice as thick). The long guns show the lock and
## the stock, the barrel running off the corner (user 2026-09-27: "some items look weak": whole, they were hairlines).
const ZOOM := {"dart_bundle": 0.55, "musket": 0.62, "over_under": 0.62, "spear_pair": 0.5, "pole": 0.55,
		"atlatl": 0.8, "blackberries": 0.72, "hazelnuts": 0.7, "acorns": 0.75, "wintergreen": 0.8, "clay_pipe": 0.62}
## Where a cropped item's frame sits along its length, from its middle (fractions of its length, + toward the butt;
## the spears show their heads).
const FOCUS := {"musket": 0.2, "over_under": 0.2, "spear_pair": -0.3, "clay_pipe": 0.28}
## Things seen from above at three quarters, not from the side: food, stone, hides (a side view showed a pile of
## berries or nuts as a flat row of blobs).
const FROM_ABOVE := ["stone", "flint", "venison", "deer_hide", "wolf_pelt", "fox_pelt", "antler", "bison_robe", "tallow",
		"tongue", "cordage", "stake_set", "steel_trap", "bar_lead", "bullet_mould", "hooks_line", "marten_pelt", "mink_pelt",
		"fisher_pelt", "raccoon_pelt", "dried_marten_pelt", "dried_mink_pelt", "dried_fisher_pelt", "dried_raccoon_pelt",
		"small_game", "roast_small_game", "charred_small_game", "blackberries",
		"strawberries", "plantain", "wintergreen", "acorns", "hazelnuts", "jerky", "cornmeal", "fire_steel", "johnnycake",
		"burnt_johnnycake", "roast_venison", "charred_venison", "willow_bark", "elm_bark", "dogwood_bark", "elderberries",
		"crabapples", "bearberry", "jimsonweed", "snuff"]
const ABOVE_DEG := 32.0
const ABOVE_YAW_DEG := -28.0
## The dark edge baked round each icon (px at SIZE), so thin things read on the dark cells and over the world.
const EDGE_PX := 2
## kind -> the Poly Haven asset and how it sits: `axis` its longest side is turned to before the kind's usual pose
## ("y": a haft upright, like GatherModels' tools, its head then turned across the view; "z": lengthwise, like the
## logs; "": as it comes), `zoom` (framing closer, as ZOOM), `tint` (multiplies its colour: the rock darkened to
## chert for the flint). The root scan (for ginseng) came out a thin stick, weaker than the game's forked root, so it
## is not used.
const SCANNED := {"felling_axe": {"id": "wooden_axe", "axis": "y"}, "mattock": {"id": "picke_dirty_01", "axis": "y"},
		"stone": {"id": "rock_07"}, "flint": {"id": "rock_09", "tint": Color(0.42, 0.44, 0.5)},
		"branches": {"id": "dry_branches_medium_01", "axis": "z", "zoom": 0.62},
		"log": {"id": "dead_tree_trunk", "axis": "z", "zoom": 0.32}}
const SCAN_PATH := "res://assets/models/polyhaven/%s/%s_1k.gltf"
static var _shared: ItemIcons

var _cache := {}
var _queue: Array = []
var _busy := false
var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _paint_vp: SubViewport         ## the sketch pass: the render through icon_sketch.gdshader
var _paint_rect: TextureRect


static func shared(tree: SceneTree) -> ItemIcons:
	if _shared == null or not is_instance_valid(_shared):
		_shared = ItemIcons.new()
		_shared.name = "ItemIcons"
		_shared.process_mode = Node.PROCESS_MODE_ALWAYS
		# deferred: the HUD asks for it from the level's _ready, while the root is still setting up its children
		tree.root.add_child.call_deferred(_shared)
	return _shared


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED   # drawn only while an icon is made
	add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.66, 0.6)
	e.ambient_light_energy = 0.55
	env.environment = e
	_vp.add_child(env)
	# the studio (the camera looks from +X, screen left is +Z): a warm key from the upper left, a cool fill from the
	# right, a rim from behind that picks out the edges
	for l: Array in [[Vector3(-1.0, -1.1, -0.8), Color(1.0, 0.93, 0.8), 1.7], [Vector3(-1.0, -0.2, 1.0), Color(0.75, 0.82, 1.0), 0.45],
			[Vector3(1.0, -0.7, 0.35), Color(1.0, 0.95, 0.85), 1.3]]:
		var dl := DirectionalLight3D.new()
		dl.basis = Basis.looking_at((l[0] as Vector3).normalized(), Vector3.UP)
		dl.light_color = l[1]
		dl.light_energy = l[2]
		_vp.add_child(dl)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)


## Paints every pack item's icon in the background a little after the game starts (a sketch takes a few frames: asked
## for only when a toast or the pack first shows it, a toast could fade before its picture came).
func prewarm(delay_s := 2.0) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	await get_tree().create_timer(delay_s, true, false, true).timeout
	for k: String in InventoryState.NAMES:
		get_icon(k)


func get_icon(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	if not _queue.has(kind):
		_queue.append(kind)
		if not _busy:
			_busy = true
			_run.call_deferred()
	return null


func _run() -> void:
	_busy = true
	if not is_inside_tree():
		await ready
	while not _queue.is_empty():
		var kind: String = _queue.pop_front()
		var m := _model(kind)
		if m == null:
			_cache[kind] = null
			continue
		_holder.add_child(m)
		await get_tree().process_frame
		if m.has_meta(&"scan_axis"):
			_align_long(m, String(m.get_meta(&"scan_axis")))
			await get_tree().process_frame
		var own := _bounds(m)            # along the model's own axes, before it is turned
		# lie it diagonally across the square, then frame its bounds
		# (the models run along their Z, up +Y; the camera looks at their side from +X)
		m.rotation = Vector3(deg_to_rad(40.0), 0.0, 0.0) if kind in ["musket", "over_under", "spear_pair", "atlatl", "dart_bundle", "pistol", "torch",
				"log", "firewood", "branches", "pole", "bow", "clay_pipe"] else Vector3.ZERO
		if kind in ["felling_axe", "mattock"]:
			m.rotation = Vector3(deg_to_rad(-42.0), 0.0, 0.0)   # the haft (+Y) from bottom left, the head top right
		elif kind in ["stone", "flint"]:
			m.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(35.0), 0.0)
		await get_tree().process_frame
		var aabb := _bounds(m)
		var c := aabb.get_center()
		var dir := Vector3.RIGHT
		if kind in FROM_ABOVE:
			var el := deg_to_rad(ABOVE_DEG)
			var yw := deg_to_rad(ABOVE_YAW_DEG)
			dir = Vector3(cos(el) * cos(yw), sin(el), cos(el) * sin(yw))
		_cam.global_position = c + dir * 3.0
		_cam.look_at(c, Vector3.UP)
		# fit what the camera sees of the bounds (their corners on its screen), square
		var right := _cam.global_basis.x
		var up := _cam.global_basis.y
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for i in 8:
			var q := aabb.get_endpoint(i) - c
			var sp := Vector2(q.dot(right), q.dot(up))
			lo = lo.min(sp)
			hi = hi.max(sp)
		var mid := (lo + hi) * 0.5
		var at := c + right * mid.x + up * mid.y
		var z := float(m.get_meta(&"scan_zoom")) if m.has_meta(&"scan_zoom") else float(ZOOM.get(kind, 1.0))
		if FOCUS.has(kind):
			at = m.global_transform * (own.get_center() + Vector3(0, 0, own.size.z * float(FOCUS[kind])))
		_cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.1 * z * (SKETCH_MARGIN if STYLE == "sketch" else 1.0)
		_cam.global_position = at + dir * 3.0
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var img := _vp.get_texture().get_image()
		if img == null or img.is_empty():
			# no renderer (headless): no picture
			_cache[kind] = null
			_holder.remove_child(m)
			m.free()
			ready_icon.emit(kind)
			continue
		if STYLE == "sketch":
			img = await _sketch(img)
		else:
			img = _edged(img)
		_cache[kind] = ImageTexture.create_from_image(img)
		_holder.remove_child(m)
		m.free()
		ready_icon.emit(kind)
	_busy = false


## The photoscanned model for `kind`, in a holder (its pose is set on the holder); null when the file is not here.
static func scanned(kind: String) -> Node3D:
	if not SCANNED.has(kind):
		return null
	var sc: Dictionary = SCANNED[kind]
	var id := String(sc.id)
	var path := SCAN_PATH % [id, id]
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var holder := Node3D.new()
	holder.name = "Scanned_" + id
	holder.set_meta(&"scan_axis", String(sc.get("axis", "")))
	holder.set_meta(&"scan_zoom", float(sc.get("zoom", 1.0)))
	var inst := ps.instantiate()
	holder.add_child(inst)
	if sc.has("tint"):
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			for si in (mesh.get_surface_count() if mesh else 0):
				var mat := mesh.surface_get_material(si) as BaseMaterial3D
				if mat:
					var m2 := mat.duplicate() as BaseMaterial3D
					m2.albedo_color = m2.albedo_color * (sc.tint as Color)
					(mi as MeshInstance3D).set_surface_override_material(si, m2)
	return holder


## Turns a scanned model inside its holder so its longest side lies along `axis` ("y" or "z"; "" leaves it).
static func _align_long(holder: Node3D, axis: String) -> void:
	if axis == "" or holder.get_child_count() == 0:
		return
	var inner := holder.get_child(0) as Node3D
	var b := _bounds(holder).size
	var longest := 0 if b.x >= b.y and b.x >= b.z else (1 if b.y >= b.z else 2)
	var want := 1 if axis == "y" else 2
	if longest != want:
		# the rotation taking the longest axis onto the wanted one
		var from := [Vector3.RIGHT, Vector3.UP, Vector3.BACK][longest] as Vector3
		var to := [Vector3.RIGHT, Vector3.UP, Vector3.BACK][want] as Vector3
		inner.transform = Transform3D(Basis(from.cross(to).normalized(), PI * 0.5), Vector3.ZERO) * inner.transform
	if axis == "y":
		# a tool's head across the view (the camera looks along X): its widest side along Z, not at the camera
		var b2 := _bounds(holder).size
		if b2.x > b2.z:
			inner.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO) * inner.transform


func _model(kind: String) -> Node3D:
	var sc := scanned(kind)
	if sc:
		return sc
	if GatherModels.has(kind):
		return GatherModels.build(kind)
	if WildlifeModels.has(kind):
		return WildlifeModels.build(kind)
	if ForageModels.has(kind):
		return ForageModels.build(kind)
	if ProvisionModels.has(kind):
		return ProvisionModels.build(kind)
	if ViceModels.has(kind):
		return ViceModels.build(kind)
	if FishModels.has(kind):
		return FishModels.build(kind)
	if GearModels.has(kind):
		return GearModels.build(kind)
	match kind:
		"musket", "bow", "pistol":
			return WeaponModels.build(kind)
		"over_under":
			return WeaponModels.build("musket")
		"dried_wolf_pelt":
			return WildlifeModels.build("wolf_pelt")
		"dried_fox_pelt":
			return WildlifeModels.build("fox_pelt")
		"dried_marten_pelt", "dried_mink_pelt", "dried_fisher_pelt", "dried_raccoon_pelt":
			return GearModels.build(kind.trim_prefix("dried_"))
		"tomahawk", "atlatl":
			return ThrowableModels.build(kind)
		"spear_pair":
			return LoadoutModels.build("spear_pair") if LoadoutModels.has_glb("spear_pair") else ThrowableModels.build("spear")
		"dart_bundle":
			# the bundle glb is only the ties: the five darts in them, as carried on the back
			return SlingModels.stowed("dart_bundle", 5, "long_B")
		"quiver", "powder_horn":
			return LoadoutModels.build(kind) if LoadoutModels.has_glb(kind) else null
		"torch":
			return TorchModels.build()
	return null


## The render drawn as a sketch (icon_sketch.gdshader) in the painter's viewport, read back.
func _sketch(img: Image) -> Image:
	if _paint_vp == null:
		_paint_vp = SubViewport.new()
		_paint_vp.size = Vector2i(SIZE, SIZE)
		_paint_vp.transparent_bg = true
		_paint_vp.disable_3d = true
		add_child(_paint_vp)
		_paint_rect = TextureRect.new()
		_paint_rect.size = Vector2(SIZE, SIZE)
		_paint_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var mat := ShaderMaterial.new()
		mat.shader = load(SKETCH_SHADER)
		_noises(mat)
		_paint_rect.material = mat
		_paint_vp.add_child(_paint_rect)
	_paint_rect.texture = ImageTexture.create_from_image(img)
	_paint_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return _paint_vp.get_texture().get_image()


## The painter's three tileable noises (the engine's seamless noise images).
static func _noises(mat: ShaderMaterial) -> void:
	for i in 3:
		var f := FastNoiseLite.new()
		f.seed = 17 + i * 101
		f.frequency = [0.045, 0.045, 0.12][i]
		f.fractal_octaves = 3
		var img := f.get_seamless_image(128, 128)
		mat.set_shader_parameter([&"noise_a", &"noise_b", &"noise_c"][i], ImageTexture.create_from_image(img))


## The icon with a dark edge round it: its silhouette in black, laid under it shifted a little every way.
static func _edged(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	var sil := img.duplicate() as Image
	sil.adjust_bcs(0.0, 1.0, 1.0)       # black, the alpha kept
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var r := Rect2i(Vector2i.ZERO, img.get_size())
	for i in 12:
		var a := TAU * i / 12.0
		out.blend_rect(sil, r, Vector2i(roundi(cos(a) * EDGE_PX), roundi(sin(a) * EDGE_PX)))
	out.blend_rect(img, r, Vector2i.ZERO)
	return out


static func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.visible:
			continue
		var bb := gi.global_transform * gi.get_aabb()
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	return out if not first else AABB(n.global_position - Vector3.ONE * 0.2, Vector3.ONE * 0.4)
