extends SceneTree

const MainScene = preload("res://frontend/scenes/main.tscn")
const Api = preload("res://backend/harness_api.gd")
const Runtime = preload("res://backend/skills/staff_skill_runtime.gd")
const Store = preload("res://frontend/state/workspace_store.gd")
var failures: Array[String] = []
var temp_dir := "/tmp/harness_timekeeper_%d" % Time.get_ticks_usec()

class FakeTime:
	extends RefCounted
	var now := {"hour": 3, "minute": 15, "second": 30}
	var fail := false
	var calls := 0
	func execute() -> Dictionary:
		calls += 1
		return {"ok": false, "error": "Test failure"} if fail else {"ok": true, "data": now.duplicate()}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(temp_dir)
	var reader := FakeTime.new()
	var main = MainScene.instantiate()
	main.api = Api.new(temp_dir.path_join("database.csv"), false)
	main.api.skills = Runtime.new(reader)
	main.store = Store.new(temp_dir.path_join("save.json"), temp_dir.path_join("workspace.json"))
	root.add_child(main)
	await process_frame
	_expect(reader.calls == 0, "菜单不运行时间技能")
	main._open_demo()
	main._start_agent_run()
	var clock = main.restaurant_scene.get_node("Furniture/HamsterClock")
	_expect(_seconds(clock) == 11730, "进入餐厅后由仓鼠技能校准墙钟")
	main._pause_game()
	reader.now = {"hour": 23, "minute": 59, "second": 59}
	# The worker schedules against monotonic wall time, independently of frame delta.
	var deadline := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(_seconds(clock) == 86399 and paused, "暂停游戏时仍自动读取现实时间")
	reader.now = {"hour": 0, "minute": 0, "second": 1}
	main._resume_game()
	_expect(_seconds(clock) == 1, "恢复时立即重读跨日时间，不累加暂停时间")
	main.api.skills.set_enabled("hamster", "local-time", false)
	var count: int = reader.calls
	reader.now = {"hour": 10, "minute": 5, "second": 0}
	main.timekeeper.sync_now()
	main.api.skills.execute("hamster", "local-time")
	_expect(reader.calls == count and _seconds(clock) == 1, "停用后自动和手动执行都停止读取")
	main.api.skills.set_enabled("hamster", "local-time", true)
	_expect(_seconds(clock) == 36300, "重新启用立即校时")
	reader.fail = true
	reader.now = {"hour": 17, "minute": 0, "second": 0}
	main.timekeeper.sync_now()
	_expect(_seconds(clock) == 36300, "技能读取失败保留最后一次有效指针位置")
	reader.fail = false
	main.api.skills.uninstall_skill("hamster", "local-time")
	count = reader.calls
	main.timekeeper.sync_now()
	_expect(reader.calls == count, "卸载后停止采样")
	main.api.skills.install_skill("hamster", "local-time")
	main.timekeeper.sync_now()
	_expect(reader.calls == count and _seconds(clock) == 36300, "重新安装后暂停，等待仓鼠启用")
	main.api.skills.set_enabled("hamster", "local-time", true)
	_expect(_seconds(clock) == 61200, "仓鼠启用后立即使用最新时间")
	main._back_to_menu()
	count = reader.calls
	main.timekeeper.sync_now()
	_expect(reader.calls == count, "返回主菜单停止时间任务")
	main._reset_session()
	main._open_workspace(temp_dir)
	main._start_agent_run()
	main.api.skills.set_enabled("hamster", "local-time", false)
	main._pause_game()
	main._save_progress()
	main._back_to_menu()
	main._open_demo()
	_expect(main.api.skills.is_enabled("hamster", "local-time"), "演示使用独立默认技能状态")
	main._back_to_menu()
	main._continue_game()
	_expect(not main.api.skills.is_enabled("hamster", "local-time"), "继续餐厅恢复保存的停用状态")
	main._back_to_menu()
	main.queue_free()
	await process_frame
	for file_name in ["save.json", "workspace.json", "database.csv"]:
		if FileAccess.file_exists(temp_dir.path_join(file_name)):
			DirAccess.remove_absolute(temp_dir.path_join(file_name))
	DirAccess.remove_absolute(temp_dir)
	if failures.is_empty():
		print("Hamster timekeeper integration test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _seconds(clock: Node) -> int:
	return int(clock._seconds_of_day)

func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
