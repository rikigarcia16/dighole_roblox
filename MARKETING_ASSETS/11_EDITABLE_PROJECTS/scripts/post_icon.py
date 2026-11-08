"""Finishing pass for icon renders: character outline from the mask render, bloom, grade, vignette.
Usage: python post_icon.py raw.png mask.png out.png [outline_px]"""
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance


def bloom(im, threshold=0.78, radius=22, strength=0.55):
    a = np.asarray(im).astype(np.float32) / 255
    lum = a @ np.array([0.2126, 0.7152, 0.0722])
    mask = np.clip((lum - threshold) / (1 - threshold), 0, 1)[..., None]
    bright = Image.fromarray((a * mask * 255).astype(np.uint8))
    b1 = np.asarray(bright.filter(ImageFilter.GaussianBlur(radius))).astype(np.float32) / 255
    b2 = np.asarray(bright.filter(ImageFilter.GaussianBlur(radius * 3))).astype(np.float32) / 255
    out = 1 - (1 - a) * (1 - (b1 * strength + b2 * strength * 0.6))
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def vignette(im, amount=0.28):
    w, h = im.size
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    v = 1 - amount * np.clip(d - 0.55, 0, 1) ** 1.6
    a = np.asarray(im).astype(np.float32) * v[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def outline(im, mask, px, ink=(24, 14, 8)):
    m = mask.getchannel("A").point(lambda v: 255 if v > 90 else 0)
    grown = m
    r = 0
    while r < px:
        s = min(4, px - r)
        grown = grown.filter(ImageFilter.MaxFilter(2 * s + 1))
        r += s
    grown = grown.filter(ImageFilter.GaussianBlur(1.0))
    ring = np.clip(np.asarray(grown).astype(np.float32) - np.asarray(m).astype(np.float32), 0, 255) / 255
    a = np.asarray(im).astype(np.float32)
    ink = np.array(ink, np.float32)
    a = a * (1 - ring[..., None]) + ink * ring[..., None]
    return Image.fromarray(a.astype(np.uint8))


def finish(raw, mask, px=7):
    im = raw.convert("RGB")
    if mask is not None:
        im = outline(im, mask, px)
    im = bloom(im)
    im = ImageEnhance.Color(im).enhance(1.10)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    return vignette(im)


if __name__ == "__main__":
    raw = Image.open(sys.argv[1])
    mask = Image.open(sys.argv[2]) if sys.argv[2] != "-" else None
    px = int(sys.argv[4]) if len(sys.argv) > 4 else 7
    finish(raw, mask, px).save(sys.argv[3])
    print("ok", sys.argv[3])
