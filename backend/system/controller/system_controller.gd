class_name SystemController
extends RefCounted

var service

func _init(system_service) -> void:
	service = system_service

func health(_context: Dictionary, _body: Dictionary) -> Dictionary:
	return service.health()

func info(_context: Dictionary, _body: Dictionary) -> Dictionary:
	return service.info()

func save_database(_context: Dictionary, _body: Dictionary) -> Dictionary:
	return service.save_database()

