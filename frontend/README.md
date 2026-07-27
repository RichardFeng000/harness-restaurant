# Harness V2 Frontend

这里存放 Harness V2 的 Godot 2D Web 游戏界面。

计划目录：

- `scenes/main.tscn`：游戏主场景
- `scripts/main.gd`：菜单、文件夹选择、控制室和 Agent 任务动画
- `assets/`：图片、音频、字体等资源
- `theme/`：Godot UI 主题

前端通过 `res://backend/harness_api.gd` 访问业务，不直接操作假数据库。

## 当前玩法

1. 在主菜单选择本地工作文件夹，或进入演示工作区。
2. 进入 Harness Control Room。
3. 查看任务、Memory、Knowledge 和 Agent 状态。
4. 点击 `RUN NEXT AGENT` 推进任务。

Web 版在支持 File System Access API 的 Chrome 或 Edge 中可以调用原生目录
选择器。浏览器只授权用户主动选择的文件夹。
