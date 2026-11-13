"""Hordebound reels (first batch). Real gameplay recorded in a Studio test session (hb_run3: full 4-minute run;
hb_lobby_drone: village fly-over). English texts use the game's own English names (Content.lua NameEn).
python hb_reels.py [ids]"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "EDITABLE_PROJECTS", "engine"))
from engine import *

register("hb_run3", "hb_lobby_drone")
OUT = os.path.join(STUDIO, "HORDEBOUND", "FINAL")
SHEETS = os.path.join(STUDIO, "HORDEBOUND", "STORYBOARDS")
RED = (230, 40, 70)
ICE = ((210, 245, 255), (120, 190, 255))


def hb_end(lang="en"):
    """End card in Hordebound's own colours (deep purple + crimson), game name and CTA."""
    a = np.zeros((H, W, 3), np.float32)
    ys = np.linspace(0, 1, H)[:, None, None]
    a[...] = np.array([24, 12, 40], np.float32) * (1 - ys) + np.array([70, 14, 40], np.float32) * ys
    im = Image.fromarray(a.astype("uint8"))
    d = ImageDraw.Draw(im)
    d.polygon([(0, 1180), (W, 980), (W, 1060), (0, 1260)], fill=RED)
    im = paste(im, text_img("HORDEBOUND", 150, FONT_TITLE, (255, 214, 120), 12), (W // 2, 700), "cc")
    sub = "SURVIVE THE NORDIC HORDE" if lang == "en" else "SOBREVIVE A LA HORDA NÓRDICA"
    im = paste(im, text_img(sub, 48, FONT_UI, (255, 255, 255), 0), (W // 2, 830), "cc")
    cta = "FREE ON ROBLOX" if lang == "en" else "GRATIS EN ROBLOX"
    return paste(im, C.pill(cta, 72, bg=(120, 220, 90)).convert("RGBA"), (W // 2, 1400), "cc")


class HBEdit(Edit):
    def __init__(self, *a, lang="en", **k):
        super().__init__(*a, lang=lang, **k)
        self._end = hb_end(lang) if self.end else None


GAME = Cam((0.5, 0.45, 1.16))  # zoomed a little: hides most of the (Spanish) weapon bar at the bottom  # the hero is always at the centre of the top-down view


def _01_four_minutes(lang="en"):
    """Timelapse of a whole run: from 3 enemies to the boss, then real speed at the peak."""
    shots = [
        (Shot("hb_run3", 3.0, 2.6, 1.0, Cam((0.5, 0.45, 1.35), (0.5, 0.45, 1.16)), grade="challenge"), "cut", 0),
        (Shot("hb_run3", 5.6, 13.0, 18.0, GAME, grade="challenge"), "cut", 0),          # ~4 minutes in 13 s
        (Shot("hb_run3", 247.0, 4.5, 1.0, Cam((0.5, 0.45, 1.16), (0.5, 0.47, 1.35)), grade="challenge"), "flash", 0.25),
    ]
    st = [0, 2.6, 15.6]
    L = [title("Minute 0." if lang == "en" else "Minuto 0.", 0.2, 2.5, y=300, size=110),
         title("Minute 4." if lang == "en" else "Minuto 4.", 15.7, 19.8, y=300, size=110, anim="pop"),
         title("Survive the horde." if lang == "en" else "Sobrevive a la horda.", 17.0, 19.9, y=1500, size=72, path=FONT_UI, stroke=6)]
    e = HBEdit("hb01", shots, L, lang=lang, end=2.2)
    cues = [(0.0, sfx("wind"), 0.5), (2.6, sfx("riser"), 0.5), (15.6, sfx("sub_boom"), 0.9), (20.1, sfx("stamp"), 0.6)]
    return e, dict(bed=music("challenge"), bed_gain=0.55, cues=cues, silences=[(0, 2.6), (15.5, 16.2)]), 16.5, "4 MINUTES" if lang == "en" else "4 MINUTOS"


def _02_it_evolved(lang="en"):
    shots = [
        (Shot("hb_run3", 200.0, 7.5, 1.0, GAME, grade="challenge"), "cut", 0),
        (Shot("hb_run3", 207.6, 4.0, 0.4, Cam((0.5, 0.45, 1.16), (0.5, 0.5, 1.55)), grade="cinematic"), "cut", 0),   # slow motion on the evolution
        (Shot("hb_run3", 209.4, 6.5, 1.0, Cam((0.5, 0.47, 1.4), (0.5, 0.45, 1.16)), grade="challenge"), "flash", 0.2),
    ]
    L = [title("Level 17. Bombs maxed…" if lang == "en" else "Nivel 17. Bombas al máximo…", 0.3, 6.8, y=300, size=72, path=FONT_UI, stroke=6, anim="type"),
         stamp("EVOLVED" if lang == "en" else "EVOLUCIÓN", 9.3, 11.5, y=420, color=(255, 196, 40), size=120),
         title("VIKING APOCALYPSE" if lang == "en" else "APOCALIPSIS VIKINGO", 11.5, 17.9, y=640, size=84, anim="pop")]
    e = HBEdit("hb02", shots, L, lang=lang, end=2.2)
    cues = [(6.0, sfx("riser"), 0.6), (9.3, sfx("stamp"), 0.8), (11.5, sfx("sub_boom"), 0.9), (11.6, sfx("drill"), 0.25)]
    return e, dict(bed=music("challenge"), bed_gain=0.5, cues=cues, silences=[(7.5, 9.3)], duck=[(9.3, 11.5, 0.4)]), 12.5, "IT EVOLVED" if lang == "en" else "EVOLUCIONÓ"


def _03_calm_chaos(lang="en"):
    shots = [
        (Shot("hb_lobby_drone", 2.0, 5.5, 2.2, Cam((0.5, 0.5, 1.0), (0.48, 0.45, 1.12)), grade="cinematic"), "cut", 0),
        (Shot("hb_run3", 249.0, 6.0, 1.0, Cam((0.5, 0.47, 1.4), (0.5, 0.45, 1.16), shake=4), grade="challenge"), "cut", 0),
    ]
    L = [title("the village:" if lang == "en" else "el pueblo:", 0.3, 5.3, y=320, size=90, path=FONT_TYPE_B, stroke=6, anim="type"),
         title("the arena:" if lang == "en" else "la arena:", 5.6, 11.4, y=620, size=90, path=FONT_TYPE_B, stroke=6)]
    e = HBEdit("hb03", shots, L, lang=lang, end=2.0)
    cues = [(0.0, sfx("wind"), 0.6), (5.5, sfx("sub_boom"), 1.0), (5.5, sfx("impact"), 0.6)]
    return e, dict(bed=music("satisfying"), bed_gain=0.6, cues=cues, silences=[(5.4, 13.5)]), 2.0, "CALM / CHAOS" if lang == "en" else "CALMA / CAOS"


def _04_pick_a_card(lang="en"):
    names = "1 TORNADO SNEAKERS\n2 RUNE BAT\n3 AIR BOMBS" if lang == "en" else "1 ZAPATILLAS TORNADO\n2 BATE RÚNICO\n3 BOMBAS AÉREAS"
    shots = [
        (Shot("hb_run3", 64.0, 6.0, 1.0, GAME, grade="challenge"), "cut", 0),
        (Shot("hb_run3", 71.6, 4.5, 1.0, Cam((0.5, 0.5, 1.8), (0.5, 0.5, 1.9)), grade="challenge", freeze_at=0.3, layout="fit"), "flash", 0.2),
        (Shot("hb_run3", 73.0, 6.0, 1.0, GAME, grade="challenge"), "cut", 0),
    ]
    q = "Which one would you pick?" if lang == "en" else "¿Cuál elegirías?"
    L = [title(q, 6.1, 10.4, y=300, size=78, path=FONT_UI, stroke=6, anim="pop"),
         title(names, 6.4, 10.4, y=1520, size=58, path=FONT_UI, stroke=6),
         title("3", 7.4, 8.3, y=560, size=200, anim="pop"), title("2", 8.3, 9.2, y=560, size=200, anim="pop"),
         title("1", 9.2, 10.1, y=560, size=200, anim="pop"),
         title("Comment 1, 2 or 3 ↓" if lang == "en" else "Comenta 1, 2 o 3 ↓", 10.6, 16.4, y=300, size=70, path=FONT_UI, stroke=6)]
    e = HBEdit("hb04", shots, L, lang=lang, end=2.0)
    cues = [(6.0, sfx("pop"), 0.7), (7.4, sfx("tick"), 0.8), (8.3, sfx("tick"), 0.8), (9.2, sfx("tick"), 0.8), (10.1, sfx("ding"), 0.7)]
    return e, dict(bed=music("quiz"), bed_gain=0.5, cues=cues, silences=[(6.0, 10.2)]), 6.5, "PICK A CARD" if lang == "en" else "ELIGE CARTA"


REELS = {"hb01_four_minutes": _01_four_minutes, "hb02_it_evolved": _02_it_evolved, "hb03_calm_chaos": _03_calm_chaos,
         "hb04_pick_a_card": _04_pick_a_card}

if __name__ == "__main__":
    ids = sys.argv[1:]
    for k, fn in REELS.items():
        if ids and not any(k.startswith(i) for i in ids):
            continue
        for lang in ("en", "es"):
            e, audio, cover_t, cover_txt = fn(lang)
            out = os.path.join(OUT, f"{k}_{lang}.mp4")
            e.render(out, audio, sheet_path=os.path.join(SHEETS, f"{k}_{lang}.jpg"))
            cover(e, cover_t, cover_txt, os.path.join(STUDIO, "HORDEBOUND", "THUMBNAILS", f"{k}_{lang}.jpg"))
