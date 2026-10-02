class_name AnimalHair
extends RefCounted
## The animals' hair (tools/wildlife/animal_hair.py: strand cards in each smoothed model's "Hair" mesh; user 2026-10-02,
## "lets add hairs likes our hair for the humans"): the hair material on it (the human hair's strand atlas coloured by
## the skin at each card's root, assets/wildlife/materials/animal_hair.tres), no shadows from the cards (the body casts
## the animal's), never simplified by distance (an automatic LOD of strand cards is a mess of slivers), and not drawn
## beyond HAIR_RANGE (a few pixels of fuzz there); the horse's eye material on added "Eyes" (the mammoth's). Called on a
## model's instance (WildAnimal, StandInGiant).

const MATERIAL := preload("res://assets/wildlife/materials/animal_hair.tres")
## The eyes added to a model that had none (the mammoth's): the horse's eye look (animal_eye.gdshader).
const EYE_MATERIAL := preload("res://assets/wildlife/materials/animal_eye.tres")
## Metres from the camera past which the hair is not drawn (fading out over the last HAIR_FADE).
const HAIR_RANGE := 70.0
const HAIR_FADE := 15.0


static func apply(model: Node) -> void:
	for mi: MeshInstance3D in model.find_children("Hair", "MeshInstance3D", true, false):
		mi.material_override = MATERIAL
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.lod_bias = 100.0
		mi.visibility_range_end = HAIR_RANGE
		mi.visibility_range_end_margin = HAIR_FADE
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for mi: MeshInstance3D in model.find_children("Eyes", "MeshInstance3D", true, false):
		mi.material_override = EYE_MATERIAL
