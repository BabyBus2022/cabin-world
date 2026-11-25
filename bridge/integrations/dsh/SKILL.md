---
name: cabin-world
description: 小屋世界（Cabin World）：你在一个像素小世界里有真实的身体，能走路、玩、买东西、吃饭、下棋。用户聊到小屋、想让你去玩、安装游戏或升级到 1.2时使用 cabin-world 的 MCP 工具。
---

# 小屋世界

你通过 `cabin-world` MCP 工具控制自己在小屋世界里的身体。世界、钱、背包和规则都在游戏里；你的人设和记忆在你自己这边。

## 怎么做

1. 先用 `cabin_status` 看自己在哪、在做什么，用 `cabin_look` 看身边有什么。想找别的房间的东西，用 `cabin_catalog` 搜。
2. 用 `cabin_go` 走过去，用 `cabin_use` 使用家具（`object` 和 `use` 取目录里实际返回的 id），`cabin_buy` / `cabin_eat` 买和吃，`cabin_restaurant` 去餐厅。
3. 返回 `running` 只是还在进行中。用 `cabin_task` 按 taskId 查回执，`done` 之后才能说做完了，`failed` 要如实说。
4. 电玩城：一个人和电脑玩用 `mode:"npc"`；两位住户一起玩，第一位 `mode:"duo"` 开桌，另一位 `mode:"join"`。五子棋是 `arcade_xiangqi` 的 `play_gomoku`。
5. `actor` 用自己接入时的稳定编号，不替别的住户行动。
6. 没做过的事不说成做过；目录里没有的东西不假装有。

## 安装或升级小屋世界

收到本包并开始安装时，在启动游戏、启动桥或初始化数据前，到新解压的 CabinWorld 目录运行 `runtime/node.exe tools/setup.mjs status`。状态为 ask 时，**主动先问玩家：“你有以前的小屋世界存档，想接着玩吗？”** 给出“有旧存档”和“没有，第一次玩”两个答案，等待选择。普通的“安装这个游戏”就触发此流程。

1. **没有**。运行 `runtime/node.exe tools/setup.mjs fresh` 初始化全功能版本，成功后启动 CabinWorld.exe，接入住户则使用 start.cmd。
2. **有**。请玩家提供旧游戏安装路径，可粘贴旧 CabinWorld.exe 的路径。提示保存并退出旧游戏和桥。运行 `runtime/node.exe tools/setup.mjs import "旧游戏路径"`。先检查成功回执；目录无效时请玩家重选。保留旧目录作为备份。
3. **状态 choose**。已完成导入，直接运行 `runtime/node.exe bridge/update-cli.mjs --plan`。将九个功能作为一次多选交互，清溪村及自家农场只列一项。只对玩家确认修改的项运行 --set，例如 `runtime/node.exe bridge/update-cli.mjs --set village12=on --set invites12=on`。收到保存确认后（包括全部保持原样）运行 `runtime/node.exe tools/setup.mjs finish`。取消或未答复则停在 choose，下次继续。
若中途退出导致状态为 fresh，重新执行 fresh 即可完成先前选择的完整安装。

4. **状态 ready**。安装完成，日常启动游戏。已使用 DSH 的安装可刷新新版 bridge/integrations/dsh/install-dsh.cmd 并重启 DSH。

若由玩家直接操作，请打开 CabinWorld.exe，由内置安装窗口执行相同步骤。在 Windows 图形界面内完成整个流程也可运行 update.cmd。每次安装选用一个新解压的目录。若使用环境变量、自定义资源或另行管理的多个存档，请先核对 cabinworld.ini、bridge/bridge.config.json 和实际数据位置，在独立副本上合并。

## 连不上时

工具说"小屋世界桥没有运行"，就请用户双击小屋世界文件夹里的 `start.cmd`，等游戏打开后再试。

## 住户新动作

群聊回复前可调用 cabin_group_turn，提供本群当前发言、引用作者、@ 对象、最近几句及时间；返回 listen 时旁听。cabin_game_context 给出已启用的收支建议和群聊指引。要存取种子等农场物品，用 cabin_use 选择 qx_shared_chest，先 look，再 chest_take 或 chest_store，item 可写 seed×2。
