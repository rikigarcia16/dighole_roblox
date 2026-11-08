"""Finishes the Blender icon renders (outline, bloom, grade) and builds the size test."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from post_icon import finish
from PIL import Image, ImageDraw, ImageFont
from comp import FONT_BODY
D = os.path.join(os.path.dirname(__file__), "..", "..", "02_ROBLOX_ICONS")
names = [("A_corte", "corte"), ("B_pico_contra_cristal", "pico_cristal"), ("C_mirar_el_pozo", "mirar_pozo"),
         ("D_profundidades", "profundidades"), ("E_hallazgo_legendario", "legendario")]
outs = []
for label, v in names:
    im = finish(Image.open(os.path.join(D, "renders", f"{v}_raw.png")), Image.open(os.path.join(D, "renders", f"{v}_mask.png")), 7)
    p = os.path.join(D, f"THNE_icono_{label}_1024.png"); im.save(p, optimize=True)
    im.resize((512, 512), Image.LANCZOS).save(os.path.join(D, f"THNE_icono_{label}_512.png"), optimize=True)
    outs.append((label, im)); print(p)
# size test on a Roblox-like dark card
f = ImageFont.truetype(FONT_BODY, 22)
sheet = Image.new("RGB", (5 * 300 + 40, 560), (25, 27, 31)); d = ImageDraw.Draw(sheet)
for i, (label, im) in enumerate(outs):
    x = 20 + i * 300
    sheet.paste(im.resize((256, 256), Image.LANCZOS), (x, 20))
    sheet.paste(im.resize((150, 150), Image.LANCZOS), (x, 300))
    sheet.paste(im.resize((50, 50), Image.LANCZOS), (x + 170, 300))
    d.text((x, 470), label.replace("_", " "), font=f, fill=(230, 230, 230))
sheet.save(os.path.join(D, "THNE_iconos_prueba_de_tamanos.jpg"), quality=90)
