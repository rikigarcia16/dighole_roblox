"""Grabs N frames every DT seconds from the Studio viewport and writes a contact sheet.
Usage: python orbit.py prefix N DT"""
import sys, time, os
sys.path.insert(0, os.path.dirname(__file__))
from wincap import find, Grabber
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "10_RAW_GAMEPLAY", "stills")
VIEW = (20, 348, 2532, 1674)
prefix, n, dt = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
g = Grabber(find("Roblox Studio"))
frames = []
t0 = time.time()
for i in range(n):
    while time.time() < t0 + i * dt: time.sleep(0.01)
    frames.append(g.grab().crop(VIEW))
cols = 4; rows = (n + cols - 1) // cols
tw, th = 628, 331
sheet = Image.new("RGB", (cols * tw, rows * th))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(frames):
    f.save(os.path.join(OUT, f"{prefix}_{i:02d}.png"))
    sheet.paste(f.resize((tw, th)), ((i % cols) * tw, (i // cols) * th))
    d.rectangle([(i % cols) * tw, (i // cols) * th, (i % cols) * tw + 40, (i // cols) * th + 28], fill=(0, 0, 0))
    d.text(((i % cols) * tw + 6, (i // cols) * th + 6), str(i), fill=(255, 255, 0))
sheet.resize((cols * tw // 2, rows * th // 2)).save(os.path.join(OUT, f"_sheet_{prefix}.jpg"), quality=82)
print("ok", len(frames))
