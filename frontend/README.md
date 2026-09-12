# Harness Kitchen Frontend

Godot 4 餐厅工作台。保留可编辑的餐厅分层场景；工作簿直接使用展开的双页书本，左页放目录与员工，右页承载当前工作内容。

## 代码边界

```text
scenes/main.tscn              应用入口
scenes/restaurant_v4.tscn     餐厅场景与员工、家具摆放
scenes/harness/              工作簿页面入口
scripts/main.gd              页面导航、游戏状态、浏览器目录桥接
scripts/harness_*.gd         工作簿导航、对话、门户
ui/kitchen_theme.gd          颜色、字号、控件样式
ui/main_menu.gd              主菜单，只发出操作信号
ui/game_hud.gd               餐厅状态与操作入口
ui/book_open_transition.gd   书本抬起、翻页与内容显示的过渡
ui/book_geometry.gd          动画与最终书页共用的边界、排版区域
ui/book_theme.gd             纸面文字、细线表单与透明控件
ui/chat_message_list.gd      按角色排列的消息气泡、换行与滚动
ui/pause_menu.gd             暂停菜单与保存反馈
ui/settings_panel.gd         模型配置表单
ui/book_empty_page.gd        未开放页面的公共布局
ui/staff_skills_page.gd       员工能力列表、逐项启用/暂停/卸载与可展开详情
ui/mcp_library_panel.gd       所有员工共用的 MCP 库、搜索与安装
ui/mcp_permissions_panel.gd   门户内的员工 MCP 单项授权开关
ui/confirmation_modal.gd      保留底层列表的悬浮确认弹窗
world/hamster_timekeeper.gd   仓鼠的时间任务调度与墙钟绑定
state/workspace_store.gd     本地 JSON 读写与旧存档兼容
assets/runtime/              运行时素材
assets/source/               素材源文件
scenes/archive/              旧场景参考
```

UI 组件通过信号通知主脚本，不在组件中写存档。餐厅场景和动画继续使用原有脚本；业务接口入口为 `res://backend/harness_api.gd`。

## 使用方式

1. 创建餐厅并选择本地文件夹，或直接体验演示餐厅。
2. 点击「开始营业」，再点击右下角皮面书本，翻书动画后打开工作簿。
3. 左页通过「对话、门户、知识库、记忆、MCP」切换右页内容；左页下方可切换员工。
4. 点击书页右上角「×」或按 Esc，书本会合拢并缩回右下角入口；餐厅内按 Esc 可暂停营业并保存进度。

已有存档时，主菜单优先提供「继续营业」。取消文件夹选择不会清空当前进度；演示不覆盖存档。支持 1280×720 与 960×540 布局。

对话页的草稿按员工隔离，仅保留在当前运行内，创建或切换餐厅会清空。门户中的员工名册与页面可见性统一读取 `database/staff_permissions.csv`；这是本地原型的界面权限，不是后端身份认证。知识库和记忆页面目前为明确标注的未开放状态。MCP 页已接入仓鼠的本地时间 Skill；模型设置只负责保存连接信息，尚未发起 AI 请求。

## 本地数据

对话消息按角色显示：用户在右、模型在左。`add_assistant_message(text, staff_id, draft_index)` 可向指定员工的会话加入模型回复；当前仅有展示接口，未连接实际模型请求。

MCP 标题右侧的「＋」打开项目内的 MCP 库，可搜索并选择工具；主管与员工共用同一套 MCP 界面，库内不含授权入口。主管在「门户」点击员工，每个工具只有一个「授权」开关，允许员工自行安装和启用，管理过程中保持主管身份。Esc 或「返回」先回到员工名册，再按 Esc 合上书本。MCP 库同样先退出库，再合书。

安装、启用和执行统一检查同一个授权；暂停和卸载不受阻止。撤销授权会立即停止运行，重新授权后需手动启用。权限在运行时接口中校验，不能通过直接调用绕过；当前员工切换仍是本地原型的身份选择，不提供远程身份认证。

主管授权不会自动安装工具；员工从「＋」的库中安装后，默认暂停，再自行选择启用、暂停或卸载。点击卸载打开居中的悬浮确认窗，原 MCP 列表保持可见，遮罩阻止操作背景。取消或 Esc 保留安装状态；确认后工具从 MCP 列表消失，授权保留，需要时从「＋」重新安装。切换员工、页面或合书会取消尚未确认的卸载。

库内选取的 MCP 按员工保存在 `mcp_servers`，主管授权保存在 `staff_tool_permissions`，均随餐厅进度保存。当前库收录的外部 MCP 尚未接入连接与执行，详情明确显示「未连接」；本地时间仍由已有 Skill 实际执行。旧版手填配置保留为只读项目，可卸载，不能直接启用。

- `user://restaurant_save.json`：餐厅进度。
- `user://workspace.json`：上次选择的文件夹。
- 所选文件夹内的 `harness_config.json`：模型配置；重新打开设置会回读，API Key 为明文存储。
- Web 目录授权刷新后需要重新选择，目录名本身不是写权限凭据。

## 运行与检查

在项目根目录执行 `./scripts/run.sh`，加 `--editor` 可进入 Godot 编辑器。

```bash
./scripts/run.sh --headless --script tests/frontend_smoke_test.gd --log-file /tmp/harness-frontend-test.log
./scripts/run.sh --headless --script tests/harness_book_test.gd --log-file /tmp/harness-book-test.log
./scripts/run.sh --headless --script tests/book_open_transition_test.gd --log-file /tmp/harness-book-transition-test.log
./scripts/run.sh --headless --script tests/workspace_store_test.gd --log-file /tmp/harness-store-test.log
./scripts/run.sh --headless --script tests/mcp_registry_test.gd --log-file /tmp/harness-mcp-registry-test.log
./scripts/run.sh --headless --script tests/mcp_add_flow_test.gd --log-file /tmp/harness-mcp-add-test.log
./scripts/run.sh --headless --script tests/mcp_permissions_test.gd --log-file /tmp/harness-mcp-permissions-test.log
```

以上测试不写真实用户存档。入口交互、暂停状态、草稿和权限、存档读写分别验证。

## 仓鼠的时间技能

「工作簿 → 仓鼠 → MCP」只列出已安装项目，显示项目名称和「启用、暂停、卸载、详情」四项操作。类型、状态和时间读数放在详情内，也可在详情中立即同步；确认卸载后从列表移除，可从「＋」重新安装。仓鼠默认安装并启用「本地时间」Skill。安装与启停状态随餐厅进度保存；演示体验不会覆盖已保存状态。

执行路径为 `HarnessApi.skills` → 已授权、安装且启用的 Skill → 用户设备的时间读取器 → `HamsterTimekeeper` → 墙钟指针。仓鼠默认获得本地时间授权；主管可修改分配，员工之间不能借用安装状态或授权。技能包在 `game/skills/local-time/`，包含 `SKILL.md`、声明和可执行 GDScript；这是项目内的本地 Skill，未依赖外部 MCP 服务或模型生成时间。

原生版读取设备操作系统的本地日期、时间及当前 UTC 偏移（包含夏令时），Web 版读取浏览器的本地 Date 和时区。有关原生时间 API 的语义见 [Godot Time 文档](https://docs.godotengine.org/en/stable/classes/class_time.html)。每秒重新采样，恢复窗口焦点或继续游戏时立即校准；游戏暂停不会冻结现实时间。停用、卸载或回到菜单后停止自动读取，失败时保留最后一次有效指针位置。

```bash
./scripts/run.sh --headless --script tests/staff_skill_runtime_test.gd --log-file /tmp/harness-skills-test.log
./scripts/run.sh --headless --script tests/staff_capability_list_test.gd --log-file /tmp/harness-capability-list-test.log
./scripts/run.sh --headless --script tests/clock_hands_test.gd --log-file /tmp/harness-clock-test.log
./scripts/run.sh --headless --script tests/hamster_timekeeper_test.gd --log-file /tmp/harness-timekeeper-test.log
```

新增测试覆盖员工分配、安装/停用/卸载、真实设备时间、无效读数、指针角度、跨日、暂停持续校准和保存恢复。Web 时间读取器已实现；浏览器导出仍需对应 Godot Web 模板并重新导出 `dist/`。
