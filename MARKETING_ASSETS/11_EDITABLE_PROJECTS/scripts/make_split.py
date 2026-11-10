"""Split-screen reels (1080x1920): any clip you provide on top, fast-cut real gameplay below.

The top clip is yours: you choose it and you are responsible for having the right to use it.
Only the top clip is heard by default (--game-audio adds the game music and effects).

Usage:
  python make_split.py TOP_CLIP.mp4 [--text "TEXTO DEL GANCHO"] [--seed 3] [--max 60] [--name nombre]
  python make_split.py CARPETA_CON_CLIPS/        (one reel per video in the folder)
  --bottom CLIP.mp4   use one of the edited gameplay clips (12_FINAL_EXPORTS/gameplay_clips_split) below
                      instead of the automatic cuts; "auto-gp" picks a different one for each reel

Output: MARKETING_ASSETS/12_FINAL_EXPORTS/reels_split/THNE_split_<nombre>.mp4
"""
import argparse, random, glob
from PIL import ImageDraw
from video import *

W, H = 1080, 1920
TOP_H = 1100           # top clip area (bigger than half: the clip is the hook)
HALF = H - TOP_H       # gameplay area height (name kept for the helpers below)
OUT_DIR = os.path.join(ROOT, "12_FINAL_EXPORTS", "reels_split")

# Best moments of the recorded gameplay: (clip, start s, focus x, zoom, sound on the cut)
# The rec_* recordings (abyss borer through every zone, loot popping, zone banners) are the most
# intense footage, so they are weighted x3.
REC_MOMENTS = [
    ("rec_borer_shaft", 1.5, 0.5, 1.3, None), ("rec_borer_shaft", 4.5, 0.5, 1.3, None), ("rec_borer_shaft", 8.4, 0.5, 1.3, None),
    ("rec_zone_crystal", 2.8, 0.5, 1.3, None), ("rec_zone_crystal", 4.2, 0.5, 1.3, None), ("rec_zone_crystal", 7.5, 0.5, 1.3, None),
    ("rec_zone_caverns", 2.8, 0.5, 1.3, None), ("rec_zone_caverns", 7.8, 0.5, 1.3, None), ("rec_zone_caverns", 9.2, 0.5, 1.3, None),
    ("rec_zone_volcanic", 2.8, 0.5, 1.3, None), ("rec_zone_volcanic", 7.4, 0.5, 1.3, None), ("rec_zone_volcanic", 9.0, 0.5, 1.3, None),
    ("rec_zone_abyss", 3.0, 0.5, 1.3, None), ("rec_zone_abyss", 8.0, 0.5, 1.3, None), ("rec_zone_abyss", 10.0, 0.5, 1.3, None),
    ("rec_surface_borer", 1.2, 0.5, 1.3, None),
]
MOMENTS = REC_MOMENTS * 3 + [
    ("dig_surface", 1.0, 0.5, 1.15, "sfx_dig_hit.wav"),
    ("dig_surface", 4.5, 0.5, 1.15, "sfx_dig_hit.wav"),
    ("dig_surface", 8.0, 0.5, 1.15, "sfx_dig_hit.wav"),
    ("descent_b", 0.5, 0.5, 1.1, "sfx_whoosh_down.wav"),
    ("descent_b", 4.0, 0.5, 1.1, "sfx_whoosh_down.wav"),
    ("descent_b", 7.5, 0.5, 1.1, "sfx_whoosh_down.wav"),
    ("mines_action", 1.0, 0.45, 1.1, "sfx_dig_hit.wav"),
    ("mines_action", 5.2, 0.45, 1.1, "sfx_dig_hit.wav"),
    ("crystal_action", 3.0, 0.6, 1.1, "sfx_dig_hit.wav"),
    ("crystal_action", 6.0, 0.6, 1.1, "sfx_dig_hit.wav"),
    ("abyss_action", 0.2, 0.5, 1.1, "sfx_impact.wav"),
    ("abyss_action", 1.0, 0.5, 1.2, "sfx_impact.wav"),
    ("legendary_ui", 2.6, 0.5, 1.0, "sfx_legendary_shimmer.wav"),
    ("sell_ui", 1.4, 0.52, 1.0, "sfx_coin.wav"),
    ("showcase_ui", 2.0, 0.45, 1.15, "sfx_legendary_shimmer.wav"),
    ("plot_crane", 7.5, 0.5, 1.0, "sfx_whoosh_down.wav"),
    ("surface_hero", 1.5, 0.55, 1.0, "sfx_whoosh_up.wav"),
]


def probe_duration(path):
    r = subprocess.run([FFMPEG, "-i", path], capture_output=True, text=True)
    for line in r.stderr.splitlines():
        if "Duration:" in line:
            h, m, s = line.split("Duration:")[1].split(",")[0].strip().split(":")
            return int(h) * 3600 + int(m) * 60 + float(s)
    raise SystemExit(f"No puedo leer el vídeo: {path}")


def top_frames(path, dur):
    """Yield the top clip as 1080xTOP_H RGB frames at 30 fps (scaled to fill, centre-cropped)."""
    cmd = [FFMPEG, "-loglevel", "error", "-i", path, "-t", f"{dur:.3f}",
           "-vf", f"fps={FPS},scale={W}:{TOP_H}:force_original_aspect_ratio=increase,crop={W}:{TOP_H}",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = W * TOP_H * 3
    last = None
    while True:
        b = p.stdout.read(size)
        if len(b) < size:
            break
        last = Image.frombytes("RGB", (W, TOP_H), b)
        yield last
    p.wait()
    while True:  # pad if the decoder delivered fewer frames than expected
        yield last if last is not None else Image.new("RGB", (W, TOP_H))


def top_audio(path, dur, out_wav):
    r = subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", path, "-t", f"{dur:.3f}", "-vn",
                        "-ac", "2", "-ar", "48000", "-c:a", "pcm_s16le", out_wav])
    return r.returncode == 0 and os.path.exists(out_wav) and os.path.getsize(out_wav) > 1000


def bottom_plan(dur, seed):
    """Very fast cuts: 0.55-1.0 s each, never the same moment twice in a row."""
    rng = random.Random(seed)
    plan, t, prev = [], 0.0, None
    while t < dur:
        m = rng.choice([x for x in MOMENTS if x != prev])
        d = min(rng.uniform(0.55, 1.0), dur - t)
        plan.append((t, d, m))
        t += d; prev = m
    return plan


def bottom_frame(plan_item, lt):
    t0, d, (name, start, fx, zoom, _) = plan_item
    c = clip(name)
    cap = 2.3 if name == "abyss_action" else c.duration - 0.05  # abyss_action: camera enters rock after 2.3 s
    img = land(c.at(min(start + lt * 1.25, cap)), (fx, 0.5), zoom, (W, HALF))
    if lt < 0.3:  # strong zoom punch + small shake on every cut
        z = 1 + 0.22 * (1 - lt / 0.3) ** 2
        cw, ch = W / z, HALF / z
        img = img.resize((W, HALF), Image.BILINEAR, box=((W - cw) / 2, (HALF - ch) / 2, (W + cw) / 2, (HALF + ch) / 2))
        dx = random.uniform(-10, 10) * (1 - lt / 0.3)
        img = img.transform(img.size, Image.AFFINE, (1, 0, dx, 0, 1, dx * 0.6), Image.BILINEAR)
    if lt < 0.08:
        img = Image.blend(img, Image.new("RGB", img.size, (255, 255, 255)), 0.55 * (1 - lt / 0.08))
    return img


TXT = {
    "es": {"cta": "BÚSCALO EN ROBLOX", "sub": "Gratis · Enlace en la bio", "what": "¿QUÉ JUEGO ES ESTE?"},
    "en": {"cta": "SEARCH IT ON ROBLOX", "sub": "Free · Link in bio", "what": "WHAT GAME IS THIS?"},
}


def end_panel(lang="es"):
    bg = ImageEnhance.Brightness(land(clip("plot_crane").at(9.5), (0.5, 0.5), 1.0, (W, HALF)).filter(ImageFilter.GaussianBlur(10))).enhance(0.45)
    bg = place(bg, fit(logo("main_en", "oscuro"), h=int(HALF * 0.55)), (W // 2, 40), "tc")
    bg = place(bg, pill(TXT[lang]["cta"], 60, bg=(120, 220, 90)), (W // 2, int(HALF * 0.74)), "cc")
    return place(bg, body_text(TXT[lang]["sub"], 40, (255, 255, 255), stroke=4), (W // 2, int(HALF * 0.88)), "cc")


# ------------------------------------------------------------------ captions (word by word)
YELLOW = ((255, 236, 60), (255, 200, 20))
CAP_SIZE = 76
_word_cache = {}


def load_words(top_path):
    """Words from transcribe.py (TOP.words.json next to the clip), or [] if there is no transcript."""
    p = os.path.splitext(top_path)[0] + ".words.json"
    if not os.path.exists(p):
        return []
    return [w for w in json.load(open(p, encoding="utf-8")) if w["w"].strip()]


def chunk_words(words, max_words=3, gap=0.45):
    """Groups of up to 3 words; a new group starts after punctuation or a pause."""
    chunks, cur = [], []
    for w in words:
        if cur and (len(cur) >= max_words or w["s"] - cur[-1]["e"] > gap or cur[-1]["w"][-1:] in ".,!?"):
            chunks.append(cur); cur = []
        cur.append(w)
    if cur:
        chunks.append(cur)
    return chunks


def word_img(text, colors):
    k = (text, colors)
    if k not in _word_cache:
        _word_cache[k] = headline(text, CAP_SIZE, colors)
    return _word_cache[k]


def caption_img(chunk, active):
    """The group in white with the word being spoken in yellow, slightly bigger."""
    parts = []
    for i, w in enumerate(chunk):
        txt = w["w"].upper().strip(",")
        im = word_img(txt, YELLOW if i == active else WHITE)
        if i == active:
            im = im.resize((int(im.width * 1.12), int(im.height * 1.12)), Image.LANCZOS)
        parts.append(im)
    gapx = 14
    wd = sum(p.width for p in parts) + gapx * (len(parts) - 1)
    ht = max(p.height for p in parts)
    out = Image.new("RGBA", (wd, ht), (0, 0, 0, 0))
    x = 0
    for p in parts:
        out.alpha_composite(p, (x, (ht - p.height) // 2)); x += p.width + gapx
    return fit(out, w=1000) if out.width > 1000 else out


def draw_caption(frame, chunks, t):
    for ch in chunks:
        if ch[0]["s"] - 0.05 <= t <= ch[-1]["e"] + 0.15:
            active = max([i for i, w in enumerate(ch) if w["s"] - 0.05 <= t] or [0])
            im = caption_img(ch, active)
            u = (t - ch[0]["s"]) / 0.12  # pop on each new group
            if u < 1:
                s = 0.8 + 0.2 * max(0.0, u)
                im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.BILINEAR)
            return place(frame, im, (W // 2, TOP_H - 210), "cc")
    return frame


GP_DIR = os.path.join(ROOT, "12_FINAL_EXPORTS", "gameplay_clips_split")


def basic_frames(seed, dur, speed=1.1):
    """Plain continuous gameplay (rec_basic_dig): no cuts, no effects, like someone just playing.
    Each reel starts at a different point of the take so the bottoms do not repeat."""
    c = clip("rec_basic_dig")
    span = c.duration - 4.0
    start = 3.0 + ((seed * 17.3) % max(1.0, span - dur * speed))
    t = 0.0
    while True:
        src = start + t * speed
        if src > c.duration - 0.1:  # wrap if a reel is longer than the take
            src = 3.0 + (src - 3.0) % (c.duration - 3.1)
        yield land(c.at(src), (0.5, 0.5), 1.25, (W, HALF))
        t += 1.0 / FPS


def bottom_frames(path, dur):
    """Edited gameplay clip as 1080x960 frames, looped if shorter than the top clip."""
    while True:
        n = 0
        for im in top_frames_once(path):
            yield im
            n += 1
        if n == 0:
            raise SystemExit(f"No puedo leer el vídeo de abajo: {path}")


def top_frames_once(path):
    # "fatal": the decoder is closed early on purpose when the reel ends (broken pipe is expected)
    cmd = [FFMPEG, "-loglevel", "fatal", "-i", path,
           "-vf", f"fps={FPS},scale={W}:{HALF}:force_original_aspect_ratio=increase,crop={W}:{HALF}",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = W * HALF * 3
    while True:
        b = p.stdout.read(size)
        if len(b) < size:
            break
        yield Image.frombytes("RGB", (W, HALF), b)
    p.wait()


def make(top_path, text=None, seed=1, max_s=60.0, name=None, end_s=1.6, bottom=None, game_audio=False, lang="es", captions=True):
    dur = min(probe_duration(top_path), max_s)
    name = name or os.path.splitext(os.path.basename(top_path))[0]
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, f"THNE_split_{name}.mp4")
    tmp_v, tmp_a, tmp_mix = out + ".v.mp4", out + ".top.wav", out + ".mix.wav"

    plan = bottom_plan(dur, seed)
    tag = pill("THE HOLE NEVER ENDS · ROBLOX", 30, bg=(255, 196, 40))
    hook_img = fit(headline(text, 84, YELLOW), w=980) if text else None
    card = end_panel(lang)
    chunks = chunk_words(load_words(top_path)) if captions else []
    # "What game is this?" over the gameplay, around the middle of the reel
    what = pill(TXT[lang]["what"], 46, bg=(255, 255, 255))
    what_t0 = max(3.2, dur * 0.42); what_t1 = min(dur - end_s - 0.2, what_t0 + 2.4)

    cmd = [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-movflags", "+faststart", tmp_v]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    tops = top_frames(top_path, dur)
    if bottom == "basic":
        bots = basic_frames(seed, dur)
        bottom = None
    else:
        bots = bottom_frames(bottom, dur) if bottom else None
    n = int(round(dur * FPS)); k = 0
    for f in range(n):
        t = f / FPS
        while k + 1 < len(plan) and t >= plan[k + 1][0]:
            k += 1
        frame = Image.new("RGB", (W, H))
        top = next(tops)
        z = 1 + 0.05 * (t / max(dur, 0.1))  # slow push-in keeps the top alive
        cw, ch = W / z, TOP_H / z
        top = top.resize((W, TOP_H), Image.BILINEAR, box=((W - cw) / 2, (TOP_H - ch) / 2, (W + cw) / 2, (TOP_H + ch) / 2))
        frame.paste(top, (0, 0))
        if t > dur - end_s:
            frame.paste(card, (0, TOP_H))
        else:
            frame.paste(next(bots) if bots else bottom_frame(plan[k], t - plan[k][0]), (0, TOP_H))
        dr = ImageDraw.Draw(frame)
        dr.rectangle([0, TOP_H - 3, W, TOP_H + 3], fill=(255, 196, 40))  # seam line
        dr.rectangle([0, 0, int(W * (t + 1 / FPS) / dur), 9], fill=(255, 196, 40))  # progress bar
        frame = place(frame, tag, (W // 2, TOP_H), "cc")  # brand on the seam
        if chunks:
            frame = draw_caption(frame, chunks, t)
        if hook_img is not None and t < 2.4:
            frame = Overlay(hook_img, 0.0, 2.4, (W // 2, 70), "tc").draw(frame, t)  # hook at the top
        if what_t0 < what_t1 and what_t0 <= t <= what_t1:
            frame = Overlay(what, what_t0, what_t1, (W // 2, TOP_H + 70), "tc").draw(frame, t)
        p.stdin.write(frame.tobytes())
    p.stdin.close(); p.wait()

    # audio: the top clip only (with --game-audio: + game music low + a light sound on each cut)
    SR = 48000
    total = int(dur * SR)
    buf = np.zeros((total, 2), np.float32)
    if top_audio(top_path, dur, tmp_a):
        a = read_wav(tmp_a)[:total]
        buf[:len(a)] += a
        os.remove(tmp_a)
    if not game_audio:
        plan = []
    elif bottom:
        bw = out + ".bot.wav"
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", bottom, "-vn", "-ac", "2", "-ar", "48000", "-c:a", "pcm_s16le", bw])
        b = read_wav(bw); os.remove(bw)
        while len(b) < total:
            b = np.concatenate([b, b])
        buf += b[:total] * 0.3
        plan = []
    if game_audio and not bottom:
        m = read_wav(os.path.join(AUDIO, "music_short_upbeat_120bpm.wav"))
        while len(m) < total:
            m = np.concatenate([m, m])
        buf += m[:total] * 0.18
    for (t0, d, mom) in plan:
        if t0 > dur - end_s:
            break
        if not mom[4]:
            continue
        x = read_wav(os.path.join(AUDIO, mom[4]))
        i = int(t0 * SR); j = min(total, i + len(x))
        buf[i:j] += x[: j - i] * 0.22
    fo = int(0.8 * SR)
    buf[-fo:] *= np.linspace(1, 0, min(fo, total))[:, None]
    peak = np.abs(buf).max()
    if peak > 0.98:
        buf *= 0.98 / peak
    with wave.open(tmp_mix, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((buf * 32767).astype("<i2").tobytes())
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", tmp_v, "-i", tmp_mix, "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
                    "-shortest", out], check=True)
    os.remove(tmp_v); os.remove(tmp_mix)
    print("VIDEO", out, round(dur, 1), "s")
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("top", help="vídeo de arriba, o una carpeta con varios")
    ap.add_argument("--text", default=None, help="texto del gancho (primeros 3 s)")
    ap.add_argument("--seed", type=int, default=1, help="cambia el orden de los cortes de abajo")
    ap.add_argument("--max", type=float, default=60.0, help="duración máxima en segundos")
    ap.add_argument("--name", default=None)
    ap.add_argument("--bottom", default=None, help='clip de gameplay editado para abajo, "auto-gp" (uno distinto por reel) o "basic" (gameplay normal continuo); por defecto: cortes rápidos automáticos')
    ap.add_argument("--game-audio", action="store_true", help="añadir música y efectos del juego (por defecto solo suena el clip de arriba)")
    ap.add_argument("--lang", default="es", choices=["es", "en"], help="idioma de los textos del juego (final y «¿qué juego es este?»)")
    ap.add_argument("--no-captions", action="store_true", help="sin subtítulos aunque exista CLIP.words.json")
    a = ap.parse_args()
    gps = sorted(glob.glob(os.path.join(GP_DIR, "THNE_gp_*.mp4")))

    def pick_bottom(i):
        if a.bottom == "auto-gp":
            if not gps:
                raise SystemExit("No hay clips en 12_FINAL_EXPORTS/gameplay_clips_split: ejecuta make_gameplay_clips.py")
            return gps[(a.seed + i) % len(gps)]
        return a.bottom

    if os.path.isdir(a.top):
        files = sorted(f for f in glob.glob(os.path.join(a.top, "*")) if f.lower().endswith((".mp4", ".mov", ".webm", ".mkv")))
        for i, f in enumerate(files):
            make(f, a.text, a.seed + i, a.max, bottom=pick_bottom(i), game_audio=a.game_audio, lang=a.lang, captions=not a.no_captions)
    else:
        make(a.top, a.text, a.seed, a.max, a.name, bottom=pick_bottom(0), game_audio=a.game_audio, lang=a.lang,
             captions=not a.no_captions)
