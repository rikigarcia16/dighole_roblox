"""Roblox Ads Manager creatives: 16:9 images (1920x1080), 5 concepts x 2 variants = 10 (the campaign maximum).
Text describes the game; no promises, prices, urgency or 'free Robux'."""
import os
from comp import *
from make_thumbnails import title, T03, T01b

OUT = suffix(os.path.join(ROOT, "08_ROBLOX_ADS"))
W, H = 1920, 1080


def corner_logo(img, w=560):
    return place(img, fit(logo("horizontal_en", "oscuro"), w=w), (40, 30), "tl")


def ad_excavacion_A():
    img = grade(frame(clip_frame("surface_hero", 200), focus=(0.5, 0.45)), sat=1.12)
    img = gradient_band(img, "top", 0.35, alpha=0.4)
    img = title(img, "CAVA EN TU JARDÍN", 70, 130)
    return place(img, fit(logo("horizontal_en", "oscuro"), w=640), (W - 40, H - 40), "br")


def ad_excavacion_B():
    img = grade(frame(clip_frame("dig_surface", 70), focus=(0.5, 0.5), zoom=1.15), sat=1.1)
    img = gradient_band(img, "top", 0.35, alpha=0.55)
    return title(img, "CAVA. VENDE. MEJORA.", 70, 120)


def ad_descubrimientos_A():
    img = grade(frame(still("legendary2_00"), crop=(560, 160, 2512, 1326), focus=(0.4, 0.3)), sat=1.15)
    img = gradient_band(img, "bottom", 0.3, alpha=0.5)
    return corner_logo(vignette(img, 0.3))


def ad_descubrimientos_B():
    """Hypothesis: the illustrated 3D key art attracts more clicks than a capture (compare with A)."""
    bg = ImageEnhance.Brightness(frame(clip_frame("crystal_action", 251)).filter(ImageFilter.GaussianBlur(14))).enhance(0.5)
    art = Image.open(os.path.join(ROOT, "02_ROBLOX_ICONS", "THNE_icono_B_pico_contra_cristal_1024.png")).convert("RGB").resize((900, 900), Image.LANCZOS)
    bg.paste(art, (W - 900 - 60, 90))
    d = ImageDraw.Draw(bg); d.rectangle([W - 966, 84, W - 54, 996], outline=INK, width=8)
    bg = place(bg, headline("MINERALES\nRAROS", 150, CYAN), (520, 300), "tc")
    return place(bg, fit(logo("horizontal_en", "oscuro"), w=700), (520, 760), "tc")


def ad_progresion_A():
    img = T01b(LANG)
    return img


def ad_progresion_B():
    img = grade(frame(clip_frame("descent_b", 4), focus=(0.5, 0.62), zoom=1.15), sat=1.12)
    img = vignette(img, 0.5, 0.3)
    img = gradient_band(img, "top", 0.4, alpha=0.45)
    img = title(img, "DE 0 A 2.200 m", 60, 160)
    return img


def ad_exploracion_A():
    img = grade(frame(clip_frame("crystal_action", 251), focus=(0.6, 0.5), zoom=1.15), sat=1.12, bri=1.06)
    img = vignette(img, 0.35)
    img = title(img, "EXPLORA 7 ZONAS", 60, 130, CYAN)
    return place(img, fit(logo("horizontal_en", "oscuro"), w=640), (W - 40, H - 40), "br")


def ad_exploracion_B():
    img = grade(frame(still("mines_act2_04"), zoom=1.05), sat=1.1, bri=1.08)
    img = vignette(img, 0.35)
    return title(img, "¿QUIÉN CAVÓ AQUÍ ANTES?", 60, 110, WHITE)


def ad_herramientas_A():
    return T03(LANG)


def ad_herramientas_B():
    sw = Image.open(still("showcase_05")).width
    img = grade(frame(still("showcase_05"), crop=(int(sw * 0.12), 110, int(sw * 0.88), 1326), focus=(0.5, 0.5)))
    img = gradient_band(img, "top", 0.3, alpha=0.4)
    return title(img, "MEJORA TU HERRAMIENTA", 40, 110)


ADS = [
    ("01_excavacion_A", ad_excavacion_A, "El gesto central (cavar en un jardín) es lo más original y se entiende al instante."),
    ("01_excavacion_B", ad_excavacion_B, "Mostrar el bucle completo con la interfaz real atrae a quien busca juegos de progresión."),
    ("02_descubrimientos_A", ad_descubrimientos_A, "El momento «¡LEGENDARIO!» con la interfaz real genera curiosidad por la recompensa."),
    ("02_descubrimientos_B", ad_descubrimientos_B, "El arte 3D ilustrado consigue más clics que una captura (comparar con A)."),
    ("03_progresion_A", ad_progresion_A, "Ver tres profundidades reales comunica escala: el juego no se acaba pronto."),
    ("03_progresion_B", ad_progresion_B, "Una cifra concreta (2.200 m) es un objetivo claro y medible para el jugador."),
    ("04_exploracion_A", ad_exploracion_A, "Las cuevas de colores atraen a jugadores de exploración más que el jardín."),
    ("04_exploracion_B", ad_exploracion_B, "Una pregunta de misterio atrae a jugadores de historia y secretos."),
    ("05_herramientas_A", ad_herramientas_A, "El antes y después de herramienta funciona en el género simulador."),
    ("05_herramientas_B", ad_herramientas_B, "La presentación 3D de herramienta nueva (interfaz real) transmite recompensa."),
]

if __name__ == "__main__":
    lines = ["# Creatividades de Roblox Ads (1920x1080, 16:9)\n", "| Archivo | Hipótesis |", "|---|---|"]
    for name, fn, hyp in ADS:
        p = save_jpg(fn(), os.path.join(OUT, f"THNE_anuncio_{name}{'_en' if LANG == 'en' else ''}.jpg"))
        lines.append(f"| `THNE_anuncio_{name}{'_en' if LANG == 'en' else ''}.jpg` | {hyp} |")
        print(p)
    open(os.path.join(OUT, "HIPOTESIS.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
