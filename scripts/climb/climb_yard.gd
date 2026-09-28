class_name ClimbYard
extends Node3D
## The climbing test yard (scenes/climb_yard.tscn; user 2026-09-27 "yea a test scene to see it in action"): at the far
## end of the range lane, where the ground is flat and clear, facing the player coming from the fort:
##   Step    a 2.5 m rock step: grab it, crawl up, pull up onto the top
##   Cliff   a 6 m rock face (a pillar 6 x 3 m): crawl up and sideways, round its corners, up onto the top
##   Slab    a rock slab leaning at 50 degrees, front left: the clinging crawl on a slope (grip_loop), not the hang
##   Giant   the woolly mammoth (StandInGiant; user 2026-09-27: "lets add a mammoth in our test climb scene") pacing on
##           the right: grab (or jump for) the fur on its flank, climb to its back, hold on when it shakes; come near on
##           foot and it drives you off (MammothTemper: threat, charge, trunk, stomp), then leaves
##   Bison   a bull bison standing beyond it (user 2026-09-27: "we can add the bison"): a still model for now, solid
##           but not grippable (it is not rigged yet)
## All the rock is GripSurface "rock"; the mammoth's body is "fur". The rock look is the Poly Haven boulder texture (CC0,
## assets/environment/props/SOURCES.md); the mammoth is Riley Kuhlman's (CC0, assets/wildlife/ice_age/SOURCE.md), the
## bison Poly by Google's (CC-BY 3.0, assets/wildlife/polypizza/SOURCE.md).

const ROCK_TEX := "res://assets/environment/props/boulder_01/boulder_01_"
const BISON := "res://assets/wildlife/polypizza/bison.glb"
## The bison model's size (as modelled, units of its own) to a bull's: about 1.9 m at the hump, 2.8 m long.
const BISON_SCALE := 0.135

var giant: StandInGiant
## The mammoth's temper (it drives people off, then leaves; off in tool and test runs unless asked for).
var temper: MammothTemper
var stations := {}               ## name -> {"stand": Vector3, "look": Vector3}


## Builds the yard with its centre at `at` (on flat ground, y = the ground); the player comes from +Z.
func build(at: Vector3, player: FrontierPlayer) -> void:
	position = Vector3.ZERO
	var rock := _rock_material()
	_rock("Step", at + Vector3(-2.0, 1.25, -2.0), Vector3(3.0, 2.5, 4.0), 0.0, rock)
	_rock("Cliff", at + Vector3(-8.0, 3.0, -3.0), Vector3(6.0, 6.0, 3.0), 0.0, rock)
	# the slab: a thick plate leaning back at 50 degrees toward the player, its foot on the ground
	_rock("Slab", at + Vector3(-11.5, 1.95, 3.5), Vector3(4.0, 0.8, 5.0), 0.0, rock, Basis(Vector3.RIGHT, deg_to_rad(50.0)))
	giant = StandInGiant.new()
	giant.name = "Mammoth"
	giant.player = player
	add_child(giant)
	giant.build(Transform3D(Basis(), at + Vector3(8.0, 0.0, -4.0)))
	temper = MammothTemper.new()
	temper.name = "Temper"
	temper.giant = giant
	giant.add_child(temper)
	_bison(at + Vector3(13.5, 0.0, 2.0), deg_to_rad(-35.0))
	stations = {
		"step": {"stand": at + Vector3(-2.0, 0.0, 0.6), "look": at + Vector3(-2.0, 1.4, -2.0)},
		"cliff": {"stand": at + Vector3(-8.0, 0.0, -0.9), "look": at + Vector3(-8.0, 2.5, -3.0)},
		"slab": {"stand": at + Vector3(-11.5, 0.0, 5.9), "look": at + Vector3(-11.5, 1.5, 3.5)},
		"giant": {"stand": at + Vector3(6.35, 0.0, -4.0), "look": at + Vector3(8.0, 2.6, -4.0)},
		"bison": {"stand": at + Vector3(11.0, 0.0, 6.5), "look": at + Vector3(13.5, 1.0, 2.0)},
	}


func _rock(nm: String, c: Vector3, size: Vector3, yaw: float, mat: Material, basis := Basis()) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = nm
	add_child(b)
	b.global_transform = Transform3D(basis.rotated(Vector3.UP, yaw), c)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	b.add_child(mi)
	GripSurface.tag(b, "rock")
	b.set_meta(&"surface", "stone")
	return b


static func _tex(p: String) -> Texture2D:
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _rock_material() -> Material:
	var m := ORMMaterial3D.new()
	m.albedo_texture = _tex(ROCK_TEX + "albedo_1k.png")
	m.normal_enabled = true
	m.normal_texture = _tex(ROCK_TEX + "normal_1k.png")
	m.orm_texture = _tex(ROCK_TEX + "arm_1k.png")
	m.albedo_color = Color(0.98, 1.04, 1.18)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.28, 0.28, 0.28)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## The bison standing at `c` (on the ground), turned `yaw`: the model scaled to a bull, on a body the player cannot walk
## through (a box over its body; its legs are thin).
func _bison(c: Vector3, yaw: float) -> void:
	var ps := load(BISON) as PackedScene
	if ps == null:
		return
	var b := StaticBody3D.new()
	b.name = "Bison"
	add_child(b)
	b.global_transform = Transform3D(Basis(Vector3.UP, yaw), c)
	var m := ps.instantiate() as Node3D
	m.scale = Vector3.ONE * BISON_SCALE
	b.add_child(m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 1.25, 2.5)
	cs.shape = bs
	cs.position = Vector3(0.0, 1.15, 0.0)
	b.add_child(cs)
	b.set_meta(&"surface", "flesh")
