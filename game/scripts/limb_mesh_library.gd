class_name LimbMeshLibrary
extends RefCounted
## Cuts real arms, legs and the head out of a rigged character scene.
##
## The character models are single skinned bodies, so a limb cannot simply be detached.
## This reads the skin weights once per model, keeps the triangles that belong to each limb,
## bakes them in rest pose and stores them as small rigid meshes. Those meshes are what lies
## on the floor after a limb pops off, what a fighter swings as a club and what gets grafted
## onto another body. One mesh and one draw call per limb.

enum Limb { ARM_L, ARM_R, LEG_L, LEG_R, HEAD }

const LIMB_SHADER := preload("res://game/shaders/limb_toon.gdshader")

const _ROOT_BONES: Array[String] = ["LeftArm", "RightArm", "LeftUpLeg", "RightUpLeg", "Head"]
const _TIP_BONES: Array[String] = ["LeftHand", "RightHand", "LeftFoot", "RightFoot", "HeadTop_End"]
const _BONE_PREFIXES: Array[String] = ["mixamorig_", "mixamorig:", ""]
const _SKIN_MATERIAL_TAGS: Array[String] = ["Material.038", "Material.064", "Material.326"]
const _EYE_COLOR := Color(0.04, 0.04, 0.04)

## resource path -> { Limb -> { "mesh": ArrayMesh, "length": float, "radius": float } }
static var _cache: Dictionary = {}

static func _find_bone(sk: Skeleton3D, base_name: String) -> int:
	for prefix: String in _BONE_PREFIXES:
		var idx: int = sk.find_bone(prefix + base_name)
		if idx >= 0:
			return idx
	return -1

## Returns the limb set for a character scene, building it on first use.
static func get_limb_set(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}
	var key: String = scene.resource_path
	if _cache.has(key):
		return _cache[key] as Dictionary
	var built: Dictionary = _build_limb_set(scene)
	_cache[key] = built
	return built

static func has_limb(scene: PackedScene, limb: int) -> bool:
	var limb_set: Dictionary = get_limb_set(scene)
	return limb_set.has(limb)

static func get_limb_length(scene: PackedScene, limb: int) -> float:
	var limb_set: Dictionary = get_limb_set(scene)
	if limb_set.has(limb):
		return float((limb_set[limb] as Dictionary)["length"])
	return 0.22

static func _build_limb_set(scene: PackedScene) -> Dictionary:
	var out: Dictionary = {}
	var inst: Node = scene.instantiate()
	var sk: Skeleton3D = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		inst.free()
		return out

	# Skeleton space -> model (scene root) space. Works off-tree by walking the parents.
	var skel_to_model := Transform3D.IDENTITY
	var walker: Node = sk
	while walker != null and walker != inst:
		if walker is Node3D:
			skel_to_model = (walker as Node3D).transform * skel_to_model
		walker = walker.get_parent()

	var bone_count: int = sk.get_bone_count()
	var limb_of_bone := PackedInt32Array()
	limb_of_bone.resize(bone_count)
	limb_of_bone.fill(-1)
	var root_idx: Array[int] = []
	var tip_idx: Array[int] = []
	for limb: int in range(_ROOT_BONES.size()):
		var r: int = _find_bone(sk, _ROOT_BONES[limb])
		root_idx.append(r)
		tip_idx.append(_find_bone(sk, _TIP_BONES[limb]))
		if r >= 0:
			limb_of_bone[r] = limb
	# Bones are stored parents-first, so one pass propagates each limb to its descendants.
	for b: int in range(bone_count):
		if limb_of_bone[b] >= 0:
			continue
		var parent: int = sk.get_bone_parent(b)
		if parent >= 0 and limb_of_bone[parent] >= 0:
			limb_of_bone[b] = limb_of_bone[parent]

	var limb_verts: Array[PackedVector3Array] = []
	var limb_normals: Array[PackedVector3Array] = []
	var limb_colors: Array[PackedColorArray] = []
	for _l: int in range(_ROOT_BONES.size()):
		limb_verts.append(PackedVector3Array())
		limb_normals.append(PackedVector3Array())
		limb_colors.append(PackedColorArray())

	var model_basis: Basis = skel_to_model.basis
	for node: Node in sk.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var skin: Skin = mi.skin
		var bind_count: int = skin.get_bind_count()
		var bind_bone := PackedInt32Array()
		bind_bone.resize(bind_count)
		var bind_xf: Array[Transform3D] = []
		for i: int in range(bind_count):
			var bone: int = skin.get_bind_bone(i)
			if bone < 0:
				bone = sk.find_bone(skin.get_bind_name(i))
			bind_bone[i] = bone
			if bone >= 0:
				bind_xf.append(sk.get_bone_global_rest(bone) * skin.get_bind_pose(i))
			else:
				bind_xf.append(Transform3D.IDENTITY)

		for s: int in range(mi.mesh.get_surface_count()):
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if verts.is_empty() or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
				continue
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var vcount: int = verts.size()
			var wpv: int = bones.size() / vcount
			if wpv <= 0:
				continue

			var mat: Material = mi.mesh.surface_get_material(s)
			var surf_col := Color.WHITE
			var tintable: float = 1.0
			if mat is BaseMaterial3D:
				surf_col = (mat as BaseMaterial3D).albedo_color
			var mat_name: String = mat.resource_name if mat != null else ""
			if mat_name.find("EYE") != -1:
				surf_col = _EYE_COLOR
				tintable = 0.0
			else:
				for tag: String in _SKIN_MATERIAL_TAGS:
					if mat_name.find(tag) != -1:
						tintable = 0.0
						break
			var vcol := Color(surf_col.r, surf_col.g, surf_col.b, tintable)

			# Which limb each vertex mostly follows.
			var vlimb := PackedInt32Array()
			vlimb.resize(vcount)
			var acc := PackedFloat32Array()
			acc.resize(_ROOT_BONES.size())
			for v: int in range(vcount):
				acc.fill(0.0)
				for k: int in range(wpv):
					var w: float = weights[v * wpv + k]
					if w <= 0.0:
						continue
					var bi: int = bones[v * wpv + k]
					if bi < 0 or bi >= bind_count:
						continue
					var bone: int = bind_bone[bi]
					if bone >= 0 and limb_of_bone[bone] >= 0:
						acc[limb_of_bone[bone]] += w
				var best: int = -1
				var best_w: float = 0.5
				for l: int in range(acc.size()):
					if acc[l] > best_w:
						best_w = acc[l]
						best = l
				vlimb[v] = best

			var indices: PackedInt32Array
			if arrays[Mesh.ARRAY_INDEX] != null:
				indices = arrays[Mesh.ARRAY_INDEX]
			else:
				indices.resize(vcount)
				for i: int in range(vcount):
					indices[i] = i

			var skinned_pos: Dictionary = {}
			var skinned_nrm: Dictionary = {}
			var tri: int = 0
			while tri + 2 < indices.size():
				var ia: int = indices[tri]
				var ib: int = indices[tri + 1]
				var ic: int = indices[tri + 2]
				tri += 3
				var la: int = vlimb[ia]
				var lb: int = vlimb[ib]
				var lc: int = vlimb[ic]
				# Only triangles fully inside the limb: a triangle that reaches into the torso
				# would drag a spike of cloth along with it.
				if la < 0 or la != lb or la != lc:
					continue
				var limb: int = la
				for vi: int in [ia, ib, ic]:
					if not skinned_pos.has(vi):
						var p := Vector3.ZERO
						var n := Vector3.ZERO
						var src_p: Vector3 = verts[vi]
						var src_n: Vector3 = normals[vi] if vi < normals.size() else Vector3.UP
						for k: int in range(wpv):
							var w: float = weights[vi * wpv + k]
							if w <= 0.0:
								continue
							var bi: int = bones[vi * wpv + k]
							if bi < 0 or bi >= bind_count:
								continue
							var xf: Transform3D = bind_xf[bi]
							p += (xf * src_p) * w
							n += (xf.basis * src_n) * w
						skinned_pos[vi] = skel_to_model * p
						skinned_nrm[vi] = (model_basis * n).normalized()
					limb_verts[limb].append(skinned_pos[vi] as Vector3)
					limb_normals[limb].append(skinned_nrm[vi] as Vector3)
					limb_colors[limb].append(vcol)

	for limb: int in range(_ROOT_BONES.size()):
		if root_idx[limb] < 0 or limb_verts[limb].size() < 9:
			continue
		var joint: Vector3 = skel_to_model * sk.get_bone_global_rest(root_idx[limb]).origin
		var rot := Quaternion.IDENTITY
		if limb != Limb.HEAD and tip_idx[limb] >= 0:
			# Limbs are stored hanging straight down from their joint (root at origin, tip at -Y).
			var tip: Vector3 = skel_to_model * sk.get_bone_global_rest(tip_idx[limb]).origin
			var axis: Vector3 = (tip - joint).normalized()
			if axis.length_squared() > 0.5 and axis.dot(Vector3.DOWN) < 0.9999:
				rot = Quaternion(axis, Vector3.DOWN)
		var v_arr: PackedVector3Array = limb_verts[limb]
		var n_arr: PackedVector3Array = limb_normals[limb]
		var length: float = 0.0
		var top: float = 0.0
		for i: int in range(v_arr.size()):
			var lp: Vector3 = rot * (v_arr[i] - joint)
			v_arr[i] = lp
			n_arr[i] = rot * n_arr[i]
			length = maxf(length, -lp.y)
			top = maxf(top, lp.y)
		# Root cross-section radius, used to size the toy joint peg.
		var radius: float = 0.0
		var radius_n: int = 0
		for i: int in range(v_arr.size()):
			var lp: Vector3 = v_arr[i]
			if absf(lp.y) < length * 0.18:
				radius += Vector2(lp.x, lp.z).length()
				radius_n += 1
		radius = (radius / float(radius_n)) if radius_n > 0 else length * 0.2

		var mesh_arrays: Array = []
		mesh_arrays.resize(Mesh.ARRAY_MAX)
		mesh_arrays[Mesh.ARRAY_VERTEX] = v_arr
		mesh_arrays[Mesh.ARRAY_NORMAL] = n_arr
		mesh_arrays[Mesh.ARRAY_COLOR] = limb_colors[limb]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
		out[limb] = {
			"mesh": am,
			"length": length if limb != Limb.HEAD else top,
			"radius": radius,
		}

	inst.free()
	return out

static func make_material(tint: Color, tint_amount: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LIMB_SHADER
	mat.set_shader_parameter("tint_color", tint)
	mat.set_shader_parameter("tint_amount", tint_amount)
	return mat

## Builds a limb node in model units: joint at the origin, limb hanging along -Y
## (the head sits upright on its neck joint). Carries the meta "limb_length".
static func build_limb_node(scene: PackedScene, limb: int, tint: Color, tint_amount: float, with_peg: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = "Limb"
	var limb_set: Dictionary = get_limb_set(scene)
	var mat: ShaderMaterial = make_material(tint, tint_amount)
	if limb_set.has(limb):
		var info: Dictionary = limb_set[limb]
		var mi := MeshInstance3D.new()
		mi.name = "LimbMesh"
		mi.mesh = info["mesh"] as ArrayMesh
		mi.material_override = mat
		root.add_child(mi)
		var length: float = float(info["length"])
		root.set_meta("limb_length", length)
		if with_peg and limb != Limb.HEAD:
			_add_joint_peg(root, float(info["radius"]))
	else:
		_build_fallback_limb(root, limb, tint)
	return root

## Toy-figure ball joint on the cut end: limbs pop off like action-figure parts, no gore.
static func _add_joint_peg(root: Node3D, radius: float) -> void:
	var peg := MeshInstance3D.new()
	peg.name = "JointPeg"
	var sm := SphereMesh.new()
	var r: float = maxf(radius * 0.62, 0.012)
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	peg.mesh = sm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.93, 0.90, 0.98)
	pm.roughness = 0.5
	peg.material_override = pm
	peg.position = Vector3(0.0, r * 0.35, 0.0)
	root.add_child(peg)

## Blocky stand-in when a model has no usable skin data.
static func _build_fallback_limb(root: Node3D, limb: int, tint: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.6
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.93, 0.74, 0.62)
	skin_mat.roughness = 0.6
	if limb == Limb.HEAD:
		_fallback_box(root, Vector3(0.16, 0.16, 0.16), Vector3(0.0, 0.08, 0.0), skin_mat)
		root.set_meta("limb_length", 0.16)
		return
	var is_leg: bool = limb == Limb.LEG_L or limb == Limb.LEG_R
	var length: float = 0.22 if is_leg else 0.20
	var thick: float = 0.075 if is_leg else 0.06
	_fallback_box(root, Vector3(thick, length * 0.7, thick), Vector3(0.0, -length * 0.35, 0.0), mat)
	if is_leg:
		_fallback_box(root, Vector3(thick * 1.15, length * 0.3, thick * 1.7), Vector3(0.0, -length * 0.85, thick * 0.3), skin_mat)
	else:
		_fallback_box(root, Vector3(thick * 1.3, length * 0.3, thick * 1.3), Vector3(0.0, -length * 0.85, 0.0), skin_mat)
	root.set_meta("limb_length", length)

static func _fallback_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
