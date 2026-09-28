# Shared helpers for the package C Blender scripts (run inside Blender 5.2, background mode).
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P <script>.py -- args
#
# Rendering trick used for card atlases: every material is an *emission* shader, so a Cycles
# render with a transparent film gives exact albedo (view transform Standard: linear emission
# -> sRGB PNG, the same encoding as the source textures) or an encoded normal (view transform
# Raw: emission n * 0.5 + 0.5 lands unchanged in the PNG). No lights, no noise except edge AA.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix

FRONTIER = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
POLYHAVEN = os.path.join(FRONTIER, 'assets', 'polyhaven')
ENV = os.path.join(FRONTIER, 'assets', 'environment')


def args():
    a = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = {}
    for s in a:
        if '=' in s:
            k, v = s.split('=', 1)
            out[k] = v
        else:
            out[s] = '1'
    return out


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def setup_render(res_x, res_y, samples=32, raw=False):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = False
    sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 0
    sc.cycles.diffuse_bounces = 0
    sc.cycles.glossy_bounces = 0
    sc.cycles.transmission_bounces = 0
    sc.cycles.transparent_max_bounces = 16
    sc.cycles.pixel_filter_type = 'BLACKMAN_HARRIS'
    sc.cycles.filter_width = 1.2
    sc.render.film_transparent = True
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.view_settings.view_transform = 'Raw' if raw else 'Standard'
    sc.view_settings.look = 'None'
    sc.view_settings.exposure = 0.0
    sc.view_settings.gamma = 1.0
    sc.display_settings.display_device = 'sRGB'
    if sc.world is None:
        sc.world = bpy.data.worlds.new('World')
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get('Background')
    if bg:
        bg.inputs[1].default_value = 0.0


def ortho_camera(center, size_x, size_y, direction=(0, 0, -1), up=(0, 1, 0), dist=20.0):
    """Orthographic camera looking along `direction`, image up = `up`, covering size_x by size_y."""
    sc = bpy.context.scene
    cam = sc.camera
    if cam is None:
        cd = bpy.data.cameras.new('OrthoCam')
        cam = bpy.data.objects.new('OrthoCam', cd)
        sc.collection.objects.link(cam)
        sc.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = max(size_x, size_y)
    cam.data.sensor_fit = 'AUTO'
    cam.data.clip_start = 0.01
    cam.data.clip_end = dist * 2 + 100
    d = Vector(direction).normalized()
    u = Vector(up).normalized()
    r = d.cross(u).normalized()
    u = r.cross(d).normalized()
    # Camera looks down its local -Z, local +Y is image up, +X image right.
    m = Matrix((r, u, -d)).transposed()
    cam.matrix_world = Matrix.Translation(Vector(center) - d * dist) @ m.to_4x4()
    return cam


def render_to(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# --- Emission materials ---------------------------------------------------------------------

def _nodes(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    return nt, out


def emission_image_material(name, image_path, tint=(1, 1, 1), ao_distance=0.0, alpha_from=None,
                            vcol=None):
    """Albedo pass: emission = texture * tint (* vertex colour attribute `vcol`) (* local AO)."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(image_path, check_existing=True)
    col = tex.outputs['Color']
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.blend_type = 'MULTIPLY'
    mix.inputs['Factor'].default_value = 1.0
    nt.links.new(col, mix.inputs['A'])
    mix.inputs['B'].default_value = (*tint, 1.0)
    col = mix.outputs['Result']
    if vcol:
        attr = nt.nodes.new('ShaderNodeAttribute')
        attr.attribute_name = vcol
        m2 = nt.nodes.new('ShaderNodeMix')
        m2.data_type = 'RGBA'
        m2.blend_type = 'MULTIPLY'
        m2.inputs['Factor'].default_value = 1.0
        nt.links.new(col, m2.inputs['A'])
        nt.links.new(attr.outputs['Color'], m2.inputs['B'])
        col = m2.outputs['Result']
    if ao_distance > 0:
        ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
        ao.samples = 16
        ao.only_local = True
        ao.inputs['Distance'].default_value = ao_distance
        nt.links.new(col, ao.inputs['Color'])
        col = ao.outputs['Color']
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Strength'].default_value = 1.0
    nt.links.new(col, em.inputs['Color'])
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    return mat


def emission_attr_material(name, attr_name='leafcol', ao_distance=0.0, detail=None):
    """Albedo pass for procedural geometry: emission = colour attribute (* AO) (* detail(...))."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    attr = nt.nodes.new('ShaderNodeAttribute')
    attr.attribute_name = attr_name
    col = attr.outputs['Color']
    if detail is not None:
        col = detail(nt, col)
    if ao_distance > 0:
        ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
        ao.samples = 16
        ao.only_local = True
        ao.inputs['Distance'].default_value = ao_distance
        nt.links.new(col, ao.inputs['Color'])
        col = ao.outputs['Color']
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(col, em.inputs['Color'])
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    return mat


def normal_material(name='NormalPass', space_matrix=None, alpha_image=None):
    """Normal pass: emission = n * 0.5 + 0.5 of the shading normal in world space (Cycles
    flips it toward the camera on back faces). Render with raw=True. For a camera looking down -Z with image up = +Y, world space
    equals the card's OpenGL tangent space (+X right, +Y up, +Z out of the card)."""
    mat = bpy.data.materials.new(name)
    nt, out = _nodes(mat)
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    # Cycles already flips N toward the viewer on back faces.
    n = geo.outputs['Normal']
    if space_matrix is not None:
        # Rotate into the view's frame: rows of the matrix as dot products.
        comps = []
        for row in space_matrix:
            dp = nt.nodes.new('ShaderNodeVectorMath')
            dp.operation = 'DOT_PRODUCT'
            nt.links.new(n, dp.inputs[0])
            dp.inputs[1].default_value = tuple(row)
            comps.append(dp.outputs['Value'])
        comb = nt.nodes.new('ShaderNodeCombineXYZ')
        for i in range(3):
            nt.links.new(comps[i], comb.inputs[i])
        n = comb.outputs['Vector']
    half = nt.nodes.new('ShaderNodeVectorMath')
    half.operation = 'MULTIPLY_ADD'
    nt.links.new(n, half.inputs[0])
    half.inputs[1].default_value = (0.5, 0.5, 0.5)
    half.inputs[2].default_value = (0.5, 0.5, 0.5)
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(half.outputs['Vector'], em.inputs['Color'])
    if alpha_image:
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(alpha_image, check_existing=True)
        gt = nt.nodes.new('ShaderNodeMath')
        gt.operation = 'GREATER_THAN'
        gt.inputs[1].default_value = 0.5
        nt.links.new(tex.outputs['Alpha'], gt.inputs[0])
        tr = nt.nodes.new('ShaderNodeBsdfTransparent')
        mix = nt.nodes.new('ShaderNodeMixShader')
        nt.links.new(gt.outputs[0], mix.inputs['Fac'])
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs['Surface'])
    else:
        nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    return mat


def set_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.material_index = 0


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    link(ob)
    return ob
