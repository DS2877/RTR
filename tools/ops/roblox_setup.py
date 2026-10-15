#!/usr/bin/env python3
"""Creator Hub setup via Open Cloud, run ONLY inside GitHub Actions (.github/workflows/ops.yml).

- Sets every game pass / developer product on Roblox that is NOT in
  src/shared/Config/Products.luau off sale (the old Rob the Rich! products).
- Creates every game pass (Products.Passes) and developer product (Products.Items) listed in
  Products.luau that doesn't exist yet (matched by name, so re-running is safe), and updates the
  price of existing ones when Products.luau says something else.
- Writes the resulting Roblox IDs back into Products.luau (the `id = ...` field of each entry).
- Sets the start place's name, description and Max Players (serverSize = one per cell), and tries
  the same name/description on the universe (experience).
- Writes a sanitized log to tools/ops/ops-log.md (status codes + response bodies, never the key).

The API key comes from the environment variable ROBLOX_KEY (the Actions secret). It is never
printed or written to disk. Key permissions needed: game-pass:read/write,
developer-product:read/write, universe.place:write.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

UNIVERSE = "10770392871"
PLACE = "95313582510402"
SERVER_SIZE = 12  # one per cell (Config/World.CellCount)
GAME_NAME = "Dig Out! Prison Escape"
GAME_DESCRIPTION = (
    "You're a prisoner with a plan. Punch through the wall of your cell, dig a giant tunnel through "
    "plaster, brick and concrete, find hidden treasures, smuggle the rubble out and upgrade your "
    "tools in the Common Room. How deep can you dig? Mobile friendly!"
)
PRODUCTS_FILE = "src/shared/Config/Products.luau"
LOG_FILE = "tools/ops/ops-log.md"
API = "https://apis.roblox.com"

KEY = os.environ.get("ROBLOX_KEY", "")
log_lines = []
current_price = {}  # (kind, name) -> Robux price on Roblox right now


def log(line):
    # Defensive: never let the key reach the log, whatever an API echoes back.
    if KEY:
        line = line.replace(KEY, "***")
    print(line)
    log_lines.append(line)


def request(method, url, body=None, content_type=None):
    headers = {"x-api-key": KEY}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")
            if e.code == 429 and attempt < 3:
                time.sleep(5 * (attempt + 1))
                continue
            return e.code, text
        except urllib.error.URLError as e:
            if attempt < 3:
                time.sleep(3)
                continue
            return 0, str(e)
    return 0, "retries exhausted"


def multipart(fields):
    boundary = "----rtr" + uuid.uuid4().hex
    parts = []
    for k, v in fields.items():
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode("utf-8")
        )
    parts.append(f"--{boundary}--\r\n".encode("utf-8"))
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def short(text, n=600):
    text = text.strip().replace("\n", " ")
    return text if len(text) <= n else text[:n] + "…"


ID_KEYS = ("productId", "developerProductId", "gamePassId", "id", "targetId")


def find_id(obj):
    if isinstance(obj, dict):
        for k in ID_KEYS:
            v = obj.get(k)
            if isinstance(v, int) and v > 0:
                return v
            if isinstance(v, str) and v.isdigit():
                return int(v)
    return None


def items_of(obj):
    """Every dict with a 'name' inside a list response, wherever the API nests it."""
    out = []
    if isinstance(obj, list):
        for x in obj:
            if isinstance(x, dict) and "name" in x:
                out.append(x)
    elif isinstance(obj, dict):
        for v in obj.values():
            if isinstance(v, list):
                out.extend(items_of(v))
    return out


def list_existing(kind):
    path = (
        f"/game-passes/v1/universes/{UNIVERSE}/game-passes/creator"
        if kind == "pass"
        else f"/developer-products/v2/universes/{UNIVERSE}/developer-products/creator"
    )
    found = {}
    token = ""
    for _ in range(20):
        url = f"{API}{path}?pageSize=50" + (f"&pageToken={token}" if token else "")
        status, text = request("GET", url)
        log(f"- LIST {kind}: HTTP {status} {short(text, 300)}")
        if status != 200:
            return None
        data = json.loads(text or "{}")
        for it in items_of(data):
            i = find_id(it)
            if i:
                found[it["name"]] = i
                info = it.get("priceInformation") or {}
                price = info.get("defaultPriceInRobux") if isinstance(info, dict) else None
                if isinstance(price, int):
                    current_price[(kind, it["name"])] = price
        token = data.get("nextPageToken") if isinstance(data, dict) else None
        if not token:
            break
    return found


def create(kind, name, description, price):
    path = (
        f"/game-passes/v1/universes/{UNIVERSE}/game-passes"
        if kind == "pass"
        else f"/developer-products/v2/universes/{UNIVERSE}/developer-products"
    )
    body, ctype = multipart(
        {"name": name, "description": description, "price": str(price), "isForSale": "true"}
    )
    status, text = request("POST", API + path, body, ctype)
    log(f"- CREATE {kind} '{name}' ({price} R$): HTTP {status} {short(text)}")
    if status not in (200, 201):
        return None
    try:
        return find_id(json.loads(text))
    except json.JSONDecodeError:
        return None


def update_price(kind, item_id, name, price):
    """Bring an existing pass/product's price in line with Products.luau."""
    if current_price.get((kind, name)) == price:
        return True
    path = (
        f"/game-passes/v1/universes/{UNIVERSE}/game-passes/{item_id}"
        if kind == "pass"
        else f"/developer-products/v2/universes/{UNIVERSE}/developer-products/{item_id}"
    )
    body, ctype = multipart({"price": str(price), "isForSale": "true"})
    status, text = request("PATCH", API + path, body, ctype)
    log(
        f"- PRICE {kind} '{name}': {current_price.get((kind, name))} -> {price} R$: "
        f"HTTP {status} {short(text, 300)}"
    )
    return status in (200, 204)


def set_off_sale(kind, item_id, name):
    path = (
        f"/game-passes/v1/universes/{UNIVERSE}/game-passes/{item_id}"
        if kind == "pass"
        else f"/developer-products/v2/universes/{UNIVERSE}/developer-products/{item_id}"
    )
    body, ctype = multipart({"isForSale": "false"})
    status, text = request("PATCH", API + path, body, ctype)
    log(f"- OFF SALE {kind} '{name}' ({item_id}): HTTP {status} {short(text, 200)}")
    return status in (200, 204)


ENTRY = re.compile(
    r'key = "(\w+)",\s*id = (\d+),\s*name = "([^"]*)",\s*emoji = "[^"]*",'
    r'\s*price = (\d+),\s*desc = "([^"]*)"'
)


def parse_catalog(src):
    """(key, name, desc, price, is_pass) for every entry in Products.luau."""
    items_at = src.index("Items = {")
    out = []
    for m in ENTRY.finditer(src):
        out.append((m.group(1), m.group(3), m.group(5), int(m.group(4)), m.start() < items_at))
    return out


def set_id(src, key, value, field="id"):
    if field == "id":
        pattern = rf'(key = "{key}",\s*id = )\d+'
    else:
        pattern = rf'(key = "{key}",\s*id = \d+,\s*{field} = )\d+'
    new, n = re.subn(pattern, rf"\g<1>{value}", src, count=1)
    if n != 1:
        raise RuntimeError(f"{field} not found for {key}")
    return new


def main():
    if not KEY:
        print("ROBLOX_KEY missing", file=sys.stderr)
        return 1
    log(f"# Creator Hub setup – {time.strftime('%Y-%m-%d %H:%M UTC', time.gmtime())}")
    log("")
    with open(PRODUCTS_FILE, encoding="utf-8") as f:
        src = f.read()
    catalog = parse_catalog(src)
    log(f"Catalog: {len(catalog)} entries in Products.luau")
    log("")

    log("## Listing existing")
    passes = list_existing("pass")
    products = list_existing("product")
    log("")
    log("## Creating")
    ok = True
    for key, name, desc, price, is_pass in catalog:
        kind = "pass" if is_pass else "product"
        existing = ((passes if is_pass else products) or {}).get(name)
        rid = existing or create(kind, name, desc, price)
        if rid:
            src = set_id(src, key, rid)
            if existing:
                ok = update_price(kind, rid, name, price) and ok
        else:
            ok = False
        log(f"  -> {key}: {kind} {rid}")
    with open(PRODUCTS_FILE, "w", encoding="utf-8") as f:
        f.write(src)

    log("")
    log("## Off sale (everything on Roblox that is not in Products.luau)")
    wanted = {name for _, name, _, _, _ in catalog}
    for kind, existing in (("pass", passes), ("product", products)):
        if existing is None:
            log(f"- could not list {kind}s, skipped")
            ok = False
            continue
        for name, item_id in sorted(existing.items()):
            if name not in wanted:
                ok = set_off_sale(kind, item_id, name) and ok

    log("")
    log("## Experience name + description")
    body = json.dumps(
        {"displayName": GAME_NAME, "description": GAME_DESCRIPTION, "serverSize": SERVER_SIZE}
    ).encode()
    status, text = request(
        "PATCH",
        f"{API}/cloud/v2/universes/{UNIVERSE}/places/{PLACE}?updateMask=displayName,description,serverSize",
        body,
        "application/json",
    )
    log(f"- PATCH place name/description/serverSize={SERVER_SIZE}: HTTP {status} {short(text, 300)}")
    ok = ok and status == 200
    body = json.dumps({"displayName": GAME_NAME, "description": GAME_DESCRIPTION}).encode()
    status, text = request(
        "PATCH",
        f"{API}/cloud/v2/universes/{UNIVERSE}?updateMask=displayName,description",
        body,
        "application/json",
    )
    log(f"- PATCH universe name/description: HTTP {status} {short(text, 300)}")

    log("")
    log("Result: " + ("ALL OK" if ok else "SOME STEPS FAILED (see HTTP codes above)"))
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(log_lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
