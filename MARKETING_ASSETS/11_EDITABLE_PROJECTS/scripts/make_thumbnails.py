"""Roblox experience thumbnails 1920x1080 (<3 MB). Real gameplay captures, light retouch only.
The bottom ~15% is kept free of important content (Roblox overlays player counts there)."""
import os
from comp import *

OUT = os.path.join(ROOT, "03_ROBLOX_THUMBNAILS")
W, H = 1920, 1080
SAFE_BOTTOM = int(H * 0.85)


def title(img, text, y=70, size=150, colors=GOLD, x=W // 2, anchor="tc", outer=None):
    if not text:
        return img
    t = headline(text, size, colors, outer=outer)
    if t.width > W * 0.9:
        t = fit(t, w=int(W * 0.9))
    return place(img, t, (x, y), anchor)


def small_logo(img, where="tl", w=520):
    lg = fit(logo("horizontal_en" if where != "es" else "horizontal_es", "oscuro"), w=w)
    return place(img, lg, (40, 34), "tl")


def T01(lang):
    img = grade(frame(clip_frame("descent_b", 4), focus=(0.5, 0.62), zoom=1.15), sat=1.12)
    img = vignette(img, 0.5, 0.3)
    img = gradient_band(img, "top", 0.4, alpha=0.45)
    txt = {"es": "¿HASTA DÓNDE?", "en": "HOW DEEP?", None: None}[lang]
    return title(img, txt, 60, 170)


def T01b(lang):
    """Three real depths side by side: surface, mines, abyss."""
    img = Image.new("RGB", (W, H))
    parts = [(still("s01_plot_wide_1640"), (0.5, 0.5)), (still("mines_act2_04"), (0.45, 0.5)), (still("abyss_07"), (0.6, 0.5))]
    labels = ["0 m", "80 m", "1.100 m"]
    cw = W // 3
    for i, (p, foc) in enumerate(parts):
        f = grade(frame(p, size=(cw, H), focus=foc), sat=1.1)
        img.paste(f, (i * cw, 0))
    d = ImageDraw.Draw(img)
    for i in (1, 2):
        d.rectangle([i * cw - 5, 0, i * cw + 5, H], fill=INK)
    img = gradient_band(img, "top", 0.35, alpha=0.45)
    for i, lab in enumerate(labels):
        img = place(img, pill(lab, 64, bg=[(120, 220, 90), (255, 170, 60), (90, 230, 255)][i]), (i * cw + cw // 2, 560), "cc")
    txt = {"es": "CAPA A CAPA", "en": "LAYER BY LAYER", None: None}[lang]
    return title(img, txt, 60, 140)


def T02(lang):
    img = grade(frame(still("legendary2_00"), crop=(560, 160, 2512, 1326), focus=(0.4, 0.3), zoom=1.0), sat=1.15)
    return vignette(img, 0.3)


def T03(lang):
    left = grade(frame(still("garage2_00"), size=(W // 2, H), focus=(0.42, 0.5)))
    sw = Image.open(still("showcase_05")).width
    right = grade(frame(still("showcase_05"), crop=(int(sw * 0.25), 110, int(sw * 0.75), 1326), size=(W // 2, H), focus=(0.5, 0.5)))
    img = Image.new("RGB", (W, H)); img.paste(left, (0, 0)); img.paste(right, (W // 2, 0))
    d = ImageDraw.Draw(img); d.rectangle([W // 2 - 6, 0, W // 2 + 6, H], fill=INK)
    img = gradient_band(img, "top", 0.33, alpha=0.5)
    img = place(img, arrow(260, 150), (W // 2, 560), "cc")
    img = place(img, pill("P1", 80, bg=(200, 160, 120)), (W // 4, 850), "cc")
    img = place(img, pill("P85", 80, bg=(90, 230, 255)), (3 * W // 4, 850), "cc")
    txt = {"es": "10 HERRAMIENTAS", "en": "10 TOOLS", None: None}[lang]
    return title(img, txt, 60, 110, x=W // 4)


def T04(lang):
    img = grade(frame(clip_frame("plot_crane", 300), focus=(0.5, 0.6)), sat=1.12)
    img = gradient_band(img, "top", 0.35, alpha=0.4)
    txt = {"es": "TU CASA.\nTU AGUJERO.", "en": "YOUR HOUSE.\nYOUR HOLE.", None: None}[lang]
    return title(img, txt, 40, 120)


def T05(lang):
    img = grade(frame(still("abyss_07"), focus=(0.55, 0.5), zoom=1.05), sat=1.15, bri=1.08)
    img = vignette(img, 0.4)
    txt = {"es": "+1.000 m", "en": "+1,000 m", None: None}[lang]
    return title(img, txt, 60, 170, CYAN)


def T06(lang):
    img = grade(frame(still("mines_act2_04"), focus=(0.5, 0.5), zoom=1.05), sat=1.1, bri=1.08)
    img = vignette(img, 0.35)
    txt = {"es": "MINAS OLVIDADAS", "en": "FORGOTTEN MINES", None: None}[lang]
    return title(img, txt, 50, 130)


def T07(lang):
    img = grade(frame(clip_frame("crystal_action", 251), focus=(0.6, 0.5), zoom=1.15), sat=1.12, bri=1.06)
    img = vignette(img, 0.35)
    txt = {"es": "CUEVAS DE CRISTAL", "en": "CRYSTAL CAVES", None: None}[lang]
    return title(img, txt, 50, 125, CYAN)


def T08(lang):
    img = grade(frame(clip_frame("surface_hero", 200), focus=(0.5, 0.45)), sat=1.12)
    img = gradient_band(img, "top", 0.3, alpha=0.3)
    lg = fit(logo("main_en" if lang != "es" else "main_es", "oscuro"), h=430)
    img = place(img, lg, (W // 2 + 430, 40), "tc")
    txt = {"es": "CAVA EN\nTU JARDÍN", "en": "DIG IN YOUR\nBACKYARD", None: None}[lang]
    if txt:
        img = title(img, txt, 560, 95, WHITE, x=W // 2 + 430)
    return img


THUMBS = [("01_hasta_donde", T01), ("01b_capa_a_capa", T01b), ("02_hallazgo_legendario", T02), ("03_herramientas", T03),
          ("04_tu_casa_tu_agujero", T04), ("05_el_abismo", T05), ("06_minas_olvidadas", T06), ("07_cuevas_de_cristal", T07),
          ("08_cava_en_tu_jardin", T08)]

if __name__ == "__main__":
    import sys
    only = sys.argv[1:]
    for name, fn in THUMBS:
        if only and not any(o in name for o in only):
            continue
        for lang, folder in (("es", "ES"), ("en", "EN"), (None, "SIN_TEXTO")):
            if fn in (T02,) and lang:
                continue  # its text is the game's own UI
            img = fn(lang)
            p = save_jpg(img, os.path.join(OUT, folder, f"THNE_miniatura_{name}_{folder.lower()}.jpg"))
            print(p, round(os.path.getsize(p) / 1e6, 2), "MB")
