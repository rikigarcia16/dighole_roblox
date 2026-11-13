"""Hordebound reels v2: hook in the first second, short (8-14 s + call to action), smooth 30 fps footage
(hb2_* recorded 13 Nov 2026 in a Studio test session, nothing saved), a fixed "search HORDEBOUND" sticker and an
animated end card where a search bar types the game's name.
python hb_reels_v2.py [ids]"""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "EDITABLE_PROJECTS", "engine"))
from engine import *
import hb_split as HS

register("hb2_god", "hb2_menu", "hb2_results", "hb2_risk")
OUT = os.path.join(HERE, "FINAL_V2")
SHEETS = os.path.join(HERE, "STORYBOARDS_V2")
GOLD = (255, 214, 120)
RED = (230, 40, 70)
GAME = Cam((0.5, 0.47, 1.22))
CLOSE = Cam((0.5, 0.47, 1.6))

TX = {
    "en": dict(search="Search on Roblox:", free="FREE · LINK IN BIO", sticker="HORDEBOUND · ROBLOX"),
    "es": dict(search="Búscalo en Roblox:", free="GRATIS · LINK EN LA BIO", sticker="HORDEBOUND · ROBLOX"),
}


def sticker(lang, t0, t1):
    """Small search pill under the safe zone, visible for the whole reel."""
    bar = HS.search_bar("HORDEBOUND", 10, width=520, height=78)

    def draw(im, lt, dur):
        return paste(im, bar, (W // 2, 1640), "cc", min(1, lt / 0.3))
    return Layer(t0, t1, draw)


def end_screen(lang, lt, bg):
    im = bg.copy()
    im = paste(im, text_img("HORDEBOUND", 150, FONT_TITLE, GOLD, 12), (W // 2, 560), "cc")
    sub = "SURVIVE THE HORDE" if lang == "en" else "SOBREVIVE A LA HORDA"
    im = paste(im, text_img(sub, 50, FONT_UI, (255, 255, 255), 6), (W // 2, 680), "cc")
    im = paste(im, text_img(TX[lang]["search"], 56, FONT_UI, (255, 255, 255), 6), (W // 2, 860), "cc")
    typed = int(min(10, max(0, (lt - 0.2) / 0.07)))
    im = paste(im, HS.search_bar("HORDEBOUND", typed, width=940, height=140), (W // 2, 990), "cc")
    if lt > 1.0:
        u = min(1, (lt - 1.0) / 0.2)
        im = paste(im, C.pill(TX[lang]["free"], 66, bg=(120, 220, 90)).convert("RGBA"), (W // 2, 1200), "cc", u, 0.7 + 0.3 * u)
    return im


class V2(Edit):
    def __init__(self, vid, shots, layers, lang="en", end=2.6):
        super().__init__(vid, shots, list(layers) + [sticker(lang, 0, sum(s[0].dur for s in shots))], lang=lang, end=end)
        c = V.clip("hb2_menu")
        bg = frame_full(c.at(3.0), (0.62, 0.5, 1.0), (W, H))
        self._bg = ImageEnhance.Brightness(bg.filter(ImageFilter.GaussianBlur(8))).enhance(0.45)
        self._end = None

    def frame(self, t):
        if t >= self.body:
            lt = t - self.body
            e = end_screen(self.lang, lt, self._bg)
            if lt < 0.3:
                last = self.shots[-1][0]
                return transition("flash", last.render(last.dur - 0.01), e, lt / 0.3)
            return e
        return super().frame(t)


def L(lang, en, es):
    return en if lang == "en" else es


# ---------------------------------------------------------------------------------------- reels
# Times in hb2_god (seconds from the start of the recording) are filled in after reviewing the take.
T_PEAK = 248.0      # most enemies on screen, boss present
T_EMPTY = 7.0       # hero alone, first enemies
T_CARD = 60.0       # a level-up card screen
T_BOSS = 240.0


def r_minute4(lang):
    """Payoff first: minute 4 chaos -> 'it started like this' -> 25x timelapse back to the chaos (loops)."""
    shots = [
        (Shot("hb2_god", T_PEAK, 2.4, 1.0, Cam((0.5, 0.47, 1.5), (0.5, 0.47, 1.22), shake=3), grade="challenge"), "flash", 0.15),
        (Shot("hb2_god", T_EMPTY, 1.4, 1.0, GAME, grade="cinematic"), "cut", 0),
        (Shot("hb2_god", T_EMPTY + 1.4, 7.0, 0, GAME, grade="challenge", ramp=[(0, 6), (3.5, 50), (7.0, 30)]), "cut", 0),
    ]
    Ls = [title(L(lang, "This is minute 4 💀", "Esto es el minuto 4 💀").replace(" 💀", ""), 0.0, 2.4, y=300, size=96, anim="pop"),
          title(L(lang, "It started like this:", "Empezó así:"), 2.4, 3.8, y=300, size=84, path=FONT_UI, stroke=7),
          title(L(lang, "4 minutes later…", "4 minutos después…"), 3.8, 10.8, y=300, size=78, path=FONT_UI, stroke=7)]
    cues = [(0.0, sfx("sub_boom"), 1.0), (2.4, sfx("whoosh_down"), 0.6), (3.8, sfx("riser"), 0.5), (10.6, sfx("impact"), 0.8)]
    return V2("v2_minute4", shots, Ls, lang), dict(bed=music("challenge"), bed_gain=0.55, cues=cues, silences=[(2.4, 3.8)]), 1.0, L(lang, "MINUTE 4", "MINUTO 4")


def r_last10(lang):
    """Challenge: 'Survive the last 10 seconds' with a big countdown over real footage."""
    s0 = T_PEAK - 10.0
    shots = [(Shot("hb2_god", s0, 10.0, 1.0, Cam((0.5, 0.47, 1.22), (0.5, 0.47, 1.45), shake=2), grade="challenge"), "cut", 0)]
    Ls = [title(L(lang, "Survive the last 10 seconds", "Sobrevive los últimos 10 segundos"), 0.0, 2.2, y=300, size=80, anim="pop"),
          big_timer(lambda lt: max(0, 10 - lt), 0.0, 10.0, y=470, size=170, color=(255, 80, 80))]
    cues = [(float(i), sfx("tick"), 0.7) for i in range(10)] + [(9.9, sfx("sub_boom"), 1.0)]
    return V2("v2_last10", shots, Ls, lang), dict(bed=music("challenge"), bed_gain=0.5, cues=cues), 5.0, L(lang, "LAST 10 S", "ÚLTIMOS 10 S")


def r_pick(lang):
    """Freeze on the real card screen within the first second; 3-2-1; comment your pick."""
    shots = [
        (Shot("hb2_god", T_CARD, 4.5, 1.0, Cam((0.5, 0.5, 1.8), (0.5, 0.5, 1.9)), grade="challenge", freeze_at=0.2, layout="fit"), "flash", 0.2),
        (Shot("hb2_god", T_CARD + 1.5, 5.0, 1.0, GAME, grade="challenge"), "cut", 0),
    ]
    Ls = [title(L(lang, "You have 3 seconds. Pick one.", "Tienes 3 segundos. Elige una."), 0.0, 4.4, y=300, size=72, path=FONT_UI, stroke=6, anim="pop"),
          title("3", 1.0, 2.0, y=1350, size=220, anim="pop"), title("2", 2.0, 3.0, y=1350, size=220, anim="pop"),
          title("1", 3.0, 4.0, y=1350, size=220, anim="pop"),
          title(L(lang, "Comment your pick ↓", "Comenta cuál ↓"), 4.6, 9.4, y=300, size=76, path=FONT_UI, stroke=6)]
    cues = [(0.0, sfx("pop"), 0.8), (1.0, sfx("tick"), 0.8), (2.0, sfx("tick"), 0.8), (3.0, sfx("tick"), 0.8), (4.0, sfx("ding"), 0.8)]
    return V2("v2_pick", shots, Ls, lang), dict(bed=music("quiz"), bed_gain=0.5, cues=cues, silences=[(0.0, 4.1)]), 0.5, L(lang, "PICK ONE", "ELIGE UNA")


def r_cleared(lang):
    """Real end screen of the run: 'ARENA CLEARED', record stats, with a fast recap before it."""
    shots = [
        (Shot("hb2_god", T_BOSS, 3.0, 1.0, Cam((0.5, 0.47, 1.4), (0.5, 0.47, 1.2), shake=3), grade="challenge"), "flash", 0.2),
        (Shot("hb2_results", 0.5, 3.4, 1.0, Cam((0.55, 0.5, 1.0)), grade="natural", layout="fit"), "cut", 0),
    ]
    Ls = [title(L(lang, "Can you beat the boss?", "¿Puedes con el jefe?"), 0.0, 3.0, y=300, size=84, anim="pop"),
          title(L(lang, "I did. Your turn 👇", "Yo sí. Te toca 👇").replace(" 👇", " ↓"), 3.2, 6.4, y=300, size=80, path=FONT_UI, stroke=7)]
    cues = [(0.0, sfx("sub_boom"), 0.9), (3.0, sfx("stamp"), 0.8), (3.1, sfx("ding"), 0.6)]
    return V2("v2_cleared", shots, Ls, lang), dict(bed=music("challenge"), bed_gain=0.5, cues=cues), 4.0, L(lang, "BOSS DOWN", "JEFE VENCIDO")


LANGS = ("en",)   # English first (the user tests the English versions); add "es" to also render Spanish
REELS = {"v2_minute4": r_minute4, "v2_last10": r_last10, "v2_pick": r_pick, "v2_cleared": r_cleared}

if __name__ == "__main__":
    ids = sys.argv[1:]
    for k, fn in REELS.items():
        if ids and not any(k.startswith(i) for i in ids):
            continue
        for lang in LANGS:
            e, audio, ct, ctext = fn(lang)
            e.render(os.path.join(OUT, f"hb_{k}_{lang}.mp4"), audio, sheet_path=os.path.join(SHEETS, f"hb_{k}_{lang}.jpg"))
            cover(e, ct, ctext, os.path.join(HERE, "THUMBNAILS_V2", f"hb_{k}_{lang}.jpg"))
