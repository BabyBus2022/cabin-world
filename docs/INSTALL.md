# 1.1 接入与迁移

使用配套1.1游戏、参考桥、工具定义和接入示例，不能只把新桥覆盖进1.0游戏。发布包应包括 `CabinWorld.exe`、`cabinworld.ini`、`start.cmd`、`selfcheck.cmd`、`bridge/`、`docs/`、`examples/`。

1. 安装 Node.js 18 或更高版本；也可在包的 runtime/node.exe 放可用运行时。
2. 编辑 bridge/bridge.config.json：resident 是默认机器人的稳定编号，displayName 是显示名字。多个机器人只运行一个桥，使用 residents 数组或游戏管理界面新增，每个适配器绑定自己的编号。
3. 双击 start.cmd。宿主会启动游戏；控制台显示“住户已就位”后开始工具调用。
4. 把 `GET /v1/tools` 返回的 tools 原样注册进机器人软件，工具调用原样转发 `/v1/tool`。使用1.1的 AI-MANUAL.md，别沿用“高级协议未实现”的旧说明，也别按每件家具生成数百个工具。
5. AstrBot 用户更新 examples/astrbot 中 main.py、cabin_client.py 及配置；设置 bridge_json 和 resident_id。未安装真实 AstrBot 的本机检查不能替代所有第三方版本兼容验证。

主要配置：dataDir 为宿主连接及事件目录，gameExe 为游戏路径；路径相对于 bridge.config.json。http.port 默认18790，设0自动选择空闲端口；waitMs 默认45000，设0立即返回任务编号。weather.mode 为 virtual 或 push。public 标准布局用根目录 cabinworld.ini 的 data=data、save=data/saves，便于便携迁移。

先运行 selfcheck.cmd 检查文件和配置。独立实机自检可以运行 `node bridge/selfcheck.mjs --live`，该命令使用临时存档。模型调用不包括在自检中。

备份旧包和 data 后再迁移。不要把本仓库 handover 中模拟测试生成的空存档、临时token、日志当成玩家发布数据；正式发布包仅放程序、文档、示例及空 data 目录。当前任务没有重写旧的公开1.0包。
