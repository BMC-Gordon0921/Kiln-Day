# 仓库边界：哪些入库、哪些不入库

> 状态：2026-10-26 清理后。仓库跟踪 **78 个文件 / 40.4 MB**，本机工作区 **222 MB**（其中 `.git` 118 MB、`node_modules` 62 MB）。
> 回滚点：`git tag pre-cleanup-2026-10-26`（清理前的 HEAD，跟踪 108 个文件）。

---

## 1. 判定标准

一个文件进不进入版本库，只问三个问题，从上往下：

1. **游戏运行／构建时会被加载吗？** → 是，入库（运行时必需资源）。
2. **换一台机器 `npm ci` 之后还能跑起来吗？** → 能，入库（源码与工程配置）。
3. **删掉以后能不能用库里的东西重新生成？** → 能，**不入库**（派生物）；不能，但体积大且已归档 → 不入库并登记归档位置。

「性能优化」「方便调试」「历史遗留」都不是入库理由。

---

## 2. 四分类矩阵

### A. 运行时必需资源（10 + 5 个）— 入库，**永不忽略**

| 路径 | 大小 | 谁在用 | 说明 |
|---|---:|---|---|
| `public/models/maps/*.glb`（4） | 10.0 MB | `src/scene-environment.js` `GLTFLoader.parseAsync` | 四站 3D 场景，合计 265,072 三角面 / 119 材质 |
| `public/models/maps/manifest.json` | 1.6 KB | 同上，先 `fetch` 清单再加载 | 锚点与体积数据 |
| `public/references/*`（4） | 3.1 MB | `src/campaign.js:7-10` 配置、`src/main.js:249` `<img>` | 订单参考图 |
| `public/maps/jingdezhen.png` | 2.1 MB | `src/places.js:3` `CITY_MAP` | 手绘地图底图 |
| `src/assets/pottery backround music.wav` | 22.0 MB | `src/music.js:1` `?url` import | 背景音乐，`dist` 40 MB 的主要来源 |
| `src/assets/fonts/zcool-kuaile-title.woff2` + `OFL-ZCOOL-KuaiLe.txt` + `README.md` | 6.3 KB | `src/opening-home.css` `@font-face` | 标题字体；OFL 1.1 **要求随字体分发许可文本**，不能删 |
| `src/assets/logo-mark.png`、`logo-lockup.png` | 383 KB | `src/*.js` `?url` import | 品牌图 |

### B. 源码与工程配置（约 60 个）— 入库

| 路径 | 数量 | 说明 |
|---|---:|---|
| `src/*.js` + `src/*.css` | 43 | 游戏本体，3774 行 JS / 约 100 KB CSS |
| `src/scenes/*.blend` | 4（1.5 MB） | 四站 GLB 的 **Blender 母版**，`tools/export-blender-scenes.py` 的唯一输入 |
| `index.html` | 1 | 入口 |
| `vite.config.js` | 1 | `base:'./'` 是 GitHub Pages 子路径能跑的前提，**改成 `'/'` 会白屏** |
| `package.json` / `package-lock.json` | 2 | 依赖只剩 `three` + `vite` |
| `.gitattributes` | 1 | `eol=lf` + 二进制白名单（缺了它 Windows 检出会污染 png/glb） |
| `.gitignore` | 1 | 本文件的下游执行者 |
| `README.md` / `docs/*.md` | 2 | 玩法说明与迁移评估 |
| `.github/workflows/deploy-pages.yml` | 1 | Pages 自动部署（`npm ci` → `npm test` → `npm run build` → deploy） |

### C. 可独立运行的验证与资产管线（7 个）— 入库

| 路径 | 说明 |
|---|---|
| `tests/*.test.js`（6） | `node:test` 纯逻辑单测，62 条断言，只 `import ../src/*`，不碰 DOM |
| `tools/export-blender-scenes.py` | `.blend → .glb` 唯一的导出脚本，迁移后仍要用它重导资产 |

### D. 派生物／交付物／本地环境 — **不入库**，已 `.gitignore`

| 路径 | 体积 | 为什么可以不要 | 怎么回来 |
|---|---:|---|---|
| `node_modules/` | 62 MB | `npm ci` | `npm ci` |
| `dist/` | 40 MB | `npm run build` | `npm run build` |
| `qa/`、`shots/`、`test-results/`、`playwright-report/` | 1.4 GB | Playwright 运行产物 | 跑对应 `tests/*browser*.mjs` |
| `release/`、`.desktop-build/`、`deliverables/`、`路演/` | 约 2.0 GB | 已弃用的 Electron 打包链路与交付物 | 见 §3 归档位置 |
| `tools/` 下 14 个非管线脚本 | 约 60 KB | 一次性补丁（`patch-*.mjs`、`fix-quote.mjs`）、文案抽取器、打包脚本、`verify-ui.mjs` | 见 §3 |
| `desktop/`（3） | 8 KB | Electron 主进程 / `terra://` 协议 / 免 Node 启动器，随打包链路一起退役 | 见 §3 |
| `tests/*browser*.mjs`（12） | 约 32 万字符 | 需要 `playwright-core`（已从 devDependencies 移除），产物是 `qa/` | `npm i -D playwright-core` |
| `public/decals/*.png`（4） | 1.7 MB | 运行时纹样由 `src/decals.js:124` `decalCanvas().toDataURL()` 现画，这 4 张 PNG 从未被加载 | `node tests/browser-smoke.mjs` |
| `src/Logo.png`、`src/img_v3_*.jpg`、`src/scenes/build.log` | 1.2 MB | 全语料 0 引用（孤儿） | 无需恢复 |

---

## 3. 被忽略之后，怎么拿回来

**仓库外归档**（打包链路删除后无法重建，故永久留档）：

```
D:\ECNU\BOKE\Porcelain_Workshop_Archive\
├─ release\   开窑啦-即开即玩\ + 开窑啦-即开即玩.zip + *.sha256     （约 128 MB + 62 MB）
└─ deliverables\   terra-course\ + 景德镇瓷器之旅_课程展示资料包.zip  （92 MB）
```

**仓库内历史**（`git rm --cached` 只移出索引，对象仍在 `.git` 里；清理前的完整快照在 tag 上）：

```sh
# 单个文件：从清理前的 tag 取回
git checkout pre-cleanup-2026-10-26 -- desktop/main.cjs
git checkout pre-cleanup-2026-10-26 -- tests/experience-browser.mjs

# 整个目录
git checkout pre-cleanup-2026-10-26 -- tools/

# 只要看内容，不落盘
git show pre-cleanup-2026-10-26:tools/package-quick-windows.mjs
```

> 注意：`.gitignore` 对**已跟踪**文件无效。当年 `deliverables/` 写进了 `.gitignore` 却仍被提交（commit `0a229fb`），必须 `git rm -r --cached` 才真正移出。这也是本次清理的起因。

---

## 4. 迁 Godot 时要带走的清单

| 必带 | 理由 |
|---|---|
| `src/scenes/*.blend`（4） | 美术母版，改模型只能从这里改 |
| `public/models/maps/*.glb` + `manifest.json` | Godot 直接导入 glTF；manifest 的锚点要在 Godot 里重建成 `Node3D` 标记 |
| `src/assets/**` | 音乐、字体、logo；**OFL 许可文本必须跟着字体走** |
| `src/sculpture.js`、`src/workshop.js` 等 A 级逻辑 | 纯 `Uint8Array` 像素逻辑与数值模型，零引擎依赖，可近乎逐行移植 |
| `tests/*browser*.mjs` 的**内容**（不是文件） | 它们是最细的行为规格：教学强制顺序、12 秒火候判定、双语切换、资源释放时机。应当读成验收清单，在 Godot 里用 `--headless` 或 GUT 重写 |

| 不要带 | 理由 |
|---|---|
| `.git/`（118 MB，含已删的 91 MB 交付物历史） | 新工程另起仓库，或先 `git filter-repo` |
| `src/*.css`、`index.html`、`vite.config.js`、`.github/workflows/` | CSS 布局与 Vite 构建在引擎里没有对等物 |
| `tests/*browser*.mjs` 文件本身、`qa/`、`shots/` | Playwright 绑定 DOM，换引擎即失效 |

细节见 `docs/engine-migration.md`（含 A/B/C 三级代码分级、五种引擎的工期对比）。

---

## 5. 体积账（清理前后）

| 项目 | 清理前 | 清理后 |
|---|---:|---:|
| 工作区磁盘 | 3455 MB | **222 MB** |
| 版本库跟踪内容 | 199 文件 / 133.6 MB | **78 文件 / 40.4 MB** |
| `node_modules` | 109 MB | 62 MB（删 6 个打包/E2E 依赖） |
| `.git` | 118 MB | 118 MB（未重写历史，见下） |

> `.git` 仍是最大单项，因为 commit `0a229fb` 曾提交 91 MB 的 `deliverables/`。要压到约 35 MB 需 `git filter-repo` 重写历史——**本次刻意没做**，它会改写所有 commit hash，破坏 tag 与协作者的克隆。若将来要公开仓库，再单独执行。
