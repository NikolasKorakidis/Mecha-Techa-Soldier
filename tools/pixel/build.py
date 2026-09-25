"""Stage 4 (8-bit) pixel art: python3 tools/pixel/build.py

Every sprite is original, drawn from ASCII grids or small procedural painters, and limited to
colours from the NES (2C02) master palette, so the whole stage reads as one Famicom-era game.
Writes PNG sheets (frames laid out left to right) into assets/retro/.
"""
import math
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "retro")

# NES master palette subset (hex values from the common 2C02 table).
PAL = {
    ".": None,
    "K": "000000", "W": "fcfcfc", "L": "bcbcbc", "G": "7c7c7c", "D": "545454",
    "N": "0000bc", "B": "0058f8", "b": "3cbcfc", "c": "a4e4fc",
    "r": "a81000", "R": "f83800", "O": "fca044", "Y": "f8b800", "y": "fce0a8",
    "P": "d800cc", "p": "f878f8", "V": "6844fc", "v": "9878f8",
    "E": "00a800", "e": "b8f818", "T": "008888", "t": "00e8d8", "M": "881400", "U": "503000",
}


def rgba(key):
    hx = PAL[key]
    if hx is None:
        return (0, 0, 0, 0)
    return (int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16), 255)


def grid(rows, w=None, h=None):
    w = w or max(len(r) for r in rows)
    h = h or len(rows)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != "." and x < w and y < h:
                img.putpixel((x, y), rgba(ch))
    return img


def strip(frames):
    w = sum(f.width for f in frames)
    h = max(f.height for f in frames)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for f in frames:
        out.paste(f, (x, 0))
        x += f.width
    return out


def recolor(rows, mapping):
    return ["".join(mapping.get(c, c) for c in r) for r in rows]


def save(name, img):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))


def put(img, x, y, key):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgba(key))


def fill_rect(img, x, y, w, h, key):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(img, xx, yy, key)


def bevel(img, x, y, w, h, base, light, dark):
    fill_rect(img, x, y, w, h, base)
    fill_rect(img, x, y, w, 1, light)
    fill_rect(img, x, y, 1, h, light)
    fill_rect(img, x, y + h - 1, w, 1, dark)
    fill_rect(img, x + w - 1, y, 1, h, dark)


def disc(img, cx, cy, r, key, light=None, dark=None):
    for yy in range(int(cy - r - 1), int(cy + r + 2)):
        for xx in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
            d = math.hypot(dx, dy)
            if d <= r:
                k = key
                if light and dx + dy < -r * 0.55:
                    k = light
                elif dark and dx + dy > r * 0.6:
                    k = dark
                put(img, xx, yy, k)


# --- Player ---------------------------------------------------------------------------

KESTREL = [
    "..........LW............",
    ".........LbbW...........",
    "...BB...LbbbW...........",
    "..BbbBBLWWWWWLL.........",
    "..BbbbbbbbbbbbbWWL......",
    "..BBBBBNNNbbbbbbbbWWcc..",
    "..BBBBBNNNbbbbbbbbWWcc..",
    "..BbbbbbbbbbbbbWWL......",
    "..BbbBBLWWWWWLL.........",
    "...BB...LbbbW...........",
    ".........LbbW...........",
    "..........LW............",
]


def player():
    frames = []
    for flame in (("YO", "RY"), ("OR", "YY")):
        rows = [list(r) for r in KESTREL]
        for y in (4, 7):
            rows[y][0], rows[y][1] = flame[0][0], flame[0][1]
        for y in (5, 6):
            rows[y][0], rows[y][1] = flame[1][0], flame[1][1]
        frames.append(grid(["".join(r) for r in rows]))
    save("player", strip(frames))


# --- Shots ----------------------------------------------------------------------------

def shots():
    save("shot_player", grid([
        "..cWWWWb",
        "bWWWWWWW",
        "bWWWWWWW",
        "..cWWWWb",
    ]))
    save("shot_spread", grid([
        ".bcb.",
        "bcWcb",
        "cWWWc",
        "bcWcb",
        ".bcb.",
    ]))
    a = grid([".RR.", "RYYR", "RYYR", ".RR."])
    b = grid([".pp.", "pWWp", "pWWp", ".pp."])
    save("shot_enemy", strip([a, b]))


# --- Enemies ----------------------------------------------------------------------------

DRONE = [
    "....DGGD....",
    "..DGLLLLGD..",
    ".DLLRRRRLLD.",
    "DGLRYWWYRLGD",
    "GLRYWKKWYRLG",
    "GLRYWKKWYRLG",
    "DGLRYWWYRLGD",
    ".DLLRRRRLLD.",
    "..DGLLLLGD..",
    "....DGGD....",
]

DART = [
    "..........GLL...",
    ".....rRRRRRRLLW.",
    "OYRRRRRRRRRRRRRW",
    "YWRRRRRRRRRRRRRW",
    ".....rRRRRRRLLW.",
    "..........GLL...",
]

POD = [
    "....TTTTTTTT....",
    "..TTttttttttTT..",
    ".TttccttttccttT.",
    ".TtcWWttttWWctT.",
    "TttcWWKKKKWWcttT",
    "TtttttKPPKtttttT",
    "TtttttKPPKtttttT",
    "TttcWWKKKKWWcttT",
    ".TtcWWttttWWctT.",
    ".TttccttttccttT.",
    "..TTttttttttTT..",
    "....TTTTTTTT....",
]

HEAVY = [
    "......DDDDDDDDDD........",
    "....DGGGGGGGGGGGGD......",
    "..DGLLLLLLLLLLLLLLGD....",
    ".DGLVVVVVVVVVVVVVVLGGGD.",
    "DGLVvvvvvvvvvvvvvvVLLLLG",
    "GLVvvWWWvvvvvvvvvvVRRYYW",
    "GLVvvWKWvvvvvvvvvvVRRYYW",
    "DGLVvvvvvvvvvvvvvvVLLLLG",
    ".DGLVVVVVVVVVVVVVVLGGGD.",
    "..DGLLLLLLLLLLLLLLGD....",
    "....DGGGGGGGGGGGGD......",
    "......DDDDDDDDDD........",
]

TURRET = [
    "......GG........",
    "......GLLLLLLLLW",
    ".....DGLGGGGGGGL",
    "...DGGLLLLD.....",
    "..DGLRRRRLLD....",
    ".DGLRYYYYRLLD...",
    "DGGLLLLLLLLLGD..",
    "GLLLLLLLLLLLLLG.",
    "GDDDDDDDDDDDDDG.",
    "GGGGGGGGGGGGGGG.",
]


def enemies():
    save("enemy_drone", strip([grid(DRONE), grid(recolor(DRONE, {"R": "P", "Y": "p"}))]))
    save("enemy_dart", strip([grid(DART), grid(recolor(DART, {"O": "R", "Y": "O"}))]))
    save("enemy_pod", strip([grid(POD), grid(recolor(POD, {"P": "W", "c": "W"}))]))
    save("enemy_heavy", strip([grid(HEAVY), grid(recolor(HEAVY, {"Y": "R", "R": "O"}))]))
    save("enemy_turret", strip([grid(TURRET), grid(recolor(TURRET, {"Y": "W", "R": "Y"}))]))
    save("asteroid_big", asteroid(24, 3))
    save("asteroid_small", asteroid(12, 7))


def asteroid(size, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    radii = [size * rnd.uniform(0.36, 0.48) for _ in range(10)]
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            ang = (math.atan2(dy, dx) + math.pi) / (2 * math.pi) * 10
            i = int(ang) % 10
            t = ang - int(ang)
            r = radii[i] * (1 - t) + radii[(i + 1) % 10] * t
            d = math.hypot(dx, dy)
            if d <= r:
                shade = (dx + dy) / r
                key = "L" if shade < -0.7 else ("U" if shade > 0.5 else "G")
                if d > r - 1.2:
                    key = "D"
                if rnd.random() < 0.06 and d < r - 2:
                    key = "D"
                img.putpixel((x, y), rgba(key))
    return img


# --- Effects -------------------------------------------------------------------------------

def explosion(size, seed):
    rnd = random.Random(seed)
    frames = []
    for f in range(4):
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        c = size / 2
        r = size * (0.22 + 0.1 * f)
        for y in range(size):
            for x in range(size):
                d = math.hypot(x + 0.5 - c, y + 0.5 - c) + rnd.uniform(-1.2, 1.2)
                if f < 3:
                    if d < r * 0.45:
                        key = "W" if f == 0 else "Y"
                    elif d < r * 0.75:
                        key = "Y" if f == 0 else "O"
                    elif d < r:
                        key = "O" if f < 2 else "R"
                    else:
                        continue
                else:
                    if r * 0.7 < d < r and rnd.random() < 0.55:
                        key = "r" if rnd.random() < 0.5 else "D"
                    else:
                        continue
                img.putpixel((x, y), rgba(key))
        frames.append(img)
    return strip(frames)


def effects():
    save("explosion", explosion(16, 11))
    save("explosion_big", explosion(32, 12))
    cap = [
        "..RRRRRR..",
        ".RYYYYYYR.",
        "RYWWYYYYYR",
        "RYWYYOOYYR",
        "RYYYOWWOYR",
        "RYYYOWWOYR",
        "RYYYYOOYYR",
        "RYYYYYYYYR",
        ".RYYYYYYR.",
        "..RRRRRR..",
    ]
    save("capsule", strip([grid(cap), grid(recolor(cap, {"R": "O", "Y": "y", "O": "R"}))]))
    heart = [
        ".RR..RR.",
        "RWRRRRRR",
        "RWRRRRRR",
        "RRRRRRRR",
        ".RRRRRR.",
        "..RRRR..",
        "...RR...",
    ]
    save("heart", strip([grid(heart), grid(recolor(heart, {"R": "p", "W": "W"}))]))


# --- Boss -------------------------------------------------------------------------------------

def boss():
    frames = []
    for open_core in (False, True):
        w, h = 80, 72
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # Hull: stacked bevelled armour, a prow pointing left, engine block right.
        bevel(img, 18, 14, 56, 44, "G", "L", "D")
        bevel(img, 22, 4, 40, 12, "D", "G", "K")
        bevel(img, 22, 56, 40, 12, "D", "G", "K")
        for i in range(14):
            fill_rect(img, 4 + i, 36 - i, 14, 1 + 2 * i if i < 12 else 0, "G")
        for i in range(14):
            put(img, 4 + i, 36 - i, "L")
            put(img, 4 + i, 36 + i, "D")
        bevel(img, 66, 20, 12, 32, "V", "v", "N")
        for ey in (24, 32, 40):
            fill_rect(img, 76, ey, 3, 5, "Y")
            put(img, 78, ey + 2, "W")
        # Armour plate seams and rivets.
        for x in range(24, 70, 8):
            fill_rect(img, x, 16, 1, 40, "D")
        for x in range(26, 70, 8):
            for y in (18, 52):
                put(img, x, y, "W")
        # Core housing and the core (shutters closed / eye open).
        disc(img, 40, 36, 13, "K")
        disc(img, 40, 36, 12, "N", "B", "K")
        if open_core:
            disc(img, 40, 36, 9, "R", "Y", "r")
            disc(img, 40, 36, 5, "Y", "W", "O")
            disc(img, 40, 36, 2, "W")
        else:
            for yy in range(24, 49):
                for xx in range(28, 53):
                    if math.hypot(xx + 0.5 - 40, yy + 0.5 - 36) <= 11:
                        put(img, xx, yy, "G" if (yy // 3) % 2 == 0 else "D")
            fill_rect(img, 29, 35, 23, 2, "R")
        # Gun ports on the upper and lower armour.
        for gy in (8, 60):
            fill_rect(img, 10, gy, 14, 3, "L")
            fill_rect(img, 8, gy, 2, 3, "R")
        frames.append(img)
    save("boss", strip(frames))


# --- Backdrops ------------------------------------------------------------------------------

def stars(name, count, keys, seed):
    rnd = random.Random(seed)
    img = Image.new("RGBA", (256, 224), (0, 0, 0, 0))
    for _ in range(count):
        x, y = rnd.randrange(256), rnd.randrange(224)
        key = rnd.choice(keys)
        put(img, x, y, key)
        if key == "W" and rnd.random() < 0.3:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(img, x + dx, y + dy, "b")
    save(name, img)


def planet():
    size = 112
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c = size / 2
    r = size / 2 - 2
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            d = math.hypot(dx, dy)
            if d > r:
                continue
            band = int((dy / r + 1) * 6 + math.sin(dx * 0.08) * 0.8) % 4
            key = ["N", "B", "N", "V"][band]
            light = (dx + dy * 0.6) / r
            # Ordered dither for the terminator, like a Famicom planet.
            bayer = [[0, 2], [3, 1]][y % 2][x % 2] / 4.0
            if light > 0.35 + bayer * 0.3:
                key = "K" if light > 0.75 + bayer * 0.2 else "N"
            if light < -0.6 and bayer < 0.5:
                key = "b"
            if d > r - 1.5:
                key = "b" if light < 0 else "N"
            img.putpixel((x, y), rgba(key))
    save("planet", img)


def tiles():
    t = 16
    img = Image.new("RGBA", (t * 6, t), (0, 0, 0, 0))
    # 0 fortress block, 1 edge block (lit side toward the corridor), 2 pipe, 3 girder,
    # 4 light panel, 5 vent.
    bevel(img, 0, 0, t, t, "D", "G", "K")
    put(img, 3, 3, "L")
    put(img, 12, 12, "L")
    bevel(img, t, 0, t, t, "G", "L", "D")
    fill_rect(img, t, 0, t, 2, "c")
    fill_rect(img, t + 2, 7, 12, 1, "D")
    fill_rect(img, t * 2, 0, t, t, "K")
    fill_rect(img, t * 2, 5, t, 6, "T")
    fill_rect(img, t * 2, 6, t, 1, "t")
    fill_rect(img, t * 2 + 7, 4, 2, 8, "G")
    fill_rect(img, t * 3, 0, t, t, "K")
    for i in range(t):
        put(img, t * 3 + i, i, "G")
        put(img, t * 3 + t - 1 - i, i, "G")
    fill_rect(img, t * 3, 0, t, 2, "L")
    fill_rect(img, t * 3, t - 2, t, 2, "L")
    bevel(img, t * 4, 0, t, t, "D", "G", "K")
    fill_rect(img, t * 4 + 4, 4, 8, 8, "Y")
    fill_rect(img, t * 4 + 5, 5, 3, 3, "W")
    bevel(img, t * 5, 0, t, t, "D", "G", "K")
    for y in range(3, 13, 3):
        fill_rect(img, t * 5 + 3, y, 10, 1, "K")
    save("tiles", img)


# --- Font -----------------------------------------------------------------------------------

FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10011", "10101", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    " ": ["00000"] * 7,
    ":": ["00000", "00100", "00100", "00000", "00100", "00100", "00000"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    ".": ["00000", "00000", "00000", "00000", "00000", "00000", "00100"],
    ",": ["00000", "00000", "00000", "00000", "00100", "00100", "01000"],
    "?": ["01110", "10001", "00001", "00110", "00100", "00000", "00100"],
    "'": ["00100", "00100", "01000", "00000", "00000", "00000", "00000"],
    "x": ["00000", "00000", "10001", "01010", "00100", "01010", "10001"],
    ">": ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
    "<": ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
    "=": ["00000", "00000", "11111", "00000", "11111", "00000", "00000"],
    "*": ["00000", "10101", "01110", "11111", "01110", "10101", "00000"],
}
FONT_ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 :-/!.,?'x><=*"


def font():
    img = Image.new("RGBA", (6 * len(FONT_ORDER), 8), (0, 0, 0, 0))
    for i, ch in enumerate(FONT_ORDER):
        for y, row in enumerate(FONT[ch]):
            for x, bit in enumerate(row):
                if bit == "1":
                    img.putpixel((i * 6 + x, y), (255, 255, 255, 255))
    save("font", img)


if __name__ == "__main__":
    player()
    shots()
    enemies()
    effects()
    boss()
    stars("stars_far", 90, ["G", "D", "L"], 5)
    stars("stars_near", 40, ["W", "c", "L"], 6)
    planet()
    tiles()
    font()
    print("wrote", sorted(os.listdir(OUT)))
