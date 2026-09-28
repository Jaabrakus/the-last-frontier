extends SceneTree
## Bakes the ground profile of every tree / sapling / shrub variant into
## assets/environment/vegetation/trees/low_foliage.json, so the layout's clipping clean-up pass
## (scripts/world/vegetation/veg_layout.gd, _fix_clipping) can keep foliage and low branches out
## of sloped ground without loading the meshes (headless builds stay fast). Headless:
##
##   Godot --headless --path . -s tools/environment/vegetation/bake_low_foliage.gd
##
## Rerun after build_trees.py. Per variant "<species>_v<k>":
##   floor     32 azimuth sectors x 0.4 m radius bands of the LOD0 foliage (and branch) vertices
##             below 3 m (the vertex set of VegLayout.low_foliage(), the one
##             tools/environment/check_clipping.gd tests): per bin [x, f, z] with f = the lowest
##             max(y, 0) of the bin, pushed out to the bin's largest radius (conservative: on a
##             slope the outer end of a spray is the deepest). Parts the model itself puts below
##             its base (the edge hemlock's skirt boughs, a shrub's stems) count from the base.
##   pts       the same bins with the plain lowest y (the 2026-09-24 format, kept for reference).
##   base      [r, y]: the bark ring the plant stands on (VegLayout.stem_base()).
##   bark_min  the lowest point of the mesh.
## (2026-09-24 first version; 2026-09-25 floor / base added for the clipping clean-up pass.)

const Assets := preload("res://scripts/world/vegetation/veg_assets.gd")
const Layout := preload("res://scripts/world/vegetation/veg_layout.gd")
const OUT := "res://assets/environment/vegetation/trees/low_foliage.json"
const SECTORS := 32
const BAND := 0.4
const BANDS := 18


func _initialize() -> void:
	var out := {}
	for k in Assets.SPECIES.size():
		for v in 3:
			var m := Assets.tree_mesh(k, v, 0)
			if m == null:
				continue
			var low := Layout.low_foliage(k, v)
			var bins := {}
			for p in low:
				var r := Vector2(p.x, p.z).length()
				var sector := int(fposmod(atan2(p.z, p.x) / TAU, 1.0) * SECTORS) % SECTORS
				var band := mini(int(r / BAND), BANDS - 1)
				var key := sector * 64 + band
				var f := maxf(p.y, 0.0)
				if not bins.has(key):
					bins[key] = [p, f, p, r]            # lowest y, its floor, lowest-floor vertex, max r
				else:
					var b: Array = bins[key]
					if p.y < (b[0] as Vector3).y:
						b[0] = p
					if f < float(b[1]):
						b[1] = f
						b[2] = p
					b[3] = maxf(float(b[3]), r)
			var pts := []
			var floor_pts := []
			var keys := bins.keys()
			keys.sort()
			for key: int in keys:
				var b: Array = bins[key]
				for which in 2:
					var q: Vector3 = b[0] if which == 0 else b[2]
					var rl := Vector2(q.x, q.z).length()
					var k2: float = float(b[3]) / rl if rl > 1e-4 else 1.0
					var y: float = q.y if which == 0 else float(b[1])
					var e := [snappedf(q.x * k2, 0.001), snappedf(y, 0.001), snappedf(q.z * k2, 0.001)]
					(pts if which == 0 else floor_pts).append(e)
			var base := Layout.stem_base(k, v)
			var name := "%s_v%d" % [Assets.SPECIES[k], v]
			out[name] = {"floor": floor_pts, "pts": pts, "base": [snappedf(base.x, 0.001), snappedf(base.y, 0.001)],
					"bark_min": snappedf(m.get_aabb().position.y, 0.001)}
			print("LOWFOL %s low=%d bins=%d base r=%.2f y=%.2f bark_min=%.2f" % [name, low.size(), floor_pts.size(),
					base.x, base.y, m.get_aabb().position.y])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("LOW FOLIAGE BAKED ", OUT)
	quit()
