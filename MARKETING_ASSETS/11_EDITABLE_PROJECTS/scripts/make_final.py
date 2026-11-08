"""Palette sheet, copies of the recommended finals into 12_FINAL_EXPORTS, and the file inventory
(real dimensions read from every file)."""
import os, shutil, glob, subprocess, re
from comp import *
import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()

# ---- palette sheet
PAL = [("Jardín", "#58B248"), ("Tierra", "#8C5C36"), ("Piedra", "#706860"), ("Cristal", "#6078E6"), ("Arenisca", "#C4965A"),
       ("Lava", "#D2461E"), ("Abismo", "#181E3C"), ("Núcleo", "#FFD25A"), ("Oro título", "#FFF06A→#FF9A1F"),
       ("Cian título", "#9AF7FF→#2F86FF"), ("Tinta contorno", "#1E0E05"), ("Crema contorno", "#FFF6E0")]
im = Image.new("RGB", (1800, 760), (245, 245, 248))
d = ImageDraw.Draw(im)
f = font(FONT_BODY, 30); fs = font(FONT_BODY, 24)
d.text((40, 24), "The Hole Never Ends · paleta (colores reales de las zonas del juego)", font=f, fill=(30, 30, 30))
for i, (n, h) in enumerate(PAL):
    x, y = 40 + (i % 6) * 290, 90 + (i // 6) * 330
    cols = [c.strip() for c in h.split("→")]
    if len(cols) == 2:
        g = Image.new("RGB", (260, 220))
        a = tuple(int(cols[0][k:k + 2], 16) for k in (1, 3, 5)); b = tuple(int(cols[1][k:k + 2], 16) for k in (1, 3, 5))
        gd = ImageDraw.Draw(g)
        for yy in range(220):
            t = yy / 219; gd.line([(0, yy), (260, yy)], fill=tuple(int(a[k] * (1 - t) + b[k] * t) for k in range(3)))
        im.paste(g, (x, y))
    else:
        d.rectangle([x, y, x + 260, y + 220], fill=h)
    d.rectangle([x, y, x + 260, y + 220], outline=(40, 40, 40), width=2)
    d.text((x, y + 232), n, font=f, fill=(30, 30, 30)); d.text((x, y + 270), h, font=fs, fill=(90, 90, 90))
im.save(os.path.join(ROOT, "01_BRANDING", "THNE_paleta.png"))

# ---- final exports (recommended set)
FE = os.path.join(ROOT, "12_FINAL_EXPORTS")
pick = {
    "logo": glob.glob(os.path.join(ROOT, "01_BRANDING", "logo", "*.png")),
    "iconos_roblox": [os.path.join(ROOT, "02_ROBLOX_ICONS", f"THNE_icono_{n}_1024.png") for n in ("C_mirar_el_pozo", "A_corte", "B_pico_contra_cristal")],
    "miniaturas_roblox_ES": glob.glob(os.path.join(ROOT, "03_ROBLOX_THUMBNAILS", "ES", "*.jpg")) + [os.path.join(ROOT, "03_ROBLOX_THUMBNAILS", "SIN_TEXTO", "THNE_miniatura_02_hallazgo_legendario_sin_texto.jpg")],
    "miniaturas_roblox_EN": glob.glob(os.path.join(ROOT, "03_ROBLOX_THUMBNAILS", "EN", "*.jpg")),
    "anuncios_roblox": glob.glob(os.path.join(ROOT, "08_ROBLOX_ADS", "*.jpg")),
    "videos": glob.glob(os.path.join(ROOT, "09_OFFICIAL_TRAILER", "*.mp4")),
}
for folder, files in pick.items():
    dst = os.path.join(FE, folder)
    os.makedirs(dst, exist_ok=True)
    for p in files:
        shutil.copy2(p, os.path.join(dst, os.path.basename(p)))


# ---- inventory
def info(p):
    ext = p.lower().rsplit(".", 1)[-1]
    size = os.path.getsize(p)
    if ext in ("png", "jpg", "jpeg"):
        with Image.open(p) as im:
            return f"{im.width}×{im.height}", size, ""
    if ext == "mp4":
        out = subprocess.run([FF, "-i", p], capture_output=True, text=True).stderr
        dur = re.search(r"Duration: (\d+):(\d+):([\d.]+)", out)
        res = re.search(r", (\d{3,4})x(\d{3,4})", out)
        secs = int(dur.group(1)) * 3600 + int(dur.group(2)) * 60 + float(dur.group(3)) if dur else 0
        return (f"{res.group(1)}×{res.group(2)}" if res else "?"), size, f"{secs:.1f} s"
    if ext == "wav":
        import wave
        with wave.open(p) as w:
            return f"{w.getframerate()} Hz", size, f"{w.getnframes() / w.getframerate():.1f} s"
    return "", size, ""


rows = ["| Carpeta | Archivo | Dimensiones | Duración | Tamaño |", "|---|---|---|---|---|"]
skip = ("10_RAW_GAMEPLAY", "renders", "__pycache__")
for dirpath, dirs, files in os.walk(ROOT):
    rel = os.path.relpath(dirpath, ROOT)
    if any(s in rel.split(os.sep) for s in skip) or (rel.startswith("12_FINAL_EXPORTS") and "shorts_9x16" not in rel):
        continue
    for fn in sorted(files):
        if fn.startswith("_") or fn.endswith((".py", ".sh", ".md", ".blend", ".pyc")):
            continue
        p = os.path.join(dirpath, fn)
        dims, size, dur = info(p)
        rows.append(f"| {rel.replace(os.sep, '/')} | `{fn}` | {dims} | {dur} | {size / 1e6:.2f} MB |")
open(os.path.join(ROOT, "INVENTARIO.md"), "w", encoding="utf-8").write(
    "# Inventario de archivos (generado automáticamente)\n\nDimensiones leídas de cada archivo. "
    "12_FINAL_EXPORTS contiene copias de los recomendados y no se repite aquí. 10_RAW_GAMEPLAY (capturas en bruto) "
    "tampoco se lista: ver MARKETING_ASSETS_README.md.\n\n" + "\n".join(rows) + "\n")
print(len(rows) - 2, "files in inventory")
