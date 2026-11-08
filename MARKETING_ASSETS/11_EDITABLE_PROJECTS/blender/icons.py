"""Roblox icon renders (square). Usage: blender -b -P icons.py -- <variant> <out.png>
Env: RES (default 1024), SAMPLES (default 160).
Variants: corte, pico_cristal, mirar_pozo, profundidades, legendario"""
import bpy, sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
import thne3d as T
from mathutils import Vector, Euler, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
variant, out = args[0], args[1]
RES = int(os.environ.get("RES", "1024"))
SAMPLES = int(os.environ.get("SAMPLES", "160"))
TEX = os.path.join(os.path.dirname(__file__), "tex")
rnd = random.Random(7)

sc = T.reset(res=(RES, RES), samples=SAMPLES, transparent=False)


# ---------------------------------------------------------------------------------------------
def pose(parts, side, ax, ay=0.0, az=0.0):
    arm = parts["armL" if side < 0 else "armR"]
    hand = parts["handL" if side < 0 else "handR"]
    piv = Vector((side * 1.5, 0, 3.9))
    R = Euler((math.radians(ax), math.radians(ay), math.radians(az))).to_matrix().to_4x4()
    M = Matrix.Translation(piv) @ R @ Matrix.Translation(-piv)
    for o in (arm, hand):
        o.matrix_world = M @ o.matrix_world
    return M


def pose_leg(parts, side, ax):
    leg = parts["legL" if side < 0 else "legR"]
    piv = Vector((side * 0.5, 0, 2.0))
    R = Euler((math.radians(ax), 0, 0)).to_matrix().to_4x4()
    leg.matrix_world = Matrix.Translation(piv) @ R @ Matrix.Translation(-piv) @ leg.matrix_world


def make_avatar(face="excited", name="Hero"):
    root, parts = T.avatar(face_img=os.path.join(TEX, f"face_{face}.png"), name=name)
    return root, parts


def hold(tool_root, avatar_root, M, side, grip_z, forward_sign=1, twist=0.0):
    """Roblox-style hold: in the rest pose the tool sticks out forward (-Y) of the hand; the arm pose M
    carries it. grip_z = tool-space Z of the point held; forward_sign=+1 -> tool +Z forward, -1 -> -Z forward."""
    tool_root.parent = avatar_root
    rest = Euler((math.radians(90 * forward_sign), 0, math.radians(twist))).to_matrix().to_4x4()
    hand = Vector((side * 1.5, -0.05, 2.15))
    tool_root.matrix_basis = M @ Matrix.Translation(hand) @ rest @ Matrix.Translation(Vector((0, 0, -grip_z)))


def mushroom(loc, h=1.6, r=1.0, color=(0.25, 0.95, 1.0), name="Mush"):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.location = loc
    st = T.cyl(r * 0.28, h, (0, 0, h / 2), T.mat(name + "S", (0.85, 0.95, 0.95), 0.6, emit=(0.6, 1, 1), emit_strength=0.4), verts=24, name=name + "_Stem")
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r, location=(0, 0, h))
    cap = bpy.context.object
    cap.scale = (1, 1, 0.55)
    cap.data.materials.append(T.mat(name + "C", color, 0.35, emit=color, emit_strength=2.5))
    bpy.ops.object.shade_smooth()
    for i in range(6):
        a = i * math.tau / 6 + 0.3
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=r * 0.13,
                                             location=(math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, h + r * 0.42))
        sp = bpy.context.object
        sp.data.materials.append(T.mat_emit(name + f"Sp{i}", (0.9, 1, 1), 4))
        sp.parent = root
    for o in (st, cap):
        o.parent = root
    return root


def sparks(center, n=14, spread=1.6, color=(1.0, 0.85, 0.4), size=0.12, strength=25, seed=3):
    r = random.Random(seed)
    m = T.mat_emit("Spark", color, strength)
    for i in range(n):
        d = Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-0.4, 1))).normalized() * r.uniform(0.3, spread)
        s = size * r.uniform(0.5, 1.3)
        o = T.rbox((s, s * 0.4, s * 2.2), tuple(Vector(center) + d), m, 0.0,
                   rot=(r.uniform(0, 3), r.uniform(0, 3), r.uniform(0, 3)), name=f"Spark{i}")


def debris(center, color, n=10, spread=1.8, size=0.35, seed=5):
    r = random.Random(seed)
    m = T.mat("Debris", color, 0.7)
    for i in range(n):
        d = Vector((r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-0.2, 1))).normalized() * r.uniform(0.4, spread)
        s = size * r.uniform(0.5, 1.2)
        T.rbox((s, s, s), tuple(Vector(center) + d), m, 0.04, rot=(r.uniform(0, 3), r.uniform(0, 3), r.uniform(0, 3)), name=f"Deb{i}")


def ground(size=60, color=None, z=0.0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, z))
    g = bpy.context.object
    g.data.materials.append(T.mat("Ground", color or T.PAL["grass"], 0.8))
    return g


def grass_tufts(n, area, z=0.0, seed=11, avoid=None):
    r = random.Random(seed)
    m = T.mat("Tuft", T.hexc("#6BCB4F"), 0.6)
    for i in range(n):
        x, y = r.uniform(area[0], area[1]), r.uniform(area[2], area[3])
        if avoid and (Vector((x, y)) - Vector(avoid[:2])).length < avoid[2]:
            continue
        for k in range(3):
            h = r.uniform(0.3, 0.7)
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.08, depth=h,
                                            location=(x + r.uniform(-0.12, 0.12), y + r.uniform(-0.12, 0.12), z + h / 2),
                                            rotation=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), 0))
            bpy.context.object.data.materials.append(m)


def house(loc, scale=1.0, rot=0.0):
    root = bpy.data.objects.new("House", None)
    bpy.context.collection.objects.link(root)
    wall = T.rbox((6, 5, 3.6), (0, 0, 1.8), T.mat("HWall", T.hexc("#F4E6CF"), 0.7), 0.05, name="HWall")
    beam_m = T.mat("HBeam", T.hexc("#6B3E22"), 0.6)
    roof_m = T.mat("HRoof", T.hexc("#D9433A"), 0.5)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=4.9, depth=2.8, location=(0, 0, 4.9), rotation=(0, 0, math.radians(45)))
    roof = bpy.context.object
    roof.scale = (1.0, 0.82, 1)
    roof.data.materials.append(roof_m)
    door = T.rbox((1.2, 0.2, 2.0), (0, -2.55, 1.0), T.mat("HDoor", T.hexc("#3B8C8C"), 0.5), 0.04, name="HDoor")
    for x in (-2.0, 2.0):
        T.rbox((1.1, 0.15, 1.0), (x, -2.55, 2.2), T.mat("HWin", T.hexc("#9ED8FF"), 0.1, emit=T.hexc("#FFE9A8"), emit_strength=0.6), 0.03, name="HWin").parent = root
    for x in (-2.95, 2.95):
        T.rbox((0.25, 0.25, 3.6), (x, -2.5, 1.8), beam_m, 0.02, name="HBeam").parent = root
    T.rbox((1.0, 1.0, 2.0), (1.8, 0.5, 6.0), T.mat("HChim", T.hexc("#B5503C"), 0.7), 0.04, name="HChim").parent = root
    for o in (wall, roof, door):
        o.parent = root
    root.location = loc
    root.scale = (scale, scale, scale)
    root.rotation_euler = (0, 0, rot)
    return root


def strata_block(x0, x1, y0, y1, z_top, layer_h, rings, shaft=None, name="Strata"):
    """Cross-section diorama: stacked coloured layers (zones). shaft=(xc, width) cuts a dark slot in front."""
    z = z_top
    for i, zid in enumerate(rings):
        col = T.PAL[zid]
        h = layer_h * (0.6 if zid == "grass" else 1.0)
        emit = col if zid in ("lava", "crystal") else None
        es = 1.4 if zid == "lava" else (0.3 if zid == "crystal" else 0)
        m = T.mat(f"{name}_{zid}", col, 0.75, emit=emit, emit_strength=es)
        if shaft:
            xc, w = shaft
            T.rbox((xc - w / 2 - x0, y1 - y0, h), ((x0 + xc - w / 2) / 2, (y0 + y1) / 2, z - h / 2), m, 0.06, name=f"{name}_{zid}_L")
            T.rbox((x1 - xc - w / 2, y1 - y0, h), ((xc + w / 2 + x1) / 2, (y0 + y1) / 2, z - h / 2), m, 0.06, name=f"{name}_{zid}_R")
            # back wall of the shaft (darker)
            T.rbox((w, (y1 - y0) * 0.35, h), (xc, y1 - (y1 - y0) * 0.175, z - h / 2),
                   T.mat(f"{name}_{zid}_back", tuple(c * 0.45 for c in col), 0.8, emit=emit, emit_strength=es * 0.6), 0.0, name=f"{name}_{zid}_B")
        else:
            T.rbox((x1 - x0, y1 - y0, h), ((x0 + x1) / 2, (y0 + y1) / 2, z - h / 2), m, 0.06, name=f"{name}_{zid}")
        z -= h
    return z


# ---------------------------------------------------------------------------------------------
if variant == "corte":
    T.world_gradient(T.hexc("#58B7FF"), T.hexc("#CFEFFF"), 1.0)
    rings = ["grass", "dirt", "stone", "crystal", "sand", "lava", "abyss"]
    bottom = strata_block(-7.5, 7.5, -3, 3, 0.0, 2.1, rings, shaft=(1.2, 3.0))
    # core glow at the bottom of the shaft
    T.rbox((3.0, 2.2, 0.6), (1.2, 1.0, bottom - 0.2), T.mat_emit("CoreG", T.PAL["core"], 14), 0.1, name="Core")
    T.light_point((1.2, -1.0, bottom + 1.2), 3000, (1, 0.8, 0.4), 1.0, name="CoreL")
    # gems in the walls (front faces)
    for (x, z, c, s) in [(-5.2, -3.2, "#FF4D5E", 0.55), (-3.0, -7.4, "#6A8BFF", 0.7), (5.3, -5.2, "#FFD34D", 0.6),
                         (-5.8, -10.6, "#B36BFF", 0.6), (4.6, -9.8, "#3DF0FF", 0.75), (-3.6, -12.4, "#FF8A2B", 0.55)]:
        cl = T.crystal_cluster(T.hexc(c), n=4, scale=s, seed=int(abs(x * 10)), emit=3.5, name=f"Gem{x}", loc=(x, -3.05, z))
        cl.rotation_euler = (math.radians(-90), 0, 0)
    # light bulbs inside the shaft (the game lights the shaft by layers)
    for z in (-4.0, -8.5):
        T.light_point((1.2, -0.2, z), 120, (1, 0.85, 0.6), 0.3)
    grass_tufts(60, (-7.3, 7.3, -2.9, 2.9), z=0.0, avoid=(1.2, 0, 2.2))
    house((-5.0, 1.8, 0.0), 0.5, math.radians(-18))
    hero, P = make_avatar("excited")
    M = pose(P, 1, -55, 0, 0)
    pose(P, -1, -60, 0, 0)
    sh = T.shovel("HeroShovel")
    hold(sh, hero, M, 1, 1.4, forward_sign=0)
    hero.scale = (1.1, 1.1, 1.1)
    hero.location = (-1.6, -0.6, 0.0)
    hero.rotation_euler = (math.radians(-6), 0, math.radians(62))
    sc.camera = T.camera((-1.0, -24, 6.0), (0.0, 0, -2.6), lens=50)
    T.sun((50, 0, -40), 3.5, (1, 0.96, 0.88), 3)
    T.sun((70, 0, 140), 1.2, (0.7, 0.85, 1), 10)

elif variant == "pico_cristal":
    T.world_gradient(T.hexc("#163A66"), T.hexc("#060A18"), 1.0)
    # cave backdrop
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=30, location=(0, 10, 0))
    cave = bpy.context.object
    cave.data.materials.append(T.mat("CaveRock", T.hexc("#1C2340"), 0.9))
    ground(80, T.hexc("#222A48"))
    big = T.crystal_cluster(T.hexc("#38E8FF"), n=9, scale=2.6, seed=4, emit=5.5, name="Big", loc=(3.3, 0.6, 0))
    T.light_point((3.0, -1.5, 3.0), 2500, (0.3, 0.9, 1.0), 1.5, name="CrystalGlow")
    hero, P = make_avatar("excited")
    M = pose(P, 1, -125, 0, 0)
    pose(P, -1, -50, 0, 10)
    pk = T.pickaxe("HeroPick")
    hold(pk, hero, M, 1, -1.6, forward_sign=1)
    hero.location = (-2.0, -1.2, 0)
    hero.rotation_euler = (0, 0, math.radians(55))
    sparks((1.6, -0.6, 3.4), n=22, spread=2.3, color=(0.3, 0.95, 1.0), strength=6)
    debris((1.9, -0.6, 3.0), T.hexc("#8FF6FF"), n=9, spread=2.4, size=0.32)
    sc.camera = T.camera((-0.2, -13.0, 3.6), (0.7, 0, 3.4), lens=40)
    T.sun((55, 0, -50), 2.2, (1, 0.9, 0.8), 6)
    T.light_area((-8, -6, 7), (0, 0, 3), 1800, 6, (1, 0.85, 0.7), "Key")
    T.light_area((6, 8, 8), (0, 0, 3), 2500, 6, (0.4, 0.9, 1.0), "Rim")

elif variant == "mirar_pozo":
    T.world_gradient(T.hexc("#58B7FF"), T.hexc("#D6F1FF"), 1.0)
    pit = T.stepped_pit(radius=5.5, depth_step=1.2, rim=9.0, name="BigPit", glow=5)
    pit.location = (0, 0, 0)
    T.light_point((0, 0, -6.0), 1400, (1, 0.78, 0.38), 3.0, name="PitGlow")
    hero, P = make_avatar("surprised")
    pose(P, 1, -175, 0, 12)
    pose(P, -1, -175, 0, -12)
    hero.location = (-0.6, -10.2, 0.55)
    hero.rotation_euler = (math.radians(-90), 0, math.radians(-8))
    grass_tufts(260, (-14, 14, -16, 14), z=0.0, seed=5, avoid=(0, 0, 6.2))
    house((-9.0, 9.0, 0), 0.9, math.radians(200))
    sc.camera = T.camera((0.0, -9.5, 18.0), (0.0, -2.2, 0.0), lens=42)
    T.sun((50, 0, 160), 3.0, (1, 0.96, 0.88), 3)
    T.light_area((0.0, -4.0, 1.5), (-0.6, -6.0, 0.6), 400, 3, (1, 0.75, 0.38), "FaceGold")

elif variant == "profundidades":
    T.world_gradient(T.hexc("#0E2A45"), T.hexc("#03070F"), 1.0)
    ground(80, T.hexc("#10192E"))
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=26, location=(0, 8, 0))
    bpy.context.object.data.materials.append(T.mat("Abyss", T.hexc("#152038"), 0.9))
    for (x, y, h, r, s) in [(4.2, 1.5, 3.2, 2.2, 1), (6.8, 4.0, 2.0, 1.4, 2), (-5.2, 2.5, 2.6, 1.8, 3), (-7.4, 5.5, 1.6, 1.1, 4), (1.0, 5.5, 1.4, 1.0, 5)]:
        mushroom((x, y, 0), h, r, T.hexc("#3DF0FF"), name=f"Mush{s}")
    T.crystal_cluster(T.hexc("#FFD34D"), n=5, scale=0.9, seed=2, emit=4, name="Gold", loc=(-3.0, -0.5, 0))
    # shaft of daylight from far above
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=2.2, radius2=0.8, depth=30, location=(0.6, 4.5, 15))
    beam = bpy.context.object
    bm = bpy.data.materials.new("Beam"); bm.use_nodes = True
    nt = bm.node_tree; [nt.nodes.remove(n) for n in list(nt.nodes)]
    o = nt.nodes.new("ShaderNodeOutputMaterial"); e = nt.nodes.new("ShaderNodeEmission"); t = nt.nodes.new("ShaderNodeBsdfTransparent"); mx = nt.nodes.new("ShaderNodeMixShader")
    e.inputs[0].default_value = T.srgb(T.hexc("#FFF2C2")); e.inputs[1].default_value = 1.2
    mx.inputs[0].default_value = 0.94
    nt.links.new(e.outputs[0], mx.inputs[1]); nt.links.new(t.outputs[0], mx.inputs[2]); nt.links.new(mx.outputs[0], o.inputs[0])
    beam.data.materials.append(bm)
    T.light_area((0.2, 2.0, 14), (-0.8, -0.5, 3), 5000, 3, (1, 0.93, 0.75), "SkyHole")
    hero, P = make_avatar("surprised")
    M = pose(P, 1, -150, 0, 0)
    pose(P, -1, -20, 0, -10)
    dr = T.pickaxe("HeroPick", handle=T.hexc("#2B2F3A"), head=T.hexc("#7CF3FF"))
    hold(dr, hero, M, 1, -1.6, forward_sign=1)
    hero.location = (-0.8, -0.5, 0)
    hero.rotation_euler = (math.radians(-8), 0, math.radians(-25))
    sc.camera = T.camera((1.2, -9.5, 1.8), (-0.3, 0.6, 4.1), lens=30)
    T.light_area((-6, -6, 3), (0, 0, 3), 600, 5, (0.3, 0.9, 1.0), "CyanFill")

elif variant == "legendario":
    T.world_gradient(T.hexc("#2A1A5E"), T.hexc("#07051A"), 1.0)
    # radial light rays behind
    for i in range(14):
        a = i * math.tau / 14
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 6, 5.6))
        ray = bpy.context.object
        ray.scale = (0.9, 1, 22)
        ray.rotation_euler = (math.radians(90), a, 0)
        ray.data.materials.append(T.mat_emit(f"Ray{i}", T.hexc("#6E4CFF") if i % 2 else T.hexc("#3DDCFF"), 0.9))
    ground(60, T.hexc("#1B1638"))
    hero, P = make_avatar("awe")
    pose(P, -1, -170, 0, -10)
    pose(P, 1, -170, 0, 10)
    gem = T.crystal_cluster(T.hexc("#3DF0FF"), n=7, scale=1.0, seed=9, emit=7, name="Legend", loc=(0, 0.0, 7.5))
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.75, depth=30, location=(0, 0.6, 15))
    hb = bpy.context.object
    hbm = bpy.data.materials.new("HaloBeam"); hbm.use_nodes = True
    nt = hbm.node_tree; [nt.nodes.remove(n) for n in list(nt.nodes)]
    o_ = nt.nodes.new("ShaderNodeOutputMaterial"); e_ = nt.nodes.new("ShaderNodeEmission"); t_ = nt.nodes.new("ShaderNodeBsdfTransparent"); m_ = nt.nodes.new("ShaderNodeMixShader")
    e_.inputs[0].default_value = T.srgb(T.hexc("#7FF6FF")); e_.inputs[1].default_value = 1.2; m_.inputs[0].default_value = 0.93
    nt.links.new(e_.outputs[0], m_.inputs[1]); nt.links.new(t_.outputs[0], m_.inputs[2]); nt.links.new(m_.outputs[0], o_.inputs[0])
    hb.data.materials.append(hbm)
    T.light_point((0, -1.2, 7.2), 1600, (0.4, 0.95, 1.0), 0.8, name="GemLight")
    sparks((0, -0.5, 8.6), n=10, spread=3.0, color=(1, 0.65, 0.15), size=0.2, strength=4, seed=8)
    for i, (x, z) in enumerate([(-3.4, 6.5), (3.6, 7.6), (-2.8, 3.0), (3.0, 2.4)]):
        c = T.cyl(0.45, 0.12, (x, -1.0, z), T.mat("Coin", T.hexc("#FFC93C"), 0.25, metal=1.0, emit=T.hexc("#FFB000"), emit_strength=0.5), verts=32, name=f"Coin{i}")
        c.rotation_euler = (math.radians(70 + i * 9), math.radians(i * 25), 0)
    hero.location = (0, 0, 0)
    sc.camera = T.camera((0, -11.0, 3.6), (0, 0, 5.2), lens=44)
    T.light_area((-6, -7, 6), (0, 0, 4), 1500, 5, (1, 0.9, 0.8), "Key")
    T.light_area((6, 5, 6), (0, 0, 4), 2000, 5, (0.6, 0.5, 1.0), "Rim")

if os.environ.get("MASK"):
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    sc.cycles.samples = 8
    keep = set()
    def walk(o):
        keep.add(o.name)
        for c in o.children:
            walk(c)
    walk(hero)
    for o in sc.objects:
        if o.type in ("MESH", "CURVE", "FONT") and o.name not in keep:
            o.is_holdout = True
T.render(out)
