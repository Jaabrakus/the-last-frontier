class_name ThuyVanStillReach
extends Node3D
## The still reach's own things in the world (WorldRiver.reaches; ThuyVanLevel's S0 / S1; plan phase 1, T5). What the
## water does there is WorldRiver's (the flow), RiverWater's (its look and its sound) and FishLife's (the fish hanging);
## this adds what stands in the reach:
##   stones   pale stones on the bed along the reach (the vegetation's own rock models in a pale stone, nothing new: the
##            place's name, Đá Trắng, is "white stone"). There in both states; the running water hides them, the still and
##            clear water shows them (river.gdshader's still band).
##   mist     held mist: soft cards over the water along the reach, fading in with S1 (FADE_S) and out with S0. Nothing in
##            them moves: no wind, no time; they turn only to face the eye (fixed-Y billboards).
## Headless (tests): nothing is built; `shown` still follows the state.

const VegAssets := preload("res://scripts/world/vegetation/veg_assets.gd")
## The rock models the stones take, in turn (VegAssets.PROPS: rock_a .. rock_e).
const STONE_KINDS := [2, 3, 5, 6, 4]
const STONES := 80
const STONE_R := Vector2(0.12, 0.42)
const STONE_COLOR := Color(0.84, 0.83, 0.78)
## The stones lie this far inside the reach's ends, and this far either side of its centre at most.
const STONE_IN_M := 6.0
const STONE_ACROSS_M := 8.5
const MIST_CARDS := 28
## A card's width and height (m), its height over the water (m), and how strong the mist is when held (alpha).
const MIST_W := Vector2(9.0, 18.0)
const MIST_H := Vector2(2.5, 4.5)
const MIST_UP := Vector2(0.2, 1.6)
const MIST_ALPHA := 0.42
const MIST_COLOR := Color(0.86, 0.88, 0.86)
const MIST_TEX := 128
const FADE_S := 3.0

## The reach ({id, z_from, z_to, ease_m, scale_by_state}).
var reach := {}
## How much of the held mist shows (0..1), and what it is going to.
var shown := 0.0
var target := 0.0
var stones: Array[MeshInstance3D] = []
var cards: Array[MeshInstance3D] = []
var rng := RandomNumberGenerator.new()
var _mist_mat: StandardMaterial3D


func setup(r: Dictionary) -> void:
	reach = r


func _ready() -> void:
	rng.seed = 1765
	if reach.is_empty() or DisplayServer.get_name() == "headless":
		return
	_build_stones()
	_build_mist()
	_show()


## Held (S1) or gone (S0); `instant`: at once (the shots, the tests).
func set_still(on: bool, instant := false) -> void:
	target = 1.0 if on else 0.0
	if instant:
		shown = target
		_show()


func _process(delta: float) -> void:
	if is_equal_approx(shown, target):
		return
	shown = move_toward(shown, target, delta / FADE_S)
	_show()


func _show() -> void:
	if _mist_mat == null:
		return
	_mist_mat.albedo_color = Color(MIST_COLOR, MIST_ALPHA * smoothstep(0.0, 1.0, shown))
	for c in cards:
		c.visible = shown > 0.001


func _build_stones() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE_COLOR
	mat.roughness = 0.82
	var z0 := float(reach.z_from) + STONE_IN_M
	var z1 := float(reach.z_to) - STONE_IN_M
	var tries := 0
	while stones.size() < STONES and tries < STONES * 6:
		tries += 1
		var z := rng.randf_range(z0, z1)
		var x := WorldRiver.x_at(z) + rng.randf_range(-STONE_ACROSS_M, STONE_ACROSS_M)
		var ground := FrontierTerrain.height_at(x, z)
		var level := WorldRiver.level_at(z)
		if level - ground < 0.25:
			continue
		var kind: int = STONE_KINDS[stones.size() % STONE_KINDS.size()]
		var mesh := VegAssets.prop_mesh(kind, 0)
		if mesh == null:
			return
		var bb := mesh.get_aabb()
		var r := rng.randf_range(STONE_R.x, STONE_R.y)
		var s := r * 2.0 / maxf(maxf(bb.size.x, bb.size.z), 0.01)
		var sy := s * 0.6
		# half sunk in the bed, its crown well under the water
		var y := ground - bb.position.y * sy - bb.size.y * sy * 0.45
		if y + bb.end.y * sy > level - 0.1:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Stone_%d" % stones.size()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 180.0
		add_child(mi)
		mi.global_transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, sy, s)), Vector3(x, y, z))
		stones.append(mi)


func _build_mist() -> void:
	_mist_mat = StandardMaterial3D.new()
	_mist_mat.albedo_texture = _mist_texture()
	_mist_mat.albedo_color = Color(MIST_COLOR, 0.0)
	_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mist_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_mist_mat.billboard_keep_scale = true
	_mist_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	_mist_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mist_mat.disable_receive_shadows = true
	# soft where it meets the water and the banks, and thin right in front of the eye
	_mist_mat.proximity_fade_enabled = true
	_mist_mat.proximity_fade_distance = 2.5
	_mist_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_mist_mat.distance_fade_min_distance = 1.5
	_mist_mat.distance_fade_max_distance = 9.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var z0 := float(reach.z_from) + 4.0
	var z1 := float(reach.z_to) - 4.0
	for i in MIST_CARDS:
		var z := lerpf(z0, z1, (float(i) + rng.randf()) / float(MIST_CARDS))
		var x := WorldRiver.x_at(z) + rng.randf_range(-9.0, 9.0)
		var w := rng.randf_range(MIST_W.x, MIST_W.y)
		var h := rng.randf_range(MIST_H.x, MIST_H.y)
		var mi := MeshInstance3D.new()
		mi.name = "Mist_%d" % i
		mi.mesh = quad
		mi.material_override = _mist_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.visibility_range_end = 260.0
		add_child(mi)
		var y := WorldRiver.level_at(z) + rng.randf_range(MIST_UP.x, MIST_UP.y) + h * 0.5
		mi.global_transform = Transform3D(Basis().scaled(Vector3(w, h, 1.0)), Vector3(x, y, z))
		cards.append(mi)


## A soft cloud on a card (made at load; nothing to ship): white, its alpha a broad falloff from the middle (wider than
## tall) times a fractal noise.
func _mist_texture() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = 1766
	n.frequency = 0.035
	n.fractal_octaves = 4
	var img := Image.create(MIST_TEX, MIST_TEX, false, Image.FORMAT_RGBA8)
	for j in MIST_TEX:
		for i in MIST_TEX:
			var u := (float(i) + 0.5) / MIST_TEX * 2.0 - 1.0
			var v := (float(j) + 0.5) / MIST_TEX * 2.0 - 1.0
			var fall := 1.0 - smoothstep(0.25, 1.0, sqrt(u * u * 0.8 + v * v * 1.3))
			var cloud := smoothstep(-0.25, 0.55, n.get_noise_2d(float(i), float(j)))
			img.set_pixel(i, j, Color(1.0, 1.0, 1.0, clampf(fall * cloud, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
