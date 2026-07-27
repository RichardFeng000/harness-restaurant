class_name SystemRepository
extends RefCounted

var db

func _init(database) -> void:
	db = database

func save_database() -> bool:
	return db.save()

func table_counts() -> Dictionary:
	var counts := {}
	for table in db.TABLES:
		counts[table] = db.count(table)
	return counts

