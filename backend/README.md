# Harness Kitchen Backend

每个业务模块采用相同的三层文件夹结构：

```text
controller/   接收 API 参数
service/      校验和业务规则
repository/   访问假数据库
```

完整目录：

```text
backend/
├── harness_api.gd
├── tenant/
│   ├── controller/tenant_controller.gd
│   ├── service/tenant_service.gd
│   └── repository/tenant_repository.gd
├── chat/
│   ├── controller/chat_controller.gd
│   ├── service/chat_service.gd
│   └── repository/chat_repository.gd
├── knowledge/
│   ├── controller/knowledge_controller.gd
│   ├── service/knowledge_service.gd
│   └── repository/knowledge_repository.gd
├── memory/
│   ├── controller/memory_controller.gd
│   ├── service/memory_service.gd
│   └── repository/memory_repository.gd
├── system/
│   ├── controller/system_controller.gd
│   ├── service/system_service.gd
│   └── repository/system_repository.gd
├── run/
│   ├── controller/run_controller.gd
│   ├── service/run_service.gd
│   └── repository/run_repository.gd
├── skills/staff_skill_runtime.gd
└── mcp/
    ├── mcp_catalog.gd
    └── mcp_registry.gd
```

假数据库位于与前后端同级的 `database/fake_db.gd`。所有模块共享同一个数据库
实例，但必须通过各自 Repository 访问。
前端仍然只调用 `res://backend/harness_api.gd`。

系统接口：

```text
GET  /api/v2/system/health
GET  /api/v2/system/info
POST /api/v2/database/save
```

## 员工技能运行时

`HarnessApi.skills` 由 `skills/staff_skill_runtime.gd` 提供。运行时执行前检查员工的使用授权、安装与启用状态，结果通过 `execution_completed` 信号通知界面。当前仅捆绑 `game/skills/local-time/`，仓鼠默认安装并获得授权；此接口是本地原型的执行边界，不是远程用户认证服务。

`export_state()` / `restore_state()` 仅保存安装与启用状态，兼容没有 `staff_skills` 字段的旧餐厅存档。真实时间样本仅保存在内存中。

## MCP 库与主管授权

`list_catalog(staff_id)` 返回项目库中的工具及该员工的 `authorized` 状态，`can_install`、`can_use` 是同一授权的只读映射。`install_skill(staff_id, tool_id)` 只接受库中工具并检查授权。旧的 `add_mcp()` 自定义地址接口拒绝新增，旧配置仅保留展示与卸载能力。

`set_authorized(actor_staff_id, target_staff_id, tool_id, authorized)` 仅允许主管 `manager` 更新单一授权，前端入口位于「门户 → 员工」。授权允许员工自行安装、启用和使用工具；主管与员工的 MCP 界面相同。授权不自动安装，员工新安装工具时默认暂停，需主动启用。撤销授权立即停用，恢复授权不自动启用。暂停、卸载仍然可用。授权作用于本地时间 Skill 和 MCP 库项目，运行时直接调用也检查授权。

已选 MCP 通过 `list_skills()` 返回，标记 `kind: "mcp"`、`connection_status: "not_connected"`。当前库项目只登记到员工工具列表，不建立外部连接、不启动进程；执行请求会明确返回“尚未连接”。

保存进度时，`export_mcp_state()` 写入 `mcp_servers`，`export_permission_state()` 写入 `staff_tool_permissions`，保留原 `staff_skills` 格式。恢复时先停止时间调度，依次调用 `restore_state()`、`restore_mcp_state()`、`restore_permission_state()`，再恢复调度；缺少授权字段的旧存档采用默认授权，演示重置清空 MCP 并重置授权。

授权存档版本 2 每项仅保存 `authorized`。版本 1 中安装、使用两项都为 `true` 时迁移为已授权，其余组合迁移为未授权，避免合并时扩大旧权限。
