# 小屋世界本地协议（游戏 ↔ 宿主）

**大多数人不需要读这份文件**：用 `bridge/` 就够了。只有想让自己的机器人软件直接当游戏的“宿主”（不经过桥），或者想扩展桥的时候才需要。

*Local protocol between the game and its host. You only need this if you replace the bridge. Times are milliseconds since 1970 unless noted.*

## 0. 分工

| 谁 | 负责 |
|---|---|
| 游戏 `CabinWorld.exe` | 身体、走路与寻路、座位、钱包、背包、商品价格、感受与生活规则、公园结果、存档、画面 |
| 宿主（桥或你的软件） | 时钟、天气、决定做什么（AI）、把动作拆成阶段、把结果交给 AI 的记忆 |

游戏从不调用 AI，也不保存任何密钥。

## 1. 发现：`<data>/world/game-link.json`

宿主每次启动时写入，游戏读取。`<data>` 是游戏的数据目录：启动参数 `-- --data <路径>` 优先，其次环境变量 `CABINWORLD_DATA`，再次游戏旁 `cabinworld.ini` 的 `data=`，最后是游戏旁的 `data\`。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `port` | 整数 | 是 | 宿主在 `127.0.0.1` 上监听的端口 |
| `token` | 字符串 | 是 | 本次运行的一次性密钥（建议 64 位十六进制）。游戏在 `hello` 里原样发回 |
| `at` | 数字 | 否 | 写入时间 |

要求：只监听 `127.0.0.1`；每次启动换新 token；不要打印或上传 token；退出时删除这个文件（如果还是你写的那份）。游戏每 2 秒重试连接。

存档位置：`-- --save <文件夹>`，其次 `CABINWORLD_SAVE`，再次 `cabinworld.ini` 的 `save=`。公开版的 `cabinworld.ini` 是 `data=data`、`save=data/saves`。

## 2. 连接

TCP，UTF-8，**一行一个 JSON 对象**（以 `\n` 结尾），每个对象有 `type`。单行超过 1 MB 会断开。

1. 游戏连上后第一行必须是 `hello`；3 秒内没有正确的 `hello` 宿主应断开。只允许一个游戏连接。
2. 宿主校验 token（用常量时间比较），回复 `welcome`，接着发 `clock` 和 `weather`。
3. 游戏每 3 秒发 `ping`，宿主回 `pong`。任何一方 9 秒没收到消息就当断线。
4. 游戏关窗时发 `quit`；宿主也可以发 `quit` 让游戏退出。不要给游戏传 `--unit`（那是 VADS 一体模式：断开宿主游戏就退出）。

| `type` | 方向 | 字段 |
|---|---|---|
| `hello` | 游戏→宿主 | `token`，`game:"cabin-world"`，能力：`actions:1`，`economy:1`，`walk:1`，`residents:1`，`bodySave:1`，`social:1`，`worldRules:1`，`restaurant:2`，`arcadeProfiles`，`sleepProfiles`，`toolPoses` |
| `welcome` | 宿主→游戏 | `residents:true`（身体归游戏管，**必须**），`bodySave:1`，`social:1`，可选 `host:{name, audioSettings:false}` |
| `clock` | 宿主→游戏 | `now`。连上时和每 15 秒一次；游戏的时间都跟它走 |
| `weather` | 宿主→游戏 | `reading`（世界天气，见下），可选 `local`（天气牌：`city, condition, temperature, wind, source, at, fetchedAt`）。连上时和每 15 秒 |
| `ping` / `pong` | 双向 | 无 |
| `quit` | 双向 | 无 |

`reading`：`kind`（`sunny partly overcast fog drizzle rain breezy snow`），`name`，`rain`/`cloud`（0–1），`fog`/`snow`（布尔），`wind`（0–4.4），`windLevel`（0–4），`windAngle`（度），`temp`（°C），`phase`（`night dawn day dusk`），`sun`（0–1），`darkness`（0–1）。参考实现：`bridge/lib/weather.mjs`。

## 3. 住户初始化

住户 key 来自 `game/assets/residents.json`（公开版：`xiaojingyu`）。连上后对每位住户：

1. `body.open {id, actor, seed:{}, patch:{}}` → `body.saved {id, actor, ok, ...}`
2. `economy.do {id, actor, op:"sync", rev:0}` → `economy.result`（`rev:0` 表示以游戏存档为准）
3. `economy.do {id, actor, op:"top_up"}` → 发当天零花钱（同一天重复调用不会多发）

之后游戏会主动发 `walk.position {actor, scene, zone, x, y}`（连上时、每次到达后）。

## 4. 让游戏显示：`world`

`{type:"world", presence:{<actor>: row}}`，状态变化时发（参考桥每 15 秒也补发一次）。身体位置由游戏决定，`sceneId`/`zone` 只是给卡片用的说明。

| 字段 | 说明 |
|---|---|
| `name` | 名字 |
| `sceneId`、`space`、`zone`、`place` | 当前地点（取自 `walk.position`） |
| `label` | 卡片上的“正在做什么” |
| `effect` | 正在进行的动作特效：`{kind, module, zone, use, seconds, at, outcome, item, slot}`；`kind`/`module` 取自 `catalog.json` 里该用法的 `effect`/`module` |
| `coins` | 零花钱（取自 `economy.result.state.wallet.coins`） |
| `mood` | `{icon, word}`（取自 `economy.result.view.life.mood`） |
| `outfit` | `"yukata"` = 汤屋浴衣 |
| `items` | `{phone: dock|hand|pocket, headphones: dock|worn}` |
| `lamps` | `auto|on|off` |
| `at` | 写入时间（必填） |

## 5. 走路

| `type` | 方向 | 字段 |
|---|---|---|
| `walk.go` | 宿主→游戏 | `id`（唯一），`actor`，`scene`（场景 id），可选 `zone`、`next` |
| `walk.arrived` | 游戏→宿主 | `id`，`scene`，`x`，`y`；被新的 `walk.go` 顶替时 `replaced:true` |
| `walk.cancel` | 宿主→游戏 | `id`，`actor`：原地停下（不会再收到 `walk.arrived`） |

只有收到 `walk.arrived`（且不是 `replaced`）才算走到。场景 id：`xiaojingyu-home`、`qianxia-park`（公园）、`qianxia-shop`（小卖部）、`world-onsen`、`world-arcade`、`world-restaurant`。`qianxia-park`/`qianxia-shop` 是历史遗留的 id，指公共的公园和小卖部。

## 6. 分阶段动作

游戏掌管时钟和动画，宿主做每一步的数据工作。

| `type` | 方向 | 字段 |
|---|---|---|
| `action.start` | 宿主→游戏 | `id`，`actor`，`kind`，`label`，`phases:[{id, label, ms, pose:-1}]` |
| `action.phase` | 游戏→宿主 | `id`，`index`：第 index 步开始了，宿主去做这一步的工作 |
| `action.done` | 宿主→游戏 | `id`，`index`，`ok`：`true` 游戏再演 `ms` 毫秒进入下一步；`false` 动作结束 |
| `action.finished` | 游戏→宿主 | `id`：全部完成 |
| `action.interrupt` | 宿主→游戏 | `id`：立即停止（只能在提交之前） |
| `action.skip` | 宿主→游戏 | `id`：跳过当前步剩余时间 |

断线时：还没提交的动作当作没发生；已提交的（付了钱、吃完了）不能重复提交。

参考桥用到的三种动作（`bridge/lib/resident.mjs`）：

| 动作 | 步骤（★ = 提交） | 每步做的事 |
|---|---|---|
| 使用家具 `use` | `walk` → `begin` → `doing`(ms) → `finish`★ → `settle` | walk：`seat.claim` + `walk.go`；begin：公园先 `economy.do play`，再 `use_record`，发 `effect`；finish：`experience`；settle：`life_event`、`seat.release` |
| 购物 `buy` | `walk_shelf` → `pick`(3200) → `walk_counter` → `pay_wait`(2200) → `pay`★ → `settle` | pay：`economy.do buy`；settle：`use_record`、`experience`、`life_event` |
| 吃喝 `eat` | `start` → `eating`(4000) → `finish`★ → `settle` | finish：`economy.do consume`（`kind: eaten|used`）+ `experience`；settle：`life_event {type:"eat"}` |

持续时间：`catalog.json` 里每种用法的 `seconds`；汤屋和小卖部长椅最多演 6 秒。

## 7. 经济与生活：`economy.do` → `economy.result`

请求都有 `id`（唯一，重复的 id 不会执行两次）、`actor`、`op`。

| `op` | 额外字段 | 作用 / 可能的错误 |
|---|---|---|
| `sync` | `rev`（及可选 `wallet`、`bag`、`foods`） | 游戏没有这个人的存档、或 rev 更新时才采用 |
| `top_up` | | 每日零花钱 |
| `buy` | `product` | 扣当天价格，进背包。`零花钱不足`、`包已装满` |
| `consume` | `product`，`kind`（`eaten`/`used`），可选 `weather`、`space` | 用掉（`keep` 商品不消失）；返回 `lines`（味道/体感）。`包里没有这个` |
| `gift_in` / `gift_out` | `product` | 收到 / 送出一件 |
| `reward` | `amount` | 奖励零花钱（有上限） |
| `play` | `use`，`weather`，`umbrella`，`day`（`YYYY-MM-DD`，北京时间） | 公园结果：`lines`、`outcome`（如 `{catch,sizeCm,released}`、`{flew,height}`、`{skips}`） |
| `use_record` | `objectId`，`label`，`at`，可选 `use` | 记一次使用 |
| `experience` | `who`（residents.json 的 `flavor`），`args:{now, objectId, use, label, history, weather, companions, outcome, taste, product}` | 计算并保存新的感受 |
| `life_event` | `who`，`event:{type, …}`，`day`，`now`，`weather` | 记录生活事件，返回 `notes`、`memorable`、`diary` |
| `need_plan` | `need`（`hunger`/`thirst`），`who`，`now`，`day`，可选 `space`、`weather` | 只读建议：饿/渴了该做什么 |
| `options` | `lamps`（`auto/on/off`） | 保存选项 |

`economy.result`：`id`，`ok`，失败时 `error`（中文，可直接给 AI），`state`（`wallet{coins,day}`、`bag{id:数量}`、`foods`、`rev`、`feeling`、`life`、`uses`、`usage`），`view`（`feeling`、`hunger`、`likes`、`life{mood, wishes, needs, environment…}`、`want`、`care`）。宿主只保留只读镜像，以游戏为准。

## 8. 座位与侧边栏

| `type` | 方向 | 字段 |
|---|---|---|
| `seat.claim` | 宿主→游戏 | `id`，`owner`（住户 key），`object`，`seconds` |
| `seat.result` | 游戏→宿主 | `id`，`ok`，`slot`（没有座位的东西为 `only`/null），失败时 `error` |
| `seat.release` | 宿主→游戏 | `owner` |
| `panel.get` | 游戏→宿主 | `id`，`panel`（`usage`、`activity`、`album`、`photo`、`memory`），`who` |
| `panel.data` | 宿主→游戏 | `id`，`panel`，`ok`，`data` 或 `error` |
| `panel.do` / `panel.did` | 双向 | 相册拍照、记忆锚点等；不支持就回 `ok:false` |

相册、记忆属于宿主的功能，本插件不提供，回 `ok:false` 即可，游戏会显示提示。

## 9. 高级消息（参考桥未实现）

这些功能在游戏里完整存在，宿主要实现对应流程才能用。字段说明写在对应源码文件顶部的 `INTERFACE` 注释里。

| 功能 | 消息 | 源码 |
|---|---|---|
| 电玩城与棋盘对局 | `arcade.view`、`arcade.watch`、`arcade.records`、`rules.ask` / `rules.answer` | `game/core/vads_link.gd`、`arcade_hall.gd`、`arcade_board.gd` |
| 餐厅点菜、做菜 | `restaurant.do`、`restaurant.get` | `game/entities/restaurant_service.gd` |
| 睡觉与起床 | `body.sleep` / `body.sleepPlan`、`body.sync`、`body.do`、`body.get` / `body.state` | `game/core/resident_sleep.gd`、`body.gd` |
| 工具姿势（打字、画画） | `body.tool` / `body.toolPose` | `game/core/tool_poses.gd` |
| 串门与路线 | `entry.route` / `entry.result`、`entry.pass`、`entry.revoke` | `game/core/entry.gd` |
| 住户之间送礼、碰面 | `economy.do op:"social"`、`economy.social` | `game/core/resident_social.gd`、`economy.gd` |
| 窗口置前 | `window.show` | `game/core/vads_link.gd` |

## 10. 数据文件（游戏内）

| 文件 | 内容 |
|---|---|
| `game/assets/world.json` | 房间、位置（zones）、出口、障碍、东西 |
| `game/assets/residents.json` | 住户：key、名字、外观、作息、家 |
| `game/assets/economy.json` | 商品、价格、零花钱规则、钓鱼表 |
| `game/assets/*-grid.json`、`furniture-library.json` | 家具摆放网格 |
| `game/assets/npcs.json` | 店员等 NPC |
| `bridge/catalog.json` | 给宿主/AI 用的整理版：地点、位置、家具、用法、座位、商品 |
