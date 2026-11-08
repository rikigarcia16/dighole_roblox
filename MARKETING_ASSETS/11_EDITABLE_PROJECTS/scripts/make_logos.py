"""Finishes the Blender logo renders into the branding deliverables."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from post_logo import finish
from PIL import Image
B = os.path.join(os.path.dirname(__file__), "..", "..", "01_BRANDING")
specs = {"main_en": 24, "main_es": 24, "horizontal_en": 20, "horizontal_es": 20, "compact_en": 18, "symbol": 20}
os.makedirs(os.path.join(B, "logo"), exist_ok=True)
prev = []
for v, px in specs.items():
    raw = Image.open(os.path.join(B, "renders", f"logo_{v}_raw.png"))
    light = finish(raw, px, outer_px=0)
    dark = finish(raw, px, outer_px=int(px * 0.7), outer=(255, 246, 224))
    light.save(os.path.join(B, "logo", f"THNE_logo_{v}_fondo_claro.png"))
    dark.save(os.path.join(B, "logo", f"THNE_logo_{v}_fondo_oscuro.png"))
    prev.append((v, light, dark))
    print(v, light.size)
W = 900; rows = []
for v, l, d in prev:
    h = int(W * 0.9 * l.height / l.width)
    row = Image.new("RGB", (2 * W, h + 40))
    a = Image.new("RGBA", (W, row.height), (236, 242, 248, 255)); a.alpha_composite(l.resize((int(W * 0.9), h)), (int(W * 0.05), 20))
    b = Image.new("RGBA", (W, row.height), (20, 26, 48, 255)); dd = d.resize((int(W * 0.9), int(W * 0.9 * d.height / d.width))); b.alpha_composite(dd, (int(W * 0.05), max(0, 20 - (dd.height - h) // 2)))
    row.paste(a.convert("RGB"), (0, 0)); row.paste(b.convert("RGB"), (W, 0)); rows.append(row)
sheet = Image.new("RGB", (2 * W, sum(r.height for r in rows))); y = 0
for r in rows:
    sheet.paste(r, (0, y)); y += r.height
sheet.save(os.path.join(B, "THNE_logos_presentacion.jpg"), quality=88)
sheet.resize((sheet.width // 2, sheet.height // 2)).save(os.path.join(B, "renders", "_prev_sheet.jpg"), quality=80)
