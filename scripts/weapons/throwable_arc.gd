class_name ThrowableArc
extends TrajectoryPreview
## The bow's dotted trajectory arc and landing ring (TrajectoryPreview), for thrown weapons that are
## not in the player's roster (ThrowableKit.install without register: tests, previews). Same dots,
## ring, range cues and stepping as TrajectoryPreview (gravity, then drag, then move, the same as
## ThrownProjectile), so a full wind-up ends on the aim dot and a weak one falls short.
##
## Registered thrown weapons (the game path, player.gd) are drawn by the player's own
## TrajectoryPreview, which takes trajectory_params() from any weapon: one arc (THROW). This
## subclass only restricts the source to thrown weapons; it uses TrajectoryPreview's public API
## (params_for, source, current_weapon) and none of its internals.


## Thrown weapons only: `source` when set (inherited), else the player's current weapon when it is
## a Throwable.
func params_for(w: Weapon) -> Dictionary:
	var t := w as Throwable
	return t.trajectory_params() if t else {}
