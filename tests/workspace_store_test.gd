extends SceneTree

const WorkspaceStore = preload("res://frontend/state/workspace_store.gd")

var failures: Array[String] = []
var test_directory := ""


func _init() -> void:
	test_directory = "/tmp/harness_workspace_store_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	if DirAccess.make_dir_absolute(test_directory) != OK:
		push_error("无法创建独立的工作区存储测试目录")
		quit(1)
		return
	var save_path := test_directory.path_join("restaurant_save.json")
	var preference_path := test_directory.path_join("workspace.json")
	var store = WorkspaceStore.new(save_path, preference_path)

	_expect(store.load_progress().is_empty(), "不存在的存档应返回空数据")
	_expect(store.load_preference().is_empty(), "不存在的位置偏好应返回空字符串")
	_expect(not store.replace_saved_workspace("/new/workspace"), "替换位置不应创建不存在的存档")

	var progress := {
		"restaurant": "/餐厅/我的厨房",
		"task_count": 2,
		"energy": 75,
		"game_started": true,
		"extension": {"note": "保留未来字段"},
	}
	_expect(store.save_progress(progress), "写入进度失败")
	var loaded: Dictionary = store.load_progress()
	_expect(loaded == progress, "进度往返读写应保留现有字段及扩展字段")
	_expect(store.replace_saved_workspace("/餐厅/新位置"), "替换存档工作区失败")
	loaded = store.load_progress()
	_expect(loaded.get("restaurant") == "/餐厅/新位置", "存档位置未更新")
	_expect(loaded.get("task_count") == 2 and loaded.get("extension") == progress["extension"], "替换位置不应丢失游戏进度")
	_expect(not store.replace_saved_workspace("  "), "不应接受空工作区位置")

	_expect(store.save_preference("/餐厅/新位置"), "写入位置偏好失败")
	_expect(store.load_preference() == "/餐厅/新位置", "位置偏好往返读写失败")
	_expect(not store.save_preference(""), "空位置不应覆盖已有偏好")
	_expect(store.load_preference() == "/餐厅/新位置", "拒绝空位置后应保留偏好")

	for invalid_json: String in ["", "  \n", "{broken", "[]", "42", "true", "null", "\"text\""]:
		_write_fixture(save_path, invalid_json)
		_expect(store.load_progress().is_empty(), "无效或非对象 JSON 应安全返回空进度")
		_expect(not store.replace_saved_workspace("/new/workspace"), "不应通过替换位置覆盖坏存档")
	_write_fixture(save_path, '{"restaurant":[],"task_count":{},"energy":"bad","game_started":[],"extension":1}')
	loaded = store.load_progress()
	_expect(loaded.size() == 1 and loaded.get("extension") == 1, "读取进度应过滤已知字段的错误类型")
	_write_fixture(preference_path, '{"folder":[]}')
	_expect(store.load_preference().is_empty(), "位置偏好类型错误应返回空字符串")

	var model_config := {"model": "本地模型", "base_url": "http://localhost:8000/v1", "api_key": "test-only-key"}
	_expect(store.load_model_config(test_directory).is_empty(), "不存在的模型配置应返回空数据")
	_expect(store.save_model_config(test_directory, model_config), "保存模型配置失败")
	_expect(store.load_model_config(test_directory) == model_config, "模型配置往返读写失败")
	_expect(store.load_model_config("").is_empty(), "空目录不应读取项目中的模型配置")
	_expect(not store.save_model_config("", model_config), "空目录不应写入项目中的模型配置")
	_write_fixture(test_directory.path_join("harness_config.json"), '{"model":[],"base_url":{},"api_key":false}')
	_expect(store.load_model_config(test_directory).is_empty(), "读取模型配置应过滤错误字段类型")

	var missing_directory := test_directory.path_join("missing")
	var unwritable_store = WorkspaceStore.new(missing_directory.path_join("save.json"), missing_directory.path_join("preference.json"))
	_expect(not unwritable_store.save_progress(progress), "写入不存在的目录应报告失败")
	_expect(not unwritable_store.save_preference("/workspace"), "偏好写入失败应报告失败")
	_expect(not store.save_model_config(missing_directory, model_config), "模型配置写入失败应报告失败")

	_cleanup()
	if failures.is_empty():
		print("Harness Kitchen workspace store test: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _write_fixture(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("无法写入测试数据：%s" % path)
		return
	file.store_string(contents)
	file.close()


func _cleanup() -> void:
	for filename: String in ["restaurant_save.json", "workspace.json", "harness_config.json"]:
		var path := test_directory.path_join(filename)
		if FileAccess.file_exists(path):
			_expect(DirAccess.remove_absolute(path) == OK, "清理测试文件失败")
	_expect(DirAccess.remove_absolute(test_directory) == OK, "清理测试目录失败")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
