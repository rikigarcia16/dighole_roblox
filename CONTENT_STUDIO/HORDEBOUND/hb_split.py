"""Hordebound split-screen reels (1080x1920): a clip you provide on top (its sound only), smooth 30 fps
Hordebound gameplay below, word-by-word captions, and a clear call to action: a search bar that types
"HORDEBOUND" plus "Free on Roblox · link in bio".

The top clip is yours: you choose it and you are responsible for having the right to use it.

python hb_split.py TOP.mp4|FOLDER [--lang en|es] [--skip 07,08] [--max 20]
Output: CONTENT_STUDIO/HORDEBOUND/FINAL_SPLIT/hb_split_<name>_<lang>.mp4"""
import sys, os, glob, argparse, wave
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, "..", "..", "MARKETING_ASSETS", "11_EDITABLE_PROJECTS", "scripts"))
sys.path.insert(0, SCRIPTS)
from PIL import ImageDraw, ImageFilter, ImageEnhance
import make_split as MS
from make_split import probe_duration, top_frames, top_audio, load_words, chunk_words, draw_caption, YELLOW
from video import *

W, H, TOP_H = MS.W, MS.H, MS.TOP_H
HALF = H - TOP_H
OUT = os.path.join(HERE, "FINAL_SPLIT")
GAME_CLIP = "hb2_god"          # full 4-minute run recorded at 30 fps
MENU_CLIP = "hb2_menu"
for _n in (GAME_CLIP, MENU_CLIP):
    CLIPS.setdefault(_n, dict(slow=1))
GOLD = (255, 214, 120)
RED = (230, 40, 70)

T = {
    "en": {"search": "Search on Roblox:", "free": "FREE · LINK IN BIO", "what": "WHAT GAME IS THIS? ↓", "tag": "HORDEBOUND · ROBLOX"},
    "es": {"search": "Búscalo en Roblox:", "free": "GRATIS · LINK EN LA BIO", "what": "¿QUÉ JUEGO ES ESTE? ↓", "tag": "HORDEBOUND · ROBLOX"},
}


def magnifier(size, color=(40, 40, 50)):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = int(size * 0.32); c = int(size * 0.4); w = max(3, size // 9)
    d.ellipse([c - r, c - r, c + r, c + r], outline=color, width=w)
    d.line([c + r * 0.7, c + r * 0.7, size * 0.9, size * 0.9], fill=color, width=w + 1)
    return im


def search_bar(text, typed, width=900, height=120):
    """White rounded search bar with a magnifier; `typed` characters of `text` shown plus a caret."""
    im = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, width - 1, height - 1], radius=height // 2, fill=(255, 255, 255), outline=RED, width=6)
    im.alpha_composite(magnifier(int(height * 0.62)), (int(height * 0.32), int(height * 0.19)))
    shown = text[:typed]
    if shown:
        t = headline(shown, int(height * 0.5), ((30, 30, 40), (30, 30, 40)), shadow=False, stroke=0)
        im.alpha_composite(t, (int(height * 1.15), (height - t.height) // 2))
        x = int(height * 1.15) + t.width + 8
    else:
        x = int(height * 1.15)
    d.rectangle([x, int(height * 0.25), x + 6, int(height * 0.75)], fill=RED)
    return im


def menu_bg():
    c = clip(MENU_CLIP)
    im = land(c.at(min(3.0, c.duration - 0.1)), (0.62, 0.5), 1.0, (W, HALF))
    return ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(6))).enhance(0.5)


def end_panel(lang, lt, bg):
    """Bottom half during the last seconds: game name, search bar typing HORDEBOUND, free pill."""
    im = bg.copy()
    im = place(im, headline("HORDEBOUND", 120, ((255, 230, 150), GOLD)), (W // 2, 40), "tc")
    im = place(im, body_text(T[lang]["search"], 46, (255, 255, 255), stroke=5), (W // 2, 250), "tc")
    typed = int(min(10, max(0, (lt - 0.15) / 0.07)))
    im = place(im, search_bar("HORDEBOUND", typed), (W // 2, 330), "tc")
    if lt > 0.9:
        im = place(im, pill(T[lang]["free"], 52, bg=(120, 220, 90)), (W // 2, 560), "tc")
    return im


def game_frames(seed, dur, zoom=1.3):
    """Continuous gameplay (no cuts), starting at a different busy moment for each reel."""
    c = clip(GAME_CLIP)
    lo, hi = 25.0, max(30.0, c.duration - dur - 8)
    start = lo + ((seed * 37.7) % (hi - lo))
    t = 0.0
    while True:
        yield land(c.at(min(start + t, c.duration - 0.05)), (0.5, 0.47), zoom, (W, HALF))
        t += 1.0 / FPS


def make(top_path, lang="en", seed=1, max_s=20.0, end_s=2.4, name=None):
    dur_top = min(probe_duration(top_path), max_s)
    dur = dur_top + end_s * 0.5            # the call to action overlaps the clip's last second and adds a little tail
    name = name or os.path.splitext(os.path.basename(top_path))[0]
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, f"hb_split_{name}_{lang}.mp4")
    tmp_v, tmp_a, tmp_mix = out + ".v.mp4", out + ".a.wav", out + ".mix.wav"
    chunks = chunk_words(load_words(top_path))
    tag = pill(T[lang]["tag"], 30, bg=GOLD)
    what = pill(T[lang]["what"], 44, bg=(255, 255, 255))
    what_t0 = min(3.0, dur_top * 0.25); what_t1 = what_t0 + 2.6
    bg = menu_bg()
    end_t0 = dur - end_s
    cmd = [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-pix_fmt", "yuv420p", "-movflags", "+faststart", tmp_v]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    tops = top_frames(top_path, dur_top)
    games = game_frames(seed, dur)
    last_top = None
    for f in range(int(round(dur * FPS))):
        t = f / FPS
        frame = Image.new("RGB", (W, H))
        if t < dur_top:
            last_top = next(tops)
        top = last_top
        z = 1 + 0.05 * min(1, t / max(dur_top, 0.1))
        cw, ch = W / z, TOP_H / z
        top = top.resize((W, TOP_H), Image.BILINEAR, box=((W - cw) / 2, (TOP_H - ch) / 2, (W + cw) / 2, (TOP_H + ch) / 2))
        if t >= dur_top:
            top = ImageEnhance.Brightness(top).enhance(max(0.35, 1 - (t - dur_top) * 1.5))
        frame.paste(top, (0, 0))
        g = next(games)
        frame.paste(end_panel(lang, t - end_t0, bg) if t >= end_t0 else g, (0, TOP_H))
        dr = ImageDraw.Draw(frame)
        dr.rectangle([0, TOP_H - 3, W, TOP_H + 3], fill=GOLD)
        dr.rectangle([0, 0, int(W * (t + 1 / FPS) / dur), 9], fill=GOLD)
        frame = place(frame, tag, (W // 2, TOP_H), "cc")
        if chunks and t < dur_top:
            frame = draw_caption(frame, chunks, t)
        if what_t0 <= t <= what_t1 and t < end_t0:
            frame = Overlay(what, what_t0, what_t1, (W // 2, TOP_H + 60), "tc").draw(frame, t)
        p.stdin.write(frame.tobytes())
    p.stdin.close(); p.wait()

    SR = 48000; total = int(dur * SR)
    buf = np.zeros((total, 2), np.float32)
    if top_audio(top_path, dur_top, tmp_a):
        a = read_wav(tmp_a)[:total]; buf[:len(a)] += a; os.remove(tmp_a)
    fo = int(0.6 * SR); i0 = int(dur_top * SR) - fo
    if i0 > 0:
        buf[i0:i0 + fo] *= np.linspace(1, 0, fo)[:, None]; buf[i0 + fo:] = 0
    peak = np.abs(buf).max()
    if peak > 0.98:
        buf *= 0.98 / peak
    with wave.open(tmp_mix, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((buf * 32767).astype("<i2").tobytes())
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", tmp_v, "-i", tmp_mix, "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
                    "-shortest", out], check=True)
    os.remove(tmp_v); os.remove(tmp_mix)
    print("VIDEO", out, round(dur, 1), "s", flush=True)
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("top")
    ap.add_argument("--lang", default="en", choices=["en", "es"])
    ap.add_argument("--skip", default="", help="números de clip a saltar, p. ej. 07,08")
    ap.add_argument("--max", type=float, default=20.0)
    ap.add_argument("--only", default="", help="solo estos números")
    a = ap.parse_args()
    skip = {s.strip() for s in a.skip.split(",") if s.strip()}
    only = {s.strip() for s in a.only.split(",") if s.strip()}
    files = sorted(glob.glob(os.path.join(a.top, "*.mp4"))) if os.path.isdir(a.top) else [a.top]
    for i, f in enumerate(files):
        num = os.path.splitext(os.path.basename(f))[0].split("_")[-1]
        if num in skip or (only and num not in only):
            continue
        make(f, a.lang, seed=i + 1, max_s=a.max, name=f"fg_{num}")
