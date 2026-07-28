@tool
extends Node2D
class_name RestaurantRoom2D

@export var room_size := Vector2(320, 220):
	set(value):
		room_size = value
		queue_redraw()
@export var floor_color := Color("#a96b38"):
	set(value):
		floor_color = value
		queue_redraw()
@export var wall_color := Color("#6f2f1e"):
	set(value):
		wall_color = value
		queue_redraw()
@export var closed_room := false:
	set(value):
		closed_room = value
		queue_redraw()
@export var draw_visual := true:
	set(value):
		draw_visual = value
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if not draw_visual:
		return
	var rect := Rect2(Vector2.ZERO, room_size)
	draw_rect(rect, floor_color)
	if floor_color == Color("#d7d5bd"):
		_draw_tiles(rect)
	var wall_width := 12.0
	draw_rect(Rect2(0, 0, room_size.x, wall_width), wall_color)
	draw_rect(Rect2(0, 0, wall_width, room_size.y), wall_color)
	draw_rect(Rect2(room_size.x - wall_width, 0, wall_width, room_size.y), wall_color)
	if closed_room:
		draw_rect(Rect2(0, room_size.y - wall_width, room_size.x, wall_width), wall_color)
		draw_rect(Rect2(12, 12, room_size.x - 24, room_size.y - 24), Color("#543322"))
	else:
		draw_rect(Rect2(0, room_size.y - wall_width, room_size.x * 0.38, wall_width), wall_color)
		draw_rect(Rect2(room_size.x * 0.62, room_size.y - wall_width, room_size.x * 0.38, wall_width), wall_color)

func _draw_tiles(rect: Rect2) -> void:
	var tile := 32
	for y in range(int(rect.size.y / tile) + 1):
		for x in range(int(rect.size.x / tile) + 1):
			var color := Color("#edf0d8") if (x + y) % 2 == 0 else Color("#9eb8af")
			draw_rect(Rect2(x * tile, y * tile, tile, tile), color)
