"""Bottomless edit engine v2.

A video is a list of Shots (real gameplay recordings, each with its own camera move, speed and grade),
joined by purposeful Transitions, with animated Layers on top (titles, diary cards, typed notes, timers,
stamps, zone titles) and a mixed soundtrack (music bed, ducking, silences, synced effects).
Families (cinematic, diary, mystery, compare, experiment, satisfying, challenge, quick, quiz) pick
different grades, fonts, transitions and music, so videos don't look like one template.

Footage: MARKETING_ASSETS/10_RAW_GAMEPLAY/clips/<name>/f_*.jpg + times.json (Studio viewport captures).
"""
import os, sys, json, math, glob, subprocess, wave, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
STUDIO = os.path.join(REPO, "CONTENT_STUDIO")
SCRIPTS = os.path.join(REPO, "MARKETING_ASSETS", "11_EDITABLE_PROJECTS", "scripts")
sys.path.insert(0, SCRIPTS)
import video as V          # clip loader (frame at time, frame blending) from the first engine
import comp as C           # headline(), pill(), logo(), fonts

FFMPEG = V.FFMPEG
W, H, FPS = 1080, 1920, 30
AUDIO = os.path.join(STUDIO, "AUDIO")
CROP_TOP = V.VIEW_CROP_TOP  # Roblox's own buttons at the top of the Studio viewport

FONT_DIARY = "C:/Windows/Fonts/segoepr.ttf"   # Segoe Print (handwriting)
FONT_TYPE = "C:/Windows/Fonts/cour.ttf"       # Courier New (typewriter)
FONT_TYPE_B = "C:/Windows/Fonts/courbd.ttf"
FONT_UI = C.FONT_UI
FONT_TITLE = C.FONT_TITLE
FONT_BODY = C.FONT_BODY


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype(FONT_BODY, size)


def register(*names):
    for n in names:
        V.CLIPS.setdefault(n, dict(slow=1))


# ------------------------------------------------------------------------------------- easing
def ease(u, kind="inout"):
    u = max(0.0, min(1.0, u))
    if kind == "in": return u * u * u
    if kind == "out": return 1 - (1 - u) ** 3
    if kind == "linear": return u
    return 3 * u * u - 2 * u * u * u


def lerp(a, b, u):
    return a + (b - a) * u


# ------------------------------------------------------------------------------------- framing
class Cam:
    """A virtual camera on the landscape recording: centre (x, y in 0..1) and zoom, eased from a to b.
    zoom=1 means the tallest 9:16 crop that fits the frame."""
    def __init__(self, a=(0.5, 0.5, 1.0), b=None, curve="inout", shake=0.0):
        self.a, self.b, self.curve, self.shake = a, b or a, curve, shake

    def at(self, u):
        e = ease(u, self.curve)
        return tuple(lerp(p, q, e) for p, q in zip(self.a, self.b))


def frame_full(im, cam_state, out=(W, H), t=0.0, shake=0.0):
    im = im.crop((0, CROP_TOP, im.width, im.height))
    cx, cy, z = cam_state
    ow, oh = out
    ar = ow / oh
    ch = im.height / z
    cw = ch * ar
    if cw > im.width:  # wide outputs (split halves)
        cw = im.width / z; ch = cw / ar
    x0 = max(0, min(im.width - cw, cx * im.width - cw / 2))
    y0 = max(0, min(im.height - ch, cy * im.height - ch / 2))
    if shake:
        x0 += math.sin(t * 53) * shake; y0 += math.cos(t * 47) * shake
        x0 = max(0, min(im.width - cw, x0)); y0 = max(0, min(im.height - ch, y0))
    return im.resize(out, Image.BICUBIC, box=(x0, y0, x0 + cw, y0 + ch))


GRADES = {
    "natural": dict(sat=1.08, con=1.05, bri=1.0, warm=0.0, vig=0.15, grain=0.0),
    "cinematic": dict(sat=1.05, con=1.12, bri=0.98, warm=0.04, vig=0.35, grain=0.0),
    "comedy": dict(sat=1.2, con=1.06, bri=1.04, warm=0.02, vig=0.0, grain=0.0),
    "mystery": dict(sat=0.75, con=1.15, bri=0.9, warm=-0.03, vig=0.55, grain=0.05),
    "satisfying": dict(sat=1.15, con=1.08, bri=1.02, warm=0.0, vig=0.2, grain=0.0),
    "challenge": dict(sat=1.12, con=1.12, bri=1.0, warm=0.0, vig=0.2, grain=0.0),
}
_vig_cache = {}


def grade(im, g):
    p = GRADES[g]
    im = ImageEnhance.Color(im).enhance(p["sat"])
    im = ImageEnhance.Contrast(im).enhance(p["con"])
    if p["bri"] != 1: im = ImageEnhance.Brightness(im).enhance(p["bri"])
    if p["warm"]:
        r, gch, b = im.split()
        k = p["warm"]
        r = r.point(lambda v: min(255, int(v * (1 + k))))
        b = b.point(lambda v: min(255, int(v * (1 - k))))
        im = Image.merge("RGB", (r, gch, b))
    if p["vig"]:
        key = (im.size, p["vig"])
        if key not in _vig_cache:
            w, h = im.size
            y, x = np.ogrid[:h, :w]
            d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
            m = np.clip(1 - p["vig"] * np.clip(d - 0.55, 0, 1) ** 1.4 * 1.6, 0, 1)
            _vig_cache[key] = Image.fromarray((m * 255).astype("uint8"))
        im = Image.composite(im, Image.new("RGB", im.size, (0, 0, 0)), _vig_cache[key])
    if p["grain"]:
        a = np.asarray(im).astype(np.int16)
        a += (np.random.default_rng().standard_normal(a.shape[:2])[..., None] * 255 * p["grain"]).astype(np.int16)
        im = Image.fromarray(np.clip(a, 0, 255).astype("uint8"))
    return im


def sharpen(im):
    return im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=60, threshold=2))


# --------------------------------------------------------------------------------------- shots
class Shot:
    """`clip` from `start` (s) for `dur` (s) at `speed`, framed by `cam`. layout: full | split_v | split_h | card.
    For split layouts give `clip2/start2/cam2`. `card` is a callable(t)->Image (diary pages, black, titles)."""
    def __init__(self, clip=None, start=0.0, dur=2.0, speed=1.0, cam=None, grade="natural", layout="full",
                 clip2=None, start2=0.0, speed2=1.0, cam2=None, card=None, freeze_at=None, ramp=None, sharpen=True):
        self.clip, self.start, self.dur, self.speed, self.cam = clip, start, dur, speed, cam or Cam()
        self.grade, self.layout, self.card = grade, layout, card
        self.clip2, self.start2, self.speed2, self.cam2 = clip2, start2, speed2, cam2 or Cam()
        self.freeze_at, self.ramp, self.sharpen = freeze_at, ramp, sharpen

    def src_time(self, lt, start, speed):
        if self.freeze_at is not None and lt >= self.freeze_at:
            lt = self.freeze_at
        if self.ramp:  # speed ramp: list of (local_t, speed) keyframes
            acc, prev_t, prev_s = 0.0, 0.0, self.ramp[0][1]
            for kt, ks in self.ramp[1:]:
                if lt <= kt:
                    return start + acc + (lt - prev_t) * lerp(prev_s, ks, (lt - prev_t) / max(1e-6, kt - prev_t) / 2)
                acc += (kt - prev_t) * (prev_s + ks) / 2; prev_t, prev_s = kt, ks
            return start + acc + (lt - prev_t) * prev_s
        return start + lt * speed

    def render(self, lt):
        u = lt / max(1e-6, self.dur)
        if self.layout == "card":
            return self.card(lt)
        c = V.clip(self.clip)
        src = min(self.src_time(lt, self.start, self.speed), c.duration - 0.05)
        if self.layout == "full":
            im = frame_full(c.at(src), self.cam.at(u), (W, H), lt, self.cam.shake)
        else:
            c2 = V.clip(self.clip2)
            src2 = min(self.src_time(lt, self.start2, self.speed2), c2.duration - 0.05)
            if self.layout == "split_v":  # left | right
                half = (W // 2 - 4, H)
                a = frame_full(c.at(src), self.cam.at(u), half, lt)
                b = frame_full(c2.at(src2), self.cam2.at(u), half, lt)
                im = Image.new("RGB", (W, H), (255, 196, 40)); im.paste(a, (0, 0)); im.paste(b, (W // 2 + 4, 0))
            else:  # top / bottom
                half = (W, H // 2 - 4)
                a = frame_full(c.at(src), self.cam.at(u), half, lt)
                b = frame_full(c2.at(src2), self.cam2.at(u), half, lt)
                im = Image.new("RGB", (W, H), (255, 196, 40)); im.paste(a, (0, 0)); im.paste(b, (0, H // 2 + 4))
        if self.sharpen:
            im = sharpen(im)
        return grade(im, self.grade)


# --------------------------------------------------------------------------------- transitions
_dirt_mask = None


def dirt_mask():
    """Organic 'earth' wipe mask (noise blobs), cached."""
    global _dirt_mask
    if _dirt_mask is None:
        r = np.random.default_rng(3)
        small = r.random((H // 40, W // 40))
        m = Image.fromarray((small * 255).astype("uint8")).resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(18))
        a = np.asarray(m).astype(np.float32) / 255
        ys = np.linspace(0, 1, H)[:, None]
        _dirt_mask = np.clip(a * 0.35 + ys * 0.65, 0, 1)  # falls from top to bottom
    return _dirt_mask


def transition(kind, a, b, u):
    """Blend outgoing frame a into incoming frame b, u in 0..1."""
    if kind == "dissolve":
        return Image.blend(a, b, ease(u))
    if kind == "dip":  # through black
        if u < 0.5:
            return Image.blend(a, Image.new("RGB", a.size), ease(u * 2))
        return Image.blend(Image.new("RGB", a.size), b, ease((u - 0.5) * 2))
    if kind == "whip_down":  # vertical whip pan with motion blur
        e = ease(u)
        off = int(e * H)
        canvas = Image.new("RGB", (W, H))
        canvas.paste(a, (0, -off)); canvas.paste(b, (0, H - off))
        blur = 40 * math.sin(math.pi * u)
        if blur > 1:
            canvas = canvas.filter(ImageFilter.BoxBlur(0)).resize((W, H // 8)).resize((W, H), Image.BILINEAR) if blur > 25 else canvas.filter(ImageFilter.GaussianBlur(blur / 6))
        return canvas
    if kind == "dirt":  # earth falls over the frame
        m = dirt_mask()
        th = lerp(-0.1, 1.1, ease(u))
        alpha = np.clip((th - m) * 6, 0, 1)
        A = np.asarray(a).astype(np.float32); B = np.asarray(b).astype(np.float32)
        edge = np.clip(1 - np.abs(th - m) * 10, 0, 1)[..., None] * np.array([70, 45, 25], np.float32)
        out = A * (1 - alpha[..., None]) + B * alpha[..., None]
        out = out * (1 - edge / 255 * 2) + edge
        return Image.fromarray(np.clip(out, 0, 255).astype("uint8"))
    if kind == "iris":  # circle opening on the new shot
        r = ease(u) * math.hypot(W, H) / 2
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).ellipse((W / 2 - r, H / 2 - r, W / 2 + r, H / 2 + r), fill=255)
        return Image.composite(b, a, mask)
    if kind == "flash":
        if u < 0.35:
            return Image.blend(a, Image.new("RGB", a.size, (255, 255, 255)), u / 0.35)
        return Image.blend(Image.new("RGB", a.size, (255, 255, 255)), b, (u - 0.35) / 0.65)
    return b  # cut


# ------------------------------------------------------------------------------------- layers
class Layer:
    def __init__(self, t0, t1, draw):
        self.t0, self.t1, self.draw = t0, t1, draw

    def apply(self, im, t):
        if self.t0 <= t <= self.t1:
            return self.draw(im, t - self.t0, self.t1 - self.t0)
        return im


def text_img(s, size, path=FONT_TITLE, fill=(255, 255, 255), stroke=8, stroke_fill=(20, 12, 6), spacing=10, align="center", shadow=True):
    f = font(path, size)
    d0 = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    box = d0.multiline_textbbox((0, 0), s, font=f, stroke_width=stroke, spacing=spacing, align=align)
    w, h = box[2] - box[0] + 24, box[3] - box[1] + 24
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if shadow:
        sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(sh).multiline_text((12 - box[0] + 4, 12 - box[1] + 6), s, font=f, fill=(0, 0, 0, 150), stroke_width=stroke,
                                          stroke_fill=(0, 0, 0, 150), spacing=spacing, align=align)
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
    ImageDraw.Draw(im).multiline_text((12 - box[0], 12 - box[1]), s, font=f, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill,
                                      spacing=spacing, align=align)
    return im


def paste(base, ov, xy, anchor="cc", alpha=1.0, scale=1.0):
    if scale != 1.0:
        ov = ov.resize((max(1, int(ov.width * scale)), max(1, int(ov.height * scale))), Image.LANCZOS)
    if alpha < 1.0:
        ov = ov.copy(); ov.putalpha(ov.getchannel("A").point(lambda v: int(v * alpha)))
    x, y = xy
    if anchor[0] == "c": x -= ov.width // 2
    elif anchor[0] == "r": x -= ov.width
    if anchor[1] == "c": y -= ov.height // 2
    elif anchor[1] == "b": y -= ov.height
    base = base.convert("RGBA"); base.alpha_composite(ov, (int(x), int(y)))
    return base.convert("RGB")


def title(s, t0, t1, y=300, size=96, path=FONT_TITLE, fill=(255, 255, 255), anim="rise", anchor="cc", x=W // 2, stroke=8):
    img = text_img(s, size, path, fill, stroke)
    if img.width > 960:
        img = img.resize((960, int(img.height * 960 / img.width)), Image.LANCZOS)

    def draw(im, lt, dur):
        a = min(1, lt / 0.25, max(0, (dur - lt) / 0.25))
        if anim == "rise":
            return paste(im, img, (x, y + (1 - ease(min(1, lt / 0.35), "out")) * 40), anchor, a)
        if anim == "pop":
            u = min(1, lt / 0.22)
            sc = 0.6 + 0.5 * ease(u, "out") - 0.1 * max(0, u - 0.7) / 0.3 if u < 1 else 1.0
            return paste(im, img, (x, y), anchor, a, sc)
        if anim == "type":  # typewriter reveal by clipping width
            n = max(1, int(len(s) * min(1, lt / max(0.3, 0.045 * len(s)))))
            part = text_img(s[:n], size, path, fill, stroke)
            return paste(im, part, (x - img.width // 2 if anchor[0] == "c" else x, y), "l" + anchor[1], min(1, max(0, (dur - lt) / 0.25)))
        return paste(im, img, (x, y), anchor, a)
    return Layer(t0, t1, draw)


def stamp(s, t0, t1, y=520, color=(220, 40, 40), size=110):
    f = font(FONT_TITLE, size)
    d0 = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    bx = d0.textbbox((0, 0), s, font=f)
    w, h = bx[2] - bx[0] + 70, bx[3] - bx[1] + 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((6, 6, w - 6, h - 6), 18, outline=color + (255,), width=10)
    d.text((35 - bx[0], 30 - bx[1]), s, font=f, fill=color + (255,))
    img = img.rotate(-6, expand=True, resample=Image.BICUBIC)

    def draw(im, lt, dur):
        u = min(1, lt / 0.18)
        sc = 1.8 - 0.8 * ease(u, "out")
        a = min(1, u * 2, max(0, (dur - lt) / 0.2))
        return paste(im, img, (W // 2, y), "cc", a, sc)
    return Layer(t0, t1, draw)


def corner_meter(get_text, t0, t1, y=1560, size=58):
    """Small live readout (metres, timer) bottom-left inside the safe zone."""
    def draw(im, lt, dur):
        s = get_text(lt)
        img = text_img(s, size, FONT_UI, (255, 255, 255), 6)
        return paste(im, img, (90, y), "lb", min(1, lt / 0.2))
    return Layer(t0, t1, draw)


def big_timer(get_seconds, t0, t1, y=300, size=150, color=(255, 255, 255)):
    def draw(im, lt, dur):
        s = get_seconds(lt)
        txt = f"{int(s // 60):02d}:{s % 60:04.1f}"
        img = text_img(txt, size, FONT_UI, color, 10)
        return paste(im, img, (W // 2, y), "cc")
    return Layer(t0, t1, draw)


def zone_title(name, metres, t0, t1, y=1380):
    """Thin film-credit style zone title with a line that draws itself."""
    a_img = text_img(name.upper(), 64, FONT_UI, (255, 255, 255), 0, shadow=True)
    b_img = text_img(metres, 44, FONT_UI, (190, 220, 255), 0, shadow=True)

    def draw(im, lt, dur):
        al = min(1, lt / 0.4, max(0, (dur - lt) / 0.4))
        im = paste(im, a_img, (W // 2, y), "cc", al)
        lw = int(520 * ease(min(1, lt / 0.6), "out"))
        ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(ov).rectangle((W // 2 - lw // 2, y + 46, W // 2 + lw // 2, y + 50), fill=(255, 255, 255, int(220 * al)))
        base = im.convert("RGBA"); base.alpha_composite(ov); im = base.convert("RGB")
        return paste(im, b_img, (W // 2, y + 90), "cc", al)
    return Layer(t0, t1, draw)


# ---------------------------------------------------------------------------------- cards
def paper(size=(W, H), tone=(238, 228, 205)):
    r = np.random.default_rng(5)
    a = np.ones((size[1], size[0], 3), np.float32) * np.array(tone, np.float32)
    n = Image.fromarray((r.random((size[1] // 6, size[0] // 6)) * 255).astype("uint8")).resize(size, Image.BICUBIC)
    a += (np.asarray(n).astype(np.float32)[..., None] - 128) * 0.12
    im = Image.fromarray(np.clip(a, 0, 255).astype("uint8"))
    d = ImageDraw.Draw(im)
    for yy in range(420, size[1] - 200, 92):  # ruled lines
        d.line((80, yy, size[0] - 80, yy), fill=(170, 190, 215), width=2)
    d.line((150, 300, 150, size[1] - 150), fill=(220, 120, 120), width=3)
    return grade(im, "natural")


_paper = None


def diary_card(lines, write_time=1.2):
    """Handwritten diary page; text writes itself in `write_time`."""
    global _paper
    if _paper is None:
        _paper = paper()
    f_big = font(FONT_DIARY, 92)

    def card(lt):
        im = _paper.copy()
        d = ImageDraw.Draw(im)
        total = sum(len(l) for l in lines)
        n = int(total * min(1, lt / write_time))
        y = 560
        for l in lines:
            k = max(0, min(len(l), n)); n -= len(l)
            d.text((190, y), l[:k], font=f_big, fill=(35, 45, 90))
            y += 184
        return im
    return card


def note_card(lines, sig="— E.", type_time=2.0):
    """Typewritten note on aged paper (real note text from the game, translated)."""
    base = paper(tone=(222, 205, 168))
    d = ImageDraw.Draw(base)
    for yy in range(0, H, 1):
        pass
    f = font(FONT_TYPE_B, 58)

    def card(lt):
        im = base.copy()
        dd = ImageDraw.Draw(im)
        total = sum(len(l) for l in lines) + len(sig)
        n = int(total * min(1, lt / type_time))
        y = 640
        for l in lines + ["", sig]:
            k = max(0, min(len(l), n)); n -= len(l)
            dd.text((150, y), l[:k], font=f, fill=(40, 30, 22))
            y += 96
        return grade(im, "mystery")
    return card


def black_card(_lt=0):
    return Image.new("RGB", (W, H), (0, 0, 0))


def end_card(lang="en"):
    """Brand end card: logo on dark earth gradient + call to action."""
    im = Image.new("RGB", (W, H))
    a = np.zeros((H, W, 3), np.float32)
    ys = np.linspace(0, 1, H)[:, None]
    a[...] = (np.array([22, 18, 30]) * (1 - ys) + np.array([60, 36, 20]) * ys)[..., None].transpose(0, 2, 1) if False else 0
    top = np.array([16, 14, 26], np.float32); bot = np.array([58, 36, 20], np.float32)
    a = (top * (1 - ys[..., None]) + bot * ys[..., None]) * np.ones((1, W, 1))
    im = Image.fromarray(a.astype("uint8"))
    im = paste(im, C.fit(C.logo("main_en", "oscuro"), w=860).convert("RGBA"), (W // 2, 560), "ct")
    cta = "FREE ON ROBLOX" if lang == "en" else "GRATIS EN ROBLOX"
    im = paste(im, C.pill(cta, 72, bg=(120, 220, 90)).convert("RGBA"), (W // 2, 1250), "cc")
    sub = "The Hole Never Ends · link in bio" if lang == "en" else "The Hole Never Ends · enlace en la bio"
    return paste(im, text_img(sub, 46, FONT_BODY, (255, 255, 255), 0), (W // 2, 1390), "cc")


# ------------------------------------------------------------------------------------- audio
def read_wav(path):
    with wave.open(path) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").reshape(-1, w.getnchannels()).astype(np.float32) / 32768
    return x if x.shape[1] == 2 else np.repeat(x, 2, axis=1)


def sfx(name):
    return os.path.join(AUDIO, "sfx", name + ".wav")


def music(name):
    return os.path.join(AUDIO, "music", name + ".wav")


def mix(total, out_wav, bed=None, bed_gain=0.5, cues=(), silences=(), duck=(), bed_offset=0.0, fade_out=1.2):
    """cues: (t, path, gain). silences: (t0, t1) where the music is cut. duck: (t0, t1, factor)."""
    SR = 48000
    n = int(total * SR)
    buf = np.zeros((n + SR, 2), np.float32)
    env = np.ones(n + SR, np.float32)
    if bed:
        m = read_wav(bed)[int(bed_offset * SR):]
        while len(m) < n: m = np.concatenate([m, m])
        for a, b in silences:
            i, j = int(a * SR), int(b * SR)
            r = int(0.08 * SR)
            env[max(0, i - r):i] *= np.linspace(1, 0, min(r, i))
            env[i:j] = 0
            env[j:j + r] *= np.linspace(0, 1, r)
        for a, b, f in duck:
            env[int(a * SR):int(b * SR)] *= f
        buf[:n] += m[:n] * bed_gain * env[:n, None]
    for t, path, g in cues:
        x = read_wav(path)
        i = int(t * SR); j = min(len(buf), i + len(x))
        if i < len(buf): buf[i:j] += x[: j - i] * g
    fo = int(fade_out * SR)
    buf[n - fo:n] *= np.linspace(1, 0, fo)[:, None]
    buf = buf[:n]
    peak = np.abs(buf).max()
    if peak > 0.95: buf *= 0.95 / peak
    with wave.open(out_wav, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes((buf * 32767).astype("<i2").tobytes())


# ------------------------------------------------------------------------------------- render
class Edit:
    """shots: list of (Shot, transition_into_next, transition_seconds). layers: list of Layer.
    end: seconds of brand end card appended (0 = none)."""
    def __init__(self, vid, shots, layers=(), lang="en", end=2.0, end_transition="dip"):
        self.vid, self.shots, self.layers, self.lang, self.end, self.end_tr = vid, shots, list(layers), lang, end, end_transition
        self.starts = []
        t = 0.0
        for sh, tr, td in shots:
            self.starts.append(t); t += sh.dur
        self.body = t
        self.total = t + end
        self._end = end_card(lang) if end else None

    def frame(self, t):
        if self._end is not None and t >= self.body:
            lt = t - self.body
            if lt < 0.4 and self.end_tr:
                last, _, _ = self.shots[-1]
                return transition(self.end_tr, last.render(last.dur - 0.01), self._end, lt / 0.4)
            return self._end
        k = max(i for i, s in enumerate(self.starts) if s <= t + 1e-9)
        sh, tr, td = self.shots[k]
        lt = t - self.starts[k]
        im = sh.render(lt)
        if k + 1 < len(self.shots) and tr != "cut" and td > 0 and sh.dur - lt < td:  # transition into next shot
            nxt = self.shots[k + 1][0]
            u = 1 - (sh.dur - lt) / td
            im = transition(tr, im, nxt.render(0.0), u)
        for L in self.layers:
            im = L.apply(im, t)
        return im

    def render(self, out_path, audio_kwargs, cover_t=None, cover_text=None, sheet_path=None):
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        tmp_v, tmp_a = out_path + ".v.mp4", out_path + ".a.wav"
        cmd = [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
               "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", tmp_v]
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        n = int(round(self.total * FPS))
        sheet = []
        for f in range(n):
            t = f / FPS
            im = self.frame(t)
            if f % int(FPS * max(1.0, self.total / 12)) == 0:
                sheet.append(im.resize((216, 384)))
            p.stdin.write(im.tobytes())
        p.stdin.close(); p.wait()
        mix(self.total, tmp_a, **audio_kwargs)
        subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", tmp_v, "-i", tmp_a, "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
                        "-shortest", out_path], check=True)
        os.remove(tmp_v); os.remove(tmp_a)
        if sheet_path:
            cols = 6; rows = (len(sheet) + cols - 1) // cols
            s = Image.new("RGB", (216 * cols, 384 * rows))
            for i, im in enumerate(sheet): s.paste(im, ((i % cols) * 216, (i // cols) * 384))
            os.makedirs(os.path.dirname(sheet_path), exist_ok=True); s.save(sheet_path, quality=85)
        print("VIDEO", out_path, round(self.total, 1), "s")
        return out_path


def cover(edit, t, text, path, size=120, color=((255, 240, 106), (255, 154, 31))):
    im = edit.frame(t)
    h = C.headline(text, size, color)
    if h.width > 960: h = C.fit(h, w=960)
    im = paste(im, h.convert("RGBA"), (W // 2, 420), "cc")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, quality=92)
    return path
