class_name TravPoseCapture
extends SkeletonModifier3D
## Test helper (fix round 3, 2026-09-25): the skeleton-space pose at this point of the modifier stack.
## TravTestUtil puts one before TravInertializer (the animation as played, "raw") and one before
## TraversalIK ("pre"), so the strict test can tell the animation's own motion from what the
## inertializer and the IK add (review: IK and inertializer pops inside moves were invisible to a
## test that only saw the final pose).

var last: Array = []             ## bone globals (skeleton space) of the latest update
var frame := -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	last = TravMeshContacts.live_globals(sk)
	frame = Engine.get_process_frames()
