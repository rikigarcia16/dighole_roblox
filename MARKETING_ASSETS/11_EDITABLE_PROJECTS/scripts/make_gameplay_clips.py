"""Fast-edited gameplay clips (20-30 s) for the bottom half of split-screen reels (make_split.py --bottom).
1080x960, 30 fps, with music + sound effects. Real gameplay only; counters show numbers that exist in the game.

Usage: python make_gameplay_clips.py [ids...]
Output: MARKETING_ASSETS/12_FINAL_EXPORTS/gameplay_clips_split/THNE_gp_<id>.mp4
"""
import sys, random
from video import *

W, HH = 1080, 960
OUT = os.path.join(ROOT, "12_FINAL_EXPORTS", "gameplay_clips_split")


# Parts of a recording where the camera is fine (seconds, real time). abyss_action clips into rock after 2.3 s.
USABLE = {"abyss_action": 2.3}


class Shot:
    def __init__(self, name, start, dur, fx=0.5, zoom=1.12, speed=1.0, sfx=None, hits=(), label=None, label_colors=GOLD):
        self.name, self.start, self.dur, self.fx, self.zoom, self.speed = name, start, dur, fx, zoom, speed
        self.sfx, self.hits, self.label, self.label_colors = sfx, hits, label, label_colors


def shake(img, amount):
    if amount < 0.5:
        return img
    dx, dy = random.uniform(-amount, amount), random.uniform(-amount, amount)
    z = 1 + 3.0 * amount / min(W, HH)
    cw, ch = W / z, HH / z
    x0 = (W - cw) / 2 + dx; y0 = (HH - ch) / 2 + dy
    return img.resize((W, HH), Image.BILINEAR, box=(x0, y0, x0 + cw, y0 + ch))


_text_cache = {}


def text_img(s, size, colors):
    k = (s, size, colors)
    if k not in _text_cache:
        im = headline(s, size, colors)
        _text_cache[k] = fit(im, w=980) if im.width > 980 else im
    return _text_cache[k]


def render_clip(cid, shots, counter=None, music="music_short_upbeat_120bpm.wav", music_start=0.0, seed=1):
    """counter: None | ("depth", m0, m1) | ("coins", c0, c1): a number that rises over the clip."""
    random.seed(seed)
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, f"THNE_gp_{cid}.mp4")
    total = sum(s.dur for s in shots)
    starts = np.cumsum([0] + [s.dur for s in shots])
    tmp = out + ".v.mp4"
    cmd = [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{HH}", "-r", str(FPS), "-i", "-",
           "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-movflags", "+faststart", tmp]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    cues = []
    for i, s in enumerate(shots):
        if s.sfx:
            cues.append((starts[i], s.sfx, 0.55))
        for h in s.hits:
            cues.append((starts[i] + h, "sfx_dig_hit.wav", 0.45))
    for f in range(int(round(total * FPS))):
        t = f / FPS
        k = min(int(np.searchsorted(starts, t, side="right") - 1), len(shots) - 1)
        s = shots[k]; lt = t - starts[k]
        c = clip(s.name)
        cap = min(USABLE.get(s.name, 1e9), c.duration - 0.05)
        base = min(s.start, max(0.0, cap - 1.0))
        src = base + lt * s.speed
        if src > cap:  # loop inside the usable part instead of freezing or showing a bad camera
            src = base + (src - base) % max(0.4, cap - base)
        img = land(c.at(src), (s.fx, 0.5), s.zoom, (W, HH))
        # punch zoom + white flash on each cut
        if lt < 0.28:
            z = 1 + 0.16 * (1 - lt / 0.28) ** 2
            cw, ch = W / z, HH / z
            img = img.resize((W, HH), Image.BILINEAR, box=((W - cw) / 2, (HH - ch) / 2, (W + cw) / 2, (HH + ch) / 2))
        if lt < 0.07:
            img = Image.blend(img, Image.new("RGB", img.size, (255, 255, 255)), 0.6 * (1 - lt / 0.07))
        # screen shake right after each hit
        amt = 0.0
        for h in s.hits:
            if 0 <= lt - h < 0.18:
                amt = max(amt, 14 * (1 - (lt - h) / 0.18))
        img = shake(img, amt)
        if s.label:
            img = Overlay(text_img(s.label, 84, s.label_colors), starts[k] + 0.05, starts[k + 1] - 0.03, (W // 2, 70), "tc").draw(img, t)
        if counter:
            kind, a, b = counter
            u = min(1.0, t / max(0.1, total - 0.5))
            v = a + (b - a) * (u ** 1.6)
            if kind == "depth":
                s_txt = f"{int(v // 10 * 10):,} m".replace(",", ".")
                img = place(img, text_img(s_txt, 110, CYAN if v > 150 else GOLD), (W // 2, HH - 40), "bc")
            else:
                s_txt = f"● {int(v):,}".replace(",", ".")
                img = place(img, text_img(s_txt, 100, GOLD), (W // 2, HH - 40), "bc")
        p.stdin.write(img.convert("RGB").tobytes())
    p.stdin.close(); p.wait()
    wav = out + ".a.wav"
    mix_audio(total, wav, cues, music, 0.7, music_start)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", tmp, "-i", wav, "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", out], check=True)
    os.remove(tmp); os.remove(wav)
    print("VIDEO", out, round(total, 1), "s")


CLIPS = {}


def gp(fn):
    CLIPS[fn.__name__[1:]] = fn
    return fn


@gp
def _01_cavar_sin_parar():
    """Digging frenzy: short hits, shakes, labels."""
    sh = []
    for (n, st, fx) in [("dig_surface", 0.5, 0.5), ("mines_action", 1.0, 0.45), ("dig_surface", 4.0, 0.5), ("crystal_action", 3.0, 0.6),
                        ("mines_action", 5.2, 0.45), ("dig_surface", 7.5, 0.5), ("crystal_action", 6.0, 0.6), ("abyss_action", 0.3, 0.5),
                        ("dig_surface", 10.5, 0.5), ("mines_action", 2.8, 0.45), ("crystal_action", 1.0, 0.6), ("abyss_action", 4.0, 0.5),
                        ("dig_surface", 2.2, 0.5), ("mines_action", 7.0, 0.45), ("crystal_action", 7.6, 0.6), ("abyss_action", 6.5, 0.5)]:
        sh.append(Shot(n, st, 1.5, fx, 1.18, speed=1.2, hits=(0.25, 0.85)))
    render_clip("01_cavar_sin_parar", sh, seed=1)


@gp
def _02_hasta_el_fondo():
    """Descent with a depth counter that climbs to 2.200 m."""
    sh = [Shot("plot_crane", 8.0, 1.6, 0.5, 1.0, sfx="sfx_whoosh_down.wav"),
          Shot("descent_b", 0.0, 4.0, 0.5, 1.1, speed=1.3), Shot("mines_action", 5.2, 1.4, 0.45, 1.15, sfx="sfx_impact.wav", hits=(0.3,)),
          Shot("descent_b", 4.0, 3.0, 0.5, 1.1, speed=1.4), Shot("crystal_action", 3.2, 1.4, 0.6, 1.15, sfx="sfx_impact.wav", hits=(0.3,)),
          Shot("descent_b", 6.5, 3.0, 0.5, 1.1, speed=1.5), Shot("abyss_action", 0.2, 1.6, 0.5, 1.15, sfx="sfx_impact.wav", hits=(0.3,)),
          Shot("descent_b", 8.6, 2.2, 0.5, 1.1, speed=1.2), Shot("abyss_action", 4.0, 2.4, 0.5, 1.2, sfx="sfx_whoosh_down.wav"),
          Shot("descent_b", 2.0, 3.0, 0.5, 1.1, speed=1.6), Shot("abyss_action", 7.0, 2.0, 0.5, 1.15, sfx="sfx_impact.wav")]
    render_clip("02_hasta_el_fondo", sh, counter=("depth", 0, 2200), seed=2)


@gp
def _03_mineral_legendario():
    """Build-up of fast hits, then the legendary find."""
    sh = [Shot(n, st, 1.0, fx, 1.18, speed=1.3, hits=(0.2, 0.6)) for (n, st, fx) in
          [("crystal_action", 1.0, 0.6), ("abyss_action", 0.5, 0.5), ("crystal_action", 4.0, 0.6), ("mines_action", 5.0, 0.45),
           ("abyss_action", 3.0, 0.5), ("crystal_action", 6.5, 0.6), ("abyss_action", 5.5, 0.5), ("crystal_action", 2.2, 0.6)]]
    sh[0].label = "¿QUÉ SALDRÁ?"
    sh += [Shot("legendary_ui", 1.8, 5.0, 0.5, 1.0, sfx="sfx_legendary_shimmer.wav", label="¡LEGENDARIO!", label_colors=CYAN),
           Shot("abyss_action", 7.0, 1.4, 0.5, 1.15, hits=(0.3,)), Shot("crystal_action", 7.8, 1.4, 0.6, 1.15, hits=(0.3,)),
           Shot("legendary_ui", 4.0, 4.0, 0.5, 1.1, sfx="sfx_legendary_shimmer.wav"),
           Shot("showcase_ui", 2.0, 3.0, 0.45, 1.15, sfx="sfx_whoosh_up.wav")]
    render_clip("03_mineral_legendario", sh, music="music_mystery_depths_90bpm.wav", music_start=10, seed=3)


@gp
def _04_cavar_y_vender():
    """Dig -> sell loop (no invented coin totals: the real sale UI shows the amounts)."""
    sh = []
    for r in range(3):
        sh += [Shot("dig_surface", 0.5 + r * 4.0, 1.3, 0.5, 1.18, speed=1.4, hits=(0.2, 0.7)),
               Shot("mines_action", 1.0 + r * 2.5, 1.2, 0.45, 1.18, speed=1.3, hits=(0.3,)),
               Shot("crystal_action", 2.0 + r * 2.0, 1.2, 0.6, 1.18, speed=1.3, hits=(0.3,)),
               Shot("sell_ui", 1.2 + r * 1.5, 2.6, 0.52, 1.0, sfx="sfx_coin.wav")]
    sh.append(Shot("showcase_ui", 2.0, 2.6, 0.45, 1.15, sfx="sfx_legendary_shimmer.wav", label="¡MEJORA!"))
    render_clip("04_cavar_y_vender", sh, seed=4)


@gp
def _05_las_7_zonas():
    zones = [("plot_crane", 8.5, 0.5, "EL JARDÍN"), ("mines_action", 5.4, 0.45, "MINAS OLVIDADAS"), ("crystal_action", 3.4, 0.6, "CUEVAS DE CRISTAL"),
             ("descent_b", 5.4, 0.5, "CAVERNAS ANTIGUAS"), ("descent_b", 7.4, 0.5, "PROFUNDIDADES VOLCÁNICAS"), ("abyss_action", 0.2, 0.5, "EL ABISMO"),
             ("descent_b", 9.9, 0.5, "???")]
    sh = []
    for i, (n, st, fx, lab) in enumerate(zones):
        sh.append(Shot(n, st, 2.2, fx, 1.12, sfx="sfx_whoosh_down.wav", label=lab, label_colors=CYAN if i >= 2 else GOLD))
        sh.append(Shot(["dig_surface", "mines_action", "crystal_action", "mines_action", "abyss_action", "abyss_action", "abyss_action"][i],
                       [2.0, 1.0, 6.0, 3.0, 5.5, 3.0, 7.0][i], 1.4, 0.5, 1.2, speed=1.3, hits=(0.25, 0.8)))
    render_clip("05_las_7_zonas", sh, counter=("depth", 0, 2200), seed=5)


@gp
def _06_mezcla_rapida():
    """Pure montage on the beat (0.5 s / 1 s cuts at 120 bpm)."""
    pool = [("dig_surface", 1.0, 0.5), ("mines_action", 1.0, 0.45), ("crystal_action", 3.0, 0.6), ("abyss_action", 0.3, 0.5),
            ("descent_b", 4.0, 0.5), ("legendary_ui", 2.6, 0.5), ("sell_ui", 1.4, 0.52), ("plot_crane", 7.5, 0.5),
            ("surface_hero", 1.5, 0.55), ("garage_pan", 4.5, 0.5), ("showcase_ui", 2.0, 0.45), ("crystal_action", 6.0, 0.6)]
    rng = random.Random(6)
    sh, t, prev = [], 0.0, None
    while t < 26:
        n, st, fx = rng.choice([x for x in pool if x != prev])
        d = 0.5 if rng.random() < 0.55 else 1.0
        sh.append(Shot(n, st + rng.uniform(0, 1.5), d, fx, 1.15, speed=1.2, sfx="sfx_whoosh_up.wav" if d == 1.0 else None,
                       hits=(0.15,) if n in ("dig_surface", "mines_action", "crystal_action", "abyss_action") else ()))
        t += d; prev = (n, st, fx)
    render_clip("06_mezcla_rapida", sh, seed=6)


# ---------------------------------------------------------------- clips from the 10 Nov recordings
# Times are seconds into each recording. Every recording starts ~1 s before the first hit.
H2 = (0.15, 0.85)  # one hit every 0.7 s


@gp
def _07_zona_tras_zona():
    """Every zone banner, back to back (the HUD shows the real depth)."""
    sh = [Shot("rec_surface_borer", 1.2, 1.6, 0.5, 1.05, sfx="sfx_impact.wav", hits=H2),
          Shot("rec_borer_shaft", 7.6, 3.0, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_crystal", 2.6, 3.2, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_caverns", 2.6, 3.2, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_volcanic", 2.6, 3.4, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_abyss", 3.0, 4.0, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25, 2.95)),
          Shot("rec_zone_abyss", 8.0, 3.6, 0.5, 1.12, sfx="sfx_legendary_shimmer.wav", hits=H2)]
    render_clip("07_zona_tras_zona", sh, seed=7)


@gp
def _08_perforadora_abisal():
    """The top tool tearing through the ground: hits, loot popping, shakes."""
    sh = [Shot("rec_surface_borer", 1.0, 2.2, 0.5, 1.0, sfx="sfx_impact.wav", hits=H2 + (1.55,), label="POTENCIA 85"),
          Shot("rec_borer_shaft", 1.2, 4.0, 0.5, 1.1, hits=H2 + (1.55, 2.25, 2.95, 3.65)),
          Shot("rec_zone_crystal", 1.2, 2.4, 0.5, 1.12, hits=H2 + (1.55,)),
          Shot("rec_borer_shaft", 5.2, 3.0, 0.5, 1.1, hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_caverns", 5.0, 2.8, 0.5, 1.12, hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_volcanic", 5.4, 2.8, 0.5, 1.12, hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_abyss", 5.0, 3.0, 0.5, 1.12, hits=H2 + (1.55, 2.25)),
          Shot("rec_borer_shaft", 9.6, 2.4, 0.5, 1.1, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55,))]
    render_clip("08_perforadora_abisal", sh, seed=8)


@gp
def _09_epico_y_legendario():
    """Only the EPIC / LEGENDARY moments, fast."""
    sh = [Shot("rec_zone_caverns", 6.2, 1.8, 0.5, 1.1, hits=H2, label="¿QUÉ SALDRÁ?"),
          Shot("rec_zone_caverns", 8.0, 3.2, 0.5, 1.1, sfx="sfx_legendary_shimmer.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_volcanic", 3.6, 2.6, 0.5, 1.1, sfx="sfx_legendary_shimmer.wav", hits=H2 + (1.55,)),
          Shot("rec_zone_volcanic", 7.0, 3.6, 0.5, 1.1, sfx="sfx_legendary_shimmer.wav", hits=H2 + (1.55, 2.25, 2.95)),
          Shot("rec_zone_crystal", 4.0, 2.4, 0.5, 1.1, sfx="sfx_legendary_shimmer.wav", hits=H2 + (1.55,)),
          Shot("rec_zone_abyss", 3.2, 3.0, 0.5, 1.1, sfx="sfx_legendary_shimmer.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_abyss", 7.6, 4.0, 0.5, 1.1, sfx="sfx_legendary_shimmer.wav", hits=H2 + (1.55, 2.25, 2.95))]
    render_clip("09_epico_y_legendario", sh, music="music_mystery_depths_90bpm.wav", music_start=6, seed=9)


@gp
def _10_del_jardin_al_abismo():
    """Chronological: garden -> mines -> crystal -> caverns -> volcanic -> abyss, quicker every zone."""
    sh = [Shot("rec_surface_borer", 1.0, 2.0, 0.5, 1.0, sfx="sfx_impact.wav", hits=H2),
          Shot("rec_borer_shaft", 2.0, 2.0, 0.5, 1.08, hits=H2 + (1.55,)),
          Shot("rec_borer_shaft", 8.2, 3.0, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_crystal", 2.8, 3.4, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25, 2.95)),
          Shot("rec_zone_caverns", 2.8, 3.0, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_volcanic", 2.8, 3.0, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25)),
          Shot("rec_zone_abyss", 3.0, 4.2, 0.5, 1.05, sfx="sfx_whoosh_down.wav", hits=H2 + (1.55, 2.25, 2.95)),
          Shot("rec_zone_abyss", 9.0, 2.6, 0.5, 1.12, sfx="sfx_legendary_shimmer.wav", hits=H2)]
    render_clip("10_del_jardin_al_abismo", sh, seed=10)


if __name__ == "__main__":
    ids = sys.argv[1:]
    for k, fn in CLIPS.items():
        if ids and not any(k.startswith(i) for i in ids):
            continue
        fn()
