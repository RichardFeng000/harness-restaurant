extends SceneTree
const Runtime = preload("res://backend/skills/staff_skill_runtime.gd")
const TIME := "local-time"
const MEMORY := "mcp-memory"
var failures: Array[String] = []

class FakeTimeReader:
	extends RefCounted
	var calls := 0
	func execute() -> Dictionary:
		calls += 1
		return {"ok": true, "data": {"hour": 10, "minute": 20, "second": 30}}

func _initialize() -> void:
	_test_grants()
	_test_revocation()
	_test_restore()
	_test_legacy_migration()
	if failures.is_empty():
		print("MCP permissions test: PASS")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _test_grants() -> void:
	var reader := FakeTimeReader.new()
	var runtime := Runtime.new(reader)
	for entry: Dictionary in runtime.list_catalog("manager"):
		_expect(entry.authorized and entry.can_install and entry.can_use and not entry.installed, "主管默认已授权所有工具")
	_expect(runtime.get_permissions("hamster", TIME) == {"can_install": true, "can_use": true}, "仓鼠默认时间权限")
	for staff: String in ["cashier", "head_chef", "sous_chef", "expeditor", "waiter"]:
		for entry: Dictionary in runtime.list_catalog(staff):
			_expect(not entry.authorized and not entry.can_install and not entry.can_use, "员工默认未授权")
		_expect(not runtime.install_skill(staff, TIME).ok and not runtime.install_catalog(staff, MEMORY).ok, "未获授权的员工不能安装")
		_expect(not runtime.set_authorized(staff, staff, TIME, true).ok, "员工不能给自己提权")
	_expect(not runtime.has_method("set_permissions"), "不保留可独立修改安装和使用权的接口")
	_expect(not runtime.set_authorized("unknown", "hamster", TIME, false).ok, "未知角色不能撤销授权")
	_expect(not runtime.set_authorized("manager", "unknown", TIME, true).ok, "不能给未知员工授权")
	_expect(not runtime.set_authorized("manager", "waiter", "unknown", true).ok, "不能给未知工具授权")
	for invalid: Variant in ["true", 1, 0, null, {}]:
		_expect(not runtime.set_authorized("manager", "waiter", TIME, invalid).ok, "授权参数拒绝非布尔值")
	_expect(not runtime.execute("waiter", TIME).ok and reader.calls == 0, "未授权操作无法触达读取器")
	_expect(runtime.set_authorized("manager", "waiter", TIME, true).ok, "主管单次授权")
	_expect(runtime.is_authorized("waiter", TIME) and not runtime.is_installed("waiter", TIME), "授权不会替员工安装")
	_expect(runtime.install_skill("waiter", TIME).ok and runtime.is_installed("waiter", TIME) and not runtime.is_enabled("waiter", TIME), "授权后员工自行安装，安装后保持暂停")
	_expect(not runtime.execute("waiter", TIME).ok and reader.calls == 0, "新安装必须由员工启用才执行")
	_expect(runtime.set_enabled("waiter", TIME, true).ok and runtime.execute("waiter", TIME).ok and reader.calls == 1, "同一授权允许员工自行启用和执行")
	_expect(runtime.uninstall_skill("waiter", TIME).ok and runtime.install_skill("waiter", TIME).ok, "授权持续有效时可自行卸载和重装")
	var grant := runtime.get_permissions("waiter", TIME)
	grant.can_install = false
	grant.can_use = false
	_expect(runtime.get_permissions("waiter", TIME) == {"can_install": true, "can_use": true}, "兼容字段来自同一授权且不泄露可变引用")
	for entry: Dictionary in runtime.list_catalog("waiter") + runtime.list_skills("waiter"):
		_expect(entry.authorized == entry.can_install and entry.authorized == entry.can_use, "列表里的只读兼容字段不会分叉")

func _test_revocation() -> void:
	var reader := FakeTimeReader.new()
	var runtime := Runtime.new(reader)
	var changes: Array = []
	runtime.skill_changed.connect(func(staff_id: String, tool_id: String): changes.append([staff_id, tool_id]))
	runtime.execute("hamster", TIME)
	runtime.set_authorized("manager", "hamster", TIME, false)
	_expect(runtime.is_installed("hamster", TIME) and not runtime.is_enabled("hamster", TIME), "收回授权立即停用且保留安装")
	_expect(changes.has(["hamster", TIME]), "权限撤销通知时间执行器立即停止")
	_expect(runtime.list_skills("hamster")[0].last_result.is_empty(), "收回授权清除旧执行结果")
	_expect(not runtime.execute("hamster", TIME).ok and reader.calls == 1, "权限撤销后无法触达读取器")
	_expect(not runtime.set_enabled("hamster", TIME, true).ok and not runtime.install_skill("hamster", TIME).ok, "撤销同时阻止安装与启用")
	_expect(runtime.set_enabled("hamster", TIME, false).ok, "收回授权仍可自行暂停")
	runtime.set_authorized("manager", "hamster", TIME, true)
	_expect(not runtime.is_enabled("hamster", TIME), "重新授权不会自动恢复已暂停的工具")
	runtime.set_enabled("hamster", TIME, true)
	_expect(runtime.execute("hamster", TIME).ok and reader.calls == 2, "重新启用才恢复真实执行")
	runtime.set_authorized("manager", "hamster", MEMORY, true)
	_expect(not runtime.is_installed("hamster", MEMORY), "主管授权不会替员工安装工具")
	runtime.install_catalog("hamster", MEMORY)
	_expect(not runtime.is_enabled("hamster", MEMORY), "即使已授权，新安装 MCP 仍默认暂停")
	runtime.set_enabled("hamster", MEMORY, true)
	runtime.set_authorized("manager", "hamster", MEMORY, false)
	_expect(runtime.is_installed("hamster", MEMORY) and not runtime.is_enabled("hamster", MEMORY), "MCP 和 Skill 使用同一撤销规则")
	_expect(not runtime.set_enabled("hamster", MEMORY, true).ok and not runtime.execute("hamster", MEMORY).ok, "MCP 后端不可绕过权限")
	_expect(runtime.set_enabled("hamster", MEMORY, false).ok and runtime.uninstall_skill("hamster", MEMORY).ok, "已收回授权的 MCP 仍可自行暂停和卸载")
	_expect(not runtime.install_catalog("hamster", MEMORY).ok, "卸载后未经授权不能重装")
	runtime.set_authorized("manager", "hamster", MEMORY, true)
	_expect(not runtime.is_enabled("hamster", MEMORY), "MCP 重新授权也不会自动启用")
	_expect(not runtime.is_installed("hamster", MEMORY), "重新授权也不自动重装")
	runtime.set_authorized("manager", "hamster", TIME, false)
	_expect(runtime.uninstall_skill("hamster", TIME).ok, "撤销后 Skill 也允许员工卸载")

func _test_restore() -> void:
	var runtime := Runtime.new(FakeTimeReader.new())
	runtime.set_authorized("manager", "waiter", TIME, true)
	runtime.install_skill("waiter", TIME)
	_expect(not runtime.is_enabled("waiter", TIME), "即使已授权，新安装 Skill 仍默认暂停")
	runtime.set_enabled("waiter", TIME, true)
	runtime.set_authorized("manager", "hamster", TIME, false)
	var grants := runtime.export_permission_state()
	_expect(grants.version == 2 and grants.staff.waiter[TIME] == {"authorized": true} and grants.staff.hamster[TIME] == {"authorized": false}, "存档只有一个授权值")
	var restored := Runtime.new(FakeTimeReader.new())
	restored.restore_state(JSON.parse_string(JSON.stringify(runtime.export_state())))
	restored.restore_mcp_state(runtime.export_mcp_state())
	restored.restore_permission_state(JSON.parse_string(JSON.stringify(grants)))
	_expect(restored.is_enabled("waiter", TIME) and not restored.is_enabled("hamster", TIME), "保存恢复同时保留授权与撤销")
	grants.staff.waiter[TIME].authorized = false
	_expect(runtime.is_authorized("waiter", TIME) and restored.is_authorized("waiter", TIME), "导出和恢复的存档副本不能更改内部授权")
	var bad := {"version": 2, "staff": {
		"waiter": {TIME: {"authorized": "true"}, MEMORY: true, "unknown": {"authorized": true}},
		"hamster": {TIME: {"can_install": true, "can_use": true}},
		"manager": {TIME: {"authorized": 1}},
		"unknown": {TIME: {"authorized": true}},
	}}
	restored.restore_permission_state(bad)
	_expect(not restored.get_permissions("waiter", TIME).can_use and not restored.get_permissions("waiter", TIME).can_install, "无效权限记录不能获取执行权")
	_expect(not restored.is_authorized("manager", TIME) and not restored.is_authorized("hamster", TIME), "无效授权记录覆盖默认授权，不接受数字或旧字段")
	_expect(restored.is_installed("waiter", TIME) and not restored.is_enabled("waiter", TIME), "恢复时撤销越权启用状态但不删除安装")
	_expect(not restored.export_permission_state().staff.has("unknown") and not restored.export_permission_state().staff.waiter.has("unknown"), "忽略未知员工和未知工具授权")
	restored.restore_state(null)
	_expect(restored.get_permissions("hamster", TIME).can_use and not restored.get_permissions("waiter", TIME).can_use, "演示重置恢复默认授权，不泄漏餐厅状态")
	for invalid_version: Variant in [true, "2", 2.5, 3]:
		restored.restore_permission_state({"version": invalid_version, "staff": {"waiter": {TIME: {"authorized": true}}}})
		_expect(not restored.is_authorized("waiter", TIME), "只接受版本 1 或 2 的数值存档")

func _test_legacy_migration() -> void:
	var runtime := Runtime.new(FakeTimeReader.new())
	var legacy := {"version": 1, "staff": {
		"waiter": {TIME: {"can_install": true, "can_use": true}},
		"cashier": {TIME: {"can_install": true, "can_use": false}},
		"head_chef": {TIME: {"can_install": false, "can_use": true}},
		"sous_chef": {TIME: {"can_install": false, "can_use": false}},
		"expeditor": {TIME: {"can_install": true, "can_use": "true"}},
		"hamster": {TIME: {"can_use": true}},
		"manager": {TIME: null},
	}}
	for state: Dictionary in [legacy, JSON.parse_string(JSON.stringify(legacy))]:
		runtime.restore_state(null)
		runtime.restore_permission_state(state)
		_expect(runtime.is_authorized("waiter", TIME), "旧存档双权限严格为真时迁移为授权")
		for staff: String in ["cashier", "head_chef", "sous_chef", "expeditor", "hamster", "manager"]:
			_expect(not runtime.is_authorized(staff, TIME), "旧单项权限、缺失字段和非布尔值不得扩展成完整授权")
		_expect(runtime.is_installed("hamster", TIME) and not runtime.is_enabled("hamster", TIME), "旧部分权限的仓鼠保留安装但立即暂停")
		var migrated := runtime.export_permission_state()
		_expect(migrated.version == 2 and migrated.staff.waiter[TIME] == {"authorized": true} and migrated.staff.cashier[TIME] == {"authorized": false}, "旧存档迁移后只写入单个授权字段")
		runtime.restore_permission_state(JSON.parse_string(JSON.stringify(migrated)))
		_expect(runtime.is_authorized("waiter", TIME) and not runtime.is_authorized("cashier", TIME), "迁移后的 JSON 存档可再次恢复")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
