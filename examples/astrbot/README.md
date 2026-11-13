# AstrBot 插件示例

1. 先在小屋世界文件夹里双击 `start.cmd`，确认窗口显示“准备好了”。
2. 把本文件夹复制到 AstrBot 的插件目录，命名为 `astrbot_plugin_cabinworld`（通常是 `AstrBot\data\plugins\`）。
3. 在 AstrBot 管理面板里打开这个插件的配置，把 `bridge_json` 填成小屋世界 `data\bridge.json` 的完整路径，保存并重载插件。
   多机器人时，每个机器人的适配配置用自己的 `resident_id`（登记编号，不是昵称）；共享同一个桥，不启动多个宿主争抢游戏。框架若共用同一个插件实例，需要按框架的机器人身份选取对应配置，不能让所有会话都落到默认编号。
4. 把小屋世界的 `docs\AI-MANUAL.md` 内容加进角色的人设或知识库。
5. 对机器人说“去公园荡秋千吧”，看游戏里的角色是不是走过去了。

说明：

- 插件只做转发：AstrBot 的模型决定调用哪个工具，插件把它发给本机的小屋世界桥，再把游戏的真实结果交还给模型。
- 使用本目录的1.1示例，不能继续保留1.0的 main.py。新增 cabin_catalog 搜索/分页、cabin_task 回执、餐厅和住户查询/邀请。cabin_use 支持 mode=npc/solo/duo/join 与日记正文。
- 本地验证覆盖参数转发、身份绑定、Python HTTP客户端及实际游戏桥；没有启动真实 AstrBot，因此第三方插件加载与不同版本UI不在本地实测范围内。
- 这是示例代码，按 AstrBot 公开的插件接口（`Star`、`@register`、`@filter.llm_tool`）编写，**没有在所有 AstrBot 版本上实测**。如果你的版本接口不同，`cabin_client.py` 部分不用改，只改注册方式。
- 记忆：插件不存任何东西。想让角色记得自己做过什么，用 AstrBot 自己的记忆功能记下工具返回的 `happened`。
