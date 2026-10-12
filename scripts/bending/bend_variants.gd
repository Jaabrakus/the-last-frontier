class_name BendVariants
extends RefCounted
## A move's own variants, picked with the mouse wheel while it is readied (Hotbar.wheel; the owner, 2026-10-12: earth's Column
## "toggle ... where it can fire diagonally or horazantally on walls ... the column ramp left to shoot them right", picked:
## "Scroll to pick"). The pick is the body's (VARIANT_META: move/mode -> its variant), kept until changed; the cast reads it
## (BendEffects.column). A bot's is never set: the first variant.
##   earth_shove/column   up (the knock-up, as before), right / left (it rises leaning and throws them that way, the caster's
##                        right and left at the cast), wall (it punches out of the nearest Earth Wall's face by the mark, any
##                        side's; no wall near: up)

const META := &"bend_variants"
const SETS := {"earth_shove/column": ["up", "right", "left", "wall"]}
## The words the strip shows after the move's name.
const WORDS := {"up": "up", "right": "throw right", "left": "throw left", "wall": "from a wall"}


static func list(m: String, md: String) -> Array:
	return SETS.get("%s/%s" % [m, md], [])


## `body`'s variant of m/md ("" when it has none).
static func of(body: Node, m: String, md: String) -> String:
	var l := list(m, md)
	if l.is_empty():
		return ""
	if body == null or not is_instance_valid(body) or not body.has_meta(META):
		return String(l[0])
	var v := String((body.get_meta(META) as Dictionary).get("%s/%s" % [m, md], l[0]))
	return v if v in l else String(l[0])


static func set_to(body: Node, m: String, md: String, v: String) -> void:
	if body == null or not is_instance_valid(body) or not v in list(m, md):
		return
	var d: Dictionary = (body.get_meta(META) as Dictionary).duplicate() if body.has_meta(META) else {}
	d["%s/%s" % [m, md]] = v
	body.set_meta(META, d)


## The next (`dir` 1) or the one before (-1); its name, "" when m/md has none.
static func cycle(body: Node, m: String, md: String, dir: int) -> String:
	var l := list(m, md)
	if l.is_empty():
		return ""
	var i := l.find(of(body, m, md))
	var v := String(l[posmod(i + (1 if dir >= 0 else -1), l.size())])
	set_to(body, m, md, v)
	return v
