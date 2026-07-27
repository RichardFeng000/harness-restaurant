class_name KnowledgeController
extends RefCounted

var service

func _init(knowledge_service) -> void:
	service = knowledge_service

func create_base(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.create_knowledge_base(str(context.get("tenant_id", "")), body)

func add_document(context: Dictionary, knowledge_id: String, body: Dictionary) -> Dictionary:
	return service.add_document(str(context.get("tenant_id", "")), knowledge_id, body)

func search(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.search(str(context.get("tenant_id", "")), str(body.get("query", "")))
