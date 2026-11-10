"""小屋世界桥的 Python 客户端，只用标准库（Python 3.8+）。

用法 / usage:
    from cabin_client import CabinClient
    cabin = CabinClient(r"D:\\CabinWorld\\data\\bridge.json")
    tools = cabin.tools()                    # 交给模型的 OpenAI 格式工具定义
    print(cabin.call("cabin_status"))        # 模型调用工具时：cabin.call(name, arguments)
    print(cabin.call("cabin_use", {"object": "swing", "use": "swing"}))

命令行试一试:
    python cabin_client.py status
    python cabin_client.py tool cabin_go "{\"place\": \"park\"}"
"""
import json
import os
import sys
import urllib.error
import urllib.request


class CabinError(Exception):
    pass


class CabinClient:
    def __init__(self, bridge_json, timeout=150):
        # bridge.json 由桥每次启动时重写（地址 + 随机 token），所以每次请求前重新读取。
        self.bridge_json = bridge_json
        self.timeout = timeout

    def _info(self):
        try:
            with open(self.bridge_json, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            raise CabinError("找不到 %s：小屋世界桥没有启动（双击 start.cmd）" % self.bridge_json)

    def _request(self, method, path, body=None):
        info = self._info()
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
        req = urllib.request.Request(info["url"] + path, data=data, method=method)
        req.add_header("Authorization", "Bearer " + info["token"])
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            # 4xx 的正文是 {"ok": false, "error": "中文原因"}，可以直接交给模型
            try:
                return json.loads(e.read().decode("utf-8"))
            except Exception:
                return {"ok": False, "error": "HTTP %s" % e.code}
        except urllib.error.URLError:
            return {"ok": False, "error": "连不上小屋世界桥，请确认 start.cmd 的窗口还开着"}

    def tools(self):
        """OpenAI function calling 格式的工具列表。"""
        return self._request("GET", "/v1/tools")["tools"]

    def call(self, name, arguments=None):
        """执行模型的一次工具调用；arguments 可以是 dict 或 JSON 字符串。返回 dict，原样交还给模型。"""
        if isinstance(arguments, str):
            arguments = json.loads(arguments or "{}")
        return self._request("POST", "/v1/tool", {"name": name, "arguments": arguments or {}})

    def status(self):
        return self._request("GET", "/v1/status")

    def push_weather(self, reading=None, local=None):
        """推送真实天气（见 docs/HTTP-API.md）。"""
        return self._request("POST", "/v1/weather", {"reading": reading, "local": local})


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    default = os.path.join(here, "..", "..", "data", "bridge.json")
    cabin = CabinClient(os.environ.get("CABIN_BRIDGE_JSON", default))
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        out = cabin.status()
    elif cmd == "tools":
        out = cabin.tools()
    elif cmd == "tool" and len(sys.argv) > 2:
        out = cabin.call(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "{}")
    else:
        out = {"usage": "python cabin_client.py [status | tools | tool <name> <json>]"}
    print(json.dumps(out, ensure_ascii=False, indent=2))
