# 安装助手操作说明

收到本包并开始安装时，在启动游戏、启动桥或初始化数据前，到新解压的 CabinWorld 目录运行 `runtime/node.exe tools/setup.mjs status`。状态为 ask 时，**主动先问玩家：“你有以前的小屋世界存档，想接着玩吗？”** 给出“有旧存档”和“没有，第一次玩”两个答案，等待选择。普通的“安装这个游戏”就触发此流程。

1. **没有**。运行 `runtime/node.exe tools/setup.mjs fresh` 初始化全功能版本，成功后启动 CabinWorld.exe，接入住户则使用 start.cmd。
2. **有**。请玩家提供旧游戏安装路径，可粘贴旧 CabinWorld.exe 的路径。提示保存并退出旧游戏和桥。运行 `runtime/node.exe tools/setup.mjs import "旧游戏路径"`。先检查成功回执；目录无效时请玩家重选。保留旧目录作为备份。
3. **状态 choose**。已完成导入，直接运行 `runtime/node.exe bridge/update-cli.mjs --plan`。将九个功能作为一次多选交互，清溪村及自家农场只列一项。只对玩家确认修改的项运行 --set，例如 `runtime/node.exe bridge/update-cli.mjs --set village12=on --set invites12=on`。收到保存确认后（包括全部保持原样）运行 `runtime/node.exe tools/setup.mjs finish`。取消或未答复则停在 choose，下次继续。
若中途退出导致状态为 fresh，重新执行 fresh 即可完成先前选择的完整安装。

4. **状态 ready**。安装完成，日常启动游戏。已使用 DSH 的安装可刷新新版 bridge/integrations/dsh/install-dsh.cmd 并重启 DSH。

若由玩家直接操作，请打开 CabinWorld.exe，由内置安装窗口执行相同步骤。在 Windows 图形界面内完成整个流程也可运行 update.cmd。每次安装选用一个新解压的目录。若使用环境变量、自定义资源或另行管理的多个存档，请先核对 cabinworld.ini、bridge/bridge.config.json 和实际数据位置，在独立副本上合并。
