extends SceneTree

const Runtime = preload("res://backend/skills/staff_skill_runtime.gd")
const LocalTime = preload("res://game/skills/local-time/scripts/read_local_time.gd")
const STAFF := "hamster"
const SKILL := "local-time"

class FakeTimeReader extends RefCounted:
	var calls := 0
	var result: Dictionary = {"ok": true, "data": {"hour": 3, "minute": 15, "second": 30}}

	func execute() -> Dictionary:
		calls += 1
		return result.duplicate(true)

var failures: Array[String] = []


func _initialize() -> void:
	_test_assignment_and_execution()
	_test_invalid_samples()
	_test_persistence()
	_test_local_device_time()
	if failures.is_empty():
		print("Staff skill runtime test: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _test_assignment_and_execution() -> void:
	var reader := FakeTimeReader.new()
	var runtime = Runtime.new(reader)
	_expect(runtime.is_installed(STAFF, SKILL), "仓鼠默认预装时间技能")
	_expect(runtime.is_enabled(STAFF, SKILL), "默认时间技能已启用")
	_expect(reader.calls == 0, "初始化安装状态不会提前执行技能")
	var skills: Array[Dictionary] = runtime.list_skills(STAFF)
	_expect(skills.size() == 1 and skills[0].id == SKILL, "仓鼠能查看已分配的本地时间技能")
	_expect(skills[0].permissions == ["device.time.read"], "技能声明设备时间权限")
	_expect(skills[0].last_result.is_empty(), "尚未执行时没有旧时间样本")
	for other_staff: String in ["head_chef", "waiter", "unknown", ""]:
		_expect(runtime.list_skills(other_staff).is_empty(), "其他员工没有时间技能目录：%s" % other_staff)
		_expect(not runtime.install_skill(other_staff, SKILL).ok, "不能给未分配员工安装时间技能：%s" % other_staff)
		_expect(not runtime.set_enabled(other_staff, SKILL, true).ok, "不能跨员工启用时间技能：%s" % other_staff)
		_expect(not runtime.execute(other_staff, SKILL).ok, "其他员工不能执行时间技能：%s" % other_staff)
	_expect(not runtime.install_skill(STAFF, "unknown").ok, "不能安装目录以外的技能")
	_expect(not runtime.execute(STAFF, "unknown").ok, "不能执行不存在的技能")
	_expect(reader.calls == 0, "被拒绝的安装与调用不会触达执行器")

	var result: Dictionary = runtime.execute(STAFF, SKILL)
	_expect(result.ok and result.data == reader.result.data and reader.calls == 1, "已安装技能实际执行读取器")
	result.data.hour = 18
	_expect(runtime.list_skills(STAFF)[0].last_result.data.hour == 3, "调用方不能篡改内部最近结果")
	skills = runtime.list_skills(STAFF)
	skills[0].last_result.data.hour = 20
	_expect(runtime.list_skills(STAFF)[0].last_result.data.hour == 3, "技能列表返回独立的结果副本")

	_expect(runtime.set_enabled(STAFF, SKILL, false).ok, "已安装技能可停用")
	_expect(runtime.is_installed(STAFF, SKILL) and not runtime.is_enabled(STAFF, SKILL), "停用保留安装记录")
	_expect(not runtime.execute(STAFF, SKILL).ok and reader.calls == 1, "停用后拒绝调用且不执行读取器")
	runtime.install_skill(STAFF, SKILL)
	_expect(not runtime.is_enabled(STAFF, SKILL), "重复安装不覆盖用户停用状态")
	_expect(runtime.set_enabled(STAFF, SKILL, true).ok, "技能可重新启用")
	_expect(runtime.execute(STAFF, SKILL).ok and reader.calls == 2, "重新启用读取最新样本")
	_expect(runtime.uninstall_skill(STAFF, SKILL).ok, "技能可卸载")
	_expect(not runtime.is_installed(STAFF, SKILL) and not runtime.is_enabled(STAFF, SKILL), "卸载删除安装状态")
	_expect(runtime.list_skills(STAFF)[0].last_result.is_empty(), "卸载清除旧结果")
	_expect(not runtime.execute(STAFF, SKILL).ok and reader.calls == 2, "卸载后禁止执行读取器")
	_expect(not runtime.set_enabled(STAFF, SKILL, true).ok, "不能直接启用已卸载的技能")
	_expect(runtime.install_skill(STAFF, SKILL).ok and not runtime.is_enabled(STAFF, SKILL), "重新安装时间技能后等待员工启用")
	_expect(not runtime.execute(STAFF, SKILL).ok and reader.calls == 2, "安装本身不会执行时间技能")
	_expect(runtime.set_enabled(STAFF, SKILL, true).ok, "员工手动启用已安装时间技能")
	reader.result.data = {"hour": 16, "minute": 42, "second": 9}
	result = runtime.execute(STAFF, SKILL)
	_expect(result.ok and result.data.hour == 16 and reader.calls == 3, "重新安装后读取新时间而非恢复旧样本")


func _test_invalid_samples() -> void:
	var reader := FakeTimeReader.new()
	var runtime = Runtime.new(reader)
	reader.result = {"ok": false, "error": "模拟设备读取失败"}
	var result: Dictionary = runtime.execute(STAFF, SKILL)
	_expect(not result.ok and result.error == reader.result.error, "设备失败正确返回给调用方")
	for invalid: Variant in [
		null, [], "03:15:30", {}, {"hour": 3, "minute": 15},
		{"hour": "3", "minute": 15, "second": 30},
		{"hour": true, "minute": 15, "second": 30},
		{"hour": -1, "minute": 0, "second": 0},
		{"hour": 24, "minute": 0, "second": 0},
		{"hour": 1, "minute": -1, "second": 0},
		{"hour": 1, "minute": 60, "second": 0},
		{"hour": 1, "minute": 1, "second": -1},
		{"hour": 1, "minute": 1, "second": 60},
		{"hour": 1.5, "minute": 1, "second": 1},
		{"hour": NAN, "minute": 1, "second": 1},
		{"hour": 1, "minute": INF, "second": 1},
	]:
		reader.result = {"ok": true, "data": invalid}
		result = runtime.execute(STAFF, SKILL)
		_expect(not result.ok and result.has("error"), "拒绝无效时间读数：%s" % str(invalid))
		_expect(not runtime.list_skills(STAFF)[0].last_result.ok, "无效结果不得显示为成功")
	reader.result = {"ok": true, "data": {"hour": 23.0, "minute": 59.0, "second": 59.0}}
	_expect(runtime.execute(STAFF, SKILL).ok, "允许来自浏览器 JSON 的整数值浮点数")


func _test_persistence() -> void:
	var reader := FakeTimeReader.new()
	var runtime = Runtime.new(reader)
	runtime.execute(STAFF, SKILL)
	runtime.set_enabled(STAFF, SKILL, false)
	var state: Dictionary = runtime.export_state()
	_expect(state == {STAFF: {SKILL: {"enabled": false}}}, "存档只含安装和启用状态，不含时间样本")
	state[STAFF][SKILL].enabled = true
	_expect(not runtime.is_enabled(STAFF, SKILL), "修改导出数据不改变内部状态")
	state[STAFF][SKILL].enabled = false
	var restored = Runtime.new(reader)
	restored.restore_state(state)
	_expect(restored.is_installed(STAFF, SKILL) and not restored.is_enabled(STAFF, SKILL), "恢复停用状态")
	_expect(restored.list_skills(STAFF)[0].last_result.is_empty(), "恢复时不回填旧时间")
	state[STAFF][SKILL].enabled = true
	_expect(not restored.is_enabled(STAFF, SKILL), "恢复后的内部状态不引用传入字典")
	restored.uninstall_skill(STAFF, SKILL)
	runtime.restore_state(restored.export_state())
	_expect(not runtime.is_installed(STAFF, SKILL), "明确卸载状态经过保存恢复仍保留")
	runtime.restore_state({})
	_expect(not runtime.is_installed(STAFF, SKILL), "空技能存档不会重新默认安装")
	runtime.restore_state(null)
	_expect(runtime.is_installed(STAFF, SKILL) and runtime.is_enabled(STAFF, SKILL), "没有技能字段的旧存档使用默认安装状态")
	_expect(runtime.list_skills(STAFF)[0].last_result.is_empty(), "旧存档恢复不会引入时间样本")
	runtime.restore_state({
		"unknown": {SKILL: {"enabled": true}},
		STAFF: {SKILL: {"enabled": false, "data": {"hour": 20}}, "unknown": {"enabled": true}},
	})
	_expect(not runtime.is_installed("unknown", SKILL), "恢复存档不能给未知员工安装技能")
	_expect(runtime.export_state() == {STAFF: {SKILL: {"enabled": false}}}, "恢复会清除无权员工、未知技能和时间字段")
	for invalid_record: Variant in [null, [], true, {"enabled": 1}, {"enabled": "true"}, {"unexpected": true}]:
		runtime.restore_state({STAFF: {SKILL: invalid_record}})
		_expect(not runtime.is_installed(STAFF, SKILL), "无效安装记录不会获得技能执行权限")
	runtime.restore_state({STAFF: "invalid"})
	_expect(not runtime.is_installed(STAFF, SKILL), "错误的员工存档类型被拒绝")
	_expect(reader.calls == 1, "保存和恢复安装状态均不执行读取器")


func _test_local_device_time() -> void:
	var before := Time.get_datetime_dict_from_system(false)
	var result: Dictionary = LocalTime.new().execute()
	var after := Time.get_datetime_dict_from_system(false)
	_expect(result.get("ok", false), "真实时间技能成功读取当前设备")
	if not result.get("ok", false):
		return
	var data: Dictionary = result.get("data", {})
	_expect(data.get("hour") is int and data.get("minute") is int and data.get("second") is int, "返回整数时分秒")
	var expected_time := "%02d:%02d:%02d" % [data.hour, data.minute, data.second]
	_expect(data.get("time") == expected_time, "时间文本与指针读数一致且补零")
	var date_pattern := RegEx.new()
	date_pattern.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
	_expect(date_pattern.search(str(data.get("date", ""))) != null, "日期使用 YYYY-MM-DD 格式")
	var sample_seconds := Time.get_unix_time_from_datetime_string(data.date + "T" + data.time)
	_expect(sample_seconds >= Time.get_unix_time_from_datetime_dict(before) and sample_seconds <= Time.get_unix_time_from_datetime_dict(after), "时间与调用前后设备本地读数匹配，容忍跨秒或跨日")
	_expect(data.get("timezone") is String and not data.timezone.is_empty(), "返回非空设备时区")
	_expect(data.get("utc_offset_minutes") is int and data.utc_offset_minutes >= -720 and data.utc_offset_minutes <= 840, "UTC 偏移在有效本地时区范围内")
	var local := Time.get_datetime_dict_from_system(false)
	var utc := Time.get_datetime_dict_from_system(true)
	var expected_offset := int(round(float(Time.get_unix_time_from_datetime_dict(local) - Time.get_unix_time_from_datetime_dict(utc)) / 60.0))
	_expect(data.utc_offset_minutes == expected_offset, "UTC 偏移与当前本地时间匹配，包含夏令时")
	_expect(data.get("source") == "设备系统时钟", "原生执行明确标识设备时间来源")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
