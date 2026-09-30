class_name WeaponState
## The state a weapon keeps when it is put down and picked up again (user 2026-09-25: rifles set in a bin
## or against a wall "for quick equip without reloading"): a firearm's charge and spare cartridges, a bow's
## quiver, a thrown weapon's count. capture() reads it off a player's weapon, apply() writes it back.


static func capture(w: Weapon) -> Dictionary:
	var s := {}
	if w is Firearm:
		var f := w as Firearm
		s.loaded = f.loaded
		s.reserve = f.reserve
	if w is Bow:
		s.quiver = (w as Bow).quiver + (w as Bow).held
	if w is Throwable:
		s.count = (w as Throwable).count
	if w is ThrowableSpear:
		s.heads = (w as ThrowableSpear).heads.duplicate(true)
	return s


static func apply(w: Weapon, s: Dictionary) -> void:
	if w is Firearm:
		var f := w as Firearm
		f.loaded = bool(s.get("loaded", f.loaded))
		f.reserve = int(s.get("reserve", f.reserve))
		f.state = Firearm.State.READY if f.loaded else Firearm.State.EMPTY
	if w is Bow:
		var b := w as Bow
		b.held = 0
		b.quiver = int(s.get("quiver", b.quiver))
	if w is Throwable:
		(w as Throwable).count = int(s.get("count", (w as Throwable).count))
	if w is ThrowableSpear:
		(w as ThrowableSpear).set_heads(s.get("heads", []))


## A short description for prompts: "loaded", "empty", "18 arrows", "2 spears".
static func describe(kind: String, s: Dictionary) -> String:
	if s.has("loaded"):
		return "loaded" if bool(s.loaded) else "empty"
	if s.has("quiver"):
		return "%d arrows" % int(s.quiver)
	if s.has("count"):
		return "%d" % int(s.count)
	return ""
