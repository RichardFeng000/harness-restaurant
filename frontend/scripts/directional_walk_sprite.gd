extends Sprite2D

enum Facing {
	SOUTH,
	NORTH,
	WEST,
	EAST,
}

@export var walk_atlas: Texture2D
@export var south_standing: Texture2D
@export var north_standing: Texture2D
@export var west_standing: Texture2D
@export var east_standing: Texture2D
@export var facing := Facing.SOUTH
@export var frames_per_second := 8.0

var moving := false
var _frame_index := 0
var _frame_clock := 0.0


func _ready() -> void:
	# Staff always spawn in a directional standing pose. Walking animation
	# may only be entered through an explicit movement event.
	moving = false
	_frame_index = 0
	_frame_clock = 0.0
	_apply_visual()
	set_process(false)


func _process(delta: float) -> void:
	if not moving:
		return
	_frame_clock += delta
	var frame_duration := 1.0 / maxf(frames_per_second, 1.0)
	while _frame_clock >= frame_duration:
		_frame_clock -= frame_duration
		_frame_index = (_frame_index + 1) % 4
		frame_coords = Vector2i(_frame_index, facing)


func start_walking(direction: Vector2) -> void:
	if direction.is_zero_approx():
		stop_walking()
		return
	set_move_direction(direction)
	moving = true
	_apply_visual()
	set_process(true)


func stop_walking() -> void:
	moving = false
	_frame_index = 0
	_frame_clock = 0.0
	_apply_visual()
	set_process(false)


func set_move_direction(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing = Facing.EAST if direction.x > 0.0 else Facing.WEST
	elif direction.y != 0.0:
		facing = Facing.SOUTH if direction.y > 0.0 else Facing.NORTH
	_apply_visual()


func set_facing(value: int) -> void:
	facing = clampi(value, Facing.SOUTH, Facing.EAST)
	_apply_visual()


func _apply_visual() -> void:
	if moving and walk_atlas:
		texture = walk_atlas
		hframes = 4
		vframes = 4
		frame_coords = Vector2i(_frame_index, facing)
		return

	hframes = 1
	vframes = 1
	frame = 0
	match facing:
		Facing.NORTH:
			texture = north_standing
		Facing.WEST:
			texture = west_standing
		Facing.EAST:
			texture = east_standing
		_:
			texture = south_standing
