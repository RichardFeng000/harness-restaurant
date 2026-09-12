# Harness Kitchen

一个使用 Godot 4 和 GDScript 构建的轻量多租户 AI Agent Harness 原型。

```text
backend/       Harness 假接口、业务服务和本地假数据库
frontend/      餐厅场景、工作簿、公共 UI 和本地状态
database/      Dictionary 数据表和单文件 CSV 持久化
game/skills/   员工可安装的本地技能包
scripts/       本地启动入口
tests/         无界面自动测试
project.godot  Godot 项目配置
```

后端入口为 `res://backend/harness_api.gd`，使用进程内接口和本地 CSV，不需要单独启动服务器或数据库。餐厅进度使用本地 JSON，通信草稿仅在当前运行内保留。

## 本地运行

```bash
./scripts/run.sh            # 运行前端
./scripts/run.sh --editor   # 打开项目编辑器
```

启动脚本自动查找 Godot，也可用 `GODOT_BIN` 指定可执行文件。主菜单可直接体验演示餐厅，或选择文件夹创建餐厅。
仓鼠已预装本地时间 Skill，可读取当前用户设备的时间并每秒校准墙钟。进入「工作簿 → 仓鼠 → MCP」管理技能。
MCP 页右上角「＋」打开 MCP 库，主管和员工使用相同的安装、启用、暂停和卸载界面。主管在「门户」中为员工勾选工具的「授权」，员工便可自行安装和启用；外部 MCP 服务的连接和执行尚未接入。
界面结构、功能状态和测试命令见 [frontend/README.md](frontend/README.md)。

Godot 主场景为 `res://frontend/scenes/main.tscn`，Web 导出配置位于
`export_presets.cfg`。

Godot 编辑器的启动、重启和场景缓存处理方法见
[GODOT_WORKFLOW.md](GODOT_WORKFLOW.md)。

## GitHub Pages

`dist/` 中包含已导出的 Godot Web 游戏，修改源码后需重新导出才能更新网页版。推送到 `main` 分支后，
`.github/workflows/deploy-pages.yml` 会把该目录自动发布到 GitHub Pages。
