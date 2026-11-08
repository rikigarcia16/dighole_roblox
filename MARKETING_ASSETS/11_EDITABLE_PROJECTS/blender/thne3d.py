"""Shared Blender helpers for The Hole Never Ends marketing renders (Blender 5.2, Cycles).

Run scenes with:  blender -b -P <scene>.py -- <args>
Everything is procedural so every render can be regenerated and edited.
"""
import bpy, math, os, sys
from mathutils import Vector, Euler

ROBLOX_FONTS = None
for root in [os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions")]:
    if os.path.isdir(root):
        for v in sorted(os.listdir(root)):
            p = os.path.join(root, v, "content", "fonts")
            if os.path.exists(os.path.join(p, "LuckiestGuy-Regular.ttf")):
                ROBLOX_FONTS = p
FONT_TITLE = os.path.join(ROBLOX_FONTS, "LuckiestGuy-Regular.ttf")
FONT_ROUND = os.path.join(ROBLOX_FONTS, "FredokaOne-Regular.ttf")

# Brand palette (real zone colours of the game, docs/marketing/03)
PAL = {
    "grass": (0.345, 0.698, 0.282), "dirt": (0.549, 0.361, 0.212), "stone": (0.439, 0.408, 0.376),
    "crystal": (0.376, 0.471, 0.902), "sand": (0.769, 0.588, 0.353), "lava": (0.824, 0.275, 0.118),
    "abyss": (0.094, 0.118, 0.235), "core": (1.0, 0.824, 0.353), "ink": (0.09, 0.05, 0.03),
    "cyan": (0.30, 0.95, 1.0),
}


def srgb(c):
    """sRGB 0-1 tuple -> linear (Blender colour inputs are linear)."""
    def f(x):
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def reset(res=(2048, 2048), samples=96, transparent=True, look="AgX - Punchy"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "HIP"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception as e:
        print("GPU unavailable:", e)
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = transparent
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    sc.render.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Standard"
    try:
        sc.view_settings.look = "Medium High Contrast"
    except Exception:
        pass
    sc.cycles.max_bounces = 6
    world = bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    return sc


def world_color(color, strength=1.0):
    w = bpy.context.scene.world
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = srgb(color)
    bg.inputs[1].default_value = strength


def world_gradient(top, bottom, strength=1.0):
    w = bpy.context.scene.world
    nt = w.node_tree
    bg = nt.nodes.get("Background")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs[0])
    ramp.color_ramp.elements[0].color = srgb(bottom)
    ramp.color_ramp.elements[1].color = srgb(top)
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[1].position = 0.65
    nt.links.new(ramp.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = strength


def mat(name, color, rough=0.45, metal=0.0, emit=None, emit_strength=0.0, spec=0.5, coat=0.0, sss=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = srgb(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    try:
        b.inputs["Specular IOR Level"].default_value = spec
        b.inputs["Coat Weight"].default_value = coat
    except Exception:
        pass
    if emit:
        b.inputs["Emission Color"].default_value = srgb(emit)
        b.inputs["Emission Strength"].default_value = emit_strength
    return m


def mat_emit(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = srgb(color)
    em.inputs[1].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def mat_outline(name="Outline", color=(0.07, 0.04, 0.02)):
    """Inverted-hull outline for Cycles: shows only the far side of a flipped shell."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = srgb(color)
    em.inputs[1].default_value = 1.0
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(em.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    m.use_backface_culling = False
    return m


def add_outline(obj, thickness, outline_mat):
    obj.data.materials.append(outline_mat)
    mod = obj.modifiers.new("Outline", "SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1.0
    mod.use_flip_normals = True
    mod.use_rim = False
    mod.material_offset = len(obj.data.materials) - 1
    return mod


def mat_two_tone(name, face_top, face_bottom, side, rough=0.35, axis_min=-1.0, axis_max=1.0, coat=0.6, emit=0.0):
    """Extruded text: front cap gets a vertical gradient, bevel/sides get `side`."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    b.inputs["Roughness"].default_value = rough
    try:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.15
    except Exception:
        pass
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sepn = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Normal"], sepn.inputs[0])
    front = nt.nodes.new("ShaderNodeMath")
    front.operation = "GREATER_THAN"
    front.inputs[1].default_value = 0.6
    nt.links.new(sepn.outputs["Z"], front.inputs[0])
    sepp = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sepp.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = axis_min
    mr.inputs["From Max"].default_value = axis_max
    nt.links.new(sepp.outputs["Y"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = srgb(face_bottom)
    ramp.color_ramp.elements[1].color = srgb(face_top)
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = srgb(side)
    nt.links.new(front.outputs[0], mix.inputs["Factor"])
    nt.links.new(ramp.outputs[0], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    if emit > 0:
        nt.links.new(ramp.outputs[0], b.inputs["Emission Color"])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = emit
        nt.links.new(front.outputs[0], mul.inputs[0])
        nt.links.new(mul.outputs[0], b.inputs["Emission Strength"])
    return m


def text(body, size=1.0, extrude=0.12, bevel=0.03, font=None, align="CENTER", spacing=1.0, location=(0, 0, 0), name=None):
    cu = bpy.data.curves.new(name or ("T_" + body[:8]), "FONT")
    cu.body = body
    cu.font = bpy.data.fonts.load(font or FONT_TITLE, check_existing=True)
    cu.size = size
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 4
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.space_character = spacing
    cu.resolution_u = 24
    ob = bpy.data.objects.new(cu.name, cu)
    bpy.context.collection.objects.link(ob)
    ob.location = location
    return ob


def to_mesh(ob):
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.view_layer.objects.active


def fix_normals(ob):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def sun(rot_deg, energy, color=(1, 1, 1), angle=5, name="Sun"):
    d = bpy.data.lights.new(name, "SUN")
    d.energy = energy
    d.color = color
    d.angle = math.radians(angle)
    o = bpy.data.objects.new(name, d)
    bpy.context.collection.objects.link(o)
    o.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    return o


def cyl(r, depth, loc, mat_=None, verts=96, name="Cyl"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    if mat_:
        o.data.materials.append(mat_)
    bpy.ops.object.shade_smooth()
    return o


def rbox(size, loc, mat_=None, bevel=0.08, rot=(0, 0, 0), name="Box", segments=4):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segments
        m.limit_method = "NONE"
    if mat_:
        o.data.materials.append(mat_)
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    except Exception:
        pass
    return o


def parent(child, par):
    child.parent = par
    child.matrix_parent_inverse = par.matrix_world.inverted()


def light_area(loc, target, energy, size=4.0, color=(1, 1, 1), name="Area"):
    d = bpy.data.lights.new(name, "AREA")
    d.energy = energy
    d.size = size
    d.color = color
    o = bpy.data.objects.new(name, d)
    bpy.context.collection.objects.link(o)
    o.location = loc
    look_at(o, target)
    return o


def light_point(loc, energy, color=(1, 1, 1), radius=0.2, name="Point"):
    d = bpy.data.lights.new(name, "POINT")
    d.energy = energy
    d.color = color
    d.shadow_soft_size = radius
    o = bpy.data.objects.new(name, d)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return o


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def camera(loc, target, lens=50, ortho=None, name="Cam"):
    d = bpy.data.cameras.new(name)
    d.lens = lens
    if ortho:
        d.type = "ORTHO"
        d.ortho_scale = ortho
    o = bpy.data.objects.new(name, d)
    bpy.context.collection.objects.link(o)
    o.location = loc
    look_at(o, target)
    bpy.context.scene.camera = o
    return o


def render(path):
    sc = bpy.context.scene
    if os.environ.get("BLEND_OUT"):
        bpy.ops.wm.save_as_mainfile(filepath=os.environ["BLEND_OUT"])
        print("SAVED", os.environ["BLEND_OUT"])
        return
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDERED", path)


# ---------------------------------------------------------------------------------------------
# The brand symbol: a round stepped pit seen from above, one ring per zone, gold glow at the bottom
ZONE_RINGS = ["grass", "dirt", "stone", "crystal", "sand", "lava", "abyss"]


def _shade(c, k):
    return tuple(max(0.0, min(1.0, v * k)) for v in c)


def stepped_pit(radius=1.0, depth_step=0.16, rim=0.14, name="Pit", glow=18.0, segs=128, ring_list=None, wall_steps=None):
    """A round stepped pit (hollow): rim + one terrace per zone + glowing core at the bottom.
    Built with bmesh: each terrace = flat annulus (zone colour) + inner wall going down (darker)."""
    import bmesh
    rings = ring_list or ZONE_RINGS
    n = len(rings)
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bm = bmesh.new()
    mats = []

    def addmat(m):
        mats.append(m)
        return len(mats) - 1

    def ring_verts(r, z):
        return [bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for a in [i * math.tau / segs for i in range(segs)]]

    def bridge(a, b, mi):
        for i in range(segs):
            j = (i + 1) % segs
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            f.material_index = mi
            f.smooth = True

    radii = [radius * (1 - i / (n + 0.9)) for i in range(n + 1)]
    # outer body: grass top annulus (outer edge .. pit edge) + dirt side wall
    R0 = radius + rim
    m_grass = addmat(mat("PitGrass", PAL["grass"], 0.75))
    m_side = addmat(mat("PitSide", _shade(PAL["dirt"], 0.85), 0.85))
    top_outer = ring_verts(R0, 0.0)
    top_inner = ring_verts(radii[0], 0.0)
    bot_outer = ring_verts(R0, -depth_step * (wall_steps if wall_steps is not None else n + 1.5))
    bridge(top_outer, top_inner, m_grass)
    bridge(bot_outer, top_outer, m_side)
    prev_edge = top_inner
    for i, zid in enumerate(rings):
        col = PAL[zid]
        emit = col if zid in ("lava", "crystal") else None
        es = 1.5 if zid == "lava" else (0.4 if zid == "crystal" else 0.0)
        m_wall = addmat(mat("Wall_" + zid, _shade(col, 0.72), 0.6, emit=emit, emit_strength=es * 0.6))
        m_flat = addmat(mat("Flat_" + zid, col, 0.55, emit=emit, emit_strength=es))
        z_top = -i * depth_step
        z_bot = -(i + 1) * depth_step
        wall_bot = ring_verts(radii[i], z_bot)
        bridge(prev_edge, wall_bot, m_wall)          # inner wall of this zone
        inner = ring_verts(radii[i + 1], z_bot)
        bridge(wall_bot, inner, m_flat)              # terrace floor
        prev_edge = inner
    # core: a glowing disc closing the bottom
    m_core = addmat(mat_emit("PitCore", PAL["core"], glow))
    center = bm.verts.new((0, 0, -n * depth_step - depth_step * 0.2))
    for i in range(segs):
        j = (i + 1) % segs
        f = bm.faces.new((prev_edge[i], prev_edge[j], center))
        f.material_index = m_core
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    lp = light_point((0, 0, -n * depth_step + depth_step * 0.6), 5 * radius * radius, color=(1, 0.82, 0.42),
                     radius=radii[-1], name=name + "_CoreLight")
    lp.parent = ob
    return ob


def pit_emblem(radius=1.0, depth_step=0.16, rim=0.12, name="Pit", glow=18.0, grass_lip=True, outline=None, wall_steps=2.2):
    root = bpy.data.objects.new(name + "_Root", None)
    bpy.context.collection.objects.link(root)
    p = stepped_pit(radius, depth_step, rim, name, glow, wall_steps=wall_steps)
    p.parent = root
    return root


# ---------------------------------------------------------------------------------------------
# A blocky avatar (proportions of a classic Roblox R6 rig) used as the recurring player character
def avatar(skin=(0.97, 0.86, 0.55), shirt=(0.12, 0.72, 0.72), jacket=(0.08, 0.08, 0.1), pants=(0.12, 0.13, 0.18),
           hair=(0.93, 0.42, 0.12), face_img=None, name="Avatar", outline=0.0):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    m_skin = mat("Skin", skin, 0.5)
    m_shirt = mat("Shirt", shirt, 0.6)
    m_jacket = mat("Jacket", jacket, 0.5)
    m_pants = mat("Pants", pants, 0.7)
    m_hair = mat("Hair", hair, 0.55)
    parts = {}
    # units: 1 stud = 0.25 here; R6: torso 2x2x1, limbs 1x2x1, head ~1.2
    parts["torso"] = rbox((2.0, 1.0, 2.0), (0, 0, 3.0), m_jacket, 0.08, name=name + "_Torso")
    parts["shirt"] = rbox((0.9, 1.02, 1.85), (0, -0.01, 3.0), m_shirt, 0.04, name=name + "_Shirt")
    parts["legL"] = rbox((0.98, 1.0, 2.0), (-0.5, 0, 1.0), m_pants, 0.08, name=name + "_LegL")
    parts["legR"] = rbox((0.98, 1.0, 2.0), (0.5, 0, 1.0), m_pants, 0.08, name=name + "_LegR")
    parts["armL"] = rbox((0.98, 1.0, 2.0), (-1.5, 0, 3.0), m_jacket, 0.08, name=name + "_ArmL")
    parts["armR"] = rbox((0.98, 1.0, 2.0), (1.5, 0, 3.0), m_jacket, 0.08, name=name + "_ArmR")
    parts["handL"] = rbox((0.96, 0.98, 0.5), (-1.5, 0, 2.2), m_skin, 0.08, name=name + "_HandL")
    parts["handR"] = rbox((0.96, 0.98, 0.5), (1.5, 0, 2.2), m_skin, 0.08, name=name + "_HandR")
    head = rbox((1.25, 1.2, 1.2), (0, 0, 4.62), m_skin, 0.32, name=name + "_Head", segments=6)
    parts["head"] = head
    # face as an image-textured plane slightly in front of the head
    if face_img:
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -0.615, 4.6), rotation=(math.radians(90), 0, 0))
        fp = bpy.context.object
        fp.name = name + "_Face"
        fp.scale = (1.1, 1.0, 1)
        fm = bpy.data.materials.new("Face")
        fm.use_nodes = True
        nt = fm.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(face_img)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        bsdf.inputs["Roughness"].default_value = 0.5
        fm.blend_method = "BLEND" if hasattr(fm, "blend_method") else None
        fp.data.materials.append(fm)
        parts["face"] = fp
    # hair: a cap plus chunky fringe blocks (orange, like the avatar in the gameplay footage)
    parts["hairCap"] = rbox((1.38, 1.32, 0.55), (0, 0.04, 5.2), m_hair, 0.22, name=name + "_HairCap")
    for i, (x, z, s) in enumerate([(-0.45, 4.95, 0.42), (0.0, 4.98, 0.46), (0.45, 4.95, 0.42)]):
        parts[f"fringe{i}"] = rbox((s, 0.3, 0.42), (x, -0.55, z), m_hair, 0.12, rot=(0, math.radians((i - 1) * 12), 0), name=f"{name}_Fringe{i}")
    parts["hairBack"] = rbox((1.4, 0.5, 1.0), (0, 0.45, 4.75), m_hair, 0.2, name=name + "_HairBack")
    for side in (-1, 1):
        parts[f"hairSide{side}"] = rbox((0.25, 1.0, 0.8), (side * 0.66, 0.1, 4.8), m_hair, 0.1, name=f"{name}_HairSide{side}")
    for k, p in parts.items():
        p.parent = root
    if outline > 0:
        om = mat_outline("AvatarOutline")
        for k, p in parts.items():
            if k != "face" and p.type == "MESH":
                add_outline(p, outline, om)
    return root, parts


def pose_arm(parts, side, angle_x, angle_y=0.0, angle_z=0.0):
    """Rotate an arm (and its hand) around the shoulder pivot."""
    arm = parts["armL" if side < 0 else "armR"]
    hand = parts["handL" if side < 0 else "handR"]
    piv = Vector((side * 1.5, 0, 3.9))
    for o in (arm, hand):
        rot = Euler((angle_x, angle_y, angle_z)).to_matrix().to_4x4()
        o.matrix_world = (
            __import__("mathutils").Matrix.Translation(piv) @ rot @ __import__("mathutils").Matrix.Translation(-piv) @ o.matrix_world
        )


# ---------------------------------------------------------------------------------------------
# Tools (shapes follow src/shared/Util/ToolModels.lua colours: rusty shovel, miner pick, abyss borer)
def shovel(name="Shovel", handle=(0.42, 0.26, 0.14), blade=(0.62, 0.64, 0.68), grip=(0.85, 0.12, 0.1)):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    h = rbox((0.22, 0.22, 3.4), (0, 0, 0), mat("Handle", handle, 0.6), 0.05, name=name + "_Handle")
    g = rbox((0.75, 0.28, 0.22), (0, 0, 1.75), mat("Grip", grip, 0.5), 0.06, name=name + "_Grip")
    b = rbox((1.1, 0.14, 1.25), (0, 0, -2.25), mat("Blade", blade, 0.25, metal=0.85), 0.05, name=name + "_Blade")
    tip = rbox((0.75, 0.13, 0.45), (0, 0, -3.0), mat("BladeTip", blade, 0.25, metal=0.85), 0.12, name=name + "_Tip")
    for o in (h, g, b, tip):
        o.parent = root
    return root


def pickaxe(name="Pick", handle=(0.85, 0.12, 0.1), head=(0.75, 0.76, 0.8)):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    h = rbox((0.24, 0.24, 3.6), (0, 0, 0), mat("PickHandle", handle, 0.5), 0.05, name=name + "_Handle")
    hd = rbox((3.0, 0.32, 0.42), (0, 0, 1.75), mat("PickHead", head, 0.25, metal=0.9), 0.08, name=name + "_Head")
    for s in (-1, 1):
        t = rbox((0.7, 0.26, 0.3), (s * 1.75, 0, 1.6), mat("PickTip", head, 0.25, metal=0.9), 0.06,
                 rot=(0, math.radians(s * 28), 0), name=f"{name}_Tip{s}")
        t.parent = root
    for o in (h, hd):
        o.parent = root
    return root


def crystal_cluster(color, n=7, scale=1.0, seed=1, emit=6.0, name="Crystal", loc=(0, 0, 0)):
    import random
    rnd = random.Random(seed)
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.location = loc
    m = mat(name + "_M", color, 0.08, emit=color, emit_strength=emit, coat=1.0)
    try:
        b = m.node_tree.nodes.get("Principled BSDF")
        b.inputs["Transmission Weight"].default_value = 0.35
    except Exception:
        pass
    for i in range(n):
        h = scale * rnd.uniform(0.9, 2.2) * (1.4 if i == 0 else 1.0)
        r = scale * rnd.uniform(0.22, 0.38) * (1.3 if i == 0 else 1.0)
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r, radius2=r * 0.85, depth=h, location=(0, 0, h / 2))
        body = bpy.context.object
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=r * 0.85, radius2=0.0, depth=r * 1.4, location=(0, 0, h + r * 0.7))
        tip = bpy.context.object
        for o in (body, tip):
            o.data.materials.append(m)
        bpy.ops.object.select_all(action="DESELECT")
        body.select_set(True)
        tip.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()
        c = bpy.context.object
        c.name = f"{name}_{i}"
        ang = rnd.uniform(0, math.tau)
        tilt = 0 if i == 0 else rnd.uniform(0.25, 0.7)
        c.rotation_euler = (math.sin(ang) * tilt, math.cos(ang) * tilt, rnd.uniform(0, 1))
        c.location = (math.cos(ang) * r * 0.9 * (0 if i == 0 else 1), math.sin(ang) * r * 0.9 * (0 if i == 0 else 1), 0)
        c.parent = root
    return root
