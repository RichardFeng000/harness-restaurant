@tool
extends CharacterBody2D
class_name RestaurantStaff2D

@export var role := "员工":
	set(value):
		role = value
		queue_redraw()
@export var uniform_color := Color("#58e6d9"):
	set(value):
		uniform_color = value
		queue_redraw()
@export var administrator := false:
	set(value):
		administrator = value
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var portrait := _role_texture()
	if portrait:
		draw_texture_rect(portrait, Rect2(-54, -118, 108, 144), false)
	var label := "%s · 管理员" % role if administrator else role
	var text_size := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var badge := Rect2(Vector2(-text_size.x * 0.5 - 7, -137), text_size + Vector2(14, 8))
	draw_style_box(_badge_style(), badge)
	draw_string(ThemeDB.fallback_font, Vector2(-text_size.x * 0.5, -122), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _role_texture() -> AtlasTexture:
	var index: int = int({
		"主厨": 0,
		"副厨": 1,
		"传菜员": 2,
		"服务员": 3,
		"收银员": 4,
		"主管": 5,
	}.get(role, 0))
	var texture := AtlasTexture.new()
	texture.atlas = load("res://frontend/assets/atlases/staff.png")
	texture.region = Rect2((index % 3) * 512, (index / 3) * 512, 512, 512)
	return texture

func _badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#402654") if administrator else Color(0.04, 0.08, 0.12, 0.92)
	style.border_color = Color("#e1b4ff") if administrator else uniform_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
