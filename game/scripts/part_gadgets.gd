class_name PartGadgets
extends RefCounted
## The gadget a special part puts on a fighter's body: chainsaw on the hand, rocket boosters on
## the calves, visor on the head, emblem on the chest. Built from a few chunky primitives so a
## part reads at 40 px, and attached to the real bones so it moves with the animation.
##
## All sizes are in fighter units (the rig is about 1.5 tall). Each builder documents the
## local frame it expects. `mat_fn` is `func(color: Color, glow: float) -> Material`, so the
## fighter can hand in its toon material with the dark outline.

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

static func _cyl(parent: Node3D, bottom_r: float, top_r: float, height: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_r
	cm.top_radius = top_r
	cm.height = height
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _unshaded(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	return mat

## Hand frame: origin at the wrist, +Y pointing out of the arm past the fingers.
## `is_right` picks the hand for one-handed parts. Returns true if anything was built.
static func build_hand(part_id: StringName, parent: Node3D, is_right: bool, mat_fn: Callable) -> bool:
	var dark: Material = mat_fn.call(Color(0.16, 0.14, 0.24), 0.02)
	match part_id:
		&"chainsaw_arm":
			if not is_right:
				# Free hand gets a spiked wristband, the saw goes on the right.
				_cyl(parent, 0.085, 0.085, 0.07, Vector3(0.0, -0.02, 0.0), dark)
				return true
			_box(parent, Vector3(0.30, 0.07, 0.30), Vector3(0.0, -0.03, 0.0), dark)
			_box(parent, Vector3(0.27, 0.30, 0.27), Vector3(0.0, 0.13, 0.0), mat_fn.call(Color(0.98, 0.44, 0.04), 0.10))
			_box(parent, Vector3(0.10, 0.10, 0.31), Vector3(0.0, 0.20, 0.0), dark)
			var blade: MeshInstance3D = _box(parent, Vector3(0.07, 0.66, 0.20), Vector3(0.0, 0.60, 0.0), mat_fn.call(Color(0.62, 0.66, 0.74), 0.08))
			var edge: Material = mat_fn.call(Color(0.88, 0.90, 0.96), 0.05)
			_box(blade, Vector3(0.08, 0.66, 0.04), Vector3(0.0, 0.0, 0.10), edge)
			_box(blade, Vector3(0.08, 0.66, 0.04), Vector3(0.0, 0.0, -0.10), edge)
			for t_i: int in range(5):
				var ty: float = -0.26 + float(t_i) * 0.13
				_box(blade, Vector3(0.09, 0.06, 0.05), Vector3(0.0, ty, 0.135), dark)
				_box(blade, Vector3(0.09, 0.06, 0.05), Vector3(0.0, ty, -0.135), dark)
			return true
		&"giant_fist":
			# Cartoon boxing glove: white cuff, chunky red mitt, thumb on the inner side, a lighter
			# knuckle pad on the punching face and laces across the back.
			var glove: Material = mat_fn.call(Color(0.92, 0.12, 0.16), 0.10)
			var pad: Material = mat_fn.call(Color(1.0, 0.36, 0.34), 0.08)
			var cuff: Material = mat_fn.call(Color(0.97, 0.96, 0.92), 0.06)
			var side: float = -1.0 if is_right else 1.0
			_cyl(parent, 0.17, 0.19, 0.16, Vector3(0.0, -0.02, 0.0), cuff)
			_cyl(parent, 0.195, 0.195, 0.04, Vector3(0.0, 0.07, 0.0), glove)
			_box(parent, Vector3(0.46, 0.42, 0.44), Vector3(0.0, 0.30, 0.0), glove)
			_box(parent, Vector3(0.40, 0.36, 0.50), Vector3(0.0, 0.31, 0.0), glove)
			_box(parent, Vector3(0.38, 0.10, 0.40), Vector3(0.0, 0.53, 0.0), pad)
			_box(parent, Vector3(0.12, 0.24, 0.20), Vector3(side * 0.25, 0.22, 0.08), glove, Vector3(0.0, 0.0, side * -12.0))
			for l_i: int in range(3):
				_box(parent, Vector3(0.20, 0.03, 0.03), Vector3(0.0, 0.14 + float(l_i) * 0.07, -0.255), cuff)
			return true
		&"mega_claws":
			_box(parent, Vector3(0.32, 0.26, 0.32), Vector3(0.0, 0.08, 0.0), mat_fn.call(Color(1.0, 0.74, 0.14), 0.12))
			_box(parent, Vector3(0.35, 0.06, 0.35), Vector3(0.0, -0.05, 0.0), dark)
			var claw: Material = mat_fn.call(Color(1.0, 0.18, 0.58), 0.18)
			for c_i: int in range(3):
				var cx: float = -0.10 + float(c_i) * 0.10
				_box(parent, Vector3(0.065, 0.40, 0.09), Vector3(cx, 0.39, 0.02), claw, Vector3(0.0, 0.0, -cx * 110.0))
				_box(parent, Vector3(0.045, 0.14, 0.07), Vector3(cx * 1.45, 0.62, 0.02), claw, Vector3(0.0, 0.0, -cx * 110.0))
			return true
	return false

## Foot frame: origin at the ankle, +Y up, +Z toes forward. Returns the flame node of a rocket
## leg (shown only while moving), or null.
static func build_foot(part_id: StringName, parent: Node3D, mat_fn: Callable) -> Node3D:
	var dark: Material = mat_fn.call(Color(0.16, 0.14, 0.24), 0.02)
	match part_id:
		&"rocket_legs":
			var red: Material = mat_fn.call(Color(0.90, 0.14, 0.18), 0.10)
			var white: Material = mat_fn.call(Color(0.96, 0.96, 0.98), 0.08)
			# Booster strapped behind the calf: red body, white band and nose, dark nozzle.
			_cyl(parent, 0.09, 0.09, 0.30, Vector3(0.0, 0.17, -0.15), red)
			_cyl(parent, 0.095, 0.095, 0.07, Vector3(0.0, 0.20, -0.15), white)
			_cyl(parent, 0.09, 0.02, 0.11, Vector3(0.0, 0.375, -0.15), white)
			_cyl(parent, 0.10, 0.06, 0.08, Vector3(0.0, -0.01, -0.15), dark)
			_box(parent, Vector3(0.20, 0.05, 0.10), Vector3(0.0, 0.10, -0.06), dark)
			var flame := Node3D.new()
			flame.name = "RocketFlame"
			flame.position = Vector3(0.0, -0.05, -0.15)
			parent.add_child(flame)
			_cyl(flame, 0.0, 0.085, 0.30, Vector3(0.0, -0.15, 0.0), _unshaded(Color(1.0, 0.58, 0.10)))
			_cyl(flame, 0.0, 0.05, 0.18, Vector3(0.0, -0.09, 0.0), _unshaded(Color(1.0, 0.92, 0.45)))
			flame.visible = false
			return flame
		&"spring_legs":
			var coil: Material = mat_fn.call(Color(0.24, 0.78, 0.96), 0.12)
			for r_i: int in range(3):
				_cyl(parent, 0.15, 0.15, 0.04, Vector3(0.0, 0.03 + float(r_i) * 0.085, 0.0), coil)
			_cyl(parent, 0.165, 0.165, 0.05, Vector3(0.0, 0.29, 0.0), mat_fn.call(Color(1.0, 0.82, 0.20), 0.12))
		&"roller_wheels":
			var wheel: Material = mat_fn.call(Color(1.0, 0.30, 0.66), 0.14)
			_box(parent, Vector3(0.11, 0.05, 0.44), Vector3(0.0, -0.13, 0.06), dark)
			for w_z: float in [-0.09, 0.21]:
				_cyl(parent, 0.085, 0.085, 0.08, Vector3(0.0, -0.17, w_z), wheel, Vector3(0.0, 0.0, 90.0))
				_cyl(parent, 0.035, 0.035, 0.09, Vector3(0.0, -0.17, w_z), dark, Vector3(0.0, 0.0, 90.0))
	return null

## Head frame: origin at the head joint (base of the skull), +Y up, +Z face forward.
## `head_h` is the head height, `face_z` the distance from the joint to the face.
static func build_head(part_id: StringName, parent: Node3D, mat_fn: Callable, head_h: float = 0.58, face_z: float = 0.22, head_w: float = 0.46) -> bool:
	var dark: Material = mat_fn.call(Color(0.14, 0.13, 0.22), 0.02)
	var eye_y: float = head_h * 0.30
	match part_id:
		&"visor_head":
			_box(parent, Vector3(head_w * 1.04, 0.13, 0.10), Vector3(0.0, eye_y, face_z - 0.02), dark)
			_box(parent, Vector3(head_w * 0.90, 0.07, 0.11), Vector3(0.0, eye_y, face_z - 0.01), _unshaded(Color(0.18, 0.88, 1.0)))
			for side: float in [-1.0, 1.0]:
				_box(parent, Vector3(0.035, 0.06, face_z + 0.06), Vector3(side * head_w * 0.52, eye_y, (face_z - 0.06) * 0.5), dark)
			return true
		&"laser_eye":
			_box(parent, Vector3(head_w * 1.04, 0.12, 0.10), Vector3(0.0, eye_y, face_z - 0.02), dark)
			_box(parent, Vector3(0.17, 0.10, 0.15), Vector3(head_w * 0.16, eye_y, face_z + 0.01), dark)
			_box(parent, Vector3(0.11, 0.065, 0.16), Vector3(head_w * 0.16, eye_y, face_z + 0.02), _unshaded(Color(1.0, 0.20, 0.18)))
			_box(parent, Vector3(0.03, 0.16, 0.03), Vector3(-head_w * 0.50, eye_y + 0.14, 0.0), dark)
			_box(parent, Vector3(0.06, 0.06, 0.06), Vector3(-head_w * 0.50, eye_y + 0.24, 0.0), _unshaded(Color(1.0, 0.20, 0.18)))
			for side: float in [-1.0, 1.0]:
				_box(parent, Vector3(0.035, 0.06, face_z + 0.06), Vector3(side * head_w * 0.52, eye_y, (face_z - 0.06) * 0.5), dark)
			return true
		&"spike_helm":
			var crest: Material = mat_fn.call(Color(0.95, 0.16, 0.24), 0.14)
			var metal: Material = mat_fn.call(Color(0.56, 0.58, 0.70), 0.06)
			# A whole helmet shell over the top of the head: it swallows any hair or hat, so the
			# crest always sits on something instead of floating.
			var brim_y: float = eye_y + 0.035
			var top: float = head_h * 0.74
			var back_z: float = -face_z * 0.95
			var depth: float = face_z - back_z + 0.04
			var mid_z: float = (face_z + back_z) * 0.5
			_box(parent, Vector3(head_w * 1.04, top - brim_y, depth), Vector3(0.0, (brim_y + top) * 0.5, mid_z), metal)
			# Smaller cap on top so the shell reads rounded rather than a crate.
			_box(parent, Vector3(head_w * 0.86, 0.06, depth * 0.84), Vector3(0.0, top + 0.02, mid_z), metal)
			_box(parent, Vector3(head_w * 1.10, 0.05, depth + 0.04), Vector3(0.0, brim_y, mid_z), dark)
			for s: float in [-1.0, 1.0]:
				_box(parent, Vector3(0.05, 0.10, 0.10), Vector3(s * head_w * 0.57, brim_y - 0.06, mid_z + depth * 0.15), dark)
			for s_i: int in range(4):
				var sz: float = face_z - 0.06 - float(s_i) * (depth / 3.8)
				var sh: float = 0.22 - absf(float(s_i) - 1.0) * 0.045
				_box(parent, Vector3(0.08, sh, 0.10), Vector3(0.0, top + sh * 0.5, sz), crest, Vector3(-14.0, 0.0, 0.0))
			return true
	return false

## Chest frame: origin at the upper spine, +Y up, +Z forward out of the chest.
static func build_core(part_id: StringName, parent: Node3D, mat_fn: Callable, chest_z: float = 0.20) -> bool:
	var root := Node3D.new()
	root.name = "CoreGadget"
	root.position = Vector3(0.0, 0.0, chest_z)
	root.scale = Vector3.ONE * 1.25
	match part_id:
		&"shield_core":
			var shield: Material = mat_fn.call(Color(0.20, 0.62, 0.96), 0.12)
			var cross: Material = mat_fn.call(Color(0.92, 0.94, 0.98), 0.06)
			_box(root, Vector3(0.26, 0.26, 0.05), Vector3(0.0, 0.03, 0.0), shield)
			_box(root, Vector3(0.18, 0.14, 0.05), Vector3(0.0, -0.10, 0.0), shield)
			_box(root, Vector3(0.20, 0.06, 0.07), Vector3(0.0, 0.03, 0.0), cross)
			_box(root, Vector3(0.06, 0.20, 0.07), Vector3(0.0, 0.03, 0.0), cross)
		&"magnet_core":
			var mag: Material = mat_fn.call(Color(0.92, 0.20, 0.35), 0.12)
			var pole: Material = mat_fn.call(Color(0.85, 0.88, 0.95), 0.06)
			_box(root, Vector3(0.26, 0.08, 0.06), Vector3(0.0, -0.09, 0.0), mag)
			_box(root, Vector3(0.08, 0.18, 0.06), Vector3(-0.09, 0.01, 0.0), mag)
			_box(root, Vector3(0.08, 0.18, 0.06), Vector3(0.09, 0.01, 0.0), mag)
			_box(root, Vector3(0.08, 0.06, 0.07), Vector3(-0.09, 0.12, 0.0), pole)
			_box(root, Vector3(0.08, 0.06, 0.07), Vector3(0.09, 0.12, 0.0), pole)
		&"crown_core":
			var crown: Material = mat_fn.call(Color(1.0, 0.78, 0.15), 0.16)
			_box(root, Vector3(0.28, 0.11, 0.05), Vector3(0.0, -0.04, 0.0), crown)
			_box(root, Vector3(0.06, 0.10, 0.05), Vector3(-0.10, 0.05, 0.0), crown)
			_box(root, Vector3(0.07, 0.14, 0.05), Vector3(0.0, 0.07, 0.0), crown)
			_box(root, Vector3(0.06, 0.10, 0.05), Vector3(0.10, 0.05, 0.0), crown)
			_box(root, Vector3(0.05, 0.05, 0.07), Vector3(0.0, -0.04, 0.01), _unshaded(Color(1.0, 0.20, 0.30)))
		_:
			root.free()
			return false
	parent.add_child(root)
	return true
