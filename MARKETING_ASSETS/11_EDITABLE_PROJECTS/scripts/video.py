"""Small edit engine: real gameplay clips -> finished MP4 (H.264 + AAC) with titles, transitions,
original music and SFX. Clips recorded in slow motion (camera + animation slowed in Studio) are
re-timed to real speed; realtime clips are smoothed by blending neighbouring frames."""
import os, json, glob, subprocess, wave, math
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance
import imageio_ffmpeg
from comp import *

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
AUDIO = os.path.join(ROOT, "11_EDITABLE_PROJECTS", "audio")
FPS = 30

# slow = how many times slower the clip was recorded than real time
CLIPS = {
    "descent_b": dict(slow=5), "plot_crane": dict(slow=4), "surface_hero": dict(slow=4),
    "mines_action": dict(slow=4), "crystal_action": dict(slow=4), "abyss_action": dict(slow=4),
    "garage_pan": dict(slow=4), "dig_surface": dict(slow=1), "sell_ui": dict(slow=1),
    "showcase_ui": dict(slow=1), "legendary_ui": dict(slow=1),
}


class Clip:
    def __init__(self, name):
        self.name = name
        d = os.path.join(RAW, "clips", name)
        self.files = sorted(glob.glob(os.path.join(d, "f_*.jpg")))
        self.times = np.array(json.load(open(os.path.join(d, "times.json"))))[: len(self.files)]
        self.slow = CLIPS[name]["slow"]
        self.duration = self.times[-1] / self.slow
        self.cache = {}

    def _img(self, i):
        if i not in self.cache:
            if len(self.cache) > 6:
                self.cache.pop(next(iter(self.cache)))
            im = Image.open(self.files[i]).convert("RGB")
            if im.width < 2400:  # half/three-quarter scale captures -> normalise to full viewport size
                im = im.resize((2512, int(2512 * im.height / im.width)), Image.BICUBIC)
            self.cache[i] = im
        return self.cache[i]

    def at(self, t):
        """Frame at output time t (seconds, real speed) from the start of the clip."""
        src = np.clip(t * self.slow, 0, self.times[-1])
        j = int(np.searchsorted(self.times, src))
        j = min(max(j, 1), len(self.times) - 1)
        i = j - 1
        if self.slow == 1:  # blend neighbours for low-fps realtime clips
            a = (src - self.times[i]) / max(1e-6, self.times[j] - self.times[i])
            a = float(np.clip(a, 0, 1))
            if 0.15 < a < 0.85:
                return Image.blend(self._img(i), self._img(j), a)
            return self._img(j if a >= 0.5 else i)
        return self._img(j if (src - self.times[i]) > (self.times[j] - src) else i)


_clips = {}


def clip(name):
    if name not in _clips:
        _clips[name] = Clip(name)
    return _clips[name]


# ------------------------------------------------------------------------------------------ layouts
def crop_top(im):
    return im.crop((0, VIEW_CROP_TOP, im.width, im.height))


def land(im, focus=(0.5, 0.5), zoom=1.0, size=(1920, 1080)):
    im = crop_top(im)
    tw, th = size
    s = max(tw / im.width, th / im.height) * zoom
    cw, ch = tw / s, th / s
    x = (im.width - cw) * focus[0]; y = (im.height - ch) * focus[1]
    return im.resize(size, Image.BILINEAR, box=(x, y, x + cw, y + ch))


def vert_full(im, focus=0.5, zoom=1.0, size=(1080, 1920)):
    return land(im, (focus, 0.5), zoom, size)


_blur_cache = {}


def vert_framed(im, focus=0.5, zoom=1.0, size=(1080, 1920), box_h=1080, y=420):
    """Square-ish gameplay window over a blurred, darkened copy of the same frame."""
    W, H = size
    bg = land(im, (focus, 0.5), 1.0, (W // 6, H // 6)).filter(ImageFilter.GaussianBlur(6)).resize(size, Image.BILINEAR)
    bg = ImageEnhance.Brightness(bg).enhance(0.45)
    win = land(im, (focus, 0.5), zoom, (W, box_h))
    bg.paste(win, (0, y))
    return bg


# ------------------------------------------------------------------------------------------ overlays
def pop(t, t_in, dur=0.28):
    """Scale curve for a pop-in: 0 -> 1.08 -> 1.0"""
    u = (t - t_in) / dur
    if u <= 0:
        return 0.0
    if u >= 1:
        return 1.0
    return 1.0 + 0.08 * math.sin(u * math.pi) if u > 0.6 else (u / 0.6) * 1.08


class Overlay:
    def __init__(self, img, t_in, t_out, xy, anchor="cc", anim="pop", fade_out=0.15):
        self.img, self.t_in, self.t_out, self.xy, self.anchor, self.anim, self.fade_out = img, t_in, t_out, xy, anchor, anim, fade_out

    def draw(self, base, t):
        if t < self.t_in or t > self.t_out:
            return base
        im = self.img
        if self.anim == "pop":
            s = pop(t, self.t_in)
            if s <= 0.02:
                return base
            if abs(s - 1) > 1e-3:
                im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.BILINEAR)
        elif self.anim == "slide":
            u = min(1, (t - self.t_in) / 0.3)
            dx = int((1 - u) ** 2 * 300)
            im = im
            return place(base, im, (self.xy[0] - dx, self.xy[1]), self.anchor)
        a = 1.0
        if self.t_out - t < self.fade_out:
            a = max(0, (self.t_out - t) / self.fade_out)
        if a < 1:
            im = im.copy()
            im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
        return place(base, im, self.xy, self.anchor)


# ------------------------------------------------------------------------------------------ timeline
class Seg:
    """One shot: clip `name` from clip time `start` for `dur` seconds, rendered by `layout(img)`."""
    def __init__(self, name, start, dur, layout, speed=1.0, punch=0.0, flash_in=False, fade_in=0.0, fade_out=0.0):
        self.name, self.start, self.dur, self.layout = name, start, dur, layout
        self.speed, self.punch, self.flash_in, self.fade_in, self.fade_out = speed, punch, flash_in, fade_in, fade_out


def render(segs, overlays, out, size, audio_cues=None, music=None, music_gain=0.8, music_start=0.0, tail_card=None, fps=FPS, crf=18):
    """segs: list of Seg; overlays: list of Overlay (global time); tail_card: (image, seconds) appended."""
    total = sum(s.dur for s in segs) + (tail_card[1] if tail_card else 0)
    nframes = int(round(total * fps))
    tmp_video = out + ".video.mp4"
    cmd = [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{size[0]}x{size[1]}", "-r", str(fps), "-i", "-",
           "-c:v", "libx264", "-preset", "medium", "-crf", str(crf), "-pix_fmt", "yuv420p", "-movflags", "+faststart", tmp_video]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    starts = np.cumsum([0] + [s.dur for s in segs])
    for f in range(nframes):
        t = f / fps
        k = int(np.searchsorted(starts, t, side="right") - 1)
        if k < len(segs):
            s = segs[k]
            lt = t - starts[k]
            img = s.layout(clip(s.name).at(s.start + lt * s.speed))
            if s.punch and lt < 0.35:  # quick zoom punch at the start of the shot
                z = 1 + s.punch * (1 - lt / 0.35) ** 2
                w, h = img.size
                cw, ch = w / z, h / z
                img = img.resize((w, h), Image.BILINEAR, box=((w - cw) / 2, (h - ch) / 2, (w + cw) / 2, (h + ch) / 2))
            if s.flash_in and lt < 0.18:
                img = Image.blend(img, Image.new("RGB", img.size, (255, 255, 255)), 1 - lt / 0.18)
            if s.fade_in and lt < s.fade_in:
                img = Image.blend(Image.new("RGB", img.size), img, lt / s.fade_in)
            if s.fade_out and s.dur - lt < s.fade_out:
                img = Image.blend(Image.new("RGB", img.size), img, max(0, (s.dur - lt) / s.fade_out))
        else:
            img = tail_card[0].copy()
            lt = t - starts[-1]
            if lt < 0.25:
                img = Image.blend(Image.new("RGB", img.size), img, lt / 0.25)
        for o in overlays:
            img = o.draw(img, t)
        p.stdin.write(img.convert("RGB").tobytes())
    p.stdin.close(); p.wait()
    # ----- audio
    wav = out + ".audio.wav"
    mix_audio(total, wav, audio_cues or [], music, music_gain, music_start)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", tmp_video, "-i", wav, "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", out], check=True)
    os.remove(tmp_video); os.remove(wav)
    print("VIDEO", out, round(total, 1), "s")
    return out


def read_wav(path):
    with wave.open(path) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").reshape(-1, w.getnchannels()).astype(np.float32) / 32768
    return x if x.shape[1] == 2 else np.repeat(x, 2, axis=1)


def mix_audio(total, out, cues, music, music_gain, music_start):
    SR = 48000
    n = int(total * SR) + SR
    buf = np.zeros((n, 2), np.float32)
    if music:
        m = read_wav(os.path.join(AUDIO, music))[int(music_start * SR):]
        L = min(len(m), n)
        buf[:L] += m[:L] * music_gain
        # fade the music out over the last 1.2 s
        fo = int(1.2 * SR); end = int(total * SR)
        buf[max(0, end - fo):end] *= np.linspace(1, 0, min(fo, end))[:, None]
        buf[end:] = 0
    for t, name, gain in cues:
        x = read_wav(os.path.join(AUDIO, name))
        i = int(t * SR); j = min(n, i + len(x))
        if i < n:
            buf[i:j] += x[: j - i] * gain
    peak = np.abs(buf).max()
    if peak > 0.98:
        buf *= 0.98 / peak
    d = (buf[: int(total * SR)] * 32767).astype("<i2")
    with wave.open(out, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
