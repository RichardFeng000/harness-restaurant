extends Control

const HarnessApi = preload("res://backend/harness_api.gd")
const LayeredRestaurant = preload("res://frontend/scenes/restaurant_v4.tscn")

const COLOR_BG := Color("#08101f")
const COLOR_PANEL := Color("#101b2f")
const COLOR_PANEL_LIGHT := Color("#17243b")
const COLOR_CYAN := Color("#58e6d9")
const COLOR_BLUE := Color("#5a8cff")
const COLOR_TEXT := Color("#e9f1ff")
const COLOR_MUTED := Color("#8290aa")
const COLOR_GREEN := Color("#62e59c")
const COLOR_ORANGE := Color("#ffb45c")

var api
var folder_callback
var selected_folder := ""
var game_time := 0.0
var active_run := false
var run_progress := 0.0
var task_count := 3
var energy := 84
var game_started := false

var menu_layer: Control
var game_layer: Control
var pause_layer: Control
var folder_label: Label
var activity_log: RichTextLabel
var progress_bar: ProgressBar
var run_button: Button
var file_dialog: FileDialog

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	api = HarnessApi.new()
	api.request("POST", "/api/v2/bootstrap")
	resized.connect(queue_redraw)
	_build_menu()
	_build_game()
	_build_file_dialog()
	game_layer.hide()
	queue_redraw()

func _process(delta: float) -> void:
	game_time += delta
	if active_run:
		run_progress = minf(run_progress + delta * 18.0, 100.0)
		progress_bar.value = run_progress
		if run_progress >= 100.0:
			_finish_agent_run()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	var spacing := 54.0
	var drift := fmod(game_time * 8.0, spacing)
	for x in range(-1, int(size.x / spacing) + 2):
		var px := x * spacing + drift
		draw_line(Vector2(px, 0), Vector2(px, size.y), Color(0.18, 0.34, 0.55, 0.10), 1.0)
	for y in range(-1, int(size.y / spacing) + 2):
		var py := y * spacing + drift * 0.35
		draw_line(Vector2(0, py), Vector2(size.x, py), Color(0.18, 0.34, 0.55, 0.10), 1.0)
	for index in range(12):
		var px := fmod(index * 173.0 + game_time * (7.0 + index), size.x + 80.0) - 40.0
		var py := fmod(index * 97.0 + sin(game_time * 0.6 + index) * 30.0, size.y)
		draw_circle(Vector2(px, py), 2.5, Color(COLOR_CYAN, 0.38))

func _build_menu() -> void:
	menu_layer = Control.new()
	menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu_layer)

	var top := HBoxContainer.new()
	top.position = Vector2(44, 34)
	top.size = Vector2(size.x - 88, 48)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 44
	top.offset_right = -44
	menu_layer.add_child(top)

	var brand := Label.new()
	brand.text = "HARNESS  /  V2"
	brand.add_theme_font_size_override("font_size", 21)
	brand.add_theme_color_override("font_color", COLOR_CYAN)
	top.add_child(brand)
	top.add_spacer(false)
	var build := Label.new()
	build.text = "LOCAL SIMULATION  •  BUILD 0.1"
	build.add_theme_font_size_override("font_size", 12)
	build.add_theme_color_override("font_color", COLOR_MUTED)
	top.add_child(build)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-310, -270)
	center.size = Vector2(620, 540)
	center.add_theme_constant_override("separation", 18)
	menu_layer.add_child(center)

	var eyebrow := Label.new()
	eyebrow.text = "CO-OP KITCHEN SIMULATION"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", COLOR_CYAN)
	center.add_child(eyebrow)

	var title := Label.new()
	title.text = "PREP. COOK. SERVE."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择本地餐厅档案，指挥你的厨师团队\n备菜、烹饪，并完成顾客点单。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	center.add_child(subtitle)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 290)
	card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, 18, Color(0.25, 0.42, 0.66, 0.45)))
	center.add_child(card)
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 13)
	card_content.set("theme_override_constants/margin_left", 20)
	card.add_child(card_content)

	var card_title := Label.new()
	card_title.text = "MAIN MENU"
	card_title.add_theme_font_size_override("font_size", 13)
	card_title.add_theme_color_override("font_color", COLOR_MUTED)
	card_content.add_child(card_title)

	folder_label = Label.new()
	folder_label.text = "No folder selected"
	folder_label.add_theme_font_size_override("font_size", 18)
	folder_label.add_theme_color_override("font_color", COLOR_TEXT)
	card_content.add_child(folder_label)

	var new_game := _button("新游戏", COLOR_CYAN, Color("#071719"))
	new_game.custom_minimum_size = Vector2(0, 48)
	new_game.pressed.connect(_new_game)
	card_content.add_child(new_game)

	var continue_game := _button("继续游戏", COLOR_PANEL_LIGHT, COLOR_TEXT)
	continue_game.custom_minimum_size = Vector2(0, 46)
	continue_game.pressed.connect(_continue_game)
	card_content.add_child(continue_game)

	var choose := _button("本地位置", COLOR_PANEL_LIGHT, COLOR_TEXT)
	choose.custom_minimum_size = Vector2(0, 46)
	choose.pressed.connect(_select_folder)
	card_content.add_child(choose)

	var settings := _button("设置", COLOR_PANEL_LIGHT, COLOR_TEXT)
	settings.custom_minimum_size = Vector2(0, 46)
	settings.pressed.connect(_show_settings_status)
	card_content.add_child(settings)

	var hint := Label.new()
	hint.text = "Your files stay on this device. Harness never uploads the folder."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	center.add_child(hint)

func _build_game() -> void:
	game_layer = Control.new()
	game_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.clip_contents = true
	add_child(game_layer)

	var restaurant := LayeredRestaurant.instantiate()
	restaurant.name = "RestaurantScene"
	game_layer.add_child(restaurant)

	var pause_button := _button("Ⅱ", Color(0.05, 0.09, 0.15, 0.88), COLOR_TEXT)
	pause_button.z_index = 100
	pause_button.position = Vector2(24, 22)
	pause_button.size = Vector2(52, 48)
	pause_button.add_theme_font_size_override("font_size", 22)
	pause_button.pressed.connect(_pause_game)
	game_layer.add_child(pause_button)

	run_button = _button("开始烹饪", COLOR_CYAN, Color("#071719"))
	run_button.z_index = 100
	run_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	run_button.offset_left = 400
	run_button.offset_right = -400
	run_button.offset_top = -76
	run_button.offset_bottom = -26
	run_button.pressed.connect(_start_agent_run)
	game_layer.add_child(run_button)

	progress_bar = ProgressBar.new()
	progress_bar.z_index = 100
	progress_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	progress_bar.offset_left = 400
	progress_bar.offset_right = -400
	progress_bar.offset_top = -20
	progress_bar.offset_bottom = -12
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	game_layer.add_child(progress_bar)

	activity_log = RichTextLabel.new()
	activity_log.bbcode_enabled = true
	activity_log.set_anchors_preset(Control.PRESET_TOP_LEFT)
	activity_log.position = Vector2(88, 25)
	activity_log.size = Vector2(360, 54)
	activity_log.add_theme_font_size_override("normal_font_size", 12)
	activity_log.text = "[color=#58e6d9]厨房准备完毕[/color]\n厨师等待第一份订单"
	game_layer.add_child(activity_log)
	activity_log.hide()

	_build_pause_layer()

func _build_pause_layer() -> void:
	pause_layer = Control.new()
	pause_layer.z_index = 200
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_layer.add_child(pause_layer)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.72)
	pause_layer.add_child(shade)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-190, -178)
	card.size = Vector2(380, 356)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#101b2f"), 18, Color(COLOR_CYAN, 0.55)))
	pause_layer.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	var title := Label.new()
	title.text = "游戏暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(title)

	var save_button := _button("保存进度", COLOR_CYAN, Color("#071719"))
	save_button.custom_minimum_size.y = 52
	save_button.pressed.connect(_save_progress)
	box.add_child(save_button)

	var menu_button := _button("返回菜单", COLOR_PANEL_LIGHT, COLOR_TEXT)
	menu_button.custom_minimum_size.y = 52
	menu_button.pressed.connect(_back_to_menu)
	box.add_child(menu_button)

	var resume_button := _button("返回游戏", COLOR_PANEL_LIGHT, COLOR_TEXT)
	resume_button.custom_minimum_size.y = 52
	resume_button.pressed.connect(_resume_game)
	box.add_child(resume_button)

	pause_layer.hide()

func _build_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "选择本地餐厅档案"
	file_dialog.dir_selected.connect(_open_workspace)
	add_child(file_dialog)

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
					window.harnessFolderPicked(["__unsupported__"]);
					return;
				}
				const handle = await window.showDirectoryPicker({mode: "readwrite"});
				window.harnessWorkspaceHandle = handle;
				window.harnessFolderPicked([handle.name]);
			} catch (error) {
				if (error.name !== "AbortError") {
					window.harnessFolderPicked(["__error__"]);
				}
			}
		})();
	""", true)

func _folder_picked_from_web(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var value := str(arguments[0])
	if value == "__unsupported__":
		folder_label.text = "Folder API unavailable — use Chrome or Edge"
		folder_label.add_theme_color_override("font_color", COLOR_ORANGE)
	elif value == "__error__":
		folder_label.text = "Could not open folder"
		folder_label.add_theme_color_override("font_color", Color("#ff718c"))
	else:
		_open_workspace(value)

func _open_workspace(folder: String) -> void:
	selected_folder = folder.get_file() if not folder.is_empty() else "Harness Restaurant"
	folder_label.text = selected_folder
	menu_layer.hide()
	game_layer.show()
	pause_layer.hide()
	run_button.visible = not game_started
	progress_bar.visible = not game_started
	activity_log.text = "[color=#58e6d9]%s[/color]\n餐厅已开门，厨房准备完成" % selected_folder

func _new_game() -> void:
	game_started = false
	task_count = 3
	energy = 84
	run_button.text = "开始烹饪"
	run_button.disabled = false
	progress_bar.value = 0
	_open_workspace("新餐厅")

func _back_to_menu() -> void:
	pause_layer.hide()
	game_layer.hide()
	menu_layer.show()
	active_run = false
	run_button.disabled = false

func _continue_game() -> void:
	if not FileAccess.file_exists("user://restaurant_save.json"):
		_open_workspace(selected_folder if not selected_folder.is_empty() else "上次的餐厅")
		return
	var save_file := FileAccess.open("user://restaurant_save.json", FileAccess.READ)
	var data = JSON.parse_string(save_file.get_as_text())
	if data is Dictionary:
		selected_folder = str(data.get("restaurant", "上次的餐厅"))
		task_count = int(data.get("task_count", 3))
		energy = int(data.get("energy", 84))
		game_started = bool(data.get("game_started", true))
	_open_workspace(selected_folder)
	if game_started:
		run_button.hide()
		progress_bar.hide()
		activity_log.text = "[color=#62e59c]进度已恢复[/color]\n欢迎回到餐厅"

func _show_settings_status() -> void:
	folder_label.text = "Settings: audio on • window 1280×720"
	folder_label.add_theme_color_override("font_color", COLOR_CYAN)

func _start_agent_run() -> void:
	game_started = true
	active_run = false
	run_button.hide()
	progress_bar.hide()
	activity_log.text = "[color=#5a8cff]游戏开始[/color]\n餐厅正式开始工作"

func _pause_game() -> void:
	pause_layer.show()

func _resume_game() -> void:
	pause_layer.hide()

func _save_progress() -> void:
	var save_data := {
		"restaurant": selected_folder,
		"task_count": task_count,
		"energy": energy,
		"game_started": game_started,
	}
	var save_file := FileAccess.open("user://restaurant_save.json", FileAccess.WRITE)
	if save_file == null:
		return
	save_file.store_string(JSON.stringify(save_data))
	activity_log.text = "[color=#62e59c]保存成功[/color]\n餐厅进度已保存到本地"

func _finish_agent_run() -> void:
	active_run = false
	task_count = maxi(task_count - 1, 0)
	energy = maxi(energy - 9, 0)
	run_button.disabled = task_count <= 0
	run_button.text = "全部订单已完成" if task_count <= 0 else "制作下一份订单"
	activity_log.append_text("\n[color=#62e59c]SERVED[/color]  菜品已出餐，餐厅进度已保存。")

func _stat_card(parent: Container, label_text: String, value: String, accent: Color) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 86
	card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, 12, Color(accent, 0.35)))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var caption := Label.new()
	caption.text = label_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", COLOR_MUTED)
	box.add_child(caption)
	var number := Label.new()
	number.text = value
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 23)
	number.add_theme_color_override("font_color", accent)
	box.add_child(number)
	return number

func _section(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, 16, Color(0.25, 0.42, 0.66, 0.35)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_MUTED)
	box.add_child(title)
	return panel

func _add_task(parent: VBoxContainer, title: String, meta: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size.y = 72
	card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_LIGHT, 10, Color(color, 0.3)))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(title_label)
	var meta_label := Label.new()
	meta_label.text = meta
	meta_label.add_theme_font_size_override("font_size", 11)
	meta_label.add_theme_color_override("font_color", color)
	box.add_child(meta_label)

func _button(text: String, color: Color, font_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_stylebox_override("normal", _panel_style(color, 10, Color(color, 0.8)))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.08), 10, Color.WHITE))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.08), 10, Color.WHITE))
	return button

func _panel_style(color: Color, radius: int, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	return style
