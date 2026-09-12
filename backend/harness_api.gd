class_name HarnessApi
extends RefCounted

const DatabaseScript = preload("res://database/fake_db.gd")
const StaffSkillRuntime = preload("res://backend/skills/staff_skill_runtime.gd")

const TenantRepository = preload("res://backend/tenant/repository/tenant_repository.gd")
const TenantService = preload("res://backend/tenant/service/tenant_service.gd")
const TenantController = preload("res://backend/tenant/controller/tenant_controller.gd")

const ChatRepository = preload("res://backend/chat/repository/chat_repository.gd")
const ChatService = preload("res://backend/chat/service/chat_service.gd")
const ChatController = preload("res://backend/chat/controller/chat_controller.gd")

const KnowledgeRepository = preload("res://backend/knowledge/repository/knowledge_repository.gd")
const KnowledgeService = preload("res://backend/knowledge/service/knowledge_service.gd")
const KnowledgeController = preload("res://backend/knowledge/controller/knowledge_controller.gd")

const MemoryRepository = preload("res://backend/memory/repository/memory_repository.gd")
const MemoryService = preload("res://backend/memory/service/memory_service.gd")
const MemoryController = preload("res://backend/memory/controller/memory_controller.gd")

const RunRepository = preload("res://backend/run/repository/run_repository.gd")
const RunService = preload("res://backend/run/service/run_service.gd")
const RunController = preload("res://backend/run/controller/run_controller.gd")

const SystemRepository = preload("res://backend/system/repository/system_repository.gd")
const SystemService = preload("res://backend/system/service/system_service.gd")
const SystemController = preload("res://backend/system/controller/system_controller.gd")

var database
var tenant
var chat
var knowledge
var memory
var run
var system
var skills

func _init(db_path: String = "user://harness_v2.csv", auto_load: bool = true) -> void:
	skills = StaffSkillRuntime.new()
	database = DatabaseScript.new(db_path)
	if auto_load:
		database.load()
	tenant = TenantController.new(TenantService.new(TenantRepository.new(database)))
	chat = ChatController.new(ChatService.new(ChatRepository.new(database)))
	knowledge = KnowledgeController.new(KnowledgeService.new(KnowledgeRepository.new(database)))
	memory = MemoryController.new(MemoryService.new(MemoryRepository.new(database)))
	run = RunController.new(RunService.new(RunRepository.new(database)))
	system = SystemController.new(SystemService.new(SystemRepository.new(database)))

func request(method: String, path: String, body: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var verb := method.to_upper()
	var parts := _path_parts(path)
	var request_context := context.duplicate(true)
	if not request_context.has("tenant_id"):
		request_context["tenant_id"] = str(body.get("tenant_id", ""))
	var result: Dictionary

	if verb == "POST" and parts == ["api", "v2", "bootstrap"]:
		result = tenant.bootstrap(request_context, body)
	elif verb == "GET" and parts == ["api", "v2", "system", "health"]:
		result = system.health(request_context, body)
	elif verb == "GET" and parts == ["api", "v2", "system", "info"]:
		result = system.info(request_context, body)
	elif verb == "POST" and parts == ["api", "v2", "tenants"]:
		result = tenant.create_tenant(request_context, body)
	elif verb == "GET" and parts == ["api", "v2", "projects"]:
		result = tenant.list_projects(request_context, body)
	elif verb == "POST" and parts == ["api", "v2", "projects"]:
		result = tenant.create_project(request_context, body)
	elif verb == "GET" and parts == ["api", "v2", "chats"]:
		result = chat.list_chats(request_context, body)
	elif verb == "POST" and parts == ["api", "v2", "chats"]:
		result = chat.create_chat(request_context, body)
	elif parts.size() == 5 and parts.slice(0, 3) == ["api", "v2", "chats"] and parts[4] == "messages":
		result = chat.add_message(request_context, parts[3], body) if verb == "POST" else chat.list_messages(request_context, parts[3])
	elif verb == "POST" and parts == ["api", "v2", "knowledge"]:
		result = knowledge.create_base(request_context, body)
	elif verb == "GET" and parts == ["api", "v2", "knowledge", "search"]:
		result = knowledge.search(request_context, body)
	elif verb == "POST" and parts.size() == 5 and parts.slice(0, 3) == ["api", "v2", "knowledge"] and parts[4] == "documents":
		result = knowledge.add_document(request_context, parts[3], body)
	elif verb == "GET" and parts == ["api", "v2", "memories"]:
		result = memory.list_memories(request_context, body)
	elif verb == "POST" and parts == ["api", "v2", "memories"]:
		result = memory.create_memory(request_context, body)
	elif verb == "POST" and parts == ["api", "v2", "runs"]:
		result = run.create_run(request_context, body)
	elif verb == "GET" and parts.size() == 4 and parts.slice(0, 3) == ["api", "v2", "runs"]:
		result = run.get_run(request_context, parts[3])
	elif verb == "POST" and parts == ["api", "v2", "database", "save"]:
		result = system.save_database(request_context, body)
	else:
		result = {
			"ok": false,
			"status": 404,
			"error": {"code": "ROUTE_NOT_FOUND", "message": "接口不存在"},
		}
	return _response(result)

func _path_parts(path: String) -> Array:
	var parts: Array = []
	for part in path.split("?")[0].strip_edges().split("/", false):
		parts.append(str(part))
	return parts

func _response(result: Dictionary) -> Dictionary:
	var success := bool(result.get("ok", false))
	return {
		"status": int(result.get("status", 500)),
		"headers": {"content-type": "application/json"},
		"body": {
			"success": success,
			"data": result.get("data") if success else null,
			"error": null if success else result.get("error"),
		},
	}
