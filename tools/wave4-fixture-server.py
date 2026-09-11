#!/usr/bin/env python3
"""Disposable loopback Syncthing API fixture for Wave 4 UI acceptance."""

from __future__ import annotations

import json
import shutil
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse


HOST = "127.0.0.1"
PORT = 28484
API_KEY = "wave4-fixture-key"
BASE = Path("/private/tmp/syncthingStatus-wave4-ui-live")
ROOT = BASE / "Sync" / "Project"
CONFIG = BASE / "config.xml"


class State:
    def __init__(self) -> None:
        self.lock = threading.Lock()
        self.scenario = "connected"
        self.requests: list[dict[str, object]] = []

    def set_scenario(self, value: str) -> None:
        with self.lock:
            self.scenario = value

    def snapshot(self) -> tuple[str, list[dict[str, object]]]:
        with self.lock:
            return self.scenario, list(self.requests)

    def record(self, method: str, path: str, query: dict[str, list[str]], key: str | None) -> None:
        with self.lock:
            self.requests.append({"method": method, "path": path, "query": query, "key": key})


STATE = State()


def prepare_files() -> None:
    if BASE.exists():
        shutil.rmtree(BASE)
    (ROOT / "candidate-0001").mkdir(parents=True)
    (ROOT / "candidate-0001" / "sentinel.txt").write_text("fixture sentinel\n")
    CONFIG.write_text(
        "<configuration><gui><address>127.0.0.1:28484</address>"
        f"<apikey>{API_KEY}</apikey></gui></configuration>\n"
    )


def folder() -> dict[str, object]:
    return {
        "id": "fixture-folder",
        "label": "Wave 4 Fixture",
        "path": str(ROOT),
        "devices": [],
        "paused": False,
    }


def need_item(index: int) -> dict[str, object]:
    return {
        "name": f"candidate-{index:04d}",
        "deleted": True,
        "type": "FILE_INFO_TYPE_DIRECTORY",
        "size": 0,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "Wave4Fixture/1"

    def log_message(self, fmt: str, *args: object) -> None:
        return

    def send_json(self, value: object, status: int = 200) -> None:
        body = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except BrokenPipeError:
            pass

    def send_empty(self, status: int = 204) -> None:
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        key = self.headers.get("X-API-Key")
        STATE.record("GET", parsed.path, query, key)
        scenario, requests = STATE.snapshot()

        if parsed.path == "/__fixture/state":
            self.send_json({"scenario": scenario, "requests": requests})
            return
        if key != API_KEY or scenario == "bad-key":
            self.send_json({"error": "forbidden"}, 403)
            return
        if parsed.path == "/rest/system/status":
            self.send_json({"myID": "fixture-local", "tilde": "~", "uptime": 123, "version": "fixture"})
        elif parsed.path == "/rest/system/config":
            self.send_json({"devices": [], "folders": [folder()]})
        elif parsed.path == "/rest/system/version":
            self.send_json({"version": "v-fixture"})
        elif parsed.path == "/rest/system/connections":
            self.send_json({"connections": {}, "total": {"connected": 0, "paused": 0,
                                                           "inBytesTotal": 0, "outBytesTotal": 0}})
        elif parsed.path == "/rest/db/status":
            self.send_json({
                "globalFiles": 1, "globalBytes": 17, "localFiles": 1, "localBytes": 17,
                "needFiles": 0, "needBytes": 0, "needDeletes": 1,
                "needDirectories": 0, "needSymlinks": 0, "needTotalItems": 1,
                "state": "idle", "lastScan": "2026-09-11T12:00:00Z",
            })
        elif parsed.path == "/rest/config/folders/fixture-folder":
            self.send_json(folder())
        elif parsed.path == "/rest/db/need":
            page = int(query.get("page", ["1"])[0])
            perpage = int(query.get("perpage", ["1000"])[0])
            if scenario == "page-failure" and page == 2:
                self.send_json({"error": "controlled later-page failure"}, 503)
                return
            if scenario == "slow-page" and page == 2:
                time.sleep(8)
            if scenario == "malformed-page" and page == 2:
                self.send_json({"page": 2, "perpage": perpage, "progress": [], "queued": []})
                return
            items = [need_item(i) for i in range(1, 1001)] if page == 1 else ([need_item(1001)] if page == 2 else [])
            self.send_json({"page": page, "perpage": perpage, "progress": [], "queued": [], "rest": items})
        else:
            self.send_json({"error": "not found", "path": parsed.path}, 404)

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        STATE.record("POST", parsed.path, query, self.headers.get("X-API-Key"))
        if parsed.path.startswith("/__fixture/scenario/"):
            scenario = parsed.path.rsplit("/", 1)[-1]
            STATE.set_scenario(scenario)
            self.send_json({"scenario": scenario})
            return
        if self.headers.get("X-API-Key") != API_KEY:
            self.send_json({"error": "forbidden"}, 403)
            return
        if parsed.path in {"/rest/db/scan", "/rest/system/pause", "/rest/system/resume"}:
            self.send_empty()
        else:
            self.send_json({"error": "not found", "path": parsed.path}, 404)


def main() -> None:
    prepare_files()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(json.dumps({"ready": True, "host": HOST, "port": PORT, "config": str(CONFIG), "root": str(ROOT)}), flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
