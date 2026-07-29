extends Sprite2D

enum Facing {
	SOUTH,
	NORTH,
	WEST,
	EAST,
}

@export var south_texture: Texture2D
@export var north_texture: Texture2D
@export var west_texture: Texture2D
@export var east_texture: Texture2D
@export var facing := Facing.SOUTH:
	set(value):
		facing = value
		_apply_facing()

func _ready() -> void:
	_apply_facing()

func set_facing(value: int) -> void:
	facing = value

func face_direction(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing = Facing.EAST if direction.x > 0.0 else Facing.WEST
	elif direction.y != 0.0:
		facing = Facing.SOUTH if direction.y > 0.0 else Facing.NORTH

func _apply_facing() -> void:
	match facing:
		Facing.NORTH:
			texture = north_texture
		Facing.WEST:
			texture = west_texture
		Facing.EAST:
			texture = east_texture
		_:
			texture = south_texture
