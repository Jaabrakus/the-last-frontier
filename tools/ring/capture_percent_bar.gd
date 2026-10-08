extends PercentBar
## Capture-only presentation: inherit the live clock/event drawing and all match
## signal/state updates, suppress just the two fighter plates. Normal HUD untouched.


func _draw_plate(_screen: int, _k: int, _info: Dictionary, _team: int, _scale: float) -> void:
	pass
