"""Records the Studio viewport (window may be behind others) to numbered JPEGs + timestamps.
Usage: python rec.py name seconds [scale]"""
import sys, os, time, threading, queue, json
sys.path.insert(0, os.path.dirname(__file__))
from wincap import find, Grabber
VIEW = (20, 348, 2532, 1674)
name, secs = sys.argv[1], float(sys.argv[2])
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
out = os.path.join(os.path.dirname(__file__), "..", "..", "10_RAW_GAMEPLAY", "clips", name)
os.makedirs(out, exist_ok=True)
q = queue.Queue(maxsize=200)
def saver():
    while True:
        item = q.get()
        if item is None: break
        i, im = item
        if scale != 1.0: im = im.resize((int(im.width * scale), int(im.height * scale)))
        im.save(os.path.join(out, f"f_{i:05d}.jpg"), quality=92)
ths = [threading.Thread(target=saver) for _ in range(8)]
for t in ths: t.start()
g = Grabber(find("Roblox Studio"))
ts = []; i = 0; t0 = time.time(); prev = None; uniq = 0
while time.time() - t0 < secs:
    im = g.grab().crop(VIEW)
    sig = im.resize((32, 18)).tobytes()
    if sig != prev:
        q.put((i, im)); ts.append(time.time() - t0); i += 1; uniq += 1
    prev = sig
for _ in ths: q.put(None)
for t in ths: t.join()
json.dump(ts, open(os.path.join(out, "times.json"), "w"))
print(name, "frames", i, "fps", round(i / secs, 1))
