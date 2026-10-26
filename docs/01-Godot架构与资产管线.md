# 01 · Godot 架构与资产管线

## 1. 分层

```
 scenes/           节点与表现（Boot / AssetLab / 将来的站点、工作台、HUD）
   │  只通过 autoload 的接口与信号交互
 autoload/         Events 事件总线 · GameState 运行时状态 · SaveGame 存档 · Settings 偏好
   │
 core/  data/     纯逻辑：常量、内容包门控、资产清单、目录读取、Resource 定义
   │
 assets/           4 站 glTF、贴画、参考图、音频、字体、UI 图
```

依赖方向永远向下。`core/` 里不出现 `Node`、`get_node`、`Input`、`OS.get_ticks_msec` ——
这是它能被无头测试直接跑的根本原因（`tests/cases/*.gd` 只 `load()` 纯逻辑脚本）。

## 2. project.godot 的关键选择

| 配置 | 值 | 为什么 |
| --- | --- | --- |
| `renderer/rendering_method` | `gl_compatibility` | ① 这是 Godot 4 唯一能导出 Web 的渲染器；② 现有模型是 0 贴图纯色材质，Forward+ 的优势用不上；③ 目标机型是 Intel UHD 620 集显 |
| `textures/canvas_textures/default_texture_filter` | `0`（最近邻） | 112×112 像素画布放大后必须是硬边，全局关掉双线性可以避免逐个控件设置 |
| `window/stretch/mode` + `aspect` | `canvas_items` + `expand` | UI 随分辨率缩放，3D 视口按宽高比扩展而不是裁切 |
| `viewport_width/height` | 1920×1080，窗口默认 1280×720 | 设计分辨率按 1080p，窗口先开小一点便于调试 |
| `gui/theme/default_font_multichannel_signed_distance_field` | `true` | 中文小字在缩放时不糊 |
| autoload 顺序 | Events → Settings → SaveGame → GameState | SaveGame 加载时要 `emit` 事件、GameState 读 SaveGame 的 data |
| `anti_aliasing/quality/msaa_3d` | `2`（2×） | 低模边缘抗锯齿；集显下先 2×，不够再关 |

输入映射已预置：`move_*`（WASD + 方向键）、`interact`（F/E）、`confirm`（Space/Enter）、
`cancel`（Esc）、`undo`/`redo`（Ctrl+Z / Ctrl+Y）、`brush_smaller`/`brush_larger`（`[` `]`）。
**不要在脚本里写死键码**，新交互先加 action。

## 3. 现在有哪几个场景

```
scenes/boot/Boot.tscn      启动自检：校验 catalog.json + manifest.json → 打印摘要 → 转场
scenes/lab/AssetLab.tscn   资产实验室：实例化一个站点 glTF（按 bounds 居中落地、慢速旋转）
                           + 左上角 112×112 像素画布预览（看最近邻是否糊）+ 数字键 1-4 切换站点
```

AssetLab 同时是两条管线的验收场：3D（glTF 能不能装进引擎）和 2D（像素画布是不是硬边）。
以后换模型、调光照，先在这里看。

## 4. autoload 契约

### Events（事件总线，26 行）

模块之间**只通过信号**互相知道，成就/图鉴/剧情/统计全是订阅方，加模块不用改老系统。

| 信号 | 语义 |
| --- | --- |
| `sculpture_finished(result)` | 一件作品捏完（含分数、用时） |
| `kiln_opened(result)` | 开窑（含等级、是否窑变） |
| `item_sold(income, item_id)` | 出售完成 |
| `item_discovered(item_id)` | 图鉴新增条目 |
| `achievement_unlocked(id)` | 成就解锁 |
| `site_changed(site_id)` / `coins_changed(coins)` | 状态变化，UI 用 |
| `save_loaded(version)` | 存档读入（含版本，便于做“版本更新提示”） |

`fire_once(key)` 做同会话去重（“第一次开窑”这类只该触发一次的事件用它）。
**事件回调里不做重活**：播个音效、改个计数可以；读盘、加载场景不行（会卡帧）。

### GameState（运行时状态门面）

数据真源永远是 `SaveGame.data`，GameState 只做带信号的读写门面，避免 UI 到处摸字典。
`coins` / `site_index` / `order_index` 都是 getter+setter 属性；`add_coins` / `try_spend` /
`discover` / `unlock` 是业务动作，写盘后发信号。

### SaveGame（存档）

见 §7。

### Settings（设备级偏好）

`user://settings.cfg` 用 ConfigFile，和进度存档分开：换机器不该丢音量设置，
清进度也不该重置语言。`apply()` 负责把音量推到 Master/Music/SFX 三条总线并设置 locale。

## 5. core 模块

| 文件 | class_name | 职责 |
| --- | --- | --- |
| `core/constants.gd` | `KilnConstants` | 全部数值常量（来自旧版 workshop.js / sculpture.js）+ `reward_for_score()` |
| `core/content_pack.gd` | `ContentPack` | 双发行门控：`OS.has_feature("demo")` 决定可用站点数与图鉴上限 |
| `core/asset_manifest.gd` | `AssetManifest` | 读/校验 `assets/models/maps/manifest.json` |
| `core/catalog.gd` | `Catalog` | 读/校验 `data/catalog.json`（站点、器物、成就） |
| `data/defs/item_def.gd` | `ItemDef` | 器物 Resource（id/名称/任务/提示/客人/品阶/缩略图/图鉴序号） |

新增数值先想清楚它属于常量（`KilnConstants`）还是数据（`catalog.json`）：
**与代码逻辑耦合的阈值放常量，策划要频繁调的内容放 JSON。**

## 6. 数据文件

`data/catalog.json`（schema 1）三块：

```jsonc
{
  "schema": 1,
  "sites": [        // 4 条，顺序必须与 KilnConstants.SITE_IDS 一致
    { "id": "guyao", "name": "...", "short": "...", "chapter": "...", "tag": "...",
      "workshop": "...", "decal": "...", "stamp": "...", "color": "#995637",
      "map_point": [606, 188], "scene": "guyao", "architecture": "..." }
  ],
  "items": [        // 订单/器物，至少 ORDERS_PER_SCENE(3) 条
    { "id": "...", "name": "...", "task": "...", "hint": "...", /* species, rarity, customer */ }
  ],
  "achievements": [ // id / name / desc / stat / count
  ]
}
```

`Catalog.validate()` 会检查：站点数量与顺序、每条站点必备字段、器物≥3 条且必备字段、
成就必备字段。**Boot 启动时跑这个校验**，缺字段直接在启动时报错而不是等到玩到一半。
加字段是兼容的，删字段会让 validate 失败 —— 这条是刻意的。

`map_point` 是景德镇地图（`assets/textures/maps/jingdezhen.png`）上的像素坐标，
站点选择界面直接用它打点，别在 UI 里另存一份坐标。

## 7. 存档

`user://save_v1.json`，分区固定，**加模块只加字段不改结构**：

| 分区 | 内容 |
| --- | --- |
| `progress` | `site_index` / `order_index` / `coins` / `passed[]` |
| `inventory` | `upgrades{}`（工作台等级）/ `stock{}` |
| `codex` | `discovered[]` ← 图鉴模块 |
| `achievements` | `unlocked[]` ← 成就模块 |
| `story` | `seen_beats[]` ← 剧情模块 |
| `meta` | `engine` / `created_at` / `version` |

- 读档：`default_data()` 打底 → 按分区 `merge(old, true)` → 补缺省键。老存档自动补齐新字段。
- 写盘：`JSON.stringify(data, "\t")`，缩进可读，方便玩家/我们排查。
- **迁移码**：`export_transfer_code()` 把去掉 `meta` 的存档序列化成 `body|checksum` 的 base64，
  `import_transfer_code()` 校验后合并。用途是试玩版进度带到完整版 —— 这也是为什么
  `ContentPack.limits()` 里 `allow_transfer_code` 一直是 true。
- 旧 three.js 版存档键是 `terra-porcelain-journey-v6`（localStorage）。只有 Web 导出才有意义，
  S2 用 `JavaScriptBridge.eval()` 读出来再 `migrate()`。要处理 v4–v8 的历史结构，
  `legacy/web-demo/src/campaign.js` 与 `tests/campaign.test.js` 里有原始的迁移逻辑可抄。

## 8. 资产管线：Blender → glTF → Godot

```
art/blender/opt/0X-*.blend ─┐
                            ├─ art/export/export-blender-scenes.py ─→ game/assets/models/maps/*.glb
                            │                                          + manifest.json
art/blender/workbenches/*.blend ─ art/export/build-workbenches.py ──→ game/assets/models/workbenches/*.glb
```

一条命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\export-art.ps1
powershell -ExecutionPolicy Bypass -File scripts\export-art.ps1 -BlendDir art\blender\opt   # 从减面版重导
powershell -ExecutionPolicy Bypass -File scripts\godot-import.ps1   # 让 Godot 重新导入
```

导出脚本做的事（`art/export/export-blender-scenes.py`）：

1. `open_mainfile` 打开 `.blend`（**不保存**，只在内存里处理）；
2. 按所有 mesh 的世界包围盒算 `bounds`，同时做 **Blender Z-up → glTF Y-up** 的轴变换：
   `min=[x, z, -y]`、`max=[x, z, -y]`；
3. 找名字以 `Tapered brick chimney` 开头的对象，取顶部 +0.18 作为烟囱锚点；
4. `object.convert(target='MESH')` 烘焙修改器，然后按材质名元组把静态件 `join` 成 batch；
5. 导出 GLB（`export_cameras=False, export_lights=False`，相机灯光由 Godot 自己打）；
6. 写 `manifest.json`。

### 已验证的导出结果（2026-10-26 实测，优化后）

| 站点 | 三角面 | batches | 垂直跨度（模型本身 y 从 -1.275 起） | GLB 体积 |
| --- | --- | --- | --- | --- |
| guyao | 35,076 | 30 | 6.883 | 1.93 MB |
| museum | 27,670 | 26 | 5.130 | 1.52 MB |
| imperial | 25,380 | 31 | 5.332 | 1.30 MB |
| taoxichuan | 46,532 | 32 | 7.483 | 2.54 MB |
| **合计** | **134,658** | 119 | — | **7.29 MB** |

优化前的原始值是 265,072 三角面 / 16.6 MB（减面 **-49.2%**，体积 **-56%**），
原文件备份在 `.local/tmp/maps-original/`（不进 git）。视觉核验见
`.local/tmp/maps-before/` 与 `.local/tmp/maps-optimized/` 的对照渲染。

导出的 4 个 GLB 与旧版 `public/models/maps/*.glb` **逐字节一致**（文件大小 delta = 0），
说明 `art/export/export-blender-scenes.py` 与旧 `tools/export-blender-scenes.py` 等价 ——
改脚本后可以这样回归：`scripts\export-art.ps1 -Out .local\tmp\glb-check` 再比文件大小和
`manifest.json` 的 bounds。

### 减面与四边面流程（`art/tools/optimize_meshes.py`）

母版 `.blend` **本身已经是四边面为主**（guyao 68.3% quad），265k 是 glTF 三角化后的数字，
不是建模面数虚高。所以减面只能靠 decimate，脚本提供两条独立产物：

| 产物 | 命令 | 用途 | 结果 |
| --- | --- | --- | --- |
| `art/blender/clean/*.blend` | `--mode none` | 美术继续编辑的干净母版 | 焊接 + 三角转四边，四边率 68.3→78.8 / 70.7→79.8 / 61.9→75.5 / 74.8→82.4% |
| `art/blender/opt/*.blend` | `--mode collapse --ratio 0.5 --min_faces 8` | 游戏内实际加载 | 三角面 265,072→134,658 |

要点：
- `bmesh.ops.decimate` **不存在**；减面必须用 `DECIMATE` 修改器 + `evaluated_get()`
  烘出新 mesh，逐对象做（1200 个对象不能用 `bpy.ops`）。
- 纯 planar dissolve 对场景几乎无效（-0.9%）：场景是几千个互不相连的小图元，
  跨不过 loose parts。
- `join_triangles` 只在同材质槽内合并三角形，所以 collapse 后四边率只能回到 ~35%；
  要高四边率就用 `clean/` 版本。
- 减面会牺牲细节，`--min_faces 48` 太保守（只 -17%）。默认 8 是实测手感与体积的平衡点，
  近景需要更精细时按站点单独调 `--ratio`。


**batches 就是 Godot 里的 draw call 数**（每个 batch 一种材质）。这是当前最主要的性能指标，
比三角面更重要。加新建筑时优先复用已有材质名，能合进现有 batch。

### manifest.json 字段

| 字段 | 含义 |
| --- | --- |
| `url` | 相对 `res://assets/` 的 glTF 路径 |
| `bounds.min` / `bounds.max` | 世界包围盒（Godot 坐标，Y 向上） |
| `groundY` | 地面高度（0.09，全站统一），摆放时用它落地 |
| `chimney` | `{x, y, z}` 烟囱顶部锚点，只有 guyao / taoxichuan 有；将来做炊烟/开窑镜头的机位参考 |
| `batches` | 合并后的批次数 = draw call 数 |
| `triangles` | 三角面总数（S1 性能基线用） |
| `source` | 生成这份 GLB 的 `.blend`（`art/blender/opt/...`），便于追溯 |

### 工作台模型（`game/assets/models/workbenches/`）

旧版六个工作台**不是模型文件**，而是 `legacy/web-demo/src/workbench-model.js` 里用
`RoundedBoxGeometry` / `CylinderGeometry` / `LatheGeometry` 程序化拼出来的（窑另在
`kiln-view.js`）。所以这里是按同一套参数用 bpy **重建**，不是格式转换：

| 工作台 | objects | faces | 三角面 | 四边面占比 |
| --- | --- | --- | --- | --- |
| clay | 25 | 1,622 | 3,116 | 87.9% |
| wheel | 36 | 1,926 | 3,916 | 99.8% |
| carve | 21 | 1,116 | 2,160 | 99.6% |
| paint | 26 | 1,066 | 2,006 | 97.7% |
| serve | 19 | 1,164 | 2,270 | 100% |
| kiln | 58 | 3,143 | 6,254 | 98.6% |

约定：
- 三个 collection = 三个层级，节点带自定义属性 `tier`（`base` / `upgrade1` / `upgrade2`），
  导出时 `export_extras=True` 才带得进 GLB。显示规则见 `core/workbench_assets.gd`
  的 `tier_visible(tier, level)`。
- 坐标：three.js `(x, y, z)` → Blender `(x, -z, y)`，脚本里用
  `SWIZZLE = Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))` 统一变换后再建 mesh，
  导出 `export_yup=True`，回到 Godot 就是原来的朝向。
- 重跑：`blender -b --python art/export/build-workbenches.py`，产物 = 6 个 `.blend`
  （`art/blender/workbenches/`）+ 6 个 `.glb` + `manifest.json`。
- 火焰**不在模型里**，Godot 侧用 `GPUParticles3D` 做，窑门上的位置由 manifest 的
  `bounds` 推算。

## 9. 像素画布管线（游玩的核心表现）

旧版用一个 112×112 的 `Uint8Array`，每格是调色板索引（0 空白 / 1 瓷白 / 2 钴蓝），
Canvas2D 逐像素画。Godot 侧的对应做法：

- 数据：`PackedByteArray`，长度 112×112，值同上。**不要用 `Image` 当数据源**，逐像素
  `set_pixel` 太慢；改完数据后一次性 `Image.create_from_data()` → `ImageTexture.update()`。
- 显示：`TextureRect` + `expand_mode = EXPAND_IGNORE_SIZE` + `texture_filter = NEAREST`
  + 整数倍缩放（`size = Vector2(112 * k, 112 * k)`），否则会出现半像素模糊。
- AssetLab 里已经用 1px 外框 + 一条对角线做了肉眼检查（边框有线、对角线是斜纹即为硬边）。

S1 移植 `sculpture.gd` 时，`create_target(id)` / `push_clay()` / `apply_brush()` /
`compare_sculpture()` 的数据结构保持不变，只把 `Uint8Array` 换成 `PackedByteArray`、
把 `for (let i…)` 换成 `for i in range()`。**评分公式一个字都不要改**，
用 `legacy/web-demo/tests/` 里的 60 项测试生成 golden 向量逐值核对（见 `docs/04` §3）。

## 10. 本地化（S1 实施）

Godot 用 CSV 翻译表：`i18n/zh.csv` + `i18n/en.csv`，列是 `keys,zh,en`，在
`project.godot` 的 `internationalization/locale/translations` 里登记后按 locale 自动切换。

词条来源：`legacy/web-demo/src/i18n.js`（810 条中英对照）。S1 只抽**当前用得到的**
（四站文案、工作台名称、HUD、结算），不要一次搬 810 条 —— 搬过来也测不到，
容易烂在那里。key 命名用 `站点.模块.用途`，例如 `guyao.workshop.title`。

## 11. 双发行：一份工程两个包

| 预设 | custom_features | 内容 |
| --- | --- | --- |
| `desktop_full` | 无 | 4 站、全部图鉴/成就/剧情 |
| `web_demo` | `demo` | `DEMO_SITE_IDS`（当前只有 guyao）、图鉴前 4 格 |

代码里只准出现 `ContentPack.is_demo()` 一处判断，业务逻辑别自己 `if OS.get_name() == "Web"`。

导出预设文件 `export_presets.cfg` **还没建**，因为导出模板缺失（`docs/00` §4）。
模板到位后按上表新建两个预设即可，代码不用改。

## 12. 测试框架

- 入口 `tests/run_tests.gd`（`extends SceneTree`），`--script` 直接跑，不需要主场景。
- 用例：`extends RefCounted` + `run(report: TestReport)`，纯逻辑、无随机、无等待。
- `tests/framework/test_report.gd` 提供 `eq / ok / error`，末尾汇总打印
  `通过 N，失败 M` 和 `ALL TESTS PASSED`（或 `TESTS FAILED: N`）。
- 当前 43 项断言、4 个套件：`test_constants`（关键数值与 `reward_for_score` 边界，含 NaN）、
  `test_catalog`（真实 `catalog.json` 通过校验 + 故意构造的坏数据被拒）、
  `test_manifest`（4 个 glTF 文件存在、bounds/groundY/batches 合法）、
  `test_content_pack`（demo 与 full 的站点数、图鉴上限、迁移码开关）。
- 需要场景树的集成测试放 `tests/integration/`，另开入口 —— **不要**混进无头入口，
  否则 CI 会随机挂。
