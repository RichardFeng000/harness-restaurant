class_name TenantRepository
extends RefCounted

var db

func _init(database) -> void:
	db = database

func create_tenant(values: Dictionary) -> Dictionary:
	return db.insert("tenants", values)

func get_tenant(id: String) -> Dictionary:
	return db.find_by_id("tenants", id)

func tenant_count() -> int:
	return db.count("tenants")

func create_user(values: Dictionary) -> Dictionary:
	return db.insert("users", values)

func create_member(values: Dictionary) -> Dictionary:
	return db.insert("members", values)

func create_project(values: Dictionary) -> Dictionary:
	return db.insert("projects", values)

func create_agent(values: Dictionary) -> Dictionary:
	return db.insert("agents", values)

func get_project(tenant_id: String, project_id: String) -> Dictionary:
	return db.find_by_id("projects", project_id, tenant_id)

func list_projects(tenant_id: String) -> Array:
	return db.find_many("projects", {}, tenant_id)
