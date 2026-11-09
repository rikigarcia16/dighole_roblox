"""Cuts a long video into 10-20 s clips at natural boundaries (a scene change close to a pause).
Usage: python cut_clips.py VIDEO.mp4 OUT_DIR [min_s] [max_s]
Writes OUT_DIR/clip_01.mp4 ... and OUT_DIR/_hoja.jpg (one frame per clip, numbered)."""
import os, re, sys, subprocess
import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

FF = imageio_ffmpeg.get_ffmpeg_exe()
src, out = sys.argv[1], sys.argv[2]
MIN, MAX = (float(sys.argv[3]), float(sys.argv[4])) if len(sys.argv) > 4 else (10.0, 20.0)
os.makedirs(out, exist_ok=True)


def run(args):
    return subprocess.run([FF] + args, capture_output=True, text=True, errors="ignore").stderr


info = run(["-i", src])
h, m, s = re.search(r"Duration: (\d+):(\d+):([\d.]+)", info).groups()
dur = int(h) * 3600 + int(m) * 60 + float(s)
scenes = [float(x) for x in re.findall(r"pts_time:([\d.]+)", run(["-i", src, "-vf", "scale=320:-1,select='gt(scene,0.3)',showinfo", "-an", "-f", "null", "-"]))]
sil = run(["-i", src, "-vn", "-af", "silencedetect=n=-32dB:d=0.3", "-f", "null", "-"])
starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", sil)]
ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", sil)]
pauses = [((a + b) / 2) for a, b in zip(starts, ends)]

# Candidate cut points, best first: scene change inside/near a pause > pause > scene change.
def score(t):
    near_pause = min((abs(t - p) for p in pauses), default=99)
    near_scene = min((abs(t - c) for c in scenes), default=99)
    return (2 if near_pause < 0.6 and near_scene < 0.6 else 1 if near_pause < 0.3 else 0.5 if near_scene < 0.1 else 0)

cands = sorted(set([round(x, 2) for x in scenes + pauses]))
cuts, t0 = [], 0.0
while dur - t0 > MAX:
    window = [c for c in cands if t0 + MIN <= c <= t0 + MAX]
    if window:
        best = max(window, key=lambda c: (score(c), -abs(c - (t0 + (MIN + MAX) / 2))))
    else:
        best = t0 + MAX
    cuts.append((t0, best)); t0 = best
if dur - t0 >= 4:
    cuts.append((t0, dur))

thumbs = []
for i, (a, b) in enumerate(cuts, 1):
    p = os.path.join(out, f"clip_{i:02d}.mp4")
    run(["-y", "-ss", f"{a:.3f}", "-i", src, "-t", f"{b - a:.3f}", "-c:v", "libx264", "-preset", "fast", "-crf", "20",
         "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", p])
    th = os.path.join(out, f"_t{i:02d}.jpg")
    run(["-y", "-ss", f"{a + (b - a) * 0.4:.3f}", "-i", src, "-frames:v", "1", "-vf", "scale=384:-1", th])
    thumbs.append((i, a, b, th))
    print(f"clip_{i:02d}  {int(a // 60)}:{a % 60:05.2f} - {int(b // 60)}:{b % 60:05.2f}  ({b - a:.1f} s)")

cols = 6; tw, thh = 384, 216; rows = (len(thumbs) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tw, rows * (thh + 34)), (20, 20, 24))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arialbd.ttf", 24)
except OSError:
    font = ImageFont.load_default()
for k, (i, a, b, th) in enumerate(thumbs):
    x, y = (k % cols) * tw, (k // cols) * (thh + 34)
    if os.path.exists(th):
        sheet.paste(Image.open(th).resize((tw, thh)), (x, y + 34)); os.remove(th)
    d.text((x + 8, y + 4), f"{i:02d}  ·  {b - a:.0f} s", fill=(255, 210, 60), font=font)
sheet.save(os.path.join(out, "_hoja.jpg"), quality=85)
print("TOTAL", len(cuts))
