extends Sprite2D

@export var columns := 4
@export var rows := 4
@export var frame_count := 16
@export var frames_per_second := 12.0
@export var autoplay := false

var playing := false
var frame_clock := 0.0

func _ready() -> void:
	hframes = maxi(columns, 1)
	vframes = maxi(rows, 1)
	frame = 0
	playing = autoplay

func _process(delta: float) -> void:
	if not playing or frame_count <= 1:
		return
	frame_clock += delta
	var frame_duration := 1.0 / maxf(frames_per_second, 1.0)
	while frame_clock >= frame_duration:
		frame_clock -= frame_duration
		frame = (frame + 1) % frame_count

func play() -> void:
	playing = true

func pause() -> void:
	playing = false

func stop() -> void:
	playing = false
	frame_clock = 0.0
	frame = 0
