import bpy
import math
import random
import os

def create_material(name, color):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = color
    return mat

def create_lowpoly_tree(name, trunk_color, leaf_color, leaf_scale=1.0, leaf_z_offset=2.5, radius=1.5):
    # Clear existing mesh objects
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

    # 1. Create Trunk (Cylinder, tapered)
    bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.3, depth=3.0, location=(0, 0, 1.5))
    trunk = bpy.context.active_object
    trunk.name = name + "_Trunk"
    
    # Taper top and slightly randomize
    for v in trunk.data.vertices:
        if v.co.z > 1.0:
            v.co.x *= 0.2
            v.co.y *= 0.2
        v.co.x += random.uniform(-0.05, 0.05)
        v.co.y += random.uniform(-0.05, 0.05)

    trunk_mat = create_material(name + "_TrunkMat", trunk_color)
    trunk.data.materials.append(trunk_mat)

    # 2. Create Leaves (Icosphere)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=(0, 0, leaf_z_offset))
    leaves = bpy.context.active_object
    leaves.name = name + "_Leaves"
    
    # Randomize vertices for low-poly stylized look
    for v in leaves.data.vertices:
        v.co.x += random.uniform(-0.3, 0.3) * leaf_scale
        v.co.y += random.uniform(-0.3, 0.3) * leaf_scale
        v.co.z += random.uniform(-0.3, 0.3) * leaf_scale

    leaves.scale = (leaf_scale, leaf_scale, leaf_scale * 0.9)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # Ensure flat shading
    for p in leaves.data.polygons:
        p.use_smooth = False

    leaf_mat = create_material(name + "_LeafMat", leaf_color)
    leaves.data.materials.append(leaf_mat)
    
    # Select both and join them!
    bpy.ops.object.select_all(action='DESELECT')
    trunk.select_set(True)
    leaves.select_set(True)
    bpy.context.view_layer.objects.active = trunk
    bpy.ops.object.join()
    
    # Rename the joined object to just the tree name
    tree_obj = bpy.context.active_object
    tree_obj.name = name
    
    # Output path
    out_dir = os.path.abspath("game/assets/models/trees")
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, f"{name}.glb")
    
    # Export the joined object
    bpy.ops.export_scene.gltf(filepath=out_file, use_selection=True, export_materials='EXPORT')
    print(f"Exported {out_file}")

# Linear colors for Blender
trunk_color = (0.04, 0.015, 0.005, 1.0)
pine_green = (0.01, 0.06, 0.02, 1.0)
oak_green = (0.02, 0.1, 0.03, 1.0)
light_green = (0.05, 0.15, 0.05, 1.0)

# Generate Trees
create_lowpoly_tree("PineTree", trunk_color, pine_green, leaf_scale=1.1, leaf_z_offset=2.8, radius=1.8)
create_lowpoly_tree("OakTree", trunk_color, oak_green, leaf_scale=1.6, leaf_z_offset=3.2, radius=2.2)
create_lowpoly_tree("SmallTree", trunk_color, light_green, leaf_scale=0.9, leaf_z_offset=2.0, radius=1.4)
