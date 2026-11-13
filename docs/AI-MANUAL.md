> 安装/升级 1.1 时先读包根目录 INSTALL-AI.md，逐项介绍可选更新并记录用户选择；不默认全部启用。游戏设置中的模块面板已移除，使用安装 AI 或 update.cmd 调整。

# 小屋世界 · 家具与物品说明书（给 AI 读）

> 本文件由 `tools/gen-manual.mjs` 从 `bridge/catalog.json`（游戏数据）自动生成。可以整段放进你的机器人的系统提示词或知识库。
> English summary: this is the in-world manual for the AI resident: every room, spot, piece of furniture, what each use does, how long it takes, and every shop item. Tool names refer to `bridge/openai-tools.json`.

## 你是谁、在哪里

你在“小屋世界”里有一个真实的身体（角色 key `xiaojingyu`，名字可以由使用者改）。身体由游戏掌管：走路要真的走过去，用东西要真的走到旁边做完，钱和背包都记在游戏存档里。
你只能通过工具去做事；**不要凭空描述自己做了什么**，以工具返回的结果为准。工具返回 `status: "running"` 表示还没做完，做完之前不要说“已经做好了”。

| 工具 | 用来 |
|---|---|
| `cabin_status` | 查看自己在小屋世界里的状态：在哪里、零花钱、背包、饱腹/口渴/心情、正在做什么、天气 |
| `cabin_look` | 看看身边：当前房间有哪些家具和东西、每样能做什么（object 和 use 的 id）、出口通向哪里 |
| `cabin_catalog` | 搜索所有可访问房间的家具及动作（含新增家具），无关键词按稳定编号分页，不按常用程度删减 |
| `cabin_task` | 按任务编号查询当前住户的真实完成回执 |
| `cabin_go` | 走去一个地方 |
| `cabin_use` | 使用家具或街机 |
| `cabin_buy` | 去小卖部买一样东西：走到货架挑选，再去收银台付钱，东西进自己的背包 |
| `cabin_eat` | 吃、喝或使用背包里的一样东西（按商品种类自动决定是吃、喝还是用） |
| `cabin_stop` | 随时取消自己当前未提交的动作，含走路、游戏和家具，不必等固定秒数 |
| `cabin_residents` | 列出住户编号、显示名字、各自房间和可用室内地图 |
| `cabin_add_resident` | 新增一位机器人，分配独立默认房间 |
| `cabin_assign_room` | 为新增住户换为地图编辑器保存的室内地图 |
| `cabin_rename` | 修改显示名字，保留住户编号、背包、日记与身份 |
| `cabin_invite` | 邀请另一位已接入住户来自己家，返回客人可使用的地点和棋盘编号；不会自动走动或发送聊天消息 |
| `cabin_restaurant` | 查菜单或实际点餐、做菜、吃饭、入座；等待完成回执，不要把 accepted/running 当作已吃完 |
| `cabin_furniture` | 查看当前可访问房间中已摆放的自制家具，以及为自己配置的动作 |
| `cabin_update_plan` | 查看小屋世界 1 |
| `cabin_update_apply` | 按用户的选择打开或关闭 1 |
| `cabin_update_undo` | 撤销最近一次模块更改，恢复到更改前的选择 |

## 1.1 接入规则

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

## 基本规则

- **一次只做一件事。** 正在做事时再下指令会被拒绝（“先做完这件事”），可以先 `cabin_stop`。
- **零花钱：** 新住户有 30 元；每天（北京时间）第一次活动时游戏发零花钱：1.1 模块“每天 50 零花钱”打开时每天 50、最多存 300，关闭时每天 20、最多 80（以 `cabin_status` 实际的钱为准）。钱不够买不了。价格每天可能有特价，以游戏为准。
- **背包：** 最多 12 件。买的东西先进背包，吃/喝/用完才扣掉；中途被打断东西还在。雨伞这类“可以留着的”东西用了也不会消失。
- **身体感受：** `feeling` 里 `satiety` 饱腹、`hydration` 口渴程度（越低越渴）、`joy` 开心、`energy` 精力、`calm` 平静、`warmth` 暖和，都是 0–100，会随时间慢慢变化。饿了就去买吃的，渴了买喝的；天冷喝热饮、天热吃冰淇淋会更舒服。
- **天气和时间：** 世界跟随北京时间昼夜变化；天气由机器人软件提供（默认是虚拟天气）。下雨时滑梯是湿的，有风才适合放风筝，晴天树荫下凉快。
- **结果由游戏决定：** 钓鱼钓到什么、风筝飞多高、打水漂几下，都是游戏算出来的，照实说就好。
- **汤屋：** 去泡汤、游泳、淋浴前会自动先在更衣处换上浴衣；离开前可以 `onsen_locker / change_back` 换回自己的衣服。
- **别人的家：** 每位住户有自己的家，只有主人能进；去别人家下棋要主人用 `cabin_invite` 邀请。新住户由使用者在设置里添加，或用 `cabin_add_resident`。
- **记忆：** 本插件不保存你的记忆。工具返回的 `happened`（发生了什么、感受）请由你的机器人软件自己记下来。

## 地图

```
小鲸鱼家(xjhome) ── 公园(park) ── 小卖部(shop) ── 汤屋(onsen)
                     │  └──── 电玩城(arcade)
                     └─────── 餐厅(restaurant)
```

| 地方 id | 名字 | 室外 | 通往 |
|---|---|---|---|
| `park` | 小屋旁的公园 | 是 | `shop`、`xjhome`、`arcade`、`restaurant` |
| `xjhome` | 小鲸鱼的小屋 | 否 | `park` |
| `shop` | 公园小卖部 | 否 | `park`、`onsen` |
| `arcade` | 星光电玩城 | 否 | `park` |
| `onsen` | 小卖部后面的汤屋 | 否 | `shop` |
| `restaurant` | 公园餐厅 | 否 | `park` |

去某个地方用 `cabin_go {"place":"park"}`；要去房间里的具体位置再加 `zone`。

## 小屋旁的公园（`park`）

**位置（zone）：** `restaurantfront` 餐厅岔路入口，`gate` 小屋门口，`bench` 大树下的长椅，`swing` 秋千，`slide` 滑滑梯，`carousel` 小转马，`flowers` 花坛，`meadow` 大草坪，`pier` 钓鱼栈桥，`bridge` 木桥，`riverbank` 河对岸的芦苇滩，`shopfront` 小卖部门口，`xjgate` 小鲸鱼家门口，`seesaw` 双人跷跷板，`rider` 小鲸鱼摇摇乐，`arcade_bridge` 通往电玩城的桥头

### 大树（`big_tree`）

长椅后面一棵枝叶很密的大树，晴天在树下是一片阴凉，风大时叶子沙沙响。

| use | 做什么 | 大约用时 |
|---|---|---|
| `shade` | 在树荫下乘凉 | 8 秒 |
| `pick_leaf` | 捡一片落叶 | 5 秒 |

例：`cabin_use {"object":"big_tree","use":"shade"}`

### 木长椅（`bench`）

大树下的木长椅，可以坐着发呆、看云。

| use | 做什么 | 大约用时 |
|---|---|---|
| `sit_bench` | 坐在长椅上发呆 | 10 秒 |
| `watch_clouds` | 靠在长椅上看云 | 10 秒 |

例：`cabin_use {"object":"bench","use":"sit_bench"}`

### 秋千（`swing`）

双柱木秋千，坐上去可以荡高。

| use | 做什么 | 大约用时 |
|---|---|---|
| `swing` | 荡秋千 | 12 秒 |

例：`cabin_use {"object":"swing","use":"swing"}`

### 滑滑梯（`slide`）

从梯子爬上去再滑下来，下雨后滑面会湿。

| use | 做什么 | 大约用时 |
|---|---|---|
| `slide` | 爬上去滑滑梯 | 9 秒 |

例：`cabin_use {"object":"slide","use":"slide"}`

### 小转马（`carousel`）

手推的小转盘，转起来会有一点晕。

| use | 做什么 | 大约用时 |
|---|---|---|
| `spin` | 坐小转马转圈 | 10 秒 |

例：`cabin_use {"object":"carousel","use":"spin"}`

### 花坛（`flower_bed`）

开着小花的花坛，晴天常有蝴蝶。

| use | 做什么 | 大约用时 |
|---|---|---|
| `smell_flower` | 凑近闻花 | 6 秒 |
| `watch_butterfly` | 看蝴蝶飞 | 8 秒 |

例：`cabin_use {"object":"flower_bed","use":"smell_flower"}`

### 大草坪（`meadow`）

开阔的草坪，有风的时候适合放风筝，也可以躺下来。

| use | 做什么 | 大约用时 |
|---|---|---|
| `fly_kite` | 在草坪上放风筝 | 14 秒 |
| `lie_grass` | 躺在草地上 | 10 秒 |

例：`cabin_use {"object":"meadow","use":"fly_kite"}`

### 钓鱼栈桥（`pier`）

伸进小河的木栈桥，放着一根钓竿，钓到的鱼会放回河里。

| use | 做什么 | 大约用时 |
|---|---|---|
| `fish` | 坐在栈桥上钓鱼 | 16 秒 |

例：`cabin_use {"object":"pier","use":"fish"}`

### 小河（`river`）

公园右侧的小河，桥和钓鱼栈桥通向水边。

| use | 做什么 | 大约用时 |
|---|---|---|
| `skip_stones` | 打水漂 | 7 秒 |
| `feed_ducks` | 喂河里的鸭子 | 9 秒 |
| `dip_feet` | 脱了鞋踩踩河水 | 8 秒 |

例：`cabin_use {"object":"river","use":"skip_stones"}`

### 木桥（`bridge`）

跨过小河的木桥，站在上面能看见流水。

| use | 做什么 | 大约用时 |
|---|---|---|
| `look_river` | 趴在桥栏上看流水 | 8 秒 |

例：`cabin_use {"object":"bridge","use":"look_river"}`

### 路灯（`park_lamps`）

两盏路灯，天黑后自动亮起。

（装饰，看看就好。）

### 双人跷跷板（`seesaw`）

侧向摆放的跷跷板，左右两端各有一个座位；两人各坐一边，共用同一根木板。

| use | 做什么 | 大约用时 |
|---|---|---|
| `ride` | 坐上跷跷板 | 30 秒 |

例：`cabin_use {"object":"seesaw","use":"ride"}`

### 鲸鱼摇摇乐（`rider`）

装在弹簧上的小鲸鱼，可以坐上去轻轻摇。

| use | 做什么 | 大约用时 |
|---|---|---|
| `rock` | 坐鲸鱼摇摇乐 | 24 秒 |

例：`cabin_use {"object":"rider","use":"rock"}`

## 小鲸鱼的小屋（`xjhome`）

**位置（zone）：** `xj_beach` 右上角海边沙滩，`xj_door` 门口，`xj_bed` 鲸鱼床，`xj_desk` 电脑桌，`xj_tank` 鱼缸，`xj_sofa` 懒人沙发，`xj_window` 圆窗，`xj_rug` 波浪地毯，`xj_shelf` 书架，`xj_album` 朋友相册，`xj_draw` 画架，`xj_notes` 书桌，`xj_accessories` 手机与耳机收纳桌，`chess_xj_a` 波浪地毯左边，`chess_xj_b` 波浪地毯右边

### 小鲸鱼家地毯上的棋盘（`home_chess_xjhome`）

两个人才能下：坐在波浪地毯两边对弈。可以用 play 邀请对方来下。 play 下象棋；play_gomoku 下五子棋，使用同一张棋桌。

| use | 做什么 | 大约用时 |
|---|---|---|
| `play` | 下象棋 | 15 分钟 |
| `quit` | 这局不下了 | 1 秒 |
| `play_gomoku` | 下五子棋 | 15 分钟 |

例：`cabin_use {"object":"home_chess_xjhome","use":"play"}`

### 家旁海边（`xj_beach`）

从小屋南门出去，沿右侧独立小路向北走，到右上角的干沙滩。能看海、听浪、玩沙；不必去公园，不穿墙、不进入深水。夜晚也能听浪。

| use | 做什么 | 大约用时 |
|---|---|---|
| `watch_sea` | 到家旁海边看海 | 30 秒 |
| `listen_waves` | 在沙滩听海浪 | 30 秒 |
| `play_sand` | 在干沙滩上画小鲸鱼 | 20 秒 |

例：`cabin_use {"object":"xj_beach","use":"watch_sea"}`

### 鲸鱼床（`whale_bed`）

米白枕头、蓝色被褥的模块化木床；躺下和睡觉使用这张床。

| use | 做什么 | 大约用时 |
|---|---|---|
| `rest` | 躺在鲸鱼床上发呆 | 20 秒 |
| `nap` | 钻进被子睡个午觉 | 40 秒 |

例：`cabin_use {"object":"whale_bed","use":"rest"}`

### 电脑桌（`xj_computer`）

白色长桌上的电脑：看视频、学东西、玩小游戏、打字、上网都在这里。画画去画架，写日记去书桌。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 在电脑上冲浪 | 20 秒 |
| `watch_video` | 在电脑上看视频 | 20 秒 |
| `learn` | 在电脑上学点东西 | 20 秒 |
| `game` | 玩一局小游戏 | 20 秒 |
| `type` | 在电脑上敲字 | 15 秒 |

例：`cabin_use {"object":"xj_computer","use":"browse"}`

### 鱼缸（`fish_tank`）

养着三条小鱼（橙色、黄色、红色）和几根水草，一直在冒泡。

| use | 做什么 | 大约用时 |
|---|---|---|
| `feed_fish` | 给小鱼喂鱼食 | 8 秒 |
| `watch_fish` | 趴在鱼缸前看鱼 | 10 秒 |

例：`cabin_use {"object":"fish_tank","use":"feed_fish"}`

### 懒人沙发（`beanbag`）

浅蓝色的懒人沙发，坐下去会陷进去。

| use | 做什么 | 大约用时 |
|---|---|---|
| `sink_in` | 陷进懒人沙发里 | 20 秒 |
| `read_comic` | 窝在沙发上看漫画 | 20 秒 |

例：`cabin_use {"object":"beanbag","use":"sink_in"}`

### 交流角（`xj_corner`）

懒人沙发边上的一角。使用者分享给机器人的文件、音乐可以“放”在这里（内容由你的机器人软件自己提供）。

| use | 做什么 | 大约用时 |
|---|---|---|
| `read_files` | 在交流角翻看主人放来的东西 | 8 秒 |
| `listen_music` | 戴上耳机听交流角里的声音 | 12 秒 |

例：`cabin_use {"object":"xj_corner","use":"read_files"}`

### 圆窗（`round_window`）

木格圆窗，能看到外面的昼夜和天气。

| use | 做什么 | 大约用时 |
|---|---|---|
| `look_out` | 趴在圆窗边看外面 | 10 秒 |

例：`cabin_use {"object":"round_window","use":"look_out"}`

### 波浪地毯（`wave_rug`）

房间中间一圈一圈的蓝色波浪地毯，可以在上面打滚、转圈、伸懒腰。

| use | 做什么 | 大约用时 |
|---|---|---|
| `roll` | 在地毯上打滚 | 8 秒 |
| `dance` | 在地毯上转圈 | 6 秒 |
| `stretch` | 伸个懒腰 | 5 秒 |

例：`cabin_use {"object":"wave_rug","use":"roll"}`

### 小盆栽（`xj_plant`）

沙发旁边开着白色小花的绿植。

| use | 做什么 | 大约用时 |
|---|---|---|
| `water_plant` | 给小盆栽浇水 | 7 秒 |

例：`cabin_use {"object":"xj_plant","use":"water_plant"}`

### 吊灯（`xj_lamp`）

屋子中间的暖光小吊灯，可以开、关或自动随天色。

| use | 做什么 | 大约用时 |
|---|---|---|
| `on` | 开灯 | — |
| `off` | 关灯 | — |
| `auto` | 自动 | — |

例：`cabin_use {"object":"xj_lamp","use":"on"}`

### 自己的书架（`xj_bookshelf`）

自己的书架，可以抽一本书翻翻，或整理一下。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse_book` | 从书架上抽一本书翻翻 | 8 秒 |
| `tidy_shelf` | 整理书架 | 7 秒 |

例：`cabin_use {"object":"xj_bookshelf","use":"browse_book"}`

### 白兔摆件（`xj_rabbit`）

书架上的白兔摆件，可以摸摸它、擦擦灰。

| use | 做什么 | 大约用时 |
|---|---|---|
| `pet` | 摸摸白兔摆件 | 6 秒 |
| `dust_rabbit` | 帮白兔擦擦灰 | 6 秒 |

例：`cabin_use {"object":"xj_rabbit","use":"pet"}`

### 朋友相册（`xj_album`）

朋友相册，可以翻看。

| use | 做什么 | 大约用时 |
|---|---|---|
| `flip_album` | 翻看朋友相册 | 8 秒 |

例：`cabin_use {"object":"xj_album","use":"flip_album"}`

### 画架（`xj_easel`）

画架，可以随手画几笔。

| use | 做什么 | 大约用时 |
|---|---|---|
| `sketch` | 随手在画布上画几笔 | 10 秒 |

例：`cabin_use {"object":"xj_easel","use":"sketch"}`

### 自己的书桌（`xj_notes`）

摊开的日记本和笔都在这张书桌上：写日记、翻日记都在这里，电脑桌不管这个。

| use | 做什么 | 大约用时 |
|---|---|---|
| `write_diary` | 在书桌上写日记 | 15 秒 |
| `read_diary` | 翻翻自己的日记 | 8 秒 |
| `doodle` | 在本子上涂鸦 | 8 秒 |
| `tidy_desk` | 收拾书桌 | 6 秒 |

例：`cabin_use {"object":"xj_notes","use":"write_diary"}`

### 收纳桌（`xj_accessories`）

床边放手机和耳机的收纳桌。

| use | 做什么 | 大约用时 |
|---|---|---|
| `tidy_table` | 把收纳桌擦干净 | 5 秒 |

例：`cabin_use {"object":"xj_accessories","use":"tidy_table"}`

### 手机（`xj_phone`）

自己的手机，平时放在收纳桌上，可以拿起或放回。

| use | 做什么 | 大约用时 |
|---|---|---|
| `take` | 拿起自己的手机 | 20 秒 |
| `put_back` | 放回手机 | 4 秒 |

例：`cabin_use {"object":"xj_phone","use":"take"}`

### 耳机（`xj_headphones`）

自己的耳机，可以戴上或摘下放回。

| use | 做什么 | 大约用时 |
|---|---|---|
| `wear` | 戴上耳机 | 20 秒 |
| `remove` | 摘下放回耳机 | 4 秒 |

例：`cabin_use {"object":"xj_headphones","use":"wear"}`

## 公园小卖部（`shop`）

**位置（zone）：** `shop_door` 店门口，`snacks` 零食货架，`drinks` 饮料冰柜，`daily` 日用品货架，`icecream` 冰淇淋柜，`counter` 收银台，`food` 食品架，`bread` 面包架，`produce` 果蔬架，`magazines` 杂志架，`shop_onsen_door` 通往汤屋的木门，`hot_cabinet` 热饮柜，`bench_a` 长椅靠门那头，`bench_b` 长椅中间，`bench_c` 长椅靠收银台那头

### 零食货架（`snack_shelf`）

软糖、薯片、面包、巧克力和小鱼饼干。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 逛零食货架 | 5 秒 |
| `buy` | 挑零食（买零食，用 `cabin_buy`） | 3 秒 |

例：`cabin_use {"object":"snack_shelf","use":"browse"}`

### 饮料冰柜（`drink_fridge`）

亮着灯的冰柜，有汽水、牛奶、茶和水。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 看看冰柜里的饮料 | 5 秒 |
| `buy` | 挑饮料（买冷饮，用 `cabin_buy`） | 3 秒 |

例：`cabin_use {"object":"drink_fridge","use":"browse"}`

### 冰淇淋柜（`freezer`）

冒着冷气的冰淇淋柜。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 趴在冰柜上看冰淇淋 | 5 秒 |
| `buy` | 挑冰淇淋（买冰淇淋，用 `cabin_buy`） | 3 秒 |

例：`cabin_use {"object":"freezer","use":"browse"}`

### 日用品货架（`daily_shelf`）

雨伞、纸巾、防晒霜、笔记本、发圈和创可贴。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 逛日用品货架 | 5 秒 |
| `buy` | 挑日用品（买日用品，用 `cabin_buy`） | 3 秒 |

例：`cabin_use {"object":"daily_shelf","use":"browse"}`

### 收银台（`counter`）

两段连起来的木收银台，有收银机和购物袋；在这里结账后物品才进入自己的包。

| use | 做什么 | 大约用时 |
|---|---|---|
| `inspect` | 查看收银台和购物袋 | 6 秒 |

例：`cabin_use {"object":"counter","use":"inspect"}`

### 店里的窗户（`shop_window`）

从窗户能看到外面公园的天气。

| use | 做什么 | 大约用时 |
|---|---|---|
| `look_out` | 从店里的窗户看外面 | 6 秒 |

例：`cabin_use {"object":"shop_window","use":"look_out"}`

### 食品架（`food_shelf`）

后排左边的食品架，和零食货架一样可以挑零食。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 看看食品架 | 6 秒 |
| `buy` | 挑选食品（买零食，用 `cabin_buy`） | 3 秒 |

例：`cabin_use {"object":"food_shelf","use":"browse"}`

### 面包架（`bread_shelf`）

后排中间的面包架，可以看看。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 看看面包架 | 6 秒 |

例：`cabin_use {"object":"bread_shelf","use":"browse"}`

### 果蔬展示架（`produce_shelf`）

左前方的果蔬展示架，可以看看。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 看看果蔬展示架 | 6 秒 |

例：`cabin_use {"object":"produce_shelf","use":"browse"}`

### 杂志展示架（`magazine_shelf`）

前方的杂志架，可以看看封面（封面不是可读的正文）。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 看看杂志封面 | 8 秒 |

例：`cabin_use {"object":"magazine_shelf","use":"browse"}`

### 热饮柜（`hot_cabinet`）

挨着冰柜的保温柜，亮着暖黄的灯，有热牛奶、咖啡、拿铁、可可、姜茶、蜂蜜柠檬、绿茶和玉米奶。

| use | 做什么 | 大约用时 |
|---|---|---|
| `browse` | 看看热饮柜里有什么 | 5 秒 |
| `buy` | 挑热饮（买热饮，用 `cabin_buy`） | 3 秒 |

例：`cabin_use {"object":"hot_cabinet","use":"browse"}`

### 长椅（`long_bench`）

靠右边墙的一条长椅，能坐三个人，坐下来面朝店里。

座位：3 个（`bench_a`、`bench_b`、`bench_c`），有人坐着就会自动换一个空位，坐满了要等。

| use | 做什么 | 大约用时 |
|---|---|---|
| `sit` | 坐在长椅上歇一会儿 | 10 分钟 |

例：`cabin_use {"object":"long_bench","use":"sit"}`

## 星光电玩城（`arcade`）

**位置（zone）：** `arcade_door` 电玩城门口，`arcade_blocks` 俄罗斯方块1号机，`arcade_mines` 扫雷机台，`arcade_xiangqi` 象棋机台，`arcade_snake` 贪吃蛇机台，`arcade_xiangqi_far` 象棋桌左边的位置，`arcade_xiangqi_near` 象棋桌右边的位置，`arcade_snake_left` 贪吃蛇机台左边，`arcade_snake_right` 贪吃蛇机台右边，`arcade_blocks_2` 俄罗斯方块2号机

### 贪吃蛇机台（`arcade_snake`）

双人贪吃蛇：一个机器人可用 mode=npc 与电脑对战；两位住户用 duo 开桌、join 加入。

| use | 做什么 | 大约用时 |
|---|---|---|
| `play` | 玩贪吃蛇 | 15 分钟 |
| `quit` | 这局不玩了 | 1 秒 |

例：`cabin_use {"object":"arcade_snake","use":"play"}`

### 俄罗斯方块1号机（`arcade_blocks`）

俄罗斯方块：摆满一行就消除，方块会越落越快。消满30行算赢，堆到顶就输。 获胜+5钱，失败-2钱，平局和中断不结算；余额最低为0。

| use | 做什么 | 大约用时 |
|---|---|---|
| `play` | 玩俄罗斯方块1号机 | 15 分钟 |
| `quit` | 这局不玩了 | 1 秒 |

例：`cabin_use {"object":"arcade_blocks","use":"play"}`

### 扫雷机台（`arcade_mines`）

扫雷：9×9的格子里有10颗雷，数字表示周围有几颗雷。翻开所有没有雷的格子就赢，翻到雷就输。第一下一定安全。 获胜+5钱，失败-2钱，平局和中断不结算；余额最低为0。

| use | 做什么 | 大约用时 |
|---|---|---|
| `play` | 玩扫雷 | 15 分钟 |
| `quit` | 这局不玩了 | 1 秒 |

例：`cabin_use {"object":"arcade_mines","use":"play"}`

### 象棋机台（`arcade_xiangqi`）

共用棋桌：play 下象棋，play_gomoku 下五子棋。mode=npc 与电脑对战；两位住户用 duo 开桌、join 加入。

| use | 做什么 | 大约用时 |
|---|---|---|
| `play` | 玩象棋 | 15 分钟 |
| `quit` | 这局不玩了 | 1 秒 |
| `play_gomoku` | 下五子棋 | 15 分钟 |

例：`cabin_use {"object":"arcade_xiangqi","use":"play"}`

### 俄罗斯方块2号机（`arcade_blocks_2`）

俄罗斯方块：摆满一行就消除，方块会越落越快。消满30行算赢，堆到顶就输。 获胜+5钱，失败-2钱，平局和中断不结算；余额最低为0。

| use | 做什么 | 大约用时 |
|---|---|---|
| `play` | 玩俄罗斯方块2号机 | 15 分钟 |
| `quit` | 这局不玩了 | 1 秒 |

例：`cabin_use {"object":"arcade_blocks_2","use":"play"}`

## 小卖部后面的汤屋（`onsen`）

**位置（zone）：** `onsen_door` 门口，`onsen_lockers` 更衣处，`onsen_rest_a` 更衣室左边的长凳，`onsen_rest_b` 更衣室右边的长凳，`onsen_stairs` 下水的台阶，`onsen_soak_a` 浅池上面的石座，`onsen_soak_b` 浅池下面的石座，`onsen_shower_a` 第一间淋浴，`onsen_shower_b` 第二间淋浴，`onsen_shower_c` 第三间淋浴

### 大池子（`onsen_pool`）

很大的公共温水池，从南边的台阶下水，能痛快地游泳。

| use | 做什么 | 大约用时 |
|---|---|---|
| `swim` | 在大池子里游泳 | 2 分钟 |

例：`cabin_use {"object":"onsen_pool","use":"swim"}`

### 浅池石座（`onsen_soak`）

池子左边的浅水区，有两个石座，不想游泳的话可以靠着安静地泡。

座位：2 个（`onsen_soak_a`、`onsen_soak_b`），有人坐着就会自动换一个空位，坐满了要等。

| use | 做什么 | 大约用时 |
|---|---|---|
| `soak` | 靠在石座上安静地泡着 | 2 分钟 |

例：`cabin_use {"object":"onsen_soak","use":"soak"}`

### 淋浴隔间（`onsen_shower`）

右边三间带帘子的淋浴隔间，拉上帘子外面看不见。

座位：3 个（`onsen_shower_a`、`onsen_shower_b`、`onsen_shower_c`），有人坐着就会自动换一个空位，坐满了要等。

| use | 做什么 | 大约用时 |
|---|---|---|
| `shower` | 拉上帘子冲个澡 | 40 秒 |

例：`cabin_use {"object":"onsen_shower","use":"shower"}`

### 更衣室长凳（`onsen_bench`）

更衣室里的木长凳，泡完可以歇一会儿。

座位：2 个（`onsen_rest_a`、`onsen_rest_b`），有人坐着就会自动换一个空位，坐满了要等。

| use | 做什么 | 大约用时 |
|---|---|---|
| `rest` | 在更衣室的长凳边歇一会儿 | 30 秒 |

例：`cabin_use {"object":"onsen_bench","use":"rest"}`

### 更衣处（`onsen_locker`）

放衣服的竹篮和叠好的浴衣。

| use | 做什么 | 大约用时 |
|---|---|---|
| `change` | 换上浴衣 | 3 秒 |
| `change_back` | 换回自己的衣服 | 3 秒 |

例：`cabin_use {"object":"onsen_locker","use":"change"}`

## 公园餐厅（`restaurant`）

**位置（zone）：** `gate` 餐厅门口，`hall` 餐厅前厅，`kitchen` 后厨，`pantry` 备餐区，`wash` 洗手池旁，`prep` 备菜台旁，`cook_a` 一号灶台旁，`cook_b` 二号灶台旁，`oven` 烤箱旁，`fryer` 炸锅旁，`sushi` 寿司台旁，`ingredients` 食材柜旁，`order_a` 点餐台左侧，`order_b` 点餐台右侧，`pickup_a` 取餐台外侧，`pickup_b` 取餐台里侧，`return` 餐具回收台旁，`water` 饮水台旁，`seat-a1_use` A桌一号座位，`seat-a2_use` A桌二号座位，`seat-b1_use` B桌一号座位，`seat-b2_use` B桌二号座位，`seat-c1_use` C桌一号座位，`seat-c2_use` C桌二号座位，`seat-c3_use` C桌三号座位，`seat-c4_use` C桌四号座位，`seat-d1_use` D桌一号座位，`seat-d2_use` D桌二号座位

### 餐厅设施与菜单（`restaurant`）

公园北边的餐厅：左边是后厨，右边找 Naiwa 店员点餐取餐，前面是餐桌。

| use | 做什么 | 大约用时 |
|---|---|---|
| `look` | 查看餐厅 | 1 秒 |
| `cook` | 自己做菜 | 1 秒 |
| `order` | 找Naiwa点菜 | 1 秒 |
| `eat` | 端菜到桌边吃 | 1 秒 |
| `sit` | 坐下休息 | 1 秒 |
| `like` | 喜欢这道已吃过的菜 | 1 秒 |
| `dislike` | 不喜欢这道已吃过的菜 | 1 秒 |
| `neutral` | 中性评价 | 1 秒 |

例：`cabin_use {"object":"restaurant","use":"look"}`

## 随身小包（`bag`）

吃、喝、用背包里的东西：`cabin_eat {"product":"商品id"}`。按商品种类自动决定是吃、喝还是用。

## 小卖部商品

买：`cabin_buy {"product":"商品id"}`。价格是原价，当天可能有特价。

| 商品 id | 名字 | 原价 | 种类 | 在哪买 | 味道/说明 |
|---|---|---|---|---|---|
| `gummy` | 草莓软糖 | 4 元 | 吃 | 零食（`snack_shelf`） | 软软的，草莓味很甜 |
| `chips` | 海苔薯片 | 6 元 | 吃 | 零食（`snack_shelf`） | 咔嚓咔嚓，咸咸的有海苔香 |
| `bread` | 奶油面包 | 5 元 | 吃 | 零食（`snack_shelf`） | 松软，奶油甜而不腻 |
| `choco` | 巧克力棒 | 5 元 | 吃 | 零食（`snack_shelf`） | 巧克力在嘴里慢慢化开 |
| `fishcookie` | 小鱼饼干 | 4 元 | 吃 | 零食（`snack_shelf`） | 小鱼形状，脆脆的，可以分给鸭子 |
| `soda` | 冰镇橘子汽水 | 4 元 | 喝·冷 | 冷饮（`drink_fridge`） | 气泡在舌头上炸开，冰得一激灵 |
| `milk` | 草莓牛奶 | 5 元 | 喝·冷 | 冷饮（`drink_fridge`） | 甜甜的奶香 |
| `oolong` | 乌龙茶 | 4 元 | 喝·冷 | 冷饮（`drink_fridge`） | 有点回甘，很解腻 |
| `water` | 矿泉水 | 2 元 | 喝·冷 | 冷饮（`drink_fridge`） | 清清凉凉 |
| `lemontea` | 柠檬茶 | 4 元 | 喝·冷 | 冷饮（`drink_fridge`） | 酸酸甜甜 |
| `hot_milk` | 热牛奶 | 5 元 | 喝·热 | 热饮（`hot_cabinet`） | 温温的奶香，喝下去胃里都暖了 |
| `hot_coffee` | 热咖啡 | 6 元 | 喝·热 | 热饮（`hot_cabinet`） | 有点苦，提神，香味飘了一路 |
| `hot_latte` | 热拿铁 | 7 元 | 喝·热 | 热饮（`hot_cabinet`） | 奶泡绵绵的，咖啡香很柔和 |
| `hot_cocoa` | 热可可 | 6 元 | 喝·热 | 热饮（`hot_cabinet`） | 浓浓的巧克力味，甜得很安心 |
| `ginger_tea` | 红糖姜茶 | 5 元 | 喝·热 | 热饮（`hot_cabinet`） | 辣辣甜甜，从喉咙一路暖到肚子 |
| `hot_honey_lemon` | 蜂蜜柠檬热饮 | 5 元 | 喝·热 | 热饮（`hot_cabinet`） | 酸酸甜甜，热气里带着柠檬香 |
| `hot_green_tea` | 热绿茶 | 4 元 | 喝·热 | 热饮（`hot_cabinet`） | 清清淡淡，有点回甘 |
| `hot_corn_milk` | 热玉米奶 | 6 元 | 喝·热 | 热饮（`hot_cabinet`） | 甜甜的玉米香，喝着很顶饱 |
| `vanilla` | 香草冰淇淋 | 5 元 | 吃·冷 | 冰淇淋（`freezer`） | 冰凉绵密，香草味很浓 |
| `melonbar` | 西瓜冰棍 | 3 元 | 吃·冷 | 冰淇淋（`freezer`） | 咬一口全是西瓜味的冰碴 |
| `umbrella` | 透明雨伞 | 15 元 | 用（用后保留） | 日用品（`daily_shelf`） | 下雨出门可以撑着，不会淋湿 |
| `tissue` | 小包纸巾 | 2 元 | 用 | 日用品（`daily_shelf`） | 擦擦手和脸 |
| `sunscreen` | 防晒霜 | 12 元 | 用（用后保留） | 日用品（`daily_shelf`） | 涂上凉凉的，大太阳下不容易晒伤 |
| `notebook` | 小笔记本 | 6 元 | 用（用后保留） | 日用品（`daily_shelf`） | 蓝色封面，可以记点东西 |
| `scrunchie` | 发圈 | 3 元 | 用（用后保留） | 日用品（`daily_shelf`） | 风大的时候把头发扎起来 |
| `bandaid` | 创可贴 | 3 元 | 用 | 日用品（`daily_shelf`） | 万一擦破皮可以贴上 |
| `zongzi` | 粽子 | 8 元 | 吃 | 零食（`snack_shelf`） | 糯米软糯，带着粽叶香 |
| `mooncake` | 月饼 | 8 元 | 吃 | 零食（`snack_shelf`） | 饼皮酥香，馅料细腻 |
| `tangyuan` | 汤圆 | 6 元 | 吃 | 零食（`snack_shelf`） | 糯米皮软软的，热汤暖胃 |
| `iced_plum` | 冰酸梅汤 | 5 元 | 喝·冷 | 冷饮（`drink_fridge`） | 酸甜清凉，带一点梅子香 |
| `roast_chestnut` | 糖炒栗子 | 6 元 | 吃 | 零食（`snack_shelf`） | 剥开外壳，栗仁热乎粉糯 |
| `hot_pot_snack` | 关东煮小碗 | 8 元 | 吃 | 零食（`snack_shelf`） | 热汤里有萝卜和豆腐的鲜香 |
| `qingtuan` | 青团 | 6 元 | 吃 | 零食（`snack_shelf`） | 糯糯的外皮，带着青草香 |

## 怎么用才自然

- 想做什么之前先 `cabin_status` / `cabin_look`，根据饱腹、口渴、心情和天气挑一件事。
- 一次做一件，做完再说下一件；把返回的 `happened` 当作真实经历说给对方听，简短自然就好，不必逐步汇报。
- 钱不多时别乱花；渴了先喝水（最便宜）。
- 失败了（钱不够、有人占着、被打断）就照实说，换一件事做。
