extends SceneTree

const MainScene = preload("res://frontend/scenes/main.tscn")
const Store = preload("res://frontend/state/workspace_store.gd")
var failures: Array[String] = []
var temporary_dir := "/tmp/harness_frontend_%d" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(temporary_dir)
	var main = MainScene.instantiate()
	main.store = Store.new(temporary_dir.path_join("save.json"), temporary_dir.path_join("workspace.json"))
	root.add_child(main)
	await process_frame
	_expect(main.menu_layer.visible and not main.game_layer.visible, "初始显示菜单")
	_expect(not main.menu_layer.continue_button.visible, "没有存档时不提供继续入口")
	main._open_demo()
	_expect(main.demo_mode and main.game_layer.visible, "演示无需文件夹即可进入")
	main._start_agent_run()
	_expect(main.hud.book_button.visible and not main.hud.run_button.visible, "开业后显示工作簿入口")
	main._open_harness()
	_expect(main.harness_layer.visible, "工作簿可打开")
	await _escape(main)
	await create_timer(0.8).timeout
	_expect(not main.harness_layer.visible, "Esc 关闭工作簿")
	await _escape(main)
	_expect(paused and main.pause_layer.visible, "Esc 暂停营业")
	_expect(not main.restaurant_scene.can_process() and main.pause_layer.can_process(), "暂停动画且保持菜单交互")
	main._save_progress()
	_expect(main.store.load_progress().is_empty(), "演示不写入真实进度")
	await _escape(main)
	_expect(not paused and not main.pause_layer.visible, "Esc 恢复营业")
	main._back_to_menu()
	main._reset_session()
	main.selected_folder = temporary_dir
	main._open_workspace(temporary_dir)
	main._start_agent_run()
	main.task_count = 2
	main.energy = 71
	main._pause_game()
	main._save_progress()
	_expect(main.pause_layer.status.text.contains("已保存"), "保存反馈直接可见")
	main._back_to_menu()
	_expect(main.menu_layer.continue_button.visible, "有存档时提供继续入口")
	main._open_demo()
	main._back_to_menu()
	main._continue_game()
	_expect(not main.demo_mode and main.game_started and main.task_count == 2 and main.energy == 71, "演示不覆盖原餐厅存档")
	main._back_to_menu()
	main._new_game()
	main.file_dialog.hide()
	main._folder_selection_canceled()
	_expect(main.game_started and main.task_count == 2, "取消创建不重置当前进度")
	main.store.save_model_config(temporary_dir, {"model": "test-model", "base_url": "https://example.test/v1", "api_key": "test-only"})
	main._show_settings_panel()
	_expect(main.model_input.text == "test-model" and main.api_key_input.secret, "设置回读已有配置且隐藏密钥")
	main.model_input.text = ""
	main._save_model_config()
	_expect(main.settings_status.text.contains("都必须填写"), "空设置不会覆盖已有配置")
	_expect(main.store.load_model_config(temporary_dir).get("model") == "test-model", "校验失败后原配置保留")
	await _escape(main)
	_expect(not main.settings_layer.visible, "Esc 关闭设置")
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		await process_frame
		await process_frame
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(dimensions))
		for child in main.menu_layer.find_children("*", "Button", true, false):
			if child.is_visible_in_tree():
				_expect(viewport_rect.encloses(child.get_global_rect()), "菜单按钮不溢出 %s: %s" % [dimensions, child.text])
		main._show_settings_panel()
		await process_frame
		await process_frame
		for child in main.settings_layer.find_children("*", "Button", true, false):
			_expect(viewport_rect.encloses(child.get_global_rect()), "设置按钮不溢出 %s" % dimensions)
		main._close_settings()
	main.queue_free()
	await process_frame
	for file_name in ["save.json", "workspace.json", "harness_config.json"]:
		DirAccess.remove_absolute(temporary_dir.path_join(file_name))
	DirAccess.remove_absolute(temporary_dir)
	if failures.is_empty():
		print("Frontend smoke test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _escape(_main: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	await process_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
