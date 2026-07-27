class_name SystemService
extends RefCounted

const VERSION := "2.0.0"

var repository

func _init(system_repository) -> void:
	repository = system_repository

func health() -> Dictionary:
	return _ok({
		"status": "ok",
		"service": "harness-v2",
		"version": VERSION,
		"database": "fake-json",
	})

func info() -> Dictionary:
	return _ok({
		"name": "Harness V2",
		"version": VERSION,
		"environment": "local",
		"features": ["tenant", "chat", "knowledge", "memory", "run"],
		"table_counts": repository.table_counts(),
	})

func save_database() -> Dictionary:
	if not repository.save_database():
		return _error("SAVE_FAILED", "假数据库保存失败", 500)
	return _ok({"saved": true})

func _ok(data: Variant, status: int = 200) -> Dictionary:
	return {"ok": true, "status": status, "data": data}

func _error(code: String, message: String, status: int) -> Dictionary:
	return {"ok": false, "status": status, "error": {"code": code, "message": message}}

