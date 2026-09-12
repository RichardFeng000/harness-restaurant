extends SceneTree

const RestaurantScene = preload("res://frontend/scenes/restaurant_v4.tscn")

var failures: Array[String] = []
var reported_times: Array[Vector3i] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Use the real polygons to catch a future asset change to the hand direction.
	var restaurant := RestaurantScene.instantiate()
	var clock = restaurant.get_node("Furniture/HamsterClock")
	clock.get_parent().remove_child(clock)
	restaurant.free()
	clock.time_changed.connect(func(hours: int, minutes: int, seconds: int) -> void:
		reported_times.append(Vector3i(hours, minutes, seconds))
	)
	clock.set_time(3, 15, 30)
	root.add_child(clock)
	_expect_hands(clock, Vector3(7.75, 3.0, 90.0), "入树前设置 03:15:30")
	_expect(reported_times.back() == Vector3i(3, 15, 30), "准备完成后报告预设时间")

	for sample: Dictionary in [
		{"hour": 0, "minute": 0, "second": 0, "angles": Vector3(-90.0, -90.0, -90.0)},
		{"hour": 3, "minute": 15, "second": 30, "angles": Vector3(7.75, 3.0, 90.0)},
		{"hour": 12, "minute": 0, "second": 0, "angles": Vector3(-90.0, -90.0, -90.0)},
		{"hour": 23, "minute": 59, "second": 59, "angles": Vector3(269.9916667, 269.9, 264.0)},
	]:
		clock.apply_time(sample)
		var expected := Vector3i(sample.hour, sample.minute, sample.second)
		_expect_hands(clock, sample.angles, str(expected))
		_expect(reported_times.back() == expected, "样本更新信号 %s" % expected)

	var report_count := reported_times.size()
	clock.apply_time({"hour": 23, "minute": 59, "second": 59})
	_expect(reported_times.size() == report_count, "同一秒不重复发送信号")
	clock.apply_time({"hour": 1})
	_expect(reported_times.size() == report_count, "不完整样本不改变时钟")

	clock.set_time(24, 0, 0)
	_expect(reported_times.back() == Vector3i.ZERO, "24 时归一化为午夜")
	clock.set_time(0, 0, -1)
	_expect(reported_times.back() == Vector3i(23, 59, 59), "负秒正确跨日归一化")

	clock.set_time_scale(3600.0)
	clock.resume_clock()
	await create_timer(0.05).timeout
	_expect_hands(clock, Vector3(269.9916667, 269.9, 264.0), "没有技能样本时不自行走时")
	clock.pause_clock()
	_expect(not clock.running, "保留暂停状态接口")
	clock.apply_time({"hour": 12, "minute": 0, "second": 0})
	_expect_hands(clock, Vector3(-90.0, -90.0, -90.0), "暂停时显式样本仍更新视图")
	clock.resume_clock()
	_expect(clock.running, "保留恢复状态接口")
	clock.set_time_scale(-1.0)
	_expect(clock.time_scale == 0.0, "保留速度参数非负校验")

	clock.queue_free()
	await process_frame
	if failures.is_empty():
		print("Clock hands test: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect_hands(clock: Node, angles: Vector3, label: String) -> void:
	var names := ["HourHand", "MinuteHand", "SecondHand"]
	for index: int in names.size():
		var hand: Polygon2D = clock.get_node(names[index])
		var tip: Vector2 = hand.polygon[2].normalized().rotated(hand.rotation)
		var expected := Vector2.RIGHT.rotated(deg_to_rad(angles[index]))
		_expect(tip.distance_to(expected) < 0.00001, "%s 的 %s 朝向正确" % [label, names[index]])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
