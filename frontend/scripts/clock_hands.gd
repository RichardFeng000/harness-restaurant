extends Sprite2D

signal time_changed(hours: int, minutes: int, seconds: int)

@export var running := true
# Retained for older callers. Real device time is supplied by the employee skill;
# neither this scale nor frame delta advances the clock view.
@export_range(0.0, 3600.0, 0.1) var time_scale := 1.0

@onready var hour_hand: Polygon2D = $HourHand
@onready var minute_hand: Polygon2D = $MinuteHand
@onready var second_hand: Polygon2D = $SecondHand

var _seconds_of_day := 0.0
var _last_reported_second := -1


func _ready() -> void:
	_update_hands()


func apply_time(sample: Dictionary) -> void:
	if not sample.has_all(["hour", "minute", "second"]):
		return
	set_time(int(sample.hour), int(sample.minute), int(sample.second))


func _update_hands() -> void:
	if not is_node_ready():
		return
	var whole_seconds := int(_seconds_of_day)
	var seconds := fmod(_seconds_of_day, 60.0)
	var minutes := fmod(_seconds_of_day / 60.0, 60.0)
	var hours := fmod(_seconds_of_day / 3600.0, 12.0)

	# restaurant_v4's Polygon2D tips point along local +X. Midnight therefore
	# needs a -90 degree rotation; fractional minutes/hours keep the hands aligned.
	second_hand.rotation = TAU * seconds / 60.0 - PI / 2.0
	minute_hand.rotation = TAU * minutes / 60.0 - PI / 2.0
	hour_hand.rotation = TAU * hours / 12.0 - PI / 2.0

	if whole_seconds != _last_reported_second:
		_last_reported_second = whole_seconds
		time_changed.emit(
			int(_seconds_of_day / 3600.0) % 24,
			int(_seconds_of_day / 60.0) % 60,
			whole_seconds % 60
		)


func set_time(hours: int, minutes: int, seconds := 0) -> void:
	_seconds_of_day = fposmod(
		float(hours * 3600 + minutes * 60 + seconds),
		86400.0
	)
	_update_hands()


func pause_clock() -> void:
	# The external sampler chooses whether to respect this flag. An explicitly
	# supplied sample always updates the view, including after a paused interval.
	running = false


func resume_clock() -> void:
	running = true


func set_time_scale(value: float) -> void:
	time_scale = maxf(value, 0.0)
