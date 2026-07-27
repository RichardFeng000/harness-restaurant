# Harness V2 Backend

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
└── run/
    ├── controller/run_controller.gd
    ├── service/run_service.gd
    └── repository/run_repository.gd
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
