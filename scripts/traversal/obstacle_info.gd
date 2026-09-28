class_name TravObstacleInfo
extends RefCounted
## One probe result (design 6.3). Positions are world space. `reason` is set whenever the
## result is `none` (the codes of Appendix A in data/traversal/traversal_moves.json).

var kind := "none"                ## none / wall / overhead / edge / gap / ledge / beam / ladder / crawl
var reason := ""
var face_class := ""              ## walkable / steep / wall
var collider: Object = null
var rid := RID()
var shape_idx := -1
var shape_node: Node = null
var descriptor := {}              ## ShapeRegistry descriptor / authored `trav` meta
var tags: Array = []

var support_y := 0.0              ## ground under the takeoff point
var hit_point := Vector3.ZERO     ## sweep contact P
var normal := Vector3.ZERO        ## outward horizontal face normal N
var face_point := Vector3.ZERO    ## point on the face at the top edge (lip), on the approach line
var top_point := Vector3.ZERO     ## top T
var h := 0.0                      ## top above the support
var base_y := 0.0                 ## ground at the foot of the face (walls; = support_y elsewhere)
var h_face := -1.0                ## top above base_y: the obstacle's own height (-1 = use h)
var depth := INF                  ## D (INF = deep)
var landing: Variant = null       ## L: landing height relative to base_y (OVER), or null
var landing_y: Variant = null
var landing_point := Vector3.ZERO
var clearance := "none"           ## stand / crouch / none (on the top)
var clearance_h := 0.0
var ceiling: Variant = null       ## approach-side ceiling height (world) or null
var irregular := false
var width := INF                  ## top width across the heading (beam test)
var support_area := {}            ## {stand, knee, hands}
var distance := 0.0               ## horizontal distance from the character to the face
var drop := 0.0                   ## edges: drop height; gaps: landing below
var gap_distance := 0.0
var ledge_id := -1                ## LedgeGraph entry (overhead / hang)
var ledge_point := Vector3.ZERO
var ledge_tangent := Vector3.ZERO
var free_hang := false
var surface := ""
var queries := 0


func is_none() -> bool:
	return kind == "none"


static func none(why: String) -> TravObstacleInfo:
	var o := TravObstacleInfo.new()
	o.kind = "none"
	o.reason = why
	return o


func shape_key() -> String:
	return "%s:%d" % [str(rid.get_id()) if rid.is_valid() else "0", shape_idx]


func to_dict() -> Dictionary:
	return {
		"kind": kind, "reason": reason, "face_class": face_class, "h": h, "h_face": h_face, "base_y": base_y, "depth": depth,
		"landing": landing, "clearance": clearance, "clearance_h": clearance_h, "width": width,
		"distance": distance, "normal": [normal.x, normal.y, normal.z],
		"face_point": [face_point.x, face_point.y, face_point.z], "top": [top_point.x, top_point.y, top_point.z],
		"support_y": support_y, "ledge_id": ledge_id, "free_hang": free_hang, "tags": tags,
		"shape": shape_node.name if shape_node else "", "descriptor": descriptor, "drop": drop,
		"gap": gap_distance, "queries": queries,
	}
