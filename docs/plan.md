# qqfeiche3d 克隆计划

状态：步骤 6 实现与验证完成，正式场景已恢复并打包，调试实例已停止，等待人工验收；步骤 7 未执行。步骤 5 历史记录保留，SDK 异常见步骤 6 验证记录。

## 目标与依据

将 [qqfeiche3d](https://lf3-static.bytednsdoc.com/obj/eden-cn/nulojnulwlo/qqfeiche3d/index.html) 的赛道、车辆、驾驶手感、比赛流程、界面、道具和声音移植到本仓库的 Unity / 抖音虚拟世界工程。

- 目标工程：`unity/`，Unity `2021.3.14f1`，URP `12.1.8`。
- 开发配置以 [hamlet-preferences.md](../.trae/skills/hamlet-skill/hamlet-preferences.md) 为准：Lua、DedicatedServer、Avatar、UnityEditor。
- 操作和逐步人工确认流程以 [clone 命令](../.trae/commands/clone.md) 为准。
- 平台 API 与编码规则以 [hamlet-skill](../.trae/skills/hamlet-skill/SKILL.md) 及其按模块引用的原文为准。
- 构建、启动、日志取证以 [hamlet-debugging](../.trae/skills/hamlet-debugging/SKILL.md) 为准。
- 本计划记录方案、任务和验证证据，不另建重复的通用规则来源。

## 1. 页面与实现分析

### 资源结构

入口 HTML 共 **717,860 字节**，包含一份内嵌 JavaScript、一份内嵌 CSS。脚本已包含 Three.js、后处理和游戏逻辑，没有外部游戏脚本、模型、图片或音频引用。

入口 SHA-256：`8765c7eee4cd33e00fa4265d22b1e961852189dffdf27ecb42f76148a3934eff`。

资源提取目录：[reference/qqfeiche3d](reference/qqfeiche3d/)。

| 文件 | 内容 |
| --- | --- |
| [index.html](reference/qqfeiche3d/index.html) | 下载的原始页面 |
| [inline-script-1.js](reference/qqfeiche3d/inline-script-1.js) | 原始内嵌脚本 |
| [readable-script.js](reference/qqfeiche3d/readable-script.js) | 格式化脚本，供定位实现 |
| [inline-style-1.css](reference/qqfeiche3d/inline-style-1.css) | 原始样式 |
| [manifest.json](reference/qqfeiche3d/manifest.json) | 静态引用、文件大小与入口哈希 |
| [browser-lobby.json](reference/qqfeiche3d/browser-lobby.json) / [browser-race.json](reference/qqfeiche3d/browser-race.json) | 浏览器 DOM、Canvas 与运行资源记录 |
| [runtime.har](reference/qqfeiche3d/runtime.har) | 开始比赛至暂停期间的网络记录 |
| [dynamic-manifest.json](reference/qqfeiche3d/dynamic-manifest.json) | 四条赛道运行规模、70 张贴图的属性与哈希 |
| `tracks/{city,aegean,egypt,snow}.json` | 运行时轨道中心线、方向、坡度、倾角、高度与地图配置 |
| [vehicle-three.json](reference/qqfeiche3d/vehicle-three.json) | 共享赛车的 Three.js 对象、29 份几何定义与材质 |
| `textures/texture-001.png` 至 `texture-070.png` | 从运行时 Canvas 提取的 PNG 贴图 |
| [lobby.png](reference/qqfeiche3d/lobby.png)、[race.png](reference/qqfeiche3d/race.png)、[pause.png](reference/qqfeiche3d/pause.png) | 大厅、比赛 HUD、暂停基准截图 |

HAR 在采集区间仅记录到站点 `favicon.ico`，响应 404；游戏运行未请求模型、纹理或音乐文件。该结论限定于本次观测区间，并由脚本的程序生成实现支持。

已导出轨道数据、可见材质的 Canvas 贴图及共享车辆模型。完整环境网格、着色器输出、音效波形没有作为独立资产导出；环境与音频生成逻辑保留在原始脚本中，后续按下表实现定位移植。

### 功能与源码定位

以下行号对应 `readable-script.js`，名称为打包后的符号。

| 模块 | 已确认实现 | 源码定位 |
| --- | --- | --- |
| 地图配置 | 城市、爱琴海、沙漠、雪地；天空、雾、水面、路面、护栏、加速带、隧道 | `Bo`，27039–27189 |
| 程序贴图 | Canvas 绘制噪声、路面、建筑、文字等，再转为 Three.js 纹理并缓存 | `rn`、`on`、`an`，27277–27826 |
| 轨道 | 闭合 centripetal Catmull–Rom 曲线；约每 1.5 单位采样；坡度、倾角、空间索引、车辆投影 | `Ho`，27828 起 |
| 环境 | 按地图构造地形、建筑、桥、隧道、植被、水面和雪粒子；按空间块合并静态几何 | `ko`，28789 起；地图构造函数 29732–30696；`loadMap`，33218 起 |
| 赛车 | 共用车身、座舱、轮胎、尾翼等几何；8 种颜色主题；轮胎转向、排气、底盘光、护盾 | `Ui`、`l_`、`Hc`，30697–31024 |
| 驾驶 | 自定义运动学；车身方向与运动方向分离；油门、刹车、倒车、漂移、碰墙、腾空、落地 | `qn`、`Yo`，31025 起 |
| 喷射 | 漂移集气、2 个氮气槽、小喷与完美窗口、双喷、起步喷、落地喷、加速带 | 31115–31393；`applyStartBoost`，33595 起 |
| AI | 轨道采样驱动、难度系数、追赶补偿；一局共 6 辆车，原版为玩家 + 5 个 AI | `Zo`，31431 起；`Wc`，32851 起；`makeRacers`，33341 起 |
| 道具 | 氮气、天使护盾、磁铁、香蕉、导弹；2 个槽位与换位；按名次加权发放 | `ta`，32607–32847 |
| 音频 | Web Audio 振荡器、噪声、滤波器合成引擎、漂移、风声、事件音效与曲目 | `Ko`，31833–32189 |
| 输入 | 键盘与触摸状态汇聚；区分持续按住与单次按下 | `Qo`，32207–32295 |
| HUD | 名次、圈数、时间、最佳单圈、速度表、小地图、集气、氮气/道具与操作提示 | `jo`，32296 起 |
| 游戏流程 | `menu → countdown → race → finish`；暂停保存进入前状态；重新开始与返回大厅 | `qc`，32943 起 |
| 更新 | `requestAnimationFrame` 渲染，运动学累积器按 `1/120` 秒步进；单次输入仅第一子步消费 | `na`，32873；`loop` / `step`，33448–33583 |
| 相机与画质 | 3 种跟车距离、速度/喷射改变 FOV；低档关闭阴影和后处理，中高档启用 Bloom | `setupQuality`，33030 起；相机与渲染 34211–34357 |
| 本地配置 | `localStorage` 键 `feiche3d.v1`；保存地图、模式、颜色、圈数、难度、画质与曲目 | 32850；33018–33029 |

### 已提取地图

长度单位沿用源程序，后续以 Unity 1 单位对应源程序 1 单位建立首轮基准。

| 地图 | 轨道长度 | 中心线采样数 | 本次场景 Mesh 数 / 顶点数 |
| --- | ---: | ---: | ---: |
| 11城 `city` | 2355.055 | 1570 | 1008 / 611737 |
| 情迷爱琴海 `aegean` | 2498.508 | 1666 | 731 / 640727 |
| 法老金字塔 `egypt` | 2430.197 | 1621 | 527 / 502221 |
| 雪地大冒险 `snow` | 2150.707 | 1434 | 539 / 921327 |

Mesh 与顶点数包含本次场景里的演示车辆及表现对象，不等同于静态赛道资产数量。

### 驾驶基准

直接使用源程序参数作为首轮移植依据，不能只靠视觉猜测。

| 参数 | 原版值 |
| --- | --- |
| 正常 / 氮气最高速度 | 55 / 76 单位每秒 |
| 正常 / 氮气加速度 | 24 / 40 |
| 制动 / 倒车最高速度 | 45 / 12 |
| 漂移最低速度 | 13 |
| 普通抓地 / 漂移抓地 / 松开漂移抓地 | 12 / 2 / 5.2 |
| 最大漂移角 | 1.15 弧度 |
| 漂移结束后的有效小喷窗口 | 0.5 秒，漂移时长需大于 0.22 秒 |
| 完美小喷判定 | 窗口开始后的前 0.2 秒 |
| 氮气持续时间 / 连续使用时上限 | 2.8 / 4.5 秒 |
| 落地喷窗口 | 0.45 秒 |
| 起步喷判定 | 倒计时最后约 0.28 秒，或 GO 后前 0.28 秒的首次油门按下 |
| 氮气库存 / 道具槽 | 各最多 2 个 |

键位保留：方向键驾驶、Shift 漂移、Ctrl/空格氮气或道具、Alt 换位、↑/W 小喷、R 复位、C 相机、M 音乐、PgUp/PgDn 切歌、Esc 暂停、H 帮助。移动端使用平台输入与自定义按钮汇聚到同一输入模型。

## 2. 克隆方案

### 方案比较

| 方案 | 收益 | 成本与适用性 |
| --- | --- | --- |
| **Unity 原生场景 + Lua 移植，推荐** | 对接平台网络、输入和调试；复用已提取贴图和轨道数值；能分阶段比对 | 需移植 Three.js 网格构造、音频合成与运动学 |
| 将原 HTML 嵌入 WebView | 浏览器视觉可直接复用 | 与 Unity 场景、Hamlet 网络和平台输入的集成不满足本次工程方向 |
| 以提取模型为基础改用通用刚体车辆控制 | 几何复用较快 | 漂移、喷射与碰撞手感会偏离原版，调参工作更多 |

推荐采用第一种。先贯通 11城的一条完整比赛链路，再扩展道具与其余地图，最终验收完整功能范围。

### 场景与代码组织

- 新建 `Assets/Scenes/RacingClone.unity`；赛道、美术、UI、Prefab 与 Lua 文件集中在 `Assets/RacingClone/`。
- 通过 `unity-mcp` 创建和配置场景对象、Prefab、材质、碰撞体、UGUI、SDK 组件与序列化引用，并保存工程资产。
- 从提取的 Three.js 车辆几何转换为 Unity Mesh，处理坐标手性、三角形绕序、法线、UV、层级变换和材质；贴图按动态清单绑定重复模式与缩放。
- 先使用提取轨道采样数据构造道路、护栏和查询模型，再按源码重建各地图环境。雪地立交与沙漠腾空保留高度数据。
- 使用 `hamlet-skill` 生成 Lua。模块按职责划分为 `RaceConfig`、`TrackMath`、`VehicleSimulation`、`RaceInput`、`RaceClient`、`RaceServer`、`RaceAI`、`RaceItems`、`RaceHUD`、`RaceCamera`、`RaceAudio`。
- 运动学保留源程序固定子步与数值参数。Unity 碰撞组件承担道路、障碍和触发检测；若需 Rigidbody，按平台物理文档在 FixedUpdate 中唯一驱动，避免 Transform 与刚体同时控制位置。
- Lua 模块通过 SDK Loader 注册；行为通过 Douyin Script 组件挂载。具体 API 和字段在对应步骤执行前核对文档与已安装 SDK 类型。

### 原版单机与工程 DS 的对应

原版没有联机服务端。目标按项目偏好实现 DS：服务端管理比赛时钟、AI、道具、圈数、碰撞结果与结算；客户端采集输入、预测自身车辆并显示经服务端确认的状态。

- 一局固定 6 个席位；一个真实玩家时补 5 个 AI，第二个真实玩家加入时替换一个 AI。网页五个 AI 的行为与难度是基准。
- 同步状态含比赛阶段、起跑时间、车辆姿态/速度、进度、喷射库存、道具和结果。输入提交携带序号，预测与校正使用同一运动学模型。
- DS 的网络发送频率独立于 120 Hz 运动学子步；具体频率在步骤 4 实测后记录。
- 大厅中的地图、模式、圈数、AI 难度由房间发起者选择；画质、赛车配色、镜头和音乐为玩家配置。
- 暂停由房间发起者请求，服务端暂停整场比赛并同步所有客户端；继续、重开和返回大厅遵循同一房间流程，避免各端时钟分叉。
- 默认不接入云存储，先还原本地设置与单局结果。

客户端输入、相机、UI、音频各自使用平台允许的实现。音频优先根据源码合成并烘焙成 Unity AudioClip；动态引擎声音由音高、音量和循环片段控制。不将 Web Audio API 直接用于 Lua。

## 3. 执行步骤与验收

状态表只表示已发生的工作；未完成的验证不记作通过。

| 步骤 | 工作及交付 | 预期结果与验证方法 | 状态 |
| --- | --- | --- | --- |
| **1** | agent-browser 页面取证；保存静态脚本、运行时轨道/贴图/赛车；形成此计划 | 页面可加载；开始比赛后出现 HUD；Esc 暂停；资源清单可追溯；导出四张地图与共享车辆数据 | **已完成，人工已确认** |
| **2** | 连接 unity-mcp，读取活动场景和 Console；建立 `RacingClone.unity` 的 SDK 世界根、服务端根与最小服务脚本；通过 `Tools/ScenePackage` 打包 | MCP 返回目标工程；新场景正确保存；构建时间与产物对应；调试器 dry-run 通过后实际启动 DS + 2 客户端；日志确认两人进入同房间 | **场景、构建、入房通过；DS 空引用已定位至 SDK 角色同步组件，未修复** |
| **3** | 转换共享赛车 Mesh / 8 配色；导入贴图；重建 11城道路、护栏、桥和主要城市环境 | 调试器内车辆、道路可见；起点视角截图可与 `race.png` 对照；中心线闭环、道路宽度与高程正确；碰撞体连续且桥面没有错误吸附 | **已获人工确认；既有 SDK 异常保留** |
| **4** | 实现输入、固定步运动学、DS 输入/状态同步、跟车相机、漂移与全部喷射 | 同一固定输入序列下，速度曲线和位移对齐原版；漂移集气、2 氮气槽、完美小喷、双喷、起步喷、落地喷均有可观察结果；另一客户端看到一致车辆状态 | **已实现；6,960 子步与 184 组三端快照对照通过，全部喷射有运行证据；SDK 异常与最终桌面重测未通过，等待人工验收** |
| **5** | 大厅配置、6 席比赛、3 档 AI、倒计时、名次与圈数、结果、暂停/重开/回大厅、比赛 HUD | 单人 + 5 AI / 双人 + 4 AI 可运行；正常完成指定圈数；倒车过线与复位不刷圈；所有客户端显示同一计时和结果；暂停恢复不跳时 | **功能与双人真实按钮通过；单人五 AI 入房通过，单人完整赛程及最终桌面回归受锁屏阻塞，待继续本步** |
| **6** | 道具模式、道具箱、2 槽换位、氮气/护盾/磁铁/香蕉/导弹、AI 用道具 | 采集、使用、换位与箱子刷新符合源码；命中只结算一次；护盾阻挡；各端库存和效果一致；竞速模式仍按漂移集气 | **实现、原版对照、真实输入、自然道具赛程及三端同步通过；保留 SDK 异常，等待人工验收** |
| **7** | 爱琴海、沙漠、雪地完整场景；隧道、跳台、立交、水面、雪；音乐/音效、3 相机、3 画质、触摸输入 | 四地图都能完整比赛；雪地上下层独立；沙漠腾空与落地喷正常；音乐切换与关闭生效；画质切换可见；横竖屏 UI 和触摸操作可用 | 未执行 |
| **8** | 完整功能回归、性能采样、源码/API 检查；整理工程启动和交付说明 | 全部验收项通过；保留实际构建与 DS/双客户端日志、截图和性能数据；计划记录差异及处理结果；交付可启动场景与脚本 | 未执行 |

每步结束后在下方新增验证记录，并停在该步的人工确认点。收到确认只继续下一步；修复与该步回归归属同一步。

### 每步平台验证

场景或脚本变更后的验证遵循 hamlet-debugging 原流程：保存 → 编译检查 → `unity-mcp` 调用 `Tools/ScenePackage` → 核对实际构建完成 → dry-run → 启动 → 按该步用例操作 → 检查 DS 与客户端日志。

新场景构建完成后，DS 预检命令为：

```bash
python3 .trae/skills/hamlet-debugging/scripts/simulator.py \
  --project unity \
  --mode ds \
  --players '赛车验证1' '赛车验证2' \
  --scene Assets/Scenes/RacingClone.unity \
  --room 0 \
  --network new \
  --data-store off \
  --pawn-actor-type avatar \
  --windowless \
  --dry-run
```

通过后移除 `--dry-run` 实际启动。新网络需项目 SDK 的有效登录与设备记录，实际入房以日志为证据。运行日志、缓存和调试会话保存在系统临时目录；计划记录其实际路径和关键结果。

### 具体回归用例

1. **驾驶与喷射**：直线加速、松油门、制动倒车；左右漂移；松开漂移后不同延迟的小喷；氮气叠加；加速带；倒计时油门；跳台落地；碰墙与 R 复位。
2. **圈数与结果**：起跑过线不提前计圈；经过半圈再过线；终点附近倒车往返；不同圈数；AI 和玩家先后完成；暂停后继续、重开、回大厅。
3. **道具**：拾取至两槽；Alt 换位；逐项使用；护盾挡导弹；香蕉对自己和对手的判定；磁铁无目标时行为；箱子刷新与多车同时拾取。
4. **地图**：四图道路边界、隧道入口与出口；爱琴海上下坡；沙漠跳台；雪地交叉上下层；小地图与实际位置一致。
5. **网络**：DS + 两客户端；不同玩家车辆的输入隔离；结算一致；暂停一致；玩家离房席位处理；重新入房后的比赛状态。
6. **表现**：8 配色、3 镜头、3 画质、音乐切换、速度和喷射音效、HUD 遮挡与分辨率适配。

## 4. 验证记录

### 步骤 1：资源提取、分析与计划

日期：2026-11-24。

- **页面访问：通过。** 使用 `agent-browser open` 访问原网址，标题为“飞车 3D · QQ飞车同人还原”。提取到大厅的地图、模式、赛车、圈数、难度、画质和按键说明。
- **流程观察：通过。** 点击 `#start`，等待倒计时后出现比赛；观测圈数 `1/2`、名次 `6/6`、计时、速度、集气/氮气栏；按 Esc 后显示继续比赛、重新开始、返回大厅。
- **截图：通过。** 已保存大厅、比赛、暂停三张基准截图，并查看比赛截图确认其内容。
- **静态资源：通过。** 保存入口、内嵌脚本和 CSS；脚本格式化成功；入口哈希与引用已记录。
- **动态资源：通过。** 在同一浏览器会话中依次调用页面已有的 `loadMap` 与 `startDemo`，导出四条赛道、70 张运行时 PNG 和 29 份共享车辆几何定义。
- **文件完整性：通过。** 87 份参考文件共 12,618,530 字节；入口哈希、70 张 PNG 的尺寸与哈希、四地图采样数组长度及计划内本地链接均已校验。
- **资源引用：通过。** 静态引用仅作者外链；本次比赛 HAR 仅一个 favicon 404 请求。贴图来自 Canvas，声音来自 AudioContext 合成。
- **工程检查：已完成。** 工程含 `SampleScene.unity`、Douyin SDK、URP 与 `com.coplaydev.unity-mcp` 包；已有 `Tools/ScenePackage` 菜单，内部调用 `SimulatorUtils.BuildActiveDebugScene()`。
- **Unity MCP：尚未连接。** 当前会话的工具发现与 MCP 资源列表未提供 Unity 操作工具。安装包存在不代表 MCP 已连接；本次没有执行 Unity 场景变更。
- **调试器前提：未通过。** 对现有 `SampleScene.unity` 执行 DS dry-run，退出码 2；缺少 `unity/AddressableAssetsData/StandaloneOSX/SampleScene/OSX/addrsettingcache/settings.json`，需要先构建场景。这次只是本地预检，没有启动调试器或验证 Unity 玩法。
- **计划自检：通过。** 功能范围覆盖四地图、8 配色、竞速/道具、AI、驾驶喷射、比赛流程、HUD、输入、声音、相机和画质；区分原版单机与 DS 目标；各步有明确产物与验收。

人工确认：**已收到用户“依据 docs/plan.md，继续执行”，据此执行步骤 2。**

### 步骤 2：场景搭建、构建与双客户端入房

日期：2026-11-24。

#### 变更与产物

- [RacingClone.unity](../unity/Assets/Scenes/RacingClone.unity)：新建 SDK 世界根、服务端根、官方 Lua Loader、两个角色出生点，以及基础地面、光源、相机。
- [RaceServer.lua](../unity/Assets/RacingClone/Lua/Server/RaceServer.lua)：仅服务端执行初始化与玩家名单日志；网络就绪后输出 `SERVER_READY`。
- [RaceClient.lua](../unity/Assets/RacingClone/Lua/Client/RaceClient.lua)：仅客户端输出本地玩家就绪与房间名单。
- [RacingMcpBridge.cs](../unity/Assets/RacingClone/Editor/RacingMcpBridge.cs)：Editor 桥接已安装的 Unity MCP 原生服务，支持当前工程的场景、代码和菜单操作。
- `Assets/RacingClone/Materials/BootstrapGround.mat`、场景 ShaderVariants 与 Addressables 源配置已保存。构建生成目录 `unity/AddressableAssetsData/` 已加入 `.gitignore`。

#### 验证结果

1. **Unity MCP：通过。** 使用已安装包的原生 stdio socket Bridge 连接活动 Unity 工程；成功读取场景与 Console，创建并保存场景，执行构建菜单。场景检查结果为未修改、一个世界根、一个服务端根，Lua ScriptAsset 引用有效。
2. **编译与打包：通过。** MCP 调用 `Tools/ScenePackage`，Editor 日志记录 `BuildPlayerGenerator Succeeded`；构建后 Console 错误和警告均为 0。缓存 `settings.json` / `catalog.json` 可解析，更新时间均为 **2026-11-24 16:46:43**，大小分别为 3,198 / 13,051 字节。完整构建日志保存在 `/tmp/racing-editor-build.log`，原日志可能含登录信息，不直接分享。
3. **本地预检：通过。** 目标场景 DS dry-run 成功，日志 `/tmp/racing-ds-preflight.log`。
4. **启动前提修正：通过。** 首次实际启动缺少设备记录；补充 SDK 设备信息后，磁盘登录缓存导致建房接口返回 `-30001`。对照发现当前 Unity 内存登录与磁盘记录不一致；使用当前登录及设备信息的环境变量覆盖后建房成功。没有在工程中保存凭证。
5. **DS + 两客户端：通过。** 使用新网络创建房间，存储关闭，Avatar，服务端无窗口，客户端昵称“赛车验证1”“赛车验证2”；以 `SERVER_READY` 为服务端就绪条件。调试器使用 `/tmp/racing-debugger/{server,client-1,client-2}/` 中的本地副本。
6. **同房间入房：通过。** 服务端与两客户端均输出 `ROOM_PLAYERS count=2 roster=2:赛车验证1,3:赛车验证2`；两客户端分别输出自身 `CLIENT_READY`。这项结论来自运行时玩家名单，不仅是启动参数或进程存活。
7. **场景显示：通过。** 两端截图可见基础地面、天空和角色，本地昵称分别正确；第一客户端画面可见另一个角色。截图：[客户端 1](verification/step-2/client-1.png)、[客户端 2](verification/step-2/client-2.png)。
8. **运行日志：未全部通过。** 三端未发现 `LuaException`，但服务端在玩家加入后持续出现 `NullReferenceException: Object reference not set to an instance of an object.`，本轮快照累计 17,482 条。Player 与 HDB 日志均未包含该异常的调用堆栈，尚未确定来源，不能据此宣称运行无错误。另有临时副本的 Application Support 目录创建被沙箱拒绝、Avatar 动画片段加载失败、HDB 未连接及 GPU 着色器警告；这些记录没有阻止本轮入房与显示。

实际会话目录：

```text
/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T/hamlet-simulator-vmz8h2yn/
```

服务端 PID `60793`，客户端 PID `60865` / `60881`；`session.json` 的三个 `roomTag` 均为 `5b48a7ce3483`。原始 `server.log`、`client-1.log`、`client-2.log`、console 与 HDB 日志保留在该临时目录。验证后已停止本轮启动命令与实例。

可分享的脱敏证据：[evidence.json](verification/step-2/evidence.json)，包含构建时间、会话、关键日志行号、玩家名单与异常计数。

步骤 2 结束时只验证了平台场景加载和入房，尚未实现赛车、赛道与比赛玩法。**步骤 2 尚未全部验收。用户随后明确要求“继续执行步骤 3”，据此继续资产与赛道工作；服务端空引用及调试器缓存权限问题保留为待修复项。**

### 步骤 3：共享赛车与 11城场景

日期：2026-11-24。

#### 变更与产物

- [City.racingmesh](../unity/Assets/RacingClone/Source/City.racingmesh)：原版暂停在起点时导出的城市与共享赛车网格，含 **755 份几何、548,972 个顶点、139 份源材质、790 个城市节点、58 个赛车节点**。保留坐标、法线、UV、顶点色、几何分组、层级、轨道高程和纹理参数。
- [prepare_racing_assets.py](../tools/prepare_racing_assets.py)：将运行时导出转换成工程源资产，按哈希匹配贴图，读取原脚本的八种颜色主题。
- [RacingMeshImporter.cs](../unity/Assets/RacingClone/Editor/RacingMeshImporter.cs)：可重复的 Unity ScriptedImporter，处理 Z 轴反射、三角形绕序、法线、32 位索引和子网格；额外生成护栏双面碰撞网格。
- [RacingCityBuilder.cs](../unity/Assets/RacingClone/Editor/RacingCityBuilder.cs)：通过 MCP 调用生成材质、预制体与场景。Three.js 单材质网格的所有子网格均绑定同一材质，避免车身、尾翼和建筑缺面。
- `Assets/RacingClone/Textures/`：原有 **70 张 PNG 全部导入**，另补充一张本次城市运行时贴图；共 71 个文件、69 个不同内容哈希。纹理 UUID、路径、哈希、重复方式见 [asset-manifest.json](verification/step-3/asset-manifest.json)。
- [City11.prefab](../unity/Assets/RacingClone/Prefabs/Maps/City11.prefab)：完整闭环道路、护栏、路肩、加速带、起跑门、看台、两座桥、建筑、树木、路灯及河面；场景内共有 **578 个静态 MeshCollider**。
- `Assets/RacingClone/Prefabs/Vehicles/`：红、蓝、紫、黄、白、粉、绿、黑八种车辆预制体，复用共享网格。起点按原版六车位置、姿态和配色放置静态展示车辆。
- [RacingClone.unity](../unity/Assets/Scenes/RacingClone.unity)：替换基础地面为城市地图；配置原版起点相机、天空、雾、光源、Bloom 与原生静态水材质。自定义相机加入 SDK 保留列表，深度设为 100，避免平台默认角色相机覆盖。
- [RacingCityVerification.cs](../unity/Assets/RacingClone/Editor/RacingCityVerification.cs)：在 Unity 实际碰撞体上进行全环采样校验。Editor MCP Bridge 改为域重载后重新启动。

#### 验证结果

1. **几何与闭环：通过。** 道路长 2355.054593 单位，1,570 个中心线采样；首尾两侧顶点接缝误差为 0。中心线最大误差 `0.0000153` 单位；水平道路宽度 26 单位，最大误差 `0.0000420`；中心线高程范围 `-0.162539` 至 `6.042768`。宽度按源程序的水平定义验证，倾角造成的斜面长度不作为宽度误差。
2. **路面与护栏碰撞：通过。** 每个采样点检测道路左侧、中心、右侧，共 **4,710 次路面射线**全部命中，最大高度误差 `0.00000334` 单位；**3,140 次向两侧护栏的射线**全部命中。检测关闭背面命中，验证护栏朝向车道的碰撞面有效。该结论限定于本轮全环采样；车辆运动中的穿墙与碰撞响应将在步骤 4 验证。
3. **桥面：通过。** **219 个桥区中心线采样**从桥面上方短距离向下检测，均命中道路碰撞体，未命中桥底或下方河面；没有观察到错误吸附。详见 [geometry-validation.json](verification/step-3/geometry-validation.json)。
4. **视觉资产：通过。** 已查看 [八配色截图](verification/step-3/vehicle-eight-colors.png)、[城市全景](verification/step-3/city-overview.png) 和 [Unity 起点截图](verification/step-3/unity-start.png)。与本次 [原版固定起点](verification/step-3/reference-start.png) 对照，车辆位置、起跑门、道路、护栏、桥和主要建筑布局对应。
5. **编译与实际打包：通过。** MCP 调用 `Tools/ScenePackage`；Editor 日志记录 `BuildPlayerGenerator: Succeeded`，构建后 Console 错误为 0。最终 `settings.json` / `catalog.json` 可解析，更新时间分别为 **17:42:34.537 / 17:42:34.532**，大小为 3,198 / 12,318 字节。完整本地构建日志 `/tmp/racing-step3-editor-build.log`，预检日志 `/tmp/racing-step3-ds-preflight.log`。
6. **DS + 两客户端实际运行：通过。** 新网络新房间、存储关闭、Avatar、服务端无窗口；等待 `SERVER_READY` 后启动“赛车验证1”“赛车验证2”。三端均输出 `ROOM_PLAYERS count=2 roster=2:赛车验证1,3:赛车验证2`，两个客户端分别输出自身 `CLIENT_READY`。
7. **调试器起点显示：通过。** 已查看并保存 [客户端 1](verification/step-3/client-1.png) 与 [客户端 2](verification/step-3/client-2.png)。两端可见起点赛车、道路、护栏、起跑门、树木、城市建筑与远处桥梁。首轮默认角色相机覆盖起点相机，修正渲染顺序后重新打包、双客户端回归通过。
8. **运行日志：未全部通过。** 最终两客户端 `NullReferenceException` / `LuaException` / `Shader error` 均为 0；服务端 `LuaException` / `Shader error` 为 0，但仍累计 **11,627 条 `NullReferenceException`**，没有可定位的调用堆栈。这是步骤 2 已观察到的未解决问题，不能宣称整体验收通过。调试器缓存权限、Avatar 动画加载及 HDB 连接相关记录仍保留在原始日志中。

最终会话目录：

```text
/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T/hamlet-simulator-52u5ey7f/
```

服务端 PID `76389`，客户端 PID `76433` / `76477`。可分享的脱敏运行证据：[evidence.json](verification/step-3/evidence.json)。截图、几何报告与资产清单均保存在 `docs/verification/step-3/`；验证后已停止最终会话和全部实例。

#### 当前范围与差异

- 本步完成静态资产、赛道碰撞与起点显示；六车尚未实现驾驶、AI、运动同步或比赛流程，步骤 4–8 均未执行。
- 使用 URP 原生材质、天空和静态河面替代 Three.js 专用着色器；光照、阴影、发光及后处理仍存在可见差异，水面动画未实现。
- 平台默认 HUD、Avatar 昵称与调试水印仍显示；比赛 HUD 在步骤 5 实现。

人工确认：**已收到用户“继续执行步骤4”，据此执行步骤 4。**

### 步骤 4：驾驶、同步、跟车相机与喷射

日期：2026-11-24。

#### 变更与产物

- `Lua/Modules/`：共享赛道投影、车辆运动学、120 Hz 输入子步协议、配置及 JSON。速度、车身朝向、运动方向、漂移集气、碰墙、腾空、落地与喷射按源程序移植。
- [RaceInput.lua](../unity/Assets/RacingClone/Lua/Client/RaceInput.lua)：方向键、Shift、Ctrl/空格、W、R、C 与平台移动输入；持续输入和单次按下分开消费，失焦清空输入。
- [RaceServer.lua](../unity/Assets/RacingClone/Lua/Server/RaceServer.lua)：DS 维护车辆、输入序列、集气和库存；验证与缓存命令，按序确认；限制客户端推进时间。
- [RaceClient.lua](../unity/Assets/RacingClone/Lua/Client/RaceClient.lua)：30 Hz 发送未确认输入，接收 20 Hz 官方 `varSync:string` 完整状态；本车预测、确认后重放，远端车辆插值；速度、集气、库存和喷射文字反馈。
- [RaceCamera.lua](../unity/Assets/RacingClone/Lua/Client/RaceCamera.lua)：使用官方相机服务跟车、自动对齐、视角切换和速度/喷射 FOV；通过相机局部偏移及反馈补偿距离限制。隐藏并锁定本地 Avatar，以其位置作为跟车锚点。
- [RacingDrivingBuilder.cs](../unity/Assets/RacingClone/Editor/RacingDrivingBuilder.cs)：主场景脚本、同步对象和驾驶按钮绑定；识别原版两组尾焰，修正继承隐藏状态。
- [RacingDrivingVerification.cs](../unity/Assets/RacingClone/Editor/RacingDrivingVerification.cs)、`Verification/DrivingFixture.lua`：独立喷射与落地验证场景；不挂载到生产场景。

#### 验证结果

1. **原版数值对照：通过。** 10 个用例、6,960 个子步，最大误差 `4.547473508864641e-13`。覆盖加速/松油门/制动倒车、左右漂移、两槽上限、完美/延迟/过期小喷、两种双喷顺序、起步喷、腾空落地、城市加速带与护栏碰撞。对照来自独立执行的原版 JavaScript 和移植 Lua，见 [simulation-comparison.json](verification/step-4/simulation-comparison.json)。
2. **真实键盘驾驶：前轮通过。** `ha4alom8`、`8rybg0tj`、`y0dcn5k7` 会话使用原生按键，观察到加速至约 198 km/h、转向、左漂移、两次集气、库存 `0 → 1 → 2`，随后氮气消耗 `2 → 1`。DS 和操作客户端均输出对应事件，另一辆车保持静止。
3. **喷射运行链：通过，使用受控初始条件。** `3bcxofxs` 场景仅设置初速 35、两份氮气与漂移小喷窗口；实际生产输入协议、DS 运动学和客户端预测均保持原实现。两位玩家分别触发 `startBoost`、`smallBoost(perfect=true)`、`nitro`、`double`；两次消费后库存为 0，第三次请求未产生额外氮气消费。两客户端均记录 `visibleFlames=2`，喷射结束后为 0。
4. **落地喷运行链：通过，使用受控腾空条件。** `u2x1kzqo` 设置初始高度增加 3、竖直速度 3；DS 实际计算出腾空 `0.741667 / 0.725` 秒，分别于 seq `89 / 87` 落地，下一子步触发 `landBoost(perfect=true)`。两客户端均出现对应事件、小喷计时和尾焰。自然跳台触发仍归后续地图回归，不以该用例替代。
5. **三端权威状态：通过。** 七轮共找到 **184 组**相同 `tick / driver / ack` 的 DS 和两客户端日志；`x / z / speed` 在六位小数日志精度下最大差值为 0。该结论针对已接收权威快照；本地预测可能领先数个输入子步，未要求预测值逐帧相等。原日志位置、事件行号和对照值见 [runtime-evidence.json](verification/step-4/runtime-evidence.json)。
6. **相机与画面：前轮通过。** 修复世界偏移被平台当成相机局部偏移的问题，并补偿相机服务的距离限制。静止跟车距离约 8.2、高度约 3；驾驶时距离约 8–10，车保持在画面中央。截图来自 `y0dcn5k7` 相机修复回归：[驾驶画面](verification/step-4/client-1-driving.jpg)，并非最后一次打包的新截图。
7. **最终生产场景与打包：通过。** 主场景构建时间 **18:42:26**；缓存 settings/catalog 有效。Editor 未在编译或刷新，Console 计数为 0；主场景测试脚本数为 0，生产输入启用，六车共 12 组尾焰绑定。`bdqh8i2q` 新启动 DS 和两客户端，主场景加载、两玩家就绪与权威快照均通过。见 [build-evidence.json](verification/step-4/build-evidence.json)。
8. **最终桌面输入重测：未通过。** 本轮 Computer Use 对 Unity 和两调试器均只返回应用菜单，没有窗口画面；原生油门、右漂移及制动操作后，日志持续显示输入 false、速度 0，不能将操作尝试记为通过。最终右漂移/制动真实按键、三镜头切换和屏幕按钮操作仍待窗口恢复后重测。左右漂移及制动倒车的数值对照已通过，但不替代真实 UI 验证；移动端触摸及布局完整验证归步骤 7。
9. **运行异常：已定位，未修复。** 增加完整异常堆栈后，既有 DS 空引用来自 `NetworkActorTransformDataComponent.UpdatePosition(float) → LateUpdate()`，属于调试器 SDK 的角色同步组件。尚未确定其内部具体空对象，未改动内部 DLL 或未公开组件；不能宣称运行无错误。七轮日志未出现 `LuaException` 标记；SDK AvatarData、资源 GUID 与角色资源警告仍需后续处理。

关键会话：

| 会话后缀 | 用途 |
| --- | --- |
| `ha4alom8` | 真实加速与跨端同步 |
| `8rybg0tj` | 真实漂移与两槽集气 |
| `bjf3hmg5` | SDK 空引用完整堆栈 |
| `y0dcn5k7` | 相机修复、真实漂移与氮气 |
| `3bcxofxs` | 受控起步喷、完美小喷、双喷、库存与尾焰 |
| `u2x1kzqo` | 受控腾空、完美落地喷与尾焰 |
| `bdqh8i2q` | 最终生产包加载与三端快照；桌面输入重测未通过 |

完整临时路径记录在脱敏证据中；原始日志可能含登录信息，仅保留在本机。验证结束后已停止本任务所有调试器实例，Editor 保持生产 `RacingClone.unity` 场景。

人工确认：**已收到用户“继续执行步骤 5”。步骤 4 保留上述未通过项，继续步骤 5。**

### 步骤 5：比赛流程实施设计

本节落实已确认方案，不增加新的通用规则来源。

1. **比赛状态**：大厅 → 3 秒倒计时 → 比赛 → 冲线等待 → 结果；房主可暂停/继续、重开或回大厅。DS 独立推进统一 120 Hz 时钟，暂停期间冻结时钟、AI 和车辆。
2. **席位与设置**：固定六席，在线玩家占位，其余由 AI 补齐。第二位玩家替换一个 AI；离房席位恢复 AI。房主设置圈数 1/2/3/5 与新手/熟练/车神难度，个人选择八种车辆配色。当前可开始的赛道/模式为 11城竞速，其他地图和道具模式按后续步骤接入。
3. **AI 与进度**：移植原版赛道曲率预判、横向跟线、漂移表现、自动氮气和追赶补偿；进度记录独立于车辆复位。起跑过线不提前计圈，完成半圈后正向冲线才记录圈时；倒车过线只撤回进度，不能重复获圈。
4. **输入与同步**：保留驾驶预测和完整状态同步，加入比赛阶段、统一时间、六席名次、圈时、结果与请求确认。阶段切换使用递增版本清理旧输入；控制请求携带序号，重发直到快照确认，避免重复开始或重开。
5. **界面**：UGUI 大厅、比赛 HUD、暂停和结果面板；按 DS 快照显示房主、玩家/AI、圈数、名次、计时、速度、集气、氮气、最佳圈时与结果。Enter/开始按钮、Esc/暂停按钮和面板按钮使用同一请求入口。
6. **验证**：先对纯逻辑执行 AI 对照、六席补位、计圈/倒车/复位、暂停与版本切换测试，再构建并运行 DS 双客户端，核对比赛阶段、时钟、圈数、名次和结果。真实窗口操作与自动输入验证分别记录。

### 步骤 5：比赛流程、六席 AI 与 HUD

日期：2026-11-24。本段为步骤 5 的历史验证记录。

#### 变更与产物

- [RaceSession.lua](../unity/Assets/RacingClone/Lua/Modules/RaceSession.lua)：DS 权威大厅、六席补位、房主配置、倒计时、暂停/继续、重开/回大厅、圈数与名次、圈时及统一结算。控制请求按序号确认；阶段版本隔离旧驾驶输入。
- [RaceAI.lua](../unity/Assets/RacingClone/Lua/Modules/RaceAI.lua)、[RaceCollision.lua](../unity/Assets/RacingClone/Lua/Modules/RaceCollision.lua)：原版三档 AI 的曲率预判、横向弹簧、自动氮气、漂移表现、追赶补偿及车间接触响应。
- [RaceServer.lua](../unity/Assets/RacingClone/Lua/Server/RaceServer.lua)、[RaceClient.lua](../unity/Assets/RacingClone/Lua/Client/RaceClient.lua)：版本 2 比赛快照、控制请求重发和确认、暂停/重开输入清理；保留 120 Hz 运动学、30 Hz 输入和 20 Hz 快照。
- [RaceHUD.lua](../unity/Assets/RacingClone/Lua/Client/RaceHUD.lua)、[RaceMenuButton.lua](../unity/Assets/RacingClone/Lua/Client/RaceMenuButton.lua)：大厅六席与选项高亮、房主按钮权限、3 秒倒计时、圈数/名次/计时、最佳单圈、六车小地图、速度/集气/氮气、暂停与结果面板。
- [RacingMatchBuilder.cs](../unity/Assets/RacingClone/Editor/RacingMatchBuilder.cs)：正式场景六席各预置八种配色；重复构建只保留一套大厅与驾驶画布。原生 `Button.onClick` 绑定 `DouyinScript.CallMethod("Click")`；驾驶按钮通过序列化指针事件绑定 Press/Release。
- [RacingMatchVerification.cs](../unity/Assets/RacingClone/Editor/RacingMatchVerification.cs)、`Verification/MatchFixture.lua`：独立验证场景，以普通驾驶输入和控制 RPC 自然绕圈，未直接写入完成标记、圈数或结果。

#### 已完成验证

1. **逻辑与完整比赛：通过。** [logic.json](../step-5-verification/logic.json) 含 84 项断言；覆盖单人 + 5 AI、双人 + 4 AI、房主权限、配色、1/2/3/5 圈、离房接替、晚加入进度、倒车过线与复位防刷圈、起步喷窗口、暂停冻结、恢复单步、旧版本输入拒绝、控制幂等、重开与回大厅、车辆接触和高差隔离。七场模拟均自然进入结果；新手一圈中玩家自然完赛，其他场次按首车冲线后 10 秒截止规则结算，未完成者保留未完成状态。
2. **AI 原版对照：通过。** [ai-comparison.json](../step-5-verification/ai-comparison.json) 对三个技能系数分别运行 8,400 子步，共 **25,200 子步**；逐步比对连续距离、横向位置/速度、车辆位置/速度/方向、喷射、腾空和漂移。最大误差 **5.684341886080802e-14**。
3. **DS 双客户端完整流程：通过，驾驶输入自动生成。** 首轮 `_71r9mhq`：大厅 → 倒计时 → 比赛 → 暂停 3 秒 → 继续 → 自然结果 → 重开 → 暂停 → 回大厅；两玩家自然完赛，三端结果时间 **63.216666666664 秒**。第二轮 `1_sbrbdj` 重跑新增 HUD 和碰撞后，同一流程通过；三端结果时间 **63.199999999997 秒**。
4. **同帧权威状态与暂停：通过。** [runtime-second.json](../step-5-verification/runtime-second.json) 比对 **39 组**三端相同 tick 的完整 JSON，比赛设置、六车状态、圈数、名次、圈时、结果均相等；多个暂停快照的时钟 **5.225 秒**和六车状态完全冻结。恢复后按固定子步推进，未补算暂停的墙钟时间。
5. **界面显示：通过。** [比赛 HUD](../step-5-verification/race-hud.jpg) 实际显示六车小地图、圈数/名次/时间、速度、集气条与驾驶按钮；中文文字可见。暂停截图 [pause-first.png](../step-5-verification/pause-first.png) 来自首轮。平台默认按钮、昵称与调试水印仍显示，完整移动端布局回归归步骤 7。
6. **正式场景真实键盘：通过。** `s4245zae` 使用生产 `RaceInput.lua`，Enter 开始倒计时，Esc 在比赛 **13.6083 秒**时暂停；已保存真实窗口截图。该场景没有自动驾驶或比赛 fixture。
7. **正式场景真实按钮：通过。** 会话 `u3bi4ila` 没有 fixture。实际鼠标操作选一圈、新手和蓝色赛车，并执行开始、暂停、继续、结果页重开、再次暂停、返回大厅；八种控制均有 `MENU_CLICK` 与服务端 `CONTROL accepted=true`。原生鼠标位置在 **1118 × 580** 渲染范围内。此前窗口外坐标问题通过核实新窗口、定位鼠标和系统鼠标事件解决，未修改 SDK。证据：[runtime-ui.json](../step-5-verification/runtime-ui.json)、[大厅选择](../step-5-verification/lobby-selected.png)、[暂停](../step-5-verification/pause-ui.png)、[结果](../step-5-verification/result-ui.png)、[回大厅](../step-5-verification/returned-lobby.png)。
8. **真实操作的同步与结果：通过。** 本轮 **179 组**三端相同 tick 的完整 JSON 一致。两次暂停分别在 **32.725 秒 / 42.3 秒**，服务端 **63 / 39 个**快照的时钟和六车状态冻结。四个 AI 自然完赛，首车 **55.0417 秒**，统一在 **65.0417 秒**结算；两个玩家未驾驶完赛，结果保留未完成。玩家自然完赛仍以前两轮自动驾驶证据为准。
9. **单人 + 5 AI：实际入房通过，完整赛程尚未通过。** 修正本地启动器的 DS 至少两玩家限制，允许 DS + 一客户端；SharedMode 仍要求两客户端，单人/双人 DS 和 SharedMode 参数校验均通过。正式构建会话 `5_de9go0` 两端均为一玩家 + 五 AI，**5 组**大厅快照完全一致，两端 `LuaException` 均为 **0**。macOS 会话显示 `CGSSessionScreenIsLocked=1`、前台为 `com.apple.loginwindow`，截图与真实按钮无法操作，因此单人完整比赛待解锁后验证。详见 [runtime-solo-locked.json](../step-5-verification/runtime-solo-locked.json)。
10. **断网后的角色生命周期：修复并完成代码回归，平台断网回归待完成。** 首次单人会话 `qgt22i9q` 出现 SDK 网络断开 **-103**；`RaceClient.LateUpdate` 随后写入失效角色位置产生六次 Lua 异常，见 [中断记录](../step-5-verification/runtime-solo-interrupted.json)。已在 LateUpdate 与退出恢复中校验网络及当前角色；**17 个 Lua 文件**语法检查、**6 项**有效/失效角色生命周期用例通过，见 [client-lifecycle.json](../step-5-verification/client-lifecycle.json)。修复后单人大厅无 Lua 异常，但未将其记作完整断网回归通过。
11. **最终保存与正式打包：通过。** 最新缓存时间 **21:58:16.562085**；对应上述角色保护与诊断清理后的源码。MCP 打包响应超时，但缓存实际更新、Editor 日志恢复目标场景，随后 MCP 返回 `compiling=false`、fixture 数 **0**。生产输入启用，开始按钮保留一个 `CallMethod` 持久化监听；已移除临时 POINTER 和 START_BUTTON 监听诊断。最终包 DS 单客户端 dry-run 与入房成功，见 [build-final.json](../step-5-verification/build-final.json)。
12. **平台保活与 SDK 异常：保留。** 强制关闭第二客户端属于断线，保活期间玩家名单不立即移除，不能将其当作正常离房补位失败；平台依据见 [断线重连机制](../.trae/skills/hamlet-skill/references/Manual/Ⅳ.%20多人游戏与网络(Multiplayer)/网络基础/断线重连机制.md)。正常离房补位已通过逻辑断言，实际正式离房通知后的补位待后续网络回归。第三轮三端 Lua 异常为 **0**，DS 仍有 `NetworkActorTransformDataComponent` 既有空引用；未修改内部 SDK。全部本轮调试实例已停止。

原始日志保存在系统临时目录；可分享证据保存在工作区根目录 `step-5-verification/`。截图与运行报告分别注明来自哪轮，不把自动驾驶验证写成真实驾驶操作。

后续操作已由用户最新授权更新为：**解锁 Mac 后继续步骤 6，完成本步验证后停在人工验收点。**

## 6. 道具模式实施设计

沿用已确认的克隆方案，以原版 `ta`（32607–32847）及 `hitRacer` 为行为依据。

1. `RaceItems` 作为纯 Lua 模块管理 20 个箱子、名次权重、两槽、香蕉、导弹与命中。箱子位于赛道 10%/35%/60%/85%，每组五箱；刷新 2.5 秒。香蕉自免疫 1.2 秒、寿命 90 秒，导弹追踪前一名、寿命 6 秒。护盾持续 7 秒、消耗一次挡击；磁铁持续 3 秒，仅加速使用者并显示目标连线。
2. `RaceSession` 在服务端依序消费玩家输入、更新车辆与碰撞、排名、道具、AI 道具决策。使用与换位纳入已有序号和 epoch 去重；模式只能由房主在大厅选择。重开和返回大厅清理库存、投射物及效果。
3. 输入和快照升级为版本 3，快照包含两槽、箱子冷却、投射物与近期效果。客户端继续预测驾驶，库存和命中以确认快照为准，预测回放不消费道具。竞速模式保留现有氮气库存与漂移集气。
4. 大厅开放道具模式，HUD 显示两槽、使用/换位触摸入口与锁定提示；Unity 原生网格表现箱子、香蕉、导弹、护盾和磁铁。表现对象不参与物理碰撞。
5. 验证覆盖原版数值、多车抢箱、刷新、满槽、无目标、单命中、护盾、AI、网络重传、暂停及重开；回归竞速。随后编译打包，运行 DS 双客户端，观察真实操作及跨端一致性，最终恢复无验证夹具的生产场景。

### 后续验证记录格式

每步记录：步骤号、变更文件/场景、构建完成时间、启动参数、实际会话目录、操作与预期、实测结果、截图/日志证据、已知差异及人工确认状态。

### 步骤 6：道具模式验证完成

日期：2026-11-25。实现及本步回归完成，停在人工验收点。

1. **实现**：新增服务端 `RaceItems.lua` 与原生网格 `RacingItemBuilder.cs`；Session、Protocol、AI、输入、HUD、客户端快照与表现完成道具集成。生产道具箱 20 个，两槽、五道具、名次权重、箱子刷新、命中与 AI 决策按原版实现；表现对象没有 Collider。指定条件使用独立 `RacingItems_Verification.unity`，生产场景无夹具。
2. **原版与纯逻辑**：17 组情形、301,724 个数值比较，最大误差 `5.684341886080802e-14`；21 项房间与自然道具赛检查通过，单/双人使用覆盖五道具。竞速 7 场和 AI 原版 25,200 步回归通过。
3. **真实输入和跨端**：正式道具场景拾取磁铁、触摸使用和连线通过；夹具真实 Alt/触摸换位、触摸氮气、Ctrl 护盾，以及导弹命中/护盾拦截、磁铁有/无目标、香蕉对手命中和自免疫均通过。夹具 3,860 个共同 tick 的完整三端 JSON 一致。
4. **自然赛程**：正常输入和 AI 完成双人四 AI 的一圈道具赛，六车全部完成，结果计时 **63.1 秒**。暂停计时冻结、恢复、结果、重开、回大厅及道具清理通过。
5. **输入回归修复**：实测长按 Esc 曾在阶段切换后重复暂停/恢复；`RaceInput.Clear()` 改为保留已采样按键。Esc/Alt/Ctrl/Enter 边缘检查通过；最终正式包竞速场景中，长按 Esc 三秒暂停与恢复各一次，暂停计时固定 **7.3 秒**。
6. **最终正式构建与运行**：缓存 UTC 时间 **2026-11-25T04:19:20.5849502Z**；活动场景 `RacingClone.unity`，`compiling=false`，夹具 0，生产输入启用。DS 双客户端最终 1,717 个共同 tick 的完整 JSON 一致，三端 LuaException 为 0。所有本轮调试实例已停止。
7. **实际 SDK 差异**：DS 角色同步空引用仍存在；夹具客户端 2 曾发生一次 SDK `LogToEditorConsole` 的 `StringBuilder` 越界，被记录为两条 LuaException，堆栈与计数单列，未修复。最终正式回归未出现该日志越界。

启动条件、构建时间、会话目录、代码与证据定位以[步骤 6 验证记录](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/README.md)为准；功能通过不表示上述 SDK 异常已解决。
