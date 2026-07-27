class_name RunService
extends RefCounted

var repository

func _init(run_repository) -> void:
	repository = run_repository

func create_run(tenant_id: String, input: Dictionary) -> Dictionary:
	var project_id := str(input.get("project_id", ""))
	var agent_id := str(input.get("agent_id", ""))
	if not repository.project_exists(tenant_id, project_id):
		return _error("PROJECT_NOT_FOUND", "项目不存在", 404)
	if not repository.agent_exists(tenant_id, agent_id):
		return _error("AGENT_NOT_FOUND", "Agent 不存在", 404)
	var run: Dictionary = repository.create_run({
		"tenant_id": tenant_id,
		"project_id": project_id,
		"agent_id": agent_id,
		"chat_id": str(input.get("chat_id", "")),
		"task": str(input.get("task", "")),
		"status": "queued",
		"step_count": 0,
		"max_steps": int(input.get("max_steps", 20)),
	})
	repository.create_event({
		"tenant_id": tenant_id,
		"run_id": run["id"],
		"type": "run.created",
		"data": {"status": "queued"},
	})
	return _created(run)

func get_run(tenant_id: String, run_id: String) -> Dictionary:
	var run: Dictionary = repository.get_run(tenant_id, run_id)
	if run.is_empty():
		return _error("RUN_NOT_FOUND", "Run 不存在", 404)
	run["events"] = repository.list_events(tenant_id, run_id)
	return _ok(run)

func _ok(data: Variant, status: int = 200) -> Dictionary:
	return {"ok": true, "status": status, "data": data}

func _created(data: Variant) -> Dictionary:
	return _ok(data, 201)

func _error(code: String, message: String, status: int = 400) -> Dictionary:
	return {"ok": false, "status": status, "error": {"code": code, "message": message}}
