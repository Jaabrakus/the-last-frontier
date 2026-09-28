class_name QuickOffhand
extends RefCounted
## Quick throwables with the long gun kept in the LEFT hand (push n01c; user 2026-09-26: "allows user to have the
## right hand to throwables and easily switch back to rifle").
##
## Switching from a long gun (musket, over-under) to a one-hand throwable (tomahawk, spear) does not sling the gun:
## the left hand takes it in the middle (HandHolds.offhand: GunMiddleCarryIK's handoff, HANDOFF_S), then the right
## hand reaches for the throwable at its carry point and draws it (the graph's grab and draw clips, as a normal
## switch plays them after its holster). The throwable aims and throws with the
## normal controls; the left arm keeps the gun low and steady (HandHolds' gun arm over the throw clips' left arm).
## Switching back (the long gun's key, or the throwable's key again, or the last one thrown) is quick: the right hand
## puts the throwable away (its holster clip over STOW_S; nothing when the hand is empty) and takes the wrist of the
## stock, the gun returns to the right hand and the left hand to the fore-end (the handoff back); the gun takes no
## draw clip (Weapon.equip_quick) and may aim once the right hand has the stock (Weapon.aim_hold).
## Not quick (the normal switch): the atlatl (a two-handed dart and board), the bow and the pistol, a switch while the
## lit torch holds the right hand, riding, a switch already running.
## The gun in the left hand counts as in the hand, not on the back (FrontierPlayer.offhand_key: SlingRig keeps it
## HELD). H, mounting, a vault or climb and death put it on the back at once (drop()).

## The long guns that can wait in the left hand and the throwables that may be drawn beside them.
const LONG_GUNS := ["musket", "over_under"]
const QUICK := ["tomahawk", "spear"]
## Seconds for the throwable's put-away on the way back (its holster clip, sped up).
const STOW_S := 0.26
## Seconds the gun takes no input after it is back in the right hand (the handoff back gates the aim itself).
const READY_S := 0.12
## Seconds the draw waits at most for the left hand to have the gun.
const WAIT_MAX_S := 0.6

var player: FrontierPlayer
## The throwable waiting to be drawn once the left hand has the gun ("" none), and how long it has waited.
var _draw_key := ""
var _wait := 0.0
## Seconds since the way back started (-1: none; tests read it).
var back_t := -1.0


func _init(p: FrontierPlayer) -> void:
	player = p


## The long gun is in the left hand (or going there).
func active() -> bool:
	return player.offhand_key != ""


## The weapon in the left hand (null none).
func gun() -> Weapon:
	return player.weapons.get(player.offhand_key) as Weapon if active() else null


func _holds() -> HandHolds:
	return player.anim.holds if player.anim else null


## switch_weapon(key) asks first: true when this took the switch (the quick way out or back).
func intercept(key: String) -> bool:
	var p := player
	if active():
		if p.is_switching() and back_t >= 0.0:
			return true    # already on the way back
		if key == p.offhand_key or (key == p.weapon_key and _draw_key == ""):
			back()
			return true
		if _draw_key != "":
			if key in QUICK and p.is_usable(key):
				_draw_key = key    # another throwable before the draw started
				return true
			drop()
			return false
		if key in QUICK and p.is_usable(key):
			return false    # throwable to throwable: the normal switch (or its retarget), the gun stays in the left hand
		drop()             # the bow, the pistol, the atlatl...: the gun goes on the back, the normal switch
		return false
	if not _can_start(key):
		return false
	var old := p.weapon
	var old_key := p.weapon_key
	old.unequip()
	if old.model:
		old.model.visible = true    # (unequip hides it: it stays in the hand)
	p.offhand_key = old_key
	var h := _holds()
	if h:
		h.offhand = old
	_draw_key = key
	_wait = 0.0
	return true


func _can_start(key: String) -> bool:
	var p := player
	if not p.quick_throwables or key not in QUICK or not p.is_usable(key) or p.weapon == null or p.weapon_key not in LONG_GUNS:
		return false
	if p.hands_free or p.is_switching() or p.riding != null or p.is_dead or not p.weapon.active:
		return false
	if p.weapon.is_equipping() or p.weapon.aim > 0.05:
		return false
	var h := _holds()
	if h == null:
		return false
	# the lit torch holds the right hand: the normal switch (the torch goes to the left hand, the gun on the back)
	if h.torch_held or h.torch_pending or h.toss_t >= 0.0:
		return false
	return true


## The way back to the long gun: the throwable put away (when one is in the hand), then the gun into the right hand.
func back() -> void:
	var p := player
	if not active():
		return
	if _draw_key != "":
		# the throwable was not drawn yet: the gun goes straight back to the right hand
		_draw_key = ""
		_finish_back()
		return
	if p.is_switching():
		# a switch beside the gun (the quick draw's grab, or throwable to throwable): given up, its models away
		var sw_old: Weapon = p._sw.get("old") as Weapon
		p._sw = {}
		if sw_old != null and sw_old != gun() and sw_old.model:
			sw_old.model.visible = false
	var t := p.weapon
	var tk := p.weapon_key
	var shows := t != null and t.active and t is Throwable and (t as Throwable).count > 0
	if t:
		t.unequip()
	var g := gun()
	p.weapon_key = p.offhand_key
	p.weapon = g
	back_t = 0.0
	var go := p.anim.graph_key(tk)
	if shows and t.model and p.anim.play_holster(go, STOW_S):
		t.model.visible = (t as Throwable).holster_shows_model()
		p._sw = {"t_finish": STOW_S, "t_grab": STOW_S, "t_draw": STOW_S, "finish": 0.0, "grab": 0.0, "lead": 0.0,
				"fast": true, "quick": true, "old": t, "old_key": go, "key": p.anim.graph_key(p.weapon_key), "t": 0.0,
				"holstered": false, "grabbing": false}
		return
	if t and t.model:
		t.model.visible = false
	_finish_back()


## The end of the way back (FrontierPlayer._tick_switch at the quick switch's draw time, or at once): the gun in the
## right hand, usable without a draw.
func _finish_back() -> void:
	var p := player
	var g := gun()
	var key := p.offhand_key
	p.offhand_key = ""
	var h := _holds()
	if h:
		h.offhand = null
		h.hurry_t = 0.6    # (the handoff back at its quick pace: the aim ready within ~0.5 s)
	back_t = -1.0
	if g == null:
		return
	p.weapon_key = key
	p.weapon = g
	p.anim.set_weapon(p._anim_key(key))
	g.equip_quick(READY_S)


## The gun onto the back at once (H, mounting, traversal, death, a switch to a weapon that needs both hands).
func drop() -> void:
	var p := player
	if not active():
		return
	var g := gun()
	p.offhand_key = ""
	_draw_key = ""
	back_t = -1.0
	var h := _holds()
	if h:
		h.drop_offhand()
	if g and g.model and g != p.weapon:
		g.model.visible = false


## Every physics tick (FrontierPlayer._physics_process): the draw starts once the left hand has the gun; leaving the
## ground for the saddle, a traversal move or death puts the gun on the back.
func tick(delta: float) -> void:
	var p := player
	if not active():
		return
	if p.is_dead or p.riding != null or (p.traversal != null and p.traversal.showing):
		drop()
		return
	if back_t >= 0.0:
		back_t += delta
	if _draw_key == "":
		return
	_wait += delta
	var h := _holds()
	if h != null and not h.mid_ik.in_left() and _wait < WAIT_MAX_S:
		return
	var key := _draw_key
	_draw_key = ""
	var old := gun()
	var nw: Weapon = p.weapons[key]
	p.weapon_key = key
	p.weapon = nw
	p.anim.set_weapon(p._anim_key(key))
	# the right hand reaches for the throwable at its carry point first (the graph's grab clip, as a normal switch's
	# after its holster), then draws it (FrontierPlayer._tick_switch at t_draw)
	var st := "crouch" if p.is_crouching else "stand"
	var go := p.anim.graph_key(p.offhand_key)
	var gn := p.anim.graph_key(key)
	var s := FrontierPlayer.switch_stages(p.anim.data, go, gn, st, old.equip_time if old else 0.0, nw.equip_time)
	var grab := float(s.grab)
	if grab > 0.0 and p.anim.holster_enabled() and p.anim.play_switch_stage(gn, "grab", grab):
		var lead := float(s.lead)
		p._sw = {"t_finish": 0.0, "t_grab": 0.0, "t_draw": maxf(grab - lead, 0.0), "finish": 0.0, "grab": grab, "lead": lead,
				"fast": false, "old": old, "old_key": go, "key": gn, "t": 0.0, "holstered": true, "grabbing": true}
		return
	p._equip_drawn()


## The throwable in the hand ran out (FrontierPlayer._switch_when_empty): back to the gun.
func on_empty() -> bool:
	if not active():
		return false
	back()
	return true
