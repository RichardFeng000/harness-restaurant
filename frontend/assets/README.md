# Assets 目录说明

素材分为三个区域。不要把新文件直接放在 `assets/` 根目录。

## `runtime/`

Godot 场景和脚本实际加载的资源。

```text
runtime/
├── v4/
│   ├── environment/        当前餐厅建筑底图
│   └── sprites/
│       ├── characters/     动物和其他角色动画
│       ├── furniture/      当前家具与门
│       ├── kitchen/        当前厨房设备
│       └── staff/          当前员工；每个职位一个文件夹
└── legacy/
    ├── atlases/            旧程序化场景使用的图集
    ├── environment/        旧版完整背景
    ├── layers/             旧版分层场景
    └── sprites/            旧版 v1–v3 精灵
```

只有游戏运行时会直接读取的图片才放入 `runtime/`。

## `source/`

可编辑原稿和生成过程文件，包括色键图、透明化母图、方向合集和工具输入。

```text
source/
├── v4/                     当前版本原稿
│   └── office-door/        办公室门参考图与合成预览
└── legacy/                 旧版原稿
```

源文件不能直接作为场景正式资源引用；处理完成后把正式输出放入 `runtime/`。

## `archive/`

历史版本、废稿和未采用变体。文件仅移动归档，没有删除。

```text
archive/
└── v4/
    ├── restroom_discarded_v2/
    └── unused/
```

归档文件不得被正式场景引用。如需恢复，先复制到 `runtime/` 或 `source/`。

## 当前办公室门

- 背景：`runtime/v4/environment/architecture-office-doorfree.png`
- 独立门：`runtime/v4/sprites/furniture/office_closed_door_v10.png`
- 合成参考：`source/v4/office-door/architecture-office-closed-v10.png`
- 调整脚本：`frontend/tools/compose_office_closed_door.py`
- 分离脚本：`frontend/tools/separate_office_door.py`
- 参数说明：项目根目录 `OFFICE_DOOR_ADJUSTMENT.md`

## 命名规则

- 使用小写英文与下划线：`office_closed_door_v10.png`
- 正式资源保留明确版本号：`_v1`、`_v2`
- 四方向角色使用：`north`、`south`、`east`、`west`
- 序列帧注明帧数：`16frame_sheet`
- `chroma`、`alpha`、`source` 文件只放在 `source/`
