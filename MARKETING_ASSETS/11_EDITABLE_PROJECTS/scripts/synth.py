"""Original music and sound effects for the marketing videos, synthesised from scratch with numpy
(no samples, no third-party audio: free to use anywhere). Output: 48 kHz stereo WAV.
Usage: python synth.py <out_dir>"""
import sys, os, wave
import numpy as np

SR = 48000
rng = np.random.default_rng(7)


def t_(d):
    return np.arange(int(d * SR)) / SR


def env_adsr(n, a=0.005, d=0.1, s=0.6, r=0.2, length=None):
    length = length or n / SR
    t = np.arange(n) / SR
    e = np.ones(n) * s
    a_n = max(1, int(a * SR)); d_n = max(1, int(d * SR))
    e[:a_n] = np.linspace(0, 1, a_n)
    e[a_n:a_n + d_n] = np.linspace(1, s, min(d_n, max(0, n - a_n)))
    rel_start = int((length - r) * SR)
    if 0 < rel_start < n:
        e[rel_start:] *= np.linspace(1, 0, n - rel_start)
    return e


def lowpass(x, cutoff):
    # one-pole low-pass, cutoff can be an array
    a = np.exp(-2 * np.pi * np.asarray(cutoff) / SR) * np.ones(len(x))
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def lp_fast(x, cutoff):
    # vectorised biquad-ish via FFT brickwall-smooth (for long buffers)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    H = 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X * H, len(x))


def hp_fast(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    H = 1 - 1 / (1 + (f / max(cutoff, 1)) ** 4)
    return np.fft.irfft(X * H, len(x))


def saw(f, t):
    return 2 * ((f * t) % 1) - 1


def note(n):  # midi -> hz
    return 440 * 2 ** ((n - 69) / 12)


def reverb(x, mix=0.25, decay=1.8):
    n = int(decay * SR)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 6, n))
    ir = lp_fast(ir, 6000)
    ir /= np.abs(ir).sum() ** 0.5 * 8
    from numpy.fft import rfft, irfft
    L = len(x) + n
    nfft = 1 << (L - 1).bit_length()
    y = irfft(rfft(x, nfft) * rfft(ir, nfft), nfft)[:len(x)]
    return x * (1 - mix) + y * mix


def place(buf, x, start, gain=1.0):
    i = int(start * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i] * gain


# ---------------------------------------------------------------------------------- instruments
def kick(d=0.45):
    t = t_(d)
    f = 45 + 110 * np.exp(-t * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 7) * 1.0 + 0.15 * rng.standard_normal(len(t)) * np.exp(-t * 120)


def snare(d=0.3):
    t = t_(d)
    noise = hp_fast(rng.standard_normal(len(t)), 1500) * np.exp(-t * 16)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return 0.55 * noise + 0.45 * body


def hat(d=0.08, open_=False):
    t = t_(0.3 if open_ else d)
    return hp_fast(rng.standard_normal(len(t)), 7000) * np.exp(-t * (12 if open_ else 60)) * 0.35


def pluck(freq, d=0.35, bright=4000):
    t = t_(d)
    x = 0.6 * saw(freq, t) + 0.4 * np.sign(np.sin(2 * np.pi * freq * 0.5 * t)) * 0.3
    cut = 300 + bright * np.exp(-t * 14)
    return lowpass(x, cut) * np.exp(-t * 6)


def bell(freq, d=1.2):
    t = t_(d)
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * 2.0 * np.exp(-t * 4)
    return np.sin(2 * np.pi * freq * t + mod) * np.exp(-t * 3)


def pad(freqs, d, cutoff=1800):
    t = t_(d)
    x = np.zeros(len(t))
    for f in freqs:
        for det in (-0.12, 0.0, 0.11):
            x += saw(f * 2 ** (det / 12), t + rng.random())
    x /= len(freqs) * 3
    x = lp_fast(x, cutoff)
    return x * env_adsr(len(t), a=0.8, d=0.5, s=0.9, r=1.0, length=d)


def bass(freq, d):
    t = t_(d)
    x = saw(freq, t) * 0.5 + np.sin(2 * np.pi * freq * t)
    return lowpass(x, 500 + 900 * np.exp(-t * 10)) * env_adsr(len(t), 0.005, 0.15, 0.7, 0.05, d) * 0.6


def whoosh(d=0.8, up=True):
    t = t_(d)
    nz = rng.standard_normal(len(t))
    cut = np.linspace(400, 6000, len(t)) if up else np.linspace(6000, 400, len(t))
    y = lowpass(nz, cut)
    e = np.sin(np.pi * t / d) ** 2
    return y * e * 0.6


def impact(d=1.6):
    t = t_(d)
    f = 30 + 80 * np.exp(-t * 12)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 3)
    nz = lp_fast(rng.standard_normal(len(t)), 2500) * np.exp(-t * 8) * 0.6
    return reverb(boom + nz, 0.35, 2.5)


def coin():
    a = bell(note(88), 0.5) * 0.6
    b = bell(note(93), 0.6) * 0.6
    out = np.zeros(int(0.8 * SR))
    place(out, a, 0); place(out, b, 0.07)
    return out


def dig_hit():
    t = t_(0.35)
    thud = np.sin(2 * np.pi * (90 + 60 * np.exp(-t * 40)) * t) * np.exp(-t * 18)
    grit = lp_fast(rng.standard_normal(len(t)), 3500) * np.exp(-t * 22) * 0.7
    return thud + grit


def shimmer(d=2.2):
    out = np.zeros(int(d * SR))
    for i, n in enumerate([81, 85, 88, 93, 97, 100, 105]):
        place(out, bell(note(n), 1.6) * 0.35, i * 0.07)
    return reverb(out, 0.45, 2.8)


# ---------------------------------------------------------------------------------- arrangement
def song(bars, bpm, prog, sections, seed=1, root=57):
    """prog: list of chord root offsets per bar (semitones from root, minor/major triads given)."""
    beat = 60 / bpm
    total = bars * 4 * beat + 2.5
    L = np.zeros(int(total * SR)); R = np.zeros(int(total * SR))
    r = np.random.default_rng(seed)
    arp_pat = [0, 2, 1, 2, 0, 2, 1, 3]
    for bar in range(bars):
        sec = sections(bar)
        chord = prog[bar % len(prog)]
        base = root + chord[0]
        tri = [base + i for i in chord[1]]
        t0 = bar * 4 * beat
        if "pad" in sec:
            p = pad([note(n) for n in tri], 4 * beat + 0.6, 1400 if "drop" not in sec else 2600)
            place(L, p, t0, 0.22); place(R, np.roll(p, 300), t0, 0.22)
        if "bass" in sec:
            for k in range(8):
                f = note(base - 12) if k % 2 == 0 else note(base)
                place(L, bass(f, beat / 2 * 0.9), t0 + k * beat / 2, 0.38); place(R, bass(f, beat / 2 * 0.9), t0 + k * beat / 2, 0.38)
        if "arp" in sec:
            for k in range(8):
                n_ = tri[arp_pat[k] % 3] + (12 if arp_pat[k] == 3 else 0) + 12
                pl = pluck(note(n_), beat * 0.9)
                pan = 0.5 + 0.35 * np.sin(k)
                place(L, pl, t0 + k * beat / 2, 0.20 * (1 - pan) * 2); place(R, pl, t0 + k * beat / 2, 0.20 * pan * 2)
        if "bell" in sec:
            for k in (0, 3, 6):
                n_ = tri[(k // 3) % 3] + 24
                b = bell(note(n_), 1.0)
                place(L, b, t0 + k * beat / 2, 0.08); place(R, b, t0 + k * beat / 2 + 0.01, 0.08)
        if "drums" in sec:
            for k in range(4):
                place(L, kick(), t0 + k * beat, 0.8); place(R, kick(), t0 + k * beat, 0.8)
                if k % 2 == 1:
                    s_ = snare(); place(L, s_, t0 + k * beat, 0.45); place(R, s_, t0 + k * beat, 0.45)
            for k in range(8):
                h = hat(open_=(k % 4 == 3)); place(L, h, t0 + k * beat / 2, 0.5); place(R, h, t0 + k * beat / 2 + 0.003, 0.5)
        if "kickonly" in sec:
            for k in range(4):
                place(L, kick(), t0 + k * beat, 0.6); place(R, kick(), t0 + k * beat, 0.6)
        if "riser" in sec:
            w = whoosh(4 * beat, True); place(L, w, t0, 0.5); place(R, w, t0, 0.5)
    L = reverb(L, 0.18, 1.6); R = reverb(R, 0.18, 1.6)
    m = np.stack([L, R], 1)
    m /= np.abs(m).max() / 0.89
    return m


def write(path, x):
    if x.ndim == 1:
        x = np.stack([x, x], 1)
    x = np.clip(x, -1, 1)
    d = (x * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(d.tobytes())
    print("wrote", path, round(len(x) / SR, 2), "s")


def norm(x, peak=0.9):
    return x / (np.abs(x).max() + 1e-9) * peak


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    MIN = (0, [0, 3, 7]); MAJ = (0, [0, 4, 7])
    # i - VI - III - VII in A minor: adventurous
    prog = [(0, [0, 3, 7]), (-4, [0, 4, 7]), (3, [0, 4, 7]), (-2, [0, 4, 7])]

    def trailer_sections(bar):
        if bar < 2: return {"pad", "bell"}
        if bar < 4: return {"pad", "arp", "kickonly"}
        if bar < 6: return {"pad", "arp", "bass", "drums"}
        if bar == 6: return {"pad", "arp", "bass", "drums", "riser"}
        if bar < 13: return {"pad", "arp", "bass", "drums", "bell", "drop"}
        if bar < 14: return {"pad", "riser"}
        return {"pad", "bell"}
    write(os.path.join(out, "music_trailer_adventure_112bpm.wav"), song(16, 112, prog, trailer_sections, seed=3))

    def short_sections(bar):
        if bar < 1: return {"pad", "arp", "kickonly"}
        return {"pad", "arp", "bass", "drums", "bell", "drop"}
    write(os.path.join(out, "music_short_upbeat_120bpm.wav"), song(16, 120, prog, short_sections, seed=5, root=60))

    prog_m = [(0, [0, 3, 7]), (1, [0, 4, 7]), (-2, [0, 3, 7]), (-4, [0, 4, 7])]

    def mystery_sections(bar):
        if bar < 2: return {"pad"}
        if bar < 6: return {"pad", "bell", "kickonly"}
        return {"pad", "bell", "arp", "kickonly"}
    write(os.path.join(out, "music_mystery_depths_90bpm.wav"), song(12, 90, prog_m, mystery_sections, seed=9, root=50))

    write(os.path.join(out, "sfx_dig_hit.wav"), norm(dig_hit()))
    write(os.path.join(out, "sfx_coin.wav"), norm(coin(), 0.7))
    write(os.path.join(out, "sfx_whoosh_down.wav"), norm(whoosh(0.9, False)))
    write(os.path.join(out, "sfx_whoosh_up.wav"), norm(whoosh(0.9, True)))
    write(os.path.join(out, "sfx_impact.wav"), norm(impact()))
    write(os.path.join(out, "sfx_legendary_shimmer.wav"), norm(shimmer(), 0.8))
