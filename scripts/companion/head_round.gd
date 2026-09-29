class_name HeadRound
extends RefCounted
## The round-face gauge: a child's head pulled toward a sphere round the cranium's centre, on the child's own copy of the game's head
## (ChildProportion's bake; baby_body.json "round": strong at the jaw, chin and the back of the skull, light over the eyes, nose and
## mouth, the UVs, the blink and the face's landmarks kept). `amount` is the rounding 0..1 (negative: a little longer than the head's
## own, down to -0.4); ChildLook.roundness(look, stage) gives it for a child: the stage's (growth.json / baby.json form "round") and the
## look's own `child_round` (-1 less round .. 1 rounder). It pulls toward a sphere a little smaller than the head's own volume
## (baby_body.json round.size): a long face gets shorter and broader, the head never gets bigger from it.
##   HeadRound.apply(body, ChildLook.roundness(look, "toddler"))

## Rounds the head of `body` by `amount` (a child's body keeps its stage's form; an adult's is shaped with its own proportions).
static func apply(body: CharacterBodyMesh, amount: float) -> ChildProportion:
	var p := ChildProportion.of(body)
	if p == null:
		if absf(amount) < 0.001:
			return null
		return ChildProportion.shape(body, {}, amount)
	if is_equal_approx(p.round_k, amount):
		return p
	return ChildProportion.shape(body, p.form, amount)


## The rounding a body has now (0 when none).
static func amount_of(body: CharacterBodyMesh) -> float:
	var p := ChildProportion.of(body)
	return p.round_k if p != null else 0.0
