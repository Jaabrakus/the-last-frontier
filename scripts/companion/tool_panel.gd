class_name ToolPanel
extends RefCounted
## The Tasks tab's tools (TOOLS: HouseholdScreen._build_tasks): what the household owns that its workers borrow
## (scripts/companion/tool_pool.gd), how many are in the chests and racks, who has the rest out, the worn and the broken, and
## the jobs waiting for a tool.


static func build(s: HouseholdScreen) -> void:
	var p: ToolPool = s.house.stock.pool if s.house != null and s.house.stock != null else null
	if p == null:
		return
	s._content.add_child(s._label("Tools and arms", 17, HouseholdScreen.HEAD))
	var c := p.counts()
	if c.is_empty():
		s._wrapped("The household owns no tools yet. Put hatchets, knives and traps in a storage chest, and guns in a rack, for the hands to borrow.", 15, HouseholdScreen.DIM)
	else:
		var parts := []
		var keys := []
		for k: String in ToolPool.kinds() + ToolPool.consumable_kinds():   # the tools and arms first, then what is used up
			if c.has(k):
				keys.append(k)
		for k: String in keys:
			var e: Dictionary = c[k]
			var t := "%s %d" % [String(e.name), int(e.owned)]
			var bits := []
			if int(e.out) > 0:
				var who := []
				for nm: String in (e.by as Dictionary):
					who.append("%s %d" % [nm, int(e.by[nm])] if int(e.by[nm]) > 1 else nm)
				bits.append("out with " + ", ".join(who))
			if int(e.worn) > 0:
				bits.append("%d worn" % int(e.worn))
			if not bits.is_empty():
				t += " (" + "; ".join(bits) + ")"
			parts.append(t)
		s._wrapped(", ".join(parts) + ".", 15, HouseholdScreen.TEXT)
	if not p.broken.is_empty():
		var br := []
		for e: Dictionary in p.broken.slice(maxi(p.broken.size() - 6, 0)):
			br.append("%s (%s, day %d)" % [String(e.get("name", "")).to_lower(), String(e.get("by", "")), int(e.get("day", 0)) + 1])
		s._wrapped("Broken: %s." % ", ".join(br), 14, Color(0.9, 0.6, 0.45))
	var waits := []
	for id: int in p.blocked:
		var w := p.worker(id)
		for jid: String in (p.blocked[id] as Dictionary):
			if w != null and bool(w.enabled.get(jid, false)):
				waits.append("%s: %s (%s)" % [w.name, JobBook.name_of(jid).to_lower(), String(p.blocked[id][jid])])
	if not waits.is_empty():
		s._wrapped("Waiting for a tool: %s." % ", ".join(waits), 14, Color(0.9, 0.6, 0.45))
