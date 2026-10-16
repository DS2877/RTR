#!/usr/bin/env python3
"""Actors for tools/view renders (store art, previews): blocky prisoners in the orange jumpsuit,
guards with a flashlight, things being lifted, debris cubes and dust flying out of a wall.

    python3 actors.py scene.json > actors.txt     (then EXTRA=tunnel.txt,actors.txt node render.mjs)

scene.json = {"actors": [{"kind": "prisoner", "at": [x, y, z], "yaw": deg, "pose": "punch",
                          "cell": 7}, {"kind": "debris", "from": [x,y,z], "dir": [x,y,z], "n": 14}, ...]}
Output: the world-dump line format (P / L / T) that page.html reads.
"""
import json
import math
import random
import sys

ORANGE = (214, 104, 34)
NAVY = (38, 52, 84)
DARK_NAVY = (26, 34, 54)
SKIN = (234, 184, 146)
HAIR = (50, 36, 28)


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def apply(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


class Frame:
    def __init__(self, pos, m):
        self.pos, self.m = list(pos), m

    def then(self, offset=(0, 0, 0), m=None):
        p = [self.pos[i] + apply(self.m, offset)[i] for i in range(3)]
        return Frame(p, mul(self.m, m) if m else self.m)


out = []


def part(f, size, color, material="SmoothPlastic", shape="Block", transparency=0.0, name="Actor"):
    m = f.m
    out.append(
        "P|%s|%s|%.3f|%.3f|%.3f|%s|%.2f|%.2f|%.2f|%d|%d|%d|%s|%.2f"
        % (
            name,
            shape,
            f.pos[0],
            f.pos[1],
            f.pos[2],
            "|".join("%.4f" % m[i][j] for i in range(3) for j in range(3)),
            size[0],
            size[1],
            size[2],
            color[0],
            color[1],
            color[2],
            material,
            transparency,
        )
    )
    return len([l for l in out if l.startswith("P|")])


def light(pos, color, rng, brightness):
    out.append("L|PointLight|%.2f|%.2f|%.2f|%d|%d|%d|%.1f|%.1f" % (pos[0], pos[1], pos[2], *color, rng, brightness))


def person(at, yaw, pose, suit, cap=None, cell=None, flashlight=False, held=None):
    """Feet at `at`, facing -Z rotated by yaw (degrees)."""
    base = Frame(at, rot_y(math.radians(yaw)))
    lean = rot_x(math.radians(-8)) if pose == "punch" else None
    body = base.then((0, 2.4, 0), lean).then((0, -2.4, 0))
    # legs (a stride when punching / walking)
    stride = 0.35 if pose in ("punch", "walk") else 0
    part(base.then((-0.5, 1.2, 0), rot_x(stride)), (0.95, 2.4, 1), suit)
    part(base.then((0.5, 1.2, 0), rot_x(-stride)), (0.95, 2.4, 1), suit)
    torso = part(body.then((0, 3.5, 0)), (2.2, 2.2, 1.1), suit)
    if cell is not None:
        out.append("T|%d|Back|%02d|30|30|34" % (torso, cell))
    # arms: pivot at the shoulder; angle about X (positive = forward / up)
    angles = {"punch": (95, 55), "walk": (25, -25), "lift": (170, 170), "idle": (5, 5), "flashlight": (70, 10)}[pose]
    for side, a in zip((1, -1), angles):
        sh = body.then((1.5 * side, 4.5, 0), rot_x(math.radians(a)))
        part(sh.then((0, -1.0, 0)), (0.8, 2.1, 0.8), suit)
        hand = sh.then((0, -2.25, 0))
        part(hand, (0.82, 0.5, 0.82), SKIN)
        if flashlight and side == 1:
            fl = hand.then((0, -0.4, 0))
            part(fl, (0.3, 0.9, 0.3), (40, 40, 44), "Metal")
            tip = fl.then((0, -0.6, 0))
            part(tip, (0.32, 0.12, 0.32), (255, 245, 210), "Neon")
            light(tip.pos, (255, 244, 210), 26, 2.6)
    head = body.then((0, 5.3, 0))
    part(head, (1.4, 1.4, 1.4), SKIN)
    part(head.then((-0.3, 0.15, -0.71)), (0.22, 0.3, 0.05), (20, 20, 20))
    part(head.then((0.3, 0.15, -0.71)), (0.22, 0.3, 0.05), (20, 20, 20))
    if cap:
        part(head.then((0, 0.85, 0)), (1.6, 0.5, 1.6), cap)
        part(head.then((0, 0.58, -1)), (1.7, 0.15, 0.6), cap)
        part(head.then((0, 0.85, -0.82)), (0.4, 0.3, 0.1), (226, 182, 70), "Metal")
    else:
        part(head.then((0, 0.82, 0.1)), (1.46, 0.36, 1.3), HAIR)
    if held == "toilet":
        top = body.then((0, 8.6, 0))
        for size, off, col in (
            ((1.4, 1.4, 1.8), (0, 0.7, 0.2), (225, 226, 228)),
            ((2.0, 0.6, 2.4), (0, 1.7, 0), (225, 226, 228)),
            ((2.2, 2.0, 0.9), (0, 2.6, 1.3), (225, 226, 228)),
        ):
            part(top.then((off[0], off[1] - 1.5, off[2])), size, col, "Marble")


def debris(origin, direction, n, color, seed):
    rnd = random.Random(seed)
    d = direction
    for i in range(n):
        t = 0.3 + rnd.random() * 1.0
        p = [origin[k] + d[k] * t * 6 + (rnd.random() - 0.5) * 3 for k in range(3)]
        p[1] = max(0.8, origin[1] + (rnd.random() - 0.2) * 3 - t * t * 2)
        m = mul(rot_x(rnd.random() * 6), mul(rot_y(rnd.random() * 6), rot_z(rnd.random() * 6)))
        s = 0.5 + rnd.random() * 1.4 if i % 3 else 1.6 + rnd.random() * 0.3
        shade = 0.85 + rnd.random() * 0.2
        part(Frame(p, m), (s, s, s), tuple(min(255, int(c * shade)) for c in color), "Concrete", name="Debris")
    for i in range(3):
        p = [origin[k] + d[k] * (2.5 + rnd.random() * 2) + (rnd.random() - 0.5) * 3 for k in range(3)]
        r = 1.2 + rnd.random() * 1.2
        part(Frame(p, rot_y(0)), (r, r, r), (215, 212, 205), "SmoothPlastic", "Ball", 0.72, name="Dust")


def main():
    scene = json.load(open(sys.argv[1]))
    for a in scene["actors"]:
        k = a["kind"]
        if k == "prisoner":
            person(a["at"], a.get("yaw", 0), a.get("pose", "idle"), ORANGE, cell=a.get("cell"), held=a.get("held"))
        elif k == "guard":
            person(a["at"], a.get("yaw", 0), a.get("pose", "flashlight"), NAVY, cap=DARK_NAVY, flashlight=True)
        elif k == "debris":
            debris(a["from"], a["dir"], a.get("n", 14), tuple(a.get("color", (142, 146, 152))), a.get("seed", 1))
        elif k == "light":
            light(a["at"], tuple(a["color"]), a.get("range", 20), a.get("brightness", 1.5))
    # T lines reference part indices inside THIS file: render.mjs offsets them by the parts before
    print("\n".join(out))


main()
