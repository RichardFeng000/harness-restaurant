class_name MemoryRepository
extends RefCounted

var db

func _init(database) -> void:
	db = database

func create(values: Dictionary) -> Dictionary:
	return db.insert("memories", values)

func list(tenant_id: String, filters: Dictionary) -> Array:
	return db.find_many("memories", filters, tenant_id)
