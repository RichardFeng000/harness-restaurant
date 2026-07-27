class_name MemoryService
extends RefCounted

var repository

func _init(memory_repository) -> void:
	repository = memory_repository

func create_memory(tenant_id: String, input: Dictionary) -> Dictionary:
	var content := str(input.get("content", "")).strip_edges()
	var scope := str(input.get("scope", "user"))
	if content.is_empty() or scope not in ["user", "chat", "project", "agent"]:
		return _error("VALIDATION_ERROR", "记忆参数不合法")
	return _created(repository.create({
		"tenant_id": tenant_id,
		"scope": scope,
		"subject_id": str(input.get("subject_id", "")),
		"content": content,
		"importance": clampf(float(input.get("importance", 0.5)), 0.0, 1.0),
		"source": str(input.get("source", "manual")),
	}))

func list_memories(tenant_id: String, scope: String, subject_id: String) -> Dictionary:
	var filters := {}
	if not scope.is_empty():
		filters["scope"] = scope
	if not subject_id.is_empty():
		filters["subject_id"] = subject_id
	return _ok(repository.list(tenant_id, filters))

func _ok(data: Variant, status: int = 200) -> Dictionary:
	return {"ok": true, "status": status, "data": data}

func _created(data: Variant) -> Dictionary:
	return _ok(data, 201)

func _error(code: String, message: String, status: int = 400) -> Dictionary:
	return {"ok": false, "status": status, "error": {"code": code, "message": message}}
