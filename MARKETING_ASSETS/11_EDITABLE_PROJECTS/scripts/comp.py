"""Shared 2D compositing helpers (Pillow) for thumbnails, banners, social posts and ads.
Every finished image is rebuilt from the raw captures/renders by make_*.py scripts."""
import os, glob
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(ROOT, "10_RAW_GAMEPLAY")
BRAND = os.path.join(ROOT, "01_BRANDING", "logo")

_fonts = None
for v in sorted(glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts"))):
    if os.path.exists(os.path.join(v, "LuckiestGuy-Regular.ttf")):
        _fonts = v
FONT_TITLE = os.path.join(_fonts, "LuckiestGuy-Regular.ttf")
FONT_BODY = os.path.join(_fonts, "FredokaOne-Regular.ttf")
FONT_UI = os.path.join(_fonts, "BuilderSans-ExtraBold.otf")

INK = (30, 14, 5)
GOLD = ((255, 240, 106), (255, 154, 31))
CYAN = ((154, 247, 255), (47, 134, 255))
WHITE = ((255, 255, 255), (255, 231, 184))
VIEW_CROP_TOP = 110  # Roblox's own top-left buttons in the Studio viewport captures


def font(path, size):
    return ImageFont.truetype(path, size)


def frame(path, crop=None, size=(1920, 1080), focus=(0.5, 0.5), zoom=1.0):
    """Load a capture and cover-crop it to `size`. `crop` = (x0, y0, x1, y1) in source pixels;
    by default the strip with Roblox's buttons is removed."""
    im = Image.open(path).convert("RGB")
    if crop:
        im = im.crop(crop)
    else:
        im = im.crop((0, VIEW_CROP_TOP if im.height > 1000 else int(VIEW_CROP_TOP * im.height / 1326), im.width, im.height))
    tw, th = size
    s = max(tw / im.width, th / im.height) * zoom
    nw, nh = int(im.width * s + 0.5), int(im.height * s + 0.5)
    im = im.resize((nw, nh), Image.LANCZOS)
    x = int((nw - tw) * focus[0]); y = int((nh - th) * focus[1])
    return im.crop((x, y, x + tw, y + th))


def grade(im, sat=1.10, con=1.06, bri=1.02, sharp=1.15):
    """Light retouch only (Roblox allows light retouching, not artificially enhanced graphics)."""
    im = ImageEnhance.Color(im).enhance(sat)
    im = ImageEnhance.Contrast(im).enhance(con)
    im = ImageEnhance.Brightness(im).enhance(bri)
    return ImageEnhance.Sharpness(im).enhance(sharp)


def vignette(im, amount=0.35, start=0.5):
    w, h = im.size
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    v = 1 - amount * np.clip(d - start, 0, 1) ** 1.5
    a = np.asarray(im.convert("RGB")).astype(np.float32) * v[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def gradient_band(im, side="top", height=0.35, color=(0, 0, 0), alpha=0.55):
    w, h = im.size
    band = Image.new("RGBA", (w, h), color + (0,))
    a = np.zeros((h, w), np.float32)
    hh = int(h * height)
    ramp = np.linspace(alpha, 0, hh) ** 1.3
    if side == "top":
        a[:hh, :] = ramp[:, None]
    elif side == "bottom":
        a[h - hh:, :] = ramp[::-1, None]
    elif side == "left":
        ww = int(w * height); r = np.linspace(alpha, 0, ww) ** 1.3; a[:, :ww] = r[None, :]
    elif side == "right":
        ww = int(w * height); r = np.linspace(alpha, 0, ww) ** 1.3; a[:, w - ww:] = r[None, ::-1]
    band.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    out = im.convert("RGBA")
    out.alpha_composite(band)
    return out.convert("RGB")


def _gradient_fill(size, top, bottom):
    w, h = size
    t = np.linspace(0, 1, h)[:, None]
    c = np.array(top)[None, None, :] * (1 - t[..., None]) + np.array(bottom)[None, None, :] * t[..., None]
    return Image.fromarray(np.repeat(c, w, axis=1).astype(np.uint8))


def headline(text, size, colors=GOLD, stroke=None, shadow=True, font_path=None, tracking=0, outer=None):
    """Big cartoon title as an RGBA image: vertical gradient fill + thick ink stroke + soft shadow.
    `outer` = (px, rgb) adds a second, lighter stroke (for dark backgrounds)."""
    f = font(font_path or FONT_TITLE, size)
    stroke = stroke if stroke is not None else max(4, size // 9)
    lines = text.split("\n")
    pad = stroke * 3 + (outer[0] if outer else 0) + 20
    widths, heights = [], []
    for ln in lines:
        bb = f.getbbox(ln)
        widths.append(bb[2] - bb[0] + tracking * max(0, len(ln) - 1)); heights.append(int(size * 1.0))
    W = max(widths) + pad * 2; H = sum(heights) + pad * 2 + int(size * 0.12) * (len(lines) - 1)
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    y = pad
    for ln, w in zip(lines, widths):
        x = (W - w) // 2
        if tracking:
            for ch in ln:
                d.text((x, y - f.getbbox(ln)[1]), ch, font=f, fill=255)
                x += f.getbbox(ch)[2] + tracking
        else:
            d.text((x, y - f.getbbox(ln)[1]), ln, font=f, fill=255)
        y += int(size * 1.12)
    fill = _gradient_fill((W, H), colors[0], colors[1]).convert("RGBA")
    fill.putalpha(mask)
    st = mask.filter(ImageFilter.MaxFilter(3))
    r = 1
    while r < stroke:
        st = st.filter(ImageFilter.MaxFilter(5)); r += 2
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if outer:
        o = st
        r = 0
        while r < outer[0]:
            o = o.filter(ImageFilter.MaxFilter(5)); r += 2
        ol = Image.new("RGBA", (W, H), outer[1] + (0,)); ol.putalpha(o)
        base_for_shadow = o
    else:
        base_for_shadow = st
    if shadow:
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sa = base_for_shadow.point(lambda v: int(v * 0.55)).filter(ImageFilter.GaussianBlur(stroke * 0.8))
        shl = Image.new("RGBA", (W, H), (0, 0, 0, 0)); shl.putalpha(sa)
        sh.paste(shl, (stroke // 2, stroke), shl)
        out.alpha_composite(sh)
    if outer:
        out.alpha_composite(ol)
    ink = Image.new("RGBA", (W, H), INK + (0,)); ink.putalpha(st)
    out.alpha_composite(ink)
    # glossy highlight on the upper part of the letters
    gl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(gl).rectangle([0, 0, W, int(H * 0.42)], fill=60)
    gl = Image.fromarray(np.minimum(np.asarray(gl), np.asarray(mask)).astype(np.uint8))
    hl = Image.new("RGBA", (W, H), (255, 255, 255, 0)); hl.putalpha(gl)
    out.alpha_composite(fill)
    out.alpha_composite(hl)
    return out.crop(out.getbbox())


def body_text(text, size, color=(255, 255, 255), stroke=0, stroke_color=INK, font_path=None, align="center", spacing=1.18, max_w=None):
    f = font(font_path or FONT_BODY, size)
    lines = []
    for para in text.split("\n"):
        if not max_w:
            lines.append(para); continue
        cur = ""
        for w_ in para.split(" "):
            t = (cur + " " + w_).strip()
            if f.getlength(t) > max_w and cur:
                lines.append(cur); cur = w_
            else:
                cur = t
        lines.append(cur)
    W = int(max(f.getlength(l) for l in lines)) + stroke * 2 + 8
    H = int(size * spacing * len(lines)) + stroke * 2 + 8
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, l in enumerate(lines):
        lw = f.getlength(l)
        x = stroke + 4 + ((W - lw - stroke * 2 - 8) / 2 if align == "center" else 0)
        d.text((x, stroke + 4 + i * size * spacing), l, font=f, fill=color, stroke_width=stroke, stroke_fill=stroke_color)
    return im.crop(im.getbbox())


def pill(text, size, bg=(255, 196, 40), fg=INK, pad=(0.6, 0.32), font_path=None, radius=None, border=None):
    f = font(font_path or FONT_TITLE, size)
    bb = f.getbbox(text)
    w, h = bb[2] - bb[0], int(size * 0.95)
    px, py = int(size * pad[0]), int(size * pad[1])
    W, H = w + 2 * px, h + 2 * py
    im = Image.new("RGBA", (W + 12, H + 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = radius or H // 2
    d.rounded_rectangle([6, 10, W + 6, H + 10], r, fill=(0, 0, 0, 110))
    d.rounded_rectangle([0, 0, W, H], r, fill=bg, outline=border or INK, width=max(3, size // 14))
    d.text((px, py - bb[1] + int(size * 0.04)), text, font=f, fill=fg)
    return im


def place(base, overlay, xy, anchor="tl"):
    """Paste RGBA overlay on base at xy; anchor tl/tc/tr/cl/cc/cr/bl/bc/br."""
    x, y = xy
    w, h = overlay.size
    ax = {"l": 0, "c": w // 2, "r": w}[anchor[1]]
    ay = {"t": 0, "c": h // 2, "b": h}[anchor[0]]
    b = base.convert("RGBA")
    b.alpha_composite(overlay, (int(x - ax), int(y - ay)))
    return b.convert("RGB") if base.mode == "RGB" else b


def fit(im, w=None, h=None):
    if w and not h:
        h = int(im.height * w / im.width)
    if h and not w:
        w = int(im.width * h / im.height)
    return im.resize((int(w), int(h)), Image.LANCZOS)


def logo(kind="horizontal_en", bg="oscuro"):
    return Image.open(os.path.join(BRAND, f"THNE_logo_{kind}_fondo_{bg}.png")).convert("RGBA")


def arrow(w, h, color=(255, 210, 60)):
    im = Image.new("RGBA", (w + 20, h + 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(10, 10 + h * 0.3), (10 + w * 0.6, 10 + h * 0.3), (10 + w * 0.6, 10), (10 + w, 10 + h / 2),
           (10 + w * 0.6, 10 + h), (10 + w * 0.6, 10 + h * 0.7), (10, 10 + h * 0.7)]
    d.polygon(pts, fill=color, outline=INK, width=max(4, h // 12))
    return im


def save_jpg(im, path, max_mb=2.9, q=92):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    while True:
        im.convert("RGB").save(path, quality=q, optimize=True, progressive=True)
        if os.path.getsize(path) <= max_mb * 1024 * 1024 or q <= 70:
            break
        q -= 4
    return path


def save_png(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    return path


def clip_frame(clip, index):
    fs = sorted(glob.glob(os.path.join(RAW, "clips", clip, "f_*.jpg")))
    return fs[min(index, len(fs) - 1)]


def still(name):
    return os.path.join(RAW, "stills", name + ".png")
