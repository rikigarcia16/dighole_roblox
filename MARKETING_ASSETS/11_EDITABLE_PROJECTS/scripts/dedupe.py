"""Drop repeated frames from a rec3 take (constant 30 fps with duplicates) and write real timestamps, so the
editor blends between real frames instead of stuttering on copies.  python dedupe.py clip_dir"""
import sys, os, json
import numpy as np
from PIL import Image
d = sys.argv[1]
files = sorted(f for f in os.listdir(d) if f.startswith("f_") and f.endswith(".jpg"))
times = json.load(open(os.path.join(d, "times.json")))
keep, prev = [], None
for i, f in enumerate(files):
    a = np.asarray(Image.open(os.path.join(d, f)).reduce(8).convert("L"), np.int16)
    if prev is None or np.abs(a - prev).mean() > 0.35:
        keep.append(i); prev = a
    else:
        os.remove(os.path.join(d, f))
for j, i in enumerate(keep):
    os.replace(os.path.join(d, files[i]), os.path.join(d, f"f_{j:05d}.jpg"))
json.dump([times[i] for i in keep], open(os.path.join(d, "times.json"), "w"))
print(d, len(files), "->", len(keep), "frames,", round(len(keep) / times[-1], 1), "real fps")
