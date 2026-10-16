"""Build a stylized casual-game Wheel of Fortune in Blender (bpy).

Usage: python3 tools/build_wheel.py [output_dir] [--no-render]
Outputs: wheel_of_fortune.blend / .glb / .fbx and preview renders.

Hierarchy:
  WheelOfFortune (root)
    Stand            - static base, back post, bulbs
    Pointer          - static red pointer at the top (pivot at its top for wobble)
    Wheel_Spin       - rotates around the Y axis (front faces -Y); holds
                       segments, dividers, rim, bulbs, hub and prize icons
"""
import math
import os
import sys

import bpy  # noqa: I001  (bpy must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector

OUT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "models/wheel_of_fortune"
RENDER = "--no-render" not in sys.argv
FONT_PATH = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"

N_SEG = 8
R_HUB = 0.22
R_SEG = 0.88
R_RIM_OUT = 1.05


# ----------------------------------------------------------------- utilities
def srgb(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


MATS = {}


def mat(name, color, metallic=0.0, rough=0.3, coat=0.0, emit=0.0, transmission=0.0, ior=1.45):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = srgb(color)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if coat:
        p.inputs["Coat Weight"].default_value = coat
        p.inputs["Coat Roughness"].default_value = 0.05
    if emit:
        p.inputs["Emission Color"].default_value = srgb(color)
        p.inputs["Emission Strength"].default_value = emit
    if transmission:
        p.inputs["Transmission Weight"].default_value = transmission
        p.inputs["IOR"].default_value = ior
    m.diffuse_color = srgb(color)
    MATS[name] = m
    return m


def new_obj(name, bm, material=None, parent=None, loc=(0, 0, 0), smooth=True, bevel=0.0, bevel_seg=3):
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if material:
        ob.data.materials.append(material)
    ob.location = loc
    if parent:
        ob.parent = parent
    if bevel:
        b = ob.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = bevel_seg
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(35)
        b.harden_normals = True
    return ob


def empty(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    e.empty_display_size = 0.2
    if parent:
        e.parent = parent
    return e


def prism(points_xz, y0, y1):
    """Extrude a 2D outline (in the XZ plane) between y0 and y1."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in points_xz]
    back = [bm.verts.new((x, y1, z)) for x, z in points_xz]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(points_xz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    return bm


def cylinder(r, depth, segs=64, axis="Y", r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    if axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    elif axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    return bm


def sphere(r, u=24, v=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r)
    return bm


def box(sx, sy, sz):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    return bm


def torus(R, r, segs=96, rsegs=16, axis="Y"):
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        ring = []
        for j in range(rsegs):
            b = 2 * math.pi * j / rsegs
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new((rr * math.cos(a), r * math.sin(b), rr * math.sin(a))))
        rings.append(ring)
    for i in range(segs):
        for j in range(rsegs):
            a, b = rings[i], rings[(i + 1) % segs]
            bm.faces.new((a[j], b[j], b[(j + 1) % rsegs], a[(j + 1) % rsegs]))
    if axis == "Z":
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    return bm


def annulus(r_in, r_out, y0, y1, segs=128, a0=0.0, a1=2 * math.pi):
    """Ring (full or sector) facing -Y. Angles measured clockwise from +Z."""
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    steps = segs if full else max(4, int(segs * (a1 - a0) / (2 * math.pi)))
    count = steps if full else steps + 1
    bm = bmesh.new()

    def ring(r, y):
        return [bm.verts.new((r * math.sin(a0 + (a1 - a0) * k / steps), y, r * math.cos(a0 + (a1 - a0) * k / steps)))
                for k in range(count)]

    fo, fi, bo, bi = ring(r_out, y0), ring(r_in, y0), ring(r_out, y1), ring(r_in, y1)
    rng = range(count) if full else range(count - 1)
    for k in rng:
        m = (k + 1) % count
        bm.faces.new((fo[k], fo[m], fi[m], fi[k]))
        bm.faces.new((bo[m], bo[k], bi[k], bi[m]))
        bm.faces.new((fo[m], fo[k], bo[k], bo[m]))
        bm.faces.new((fi[k], fi[m], bi[m], bi[k]))
    if not full:
        bm.faces.new((fo[0], fi[0], bi[0], bo[0]))
        bm.faces.new((fo[-1], bo[-1], bi[-1], fi[-1]))
    return bm


def star_points(n=5, r_out=0.1, r_in=0.045, rot=0.0):
    pts = []
    for k in range(n * 2):
        r = r_out if k % 2 == 0 else r_in
        a = rot + math.pi * k / n
        pts.append((r * math.sin(a), r * math.cos(a)))
    return pts


def rounded_rect(w, h, r, steps=6):
    pts = []
    for cx, cz, a0 in ((w / 2 - r, h / 2 - r, 0), (w / 2 - r, -h / 2 + r, 90), (-w / 2 + r, -h / 2 + r, 180),
                       (-w / 2 + r, h / 2 - r, 270)):
        for s in range(steps + 1):
            a = math.radians(a0 + 90 * s / steps)
            pts.append((cx + r * math.sin(a), cz + r * math.cos(a)))
    return pts


def text_mesh(name, body, size, depth, material, parent, loc, bevel=0.006):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    if os.path.exists(FONT_PATH):
        cu.font = bpy.data.fonts.load(FONT_PATH, check_existing=True)
    cu.size = size
    cu.extrude = depth
    cu.bevel_depth = bevel
    cu.bevel_resolution = 2
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    tmp = bpy.data.objects.new(name + "_tmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    tmp.rotation_euler = (math.radians(90), 0, 0)  # text faces -Y
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    me.transform(tmp.matrix_basis)
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(material)
    ob.location = loc
    ob.parent = parent
    return ob


# ----------------------------------------------------------------- scene
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()


def materials():
    return dict(
        gold=mat("Gold", "#F2B01C", metallic=1.0, rough=0.2),
        gold_dark=mat("GoldDark", "#C7850C", metallic=1.0, rough=0.28),
        dark=mat("StandDark", "#262631", metallic=0.3, rough=0.35, coat=0.5),
        bulb=mat("Bulb", "#FFF4C8", rough=0.2, emit=18.0),
        red=mat("Red", "#E0141E", rough=0.25, coat=0.3),
        red_dark=mat("RedDark", "#9E1420", rough=0.3, coat=0.6),
        white=mat("White", "#F4F1EE", rough=0.3, coat=0.6),
        green_cash=mat("Cash", "#2E9E45", rough=0.5),
        green_cash_light=mat("CashLight", "#5CC46A", rough=0.5),
        gem_purple=mat("GemPurple", "#A855F7", rough=0.05, coat=1.0, transmission=0.6, ior=2.0),
        gem_red=mat("GemRed", "#E11D48", rough=0.05, coat=1.0),
        yellow_icon=mat("StarYellow", "#FFD21F", metallic=0.6, rough=0.2, coat=0.8),
        x2_green=mat("X2Green", "#22A93A", rough=0.25, coat=0.8),
        x2_text=mat("X2Text", "#FFC928", metallic=0.5, rough=0.25, coat=0.6),
    )


SEGMENTS = [  # clockwise from top
    ("Coins", "#1F6FF0"),
    ("Diamond", "#8B2CF5"),
    ("Gift", "#F45BB6"),
    ("Star", "#FF7417"),
    ("Cash", "#FFD21A"),
    ("X2", "#2EC23E"),
    ("Crown", "#18B4EE"),
    ("Jackpot", "#E5262D"),
]


# ----------------------------------------------------------------- icons
def icon_coins(M, parent):
    root = empty("Icon_Coins", parent)
    for i in range(4):
        c = new_obj(f"Coin_stack_{i}", cylinder(0.065, 0.022, 48, axis="Z"), M["gold"], root,
                    (0.03 + 0.012 * (i % 2), 0.02, -0.07 + i * 0.024), bevel=0.006)
    for i in range(3):
        new_obj(f"Coin_stack2_{i}", cylinder(0.055, 0.02, 48, axis="Z"), M["gold"], root,
                (0.1, 0.04, -0.08 + i * 0.022), bevel=0.006)
    front = new_obj("Coin_front", cylinder(0.055, 0.022, 48, axis="Y"), M["gold"], root, (-0.045, -0.05, -0.045),
                    bevel=0.006)
    front.rotation_euler = (0, math.radians(15), 0)
    new_obj("Coin_front_star", prism(star_points(5, 0.03, 0.013), -0.012, 0.0), M["gold_dark"], front,
            (0, -0.012, 0), bevel=0.002)
    return root


def icon_diamond(M, parent):
    root = empty("Icon_Diamond", parent)
    bm = bmesh.new()
    n = 8
    table = [bm.verts.new((0.06 * math.cos(2 * math.pi * k / n), 0.06 * math.sin(2 * math.pi * k / n), 0.05))
             for k in range(n)]
    girdle = [bm.verts.new((0.12 * math.cos(2 * math.pi * (k + 0.5) / n), 0.12 * math.sin(2 * math.pi * (k + 0.5) / n),
                            0.015)) for k in range(n)]
    tip = bm.verts.new((0, 0, -0.1))
    bm.faces.new(table)
    for k in range(n):
        m = (k + 1) % n
        bm.faces.new((table[k], girdle[k], table[m]))
        bm.faces.new((girdle[k], girdle[m], table[m]))
        bm.faces.new((girdle[k], tip, girdle[m]))
    gem = new_obj("Diamond", bm, M["gem_purple"], root, smooth=False)
    gem.rotation_euler = (math.radians(12), 0, math.radians(10))
    return root


def icon_gift(M, parent):
    root = empty("Icon_Gift", parent)
    new_obj("Gift_box", box(0.15, 0.15, 0.12), M["white"], root, (0, 0, -0.03), bevel=0.008)
    new_obj("Gift_lid", box(0.17, 0.17, 0.04), M["white"], root, (0, 0, 0.045), bevel=0.008)
    new_obj("Gift_ribbon_v", box(0.035, 0.176, 0.17), M["red"], root, (0, 0, 0.0), bevel=0.004)
    new_obj("Gift_ribbon_h", box(0.176, 0.035, 0.17), M["red"], root, (0, 0, 0.0), bevel=0.004)
    for side in (-1, 1):
        loop = new_obj(f"Gift_bow_{side}", torus(0.035, 0.012, 32, 10), M["red"], root, (side * 0.035, 0, 0.09))
        loop.rotation_euler = (0, math.radians(side * 30), 0)
        loop.scale = (1.0, 0.6, 1.0)
    new_obj("Gift_knot", sphere(0.018), M["red"], root, (0, -0.005, 0.075))
    root.rotation_euler = (math.radians(12), 0, math.radians(-25))
    return root


def icon_star(M, parent):
    root = empty("Icon_Star", parent)
    s = new_obj("Star", prism(star_points(5, 0.12, 0.055), -0.04, 0.0), M["yellow_icon"], root, bevel=0.018,
                bevel_seg=4)
    s.rotation_euler = (0, math.radians(-8), 0)
    return root


def icon_cash(M, parent):
    root = empty("Icon_Cash", parent)
    for i in range(4):
        new_obj(f"Cash_bill_{i}", box(0.2, 0.11, 0.018), M["green_cash"] if i % 2 == 0 else M["green_cash_light"],
                root, (0.004 * i, 0, -0.04 + i * 0.019), bevel=0.003)
    new_obj("Cash_band", box(0.05, 0.116, 0.082), M["x2_text"], root, (0.005, 0, -0.0105), bevel=0.003)
    text_mesh("Cash_dollar", "$", 0.06, 0.004, M["green_cash"], root, (0.005, -0.06, -0.012), bevel=0.001)
    root.rotation_euler = (math.radians(58), 0, math.radians(-12))
    return root


def icon_x2(M, parent):
    root = empty("Icon_X2", parent)
    new_obj("X2_disc", cylinder(0.105, 0.03, 64), M["x2_green"], root, (0, 0, 0), bevel=0.01)
    new_obj("X2_ring", torus(0.105, 0.012, 64, 12), M["x2_text"], root, (0, -0.005, 0))
    text_mesh("X2_text", "x2", 0.15, 0.012, M["x2_text"], root, (0, -0.03, 0.0), bevel=0.004)
    return root


def crown_outline(w=0.22, h=0.15):
    return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h * 0.35), (w / 4, 0.0), (0, h / 2), (-w / 4, 0.0),
            (-w / 2, h * 0.35)]


def icon_crown(M, parent, scale=1.0, name="Icon_Crown"):
    root = empty(name, parent)
    root.scale = (scale,) * 3
    new_obj(name + "_body", prism(crown_outline(), -0.03, 0.03), M["gold"], root, bevel=0.012, bevel_seg=4)
    new_obj(name + "_band", box(0.24, 0.07, 0.035), M["gold_dark"], root, (0, 0, -0.06), bevel=0.01)
    for x, z in ((-0.11, 0.055), (0.0, 0.08), (0.11, 0.055)):
        new_obj(name + "_ball", sphere(0.016), M["gold"], root, (x, 0, z))
    for x in (-0.07, 0.0, 0.07):
        g = new_obj(name + "_gem", prism([(0, 0.022), (0.016, 0), (0, -0.022), (-0.016, 0)], -0.045, -0.02),
                    M["gem_red"], root, (x, 0, -0.01), smooth=False, bevel=0.003)
    return root


def icon_jackpot(M, parent):
    root = empty("Icon_Jackpot", parent)
    new_obj("Jackpot_badge", prism(rounded_rect(0.36, 0.11, 0.03), -0.02, 0.01), M["red_dark"], root, bevel=0.012)
    text_mesh("Jackpot_text", "JACKPOT", 0.075, 0.012, M["x2_text"], root, (0, -0.035, -0.002), bevel=0.003)
    icon_crown(M, root, 0.35, "Jackpot_crown").location = (0, 0.0, 0.085)
    root.rotation_euler = (0, math.radians(-18), 0)  # matches the reference tilt inside the red segment
    return root


ICON_SCALE = {"Coins": 1.6, "Diamond": 1.4, "Gift": 1.8, "Star": 1.6, "Cash": 1.6, "X2": 1.7, "Crown": 1.6,
              "Jackpot": 1.4}

ICONS = {"Coins": icon_coins, "Diamond": icon_diamond, "Gift": icon_gift, "Star": icon_star, "Cash": icon_cash,
         "X2": icon_x2, "Crown": icon_crown, "Jackpot": icon_jackpot}


# ----------------------------------------------------------------- build
def build():
    reset()
    M = materials()
    root = empty("WheelOfFortune")
    wheel = empty("Wheel_Spin", root)

    # back plate + segments
    new_obj("Wheel_backplate", cylinder(R_SEG + 0.02, 0.06, 128), M["gold_dark"], wheel, (0, 0.03, 0), bevel=0.01)
    step = 2 * math.pi / N_SEG
    for i, (label, color) in enumerate(SEGMENTS):
        a0, a1 = i * step - step / 2, i * step + step / 2
        seg = new_obj(f"Segment_{i}_{label}", annulus(R_HUB - 0.02, R_SEG, -0.05, 0.0, 256, a0, a1),
                      mat(f"Seg_{label}", color, rough=0.3, coat=0.25), wheel, bevel=0.012, bevel_seg=3)
        icon = ICONS[label](M, wheel)
        mid = i * step
        r_icon = 0.6 if label == "Jackpot" else 0.56
        icon.location = (r_icon * math.sin(mid), -0.13, r_icon * math.cos(mid))
        icon.scale = tuple(s * ICON_SCALE[label] for s in icon.scale)
        # sparkle accents on some segments
        if label in ("Coins", "Diamond", "Star", "X2"):
            for k, (dx, dz, sz) in enumerate(((-0.16, 0.08, 0.03), (0.14, -0.1, 0.022))):
                new_obj(f"Sparkle_{label}_{k}", prism(star_points(4, sz, sz * 0.25), -0.008, 0.0), M["white"], wheel,
                        (icon.location.x + dx, -0.055, icon.location.z + dz), smooth=False)

    # dividers with rivets
    for i in range(N_SEG):
        a = i * step + step / 2
        rot = Matrix.Rotation(-a, 3, "Y")
        bm = box(0.032, 0.05, R_SEG - R_HUB)
        bmesh.ops.translate(bm, vec=(0, -0.03, (R_SEG + R_HUB) / 2), verts=bm.verts)
        bmesh.ops.rotate(bm, verts=bm.verts, matrix=rot)
        new_obj(f"Divider_{i}", bm, M["gold"], wheel, bevel=0.012, bevel_seg=3)
        p = rot @ Vector((0, 0, R_SEG + 0.005))
        new_obj(f"Rivet_{i}", sphere(0.04), M["gold"], wheel, (p.x, -0.07, p.z))

    # rim
    new_obj("Rim", annulus(R_SEG, R_RIM_OUT, -0.1, 0.06, 192), M["gold"], wheel, bevel=0.03, bevel_seg=4)
    new_obj("Rim_lip", torus(R_SEG + 0.01, 0.022, 160, 12, axis="Y"), M["gold_dark"], wheel, (0, -0.1, 0))
    n_bulbs = 28
    for k in range(n_bulbs):
        a = 2 * math.pi * (k + 0.5) / n_bulbs
        x, z = (R_SEG + R_RIM_OUT) / 2 * math.sin(a), (R_SEG + R_RIM_OUT) / 2 * math.cos(a)
        new_obj(f"RimBulb_socket_{k}", cylinder(0.032, 0.02, 24), M["gold_dark"], wheel, (x, -0.105, z), bevel=0.004)
        new_obj(f"RimBulb_{k}", sphere(0.026, 16, 10), M["bulb"], wheel, (x, -0.12, z))

    # hub
    new_obj("Hub", cylinder(R_HUB, 0.12, 96), M["gold"], wheel, (0, -0.08, 0), bevel=0.03, bevel_seg=4)
    new_obj("Hub_ring", torus(R_HUB * 0.78, 0.014, 96, 12), M["gold_dark"], wheel, (0, -0.14, 0))
    new_obj("Hub_star", prism(star_points(5, 0.12, 0.055), -0.04, 0.0), M["yellow_icon"], wheel, (0, -0.14, 0),
            bevel=0.016, bevel_seg=4)

    # pointer (static)
    pointer = empty("Pointer", root, (0, 0, R_RIM_OUT + 0.1))
    pointer.scale = (1.3, 1.0, 1.3)
    tri_gold = [(-0.16, 0.08), (0.16, 0.08), (0.0, -0.24)]
    tri_red = [(-0.115, 0.05), (0.115, 0.05), (0.0, -0.18)]
    new_obj("Pointer_frame", prism(tri_gold, -0.14, -0.04), M["gold"], pointer, bevel=0.035, bevel_seg=4)
    new_obj("Pointer_body", prism(tri_red, -0.16, -0.13), M["red"], pointer, bevel=0.02, bevel_seg=3)
    new_obj("Pointer_ball", sphere(0.04), M["gold"], pointer, (0, -0.17, 0.0))
    new_obj("Pointer_cap", box(0.36, 0.1, 0.05), M["gold"], pointer, (0, -0.09, 0.1), bevel=0.02)

    # stand (static)
    stand = empty("Stand", root)
    new_obj("Stand_base", prism(rounded_rect(1.7, 0.08, 0.03), -0.36, 0.36), M["gold"], stand, (0, 0, -1.33),
            bevel=0.02)
    band = rounded_rect(1.5, 0.13, 0.04)
    new_obj("Stand_band", prism(band, -0.3, 0.3), M["dark"], stand, (0, 0, -1.225), bevel=0.015)
    new_obj("Stand_top", prism(rounded_rect(1.4, 0.04, 0.015), -0.28, 0.28), M["gold"], stand, (0, 0, -1.14),
            bevel=0.012)
    for k in range(7):
        x = -0.6 + k * 0.2
        new_obj(f"StandBulb_{k}", sphere(0.03, 16, 10), M["bulb"], stand, (x, -0.3, -1.225))
    trap = [(-0.62, -1.12), (0.62, -1.12), (0.42, -0.55), (-0.42, -0.55)]
    new_obj("Stand_back", prism(trap, 0.07, 0.17), M["dark"], stand, bevel=0.02)
    for side in (-1, 1):
        rail = [(side * 0.62, -1.12), (side * 0.67, -1.12), (side * 0.47, -0.55), (side * 0.42, -0.55)]
        if side < 0:
            rail = list(reversed(rail))
        new_obj(f"Stand_trim_{side}", prism(rail, 0.05, 0.19), M["gold"], stand, bevel=0.01)
    new_obj("Stand_post", box(0.16, 0.12, 1.15), M["dark"], stand, (0, 0.19, -0.6), bevel=0.02)
    new_obj("Axle", cylinder(0.07, 0.2, 48), M["gold_dark"], stand, (0, 0.13, 0), bevel=0.01)

    return root, wheel, pointer


def animate(wheel, pointer, fps=30):
    """Spin animation: fast start, long ease-out, settles on the Jackpot."""
    sc = bpy.context.scene
    sc.render.fps = fps
    sc.frame_start, sc.frame_end = 1, 150
    wheel.rotation_mode = "XYZ"
    wheel.rotation_euler = (0, 0, 0)
    wheel.keyframe_insert("rotation_euler", index=1, frame=1)
    # rotating around +Y by +a turns the front (-Y side) clockwise; land Jackpot (segment 7) under the pointer
    wheel.rotation_euler = (0, 2 * math.pi * 5 + 2 * math.pi / N_SEG, 0)
    wheel.keyframe_insert("rotation_euler", index=1, frame=140)
    for fc in _fcurves(wheel):
        for kp in fc.keyframe_points:
            kp.interpolation = "QUART"
            kp.easing = "EASE_OUT"


def _fcurves(ob):
    ad = ob.animation_data
    if not ad or not ad.action:
        return []
    act = ad.action
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    out = []  # Blender 5 layered actions
    for layer in act.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.extend(cb.fcurves)
    return out


def setup_render(res=1080, samples=48):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = -0.2
    world = bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = srgb("#C9CBCF")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

    def area(name, loc, size, energy, color="#FFFFFF"):
        ld = bpy.data.lights.new(name, "AREA")
        ld.size = size
        ld.energy = energy
        ld.color = srgb(color)[:3]
        ob = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(ob)
        ob.location = loc
        d = Vector((0, 0, 0)) - Vector(loc)
        ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        return ob

    area("Key", (-2.5, -4.0, 3.0), 3.0, 550)
    area("Fill", (3.0, -3.5, 0.5), 4.0, 220, "#E8F0FF")
    area("Rim", (0.0, 3.0, 3.0), 3.0, 500)
    area("Top", (0.0, -1.5, 4.5), 2.0, 300)

    # hidden soft boxes for nice gold reflections
    for i, (loc, rot) in enumerate((((-2.2, -2.6, 1.6), (60, 0, -40)), ((2.4, -2.4, -0.6), (90, 0, 45)))):
        bm = box(2.5, 0.01, 1.4)
        sb = new_obj(f"SoftBox_{i}", bm, mat(f"SoftBox_{i}", "#FFFFFF", emit=3.0), None, loc, smooth=False)
        sb.rotation_euler = tuple(math.radians(v) for v in rot)
        sb.visible_camera = False
        sb.visible_shadow = False


def camera(name, loc, target=(0, 0, -0.15), lens=60):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    ob = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return ob


def render(cam, path):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    root, wheel, pointer = build()
    animate(wheel, pointer)
    setup_render()
    cam_front = camera("Cam_Front", (0, -4.9, -0.05), (0, 0, -0.05), 50)
    cam_34 = camera("Cam_3Q", (2.9, -4.1, 1.0), (0, 0, -0.1), 50)
    bpy.context.scene.frame_set(1)

    base = os.path.join(OUT, "wheel_of_fortune")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(base + ".blend"))

    # exports: only the model hierarchy (no lights/cameras/soft boxes)
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    model = [root] + list(root.children_recursive)
    for ob in model:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(base + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_animations=True)
    bpy.ops.export_scene.fbx(filepath=os.path.abspath(base + ".fbx"), use_selection=True, use_mesh_modifiers=True,
                             object_types={"EMPTY", "MESH"}, bake_anim=True, path_mode="COPY", embed_textures=True)

    if RENDER:
        render(cam_front, os.path.abspath(os.path.join(OUT, "preview_front.png")))
        render(cam_34, os.path.abspath(os.path.join(OUT, "preview_3q.png")))


if __name__ == "__main__":
    main()
