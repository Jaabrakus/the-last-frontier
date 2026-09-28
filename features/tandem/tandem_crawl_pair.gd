class_name TandemCrawlPair
extends Node
## A crawling player invites one partner to kneel behind them.
## The caller routes each player's input through invite(), try_join(), and leave().
## Pose controllers own animations; this coordinator owns placement and visibility.

signal invitation_changed(pending: bool)
signal partner_joined
signal partner_left

@export var base_actor: TandemPoseMannequin
@export var base_hold: TandemCrawlHold
@export var partner_actor: TandemPoseMannequin
@export var partner_pose: TandemKneelPose
## Placement relative to the crawling actor, not the world axes.
@export var partner_offset := Vector3(0.0, 0.0, -0.30)
## Facing relative to the crawling actor, in radians.
@export var partner_yaw := 0.0
## Seconds after the kneeling flinch starts before the crawling player reacts.
@export_range(0.0, 1.0, 0.01) var crawl_response_delay := 0.15

var occupied := false
var invitation_pending := false
var _return_transform := Transform3D.IDENTITY
var _pending_responses: Array[float] = []


func _ready() -> void:
	assert(base_actor != partner_actor, "The partner must be a different player.")
	process_priority = 50 # after pose evaluation, before mannequin drawing (100)
	partner_pose.stop_session()
	partner_actor.hide()
	base_hold.released.connect(_on_base_released)
	partner_pose.session_stopped.connect(_on_partner_session_stopped)


func _process(delta: float) -> void:
	if occupied:
		_align_partner()
	for i in _pending_responses.size():
		_pending_responses[i] -= delta
	while not _pending_responses.is_empty() and _pending_responses[0] <= 0.0:
		_pending_responses.pop_front()
		if occupied and base_hold.holding:
			base_hold.flinch("partner")


func can_invite() -> bool:
	return base_hold.holding and not occupied and not invitation_pending


func invite() -> bool:
	if not can_invite():
		return false
	invitation_pending = true
	invitation_changed.emit(true)
	return true


func can_join() -> bool:
	return invitation_pending and base_hold.holding and not occupied


## Joining requires an invitation from a player who is still holding the crawl.
func try_join() -> bool:
	if not can_join() or not partner_pose.start_session():
		return false
	_return_transform = partner_actor.global_transform
	occupied = true
	invitation_pending = false
	_align_partner()
	partner_actor.show()
	invitation_changed.emit(false)
	partner_joined.emit()
	return true


## The crawling player reacts shortly after the kneeling flinch starts.
func request_partner_flinch() -> bool:
	if not occupied or not base_hold.holding or base_hold.stamina <= 0.0:
		return false
	if not partner_pose.flinch():
		return false
	base_hold.pause_recovery()
	_pending_responses.append(crawl_response_delay)
	_pending_responses.sort()
	return true


## Leaving also cancels an unanswered invitation and any delayed reaction.
func leave() -> void:
	var had_invitation := invitation_pending
	var had_partner := occupied
	_pending_responses.clear()
	invitation_pending = false
	occupied = false
	if had_partner:
		partner_pose.stop_session()
		partner_actor.hide()
		partner_actor.global_transform = _return_transform
	if had_invitation:
		invitation_changed.emit(false)
	if had_partner:
		partner_left.emit()


func _on_partner_session_stopped() -> void:
	_pending_responses.clear()


func _on_base_released(_reason: String) -> void:
	leave()


func _align_partner() -> void:
	var relative := Transform3D(Basis(Vector3.UP, partner_yaw), partner_offset)
	partner_actor.global_transform = base_actor.global_transform * relative
