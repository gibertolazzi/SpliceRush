class_name BlockyFighter3D
extends Node3D

const TOON_SHADER := preload("res://game/shaders/character_toon.gdshader")
const OUTLINE_SHADER := preload("res://game/shaders/character_outline.gdshader")

var fighter_id: int = 0
var is_bot: bool = true
var base_color: Color = Color(0.45, 0.08, 0.78)
var shape_id: int = 0

var pivot: Node3D
var torso_mesh: MeshInstance3D
var head_socket: Node3D
var left_arm_socket: Node3D
var right_arm_socket: Node3D
var left_leg_socket: Node3D
var right_leg_socket: Node3D
var core_socket: Node3D
var laser_beam: MeshInstance3D
var rocket_flame: MeshInstance3D
var bot_indicator_root: Node3D

var _walk_phase: float = 0.0
static var _shared_outline_mat: ShaderMaterial
static var _shared_dark_mat: ShaderMaterial
static var _shared_shadow_mat: StandardMaterial3D

func setup_fighter(id: int, bot: bool, color: Color, a11y_shape: int) -> void:
	fighter_id = id
	is_bot = bot
	base_color = color
	shape_id = a11y_shape
	_walk_phase = float(id) * 0.85
	_build_rig()

func _make_toon_mat(col: Color, emission_boost: float = 0.08, outline_w: float = 0.036) -> ShaderMaterial:
	if _shared_outline_mat == null:
		_shared_outline_mat = ShaderMaterial.new()
		_shared_outline_mat.shader = OUTLINE_SHADER
		_shared_outline_mat.set_shader_parameter("outline_color", Color(0.07, 0.04, 0.14, 1.0))
		_shared_outline_mat.set_shader_parameter("outline_width", outline_w)
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

func _build_rig() -> void:
	for child: Node in get_children():
		child.queue_free()

	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)

	if _shared_dark_mat == null:
		_shared_dark_mat = _make_toon_mat(Color(0.14, 0.13, 0.22), 0.02)
	if _shared_shadow_mat == null:
		_shared_shadow_mat = StandardMaterial3D.new()
		_shared_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_shadow_mat.albedo_color = Color(0.10, 0.06, 0.20)
	var body_mat: ShaderMaterial = _make_toon_mat(base_color, 0.03)
	var dark_mat: ShaderMaterial = _shared_dark_mat

	# Crisp ground blob shadow (replaces expensive directional shadow cascades on mobile/web)
	_add_box(self, Vector3(1.15, 0.03, 1.05), Vector3(0.0, 0.03, 0.0), _shared_shadow_mat)
	var skin_col: Color = Color(0.82, 0.70, 0.62) if fighter_id == 0 else base_color.lightened(0.05)
	var skin_mat: ShaderMaterial = _make_toon_mat(skin_col, 0.02)
	var gold_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.78, 0.15))

	# Protagonist is larger & dynamic in foreground (hero scale)
	var hero_scale: float = 1.18 if fighter_id == 0 else 0.92
	pivot.scale = Vector3.ONE * hero_scale
	if fighter_id == 0:
		pivot.position.y = 0.68
		pivot.rotation_degrees.x = 10.0
		pivot.rotation_degrees.z = -8.0

	# Torso & Pelvis
	torso_mesh = _add_box(pivot, Vector3(0.92, 0.96, 0.62), Vector3(0.0, 1.15, 0.0), body_mat)
	_add_box(pivot, Vector3(0.84, 0.34, 0.56), Vector3(0.0, 0.62, 0.0), dark_mat)

	# Core Socket (Slot 3: Core)
	core_socket = Node3D.new()
	core_socket.name = "CoreSocket"
	core_socket.position = Vector3(0.0, 1.18, 0.0)
	pivot.add_child(core_socket)
	if fighter_id == 0:
		# Golden Crown emblem on front & back of purple shirt so it's visible from camera and front!
		_add_box(core_socket, Vector3(0.46, 0.22, 0.66), Vector3(0.0, -0.04, 0.0), gold_mat)
		_add_box(core_socket, Vector3(0.12, 0.16, 0.67), Vector3(-0.16, 0.12, 0.0), gold_mat)
		_add_box(core_socket, Vector3(0.12, 0.20, 0.67), Vector3(0.0, 0.14, 0.0), gold_mat)
		_add_box(core_socket, Vector3(0.12, 0.16, 0.67), Vector3(0.16, 0.12, 0.0), gold_mat)
	else:
		_add_box(core_socket, Vector3(0.36, 0.36, 0.65), Vector3.ZERO, _make_toon_mat(base_color.lightened(0.20), 0.06))

	# Head Socket (Slot 0: Head)
	head_socket = Node3D.new()
	head_socket.name = "HeadSocket"
	head_socket.position = Vector3(0.0, 1.98, 0.0)
	pivot.add_child(head_socket)
	var head_mat: ShaderMaterial = _make_toon_mat(Color(0.84, 0.76, 0.70) if fighter_id == 0 else base_color.lightened(0.04), 0.03)
	_add_box(head_socket, Vector3(0.84, 0.80, 0.78), Vector3.ZERO, head_mat)

	var eye_red_mat: StandardMaterial3D = _make_unshaded_mat(Color(1.0, 0.18, 0.18))
	if fighter_id == 0 or fighter_id == 4:
		# Laser eye + beam aimed toward screen-right (-X local when yaw ~ 160 deg)
		_add_box(head_socket, Vector3(0.26, 0.22, 0.84), Vector3(-0.16, 0.08, 0.0), eye_red_mat)
		_add_box(head_socket, Vector3(0.36, 0.14, 0.83), Vector3(0.0, -0.20, 0.0), dark_mat)
		laser_beam = MeshInstance3D.new()
		var beam_box := BoxMesh.new()
		beam_box.size = Vector3(3.6, 0.09, 0.09)
		laser_beam.mesh = beam_box
		laser_beam.position = Vector3(-1.95, 0.16, -0.25)
		laser_beam.rotation_degrees = Vector3(0.0, -14.0, -8.0)
		laser_beam.material_override = _make_unshaded_mat(Color(1.0, 0.25, 0.18))
		head_socket.add_child(laser_beam)
	elif fighter_id == 1:
		# Red fighter on left: knocked-out white eye visor with X X eyes & open mouth + flying detached arm!
		_add_box(head_socket, Vector3(0.64, 0.26, 0.84), Vector3(0.0, 0.10, 0.0), _make_unshaded_mat(Color(0.96, 0.96, 0.98)))
		_add_box(head_socket, Vector3(0.18, 0.06, 0.87), Vector3(-0.16, 0.10, 0.0), dark_mat, Vector3(0.0, 0.0, 42.0))
		_add_box(head_socket, Vector3(0.18, 0.06, 0.87), Vector3(-0.16, 0.10, 0.0), dark_mat, Vector3(0.0, 0.0, -42.0))
		_add_box(head_socket, Vector3(0.18, 0.06, 0.87), Vector3(0.16, 0.10, 0.0), dark_mat, Vector3(0.0, 0.0, 42.0))
		_add_box(head_socket, Vector3(0.18, 0.06, 0.87), Vector3(0.16, 0.10, 0.0), dark_mat, Vector3(0.0, 0.0, -42.0))
		_add_box(head_socket, Vector3(0.42, 0.20, 0.85), Vector3(0.0, -0.20, 0.0), dark_mat)
		# Detached flying arm piece next to Red fighter (key art moment!)
		var flying_arm: MeshInstance3D = _add_box(pivot, Vector3(0.75, 0.34, 0.34), Vector3(-1.35, 2.05, 0.15), _make_toon_mat(Color(0.90, 0.84, 0.80), 0.04), Vector3(15.0, -18.0, 32.0))
		_add_box(flying_arm, Vector3(0.24, 0.38, 0.38), Vector3(0.32, 0.0, 0.0), _make_toon_mat(Color(0.42, 0.18, 0.62), 0.04))
	elif fighter_id == 2 or fighter_id == 5:
		# Cool dark visor sunglasses (Blue bot in key art)
		_add_box(head_socket, Vector3(0.90, 0.26, 0.86), Vector3(0.0, 0.10, 0.0), dark_mat)
	elif fighter_id == 3:
		# Green bot with bright red mohawk crest
		var crest_mat: ShaderMaterial = _make_toon_mat(Color(0.95, 0.16, 0.20), 0.08)
		_add_box(head_socket, Vector3(0.22, 0.38, 0.72), Vector3(0.0, 0.52, 0.0), crest_mat)
	else:
		# Bold blocky visor/eyes
		_add_box(head_socket, Vector3(0.62, 0.22, 0.84), Vector3(0.0, 0.08, 0.0), _make_unshaded_mat(Color(0.95, 0.92, 0.88)))
		_add_box(head_socket, Vector3(0.18, 0.14, 0.86), Vector3(-0.16, 0.08, 0.0), dark_mat)
		_add_box(head_socket, Vector3(0.18, 0.14, 0.86), Vector3(0.16, 0.08, 0.0), dark_mat)

	# Arms Sockets (Slot 1: Arms)
	left_arm_socket = Node3D.new()
	left_arm_socket.name = "LeftArmSocket"
	left_arm_socket.position = Vector3(-0.68, 1.38, 0.0)
	pivot.add_child(left_arm_socket)

	right_arm_socket = Node3D.new()
	right_arm_socket.name = "RightArmSocket"
	right_arm_socket.position = Vector3(0.68, 1.38, 0.0)
	pivot.add_child(right_arm_socket)

	if fighter_id == 0:
		# Local +X (right_arm_socket) appears on SCREEN-LEFT when yaw ~ 160 deg: Giant Muscular Arm & Fist!
		_add_box(right_arm_socket, Vector3(0.56, 0.56, 0.54), Vector3(0.26, -0.06, -0.08), skin_mat, Vector3(0.0, 0.0, -18.0))
		_add_box(right_arm_socket, Vector3(0.78, 0.74, 0.74), Vector3(0.62, -0.52, -0.22), skin_mat, Vector3(12.0, 0.0, -14.0))
		# Local -X (left_arm_socket) appears on SCREEN-RIGHT when yaw ~ 160 deg: Orange Chainsaw Arm!
		var orange_mat: ShaderMaterial = _make_toon_mat(Color(0.98, 0.44, 0.04), 0.08)
		var blade_mat: ShaderMaterial = _make_toon_mat(Color(0.74, 0.78, 0.84), 0.06)
		_add_box(left_arm_socket, Vector3(0.46, 0.48, 0.46), Vector3(-0.18, -0.06, 0.0), skin_mat)
		_add_box(left_arm_socket, Vector3(0.62, 0.54, 0.82), Vector3(-0.48, -0.32, -0.18), orange_mat, Vector3(-16.0, 18.0, 22.0))
		var saw_blade: MeshInstance3D = _add_box(left_arm_socket, Vector3(0.18, 0.42, 1.48), Vector3(-0.92, -0.58, -0.62), blade_mat, Vector3(-16.0, 18.0, 22.0))
		for t_idx: int in range(4):
			var tz: float = -0.52 + float(t_idx) * 0.34
			_add_box(saw_blade, Vector3(0.20, 0.10, 0.12), Vector3(0.0, -0.24, tz), dark_mat)
			_add_box(saw_blade, Vector3(0.20, 0.10, 0.12), Vector3(0.0, 0.24, tz), dark_mat)
	else:
		# Oversized chunky arms and fists
		_add_box(left_arm_socket, Vector3(0.38, 0.58, 0.38), Vector3(-0.12, -0.22, 0.0), body_mat)
		_add_box(left_arm_socket, Vector3(0.48, 0.46, 0.48), Vector3(-0.16, -0.58, 0.0), dark_mat)
		_add_box(right_arm_socket, Vector3(0.38, 0.58, 0.38), Vector3(0.12, -0.22, 0.0), body_mat)
		_add_box(right_arm_socket, Vector3(0.48, 0.46, 0.48), Vector3(0.16, -0.58, 0.0), dark_mat)

	# Legs Sockets (Slot 2: Legs)
	left_leg_socket = Node3D.new()
	left_leg_socket.name = "LeftLegSocket"
	left_leg_socket.position = Vector3(-0.28, 0.52, 0.0)
	pivot.add_child(left_leg_socket)

	right_leg_socket = Node3D.new()
	right_leg_socket.name = "RightLegSocket"
	right_leg_socket.position = Vector3(0.28, 0.52, 0.0)
	pivot.add_child(right_leg_socket)

	if fighter_id == 0:
		# Local +X (right_leg_socket) is SCREEN-LEFT: Red & White striped Rocket Thruster Leg + bright flame!
		var red_mat: ShaderMaterial = _make_toon_mat(Color(0.88, 0.12, 0.16), 0.08)
		var white_mat: ShaderMaterial = _make_toon_mat(Color(0.92, 0.92, 0.96), 0.06)
		_add_box(right_leg_socket, Vector3(0.52, 0.34, 0.52), Vector3(0.10, -0.18, -0.12), red_mat, Vector3(22.0, 0.0, -16.0))
		_add_box(right_leg_socket, Vector3(0.54, 0.28, 0.54), Vector3(0.20, -0.44, -0.24), white_mat, Vector3(22.0, 0.0, -16.0))
		_add_box(right_leg_socket, Vector3(0.58, 0.26, 0.58), Vector3(0.28, -0.68, -0.34), red_mat, Vector3(22.0, 0.0, -16.0))
		rocket_flame = _add_box(
			right_leg_socket,
			Vector3(0.46, 0.88, 0.46),
			Vector3(0.42, -1.16, -0.52),
			_make_unshaded_mat(Color(1.0, 0.56, 0.08)),
			Vector3(22.0, 0.0, -16.0)
		)
		_add_box(
			right_leg_socket,
			Vector3(0.26, 0.56, 0.26),
			Vector3(0.38, -1.04, -0.48),
			_make_unshaded_mat(Color(1.0, 0.90, 0.32)),
			Vector3(22.0, 0.0, -16.0)
		)
		# Local -X (left_leg_socket) is SCREEN-RIGHT: Bent dark boot
		_add_box(left_leg_socket, Vector3(0.40, 0.52, 0.44), Vector3(-0.06, -0.26, 0.10), dark_mat, Vector3(-18.0, 0.0, 8.0))
	else:
		_add_box(left_leg_socket, Vector3(0.36, 0.52, 0.42), Vector3(0.0, -0.26, 0.0), dark_mat)
		_add_box(right_leg_socket, Vector3(0.36, 0.52, 0.42), Vector3(0.0, -0.26, 0.0), dark_mat)

	# Bot indicator + Colorblind Shape marker overhead (Rule 5 & Rule 9)
	bot_indicator_root = Node3D.new()
	bot_indicator_root.name = "BotIndicator"
	bot_indicator_root.position = Vector3(0.0, 2.72, 0.0)
	pivot.add_child(bot_indicator_root)
	if is_bot:
		# Small antenna + distinct shape badge so bots are visibly identified without cluttering silhouette
		_add_box(bot_indicator_root, Vector3(0.06, 0.24, 0.06), Vector3(0.0, -0.08, 0.0), dark_mat)
		var badge_rot := Vector3(0.0, 45.0 * float(shape_id), 45.0 if (shape_id % 2 == 1) else 0.0)
		_add_box(bot_indicator_root, Vector3(0.24, 0.24, 0.24), Vector3(0.0, 0.12, 0.0), _make_unshaded_mat(base_color.lightened(0.35)), badge_rot)

func update_visual_state(
	interp_xz: Vector2,
	vel_xz: Vector2,
	facing_rad: float,
	attack_timer: float,
	hurt_timer: float,
	alive: bool,
	dt: float
) -> void:
	visible = alive
	if not alive:
		return
	global_position = Vector3(interp_xz.x, 0.0, interp_xz.y)

	# Convert 2D XZ angle to 3D Y-rotation; keep Player 0 in a 3/4 front-facing brawler stance so silhouette & parts stay 100% readable
	var target_yaw: float = -facing_rad + PI * 0.5
	if fighter_id == 0:
		var strafe_tilt: float = clampf(vel_xz.x / 7.0, -1.0, 1.0)
		var hero_yaw: float = deg_to_rad(158.0 - strafe_tilt * 16.0)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, hero_yaw, minf(1.0, 10.0 * dt))
	else:
		pivot.rotation.y = lerp_angle(pivot.rotation.y, target_yaw, minf(1.0, 12.0 * dt))

	var speed: float = vel_xz.length()
	_walk_phase += (2.5 + speed * 1.4) * dt
	var swing: float = sin(_walk_phase) * clampf(speed / 6.0, 0.15, 1.0) * 26.0

	if fighter_id != 0:
		left_leg_socket.rotation_degrees.x = swing
		right_leg_socket.rotation_degrees.x = -swing
		left_arm_socket.rotation_degrees.x = -swing * 0.9
		right_arm_socket.rotation_degrees.x = swing * 0.9 + (45.0 if attack_timer > 0.0 else 0.0)
		pivot.position.y = absf(sin(_walk_phase * 2.0)) * 0.12
	else:
		# Hero hover & rocket pulse
		pivot.position.y = 0.52 + sin(_walk_phase * 2.0) * 0.08
		if rocket_flame != null:
			var pulse: float = 0.90 + 0.22 * sin(_walk_phase * 5.0)
			rocket_flame.scale = Vector3(pulse, 0.85 + 0.3 * pulse, pulse)
		if attack_timer > 0.0:
			right_arm_socket.rotation_degrees.x = -35.0
		else:
			right_arm_socket.rotation_degrees.x = lerpf(right_arm_socket.rotation_degrees.x, 0.0, minf(1.0, 10.0 * dt))

	if hurt_timer > 0.0:
		pivot.scale = Vector3(1.18, 0.84, 1.18) * (1.28 if fighter_id == 0 else 1.0)
	else:
		var base_s: float = 1.28 if fighter_id == 0 else 1.0
		pivot.scale = pivot.scale.lerp(Vector3.ONE * base_s, minf(1.0, 12.0 * dt))
