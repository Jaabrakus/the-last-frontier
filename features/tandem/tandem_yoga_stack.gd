class_name TandemYogaStack
extends Node
## One partner slot above a player who is holding Happy Baby.
## The game can call try_join(), request_dip(), and leave() for its second player.
## This node owns the partner's placement while the slot is occupied; the two
## pose controllers continue to own their respective AnimationTrees.

signal availability_changed(available: bool)
signal partner_joined
signal partner_left

@export var base_actor: TandemPoseMannequin
@export var base_hold: TandemYogaHoldController
@export var partner_actor: TandemPoseMannequin
@export var partner_plank: TandemPlankDipController
## Both clips share the mat's ground plane: the plank's hands and feet stay planted
## while its torso stacks closely above Happy Baby. Do not add a vertical lift.
@export var plank_offset := Vector3.ZERO
## The authored plank and Happy Baby clips face opposite directions.
@export var plank_yaw := PI

var occupied := false
var _return_transform := Transform3D.IDENTITY


func _ready() -> void:
	assert(base_actor != partner_actor, "The partner must be a different player.")
	process_priority = 50 # after pose evaluation, before mannequin drawing (100)
	partner_plank.stop_session()
	partner_actor.hide()
	base_hold.state_changed.connect(_on_base_state_changed)


func _process(_delta: float) -> void:
	if occupied:
		_align_partner()


func can_join() -> bool:
	return not occupied and base_hold.state == TandemYogaHoldController.State.HOLD


## A second player must explicitly choose to join after the base pose is ready.
func try_join() -> bool:
	if not can_join():
		return false
	_return_transform = partner_actor.global_transform
	occupied = true
	_align_partner()
	partner_plank.start_session()
	partner_actor.show()
	availability_changed.emit(false)
	partner_joined.emit()
	return true


func request_dip() -> bool:
	if not occupied or base_hold.state != TandemYogaHoldController.State.HOLD:
		return false
	return partner_plank.request_dip()


## Also called immediately when the base exits or collapses.
func leave() -> void:
	if not occupied:
		return
	occupied = false
	partner_plank.stop_session()
	partner_actor.hide()
	partner_actor.global_transform = _return_transform
	partner_left.emit()
	availability_changed.emit(can_join())


func _on_base_state_changed(state: TandemYogaHoldController.State) -> void:
	if state != TandemYogaHoldController.State.HOLD and occupied:
		leave()
	else:
		availability_changed.emit(can_join())


func _align_partner() -> void:
	partner_actor.global_transform = base_actor.global_transform * Transform3D(Basis(Vector3.UP, plank_yaw), plank_offset)
