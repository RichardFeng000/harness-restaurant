class_name ChatRepository
extends RefCounted

var db

func _init(database) -> void:
	db = database

func project_exists(tenant_id: String, project_id: String) -> bool:
	return not db.find_by_id("projects", project_id, tenant_id).is_empty()

func create_chat(values: Dictionary) -> Dictionary:
	return db.insert("chats", values)

func get_chat(tenant_id: String, chat_id: String) -> Dictionary:
	return db.find_by_id("chats", chat_id, tenant_id)

func list_chats(tenant_id: String, filters: Dictionary) -> Array:
	return db.find_many("chats", filters, tenant_id)

func create_message(values: Dictionary) -> Dictionary:
	return db.insert("messages", values)

func list_messages(tenant_id: String, chat_id: String) -> Array:
	return db.find_many("messages", {"chat_id": chat_id}, tenant_id)
