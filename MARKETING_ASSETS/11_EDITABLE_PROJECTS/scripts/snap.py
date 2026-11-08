"""Saves the Roblox Studio game viewport (even if the window is behind others) as a PNG.
Usage: python snap.py name [x0 y0 x1 y1]   (viewport rect in window pixels; default measured 2512x1326)"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from wincap import find, Grabber
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "10_RAW_GAMEPLAY", "stills")
VIEW = (20, 348, 2532, 1674)
if __name__ == "__main__":
    name = sys.argv[1]
    view = tuple(int(v) for v in sys.argv[2:6]) if len(sys.argv) >= 6 else VIEW
    g = Grabber(find("Roblox Studio"))
    im = g.grab().crop(view)
    path = os.path.join(OUT, name + ".png")
    im.save(path)
    im.resize((im.width // 4, im.height // 4)).save(os.path.join(OUT, "_preview_" + name + ".jpg"), quality=80)
    print(path, im.size)
