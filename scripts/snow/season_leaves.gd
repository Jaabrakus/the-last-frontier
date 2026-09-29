class_name SeasonLeaves
extends Node
## The broadleaf trees' year (user 2026-09-28: "for autumn we can have orange leaves ... the trees need to lose their green
## leaves, only pine trees keep their leaves ... and then spring it starts to grow again"): the shader global leaf_season
## (shaders/vegetation/leaf_season.gdshaderinc) from the game's date, the survival core's clock (the sky's without one).
## The maples, oaks, birches and hazels (VegAssets.AUTUMN) turn from mid September, are in full colour by mid October,
## drop their leaves through November, stand bare to April, bud in April and are in full leaf by June; the pines and the
## hemlocks keep their needles (and the snow on them).
## Tree by tree over the whole world ("slowly all of them turn autumn colors until snow then they all disappear", "it
## should be a world thing to turn trees not just players eye distance"): each tree runs this value early or late by its
## species, its stand, its ground and itself (leaf_season.gdshaderinc leaf_season_at), in every LOD at every distance and
## in the shadow crowns, so the woods turn patch by patch; the first lasting snow strips what leaves are left
## (STRIP_CM); the canopy's light follows (canopy_leaves: the woods under the bare broadleaves open to the sky).
##
##   leaf_season    0 summer .. 1 full autumn colour .. 2 bare .. 3 (= 0) full leaf again
##   canopy_leaves  1 the broadleaves' crowns full .. LIMBS_COVER bare (CanopyMap.leaves on the CPU)

## [day of the year (0 = Early January .. 35 = Late December; a game day is a third of a month), leaf_season].
const KEYS := [[0.0, 2.0], [9.0, 2.0], [10.5, 2.35], [12.5, 2.75], [15.0, 3.0], [15.01, 0.0], [25.0, 0.0], [28.0, 1.0],
		[29.0, 1.12], [31.0, 1.8], [32.5, 2.0], [36.0, 2.0]]

## Snow this deep (cm) on the ground in the fall strips the trees bare (less: that share of the way).
const STRIP_CM := 8.0
## A bare broadleaf's limbs still take this much of its crown's sky.
const LIMBS_COVER := 0.2
const CanopyMap := preload("res://scripts/world/vegetation/canopy_map.gd")

## The value set now (tests); `force` >= 0 holds it (tools, captures).
var value := 0.0
var force := -1.0
## canopy_leaves now.
var leaves := 1.0
## How far this autumn's snow has stripped the trees (0..1; kept through a thaw: the leaves do not come back).
var stripped := 0.0


static func at_day(day: float) -> float:
	var d := fposmod(day, 36.0)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if d >= float(a[0]) and d <= float(b[0]):
			var t := (d - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4)
			return lerpf(float(a[1]), float(b[1]), t)
	return 0.0


func _process(_delta: float) -> void:
	var v := force
	if v < 0.0:
		var b := SurvivalBridge.find(get_tree())
		var core: SurvivalCore = b.core if b else null
		if core:
			v = at_day(float(SurvivalClock.day_of_year(core)) + SurvivalClock.hour(core) / 24.0)
			# the first lasting snow brings down the leaves still on the trees
			if v >= 0.5 and v < 2.0:
				stripped = maxf(stripped, clampf(SurvivalWeather.snow_depth_cm(core) / STRIP_CM, 0.0, 1.0))
				v = lerpf(v, 2.0, stripped)
			else:
				stripped = 0.0
		else:
			# (no survival core: the sky's calendar, its day of a 365-day year)
			var dn := get_tree().get_first_node_in_group(&"weather")
			var c: Variant = dn.get("clock") if dn else null
			v = at_day(float(c.day_of_year) / 365.0 * 36.0) if c else 0.0
	if v >= 3.0:
		v = 0.0
	value = v
	SnowCover._global(&"leaf_season", v)
	leaves = lerpf(LIMBS_COVER, 1.0, 1.0 - bare(v))
	CanopyMap.leaves = leaves
	SnowCover._global(&"canopy_leaves", leaves)


func _exit_tree() -> void:
	# (the next scene's canopy, if any, in full leaf until told otherwise)
	CanopyMap.leaves = 1.0
	SnowCover._global(&"canopy_leaves", 1.0)


## How bare the broadleaves are at `v` on the whole (leaf_season.gdshaderinc leaf_bare): 0 in leaf .. 1 bare.
static func bare(v: float) -> float:
	if v <= 1.0 or v >= 3.0:
		return 0.0
	if v < 2.0:
		return clampf((v - 1.0) * 1.3, 0.0, 1.0)
	return 1.0 - smoothstep(2.0, 2.8, v)
