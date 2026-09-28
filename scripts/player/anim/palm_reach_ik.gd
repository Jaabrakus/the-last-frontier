class_name PalmReachIK
extends ReachIK
## ReachIK solved for the palm (l_palm / r_palm) instead of the hand's prop bone: with the hands free the prop bones
## are animated well away from the hands (they follow where a held prop would be), so a reach for them misses the
## hand. For what a bare hand holds: the rope of a carcass dragged on foot (FootDrag, the left hand), the handles of
## a wheelbarrow (Wheelbarrow, both hands).

var _palm_idx := {}


func _bones(sk: Skeleton3D, side: String) -> Array:
	if not _palm_idx.has(side):
		var out: Array = []
		for bn: String in ["shoulder", "elbow", "wrist", "palm"]:
			var b := sk.find_bone("%s_%s" % [side, bn])
			if b < 0:
				_palm_idx[side] = []
				return []
			out.append(b)
		_palm_idx[side] = out
	return _palm_idx[side]
