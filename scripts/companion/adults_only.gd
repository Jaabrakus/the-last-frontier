class_name AdultsOnly
extends RefCounted
## Intimacy is between adults only (user 2026-09-29: "turn off intimacy options for children, toddler and teen ... have it be
## adults only"). A worker is a minor while it is a teen recruit (Recruit: age "teen") or a child of the family who has not
## reached the adult stage (Growth: its family record's worker_id). The intimacy gauge, yoga together and the pregnancy
## roll all ask here; children, toddlers and teens are never offered any of it, with an adult or with each other.


## Whether worker `w` of `house` is an adult.
static func is_adult(house: Node, w: Object) -> bool:
	if w == null:
		return false
	var rec: Variant = w.get("recruit")
	if rec is Dictionary and String((rec as Dictionary).get("age", "adult")) != "adult":
		return false
	var fam: Variant = house.get("family") if house != null else null
	if fam is Array:
		var wid := int(w.get("worker_id")) if w.get("worker_id") != null else -1
		for c: Variant in fam:
			if c is Dictionary and int((c as Dictionary).get("worker_id", -1)) == wid and wid >= 0:
				return Growth.stage_of(c) == "adult"
	return true
