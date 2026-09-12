extends Control
## Coordinates views, workspace access and the restaurant session.

const HarnessApi = preload("res://backend/harness_api.gd")
const LayeredRestaurant = preload("res://frontend/scenes/restaurant_v4.tscn")
const HarnessBookSystem = preload("res://frontend/scenes/harness_book_system.tscn")
const UI = preload("res://frontend/ui/kitchen_theme.gd")
const MainMenu = preload("res://frontend/ui/main_menu.gd")
const SettingsPanel = preload("res://frontend/ui/settings_panel.gd")
const GameHud = preload("res://frontend/ui/game_hud.gd")
const PauseMenu = preload("res://frontend/ui/pause_menu.gd")
const WorkspaceStore = preload("res://frontend/state/workspace_store.gd")
const HamsterTimekeeper = preload("res://frontend/world/hamster_timekeeper.gd")
const MODEL_CONFIG_FILENAME := "harness_config.json"

var store = WorkspaceStore.new()
var api
var folder_callback
var config_write_callback
var config_read_callback
var selected_folder := ""
var folder_selection_mode := "open"
var task_count := 3
var energy := 84
var game_started := false
var demo_mode := false
var workspace_session_key := ""
var menu_layer
var game_layer: Control
var pause_layer
var settings_layer
var hud
var harness_layer: Control
var restaurant_scene: Node
var timekeeper: Node
var file_dialog: FileDialog
var folder_label: Label
var model_input: LineEdit
var base_url_input: LineEdit
var api_key_input: LineEdit
var settings_status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UI.create()
	get_window().min_size = Vector2i(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if api == null:
		api = HarnessApi.new()
	api.request("POST", "/api/v2/bootstrap")
	_build_menu()
	_build_game()
	_build_harness_layer()
	_build_settings()
	_build_file_dialog()
	_load_workspace_preference()
	menu_layer.set_can_continue(not store.load_progress().is_empty())
	game_layer.hide()
	restaurant_scene.process_mode = Node.PROCESS_MODE_DISABLED

func _build_menu() -> void:
	menu_layer = MainMenu.new()
	add_child(menu_layer)
	folder_label = menu_layer.folder_label
	menu_layer.new_requested.connect(_new_game)
	menu_layer.continue_requested.connect(_continue_game)
	menu_layer.folder_requested.connect(_choose_local_folder)
	menu_layer.settings_requested.connect(_show_settings_status)
	menu_layer.demo_requested.connect(_open_demo)

func _build_game() -> void:
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.clip_contents = true
	add_child(game_layer)
	restaurant_scene = LayeredRestaurant.instantiate()
	restaurant_scene.name = "RestaurantScene"
	restaurant_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	game_layer.add_child(restaurant_scene)
	timekeeper = HamsterTimekeeper.new()
	add_child(timekeeper)
	timekeeper.bind(api.skills, restaurant_scene.get_node("Furniture/HamsterClock"))
	timekeeper.working_changed.connect(_timekeeper_working_changed)
	hud = GameHud.new()
	game_layer.add_child(hud)
	hud.pause_requested.connect(_pause_game)
	hud.start_requested.connect(_start_agent_run)
	hud.book_requested.connect(_open_harness)
	pause_layer = PauseMenu.new()
	game_layer.add_child(pause_layer)
	pause_layer.resume_requested.connect(_resume_game)
	pause_layer.save_requested.connect(_save_progress)
	pause_layer.menu_requested.connect(_back_to_menu)

func _build_settings() -> void:
	settings_layer = SettingsPanel.new()
	add_child(settings_layer)
	settings_layer.close_requested.connect(_close_settings)
	settings_layer.save_requested.connect(_save_model_config)
	model_input = settings_layer.model_input
	base_url_input = settings_layer.base_url_input
	api_key_input = settings_layer.api_key_input
	settings_status = settings_layer.status

func _folder_selected(folder: String) -> void:
	if folder.is_empty():
		return
	var selection_mode := folder_selection_mode
	folder_selection_mode = "open"
	selected_folder = folder
	_save_workspace_preference()
	if selection_mode == "settings":
		_show_settings_panel()
		return
	if selection_mode == "continue":
		if not store.replace_saved_workspace(selected_folder):
			folder_label.text = "无法更新存档位置，请检查本地存储权限"
			return
		_continue_game()
		return
	_reset_session()
	if selection_mode == "new_game" and not _write_progress_file():
		folder_label.text = "无法保存餐厅档案，请检查本地存储权限"
		return
	_open_workspace(selected_folder)

func _open_workspace(folder: String) -> void:
	var session_key := "__demo__" if demo_mode else folder
	if workspace_session_key != session_key:
		harness_layer.reset_session()
	workspace_session_key = session_key
	selected_folder = folder
	var display_name := "演示餐厅" if demo_mode else _workspace_display_name(folder)
	folder_label.text = display_name
	folder_label.tooltip_text = folder
	folder_label.add_theme_color_override("font_color", UI.INK)
	menu_layer.hide()
	game_layer.show()
	pause_layer.hide()
	harness_layer.hide()
	get_tree().paused = false
	restaurant_scene.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.update_state(display_name, game_started, demo_mode)
	_set_hamster_running(game_started)
	timekeeper.set_active(true)

func _reset_session() -> void:
	timekeeper.set_active(false)
	api.skills.restore_state(null)
	harness_layer.reset_session()
	game_started = false
	demo_mode = false
	task_count = 3
	energy = 84
	_set_hamster_running(false)

func _open_demo() -> void:
	_reset_session()
	demo_mode = true
	_open_workspace("")

func _new_game() -> void:
	folder_selection_mode = "new_game"
	folder_label.text = "选择一个文件夹，创建新的餐厅档案"
	_select_folder()

func _back_to_menu() -> void:
	timekeeper.set_active(false)
	get_tree().paused = false
	pause_layer.hide()
	harness_layer.hide()
	game_layer.hide()
	restaurant_scene.process_mode = Node.PROCESS_MODE_DISABLED
	menu_layer.show()
	_load_workspace_preference()
	menu_layer.set_can_continue(not store.load_progress().is_empty())

func _continue_game() -> void:
	var saved_data: Dictionary = store.load_progress()
	if saved_data.is_empty():
		folder_label.text = "尚无存档，请创建餐厅或体验演示"
		return
	selected_folder = str(saved_data.get("restaurant", selected_folder))
	if not _workspace_is_available(selected_folder):
		folder_selection_mode = "continue"
		folder_label.text = "请重新选择存档对应的本地文件夹"
		_select_folder()
		return
	demo_mode = false
	timekeeper.set_active(false)
	api.skills.restore_state(saved_data.get("staff_skills"))
	api.skills.restore_mcp_state(saved_data.get("mcp_servers"))
	api.skills.restore_permission_state(saved_data.get("staff_tool_permissions"))
	task_count = int(saved_data.get("task_count", 3))
	energy = int(saved_data.get("energy", 84))
	game_started = bool(saved_data.get("game_started", true))
	_open_workspace(selected_folder)

func _show_settings_panel() -> void:
	model_input.clear()
	base_url_input.clear()
	api_key_input.clear()
	settings_status.text = "保存到：%s / %s" % [_workspace_display_name(selected_folder), MODEL_CONFIG_FILENAME]
	settings_status.add_theme_color_override("font_color", UI.MUTED)
	settings_layer.set_loading(OS.has_feature("web"))
	if OS.has_feature("web"):
		settings_status.text = "正在读取餐厅配置…"
		_read_model_config_web()
	else:
		_fill_model_config(store.load_model_config(selected_folder))
	settings_layer.show()
	settings_layer.move_to_front()
	model_input.grab_focus()

func _fill_model_config(config: Dictionary) -> void:
	model_input.text = str(config.get("model", ""))
	base_url_input.text = str(config.get("base_url", ""))
	api_key_input.text = str(config.get("api_key", ""))

func _read_model_config_web() -> void:
	config_read_callback = JavaScriptBridge.create_callback(_model_config_read_from_web)
	var window = JavaScriptBridge.get_interface("window")
	window.harnessConfigRead = config_read_callback
	JavaScriptBridge.eval("""
		(async () => {
			try {
				const handle = window.harnessWorkspaceHandle;
				const file = await (await handle.getFileHandle("harness_config.json")).getFile();
				window.harnessConfigRead(await file.text());
			} catch (error) { window.harnessConfigRead("{}"); }
		})();
	""", true)

func _model_config_read_from_web(arguments: Array) -> void:
	if arguments.is_empty() or not settings_layer.visible:
		return
	settings_layer.set_loading(false)
	settings_status.text = "保存到：%s / %s" % [_workspace_display_name(selected_folder), MODEL_CONFIG_FILENAME]
	var parsed = JSON.parse_string(str(arguments[0]))
	if parsed is Dictionary:
		_fill_model_config(parsed)

func _start_agent_run() -> void:
	game_started = true
	_set_hamster_running(true)
	hud.update_state("演示餐厅" if demo_mode else _workspace_display_name(selected_folder), true, demo_mode)

func _open_harness() -> void:
	if not game_started:
		return
	harness_layer.open(hud.book_button.get_global_rect())

func _close_harness() -> void:
	harness_layer.close(hud.book_button.get_global_rect())

func _on_harness_closed() -> void:
	hud.book_button.grab_focus()

func _pause_game() -> void:
	get_tree().paused = true
	pause_layer.save_button.disabled = demo_mode
	pause_layer.status.text = "演示体验不保存进度" if demo_mode else "Esc 继续营业 · 进度需要手动保存"
	pause_layer.status.add_theme_color_override("font_color", UI.MUTED)
	pause_layer.show()

func _resume_game() -> void:
	get_tree().paused = false
	pause_layer.hide()
	timekeeper.sync_now()

func _save_progress() -> void:
	if demo_mode:
		pause_layer.status.text = "演示体验不保存进度"
		return
	if not _write_progress_file():
		pause_layer.status.text = "保存失败，请检查本地存储权限后重试"
		pause_layer.status.add_theme_color_override("font_color", UI.ACCENT)
		return
	_save_workspace_preference()
	pause_layer.status.text = "进度已保存 · 可以安心休息了"
	pause_layer.status.add_theme_color_override("font_color", UI.GREEN)

func _write_progress_file() -> bool:
	return store.save_progress({
		"restaurant": selected_folder,
		"task_count": task_count,
		"energy": energy,
		"game_started": game_started,
		"staff_skills": api.skills.export_state(),
		"mcp_servers": api.skills.export_mcp_state(),
		"staff_tool_permissions": api.skills.export_permission_state(),
	})

func _save_workspace_preference() -> void:
	if not selected_folder.is_empty():
		store.save_preference(selected_folder)

func _load_workspace_preference() -> void:
	var saved_folder: String = store.load_preference()
	if saved_folder.is_empty():
		return
	selected_folder = saved_folder
	folder_label.text = _workspace_display_name(saved_folder)
	folder_label.tooltip_text = saved_folder
	folder_label.add_theme_color_override("font_color", UI.INK)

func _workspace_is_available(folder: String) -> bool:
	if folder.is_empty():
		return false
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.harnessWorkspaceHandle ? window.harnessWorkspaceHandle.name : null", true)) == folder
	return DirAccess.dir_exists_absolute(folder)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_game") or event.is_echo():
		return
	if file_dialog.visible:
		return
	if settings_layer.visible:
		_close_settings()
	elif harness_layer.visible:
		if not harness_layer.dismiss_active_panel():
			_close_harness()
	elif game_layer.visible:
		if pause_layer.visible:
			_resume_game()
		else:
			_pause_game()
	else:
		return
	get_viewport().set_input_as_handled()

func _build_harness_layer() -> void:
	harness_layer = HarnessBookSystem.instantiate()
	harness_layer.connect("closed", _on_harness_closed)
	add_child(harness_layer)
	harness_layer.set_skill_runtime(api.skills)
	harness_layer.visibility_changed.connect(func():
		# The cover is lifted into the animation, leaving no duplicate in the HUD.
		hud.book_button.modulate.a = 0.0 if harness_layer.visible else 1.0
	)
	harness_layer.hide()

func _build_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "选择本地餐厅档案"
	file_dialog.dir_selected.connect(_folder_selected)
	add_child(file_dialog)
	file_dialog.canceled.connect(_folder_selection_canceled)

func _choose_local_folder() -> void:
	folder_selection_mode = "open"
	_select_folder()

func _select_folder() -> void:
	if OS.has_feature("web"):
		_select_folder_web()
	else:
		file_dialog.popup_centered_ratio(0.75)

func _select_folder_web() -> void:
	folder_callback = JavaScriptBridge.create_callback(_folder_picked_from_web)
	var window = JavaScriptBridge.get_interface("window")
	window.harnessFolderPicked = folder_callback
	JavaScriptBridge.eval("""
		(async () => {
			try {
				if (!window.showDirectoryPicker) {
					window.harnessFolderPicked("__unsupported__");
					return;
				}
				const handle = await window.showDirectoryPicker({mode: "readwrite"});
				window.harnessWorkspaceHandle = handle;
				window.harnessFolderPicked(handle.name);
			} catch (error) {
				window.harnessFolderPicked(error.name === "AbortError" ? "__cancelled__" : "__error__");
			}
		})();
	""", true)

func _folder_picked_from_web(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var value := str(arguments[0])
	if value == "__cancelled__":
		_folder_selection_canceled()
	elif value == "__unsupported__":
		folder_label.text = "此浏览器不支持选择文件夹，可先体验演示餐厅"
		folder_label.add_theme_color_override("font_color", UI.ACCENT)
	elif value == "__error__":
		folder_label.text = "无法打开文件夹，请重试"
		folder_label.add_theme_color_override("font_color", UI.ACCENT)
	else:
		_folder_selected(value)

func _show_settings_status() -> void:
	if selected_folder.is_empty() or not _workspace_is_available(selected_folder):
		folder_selection_mode = "settings"
		folder_label.text = "设置前请选择本地餐厅文件夹"
		folder_label.add_theme_color_override("font_color", UI.MUTED)
		_select_folder()
		return
	_show_settings_panel()

func _close_settings() -> void:
	settings_layer.hide()

func _save_model_config() -> void:
	var model := model_input.text.strip_edges()
	var base_url := base_url_input.text.strip_edges()
	var api_key := api_key_input.text.strip_edges()
	if model.is_empty() or base_url.is_empty() or api_key.is_empty():
		settings_status.text = "模型、Base URL 和 API Key 都必须填写"
		settings_status.add_theme_color_override("font_color", UI.ACCENT)
		return
	var config := {
		"model": model,
		"base_url": base_url,
		"api_key": api_key,
	}
	if OS.has_feature("web"):
		settings_layer.set_loading(true)
		settings_status.text = "正在保存配置…"
		_write_model_config_web(JSON.stringify(config, "\t"))
		return
	var config_path := selected_folder.path_join(MODEL_CONFIG_FILENAME)
	if not store.save_model_config(selected_folder, config):
		settings_status.text = "无法写入配置文件，请检查文件夹权限"
		settings_status.add_theme_color_override("font_color", UI.ACCENT)
		return
	_model_config_saved(config_path)

func _write_model_config_web(config_text: String) -> void:
	config_write_callback = JavaScriptBridge.create_callback(_model_config_written_from_web)
	var window = JavaScriptBridge.get_interface("window")
	window.harnessConfigWritten = config_write_callback
	var encoded_text := JSON.stringify(config_text)
	JavaScriptBridge.eval("""
		(async () => {
			try {
				const handle = window.harnessWorkspaceHandle;
				if (!handle) throw new Error("missing-directory-handle");
				const fileHandle = await handle.getFileHandle("%s", {create: true});
				const writable = await fileHandle.createWritable();
				await writable.write(%s);
				await writable.close();
				window.harnessConfigWritten("ok");
			} catch (error) {
				window.harnessConfigWritten("error");
			}
		})();
	""" % [MODEL_CONFIG_FILENAME, encoded_text], true)

func _model_config_written_from_web(arguments: Array) -> void:
	settings_layer.set_loading(false)
	if not arguments.is_empty() and str(arguments[0]) == "ok":
		_model_config_saved("%s/%s" % [selected_folder, MODEL_CONFIG_FILENAME])
		return
	settings_status.text = "配置写入失败，请重新授权本地文件夹"
	settings_status.add_theme_color_override("font_color", UI.ACCENT)

func _model_config_saved(_path: String) -> void:
	settings_status.text = "配置已保存到当前餐厅文件夹"
	settings_status.add_theme_color_override("font_color", UI.GREEN)

func _set_hamster_running(should_run: bool) -> void:
	should_run = should_run and api.skills.is_enabled("hamster", "local-time")
	if restaurant_scene == null:
		return
	var generator := restaurant_scene.get_node_or_null("Furniture/ClockPlatform/HamsterGenerator")
	if generator == null:
		return
	var wheel := generator.get_node_or_null("RotatingWheel")
	var hamster := generator.get_node_or_null("Hamster")
	if wheel != null:
		if should_run and wheel.has_method("start"):
			wheel.start()
		elif not should_run and wheel.has_method("stop"):
			wheel.stop()
	if hamster != null:
		if should_run and hamster.has_method("play"):
			hamster.play()
		elif not should_run and hamster.has_method("stop"):
			hamster.stop()

func _timekeeper_working_changed(working: bool) -> void:
	_set_hamster_running(working and game_started)

func _workspace_display_name(folder: String) -> String:
	if folder.is_empty():
		return "Harness Restaurant"
	var display_name := folder.trim_suffix("/").get_file()
	return display_name if not display_name.is_empty() else folder

func _folder_selection_canceled() -> void:
	folder_selection_mode = "open"
	_load_workspace_preference()
