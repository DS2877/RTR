#!/usr/bin/env python3
"""Headless smoke test, run ONLY inside GitHub Actions (.github/workflows/deploy.yml).

1. Uploads rtr.rbxl as a *Saved* place version (not published: players never see it).
2. Runs tools/smoke.luau inside that version through the Open Cloud Luau Execution API.
3. Prints the task logs and the result, and writes a short summary to smoke-result.md.

Exit codes: 0 = all checks passed, 1 = checks failed / script error (do not publish),
            2 = smoke test unavailable (missing key permission, API down) -> publish anyway, warn.

The API key comes from the environment variable ROBLOX_KEY (the Actions secret). It is never
printed or written to disk. Needed key permissions: universe-places:write (already used to
publish) and universe.place.luau-execution-session:write (for step 2).
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

UNIVERSE = "10770392871"
PLACE = "95313582510402"
API = "https://apis.roblox.com"
KEY = os.environ.get("ROBLOX_KEY", "")
SUMMARY = "smoke-result.md"


def say(line):
    if KEY:
        line = line.replace(KEY, "***")
    print(line, flush=True)


def request(method, url, body=None, content_type=None):
    headers = {"x-api-key": KEY}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")
            if e.code in (429, 500, 502, 503) and attempt < 5:
                time.sleep(6 * (attempt + 1))
                continue
            return e.code, text
        except urllib.error.URLError as e:
            if attempt < 5:
                time.sleep(4)
                continue
            return 0, str(e)
    return 0, "retries exhausted"


def short(text, n=500):
    text = (text or "").strip().replace("\n", " ")
    return text if len(text) <= n else text[:n] + "…"


def summary(text):
    with open(SUMMARY, "w", encoding="utf-8") as f:
        f.write(text + "\n")


def unavailable(why):
    say(f"::warning::Smoke test unavailable: {why}")
    summary(f"Smoke test unavailable: {why}")
    return 2


def main():
    if not KEY:
        return unavailable("ROBLOX_KEY is not set")

    with open("rtr.rbxl", "rb") as f:
        place = f.read()
    status, text = request(
        "POST",
        f"{API}/universes/v1/{UNIVERSE}/places/{PLACE}/versions?versionType=Saved",
        place,
        "application/octet-stream",
    )
    say(f"Save version: HTTP {status} {short(text, 200)}")
    if status != 200:
        return unavailable(f"could not save a place version (HTTP {status})")
    version = json.loads(text).get("versionNumber")

    with open("tools/smoke.luau", encoding="utf-8") as f:
        script = f.read()
    status, text = request(
        "POST",
        f"{API}/cloud/v2/universes/{UNIVERSE}/places/{PLACE}/versions/{version}/luau-execution-session-tasks",
        json.dumps({"script": script, "timeout": "180s"}).encode(),
        "application/json",
    )
    say(f"Create task (version {version}): HTTP {status} {short(text, 300)}")
    if status in (401, 403):
        return unavailable(
            "the API key needs the permission universe.place.luau-execution-session:write "
            f"(HTTP {status})"
        )
    if status != 200:
        return unavailable(f"could not start the task (HTTP {status})")
    task = json.loads(text)
    path = task["path"]

    deadline = time.time() + 300
    while task.get("state") not in ("COMPLETE", "FAILED", "CANCELLED") and time.time() < deadline:
        time.sleep(5)
        status, text = request("GET", f"{API}/cloud/v2/{path}")
        if status == 200:
            task = json.loads(text)
        else:
            say(f"Poll: HTTP {status} {short(text, 200)}")
    state = task.get("state")
    say(f"Task state: {state}")

    status, text = request("GET", f"{API}/cloud/v2/{path}/logs?view=FLAT")
    if status == 200:
        for entry in json.loads(text).get("luauExecutionSessionTaskLogs", []):
            for m in entry.get("messages", []):
                say("  | " + m)

    if state == "COMPLETE":
        results = (task.get("output") or {}).get("results") or []
        result = results[0] if results else {}
        passed = result.get("passed", 0)
        failed = result.get("failed", 0)
        failures = result.get("failures") or []
        world = result.get("world")
        if world:
            with open("world.txt", "w") as f:
                f.write(world)
            say(f"World dump: {len(world)} bytes -> world.txt")
        lines = [f"Smoke test: {passed} passed, {failed} failed"] + [f"- {x}" for x in failures]
        summary("\n".join(lines))
        for line in lines:
            say(line)
        if failed:
            say("::error::Smoke test failed")
            return 1
        return 0
    if state == "FAILED":
        err = task.get("error") or {}
        summary(f"Smoke script crashed: {short(json.dumps(err), 1500)}")
        say(f"::error::Smoke script crashed: {short(json.dumps(err), 1500)}")
        return 1
    return unavailable(f"task did not finish (state {state})")


if __name__ == "__main__":
    sys.exit(main())
