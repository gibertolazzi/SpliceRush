class_name BlockyFighter3D
extends Node3D

enum CharacterModelType {
	BLOCKY_HERO,
	STATUSFX_GUY,
	MAN_CUTIE,
	MAN_OFFICER,
	WOMAN_CUTIE,
	WOMAN_OFFICER,
}

const HERO_SCENE := preload("res://Rigged_Blocky_Hero/Meshy_AI_Rigged_Blocky_Hero_20261110_animated_mixamo_Walking.fbx")
const GUY_SCENE := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/shared/guy/guy.glb")
const MAN_CUTIE_SCENE := preload("res://characters/MAN-CUTIE.fbx")
const MAN_OFFICER_SCENE := preload("res://characters/MAN-OFFICER.fbx")
const WOMAN_CUTIE_SCENE := preload("res://characters/WOMAN-CUTIE.fbx")
const WOMAN_OFFICER_SCENE := preload("res://characters/WOMAN-OFFICER.fbx")
const STATUS_SHATTER_VFX := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/StatusFX/effects/status/vfx_status_shatter.tscn")
const STATUS_OVERLAY_RES := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/StatusFX/effects/overlay/shatter_overlay.tres")
const TOON_SHADER := preload("res://game/shaders/character_toon.gdshader")
const OUTLINE_SHADER := preload("res://game/shaders/character_outline.gdshader")

static var default_model_type: CharacterModelType = CharacterModelType.MAN_CUTIE
var character_model_type: CharacterModelType = CharacterModelType.MAN_CUTIE
var status_overlay_mat: ShaderMaterial

static var _cached_mixamo_walk_anim: Animation = null
static var _cached_mixamo_idle_anim: Animation = null
static var _cached_mixamo_attack_anim: Animation = null

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
var face_root: Node3D
var face_eyes_root: Node3D
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

# --- Dismemberment visuals: stump sockets, grafted limbs and the limb held as a club ---
const LIMB_KEYS: Array[StringName] = [&"arm_l", &"arm_r", &"leg_l", &"leg_r"]
const SHATTER_VFX_SCALE: float = 0.42
const MIXAMO_OVERLAY_OFFSET: float = 0.00012
const CLUB_SWING_SEC: float = 0.30
const CLUB_HOLD_DIR := Vector3(-0.38, 0.86, 0.34)
const CLUB_WINDUP_DIR := Vector3(-0.25, 0.92, -0.55)
const CLUB_SLAM_DIR := Vector3(0.12, -0.12, 1.0)
const CLUB_LENGTH_SCALE: float = 1.35
const GRAFT_ARM_LENGTH_SCALE: float = 1.15 # Foreign arms are a touch too long: reads as "not mine"
const GRAFT_LEG_LENGTH_SCALE: float = 1.0  # Legs match so both feet reach the floor

var limb_extra_roots: Dictionary = {} # StringName -> Node3D placed on the real joint
var held_limb_node: Node3D
var held_limb_slot: int = -1
var _grafts: Dictionary = {} # StringName -> {"scene": PackedScene, "tint": Color, "tint_amount": float}
var _held_info: Dictionary = {}
var _graft_nodes: Dictionary = {} # StringName -> Node3D
var _hand_attach_r: BoneAttachment3D
var _hand_attach_l: BoneAttachment3D
var _skel_to_pivot := Transform3D.IDENTITY
var _skel_to_pivot_rot := Basis.IDENTITY
var _club_dir := CLUB_HOLD_DIR
var _club_side: float = 1.0
var _bonk_squash_timer: float = 0.0
var _collapsed_bones: Dictionary = {} # bone index -> collapsed pose scale
var _overlay_meshes: Array[MeshInstance3D] = []

static var _shared_outline_mat: ShaderMaterial
static var _shared_dark_mat: ShaderMaterial
static var _shared_shadow_mat: StandardMaterial3D
static var _shared_gold_mat: StandardMaterial3D
static var _shared_white_mat: StandardMaterial3D
static var _shared_red_eye_mat: StandardMaterial3D
static var _shared_magenta_mat: StandardMaterial3D
static var _shared_cyan_mat: StandardMaterial3D
static var _shared_player_ring_mat: StandardMaterial3D
static var _shared_mixamo_outline_mat: ShaderMaterial

func _exit_tree() -> void:
	if char_mesh != null:
		char_mesh.material_overlay = null
	for o_mesh: MeshInstance3D in _overlay_meshes:
		if is_instance_valid(o_mesh):
			o_mesh.material_overlay = null

func _is_mixamo_collection_model() -> bool:
	return character_model_type in [
		CharacterModelType.MAN_CUTIE,
		CharacterModelType.MAN_OFFICER,
		CharacterModelType.WOMAN_CUTIE,
		CharacterModelType.WOMAN_OFFICER
	]

## Which character model a fighter id gets when none is forced.
static func model_type_for_fighter_id(id: int) -> CharacterModelType:
	if default_model_type in [CharacterModelType.BLOCKY_HERO, CharacterModelType.STATUSFX_GUY]:
		return default_model_type
	if id == 0:
		return default_model_type
	var bot_models: Array[CharacterModelType] = [
		CharacterModelType.MAN_CUTIE,
		CharacterModelType.MAN_OFFICER,
		CharacterModelType.WOMAN_CUTIE,
		CharacterModelType.WOMAN_OFFICER,
	]
	return bot_models[id % bot_models.size()]

static func scene_for_model_type(model_type: int) -> PackedScene:
	match model_type:
		CharacterModelType.BLOCKY_HERO:
			return HERO_SCENE
		CharacterModelType.STATUSFX_GUY:
			return GUY_SCENE
		CharacterModelType.MAN_OFFICER:
			return MAN_OFFICER_SCENE
		CharacterModelType.WOMAN_CUTIE:
			return WOMAN_CUTIE_SCENE
		CharacterModelType.WOMAN_OFFICER:
			return WOMAN_OFFICER_SCENE
	return MAN_CUTIE_SCENE

func get_model_scene() -> PackedScene:
	return scene_for_model_type(character_model_type)

## How this fighter's loose limbs are coloured: bots wear their flat team colour, the player keeps the outfit.
func get_limb_tint_amount() -> float:
	return 0.0 if fighter_id == 0 else 1.0

func setup_fighter(id: int, bot: bool, color: Color, a11y_shape: int, initial_slots: Dictionary = {}, abom: bool = false, model_type: int = -1) -> void:
	fighter_id = id
	is_bot = bot
	base_color = color
	shape_id = a11y_shape
	is_abomination = abom
	if model_type >= 0:
		character_model_type = model_type as CharacterModelType
	else:
		character_model_type = model_type_for_fighter_id(id)
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
		_shared_outline_mat.set_shader_parameter("outline_color", Color(0.08, 0.04, 0.14, 1.0))
		_shared_outline_mat.set_shader_parameter("outline_width", 0.024)
	if _shared_mixamo_outline_mat == null:
		_shared_mixamo_outline_mat = ShaderMaterial.new()
		_shared_mixamo_outline_mat.shader = OUTLINE_SHADER
		_shared_mixamo_outline_mat.set_shader_parameter("outline_color", Color(0.08, 0.04, 0.14, 1.0))
		_shared_mixamo_outline_mat.set_shader_parameter("outline_width", 0.0001)
	if _shared_dark_mat == null:
		_shared_dark_mat = ShaderMaterial.new()
		_shared_dark_mat.shader = TOON_SHADER
		_shared_dark_mat.set_shader_parameter("use_texture", false)
		_shared_dark_mat.set_shader_parameter("base_color", Color(0.14, 0.13, 0.22))
		_shared_dark_mat.set_shader_parameter("emission_boost", 0.02)
		_shared_dark_mat.set_shader_parameter("rim_color", Color(0.88, 0.72, 1.0))
		_shared_dark_mat.set_shader_parameter("rim_power", 2.4)
		_shared_dark_mat.set_shader_parameter("rim_strength", 0.35)
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
	mat.set_shader_parameter("use_texture", false)
	mat.set_shader_parameter("base_color", col)
	mat.set_shader_parameter("emission_boost", emission_boost)
	mat.set_shader_parameter("rim_color", Color(0.92, 0.78, 1.0))
	mat.set_shader_parameter("rim_power", 2.2)
	mat.set_shader_parameter("rim_strength", 0.45)
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
		if s.is_equal_approx(Vector3.ONE):
			_collapsed_bones.erase(bone_idx)
		else:
			_collapsed_bones[bone_idx] = s

## Skeleton3D ignores pose changes made while it is outside the tree, and an idle fighter has
## no animation track on its legs to refresh them. Re-applying the collapse every frame keeps
## hidden limbs hidden however and whenever the fighter was set up.
func _reassert_collapsed_bones() -> void:
	if skeleton == null:
		return
	for bone_idx: Variant in _collapsed_bones.keys():
		var s: Vector3 = _collapsed_bones[bone_idx] as Vector3
		skeleton.set_bone_pose_scale(int(bone_idx), s * 1.01)
		skeleton.set_bone_pose_scale(int(bone_idx), s)

func play_shatter_vfx(local_pos: Vector3) -> void:
	if STATUS_SHATTER_VFX == null or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var vfx: Node3D = STATUS_SHATTER_VFX.instantiate() as Node3D
	vfx.position = local_pos
	# The StatusFX burst is authored for a much larger scene; at full size it hides the fight.
	vfx.scale = Vector3.ONE * SHATTER_VFX_SCALE
	pivot.add_child(vfx)
	var ap: AnimationPlayer = vfx.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and ap.has_animation("open"):
		ap.play("open")
	var t: SceneTreeTimer = tree.create_timer(0.75, true, false, true)
	t.timeout.connect(func() -> void:
		if is_instance_valid(vfx):
			vfx.queue_free()
	)

func _build_guy_walk_animation() -> void:
	if anim_player == null or skeleton == null:
		return
	var lib: AnimationLibrary = anim_player.get_animation_library("")
	if lib == null or lib.has_animation(&"Walk"):
		return

	var walk_anim := Animation.new()
	walk_anim.resource_name = "Walk"
	walk_anim.length = 0.8
	walk_anim.loop_mode = Animation.LOOP_LINEAR

	var bone_names: Array[String] = [
		"DEF-thigh.L", "DEF-shin.L", "DEF-thigh.R", "DEF-shin.R",
		"DEF-upper_arm.L", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R",
		"DEF-spine", "DEF-spine.002"
	]

	var base_rots: Dictionary = {}
	var track_map: Dictionary = {}
	for b: String in bone_names:
		var b_idx: int = skeleton.find_bone(b)
		if b_idx >= 0:
			base_rots[b] = skeleton.get_bone_rest(b_idx).basis.get_rotation_quaternion()
			var t_idx: int = walk_anim.add_track(Animation.TYPE_ROTATION_3D)
			walk_anim.track_set_path(t_idx, "rig/Skeleton3D:" + b)
			track_map[b] = t_idx

	var times: Array[float] = [0.0, 0.2, 0.4, 0.6, 0.8]
	for step: int in range(5):
		var t: float = times[step]
		var phase: float = float(step) * (PI * 0.5)

		var leg_l_pitch: float = sin(phase) * 0.45
		var leg_r_pitch: float = -sin(phase) * 0.45
		var knee_l_bend: float = maxf(0.0, -sin(phase)) * 0.65
		var knee_r_bend: float = maxf(0.0, sin(phase)) * 0.65

		var arm_l_pitch: float = -sin(phase) * 0.38
		var arm_r_pitch: float = sin(phase) * 0.38
		var elbow_l_bend: float = 0.25 + maxf(0.0, -sin(phase)) * 0.22
		var elbow_r_bend: float = 0.25 + maxf(0.0, sin(phase)) * 0.22

		var spine_twist: float = sin(phase) * 0.08

		if track_map.has("DEF-thigh.L"):
			var q: Quaternion = (base_rots["DEF-thigh.L"] as Quaternion) * Quaternion(Vector3.RIGHT, leg_l_pitch)
			walk_anim.rotation_track_insert_key(track_map["DEF-thigh.L"], t, q)
		if track_map.has("DEF-thigh.R"):
			var q: Quaternion = (base_rots["DEF-thigh.R"] as Quaternion) * Quaternion(Vector3.RIGHT, leg_r_pitch)
			walk_anim.rotation_track_insert_key(track_map["DEF-thigh.R"], t, q)
		if track_map.has("DEF-shin.L"):
			var q: Quaternion = (base_rots["DEF-shin.L"] as Quaternion) * Quaternion(Vector3.RIGHT, knee_l_bend)
			walk_anim.rotation_track_insert_key(track_map["DEF-shin.L"], t, q)
		if track_map.has("DEF-shin.R"):
			var q: Quaternion = (base_rots["DEF-shin.R"] as Quaternion) * Quaternion(Vector3.RIGHT, knee_r_bend)
			walk_anim.rotation_track_insert_key(track_map["DEF-shin.R"], t, q)
		if track_map.has("DEF-upper_arm.L"):
			var q: Quaternion = (base_rots["DEF-upper_arm.L"] as Quaternion) * Quaternion(Vector3.RIGHT, arm_l_pitch)
			walk_anim.rotation_track_insert_key(track_map["DEF-upper_arm.L"], t, q)
		if track_map.has("DEF-upper_arm.R"):
			var q: Quaternion = (base_rots["DEF-upper_arm.R"] as Quaternion) * Quaternion(Vector3.RIGHT, arm_r_pitch)
			walk_anim.rotation_track_insert_key(track_map["DEF-upper_arm.R"], t, q)
		if track_map.has("DEF-forearm.L"):
			var q: Quaternion = (base_rots["DEF-forearm.L"] as Quaternion) * Quaternion(Vector3.RIGHT, elbow_l_bend)
			walk_anim.rotation_track_insert_key(track_map["DEF-forearm.L"], t, q)
		if track_map.has("DEF-forearm.R"):
			var q: Quaternion = (base_rots["DEF-forearm.R"] as Quaternion) * Quaternion(Vector3.RIGHT, elbow_r_bend)
			walk_anim.rotation_track_insert_key(track_map["DEF-forearm.R"], t, q)
		if track_map.has("DEF-spine"):
			var q: Quaternion = (base_rots["DEF-spine"] as Quaternion) * Quaternion(Vector3.UP, spine_twist)
			walk_anim.rotation_track_insert_key(track_map["DEF-spine"], t, q)
		if track_map.has("DEF-spine.002"):
			var q: Quaternion = (base_rots["DEF-spine.002"] as Quaternion) * Quaternion(Vector3.UP, -spine_twist * 0.5)
			walk_anim.rotation_track_insert_key(track_map["DEF-spine.002"], t, q)

	lib.add_animation(&"Walk", walk_anim)

static func _get_or_build_mixamo_walk_anim() -> Animation:
	if _cached_mixamo_walk_anim != null:
		return _cached_mixamo_walk_anim

	var hero_scene: PackedScene = HERO_SCENE
	var temp_hero: Node = hero_scene.instantiate()
	var temp_ap: AnimationPlayer = temp_hero.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var orig_anim: Animation = null
	if temp_ap != null:
		var lib: AnimationLibrary = temp_ap.get_animation_library("")
		for a_name: StringName in lib.get_animation_list():
			orig_anim = lib.get_animation(a_name)
			break

	if orig_anim == null:
		temp_hero.free()
		return null

	var bone_map: Dictionary = {
		"Hips": "mixamorig_Hips",
		"Spine": "mixamorig_Spine",
		"Spine01": "mixamorig_Spine1",
		"Spine02": "mixamorig_Spine2",
		"neck": "mixamorig_Neck",
		"Head": "mixamorig_Head",
		"headfront": "mixamorig_HeadTop_End",
		"LeftShoulder": "mixamorig_LeftShoulder",
		"LeftArm": "mixamorig_LeftArm",
		"LeftForeArm": "mixamorig_LeftForeArm",
		"LeftHand": "mixamorig_LeftHand",
		"RightShoulder": "mixamorig_RightShoulder",
		"RightArm": "mixamorig_RightArm",
		"RightForeArm": "mixamorig_RightForeArm",
		"RightHand": "mixamorig_RightHand",
		"LeftUpLeg": "mixamorig_LeftUpLeg",
		"LeftLeg": "mixamorig_LeftLeg",
		"LeftFoot": "mixamorig_LeftFoot",
		"LeftToeBase": "mixamorig_LeftToeBase",
		"RightUpLeg": "mixamorig_RightUpLeg",
		"RightLeg": "mixamorig_RightLeg",
		"RightFoot": "mixamorig_RightFoot",
		"RightToeBase": "mixamorig_RightToeBase",
	}

	var walk_anim := Animation.new()
	walk_anim.resource_name = "Walk"
	walk_anim.length = orig_anim.length
	walk_anim.loop_mode = Animation.LOOP_LINEAR

	for t: int in range(orig_anim.get_track_count()):
		var track_type: int = orig_anim.track_get_type(t)
		# Only retarget 3D rotation tracks: preserves target skeleton rest proportions and prevents position explosion
		if track_type != Animation.TYPE_ROTATION_3D:
			continue
		var subname: String = orig_anim.track_get_path(t).get_subname(0)
		var target_bone: String = bone_map.get(subname, "mixamorig_" + subname) as String
		var new_t_idx: int = walk_anim.add_track(Animation.TYPE_ROTATION_3D)
		walk_anim.track_set_path(new_t_idx, NodePath(".:" + target_bone))
		walk_anim.track_set_interpolation_type(new_t_idx, orig_anim.track_get_interpolation_type(t))
		var key_count: int = orig_anim.track_get_key_count(t)
		for k: int in range(key_count):
			walk_anim.track_insert_key(new_t_idx, orig_anim.track_get_key_time(t, k), orig_anim.track_get_key_value(t, k), orig_anim.track_get_key_transition(t, k))

	temp_hero.free()
	_cached_mixamo_walk_anim = walk_anim
	return _cached_mixamo_walk_anim

static func _get_or_build_mixamo_idle_anim(sk: Skeleton3D) -> Animation:
	if _cached_mixamo_idle_anim != null:
		return _cached_mixamo_idle_anim

	var idle_anim := Animation.new()
	idle_anim.resource_name = "Idle"
	idle_anim.length = 1.6
	idle_anim.loop_mode = Animation.LOOP_LINEAR

	var b_spine: int = sk.find_bone("mixamorig_Spine")
	var base_spine_q: Quaternion = sk.get_bone_rest(b_spine).basis.get_rotation_quaternion() if b_spine >= 0 else Quaternion.IDENTITY
	var t_spine: int = idle_anim.add_track(Animation.TYPE_ROTATION_3D)
	idle_anim.track_set_path(t_spine, NodePath(".:mixamorig_Spine"))

	var b_arm_l: int = sk.find_bone("mixamorig_LeftArm")
	var base_arm_l_q: Quaternion = sk.get_bone_rest(b_arm_l).basis.get_rotation_quaternion() if b_arm_l >= 0 else Quaternion.IDENTITY
	var t_arm_l: int = idle_anim.add_track(Animation.TYPE_ROTATION_3D)
	idle_anim.track_set_path(t_arm_l, NodePath(".:mixamorig_LeftArm"))

	var b_arm_r: int = sk.find_bone("mixamorig_RightArm")
	var base_arm_r_q: Quaternion = sk.get_bone_rest(b_arm_r).basis.get_rotation_quaternion() if b_arm_r >= 0 else Quaternion.IDENTITY
	var t_arm_r: int = idle_anim.add_track(Animation.TYPE_ROTATION_3D)
	idle_anim.track_set_path(t_arm_r, NodePath(".:mixamorig_RightArm"))

	for step: int in range(5):
		var time: float = float(step) * 0.4
		var phase: float = float(step) * (PI * 0.5)
		var q_s: Quaternion = base_spine_q * Quaternion(Vector3.RIGHT, sin(phase) * 0.035)
		idle_anim.rotation_track_insert_key(t_spine, time, q_s)
		var q_al: Quaternion = base_arm_l_q * Quaternion(Vector3.FORWARD, sin(phase) * 0.02)
		idle_anim.rotation_track_insert_key(t_arm_l, time, q_al)
		var q_ar: Quaternion = base_arm_r_q * Quaternion(Vector3.FORWARD, -sin(phase) * 0.02)
		idle_anim.rotation_track_insert_key(t_arm_r, time, q_ar)

	_cached_mixamo_idle_anim = idle_anim
	return _cached_mixamo_idle_anim

static func _get_or_build_mixamo_attack_anim(sk: Skeleton3D) -> Animation:
	if _cached_mixamo_attack_anim != null:
		return _cached_mixamo_attack_anim

	var atk_anim := Animation.new()
	atk_anim.resource_name = "Attack"
	atk_anim.length = 0.32
	atk_anim.loop_mode = Animation.LOOP_NONE

	var b_arm: int = sk.find_bone("mixamorig_RightArm")
	var base_arm_q: Quaternion = sk.get_bone_rest(b_arm).basis.get_rotation_quaternion() if b_arm >= 0 else Quaternion.IDENTITY
	var t_arm: int = atk_anim.add_track(Animation.TYPE_ROTATION_3D)
	atk_anim.track_set_path(t_arm, NodePath(".:mixamorig_RightArm"))

	var b_spine: int = sk.find_bone("mixamorig_Spine1")
	var base_spine_q: Quaternion = sk.get_bone_rest(b_spine).basis.get_rotation_quaternion() if b_spine >= 0 else Quaternion.IDENTITY
	var t_spine: int = atk_anim.add_track(Animation.TYPE_ROTATION_3D)
	atk_anim.track_set_path(t_spine, NodePath(".:mixamorig_Spine1"))

	atk_anim.rotation_track_insert_key(t_arm, 0.0, base_arm_q)
	atk_anim.rotation_track_insert_key(t_arm, 0.12, base_arm_q * Quaternion(Vector3.RIGHT, -0.65) * Quaternion(Vector3.UP, 0.30))
	atk_anim.rotation_track_insert_key(t_arm, 0.32, base_arm_q)

	atk_anim.rotation_track_insert_key(t_spine, 0.0, base_spine_q)
	atk_anim.rotation_track_insert_key(t_spine, 0.12, base_spine_q * Quaternion(Vector3.UP, 0.18))
	atk_anim.rotation_track_insert_key(t_spine, 0.32, base_spine_q)

	_cached_mixamo_attack_anim = atk_anim
	return _cached_mixamo_attack_anim

func _build_base_skeleton() -> void:
	for child: Node in get_children():
		child.free()

	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	limb_extra_roots.clear()
	_overlay_meshes.clear()
	_collapsed_bones.clear()
	_graft_nodes.clear()
	_grafts.clear()
	_held_info.clear()
	held_limb_node = null
	held_limb_slot = -1
	_hand_attach_r = null
	_hand_attach_l = null

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

	# Thin white ground ring under the player's own fighter (key art): finds you in the brawl at a glance.
	player_cursor_ring = null
	if fighter_id == 0:
		var cursor_mi := MeshInstance3D.new()
		cursor_mi.name = "PlayerGroundRing"
		var cursor_torus := TorusMesh.new()
		cursor_torus.inner_radius = 0.92
		cursor_torus.outer_radius = 0.98
		cursor_torus.rings = 28
		cursor_torus.ring_segments = 4
		cursor_mi.mesh = cursor_torus
		cursor_mi.position = Vector3(0.0, 0.05, 0.0)
		cursor_mi.material_override = _shared_white_mat
		add_child(cursor_mi)
		player_cursor_ring = cursor_mi

	var base_s: float = _get_target_base_scale()
	pivot.scale = Vector3.ONE * base_s

	var is_guy: bool = (character_model_type == CharacterModelType.STATUSFX_GUY)
	var is_mixamo_coll: bool = _is_mixamo_collection_model()
	if is_mixamo_coll:
		match character_model_type:
			CharacterModelType.MAN_CUTIE:
				hero_instance = MAN_CUTIE_SCENE.instantiate() as Node3D
				hero_instance.name = "ManCutieModel"
			CharacterModelType.MAN_OFFICER:
				hero_instance = MAN_OFFICER_SCENE.instantiate() as Node3D
				hero_instance.name = "ManOfficerModel"
			CharacterModelType.WOMAN_CUTIE:
				hero_instance = WOMAN_CUTIE_SCENE.instantiate() as Node3D
				hero_instance.name = "WomanCutieModel"
			CharacterModelType.WOMAN_OFFICER:
				hero_instance = WOMAN_OFFICER_SCENE.instantiate() as Node3D
				hero_instance.name = "WomanOfficerModel"
			_:
				hero_instance = MAN_CUTIE_SCENE.instantiate() as Node3D
				hero_instance.name = "ManCutieModel"

		hero_instance.scale = Vector3.ONE * 2.75
		pivot.add_child(hero_instance)

		skeleton = hero_instance.find_child("Skeleton3D", true, false) as Skeleton3D
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		hero_instance.add_child(anim_player)
		if skeleton != null:
			anim_player.root_node = anim_player.get_path_to(skeleton)

		var lib := AnimationLibrary.new()
		var walk_a: Animation = _get_or_build_mixamo_walk_anim()
		if walk_a != null:
			lib.add_animation(&"Walk", walk_a)
		if skeleton != null:
			var idle_a: Animation = _get_or_build_mixamo_idle_anim(skeleton)
			if idle_a != null:
				lib.add_animation(&"Idle", idle_a)
			var atk_a: Animation = _get_or_build_mixamo_attack_anim(skeleton)
			if atk_a != null:
				lib.add_animation(&"Attack", atk_a)
		anim_player.add_animation_library("", lib)
		anim_player.play(&"Idle")

		for c_child: Node in skeleton.get_children():
			if c_child is MeshInstance3D:
				char_mesh = c_child as MeshInstance3D
				break
	elif is_guy:
		hero_instance = GUY_SCENE.instantiate() as Node3D
		hero_instance.name = "GuyModel"
		pivot.add_child(hero_instance)

		skeleton = hero_instance.find_child("Skeleton3D", true, false) as Skeleton3D
		anim_player = hero_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		char_mesh = hero_instance.find_child("Chest", true, false) as MeshInstance3D
		_build_guy_walk_animation()
	else:
		# Instantiate the authentic Rigged Blocky Hero FBX model
		hero_instance = HERO_SCENE.instantiate() as Node3D
		hero_instance.name = "HeroModel"
		pivot.add_child(hero_instance)

		skeleton = hero_instance.find_child("Skeleton3D", true, false) as Skeleton3D
		anim_player = hero_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		char_mesh = hero_instance.find_child("char1", true, false) as MeshInstance3D

	# Apply Toon Shader with texture, skin warmth boost, rim light, and dark outline (Point 9)
	if is_mixamo_coll:
		if skeleton != null:
			for c_child: Node in skeleton.get_children():
				if c_child is MeshInstance3D:
					var mi: MeshInstance3D = c_child as MeshInstance3D
					if mi.mesh != null:
						for s_i: int in range(mi.mesh.get_surface_count()):
							var orig_m: Material = mi.mesh.surface_get_material(s_i)
							var orig_c: Color = (orig_m as StandardMaterial3D).albedo_color if orig_m is StandardMaterial3D else Color.WHITE
							var m_name: String = orig_m.resource_name if orig_m != null else ""
							var is_eye: bool = m_name.find("EYE") != -1
							var is_skin: bool = m_name.find("Material.038") != -1 or m_name.find("Material.064") != -1 or m_name.find("Material.326") != -1
							var toon_m := ShaderMaterial.new()
							toon_m.shader = TOON_SHADER
							toon_m.set_shader_parameter("use_texture", false)
							if is_eye:
								toon_m.set_shader_parameter("base_color", Color(0.04, 0.04, 0.04))
							elif is_skin:
								toon_m.set_shader_parameter("base_color", orig_c)
								toon_m.set_shader_parameter("skin_warmth_boost", 0.55)
							else:
								var col: Color = orig_c if fighter_id == 0 else base_color
								toon_m.set_shader_parameter("base_color", col)
							toon_m.set_shader_parameter("rim_color", Color(0.92, 0.82, 1.0))
							toon_m.set_shader_parameter("rim_power", 2.2)
							toon_m.set_shader_parameter("rim_strength", 0.45)
							toon_m.next_pass = _shared_mixamo_outline_mat
							mi.set_surface_override_material(s_i, toon_m)

		if STATUS_OVERLAY_RES != null and char_mesh != null and skeleton != null:
			status_overlay_mat = STATUS_OVERLAY_RES.duplicate() as ShaderMaterial
			status_overlay_mat.set_shader_parameter("effect_amount", 0.0)
			# The overlay pushes vertices out along the normal in mesh units. These rigs are
			# authored 100x smaller than the scene, so the stock offset ballooned the hit flash
			# into a screen-filling blob. Rescale it and flash the whole body, not one sub-mesh.
			status_overlay_mat.set_shader_parameter("offset", MIXAMO_OVERLAY_OFFSET)
			for o_child: Node in skeleton.get_children():
				if o_child is MeshInstance3D:
					(o_child as MeshInstance3D).material_overlay = status_overlay_mat
					_overlay_meshes.append(o_child as MeshInstance3D)
	elif char_mesh != null and char_mesh.mesh != null and char_mesh.mesh.get_surface_count() > 0:
		if is_guy:
			var guy_skin_mat := ShaderMaterial.new()
			guy_skin_mat.shader = TOON_SHADER
			guy_skin_mat.set_shader_parameter("use_texture", false)
			guy_skin_mat.set_shader_parameter("base_color", Color(0.98, 0.84, 0.74))
			guy_skin_mat.set_shader_parameter("rim_color", Color(0.92, 0.80, 1.0))
			guy_skin_mat.set_shader_parameter("rim_power", 2.2)
			guy_skin_mat.set_shader_parameter("rim_strength", 0.45)
			guy_skin_mat.set_shader_parameter("emission_boost", 0.05)
			guy_skin_mat.set_shader_parameter("skin_warmth_boost", 0.55)
			guy_skin_mat.next_pass = _shared_outline_mat
			char_mesh.set_surface_override_material(0, guy_skin_mat)

			if char_mesh.mesh.get_surface_count() > 1:
				var guy_suit_mat := ShaderMaterial.new()
				guy_suit_mat.shader = TOON_SHADER
				guy_suit_mat.set_shader_parameter("use_texture", false)
				var suit_color: Color = Color(0.50, 0.12, 0.88) if fighter_id == 0 else base_color
				guy_suit_mat.set_shader_parameter("base_color", suit_color)
				guy_suit_mat.set_shader_parameter("rim_color", Color(0.95, 0.82, 1.0))
				guy_suit_mat.set_shader_parameter("rim_power", 2.2)
				guy_suit_mat.set_shader_parameter("rim_strength", 0.48)
				guy_suit_mat.set_shader_parameter("emission_boost", 0.06)
				guy_suit_mat.next_pass = _shared_outline_mat
				char_mesh.set_surface_override_material(1, guy_suit_mat)
		else:
			var orig_mat = char_mesh.mesh.surface_get_material(0)
			var orig_tex: Texture2D = null
			if orig_mat is StandardMaterial3D and orig_mat.albedo_texture != null:
				orig_tex = orig_mat.albedo_texture
			elif orig_mat != null and orig_mat.get("albedo_texture") != null:
				orig_tex = orig_mat.get("albedo_texture") as Texture2D

			var hero_toon_mat := ShaderMaterial.new()
			hero_toon_mat.shader = TOON_SHADER
			hero_toon_mat.set_shader_parameter("use_texture", orig_tex != null)
			if orig_tex != null:
				hero_toon_mat.set_shader_parameter("albedo_texture", orig_tex)
			hero_toon_mat.set_shader_parameter("base_color", Color.WHITE if fighter_id == 0 else base_color)
			hero_toon_mat.set_shader_parameter("rim_color", Color(0.88, 0.72, 1.0))
			hero_toon_mat.set_shader_parameter("rim_power", 2.2)
			hero_toon_mat.set_shader_parameter("rim_strength", 0.48)
			hero_toon_mat.set_shader_parameter("emission_boost", 0.05)
			hero_toon_mat.set_shader_parameter("skin_warmth_boost", 0.55)
			hero_toon_mat.set_shader_parameter("skin_tint", Color(1.15, 0.88, 0.76))
			hero_toon_mat.set_shader_parameter("purple_shift", 1.0 if fighter_id == 0 else 0.0)
			hero_toon_mat.next_pass = _shared_outline_mat
			char_mesh.set_surface_override_material(0, hero_toon_mat)
			for s_idx in range(1, char_mesh.mesh.get_surface_count()):
				char_mesh.set_surface_override_material(s_idx, hero_toon_mat)

		# Attach StatusFX Shatter Overlay as material_overlay
		if STATUS_OVERLAY_RES != null:
			status_overlay_mat = STATUS_OVERLAY_RES.duplicate() as ShaderMaterial
			status_overlay_mat.set_shader_parameter("effect_amount", 0.0)
			char_mesh.material_overlay = status_overlay_mat

	if skeleton != null:
		if is_guy:
			_bone_head = skeleton.find_bone("head")
			_bone_left_arm = skeleton.find_bone("DEF-upper_arm.L")
			_bone_right_arm = skeleton.find_bone("DEF-upper_arm.R")
			_bone_left_forearm = skeleton.find_bone("DEF-forearm.L")
			_bone_right_forearm = skeleton.find_bone("DEF-forearm.R")
			_bone_left_hand = skeleton.find_bone("DEF-hand.L")
			_bone_right_hand = skeleton.find_bone("DEF-hand.R")
			_bone_left_upleg = skeleton.find_bone("DEF-thigh.L")
			_bone_right_upleg = skeleton.find_bone("DEF-thigh.R")
			_bone_left_leg = skeleton.find_bone("DEF-shin.L")
			_bone_right_leg = skeleton.find_bone("DEF-shin.R")
			_bone_left_foot = skeleton.find_bone("DEF-foot.L")
			_bone_right_foot = skeleton.find_bone("DEF-foot.R")
		elif is_mixamo_coll:
			_bone_head = skeleton.find_bone("mixamorig_Head")
			_bone_left_arm = skeleton.find_bone("mixamorig_LeftArm")
			_bone_right_arm = skeleton.find_bone("mixamorig_RightArm")
			_bone_left_forearm = skeleton.find_bone("mixamorig_LeftForeArm")
			_bone_right_forearm = skeleton.find_bone("mixamorig_RightForeArm")
			_bone_left_hand = skeleton.find_bone("mixamorig_LeftHand")
			_bone_right_hand = skeleton.find_bone("mixamorig_RightHand")
			_bone_left_upleg = skeleton.find_bone("mixamorig_LeftUpLeg")
			_bone_right_upleg = skeleton.find_bone("mixamorig_RightUpLeg")
			_bone_left_leg = skeleton.find_bone("mixamorig_LeftLeg")
			_bone_right_leg = skeleton.find_bone("mixamorig_RightLeg")
			_bone_left_foot = skeleton.find_bone("mixamorig_LeftFoot")
			_bone_right_foot = skeleton.find_bone("mixamorig_RightFoot")
		else:
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

	var head_pos: Vector3 = Vector3(0.0, 1.52, 0.02) if is_mixamo_coll else (Vector3(0.0, 1.76, 0.04) if is_guy else Vector3(0.0, 1.625, 0.118))
	var head_tilt: Vector3 = Vector3(-4.0, 0.0, 0.0) if is_mixamo_coll else (Vector3(-5.0, 0.0, 0.0) if is_guy else Vector3(-17.5, 0.0, 0.0))

	# Sockets positioned precisely on character axes (+Z = Forward, +Y = Up, +X = Left, -X = Right)
	head_socket = Node3D.new()
	head_socket.name = "HeadSocket"
	head_socket.position = head_pos
	head_socket.rotation_degrees = head_tilt
	pivot.add_child(head_socket)

	# Expressive Face Root (Point 9: big eyes, eyebrows, expressive mouth)
	face_root = Node3D.new()
	face_root.name = "FaceRoot"
	face_root.position = head_pos
	face_root.rotation_degrees = head_tilt
	face_root.visible = not (is_mixamo_coll or is_guy)
	pivot.add_child(face_root)
	_build_expressive_face()

	var arm_x: float = 0.58 if is_mixamo_coll else (0.42 if is_guy else 0.38)
	var arm_y: float = 1.18 if is_mixamo_coll else (1.34 if is_guy else 1.25)
	var leg_x: float = 0.24 if is_mixamo_coll else (0.18 if is_guy else 0.16)
	var leg_y: float = 0.58 if is_mixamo_coll else (0.54 if is_guy else 0.50)
	var core_y: float = 1.02 if is_mixamo_coll else (1.25 if is_guy else 1.15)
	var core_z: float = 0.06 if is_mixamo_coll else (0.18 if is_guy else 0.22)

	# In skeleton coordinates, LeftArm is at +X and RightArm is at -X
	left_arm_socket = Node3D.new()
	left_arm_socket.name = "LeftArmSocket"
	left_arm_socket.position = Vector3(arm_x, arm_y, 0.0)
	pivot.add_child(left_arm_socket)

	right_arm_socket = Node3D.new()
	right_arm_socket.name = "RightArmSocket"
	right_arm_socket.position = Vector3(-arm_x, arm_y, 0.0)
	pivot.add_child(right_arm_socket)

	left_leg_socket = Node3D.new()
	left_leg_socket.name = "LeftLegSocket"
	left_leg_socket.position = Vector3(leg_x, leg_y, 0.0)
	pivot.add_child(left_leg_socket)

	right_leg_socket = Node3D.new()
	right_leg_socket.name = "RightLegSocket"
	right_leg_socket.position = Vector3(-leg_x, leg_y, 0.0)
	pivot.add_child(right_leg_socket)

	core_socket = Node3D.new()
	core_socket.name = "CoreSocket"
	core_socket.position = Vector3(0.0, core_y, core_z)
	pivot.add_child(core_socket)

	_setup_limb_rig()

	var bot_ind_y: float = 2.65 if is_mixamo_coll else (2.70 if is_guy else 2.55)
	# Bot indicator shape overhead (Rule 5 & Rule 9)
	bot_indicator_root = Node3D.new()
	bot_indicator_root.name = "BotIndicator"
	bot_indicator_root.position = Vector3(0.0, bot_ind_y, 0.0)
	pivot.add_child(bot_indicator_root)
	if is_bot:
		_add_box(bot_indicator_root, Vector3(0.05, 0.20, 0.05), Vector3(0.0, -0.06, 0.0), _shared_dark_mat)
		var badge_rot := Vector3(0.0, 45.0 * float(shape_id), 45.0 if (shape_id % 2 == 1) else 0.0)
		_add_box(bot_indicator_root, Vector3(0.22, 0.22, 0.22), Vector3(0.0, 0.10, 0.0), _make_unshaded_mat(base_color.lightened(0.35)), badge_rot)

	var abom_mark_y: float = 3.00 if is_mixamo_coll else (3.05 if is_guy else 2.90)
	# Overhead Abomination Crown Beacon
	abomination_marker_root = Node3D.new()
	abomination_marker_root.name = "AbominationMarker"
	abomination_marker_root.position = Vector3(0.0, abom_mark_y, 0.0)
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
		abomination_ring.visible = false
	if changed:
		_refresh_limb_extras()
		_refresh_held_limb()

	if changed and animate_pop:
		trigger_transform_pop()

func _setup_limb_rig() -> void:
	_skel_to_pivot = Transform3D.IDENTITY
	if skeleton != null:
		var walker: Node = skeleton
		while walker != null and walker != pivot:
			if walker is Node3D:
				_skel_to_pivot = (walker as Node3D).transform * _skel_to_pivot
			walker = walker.get_parent()
	_skel_to_pivot_rot = _skel_to_pivot.basis.orthonormalized()

	# Manual animation stepping lets the club pose be layered on top of the walk cycle.
	if anim_player != null:
		anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

	var fallback: Dictionary = {
		&"arm_l": left_arm_socket.position,
		&"arm_r": right_arm_socket.position,
		&"leg_l": left_leg_socket.position,
		&"leg_r": right_leg_socket.position,
	}
	for key: StringName in LIMB_KEYS:
		var root_n := Node3D.new()
		root_n.name = "LimbExtra_%s" % key
		var bone: int = _limb_root_bone(key)
		if skeleton != null and bone >= 0:
			root_n.position = _skel_to_pivot * skeleton.get_bone_global_rest(bone).origin
		else:
			root_n.position = fallback[key] as Vector3
		pivot.add_child(root_n)
		limb_extra_roots[key] = root_n

	if skeleton != null:
		if _bone_right_hand >= 0:
			_hand_attach_r = BoneAttachment3D.new()
			_hand_attach_r.name = "HandAttachR"
			skeleton.add_child(_hand_attach_r)
			_hand_attach_r.bone_idx = _bone_right_hand
		if _bone_left_hand >= 0:
			_hand_attach_l = BoneAttachment3D.new()
			_hand_attach_l.name = "HandAttachL"
			skeleton.add_child(_hand_attach_l)
			_hand_attach_l.bone_idx = _bone_left_hand

func _limb_root_bone(key: StringName) -> int:
	match key:
		&"arm_l":
			return _bone_left_arm
		&"arm_r":
			return _bone_right_arm
		&"leg_l":
			return _bone_left_upleg
		&"leg_r":
			return _bone_right_upleg
	return -1

func _limb_enum_for_key(key: StringName) -> int:
	match key:
		&"arm_l":
			return LimbMeshLibrary.Limb.ARM_L
		&"arm_r":
			return LimbMeshLibrary.Limb.ARM_R
		&"leg_l":
			return LimbMeshLibrary.Limb.LEG_L
	return LimbMeshLibrary.Limb.LEG_R

func is_limb_missing(key: StringName) -> bool:
	var arms: StringName = current_slots.get(PartData.Slot.ARMS, &"base_fist") as StringName
	var legs: StringName = current_slots.get(PartData.Slot.LEGS, &"base_boots") as StringName
	match key:
		&"arm_l":
			return arms == &"severed_one_arm" or arms == &"severed_arms"
		&"arm_r":
			return arms == &"severed_arms"
		&"leg_r":
			return legs == &"severed_one_leg" or legs == &"severed_legs"
		&"leg_l":
			return legs == &"severed_legs"
	return false

## Length of this fighter's own limb in pivot units (used to size clubs and grafts).
func _native_limb_length(limb: int) -> float:
	var model_scale: float = hero_instance.scale.x if hero_instance != null else 1.0
	var scene: PackedScene = get_model_scene()
	if LimbMeshLibrary.has_limb(scene, limb):
		return LimbMeshLibrary.get_limb_length(scene, limb) * model_scale
	var is_leg: bool = limb == LimbMeshLibrary.Limb.LEG_L or limb == LimbMeshLibrary.Limb.LEG_R
	return 0.62 if is_leg else 0.50

## Server body state -> visuals. `held` and each graft: {"scene", "tint", "tint_amount"}.
func apply_body_state(new_held_slot: int, held: Dictionary, grafts: Dictionary) -> void:
	var grafts_changed: bool = grafts.keys() != _grafts.keys()
	if not grafts_changed:
		for k: Variant in grafts.keys():
			if (grafts[k] as Dictionary).get("scene") != (_grafts[k] as Dictionary).get("scene") or (grafts[k] as Dictionary).get("tint") != (_grafts[k] as Dictionary).get("tint"):
				grafts_changed = true
				break
	if grafts_changed:
		_grafts = grafts.duplicate(true)
		# Re-run the slot visuals so bones hidden by an old graft come back, then hide the new ones.
		_populate_arm_sockets(current_slots.get(PartData.Slot.ARMS, &"base_fist") as StringName)
		_populate_leg_sockets(current_slots.get(PartData.Slot.LEGS, &"base_boots") as StringName)
		_refresh_limb_extras()

	var held_changed: bool = new_held_slot != held_limb_slot or held.get("scene") != _held_info.get("scene") or held.get("tint") != _held_info.get("tint")
	held_limb_slot = new_held_slot
	_held_info = held.duplicate()
	if held_changed or (held_limb_slot >= 0 and held_limb_node == null):
		_refresh_held_limb()

func _refresh_limb_extras() -> void:
	if limb_extra_roots.is_empty():
		return
	_graft_nodes.clear()
	for key: StringName in LIMB_KEYS:
		var root_n: Node3D = limb_extra_roots[key] as Node3D
		for child: Node in root_n.get_children():
			child.free()
		var is_arm: bool = key == &"arm_l" or key == &"arm_r"
		var side: float = 1.0 if (key == &"arm_l" or key == &"leg_l") else -1.0
		if is_limb_missing(key):
			_build_stump_socket(root_n, is_arm, side)
		elif _grafts.has(key):
			var info: Dictionary = _grafts[key]
			var bone: int = _limb_root_bone(key)
			_set_bone_scale(bone, Vector3(0.001, 0.001, 0.001))
			var limb: int = _limb_enum_for_key(key)
			var scene: PackedScene = info.get("scene") as PackedScene
			var node: Node3D = LimbMeshLibrary.build_limb_node(scene, limb, info.get("tint", Color.WHITE) as Color, float(info.get("tint_amount", 1.0)))
			var src_len: float = maxf(float(node.get_meta("limb_length", 0.2)), 0.001)
			var graft_scale: float = GRAFT_ARM_LENGTH_SCALE if is_arm else GRAFT_LEG_LENGTH_SCALE
			node.scale = Vector3.ONE * (_native_limb_length(limb) * graft_scale / src_len)
			if is_arm:
				node.rotation_degrees.z = 12.0 * side
			root_n.add_child(node)
			_graft_nodes[key] = node

## Empty toy-figure socket where a limb used to plug in (round, clean, no gore).
func _build_stump_socket(root_n: Node3D, is_arm: bool, side: float) -> void:
	var radius: float = 0.105 if is_arm else 0.125
	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = radius
	rim_mesh.bottom_radius = radius
	rim_mesh.height = 0.07
	rim_mesh.radial_segments = 12
	rim.mesh = rim_mesh
	rim.material_override = _shared_white_mat
	var hole := MeshInstance3D.new()
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = radius * 0.58
	hole_mesh.bottom_radius = radius * 0.58
	hole_mesh.height = 0.08
	hole_mesh.radial_segments = 10
	hole.mesh = hole_mesh
	hole.material_override = _shared_dark_mat
	rim.add_child(hole)
	if is_arm:
		rim.rotation_degrees.z = 90.0
		rim.position.x = 0.02 * side
		hole.position.y = -0.012 * side
	else:
		rim.position.y = -0.03
		hole.position.y = -0.012
	root_n.add_child(rim)

func _refresh_held_limb() -> void:
	if held_limb_node != null and is_instance_valid(held_limb_node):
		held_limb_node.free()
	held_limb_node = null
	if held_limb_slot < 0 or skeleton == null:
		return
	var arms: StringName = current_slots.get(PartData.Slot.ARMS, &"base_fist") as StringName
	if arms == &"severed_arms":
		return
	# The chainsaw replaces the right arm, so the club goes in the left hand.
	var use_left: bool = arms == &"chainsaw_arm"
	var attach: BoneAttachment3D = _hand_attach_l if use_left else _hand_attach_r
	if attach == null:
		return
	_club_side = -1.0 if use_left else 1.0
	_club_dir = Vector3(CLUB_HOLD_DIR.x * _club_side, CLUB_HOLD_DIR.y, CLUB_HOLD_DIR.z)
	var is_leg: bool = held_limb_slot == int(PartData.Slot.LEGS)
	var limb: int = LimbMeshLibrary.Limb.LEG_L if is_leg else LimbMeshLibrary.Limb.ARM_L
	var scene: PackedScene = _held_info.get("scene", get_model_scene()) as PackedScene
	var node: Node3D = LimbMeshLibrary.build_limb_node(scene, limb, _held_info.get("tint", base_color) as Color, float(_held_info.get("tint_amount", 1.0)))
	node.name = "HeldLimb"
	var src_len: float = maxf(float(node.get_meta("limb_length", 0.2)), 0.001)
	var want_len: float = _native_limb_length(limb) * CLUB_LENGTH_SCALE
	var skel_scale: float = maxf(_skel_to_pivot.basis.get_scale().x, 0.0001)
	# The limb hangs along -Y; flip it so it sticks out of the fist along the hand bone (+Y).
	node.rotation = Vector3(0.0, 0.0, PI)
	node.scale = Vector3.ONE * (want_len / (src_len * skel_scale))
	attach.add_child(node)
	held_limb_node = node

## How far the body sinks when both legs are gone (negative, fighter-local units).
func _legless_drop() -> float:
	return -(_native_limb_length(LimbMeshLibrary.Limb.LEG_L) * _get_target_base_scale()) + 0.10

## Short squash when this fighter lands a club hit.
func trigger_bonk_squash() -> void:
	_bonk_squash_timer = 0.14

func _aim_bone_along(bone_idx: int, dir_pivot: Vector3) -> void:
	if skeleton == null or bone_idx < 0:
		return
	var parent: int = skeleton.get_bone_parent(bone_idx)
	var parent_global := Basis.IDENTITY
	if parent >= 0:
		parent_global = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	var dir_skel: Vector3 = (_skel_to_pivot_rot.inverse() * dir_pivot).normalized()
	var rest_global: Basis = parent_global * skeleton.get_bone_rest(bone_idx).basis.orthonormalized()
	var arc := Quaternion(rest_global.y.normalized(), dir_skel)
	var local: Basis = parent_global.inverse() * (Basis(arc) * rest_global)
	skeleton.set_bone_pose_rotation(bone_idx, local.get_rotation_quaternion())

## Raises the club arm and swings it overhead while an attack is playing.
func _update_club_pose(attack_timer: float, dt: float) -> float:
	var lean_deg: float = 0.0
	var target: Vector3 = CLUB_HOLD_DIR
	var rate: float = 14.0
	if attack_timer > 0.0:
		var p: float = clampf(1.0 - attack_timer / CLUB_SWING_SEC, 0.0, 1.0)
		if p < 0.30:
			target = CLUB_WINDUP_DIR
			rate = 34.0
			lean_deg = -10.0
		elif p < 0.72:
			target = CLUB_SLAM_DIR
			rate = 46.0
			lean_deg = 16.0
	target = Vector3(target.x * _club_side, target.y, target.z)
	_club_dir = _club_dir.lerp(target, minf(1.0, rate * dt)).normalized()
	var upper: int = _bone_right_arm if _club_side > 0.0 else _bone_left_arm
	var fore: int = _bone_right_forearm if _club_side > 0.0 else _bone_left_forearm
	var hand: int = _bone_right_hand if _club_side > 0.0 else _bone_left_hand
	_aim_bone_along(upper, _club_dir)
	if fore >= 0:
		skeleton.set_bone_pose_rotation(fore, skeleton.get_bone_rest(fore).basis.get_rotation_quaternion())
	if hand >= 0:
		skeleton.set_bone_pose_rotation(hand, skeleton.get_bone_rest(hand).basis.get_rotation_quaternion())
	return lean_deg

func trigger_transform_pop() -> void:
	_transform_flash_timer = 0.32
	if transform_burst_ring != null:
		transform_burst_ring.visible = true
		transform_burst_ring.scale = Vector3(0.35, 0.35, 0.35)
	if pivot != null:
		var base_s: float = _get_target_base_scale()
		pivot.scale = Vector3(1.38, 0.68, 1.38) * base_s
	# Trigger StatusFX Shatter burst at center of fighter
	play_shatter_vfx(Vector3(0.0, 1.2, 0.0))

func _get_target_base_scale() -> float:
	var mult: float = 0.86 if character_model_type == CharacterModelType.STATUSFX_GUY else 1.0
	if fighter_id == 0:
		return (1.82 if is_abomination else 1.42) * mult
	return (1.68 if is_abomination else 1.30) * mult

func _populate_head_socket(part_id: StringName) -> void:
	_clear_socket(head_socket)
	if face_eyes_root != null:
		face_eyes_root.visible = true

	match part_id:
		&"laser_eye":
			# Sleek Cyber mono-visor with red laser lens on eye level (+Z face)
			if face_eyes_root != null:
				face_eyes_root.visible = false
			_add_box(head_socket, Vector3(0.22, 0.065, 0.04), Vector3(0.0, 0.016, 0.012), _shared_dark_mat)
			_add_box(head_socket, Vector3(0.12, 0.035, 0.05), Vector3(0.0, 0.016, 0.020), _shared_red_eye_mat)
		&"visor_head":
			# Sleek dark cyber sunglasses with cyan trim on eye level (+Z face)
			if face_eyes_root != null:
				face_eyes_root.visible = false
			_add_box(head_socket, Vector3(0.22, 0.065, 0.04), Vector3(0.0, 0.016, 0.012), _shared_dark_mat)
			_add_box(head_socket, Vector3(0.18, 0.030, 0.05), Vector3(0.0, 0.016, 0.020), _shared_cyan_mat)
		&"spike_helm":
			# Spiked red mohawk crest on top of head (expressive eyes, eyebrows and mouth visible)
			var crest_mat: ShaderMaterial = _make_toon_mat(Color(0.95, 0.16, 0.24), 0.12)
			_add_box(head_socket, Vector3(0.08, 0.16, 0.22), Vector3(0.0, 0.12, -0.06), crest_mat)
		_:
			# Default: show the natural expressive head with big eyes, eyebrows and mouth!
			pass

func _build_expressive_face() -> void:
	if face_root == null:
		return
	_clear_socket(face_root)

	# 1. Clean face plate mask covering old tiny dots & slit
	var mask_mat := StandardMaterial3D.new()
	mask_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mask_mat.albedo_color = Color(0.96, 0.88, 0.80) if fighter_id == 0 else Color(0.94, 0.86, 0.78)
	_add_box(face_root, Vector3(0.24, 0.24, 0.008), Vector3(0.0, 0.005, 0.004), mask_mat)

	# 2. Big Expressive Anime/Cartoon Eyes Root
	face_eyes_root = Node3D.new()
	face_eyes_root.name = "EyesRoot"
	face_root.add_child(face_eyes_root)

	var eye_y: float = 0.020
	var eye_z: float = 0.010
	var eye_xs: Array[float] = [-0.054, 0.054]

	for ex: float in eye_xs:
		# Outer dark eye contour / frame
		_add_box(face_eyes_root, Vector3(0.054, 0.065, 0.008), Vector3(ex, eye_y, eye_z), _shared_dark_mat)
		# Crisp white sclera
		_add_box(face_eyes_root, Vector3(0.046, 0.056, 0.010), Vector3(ex, eye_y, eye_z + 0.002), _shared_white_mat)

		# Iris & Pupil (Signature royal deep purple for player, dark contrasting for bots)
		var iris_mat := StandardMaterial3D.new()
		iris_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		iris_mat.albedo_color = Color(0.22, 0.12, 0.44) if fighter_id == 0 else Color(0.12, 0.08, 0.20)
		_add_box(face_eyes_root, Vector3(0.032, 0.042, 0.012), Vector3(ex, eye_y - 0.002, eye_z + 0.004), iris_mat)

		# Specular eye glints / highlights (Luce negli occhi)
		_add_box(face_eyes_root, Vector3(0.015, 0.016, 0.014), Vector3(ex - 0.008, eye_y + 0.012, eye_z + 0.006), _shared_white_mat)
		_add_box(face_eyes_root, Vector3(0.007, 0.008, 0.014), Vector3(ex + 0.008, eye_y - 0.008, eye_z + 0.006), _shared_white_mat)

	# 3. Expressive Brawler Eyebrows (Dynamic inward-angled determination)
	var eb_y: float = 0.066
	_add_box(face_root, Vector3(0.055, 0.018, 0.010), Vector3(-0.054, eb_y, eye_z + 0.004), _shared_dark_mat, Vector3(0.0, 0.0, -14.0))
	_add_box(face_root, Vector3(0.055, 0.018, 0.010), Vector3(0.054, eb_y, eye_z + 0.004), _shared_dark_mat, Vector3(0.0, 0.0, 14.0))

	# 4. Expressive Brawler Smirk / Mouth
	var mouth_y: float = -0.046
	# Outer dark smirk cavity
	_add_box(face_root, Vector3(0.090, 0.026, 0.008), Vector3(0.004, mouth_y, eye_z), _shared_dark_mat)
	# White teeth flash
	_add_box(face_root, Vector3(0.072, 0.011, 0.010), Vector3(0.004, mouth_y + 0.005, eye_z + 0.002), _shared_white_mat)
	# Lower lip / red tongue accent
	var tongue_mat := StandardMaterial3D.new()
	tongue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tongue_mat.albedo_color = Color(0.92, 0.24, 0.36)
	_add_box(face_root, Vector3(0.048, 0.007, 0.010), Vector3(0.004, mouth_y - 0.005, eye_z + 0.002), tongue_mat)

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


		&"severed_arms":
			# Hide skinned hero arms
			_set_bone_scale(_bone_left_arm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_arm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_forearm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_forearm, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_hand, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_hand, Vector3(0.001, 0.001, 0.001))

			# The empty toy sockets are drawn by _refresh_limb_extras on the real shoulder joints.

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
			var blade_mat: ShaderMaterial = _make_toon_mat(Color(0.48, 0.52, 0.60), 0.08)
			var edge_mat: ShaderMaterial = _make_toon_mat(Color(0.85, 0.88, 0.94), 0.05)
			_add_box(right_arm_socket, Vector3(0.28, 0.28, 0.36), Vector3(0.0, -0.20, 0.16), orange_mat)
			var blade: MeshInstance3D = _add_box(right_arm_socket, Vector3(0.07, 0.22, 0.62), Vector3(0.0, -0.20, 0.56), blade_mat)
			_add_box(blade, Vector3(0.08, 0.05, 0.60), Vector3(0.0, 0.11, 0.0), edge_mat)
			_add_box(blade, Vector3(0.08, 0.05, 0.60), Vector3(0.0, -0.11, 0.0), edge_mat)
			for t_i: int in range(3):
				var tz: float = -0.20 + float(t_i) * 0.20
				_add_box(blade, Vector3(0.09, 0.04, 0.06), Vector3(0.0, 0.13, tz), _shared_dark_mat)
				_add_box(blade, Vector3(0.09, 0.04, 0.06), Vector3(0.0, -0.13, tz), _shared_dark_mat)

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


		&"severed_legs":
			# Hide skinned hero legs
			_set_bone_scale(_bone_left_upleg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_upleg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_leg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_leg, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_left_foot, Vector3(0.001, 0.001, 0.001))
			_set_bone_scale(_bone_right_foot, Vector3(0.001, 0.001, 0.001))


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
			var shield_mat: ShaderMaterial = _make_toon_mat(Color(0.20, 0.62, 0.96), 0.10)
			var cross_mat: ShaderMaterial = _make_toon_mat(Color(0.92, 0.94, 0.98), 0.05)
			_add_box(core_socket, Vector3(0.26, 0.28, 0.05), Vector3(0.0, 0.02, 0.0), shield_mat)
			_add_box(core_socket, Vector3(0.18, 0.16, 0.05), Vector3(0.0, -0.10, 0.0), shield_mat)
			_add_box(core_socket, Vector3(0.20, 0.06, 0.07), Vector3(0.0, 0.02, 0.0), cross_mat)
			_add_box(core_socket, Vector3(0.06, 0.20, 0.07), Vector3(0.0, 0.02, 0.0), cross_mat)
		&"magnet_core":
			var mag_mat: ShaderMaterial = _make_toon_mat(Color(0.92, 0.20, 0.35), 0.10)
			var pole_mat: ShaderMaterial = _make_toon_mat(Color(0.85, 0.88, 0.95), 0.05)
			_add_box(core_socket, Vector3(0.26, 0.08, 0.05), Vector3(0.0, -0.08, 0.0), mag_mat)
			_add_box(core_socket, Vector3(0.08, 0.18, 0.05), Vector3(-0.09, 0.02, 0.0), mag_mat)
			_add_box(core_socket, Vector3(0.08, 0.18, 0.05), Vector3(0.09, 0.02, 0.0), mag_mat)
			_add_box(core_socket, Vector3(0.08, 0.06, 0.06), Vector3(-0.09, 0.12, 0.0), pole_mat)
			_add_box(core_socket, Vector3(0.08, 0.06, 0.06), Vector3(0.09, 0.12, 0.0), pole_mat)
		&"crown_core":
			# 3D Golden Crown on chest with toon shading
			var crown_mat: ShaderMaterial = _make_toon_mat(Color(1.0, 0.78, 0.15), 0.12)
			_add_box(core_socket, Vector3(0.28, 0.12, 0.04), Vector3(0.0, -0.02, 0.0), crown_mat)
			_add_box(core_socket, Vector3(0.06, 0.10, 0.05), Vector3(-0.09, 0.06, 0.0), crown_mat)
			_add_box(core_socket, Vector3(0.07, 0.13, 0.05), Vector3(0.0, 0.08, 0.0), crown_mat)
			_add_box(core_socket, Vector3(0.06, 0.10, 0.05), Vector3(0.09, 0.06, 0.0), crown_mat)
			_add_box(core_socket, Vector3(0.04, 0.04, 0.06), Vector3(0.0, 0.0, 0.01), _shared_red_eye_mat)
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

	# Drive skeletal animation
	if anim_player != null:
		var is_guy: bool = (character_model_type == CharacterModelType.STATUSFX_GUY)
		var is_mixamo_coll: bool = _is_mixamo_collection_model()
		var walk_anim: String = "Walk" if (is_guy or is_mixamo_coll) else "Armature|Armature|Armature|Armature|walking_man|baselayer"
		if is_moving:
			if not anim_player.is_playing() or anim_player.current_animation != walk_anim:
				anim_player.play(walk_anim)
			anim_player.speed_scale = clampf(speed / (2.4 if is_guy else 3.2), 0.75, 2.0)
		elif attack_timer > 0.0 and is_mixamo_coll and anim_player.has_animation("Attack"):
			if anim_player.current_animation != "Attack":
				anim_player.play("Attack")
			anim_player.speed_scale = 1.0
		else:
			if is_guy or is_mixamo_coll:
				if not anim_player.is_playing() or anim_player.current_animation != "Idle":
					anim_player.play("Idle")
				anim_player.speed_scale = 1.0
			else:
				if anim_player.is_playing():
					anim_player.pause()
			if anim_player.is_playing():
				anim_player.advance(dt)

	_reassert_collapsed_bones()

	# Club in hand: raise it and swing it overhead, layered on top of the walk cycle.
	if held_limb_node != null and is_instance_valid(held_limb_node):
		pivot.rotation_degrees.x = _update_club_pose(attack_timer, dt)

	# Drive attack swing on right arm socket
	if attack_timer > 0.0:
		right_arm_socket.rotation_degrees.x = -65.0
	else:
		var rest_pitch: float = 35.0 if current_slots.get(PartData.Slot.ARMS, &"") == &"chainsaw_arm" else 0.0
		right_arm_socket.rotation_degrees.x = lerpf(right_arm_socket.rotation_degrees.x, rest_pitch, minf(1.0, 14.0 * dt))

	# Severed legs limping wobble & hopping
	var legs_slot: StringName = current_slots.get(PartData.Slot.LEGS, &"")
	var has_severed_legs: bool = (legs_slot == &"severed_legs")
	var has_severed_one_leg: bool = (legs_slot == &"severed_one_leg")
	var is_guy_model: bool = (character_model_type == CharacterModelType.STATUSFX_GUY)
	if is_moving:
		_walk_phase += (3.5 + speed * 1.5) * dt
		if has_severed_one_leg:
			# Hopping on single remaining leg: distinct vertical hop and asymmetric tilt!
			pivot.position.y = -0.06 + absf(sin(_walk_phase * 1.6)) * 0.16
			pivot.rotation_degrees.z = sin(_walk_phase * 1.6) * 13.0
		elif has_severed_legs:
			# No legs left: the torso sits on its sockets and bounces along like a ball.
			pivot.position.y = _legless_drop() + absf(sin(_walk_phase * 1.5)) * 0.24
			pivot.rotation_degrees.z = sin(_walk_phase * 1.5) * 9.0
		elif is_guy_model:
			# Energetic cartoon brawler bob for StatusFX Guy model
			pivot.position.y = absf(sin(_walk_phase * 2.2)) * 0.08
			pivot.rotation_degrees.z = sin(_walk_phase * 1.8) * 4.5
		else:
			pivot.position.y = 0.0
			pivot.rotation_degrees.z = 0.0
	else:
		var rest_y: float = _legless_drop() if has_severed_legs else 0.0
		pivot.position.y = lerpf(pivot.position.y, rest_y, minf(1.0, 12.0 * dt))
		pivot.rotation_degrees.z = lerpf(pivot.rotation_degrees.z, 0.0, minf(1.0, 12.0 * dt))

	# Grafted limbs are stiff foreign parts: they swing from the joint like a puppet's.
	for g_key: Variant in _graft_nodes.keys():
		var g_node: Node3D = _graft_nodes[g_key] as Node3D
		if g_node == null or not is_instance_valid(g_node):
			continue
		var g_phase: float = 0.0 if (g_key == &"arm_l" or g_key == &"leg_r") else PI
		var g_amp: float = 0.75 if (g_key == &"leg_l" or g_key == &"leg_r") else 0.55
		var g_target: float = sin(_walk_phase * 1.6 + g_phase) * g_amp if is_moving else 0.0
		g_node.rotation.x = lerpf(g_node.rotation.x, g_target, minf(1.0, 18.0 * dt))

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

	# Drive StatusFX Shatter/Energy Overlay on character mesh
	if status_overlay_mat != null:
		var target_overlay_amount: float = 0.0
		var overlay_color: Color = Color.WHITE
		if hurt_timer > 0.0:
			target_overlay_amount = clampf(hurt_timer * 4.0, 0.35, 1.0)
			overlay_color = Color(1.0, 0.20, 0.15)
			status_overlay_mat.set_shader_parameter("emission", 5.0)
		elif _transform_flash_timer > 0.0:
			target_overlay_amount = clampf(_transform_flash_timer / 0.32, 0.0, 1.0)
			overlay_color = Color(1.0, 0.82, 0.22) if fighter_id == 0 else Color(1.0, 0.24, 0.72)
			status_overlay_mat.set_shader_parameter("emission", 6.0)
		elif is_abomination:
			var pulse: float = 0.60 + 0.35 * sin(float(Time.get_ticks_msec()) * 0.008)
			target_overlay_amount = pulse
			overlay_color = Color(1.0, 0.18, 0.65)
			status_overlay_mat.set_shader_parameter("emission", 4.2)

		status_overlay_mat.set_shader_parameter("effect_amount", target_overlay_amount)
		status_overlay_mat.set_shader_parameter("primary_color", overlay_color)

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
	elif _bonk_squash_timer > 0.0:
		_bonk_squash_timer = maxf(0.0, _bonk_squash_timer - dt)
		pivot.scale = Vector3(0.88, 1.20, 0.88) * base_s
	elif hurt_timer > 0.0:
		pivot.scale = Vector3(1.18, 0.84, 1.18) * base_s
	else:
		pivot.scale = pivot.scale.lerp(Vector3.ONE * base_s, minf(1.0, 12.0 * dt))
