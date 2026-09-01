import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

state = {"mode": "normal", "delay_ms": 0, "failures_remaining": 0}
lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {"status": "ok"})
        else:
            self.reply(404, {"error": "not found"})

    def do_POST(self):
        if self.path == "/control/reset":
            with lock:
                state.update(mode="normal", delay_ms=0, failures_remaining=0)
            return self.reply(200, state)

        body = self.read_json()
        if self.path == "/control":
            with lock:
                state.update(
                    mode=body.get("mode", "normal"),
                    delay_ms=int(body.get("delay_ms", 0)),
                    failures_remaining=int(body.get("failures", 0)),
                )
            return self.reply(200, state)
        if self.path != "/route":
            return self.reply(404, {"error": "not found"})

        with lock:
            mode = state["mode"]
            delay_ms = state["delay_ms"]
            if state["failures_remaining"] > 0:
                state["failures_remaining"] -= 1
                mode = "error"
        time.sleep(delay_ms / 1000)
        if mode == "error":
            return self.reply(503, {"error": "routing unavailable"})
        if mode == "malformed":
            return self.reply(200, {"unexpected": True})
        self.reply(200, {"distance_m": 1800, "duration_seconds": 420, "eta_seconds": 420})

    def read_json(self):
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length) or b"{}")

    def reply(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format, *args):
        print(format % args, flush=True)


ThreadingHTTPServer(("0.0.0.0", 9292), Handler).serve_forever()
