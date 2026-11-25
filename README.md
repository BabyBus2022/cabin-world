# Cabin World 1.2 · 宠物口粮版

把完整 ZIP 解压到一个新文件夹，双击 **CabinWorld.exe**。首次打开会问你 **“你有以前的小屋世界存档，想接着玩吗？”** 使用机器人的玩家也可以双击 **start.cmd**，首次安装步骤相同。

本版新玩家默认操控团团。清溪村牧铃畜牧铺出售猫粮和狗粮，每份 3 币。买好后靠近宠物按 E 喂食。此版不含宠物医院。

[What changed since 1.1 (English)](Cabin-World-1.2-Release-Guide-EN.md) · [中文对照手册](1.2-版本对照手册.md) · [开始使用与升级](开始使用与升级.md)


本次升级和测试结果见 [DSH 第二轮回归](DSH-第二轮回归.md)。玩家换肤、领养小窝和可摆放的宠物睡篮见 [玩家皮肤与宠物家具](玩家皮肤与宠物家具.md)。


当前版的玩家换肤、涉水音效和资源修改方法见 [公开版编辑指南](公开版编辑指南.md)。

## 从公开源码运行

用 Godot 4.7.2 打开 `game/project.godot`，等待首次资源导入完成，按 F6 运行主场景或 F5 运行游戏。代码与可编辑美术存放于 game，机器人接入代码在 bridge。Windows 便携安装包见仓库 Releases。仓库里的 tools/CabinLauncher.cs 和 tools/install.ps1 分别是启动器和首次安装流程的源码。

Windows 导出需要安装对应的 Godot 导出模板。运行 `node tools/export-game.mjs <Godot控制台程序路径>` 可导出游戏引擎与独立 PCK。发行包另带启动器、Node.js 便携运行时及 editable 编辑工具所需的资源副本。
