class_name RecruitPanel
extends RefCounted
## The household screen's recruiting lines (RECRUIT; HouseholdScreen calls build on the Tasks tab): for a recruited worker
## her morale (the bar, its word and what it is made of), trust and terms, and "Send away" (a second press confirms: she
## leaves walking by the road, Household.remove_worker); for everyone, the places to sleep and who is camped by the fort.

static var _confirm := -1


static func build(s: HouseholdScreen) -> void:
	var link: RecruitLink = s.house.recruits
	if link == null:
		return
	var w := s._sc()
	if not w.recruit.is_empty():
		s._content.add_child(s._label("Morale", 17, HouseholdScreen.HEAD))
		var m := float(w.recruit.get("morale", 0.7))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = m
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(240, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(s._label("%s, working at %d%% pace" % [Recruit.morale_word(m), roundi(w.work_mult * 100.0)], 15, HouseholdScreen.DIM))
		s._content.add_child(row)
		var t := Recruit.morale_target(w, link.housed())
		var p: Dictionary = t.parts
		s._wrapped("Fed %d%%, housed %s, rested %d%%, trust %.1f of 10. Terms: %s. %s" % [roundi(float(p.fed) * 100.0),
				"yes" if float(p.housed) >= 1.0 else "no (not enough places to sleep)", roundi(float(p.rested) * 100.0),
				float(w.recruit.get("trust", 0.0)), Recruit.share_name(int(w.recruit.get("share", 0))).to_lower(),
				("Low for %d days: she may leave." % int(w.recruit.low_days)) if int(w.recruit.get("low_days", 0)) > 0 else ""], 14, HouseholdScreen.DIM)
		var ways := Recruit.trait_names(w.recruit.get("traits", []))
		if not ways.is_empty():
			s._wrapped("Ways: %s." % ", ".join(ways), 14, HouseholdScreen.DIM)
		var r := s._row()
		var b := s._button("Send %s away" % w.name if _confirm != w.worker_id else "Yes, send %s away" % w.name, 0)
		b.pressed.connect(func() -> void:
			if _confirm != w.worker_id:
				_confirm = w.worker_id
			else:
				_confirm = -1
				s.house.remove_worker(w)
			s._refresh_title()
			s._show(s.tab))
		r.add_child(b)
	s._wrapped("Places to sleep near home: %d, %d taken." % [link.places(), link.occupants()], 14, HouseholdScreen.DIM)
	var about := []
	for c: Dictionary in Recruit.present(link.st):
		about.append("%s (%s)" % [String(c.name), String(Recruit.kind_row(String(c.kind)).get("name", c.kind))])
	if not about.is_empty():
		s._wrapped("Camped by the fort: %s. Go and talk to them." % ", ".join(about), 14, HouseholdScreen.DIM)
