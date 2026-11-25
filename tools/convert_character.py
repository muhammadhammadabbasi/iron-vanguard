"""Convert a Mixamo FBX character to a compact GLB for Godot.

Usage:
  blender -b --python tools/convert_character.py -- input.fbx output.glb [max_texture_size]

- Shrinks every texture to max_texture_size (default 2048).
- Exports a binary glTF (.glb) with JPEG textures and the skeleton/skin intact.
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
max_size = int(argv[2]) if len(argv) > 2 else 2048

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src, automatic_bone_orientation=False, ignore_leaf_bones=True)

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
tris = 0
for o in meshes:
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print(f"CONVERT: meshes={len(meshes)} triangles={tris} armatures={len([o for o in bpy.data.objects if o.type == 'ARMATURE'])}")

for img in list(bpy.data.images):
    if img.size[0] == 0:
        print(f"CONVERT: texture {img.name} MISSING (not embedded in the FBX) - {img.filepath}")
        continue
    w, h = img.size
    if max(w, h) > max_size:
        s = max_size / max(w, h)
        img.scale(int(w * s), int(h * s))
        print(f"CONVERT: texture {img.name} {w}x{h} -> {img.size[0]}x{img.size[1]}")
    else:
        print(f"CONVERT: texture {img.name} {w}x{h}")
    try:
        img.pack()
    except RuntimeError as e:
        print(f"CONVERT: could not pack {img.name}: {e}")

bpy.ops.export_scene.gltf(
    filepath=dst,
    export_format="GLB",
    export_image_format="JPEG",
    export_jpeg_quality=88,
    export_animations=False,
    export_skins=True,
    export_yup=True,
    export_apply=False,
)
print("CONVERT: wrote", dst)
