"""AstrBot 插件示例：把小屋世界的 通用工具（无需每件家具注册一个工具）注册成 LLM 工具。

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


@register("astrbot_plugin_cabinworld", "CabinWorld", "小屋世界：让 AI 在像素小世界里生活", "1.1.0")
class CabinWorldPlugin(Star):
    def __init__(self, context: Context, config: AstrBotConfig = None):
        super().__init__(context)
        path = (config or {}).get("bridge_json") or r"D:\CabinWorld\data\bridge.json"
        self.cabin = CabinClient(path)
        self.actor = str((config or {}).get("resident_id") or "").strip()

    async def _call(self, name, args=None):
        # 桥的调用是阻塞 HTTP，放到线程里，不卡住 AstrBot 的事件循环
        bound = dict(args or {})
        if self.actor:
            bound.setdefault("actor", self.actor)
        result = await asyncio.to_thread(self.cabin.call, name, bound)
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
    async def cabin_use(self, event: AstrMessageEvent, object: str, use: str, item: str = "", feeling: str = "", mode: str = "solo", text: str = "", durationSeconds: int = 0):
        """使用一件家具或东西（会自己走过去），例如 swing/swing 荡秋千、pier/fish 钓鱼、fish_tank/feed_fish 喂鱼。

        Args:
            object(string): 东西的 id
            use(string): 怎么用的 id
            item(string): 只在吃喝包里东西或在货架购买时需要：商品 id
            durationSeconds(int): 休闲持续活动可指定1至3600秒；0表示使用默认时长
            mode(string): npc 与电脑对战；duo 等另一住户，join 加入；扫雷和方块用 solo
            text(string): 写日记的正文
            feeling(string): 可选，自己此刻的想法
        """
        args = {"object": object, "use": use, "mode": mode, "text": text}
        if durationSeconds:
            args["durationSeconds"] = durationSeconds
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
    async def cabin_stop(self, event: AstrMessageEvent, action: str = "stop", reason: str = ""):
        """主动或按用户要求结束当前活动，不需要等固定秒数。

        Args:
            action(string): stop取消；finish提前结束休闲活动并收尾
            reason(string): 结束原因
        """
        return await self._call("cabin_stop", {"action": action, "reason": reason})

    @filter.llm_tool(name="cabin_catalog")
    async def cabin_catalog(self, event: AstrMessageEvent, query: str = "", space: str = "", offset: int = 0, limit: int = 20):
        """搜索所有可访问房间的家具和动作。没有关键词时完整分页，不因家具数量多而隐藏。找到后调用 cabin_use。

        Args:
            query(string): 名称或动作关键词，留空列出全部
            space(string): 可选房间编号
            offset(int): 首次0，之后使用返回的 nextOffset
            limit(int): 每页1至50件，默认20
        """
        return await self._call("cabin_catalog", {"query": query, "space": space, "offset": offset, "limit": limit})

    @filter.llm_tool(name="cabin_task")
    async def cabin_task(self, event: AstrMessageEvent, taskId: str):
        """查询本住户任务回执。running 不是成功，不要重复开局；done 才表示完成。

        Args:
            taskId(string): 之前工具返回的任务编号
        """
        return await self._call("cabin_task", {"taskId": taskId})

    @filter.llm_tool(name="cabin_restaurant")
    async def cabin_restaurant(self, event: AstrMessageEvent, action: str, dish: str = "", feeling: str = ""):
        """餐厅查看菜单、点餐、做菜和吃饭。

        Args:
            action(string): menu、order、cook、eat、sit、status、cancel 或 like/dislike/neutral
            feeling(string): 食后评价的主观理由，1至300字
            dish(string): menu 返回的菜品编号，order/cook/eat/评价需要
        """
        return await self._call("cabin_restaurant", {"action": action, "dish": dish, "feeling": feeling})

    @filter.llm_tool(name="cabin_residents")
    async def cabin_residents(self, event: AstrMessageEvent):
        """列出当前接入的住户及稳定编号。双人游戏不绑定特定名字。"""
        return await self._call("cabin_residents")

    @filter.llm_tool(name="cabin_invite")
    async def cabin_invite(self, event: AstrMessageEvent, guest: str):
        """邀请另一个已接入住户来家里；不替它行动。客人用返回的棋盘编号 join。

        Args:
            guest(string): cabin_residents 返回的客人稳定编号，不是显示名字
        """
        return await self._call("cabin_invite", {"guest": guest})

    @filter.llm_tool(name="cabin_add_resident")
    async def cabin_add_resident(self, event: AstrMessageEvent, key: str, name: str, mapId: str = ""):
        """按玩家要求新增机器人住户，分配默认房间或指定室内地图。

        Args:
            key(string): 新住户唯一稳定编号，不能用已有住户编号冒充另一个人
            name(string): 玩家指定的显示名字
            mapId(string): 可选已保存地图编号，留空分配默认房间
        """
        return await self._call("cabin_add_resident", {"key": key, "name": name, "mapId": mapId})

    @filter.llm_tool(name="cabin_assign_room")
    async def cabin_assign_room(self, event: AstrMessageEvent, mapId: str = ""):
        """按玩家要求更换本住户的房间，先离开原房间再申请更换。

        Args:
            mapId(string): 已保存室内地图编号，留空恢复默认房间
        """
        return await self._call("cabin_assign_room", {"mapId": mapId})

    @filter.llm_tool(name="cabin_rename")
    async def cabin_rename(self, event: AstrMessageEvent, name: str):
        """按玩家要求修改本住户显示名字，稳定编号不变。

        Args:
            name(string): 新显示名字，1至32字
        """
        return await self._call("cabin_rename", {"name": name})

    @filter.llm_tool(name="cabin_furniture")
    async def cabin_furniture(self, event: AstrMessageEvent):
        """查看可访问的自制家具及动作编号，随后用 cabin_use 调用。无动作的是装饰。"""
        return await self._call("cabin_furniture")
