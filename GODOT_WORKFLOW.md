# Godot 启动与场景重载

本项目的 Godot 工程目录：

```text
/Users/fengruiding/Downloads/harness-visual-factory
```

项目配置：

```text
/Users/fengruiding/Downloads/harness-visual-factory/project.godot
```

## 可靠的重启方法

先关闭所有 Godot 编辑器和项目管理器进程：

```bash
pkill -TERM -f /Applications/Godot.app/Contents/MacOS/Godot
```

然后通过 macOS 启动新的 Godot 实例，并直接打开本项目：

```bash
open -n -a Godot --args \
  --editor \
  --path /Users/fengruiding/Downloads/harness-visual-factory
```

成功后窗口标题应为：

```text
restaurant_v4.tscn - Harness V2 - Godot Engine
```

不要只打开 Godot Project Manager；项目管理器中可能没有登记本项目。

## 主要场景

游戏入口脚本：

```text
frontend/scripts/main.gd
```

餐厅可编辑分层场景：

```text
frontend/scenes/restaurant_v4.tscn
```

`main.gd` 会直接实例化 `restaurant_v4.tscn`。

## 编辑器缓存注意事项

如果外部工具修改了 `.tscn`，而 Godot 中仍开着修改前的场景标签页：

1. 不要保存旧标签页。
2. 关闭该场景标签页。
3. 选择从磁盘重新加载，或者按上面的命令重启 Godot。

否则 Godot 会把内存中的旧场景重新写入磁盘，覆盖外部修改。

修改后应同时检查磁盘文件和编辑器 Inspector。例如 Cashier 只使用
North 图片时，`restaurant_v4.tscn` 中应只有：

```text
res://frontend/assets/runtime/v4/sprites/staff/cashier/cashier_north_v3.png
```

## 无界面检查

不打开窗口时，可执行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --editor \
  --path /Users/fengruiding/Downloads/harness-visual-factory \
  --quit \
  --log-file /tmp/harness-godot-check.log
```

返回码为 `0` 表示项目资源和脚本可以加载。沙盒环境中出现无法保存
Godot 全局编辑器设置的提示，不代表项目场景错误。

