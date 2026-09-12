extends Control
## The HUD cover opens around the spine into the same artwork as the live pages.

signal finished
signal closing_finished
signal progress_changed(progress: float)

const COVER = preload("res://frontend/assets/runtime/v4/ui/harness/harness_book_closed_v1.png")
const SPREAD = preload("res://frontend/assets/runtime/v4/ui/harness/harness_book_open_v2_rect_trimmed.png")
const BookGeometry = preload("res://frontend/ui/book_geometry.gd")
const DURATION := 0.85
const CLOSE_DURATION := 0.65
const LIFT_END := 0.32
const TURN_END := 0.80
var progress := 0.0
var is_playing := false
var is_closing := false
var source_rect := Rect2()
var animation: Tween
var cover_region := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_STOP
	cover_region = Rect2(COVER.get_image().get_used_rect())
	hide()

func play(origin: Rect2) -> void:
	cancel()
	source_rect = origin
	is_playing = true
	show()
	_set_progress(0.0)
	animation = create_tween()
	animation.tween_method(_set_progress, 0.0, 1.0, DURATION)
	animation.tween_callback(_finish)

func play_close(destination: Rect2) -> void:
	if is_closing:
		return
	# Reverse an in-flight opening from its current pose, never from a full spread.
	var start_progress := progress if is_playing else 1.0
	cancel()
	source_rect = destination
	is_playing = true
	is_closing = true
	show()
	_set_progress(start_progress)
	animation = create_tween()
	animation.tween_method(_set_progress, start_progress, 0.0, maxf(0.1, CLOSE_DURATION * start_progress))
	animation.tween_callback(_finish_close)

func cancel() -> void:
	if animation != null and animation.is_valid():
		animation.kill()
	is_playing = false
	is_closing = false
	hide()

func _set_progress(value: float) -> void:
	progress = value
	progress_changed.emit(value)
	queue_redraw()

func _finish() -> void:
	is_playing = false
	hide()
	finished.emit()

func _finish_close() -> void:
	is_playing = false
	is_closing = false
	hide()
	closing_finished.emit()

func _draw() -> void:
	var reveal := smoothstep(TURN_END, 1.0, progress)
	var opacity := 1.0 - reveal
	var spread := BookGeometry.spread_rect(size)
	var right_page := Rect2(spread.position + Vector2(spread.size.x * 0.5, 0), Vector2(spread.size.x * 0.5, spread.size.y))
	if progress < LIFT_END:
		var lift := smoothstep(0.0, LIFT_END, progress)
		var source := _cover_art_rect(source_rect)
		var rect := Rect2(source.position.lerp(right_page.position, lift), source.size.lerp(right_page.size, lift))
		var shadow := Rect2(rect.position + Vector2(7, 12) * lift, rect.size)
		draw_texture_rect_region(COVER, shadow, cover_region, Color(0, 0, 0, 0.22 * sin(lift * PI)))
		draw_texture_rect_region(COVER, rect, cover_region)
		return
	if progress >= TURN_END:
		# There is no zoom or geometry change at the handoff to the working pages.
		draw_texture_rect(SPREAD, spread, false, Color(1, 1, 1, opacity))
		return
	var turn := smoothstep(LIFT_END, TURN_END, progress)
	var angle := turn * PI
	var right_region := Rect2(Vector2(SPREAD.get_width() * 0.5, 0), Vector2(SPREAD.get_width() * 0.5, SPREAD.get_height()))
	draw_texture_rect_region(SPREAD, right_page, right_region, Color(1, 1, 1, smoothstep(0.0, 0.16, turn)))
	# The right page stays still. Only the cover/left page rotates around the spine.
	var shadow_width := sin(angle) * right_page.size.x * 0.14
	for index in 12:
		var band := Rect2(right_page.position + Vector2(shadow_width * index / 12.0, 0), Vector2(shadow_width / 12.0 + 0.5, right_page.size.y))
		draw_rect(band, Color(0.16, 0.065, 0.025, 0.20 * sin(angle) * (1.0 - index / 12.0)))
	_draw_turning_leaf(right_page, angle)

func _draw_turning_leaf(right_page: Rect2, angle: float) -> void:
	var width := right_page.size.x * cos(angle)
	if absf(width) < 0.5:
		return
	var front := width > 0.0
	var texture: Texture2D = COVER if front else SPREAD
	var uv_start := cover_region.position / COVER.get_size() if front else Vector2(0.5, 0)
	var uv_end := cover_region.end / COVER.get_size() if front else Vector2(0, 1)
	# At the narrow edge of the turn, the leather face gives way to the paper face.
	# Strips retain the original paper grain while adding a small natural page bow.
	for index in 16:
		var from := index / 16.0
		var to := (index + 1) / 16.0
		var from_bow := _leaf_bow(from, angle, right_page.size.y)
		var to_bow := _leaf_bow(to, angle, right_page.size.y)
		var points := PackedVector2Array([
			right_page.position + Vector2(width * from, from_bow),
			right_page.position + Vector2(width * to, to_bow),
			right_page.position + Vector2(width * to, right_page.size.y - to_bow),
			right_page.position + Vector2(width * from, right_page.size.y - from_bow),
		])
		var u0 := lerpf(uv_start.x, uv_end.x, from)
		var u1 := lerpf(uv_start.x, uv_end.x, to)
		var uvs := PackedVector2Array([
			Vector2(u0, uv_start.y), Vector2(u1, uv_start.y),
			Vector2(u1, uv_end.y), Vector2(u0, uv_end.y),
		])
		var shade := 1.0 - sin(angle) * (0.12 + 0.10 * from)
		draw_polygon(points, PackedColorArray([Color(shade, shade, shade, 1)]), uvs, texture)

func _leaf_bow(fraction: float, angle: float, height: float) -> float:
	return sin(angle) * height * (0.035 * fraction + 0.012 * sin(fraction * PI))

func _cover_art_rect(bounds: Rect2) -> Rect2:
	# Removing transparent margins preserves the first frame's exact HUD appearance.
	var fitted := _fit_cover(bounds)
	var texture_scale := fitted.size / COVER.get_size()
	return Rect2(fitted.position + cover_region.position * texture_scale, cover_region.size * texture_scale)

func _fit_cover(bounds: Rect2) -> Rect2:
	var texture_size := COVER.get_size()
	var scale_factor := minf(bounds.size.x / texture_size.x, bounds.size.y / texture_size.y)
	var fitted_size := texture_size * scale_factor
	return Rect2(bounds.position + (bounds.size - fitted_size) * 0.5, fitted_size)
