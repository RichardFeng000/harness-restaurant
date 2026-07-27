extends Control

const HarnessApi = preload("res://backend/harness_api.gd")

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

var menu_layer: Control
var game_layer: Control
var folder_label: Label
var activity_log: RichTextLabel
var progress_bar: ProgressBar
var run_button: Button
var task_label: Label
var energy_label: Label
var file_dialog: FileDialog

func _ready() -> void:
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
	center.position = Vector2(-310, -230)
	center.size = Vector2(620, 460)
	center.add_theme_constant_override("separation", 18)
	menu_layer.add_child(center)

	var eyebrow := Label.new()
	eyebrow.text = "AGENT OPERATIONS CONSOLE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", COLOR_CYAN)
	center.add_child(eyebrow)

	var title := Label.new()
	title.text = "BUILD. RUN. REMEMBER."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Choose a local workspace and command your agent crew\nthrough chats, knowledge and memory."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	center.add_child(subtitle)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 168)
	card.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, 18, Color(0.25, 0.42, 0.66, 0.45)))
	center.add_child(card)
	var card_content := VBoxContainer.new()
	card_content.add_theme_constant_override("separation", 13)
	card_content.set("theme_override_constants/margin_left", 20)
	card.add_child(card_content)

	var card_title := Label.new()
	card_title.text = "LOCAL WORKSPACE"
	card_title.add_theme_font_size_override("font_size", 13)
	card_title.add_theme_color_override("font_color", COLOR_MUTED)
	card_content.add_child(card_title)

	folder_label = Label.new()
	folder_label.text = "No folder selected"
	folder_label.add_theme_font_size_override("font_size", 18)
	folder_label.add_theme_color_override("font_color", COLOR_TEXT)
	card_content.add_child(folder_label)

	var choose := _button("SELECT LOCAL FOLDER", COLOR_CYAN, Color("#071719"))
	choose.custom_minimum_size = Vector2(0, 54)
	choose.pressed.connect(_select_folder)
	card_content.add_child(choose)

	var demo := _button("ENTER DEMO WORKSPACE", COLOR_PANEL_LIGHT, COLOR_TEXT)
	demo.custom_minimum_size = Vector2(0, 48)
	demo.pressed.connect(func(): _open_workspace("Harness Demo"))
	center.add_child(demo)

	var hint := Label.new()
	hint.text = "Your files stay on this device. Harness never uploads the folder."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	center.add_child(hint)

func _build_game() -> void:
	game_layer = Control.new()
	game_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_layer)

	var shell := VBoxContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 28
	shell.offset_top = 24
	shell.offset_right = -28
	shell.offset_bottom = -24
	shell.add_theme_constant_override("separation", 16)
	game_layer.add_child(shell)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 54
	shell.add_child(header)
	var logo := Label.new()
	logo.text = "HARNESS / CONTROL ROOM"
	logo.add_theme_font_size_override("font_size", 20)
	logo.add_theme_color_override("font_color", COLOR_CYAN)
	header.add_child(logo)
	header.add_spacer(false)
	var workspace := Label.new()
	workspace.name = "WorkspaceName"
	workspace.add_theme_color_override("font_color", COLOR_MUTED)
	header.add_child(workspace)
	var back := _button("MENU", COLOR_PANEL_LIGHT, COLOR_TEXT)
	back.custom_minimum_size = Vector2(88, 38)
	back.pressed.connect(_back_to_menu)
	header.add_child(back)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 12)
	shell.add_child(stats)
	task_label = _stat_card(stats, "ACTIVE TASKS", str(task_count), COLOR_BLUE)
	energy_label = _stat_card(stats, "AGENT ENERGY", "%d%%" % energy, COLOR_GREEN)
	_stat_card(stats, "MEMORIES", "12", COLOR_CYAN)
	_stat_card(stats, "KNOWLEDGE", "4 DOCS", COLOR_ORANGE)

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 350
	shell.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 330
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	var mission := _section("MISSION QUEUE")
	left.add_child(mission)
	var mission_box := mission.get_child(0) as VBoxContainer
	_add_task(mission_box, "INDEX RECIPE BOOK", "Knowledge • PDF", COLOR_ORANGE)
	_add_task(mission_box, "MAP WORKSPACE", "System • Local", COLOR_CYAN)
	_add_task(mission_box, "BUILD MEMORY GRAPH", "Memory • Agent", COLOR_BLUE)

	run_button = _button("RUN NEXT AGENT", COLOR_CYAN, Color("#071719"))
	run_button.custom_minimum_size.y = 52
	run_button.pressed.connect(_start_agent_run)
	left.add_child(run_button)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var map_panel := PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, 16, Color(0.25, 0.42, 0.66, 0.35)))
	right.add_child(map_panel)
	var map := AgentMap.new()
	map.name = "AgentMap"
	map.custom_minimum_size = Vector2(500, 300)
	map_panel.add_child(map)

	var console := _section("ACTIVITY STREAM")
	console.custom_minimum_size.y = 190
	right.add_child(console)
	var console_box := console.get_child(0) as VBoxContainer
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 6
	console_box.add_child(progress_bar)
	activity_log = RichTextLabel.new()
	activity_log.bbcode_enabled = true
	activity_log.fit_content = false
	activity_log.scroll_active = true
	activity_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	activity_log.add_theme_font_size_override("normal_font_size", 13)
	activity_log.text = "[color=#8290aa]SYSTEM[/color]  Control room ready.\n[color=#58e6d9]DATABASE[/color]  CSV workspace connected."
	console_box.add_child(activity_log)

func _build_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Harness Workspace"
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
	selected_folder = folder.get_file() if not folder.is_empty() else "Harness Workspace"
	folder_label.text = selected_folder
	var workspace := game_layer.find_child("WorkspaceName", true, false) as Label
	workspace.text = "WORKSPACE  /  %s" % selected_folder.to_upper()
	menu_layer.hide()
	game_layer.show()
	activity_log.text = "[color=#58e6d9]WORKSPACE[/color]  %s mounted locally.\n[color=#8290aa]SYSTEM[/color]  Harness agents standing by." % selected_folder

func _back_to_menu() -> void:
	game_layer.hide()
	menu_layer.show()
	active_run = false
	run_button.disabled = false

func _start_agent_run() -> void:
	if active_run or task_count <= 0:
		return
	active_run = true
	run_progress = 0.0
	run_button.disabled = true
	run_button.text = "AGENT RUNNING..."
	activity_log.append_text("\n[color=#5a8cff]RUN[/color]  Agent dispatched to workspace.")

func _finish_agent_run() -> void:
	active_run = false
	task_count = maxi(task_count - 1, 0)
	energy = maxi(energy - 9, 0)
	task_label.text = str(task_count)
	energy_label.text = "%d%%" % energy
	run_button.disabled = task_count <= 0
	run_button.text = "ALL TASKS COMPLETE" if task_count <= 0 else "RUN NEXT AGENT"
	activity_log.append_text("\n[color=#62e59c]COMPLETE[/color]  Task resolved. Memory checkpoint saved.")

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

class AgentMap extends Control:
	var time := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var room := Rect2(Vector2(24, 20), size - Vector2(48, 40))
		draw_rect(room, Color("#1a2940"))
		var tile := 34.0
		for x in range(int(room.size.x / tile) + 1):
			for y in range(int(room.size.y / tile) + 1):
				var tile_rect := Rect2(room.position + Vector2(x, y) * tile, Vector2(tile, tile))
				var tile_color := Color("#263a50") if (x + y) % 2 == 0 else Color("#203247")
				draw_rect(tile_rect.intersection(room), tile_color)

		# Thick room walls, inspired by a compact top-down co-op workspace.
		draw_rect(Rect2(room.position, Vector2(room.size.x, 18)), Color("#6e3c34"))
		draw_rect(Rect2(room.position + Vector2(0, room.size.y - 18), Vector2(room.size.x, 18)), Color("#6e3c34"))
		draw_rect(Rect2(room.position, Vector2(18, room.size.y)), Color("#6e3c34"))
		draw_rect(Rect2(room.position + Vector2(room.size.x - 18, 0), Vector2(18, room.size.y)), Color("#6e3c34"))

		var center := room.get_center()
		var stations := [
			Rect2(room.position + Vector2(48, 44), Vector2(150, 62)),
			Rect2(room.position + Vector2(room.size.x - 198, 44), Vector2(150, 62)),
			Rect2(room.position + Vector2(48, room.size.y - 106), Vector2(150, 62)),
			Rect2(room.position + Vector2(room.size.x - 198, room.size.y - 106), Vector2(150, 62)),
		]
		var station_colors := [COLOR_ORANGE, COLOR_CYAN, COLOR_BLUE, COLOR_GREEN]
		for index in range(stations.size()):
			var station: Rect2 = stations[index]
			draw_rect(station, Color("#a86439"))
			draw_rect(station.grow(-7), Color("#d99a4f"))
			for slot in range(3):
				var slot_pos := station.position + Vector2(28 + slot * 47, station.size.y * 0.5)
				draw_circle(slot_pos, 13, Color("#162338"))
				draw_arc(slot_pos, 13, 0, TAU, 24, station_colors[index], 3)

		# Central task conveyor.
		var conveyor := Rect2(center - Vector2(34, room.size.y * 0.32), Vector2(68, room.size.y * 0.64))
		draw_rect(conveyor, Color("#bb743d"))
		draw_rect(conveyor.grow(-8), Color("#e0a04f"))
		for step in range(5):
			var item_pos := Vector2(center.x, conveyor.position.y + 35 + step * (conveyor.size.y - 70) / 4.0)
			var accent: Color = [COLOR_CYAN, COLOR_BLUE, COLOR_ORANGE][step % 3]
			draw_circle(item_pos, 17, Color("#132238"))
			draw_circle(item_pos, 7, accent)

		# Two animated agent workers moving between stations.
		var agent_a_start: Vector2 = stations[0].get_center() + Vector2(0, 52)
		var agent_a_end: Vector2 = conveyor.get_center() + Vector2(-68, 0)
		var agent_b_start: Vector2 = stations[3].get_center() - Vector2(0, 52)
		var agent_b_end: Vector2 = conveyor.get_center() + Vector2(68, 0)
		var phase := (sin(time * 1.25) + 1.0) * 0.5
		_draw_agent(agent_a_start.lerp(agent_a_end, phase), COLOR_CYAN, -1.0)
		_draw_agent(agent_b_start.lerp(agent_b_end, 1.0 - phase), COLOR_ORANGE, 1.0)

	func _draw_agent(position: Vector2, accent: Color, facing: float) -> void:
		draw_circle(position + Vector2(0, 10), 17, Color(0, 0, 0, 0.22))
		draw_circle(position, 18, Color("#e7eef8"))
		draw_circle(position + Vector2(0, 3), 13, accent)
		draw_circle(position + Vector2(facing * 7, -5), 4, Color("#08101f"))
		draw_arc(position, 21 + sin(time * 3.0) * 2.0, 0, TAU, 28, Color(accent, 0.45), 2)
