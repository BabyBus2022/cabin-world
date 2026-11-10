"""AstrBot 插件示例：把小屋世界的 7 个工具注册成 LLM 工具。

⚠️ 示例代码：按 AstrBot 公开的插件接口编写（Star / @register / @filter.llm_tool），
没有在每个 AstrBot 版本上实测过。若你的 AstrBot 版本接口不同，保留 _call() 的部分，改注册方式即可。

配置：插件配置里的 bridge_json 填小屋世界 data\\bridge.json 的完整路径。
"""
import asyncio
import json
import os
import sys

from astrbot.api import AstrBotConfig, logger
from astrbot.api.event import AstrMessageEvent, filter
from astrbot.api.star import Context, Star, register

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cabin_client import CabinClient  # noqa: E402  同目录下，从 examples/python 复制而来


@register("astrbot_plugin_cabinworld", "CabinWorld", "小屋世界：让 AI 在像素小世界里生活", "0.1.0")
class CabinWorldPlugin(Star):
    def __init__(self, context: Context, config: AstrBotConfig = None):
        super().__init__(context)
        path = (config or {}).get("bridge_json") or r"D:\CabinWorld\data\bridge.json"
        self.cabin = CabinClient(path)

    async def _call(self, name, args=None):
        # 桥的调用是阻塞 HTTP，放到线程里，不卡住 AstrBot 的事件循环
        result = await asyncio.to_thread(self.cabin.call, name, args or {})
        if isinstance(result, dict) and result.get("ok") is False:
            logger.info("cabinworld %s: %s", name, result.get("error"))
        return json.dumps(result, ensure_ascii=False)

    @filter.llm_tool(name="cabin_status")
    async def cabin_status(self, event: AstrMessageEvent):
        """查看自己在小屋世界里的状态：在哪里、零花钱、背包、饱腹/口渴/心情、正在做什么、天气。"""
        return await self._call("cabin_status")

    @filter.llm_tool(name="cabin_look")
    async def cabin_look(self, event: AstrMessageEvent):
        """看看身边：当前房间有哪些东西、每样能做什么、出口去哪。"""
        return await self._call("cabin_look")

    @filter.llm_tool(name="cabin_go")
    async def cabin_go(self, event: AstrMessageEvent, place: str, zone: str = ""):
        """走去一个地方，身体会真的走过去。

        Args:
            place(string): 地方 id：xjhome 小鲸鱼家、park 公园、shop 小卖部、onsen 汤屋、arcade 电玩城、restaurant 餐厅
            zone(string): 可选，房间里的具体位置 id
        """
        return await self._call("cabin_go", {"place": place, **({"zone": zone} if zone else {})})

    @filter.llm_tool(name="cabin_use")
    async def cabin_use(self, event: AstrMessageEvent, object: str, use: str, item: str = "", feeling: str = ""):
        """使用一件家具或东西（会自己走过去），例如 swing/swing 荡秋千、pier/fish 钓鱼、fish_tank/feed_fish 喂鱼。

        Args:
            object(string): 东西的 id
            use(string): 怎么用的 id
            item(string): 只在吃喝包里东西或在货架购买时需要：商品 id
            feeling(string): 可选，自己此刻的想法
        """
        args = {"object": object, "use": use}
        if item:
            args["item"] = item
        if feeling:
            args["feeling"] = feeling
        return await self._call("cabin_use", args)

    @filter.llm_tool(name="cabin_buy")
    async def cabin_buy(self, event: AstrMessageEvent, product: str):
        """去小卖部买一样东西：走到货架挑选，再去收银台付钱，东西进背包。

        Args:
            product(string): 商品 id，例如 soda、bread、hot_cocoa、water
        """
        return await self._call("cabin_buy", {"product": product})

    @filter.llm_tool(name="cabin_eat")
    async def cabin_eat(self, event: AstrMessageEvent, product: str):
        """吃、喝或使用背包里的一样东西。

        Args:
            product(string): 背包里的商品 id
        """
        return await self._call("cabin_eat", {"product": product})

    @filter.llm_tool(name="cabin_stop")
    async def cabin_stop(self, event: AstrMessageEvent):
        """停下正在做的事。"""
        return await self._call("cabin_stop")
