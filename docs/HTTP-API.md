# 参考桥 1.1 HTTP 接口

基础地址与每次启动生成的访问 token 在配置 dataDir 的 `bridge.json`。请求加 `Authorization: Bearer <token>`。只监听本机，拒绝浏览器跨站 Origin；不要把 token 放入模型上下文。

通用调用：`POST /v1/tool`，JSON `{ "name": "cabin_use", "arguments": { "object": "arcade_snake", "use": "play", "mode": "npc" } }`。arguments 也可为 JSON 字符串。`GET /v1/tools` 返回同目录 openai-tools.json 的全部通用工具。

| 方法与路径 | 用途 |
|---|---|
| GET /v1/health | 无鉴权的进程/游戏连接状态 |
| GET /v1/status?actor=编号 | 当前住户状态 |
| GET /v1/look?actor=编号 | 当前房间、运行时家具与自制家具 |
| GET /v1/catalog | 兼容旧的完整目录，支持 actor |
| GET /v1/catalog?query=五子棋&offset=0&limit=20 | 精简搜索与分页；也可用 space、object；模型调用 cabin_catalog |
| GET /v1/tasks/任务编号 | 真实任务回执；模型使用绑定 actor 的 cabin_task |
| GET /v1/events?after=序号 | 最近最多200条事件，按 seq 增量消费；不是长期记忆存储 |
| GET /v1/residents | 已接入住户编号、名字与房间 |
| POST /v1/residents | key、name，可选 mapId，新增住户 |
| POST /v1/room | actor、mapId，更换自己的室内地图 |
| POST /v1/rename | actor、name，改显示名字，稳定编号不变 |
| POST /v1/invite | actor 为主人，guest 为客人稳定编号 |
| POST /v1/go | actor、place，可选 zone |
| POST /v1/use | actor、object、use，可选 mode/item/feeling/text/durationSeconds |
| POST /v1/buy 或 /v1/eat | actor、product，可选 feeling |
| POST /v1/stop | actor，可选 reason、action（stop 取消；finish 提前结束正在体验的休闲活动） |
| POST /v1/restaurant | actor、action、dish，可选 feeling；动作见 README-1.1.md |
| GET /v1/furniture | actor，列出游戏实际返回的可访问自制家具 |
| POST /v1/furniture | spec、images，导入PNG及声明式家具配置 |
| POST /v1/furniture/complete | actor、requestId、ok、result，提交外部家具功能的实际执行结果 |
| POST /v1/weather | reading、local；推送天气，是否采用 reading 取决于 weather.mode |

`cabin_catalog` 默认20件，上限50件；返回 total、nextOffset、objects。不按热门程度省略家具。用稳定编号排序，可检索动作；布局改变后请从第一页重新查询。无参数 GET /v1/catalog 保持旧客户端兼容。

异步调用返回 taskId/status。普通家具体验默认立即返回任务回执，机器人无需等待坐满20秒才能继续调用停止；显式 waitMs 才等待，其他类型按配置等待。用 `cabin_task` 查询时必须仍传该任务的 actor，不支持拿其他住户的编号冒领回执。任务只在本次桥进程中保存最近100条；桥重启后查询游戏状态和历史记录，不重放已完成的扣费或结算。

目录中标有 durationSeconds 的休闲动作可指定1–3600秒，例如沙发、游泳、泡汤、看海；不传时沿用原时长。`cabin_stop(action="finish")` 仅提前结束已经进入体验阶段的此类动作，最终成功仍须查询任务回执；`action="stop"` 可取消未提交的行动。购买、进食等已经提交的扣费/消耗不能用停止回滚，不承诺撤销已完成事实。

一个本机桥服务整个世界。多机器人共享同一个桥，各自适配器固定自己的 actor。HTTP token 是整个宿主的权限边界，不能把它交给不受信任的客户端当成细分租户凭据。
