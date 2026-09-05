#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import time

HERE = Path(__file__).resolve().parent
TMP = Path("/private/tmp/syncthingStatus-status-ui-probe")
APP = TMP / "StatusUIFixture.app/Contents/MacOS/StatusUIFixture"
BUNDLE = TMP / "StatusUIFixture.app"
AX = TMP / "ax-status-dump"
log = []


def record(value):
    log.append(value)
    print(value, flush=True)


def dump(process):
    result = subprocess.run([str(AX), str(process.pid), "dump"], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def visible_strings(nodes):
    values = []
    for node in nodes:
        for key in ("title", "label", "value"):
            value = node.get(key)
            if isinstance(value, str) and value:
                values.append(value)
    return values


def wait_for_rows(process):
    deadline = time.monotonic() + 15
    last = []
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("fixture exited before AX inspection: " + process.stdout.read())
        try:
            last = dump(process)
            strings = visible_strings(last)
            if "Idle Folder" in strings and "Offline Peer" in strings and "Close Fixture" in strings:
                return last
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            pass
        time.sleep(0.15)
    raise RuntimeError("timed out waiting for production rows: " + json.dumps(last))


def require(strings, expected, mode):
    missing = [value for value in expected if not any(value in actual for actual in strings)]
    if missing:
        raise AssertionError(f"{mode} missing AX text: {missing}")


subprocess.run(["zsh", str(HERE / "build.sh")], check=True)
entitlements = subprocess.run(
    ["codesign", "-d", "--entitlements", ":-", str(BUNDLE)],
    check=True,
    capture_output=True,
    text=True,
).stdout
(HERE / "signed-entitlements.plist").write_text(entitlements)
if "com.apple.security.app-sandbox" not in entitlements or "<true" not in entitlements:
    raise AssertionError("fixture bundle is not sandboxed")
record("bundleIsolation=unique-id;app-sandbox=true")
for mode in ("compact", "detailed"):
    process = subprocess.Popen([str(APP), mode], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        nodes = wait_for_rows(process)
        strings = visible_strings(nodes)
        require(strings, [
            "Idle Folder", "Pending Deletes Folder", "Unavailable Folder", "Paused Folder",
            "Idle Device", "Pending Deletes Device", "Unavailable Device", "Paused Device", "Offline Peer",
            "Up to date", "Out of sync", "Status unavailable", "Paused", "Offline",
            "Traffic icon semantic: unavailable: Folder status unavailable; icon=warning",
            "Monochrome icon semantic: unavailable: Folder status unavailable; icon=warning",
            "Soft warning mapping: traffic=warning; monochrome=normal",
            "Paused mapping: traffic=warning; monochrome=normal",
            "Config-only failure: unavailable: Configuration unavailable",
            "Up to date means no pending files, directories, symlinks, deletions or bytes",
        ], mode)
        if mode == "compact":
            require(strings, ["4 deletes", "Syncing (100%)"], mode)
        (HERE / f"ax-{mode}.json").write_text(json.dumps(nodes, indent=2, sort_keys=True) + "\n")

        screenshot = HERE / f"status-{mode}.png"
        window_id = subprocess.run([str(AX), str(process.pid), "window-id"], check=True, capture_output=True, text=True).stdout.strip()
        shot = subprocess.run(["screencapture", "-x", "-o", "-l", window_id, str(screenshot)], capture_output=True, text=True)
        record(f"{mode}: axNodes={len(nodes)};requiredText=passed;screenshot={'saved' if shot.returncode == 0 else 'unavailable'}")
        if shot.returncode != 0:
            record(f"{mode}: screencaptureError={shot.stderr.strip()}")

        subprocess.run([str(AX), str(process.pid), "close"], check=True, capture_output=True, text=True)
        output = process.communicate(timeout=10)[0].strip()
        record(f"{mode}: {output}")
        if "unexpectedHTTP=0" not in output or "notifications=0" not in output:
            raise AssertionError(f"{mode} fixture isolation failed: {output}")
    finally:
        if process.poll() is None:
            process.terminate()
            process.communicate(timeout=5)

(HERE / "results.txt").write_text("\n".join(log) + "\n")
