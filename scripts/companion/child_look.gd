class_name ChildLook
extends RefCounted
## A child's look from its parents' looks, through the customizer's face engine (user 2026-09-28: "the baby should use our
## faces engine"): the same look dictionary the player and everyone else is dressed from (CharacterPeoples, BodyMaterials.
## apply_look, PlayerAppearance.dress), so the child's face, skin, eyes, hair and brows come from the two parents and it is
## drawn and blinks like everyone. Deterministic for the child's seed (the family record keeps it).
##
##   var look := ChildLook.from_parents(mother_look, father_look, child.sex, child.seed)
##
## Face: each face feature comes from one parent or the other at random (about half each) or a blend of the two, with a
## little noise, clamped to -1..1. Skin: melanin a blend of the parents' with a small spread, the undertone and iris from
## one parent, hair colour from one parent (a child's hair style is set by the caller: babies have little). The stage
## modifiers (an infant's proportions, bigger eyes) are for the caller: `infant(look)` gives the shared baby-like tweaks.

const NOISE := 0.06


static func from_parents(mother: Dictionary, father: Dictionary, sex: float, seed_v: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var out := {}
	var keep := ["people", "face_style"]
	for k in keep:
		var src: Dictionary = mother if rng.randf() < 0.5 else father
		if src.has(k):
			out[k] = src[k]
	out["sex"] = sex
	var fa: Dictionary = mother.get("face", {}) if mother.get("face") is Dictionary else {}
	var fb: Dictionary = father.get("face", {}) if father.get("face") is Dictionary else {}
	var keys := {}
	for k in fa.keys():
		keys[k] = true
	for k in fb.keys():
		keys[k] = true
	var face := {}
	for k in keys.keys():
		var a := float(fa.get(k, 0.0))
		var b := float(fb.get(k, 0.0))
		var roll := rng.randf()
		var v := a if roll < 0.35 else b if roll < 0.7 else (a + b) * 0.5
		v = clampf(v + rng.randfn(0.0, NOISE), -1.0, 1.0)
		if absf(v) > 0.001:
			face[k] = snappedf(v, 0.001)
	out["face"] = face
	var ma := float(mother.get("melanin", 0.4))
	var mb := float(father.get("melanin", 0.4))
	out["melanin"] = snappedf(clampf(lerpf(ma, mb, rng.randf_range(0.3, 0.7)) + rng.randfn(0.0, 0.02), 0.0, 1.0), 0.001)
	var sk: Dictionary = mother if rng.randf() < 0.5 else father
	for k in ["undertone", "iris", "haemoglobin", "freckles"]:
		if sk.has(k):
			out[k] = sk[k]
	var hr: Dictionary = (mother if rng.randf() < 0.5 else father).get("hair", {})
	out["hair"] = {"style": String(hr.get("style", "")), "color": hr.get("color", "dark_brown")}
	out["brows"] = ((mother if rng.randf() < 0.5 else father).get("brows", {}) as Dictionary).duplicate()
	out["stature"] = 1.0
	return out


## The look of the same child as an infant (BabyModel's head): the parents' blended face weights nudged toward baby proportions
## (baby.json "infant": `blend` of the way to each target, targets in -1..1 face weights: a short broad face, high forehead (no
## brow ridge), large low-set eyes, a button nose, full round cheeks, a tiny chin), soft flushed skin, no weathering, wispy hair.
## The child's own features still show through (the rest of its face stays the parents' blend).
static func infant(look: Dictionary) -> Dictionary:
	var cfg: Dictionary = BabyCare.cfg().get("infant", {})
	var out := look.duplicate(true)
	var face: Dictionary = {}
	var f: Variant = out.get("face", {})
	if f is Dictionary:
		face = (f as Dictionary).duplicate()
	var blend := float(cfg.get("blend", 0.75))
	var targets: Dictionary = cfg.get("targets", {})
	for k: String in targets:
		face[k] = snappedf(clampf(lerpf(float(face.get(k, 0.0)), float(targets[k]), blend), -1.0, 1.0), 0.001)
	out["face"] = face
	out["haemoglobin"] = maxf(float(out.get("haemoglobin", 0.5)), float(cfg.get("haemoglobin", 0.62)))
	out["weathering"] = 0.0
	out["freckles"] = 0.0
	out["stubble"] = 0.0
	out["marks"] = {}
	out["brows"] = {"thickness": 0.3, "arch": 0.4, "density": 0.45}
	out["hair"] = {"style": String(cfg.get("hair_style", "hair_shaved")), "color": (look.get("hair", {}) as Dictionary).get("color", "dark_brown")}
	return out


## The body keys of a look for a life stage (one rule for the baby, the toddler and the child): until a teen milestone the body is
## flat and asexual: no bust (the breast shapes at their smallest), no genital shape, no pubic hair, stature 1, and the `sex` fit
## at the neutral value that gives the flattest chest and the least hip and waist curve (baby.json "body" neutral_sex, chosen by
## the shots). "teen" and "adult" keep the look's own. The face keeps its own features (the sex fit also shapes the head a little).
static func body_for_stage(look: Dictionary, stage: String) -> Dictionary:
	if stage in ["teen", "adult"]:
		return look.duplicate(true)
	var out := look.duplicate(true)
	out["sex"] = float((BabyCare.cfg().get("body", {}) as Dictionary).get("neutral_sex", 1.0))
	out["bust"] = -1.0
	out["genital"] = 0.0
	out["body_hair"] = 0.0
	out["stature"] = 1.0
	return out
