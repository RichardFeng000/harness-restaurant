class_name TenantService
extends RefCounted

var repository

func _init(tenant_repository) -> void:
	repository = tenant_repository

func bootstrap() -> Dictionary:
	if repository.tenant_count() > 0:
		return _ok({"seeded": false})
	var tenant: Dictionary = repository.create_tenant({
		"name": "Harness Demo", "slug": "harness-demo", "status": "active",
	})
	var user: Dictionary = repository.create_user({
		"name": "Demo User", "email": "demo@harness.local", "status": "active",
	})
	repository.create_member({
		"tenant_id": tenant["id"], "user_id": user["id"], "role": "owner",
	})
	var project: Dictionary = repository.create_project({
		"tenant_id": tenant["id"],
		"name": "Default Project",
		"description": "Harness Kitchen 默认项目",
	})
	var agent: Dictionary = repository.create_agent({
		"tenant_id": tenant["id"],
		"project_id": project["id"],
		"name": "Harness Assistant",
		"system_prompt": "You are a helpful assistant.",
		"model": "mock-model",
		"status": "active",
	})
	return _created({
		"seeded": true,
		"tenant": tenant,
		"user": user,
		"project": project,
		"agent": agent,
	})

func create_tenant(input: Dictionary) -> Dictionary:
	var name := str(input.get("name", "")).strip_edges()
	if name.is_empty():
		return _error("VALIDATION_ERROR", "租户名称不能为空")
	return _created(repository.create_tenant({
		"name": name,
		"slug": str(input.get("slug", name.to_lower().replace(" ", "-"))),
		"status": "active",
	}))

func create_project(tenant_id: String, input: Dictionary) -> Dictionary:
	if repository.get_tenant(tenant_id).is_empty():
		return _error("TENANT_NOT_FOUND", "租户不存在", 404)
	var name := str(input.get("name", "")).strip_edges()
	if name.is_empty():
		return _error("VALIDATION_ERROR", "项目名称不能为空")
	return _created(repository.create_project({
		"tenant_id": tenant_id,
		"name": name,
		"description": str(input.get("description", "")),
	}))

func list_projects(tenant_id: String) -> Dictionary:
	return _ok(repository.list_projects(tenant_id))

func _ok(data: Variant, status: int = 200) -> Dictionary:
	return {"ok": true, "status": status, "data": data}

func _created(data: Variant) -> Dictionary:
	return _ok(data, 201)

func _error(code: String, message: String, status: int = 400) -> Dictionary:
	return {"ok": false, "status": status, "error": {"code": code, "message": message}}
