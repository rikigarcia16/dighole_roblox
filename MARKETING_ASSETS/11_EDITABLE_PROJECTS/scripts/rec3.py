"""Smooth recorder (30 fps) for the Studio viewport with Windows Graphics Capture: it captures only the
Studio window, even when other windows cover it (nothing else on the screen is recorded).
Writes f_00000.jpg... + times.json (same format as rec.py) plus raw.mp4.
Usage: python rec3.py name seconds [scale]"""
import sys, os, json, time, subprocess, threading
sys.path.insert(0, os.path.dirname(__file__))
from wincap import find
import imageio_ffmpeg
from windows_capture import WindowsCapture
import cv2

FF = imageio_ffmpeg.get_ffmpeg_exe()
FPS = 30
VIEW = (20, 348, 2532, 1674)


def main():
    name, secs = sys.argv[1], float(sys.argv[2])
    scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.75
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "10_RAW_GAMEPLAY", "clips", name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        os.remove(os.path.join(out, f))
    raw = os.path.join(out, "raw.mp4")
    w, h = (VIEW[2] - VIEW[0]) // 2 * 2, (VIEW[3] - VIEW[1]) // 2 * 2
    ow, oh = int(w * scale) // 2 * 2, int(h * scale) // 2 * 2
    ff = subprocess.Popen([FF, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{ow}x{oh}",
                           "-use_wallclock_as_timestamps", "1", "-i", "-",
                           "-fps_mode", "cfr", "-r", str(FPS),
                           "-c:v", "libx264", "-preset", "veryfast", "-crf", "14", "-pix_fmt", "yuv420p", raw],
                          stdin=subprocess.PIPE)
    st = {"t0": None, "n": 0, "last": 0.0}
    import ctypes
    hw = find("Roblox Studio"); u = ctypes.windll.user32
    if u.IsIconic(hw):  # restore behind the other windows, without taking focus
        u.ShowWindow(hw, 4); u.SetWindowPos(hw, 1, 0, 0, 0, 0, 0x13)
    cap = WindowsCapture(cursor_capture=False, draw_border=False, window_hwnd=hw)

    @cap.event
    def on_frame_arrived(frame, control):
        now = time.time()
        if st["t0"] is None:
            st["t0"] = now
        if now - st["t0"] > secs:
            control.stop(); return
        if now - st["last"] < 1.0 / (FPS + 4):
            return
        st["last"] = now
        buf = cv2.resize(frame.frame_buffer[VIEW[1]:VIEW[1] + h, VIEW[0]:VIEW[0] + w, :3], (ow, oh), interpolation=cv2.INTER_AREA)
        ff.stdin.write(buf.tobytes()); st["n"] += 1

    @cap.event
    def on_closed():
        pass

    cap.start()
    ff.stdin.close(); ff.wait()
    subprocess.run([FF, "-y", "-loglevel", "error", "-i", raw, "-q:v", "2", "-start_number", "0",
                    os.path.join(out, "f_%05d.jpg")], check=True)
    n = len([f for f in os.listdir(out) if f.startswith("f_")])
    json.dump([i / FPS for i in range(n)], open(os.path.join(out, "times.json"), "w"))
    print(name, "captured", st["n"], "->", n, "frames at", FPS, "fps, size", ow, oh, flush=True)


if __name__ == "__main__":
    main()
