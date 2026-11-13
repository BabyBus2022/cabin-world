# 给机器人软件的 1.1 接入提示

小屋世界提供身体、房间、物品和本地游戏规则，不提供模型、人设、QQ登录或记忆模块。

1. 先用 `cabin_status` 看本住户当前状态。工具参数 `actor` 使用接入时登记的稳定编号，不能填昵称、QQ昵称，也不能固定认定另一位住户是谁。同名机器人也必须使用不同编号。
2. 身边有什么用 `cabin_look`。想找其他房间的功能，用 `cabin_catalog` 搜关键词或房间；没有结果时清空关键词分页，按返回的 `nextOffset` 继续。找到 `object`、`use` 后调用 `cabin_use`。不要仅因当前房间没有列出就断言功能不存在。
3. 所有家具共用通用工具，不要把每件家具变成一个独立模型工具，也不必每轮注入整份 catalog。装饰品没有 uses，不假装有交互。
4. 电玩城一位机器人对 NPC：贪吃蛇 `arcade_snake/play`，象棋 `arcade_xiangqi/play`，五子棋 `arcade_xiangqi/play_gomoku`，都使用 `mode:"npc"`。旧 `solo` 兼容；扫雷与方块用 `solo`。
5. 两位机器人：第一位 `mode:"duo"` 开桌，另一位以自己的 actor 对同一物件 `mode:"join"` 入座。`duo` 不会自动补 NPC。客人是谁由已接入编号决定，不限制名字。家中棋盘需要主人邀请与两位真实住户。
6. `running` 只表示任务进行中。用 `cabin_task` 按原 taskId 查回执；`done` 才能报告完成，`failed` 要如实说明。不因等待重复开桌、不把历史结果说成刚赢。每一步游戏由本地规则推进，不调用模型逐手下棋。
7. 餐厅先 `cabin_restaurant(action="menu")`，拿到 dish 编号后 order/cook/eat。拿到菜不等于吃完。食后 like/dislike/neutral 需要自己的主观 feeling，拒绝评价没吃过的菜；宿主可订阅 `food_preference` 事件存入自己已有的记忆。
8. 别替其他机器人决定行动。工具允许传 actor 是宿主调度接口；对外适配器应绑定每个机器人自己的 actor。查看玩家全体住户用 `cabin_residents`，不能把同名显示标签当作编号。

9. 沙发、游泳等目录标记的休闲体验可传 `durationSeconds`（整数1–3600），想多待一会由你选择。普通家具调用立即返回任务号，不必等20秒。想正常提前收尾用 `cabin_stop(action="finish")`，用户叫停或改变计划用 `action="stop"`；收尾后查真实回执，再描述完成。已经提交的购买/吃饭不能撤销。

10. **1.1 更新和可选模块。** 用户问到更新、新功能，或者想要回旧样子时：
    - 先调用 `cabin_update_plan`，把每个模块用大白话讲给用户：改了什么（summary、changes）、看起来会不会不一样（looksDifferent）、会不会动到存档（touches）、现在是开还是关。
    - `askUser` 为 true 的模块（新电玩城、家具转向与新家具图、每天 50 零花钱）会改变外观或玩法，从 1.0 升级时默认是关的。一定要先问用户想不想要，不要替用户决定。
    - 用户同意后才调用 `cabin_update_apply`，只改用户说了的模块。没有返回 `ok` 之前，不要说已经改好。
    - 改完提醒用户：要完全关闭游戏再用 start.cmd 打开，才会生效。用户说改回去，就用 `cabin_update_undo`。
    - 模块关掉时，对应的东西在目录里也会消失（例如关掉五子棋，棋桌就没有 `play_gomoku`）。以 `cabin_look` / `cabin_catalog` 实际返回的为准。

模型仍可能不主动选择某个活动。这份接口保证目录可检索、可完整翻页与真实执行回执，不保证模型的每一次自主决策。
