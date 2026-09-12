extends VBoxContainer

const KitchenTheme = preload("res://frontend/ui/kitchen_theme.gd")

@export var page_title := "知识库"
@export var page_description := "集中整理餐厅的菜谱、文档与操作指引。"
@export var empty_description := "资料整理与检索尚未开放。"
@export var monogram := "知"


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(KitchenTheme.label(page_title, 23))
	add_child(KitchenTheme.label("尚未开放", 14, KitchenTheme.MUTED))
