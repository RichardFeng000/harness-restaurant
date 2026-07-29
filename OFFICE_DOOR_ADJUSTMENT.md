# 办公室门调整命令

本文档记录办公室门的生成、位置、尺寸和角度参数，方便以后继续调整。

## 当前采用的参数

在项目根目录执行：

```bash
python frontend/tools/compose_office_closed_door.py \
  --x 229 \
  --y 360 \
  --width 120 \
  --height 75 \
  --rotation -1 \
  --skew -2
```

当前参数含义：

- `x=229`：门的水平位置。
- `y=360`：门的垂直位置。
- `width=120`：门的宽度。
- `height=75`：门的高度。
- `rotation=-1`：整扇门顺时针旋转 1°。
- `skew=-2`：门底相对门顶向左倾斜 2°。

## 参数调整规则

- `x` 增大：向右移动。
- `x` 减小：向左移动。
- `y` 增大：向下移动。
- `y` 减小：向上移动。
- `width` 增大：门变宽。
- `height` 增大：门变高。
- `rotation` 为正数：逆时针旋转。
- `rotation` 为负数：顺时针旋转。
- `skew` 为正数：门底相对门顶向右倾斜。
- `skew` 为负数：门底相对门顶向左倾斜。

建议每次只调整一个参数，位置每次修改 `1–5` 像素，角度每次修改 `0.5–1°`。

## 更新独立门图片

办公室门已经与背景分离。执行上面的合成命令后，还需要执行：

```bash
python frontend/tools/separate_office_door.py
```

该命令会从最新合成结果中更新独立透明门：

```text
frontend/assets/runtime/v4/sprites/furniture/office_closed_door_v10.png
```

Godot 场景中的节点位置：

```text
Architecture
└── OfficeRegion
    └── OfficeClosedDoor
```

## 完整更新流程

```bash
python frontend/tools/compose_office_closed_door.py \
  --x 229 \
  --y 360 \
  --width 120 \
  --height 75 \
  --rotation -1 \
  --skew -2

python frontend/tools/separate_office_door.py
```

执行完成后，在 Godot 中重新导入图片或重新加载 `restaurant_v4.tscn`。

## 备用角度

之前测试过更明显的透视倾斜：

```bash
python frontend/tools/compose_office_closed_door.py \
  --x 229 \
  --y 360 \
  --width 120 \
  --height 75 \
  --rotation -1 \
  --skew -5
```

当前采用的是较自然的 `--skew -2`。
