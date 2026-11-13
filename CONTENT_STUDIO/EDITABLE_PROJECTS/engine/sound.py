"""Bottomless sound library v2: original SFX and music beds synthesised with numpy (no samples, no
third-party audio). Builds CONTENT_STUDIO/AUDIO/{sfx,music}/*.wav.  python sound.py"""
import os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "..", "MARKETING_ASSETS", "11_EDITABLE_PROJECTS", "scripts")))
import synth as S  # reuse the oscillators, envelopes and filters from the first sound kit

SR = S.SR
AUDIO = os.path.normpath(os.path.join(HERE, "..", "..", "AUDIO"))
rng = np.random.default_rng(11)


def t_(d):
    return np.arange(int(d * SR)) / SR


def noise(d):
    return rng.standard_normal(int(d * SR))


def stereo(x, width=0.0):
    if width <= 0:
        return np.stack([x, x], 1)
    d = int(0.012 * SR)
    r = np.concatenate([np.zeros(d), x[:-d]])
    return np.stack([x, (1 - width) * x + width * r], 1)


def fade(x, a=0.005, r=0.05):
    a_n, r_n = int(a * SR), int(r * SR)
    x = x.copy()
    if a_n: x[:a_n] *= np.linspace(0, 1, a_n)
    if r_n: x[-r_n:] *= np.linspace(1, 0, r_n)
    return x


# ---------------------------------------------------------------------------------- sound effects
def riser(d=1.6):
    t = t_(d)
    f = 200 * (8 ** (t / d))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.25
    n = S.hp_fast(noise(d), 1500) * (t / d) ** 2 * 0.5
    return fade((tone + n) * (t / d) ** 1.5, 0.01, 0.02)


def sub_boom(d=1.8):
    t = t_(d)
    f = 70 * np.exp(-t * 2.2) + 32
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 2.4)
    x += S.lp_fast(noise(d), 400) * np.exp(-t * 9) * 0.6
    return fade(x, 0.002, 0.2)


def tick():
    t = t_(0.05)
    return np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 120) * 0.6


def tock():
    t = t_(0.08)
    return np.sin(2 * np.pi * 900 * t) * np.exp(-t * 70) * 0.7


def key_click():
    t = t_(0.06)
    x = S.hp_fast(noise(0.06), 2500) * np.exp(-t * 90) * 0.5 + np.sin(2 * np.pi * 180 * t) * np.exp(-t * 60) * 0.4
    return x


def pencil(d=0.9):
    t = t_(d)
    x = S.hp_fast(noise(d), 3500) * 0.18
    strokes = (np.sin(2 * np.pi * 7 * t) > 0.2).astype(float)
    return fade(x * strokes * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * t) ** 2), 0.02, 0.1)


def stamp():
    t = t_(0.5)
    body = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 18)
    slap = S.lp_fast(noise(0.5), 2200) * np.exp(-t * 35)
    return fade(body * 0.9 + slap * 0.8, 0.001, 0.05)


def ding():
    return fade(S.bell(S.note(84), 1.4) * 0.8 + S.bell(S.note(91), 1.4) * 0.3, 0.001, 0.2)


def glass(seed=0):
    r = np.random.default_rng(seed)
    t = t_(0.9)
    x = np.zeros_like(t)
    for k in range(6):
        f = r.uniform(1800, 5200)
        x += np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * np.exp(-t * r.uniform(6, 14)) * r.uniform(0.1, 0.3)
    x += S.hp_fast(noise(0.9), 3000) * np.exp(-t * 30) * 0.5
    return fade(x, 0.001, 0.1)


def knock():
    t = t_(0.35)
    x = np.sin(2 * np.pi * 95 * t) * np.exp(-t * 22) + S.lp_fast(noise(0.35), 900) * np.exp(-t * 40) * 0.7
    return fade(x, 0.001, 0.05)


def gears(d=2.5):
    t = t_(d)
    x = np.zeros_like(t)
    for k in range(int(d * 9)):
        s = int((k / 9 + rng.uniform(0, 0.03)) * SR)
        c = key_click() * rng.uniform(0.5, 1.0)
        x[s:s + len(c)] += c[: len(x) - s]
    hum = np.sin(2 * np.pi * 55 * t) * 0.15
    return fade(x * 0.7 + hum, 0.2, 0.3)


def drill(d=2.0):
    t = t_(d)
    f = 95 + 8 * np.sin(2 * np.pi * 6 * t)
    x = S.saw(f, t) * 0.25 + S.lp_fast(noise(d), 1200) * 0.35
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * 31 * t)
    return fade(x, 0.05, 0.15)


def shovel():
    return fade(S.dig_hit() * 0.9 + knock()[: len(S.dig_hit())] * 0.0, 0.001, 0.03)


def pop():
    t = t_(0.18)
    f = 500 + 900 * np.exp(-t * 30)
    return fade(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 20) * 0.6, 0.001, 0.02)


def wind(d=8.0):
    x = S.lp_fast(noise(d), 500) * 0.35
    t = t_(d)
    return fade(x * (0.6 + 0.4 * np.sin(2 * np.pi * 0.15 * t)), 0.5, 0.8)


def birds(d=8.0):
    t = t_(d)
    x = wind(d) * 0.5
    for k in range(int(d * 1.3)):
        s = rng.uniform(0, d - 0.4)
        n = int(0.25 * SR); tt = np.arange(n) / SR
        f = rng.uniform(2800, 4200) + 600 * np.sin(2 * np.pi * rng.uniform(15, 30) * tt)
        chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 14) * 0.12
        i = int(s * SR); x[i:i + n] += chirp[: len(x) - i]
    return x


def drone(d=10.0, root=41):
    t = t_(d)
    x = sum(np.sin(2 * np.pi * S.note(root + o) * t + o) * g for o, g in [(0, 0.35), (7, 0.18), (12, 0.12), (19, 0.05)])
    x *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * t)
    return fade(S.lp_fast(x + S.lp_fast(noise(d), 300) * 0.08, 900), 1.0, 1.5)


# ------------------------------------------------------------------------------------ music beds
def bed_cinematic(d=36.0):
    """Slow pad that swells in steps (one per layer of the descent)."""
    prog = [(45, 52, 57, 60), (41, 48, 53, 57), (43, 50, 55, 59), (40, 47, 52, 55)]
    seg = d / 8
    out = np.zeros(int(d * SR))
    for i in range(8):
        chord = prog[i % 4]
        p = S.pad([S.note(n) for n in chord], seg + 1.0, cutoff=900 + i * 250) * (0.35 + i * 0.05)
        S.place(out, p, i * seg)
    out += drone(d, 33) * 0.6
    return S.reverb(fade(out, 1.5, 2.5), 0.3, 2.5)


def bed_comedy(d=30.0, bpm=104):
    beat = 60 / bpm
    out = np.zeros(int(d * SR))
    notes = [60, 64, 67, 64, 62, 65, 69, 65]
    k = 0; t0 = 0.0
    while t0 < d - 0.5:
        S.place(out, S.pluck(S.note(notes[k % 8]), 0.3, 3000) * 0.35, t0)
        if k % 2 == 0:
            S.place(out, S.bass(S.note(36 + (0 if (k // 8) % 2 == 0 else 5)), beat * 1.6) * 0.4, t0)
        if k % 4 == 2:
            S.place(out, S.hat(0.06) * 0.25, t0)
        t0 += beat / 2; k += 1
    return fade(out, 0.05, 1.0)


def bed_mystery(d=36.0):
    out = drone(d, 38) * 0.9
    t = 0.0
    while t < d - 3:
        for j in range(3):  # three knocks, a pause (E.'s rhythm)
            S.place(out, knock() * 0.5, t + j * 0.42)
        t += 3.2
    return S.reverb(fade(out, 1.0, 2.0), 0.35, 2.2)


def bed_satisfying(d=20.0, bpm=90):
    beat = 60 / bpm
    out = np.zeros(int(d * SR))
    t = 0.0; k = 0
    while t < d:
        S.place(out, S.bell(S.note([72, 76, 79, 83][k % 4]), 1.6) * 0.18, t)
        t += beat * 2; k += 1
    out += S.pad([S.note(n) for n in (48, 55, 59, 64)], d, 700) * 0.18
    return S.reverb(fade(out, 0.8, 1.5), 0.4, 2.8)


def bed_challenge(d=30.0, bpm=128):
    beat = 60 / bpm
    out = np.zeros(int(d * SR))
    t = 0.0; k = 0
    while t < d:
        S.place(out, S.kick(0.35) * 0.5, t)
        S.place(out, tick() * 0.4, t + beat / 2)
        if k % 2 == 1: S.place(out, S.snare(0.2) * 0.25, t)
        S.place(out, S.bass(S.note(33 + [0, 0, 3, 5][(k // 4) % 4]), beat * 0.9) * 0.35, t)
        t += beat; k += 1
    return fade(out, 0.05, 1.0)


def bed_quiz(d=20.0, bpm=116):
    beat = 60 / bpm
    out = np.zeros(int(d * SR))
    t = 0.0; k = 0
    while t < d:
        S.place(out, S.pluck(S.note([67, 71, 74, 71][k % 4]), 0.25, 3500) * 0.28, t)
        if k % 2 == 0: S.place(out, S.kick(0.3) * 0.3, t)
        t += beat / 2; k += 1
    return fade(out, 0.05, 1.0)


SFX = dict(riser=riser, sub_boom=sub_boom, tick=tick, tock=tock, key=key_click, pencil=pencil, stamp=stamp, ding=ding,
           glass_a=lambda: glass(1), glass_b=lambda: glass(2), glass_c=lambda: glass(3), knock=knock, gears=gears,
           drill=drill, shovel=shovel, pop=pop, wind=wind, birds=birds, drone=drone,
           whoosh_down=lambda: S.whoosh(0.9, up=False), whoosh_up=lambda: S.whoosh(0.7, up=True), impact=S.impact)
MUSIC = dict(cinematic=bed_cinematic, comedy=bed_comedy, mystery=bed_mystery, satisfying=bed_satisfying,
             challenge=bed_challenge, quiz=bed_quiz)


def build():
    for sub, table in (("sfx", SFX), ("music", MUSIC)):
        os.makedirs(os.path.join(AUDIO, sub), exist_ok=True)
        for name, fn in table.items():
            x = fn()
            x = S.norm(x, 0.85 if sub == "sfx" else 0.6)
            S.write(os.path.join(AUDIO, sub, name + ".wav"), stereo(x, 0.4) if x.ndim == 1 else x)
    print("audio library in", AUDIO)


if __name__ == "__main__":
    build()
