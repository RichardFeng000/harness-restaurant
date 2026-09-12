extends Sprite2D

@export var frames_per_second := 12.0
@export var running := false

var frame_clock := 0.0

func _ready() -> void:
	hframes = 4
	vframes = 4
	frame = 0

func _process(delta: float) -> void:
	if not running:
		return
	frame_clock += delta
	var frame_duration := 1.0 / maxf(frames_per_second, 1.0)
	while frame_clock >= frame_duration:
		frame_clock -= frame_duration
		frame = (frame + 1) % 16

func start() -> void:
	frame_clock = 0.0
	running = true

func stop() -> void:
	running = false
	frame_clock = 0.0
	frame = 0
