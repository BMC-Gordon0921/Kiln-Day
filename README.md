# 开窑啦！Kiln Day

景德镇陶瓷题材的小游戏：捏器型、描纹样、看窑火。Godot 4.7 工程 + Blender 5.2 美术源，
从旧的三渲二 Web 原型（three.js，仓库 `BMC-Gordon0921/Porcelain_Workshop`）迁移而来。

**状态快照：2026-10-26 · S0「工作区地基」完成。** 当前工程能无头导入全部资产、跑通 43 项单元测试、
把四个场景 glTF 加载进引擎；游戏玩法本体尚未开始（S1 起）。

## 现在能跑什么

| 能力 | 状态 | 验证方式 |
| --- | --- | --- |
| Godot 工程可启动、无脚本错误 | ✅ | `scripts\check.ps1` · SMOKE OK |
| 四站 glTF 自动导入（265,072 三角面） | ✅ | `scripts\godot-import.ps1` · IMPORT OK |
| 核心层单元测试（常量/目录/清单/内容包/数据定义） | ✅ 43 项 | `scripts\test.ps1` · TESTS OK |
| Blender → glTF 全自动导出，与原资源逐字节一致 | ✅ | `scripts\export-art.ps1` |
| 112×112 像素画布最近邻放大不糊 | ✅ | AssetLab 场景目视 + 冒烟 |
| 内容包门控（试玩版 / 完整版同工程双发行） | ✅ 逻辑就绪 | `test_content_pack.gd` |
| 存档 v1 分区 + 迁移码 | ✅ 框架就绪 | 单元测试未覆盖（S1 补） |
| 玩法：捏塑/施釉/烧窑/结算/图鉴/成就 | ⬜ 未开始 | — |
| 导出 exe / web | ⛔ 阻塞 | 未装导出模板，见 `docs/00` |

## 怎么开始

本仓库的脚本是纯 ASCII 的 `.ps1`，Windows 默认执行策略会拦截，**必须带 `-ExecutionPolicy Bypass`**：

```powershell
cd D:\Projects\Porcelain_Workshop

# 1) 体检：工具链版本、资源在位、导出模板缺口
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1

# 2) 一条命令跑完：导入资源 → 单元测试 → 冒烟
powershell -ExecutionPolicy Bypass -File scripts\check.ps1

# 3) 打开 Godot 编辑器（-Run 直接运行主场景）
powershell -ExecutionPolicy Bypass -File scripts\run.ps1
```

改了 `.glb` / `.csv` / 图片之后，先跑 `scripts\godot-import.ps1` 再跑测试。

## 目录

```
game/                  Godot 工程（唯一需要引擎打开的目录）
  autoload/            Events / Settings / SaveGame / GameState
  core/                常量、内容包门控、资产清单、目录读取
  data/                catalog.json（站点/器物/成就数据）+ Resource 定义
  scenes/              boot/（自检）、lab/（资产实验室）
  tests/               run_tests.gd + cases/ + framework/
  assets/              models/maps（4 站 glTF）、textures、references、audio、fonts、ui
art/
  blender/             4 个 .blend 源文件（美术的编辑现场）
  export/              export-blender-scenes.py（blend → glb + manifest.json）
legacy/                旧 three.js 版本只读副本（git 忽略，见 docs/00）
scripts/               verify / import / test / smoke / run / export-art / check
docs/                  00 环境 · 01 架构与资产管线 · 02 模块路线图 · 03 潜力评估 · 04 规范
.local/                Godot 的 user:// 重定向与临时文件（git 忽略，可随时删）
```

## 硬约定

1. **不往 C 盘写项目内容。** 脚本把 `APPDATA`/`TMP` 重定向到 `.local\`，否则 Godot 会在
   `C:\Users\<你>\AppData\Roaming\Godot` 下建 user:// 目录。
2. **`legacy/` 只读。** 它是旧实现的参考资料，不是我们要维护的代码。
3. **美术源只在 `art/blender/` 改。** `game/assets/models/maps/*.glb` 是生成产物，
   直接用 Blender 改 glb 的改动下次导出会被覆盖。
4. **改 `.ps1` 时保持 ASCII。** Windows PowerShell 5.1 会按 ANSI 解析无 BOM 的 UTF-8 中文，
   一有中文注释就可能语法崩。中文写进 `.md` / `.gd`。

## 文档

- [环境与工作区](docs/00-环境与工作区.md) — 工具链、沙箱坑、网络与导出模板缺口
- [架构与资产管线](docs/01-Godot架构与资产管线.md) — 工程结构、数据流、blend→glb 管线、存档
- [模块路线图](docs/02-模块路线图.md) — 13 个模块的阶段、依赖与首发范围
- [开发潜力评估](docs/03-开发潜力评估.md) — 这事儿值不值得做、做多大、怎么验证
- [工程规范](docs/04-工程规范.md) — 命名、测试、提交、日志标记
