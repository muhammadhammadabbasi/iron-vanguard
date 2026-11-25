extends RefCounted
## Small helpers for building geometry out of primitives.


static func mesh_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func solid_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation = rot
	parent.add_child(sb)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	if mat != null:
		mesh_box(sb, size, Vector3.ZERO, mat)
	return sb


static func mesh_cyl(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO, top_radius := -1.0, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func solid_cyl(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation = rot
	parent.add_child(sb)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	sb.add_child(cs)
	mesh_cyl(sb, radius, height, Vector3.ZERO, mat)
	return sb


static func mesh_sphere(parent: Node, radius: float, pos: Vector3, mat: Material, scl := Vector3.ONE, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(segs / 2, 3)
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func no_shadow(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		no_shadow(c)
