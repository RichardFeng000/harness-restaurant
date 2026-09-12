extends RefCounted
## Employee tool assignments are checked against manager-controlled grants.

signal skill_changed(staff_id: String, skill_id: String)
signal execution_completed(staff_id: String, skill_id: String, result: Dictionary)

const LocalTime = preload("res://game/skills/local-time/scripts/read_local_time.gd")
const McpRegistry = preload("res://backend/mcp/mcp_registry.gd")
const McpCatalog = preload("res://backend/mcp/mcp_catalog.gd")
const MANIFEST_PATH := "res://game/skills/local-time/manifest.json"
const SKILL_ID := "local-time"
const STAFF_IDS := ["manager", "cashier", "head_chef", "sous_chef", "expeditor", "waiter", "hamster"]
var _catalog: Dictionary = {}
var _installed: Dictionary = {}
var _last_results: Dictionary = {}
var _permissions: Dictionary = {}
var _time_reader: RefCounted
var _mcp_registry: RefCounted

func _init(time_reader: RefCounted = null) -> void:
	_mcp_registry = McpRegistry.new()
	_mcp_registry.changed.connect(_on_mcp_changed)
	_time_reader = time_reader if time_reader != null else LocalTime.new()
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file != null:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			var definition: Dictionary = json.data
			if definition.get("id") == SKILL_ID and definition.get("entrypoint") == "res://game/skills/local-time/scripts/read_local_time.gd":
				_catalog[SKILL_ID] = definition
	restore_state(null)

func list_catalog(staff_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if staff_id not in STAFF_IDS:
		return result
	for skill_id: String in _catalog:
		var item: Dictionary = _catalog[skill_id].duplicate(true)
		item["source_url"] = item.get("instructions", "")
		item["connection_status"] = "bundled"
		result.append(_with_state(staff_id, item))
	for item: Dictionary in McpCatalog.list_entries():
		result.append(_with_state(staff_id, item))
	return result

func list_skills(staff_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if staff_id not in STAFF_IDS:
		return result
	for skill_id: String in _catalog:
		# Keep the hamster's bundled skill discoverable after uninstalling it.
		if not is_installed(staff_id, skill_id) and staff_id not in _catalog[skill_id].get("eligible_staff", []):
			continue
		var item: Dictionary = _catalog[skill_id].duplicate(true)
		item["connection_status"] = "bundled"
		item["source_url"] = item.get("instructions", "")
		result.append(_with_state(staff_id, item))
	for item: Dictionary in _mcp_registry.list_entries(staff_id):
		result.append(_with_state(staff_id, item))
	return result

func _with_state(staff_id: String, item: Dictionary) -> Dictionary:
	var tool_id: String = item.id
	item["installed"] = is_installed(staff_id, tool_id)
	item["enabled"] = is_enabled(staff_id, tool_id)
	item["authorized"] = is_authorized(staff_id, tool_id)
	item["last_result"] = _last_results.get(_key(staff_id, tool_id), {}).duplicate(true)
	item.merge(get_permissions(staff_id, tool_id), true)
	return item

func get_permissions(staff_id: String, tool_id: String) -> Dictionary:
	# Read-only aliases for older consumers; both are derived from one grant.
	var allowed := is_authorized(staff_id, tool_id)
	return {"can_install": allowed, "can_use": allowed}

func is_authorized(staff_id: String, tool_id: String) -> bool:
	if staff_id not in STAFF_IDS or not _known_tool(tool_id):
		return false
	var configured: Variant = _permissions.get(staff_id, {}).get(tool_id)
	if configured is Dictionary:
		return configured.get("authorized") is bool and configured.authorized
	return staff_id == "manager" or (staff_id == "hamster" and tool_id == SKILL_ID)

func set_authorized(actor_staff_id: String, target_staff_id: String, tool_id: String, authorized: Variant) -> Dictionary:
	if actor_staff_id != "manager":
		return _error("只有主管可以设置权限")
	if target_staff_id not in STAFF_IDS or not _known_tool(tool_id):
		return _error("请选择有效员工和库内工具")
	if not authorized is bool:
		return _error("授权必须为开关值")
	if not _permissions.has(target_staff_id):
		_permissions[target_staff_id] = {}
	_permissions[target_staff_id][tool_id] = {"authorized": authorized}
	if not authorized:
		_pause_without_grant(target_staff_id, tool_id)
	skill_changed.emit(target_staff_id, tool_id)
	return {"ok": true}

func is_installed(staff_id: String, skill_id: String) -> bool:
	if staff_id not in STAFF_IDS:
		return false
	if skill_id.begins_with("mcp-"):
		return _mcp_registry.is_installed(staff_id, skill_id)
	return _catalog.has(skill_id) and _installed.get(staff_id, {}).has(skill_id)

func is_enabled(staff_id: String, skill_id: String) -> bool:
	if not is_authorized(staff_id, skill_id):
		return false
	if skill_id.begins_with("mcp-"):
		return _mcp_registry.is_enabled(staff_id, skill_id)
	return is_installed(staff_id, skill_id) and bool(_installed[staff_id][skill_id].get("enabled", false))

func install_catalog(staff_id: String, tool_id: String) -> Dictionary:
	return install_skill(staff_id, tool_id)

func install_skill(staff_id: String, skill_id: String) -> Dictionary:
	if not is_authorized(staff_id, skill_id):
		return _error("主管尚未授权")
	if skill_id.begins_with("mcp-"):
		return _mcp_registry.install(staff_id, skill_id)
	if is_installed(staff_id, skill_id):
		return {"ok": true, "id": skill_id}
	if not _installed.has(staff_id):
		_installed[staff_id] = {}
	_installed[staff_id][skill_id] = {"enabled": false}
	skill_changed.emit(staff_id, skill_id)
	return {"ok": true, "id": skill_id}

func uninstall_skill(staff_id: String, skill_id: String) -> Dictionary:
	if skill_id.begins_with("mcp-"):
		return _mcp_registry.uninstall(staff_id, skill_id)
	if not is_installed(staff_id, skill_id):
		return _error("此员工尚未安装该技能")
	_installed[staff_id].erase(skill_id)
	if _installed[staff_id].is_empty():
		_installed.erase(staff_id)
	_last_results.erase(_key(staff_id, skill_id))
	skill_changed.emit(staff_id, skill_id)
	return {"ok": true}

func set_enabled(staff_id: String, skill_id: String, enabled: bool) -> Dictionary:
	if not is_installed(staff_id, skill_id):
		return _error("请先安装工具")
	if enabled and not is_authorized(staff_id, skill_id):
		return _error("主管尚未授权")
	if skill_id.begins_with("mcp-"):
		return _mcp_registry.set_enabled(staff_id, skill_id, enabled)
	_installed[staff_id][skill_id]["enabled"] = enabled
	skill_changed.emit(staff_id, skill_id)
	return {"ok": true}

func execute(staff_id: String, skill_id: String) -> Dictionary:
	var result: Dictionary
	if not is_authorized(staff_id, skill_id):
		result = _error("主管尚未授权")
	elif not is_installed(staff_id, skill_id):
		result = _error("此员工尚未安装该工具")
	elif not is_enabled(staff_id, skill_id):
		result = _error("该工具已暂停")
	elif skill_id.begins_with("mcp-"):
		result = _mcp_registry.execute(staff_id, skill_id)
	elif skill_id == SKILL_ID:
		result = _time_reader.execute()
		if bool(result.get("ok", false)) and not _valid_time(result.get("data")):
			result = _error("时间技能返回了无效的时钟读数")
	else:
		result = _error("未找到工具执行器")
	if skill_id.begins_with("mcp-"):
		result["connection_status"] = "not_connected"
	if is_installed(staff_id, skill_id):
		_last_results[_key(staff_id, skill_id)] = result.duplicate(true)
	execution_completed.emit(staff_id, skill_id, result.duplicate(true))
	return result

func export_state() -> Dictionary:
	# Installation only; timestamps and manager grants have separate lifetimes.
	return _installed.duplicate(true)

func restore_state(state: Variant) -> void:
	_mcp_registry.restore_state(null)
	_permissions.clear()
	_installed.clear()
	_last_results.clear()
	for skill_id: String in _catalog:
		var definition: Dictionary = _catalog[skill_id]
		for staff_id: String in STAFF_IDS:
			var record: Variant = null
			if state is Dictionary:
				var staff_state: Variant = state.get(staff_id, {})
				if staff_state is Dictionary:
					record = staff_state.get(skill_id)
			elif staff_id in definition.get("default_installed", []):
				record = {"enabled": true}
			if record is Dictionary and record.get("enabled") is bool:
				if not _installed.has(staff_id):
					_installed[staff_id] = {}
				_installed[staff_id][skill_id] = {"enabled": record.enabled}
			skill_changed.emit(staff_id, skill_id)

func add_mcp(_staff_id: String, _definition: Dictionary) -> Dictionary:
	return _error("请先由主管授权，再从 MCP 库选择工具")

func export_mcp_state() -> Dictionary:
	return _mcp_registry.export_state()

func restore_mcp_state(state: Variant) -> void:
	_mcp_registry.restore_state(state)

func export_permission_state() -> Dictionary:
	return {"version": 2, "staff": _permissions.duplicate(true)}

func restore_permission_state(state: Variant) -> void:
	_permissions.clear()
	if state is Dictionary and (state.get("version") is int or state.get("version") is float) and (state.get("version") == 1 or state.get("version") == 2) and state.get("staff") is Dictionary:
		for staff_id: String in STAFF_IDS:
			var records: Variant = state.staff.get(staff_id)
			if not records is Dictionary:
				continue
			for tool_id: Variant in records:
				if not tool_id is String or not _known_tool(tool_id):
					continue
				var record: Variant = records[tool_id]
				var authorized := false
				if record is Dictionary:
					if state.version == 1:
						# Partial legacy grants cannot expand into full authorization.
						authorized = record.get("can_install") is bool and record.get("can_use") is bool and record.can_install and record.can_use
					else:
						authorized = record.get("authorized") is bool and record.authorized
				if not _permissions.has(staff_id):
					_permissions[staff_id] = {}
				_permissions[staff_id][tool_id] = {"authorized": authorized}
	for staff_id: String in STAFF_IDS:
		for item: Dictionary in list_catalog(staff_id):
			if not item.authorized:
				_pause_without_grant(staff_id, item.id)
			skill_changed.emit(staff_id, item.id)

func _pause_without_grant(staff_id: String, tool_id: String) -> void:
	_last_results.erase(_key(staff_id, tool_id))
	if not is_installed(staff_id, tool_id):
		return
	if tool_id.begins_with("mcp-"):
		_mcp_registry.set_enabled(staff_id, tool_id, false)
	else:
		_installed[staff_id][tool_id].enabled = false

func _known_tool(tool_id: String) -> bool:
	return _catalog.has(tool_id) or McpCatalog.has_entry(tool_id)

func _on_mcp_changed(staff_id: String, mcp_id: String) -> void:
	skill_changed.emit(staff_id, mcp_id)

func _valid_time(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for field in ["hour", "minute", "second"]:
		if not data.has(field) or not (data[field] is int or data[field] is float):
			return false
		var value := float(data[field])
		if not is_finite(value) or value != floor(value):
			return false
	return data.hour >= 0 and data.hour < 24 and data.minute >= 0 and data.minute < 60 and data.second >= 0 and data.second < 60

func _key(staff_id: String, skill_id: String) -> String:
	return staff_id + ":" + skill_id

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
