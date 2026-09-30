class_name WaterSurface
extends RefCounted
## The water a boat floats on, whichever it is (WorldRiver today; the lake the river widens into joins here). Everything the
## boats ask of the water goes through this: its surface, how deep it is, how it runs.
##   surface_at(x, z)   the surface's height, or NO_WATER where there is none
##   depth_at(x, z)     how deep it is over the ground (0 where none)
##   current_at(x, z)   the way and how fast it carries a floating thing (m/s, flat): the river's flow, the faster in a rapid
## user 2026-09-29: "widen the river into a lake".

const NO_WATER := -INF
## The river's drift, m/s (the current the fords and bends show; rapids run RAPID_MULT x faster).
const RIVER_MPS := 0.45
const RAPID_MULT := 3.0


static func surface_at(x: float, z: float) -> float:
	return WorldRiver.surface_at(x, z) if WorldRiver.has_water() else NO_WATER


static func depth_at(x: float, z: float) -> float:
	var s := surface_at(x, z)
	return maxf(s - FrontierTerrain.height_at(x, z), 0.0) if s != NO_WATER else 0.0


static func current_at(x: float, z: float) -> Vector3:
	if surface_at(x, z) == NO_WATER:
		return Vector3.ZERO
	var mult := 1.0 + (RAPID_MULT - 1.0) * WorldRiver.rapid_at(z)
	return WorldRiver.flow_at(z) * RIVER_MPS * mult
