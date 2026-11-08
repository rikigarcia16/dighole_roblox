"""15 vertical shorts (1080x1920, 30 fps) for Reels / TikTok / Shorts, plus a cover for each.
Real gameplay only; every claim is something that exists in the game.
Safe zone used for text: x 80..1000, y 250..1450 (platform UI covers the bottom and right edge).
Usage: python make_shorts.py [ids...]"""
import sys, os
from video import *

W, H = 1080, 1920
OUT = os.path.join(ROOT, "12_FINAL_EXPORTS", "shorts_9x16")
COVERS = os.path.join(ROOT, "05_INSTAGRAM", "portadas_reels")


def vf(focus=0.5, zoom=1.0):
    return lambda im: vert_full(im, focus, zoom)


def vb(focus=0.5, zoom=1.0):
    return lambda im: vert_framed(im, focus, zoom)


def hook(text, size=96, colors=GOLD, y=300, t0=0.0, t1=2.8):
    img = headline(text, size, colors)
    if img.width > 940:
        img = fit(img, w=940)
    return Overlay(img, t0, t1, (W // 2, y), "tc")


def cap(text, t0, t1, y=1250, size=78, colors=WHITE):
    img = headline(text, size, colors)
    if img.width > 940:
        img = fit(img, w=940)
    return Overlay(img, t0, t1, (W // 2, y), "cc")


def end_card(text="BÚSCALO EN ROBLOX", bg_clip="plot_crane", bg_t=9.5):
    card = ImageEnhance.Brightness(vert_full(clip(bg_clip).at(bg_t), 0.5).filter(ImageFilter.GaussianBlur(12))).enhance(0.42)
    card = place(card, fit(logo("main_en", "oscuro"), w=900), (W // 2, 330), "tc")
    card = place(card, pill(text, 66, bg=(120, 220, 90)), (W // 2, 1050), "cc")
    card = place(card, body_text("The Hole Never Ends\nEnlace en la bio", 50, (255, 255, 255), stroke=4), (W // 2, 1230), "cc")
    return card


def make(sid, title, segs, ovs, music="music_short_upbeat_120bpm.wav", cues=(), card_text="BÚSCALO EN ROBLOX", card_s=2.6,
         cover=None, music_start=0.0):
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, f"THNE_short_{sid}.mp4")
    render(segs, ovs, out, (W, H), list(cues), music, 0.8, music_start, tail_card=(end_card(card_text), card_s), crf=19)
    # cover: chosen frame + hook
    if cover:
        name, t, layout, text = cover
        im = layout(clip(name).at(t))
        im = gradient_band(im, "top", 0.35, alpha=0.55)
        h = headline(text, 110, GOLD)
        if h.width > 960:
            h = fit(h, w=960)
        im = place(im, h, (W // 2, 330), "tc")
        im = place(im, fit(logo("horizontal_en", "oscuro"), w=640), (W // 2, 1380), "tc")
        save_jpg(im, os.path.join(COVERS, f"THNE_portada_{sid}.jpg"))


def starts_of(segs):
    return np.cumsum([0] + [s.dur for s in segs])


SHORTS = {}


def short(fn):
    SHORTS[fn.__name__[1:]] = fn
    return fn


@short
def _01_cave_1000m_en_mi_jardin():
    segs = [Seg("plot_crane", 7.5, 1.6, vf(0.5)), Seg("descent_b", 0.0, 9.0, vf(0.5), speed=1.12)]
    st = starts_of(segs)
    ov = [hook("CAVÉ 1.000 m\nEN MI JARDÍN", 104, t1=st[1] + 1.2)]
    depths = [("50 m", 2.0), ("150 m", 3.6), ("350 m", 5.2), ("650 m", 6.9), ("1.000 m", 8.6)]
    for k, (d, t) in enumerate(depths):
        ov.append(Overlay(headline(d, 150, CYAN if k > 1 else GOLD), t, (depths[k + 1][1] if k + 1 < len(depths) else st[-1]) - 0.03, (W // 2, 900), "cc"))
    cues = [(st[1] - 0.2, "sfx_whoosh_down.wav", 0.9), (st[-1] - 0.05, "sfx_impact.wav", 0.8)]
    make("01_cave_1000m_en_mi_jardin", "", segs, ov, cues=cues, cover=("descent_b", 0.1, vf(0.5), "CAVÉ 1.000 m\nEN MI JARDÍN"))


@short
def _02_que_hay_debajo_de_tu_casa():
    segs = [Seg("surface_hero", 1.0, 2.2, vf(0.55)), Seg("plot_crane", 8.0, 1.6, vf(0.5)), Seg("descent_b", 1.5, 3.0, vf(0.5), speed=2.0),
            Seg("mines_action", 5.2, 1.4, vf(0.45), flash_in=True), Seg("crystal_action", 3.0, 1.4, vf(0.6), flash_in=True),
            Seg("abyss_action", 0.0, 1.6, vf(0.5), flash_in=True)]
    st = starts_of(segs)
    ov = [hook("¿QUÉ HAY DEBAJO\nDE TU CASA?", 104, t1=st[2]), cap("MINAS", st[3] + 0.1, st[4] - 0.05), cap("CRISTAL", st[4] + 0.1, st[5] - 0.05, colors=CYAN),
          cap("EL ABISMO", st[5] + 0.1, st[6] - 0.05, colors=CYAN)]
    cues = [(st[2] - 0.1, "sfx_whoosh_down.wav", 0.8)] + [(st[i], "sfx_impact.wav", 0.35) for i in (3, 4, 5)]
    make("02_que_hay_debajo_de_tu_casa", "", segs, ov, cues=cues, cover=("surface_hero", 2.0, vf(0.55), "¿QUÉ HAY DEBAJO\nDE TU CASA?"))


@short
def _03_herramienta_1_vs_10():
    segs = [Seg("garage_pan", 0.3, 7.4, vb(0.5, 1.0)), Seg("showcase_ui", 1.8, 3.2, vb(0.42, 1.25))]
    st = starts_of(segs)
    ov = [hook("HERRAMIENTA 1\nVS HERRAMIENTA 10", 96, t1=st[-1]), cap("PALAS", 0.6, 2.6, y=1600), cap("PICOS", 2.8, 4.6, y=1600),
          cap("TALADROS", 4.8, st[1] - 0.05, y=1600, colors=CYAN), cap("POTENCIA 85", st[1] + 0.6, st[-1], y=1600, colors=CYAN)]
    cues = [(st[1] + 0.3, "sfx_legendary_shimmer.wav", 0.7)]
    make("03_herramienta_1_vs_10", "", segs, ov, cues=cues, cover=("showcase_ui", 3.0, vb(0.42, 1.25), "HERRAMIENTA 1\nVS 10"))


@short
def _04_el_mineral_mas_raro():
    segs = [Seg("abyss_action", 0.0, 1.8, vb(0.5)), Seg("legendary_ui", 2.6, 4.6, vb(0.5, 1.0))]
    st = starts_of(segs)
    ov = [hook("EL MINERAL MÁS RARO\nDEL JUEGO", 92, colors=CYAN, t1=st[1] + 0.6), cap("¿CUÁNTO CREES\nQUE VALE?", st[1] + 2.4, st[-1], y=1450, size=84)]
    cues = [(st[1] + 0.9, "sfx_legendary_shimmer.wav", 0.9)]
    make("04_el_mineral_mas_raro", "", segs, ov, music="music_mystery_depths_90bpm.wav", music_start=10, cues=cues,
         cover=("legendary_ui", 4.0, vf(0.5), "EL MINERAL\nMÁS RARO"))


@short
def _05_picar_cristal_camara_lenta():
    segs = [Seg("crystal_action", 0.5, 11.0, vf(0.58, 1.05), speed=0.7)]
    ov = [hook("PICAR CRISTAL\nA CÁMARA LENTA", 96, colors=CYAN, t1=3.2)]
    cues = [(0.4 + k * 1.2, "sfx_dig_hit.wav", 0.55) for k in range(9)]
    make("05_picar_cristal_camara_lenta", "", segs, ov, music="music_mystery_depths_90bpm.wav", music_start=12, cues=cues,
         cover=("crystal_action", 6.3, vf(0.58, 1.05), "PICAR CRISTAL\nA CÁMARA LENTA"))


@short
def _06_pov_heredas_una_casa():
    segs = [Seg("plot_crane", 3.0, 2.6, vf(0.5)), Seg("surface_hero", 1.0, 2.8, vf(0.55)), Seg("dig_surface", 1.0, 3.6, vf(0.5)),
            Seg("descent_b", 0.5, 3.0, vf(0.5), speed=2.2)]
    st = starts_of(segs)
    ov = [hook("POV: HEREDAS UNA CASA\nCON JARDÍN…", 92, t1=st[1]), cap("…Y UNA NOTA\nQUE DICE «CAVA»", st[1] + 0.2, st[2] - 0.05, y=420),
          cap("ASÍ QUE CAVAS", st[2] + 0.2, st[3] - 0.05, y=420, colors=GOLD), cap("Y CAVAS…", st[3] + 0.2, st[4] - 0.05, y=420, colors=CYAN)]
    cues = [(st[1] + 0.35 + k * 0.75, "sfx_dig_hit.wav", 0.4) for k in range(3)] + [(st[3] - 0.1, "sfx_whoosh_down.wav", 0.8)]
    make("06_pov_heredas_una_casa", "", segs, ov, cues=cues, cover=("plot_crane", 4.5, vf(0.5), "POV: HEREDAS\nUNA CASA…"))


@short
def _07_las_7_capas():
    layers = [("plot_crane", 8.5, 0.5, "1. EL JARDÍN", "0–50 m"), ("mines_action", 5.4, 0.45, "2. MINAS OLVIDADAS", "50–150 m"),
              ("crystal_action", 3.4, 0.6, "3. CUEVAS DE CRISTAL", "150–350 m"), ("descent_b", 5.4, 0.5, "4. CAVERNAS ANTIGUAS", "350–650 m"),
              ("descent_b", 7.4, 0.5, "5. PROFUNDIDADES VOLCÁNICAS", "650–1.000 m"), ("abyss_action", 0.2, 0.5, "6. EL ABISMO", "1.000–1.500 m"),
              ("descent_b", 9.9, 0.5, "7. ???", "1.500–2.200 m")]
    segs, ov = [], []
    for name, t, fx, lab, rng_ in layers:
        segs.append(Seg(name, t, 1.55, vf(fx), flash_in=True))
    st = starts_of(segs)
    ov.append(hook("LAS 7 CAPAS\nDEL AGUJERO", 104, t1=st[-1], y=260))
    for i, (_, _, _, lab, rng_) in enumerate(layers):
        ov.append(cap(lab, st[i] + 0.05, st[i + 1] - 0.03, y=880, size=78, colors=CYAN if i >= 2 else GOLD))
        ov.append(Overlay(pill(rng_, 56, bg=(255, 255, 255)), st[i] + 0.1, st[i + 1] - 0.03, (W // 2, 1010), "cc"))
    cues = [(st[i], "sfx_whoosh_down.wav", 0.35) for i in range(len(layers))] + [(st[6], "sfx_impact.wav", 0.7)]
    make("07_las_7_capas", "", segs, ov, cues=cues, cover=("crystal_action", 4.0, vf(0.6), "LAS 7 CAPAS\nDEL AGUJERO"))


@short
def _08_vendiendo_todo():
    segs = [Seg("sell_ui", 1.2, 6.5, vf(0.52, 1.0))]
    ov = [hook("TODO LO QUE CAVAS\nSE VENDE", 96, t1=2.6), cap("VENDE Y MEJORA", 3.0, 6.4, y=1380, colors=GOLD, size=92)]
    cues = [(0.9 + k * 0.18, "sfx_coin.wav", 0.45) for k in range(8)]
    make("08_a_vender", "", segs, ov, cues=cues, cover=("sell_ui", 3.0, vf(0.52), "¡A VENDER!"))


@short
def _09_no_mires_abajo():
    segs = [Seg("plot_crane", 9.0, 1.0, vf(0.5)), Seg("descent_b", 0.0, 5.0, vf(0.5), speed=2.0, fade_out=0.6)]
    st = starts_of(segs)
    ov = [hook("NO MIRES ABAJO.", 110, colors=WHITE, t1=st[1] + 0.8), cap("…DEMASIADO TARDE.", st[1] + 2.6, st[-1], y=900, size=90, colors=CYAN)]
    cues = [(st[1] - 0.1, "sfx_whoosh_down.wav", 1.0), (st[1] + 2.5, "sfx_impact.wav", 0.6)]
    make("09_no_mires_abajo", "", segs, ov, music="music_mystery_depths_90bpm.wav", music_start=8, cues=cues,
         cover=("descent_b", 0.05, vf(0.5), "NO MIRES\nABAJO."))


@short
def _10_alguien_cavo_aqui_antes():
    segs = [Seg("mines_action", 0.3, 4.0, vf(0.45, 1.0)), Seg("mines_action", 5.0, 3.5, vf(0.45))]
    st = starts_of(segs)
    ov = [hook("ALGUIEN CAVÓ AQUÍ\nANTES QUE YO", 92, colors=WHITE, t1=st[1]), cap("¿QUIÉN ERA «E.»?", st[1] + 0.4, st[-1], y=420, size=96)]
    cues = [(st[1] + 0.3 + k * 0.85, "sfx_dig_hit.wav", 0.4) for k in range(4)]
    make("10_alguien_cavo_aqui_antes", "", segs, ov, music="music_mystery_depths_90bpm.wav", music_start=4, cues=cues,
         cover=("mines_action", 6.0, vf(0.45), "ALGUIEN CAVÓ\nAQUÍ ANTES"))


@short
def _11_reto_adivina_la_profundidad():
    rounds = [("crystal_action", 3.2, 0.6, "150–350 m"), ("mines_action", 5.4, 0.45, "50–150 m"), ("abyss_action", 0.1, 0.5, "+1.000 m")]
    segs, ov = [], []
    for name, t, fx, ans in rounds:
        segs.append(Seg(name, t, 2.4, vf(fx), flash_in=True))
    st = starts_of(segs)
    ov.append(hook("RETO: ¿A QUÉ PROFUNDIDAD\nESTOY?", 84, t1=st[-1], y=260))
    for i, (_, _, _, ans) in enumerate(rounds):
        ov.append(Overlay(pill("?", 120, bg=(255, 210, 60)), st[i] + 0.1, st[i] + 1.3, (W // 2, 960), "cc"))
        ov.append(Overlay(pill(ans, 90, bg=(120, 220, 90)), st[i] + 1.35, st[i + 1] - 0.03, (W // 2, 960), "cc"))
    cues = [(st[i] + 1.35, "sfx_coin.wav", 0.6) for i in range(3)]
    make("11_reto_adivina_la_profundidad", "", segs, ov, cues=cues, card_text="¿CUÁNTOS ACERTASTE?",
         cover=("crystal_action", 4.0, vf(0.6), "¿A QUÉ\nPROFUNDIDAD?"))


@short
def _12_lo_he_hecho_yo():
    shots = [("plot_crane", 6.0, 0.5, "7 ZONAS"), ("descent_b", 4.0, 0.5, "2.200 METROS"), ("garage_pan", 4.5, 0.5, "10 HERRAMIENTAS"),
             ("crystal_action", 3.0, 0.6, "MINERALES Y HALLAZGOS"), ("mines_action", 5.3, 0.45, "UN MISTERIO"), ("surface_hero", 1.5, 0.55, "SIN MASCOTAS\nNI RENACIMIENTOS")]
    segs = [Seg(n, t, 1.7, vf(f), flash_in=i > 0) for i, (n, t, f, _) in enumerate(shots)]
    st = starts_of(segs)
    ov = [hook("LLEVO MESES HACIENDO\nESTE JUEGO EN ROBLOX", 84, colors=WHITE, t1=st[1], y=260)]
    for i, (_, _, _, lab) in enumerate(shots):
        if i:
            ov.append(cap(lab, st[i] + 0.05, st[i + 1] - 0.03, y=900, size=88, colors=GOLD if i % 2 else CYAN))
    ov.append(cap("¿LO PROBARÍAS?", st[-1] - 0.9, st[-1], y=900, size=100))
    cues = [(st[i], "sfx_whoosh_up.wav", 0.3) for i in range(1, len(shots))]
    make("12_lo_he_hecho_yo", "", segs, ov, cues=cues, cover=("surface_hero", 2.0, vf(0.55), "LO HE HECHO\nYO"))


@short
def _13_a_1000_metros_todo_brilla():
    segs = [Seg("abyss_action", 0.0, 2.2, vb(0.5)), Seg("legendary_ui", 0.2, 2.6, vb(0.5)), Seg("abyss_action", 8.3, 0.9, vb(0.5))]
    st = starts_of(segs)
    ov = [hook("A 1.000 METROS\nTODO BRILLA", 100, colors=CYAN, t1=st[-1])]
    make("13_a_1000_metros_todo_brilla", "", segs, ov, music="music_mystery_depths_90bpm.wav", music_start=14,
         cover=("abyss_action", 0.5, vf(0.5), "A 1.000 m\nTODO BRILLA"))


@short
def _14_mochila_llena():
    segs = [Seg("dig_surface", 0.5, 7.0, vf(0.5)), Seg("sell_ui", 1.6, 3.4, vf(0.52))]
    st = starts_of(segs)
    ov = [hook("CUANDO LA MOCHILA\nSE LLENA A 16 METROS…", 84, colors=WHITE, t1=st[1] - 0.2, y=260), cap("…Y TOCA SUBIR A VENDER", st[1] + 0.1, st[-1], y=420, size=80)]
    cues = [(0.6 + k * 0.6, "sfx_dig_hit.wav", 0.35) for k in range(10)] + [(st[1] + 0.6 + k * 0.2, "sfx_coin.wav", 0.4) for k in range(5)]
    make("14_mochila_llena", "", segs, ov, cues=cues, cover=("dig_surface", 6.0, vf(0.5), "MOCHILA\nLLENA…"))


@short
def _15_muy_pronto():
    shots = [("plot_crane", 9.0, 0.5), ("surface_hero", 2.0, 0.55), ("descent_b", 3.0, 0.5), ("mines_action", 5.6, 0.45),
             ("crystal_action", 4.0, 0.6), ("abyss_action", 0.4, 0.5), ("showcase_ui", 2.6, 0.42), ("legendary_ui", 3.8, 0.5)]
    beat = 60 / 120
    segs = [Seg(n, t, beat * 2, vf(f), flash_in=True, punch=0.1) for n, t, f in shots]
    st = starts_of(segs)
    ov = [hook("MUY PRONTO\nEN ROBLOX", 110, t0=st[-1] - 1.6, t1=st[-1], y=820)]
    cues = [(s, "sfx_whoosh_up.wav", 0.25) for s in st[:-1]] + [(st[-1], "sfx_impact.wav", 0.9)]
    make("15_muy_pronto", "", segs, ov, cues=cues, card_text="MUY PRONTO", cover=("crystal_action", 4.0, vf(0.6), "MUY PRONTO"))


if __name__ == "__main__":
    ids = sys.argv[1:]
    for k, fn in SHORTS.items():
        if ids and not any(k.startswith(i) for i in ids):
            continue
        fn()
