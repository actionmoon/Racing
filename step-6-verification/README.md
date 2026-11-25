# 步骤 6 验证记录

状态：步骤 6 的实现、功能与同步验证完成，等待人工验收。正式场景已恢复并打包，所有调试实例已停止；步骤 7 未执行。

- **原版对照通过**：17 组情形、301,724 个数值比较，最大误差 `5.684341886080802e-14`。覆盖名次权重、20 箱刷新、多车抢箱、满槽、两槽换位、五道具、导弹追踪、香蕉自免疫和护盾。21 项房间检查包含重传/epoch、房主权限、预测不消费库存、暂停、重开、离房转 AI，以及单人/双人自然道具比赛和五道具使用。[逻辑证据](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/items-comparison.json)
- **竞速回归通过**：7 组完整比赛，AI 原版对照 25,200 步。[比赛证据](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/race-regression.json)、[AI 证据](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/ai-regression.json)
- **正式道具场景真实操作通过**：选择道具模式、一圈、新手；键盘拾取磁铁、触摸使用并显示连线。首轮 69 个共同 tick 的完整三端 JSON 一致，三端 LuaException 为 0。[首轮运行](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/runtime-production-first.json)、[磁铁画面](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/magnet-used.png)
- **指定情形通过**：独立夹具只设置车辆和初始库存；使用通过生产输入和 RPC。真实 Alt 换位、触摸换位、触摸使用氮气、Ctrl 使用护盾均收到服务端确认。导弹命中、护盾拦截、磁铁有/无目标、香蕉命中对手、1.2 秒自免疫及其后自命中均通过。3,860 个共同 tick 的完整三端 JSON 一致。[夹具运行与断言](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/runtime-fixture.json)、[两槽](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/two-slots.png)、[护盾](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/shield-used.png)
- **自然道具赛程通过**：夹具恢复正常车辆与 AI，双人及四 AI 均自然完成一圈，最终计时 **63.1 秒**。暂停恢复、结果、重开、返回大厅和道具清理均通过。控制标记仅由房主夹具输出；另一客户端的状态由共同 tick 比较确认。
- **长按输入修复并回归**：阶段切换清理输入时保留已采样按键，避免长按 Esc 反复暂停/恢复。Esc、Alt、Ctrl、Enter 的边缘回归通过；最终正式包竞速场景中，真实长按 Esc 三秒，暂停/恢复各一次，暂停计时固定为 **7.3 秒**。[真实输入回归](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/input-runtime-regression.json)、[最终运行](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/runtime-production-final.json)、[暂停画面](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/production-pause.png)
- **最终生产构建通过**：`Assets/Scenes/RacingClone.unity`，编译完成，验证夹具 0，生产输入启用，20 箱，道具表现 Collider 0。缓存 UTC 时间 **2026-11-25T04:19:20.5849502Z**。最终运行 1,717 个共同 tick 的完整三端 JSON 一致，三端 LuaException 为 0。[最终构建](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/build-final.json)

运行条件统一为 Unity 2021.3.14f1、URP、Lua、DedicatedServer、新网络新房间、存储关闭、Avatar、服务端无窗口，客户端“赛车验证1”“赛车验证2”。夹具缓存 UTC 时间为 **2026-11-25T03:50:01.7363497Z**。夹具会话为 `/var/folders/t5/cx_l90z95vx72xgc8ps0j8n80000gn/T/hamlet-simulator-vgow9m6l`；最终生产会话为同目录下 `hamlet-simulator-fh6tk693`。原始日志留在这些临时目录，交付 JSON 已脱敏。

实际保留的 SDK 问题：各轮 DS 仍有 `NetworkActorTransformDataComponent` 空引用。夹具客户端 2 另有一次 `Hamlet.GameLaunch.Log.LogToEditorConsole` 的 `StringBuilder` 越界，经网络 `FireServer` 包装为两条 LuaException 记录；其后比赛与同步正常，最终正式回归未出现该异常。[堆栈证据](computer:///Users/bytedance/Documents/aireverse/Racing/step-6-verification/sdk-logger-exception.txt)。这些异常未修复，运行 JSON 分别统计，不归入道具断言通过范围。
