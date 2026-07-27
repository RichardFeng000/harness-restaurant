extends SceneTree

const ApiScript = preload("res://backend/harness_api.gd")

var failures: Array[String] = []

func _init() -> void:
	var api = ApiScript.new("user://harness_v2_test.csv", false)
	var health = api.request("GET", "/api/v2/system/health")
	_expect(health["status"] == 200, "系统健康检查失败")
	var bootstrap = api.request("POST", "/api/v2/bootstrap")
	_expect(bootstrap["status"] == 201, "初始化失败")

	var seed: Dictionary = bootstrap["body"]["data"]
	var tenant_id: String = seed["tenant"]["id"]
	var project_id: String = seed["project"]["id"]
	var agent_id: String = seed["agent"]["id"]
	var context := {"tenant_id": tenant_id}

	var chat = api.request("POST", "/api/v2/chats", {
		"project_id": project_id,
		"title": "测试对话",
	}, context)
	_expect(chat["status"] == 201, "创建对话失败")
	var chat_id: String = chat["body"]["data"]["id"]

	var message = api.request("POST", "/api/v2/chats/%s/messages" % chat_id, {
		"role": "user",
		"content": "Harness 是什么？",
	}, context)
	_expect(message["status"] == 201, "创建消息失败")
	var messages = api.request("GET", "/api/v2/chats/%s/messages" % chat_id, {}, context)
	_expect(messages["body"]["data"].size() == 1, "消息列表错误")

	var knowledge = api.request("POST", "/api/v2/knowledge", {
		"project_id": project_id,
		"name": "产品知识",
	}, context)
	var knowledge_id: String = knowledge["body"]["data"]["id"]
	api.request("POST", "/api/v2/knowledge/%s/documents" % knowledge_id, {
		"title": "Harness V2",
		"content": "Harness V2 是一个轻量 Agent 运行平台。",
	}, context)
	var search = api.request("GET", "/api/v2/knowledge/search", {"query": "Agent"}, context)
	_expect(search["body"]["data"].size() == 1, "知识检索失败")

	var memory = api.request("POST", "/api/v2/memories", {
		"scope": "user",
		"subject_id": seed["user"]["id"],
		"content": "用户偏好中文回答",
		"importance": 0.8,
	}, context)
	_expect(memory["status"] == 201, "创建记忆失败")

	var run = api.request("POST", "/api/v2/runs", {
		"project_id": project_id,
		"agent_id": agent_id,
		"chat_id": chat_id,
		"task": "回答用户问题",
	}, context)
	_expect(run["status"] == 201, "创建 Run 失败")
	var run_id: String = run["body"]["data"]["id"]
	var fetched_run = api.request("GET", "/api/v2/runs/%s" % run_id, {}, context)
	_expect(fetched_run["body"]["data"]["events"].size() == 1, "Run 事件缺失")

	var other_tenant = api.request("POST", "/api/v2/tenants", {"name": "Other"})
	var other_context := {"tenant_id": other_tenant["body"]["data"]["id"]}
	var isolated = api.request("GET", "/api/v2/chats/%s/messages" % chat_id, {}, other_context)
	_expect(isolated["status"] == 404, "租户数据没有隔离")

	var saved = api.request("POST", "/api/v2/database/save")
	_expect(saved["status"] == 200, "假数据库保存失败")

	if failures.is_empty():
		print("Harness V2 lightweight backend test: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
