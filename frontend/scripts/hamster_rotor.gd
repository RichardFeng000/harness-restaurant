extends Node2D

@export var rotation_speed := 1.8
@export var running := true
@export var radius := 82.0

const BRASS_DARK := Color("#8f541d")
const BRASS := Color("#d99a38")
const BRASS_LIGHT := Color("#f1c063")

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if running:
		rotation += rotation_speed * delta

func _draw() -> void:
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var tip := Vector2(cos(angle), sin(angle)) * radius
		draw_line(Vector2.ZERO, tip, BRASS_DARK, 8.0, true)
		draw_line(Vector2.ZERO, tip, BRASS, 4.0, true)
	draw_circle(Vector2.ZERO, 18.0, BRASS_DARK)
	draw_circle(Vector2.ZERO, 13.0, BRASS)
	draw_circle(Vector2.ZERO, 6.0, BRASS_LIGHT)

func start() -> void:
	running = true

func stop() -> void:
	running = false

