# 引擎迁移可行性评估

> 对象：`Porcelain_Workshop_Code`（Terra · 景德镇瓷器之旅，v0.1.0）
> 结论基于当前工作区的实测数据（源码 3774 行、资源 16.6 MB、四站 GLB 265k 三角面），不是估算。

---

## 0. 一句话结论

**可行，且不需要换掉美术资产，但这不是「搬迁」，而是「重写表现层 + 搬运逻辑层」。**

- 约 **17%** 的代码可以几乎逐行搬过去（纯像素逻辑与数值模型，零引擎依赖）；
- 约 **24%** 是数据表（双语字典、关卡配置），可机械转换成引擎本地化格式；
- 约 **59%** 必须按引擎重写，其中真正棘手的只有三块：**程序化 3D 场景构建、HTML/CSS 界面、程序化 WebAudio 音效**。

如果目标只是「脱离浏览器」，**不必换引擎**——现有 `desktop/`（Electron）+ 免安装 Node 启动包已经覆盖了这个需求。

---

## 1. 现状技术栈测绘

这不是一个「使用某引擎」的项目，而是一个**直接用 Three.js 底层 API 手写的 Web 游戏**，没有任何引擎层。它由 5 套相互独立的表现系统拼成：

| 子系统 | 文件 | 行数 | 技术 | 引擎耦合 |
|---|---|---|---|---|
| 3D 工坊世界 | `src/world.js` | 352 | Three.js 场景图、程序化几何、正交相机轨道、阴影、WASD 移动 | 110 处 THREE 调用 |
| 窑炉特写 | `src/kiln-view.js` | 61 | 独立 WebGLRenderer + 浮雕模型 | 46 |
| 工位模型预览 | `src/workbench-model.js` | 61 | 独立 WebGLRenderer | 19 |
| 瓷砖轮播/地标 | `src/landmarks.js` | 81 | Three.js 网格 | 27 |
| 瓷碗材质与纹样 | `src/decals.js` | 165 | Canvas2D 程序化绘制 → CanvasTexture → 车削体 | 33 THREE + 19 Canvas2D |
| 首页轮播 | `src/hero-carousel.js` | 78 | 独立 WebGLRenderer | 11 |
| 粒子 | `src/particles.js` | 66 | **唯一自定义着色器**（软点精灵） | 10 + GLSL |
| 像素制瓷玩法 | `src/sculpture.js` | 427 | `Uint8Array`(112×112) 像素模型、笔刷、IoU/F1 评分 | **0** |
| 像素渲染 | `src/sculpture-view.js` | 39 | Canvas2D `ImageData` + 关闭平滑 | 0 THREE / 7 Canvas2D |
| 玩法数值 | `src/workshop.js` | 65 | 火候带、漂移函数、经济公式 | **0** |
| 全局状态机与 UI 装配 | `src/main.js` | 335 | DOM 模板字符串、事件委托、存档 | 125 DOM / 9 storage |
| 双语 | `src/i18n.js` + 3 个子表 | 810 | **运行时遍历 DOM 替换文本**，417 条词条 + 41 条正则规则 | 8 DOM / 2 storage |
| 音效 | `src/sfx.js` | 348 | 程序化 WebAudio 振荡器合成 | 17 WebAudio |
| 城市地图 | `src/city-map.js` | 100 | DOM + CSS | 55 DOM |
| 背景音乐 | `src/music.js` | 23 | `<audio>` + 单个 22.5 MB WAV | 7 DOM |
| 样式 | `src/*.css` | 414 | 纯 CSS（构建后 98 KB） | — |

**耦合度总计**：THREE 调用 267 次 / DOM 操作 284 次 / Canvas2D 43 次 / WebAudio 17 次 / localStorage 11 次 / requestAnimationFrame 10 次。

两个关键结构事实：

1. **同时存在 5 个独立的 `WebGLRenderer` 上下文**（`world.js:160`、`kiln-view.js:51`、`decals.js:145`、`workbench-model.js:52`、`hero-carousel.js:20`）。浏览器上下文上限约 16 个，现在是靠「用完即 `forceContextLoss()`」撑住的。引擎里通常用 Viewport / RenderTexture 替代，这一层必须重新设计。
2. **双语不是 keyed i18n**，而是「页面渲染完之后扫描文本节点、按字典和正则替换成英文」。这是一套**只在浏览器 DOM 上成立**的机制，迁移时整套作废，界面文案必须重新按 key 组织（好在 `tools/zh-fragments.json`、`tools/zh-literals.txt` 已经做过中文提取，417 条词条可以直接转 CSV）。

---

## 2. 可迁移性分级

以 3360 行 JS 为基数：

### A 级 · 可几乎逐行搬运（约 561 行 / 16.7%）

| 文件 | 行数 | 说明 |
|---|---|---|
| `src/sculpture.js` | 427 | 纯 `Uint8Array` 像素运算：`pushClay`/`applyBrush`/`protectedCut`/`clayEdge`、`compareSculpture`（形状 IoU×65% + 颜色 F1×35%）、`SculptureChallenge` 的 undo/redo 与站点门禁 |
| `src/workshop.js` | 65 | `createFireDrift` 的三层正弦 + 阵风、`fireGrade`、`orderIncome`、`clockPolicy` |
| `src/campaign.js` `places.js` `tutorial.js` `public-assets.js` | 69 | 关卡与站点数据表 |

**这是整个项目最值钱的部分**：游戏的核心乐趣（像素级捏泥、评分、火候）**与渲染完全解耦**，连一个 `document` 或 `THREE` 引用都没有。翻译成 C# / GDScript / C++ 是机械工作，坐标与算法可保持 1:1，可以逐条对照现有的 62 项逻辑测试验证等价性。

### B 级 · 数据结构可留、调用 API 必须换（约 1145 行 / 34%）

`i18n.js` 810（词条留、机制废）、`main.js` 335（状态机与流程留、DOM 全废）、`sfx.js` 348（音色设计留、WebAudio 全废，需改写成引擎合成器或预渲染 WAV）、`city-map.js` 100、`sculpture-view.js` 39（`ImageData` → `Texture2D` 逐帧上传）。

### C 级 · 必须按引擎重写（约 1650 行 / 49%）

3D 场景构建（world / kiln-view / workbench-model / landmarks / relief-model / particles / decals 的 Three.js 部分，约 560 行）、`scene-carousel.js` 82、`hero-carousel.js` 78、`upgrades-view.js` 32、`guidance.js` 26、`opening-title.js` 24、`art.js` 21 以及全部 414 行 CSS。

> 说明：C 级虽然行数最多，但**技术难度不高**——没有任何物理、没有动画状态机、没有寻路、没有网络同步、没有后处理链，只有一个 30 行的软粒子着色器。真正的成本在**逐件重建程序化几何**（`world.js` 靠 7 个构造辅助函数 `mat/mesh/box/ball/cyl/torus/group` 加 26 处几何构造，拼出工坊、街景、NPC、植物与招牌；`kiln-view.js` 另有 11 处、`landmarks.js` 10 处）和**重排界面**。

### D 级 · 基础设施必须替换

| 现有 | 迁移后 |
|---|---|
| `localStorage` 存档 v9 + v4–v8 迁移链（键 `terra-porcelain-journey-v6`，同时镜像 `sessionStorage`） | 引擎持久化（Godot `user://` JSON / Unity `PlayerPrefs`+JSON / Unreal `SaveGame`），并重写迁移链 |
| Vite 构建 + GitHub Pages | 引擎导出管线（需替换 CI：`.github/workflows/deploy-pages.yml` 整个作废） |
| 62 项 `node --test` 逻辑测试 | 可 1:1 翻译（它们只 import A 级模块），是迁移期最有价值的回归网 |
| 13 个 Playwright `*-browser.mjs` | **全部作废**，只能人工重写为引擎内自动化 |
| Electron / 免安装 Node 包 | 引擎原生导出即可替代 |

---

## 3. 资源迁移性：几乎没有摩擦

| 资产 | 体量 | 迁移方式 |
|---|---|---|
| 四站场景 GLB | 4 个，10.0 MB，265,072 三角面 / 119 材质 / **0 张贴图** | glTF 是三家引擎的统一入口，**1:1 导入**。材质全是纯色 `pbrMetallicRoughness`，无贴图、无骨骼、无动画，重定向成本接近零 |
| `src/scenes/*.blend` | 4 个，1.57 MB | Blender 可再导出 FBX / glTF 给任何引擎，是最高保真的源 |
| 参考图 `public/references/` | 4 张，3.1 MB | 1:1 |
| 地图底图 `public/maps/jingdezhen.png` | 2.1 MB | 1:1 |
| 背景音乐 WAV | **22.5 MB** | 1:1，但**强烈建议先转 OGG（约 2–3 MB）**；这是当前 `dist/` 40 MB 的绝对主因 |
| 字体 `zcool-kuaile-title.woff2` | 1.4 KB | 引擎需 TTF/OTF，用原字体重新导出 |
| 纹样 PNG | 4 张，1.75 MB | **本来就是 `src/decals.js` 的 Canvas 输出**，可直接当预烤贴图用 |

值得强调：**美术资产是本项目里最适合迁移的部分**。真正难搬的是「用代码堆出来的场景装饰」，不是模型。

---

## 4. 引擎选型对比

| 维度 | Godot 4.x | Cocos Creator 3.x | Unity | Unreal 5 |
|---|---|---|---|---|
| 与现有代码的语言距离 | GDScript 重写 / 可用 C# | **TypeScript，可直接复用 A 级 JS 逻辑** | C# 重写 | C++/蓝图重写 |
| GLB 导入 | 原生 | 原生 | 需 glTFast / UnityGLTF | 原生但管线重 |
| 112×112 像素层 | `ImageTexture` + point filter，很自然 | `Texture2D` setPixels，很自然 | `Texture2D.SetPixels32` | 需 UTexture2D 动态更新，笨重 |
| 程序化几何 | `ArrayMesh`/`SurfaceTool` | `utils.MeshUtils` | `Mesh` API | 不友好 |
| UI 重建 | Control 节点 | cc.UITransform | UGUI | UMG（最重） |
| 程序化音频 | `AudioStreamGenerator` | WebAudio（**与现有 sfx.js 同源，几乎零成本**） | `OnAudioFilterRead` | 合成器需插件 |
| 导出目标 | Web / Win / Mac / Linux / 移动 | Web / 小游戏 / 原生 | 全平台 | 全平台 |
| 引擎体积/包体 | 最小 | 小 | 中 | 极大 |
| 与本项目的匹配度 | **高** | **高（若是前端团队）** | 中 | 低 |

**推荐顺序**

1. **Godot 4** —— 首选。GLB 直读、2D/3D 混排自然、包体小、开源无授权风险；GDScript 重写 1650 行表现层是可控工作量；`AudioStreamGenerator` 能承接 `sfx.js` 的合成器思路。
2. **Cocos Creator 3.x** —— 如果团队是 TS/前端。A 级逻辑文件几乎可以原样 import（同为 ESM 语义），`sfx.js` 的 WebAudio 代码在 Cocos 的 Web 后端可直接跑；代价是 3D 表现层仍要重写，且中文生态文档优于 Godot。
3. **Unity** —— 只有在「需要成熟资产商店 / 商业化管线 / 团队已熟悉 C#」时才选。glTF 需要第三方包是额外摩擦。
4. **Unreal** —— **不建议**。本项目无物理、无大型关卡、无 Nanite/Lumen 需求，用 Unreal 等于为 265k 面的场景付出 100 倍的工具链复杂度。
5. **保留 Web（Phaser / PixiJS / Babylon.js）** —— 如果只是想摆脱「手写 Three.js」的维护负担。Phaser 承载像素玩法极合适，Babylon 承载 3D 世界比 Three 更「引擎化」。这条路的迁移成本最低，但不算「换游戏引擎」。

---

## 5. 主要风险

1. **像素渲染精度**：玩法画布是 112×112 的 `Uint8Array`，靠 `imageSmoothingEnabled=false` + CSS 放大实现「点阵感」。引擎里要保证 point sampling、避免纹理过滤与 mipmap 把边缘糊掉，还要处理高 DPI 与触屏坐标换算（现有 `sculpture-view.js` 的 `pos()` 用的是 `getBoundingClientRect`）。
2. **多 WebGL 上下文 → 单渲染管线**：现在 5 个 Renderer 各自成画，UI 里嵌 3 个独立 3D 预览。迁移后要用 Viewport / SubViewport / RenderTexture 重做，画质（尤其 ACES 色调映射与 PMREM 环境光）会有肉眼可见差异，需要重新调色。
3. **程序化音频重写**：`sfx.js` 348 行是振荡器 + 包络 + 噪声的实时合成。引擎音频 API 差异最大，通常要么重写成引擎合成器，要么**离线预渲染成 20–30 个 WAV**（推荐，成本低且音色一致）。
4. **双语体系重建**：现有 417 条词条 + 41 条规则是「DOM 文本替换」，迁移后所有界面文案必须重新按 key 组织。`i18n.js` 有大量针对中文语境的规则（CJK 检测、属性白名单），这部分设计意图需要人工保真。
5. **存档兼容**：v9 + 四条历史迁移分支。迁移后老玩家的进度无法带过去（除非引擎侧继续读 `localStorage` 键做一次性导入——Web 导出版本可以做到）。
6. **测试断档**：13 个 Playwright 脚本全部作废，62 项逻辑测试需翻译。迁移期会有 2–4 周「没有自动化回归」的窗口，建议先在 Web 侧把 A 级逻辑抽成独立包并跑通测试，迁移时用它做等价性基准。

---

## 6. 迁移前应该先做的解耦（成本最低、收益最大）

**不要直接开新工程。** 先在现有 Web 项目里做 4 件事，能把迁移从「重写一个游戏」降级为「替换一层壳」：

1. **抽 `src/core/`**：把 `sculpture.js` + `workshop.js` + `campaign/places/tutorial` 数据移进零依赖目录，加一条构建期断言「core 不得 import 任何 DOM/THREE 模块」。这 561 行是迁移时唯一能整包带走的东西，必须保证它不被表现层污染。
2. **渲染适配器**：给 `world.js`/`kiln-view.js`/`decals.js` 抽一层 `Renderer` 接口（`createScene / addWorkbench / setCamera / render`），把 267 处 THREE 调用收敛到 1 个文件里。迁移时只需要重写这一个文件。
3. **WebGL 上下文收敛**：5 个 Renderer 合并为 1 个主 Renderer + offscreen RenderTexture 预览，同时解决上下文上限与移动端性能问题。
4. **文案外提**：把 1961 处中文字面量按 key 提成 `zh.json` / `en.json`，现有 `tools/zh-literals.txt` 已经把范围摸清了。这一步做完，任何引擎的本地化系统都能直接吃。

做完这 4 步，A+B 级（约 47%）就能以数据与模块的形式整体搬走，C 级也收缩成「一个渲染适配器 + 一套界面」。

---

## 7. 工期粗估（单人、熟悉目标引擎、含回归）

| 目标 | 逻辑移植 | 3D 重建 | 像素玩法与界面 | UI/双语/无障碍 | 音频 | 打包+存档+回归 | 合计 |
|---|---|---|---|---|---|---|---|
| Godot 4 | 0.5 周 | 2 周 | 1.5 周 | 2 周 | 0.5 周 | 1 周 | **7–8 人周** |
| Cocos 3.x | 0.2 周 | 2 周 | 1 周 | 2 周 | 0.3 周 | 1 周 | **6–7 人周** |
| Unity | 0.5 周 | 2.5 周 | 1.5 周 | 2 周 | 1 周 | 1 周 | **8–9 人周** |
| Unreal | 1 周 | 4 周 | 2 周 | 3 周 | 1.5 周 | 1.5 周 | **13 人周以上** |
| 先做 §6 解耦 | — | — | — | — | — | — | 额外 **1.5–2 人周**，但后续每一项都缩水 20–30% |

> 前提：不重做美术、不复刻像素级视效、不追求与 Web 版 1:1 的渲染一致性。若要求「换引擎但画面完全一致」，把 3D 重建一栏乘以 1.8。

---

## 8. 最终建议

- **要做，而且值得做**：核心玩法（像素制瓷 + 评分 + 火候）是**引擎无关的纯逻辑**，这在这个体量的项目里非常少见，等于已经把最难搬的部分搬完了。
- **但要先做 §6 的解耦**，否则会花 2 周在目标引擎里重新发明 `localStorage`、`requestAnimationFrame` 和 CSS 布局。
- **不要选 Unreal**；**Godot 4 是性价比最高的落脚点**，除非团队明确要求 TS 生态，那选 Cocos Creator。
- **如果目标只是 Windows 单机发行**，迁移是纯粹的长期维护投资，不是交付必需：已有免安装包（现归档在仓库外 `D:\ECNU\BOKE\Porcelain_Workshop_Archive\release\`）在本机就能跑，没必要为了发行换引擎。

---

## 9. 仓库瘦身对迁移的影响（2026-10-26）

上一轮已把仓库收敛到「源码 + 运行必需资源 + 可独立运行的单测」约 78 个文件（明细见 `docs/repo-layout.md`）。对迁移计划的净影响是**正面的**，但有三处必须提前注意：

### 9.1 变好的部分

| 变化 | 对迁移的意义 |
|---|---|
| `desktop/` 与 `tools/package-*.mjs` 移出版本库 | Web 版与 Electron 外壳彻底解耦，不会有人误以为「桌面端是产品形态」。Godot 的 export preset 直接替代这 3 个文件。 |
| 6 个 devDependencies 删除（electron / @electron/* / playwright-core / png-to-ico） | Godot 侧不需要 Node 工具链；Web 版只剩 `three` + `vite`，移植时阅读 `package.json` 不会再被无关依赖干扰。 |
| 浏览器 E2E（12 个 `tests/*browser*.mjs`）只留本机 | 这些脚本的价值是**行为规格文档**：32 万字符里写清了教学强制顺序、12 秒火候、双语切换、资源释放。迁移时应把它们当验收清单读，而不是当测试跑（Godot 里重写同样的用例，Godot 单测用 GUT 或 `--headless` 脚本）。 |
| `qa/`、`shots/`、`.desktop-build/`、`release/` 清理 | 工作区从 3.4 GB 降到约 220 MB，迁移时把整个仓库拖进新工程目录的成本几乎为零。 |

### 9.2 必须带走、且**没有**被 gitignore 的迁移输入

这 4 类文件是迁移的原料，全部仍在版本库内，克隆即得：

1. `src/scenes/*.blend` ×4（1.5 MB）—— 四站 GLB 的**唯一母版**。Godot 用 `glTF` 导入管线，仍需保留 .blend 以便将来改美术；若只想复用现成 GLB，可只带 `public/models/maps/*.glb`。
2. `public/models/maps/*.glb` + `manifest.json` ×5 —— 265,072 三角面 / 119 材质 / 0 贴图 / 0 动画。Godot 可直接导入 glTF，但 `manifest.json` 里的锚点（工作台位置）需要在 Godot 里重建成 `Node3D` 标记点。
3. `src/assets/pottery backround music.wav`（22 MB）+ `src/assets/fonts/`（含 OFL 许可文本，**迁移后仍须随字体分发**）。
4. `src/*.js` 里的 A 级逻辑（`sculpture.js` 427 行纯 `Uint8Array`、`workshop.js` 65 行数值模型）—— 这是最该原样搬走的部分。

### 9.3 迁移时**不要**带走的东西

- `.git/` 历史（109 MB，含已删除的 91 MB deliverables 历史）：新引擎工程建议另起 git 仓库，或 `git filter-repo` 后再迁，避免把 Web 版历史拖过去。
- `tests/*browser*.mjs`、`qa/`、`shots/`：Playwright 绑定 DOM，换成 Godot 后全部失效。
- `src/*.css`（约 100 KB / 10 个文件）：CSS 布局在引擎里没有对等物，属于重写项。
- `vite.config.js`、`index.html`、`.github/workflows/deploy-pages.yml`：Web 专属发布链路。

> 一句话：**仓库瘦身把「迁移时要读的东西」从 5768 个文件压到 78 个，这是这次清理对迁移最大的实际收益。**
