"""Banners, Instagram (posts, carousel, stories), community posts, templates and YouTube thumbnails.
Each format is composed for its own size and safe zone (not a crop of a square image)."""
import os, shutil, glob
from comp import *

R = ROOT


def bg_from(src, size, focus=(0.5, 0.5), zoom=1.0, dark=1.0, blur=0):
    im = grade(frame(src, size=size, focus=focus, zoom=zoom))
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    if dark != 1.0:
        im = ImageEnhance.Brightness(im).enhance(dark)
    return im


def H(text, size, colors=GOLD, maxw=None):
    h = headline(text, size, colors)
    return fit(h, w=maxw) if maxw and h.width > maxw else h


def logo_w(kind, w, bg="oscuro"):
    return fit(logo(kind, bg), w=w)


ICON_C = os.path.join(R, "02_ROBLOX_ICONS", "THNE_icono_C_mirar_el_pozo_1024.png")
ICON_A = os.path.join(R, "02_ROBLOX_ICONS", "THNE_icono_A_corte_1024.png")
SYMBOL = os.path.join(R, "01_BRANDING", "logo", "THNE_logo_symbol_fondo_oscuro.png")


def banners():
    out = os.path.join(R, "04_BANNERS")
    # main web/press banner 1920x600
    im = bg_from(clip_frame("plot_crane", 300), (1920, 600), (0.5, 0.62), dark=0.85)
    im = gradient_band(im, "left", 0.6, alpha=0.6)
    im = place(im, logo_w("horizontal_en", 1100), (60, 300), "cl")
    save_jpg(im, os.path.join(out, "THNE_banner_principal_1920x600.jpg"))
    # YouTube channel art 2560x1440 (safe area 1546x423 in the centre)
    im = bg_from(clip_frame("plot_crane", 300), (2560, 1440), (0.5, 0.6), dark=0.9)
    im = gradient_band(gradient_band(im, "top", 0.35, alpha=0.35), "bottom", 0.35, alpha=0.35)
    im = place(im, logo_w("horizontal_en", 1450), (1280, 720), "cc")
    save_jpg(im, os.path.join(out, "THNE_banner_youtube_2560x1440.jpg"))
    # X / Twitter header 1500x500
    im = bg_from(still("s01_plot_wide_1640"), (1500, 500), (0.5, 0.55), dark=0.85)
    im = place(im, logo_w("horizontal_en", 980), (750, 250), "cc")
    save_jpg(im, os.path.join(out, "THNE_cabecera_x_1500x500.jpg"))
    # launch banners (ES/EN) 1920x1080 and 1080x1350
    for lang, txt, lg in (("es", "¡YA EN ROBLOX!", "main_es"), ("en", "OUT NOW ON ROBLOX!", "main_en")):
        im = bg_from(clip_frame("surface_hero", 200), (1920, 1080), (0.5, 0.45), dark=0.6, blur=3)
        im = place(im, logo_w(lg, 1150), (960, 80), "tc")
        im = place(im, pill(txt, 96, bg=(120, 220, 90)), (960, 860), "cc")
        save_jpg(im, os.path.join(out, f"THNE_banner_lanzamiento_{lang}_1920x1080.jpg"))
    # next-update template (text slot to fill with a REAL feature when it exists)
    for lang, hdr in (("es", "PRÓXIMA ACTUALIZACIÓN"), ("en", "NEXT UPDATE")):
        im = bg_from(still("abyss_07"), (1920, 1080), (0.55, 0.5), dark=0.55, blur=4)
        im = place(im, logo_w("horizontal_en", 700), (60, 50), "tl")
        im = place(im, H(hdr, 120, CYAN), (960, 330), "tc")
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([360, 560, 1560, 800], 30, outline=(255, 255, 255), width=6)
        im = place(im, body_text("[ escribe aquí la novedad real ]" if lang == "es" else "[ write the real feature here ]", 54, (255, 255, 255)), (960, 680), "cc")
        save_jpg(im, os.path.join(out, f"THNE_plantilla_proxima_actualizacion_{lang}_1920x1080.jpg"))


def instagram():
    out = os.path.join(R, "05_INSTAGRAM")
    W, Hh = 1080, 1350
    # presentation post (4:5)
    im = bg_from(clip_frame("surface_hero", 200), (W, Hh), (0.55, 0.5))
    im = gradient_band(im, "top", 0.4, alpha=0.55)
    im = place(im, logo_w("main_es", 900), (W // 2, 70), "tc")
    im = place(im, body_text("Cava en tu jardín hasta el fondo del mundo.", 52, (255, 255, 255), stroke=5, max_w=900), (W // 2, 1180), "cc")
    save_jpg(im, os.path.join(out, "THNE_post_presentacion_1080x1350.jpg"))
    # carousel (5 slides, 4:5)
    slides = [
        (still("s01_plot_wide_1640"), (0.5, 0.55), "HEREDAS UNA CASA", "…y una nota firmada por «E.» que dice: cava."),
        (still("crystal_cave_07"), (0.6, 0.5), "7 ZONAS", "Jardín · Minas · Cristal · Cavernas · Volcán · Abismo · ???"),
        (still("garage2_07"), (0.5, 0.5), "10 HERRAMIENTAS", "De la pala oxidada a la perforadora abisal."),
        (still("legendary2_00"), (0.6, 0.4), "HALLAZGOS", "Minerales, fósiles, geodas… y algún legendario."),
    ]
    car = os.path.join(out, "carrusel_presentacion")
    im = Image.new("RGB", (W, Hh), (14, 18, 36))
    im = place(im, fit(Image.open(SYMBOL).convert("RGBA"), w=620), (W // 2, 120), "tc")
    im = place(im, logo_w("main_es", 900), (W // 2, 800), "tc")
    save_jpg(im, os.path.join(car, "01_portada.jpg"))
    for i, (src, foc, t, sub) in enumerate(slides, start=2):
        im = bg_from(src, (W, Hh), foc)
        im = gradient_band(gradient_band(im, "top", 0.35, alpha=0.6), "bottom", 0.35, alpha=0.6)
        im = place(im, H(t, 110, GOLD if i % 2 else CYAN, 960), (W // 2, 80), "tc")
        im = place(im, body_text(sub, 48, (255, 255, 255), stroke=4, max_w=940), (W // 2, 1180), "cc")
        save_jpg(im, os.path.join(car, f"{i:02d}_{t.lower().replace(' ', '_')}.jpg"))
    im = bg_from(clip_frame("plot_crane", 330), (W, Hh), (0.5, 0.6), dark=0.5, blur=6)
    im = place(im, H("¿HASTA DÓNDE\nLLEGARÁS?", 110, GOLD, 960), (W // 2, 200), "tc")
    im = place(im, pill("GRATIS EN ROBLOX", 70, bg=(120, 220, 90)), (W // 2, 760), "cc")
    im = place(im, body_text("Enlace en la bio", 54, (255, 255, 255), stroke=4), (W // 2, 900), "cc")
    save_jpg(im, os.path.join(car, "06_llamada.jpg"))
    # stories 1080x1920 (text kept between y 250 and 1500; stickers are added in the app)
    st = os.path.join(out, "stories")
    S = (1080, 1920)
    stories = [
        ("01_pregunta_rapida", clip_frame("plot_crane", 300), 0.5, "PREGUNTA\nRÁPIDA 👇".replace(" 👇", ""), "Pon aquí la encuesta: ¿Juegas a Roblox?"),
        ("02_llevo_meses", clip_frame("surface_hero", 150), 0.55, "LLEVO MESES CON\nESTO EN SECRETO…", "Desliza el emoji 😱 (sticker)".replace(" 😱", "")),
        ("03_icono_a_o_b", None, 0.5, "¿CUÁL TE DAN MÁS\nGANAS DE JUGAR?", "Encuesta: A / B"),
        ("04_busco_testers", still("abyss_07"), 0.55, "BUSCO 50 PERSONAS\nDE 16+ PARA PROBARLO", "Sticker de enlace (ig_beta)"),
        ("05_cuenta_atras", clip_frame("crystal_action", 251), 0.6, "SE ABRE\nEL AGUJERO", "Sticker de cuenta atrás"),
        ("06_ya_esta", clip_frame("surface_hero", 220), 0.55, "¡YA ESTÁ!\nGRATIS EN ROBLOX", "Sticker de enlace (ig_stories)"),
        ("07_a_cuantos_metros", clip_frame("descent_b", 300), 0.5, "¿A CUÁNTOS METROS\nHAS LLEGADO?", "Sticker de pregunta"),
    ]
    for name, src, foc, t, hint in stories:
        if src is None:
            im = Image.new("RGB", S, (14, 18, 36))
            a = Image.open(ICON_A).convert("RGB").resize((470, 470)); c = Image.open(ICON_C).convert("RGB").resize((470, 470))
            im.paste(a, (50, 640)); im.paste(c, (560, 640))
            im = place(im, pill("A", 90, bg=(255, 210, 60)), (285, 1180), "cc"); im = place(im, pill("B", 90, bg=(90, 230, 255)), (795, 1180), "cc")
        else:
            im = bg_from(src, S, (foc, 0.5))
            im = gradient_band(im, "top", 0.4, alpha=0.6)
        im = place(im, H(t, 96, GOLD, 960), (540, 300), "tc")
        save_jpg(im, os.path.join(st, f"THNE_story_{name}.jpg"))
    # community posts 1080x1080
    cm = os.path.join(out, "comunidad")
    posts = [("a_cuantos_metros", clip_frame("descent_b", 4), "¿A CUÁNTOS METROS\nHAS LLEGADO?", "Dímelo en comentarios 👇".replace(" 👇", "")),
             ("captura_de_la_semana", still("crystal_cave_07"), "CAPTURA DE\nLA SEMANA", "Etiqueta tus mejores capturas del juego"),
             ("adivina_la_zona", still("abyss_07"), "¿EN QUÉ ZONA\nESTOY?", "Pista: hay setas que brillan")]
    for name, src, t, sub in posts:
        im = bg_from(src, (1080, 1080))
        im = gradient_band(gradient_band(im, "top", 0.4, alpha=0.55), "bottom", 0.3, alpha=0.55)
        im = place(im, H(t, 96, GOLD, 980), (540, 60), "tc")
        im = place(im, body_text(sub, 44, (255, 255, 255), stroke=4, max_w=960), (540, 980), "cc")
        save_jpg(im, os.path.join(cm, f"THNE_comunidad_{name}_1080x1080.jpg"))
    # templates: discovery / tool / news (1080x1350) with an editable slot
    tp = os.path.join(out, "plantillas")
    for name, hdr, col in (("nuevo_descubrimiento", "¡NUEVO HALLAZGO!", CYAN), ("herramienta", "HERRAMIENTA", GOLD), ("novedad", "NOVEDAD", GOLD)):
        im = Image.new("RGB", (W, Hh), (14, 18, 36))
        grad = Image.new("RGB", (W, Hh)); dg = ImageDraw.Draw(grad)
        for y in range(Hh):
            k = y / Hh; dg.line([(0, y), (W, y)], fill=(int(22 + 30 * k), int(28 + 10 * k), int(60 + 40 * (1 - k))))
        im = grad
        im = place(im, H(hdr, 110, col, 960), (W // 2, 80), "tc")
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([90, 330, W - 90, 1030], 40, outline=(255, 255, 255), width=6)
        im = place(im, body_text("[ captura real aquí ]", 48, (200, 210, 230)), (W // 2, 680), "cc")
        im = place(im, body_text("[ nombre · dato real ]", 52, (255, 255, 255), stroke=4), (W // 2, 1120), "cc")
        im = place(im, logo_w("horizontal_en", 620), (W // 2, 1270), "cc")
        save_png(im, os.path.join(tp, f"THNE_plantilla_{name}_1080x1350.png"))


def youtube():
    out = os.path.join(R, "07_YOUTUBE")
    S = (1280, 720)
    items = [("trailer_oficial", clip_frame("surface_hero", 200), (0.5, 0.45), "TRÁILER", None),
             ("cave_1000m", clip_frame("descent_b", 4), (0.5, 0.62), "CAVÉ 1.000 m", None),
             ("las_7_capas", None, None, "LAS 7 CAPAS", None),
             ("devlog", still("s01_plot_wide_1640"), (0.5, 0.55), "HICE UN JUEGO\nEN ROBLOX", None)]
    for name, src, foc, t, _ in items:
        if src is None:
            im = Image.new("RGB", S)
            parts = [still("s01_plot_wide_1640"), clip_frame("mines_action", 400), clip_frame("crystal_action", 251), still("abyss_07")]
            for i, p in enumerate(parts):
                im.paste(grade(frame(p, size=(320, 720))), (i * 320, 0))
        else:
            im = bg_from(src, S, foc)
        im = gradient_band(im, "left", 0.65, alpha=0.6)
        im = place(im, H(t, 120, GOLD, 700), (40, 360), "cl")
        im = place(im, logo_w("horizontal_en", 520), (1240, 690), "br")
        save_jpg(im, os.path.join(out, f"THNE_miniatura_youtube_{name}_1280x720.jpg"), max_mb=1.9)


def tiktok_copies():
    src = os.path.join(R, "05_INSTAGRAM", "portadas_reels")
    dst = os.path.join(R, "06_TIKTOK", "portadas")
    os.makedirs(dst, exist_ok=True)
    for f in glob.glob(os.path.join(src, "*.jpg")):
        shutil.copy(f, os.path.join(dst, os.path.basename(f)))


if __name__ == "__main__":
    banners(); instagram(); youtube(); tiktok_copies()
    print("social done")
