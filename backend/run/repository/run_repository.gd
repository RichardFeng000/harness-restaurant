class_name RunRepository
extends RefCounted

var db

func _init(database) -> void:
	db = database

func project_exists(tenant_id: String, project_id: String) -> bool:
	return not db.find_by_id("projects", project_id, tenant_id).is_empty()

func agent_exists(tenant_id: String, agent_id: String) -> bool:
	return not db.find_by_id("agents", agent_id, tenant_id).is_empty()

func create_run(values: Dictionary) -> Dictionary:
	return db.insert("runs", values)

func get_run(tenant_id: String, run_id: String) -> Dictionary:
	return db.find_by_id("runs", run_id, tenant_id)

func create_event(values: Dictionary) -> Dictionary:
	return db.insert("events", values)

func list_events(tenant_id: String, run_id: String) -> Array:
	return db.find_many("events", {"run_id": run_id}, tenant_id)
