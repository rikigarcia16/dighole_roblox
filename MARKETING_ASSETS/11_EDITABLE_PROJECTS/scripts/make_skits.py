"""Story skits for Reels / TikTok / Shorts (1080x1920), in English.
Format learnt from viral Roblox POV skits: a relatable hook line, a mini story told with the game's own
chat bubbles, an escalation and a punchline. Real gameplay recorded in Studio (sk_* clips): no HUD,
English bubbles, local NPCs. No music on purpose: add a trending sound in the app when posting.

Usage: python make_skits.py [ids...]
Output: MARKETING_ASSETS/12_FINAL_EXPORTS/skits_9x16/THNE_skit_<id>.mp4
"""
import sys
from video import *

W, H = 1080, 1920
OUT = os.path.join(ROOT, "12_FINAL_EXPORTS", "skits_9x16")
WIN_Y, WIN_H = 330, 1240  # gameplay window; hook above it, brand below it


def vw(focus=0.5, zoom=1.0, box_h=WIN_H):
    """Gameplay window; a lower box_h shows more of the width (for two speakers far apart)."""
    return lambda im: vert_framed(im, focus, zoom, (W, H), box_h=box_h, y=WIN_Y + (WIN_H - box_h) // 2)


def black(_im):
    return Image.new("RGB", (W, H), (8, 8, 12))


def txt(s, size=88, colors=WHITE, w=980):
    im = headline(s, size, colors)
    return fit(im, w=w) if im.width > w else im


def hook(s, t1, size=80):
    return Overlay(txt(s, size, WHITE), 0.0, t1, (W // 2, 70), "tc")


def mid(s, t0, t1, colors=WHITE, size=110, y=None):
    return Overlay(txt(s, size, colors), t0, t1, (W // 2, y or H // 2), "cc")


def label(s, t0, t1, colors=CYAN, size=74, y=WIN_Y + 40):
    return Overlay(txt(s, size, colors), t0, t1, (W // 2, y), "tc")


def tail():
    card = Image.new("RGB", (W, H), (8, 8, 12))
    card = place(card, fit(logo("main_en", "oscuro"), w=900), (W // 2, 520), "tc")
    card = place(card, pill("FREE ON ROBLOX", 70, bg=(120, 220, 90)), (W // 2, 1180), "cc")
    return place(card, body_text("The Hole Never Ends · link in bio", 50, (255, 255, 255), stroke=4), (W // 2, 1330), "cc")


def brand(total):
    return Overlay(pill("THE HOLE NEVER ENDS · ROBLOX", 34, bg=(255, 196, 40)), 0.0, total, (W // 2, WIN_Y + WIN_H + 60), "tc")


def make(sid, segs, ovs, cues):
    os.makedirs(OUT, exist_ok=True)
    total = sum(s.dur for s in segs)
    out = os.path.join(OUT, f"THNE_skit_{sid}.mp4")
    render(segs, ovs + [brand(total)], out, (W, H), cues, None, 0.0, 0.0, tail_card=(tail(), 2.0), crf=19)


def starts(segs):
    return list(np.cumsum([0] + [s.dur for s in segs]))


def digs(t0, t1, every=0.55, gain=0.4):
    return [(t0 + k * every, "sfx_dig_hit.wav", gain) for k in range(int((t1 - t0) / every))]


SKITS = {}


def skit(fn):
    SKITS[fn.__name__[1:]] = fn
    return fn


@skit
def _01_mom_said_go_outside():
    segs = [Seg("sk_mom_outside", 0.4, 4.6, vw(0.5)),
            Seg("rec_basic_dig", 14.0, 3.2, vw(0.5, 1.1), speed=1.6, flash_in=True),
            Seg("sk_abyss_plain", 0.0, 1.3, black),
            Seg("sk_mom_dinner", 0.3, 3.6, vw(0.52), flash_in=True),
            Seg("sk_abyss_coming", 0.6, 5.6, vw(0.5), flash_in=True)]
    st = starts(segs)
    ov = [hook("POV: mom said\n\"go play outside\"", st[2]),
          mid("3 HOURS LATER…", st[2] + 0.1, st[3] - 0.05),
          label("1,000 m UNDERGROUND", st[4] + 0.2, st[5])]
    cues = digs(st[1], st[2]) + [(st[3], "sfx_impact.wav", 0.6), (st[4], "sfx_whoosh_down.wav", 0.8)] + digs(st[4] + 0.3, st[5], 0.7, 0.3)
    make("01_mom_said_go_outside", segs, ov, cues)


@skit
def _02_she_said_she_would_wait():
    segs = [Seg("sk_gf_where", 0.3, 3.8, vw(0.52)),
            Seg("sk_abyss_almost", 0.5, 5.5, vw(0.5), flash_in=True),
            Seg("sk_abyss_plain", 0.0, 1.4, black),
            Seg("sk_abyss_plain", 1.0, 4.5, vw(0.5), flash_in=True)]
    st = starts(segs)
    ov = [hook("she said she'd wait for me\nat the surface", st[1] + 0.8),
          label("1,000 m DOWN", st[1] + 0.3, st[2]),
          mid("he was NOT\nalmost there", st[2] + 0.1, st[3] - 0.05),
          label("STILL DIGGING…", st[3] + 0.2, st[4])]
    cues = [(st[1], "sfx_whoosh_down.wav", 0.8)] + digs(st[1] + 0.3, st[2], 0.7, 0.3) + digs(st[3] + 0.2, st[4], 0.7, 0.3)
    make("02_she_said_she_would_wait", segs, ov, cues)


@skit
def _03_dad_went_to_get_milk():
    segs = [Seg("rec_basic_dig", 12.0, 3.4, vw(0.5, 1.1), speed=1.6),
            Seg("sk_cave_dad", 0.2, 5.0, vw(0.5), flash_in=True),
            Seg("sk_cave_box", 0.0, 3.8, vw(0.5))]
    st = starts(segs)
    ov = [hook("dad went to get milk\n10 years ago", st[1]),
          label("so I started digging", 0.2, st[1] - 0.05, WHITE, 70),
          label("…all I found was his old box", st[2] + 0.2, st[3], WHITE, 64)]
    cues = digs(0.0, st[1]) + [(st[1], "sfx_whoosh_down.wav", 0.8), (st[2] + 0.3, "sfx_legendary_shimmer.wav", 0.6)]
    make("03_dad_went_to_get_milk", segs, ov, cues)


@skit
def _04_just_one_more_block():
    segs = [Seg("sk_one_more", 0.2, 3.4, vw(0.5)),
            Seg("sk_abyss_plain", 0.0, 1.3, black),
            Seg("sk_abyss_plain", 0.6, 5.6, vw(0.5), flash_in=True)]
    st = starts(segs)
    ov = [hook("me at 2 AM:", st[1]),
          mid("6 HOURS LATER…", st[1] + 0.1, st[2] - 0.05),
          label("ZONE 6 · THE ABYSS", st[2] + 0.2, st[3]),
          label("1,000 m", st[2] + 0.2, st[3], GOLD, 64, WIN_Y + 140)]
    cues = digs(0.0, st[1], 0.6) + [(st[2], "sfx_impact.wav", 0.7)] + digs(st[2] + 0.3, st[3], 0.7, 0.3)
    make("04_just_one_more_block", segs, ov, cues)


@skit
def _05_friend_said_boring():
    segs = [Seg("sk_friend_boring", 0.2, 4.6, vw(0.56, 1.0, 860)),
            Seg("sk_friend_boring", 4.8, 3.0, vw(0.5, 1.0, 860), flash_in=True)]
    st = starts(segs)
    ov = [hook("my friend: \"this game is boring\"", st[1]),
          label("ABYSS BORER: 81 BLOCKS PER HIT", st[1] + 0.2, st[2], GOLD, 60)]
    cues = [(st[1] + 0.1, "sfx_impact.wav", 0.9), (st[1] + 0.9, "sfx_impact.wav", 0.7), (st[1] + 1.7, "sfx_whoosh_down.wav", 0.8)]
    make("05_friend_said_boring", segs, ov, cues)


@skit
def _06_someone_dug_here_before():
    segs = [Seg("rec_basic_dig", 22.0, 3.2, vw(0.5, 1.1), speed=1.6),
            Seg("sk_cave_who", 0.2, 4.0, vw(0.5), flash_in=True),
            Seg("sk_cave_box", 0.0, 3.6, vw(0.5))]
    st = starts(segs)
    ov = [hook("POV: you find a tunnel\nunder YOUR house", st[1]),
          label("45 m under the garden", st[1] + 0.2, st[2], WHITE, 64),
          label("someone was here before me…", st[2] + 0.2, st[3], WHITE, 60)]
    cues = digs(0.0, st[1]) + [(st[1], "sfx_whoosh_down.wav", 0.8), (st[2] + 0.3, "sfx_legendary_shimmer.wav", 0.5)]
    make("06_someone_dug_here_before", segs, ov, cues)


if __name__ == "__main__":
    ids = sys.argv[1:]
    for k, fn in SKITS.items():
        if ids and not any(k.startswith(i) for i in ids):
            continue
        fn()
