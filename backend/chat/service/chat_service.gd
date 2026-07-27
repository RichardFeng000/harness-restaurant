class_name ChatService
extends RefCounted

var repository

func _init(chat_repository) -> void:
	repository = chat_repository

func create_chat(tenant_id: String, input: Dictionary) -> Dictionary:
	var project_id := str(input.get("project_id", ""))
	if not repository.project_exists(tenant_id, project_id):
		return _error("PROJECT_NOT_FOUND", "项目不存在", 404)
	return _created(repository.create_chat({
		"tenant_id": tenant_id,
		"project_id": project_id,
		"title": str(input.get("title", "新对话")),
		"status": "active",
	}))

func list_chats(tenant_id: String, project_id: String = "") -> Dictionary:
	var filters := {} if project_id.is_empty() else {"project_id": project_id}
	return _ok(repository.list_chats(tenant_id, filters))

func add_message(tenant_id: String, chat_id: String, input: Dictionary) -> Dictionary:
	if repository.get_chat(tenant_id, chat_id).is_empty():
		return _error("CHAT_NOT_FOUND", "对话不存在", 404)
	var role := str(input.get("role", "user"))
	var content := str(input.get("content", "")).strip_edges()
	if role not in ["system", "user", "assistant", "tool"] or content.is_empty():
		return _error("VALIDATION_ERROR", "消息参数不合法")
	return _created(repository.create_message({
		"tenant_id": tenant_id,
		"chat_id": chat_id,
		"role": role,
		"content": content,
		"metadata": input.get("metadata", {}),
	}))

func list_messages(tenant_id: String, chat_id: String) -> Dictionary:
	if repository.get_chat(tenant_id, chat_id).is_empty():
		return _error("CHAT_NOT_FOUND", "对话不存在", 404)
	return _ok(repository.list_messages(tenant_id, chat_id))

func _ok(data: Variant, status: int = 200) -> Dictionary:
	return {"ok": true, "status": status, "data": data}

func _created(data: Variant) -> Dictionary:
	return _ok(data, 201)

func _error(code: String, message: String, status: int = 400) -> Dictionary:
	return {"ok": false, "status": status, "error": {"code": code, "message": message}}
