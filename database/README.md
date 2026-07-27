# Fake Database

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
