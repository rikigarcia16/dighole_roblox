"""Builds 12_FINAL_EXPORTS/SUBIR_A_ROBLOX: exactly the files to upload to the Creator Hub, numbered in order."""
import os, shutil
from PIL import Image
from comp import ROOT
U = os.path.join(ROOT, "12_FINAL_EXPORTS", "SUBIR_A_ROBLOX")
if os.path.isdir(U):
    shutil.rmtree(U)
def cp(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copy2(src, dst)
I = os.path.join(ROOT, "02_ROBLOX_ICONS")
cp(os.path.join(I, "THNE_icono_C_mirar_el_pozo_512.png"), os.path.join(U, "1_ICONO", "SUBIR_icono_512x512.png"))
cp(os.path.join(I, "THNE_icono_A_corte_512.png"), os.path.join(U, "1_ICONO", "alternativa_A_corte_512x512.png"))
cp(os.path.join(I, "THNE_icono_B_pico_contra_cristal_512.png"), os.path.join(U, "1_ICONO", "alternativa_B_pico_contra_cristal_512x512.png"))
order = ["01_hasta_donde", "08_cava_en_tu_jardin", "07_cuevas_de_cristal", "02_hallazgo_legendario", "04_tu_casa_tu_agujero",
         "03_herramientas", "01b_capa_a_capa", "05_el_abismo", "06_minas_olvidadas"]
T = os.path.join(ROOT, "03_ROBLOX_THUMBNAILS")
for lang, folder in (("es", "2_MINIATURAS_ESPANOL"), ("en", "3_MINIATURAS_INGLES")):
    for i, n in enumerate(order, 1):
        src = os.path.join(T, lang.upper(), f"THNE_miniatura_{n}_{lang}.jpg")
        if not os.path.exists(src):
            src = os.path.join(T, "SIN_TEXTO", f"THNE_miniatura_{n}_sin_texto.jpg")
        cp(src, os.path.join(U, folder, f"{i:02d}_{n}{'_PERSONALIZACION' if i <= 4 else ''}.jpg"))
cp(os.path.join(ROOT, "09_OFFICIAL_TRAILER", "THNE_video_pagina_roblox_gameplay_1920x1080.mp4"), os.path.join(U, "4_VIDEO", "SUBIR_video_de_juego_1920x1080.mp4"))
sym = Image.open(os.path.join(ROOT, "01_BRANDING", "logo", "THNE_logo_symbol_fondo_oscuro.png")).convert("RGBA")
sq = Image.new("RGBA", (512, 512), (20, 26, 48, 255)); sym.thumbnail((440, 440)); sq.alpha_composite(sym, ((512 - sym.width) // 2, (512 - sym.height) // 2))
os.makedirs(os.path.join(U, "5_GRUPO_Y_REDES"), exist_ok=True)
sq.convert("RGB").save(os.path.join(U, "5_GRUPO_Y_REDES", "icono_grupo_y_avatar_redes_512x512.png"))
cp(os.path.join(ROOT, "04_BANNERS", "THNE_banner_principal_1920x600.jpg"), os.path.join(U, "5_GRUPO_Y_REDES", "banner_1920x600.jpg"))
shutil.copy2(os.path.join(ROOT, "SUBIR_A_ROBLOX.md"), os.path.join(U, "LEEME_SUBIR_A_ROBLOX.md"))
print("upload pack ready")
