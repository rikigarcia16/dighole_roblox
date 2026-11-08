"""Official trailer (real gameplay, cut to the beat of the original 112 BPM track).
Usage: python make_trailer.py [es|en] [land|vert]"""
import sys, os
from video import *

lang = sys.argv[1] if len(sys.argv) > 1 else "es"
fmt = sys.argv[2] if len(sys.argv) > 2 else "land"
L = {"es": dict(t1="HEREDASTE UNA CASA…", t2="…Y UNA NOTA QUE DICE: CAVA.", t3="ASÍ QUE CAVAS.", mines="MINAS OLVIDADAS",
                crystal="CUEVAS DE CRISTAL", abyss="EL ABISMO", tools="10 HERRAMIENTAS", q="¿QUÉ HAY A 2.200 m?",
                cta="GRATIS EN ROBLOX", sub="Busca: The Hole Never Ends", logo="main_es"),
     "en": dict(t1="YOU INHERITED A HOUSE…", t2="…AND A NOTE THAT SAYS: DIG.", t3="SO YOU DIG.", mines="FORGOTTEN MINES",
                crystal="CRYSTAL CAVES", abyss="THE ABYSS", tools="10 TOOLS", q="WHAT'S AT 2,200 m?",
                cta="FREE ON ROBLOX", sub="Search: The Hole Never Ends", logo="main_en")}[lang]

VERT = fmt == "vert"
SIZE = (1080, 1920) if VERT else (1920, 1080)
W, H = SIZE
BEAT = 60 / 112
BAR = BEAT * 4


def lay(focus=0.5, zoom=1.0, fy=0.5):
    if VERT:
        return lambda im: vert_framed(im, focus, zoom)
    return lambda im: land(im, (focus, fy), zoom)


segs = [
    Seg("plot_crane", 0.0, 1.5 * BAR, lay(0.5, 1.0, 0.6), fade_in=0.6),
    Seg("surface_hero", 1.0, 1.5 * BAR, lay(0.52)),
    Seg("descent_b", 0.0, 1.0 * BAR, lay(0.5)),
    Seg("descent_b", 2.2, 2.0 * BAR, lay(0.5), speed=1.85),
    Seg("mines_action", 5.0, 1.0 * BAR, lay(0.45, 1.05)),
    Seg("crystal_action", 3.0, 1.0 * BAR, lay(0.55, 1.1), flash_in=True, punch=0.12),
    Seg("abyss_action", 0.0, 1.0 * BAR, lay(0.5, 1.0), punch=0.1),
    Seg("garage_pan", 4.0, 1.0 * BAR, lay(0.5), punch=0.08),
    Seg("showcase_ui", 1.8, 1.0 * BAR, lay(0.42, 1.0)),
    Seg("sell_ui", 1.8, 1.0 * BAR, lay(0.5, 1.0)),
    Seg("legendary_ui", 3.2, 1.0 * BAR, lay(0.5, 1.0)),
    Seg("descent_b", 8.0, 1.0 * BAR, lay(0.5), fade_out=0.5),
]
starts = np.cumsum([0] + [s.dur for s in segs])

big = 120 if not VERT else 104
med = 96 if not VERT else 84
ty = 120 if not VERT else 230
ov = []


def T(text, i, offset=0.15, length=None, colors=GOLD, size=None, y=None):
    t0 = starts[i] + offset
    t1 = t0 + (length or segs[i].dur - offset - 0.05)
    img = headline(text, size or med, colors)
    if img.width > W * 0.92:
        img = fit(img, w=int(W * 0.92))
    ov.append(Overlay(img, t0, t1, (W // 2, y or ty), "tc"))


T(L["t1"], 0, 0.5, colors=WHITE)
T(L["t2"], 1, 0.2, colors=WHITE)
T(L["t3"], 2, 0.1, size=big)
# depth counter during the dive (zones of the real game)
depths = ["50 m", "150 m", "350 m", "650 m", "1.000 m" if lang == "es" else "1,000 m"]
for k, dtxt in enumerate(depths):
    t0 = starts[3] + k * segs[3].dur / len(depths)
    ov.append(Overlay(headline(dtxt, big + 20, CYAN if k >= 2 else GOLD), t0, t0 + segs[3].dur / len(depths) - 0.02,
                      (W // 2, H // 2), "cc"))
T(L["mines"], 4)
T(L["crystal"], 5, colors=CYAN)
T(L["abyss"], 6, colors=CYAN)
T(L["tools"], 7)
T(L["q"], 11, 0.1, colors=WHITE, size=big if not VERT else 92)

# end card
card = Image.new("RGB", SIZE)
bgimg = land(clip("plot_crane").at(9.5), (0.5, 0.6), 1.0, SIZE) if not VERT else vert_full(clip("plot_crane").at(9.5), 0.5)
card = ImageEnhance.Brightness(bgimg.filter(ImageFilter.GaussianBlur(10))).enhance(0.45)
lg = fit(logo(L["logo"], "oscuro"), w=int(W * (0.62 if not VERT else 0.86)))
card = place(card, lg, (W // 2, int(H * (0.12 if not VERT else 0.22))), "tc")
cta = pill(L["cta"], 76 if not VERT else 70, bg=(120, 220, 90))
card = place(card, cta, (W // 2, int(H * (0.78 if not VERT else 0.62))), "cc")
sub = body_text(L["sub"], 46, (255, 255, 255), stroke=4)
card = place(card, sub, (W // 2, int(H * (0.9 if not VERT else 0.69))), "cc")

cues = [(starts[2] - 0.15, "sfx_whoosh_down.wav", 0.8), (starts[5], "sfx_impact.wav", 0.9), (starts[11] + segs[11].dur, "sfx_impact.wav", 0.9),
        (starts[9] + 0.3, "sfx_coin.wav", 0.6), (starts[9] + 0.7, "sfx_coin.wav", 0.6), (starts[10] + 0.4, "sfx_legendary_shimmer.wav", 0.7),
        (starts[8] + 0.2, "sfx_legendary_shimmer.wav", 0.45)]
for k in range(4):
    cues.append((starts[1] + 0.35 + k * 0.75, "sfx_dig_hit.wav", 0.5))
for i in (4, 5, 6):
    for k in range(2):
        cues.append((starts[i] + 0.3 + k * 0.85, "sfx_dig_hit.wav", 0.45))

out_dir = os.path.join(ROOT, "09_OFFICIAL_TRAILER")
os.makedirs(out_dir, exist_ok=True)
name = f"THNE_trailer_oficial_{lang}_{'9x16_1080x1920' if VERT else '16x9_1920x1080'}.mp4"
render(segs, ov, os.path.join(out_dir, name), SIZE, cues, "music_trailer_adventure_112bpm.wav", 0.85, 0.0, tail_card=(card, 4.2))
