class_name MemoryController
extends RefCounted

var service

func _init(memory_service) -> void:
	service = memory_service

func create_memory(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.create_memory(str(context.get("tenant_id", "")), body)

func list_memories(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.list_memories(
		str(context.get("tenant_id", "")),
		str(body.get("scope", "")),
		str(body.get("subject_id", ""))
	)
