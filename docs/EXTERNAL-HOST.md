# 本机宿主扩展接口（版本 1）

AstrBot、DSH 和其他机器人继续使用 [1.1 HTTP 桥](HTTP-API.md)。小屋世界拥有住户、碰撞和遮挡、活动、交易及存档。外部程序可以给其中一位住户提供画面，也可以在游戏侧栏提供自己的会话。

## 启动

支持本接口的 Windows 发行包带有 `bridge/external-host.json`。宿主检查其中的 `version`，从原安装目录启动程序，使用已选定的数据和存档路径。环境变量只传给本次游戏进程。

| 环境变量 | 值 |
| --- | --- |
| `CABIN_EXTERNAL_HOST_ACTOR` | 由常规桥登记的住户 ID。使用已有 ID 可继续读原住户存档。 |
| `CABIN_EXTERNAL_HOST_SOCKET` | 绑定到 `127.0.0.1` 的临时 WebSocket，路径为 24 个随机字节的十六进制编码。游戏主动连接。 |
| `CABIN_EXTERNAL_HOST_NAME` | 可选。侧栏显示的宿主名称，最多 32 字符。 |
| `CABIN_EXTERNAL_HOST_PORTRAIT` | 可选。宿主指定的本地头像文件。 |
| `CABIN_EXTERNAL_HOST_PORTRAITS` | 可选。宿主使用的头像缓存目录，与游戏源素材分开。 |

有外部画面的窗口需以 `--position -16000,-16000` 启动。宿主持续提供透明 PNG 二进制帧。帧画布在连接期间固定，单边最多 1024 像素，单帧最多 512 KiB。游戏把第一次有效画面的底部对齐住户落脚点。

| 方向 | 消息 | 含义 |
| --- | --- | --- |
| 宿主到游戏 | 文本 `report-position` | 请求住户向常规桥补报位置。 |
| 游戏到宿主 | 文本 `position-reported` | 住户已向常规桥报告。宿主通过 HTTP 查询真实位置。 |
| 游戏到宿主 | 文本 `ready` | 已登记的住户完成首帧绘制。 |
| 宿主到游戏 | 文本 `reveal` | 显示已经就绪的游戏窗口。 |
| 游戏到宿主 | 文本 `presented` | 游戏完成窗口呈现，可启用会话。 |

断开时恢复住户自身的显示。宿主根据窗口是否仍存在确定重连或结束会话。无宿主环境变量时游戏独立运行。

## 会话

游戏发出 `{"type":"chat-read"}` 查询会话，发出 `{"type":"chat-send","id":"…","text":"…"}` 请求发送。宿主用 `chat-state` 返回 `phase` 和 `messages`，每条消息包含 `cursor`、`side` 和 `text`。发送结果用 `chat-result` 返回原 `id` 和 `ok`，失败时可提供 `error`。同一条发送重试会保留 `id`。宿主用这个 ID 去重，并保存会话历史。游戏保留草稿与当前滚动位置。

## 像素角色素材

发行包内的 [figure-exports.json](../game/assets/figure-exports.json) 指向原作者的角色及动作元数据。路径以 `game/assets` 为基准。方向、帧矩形、脚点、缩放和时间参数沿用原数据。相同的住户 ID 在升级后继续绑定同一位住户。

Figure Scape 通过上述接口提供角色画面与 Coo 对话，使用原有 14 个 `cabin_*` 工具的交集驱动游戏。完整动作结果仍通过 HTTP 桥的任务 ID 查询。导入原版像素住户时，Figure Scape 通过素材清单读取作者给出的动作数据，并生成角色卡和封面。

## 验证桥与住户

运行游戏并等住户就绪。在发行目录下用 Node.js 18 或更新版本运行以下示例，将 `data/bridge.json` 替换为本次启动的数据目录，住户编号替换成要验证的编号。示例只读取状态。

```js
import { readFile } from "node:fs/promises";

const { url, token } = JSON.parse(await readFile("data/bridge.json", "utf8"));
const actor = "xiaojingyu";
const endpoint = new URL("/v1/status", url);
endpoint.searchParams.set("actor", actor);
const response = await fetch(endpoint, {
  headers: { authorization: `Bearer ${token}` },
});
if (!response.ok) throw new Error(`HTTP ${response.status}`);
const state = await response.json();
console.log({ actor: state.actor, connected: state.connected, position: state.position });
```

验证外部画面时，可以从 Figure Scape 的「引擎 → 小屋世界」选择刚导出的程序，再从角色库选一个角色进场。游戏中打开「对话」发送一条测试消息，从「记录」查看一次活动，退场后重新进入并确认住户仍在上次的位置。
