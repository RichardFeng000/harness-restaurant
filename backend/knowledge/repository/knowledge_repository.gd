class_name KnowledgeRepository
extends RefCounted

var db

func _init(database) -> void:
	db = database

func project_exists(tenant_id: String, project_id: String) -> bool:
	return not db.find_by_id("projects", project_id, tenant_id).is_empty()

func create_knowledge_base(values: Dictionary) -> Dictionary:
	return db.insert("knowledge_bases", values)

func get_knowledge_base(tenant_id: String, id: String) -> Dictionary:
	return db.find_by_id("knowledge_bases", id, tenant_id)

func create_document(values: Dictionary) -> Dictionary:
	return db.insert("documents", values)

func list_documents(tenant_id: String) -> Array:
	return db.find_many("documents", {}, tenant_id)
