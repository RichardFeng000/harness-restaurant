class_name RunController
extends RefCounted

var service

func _init(run_service) -> void:
	service = run_service

func create_run(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.create_run(str(context.get("tenant_id", "")), body)

func get_run(context: Dictionary, run_id: String) -> Dictionary:
	return service.get_run(str(context.get("tenant_id", "")), run_id)
