extends ScrollContainer
## Role-aware message bubbles, sized to the usable width of a book page.

const UI = preload("res://frontend/ui/kitchen_theme.gd")
const FONT_SIZE := 14
const PADDING := 10
const MAX_WIDTH_RATIO := 0.84

var rows: VBoxContainer
var _entries: Array = []
var _layout_pending := false
var _follow_latest := false
var _render_generation := 0

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.y = 70
	rows = VBoxContainer.new()
	rows.name = "MessageRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	add_child(rows)
	rows.resized.connect(_queue_layout)
	resized.connect(_queue_layout)
	get_v_scroll_bar().changed.connect(_scroll_to_latest)

func render_entries(entries: Array) -> void:
	_entries = entries.duplicate(true)
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for index in _entries.size():
		var entry: Dictionary = _entries[index]
		var is_user := str(entry.get("role", "user")) != "assistant"
		var row := HBoxContainer.new()
		row.name = "Message%d" % index
		row.set_meta("role", "user" if is_user else "assistant")
		row.add_theme_constant_override("separation", 0)
		rows.add_child(row)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_user:
			row.add_child(spacer)
		var bubble := PanelContainer.new()
		bubble.name = "Bubble"
		bubble.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var fill := Color(0.53, 0.26, 0.10, 0.16) if is_user else Color(1, 0.98, 0.90, 0.36)
		var border := Color(0.49, 0.28, 0.13, 0.20)
		bubble.add_theme_stylebox_override("panel", UI.style(fill, 8, border, PADDING))
		row.add_child(bubble)
		var body := RichTextLabel.new()
		body.name = "Body"
		body.text = str(entry.get("text", ""))
		body.bbcode_enabled = false
		body.selection_enabled = true
		body.fit_content = true
		body.scroll_active = false
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("normal_font_size", FONT_SIZE)
		body.add_theme_color_override("default_color", UI.INK)
		body.add_theme_constant_override("line_separation", 3)
		body.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		body.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		body.tooltip_text = "你" if is_user else "模型"
		bubble.add_child(body)
		if not is_user:
			row.add_child(spacer)
	_follow_latest = true
	_render_generation += 1
	_queue_layout()
	_finish_follow.call_deferred(_render_generation)

func get_parsed_text() -> String:
	var values := PackedStringArray()
	for entry: Dictionary in _entries:
		values.append(str(entry.get("text", "")))
	return "\n\n".join(values)

func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_layout_bubbles.call_deferred()

func _layout_bubbles() -> void:
	_layout_pending = false
	var available := maxf(1.0, minf(rows.size.x, size.x))
	var max_width := maxf(40.0, floorf(available * MAX_WIDTH_RATIO))
	for row: HBoxContainer in rows.get_children():
		var bubble: PanelContainer = row.get_node("Bubble")
		var body: RichTextLabel = bubble.get_node("Body")
		var font := body.get_theme_font("normal_font")
		var text_width := 0.0
		for line: String in body.text.split("\n"):
			text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
		var width := clampf(ceilf(text_width) + PADDING * 2 + 2, 40.0, max_width)
		bubble.custom_minimum_size.x = width
		body.custom_minimum_size.x = width - PADDING * 2
	_scroll_to_latest.call_deferred()

func _scroll_to_latest() -> void:
	if _follow_latest:
		scroll_vertical = int(get_v_scroll_bar().max_value)

func _finish_follow(generation: int) -> void:
	# Wrapping, container sizing and scrollbar sizing can settle on different frames.
	# Follow those updates until the final height stabilizes, then allow free scrolling.
	var previous_height := -1.0
	var stable_frames := 0
	for frame in 8:
		await get_tree().process_frame
		if generation != _render_generation:
			return
		if not _layout_pending and is_equal_approx(rows.size.y, previous_height):
			stable_frames += 1
		else:
			stable_frames = 0
		previous_height = rows.size.y
		_scroll_to_latest()
		if stable_frames >= 2:
			break
	_follow_latest = false
