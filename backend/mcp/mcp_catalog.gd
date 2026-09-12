extends RefCounted
## Reviewed catalog metadata. Selecting a record does not download or run it.

const ENTRIES := [
	{
		"id": "mcp-memory", "name": "记忆", "kind": "mcp",
		"description": "使用本地知识图谱保存和检索记忆。尚未接入 MCP 运行器。",
		"source_url": "https://github.com/modelcontextprotocol/servers/tree/main/src/memory",
		"package": "@modelcontextprotocol/server-memory",
		"connection_status": "not_connected",
	},
	{
		"id": "mcp-fetch", "name": "网页读取", "kind": "mcp",
		"description": "读取网页内容并转换为 Markdown。尚未接入 MCP 运行器。",
		"source_url": "https://github.com/modelcontextprotocol/servers/tree/main/src/fetch",
		"package": "mcp-server-fetch",
		"connection_status": "not_connected",
	},
]

static func list_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		result.append(entry.duplicate(true))
	return result

static func get_entry(tool_id: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry.id == tool_id:
			return entry.duplicate(true)
	return {}

static func has_entry(tool_id: String) -> bool:
	return not get_entry(tool_id).is_empty()
