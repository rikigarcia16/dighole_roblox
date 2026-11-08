"""2D finishing for logo renders: cartoon outer stroke(s), soft shadow, crop. 
Usage: python post_logo.py in.png out.png stroke_px [outer_px outer_hex]"""
import sys
from PIL import Image, ImageFilter, ImageChops
def stroke(alpha, px):
    a = alpha
    k = 3
    steps = max(1, px // 1)
    out = a
    # grow alpha with repeated max filters (round-ish dilation)
    r = 0
    while r < px:
        s = min(6, px - r)
        out = out.filter(ImageFilter.MaxFilter(2 * s + 1 if s % 2 == 0 else 2 * s + 1))
        r += s
    return out.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: 255 if v > 110 else int(v * 255 / 110))
def finish(im, px, ink=(30, 14, 5), outer_px=0, outer=(255, 248, 230), shadow=True):
    im = im.convert("RGBA")
    pad = px + outer_px + 40
    big = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    big.paste(im, (pad, pad))
    a = big.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    s1 = stroke(a, px)
    layers = Image.new("RGBA", big.size, (0, 0, 0, 0))
    if outer_px:
        s2 = stroke(s1, outer_px)
        o = Image.new("RGBA", big.size, outer + (0,)); o.putalpha(s2); layers.alpha_composite(o)
    if shadow:
        sh = Image.new("RGBA", big.size, (0, 0, 0, 0)); base = s2 if outer_px else s1
        shc = Image.new("RGBA", big.size, (0, 0, 0, 0)); shc.putalpha(base.point(lambda v: int(v * 0.45)))
        shc = shc.filter(ImageFilter.GaussianBlur(px * 0.6))
        sh.paste(shc, (int(px * 0.35), int(px * 0.6)), shc)
        layers = Image.alpha_composite(sh, layers)
    ik = Image.new("RGBA", big.size, ink + (0,)); ik.putalpha(s1); layers.alpha_composite(ik)
    layers.alpha_composite(big)
    return layers.crop(layers.getbbox())
if __name__ == "__main__":
    a = sys.argv
    im = Image.open(a[1])
    outer_px = int(a[4]) if len(a) > 4 else 0
    outer = tuple(int(a[5].lstrip("#")[i:i+2], 16) for i in (0, 2, 4)) if len(a) > 5 else (255, 248, 230)
    finish(im, int(a[3]), outer_px=outer_px, outer=outer).save(a[2])
    print("ok", a[2])
