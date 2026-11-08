"""Logo renders. Usage: blender -b -P logo.py -- <variant> <out.png>
variants: main_en, main_es, horizontal_en, horizontal_es, compact_en, symbol"""
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import thne3d as T
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
variant, out = args[0], args[1]

GOLD = dict(face_top=T.hexc("#FFF06A"), face_bottom=T.hexc("#FF9A1F"), side=T.hexc("#7A3E12"))
CYAN = dict(face_top=T.hexc("#9AF7FF"), face_bottom=T.hexc("#2F86FF"), side=T.hexc("#16205A"))
CREAM = dict(face_top=T.hexc("#FFFFFF"), face_bottom=T.hexc("#FFE7B8"), side=T.hexc("#6B4A2A"))
OUTLINE = T.hexc("#1E0E05")


def word(body, size, colors, extrude=0.16, bevel=0.035, outline=0.045, spacing=1.0, font=None):
    ob = T.text(body, size=size, extrude=extrude * size, bevel=bevel * size, spacing=spacing, font=font)
    h = size * 0.45
    m = T.mat_two_tone("W_" + body, axis_min=-h, axis_max=h, **colors)
    ob.data.materials.append(m)
    ob = T.to_mesh(ob)
    T.fix_normals(ob)
    ob.rotation_euler = (math.radians(90), 0, 0)
    return ob


def emblem(size):
    e = T.pit_emblem(radius=size * 0.40, depth_step=size * 0.062, rim=size * 0.075, glow=9)
    e.rotation_euler = (math.radians(66), 0, 0)
    return e


def dims(ob):
    bpy.context.view_layer.update()
    return ob.dimensions.copy()


def row(items, gap, z):
    """items: list of (object, width). Lays them left->right centred at x=0, at height z."""
    total = sum(w for _, w in items) + gap * (len(items) - 1)
    x = -total / 2
    for ob, w in items:
        ob.location.x = x + w / 2
        ob.location.z = z
        x += w + gap
    return total


def hole_word(letters_before, letters_after, size, colors=GOLD):
    """A word whose O is the pit emblem, e.g. ('H', 'LE') or ('AGUJER', '')."""
    items = []
    if letters_before:
        a = word(letters_before, size, colors)
        items.append((a, dims(a).x))
    e = emblem(size)
    items.append((e, size * 0.98))
    if letters_after:
        b = word(letters_after, size, colors)
        items.append((b, dims(b).x))
    return items


sc = T.reset(res=(int(os.environ.get("RESX","3000")), int(os.environ.get("RESY","1800"))), samples=int(os.environ.get("SAMPLES","128")), transparent=True)
T.world_color((0.55, 0.6, 0.75), 0.6)

if variant in ("main_en", "main_es"):
    if variant == "main_en":
        top, (wb, wa), bottom = "THE", ("H", "LE"), "NEVER ENDS"
    else:
        top, (wb, wa), bottom = "EL", ("AGUJER", ""), "SIN FIN"
    es = variant == "main_es"
    t = word(top, 0.62, CREAM)
    row([(t, dims(t).x)], 0, 0.98 if es else 1.18)
    big = 1.75 if not es else 1.3
    row(hole_word(wb, wa, big), 0.06, 0.12)
    b = word(bottom, 0.98 if not es else 1.05, CYAN, spacing=1.04)
    row([(b, dims(b).x)], 0, -0.98 if es else -1.02)
    cam = T.camera((0, -14, 0.25), (0, 0, 0.05), lens=50)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 6.4 if variant == "main_en" else 7.4
elif variant in ("horizontal_en", "horizontal_es"):
    if variant == "horizontal_en":
        parts = [("w", "THE", 0.62, CREAM), ("hole", ("H", "LE"), 1.05, GOLD), ("w", "NEVER ENDS", 0.78, CYAN)]
    else:
        parts = [("w", "EL", 0.62, CREAM), ("hole", ("AGUJER", ""), 0.95, GOLD), ("w", "SIN FIN", 0.78, CYAN)]
    items = []
    for kind, content, size, col in parts:
        if kind == "w":
            o = word(content, size, col)
            items.append((o, dims(o).x))
        else:
            items += hole_word(content[0], content[1], size, col)
    total = row(items, 0.1, 0)
    cam = T.camera((0, -14, 0.1), (0, 0, 0), lens=50)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = total * 1.08
    sc.render.resolution_x, sc.render.resolution_y = 4000, int(4000 * 1.6 / (total * 1.08)) + 40
elif variant == "compact_en":
    e = emblem(2.2)
    e.location = (0, 0, 1.05)
    a = word("THE HOLE", 0.78, GOLD)
    row([(a, dims(a).x)], 0, -0.55)
    b = word("NEVER ENDS", 0.6, CYAN)
    row([(b, dims(b).x)], 0, -1.28)
    cam = T.camera((0, -14, 0), (0, 0, 0), lens=50)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 4.4
    sc.render.resolution_x, sc.render.resolution_y = 2048, 2048
elif variant == "symbol":
    e = emblem(3.0)
    e.rotation_euler = (math.radians(62), 0, 0)
    cam = T.camera((0, -14, 0), (0, 0, 0), lens=50)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.6
    sc.render.resolution_x, sc.render.resolution_y = 2048, 2048

# lighting: warm key from top-left, cool fill from right, strong rim from behind
T.sun((55, 0, -35), 3.2, (1.0, 0.95, 0.86), angle=8, name="Key")
T.sun((75, 0, 50), 1.0, (0.75, 0.88, 1.0), angle=15, name="Fill")
T.sun((-35, 0, 180), 2.5, (1.0, 0.93, 0.8), angle=5, name="Rim")
T.sun((150, 0, 0), 0.5, (0.6, 0.85, 1.0), angle=20, name="Under")
T.render(out)
