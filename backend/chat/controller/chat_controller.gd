class_name ChatController
extends RefCounted

var service

func _init(chat_service) -> void:
	service = chat_service

func create_chat(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.create_chat(str(context.get("tenant_id", "")), body)

func list_chats(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.list_chats(
		str(context.get("tenant_id", "")),
		str(body.get("project_id", ""))
	)

func add_message(context: Dictionary, chat_id: String, body: Dictionary) -> Dictionary:
	return service.add_message(str(context.get("tenant_id", "")), chat_id, body)

func list_messages(context: Dictionary, chat_id: String) -> Dictionary:
	return service.list_messages(str(context.get("tenant_id", "")), chat_id)
