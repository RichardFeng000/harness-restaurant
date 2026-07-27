class_name KnowledgeService
extends RefCounted

var repository

func _init(knowledge_repository) -> void:
	repository = knowledge_repository

func create_knowledge_base(tenant_id: String, input: Dictionary) -> Dictionary:
	var project_id := str(input.get("project_id", ""))
	if not repository.project_exists(tenant_id, project_id):
		return _error("PROJECT_NOT_FOUND", "项目不存在", 404)
	return _created(repository.create_knowledge_base({
		"tenant_id": tenant_id,
		"project_id": project_id,
		"name": str(input.get("name", "知识库")),
		"description": str(input.get("description", "")),
	}))

func add_document(tenant_id: String, knowledge_id: String, input: Dictionary) -> Dictionary:
	if repository.get_knowledge_base(tenant_id, knowledge_id).is_empty():
		return _error("KNOWLEDGE_NOT_FOUND", "知识库不存在", 404)
	var content := str(input.get("content", "")).strip_edges()
	if content.is_empty():
		return _error("VALIDATION_ERROR", "文档内容不能为空")
	return _created(repository.create_document({
		"tenant_id": tenant_id,
		"knowledge_base_id": knowledge_id,
		"title": str(input.get("title", "未命名文档")),
		"content": content,
		"status": "ready",
	}))

func search(tenant_id: String, query: String) -> Dictionary:
	var normalized := query.to_lower().strip_edges()
	var matches: Array = []
	if normalized.is_empty():
		return _ok(matches)
	for document in repository.list_documents(tenant_id):
		var text := ("%s\n%s" % [document.get("title", ""), document.get("content", "")]).to_lower()
		if text.contains(normalized):
			matches.append(document)
	return _ok(matches)

func _ok(data: Variant, status: int = 200) -> Dictionary:
	return {"ok": true, "status": status, "data": data}

func _created(data: Variant) -> Dictionary:
	return _ok(data, 201)

func _error(code: String, message: String, status: int = 400) -> Dictionary:
	return {"ok": false, "status": status, "error": {"code": code, "message": message}}
