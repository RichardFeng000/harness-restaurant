extends SceneTree
## Run: ./scripts/run.sh --headless --script tests/mcp_add_flow_test.gd
## Library/permissions use isolated saves and never contact external servers.

const MainScene = preload("res://frontend/scenes/main.tscn")
const Api = preload("res://backend/harness_api.gd")
const Store = preload("res://frontend/state/workspace_store.gd")
const MEMORY_ID := "mcp-memory"
const FETCH_ID := "mcp-fetch"
var failures: Array[String] = []
var temporary_dir := "/tmp/harness_mcp_library_%d" % Time.get_ticks_usec()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(temporary_dir)
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var main = MainScene.instantiate()
	main.api = Api.new(temporary_dir.path_join("database.csv"), false)
	main.store = Store.new(temporary_dir.path_join("save.json"), temporary_dir.path_join("workspace.json"))
	root.add_child(main)
	await _settle()
	main._reset_session()
	main._open_workspace(temporary_dir)
	main._start_agent_run()
	await _open_book(main)
	var book = main.harness_layer
	var page = book.mcp_page
	var runtime = main.api.skills
	book.show_mcp()
	await _settle()
	_check(page.add_button.name == "AddMcp" and page.add_button.is_visible_in_tree(), "MCP 标题右侧提供加号")
	var initial_mcp: Dictionary = runtime.export_mcp_state()
	var initial_permissions: Dictionary = runtime.export_permission_state()
	await _click(page.add_button)
	var panel = page.library_panel
	var portal = book.portal_page
	var permissions = portal.permissions_panel
	_check(panel.is_visible_in_tree() and not page.scroll.visible, "加号打开 MCP 库并收起已安装列表")
	_check(panel.find_child("McpUrl", true, false) == null and panel.find_child("McpCommand", true, false) == null, "MCP 库不提供服务地址或本地命令表单")
	_check(panel.item_views.has(MEMORY_ID) and panel.item_views.has(FETCH_ID), "库中提供可选择的 MCP 项目")
	_check_common_library(panel, "manager")
	await _escape()
	_check(not panel.visible and book.visible and not book.is_closing and not paused, "Esc 只关闭库，不合书或暂停餐厅")
	_check(runtime.export_mcp_state() == initial_mcp and runtime.export_permission_state() == initial_permissions, "退出库不修改安装和权限")
	_check(not page.cancel_library(), "库未打开时取消返回 false")
	await _click(page.add_button)
	await _click(book.staff_buttons["hamster"])
	_check(not panel.visible, "切换员工关闭库，避免沿用另一位员工身份")
	await _click(book.mcp_button)
	await _click(page.add_button)
	await _click(book.chat_button)
	_check(not panel.visible and runtime.export_mcp_state() == initial_mcp, "切换页面关闭库且不安装项目")
	await _click(book.mcp_button)
	await _click(page.add_button)
	_check_common_library(panel, "hamster")
	_check(not book.portal_button.visible, "普通员工没有主管门户入口")
	book.show_portal()
	_check(book.current_page == "chat", "普通员工直接请求门户仍受页面权限限制")
	portal.open_permissions("hamster")
	_check(not permissions.visible and portal.permission_target_id.is_empty(), "普通员工不能直接打开授权面板")
	await _click(book.mcp_button)
	await _click(page.add_button)
	var blocked_install := _library_button(panel, MEMORY_ID, "install")
	_check(blocked_install != null and blocked_install.disabled, "未授权的 MCP 禁止安装")
	await _click(blocked_install)
	_check(not runtime.is_installed("hamster", MEMORY_ID), "点击被禁用的安装按钮不会安装 MCP")
	_check(not runtime.install_skill("hamster", MEMORY_ID).get("ok", true), "运行时拒绝未经主管授权的安装")
	_check(not runtime.set_authorized("hamster", "hamster", MEMORY_ID, true).get("ok", true), "员工不能给自己授权")
	var catalog_name := str(_catalog_entry(runtime, "hamster", MEMORY_ID).get("name", ""))
	_fill(panel.search, catalog_name)
	await _settle()
	_check(panel.item_views.has(MEMORY_ID) and not panel.item_views.has(FETCH_ID), "搜索从库中筛选对应 MCP")
	_fill(panel.search, "")
	await _settle()

	# One grant permits employees to manage installation and use themselves.
	await _open_permissions(book, "hamster")
	_check_single_grants(permissions)
	await _click(_permission_box(permissions, MEMORY_ID))
	_check(runtime.is_authorized("hamster", MEMORY_ID) and runtime.get_permissions("hamster", MEMORY_ID) == {"can_install": true, "can_use": true}, "主管一次授权同时允许员工自行安装和启用")
	_check(_catalog_entry(runtime, "hamster", MEMORY_ID).get("authorized", false), "MCP 库反映当前员工的统一授权")
	_check(not runtime.is_installed("hamster", MEMORY_ID) and not runtime.is_enabled("hamster", MEMORY_ID), "主管授权不自动安装或启用 MCP")
	_check(book.current_staff_id == "manager" and book.current_page == "portal" and permissions.visible and portal.permission_target_id == "hamster", "在门户设置员工权限时保持主管身份")
	await _select_staff(book, "hamster")
	_check(not permissions.visible and portal.permission_target_id.is_empty(), "切换员工立即关闭旧授权上下文")
	permissions.permissions_requested.emit(MEMORY_ID, false)
	_check(runtime.is_authorized("hamster", MEMORY_ID), "失去主管身份后旧授权控件信号不能撤销授权")
	await _click(page.add_button)
	await _click(_library_button(panel, MEMORY_ID, "install"))
	_check(not panel.visible and page.scroll.visible, "库中安装成功后回到当前员工列表")
	_check(runtime.is_installed("hamster", MEMORY_ID) and not runtime.is_enabled("hamster", MEMORY_ID), "已授权 MCP 由员工安装后默认暂停")
	_check(not runtime.is_installed("manager", MEMORY_ID), "员工安装不影响主管名下工具")
	var enable := _entry_button(page, MEMORY_ID, "EnableSkill")
	_check(enable != null and not enable.disabled, "同一次授权允许员工自行启用已安装 MCP")
	await _click(_entry_button(page, MEMORY_ID, "SkillDetails"))
	var memory_row: Control = page.content.get_node_or_null("Skill_" + MEMORY_ID)
	_check(memory_row != null and _visible_text(memory_row).contains("未连接"), "库项目详情如实显示尚未连接")
	await _click(_entry_button(page, MEMORY_ID, "EnableSkill"))
	_check(runtime.is_enabled("hamster", MEMORY_ID), "员工可以直接启用，无须主管再次授权使用")
	await _click(_entry_button(page, MEMORY_ID, "PauseSkill"))
	_check(not runtime.is_enabled("hamster", MEMORY_ID), "已启用库项目可以暂停")
	await _click(_entry_button(page, MEMORY_ID, "EnableSkill"))
	_check(runtime.is_enabled("hamster", MEMORY_ID), "暂停后可以再次启用")

	# Revocation also stops the actual clock worker immediately.
	await _open_permissions(book, "hamster")
	await _click(_permission_box(permissions, MEMORY_ID))
	_check(not runtime.is_authorized("hamster", MEMORY_ID) and runtime.is_installed("hamster", MEMORY_ID) and not runtime.is_enabled("hamster", MEMORY_ID), "取消授权立即暂停且保留安装")
	_check(not runtime.set_enabled("hamster", MEMORY_ID, true).get("ok", true) and not runtime.execute("hamster", MEMORY_ID).get("ok", true), "收回权限后阻止启用和执行")
	_check(main.timekeeper.is_working(), "仓鼠本地时间默认运行")
	await _click(_permission_box(permissions, "local-time"))
	_check(runtime.is_installed("hamster", "local-time") and not main.timekeeper.is_working(), "收回时间权限后时钟员工立即停止")
	_check(not runtime.execute("hamster", "local-time").get("ok", true), "真实本地时间执行器同样受授权约束")
	await _click(_permission_box(permissions, "local-time"))
	_check(not main.timekeeper.is_working(), "重新授权不自动恢复时钟任务")
	await _click(_permission_box(permissions, MEMORY_ID))
	_check(runtime.is_authorized("hamster", MEMORY_ID) and not runtime.is_enabled("hamster", MEMORY_ID), "重新授权保留 MCP 的暂停状态")
	await _click(_permission_box(permissions, MEMORY_ID))
	await _select_staff(book, "hamster")
	_check(_entry_button(page, MEMORY_ID, "EnableSkill").disabled, "未授权的已安装 MCP 禁止从列表启用")
	await _confirm_uninstall(page, MEMORY_ID)
	_check(not runtime.is_installed("hamster", MEMORY_ID), "取消授权后员工仍可自行卸载")
	await _click(page.add_button)
	_check(_library_button(panel, MEMORY_ID, "install").disabled, "取消授权后库中禁止重新安装")
	_check(not runtime.install_skill("hamster", MEMORY_ID).get("ok", true), "取消授权后运行时同样拒绝重新安装")
	await _open_permissions(book, "hamster")
	await _click(_permission_box(permissions, MEMORY_ID))
	_check(runtime.is_authorized("hamster", MEMORY_ID) and not runtime.is_installed("hamster", MEMORY_ID), "重新授权不会自动装回员工已卸载的 MCP")
	await _select_staff(book, "hamster")
	await _click(page.add_button)
	await _click(_library_button(panel, MEMORY_ID, "install"))
	_check(runtime.is_installed("hamster", MEMORY_ID) and not runtime.is_enabled("hamster", MEMORY_ID), "重新授权后员工自行安装，仍等待主动启用")
	await _click(_entry_button(page, "local-time", "EnableSkill"))
	_check(main.timekeeper.is_working(), "员工重新启用后恢复时钟工作")

	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	await _settle()
	await _check_uninstall_flow(main, book, page, runtime)
	await _click(page.add_button)
	_check(page.size.x <= 335.0, "小窗口使用约 334px 宽的真实右书页")
	_check_library_width(page, "MCP 库")
	await _click(_library_button(panel, FETCH_ID, "details_button"))
	_check_library_width(page, "库详情")
	await _open_permissions(book, "hamster")
	_check_width(portal, permissions, "主管权限")
	_check_single_grants(permissions)
	var unchanged_permissions: Dictionary = runtime.export_permission_state()
	await _click(permissions.back_button)
	_check(not permissions.visible and portal.permission_target_id.is_empty() and book.current_page == "portal", "授权面板返回员工门户")
	_check_width(portal, portal, "主管员工列表")
	_fill(portal.search, "仓鼠")
	await _settle()
	_check(portal.staff_rows.size() == 1 and portal.staff_rows.has("hamster"), "门户搜索筛选授权员工")
	await _click(portal.staff_rows["hamster"])
	await _escape()
	_check(not permissions.visible and book.visible and not book.is_closing and book.current_page == "portal", "Esc 只返回员工门户，不合书")
	_check(runtime.export_permission_state() == unchanged_permissions, "返回或 Esc 不改变工具授权")
	await _click(portal.staff_rows["hamster"])
	await _click(book.mcp_button)
	_check(not permissions.visible and portal.permission_target_id.is_empty(), "切到 MCP 关闭门户授权面板")
	await _click(page.add_button)
	_check_common_library(panel, "manager")
	_check(page.cancel_library(), "打开的库可以取消")
	await _settle()
	_check(page.scroll.visible and book.visible and not book.is_closing, "取消库恢复列表而不合书")
	await _click(page.add_button)
	await _click(_library_button(panel, FETCH_ID, "install"))
	_check(runtime.is_installed("manager", FETCH_ID), "主管可按自身权限从库安装")
	_check(not runtime.is_enabled("manager", FETCH_ID), "主管与员工一样，安装后默认暂停")
	await _click(_entry_button(page, FETCH_ID, "EnableSkill"))
	_check(runtime.is_enabled("manager", FETCH_ID), "主管在同一 MCP 列表主动启用自己的工具")
	await _click(_entry_button(page, FETCH_ID, "PauseSkill"))
	_check(not runtime.is_enabled("manager", FETCH_ID), "主管在同一 MCP 列表暂停自己的工具")
	await _confirm_uninstall(page, FETCH_ID)
	_check(not runtime.is_installed("manager", FETCH_ID) and runtime.is_installed("hamster", MEMORY_ID), "卸载只删除对应安装，不影响其他员工")
	await _select_staff(book, "hamster")
	_check(not runtime.is_enabled("hamster", MEMORY_ID), "保存前 MCP 保持暂停状态")
	main._save_progress()
	var saved: Dictionary = main.store.load_progress()
	var saved_mcp: Dictionary = runtime.export_mcp_state()
	var saved_permissions: Dictionary = runtime.export_permission_state()
	_check(saved.get("mcp_servers") == JSON.parse_string(JSON.stringify(saved_mcp)), "餐厅存档保存 MCP 安装与暂停状态")
	_check(saved.get("staff_tool_permissions") == JSON.parse_string(JSON.stringify(saved_permissions)), "主管的工具权限单独保存到进度")
	main._back_to_menu()
	main._open_demo()
	main._start_agent_run()
	_check(not runtime.is_installed("hamster", MEMORY_ID) and runtime.get_permissions("hamster", MEMORY_ID) == {"can_install": false, "can_use": false}, "演示不沿用餐厅安装和授权")
	await _open_book(main)
	book.show_mcp()
	await _settle()
	await _open_permissions(book, "hamster")
	await _click(_permission_box(permissions, FETCH_ID))
	_check(runtime.is_authorized("hamster", FETCH_ID) and not runtime.is_installed("hamster", FETCH_ID), "主管一次授权不会自动安装")
	await _select_staff(book, "hamster")
	await _click(page.add_button)
	await _click(_library_button(panel, FETCH_ID, "install"))
	_check(runtime.is_installed("hamster", FETCH_ID), "演示也可体验主管授权与员工安装")
	_check(not runtime.is_enabled("hamster", FETCH_ID), "员工安装已授权的 MCP 后仍默认暂停")
	await _click(_entry_button(page, FETCH_ID, "EnableSkill"))
	_check(runtime.is_enabled("hamster", FETCH_ID), "员工手动启用后 MCP 才进入启用状态")
	await _click(_entry_button(page, FETCH_ID, "PauseSkill"))
	_check(not runtime.is_enabled("hamster", FETCH_ID), "员工可以再次暂停自行启用的 MCP")
	await _confirm_uninstall(page, FETCH_ID)
	_check(not runtime.is_installed("hamster", FETCH_ID) and runtime.get_permissions("hamster", FETCH_ID) == {"can_install": true, "can_use": true}, "员工可自行卸载 MCP，主管已授权限保持不变")
	main._save_progress()
	_check(main.store.load_progress() == saved, "演示安装和授权不污染餐厅存档")
	main._back_to_menu()
	main._continue_game()
	_check(not main.demo_mode and runtime.export_mcp_state() == saved_mcp, "继续餐厅恢复原 MCP 状态而非演示状态")
	if runtime.export_permission_state() != saved_permissions:
		print("Permission restore mismatch: expected=", saved_permissions, " actual=", runtime.export_permission_state())
	_check(runtime.export_permission_state() == saved_permissions, "继续餐厅恢复主管保存的权限")
	_check(runtime.is_installed("hamster", MEMORY_ID) and not runtime.is_enabled("hamster", MEMORY_ID) and not runtime.is_installed("hamster", FETCH_ID), "安装暂停状态完整恢复，演示工具隔离")
	await _finish(main)

func _check_uninstall_flow(main: Control, book: Control, page: Control, runtime: RefCounted) -> void:
	var initial_installation: Dictionary = runtime.export_state()
	var original_row: Control = page.content.get_node("Skill_local-time")
	var original_row_rect: Rect2 = original_row.get_global_rect()
	await _request_uninstall(page, "local-time")
	_check_floating_confirmation(page)
	_check(page.scroll.is_visible_in_tree() and page.page_header.is_visible_in_tree() and original_row.is_visible_in_tree(), "悬浮确认下方持续显示原 MCP 列表")
	_check(original_row.get_global_rect().is_equal_approx(original_row_rect), "悬浮确认不改变原列表位置")
	_check(runtime.export_state() == initial_installation and main.timekeeper.is_working(), "点击卸载后先确认，本地时间继续工作")
	await _check_modal_focus(page)
	await _click(book.chat_button)
	await _click(book.staff_buttons["manager"])
	await _click(book.close_button)
	await _click(_entry_button(page, "local-time", "PauseSkill"))
	await _click(_entry_button(page, "local-time", "SkillDetails"))
	await _click(page.add_button)
	_check(page.confirmation_panel.is_visible_in_tree() and book.current_page == "mcp" and book.current_staff_id == "hamster" and not book.is_closing, "真模态遮罩阻止背景页面、员工和合书操作")
	_check(runtime.export_state() == initial_installation and main.timekeeper.is_working() and not paused, "背景点击不能暂停工具或餐厅")
	_check(not page.item_views["local-time"].details.visible and not page.library_panel.visible, "背景点击不能展开工具详情或打开 MCP 库")
	_check(original_row.get_global_rect().is_equal_approx(original_row_rect), "背景点击期间原 MCP 列表位置保持不变")
	await _click(page.cancel_uninstall_button)
	_check(not page.confirmation_panel.is_visible_in_tree() and page.pending_uninstall_tool_id.is_empty() and page.pending_uninstall_staff_id.is_empty(), "取消清除待卸载的员工和工具")
	_check(runtime.export_state() == initial_installation and page.scroll.visible, "取消卸载返回原列表并保留安装状态")
	await _request_uninstall(page, "local-time")
	await _escape()
	_check(not page.confirmation_panel.is_visible_in_tree() and book.visible and not book.is_closing and not paused, "Esc 只取消卸载，不合书或暂停餐厅")
	_check(runtime.export_state() == initial_installation, "Esc 取消不会卸载或暂停")
	await _request_uninstall(page, "local-time")
	book.show_chat()
	await _settle()
	page.confirm_uninstall_button.pressed.emit()
	await _settle()
	_check(not page.confirmation_panel.is_visible_in_tree() and runtime.export_state() == initial_installation, "程序换页取消确认，旧确认信号不能继续卸载")
	await _select_staff(book, "manager")
	await _click(page.add_button)
	await _click(_library_button(page.library_panel, "local-time", "install"))
	_check(runtime.is_installed("manager", "local-time") and not runtime.is_enabled("manager", "local-time"), "主管也能从同一 MCP 库安装自己的本地时间")
	await _select_staff(book, "hamster")
	await _request_uninstall(page, "local-time")
	book._select_staff("manager")
	book.show_mcp()
	await _settle()
	page.confirm_uninstall_button.pressed.emit()
	await _settle()
	_check(not page.confirmation_panel.is_visible_in_tree() and runtime.is_installed("manager", "local-time") and runtime.is_installed("hamster", "local-time"), "程序换员工取消确认，旧信号不能卸载任何一位员工的同名工具")
	await _confirm_uninstall(page, "local-time")
	_check(not runtime.is_installed("manager", "local-time") and runtime.is_installed("hamster", "local-time"), "主管确认卸载自己的工具不影响仓鼠安装")
	await _select_staff(book, "hamster")
	await _request_uninstall(page, "local-time")
	main._close_harness()
	await create_timer(0.8).timeout
	page.confirm_uninstall_button.pressed.emit()
	await _settle()
	_check(not book.visible and not page.confirmation_panel.is_visible_in_tree() and runtime.is_installed("hamster", "local-time"), "程序合书动画关闭待确认面板，旧信号不能继续卸载")
	await _open_book(main)
	await _click(book.mcp_button)
	_check(not page.confirmation_panel.is_visible_in_tree() and main.timekeeper.is_working(), "重新开书保留原安装且不恢复过期确认")
	await _confirm_uninstall(page, "local-time")
	_check(not runtime.is_installed("hamster", "local-time") and not main.timekeeper.is_working(), "确认卸载一次即移除本地时间并停止真实时钟员工")
	_check(runtime.is_authorized("hamster", "local-time"), "员工卸载保留主管原来的授权")
	page.confirm_uninstall_button.pressed.emit()
	await _settle()
	_check(not runtime.is_installed("hamster", "local-time") and page.pending_uninstall_tool_id.is_empty(), "重复确认不重新执行卸载或恢复待确认状态")
	await _click(page.add_button)
	var reinstall := _library_button(page.library_panel, "local-time", "install")
	_check(not reinstall.disabled, "保留授权的本地时间可从加号重新安装")
	await _click(reinstall)
	_check(runtime.is_installed("hamster", "local-time") and not runtime.is_enabled("hamster", "local-time") and not main.timekeeper.is_working(), "加号重装默认暂停，由仓鼠自行选择启用")
	_check(page.content.get_node_or_null("Skill_local-time") != null and not page.library_panel.visible, "重装后工具重新出现在 MCP 列表")
	await _click(_entry_button(page, "local-time", "EnableSkill"))
	_check(main.timekeeper.is_working(), "重装后员工自行启用可恢复真实时钟工作")

func _request_uninstall(page: Control, tool_id: String) -> void:
	await _click(_entry_button(page, tool_id, "UninstallSkill"))
	_check(page.confirmation_overlay.is_visible_in_tree() and page.confirmation_panel.is_visible_in_tree() and page.pending_uninstall_tool_id == tool_id and page.pending_uninstall_staff_id == page.selected_staff_id, "悬浮卸载先确认当前员工的指定工具")

func _confirm_uninstall(page: Control, tool_id: String) -> void:
	await _request_uninstall(page, tool_id)
	await _click(page.confirm_uninstall_button)
	_check(not page.confirmation_panel.is_visible_in_tree() and not page.confirmation_overlay.visible and page.pending_uninstall_tool_id.is_empty() and page.pending_uninstall_staff_id.is_empty(), "确认卸载后关闭遮罩并清除待确认状态")
	_check(page.content.get_node_or_null("Skill_" + tool_id) == null and not page.item_views.has(tool_id), "卸载项目从 MCP 主列表消失")
	_check(page.content.find_child("InstallSkill", true, false) == null, "MCP 主列表没有卸载项目的安装按钮")

func _check_floating_confirmation(page: Control) -> void:
	var viewport_rect := root.get_visible_rect()
	var card: Rect2 = page.confirmation_panel.get_global_rect()
	_check(page.confirmation_overlay.get_global_rect().is_equal_approx(viewport_rect), "半透明遮罩覆盖整个视口")
	_check(card.get_center().distance_to(viewport_rect.get_center()) < 1.0, "确认卡片悬浮于视口中央")
	_check(card.size.x <= minf(360.0, viewport_rect.size.x - 32.0) + 1.0, "确认卡片保持紧凑宽度并留出边距")
	_check(card.position.x >= viewport_rect.position.x and card.end.x <= viewport_rect.end.x and card.position.y >= viewport_rect.position.y and card.end.y <= viewport_rect.end.y, "悬浮卡片完整显示在视口中")

func _check_modal_focus(page: Control) -> void:
	var buttons := [page.cancel_uninstall_button, page.confirm_uninstall_button]
	_check(root.gui_get_focus_owner() in buttons, "打开卸载确认时焦点进入悬浮窗")
	for backwards in [false, false, false, false, true, true, true]:
		var previous := root.gui_get_focus_owner()
		for pressed in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_TAB
			event.physical_keycode = KEY_TAB
			event.shift_pressed = backwards
			event.pressed = pressed
			root.push_input(event)
		await _settle()
		_check(root.gui_get_focus_owner() in buttons and root.gui_get_focus_owner() != previous, "Tab 与 Shift+Tab 只在取消和卸载之间循环")

func _select_staff(book: Control, staff_id: String) -> void:
	await _click(book.staff_buttons[staff_id])
	await _click(book.mcp_button)

func _open_permissions(book: Control, target: String) -> void:
	if book.current_staff_id != "manager":
		await _select_staff(book, "manager")
	await _click(book.portal_button)
	var portal = book.portal_page
	if portal.permissions_panel.visible:
		await _click(portal.permissions_panel.back_button)
	_fill(portal.search, "")
	await _settle()
	_check(portal.staff_rows.has(target), "门户提供授权员工 " + target)
	await _click(portal.staff_rows.get(target))
	_check(book.current_staff_id == "manager" and portal.selected_id == "manager" and book.staff_buttons["manager"].button_pressed, "点击门户员工行不会切换主管身份")
	_check(book.current_page == "portal" and portal.permission_target_id == target and portal.permissions_panel.is_visible_in_tree(), "门户员工行打开对应的授权面板")

func _check_common_library(panel: Control, staff_id: String) -> void:
	_check(panel.actor_staff_id == staff_id, "MCP 库对应当前员工自己的工具")
	_check(panel.find_child("LibraryPermissions", true, false) == null and panel.find_child("LibraryTarget", true, false) == null, "主管与仓鼠的 MCP 库都没有授权或目标员工控件")
	_check(panel.find_children("*", "CheckBox", true, false).is_empty() and panel.find_children("*", "OptionButton", true, false).is_empty(), "相同的 MCP 库只管理当前员工安装，不包含授权复选框或员工选择器")
	for tool_id: String in panel.item_views:
		var view: Dictionary = panel.item_views[tool_id]
		_check(view.has("install") and view.has("details_button") and not view.has("can_install") and not view.has("can_use"), "主管与仓鼠使用相同的 MCP 安装和详情操作")

func _catalog_entry(runtime: RefCounted, staff_id: String, id: String) -> Dictionary:
	for entry: Dictionary in runtime.list_catalog(staff_id):
		if entry.get("id") == id:
			return entry
	return {}

func _library_button(panel: Control, id: String, key: String) -> Button:
	var button: Button = panel.item_views.get(id, {}).get(key)
	_check(button != null, "库中 %s 提供 %s" % [id, key])
	return button

func _permission_box(panel: Control, id: String) -> CheckBox:
	var box: CheckBox = panel.item_views.get(id, {}).get("authorized")
	_check(box != null, "主管可为 %s 授权" % id)
	return box

func _check_single_grants(panel: Control) -> void:
	_check(not panel.item_views.is_empty(), "主管授权面板列出 MCP 库项目")
	for tool_id: String in panel.item_views:
		var view: Dictionary = panel.item_views[tool_id]
		var box := _permission_box(panel, tool_id)
		_check(box != null and box.name == "ToolAuthorized" and box.text == "授权", "每个 MCP 只有一个名为授权的控件")
		_check(view.item.find_children("*", "CheckBox", true, false).size() == 1, "每个 MCP 只有一个授权复选框")
		_check(view.item.find_child("CanInstall", true, false) == null and view.item.find_child("CanUse", true, false) == null, "主管界面不再分开设置安装和使用")
		var captions := _visible_text(view.item).split("\n")
		_check(not captions.has("安装") and not captions.has("使用"), "授权行不再显示安装或使用文案")

func _check_library_width(page: Control, context: String) -> void:
	_check_width(page, page.library_panel, context)

func _check_width(page: Control, panel: Control, context: String) -> void:
	var bounds := page.get_global_rect()
	_check(panel.is_visible_in_tree(), "宽度检查对象必须显示：" + context)
	_check(panel.size.x <= page.size.x + 1.0, "内容不撑宽纸页：" + context)
	for control in panel.find_children("*", "Control", true, false):
		if control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			_check(rect.position.x >= bounds.position.x - 1.0 and rect.end.x <= bounds.end.x + 1.0, "控件不横向溢出：%s / %s" % [context, control.name])

func _entry_button(page: Control, id: String, control_name: String) -> Button:
	var row: Control = page.content.get_node_or_null("Skill_" + id)
	var button: Button = row.find_child(control_name, true, false) if row != null else null
	_check(button != null, "MCP 项目提供操作 " + control_name)
	return button

func _visible_text(parent: Control) -> String:
	var texts := PackedStringArray()
	for control in parent.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and (control is Label or control is Button):
			texts.append(str(control.text))
	return "\n".join(texts)

func _fill(control: Control, value: String) -> void:
	control.text = value
	if control is LineEdit:
		control.text_changed.emit(value)
	elif control is TextEdit:
		control.text_changed.emit()

func _open_book(main: Control) -> void:
	await _click(main.hud.book_button)
	var deadline := Time.get_ticks_msec() + 1050
	while Time.get_ticks_msec() < deadline:
		await process_frame

func _click(control: Control) -> void:
	if control == null:
		_check(false, "待点击的控件必须存在")
		return
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _settle()
	var center := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await _settle()

func _escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event)
	await _settle()

func _settle() -> void:
	for frame in 4:
		await process_frame

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _finish(main: Control) -> void:
	main._back_to_menu()
	main.queue_free()
	await process_frame
	for filename in ["save.json", "workspace.json", "database.csv"]:
		var path := temporary_dir.path_join(filename)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(temporary_dir)
	for failure in failures:
		push_error(failure)
	print("MCP library flow test: ", "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	quit(0 if failures.is_empty() else 1)
