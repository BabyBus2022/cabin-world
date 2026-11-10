# 小屋世界桥 · HTTP 接口

桥只监听 `127.0.0.1`。地址和 token 在 `data/bridge.json`：

```json
{ "url": "http://127.0.0.1:18790", "token": "48 位十六进制，每次启动随机", "resident": "xiaojingyu", "pid": 1234, "at": 1762700000000 }
```

- 除 `/v1/health` 外都要带 `Authorization: Bearer <token>`（或 `X-Cabin-Token: <token>`），否则 `401`。
- 带 `Origin` 头的请求（浏览器网页发出的）一律 `403`，防止网页借你的浏览器操纵角色。
- POST 正文是 JSON 对象，最大 64 KB。返回都是 JSON，`ok:false` 时有中文 `error`，可以直接交给模型。
- HTTP 状态：`200` 正常；`400` 参数不对或游戏拒绝；`409` 正在做别的事；`503` 游戏没打开。

## 给模型用：一个入口就够

| 方法 | 路径 | 正文 | 说明 |
|---|---|---|---|
| GET | `/v1/tools` | | OpenAI function calling 格式的工具定义（同 `bridge/openai-tools.json`） |
| POST | `/v1/tool` | `{"name":"cabin_use","arguments":{"object":"swing","use":"swing"}}` | 按工具名执行。`arguments` 可以是对象，也可以是 JSON 字符串（很多 SDK 给的是字符串） |

## 逐个接口

| 方法 | 路径 | 正文 | 对应工具 |
|---|---|---|---|
| GET | `/v1/health` | | 不需要 token：`{ok, game, resident}`，`game` 表示游戏是否连着 |
| GET | `/v1/status` | | `cabin_status` |
| GET | `/v1/look` | | `cabin_look` |
| GET | `/v1/catalog` | | 全部地点、位置、家具、用法、商品（`bridge/catalog.json`） |
| POST | `/v1/go` | `{"place":"park","zone":"pier"}` | `cabin_go`（`zone` 可省） |
| POST | `/v1/use` | `{"object":"pier","use":"fish","feeling":"想安静一会儿"}` | `cabin_use` |
| POST | `/v1/buy` | `{"product":"soda"}` | `cabin_buy` |
| POST | `/v1/eat` | `{"product":"soda"}` | `cabin_eat` |
| POST | `/v1/stop` | `{}` | `cabin_stop` |
| GET | `/v1/tasks/{taskId}` | | 查询一个动作 |
| GET | `/v1/events?after=0` | | 最近的事件（到达、动作完成/失败、游戏连上/断开），用 `last` 作为下次的 `after` |
| POST | `/v1/weather` | 见下 | 推送真实天气 |

所有 POST 动作都可以加 `"waitMs": 毫秒`，覆盖默认等待时间（`0` = 立刻返回任务号）。

### 动作的返回

做完了：

```json
{ "taskId": "use-m3x…", "status": "done", "label": "荡秋千",
  "result": { "ok": true, "label": "荡秋千",
              "happened": ["秋千升起时风拂过脸……", "开心又有点雀跃"],
              "outcome": null, "wallet": 28, "bag": [{"id":"water","name":"矿泉水","count":1,"kind":"drink"}] } }
```

还没做完（超过 `waitMs`）：

```json
{ "taskId": "use-m3x…", "status": "running", "label": "坐在栈桥上钓鱼", "hint": "还在进行中：稍后用 GET /v1/tasks/… 查询，完成前不要当作已经做完" }
```

失败：`{"taskId":…, "status":"failed", "error":"零花钱只剩 3 元"}`；或者直接 `{"ok":false,"error":"正在荡秋千，先做完这件事（或调用 stop）"}`（HTTP 409）。

**规则：只有 `status: "done"` 才算发生过。** 失败、被叫停、游戏断开都不算；把 `result.happened` 交给你的机器人的记忆，不要自己编。

### `/v1/status` 的返回

```json
{ "ok": true, "resident": "xiaojingyu", "name": "小鲸鱼", "connected": true,
  "position": { "space": "park", "place": "小屋旁的公园", "zone": "pier", "zoneName": "钓鱼栈桥" },
  "wallet": 28, "bag": [], "bagSlots": 12,
  "feeling": { "joy": 72, "energy": 60, "calm": 66, "satiety": 58, "hydration": 49, "warmth": 55, "last": "……" },
  "hunger": "不饿", "mood": { "key": "plain", "word": "平平常常", "icon": "😌", "cause": "没什么特别的" },
  "wishes": [ { "id": "big_fish", "text": "钓到一条15厘米以上的鱼", "done": false } ],
  "environment": { "note": "……", "indoors": false },
  "doing": null, "outfit": null, "items": { "phone": "dock", "headphones": "dock" }, "lamps": "auto",
  "weather": { "kind": "partly", "name": "多云", "temp": 18.4, "phase": "day", "rain": 0, "windLevel": 1, "…": "…" } }
```

字段由游戏计算，桥只转述；数值 0–100。

### 推送真实天气 `POST /v1/weather`

```json
{
  "reading": { "kind": "rain", "name": "小雨", "rain": 0.6, "cloud": 1, "temp": 12.5, "windLevel": 2 },
  "local":   { "city": "长沙", "condition": "小雨", "temperature": 12.5, "wind": 9, "source": "我的天气插件" }
}
```

- `reading` 是世界里的天气（画面、雨雪、体感都用它），没给的字段用虚拟天气补齐；需要 `bridge.config.json` 里 `"weather": {"mode": "push"}` 才会替代虚拟天气。`kind` 可选：`sunny partly overcast fog drizzle rain breezy snow`。
- `local` 只显示在游戏右上角的天气牌上，任何模式都生效；90 分钟没有新推送就改回显示虚拟天气。
- 桥不会自己联网查天气。

## curl 试一试

```bat
set URL=http://127.0.0.1:18790
set TOKEN=（从 data\bridge.json 复制）
curl -s %URL%/v1/health
curl -s -H "Authorization: Bearer %TOKEN%" %URL%/v1/status
curl -s -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"name\":\"cabin_go\",\"arguments\":{\"place\":\"park\"}}" %URL%/v1/tool
curl -s -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"object\":\"swing\",\"use\":\"swing\"}" %URL%/v1/use
```
