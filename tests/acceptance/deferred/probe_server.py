#!/usr/bin/env python3
"""tests/acceptance/deferred/probe_server.py

验收用 OTLP/HTTP 探针接收器（仅本地回环 127.0.0.1，零外网）。
用法：python3 probe_server.py <capture_file>
  * 绑定 127.0.0.1:0（内核分配端口），把 `PORT <n>` 打到 **stdout** 后开始服务——
    测试侧用 `coproc` 拿这个管道做阻塞 `read`，天然就绪同步，**无需 sleep 轮询**；
  * 每个 POST 的 body 追加写入 capture_file（用 ---REQ--- 分隔），便于断言 payload 与请求次数；
  * 每收到一个请求就在 stdout 打一行 `REQ`——测试侧用阻塞 `read` 精确同步，无需轮询即可在
    「探针正挂住等响应」的窗口内做 argv / 进程取样；
  * env STUB_HTTP_STATUS   控制响应码（缺省 200；用于「HTTP 500 → exit 2」路径）；
  * env STUB_DELAY_SECONDS 响应前延迟（缺省 0）：模拟慢后端，用于断言 --timeout 缺省档。
  * 为什么走 stdout 而不是 FIFO：CI 的 Windows runner 上 python3 是**原生解释器**，打不开 MSYS 的
    mkfifo 管道（run 45222755424 实测 9 条「未在 30s 内报告端口」）。stdout 是普通 OS 管道，
    MSYS bash 与原生 python 两端都能用。
"""
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

# Windows 编码自保（CI 实跑 run 43031069740）：cp1252 控制台下打印中文会抛 UnicodeEncodeError
# → rc=1 且 stdout 为空（上层的 /tmp 断言与折叠计数随之连锁失败）。这里显式把流切到 UTF-8，
# 即使调用方设置了 PYTHONIOENCODING=cp1252 也能自保。
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

capture = sys.argv[1]
status = int(os.environ.get("STUB_HTTP_STATUS", "200"))
delay = float(os.environ.get("STUB_DELAY_SECONDS", "0") or 0)


def notify():
    """每收到一个请求就在 stdout 打一行 REQ（调用方用阻塞 read 精确同步）。"""
    try:
        print("REQ", flush=True)
    except OSError:
        pass


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802 (stdlib 命名)
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length)
        with open(capture, "ab") as fh:
            fh.write(body + b"\n---REQ---\n")
        notify()
        if delay > 0:
            time.sleep(delay)
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b"{}")

    def do_GET(self):  # noqa: N802
        self.send_response(status)
        self.end_headers()

    def log_message(self, *args):  # 静音，避免污染测试输出
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
print("PORT %d" % server.server_address[1], flush=True)
server.serve_forever()
