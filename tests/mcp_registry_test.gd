extends SceneTree
## Catalog and legacy migration tests. No MCP process or network connection.
const Runtime = preload("res://backend/skills/staff_skill_runtime.gd")
const MEMORY := "mcp-memory"
const FETCH := "mcp-fetch"
const LEGACY := "mcp-11111111111111111111111111111111"
var failures: Array[String] = []

func _initialize() -> void:
	_test_catalog()
	_test_round_trip()
	_test_legacy_migration()
	if failures.is_empty():
		print("MCP registry test: PASS")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _test_catalog() -> void:
	var runtime := Runtime.new()
	var catalog := runtime.list_catalog("manager")
	_expect(catalog.size() == 3 and catalog[0].id == "local-time" and catalog[0].kind == "skill", "目录保留真实 Skill 类型")
	_expect(catalog[1].id == MEMORY and catalog[2].id == FETCH, "只列出审核过的 MCP 库条目")
	_expect(catalog[1].source_url.begins_with("https://github.com/modelcontextprotocol/servers/"), "库条目提供官方来源")
	_expect(not runtime.add_mcp("manager", {"name": "任意配置", "type": "stdio", "command": "arbitrary"}).ok, "旧任意配置入口关闭")
	_expect(not runtime.install_catalog("manager", "mcp-unknown").ok, "不安装目录外 ID")
	_expect(runtime.install_catalog("manager", MEMORY).ok, "主管可以从库添加 MCP")
	var entry: Dictionary = runtime.list_skills("manager")[0]
	_expect(entry.id == MEMORY and entry.kind == "mcp" and entry.installed and not entry.enabled, "库选择进入已分配列表且等待员工启用")
	_expect(entry.connection_status == "not_connected" and not entry.has("config"), "不伪造连接或随意编辑底层配置")
	_expect(runtime.set_enabled("manager", MEMORY, true).ok, "安装后由员工手动启用 MCP")
	var result := runtime.execute("manager", MEMORY)
	_expect(not result.ok and result.connection_status == "not_connected", "尚未接入的运行器明确拒绝执行")
	runtime.set_enabled("manager", MEMORY, false)
	runtime.install_catalog("manager", MEMORY)
	_expect(runtime.list_skills("manager").size() == 1 and not runtime.is_enabled("manager", MEMORY), "重复选择不重复安装、不覆盖暂停")
	_expect(runtime.list_skills("waiter").is_empty(), "员工安装记录隔离")
	catalog[1].name = "修改"
	entry.name = "修改"
	_expect(runtime.list_catalog("manager")[1].name == "记忆", "目录返回独立副本")
	_expect(runtime.uninstall_skill("manager", MEMORY).ok and runtime.list_skills("manager").is_empty(), "卸载从列表移除，库保留可再次选择")
	_expect(runtime.install_catalog("manager", MEMORY).ok, "库内条目可以重新安装")

func _test_round_trip() -> void:
	var runtime := Runtime.new()
	runtime.install_catalog("manager", MEMORY)
	runtime.set_authorized("manager", "waiter", FETCH, true)
	runtime.install_catalog("waiter", FETCH)
	runtime.set_enabled("waiter", FETCH, true)
	runtime.set_enabled("manager", MEMORY, false)
	var state := runtime.export_mcp_state()
	_expect(state.version == 2 and state.staff.manager[MEMORY] == {"enabled": false, "catalog_id": MEMORY}, "MCP 存档只包含库 ID 和启用状态")
	var restored := Runtime.new()
	restored.restore_state(runtime.export_state())
	restored.restore_mcp_state(JSON.parse_string(JSON.stringify(state)))
	restored.restore_permission_state(JSON.parse_string(JSON.stringify(runtime.export_permission_state())))
	_expect(restored.is_installed("manager", MEMORY) and not restored.is_enabled("manager", MEMORY), "主管暂停状态恢复")
	_expect(restored.is_installed("waiter", FETCH) and restored.is_enabled("waiter", FETCH), "员工授权和安装按顺序恢复")
	state.staff.waiter[FETCH].enabled = false
	_expect(restored.is_enabled("waiter", FETCH), "恢复没有共享可变引用")
	var corrupted := runtime.export_mcp_state()
	corrupted.staff.manager[MEMORY].connection_status = "connected"
	corrupted.staff.manager[MEMORY].config = {"command": "anything"}
	corrupted.staff.manager["mcp-injected"] = {"enabled": true, "catalog_id": "mcp-injected"}
	corrupted.staff["unknown"] = {MEMORY: {"enabled": true, "catalog_id": MEMORY}}
	restored.restore_mcp_state(corrupted)
	_expect(restored.export_mcp_state() == runtime.export_mcp_state(), "过滤不可信存档的未知工具、未知员工和注入字段")
	restored.restore_state(null)
	_expect(restored.list_skills("manager").is_empty() and restored.list_skills("hamster").size() == 1, "餐厅重置清空 MCP 但恢复仓鼠内置技能")
	_expect(not restored.get_permissions("waiter", FETCH).can_use, "餐厅重置清除前餐厅授权")

func _test_legacy_migration() -> void:
	var runtime := Runtime.new()
	var old := {"version": 1, "staff": {"manager": {LEGACY: {
		"enabled": true, "config": {"name": "旧工具", "type": "http", "url": "https://example.test/mcp"},
	}}}}
	runtime.restore_mcp_state(old)
	var entries := runtime.list_skills("manager")
	_expect(entries.size() == 1 and entries[0].legacy and entries[0].config.url == "https://example.test/mcp", "旧自定义配置保留以免丢失用户数据")
	_expect(entries[0].installed and not entries[0].enabled and not entries[0].can_use and not entries[0].can_install, "旧配置不可绕过库授权")
	_expect(not runtime.set_authorized("manager", "manager", LEGACY, true).ok, "主管也不能授权目录外任意配置")
	_expect(not runtime.set_enabled("manager", LEGACY, true).ok and not runtime.execute("manager", LEGACY).ok, "迁移条目不能启用或执行")
	var migrated := runtime.export_mcp_state()
	_expect(migrated.version == 2 and migrated.staff.manager[LEGACY].config == old.staff.manager[LEGACY].config, "迁移后保存原配置信息")
	runtime.restore_mcp_state(migrated)
	_expect(runtime.list_skills("manager")[0].legacy, "新版存档仍能读取迁移数据")
	_expect(runtime.uninstall_skill("manager", LEGACY).ok and runtime.list_skills("manager").is_empty(), "迁移条目可以卸载")
	for bad: Variant in [null, [], {}, {"version": true, "staff": old.staff}, {"version": 3, "staff": old.staff}]:
		runtime.restore_mcp_state(old)
		runtime.restore_mcp_state(bad)
		_expect(runtime.list_skills("manager").is_empty(), "无效存档不会保留上一餐厅配置")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
