class_name FormCircle
extends MeshInstance3D
## The Form lock's circle (FormCast; SwayCaster's lock for the art "form"): our own circle-work drawn on the ground at the
## target (or on the face of an upright, for mend), a flat quad of `radius` laid on the surface's `normal` with
## shaders/sway/form_circle.gdshader: it draws itself as `fill` goes 0 -> 1 (the lock), pulses when full, flashes on the click
## and on the release, and fades away when the lock ends (end(): "cast" swells and fades, "break" / "fizzle" dims out). A
## faint blue light comes up under it as it fills (not headless). Cheap: one quad, one light, no shadow.

const SHADER := "res://shaders/sway/form_circle.gdshader"
const GROUP := &"form_circles"
const FLASH_S := 0.3
const END_S := {"cast": 0.9, "break": 0.45, "fizzle": 0.6}
const LIGHT_ENERGY := 0.9
## The circle's render layer (20): outside every ground decal's cull mask (FormHollow's, a fire's ruin, blood: layer 1), so
## a circle drawn over an older hollow keeps its glowing lines (the camera sees every layer). FormCrackle's too.
const FX_LAYER := 1 << 19

var radius := 1.0
var normal := Vector3.UP
var fill := 0.0
var full := false
var color := Color(0.5, 0.78, 1.0)
## "": drawing; "cast", "break", "fizzle": fading away (freed after).
var ending := ""

var _mat: ShaderMaterial
var _flash := 0.0
var _end_t := 0.0
var _spin := 0.0
var _light: OmniLight3D

static var _shader: Shader


## A circle of `r` at `at` on a surface facing `n`, under `parent` (the level).
static func make(parent: Node, at: Vector3, n: Vector3, r: float, col: Color) -> FormCircle:
	var c := FormCircle.new()
	c.name = "FormCircle"
	c.radius = r
	c.normal = n.normalized() if n.length_squared() > 1e-6 else Vector3.UP
	c.color = col
	c.add_to_group(GROUP)
	parent.add_child(c)
	c.global_transform = Transform3D(basis_on(c.normal), at + c.normal * 0.025)
	return c


## A basis with +Y on `n` (its X and Z in the surface).
static func basis_on(n: Vector3) -> Basis:
	var y := n.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func material(col: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = load(SHADER) as Shader
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter(&"color", Vector3(col.r, col.g, col.b))
	return m


func _ready() -> void:
	var q := PlaneMesh.new()
	q.size = Vector2.ONE * radius * 2.0
	mesh = q
	_mat = material(color)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = FX_LAYER
	if DisplayServer.get_name() != "headless":
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.light_energy = 0.0
		_light.omni_range = radius * 2.6
		_light.shadow_enabled = false
		_light.position = Vector3.UP * 0.35
		add_child(_light)
	_apply()


## The click (full) or the release: a flash.
func flash() -> void:
	_flash = 1.0


func end(kind: String) -> void:
	if ending != "":
		return
	ending = kind
	_end_t = 0.0
	if kind == "cast":
		_flash = 1.0


func _process(dt: float) -> void:
	_spin += dt * (1.0 + 2.5 * fill)
	_flash = maxf(_flash - dt / FLASH_S, 0.0)
	if ending != "":
		_end_t += dt
		var span := float(END_S.get(ending, 0.5))
		if _end_t >= span:
			queue_free()
			return
	_apply()


func _apply() -> void:
	if _mat == null:
		return
	var f := 1.0
	var g := 1.0
	if ending != "":
		var u := clampf(_end_t / float(END_S.get(ending, 0.5)), 0.0, 1.0)
		f = 1.0 - u
		if ending == "cast":
			g = 1.0 + 0.8 * (1.0 - u)
		else:
			g = 0.55
	_mat.set_shader_parameter(&"fill", fill)
	_mat.set_shader_parameter(&"full", 1.0 if full and ending == "" else 0.0)
	_mat.set_shader_parameter(&"flash", _flash)
	_mat.set_shader_parameter(&"fade", f)
	_mat.set_shader_parameter(&"glow", g)
	_mat.set_shader_parameter(&"spin", _spin)
	if _light != null:
		_light.light_energy = LIGHT_ENERGY * (0.25 + fill * 0.75 + _flash) * f
