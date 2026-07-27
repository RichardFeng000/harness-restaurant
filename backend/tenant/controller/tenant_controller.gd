class_name TenantController
extends RefCounted

var service

func _init(tenant_service) -> void:
	service = tenant_service

func bootstrap(_context: Dictionary, _body: Dictionary) -> Dictionary:
	return service.bootstrap()

func create_tenant(_context: Dictionary, body: Dictionary) -> Dictionary:
	return service.create_tenant(body)

func create_project(context: Dictionary, body: Dictionary) -> Dictionary:
	return service.create_project(str(context.get("tenant_id", "")), body)

func list_projects(context: Dictionary, _body: Dictionary) -> Dictionary:
	return service.list_projects(str(context.get("tenant_id", "")))
