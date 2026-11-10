class_name BlockyFighter3D
extends Node3D

const TOON_SHADER := preload("res://game/shaders/character_toon.gdshader")
const OUTLINE_SHADER := preload("res://game/shaders/character_outline.gdshader")

var fighter_id: int = 0
var is_bot: bool = true
var base_color: Color = Color(0.45, 0.08, 0.78)
var shape_id: int = 0
var is_abomination: bool = false
var current_slots: Dictionary = {}

var pivot: Node3D
var torso_mesh: MeshInstance3D
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

var _walk_phase: float = 0.0
var _transform_flash_timer: float = 0.0
var _body_mat: ShaderMaterial
var _skin_mat: ShaderMaterial

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
		_shared_shadow_mat.albedo_color = Color(0.10, 0.06, 0.20)
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
		_shared_player_ring_mat.albedo_color = Color(0.20, 0.95, 1.0)

func _make_toon_mat(col: Color, emission_boost: float = 0.06) -> ShaderMaterial:
	_ensure_shared_materials()
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("base_color", col)
	mat.set_shader_parameter("emission_boost", emission_boost)
	mat.next_pass = _shared_outline_mat
	return mat

func _make_unshaded_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
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

func _build_base_skeleton() -> void:
	for child: Node in get_children():
		child.free()

	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)

	_body_mat = _make_toon_mat(base_color, 0.04)
	var skin_col: Color = Color(0.88, 0.75, 0.65) if fighter_id == 0 else base_color.lightened(0.10)
	_skin_mat = _make_toon_mat(skin_col, 0.02)

	# Ground blob shadow
	_add_box(self, Vector3(1.10, 0.02, 1.10), Vector3(0.0, 0.02, 0.0), _shared_shadow_mat)

	# PLAYER DISTINCT GROUND CURSOR (Unmistakable identity - only on player!)
	if fighter_id == 0:
		player_cursor_ring = Node3D.new()
		player_cursor_ring.name = "PlayerCursorRing"
		player_cursor_ring.position = Vector3(0.0, 0.04, 0.0)
		add_child(player_cursor_ring)

		# Outer glowing ring
		var ring_mi := MeshInstance3D.new()
		var ring_cyl := CylinderMesh.new()
		ring_cyl.top_radius = 1.15
		ring_cyl.bottom_radius = 1.25
		ring_cyl.height = 0.03
		ring_cyl.radial_segments = 24
		ring_mi.mesh = ring_cyl
		ring_mi.material_override = _shared_player_ring_mat
		player_cursor_ring.add_child(ring_mi)

		# Directional pointer arrow extending forward (+Z)
		_add_box(player_cursor_ring, Vector3(0.16, 0.04, 0.55), Vector3(0.0, 0.02, 0.95), _shared_gold_mat)
		_add_box(player_cursor_ring, Vector3(0.38, 0.04, 0.16), Vector3(0.0, 0.02, 1.15), _shared_gold_mat)

	# Abomination Ground Aura Ring (visible to all when fighter is the Abomination)
	abomination_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.35
	cyl.bottom_radius = 1.45
	cyl.height = 0.05
	cyl.radial_segments = 16
	abomination_ring.mesh = cyl
	abomination_ring.position = Vector3(0.0, 0.06, 0.0)
	abomination_ring.material_override = _shared_magenta_mat
	abomination_ring.visible = false
	add_child(abomination_ring)

	var base_s: float = _get_target_base_scale()
	pivot.scale = Vector3.ONE * base_s

	# Torso & Pelvis
	torso_mesh = _add_box(pivot, Vector3(0.82, 0.88, 0.52), Vector3(0.0, 1.05, 0.0), _body_mat)
	_add_box(pivot, Vector3(0.80, 0.28, 0.50), Vector3(0.0, 0.58, 0.0), _shared_dark_mat)

	# Sockets strictly aligned to character axes (+Z = Forward, +Y = Up, +X = Right, -X = Left)
	head_socket = Node3D.new()
	head_socket.name = "HeadSocket"
	head_socket.position = Vector3(0.0, 1.82, 0.0)
	pivot.add_child(head_socket)

	left_arm_socket = Node3D.new()
	left_arm_socket.name = "LeftArmSocket"
	left_arm_socket.position = Vector3(-0.58, 1.25, 0.0)
	pivot.add_child(left_arm_socket)

	right_arm_socket = Node3D.new()
	right_arm_socket.name = "RightArmSocket"
	right_arm_socket.position = Vector3(0.58, 1.25, 0.0)
	pivot.add_child(right_arm_socket)

	left_leg_socket = Node3D.new()
	left_leg_socket.name = "LeftLegSocket"
	left_leg_socket.position = Vector3(-0.24, 0.50, 0.0)
	pivot.add_child(left_leg_socket)

	right_leg_socket = Node3D.new()
	right_leg_socket.name = "RightLegSocket"
	right_leg_socket.position = Vector3(0.24, 0.50, 0.0)
	pivot.add_child(right_leg_socket)

	core_socket = Node3D.new()
	core_socket.name = "CoreSocket"
	core_socket.position = Vector3(0.0, 1.08, 0.28)
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
	_transform_flash_timer = 0.28
	if pivot != null:
		var base_s: float = _get_target_base_scale()
		pivot.scale = Vector3(1.30, 0.75, 1.30) * base_s

func _get_target_base_scale() -> float:
	if fighter_id == 0:
		return 1.35 if is_abomination else 1.08
	return 1.32 if is_abomination else 0.95

func _populate_head_socket(part_id: StringName) -> void:
	_clear_socket(head_socket)
	var head_col: Color = Color(0.88, 0.75, 0.65) if fighter_id == 0 else base_color.lightened(0.08)
	var head_mat: ShaderMaterial = _make_toon_mat(head_col, 0.03)

	# Clean Head Cube
	_add_box(head_socket, Vector3(0.74, 0.74, 0.70), Vector3.ZERO, head_mat)

	# Hair cap / helmet base
	var hair_mat: ShaderMaterial = _shared_dark_mat
	if fighter_id == 0:
		_add_box(head_socket, Vector3(0.76, 0.24, 0.72), Vector3(0.0, 0.28, 0.0), hair_mat)

	match part_id:
		&"laser_eye":
			# Sleek Cyber mono-visor with red laser lens on face (+Z)
			_add_box(head_socket, Vector3(0.48, 0.18, 0.12), Vector3(0.0, 0.06, 0.36), _shared_dark_mat)
			_add_box(head_socket, Vector3(0.24, 0.12, 0.14), Vector3(0.0, 0.06, 0.38), _shared_red_eye_mat)
		&"visor_head":
			# Sleek dark cyber sunglasses with cyan trim on face (+Z)
			_add_box(head_socket, Vector3(0.68, 0.20, 0.10), Vector3(0.0, 0.08, 0.36), _shared_dark_mat)
			_add_box(head_socket, Vector3(0.60, 0.08, 0.12), Vector3(0.0, 0.08, 0.37), _shared_cyan_mat)
		&"spike_helm":
			# Spiked red mohawk crest on top of head
			var crest_mat: ShaderMaterial = _make_toon_mat(Color(0.95, 0.16, 0.24), 0.12)
			_add_box(head_socket, Vector3(0.18, 0.36, 0.65), Vector3(0.0, 0.46, 0.0), crest_mat)
			# Eyes on front
			_add_box(head_socket, Vector3(0.14, 0.12, 0.08), Vector3(-0.16, 0.06, 0.36), _shared_white_mat)
			_add_box(head_socket, Vector3(0.14, 0.12, 0.08), Vector3(0.16, 0.06, 0.36), _shared_white_mat)
		_:
			# Clean expressive brawler eyes on face (+Z)
			_add_box(head_socket, Vector3(0.16, 0.14, 0.08), Vector3(-0.16, 0.06, 0.36), _shared_white_mat)
			_add_box(head_socket, Vector3(0.16, 0.14, 0.08), Vector3(0.16, 0.06, 0.36), _shared_white_mat)
			_add_box(head_socket, Vector3(0.08, 0.08, 0.09), Vector3(-0.16, 0.06, 0.38), _shared_dark_mat)
			_add_box(head_socket, Vector3(0.08, 0.08, 0.09), Vector3(0.16, 0.06, 0.38), _shared_dark_mat)

func _populate_arm_sockets(part_id: StringName) -> void:
	_clear_socket(left_arm_socket)
	_clear_socket(right_arm_socket)

	match part_id:
		&"severed_arms":
			# Severed Arm Stumps: dark mechanical bone sockets with raw sparking ends
			var socket_mat: ShaderMaterial = _shared_dark_mat
			var spark_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.25, 0.20))
			_add_box(left_arm_socket, Vector3(0.24, 0.22, 0.24), Vector3(0.0, -0.09, 0.0), socket_mat)
			_add_box(left_arm_socket, Vector3(0.16, 0.08, 0.16), Vector3(0.0, -0.22, 0.0), spark_mat)
			_add_box(right_arm_socket, Vector3(0.24, 0.22, 0.24), Vector3(0.0, -0.09, 0.0), socket_mat)
			_add_box(right_arm_socket, Vector3(0.16, 0.08, 0.16), Vector3(0.0, -0.22, 0.0), spark_mat)
		&"chainsaw_arm":
			# Left Arm: Muscular brawler fist with dark wristband (matches key-art protagonist!)
			_add_box(left_arm_socket, Vector3(0.36, 0.44, 0.36), Vector3(0.0, -0.18, 0.0), _skin_mat)
			_add_box(left_arm_socket, Vector3(0.42, 0.14, 0.42), Vector3(0.0, -0.38, 0.0), _shared_dark_mat)
			_add_box(left_arm_socket, Vector3(0.52, 0.46, 0.52), Vector3(0.0, -0.60, 0.0), _skin_mat)
			# Right Arm: Mechanical Chainsaw Arm extending forward (+Z)
			var orange_mat: ShaderMaterial = _make_toon_mat(Color(0.98, 0.44, 0.04), 0.08)
			var blade_mat: ShaderMaterial = _make_toon_mat(Color(0.82, 0.85, 0.90), 0.06)
			_add_box(right_arm_socket, Vector3(0.34, 0.45, 0.34), Vector3(0.0, -0.20, 0.0), _shared_dark_mat)
			_add_box(right_arm_socket, Vector3(0.48, 0.48, 0.60), Vector3(0.0, -0.48, 0.14), orange_mat)
			var blade: MeshInstance3D = _add_box(right_arm_socket, Vector3(0.12, 0.34, 1.10), Vector3(0.0, -0.48, 0.78), blade_mat)
			# Clean blade teeth along top and bottom
			for t_i: int in range(3):
				var tz: float = -0.30 + float(t_i) * 0.30
				_add_box(blade, Vector3(0.14, 0.08, 0.10), Vector3(0.0, 0.18, tz), _shared_dark_mat)
				_add_box(blade, Vector3(0.14, 0.08, 0.10), Vector3(0.0, -0.18, tz), _shared_dark_mat)
		&"giant_fist":
			# Heavyweight muscular fists on both sides
			_add_box(left_arm_socket, Vector3(0.38, 0.48, 0.38), Vector3(0.0, -0.20, 0.0), _skin_mat)
			_add_box(left_arm_socket, Vector3(0.58, 0.54, 0.58), Vector3(0.0, -0.56, 0.0), _skin_mat)
			_add_box(right_arm_socket, Vector3(0.38, 0.48, 0.38), Vector3(0.0, -0.20, 0.0), _skin_mat)
			_add_box(right_arm_socket, Vector3(0.58, 0.54, 0.58), Vector3(0.0, -0.56, 0.0), _skin_mat)
		&"mega_claws":
			var claw_mat: ShaderMaterial = _make_toon_mat(Color(1.0, 0.72, 0.14), 0.10)
			_add_box(left_arm_socket, Vector3(0.34, 0.45, 0.34), Vector3(0.0, -0.20, 0.0), _shared_dark_mat)
			_add_box(left_arm_socket, Vector3(0.46, 0.44, 0.46), Vector3(0.0, -0.48, 0.0), claw_mat)
			_add_box(left_arm_socket, Vector3(0.10, 0.45, 0.14), Vector3(-0.12, -0.74, 0.10), _shared_magenta_mat)
			_add_box(left_arm_socket, Vector3(0.10, 0.45, 0.14), Vector3(0.12, -0.74, 0.10), _shared_magenta_mat)
			_add_box(right_arm_socket, Vector3(0.34, 0.45, 0.34), Vector3(0.0, -0.20, 0.0), _shared_dark_mat)
			_add_box(right_arm_socket, Vector3(0.46, 0.44, 0.46), Vector3(0.0, -0.48, 0.0), claw_mat)
			_add_box(right_arm_socket, Vector3(0.10, 0.45, 0.14), Vector3(-0.12, -0.74, 0.10), _shared_magenta_mat)
			_add_box(right_arm_socket, Vector3(0.10, 0.45, 0.14), Vector3(0.12, -0.74, 0.10), _shared_magenta_mat)
		_:
			# Clean base brawler arms
			_add_box(left_arm_socket, Vector3(0.32, 0.48, 0.32), Vector3(0.0, -0.20, 0.0), _body_mat)
			_add_box(left_arm_socket, Vector3(0.44, 0.44, 0.44), Vector3(0.0, -0.52, 0.0), _skin_mat)
			_add_box(right_arm_socket, Vector3(0.32, 0.48, 0.32), Vector3(0.0, -0.20, 0.0), _body_mat)
			_add_box(right_arm_socket, Vector3(0.44, 0.44, 0.44), Vector3(0.0, -0.52, 0.0), _skin_mat)

func _populate_leg_sockets(part_id: StringName) -> void:
	_clear_socket(left_leg_socket)
	_clear_socket(right_leg_socket)
	rocket_flame = null

	match part_id:
		&"severed_legs":
			# Severed Leg Stumps: short mechanical pegs with warning hazard accents
			var peg_mat: ShaderMaterial = _shared_dark_mat
			var warning_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.25, 0.20))
			_add_box(left_leg_socket, Vector3(0.20, 0.20, 0.20), Vector3(0.0, -0.08, 0.0), peg_mat)
			_add_box(left_leg_socket, Vector3(0.14, 0.06, 0.14), Vector3(0.0, -0.19, 0.0), warning_mat)
			_add_box(right_leg_socket, Vector3(0.20, 0.20, 0.20), Vector3(0.0, -0.08, 0.0), peg_mat)
			_add_box(right_leg_socket, Vector3(0.14, 0.06, 0.14), Vector3(0.0, -0.19, 0.0), warning_mat)
		&"rocket_legs":
			var red_mat: ShaderMaterial = _make_toon_mat(Color(0.88, 0.12, 0.16), 0.08)
			var white_mat: ShaderMaterial = _make_toon_mat(Color(0.94, 0.94, 0.98), 0.06)
			# Left thruster boot
			_add_box(left_leg_socket, Vector3(0.42, 0.28, 0.42), Vector3(0.0, -0.14, 0.0), red_mat)
			_add_box(left_leg_socket, Vector3(0.44, 0.24, 0.44), Vector3(0.0, -0.34, 0.0), white_mat)
			_add_box(left_leg_socket, Vector3(0.46, 0.22, 0.46), Vector3(0.0, -0.52, 0.0), red_mat)
			# Right thruster boot with flame
			_add_box(right_leg_socket, Vector3(0.42, 0.28, 0.42), Vector3(0.0, -0.14, 0.0), red_mat)
			_add_box(right_leg_socket, Vector3(0.44, 0.24, 0.44), Vector3(0.0, -0.34, 0.0), white_mat)
			_add_box(right_leg_socket, Vector3(0.46, 0.22, 0.46), Vector3(0.0, -0.52, 0.0), red_mat)
			rocket_flame = _add_box(right_leg_socket, Vector3(0.32, 0.55, 0.32), Vector3(0.0, -0.85, 0.0), _make_unshaded_mat(Color(1.0, 0.58, 0.10)))
			_add_box(right_leg_socket, Vector3(0.18, 0.35, 0.18), Vector3(0.0, -0.75, 0.0), _shared_gold_mat)
		&"spring_legs":
			_add_box(left_leg_socket, Vector3(0.26, 0.28, 0.26), Vector3(0.0, -0.14, 0.0), _shared_cyan_mat)
			_add_box(left_leg_socket, Vector3(0.36, 0.18, 0.42), Vector3(0.0, -0.42, 0.04), _shared_gold_mat)
			_add_box(right_leg_socket, Vector3(0.26, 0.28, 0.26), Vector3(0.0, -0.14, 0.0), _shared_cyan_mat)
			_add_box(right_leg_socket, Vector3(0.36, 0.18, 0.42), Vector3(0.0, -0.42, 0.04), _shared_gold_mat)
		&"roller_wheels":
			_add_box(left_leg_socket, Vector3(0.30, 0.35, 0.32), Vector3(0.0, -0.18, 0.0), _shared_dark_mat)
			_add_box(left_leg_socket, Vector3(0.44, 0.24, 0.48), Vector3(0.0, -0.44, 0.0), _shared_magenta_mat)
			_add_box(right_leg_socket, Vector3(0.30, 0.35, 0.32), Vector3(0.0, -0.18, 0.0), _shared_dark_mat)
			_add_box(right_leg_socket, Vector3(0.44, 0.24, 0.48), Vector3(0.0, -0.44, 0.0), _shared_magenta_mat)
		_:
			# Clean dark combat boots
			_add_box(left_leg_socket, Vector3(0.30, 0.45, 0.34), Vector3(0.0, -0.22, 0.0), _shared_dark_mat)
			_add_box(left_leg_socket, Vector3(0.34, 0.22, 0.44), Vector3(0.0, -0.44, 0.04), _shared_dark_mat)
			_add_box(right_leg_socket, Vector3(0.30, 0.45, 0.34), Vector3(0.0, -0.22, 0.0), _shared_dark_mat)
			_add_box(right_leg_socket, Vector3(0.34, 0.22, 0.44), Vector3(0.0, -0.44, 0.04), _shared_dark_mat)

func _populate_core_socket(part_id: StringName) -> void:
	_clear_socket(core_socket)
	match part_id:
		&"crown_core":
			# Golden Crown Emblem badge on chest
			_add_box(core_socket, Vector3(0.44, 0.22, 0.08), Vector3(0.0, -0.04, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.10, 0.16, 0.09), Vector3(-0.14, 0.10, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.12, 0.20, 0.09), Vector3(0.0, 0.12, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.10, 0.16, 0.09), Vector3(0.14, 0.10, 0.0), _shared_gold_mat)
		&"shield_core":
			_add_box(core_socket, Vector3(0.46, 0.46, 0.10), Vector3.ZERO, _shared_cyan_mat)
			_add_box(core_socket, Vector3(0.26, 0.26, 0.12), Vector3.ZERO, _shared_white_mat)
		&"magnet_core":
			_add_box(core_socket, Vector3(0.46, 0.40, 0.10), Vector3.ZERO, _shared_magenta_mat)
			_add_box(core_socket, Vector3(0.14, 0.20, 0.12), Vector3(-0.14, 0.12, 0.0), _shared_gold_mat)
			_add_box(core_socket, Vector3(0.14, 0.20, 0.12), Vector3(0.14, 0.12, 0.0), _shared_gold_mat)
		_:
			if fighter_id == 0:
				# Crown logo for player
				_add_box(core_socket, Vector3(0.42, 0.20, 0.08), Vector3(0.0, -0.04, 0.0), _shared_gold_mat)
				_add_box(core_socket, Vector3(0.10, 0.14, 0.09), Vector3(-0.12, 0.08, 0.0), _shared_gold_mat)
				_add_box(core_socket, Vector3(0.10, 0.18, 0.09), Vector3(0.0, 0.10, 0.0), _shared_gold_mat)
				_add_box(core_socket, Vector3(0.10, 0.14, 0.09), Vector3(0.12, 0.08, 0.0), _shared_gold_mat)
			else:
				_add_box(core_socket, Vector3(0.32, 0.32, 0.08), Vector3.ZERO, _make_toon_mat(base_color.lightened(0.25), 0.06))

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
		pivot.position.y = 0.72
		pivot.rotation_degrees = Vector3(-24.0, 22.0, 26.0)
		left_arm_socket.rotation_degrees.z = -55.0
		right_arm_socket.rotation_degrees.z = 55.0
		left_leg_socket.rotation_degrees.x = -35.0
		right_leg_socket.rotation_degrees.x = 25.0
		return

	# Reset upright stance
	pivot.rotation_degrees.x = 0.0
	pivot.rotation_degrees.z = 0.0
	left_arm_socket.rotation_degrees.z = 0.0
	right_arm_socket.rotation_degrees.z = 0.0

	# Smooth character rotation to face movement / target direction
	var target_yaw: float = -facing_rad + PI * 0.5
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw, minf(1.0, 16.0 * dt))

	if player_cursor_ring != null:
		player_cursor_ring.rotation.y = pivot.rotation.y

	var speed: float = vel_xz.length()
	var is_moving: bool = speed > 0.15

	if is_moving:
		_walk_phase += (3.2 + speed * 1.6) * dt
		var has_severed_legs: bool = (current_slots.get(PartData.Slot.LEGS) == &"severed_legs")
		var swing_amp: float = 14.0 if has_severed_legs else 28.0
		var swing: float = sin(_walk_phase) * clampf(speed / 6.0, 0.25, 1.0) * swing_amp
		left_leg_socket.rotation_degrees.x = swing
		right_leg_socket.rotation_degrees.x = -swing
		left_arm_socket.rotation_degrees.x = -swing * 0.85
		if attack_timer > 0.0:
			right_arm_socket.rotation_degrees.x = -65.0
		else:
			right_arm_socket.rotation_degrees.x = swing * 0.85
		if has_severed_legs:
			pivot.position.y = -0.15 + absf(sin(_walk_phase)) * 0.06
			pivot.rotation_degrees.z = sin(_walk_phase) * 8.0
		else:
			pivot.position.y = absf(sin(_walk_phase * 2.0)) * 0.08
			pivot.rotation_degrees.z = 0.0
	else:
		# Return smoothly to idle stance
		left_leg_socket.rotation_degrees.x = lerpf(left_leg_socket.rotation_degrees.x, 0.0, minf(1.0, 12.0 * dt))
		right_leg_socket.rotation_degrees.x = lerpf(right_leg_socket.rotation_degrees.x, 0.0, minf(1.0, 12.0 * dt))
		left_arm_socket.rotation_degrees.x = lerpf(left_arm_socket.rotation_degrees.x, 0.0, minf(1.0, 12.0 * dt))
		if attack_timer > 0.0:
			right_arm_socket.rotation_degrees.x = -65.0
		else:
			right_arm_socket.rotation_degrees.x = lerpf(right_arm_socket.rotation_degrees.x, 0.0, minf(1.0, 12.0 * dt))
		pivot.position.y = lerpf(pivot.position.y, 0.0, minf(1.0, 12.0 * dt))

	if rocket_flame != null:
		if is_moving:
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
		pivot.scale = pivot.scale.lerp(Vector3(1.12, 1.18, 1.12) * base_s, minf(1.0, 16.0 * dt))
	elif hurt_timer > 0.0:
		pivot.scale = Vector3(1.18, 0.84, 1.18) * base_s
	else:
		pivot.scale = pivot.scale.lerp(Vector3.ONE * base_s, minf(1.0, 12.0 * dt))
