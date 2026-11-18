extends RefCounted

static func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.68
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

static func put(parent: Node3D, mesh: Mesh, at: Vector3, paint: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = paint
	parent.add_child(part)
	part.position = at
	return part

static func orb(parent: Node3D, at: Vector3, radii: Vector3, paint: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var part := put(parent, mesh, at, paint)
	part.scale = radii
	return part

static func box(parent: Node3D, at: Vector3, size: Vector3, paint: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return put(parent, mesh, at, paint)

static func disc(parent: Node3D, at: Vector3, radius: float, height: float, paint: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 40
	return put(parent, mesh, at, paint)

static func link(parent: Node3D, start: Vector3, end: Vector3, radius: float, paint: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = start.distance_to(end) + 2.0 * radius
	mesh.radial_segments = 12
	mesh.rings = 4
	var part := put(parent, mesh, (start + end) * 0.5, paint)
	part.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return part

static func pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var part := Node3D.new()
	part.name = label
	parent.add_child(part)
	part.position = at
	return part
