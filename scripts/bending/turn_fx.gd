extends Node3D
## The Turn's water (the anime pass, 2026-10-16; the owner: water "as close to Anime Style Avatar: The Last Airbender as
## possible"): two ribbons of water winding round the guard's waist, each chasing the other in the lap a caught shot is swung
## round him in (BendZone.SWING_S, SWING_R), drawn into the circle as the guard stands (0.25 s) and gone with the guard (a node
## of its look: freed with the zone). Their paths are laid again every frame (ToonRibbon.lay_path). On the guarder only (the
## zone's `r2` look). A shot swung round him leaves its own ribbon behind it (the water bolt's trail), so what is caught is
## seen going round as a ribbon too. Looks only.
##   TurnFx.make(under, zone) -> TurnFx       muddy(): the ribbons turn to mud (a stone swung round in water: BendZone._muddy)

const RIBS := 2
## How much of the circle each ribbon covers (rad) and its half widths (head, tail), the lap's time (s) and its radius (m).
const ARC := 3.0
const HALF_W := Vector2(0.075, 0.1)
const LAP_S := 0.45
const GROW_S := 0.25
const N := 28

var zone: Node3D
var _t := 0.0
var _ribs: Array[ToonRibbon] = []


static func make(under: Node3D, p_zone: Node3D) -> Node3D:
	var f := (load("res://scripts/bending/turn_fx.gd") as GDScript).new() as Node3D
	f.name = "TurnFx"
	f.set(&"zone", p_zone)
	under.add_child(f)
	return f


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	for i in RIBS:
		var rb := ToonRibbon.new()
		rb.main_mat = ToonFx.mat("water_ribbon")
		rb.coils = 0
		add_child(rb)
		_ribs.append(rb)


## The ribbons turned to mud.
func muddy() -> void:
	for rb in _ribs:
		rb.main_mat = ToonFx.mat("mud_ribbon")


func _process(dt: float) -> void:
	_t += dt
	if zone == null or not is_instance_valid(zone):
		queue_free()
		return
	var c := zone.global_position
	var grow := smoothstep(0.0, GROW_S, _t)
	var span := ARC * grow
	for i in RIBS:
		var head := _t * TAU / LAP_S + PI * float(i)
		var pts := PackedVector3Array()
		for j in N + 1:
			var f := float(j) / float(N)
			var a := head - f * span
			var y := 1.0 + 0.16 * sin(a * 2.0 + float(i)) + 0.1 * f
			pts.append(c + Vector3(sin(a) * 1.0, y, cos(a) * 1.0))
		_ribs[i].fade = 1.0
		_ribs[i].lay_path(pts, HALF_W.x * grow, HALF_W.y * grow, 0.1)
