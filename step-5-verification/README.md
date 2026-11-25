# 步骤 5 验证证据

生产场景：`unity/Assets/Scenes/RacingClone.unity`。当前功能、验证状态和剩余工作见 [计划](../docs/plan.md#步骤-5比赛流程六席-ai-与-hud)。

- [逻辑报告](logic.json)：84 项断言，七场自然比赛，覆盖三档难度、四种圈数、单人/双人席位、计圈防刷、起步喷和暂停恢复。
- [AI 对照](ai-comparison.json)：独立执行原版 JavaScript 与 Lua，共 25,200 个子步。
- [第二轮 DS 运行证据](runtime-second.json)：39 组三端完整快照相等，两玩家自然完赛，暂停冻结、重开与回大厅。
- [首轮 DS 运行证据](runtime-first.json)：首轮完整流程，19 组三端快照相等。
- [比赛 HUD](race-hud.jpg)：第二轮实际窗口截图，含小地图和集气条。
- [暂停画面](pause-first.png)：首轮实际窗口截图。
- [真实按钮运行](runtime-ui.json)：正式场景、无 fixture；选圈、难度、配色、开始、暂停、继续、重开和回大厅均由服务端接受，179 组三端快照一致。
- [大厅选择](lobby-selected.png)、[真实暂停](pause-ui.png)、[真实结果](result-ui.png)、[返回大厅](returned-lobby.png)：第三轮实际窗口截图，已裁去房间标识。
- [最终构建](build-final.json)：正式场景构建时间、缓存和脚本哈希，无 fixture。
- [单人中断记录](runtime-solo-interrupted.json)：SDK 网络断开 -103，未完成比赛；客户端角色失效后写入位置产生六次 Lua 异常，后续已增加网络与当前角色校验。
- [单人大厅与锁屏记录](runtime-solo-locked.json)：最终包一玩家 + 五 AI、5 组两端快照一致、两端 Lua 异常为 0；锁屏阻止完整比赛回归。
- [角色生命周期检查](client-lifecycle.json)：17 份 Lua 语法、6 项断网/角色失效/正常恢复用例通过。

前两轮 DS 完整比赛使用独立场景的自动输入，通过同一驾驶协议自然绕圈；未直接设置完成标记。正式场景 Enter/Esc 与第三轮屏幕按钮已完成真实操作。第三轮玩家未驾驶完赛，四个 AI 自然完赛，统一结果时间 65.0417 秒。SDK 角色同步空引用继续保留，不将业务验证通过写成运行无异常。

关闭进程属于断线，平台保活期间仍保留玩家名单；应以平台正式离房通知后的补位为准。单人 DS 启动器已允许一个客户端，SharedMode 仍要求至少两个。

最终缓存时间为 2026-11-24 21:58:16.562085。本轮调试实例已停止。解锁 macOS 后继续步骤 5 的单人完整比赛与最终桌面回归，再进入人工验收；步骤 6 尚未执行。

复现工具：

1. `python3 tools/verify_racing_session.py`，输出默认写入 `/tmp/racing-step5-logic.json`。
2. `python3 tools/verify_racing_ai.py`，输出写入 `/tmp/racing-step5-ai.json`。
3. 使用 Unity MCP 调用 `RacingMatchVerification.BuildFixture()`，按项目调试流程启动 DS + 两客户端。
4. `python3 tools/collect_racing_match_evidence.py <会话路径> --output /tmp/racing-step5-runtime.json`。
5. 正式场景的真实按钮日志：`python3 tools/collect_racing_ui_evidence.py <会话路径> --output /tmp/racing-step5-ui.json`；单人会话追加 `--solo`。
6. 鼠标工具：`swiftc tools/racing_mouse_click.swift -o /tmp/racing-mouse-click`；传入当前客户端 PID、窗口 ID、截图内相对 x/y，最后可追加按住秒数。

原始日志含账号环境信息，保留在本机临时目录；这里的结果已把玩家身份替换为 `player-1` / `player-2`。
