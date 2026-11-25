# 步骤 7 验证记录

日期：2026-11-25。地图、音频、设置和布局实现及功能回归完成，正式包已生成；最终正式 DS 启动因沙箱权限中断，保留为待补验。

## 测试条件

Unity 2021.3.14f1 / URP 12.1.8，Lua、DedicatedServer、新网络、Avatar、关闭平台数据存储。DS 与两个客户端分别使用独立调试器副本；客户端昵称为“赛车验证1”“赛车验证2”，重启沿用相同身份。

地图回归使用隔离验证场景和普通驾驶输入，不直接写入车辆权威位置。手动验证场景 `RacingPresentation_Manual.unity` 转发真实 `RaceInput`，只增加音频、输入和渲染采样。正式场景已恢复为 `RacingClone.unity`，夹具数为 0。

## 验证结果

- [四图纯逻辑回归](maps-logic.json)：40 项通过。双人及四 AI 在四图全部完赛；轨道投影、雪地上下层隔离、埃及自然腾空及落地喷通过。
- [真实 DS 四图回归](runtime-maps-audio.json)：27 项通过。四图六车全部完赛，DS 与两客户端结果一致；非房主地图请求被拒绝，两客户端音频输出非零，三档画质切换通过。
- [实机交互与重启记录](manual-runtime.json)：记录真实设置按钮、触控油门/左右/漂移与释放、开赛和重开、音乐开关及切歌。漂移联动使用键盘油门和转向配合鼠标长按屏幕漂移按钮；本轮没有手机真机多点触摸测试。
- 音乐关闭后大厅 AudioListener 连续采样为零，恢复及切歌后输出非零。动态引擎音高、风声音量随驾驶变化；倒计时、发车、圈数、碰撞等音频事件有运行日志。采样峰值小于 1，未观察到采样削波。
- 同身份重启保留画质、镜头、音乐开关和曲目，两客户端使用各自的设置。已修复 `music1.0` 音源名称错误和初次地图加载覆盖保存曲目；第三镜头名称为“近景”。
- 平台实际相机为 `TPCameraAvatar`。采样确认 `RacingQuality2` / `RacingQuality0` 切换、HDR 相机和主光源阴影参数；精致档开启后处理 Volume，流畅和均衡档关闭。画面对照包含分辨率、抗锯齿和阴影差别，未单独隔离泛光贡献。
- 官方 `UISystem` 初始化后隐藏，退出时恢复。最终竖屏截图不再出现默认摇杆和社交控件。
- [正式场景绑定](client-scene.json)：0 个验证夹具、26 个音源、三档渲染资产与个人设置绑定齐全。
- [语法校验](lua-syntax.json)：32 份 Lua 脚本通过。[最终构建](build-final.json)：编译完成，着色器错误为 0，settings/catalog 有效，缓存时间 `2026-11-25T06:58:08.6246988Z`。

## 画面证据

- [最终竖屏大厅](portrait-lobby-final.png)
- [最终竖屏设置](portrait-settings-final.png)
- [最终竖屏驾驶](portrait-driving-final.png)
- [精致画质](quality-high-final.png) / [流畅画质](quality-low-final.png)
- [油门释放后的画面](touch-throttle-release.png) / [漂移统计结果](touch-drift-release.png)
- [横屏驾驶历史截图](landscape-driving.png)：来自系统控件隐藏修正之前，默认控件遮挡在最终竖屏截图中已消除。

其他未带 `final` 的截图保留修复前后的历史过程，不代表正式包最终画面。

## 会话与已知 SDK 差异

原始 Player 日志保留在本机临时目录，未复制账号或设备数据到证据文件。

| 会话 | 用途 | 结果 |
| --- | --- | --- |
| `kocn5v31` | DS 四图、画质及音频回归 | 27 项通过 |
| `y0b7maki` | 第一轮真实设置操作 | 复现切歌音源查找错误；音乐静音有采样证据 |
| `6g5wrwn8` | 切歌修复、画质、油门 | 切歌播放和油门长按/释放通过 |
| `2skxeyew` | 设置保留、控件隐藏、方向及漂移 | 功能通过；SDK 日志器越界单列保留 |
| `dhi2n_v1` | 最终渲染及设置重启 | 没有玩法 Lua 错误，阴影参数及渲染资产切换已采样 |
| `u_wi55zx` | 正式无夹具启动 | 服务端被沙箱写入权限中断，客户端未启动 |

`2skxeyew` 的 SDK 异常来自 `Hamlet.GameLaunch.Log.LogToEditorConsole → StringBuilder.ToString`，发生在网络发送日志链中，被包装为 LuaException。这与步骤 6 的同类异常一致；汇总中与玩法 Lua 错误分开记录。历史 DS 空引用计数也保留，未声称解决 SDK 异常。

## 待补验与恢复入口

正式启动日志明确记录：

```text
CreateDirectory '/Users/bytedance/Library/Application Support/local.racingclone.debugger.server' failed: Permission denied
```

待文件系统权限恢复后：

1. 按 [hamlet-debugging](../.trae/skills/hamlet-debugging/SKILL.md) 准备启动认证，继续使用 `tools/launch_racing_driving.py` 启动正式 `RacingClone.unity`。
2. 确认 DS 就绪、两个客户端加载与入房，实际开始比赛并保存最终画面；日志中不应出现验证夹具。
3. 补充 `build-final.json` 与本记录的正式启动结果，停止调试器，进入步骤 7 人工验收。

本轮已停止调试实例，Unity 保持打开正式场景。步骤 8 未执行。
