class_name BlockyFighter3D
extends Node3D

const HERO_SCENE := preload("res://Rigged_Blocky_Hero/Meshy_AI_Rigged_Blocky_Hero_20261110_animated_mixamo_Walking.fbx")
const STATUS_SHATTER_VFX := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/StatusFX/effects/status/vfx_status_shatter.tscn")
const TOON_SHADER := preload("res://game/shaders/character_toon.gdshader")
const OUTLINE_SHADER := preload("res://game/shaders/character_outline.gdshader")

var fighter_id: int = 0
var is_bot: bool = true
var base_color: Color = Color(0.45, 0.08, 0.78)
var shape_id: int = 0
var is_abomination: bool = false
var current_slots: Dictionary = {}

var pivot: Node3D
var hero_instance: Node3D
var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var char_mesh: MeshInstance3D

var head_socket: Node3D
var left_arm_socket: Node3D
var right_arm_socket: Node3D
var left_leg_socket: Node3D
var right_leg_socket: Node3D
var core_socket: Node3D

var player_cursor_ring: Node3D
var rocket_flame: MeshInstance3D
var bot_indicator_root: Node3D
var abomination_marker_root: Node3D
var abomination_ring: MeshInstance3D
var transform_burst_ring: MeshInstance3D

var _bone_head: int = -1
var _bone_left_arm: int = -1
var _bone_right_arm: int = -1
var _bone_left_forearm: int = -1
var _bone_right_forearm: int = -1
var _bone_left_hand: int = -1
var _bone_right_hand: int = -1
var _bone_left_upleg: int = -1
var _bone_right_upleg: int = -1
var _bone_left_leg: int = -1
var _bone_right_leg: int = -1
var _bone_left_foot: int = -1
var _bone_right_foot: int = -1

var _walk_phase: float = 0.0
var _transform_flash_timer: float = 0.0

static var _shared_outline_mat: ShaderMaterial
static var _shared_dark_mat: ShaderMaterial
static var _shared_shadow_mat: StandardMaterial3D
static var _shared_gold_mat: StandardMaterial3D
static var _shared_white_mat: StandardMaterial3D
static var _shared_red_eye_mat: StandardMaterial3D
static var _shared_magenta_mat: StandardMaterial3D
static var _shared_cyan_mat: StandardMaterial3D
static var _shared_player_ring_mat: StandardMaterial3D

func setup_fighter(id: int, bot: bool, color: Color, a11y_shape: int, initial_slots: Dictionary = {}, abom: bool = false) -> void:
	fighter_id = id
	is_bot = bot
	base_color = color
	shape_id = a11y_shape
	is_abomination = abom
	_walk_phase = float(id) * 0.85
	_ensure_shared_materials()
	_build_base_skeleton()
	if initial_slots.is_empty():
		initial_slots = {
			PartData.Slot.HEAD: &"laser_eye" if id == 0 else &"base_head",
			PartData.Slot.ARMS: &"chainsaw_arm" if id == 0 else &"base_fist",
			PartData.Slot.LEGS: &"rocket_legs" if id == 0 else &"base_boots",
			PartData.Slot.CORE: &"crown_core" if id == 0 else &"base_core",
		}
	apply_slots(initial_slots, abom, false)

static func _ensure_shared_materials() -> void:
	if _shared_outline_mat == null:
		_shared_outline_mat = ShaderMaterial.new()
		_shared_outline_mat.shader = OUTLINE_SHADER
		_shared_outline_mat.set_shader_parameter("outline_color", Color(0.07, 0.04, 0.14, 1.0))
		_shared_outline_mat.set_shader_parameter("outline_width", 0.036)
	if _shared_dark_mat == null:
		_shared_dark_mat = ShaderMaterial.new()
		_shared_dark_mat.shader = TOON_SHADER
		_shared_dark_mat.set_shader_parameter("base_color", Color(0.14, 0.13, 0.22))
		_shared_dark_mat.set_shader_parameter("emission_boost", 0.02)
		_shared_dark_mat.next_pass = _shared_outline_mat
	if _shared_shadow_mat == null:
		_shared_shadow_mat = StandardMaterial3D.new()
		_shared_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared_shadow_mat.albedo_color = Color(0.04, 0.02, 0.12, 0.58)
	if _shared_gold_mat == null:
		_shared_gold_mat = StandardMaterial3D.new()
		_shared_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_gold_mat.albedo_color = Color(1.0, 0.78, 0.15)
	if _shared_white_mat == null:
		_shared_white_mat = StandardMaterial3D.new()
		_shared_white_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_white_mat.albedo_color = Color(0.96, 0.96, 0.98)
	if _shared_red_eye_mat == null:
		_shared_red_eye_mat = StandardMaterial3D.new()
		_shared_red_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_red_eye_mat.albedo_color = Color(1.0, 0.20, 0.18)
	if _shared_magenta_mat == null:
		_shared_magenta_mat = StandardMaterial3D.new()
		_shared_magenta_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_magenta_mat.albedo_color = Color(1.0, 0.18, 0.58)
	if _shared_cyan_mat == null:
		_shared_cyan_mat = StandardMaterial3D.new()
		_shared_cyan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_cyan_mat.albedo_color = Color(0.18, 0.88, 1.0)
	if _shared_player_ring_mat == null:
		_shared_player_ring_mat = StandardMaterial3D.new()
		_shared_player_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_player_ring_mat.albedo_color = Color(0.76, 0.38, 1.0) # Signature Royal Purple glow

func _make_unshaded_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	return mat

func _make_toon_mat(col: Color, emission_boost: float = 0.06) -> ShaderMaterial:
	_ensure_shared_materials()
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("base_color", col)
	mat.set_shader_parameter("emission_boost", emission_boost)
	mat.next_pass = _shared_outline_mat
	return mat

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _clear_socket(socket: Node3D) -> void:
	if socket == null:
		return
	for child: Node in socket.get_children():
		child.free()

func _set_bone_scale(bone_idx: int, s: Vector3) -> void:
	if skeleton != null and bone_idx >= 0 and bone_idx < skeleton.get_bone_count():
		skeleton.set_bone_pose_scale(bone_idx, s)

func play_shatter_vfx(local_pos: Vector3) -> void:
	if STATUS_SHATTER_VFX == null or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var vfx: Node3D = STATUS_SHATTER_VFX.instantiate() as Node3D
	vfx.position = local_pos
	pivot.add_child(vfx)
	var ap: AnimationPlayer = vfx.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation("open"):
		ap.play("open")
	var t: SceneTreeTimer = tree.create_timer(0.75, true, false, true)
	t.timeout.connect(func() -> void:
		if is_instance_valid(vfx):
			vfx.queue_free()
	)

func _build_base_skeleton() -> void:
	for child: Node in get_children():
		child.free()

	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)

	# Soft circular ground shadow (replaces old clunky box shadow)
	var shadow_mi := MeshInstance3D.new()
	var shadow_cyl := CylinderMesh.new()
	shadow_cyl.top_radius = 0.74
	shadow_cyl.bottom_radius = 0.74
	shadow_cyl.height = 0.015
	shadow_cyl.radial_segments = 20
	shadow_mi.mesh = shadow_cyl
	shadow_mi.position = Vector3(0.0, 0.015, 0.0)
	shadow_mi.material_override = _shared_shadow_mat
	add_child(shadow_mi)

	# PLAYER DISTINCT GROUND CURSOR (Sleek hero-colored hollow torus ring)
	if fighter_id == 0:
		player_cursor_ring = Node3D.new()
		player_cursor_ring.name = "PlayerCursorRing"
		player_cursor_ring.position = Vector3(0.0, 0.035, 0.0)
		add_child(player_cursor_ring)

		# Outer glowing torus ring (flat horizontal circle on the ground in signature royal purple)
		var ring_mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.88
		torus.outer_radius = 1.00
		torus.rings = 24
		torus.ring_segments = 6
		ring_mi.mesh = torus
		ring_mi.position = Vector3(0.0, 0.06, 0.0)
		ring_mi.material_override = _shared_player_ring_mat
		player_cursor_ring.add_child(ring_mi)

		# Golden accent inner ring
		var inner_gold := MeshInstance3D.new()
		var inner_torus := TorusMesh.new()
		inner_torus.inner_radius = 0.72
		inner_torus.outer_radius = 0.78
		inner_torus.rings = 20
		inner_torus.ring_segments = 4
		inner_gold.mesh = inner_torus
		inner_gold.position = Vector3(0.0, 0.065, 0.0)
		inner_gold.material_override = _shared_gold_mat
		player_cursor_ring.add_child(inner_gold)

		# Directional pointer arrow extending forward (+Z)
		_add_box(player_cursor_ring, Vector3(0.14, 0.03, 0.42), Vector3(0.0, 0.07, 0.92), _shared_gold_mat)
		_add_box(player_cursor_ring, Vector3(0.32, 0.03, 0.14), Vector3(0.0, 0.07, 1.10), _shared_gold_mat)

	# Abomination Ground Aura Ring (flat horizontal torus on ground)
	abomination_ring = MeshInstance3D.new()
	var abom_torus := TorusMesh.new()
	abom_torus.inner_radius = 1.25
	abom_torus.outer_radius = 1.45
	abom_torus.rings = 24
	abom_torus.ring_segments = 6
	abomination_ring.mesh = abom_torus
	abomination_ring.position = Vector3(0.0, 0.065, 0.0)
	abomination_ring.material_override = _shared_magenta_mat
	abomination_ring.visible = false
	add_child(abomination_ring)

	transform_burst_ring = MeshInstance3D.new()
	var burst_torus := TorusMesh.new()
	burst_torus.inner_radius = 0.65
	burst_torus.outer_radius = 0.85
	burst_torus.rings = 24
	burst_torus.ring_segments = 6
	transform_burst_ring.mesh = burst_torus
	transform_burst_ring.position = Vector3(0.0, 0.08, 0.0)
	transform_burst_ring.material_override = _shared_gold_mat if fighter_id == 0 else _shared_white_mat
	transform_burst_ring.visible = false
	add_child(transform_burst_ring)

	var base_s: float = _get_target_base_scale()
	pivot.scale = Vector3.ONE * base_s

	# Instantiate the authentic Rigged Blocky Hero FBX model
	hero_instance = HERO_SCENE.instantiate() as Node3D
	hero_instance.name = "HeroModel"
	pivot.add_child(hero_instance)

	skeleton = hero_instance.find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = hero_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	char_mesh = hero_instance.find_child("char1", true, false) as MeshInstance3D

	# Tint bot materials or preserve pure crisp original texture for player
	if char_mesh != null and char_mesh.mesh != null and char_mesh.mesh.get_surface_count() > 0:
		var orig_mat = char_mesh.mesh.surface_get_material(0)
		if orig_mat != null:
			var mat: StandardMaterial3D = orig_mat.duplicate() as StandardMaterial3D
			if fighter_id == 0:
				mat.albedo_color = Color.WHITE
			else:
				# Tint bot body with vivid, saturated fighter palette color
				mat.albedo_color = base_color
			char_mesh.set_surface_override_material(0, mat)

	if skeleton != null:
		_bone_head = skeleton.find_bone("Head")
		_bone_left_arm = skeleton.find_bone("LeftArm")
		_bone_right_arm = skeleton.find_bone("RightArm")
		_bone_left_forearm = skeleton.find_bone("LeftForeArm")
		_bone_right_forearm = skeleton.find_bone("RightForeArm")
		_bone_left_hand = skeleton.find_bone("LeftHand")
		_bone_right_hand = skeleton.find_bone("RightHand")
		_bone_left_upleg = skeleton.find_bone("LeftUpLeg")
		_bone_right_upleg = skeleton.find_bone("RightUpLeg")
		_bone_left_leg = skeleton.find_bone("LeftLeg")
		_bone_right_leg = skeleton.find_bone("RightLeg")
		_bone_left_foot = skeleton.find_bone("LeftFoot")
		_bone_right_foot = skeleton.find_bone("RightFoot")

	# Sockets positioned precisely on character axes (+Z = Forward, +Y = Up, +X = Left, -X = Right)
	head_socket = Node3D.new()
	head_socket.name = "HeadSocket"
	head_socket.position = Vector3(0.0, 1.54, 0.0)
	pivot.add_child(head_socket)

	# In skeleton coordinates, LeftArm is at +X and RightArm is at -X
	left_arm_socket = Node3D.new()
	left_arm_socket.name = "LeftArmSocket"
	left_arm_socket.position = Vector3(0.38, 1.25, 0.0)
	pivot.add_child(left_arm_socket)

	right_arm_socket = Node3D.new()
	right_arm_socket.name = "RightArmSocket"
	right_arm_socket.position = Vector3(-0.38, 1.25, 0.0)
	pivot.add_child(right_arm_socket)

	left_leg_socket = Node3D.new()
	left_leg_socket.name = "LeftLegSocket"
	left_leg_socket.position = Vector3(0.16, 0.50, 0.0)
	pivot.add_child(left_leg_socket)

	right_leg_socket = Node3D.new()
	right_leg_socket.name = "RightLegSocket"
	right_leg_socket.position = Vector3(-0.16, 0.50, 0.0)
	pivot.add_child(right_leg_socket)

	core_socket = Node3D.new()
	core_socket.name = "CoreSocket"
	core_socket.position = Vector3(0.0, 1.15, 0.22)
	pivot.add_child(core_socket)

	# Bot indicator shape overhead (Rule 5 & Rule 9)
	bot_indicator_root = Node3D.new()
	bot_indicator_root.name = "BotIndicator"
	bot_indicator_root.position = Vector3(0.0, 2.55, 0.0)
	pivot.add_child(bot_indicator_root)
	if is_bot:
		_add_box(bot_indicator_root, Vector3(0.05, 0.20, 0.05), Vector3(0.0, -0.06, 0.0), _shared_dark_mat)
		var badge_rot := Vector3(0.0, 45.0 * float(shape_id), 45.0 if (shape_id % 2 == 1) else 0.0)
		_add_box(bot_indicator_root, Vector3(0.22, 0.22, 0.22), Vector3(0.0, 0.10, 0.0), _make_unshaded_mat(base_color.lightened(0.35)), badge_rot)

	# Overhead Abomination Crown Beacon
	abomination_marker_root = Node3D.new()
	abomination_marker_root.name = "AbominationMarker"
	abomination_marker_root.position = Vector3(0.0, 2.90, 0.0)
	abomination_marker_root.visible = false
	pivot.add_child(abomination_marker_root)
	_add_box(abomination_marker_root, Vector3(0.58, 0.14, 0.16), Vector3(0.0, 0.0, 0.0), _shared_gold_mat)
	_add_box(abomination_marker_root, Vector3(0.12, 0.24, 0.16), Vector3(-0.20, 0.14, 0.0), _shared_gold_mat)
	_add_box(abomination_marker_root, Vector3(0.14, 0.30, 0.16), Vector3(0.0, 0.18, 0.0), _shared_magenta_mat)
	_add_box(abomination_marker_root, Vector3(0.12, 0.24, 0.16), Vector3(0.20, 0.14, 0.0), _shared_gold_mat)

func apply_slots(new_slots: Dictionary, abom: bool, animate_pop: bool = true) -> void:
	var head_id: StringName = new_slots.get(PartData.Slot.HEAD, &"base_head") as StringName
	var arms_id: StringName = new_slots.get(PartData.Slot.ARMS, &"base_fist") as StringName
	var legs_id: StringName = new_slots.get(PartData.Slot.LEGS, &"base_boots") as StringName
	var core_id: StringName = new_slots.get(PartData.Slot.CORE, &"base_core") as StringName

	var changed: bool = false
	if current_slots.get(PartData.Slot.HEAD, &"") != head_id:
		_populate_head_socket(head_id)
		changed = true
	if current_slots.get(PartData.Slot.ARMS, &"") != arms_id:
		_populate_arm_sockets(arms_id)
		changed = true
	if current_slots.get(PartData.Slot.LEGS, &"") != legs_id:
		_populate_leg_sockets(legs_id)
		changed = true
	if current_slots.get(PartData.Slot.CORE, &"") != core_id:
		_populate_core_socket(core_id)
		changed = true

	current_slots = {
		PartData.Slot.HEAD: head_id,
		PartData.Slot.ARMS: arms_id,
		PartData.Slot.LEGS: legs_id,
		PartData.Slot.CORE: core_id,
	}
	is_abomination = abom
	if abomination_marker_root != null:
		abomination_marker_root.visible = is_abomination
	if abomination_ring != null:
		abomination_ring.visible = is_abomination

	if changed and animate_pop:
		trigger_transform_pop()

func trigger_transform_pop() -> void:
	_transform_flash_timer = 0.32
	if transform_burst_ring != null:
		transform_burst_ring.visible = true
		transform_burst_ring.scale = Vector3(0.35, 0.35, 0.35)
	if pivot != null:
		var base_s: float = _get_target_base_scale()
		pivot.scale = Vector3(1.38, 0.68, 1.38) * base_s

func _get_target_base_scale() -> float:
	if fighter_id == 0:
		return 1.65 if is_abomination else 1.28
	return 1.50 if is_abomination else 1.15

func _populate_head_socket(part_id: StringName) -> void:
	_clear_socket(head_socket)

	match part_id:
		&"laser_eye":
			# Sleek Cyber mono-visor with red laser lens on eye level (+Z face)
			_add_box(head_socket, Vector3(0.36, 0.12, 0.10), Vector3(0.0, 0.16, 0.22), _shared_dark_mat)
			_add_box(head_socket, Vector3(0.18, 0.06, 0.12), Vector3(0.0, 0.16, 0.23), _shared_red_eye_mat)
		&"visor_head":
			# Sleek dark cyber sunglasses with cyan trim on eye level (+Z face)
			_add_box(head_socket, Vector3(0.38, 0.12, 0.10), Vector3(0.0, 0.16, 0.22), _shared_dark_mat)
			_add_box(head_socket, Vector3(0.32, 0.05, 0.12), Vector3(0.0, 0.16, 0.23), _shared_cyan_mat)
		&"spike_helm":
			# Spiked red mohawk crest on top of head
			var crest_mat: ShaderMaterial = _make_toon_mat(Color(0.95, 0.16, 0.24), 0.12)
			_add_box(head_socket, Vector3(0.16, 0.32, 0.46), Vector3(0.0, 0.44, 0.0), crest_mat)
		_:
			# Default: show the natural expressive head of the 3D model!
			pass

func _populate_arm_sockets(part_id: StringName) -> void:
	_clear_socket(left_arm_socket)
	_clear_socket(right_arm_socket)

	match part_id:
		&"severed_one_arm":
			# Left Arm: severed socket stump with sparks
			_set_bone_scale(_bone_left_arm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_forearm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_hand, Vector3(0.001, 0.001, 0.001))
			# Right Arm: intact muscular arm
			_set_bone_scale(_bone_right_arm, Vector3.ONE)
			_set_bone_scale(_bone_right_forearm, Vector3.ONE)
			_set_bone_scale(_bone_right_hand, Vector3.ONE)

			var socket_mat: ShaderMaterial = _shared_dark_mat
			var spark_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.25, 0.20))
			_add_box(left_arm_socket, Vector3(0.24, 0.22, 0.24), Vector3(0.0, -0.09, 0.0), socket_mat)
			_add_box(left_arm_socket, Vector3(0.16, 0.08, 0.16), Vector3(0.0, -0.22, 0.0), spark_mat)
			play_shatter_vfx(left_arm_socket.position)

		&"severed_arms":
			# Hide skinned hero arms
			_set_bone_scale(_bone_left_arm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_arm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_forearm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_forearm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_hand, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_hand, Vector3(0.001, 0.001, 0.001))

			# Severed Arm Stumps: dark mechanical bone sockets with raw sparking ends
			var socket_mat: ShaderMaterial = _shared_dark_mat
			var spark_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.25, 0.20))
			_add_box(left_arm_socket, Vector3(0.24, 0.22, 0.24), Vector3(0.0, -0.09, 0.0), socket_mat)
			_add_box(left_arm_socket, Vector3(0.16, 0.08, 0.16), Vector3(0.0, -0.22, 0.0), spark_mat)
			_add_box(right_arm_socket, Vector3(0.24, 0.22, 0.24), Vector3(0.0, -0.09, 0.0), socket_mat)
			_add_box(right_arm_socket, Vector3(0.16, 0.08, 0.16), Vector3(0.0, -0.22, 0.0), spark_mat)
			play_shatter_vfx(left_arm_socket.position)
			play_shatter_vfx(right_arm_socket.position)

		&"chainsaw_arm":
			# Left Arm: show natural muscular arm from 3D model with spiked wristband
			_set_bone_scale(_bone_left_arm, Vector3.ONE)
			_set_bone_scale(_bone_left_forearm, Vector3.ONE)
			_set_bone_scale(_bone_left_hand, Vector3.ONE)
			_add_box(left_arm_socket, Vector3(0.26, 0.14, 0.26), Vector3(0.0, -0.32, 0.0), _shared_dark_mat)

			# Right Arm: hide skinned arm and equip Mechanical Chainsaw Blade extending forward (+Z)
			_set_bone_scale(_bone_right_arm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_forearm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_hand, Vector3(0.001, 0.001, 0.001))

			var orange_mat: ShaderMaterial = _make_toon_mat(Color(0.98, 0.44, 0.04), 0.08)
			var blade_mat: ShaderMaterial = _make_toon_mat(Color(0.85, 0.88, 0.92), 0.06)
			_add_box(right_arm_socket, Vector3(0.30, 0.32, 0.42), Vector3(0.0, -0.20, 0.20), orange_mat)
			var blade: MeshInstance3D = _add_box(right_arm_socket, Vector3(0.08, 0.28, 0.95), Vector3(0.0, -0.20, 0.85), blade_mat)
			for t_i: int in range(3):
				var tz: float = -0.25 + float(t_i) * 0.25
				_add_box(blade, Vector3(0.10, 0.06, 0.08), Vector3(0.0, 0.15, tz), _shared_dark_mat)
				_add_box(blade, Vector3(0.10, 0.06, 0.08), Vector3(0.0, -0.15, tz), _shared_dark_mat)

		&"mega_claws":
			# Keep arms visible, attach golden power claws to both hands
			_set_bone_scale(_bone_left_arm, Vector3.ONE)
			_set_bone_scale(_bone_right_arm, Vector3.ONE)
			_set_bone_scale(_bone_left_forearm, Vector3.ONE)
			_set_bone_scale(_bone_right_forearm, Vector3.ONE)
			_set_bone_scale(_bone_left_hand, Vector3.ONE)
			_set_bone_scale(_bone_right_hand, Vector3.ONE)

			var claw_mat: ShaderMaterial = _make_toon_mat(Color(1.0, 0.72, 0.14), 0.10)
			_add_box(left_arm_socket, Vector3(0.32, 0.32, 0.32), Vector3(0.0, -0.45, 0.0), claw_mat)
			_add_box(left_arm_socket, Vector3(0.08, 0.36, 0.12), Vector3(-0.10, -0.68, 0.08), _shared_magenta_mat)
			_add_box(left_arm_socket, Vector3(0.08, 0.36, 0.12), Vector3(0.10, -0.68, 0.08), _shared_magenta_mat)

			_add_box(right_arm_socket, Vector3(0.32, 0.32, 0.32), Vector3(0.0, -0.45, 0.0), claw_mat)
			_add_box(right_arm_socket, Vector3(0.08, 0.36, 0.12), Vector3(-0.10, -0.68, 0.08), _shared_magenta_mat)
			_add_box(right_arm_socket, Vector3(0.08, 0.36, 0.12), Vector3(0.10, -0.68, 0.08), _shared_magenta_mat)

		_:
			# Default: show the natural muscular arms of the 3D model!
			_set_bone_scale(_bone_left_arm, Vector3.ONE)
			_set_bone_scale(_bone_right_arm, Vector3.ONE)
			_set_bone_scale(_bone_left_forearm, Vector3.ONE)
			_set_bone_scale(_bone_right_forearm, Vector3.ONE)
			_set_bone_scale(_bone_left_hand, Vector3.ONE)
			_set_bone_scale(_bone_right_hand, Vector3.ONE)

func _populate_leg_sockets(part_id: StringName) -> void:
	_clear_socket(left_leg_socket)
	_clear_socket(right_leg_socket)
	rocket_flame = null

	match part_id:
		&"severed_one_leg":
			# Right Leg: severed peg stump with warning accent
			_set_bone_scale(_bone_right_upleg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_leg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_foot, Vector3(0.001, 0.001, 0.001))
			# Left Leg: authentic full rocket boot remains intact!
			_set_bone_scale(_bone_left_upleg, Vector3.ONE)
			_set_bone_scale(_bone_left_leg, Vector3.ONE)
			_set_bone_scale(_bone_left_foot, Vector3.ONE)

			var peg_mat: ShaderMaterial = _shared_dark_mat
			var warning_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.25, 0.20))
			_add_box(right_leg_socket, Vector3(0.20, 0.20, 0.20), Vector3(0.0, -0.08, 0.0), peg_mat)
			_add_box(right_leg_socket, Vector3(0.14, 0.06, 0.14), Vector3(0.0, -0.19, 0.0), warning_mat)
			play_shatter_vfx(right_leg_socket.position)

		&"severed_legs":
			# Hide skinned hero legs
			_set_bone_scale(_bone_left_upleg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_upleg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_leg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_leg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_foot, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_foot, Vector3(0.001, 0.001, 0.001))

			# Severed Leg Stumps: short mechanical pegs with warning hazard accents
			var peg_mat: ShaderMaterial = _shared_dark_mat
			var warning_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.25, 0.20))
			_add_box(left_leg_socket, Vector3(0.20, 0.20, 0.20), Vector3(0.0, -0.08, 0.0), peg_mat)
			_add_box(left_leg_socket, Vector3(0.14, 0.06, 0.14), Vector3(0.0, -0.19, 0.0), warning_mat)
			_add_box(right_leg_socket, Vector3(0.20, 0.20, 0.20), Vector3(0.0, -0.08, 0.0), peg_mat)
			_add_box(right_leg_socket, Vector3(0.14, 0.06, 0.14), Vector3(0.0, -0.19, 0.0), warning_mat)
			play_shatter_vfx(left_leg_socket.position)
			play_shatter_vfx(right_leg_socket.position)

		&"spring_legs":
			_set_bone_scale(_bone_left_upleg, Vector3.ONE)
			_set_bone_scale(_bone_right_upleg, Vector3.ONE)
			_set_bone_scale(_bone_left_leg, Vector3.ONE)
			_set_bone_scale(_bone_right_leg, Vector3.ONE)
			_set_bone_scale(_bone_left_foot, Vector3.ONE)
			_set_bone_scale(_bone_right_foot, Vector3.ONE)
			_add_box(left_leg_socket, Vector3(0.24, 0.22, 0.24), Vector3(0.0, -0.42, 0.0), _shared_cyan_mat)
			_add_box(right_leg_socket, Vector3(0.24, 0.22, 0.24), Vector3(0.0, -0.42, 0.0), _shared_cyan_mat)

		&"roller_wheels":
			_set_bone_scale(_bone_left_upleg, Vector3.ONE)
			_set_bone_scale(_bone_right_upleg, Vector3.ONE)
			_set_bone_scale(_bone_left_leg, Vector3.ONE)
			_set_bone_scale(_bone_right_leg, Vector3.ONE)
			_set_bone_scale(_bone_left_foot, Vector3.ONE)
			_set_bone_scale(_bone_right_foot, Vector3.ONE)
			_add_box(left_leg_socket, Vector3(0.36, 0.18, 0.44), Vector3(0.0, -0.44, 0.0), _shared_magenta_mat)
			_add_box(right_leg_socket, Vector3(0.36, 0.18, 0.44), Vector3(0.0, -0.44, 0.0), _shared_magenta_mat)

		_:
			# Default: show the natural rocket boots of the 3D model!
			_set_bone_scale(_bone_left_upleg, Vector3.ONE)
			_set_bone_scale(_bone_right_upleg, Vector3.ONE)
			_set_bone_scale(_bone_left_leg, Vector3.ONE)
			_set_bone_scale(_bone_right_leg, Vector3.ONE)
			_set_bone_scale(_bone_left_foot, Vector3.ONE)
			_set_bone_scale(_bone_right_foot, Vector3.ONE)

			# Rocket flame at heel
			rocket_flame = _add_box(right_leg_socket, Vector3(0.24, 0.42, 0.24), Vector3(0.0, -0.45, -0.15), _make_unshaded_mat(Color(1.0, 0.58, 0.10)))
			_add_box(rocket_flame, Vector3(0.14, 0.25, 0.14), Vector3(0.0, -0.05, 0.0), _shared_gold_mat)
			rocket_flame.visible = false

func _populate_core_socket(part_id: StringName) -> void:
	_clear_socket(core_socket)

	match part_id:
		&"shield_core":
			_add_box(core_socket, Vector3(0.42, 0.42, 0.08), Vector3.ZERO, _shared_cyan_mat)
			_add_box(core_socket, Vector3(0.22, 0.22, 0.10), Vector3.ZERO, _shared_white_mat)
		&"magnet_core":
			_add_box(core_socket, Vector3(0.42, 0.36, 0.08), Vector3.ZERO, _shared_magenta_mat)
			_add_box(core_socket, Vector3(0.12, 0.18, 0.10), Vector3(-0.12, 0.08, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.12, 0.18, 0.10), Vector3(0.12, 0.08, 0.0), _shared_gold_mat)
		&"crown_core":
			# 3D Golden Crown on chest
			_add_box(core_socket, Vector3(0.40, 0.18, 0.06), Vector3(0.0, -0.04, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.08, 0.14, 0.07), Vector3(-0.12, 0.08, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.09, 0.18, 0.07), Vector3(0.0, 0.10, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.08, 0.14, 0.07), Vector3(0.12, 0.08, 0.0), _shared_gold_mat)
		_:
			# Default: the model's torso already displays the royal shirt and gold crown!
			pass

func update_visual_state(
	interp_xz: Vector2,
	vel_xz: Vector2,
	facing_rad: float,
	attack_timer: float,
	hurt_timer: float,
	alive: bool,
	dt: float,
	ko_tumble_active: bool = false
) -> void:
	visible = alive or ko_tumble_active
	if not visible:
		return
	global_position = Vector3(interp_xz.x, 0.0, interp_xz.y)

	if ko_tumble_active and not alive:
		pivot.position.y = 0.50
		pivot.rotation_degrees = Vector3(-35.0, 22.0, 45.0)
		if anim_player != null and anim_player.is_playing():
			anim_player.pause()
		return

	# Upright stance
	pivot.rotation_degrees.x = 0.0
	pivot.rotation_degrees.z = 0.0

	# Smooth character rotation to face movement / target direction
	var target_yaw: float = -facing_rad + PI * 0.5
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw, minf(1.0, 16.0 * dt))

	if player_cursor_ring != null:
		player_cursor_ring.rotation.y = pivot.rotation.y

	var speed: float = vel_xz.length()
	var is_moving: bool = speed > 0.15

	# Drive Mixamo skeletal walk animation
	if anim_player != null:
		if is_moving:
			if not anim_player.is_playing():
				anim_player.play("Armature|Armature|Armature|Armature|walking_man|baselayer")
			anim_player.speed_scale = clampf(speed / 3.2, 0.75, 1.8)
		else:
			if anim_player.is_playing():
				anim_player.pause()

	# Drive attack swing on right arm socket
	if attack_timer > 0.0:
		right_arm_socket.rotation_degrees.x = -65.0
	else:
		right_arm_socket.rotation_degrees.x = lerpf(right_arm_socket.rotation_degrees.x, 0.0, minf(1.0, 14.0 * dt))

	# Severed legs limping wobble & hopping
	var legs_slot: StringName = current_slots.get(PartData.Slot.LEGS, &"")
	var has_severed_legs: bool = (legs_slot == &"severed_legs")
	var has_severed_one_leg: bool = (legs_slot == &"severed_one_leg")
	if is_moving:
		_walk_phase += (3.5 + speed * 1.5) * dt
		if has_severed_one_leg:
			# Hopping on single remaining leg: distinct vertical hop and asymmetric tilt!
			pivot.position.y = -0.06 + absf(sin(_walk_phase * 1.6)) * 0.16
			pivot.rotation_degrees.z = sin(_walk_phase * 1.6) * 13.0
		elif has_severed_legs:
			pivot.position.y = -0.12 + absf(sin(_walk_phase)) * 0.05
			pivot.rotation_degrees.z = sin(_walk_phase) * 7.0
		else:
			pivot.position.y = 0.0
			pivot.rotation_degrees.z = 0.0
	else:
		pivot.position.y = lerpf(pivot.position.y, 0.0, minf(1.0, 12.0 * dt))
		pivot.rotation_degrees.z = lerpf(pivot.rotation_degrees.z, 0.0, minf(1.0, 12.0 * dt))

	if rocket_flame != null:
		if is_moving and not has_severed_legs and not has_severed_one_leg:
			var pulse: float = 0.85 + 0.35 * sin(float(Time.get_ticks_msec()) * 0.02)
			rocket_flame.scale = Vector3(pulse, 0.90 + 0.40 * pulse, pulse)
			rocket_flame.visible = true
		else:
			rocket_flame.visible = false

	if abomination_marker_root != null and abomination_marker_root.visible:
		abomination_marker_root.rotate_y(2.8 * dt)
	if abomination_ring != null and abomination_ring.visible:
		abomination_ring.rotate_y(-1.8 * dt)

	var base_s: float = _get_target_base_scale()
	if _transform_flash_timer > 0.0:
		_transform_flash_timer = maxf(0.0, _transform_flash_timer - dt)
		var t_norm: float = 1.0 - (_transform_flash_timer / 0.32)
		if transform_burst_ring != null and transform_burst_ring.visible:
			transform_burst_ring.scale = Vector3.ONE * lerpf(0.35, 2.8, t_norm)
			if _transform_flash_timer <= 0.0:
				transform_burst_ring.visible = false
		var target_scale := Vector3.ONE
		if t_norm < 0.22:
			target_scale = Vector3(1.38, 0.68, 1.38) # Squash
		elif t_norm < 0.62:
			target_scale = Vector3(0.92, 1.26, 0.92) # Stretch overshoot
		else:
			target_scale = Vector3.ONE # Spring settle
		pivot.scale = pivot.scale.lerp(target_scale * base_s, minf(1.0, 18.0 * dt))
	elif hurt_timer > 0.0:
		pivot.scale = Vector3(1.18, 0.84, 1.18) * base_s
	else:
		pivot.scale = pivot.scale.lerp(Vector3.ONE * base_s, minf(1.0, 12.0 * dt))
