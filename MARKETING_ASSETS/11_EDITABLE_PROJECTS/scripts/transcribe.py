"""Word-level transcription with faster-whisper (runs locally, nothing is uploaded).
Needs the separate Python 3.13 environment: C:/Users/rinox/tools/whisper-venv/Scripts/python.exe transcribe.py FILES...
Writes FILE.words.json next to each video: [{"w": "word", "s": start, "e": end}, ...]
"""
import sys, json, os, subprocess
import numpy as np
from faster_whisper import WhisperModel

# Decode with ffmpeg ourselves (the PyAV build in the venv rejects faster-whisper's open() arguments).
FFMPEG = os.environ.get("FFMPEG") or subprocess.run(["python", "-c", "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())"],
                                                    capture_output=True, text=True).stdout.strip()


def load_audio(path):
    raw = subprocess.run([FFMPEG, "-loglevel", "error", "-i", path, "-vn", "-ac", "1", "-ar", "16000", "-f", "s16le", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768

model = WhisperModel(os.environ.get("WHISPER_MODEL", "small.en"), device="cpu", compute_type="int8")
for path in sys.argv[1:]:
    segments, info = model.transcribe(load_audio(path), word_timestamps=True, vad_filter=True, beam_size=5)
    words = []
    for seg in segments:
        for w in seg.words or []:
            words.append({"w": w.word.strip(), "s": round(w.start, 3), "e": round(w.end, 3), "p": round(w.probability, 3)})
    out = os.path.splitext(path)[0] + ".words.json"
    json.dump(words, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(os.path.basename(path), len(words), "words:", " ".join(x["w"] for x in words)[:300])
