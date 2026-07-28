extends Sprite2D

signal time_changed(hours: int, minutes: int, seconds: int)

@export var running := true
@export_range(0.0, 3600.0, 0.1) var time_scale := 1.0

@onready var hour_hand: Polygon2D = $HourHand
@onready var minute_hand: Polygon2D = $MinuteHand
@onready var second_hand: Polygon2D = $SecondHand

var _seconds_of_day := 0.0
var _last_reported_second := -1


func _ready() -> void:
	sync_with_system_time()
	_update_hands()


func _process(delta: float) -> void:
	if running:
		_seconds_of_day = fmod(_seconds_of_day + delta * time_scale, 86400.0)
	_update_hands()


func _update_hands() -> void:
	var whole_seconds := int(_seconds_of_day)
	var seconds := fmod(_seconds_of_day, 60.0)
	var minutes := fmod(_seconds_of_day / 60.0, 60.0)
	var hours := fmod(_seconds_of_day / 3600.0, 12.0)

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


func sync_with_system_time() -> void:
	var now := Time.get_time_dict_from_system()
	_seconds_of_day = (
		float(now.hour) * 3600.0
		+ float(now.minute) * 60.0
		+ float(now.second)
	)


func set_time(hours: int, minutes: int, seconds := 0) -> void:
	_seconds_of_day = fposmod(
		float(hours * 3600 + minutes * 60 + seconds),
		86400.0
	)
	_update_hands()


func pause_clock() -> void:
	running = false


func resume_clock() -> void:
	running = true


func set_time_scale(value: float) -> void:
	time_scale = maxf(value, 0.0)
