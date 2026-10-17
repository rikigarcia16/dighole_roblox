"""Renders the text dump from dump_slices.lua into PNG images (cross-sections of the hole)."""
import sys
from PIL import Image, ImageDraw

COLORS = {"#": (92, 84, 78), "o": (214, 140, 60), ".": (18, 18, 24), "~": (60, 140, 230), "f": (240, 235, 210)}
SCALE = 6


def main(dump_path, out_dir):
    lines = open(dump_path, encoding="utf-8").read().splitlines()
    i = 0
    images = []
    while i < len(lines):
        line = lines[i]
        if line.startswith("SLICE"):
            header = line
            rows = []
            i += 1
            while lines[i] != "END":
                rows.append(lines[i])
                i += 1
            images.append((header, rows))
        elif line.startswith("PLANS"):
            header = line
            plans = []
            i += 1
            while lines[i] != "END":
                _, d, data = lines[i].split(" ", 2)
                plans.append((d, data.split("|")))
                i += 1
            images.append((header, plans))
        i += 1

    by_seed = {}
    for header, data in images:
        seed = header.split("seed=")[1].split(" ")[0]
        by_seed.setdefault(seed, []).append((header, data))

    for seed, items in by_seed.items():
        slices = [(h, d) for h, d in items if h.startswith("SLICE")]
        plans = [d for h, d in items if h.startswith("PLANS")][0]
        height = max(len(rows) for _, rows in slices)
        width = len(slices[0][1][0])
        gap = 4
        img = Image.new("RGB", ((width * len(slices) + gap * (len(slices) - 1)) * SCALE + 60, height * SCALE + 20), (240, 240, 240))
        draw = ImageDraw.Draw(img)
        for k, (header, rows) in enumerate(slices):
            ox = 50 + k * (width + gap) * SCALE
            for y, row in enumerate(rows):
                for x, ch in enumerate(row):
                    draw.rectangle([ox + x * SCALE, 10 + y * SCALE, ox + (x + 1) * SCALE - 1, 10 + (y + 1) * SCALE - 1], fill=COLORS[ch])
            draw.text((ox, 0), header.split("axis=")[1], fill=(0, 0, 0))
        for depth in range(40, 361, 20):
            y = 10 + (depth - 40) * SCALE
            draw.text((2, y - 5), f"{depth}m", fill=(0, 0, 0))
        img.save(f"{out_dir}/section_seed{seed}.png")

        cols = 9
        cell = len(plans[0][1])
        tile = cell * SCALE
        rows_n = (len(plans) + cols - 1) // cols
        plan_img = Image.new("RGB", (cols * (tile + 8), rows_n * (tile + 18)), (240, 240, 240))
        pd = ImageDraw.Draw(plan_img)
        for n, (d, grid) in enumerate(plans):
            ox, oy = (n % cols) * (tile + 8), (n // cols) * (tile + 18)
            pd.text((ox, oy), d, fill=(0, 0, 0))
            for x, row in enumerate(grid):
                for z, ch in enumerate(row):
                    pd.rectangle([ox + z * SCALE, oy + 12 + x * SCALE, ox + (z + 1) * SCALE - 1, oy + 12 + (x + 1) * SCALE - 1], fill=COLORS[ch])
        plan_img.save(f"{out_dir}/plans_seed{seed}.png")
        print("wrote", seed)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
