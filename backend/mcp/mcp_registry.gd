extends RefCounted
## Stores catalog assignments, never downloads, connects, or starts MCP processes.

signal changed(staff_id: String, mcp_id: String)

const Catalog = preload("res://backend/mcp/mcp_catalog.gd")
const STAFF_IDS := ["manager", "cashier", "head_chef", "sous_chef", "expeditor", "waiter", "hamster"]
const STATE_VERSION := 2
var _records: Dictionary = {}

func add_mcp(_staff_id: String, _definition: Dictionary) -> Dictionary:
	return _error("请从 MCP 库选择工具，并由主管授权安装")

func list_entries(staff_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries: Dictionary = _records.get(staff_id, {})
	for mcp_id: String in entries:
		var record: Dictionary = entries[mcp_id]
		var item: Dictionary = Catalog.get_entry(mcp_id)
		if item.is_empty():
			item = {
				"id": mcp_id, "name": record.config.name, "kind": "mcp",
				"legacy": true, "config": record.config.duplicate(true),
				"description": "旧版自定义配置，仅保留查看和卸载；请从 MCP 库重新选择工具。",
			}
		item["installed"] = true
		item["enabled"] = is_enabled(staff_id, mcp_id)
		item["connection_status"] = "not_connected"
		result.append(item)
	return result

func is_installed(staff_id: String, mcp_id: String) -> bool:
	return _records.get(staff_id, {}).has(mcp_id)

func is_enabled(staff_id: String, mcp_id: String) -> bool:
	return Catalog.has_entry(mcp_id) and is_installed(staff_id, mcp_id) and bool(_records[staff_id][mcp_id].enabled)

func install(staff_id: String, mcp_id: String) -> Dictionary:
	if staff_id not in STAFF_IDS or not Catalog.has_entry(mcp_id):
		return _error("请从 MCP 库选择有效工具")
	if is_installed(staff_id, mcp_id):
		return {"ok": true, "id": mcp_id}
	if not _records.has(staff_id):
		_records[staff_id] = {}
	_records[staff_id][mcp_id] = {"enabled": false, "catalog_id": mcp_id}
	changed.emit(staff_id, mcp_id)
	return {"ok": true, "id": mcp_id}

func uninstall(staff_id: String, mcp_id: String) -> Dictionary:
	if not is_installed(staff_id, mcp_id):
		return _error("此员工尚未添加该 MCP")
	_records[staff_id].erase(mcp_id)
	if _records[staff_id].is_empty():
		_records.erase(staff_id)
	changed.emit(staff_id, mcp_id)
	return {"ok": true}

func set_enabled(staff_id: String, mcp_id: String, enabled: bool) -> Dictionary:
	if not is_installed(staff_id, mcp_id):
		return _error("请先安装 MCP")
	if enabled and not Catalog.has_entry(mcp_id):
		return _error("旧版自定义配置仅供查看和卸载")
	_records[staff_id][mcp_id].enabled = enabled
	changed.emit(staff_id, mcp_id)
	return {"ok": true}

func execute(staff_id: String, mcp_id: String) -> Dictionary:
	var message := "MCP 尚未连接，无法执行工具。"
	if not is_installed(staff_id, mcp_id):
		message = "此员工尚未添加该 MCP。"
	elif not is_enabled(staff_id, mcp_id):
		message = "此 MCP 已暂停。"
	return {"ok": false, "error": message, "connection_status": "not_connected"}

func export_state() -> Dictionary:
	return {"version": STATE_VERSION, "staff": _records.duplicate(true)}

func restore_state(state: Variant) -> void:
	var restored: Dictionary = {}
	if state is Dictionary:
		var version: Variant = state.get("version")
		if (version is int or version is float) and (version == 1 or version == STATE_VERSION) and state.get("staff") is Dictionary:
			for staff_id: String in STAFF_IDS:
				var records: Variant = state.staff.get(staff_id)
				if not records is Dictionary:
					continue
				var accepted: Dictionary = {}
				for mcp_id: Variant in records:
					if not mcp_id is String:
						continue
					var record: Variant = records[mcp_id]
					if not record is Dictionary or not record.get("enabled") is bool:
						continue
					if version == STATE_VERSION and Catalog.has_entry(mcp_id) and record.get("catalog_id") == mcp_id:
						accepted[mcp_id] = {"enabled": record.enabled, "catalog_id": mcp_id}
					elif _matches("^mcp-[0-9a-f]{32}$", mcp_id) and not _has_id(restored, mcp_id) and record.get("config") is Dictionary:
						var validated := _normalize(record.config)
						if validated.ok and not _duplicate(accepted, validated.config):
							accepted[mcp_id] = {"enabled": false, "legacy": true, "config": validated.config}
				if not accepted.is_empty():
					restored[staff_id] = accepted
	var previous := _records
	_records = restored
	for staff_id: String in STAFF_IDS:
		var changed_ids: Dictionary = previous.get(staff_id, {}).duplicate()
		changed_ids.merge(_records.get(staff_id, {}), true)
		for mcp_id: String in changed_ids:
			changed.emit(staff_id, mcp_id)

func _normalize(definition: Dictionary) -> Dictionary:
	if not definition.get("name") is String or definition.name.strip_edges().is_empty():
		return _error("请填写 MCP 名称")
	var name_text: String = definition.name.strip_edges()
	if _matches("[\\x00-\\x1f\\x7f]", name_text):
		return _error("MCP 名称不能包含控制字符")
	var type_value: Variant = definition.get("type", definition.get("transport", ""))
	if not type_value is String:
		return _error("请选择 HTTP 或 stdio 传输类型")
	var transport := _transport(type_value)
	if transport.is_empty():
		return _error("仅支持 HTTP 或 stdio 配置")
	if definition.has("transport"):
		if not definition.transport is String or _transport(definition.transport) != transport:
			return _error("MCP 的 type 与 transport 不一致")
	if transport == "http":
		if not definition.get("url") is String:
			return _error("请填写 HTTP 地址")
		var address := _normalize_url(definition.url)
		if not address.ok:
			return address
		return {"ok": true, "config": {"name": name_text, "type": "http", "url": address.url}}
	if not definition.get("command") is String or definition.command.strip_edges().is_empty():
		return _error("请填写 stdio 命令")
	var command: String = definition.command.strip_edges()
	if _matches("[\\x00-\\x1f\\x7f]", command):
		return _error("stdio 命令不能包含控制字符")
	var arguments: Variant = definition.get("args", [])
	if not arguments is Array:
		return _error("stdio 参数必须是字符串数组")
	var clean_arguments: Array[String] = []
	for argument: Variant in arguments:
		if not argument is String or _matches("\\x00", argument):
			return _error("stdio 的每个参数必须是有效字符串")
		clean_arguments.append(argument)
	return {"ok": true, "config": {"name": name_text, "type": "stdio", "command": command, "args": clean_arguments}}

func _normalize_url(url: String) -> Dictionary:
	if _matches("[\\s\\p{Z}\\x00-\\x1f\\x7f]", url) or url.contains("#") or url.contains("\\"):
		return _error("HTTP 地址不能包含空白、用户信息或片段标记")
	var pattern := RegEx.new()
	pattern.compile("^(?i:(https?))://([^/?#]+)([^#]*)$")
	var matched := pattern.search(url)
	if matched == null:
		return _error("请填写包含主机名的 http:// 或 https:// 地址")
	var scheme := matched.get_string(1).to_lower()
	var authority := matched.get_string(2)
	var suffix := matched.get_string(3)
	if authority.contains("@"):
		return _error("HTTP 地址不能包含用户名或密码")
	var host := ""
	var port := ""
	if authority.begins_with("["):
		var end := authority.find("]")
		if end < 0:
			return _error("HTTP 地址中的 IPv6 主机格式无效")
		var ipv6 := authority.substr(1, end - 1)
		if not ipv6.contains(":") or not ipv6.is_valid_ip_address():
			return _error("HTTP 地址中的 IPv6 主机格式无效")
		host = "[" + ipv6.to_lower() + "]"
		var remainder := authority.substr(end + 1)
		if not remainder.is_empty():
			if not remainder.begins_with(":"):
				return _error("HTTP 地址中的主机格式无效")
			port = remainder.substr(1)
			if port.is_empty():
				return _error("HTTP 地址的端口不能为空")
	else:
		var parts := authority.split(":")
		if parts.size() > 2:
			return _error("IPv6 主机需要使用方括号")
		host = parts[0].to_lower().trim_suffix(".")
		if host.is_empty() or host.length() > 253:
			return _error("HTTP 地址需要有效主机名")
		for label: String in host.split("."):
			if not _matches("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$", label):
				return _error("HTTP 地址中的主机名无效")
		if _matches("^[0-9.]+$", host) and host.contains(".") and not host.is_valid_ip_address():
			return _error("HTTP 地址中的 IP 地址无效")
		if parts.size() == 2:
			port = parts[1]
			if port.is_empty():
				return _error("HTTP 地址的端口不能为空")
	if not port.is_empty():
		if not _matches("^[0-9]{1,5}$", port) or int(port) < 1 or int(port) > 65535:
			return _error("HTTP 地址的端口应为 1 到 65535")
		port = str(int(port))
		if (scheme == "http" and port == "80") or (scheme == "https" and port == "443"):
			port = ""
	if suffix.is_empty() or suffix.begins_with("?"):
		suffix = "/" + suffix
	return {"ok": true, "url": scheme + "://" + host + (":" + port if not port.is_empty() else "") + suffix}

func _transport(value: String) -> String:
	var transport := value.strip_edges().to_lower()
	if transport in ["http", "streamable-http"]:
		return "http"
	return "stdio" if transport == "stdio" else ""

func _duplicate(records: Dictionary, config: Dictionary) -> bool:
	for record: Dictionary in records.values():
		if not record.has("config"):
			continue
		var existing: Dictionary = record.config
		if existing.type != config.type:
			continue
		if config.type == "http" and existing.url == config.url:
			return true
		if config.type == "stdio" and existing.command == config.command and existing.args == config.args:
			return true
	return false

func _has_id(records: Dictionary, mcp_id: String) -> bool:
	for staff_records: Dictionary in records.values():
		if staff_records.has(mcp_id):
			return true
	return false

func _matches(pattern: String, value: String) -> bool:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null

func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
