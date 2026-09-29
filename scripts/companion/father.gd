class_name Father
extends RefCounted
## The NPC father's day (user 2026-09-28: "FATHER LOGIC ... roles provider/protector/teacher (data-driven schedule blocks: mornings
## teach when a child is old enough, days work, evenings home) ... takes a child along on his outside jobs, plays with and carries the
## baby when the mother is busy, reacts to danger by keeping the family together"). LOGIC ONLY: decide() is a pure function of what
## GrowthLink sees; the schedule is data/companion/growth.json "father". The father is the husband NPC when the player is a woman; when
## the player is the father these are the player's own commands (Take along, Teach: GrowthLink / the household screen).
##
##   Father.decide({hour, danger, children: [{id, stage, due, with}], baby: {present, holder}, mother_busy})
##     -> {block, role ("provider" | "teacher" | "protector"), act ("teach" | "work" | "home" | "rest" | "gather"), sc_role ("home" | "outside"),
##         teach (child id or ""), take [child ids that go with him], release [child ids that go back to the mother],
##         carry_baby (bool), keep_together (bool), text}

static func cfg() -> Dictionary:
	return Growth.cfg().get("father", {})


## The schedule block the hour falls in ({id, from, to, role}); a block may wrap midnight (from > to).
static func block(hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	for b: Dictionary in cfg().get("blocks", []):
		var f := float(b.get("from", 0.0))
		var t := float(b.get("to", 24.0))
		if (f <= t and h >= f and h < t) or (f > t and (h >= f or h < t)):
			return b
	return {"id": "home", "from": 0.0, "to": 24.0, "role": "protector"}


static func _old_enough(stage: String) -> bool:
	return Growth.stage_index(stage) >= Growth.stage_index(String(cfg().get("take_along_min_stage", "toddler")))


static func decide(ctx: Dictionary) -> Dictionary:
	var c := cfg()
	var b := block(float(ctx.get("hour", 12.0)))
	var kids: Array = ctx.get("children", [])
	var walking := []   # the children with a body (toddler on)
	var due := ""
	for k: Dictionary in kids:
		if Growth.stage_row(String(k.get("stage", ""))).get("body", false) and String(k.stage) != "adult":
			walking.append(k)
			if due == "" and bool(k.get("due", false)):
				due = String(k.id)
	var baby: Dictionary = ctx.get("baby", {})
	var out := {"block": String(b.id), "role": String(b.get("role", "protector")), "act": String(b.id), "sc_role": "home", "teach": "",
			"take": [], "release": [], "carry_baby": false, "keep_together": false, "text": ""}
	# the baby: he carries it when the mother is busy and has it in her arms
	if bool(baby.get("present", false)) and bool((c.get("baby", {}) as Dictionary).get("carry_when_mother_busy", true)) \
			and bool(ctx.get("mother_busy", false)) and String(baby.get("holder", "")) == "player":
		out.carry_baby = true
	# danger: everyone home and together, he stays with the family
	if bool(ctx.get("danger", false)):
		out.act = "gather"
		out.role = "protector"
		out.sc_role = "home"
		out.keep_together = true
		for k: Dictionary in walking:
			out.take.append(String(k.id))
		out.text = "Keeping the family together."
		return out
	match String(b.id):
		"teach":
			if due != "":
				out.act = "teach"
				out.role = "teacher"
				out.teach = due
				out.take.append(due)
				out.text = "Teaching a lesson."
			else:
				out.act = "work"
				out.role = "provider"
				out.sc_role = "outside"
				_take_along(out, walking, "work")
		"work":
			out.act = "work"
			out.role = "provider"
			out.sc_role = "outside"
			_take_along(out, walking, "work")
			out.text = "Out working."
		_:
			# home and rest: the protector keeps the house; the children go back to their mother
			out.sc_role = "home"
			out.act = String(b.id)
	# whoever was with him and is not taken now goes back to the mother
	for k: Dictionary in walking:
		if String(k.get("with", "mother")) == "father" and not (out.take as Array).has(String(k.id)):
			out.release.append(String(k.id))
	return out


static func _take_along(out: Dictionary, walking: Array, block_id: String) -> void:
	if not (Father.cfg().get("take_along_blocks", []) as Array).has(block_id):
		return
	for k: Dictionary in walking:
		if _old_enough(String(k.stage)) and String(k.get("mode", "follow")) != "stay":
			out.take.append(String(k.id))
