# Harness V2

一个使用 Godot 4 和 GDScript 构建的轻量多租户 AI Agent Harness 原型。

```text
backend/       Harness 假接口、业务服务和本地假数据库
frontend/      Chat、Knowledge、Memory 和管理界面
database/      Dictionary 数据表和单文件 CSV 持久化
tests/         无界面自动测试
project.godot  Godot 项目配置
```

后端入口为 `res://backend/harness_api.gd`。当前数据保存在浏览器本地 CSV
文件中，不需要真实服务器或数据库。

Godot 主场景为 `res://frontend/scenes/main.tscn`，Web 导出配置位于
`export_presets.cfg`。

Godot 编辑器的启动、重启和场景缓存处理方法见
[GODOT_WORKFLOW.md](GODOT_WORKFLOW.md)。

## GitHub Pages

`dist/` 中包含已导出的 Godot Web 游戏。推送到 `main` 分支后，
`.github/workflows/deploy-pages.yml` 会把该目录自动发布到 GitHub Pages。
