#!/usr/bin/env python3
"""Local SQLite HTTP bridge for previewing the Flutter Hanzi app in Chrome/Desktop."""

import base64
import json
import os
import sqlite3
import subprocess
import tempfile
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DICT_DB = os.path.join(os.path.dirname(ROOT), "vi_full.db")
USER_DB = os.path.join(ROOT, "user_preview.db")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        if self.path == "/tts":
            try:
                req = json.loads(raw)
                text = (req.get("text") or "").strip()
                slow = bool(req.get("slow"))
                if text:
                    q = urllib.parse.quote(text)
                    speed = "0.24" if slow else "1"
                    url = (
                        f"https://translate.googleapis.com/translate_tts"
                        f"?ie=UTF-8&client=tw-ob&tl=zh-CN&ttsspeed={speed}&q={q}"
                    )
                    subprocess.Popen(
                        ["mpv", "--no-video", "--really-quiet", url],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                resp = b'{"ok":true}'
                self.send_response(200)
            except Exception as e:
                resp = json.dumps({"error": str(e)}).encode("utf-8")
                self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        if self.path == "/screenshot":
            try:
                tmp = tempfile.mktemp(suffix=".png")
                res = subprocess.run(["slurp"], capture_output=True, text=True)
                geom = res.stdout.strip()
                if geom:
                    subprocess.run(["grim", "-g", geom, tmp], check=True)
                else:
                    subprocess.run(["grim", tmp], check=True)
                with open(tmp, "rb") as f:
                    b64 = base64.b64encode(f.read()).decode("ascii")
                os.remove(tmp)
                resp = json.dumps({"image_base64": b64}).encode("utf-8")
                self.send_response(200)
            except Exception as e:
                resp = json.dumps({"error": str(e)}).encode("utf-8")
                self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(resp)))
            self.end_headers()
            self.wfile.write(resp)
            return

        try:
            req = json.loads(raw)
            db_name = req.get("db", "vi_full.db")
            sql = req.get("sql", "")
            args = req.get("args") or []
            db_path = USER_DB if db_name == "user.db" else DICT_DB

            conn = sqlite3.connect(db_path)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute(sql, args)
            rows = [dict(r) for r in cur.fetchall()]
            conn.commit()
            conn.close()
            resp = json.dumps({"rows": rows}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
        except Exception as e:
            resp = json.dumps({"error": str(e)}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)

        self._cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 43821), Handler)
    print("SQLite bridge listening on http://127.0.0.1:43821", flush=True)
    server.serve_forever()
