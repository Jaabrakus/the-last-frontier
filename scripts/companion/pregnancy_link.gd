class_name PregnancyLink
extends Node
## The node side of Pregnancy (scripts/companion/pregnancy.gd): a child of Household. After a finished yoga session
## (TandemLink hands it "session_done" from YogaFlow) the woman of the pair rolls to conceive; each frame it lets time pass
## for both records (the wife's, on her SpouseCore, and the player's, in the survival state's players[player_id]) and tells
## what changes: she tells the player (a toast), or the game does when the player is the mother; at term a child record is
## added to Household.family. Household.pregnancy is this node.
##   Household.pregnancy.on_session()     the roll (called by TandemLink)
##   Household.pregnancy.talk_line()      a line for the Talk tab ("" none)
##   Household.pregnancy.status_lines()   [[label, text]] for the Stats tab

var house: Household
## The last roll's result (for debugging and the console).
var last := {}
var _t := 0.0


func _process(dt: float) -> void:
	if house == null or house.sc == null or house.bridge == null or house.bridge.core == null:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.5
	tick()


## Lets time pass for both records and acts on the events (also callable headless).
func tick() -> void:
	var sc := house.sc
	var main := house.bridge.core
	_handle(Pregnancy.KIND_SPOUSE, Pregnancy.advance(sc.pregnancy, sc.core, sc.core.state.minutes, _parents(Pregnancy.KIND_SPOUSE)))
	_handle(Pregnancy.KIND_PLAYER, Pregnancy.advance(Pregnancy.player_record(main), main, main.state.minutes, _parents(Pregnancy.KIND_PLAYER)))


func _player_is_male() -> bool:
	return house.sc.is_male() == false   # she is the opposite sex: a woman wife means a man


## The woman of the pair: KIND_SPOUSE (the wife) or KIND_PLAYER.
func woman() -> String:
	return Pregnancy.woman_kind(_player_is_male())


func _parents(kind: String) -> Dictionary:
	var sc := house.sc
	return {"mother": sc.name if kind == Pregnancy.KIND_SPOUSE else "player",
			"father": "player" if kind == Pregnancy.KIND_SPOUSE else sc.name, "kind": kind,
			"next_id": house.family.size() + 1}


## After a finished yoga session: her roll.
func on_session() -> Dictionary:
	if house == null or house.sc == null or house.bridge == null:
		return {}
	var main := house.bridge.core
	var on := Pregnancy.enabled(main)
	if woman() == Pregnancy.KIND_SPOUSE:
		var sc := house.sc
		last = Pregnancy.attempt(sc.pregnancy, sc.core, sc.core.state.minutes, on)
	else:
		last = Pregnancy.attempt(Pregnancy.player_record(main), main, main.state.minutes, on)
	return last


func _handle(kind: String, events: Array) -> void:
	for e: Dictionary in events:
		match String(e.do):
			"notice":
				_say(kind, ["pregnancy", "notice"])
			"stage":
				_say(kind, ["pregnancy", "stage", String(e.stage)])
			"birth":
				var child: Dictionary = e.child
				house.family.append(child)
				_say(kind, ["pregnancy", "birth_girl" if float(child.sex) < 0.5 else "birth_boy"], String(child.name))


## The wife tells the player; when the player is the mother the game does (the HUD toast TandemLink uses).
func _say(kind: String, path: Array, child_name := "") -> void:
	var line := house.pick(path if kind == Pregnancy.KIND_SPOUSE else ["pregnancy", "player"] + path.slice(1))
	if line == "":
		return
	line = line.replace("{name}", child_name)
	toast(("%s: \"%s\"" % [house.sc.name, line]) if kind == Pregnancy.KIND_SPOUSE else line)


func toast(text: String) -> void:
	if is_instance_valid(house.player) and house.player.hud != null:
		house.player.hud.toast(text)
	else:
		print(text)


## A line for the Talk tab about her state ("" when nothing).
func talk_line() -> String:
	var sc := house.sc
	var now := sc.core.state.minutes
	if Pregnancy.is_pregnant(sc.pregnancy):
		return house.pick(["pregnancy", "talk", Pregnancy.stage_of(sc.pregnancy, now)]) if bool(sc.pregnancy.noticed) else ""
	if Pregnancy.resting(sc.pregnancy, now):
		return house.pick(["pregnancy", "talk", "rest"])
	return ""


## Stats-tab rows [label, text]: hers, and the player's own when the player is expecting.
func status_lines() -> Array:
	var out := []
	var l := Pregnancy.status_line(house.sc.pregnancy, house.sc.core.state.minutes)
	if l != "":
		out.append([house.sc.name, l])
	var main := house.bridge.core
	var pl := Pregnancy.status_line(Pregnancy.player_record(main), main.state.minutes)
	if pl != "":
		out.append(["You", pl])
	return out
