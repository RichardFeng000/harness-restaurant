@tool
extends Node2D
class_name HamsterClock2D

@export var running := true
var elapsed := 0.0

func _process(delta: float) -> void:
	if running and not Engine.is_editor_hint():
		elapsed += delta
		queue_redraw()

func _draw() -> void:
	var brass := Color("#b87925")
	var dark := Color("#4a2b16")
	draw_circle(Vector2(0, -54), 43, Color("#d5a14a"))
	draw_circle(Vector2(0, -54), 36, Color("#f3dfad"))
	draw_arc(Vector2.ZERO, 37, 0, TAU, 48, brass, 5)
	for spoke in range(12):
		var angle := elapsed * 2.6 + spoke * TAU / 12.0
		draw_line(Vector2.ZERO, Vector2(cos(angle), sin(angle)) * 34, dark, 1.5)
	draw_circle(Vector2(6, 7), 13, Color("#bd7440"))
	draw_circle(Vector2(15, 1), 7, Color("#d78c50"))
	draw_circle(Vector2(18, -1), 2, Color("#241611"))
	var minute_angle := elapsed * 0.45 - PI * 0.5
	var hour_angle := elapsed * 0.075 - PI * 0.5
	draw_line(Vector2(0, -54), Vector2(0, -54) + Vector2(cos(minute_angle), sin(minute_angle)) * 27, dark, 2)
	draw_line(Vector2(0, -54), Vector2(0, -54) + Vector2(cos(hour_angle), sin(hour_angle)) * 19, dark, 3)
	draw_circle(Vector2(0, -54), 3, brass)
