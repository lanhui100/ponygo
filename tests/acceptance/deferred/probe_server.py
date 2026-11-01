#!/usr/bin/env python3
"""tests/acceptance/deferred/probe_server.py

验收用 OTLP/HTTP 探针接收器（仅本地回环 127.0.0.1，零外网）。
用法：python3 probe_server.py <port_fifo> <capture_file>
  * 绑定 127.0.0.1:0（内核分配端口），把端口写入 FIFO 后开始服务——
    测试侧用阻塞 `read` 拿端口，天然就绪同步，**无需 sleep 轮询**；
  * 每个 POST 的 body 追加写入 capture_file（用 ---REQ--- 分隔），便于断言 payload 与请求次数；
  * env STUB_HTTP_STATUS 控制响应码（缺省 200；用于「HTTP 500 → exit 2」路径）。
"""
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port_fifo = sys.argv[1]
capture = sys.argv[2]
status = int(os.environ.get("STUB_HTTP_STATUS", "200"))


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):  # noqa: N802 (stdlib 命名)
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length)
        with open(capture, "ab") as fh:
            fh.write(body + b"\n---REQ---\n")
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
with open(port_fifo, "w", encoding="utf-8") as fh:
    fh.write("%d\n" % server.server_address[1])
    fh.flush()
server.serve_forever()
