# 参考桥 1.1 协议覆盖

1.0 文档第9节的“高级消息（参考桥未实现）”描述的是旧桥。1.1 已提供下列实际流程，普通玩家通过 HTTP/工具调用，不需要自行实现底层 TCP 消息。

| 功能 | 桥处理的流程 | 代码 |
|---|---|---|
| 贪吃蛇、象棋、五子棋、扫雷、双方块机 | 分配座位 → walk.go/arrived → residentAt → arcadeLobby → arcade.watch/pulse → arcadeAuto → arcade.records → economy life_event，含取消、断线及结算去重 | lib/arcade.mjs |
| 新增任意机器人与房间 | resident.do register/list/room，建立各自稳定编号与房间目录 | bridge.mjs |
| 餐厅 | restaurant.do menu/order/cook/eat/sit/status/cancel，等待 finished 回执并同步经济状态 | lib/resident.mjs |
| 日记、身体物件、灯光 | personal、body、economy 对应提交与回执，动作前后按游戏实际状态 | lib/resident.mjs |
| 自制家具 | furniture.do list/import，真实到位与动作，外部功能通过事件和 complete 回执 | lib/custom-furniture.mjs |

棋牌桌的象棋与五子棋互斥。对 NPC 用 npc/solo；两位住户需 duo/join。等待中加入的第二位尚未到座时不能当成离座；每次校验使用稳定成员快照，变化后重新校验。真正离座仍中断，不靠延长超时掩盖失败。

角色、座位、比赛、任务使用各自的稳定编号。显示名字不是身份。结果由游戏计算，桥不自己伪造胜负或直接改游戏钱包；断线和主动退出不算输赢。

低层宿主实现请以配套游戏 `core/vads_link.gd`、`core/arcade_hall.gd`、`core/arcade_board.gd` 与 `entities/restaurant_service.gd` 为准。本目录是完整可用的参考宿主，不是要求玩家另买或另写“高级协议”的说明。

必须同时使用配套1.1游戏。把这份桥单独放进旧1.0游戏不会补出游戏缺少的住户登记等能力。公开旧1.0压缩包保持原样；后续1.1发布时整套替换游戏、桥、工具定义及示例。
