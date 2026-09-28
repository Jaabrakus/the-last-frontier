class_name OverUnderBarrels
extends RefCounted
## Bookkeeping of the over-under's two barrels: pure logic, no nodes, unit-testable.
##
## The physical barrels are 0 (A, on top when the gun is built) and 1 (B). `top` is the barrel
## under the lock. stage[i] is barrel i's next loading step (weapons_balance_design.md 2.4):
##
##   0 Charging powder   1 Patch and ball   2 Ramming   3 Returning rod    top or bottom, in place
##   4 Priming                                                            top only
##   5 (READY)           charged and primed
##
## Both muzzles are always open, so an empty barrel is charged where it lies (steps 0-3). Its
## pan faces down and to the left while it is underneath, so it is primed only on top (step 4).
## A primed barrel keeps its priming under the closed frizzen when it is turned under.
##
## A load (ball, patch, powder charge) is taken from the reserve when a barrel's step 0 begins
## (load_in); an interrupted barrel never needs a second one. Priming powder comes from the horn
## and is not counted, so a charged barrel can be primed with no loads left.

const READY := 5
const PRIME_STEP := 4
## Glyphs for the HUD (ammo_text): ready, charged but not primed, partly charged, empty.
const G_READY := "●"
const G_CHARGED := "◑"
const G_PARTLY := "◐"
const G_EMPTY := "○"

var stage := PackedInt32Array([READY, READY])
var load_in: Array[bool] = [true, true]
var top := 0


func bottom() -> int:
	return 1 - top


func is_ready(i: int) -> bool:
	return stage[i] >= READY


## Powder and ball down; priming may still be due.
func is_charged(i: int) -> bool:
	return stage[i] >= PRIME_STEP


func is_partly(i: int) -> bool:
	return (stage[i] > 0 and stage[i] < PRIME_STEP) or (stage[i] == 0 and load_in[i])


## [top ready, bottom ready] (HUD and tests).
func barrels_loaded() -> Array:
	return [is_ready(top), is_ready(bottom())]


## The barrel on top fires. Returns the physical barrel that fired (-1 when it was not ready).
func fire() -> int:
	if not is_ready(top):
		return -1
	stage[top] = 0
	load_in[top] = false
	return top


## The latch of a half turn: the other barrel comes up under the lock.
func flip() -> void:
	top = 1 - top


func needs_load(i: int) -> bool:
	return stage[i] == 0 and not load_in[i]


## True when barrel i has a step it can do where it lies with `reserve` loads left: not ready,
## a load available if its step 0 has not begun, and priming only on top.
func can_work(i: int, reserve: int) -> bool:
	if is_ready(i):
		return false
	if needs_load(i) and reserve <= 0:
		return false
	return i == top or not is_charged(i)


## True when barrel i may do `step` now (its own next step; priming refused underneath).
func can_step(i: int, step: int) -> bool:
	return step == stage[i] and step < READY and (step != PRIME_STEP or i == top)


## Begins barrel i's current step. Returns true when a load must be taken from the reserve now
## (its step 0 begins for the first time since it was fired).
func begin_step(i: int) -> bool:
	if stage[i] == 0 and not load_in[i]:
		load_in[i] = true
		return true
	return false


func finish_step(i: int) -> void:
	stage[i] = mini(stage[i] + 1, READY)
	load_in[i] = true


## The next piece of reload work (the R chain), with `reserve` loads left:
##   {"do": "step", "barrel": i, "step": s}   the top barrel from its own step (priming last, on
##                                            top); else the bottom barrel's steps 0-3 in place
##   {"do": "turn"}                           the bottom is charged but not primed: turn over,
##                                            then prime it on top
##   {"do": "done"}                           nothing left to charge or prime
func next_work(reserve: int) -> Dictionary:
	var t := top
	var b := bottom()
	if can_work(t, reserve):
		return {"do": "step", "barrel": t, "step": stage[t]}
	if not is_charged(b) and can_work(b, reserve):
		return {"do": "step", "barrel": b, "step": stage[b]}
	if is_charged(b) and not is_ready(b):
		return {"do": "turn"}
	return {"do": "done"}


## Seconds of loading left for barrel i in its current position (steps 0-4 on top, 0-3 below).
func work_seconds(i: int, steps: Array) -> float:
	var last := PRIME_STEP if i == top else PRIME_STEP - 1
	var s := 0.0
	for k in range(stage[i], mini(last, steps.size() - 1) + 1):
		s += float(steps[k][1])
	return s


func glyph(i: int) -> String:
	if is_ready(i):
		return G_READY
	if is_charged(i):
		return G_CHARGED
	if is_partly(i):
		return G_PARTLY
	return G_EMPTY


## "▲● ▼○": the top barrel, then the bottom one.
func glyphs() -> String:
	return "▲%s ▼%s" % [glyph(top), glyph(bottom())]


func snapshot() -> Dictionary:
	return {"top": top, "stage": [stage[0], stage[1]], "load_in": load_in.duplicate(),
			"loaded": barrels_loaded()}


func restore(d: Dictionary) -> void:
	top = int(d.get("top", 0))
	var s: Array = d.get("stage", [READY, READY])
	stage = PackedInt32Array([int(s[0]), int(s[1])])
	var l: Array = d.get("load_in", [true, true])
	load_in = [bool(l[0]), bool(l[1])]
