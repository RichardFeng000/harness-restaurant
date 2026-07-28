extends Sprite2D

@export var animation_duration := 0.38
@export var open_width_ratio := 0.22
@export var hinge_shift := Vector2(-28.0, -3.0)

var is_open := false
var is_animating := false
var _closed_position: Vector2
var _closed_rotation: float
var _closed_scale: Vector2
var _active_tween: Tween


func _ready() -> void:
	_closed_position = position
	_closed_rotation = rotation
	_closed_scale = scale
	$InteractionArea.input_event.connect(_on_input_event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		toggle()


func toggle() -> void:
	if is_animating:
		return

	is_open = not is_open
	is_animating = true

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	var target_position := _closed_position
	var target_rotation := _closed_rotation
	var target_scale := _closed_scale
	var target_skew := 0.0

	if is_open:
		target_position += hinge_shift
		target_rotation -= 0.045
		target_scale.x *= open_width_ratio
		target_skew = -0.08

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(self, "position", target_position, animation_duration)
	_active_tween.tween_property(self, "rotation", target_rotation, animation_duration)
	_active_tween.tween_property(self, "scale", target_scale, animation_duration)
	_active_tween.tween_property(self, "skew", target_skew, animation_duration)
	_active_tween.set_parallel(false)
	_active_tween.tween_callback(_finish_animation)


func _finish_animation() -> void:
	is_animating = false


func _on_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int
) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle()
		get_viewport().set_input_as_handled()
