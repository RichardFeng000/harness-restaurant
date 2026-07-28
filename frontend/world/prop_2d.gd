@tool
extends StaticBody2D
class_name RestaurantProp2D

enum Kind { TABLE, CHAIR, COUNTER, STOVE, SINK, FRIDGE, DESK, COMPUTER, BENCH, PODIUM, DOOR, WC_DOOR }

@export var kind: Kind = Kind.TABLE:
	set(value):
		kind = value
		queue_redraw()
@export var prop_size := Vector2(100, 60):
	set(value):
		prop_size = value
		queue_redraw()
@export var accent := Color("#c95943"):
	set(value):
		accent = value
		queue_redraw()
@export var use_atlas_visual := true:
	set(value):
		use_atlas_visual = value
		queue_redraw()
@export_range(0.3, 2.0, 0.05) var visual_scale := 1.0:
	set(value):
		visual_scale = value
		queue_redraw()

func _ready() -> void:
	_ensure_collision()
	queue_redraw()

func _ensure_collision() -> void:
	if get_node_or_null("CollisionShape2D"):
		return
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = prop_size
	collision.shape = shape
	add_child(collision)

func _draw() -> void:
	var rect := Rect2(-prop_size * 0.5, prop_size)
	var atlas_texture := _atlas_texture()
	if use_atlas_visual and atlas_texture:
		var visual_size := Vector2(prop_size.x * 1.65, prop_size.y * 2.15) * visual_scale
		var visual_rect := Rect2(Vector2(-visual_size.x * 0.5, -visual_size.y * 0.72), visual_size)
		draw_texture_rect(atlas_texture, visual_rect, false)
		return
	match kind:
		Kind.TABLE:
			draw_style_box(_box(Color("#d9a04d"), 10, Color("#7a3d24")), rect)
			_draw_checkered_cloth(rect.grow(-7))
		Kind.CHAIR:
			draw_style_box(_box(accent, 9, Color("#682e24")), rect)
			draw_line(Vector2(-prop_size.x * 0.3, 0), Vector2(prop_size.x * 0.3, 0), Color("#f3aa78"), 3)
		Kind.COUNTER:
			draw_style_box(_box(Color("#df9b3f"), 6, Color("#78391f")), rect)
			draw_line(Vector2(rect.position.x, -6), Vector2(rect.end.x, -6), Color("#ffe0a0"), 3)
		Kind.STOVE:
			draw_style_box(_box(Color("#39414b"), 6, Color("#151a20")), rect)
			draw_circle(Vector2(-prop_size.x * 0.23, 0), 15, Color("#15171a"))
			draw_circle(Vector2(prop_size.x * 0.23, 0), 15, Color("#15171a"))
		Kind.SINK:
			draw_style_box(_box(Color("#aebbc1"), 6, Color("#53646b")), rect)
			draw_rect(Rect2(-prop_size.x * 0.28, -prop_size.y * 0.28, prop_size.x * 0.56, prop_size.y * 0.56), Color("#647e86"))
		Kind.FRIDGE:
			draw_style_box(_box(Color("#318c91"), 7, Color("#174b52")), rect)
			draw_line(Vector2(0, rect.position.y), Vector2(0, rect.end.y), Color("#b9e0d8"), 2)
		Kind.DESK:
			draw_style_box(_box(Color("#8b502c"), 5, Color("#482516")), rect)
		Kind.COMPUTER:
			draw_style_box(_box(Color("#202a35"), 4, Color("#84d9e1")), rect)
			draw_rect(rect.grow(-6), Color("#173e4c"))
		Kind.BENCH:
			draw_style_box(_box(Color("#b94c44"), 12, Color("#6b2925")), rect)
		Kind.PODIUM:
			draw_style_box(_box(Color("#7e4728"), 5, Color("#402216")), rect)
		Kind.DOOR, Kind.WC_DOOR:
			draw_style_box(_box(Color("#6d3b24"), 4, Color("#30180f")), rect)
			draw_circle(Vector2(prop_size.x * 0.28, 0), 3, Color("#e2b14c"))
			if kind == Kind.WC_DOOR:
				draw_string(ThemeDB.fallback_font, Vector2(-13, 5), "WC", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f2c65d"))

func _atlas_texture() -> AtlasTexture:
	var atlas_path := ""
	var cell := Vector2i.ZERO
	var cell_size := Vector2i.ZERO
	match kind:
		Kind.TABLE:
			atlas_path = "res://frontend/assets/atlases/restaurant-props.png"
			cell = Vector2i(0, 0)
			cell_size = Vector2i(362, 362)
		Kind.CHAIR:
			atlas_path = "res://frontend/assets/atlases/restaurant-props.png"
			cell = Vector2i(1, 0)
			cell_size = Vector2i(362, 362)
		Kind.BENCH:
			atlas_path = "res://frontend/assets/atlases/restaurant-props.png"
			cell = Vector2i(2, 0)
			cell_size = Vector2i(362, 362)
		Kind.PODIUM:
			atlas_path = "res://frontend/assets/atlases/restaurant-props.png"
			cell = Vector2i(3, 0)
			cell_size = Vector2i(362, 362)
		Kind.DESK:
			atlas_path = "res://frontend/assets/atlases/restaurant-props.png"
			cell = Vector2i(0, 1)
			cell_size = Vector2i(362, 362)
		Kind.COMPUTER:
			atlas_path = "res://frontend/assets/atlases/restaurant-props.png"
			cell = Vector2i(1, 1)
			cell_size = Vector2i(362, 362)
		Kind.WC_DOOR, Kind.DOOR:
			atlas_path = "res://frontend/assets/atlases/restaurant-props.png"
			cell = Vector2i(0, 2)
			cell_size = Vector2i(362, 362)
		Kind.COUNTER:
			atlas_path = "res://frontend/assets/atlases/kitchen-props.png"
			cell = Vector2i(0, 1)
			cell_size = Vector2i(384, 341)
		Kind.STOVE:
			atlas_path = "res://frontend/assets/atlases/kitchen-props.png"
			cell = Vector2i(1, 0)
			cell_size = Vector2i(384, 341)
		Kind.SINK:
			atlas_path = "res://frontend/assets/atlases/kitchen-props.png"
			cell = Vector2i(2, 0)
			cell_size = Vector2i(384, 341)
		Kind.FRIDGE:
			atlas_path = "res://frontend/assets/atlases/kitchen-props.png"
			cell = Vector2i(3, 0)
			cell_size = Vector2i(384, 341)
		_:
			return null
	var texture := AtlasTexture.new()
	texture.atlas = load(atlas_path)
	texture.region = Rect2(cell.x * cell_size.x, cell.y * cell_size.y, cell_size.x, cell_size.y)
	return texture

func _draw_checkered_cloth(rect: Rect2) -> void:
	var cell := 12.0
	for y in range(int(rect.size.y / cell) + 1):
		for x in range(int(rect.size.x / cell) + 1):
			var color := Color("#f3e0c4") if (x + y) % 2 == 0 else Color("#c94e42")
			draw_rect(Rect2(rect.position + Vector2(x, y) * cell, Vector2(cell, cell)), color)

func _box(color: Color, radius: int, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
