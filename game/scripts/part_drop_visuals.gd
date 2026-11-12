class_name PartDropVisuals
extends RefCounted
## Builds what a dropped piece looks like on the arena floor: a real arm, leg or head cut
## from a character model (see LimbMeshLibrary), dressed with the gadget that makes the part
## special (chainsaw, rocket nozzle, visor...). No abstract cubes.
##
## Every visual is returned centred on its origin, long axis along local Y, in world units.

const ARM_WORLD_LENGTH: float = 0.95
const LEG_WORLD_LENGTH: float = 1.15
const HEAD_WORLD_HEIGHT: float = 0.82
const CORE_WORLD_SCALE: float = 2.5

static func _toon(col: Color, glow: float = 0.10) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = glow
	return mat

static func _glow(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	return mat

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## Adds a limb scaled to `world_length`, hanging from y = +length/2 down to y = -length/2.
static func _add_limb(root: Node3D, scene: PackedScene, limb: int, tint: Color, tint_amount: float, world_length: float) -> float:
	var node: Node3D = LimbMeshLibrary.build_limb_node(scene, limb, tint, tint_amount)
	var src_len: float = maxf(float(node.get_meta("limb_length", 0.2)), 0.001)
	var s: float = world_length / src_len
	node.scale = Vector3.ONE * s
	node.position = Vector3(0.0, world_length * 0.5, 0.0)
	root.add_child(node)
	return s

static func build(part_id: StringName, scene: PackedScene, tint: Color, tint_amount: float) -> Node3D:
	var root := Node3D.new()
	root.name = "PartVisual"
	var pdata: PartData = PartCatalog.get_part(part_id)
	var accent: StandardMaterial3D = _toon(pdata.accent_color, 0.25)
	var primary: StandardMaterial3D = _toon(pdata.primary_color, 0.18)
	var dark: StandardMaterial3D = _toon(Color(0.16, 0.14, 0.24), 0.02)

	match pdata.slot:
		PartData.Slot.ARMS:
			var half: float = ARM_WORLD_LENGTH * 0.5
			_add_limb(root, scene, LimbMeshLibrary.Limb.ARM_L, tint, tint_amount, ARM_WORLD_LENGTH)
			match part_id:
				&"chainsaw_arm":
					# Orange motor block over the hand, long toothed blade beyond it.
					_box(root, Vector3(0.36, 0.34, 0.36), Vector3(0.0, -half + 0.06, 0.0), _toon(Color(0.98, 0.44, 0.04), 0.2))
					var blade: MeshInstance3D = _box(root, Vector3(0.09, 0.72, 0.26), Vector3(0.0, -half - 0.44, 0.0), _toon(Color(0.62, 0.66, 0.74), 0.1))
					for t_i: int in range(4):
						var ty: float = -0.27 + float(t_i) * 0.18
						_box(blade, Vector3(0.10, 0.07, 0.06), Vector3(0.0, ty, 0.15), dark)
						_box(blade, Vector3(0.10, 0.07, 0.06), Vector3(0.0, ty, -0.15), dark)
				&"giant_fist":
					_box(root, Vector3(0.50, 0.46, 0.50), Vector3(0.0, -half - 0.05, 0.0), primary)
					_box(root, Vector3(0.54, 0.12, 0.54), Vector3(0.0, -half + 0.20, 0.0), accent)
				&"mega_claws":
					_box(root, Vector3(0.36, 0.30, 0.36), Vector3(0.0, -half + 0.02, 0.0), primary)
					for cx: float in [-0.12, 0.0, 0.12]:
						_box(root, Vector3(0.07, 0.42, 0.10), Vector3(cx, -half - 0.30, 0.04), accent, Vector3(-8.0, 0.0, cx * 60.0))
		PartData.Slot.LEGS:
			var half: float = LEG_WORLD_LENGTH * 0.5
			_add_limb(root, scene, LimbMeshLibrary.Limb.LEG_L, tint, tint_amount, LEG_WORLD_LENGTH)
			match part_id:
				&"rocket_legs":
					# Red and white rocket shin with a nozzle and flame at the heel (key-art leg).
					var red: StandardMaterial3D = _toon(Color(0.90, 0.14, 0.18), 0.18)
					var white: StandardMaterial3D = _toon(Color(0.96, 0.96, 0.98), 0.12)
					_cyl(root, 0.20, 0.16, Vector3(0.0, -half + 0.52, 0.0), red)
					_cyl(root, 0.205, 0.10, Vector3(0.0, -half + 0.39, 0.0), white)
					_cyl(root, 0.20, 0.16, Vector3(0.0, -half + 0.26, 0.0), red)
					_cyl(root, 0.17, 0.16, Vector3(0.0, -half - 0.04, -0.10), dark, Vector3.ZERO, 0.11)
					_cyl(root, 0.02, 0.40, Vector3(0.0, -half - 0.30, -0.10), _glow(Color(1.0, 0.62, 0.10)), Vector3.ZERO, 0.13)
					_cyl(root, 0.01, 0.24, Vector3(0.0, -half - 0.24, -0.10), _glow(Color(1.0, 0.92, 0.45)), Vector3.ZERO, 0.07)
				&"spring_legs":
					for ring_i: int in range(4):
						_cyl(root, 0.19, 0.045, Vector3(0.0, -half - 0.06 - float(ring_i) * 0.09, 0.03), primary)
					_cyl(root, 0.23, 0.05, Vector3(0.0, -half - 0.42, 0.03), accent)
				&"roller_wheels":
					_box(root, Vector3(0.30, 0.08, 0.52), Vector3(0.0, -half - 0.03, 0.06), dark)
					_cyl(root, 0.15, 0.14, Vector3(0.0, -half - 0.16, 0.24), accent, Vector3(0.0, 0.0, 90.0))
					_cyl(root, 0.15, 0.14, Vector3(0.0, -half - 0.16, -0.12), accent, Vector3(0.0, 0.0, 90.0))
		PartData.Slot.HEAD:
			var head: Node3D = LimbMeshLibrary.build_limb_node(scene, LimbMeshLibrary.Limb.HEAD, tint, tint_amount, false)
			var src_h: float = maxf(float(head.get_meta("limb_length", 0.2)), 0.001)
			var hs: float = HEAD_WORLD_HEIGHT / src_h
			head.scale = Vector3.ONE * hs
			head.position = Vector3(0.0, -HEAD_WORLD_HEIGHT * 0.5, 0.0)
			root.add_child(head)
			# Face metrics: eyes sit around 45% of the head height, on the +Z side.
			var eye_y: float = -HEAD_WORLD_HEIGHT * 0.5 + HEAD_WORLD_HEIGHT * 0.42
			var face_z: float = HEAD_WORLD_HEIGHT * 0.36
			var face_w: float = HEAD_WORLD_HEIGHT * 0.62
			match part_id:
				&"visor_head":
					_box(root, Vector3(face_w, 0.17, 0.10), Vector3(0.0, eye_y, face_z), dark)
					_box(root, Vector3(face_w * 0.86, 0.08, 0.12), Vector3(0.0, eye_y, face_z + 0.01), _glow(Color(0.18, 0.88, 1.0)))
				&"laser_eye":
					_box(root, Vector3(face_w, 0.17, 0.10), Vector3(0.0, eye_y, face_z), dark)
					_box(root, Vector3(0.20, 0.11, 0.14), Vector3(0.0, eye_y, face_z + 0.02), _glow(Color(1.0, 0.20, 0.18)))
				&"spike_helm":
					var crest: StandardMaterial3D = _toon(Color(0.95, 0.16, 0.24), 0.25)
					for sp_i: int in range(4):
						var sz: float = -0.22 + float(sp_i) * 0.14
						_box(root, Vector3(0.09, 0.26, 0.12), Vector3(0.0, HEAD_WORLD_HEIGHT * 0.5 + 0.05, sz), crest, Vector3(-12.0 + float(sp_i) * 8.0, 0.0, 0.0))
		PartData.Slot.CORE:
			var core := Node3D.new()
			core.name = "CoreGadget"
			core.scale = Vector3.ONE * CORE_WORLD_SCALE
			root.add_child(core)
			match part_id:
				&"shield_core":
					var shield_mat: StandardMaterial3D = _toon(Color(0.20, 0.62, 0.96), 0.2)
					var cross_mat: StandardMaterial3D = _toon(Color(0.92, 0.94, 0.98), 0.15)
					_box(core, Vector3(0.26, 0.28, 0.06), Vector3(0.0, 0.03, 0.0), shield_mat)
					_box(core, Vector3(0.18, 0.16, 0.06), Vector3(0.0, -0.09, 0.0), shield_mat)
					_box(core, Vector3(0.20, 0.06, 0.08), Vector3(0.0, 0.03, 0.0), cross_mat)
					_box(core, Vector3(0.06, 0.20, 0.08), Vector3(0.0, 0.03, 0.0), cross_mat)
				&"magnet_core":
					var mag_mat: StandardMaterial3D = _toon(Color(0.92, 0.20, 0.35), 0.2)
					var pole_mat: StandardMaterial3D = _toon(Color(0.85, 0.88, 0.95), 0.15)
					_box(core, Vector3(0.26, 0.08, 0.07), Vector3(0.0, -0.10, 0.0), mag_mat)
					_box(core, Vector3(0.08, 0.18, 0.07), Vector3(-0.09, 0.0, 0.0), mag_mat)
					_box(core, Vector3(0.08, 0.18, 0.07), Vector3(0.09, 0.0, 0.0), mag_mat)
					_box(core, Vector3(0.08, 0.06, 0.08), Vector3(-0.09, 0.11, 0.0), pole_mat)
					_box(core, Vector3(0.08, 0.06, 0.08), Vector3(0.09, 0.11, 0.0), pole_mat)
				&"crown_core":
					var crown_mat: StandardMaterial3D = _toon(Color(1.0, 0.78, 0.15), 0.3)
					_box(core, Vector3(0.28, 0.12, 0.07), Vector3(0.0, -0.05, 0.0), crown_mat)
					_box(core, Vector3(0.06, 0.10, 0.07), Vector3(-0.10, 0.04, 0.0), crown_mat)
					_box(core, Vector3(0.07, 0.14, 0.07), Vector3(0.0, 0.07, 0.0), crown_mat)
					_box(core, Vector3(0.06, 0.10, 0.07), Vector3(0.10, 0.04, 0.0), crown_mat)
					_box(core, Vector3(0.05, 0.05, 0.08), Vector3(0.0, -0.04, 0.01), _glow(Color(1.0, 0.20, 0.30)))
				_:
					# Plain reactor: a little battery cell.
					_cyl(core, 0.09, 0.22, Vector3.ZERO, primary)
					_cyl(core, 0.095, 0.05, Vector3(0.0, 0.07, 0.0), accent)
	return root

## Long axis length of the visual in world units (used to lay it flat on the floor).
static func get_visual_length(part_id: StringName) -> float:
	match PartCatalog.get_part(part_id).slot:
		PartData.Slot.ARMS:
			return ARM_WORLD_LENGTH
		PartData.Slot.LEGS:
			return LEG_WORLD_LENGTH
		PartData.Slot.HEAD:
			return HEAD_WORLD_HEIGHT
	return 0.9
