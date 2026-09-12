# 本地 Fake Database

`fake_db.gd` 使用 Godot `Dictionary` 模拟数据表，并将全部数据保存到一个 CSV。

```text
harness_v2.csv
```

CSV 格式：

```text
table,id,tenant_id,data
```

- `table`：逻辑表名
- `id`：记录 ID
- `tenant_id`：所属租户
- `data`：完整记录的 JSON 文本，作为一个 CSV 单元格保存

仓库里的 CSV 是空库模板。Godot Web 运行时的数据保存在浏览器本地的
`user://harness_v2.csv`。

当前逻辑表：

```text
tenants
users
members
projects
chats
messages
knowledge_bases
documents
memories
agents
runs
events
```

业务代码不能直接访问 CSV；统一通过各模块的 Repository 操作数据。

## 员工权限表

`staff_permissions.csv` 保存七位员工的角色及 Chat、门户、知识库访问权限：

- `staff_id`：程序使用的员工 ID。
- `display_name`：员工显示名称。
- `role_code`：角色；主管为 `ADMIN`，其他员工为 `STAFF`。
- `can_chat`：是否显示 Chat。
- `can_portal`：是否显示门户。
- `can_knowledge`：是否显示知识库。
- `can_memory`：是否显示 Memory。
- `can_mcp`：是否显示 MCP。

权限值使用 `true` / `false`。修改 CSV 后重新运行 Godot 即可生效。
