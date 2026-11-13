class_name MainArenaController
extends Node3D

@export var balance: BalanceConfig = preload("res://shared/default_balance.tres")

var server: MatchServer
var arena_builder: ArenaBuilder3D
var sound_controller: SoundController
const CustomizationMenuScript := preload("res://game/ui/customization_menu.gd")
const STREAKS_SHADER := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/StatusFX/shader/streaks.gdshader")

var camera: Camera3D
var hud: VerticalHUD
var virtual_joystick: TouchJoystick
var customization_menu: Control
var is_customizing: bool = false
var fighter_nodes: Array[BlockyFighter3D] = []
var attack_fx_pool: Array[MeshInstance3D] = []
var active_attack_fx: Array[Dictionary] = []

var camera_shake_trauma: float = 0.0
var current_cam_yaw: float = 0.0
var target_cam_yaw: float = 0.0
var kill_cam_timer: float = 0.0
var kill_cam_focus_xz: Vector2 = Vector2.ZERO
var hit_stop_active: bool = false
var _hit_stop_id: int = 0
var _pending_combatant_slots: Dictionary = {}
var _flying_parts_in_flight: Dictionary = {}
var target_ring_mesh: MeshInstance3D
var _custom_hero_yaw: float = -0.28

var customize_stage_root: Node3D
var customize_floating_cubes: Array[Dictionary] = []
var customize_light_shaft: MeshInstance3D
var customize_spotlight: SpotLight3D
var customize_fill_light: OmniLight3D
var _custom_stage_time: float = 0.0

var _joystick_vec: Vector2 = Vector2.ZERO
var _last_raw_move_input: Vector2 = Vector2.ZERO
var _ability_queued: bool = false
var _attack_queued: bool = false
var _frame_counter: int = 0
var _screenshot_path: String = ""
var _target_screenshot_frame: int = 15
var _simulate_input_preview: bool = false
var _preview_frenzy: bool = false
var _preview_result: bool = false
var _preview_clip: bool = false
var _preview_steal_juice: bool = false
var _preview_tutorial_phase2: bool = false
var _preview_tutorial_dismissed: bool = false
var _preview_customize: bool = false
var _preview_loading: bool = false
var _preview_one_leg: bool = false
var _preview_last10s: bool = false
var _skip_customize: bool = false
var _requested_map_theme: int = -1
var _preview_tab_name: String = ""
var _web_first_frame_reported: bool = false
var _web_first_input_reported: bool = false
var _preview_attack_vfx: bool = false
var _preview_face_east: bool = false
var _preview_face_south: bool = false
var _preview_settings: bool = false
var _preview_9parts: bool = false
var _preview_limbs: bool = false
var _preview_brawl: bool = false
var _preview_menu: String = "" # "shop" | "pass" | "pass-xp" | "missions"
var _preview_scroll: float = -1.0
var _preview_skin: String = ""
var _camera_transitioning: bool = false

func _ready() -> void:
	_parse_cmdline_args()
	if _preview_customize:
		is_customizing = true
	elif _preview_limbs or _simulate_input_preview or _preview_frenzy or _preview_last10s or _preview_result or _preview_clip or _preview_steal_juice or _preview_tutorial_phase2 or _preview_tutorial_dismissed or _skip_customize or _requested_map_theme != -1 or _preview_face_east or _preview_face_south or _preview_settings or _preview_9parts:
		is_customizing = false
	else:
		is_customizing = true

	_setup_audio()
	_setup_environment_and_lights()
	_setup_camera()
	_setup_server_and_world()
	if _requested_map_theme != -1:
		server.set_map_theme(_requested_map_theme)
	_setup_ui()
	if _preview_tab_name != "" and customization_menu != null:
		if _preview_tab_name == "arms":
			customization_menu._switch_tab(CustomizationMenu.TAB_ARMS)
			customization_menu._select_option(&"chainsaw_arm")
		elif _preview_tab_name == "legs":
			customization_menu._switch_tab(CustomizationMenu.TAB_LEGS)
			customization_menu._select_option(&"rocket_legs")
		elif _preview_tab_name == "core":
			customization_menu._switch_tab(CustomizationMenu.TAB_CORE)
			customization_menu._select_option(&"shield_core")
	if _preview_loading and customization_menu != null:
		customization_menu.is_loading = true
		customization_menu.loading_progress = 0.65
	if _preview_last10s:
		server.match_elapsed_sec = balance.match_duration_sec - 7.0
	elif _preview_frenzy:
		server.match_elapsed_sec = balance.frenzy_start_sec - 0.02
	if _preview_result:
		server.match_elapsed_sec = balance.match_duration_sec - 0.05
	if _preview_clip:
		_stage_viral_clip_moment()
	elif _preview_steal_juice:
		_stage_steal_juice_scenario()
	if _preview_one_leg and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		p0.slots[PartData.Slot.LEGS] = &"severed_one_leg"
		p0.slots[PartData.Slot.ARMS] = &"chainsaw_arm"
		p0.slots[PartData.Slot.HEAD] = &"laser_eye"
		server._recalc_combatant_stats(p0, true)
		if not fighter_nodes.is_empty():
			fighter_nodes[0].apply_slots(p0.slots, false, false)
	if _preview_attack_vfx and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		p0.pos = Vector2(0.0, 3.2)
		p0.prev_pos = p0.pos
		p0.facing_angle = -PI * 0.5 # face upward toward target
		p0.slots[PartData.Slot.HEAD] = &"laser_eye"
		p0.slots[PartData.Slot.ARMS] = &"chainsaw_arm"
		p0.slots[PartData.Slot.LEGS] = &"rocket_legs"
		server._recalc_combatant_stats(p0, true)
		if not fighter_nodes.is_empty():
			fighter_nodes[0].apply_slots(p0.slots, false, false)
			fighter_nodes[0].update_visual_state(p0.pos, Vector2.ZERO, p0.facing_angle, 0.25, 0.0, true, 0.016)
		if server.combatants.size() > 1:
			var bot1: MatchServer.CombatantState = server.combatants[1]
			bot1.pos = Vector2(0.0, 0.4)
			bot1.prev_pos = bot1.pos
			if fighter_nodes.size() > 1:
				fighter_nodes[1].update_visual_state(bot1.pos, Vector2.ZERO, PI * 0.5, 0.0, 0.25, true, 0.016)
			_on_server_attack_performed(0, 1, p0.pos, bot1.pos, 35)
	if _preview_tutorial_phase2 and hud != null:
		hud.intro_tutorial_timer = 2.4
		hud._intro_elapsed = 3.6
	elif _preview_tutorial_dismissed and hud != null:
		hud.intro_tutorial_timer = 0.0
		hud._intro_elapsed = 6.0
	if _preview_settings and hud != null:
		hud.toggle_settings()
	if _preview_9parts and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		p0.collected_parts[PartData.Slot.ARMS] = 3
		p0.collected_parts[PartData.Slot.LEGS] = 3
		p0.collected_parts[PartData.Slot.CORE] = 3
		p0.slots[PartData.Slot.ARMS] = &"chainsaw_arm"
		p0.slots[PartData.Slot.LEGS] = &"rocket_legs"
		p0.slots[PartData.Slot.CORE] = &"shield_core"
		server._recalc_combatant_stats(p0, true)
		if hud != null:
			hud.on_collected_parts_updated(p0.collected_parts, p0.stolen_parts_count)
			hud.on_player_slots_updated(p0.slots, p0.is_abomination, p0.total_mass)
	if _preview_limbs:
		_stage_limb_preview()
		if _preview_brawl:
			server.bots_enabled = true
			for c: MatchServer.CombatantState in server.combatants:
				c.attack_cooldown = 0.4
	if _preview_face_east and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		p0.pos = Vector2(-1.5, 2.0)
		p0.prev_pos = p0.pos
		p0.facing_angle = 0.0 # Facing East
		current_cam_yaw = -PI * 0.5
		target_cam_yaw = -PI * 0.5
		camera.rotation_degrees = Vector3(balance.camera_pitch_deg, rad_to_deg(current_cam_yaw), 0.0)
		if server.combatants.size() > 1:
			var bot1: MatchServer.CombatantState = server.combatants[1]
			bot1.pos = Vector2(2.5, 2.0) # Enemy situated East of player
			bot1.prev_pos = bot1.pos
	elif _preview_face_south and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		p0.pos = Vector2(0.0, -1.0)
		p0.prev_pos = p0.pos
		p0.facing_angle = PI * 0.5 # Facing South
		current_cam_yaw = -PI
		target_cam_yaw = -PI
		camera.rotation_degrees = Vector3(balance.camera_pitch_deg, rad_to_deg(current_cam_yaw), 0.0)
		if server.combatants.size() > 1:
			var bot1: MatchServer.CombatantState = server.combatants[1]
			bot1.pos = Vector2(0.0, 3.5) # Enemy situated South of player
			bot1.prev_pos = bot1.pos
	if _simulate_input_preview and virtual_joystick != null:
		virtual_joystick.simulate_drag(Vector2(210.0, 868.0), Vector2(246.0, 832.0))

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	for fx: MeshInstance3D in attack_fx_pool:
		if is_instance_valid(fx):
			fx.material_override = null
	for item: Dictionary in active_attack_fx:
		var fx: MeshInstance3D = item.get("node")
		if fx != null and is_instance_valid(fx):
			fx.material_override = null

func _parse_cmdline_args() -> void:
	var all_args: Array[String] = []
	all_args.append_array(OS.get_cmdline_user_args())
	all_args.append_array(OS.get_cmdline_args())
	for arg: String in all_args:
		if arg.begins_with("--capture-screenshot="):
			_screenshot_path = arg.trim_prefix("--capture-screenshot=")
		elif arg.begins_with("--screenshot-frame="):
			_target_screenshot_frame = int(arg.trim_prefix("--screenshot-frame="))
		elif arg == "--simulate-input":
			_simulate_input_preview = true
		elif arg == "--preview-frenzy":
			_preview_frenzy = true
		elif arg == "--preview-last10s":
			_preview_last10s = true
		elif arg == "--preview-result":
			_preview_result = true
		elif arg == "--preview-clip":
			_preview_clip = true
		elif arg == "--preview-steal-juice":
			_preview_steal_juice = true
		elif arg == "--preview-attack-vfx":
			_preview_attack_vfx = true
			_skip_customize = true
		elif arg == "--preview-face-east":
			_preview_face_east = true
			_skip_customize = true
		elif arg == "--preview-face-south":
			_preview_face_south = true
			_skip_customize = true
		elif arg == "--preview-tutorial-phase2":
			_preview_tutorial_phase2 = true
		elif arg == "--preview-tutorial-dismissed":
			_preview_tutorial_dismissed = true
		elif arg == "--map-theme=cyber":
			_requested_map_theme = MatchServer.MapTheme.CYBER_FACTORY
		elif arg == "--map-theme=hex":
			_requested_map_theme = MatchServer.MapTheme.FLOATING_HEX
		elif arg == "--preview-customize":
			_preview_customize = true
		elif arg == "--preview-settings":
			_preview_settings = true
			_skip_customize = true
		elif arg == "--preview-9parts":
			_preview_9parts = true
			_skip_customize = true
		elif arg == "--preview-limbs":
			_preview_limbs = true
			_skip_customize = true
		elif arg == "--preview-brawl":
			# Same staging as --preview-limbs, then the bots are let loose around the player.
			_preview_limbs = true
			_preview_brawl = true
			_skip_customize = true
		elif arg.begins_with("--preview-menu="):
			_preview_menu = arg.trim_prefix("--preview-menu=")
		elif arg.begins_with("--preview-scroll="):
			_preview_scroll = float(arg.trim_prefix("--preview-scroll="))
		elif arg.begins_with("--preview-skin="):
			_preview_skin = arg.trim_prefix("--preview-skin=")
		elif arg == "--preview-loading":
			_preview_loading = true
		elif arg == "--preview-one-leg":
			_preview_one_leg = true
		elif arg.begins_with("--preview-tab="):
			_preview_tab_name = arg.trim_prefix("--preview-tab=")
			_preview_customize = true
		elif arg == "--skip-customize" or arg == "--instant-match":
			_skip_customize = true
		elif arg == "--use-blocky-hero":
			BlockyFighter3D.default_model_type = BlockyFighter3D.CharacterModelType.BLOCKY_HERO
		elif arg == "--use-statusfx-guy" or arg == "--statusfx-models" or arg == "--guy-model":
			BlockyFighter3D.default_model_type = BlockyFighter3D.CharacterModelType.STATUSFX_GUY
		elif arg == "--use-characters" or arg == "--use-cutie" or arg == "--characters-models":
			BlockyFighter3D.default_model_type = BlockyFighter3D.CharacterModelType.MAN_CUTIE

func _setup_audio() -> void:
	sound_controller = SoundController.new()
	sound_controller.name = "SoundController"
	add_child(sound_controller)

func _stage_viral_clip_moment() -> void:
	for k: Variant in arena_builder.dropped_part_nodes.keys():
		var dn: Node3D = arena_builder.dropped_part_nodes[k]
		if is_instance_valid(dn):
			dn.queue_free()
	arena_builder.dropped_part_nodes.clear()
	server.setup_viral_clip_scenario()
	# Simulate the 3-second viral clip culmination: dash -> KO bot #1 -> steal Chainsaw Arm -> transform into Abomination!
	var p0: MatchServer.CombatantState = server.combatants[0]
	var bot1: MatchServer.CombatantState = server.combatants[1]
	bot1.pos = Vector2(-1.65, 1.35)
	bot1.prev_pos = bot1.pos
	server._handle_combatant_death(bot1, p0)
	if not server.dropped_parts.is_empty():
		var d: MatchServer.DroppedPartState = server.dropped_parts[0]
		var d_id: int = d.id
		var d_pos: Vector2 = d.pos
		server.dropped_parts.remove_at(0)
		server.equip_part_on_combatant(0, &"chainsaw_arm")
		server.part_picked_up.emit(d_id, 0, &"chainsaw_arm", int(PartData.Slot.ARMS), int(PartData.Rarity.EPIC), d_pos)
	# Keep rocket legs & laser eye for iconic key-art silhouette after clip steal.
	# Offset from the pedestal so the gold cube does not sit on the hero's head.
	p0.pos = Vector2(1.8, 5.2)
	p0.prev_pos = p0.pos
	p0.slots[PartData.Slot.LEGS] = &"rocket_legs"
	p0.slots[PartData.Slot.HEAD] = &"laser_eye"
	server._recalc_combatant_stats(p0, true)
	if hud != null:
		hud.intro_tutorial_timer = 0.0
		hud._intro_elapsed = 6.0
	if not fighter_nodes.is_empty() and fighter_nodes[0].transform_burst_ring != null:
		fighter_nodes[0].transform_burst_ring.visible = false

## Screenshot staging for the dismemberment loop: club in hand, a graft, a hopping victim, limbs on the floor.
func _stage_limb_preview() -> void:
	if server.combatants.size() < 4:
		return
	server.bots_enabled = false
	if hud != null:
		hud.intro_tutorial_timer = 0.0
		hud._intro_elapsed = 6.0
	var p0: MatchServer.CombatantState = server.combatants[0]
	p0.pos = Vector2(0.0, 6.0)
	p0.prev_pos = p0.pos
	p0.facing_angle = -PI * 0.5
	p0.attack_cooldown = 1.0 # First club swing lands about one second in.
	var layout: Array[Vector2] = [Vector2(-2.6, 3.4), Vector2(2.4, 2.8), Vector2(0.4, 2.7)]
	for i: int in range(1, 4):
		var b: MatchServer.CombatantState = server.combatants[i]
		b.pos = layout[i - 1]
		b.prev_pos = b.pos
		b.facing_angle = (p0.pos - b.pos).angle()
		b.attack_cooldown = 99.0
	for i: int in range(4, server.combatants.size()):
		server.combatants[i].attack_cooldown = 99.0
	# Bot 1 loses an arm and a leg, bot 2 an arm: their limbs land on the floor.
	server._sever_limb(server.combatants[1], p0, int(PartData.Slot.ARMS), Vector2(0.4, 1.0))
	server._sever_limb(server.combatants[1], p0, int(PartData.Slot.LEGS), Vector2(1.0, 0.6))
	server._sever_limb(server.combatants[2], p0, int(PartData.Slot.ARMS), Vector2(-1.0, 0.8))
	server._sever_limb(server.combatants[3], p0, int(PartData.Slot.LEGS), Vector2(-0.6, 1.0))
	for d: MatchServer.DroppedPartState in server.dropped_parts:
		d.lifetime_sec = -1.0
	# The player swings bot 3's leg and wears bot 2's arm as a graft.
	p0.held_limb_slot = int(PartData.Slot.LEGS)
	p0.held_limb_owner_id = 3
	p0.held_limb_hits_left = 5
	p0.graft_owners[&"arm_l"] = 2
	server._recalc_combatant_stats(p0, true)
	for i: int in range(fighter_nodes.size()):
		_apply_body_state(i)

func _stage_steal_juice_scenario() -> void:
	_stage_viral_clip_moment()
	if hud != null:
		hud.intro_tutorial_timer = 0.0
		hud._intro_elapsed = 6.0
		hud.show_part_stolen_banner(&"chainsaw_arm", int(PartData.Rarity.EPIC), int(PartData.Slot.ARMS))
	if arena_builder != null:
		arena_builder.spawn_impact_star(Vector2(0.0, 4.4), true)

func _setup_environment_and_lights() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.26, 0.42, 0.96)     # Clear cartoon-blue zenith
	sky_mat.sky_horizon_color = Color(0.66, 0.70, 1.0)  # Bright lavender horizon
	sky_mat.ground_horizon_color = Color(0.58, 0.56, 0.94)
	sky_mat.ground_bottom_color = Color(0.34, 0.30, 0.72)
	sky_mat.sky_curve = 0.12
	sky_mat.sky_energy_multiplier = 1.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.50, 0.82)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.60, 0.96)
	env.fog_light_energy = 0.40
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.08
	env.fog_aerial_perspective = 0.0
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-42.0, 32.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.035
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)

	var rim_dir := DirectionalLight3D.new()
	rim_dir.name = "RimLight"
	rim_dir.light_color = Color(0.55, 0.38, 0.95)
	rim_dir.light_energy = 0.42
	rim_dir.rotation_degrees = Vector3(-30.0, -145.0, 0.0)
	rim_dir.shadow_enabled = false
	add_child(rim_dir)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ArenaCamera3D"
	camera.fov = balance.camera_fov_deg
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 0.2
	camera.far = 95.0
	current_cam_yaw = 0.0
	target_cam_yaw = 0.0
	if is_customizing:
		camera.position = Vector3(0.0, 1.78, 4.35)
		camera.rotation_degrees = Vector3(-14.5, 0.0, 0.0)
	else:
		var start_z: float = 14.0 + balance.camera_z_bias
		camera.position = Vector3(0.0, balance.camera_distance, start_z)
		camera.rotation_degrees = Vector3(balance.camera_pitch_deg, 0.0, 0.0)
	add_child(camera)
	camera.make_current()

func _setup_server_and_world() -> void:
	server = MatchServer.new()
	server.name = "MatchServer"
	server.balance = balance
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--static-preview":
			server.bots_enabled = false
	if is_customizing:
		server.bots_enabled = false
		if not server.combatants.is_empty():
			server.combatants[0].pos = Vector2.ZERO
			server.combatants[0].prev_pos = Vector2.ZERO
			server.combatants[0].facing_angle = -PI * 0.5
	add_child(server)

	arena_builder = ArenaBuilder3D.new()
	arena_builder.name = "ArenaBuilder3D"
	add_child(arena_builder)
	arena_builder.drop_owner_resolver = _resolve_fighter_visual_info
	arena_builder.build_from_server(server)
	arena_builder.visible = not is_customizing
	if is_customizing:
		var ped: Node = arena_builder.get_node_or_null("PowerPedestal")
		if ped != null:
			ped.set("visible", false)

	_setup_customization_stage()

	fighter_nodes.clear()
	for c: MatchServer.CombatantState in server.combatants:
		var fn := BlockyFighter3D.new()
		fn.name = "Fighter_%d" % c.id
		add_child(fn)
		fn.setup_fighter(c.id, c.is_bot, c.base_color, c.shape_id, c.slots, c.is_abomination)
		if is_customizing and c.id != 0:
			fn.visible = false
		fn.update_visual_state(c.pos, c.vel, c.facing_angle, 0.0, 0.0, c.alive, 0.016)
		fighter_nodes.append(fn)

	# Cut the limb meshes for every model in the match now, at load, so the first limb that
	# pops off mid-fight does not cost a frame hitch.
	for fn_warm: BlockyFighter3D in fighter_nodes:
		LimbMeshLibrary.get_limb_set(fn_warm.get_model_scene())

	for i: int in range(8):
		var fx := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.18, 1.0)
		fx.mesh = bm
		if STREAKS_SHADER != null:
			var mat := ShaderMaterial.new()
			mat.shader = STREAKS_SHADER
			mat.set_shader_parameter("primary_color", Color(1.0, 0.85, 0.25))
			mat.set_shader_parameter("secondary_color", Color(1.0, 0.45, 0.15))
			mat.set_shader_parameter("emission", 3.8)
			fx.material_override = mat
		fx.visible = false
		add_child(fx)
		attack_fx_pool.append(fx)

	target_ring_mesh = MeshInstance3D.new()
	target_ring_mesh.name = "TargetLockRing"
	var lock_torus := TorusMesh.new()
	lock_torus.inner_radius = 0.84
	lock_torus.outer_radius = 0.94
	lock_torus.rings = 24
	lock_torus.ring_segments = 6
	target_ring_mesh.mesh = lock_torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.28, 0.18) # High-visibility targeting orange-red
	target_ring_mesh.material_override = ring_mat
	target_ring_mesh.position = Vector3(0.0, 0.07, 0.0)
	target_ring_mesh.visible = false
	add_child(target_ring_mesh)

	# 4 sleek targeting bracket markers at 90-degree intervals
	for b_i: int in range(4):
		var bracket := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.03, 0.22)
		bracket.mesh = bm
		bracket.material_override = ring_mat
		var b_angle: float = float(b_i) * (PI * 0.5)
		bracket.position = Vector3(cos(b_angle) * 0.96, 0.01, sin(b_angle) * 0.96)
		bracket.rotation = Vector3(0.0, -b_angle, 0.0)
		target_ring_mesh.add_child(bracket)

	server.state_ticked.connect(_on_server_state_ticked)
	server.attack_performed.connect(_on_server_attack_performed)
	server.block_damaged.connect(_on_server_block_damaged)
	server.part_dropped.connect(_on_server_part_dropped)
	server.part_picked_up.connect(_on_server_part_picked_up)
	server.combatant_slots_changed.connect(_on_server_combatant_slots_changed)
	server.abomination_changed.connect(_on_server_abomination_changed)
	server.frenzy_started.connect(_on_server_frenzy_started)
	server.arena_ring_collapsed.connect(_on_server_arena_ring_collapsed)
	server.map_theme_changed.connect(_on_server_map_theme_changed)
	server.combatant_lives_changed.connect(_on_server_combatant_lives_changed)
	server.combatant_eliminated.connect(_on_server_combatant_eliminated)
	server.match_ended.connect(_on_server_match_ended)
	server.match_restarted.connect(_on_server_match_restarted)
	server.combatant_body_changed.connect(_on_server_combatant_body_changed)
	server.limb_severed.connect(_on_server_limb_severed)
	server.limb_bonk.connect(_on_server_limb_bonk)
	server.part_expired.connect(_on_server_part_expired)

## How a fighter's body pieces look once detached: its model and colours.
func _resolve_fighter_visual_info(fighter_id: int) -> Dictionary:
	if fighter_id < 0 or fighter_id >= fighter_nodes.size():
		return {}
	var fn: BlockyFighter3D = fighter_nodes[fighter_id]
	return {
		"scene": fn.get_model_scene(),
		"tint": fn.get_limb_tint_color(),
		"tint_amount": fn.get_limb_tint_amount(),
	}

func _apply_body_state(combatant_id: int) -> void:
	if combatant_id < 0 or combatant_id >= fighter_nodes.size() or combatant_id >= server.combatants.size():
		return
	var c: MatchServer.CombatantState = server.combatants[combatant_id]
	var held: Dictionary = {}
	if c.held_limb_slot >= 0:
		held = _resolve_fighter_visual_info(c.held_limb_owner_id)
		if held.is_empty():
			held = _resolve_fighter_visual_info(combatant_id)
	var grafts: Dictionary = {}
	for key: Variant in c.graft_owners.keys():
		var info: Dictionary = _resolve_fighter_visual_info(int(c.graft_owners[key]))
		if not info.is_empty():
			grafts[key] = info
	fighter_nodes[combatant_id].apply_body_state(c.held_limb_slot, held, grafts)

func _on_server_combatant_body_changed(combatant_id: int) -> void:
	_apply_body_state(combatant_id)

const COMIC_FEEDBACK_RADIUS: float = 11.0

## Twelve fighters pop limbs all over the arena: only what happens around the player gets
## text and sound, so the screen and the mix stay readable.
func _is_near_player(pos_xz: Vector2) -> bool:
	if server == null or server.combatants.is_empty():
		return false
	return server.combatants[0].pos.distance_to(pos_xz) <= COMIC_FEEDBACK_RADIUS

func _pick_comic(keys: Array[StringName]) -> String:
	return tr(keys[randi() % keys.size()])

func _on_server_limb_severed(victim_id: int, attacker_id: int, _slot: int, pos_xz: Vector2) -> void:
	var involves_player: bool = attacker_id == 0 or victim_id == 0
	if not involves_player and not _is_near_player(pos_xz):
		return
	if arena_builder != null:
		arena_builder.spawn_impact_sparks(pos_xz, 6)
		arena_builder.spawn_dust_puff(Vector3(pos_xz.x, 0.9, pos_xz.y), 2, 0.3)
		arena_builder.spawn_comic_text(Vector3(pos_xz.x, 2.6, pos_xz.y), _pick_comic([&"COMIC_LIMB_POP_1", &"COMIC_LIMB_POP_2", &"COMIC_LIMB_POP_3"]), Color(1.0, 0.95, 0.45), 0.9)
	if sound_controller != null:
		sound_controller.play_limb_pop_sfx()
	if involves_player:
		camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.35)
		if attacker_id == 0:
			trigger_hit_stop(0.06, 0.10)

func _on_server_limb_bonk(attacker_id: int, target_id: int, limb_slot: int, pos_xz: Vector2, broke: bool) -> void:
	if attacker_id >= 0 and attacker_id < fighter_nodes.size():
		fighter_nodes[attacker_id].trigger_bonk_squash()
	var is_ko: bool = target_id >= 0 and target_id < server.combatants.size() and not server.combatants[target_id].alive
	if attacker_id != 0 and target_id != 0 and not _is_near_player(pos_xz):
		return
	if arena_builder != null:
		arena_builder.spawn_impact_star(pos_xz, true)
		var txt: String = tr(&"COMIC_KO") if is_ko else _pick_comic([&"COMIC_BONK_1", &"COMIC_BONK_2", &"COMIC_BONK_3", &"COMIC_BONK_4"])
		var col: Color = Color(1.0, 0.30, 0.55) if limb_slot == int(PartData.Slot.LEGS) else Color(1.0, 0.72, 0.15)
		arena_builder.spawn_comic_text(Vector3(pos_xz.x, 2.9, pos_xz.y), txt, col, 1.25 if attacker_id == 0 else 0.95)
		if broke and attacker_id >= 0 and attacker_id < server.combatants.size():
			var a_pos: Vector2 = server.combatants[attacker_id].pos
			arena_builder.spawn_impact_debris(a_pos, 4)
			arena_builder.spawn_comic_text(Vector3(a_pos.x, 3.3, a_pos.y), tr(&"COMIC_CLUB_BREAK"), Color(0.92, 0.92, 1.0), 0.85)
	if sound_controller != null:
		sound_controller.play_bonk_sfx()
		if broke:
			sound_controller.play_club_break_sfx()
	if attacker_id == 0:
		camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.45)
		trigger_hit_stop(0.075, 0.07)
		if hud != null:
			hud.trigger_impact_speed_lines(0.22)
	elif target_id == 0:
		camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.40)

func _on_server_part_expired(drop_id: int, pos_xz: Vector2) -> void:
	if arena_builder != null:
		arena_builder.expire_dropped_part_visual(drop_id, pos_xz)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)

	customization_menu = CustomizationMenuScript.new()
	customization_menu.name = "CustomizationMenu"
	customization_menu.sound_controller = sound_controller
	customization_menu.visible = is_customizing
	customization_menu.part_selected.connect(_on_custom_part_selected)
	customization_menu.color_selected.connect(_on_custom_color_selected)
	customization_menu.hero_rotated.connect(_on_custom_hero_rotated)
	customization_menu.play_pressed.connect(_on_custom_play_pressed)
	layer.add_child(customization_menu)
	var menu_social: Variant = customization_menu.get("social")
	if menu_social != null:
		# Screenshot and preview runs must never write into the player's real save.
		if _screenshot_path != "":
			menu_social.persistence_enabled = false
		menu_social.inventory_changed.connect(_apply_player_skin)
	_apply_player_skin(false)
	_stage_menu_preview()

	virtual_joystick = TouchJoystick.new()
	virtual_joystick.name = "VirtualJoystick"
	virtual_joystick.deadzone = balance.joystick_deadzone
	virtual_joystick.max_radius_px = balance.joystick_max_radius_px
	virtual_joystick.visible = not is_customizing
	layer.add_child(virtual_joystick)
	virtual_joystick.joystick_updated.connect(_on_joystick_updated)
	virtual_joystick.ability_triggered.connect(_on_ability_triggered)
	virtual_joystick.attack_triggered.connect(_on_attack_triggered)

	hud = VerticalHUD.new()
	hud.name = "VerticalHUD"
	hud.sound_controller = sound_controller
	hud.visible = not is_customizing
	layer.add_child(hud)
	hud.rematch_requested.connect(_on_hud_rematch_requested)
	hud.customize_requested.connect(_on_hud_customize_requested)
	hud.leave_match_requested.connect(_on_hud_leave_match_requested)
	if not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		hud.on_player_slots_updated(p0.slots, p0.is_abomination, p0.total_mass)
		hud.on_collected_parts_updated(p0.collected_parts, p0.stolen_parts_count)

func trigger_hit_stop(duration_sec: float, time_scale_val: float = 0.12) -> void:
	if _screenshot_path != "":
		# Keep frame capture deterministic during automated screenshot runs
		return
	_hit_stop_id += 1
	var my_id: int = _hit_stop_id
	hit_stop_active = true
	Engine.time_scale = time_scale_val
	# ignore_time_scale = true (4th parameter) so Engine.time_scale always restores cleanly (game-feel skill)
	var timer: SceneTreeTimer = get_tree().create_timer(duration_sec, true, false, true)
	timer.timeout.connect(func() -> void:
		if my_id == _hit_stop_id:
			Engine.time_scale = 1.0
			hit_stop_active = false
	)

func trigger_kill_cam(focus_xz: Vector2, duration_sec: float = 0.36) -> void:
	kill_cam_focus_xz = focus_xz
	kill_cam_timer = duration_sec

func _on_hud_rematch_requested() -> void:
	server.request_rematch()

func _on_joystick_updated(vec: Vector2) -> void:
	_joystick_vec = vec
	_mark_web_first_input()

func _on_attack_triggered() -> void:
	_attack_queued = true
	_mark_web_first_input()
	if hud != null and hud.intro_tutorial_timer > 1.2:
		hud.intro_tutorial_timer = minf(hud.intro_tutorial_timer, 0.8)

func _trigger_dash_juice() -> void:
	if server == null or server.combatants.is_empty():
		return
	var p0: MatchServer.CombatantState = server.combatants[0]
	if p0.dash_cooldown > 0.1:
		return
	var back_dir: Vector2 = -p0.vel.normalized() if p0.vel.length_squared() > 0.01 else -Vector2(cos(p0.facing_angle), sin(p0.facing_angle))
	if arena_builder != null:
		arena_builder.spawn_dash_dust(Vector3(p0.pos.x, 0.0, p0.pos.y), back_dir)
	camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.12)

func _on_ability_triggered() -> void:
	_ability_queued = true
	if sound_controller != null:
		sound_controller.play_dash_sfx()
	_trigger_dash_juice()
	_mark_web_first_input()
	if hud != null and hud.intro_tutorial_timer > 1.2:
		hud.intro_tutorial_timer = minf(hud.intro_tutorial_timer, 0.8)

func _physics_process(_delta: float) -> void:
	if is_customizing:
		return
	var kb_vec: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", balance.joystick_deadzone)
	var combined: Vector2 = _joystick_vec if _joystick_vec.length_squared() > kb_vec.length_squared() else kb_vec
	if Input.is_action_just_pressed(&"attack_action"):
		_attack_queued = true
	if Input.is_action_just_pressed(&"ability_action"):
		_ability_queued = true
		if sound_controller != null:
			sound_controller.play_dash_sfx()
		_trigger_dash_juice()
	if combined.length_squared() > 0.001 or _ability_queued or _attack_queued:
		_mark_web_first_input()
		if hud != null and hud.intro_tutorial_timer > 1.2 and combined.length_squared() > 0.05:
			hud.intro_tutorial_timer = minf(hud.intro_tutorial_timer, 0.8)

	_last_raw_move_input = combined
	var move_to_submit := combined
	if balance.camera_rotation_enabled and combined.length_squared() > 0.001:
		var cam_forward_2d := Vector2(-sin(current_cam_yaw), -cos(current_cam_yaw))
		var cam_right_2d := Vector2(cos(current_cam_yaw), -sin(current_cam_yaw))
		move_to_submit = cam_right_2d * combined.x + cam_forward_2d * (-combined.y)
		move_to_submit = move_to_submit.limit_length(1.0)

	server.submit_client_input(0, move_to_submit, _ability_queued, _attack_queued)
	_ability_queued = false
	_attack_queued = false

func _process(delta: float) -> void:
	_frame_counter += 1
	if OS.has_feature("web"):
		_update_web_telemetry()

	if is_customizing:
		_custom_stage_time += delta
		var lobby_companions: Array[Dictionary] = []
		if customization_menu != null:
			var soc: Variant = customization_menu.get("social")
			if soc != null:
				for lm: Dictionary in soc.lobby_members:
					if not bool(lm.get("is_host", false)):
						lobby_companions.append(lm)
		var comp_offsets: Array[Vector3] = [
			Vector3(-0.95, 0.0, -0.45),
			Vector3(0.95, 0.0, -0.45),
			Vector3(0.0, 0.0, -0.85),
		]
		for i: int in range(1, fighter_nodes.size()):
			var comp_idx: int = i - 1
			if comp_idx < lobby_companions.size() and comp_idx < comp_offsets.size():
				fighter_nodes[i].visible = true
				fighter_nodes[i].position = comp_offsets[comp_idx]
				fighter_nodes[i].rotation = Vector3(0.0, 0.25 if comp_idx == 0 else -0.25, 0.0)
			else:
				fighter_nodes[i].visible = false

		if customize_light_shaft != null:
			customize_light_shaft.rotation.y += delta * 0.35
		for cube_data: Dictionary in customize_floating_cubes:
			var c_node: MeshInstance3D = cube_data["node"]
			var b_pos: Vector3 = cube_data["base_pos"]
			var spd: float = cube_data["spd"]
			var amp: float = cube_data["amp"]
			var phase: float = cube_data["phase"]
			c_node.position.y = b_pos.y + sin(_custom_stage_time * spd + phase) * amp
			c_node.rotation.x += delta * (0.8 + 0.3 * sin(phase))
			c_node.rotation.y += delta * (1.1 + 0.4 * cos(phase))

		if not fighter_nodes.is_empty():
			var fn: BlockyFighter3D = fighter_nodes[0]
			fn.global_position = Vector3(0.0, 0.0, 0.0)
			fn.update_visual_state(Vector2.ZERO, Vector2.ZERO, PI * 0.5, 0.0, 0.0, true, delta, false)
			var breath_y: float = sin(_custom_stage_time * 2.6) * 0.024
			if fn.pivot != null:
				fn.pivot.position.y = breath_y
				fn.pivot.rotation.y = _custom_hero_yaw
		if _screenshot_path != "" and _frame_counter >= _target_screenshot_frame:
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(_screenshot_path)
			get_tree().quit(0)
		return

	var alpha: float = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	for i: int in range(server.combatants.size()):
		var c: MatchServer.CombatantState = server.combatants[i]
		var fn: BlockyFighter3D = fighter_nodes[i]
		var interp_xz: Vector2 = c.prev_pos.lerp(c.pos, alpha)
		var ko_tumble: bool = (not c.alive) and (c.respawn_timer > balance.respawn_delay_sec - 0.75)
		fn.update_visual_state(interp_xz, c.vel, c.facing_angle, c.attack_anim_timer, c.hurt_anim_timer, c.alive, delta, ko_tumble)

	_update_camera_follow(delta)
	_update_target_ring()
	arena_builder.sync_dropped_parts(server.dropped_parts, delta, server.match_elapsed_sec)
	arena_builder.update_arena_vfx(delta, current_cam_yaw)
	_update_attack_fx(delta)
	if hud != null:
		hud.update_overhead_combatants(server.combatants, camera)

	if _screenshot_path != "" and _frame_counter >= _target_screenshot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_screenshot_path)
		get_tree().quit(0)

func _update_camera_follow(dt: float) -> void:
	if is_customizing or _camera_transitioning or server.combatants.is_empty():
		return
	var player_state: MatchServer.CombatantState = server.combatants[0]
	var focus_pos: Vector2 = player_state.pos
	var desired_fov: float = balance.camera_fov_deg
	if kill_cam_timer > 0.0:
		kill_cam_timer = maxf(0.0, kill_cam_timer - dt)
		focus_pos = player_state.pos.lerp(kill_cam_focus_xz, 0.14)
		desired_fov = balance.camera_fov_deg - 2.4
	camera.fov = lerpf(camera.fov, desired_fov, minf(1.0, 12.0 * dt))

	if balance.camera_rotation_enabled:
		if kill_cam_timer > 0.0:
			var to_killer: Vector2 = kill_cam_focus_xz - player_state.pos
			if to_killer.length_squared() > 0.1:
				target_cam_yaw = -to_killer.angle() - PI * 0.5
		elif not (_last_raw_move_input.y > 0.35 and absf(_last_raw_move_input.x) < 0.50):
			target_cam_yaw = -player_state.facing_angle - PI * 0.5
		var t_yaw: float = 1.0 - exp(-balance.camera_rotation_smooth_rate * dt)
		current_cam_yaw = lerp_angle(current_cam_yaw, target_cam_yaw, t_yaw)
	else:
		current_cam_yaw = 0.0

	var safe_b: Vector2 = server.get_safe_bounds_xz()
	var clamped_focus_x: float = clampf(focus_pos.x, -safe_b.x + 1.5, safe_b.x - 1.5)
	var clamped_focus_z: float = clampf(focus_pos.y, -safe_b.y + 1.5, safe_b.y - 1.5)

	var cam_forward_dir := Vector3(-sin(current_cam_yaw), 0.0, -cos(current_cam_yaw))
	var look_ahead: Vector3 = cam_forward_dir * (balance.camera_look_ahead_dist if balance.camera_rotation_enabled else 0.0)
	var focus_3d := Vector3(clamped_focus_x, 0.7, clamped_focus_z) + look_ahead

	var cam_back_offset := Vector3(sin(current_cam_yaw) * balance.camera_z_bias, balance.camera_distance, cos(current_cam_yaw) * balance.camera_z_bias)
	var desired_cam_pos: Vector3 = focus_3d + cam_back_offset

	var t_pos: float = 1.0 - exp(-balance.camera_smooth_rate * dt)
	var base_cam_pos: Vector3 = camera.position.lerp(desired_cam_pos, t_pos)

	var shake_off := Vector3.ZERO
	if camera_shake_trauma > 0.0 and (hud == null or hud.screen_shake_enabled):
		camera_shake_trauma = maxf(0.0, camera_shake_trauma - 2.8 * dt)
		var amt: float = camera_shake_trauma * camera_shake_trauma * 0.28
		var cam_right_dir := Vector3(cos(current_cam_yaw), 0.0, -sin(current_cam_yaw))
		shake_off = cam_right_dir * (sin(float(_frame_counter) * 1.9) * amt) + Vector3(0.0, cos(float(_frame_counter) * 2.3) * amt, 0.0)

	camera.position = base_cam_pos + shake_off
	camera.rotation_degrees = Vector3(balance.camera_pitch_deg, rad_to_deg(current_cam_yaw), 0.0)

func _update_target_ring() -> void:
	if target_ring_mesh == null or server == null:
		return
	var nearest: MatchServer.CombatantState = server.find_nearest_enemy(0, balance.auto_attack_range * 1.35)
	if nearest != null and nearest.alive:
		target_ring_mesh.visible = true
		target_ring_mesh.position = Vector3(nearest.pos.x, 0.06, nearest.pos.y)
		target_ring_mesh.rotate_y(0.05)
	else:
		target_ring_mesh.visible = false

func _on_server_state_ticked(time_left: float) -> void:
	if hud != null:
		hud.on_match_time_updated(time_left)
		if not server.combatants.is_empty():
			var p0: MatchServer.CombatantState = server.combatants[0]
			hud.on_collected_parts_updated(p0.collected_parts, p0.stolen_parts_count)
	if virtual_joystick != null and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		virtual_joystick.attack_cooldown_timer = p0.attack_cooldown
		virtual_joystick.attack_max_cooldown = maxf(0.1, balance.auto_attack_cooldown_sec * p0.cooldown_mult)
		virtual_joystick.dash_cooldown_timer = p0.dash_cooldown
		virtual_joystick.dash_max_cooldown = maxf(0.1, balance.dash_cooldown_sec * p0.cooldown_mult)

func _on_server_attack_performed(attacker_id: int, target_id: int, from_xz: Vector2, to_xz: Vector2, _damage: int) -> void:
	var is_ko: bool = (target_id >= 0 and target_id < server.combatants.size() and not server.combatants[target_id].alive)

	var beam_col := Color(1.0, 0.85, 0.25) # Default golden spark
	var sec_col := Color(1.0, 0.45, 0.15)
	if attacker_id >= 0 and attacker_id < server.combatants.size():
		var att: MatchServer.CombatantState = server.combatants[attacker_id]
		if att.is_abomination:
			beam_col = Color(1.0, 0.18, 0.58) # Abomination magenta
			sec_col = Color(0.70, 0.10, 0.90) # Dark violet
		elif att.slots.get(PartData.Slot.HEAD, &"") == &"laser_eye":
			beam_col = Color(0.20, 0.90, 1.00) # Cyber cyan beam
			sec_col = Color(0.10, 0.45, 1.00)
		elif att.slots.get(PartData.Slot.ARMS, &"") == &"chainsaw_arm":
			beam_col = Color(1.0, 0.55, 0.10) # Spark orange
			sec_col = Color(1.0, 0.20, 0.05)
		elif att.slots.get(PartData.Slot.ARMS, &"") == &"mega_claws":
			beam_col = Color(0.95, 0.15, 0.25) # Crimson claw slash
			sec_col = Color(0.50, 0.05, 0.10)

	if arena_builder != null:
		arena_builder.spawn_statusfx_muzzle_flash(from_xz, beam_col)
		arena_builder.spawn_statusfx_impact(to_xz, is_ko, beam_col)

	if attacker_id == 0:
		if is_ko:
			camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.52)
			trigger_hit_stop(0.085, 0.08)
			trigger_kill_cam(to_xz, 0.36)
			if sound_controller != null:
				sound_controller.play_kill_sfx()
			if hud != null:
				hud.trigger_impact_speed_lines(0.36)
		else:
			camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.28)
			trigger_hit_stop(0.045, 0.15)
			if sound_controller != null:
				sound_controller.play_hit_sfx()
	elif target_id == 0:
		camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.32)

	if not attack_fx_pool.is_empty():
		var fx: MeshInstance3D = attack_fx_pool.pop_back()
		var smat := fx.material_override as ShaderMaterial
		if smat != null:
			smat.set_shader_parameter("primary_color", beam_col)
			smat.set_shader_parameter("secondary_color", sec_col)
		var mid: Vector2 = (from_xz + to_xz) * 0.5
		var dist: float = maxf(from_xz.distance_to(to_xz), 0.4)
		fx.visible = true
		fx.position = Vector3(mid.x, 1.35, mid.y)
		fx.scale = Vector3(1.0, 1.0, dist)
		var dir: Vector2 = (to_xz - from_xz).normalized()
		fx.rotation = Vector3(0.0, -dir.angle() + PI * 0.5, 0.0)
		active_attack_fx.append({"node": fx, "ttl": 0.12})

func _on_server_block_damaged(cell: Vector2i, remaining_hp: int, destroyed: bool, world_xz: Vector2) -> void:
	arena_builder.on_block_damaged(cell, remaining_hp, destroyed, world_xz)

func _on_server_part_dropped(drop_id: int, part_id: StringName, slot: int, rarity: int, pos_xz: Vector2, is_power: bool) -> void:
	var drop: MatchServer.DroppedPartState = server.get_drop_by_id(drop_id)
	var owner_id: int = drop.owner_id if drop != null else -1
	var popped: bool = drop != null and drop.vel.length_squared() > 0.5
	arena_builder.spawn_dropped_part_visual(drop_id, part_id, slot, rarity, pos_xz, is_power, owner_id, popped)

func _on_server_part_picked_up(drop_id: int, collector_id: int, part_id: StringName, slot: int, rarity: int, pos_xz: Vector2) -> void:
	var collector_node: BlockyFighter3D = null
	if collector_id >= 0 and collector_id < fighter_nodes.size():
		collector_node = fighter_nodes[collector_id]

	var in_flight: int = int(_flying_parts_in_flight.get(collector_id, 0)) + 1
	_flying_parts_in_flight[collector_id] = in_flight

	var on_part_arrived := func() -> void:
		var rem: int = int(_flying_parts_in_flight.get(collector_id, 1)) - 1
		if rem <= 0:
			_flying_parts_in_flight.erase(collector_id)
		else:
			_flying_parts_in_flight[collector_id] = rem

		if collector_node != null and is_instance_valid(collector_node):
			if _pending_combatant_slots.has(collector_id):
				var ps: Dictionary = _pending_combatant_slots[collector_id]
				collector_node.apply_slots(ps["slots"], ps["abom"], true)
				_pending_combatant_slots.erase(collector_id)
			else:
				collector_node.trigger_transform_pop()
			_apply_body_state(collector_id)

		if PartCatalog.is_limb(part_id) and arena_builder != null and collector_id >= 0 and collector_id < server.combatants.size():
			# Loose limb grabbed: either swung as a club or snapped back onto the body.
			var cs: MatchServer.CombatantState = server.combatants[collector_id]
			var comic_key: StringName = &"COMIC_REATTACH"
			if cs.held_limb_slot == slot:
				comic_key = &"COMIC_WIELD_LEG" if slot == int(PartData.Slot.LEGS) else &"COMIC_WIELD_ARM"
			if collector_id == 0 or _is_near_player(cs.pos):
				arena_builder.spawn_comic_text(Vector3(cs.pos.x, 3.1, cs.pos.y), tr(comic_key), Color(0.55, 1.0, 0.70), 1.1 if collector_id == 0 else 0.8)

		if collector_id == 0:
			camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.65)
			trigger_hit_stop(0.12, 0.05)
			trigger_kill_cam(pos_xz, 0.35)
			if sound_controller != null:
				sound_controller.play_steal_stinger()
			if hud != null:
				hud.show_part_stolen_banner(part_id, rarity, slot)

	if collector_node != null and is_instance_valid(collector_node):
		arena_builder.spawn_flying_part(drop_id, part_id, slot, rarity, pos_xz, collector_node, on_part_arrived)
	else:
		arena_builder.remove_dropped_part_visual(drop_id, pos_xz)
		on_part_arrived.call()

func _on_server_combatant_slots_changed(combatant_id: int, slots: Dictionary, is_abomination: bool, total_mass: int) -> void:
	if combatant_id == 0 and hud != null:
		hud.on_player_slots_updated(slots, is_abomination, total_mass)
		if not server.combatants.is_empty():
			var p0: MatchServer.CombatantState = server.combatants[0]
			hud.on_collected_parts_updated(p0.collected_parts, p0.stolen_parts_count)

	if _flying_parts_in_flight.has(combatant_id):
		# Stash pending slots until flying projectile impacts body
		_pending_combatant_slots[combatant_id] = {
			"slots": slots.duplicate(),
			"abom": is_abomination,
			"mass": total_mass,
		}
	else:
		if combatant_id >= 0 and combatant_id < fighter_nodes.size():
			fighter_nodes[combatant_id].apply_slots(slots, is_abomination, true)

func _on_server_abomination_changed(combatant_id: int, active: bool, _pos_xz: Vector2) -> void:
	if active and sound_controller != null:
		sound_controller.play_abomination_stinger()
	elif not active and combatant_id == 0 and sound_controller != null:
		sound_controller.set_music_intensity(&"frenzy" if server.is_frenzy_active() else &"normal")

func _on_server_frenzy_started() -> void:
	camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.55)
	if sound_controller != null:
		sound_controller.set_music_intensity(&"frenzy")
	if hud != null:
		hud.on_frenzy_started()

func _on_server_arena_ring_collapsed(_ring_index: int, collapsed_cells: Array[Vector2i], safe_bounds_xz: Vector2) -> void:
	camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.45)
	arena_builder.on_arena_ring_collapsed(collapsed_cells, safe_bounds_xz, server)

func _on_server_map_theme_changed(theme: int) -> void:
	arena_builder.apply_theme_materials(theme as MatchServer.MapTheme)
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null and we.environment.sky != null:
		var sky_mat: ProceduralSkyMaterial = we.environment.sky.sky_material as ProceduralSkyMaterial
		if sky_mat != null:
			match theme:
				MatchServer.MapTheme.CYBER_FACTORY:
					sky_mat.sky_top_color = Color(0.12, 0.16, 0.24)
					sky_mat.sky_horizon_color = Color(0.24, 0.32, 0.42)
				MatchServer.MapTheme.FLOATING_HEX:
					sky_mat.sky_top_color = Color(0.22, 0.48, 0.86)
					sky_mat.sky_horizon_color = Color(0.65, 0.78, 0.95)
				_:
					sky_mat.sky_top_color = Color(0.26, 0.42, 0.96)
					sky_mat.sky_horizon_color = Color(0.66, 0.70, 1.0)

func _on_server_combatant_lives_changed(combatant_id: int, lives: int) -> void:
	if combatant_id == 0 and hud != null:
		hud.on_player_lives_updated(lives)

func _on_server_combatant_eliminated(combatant_id: int, rank: int) -> void:
	if combatant_id == 0 and hud != null:
		hud.on_player_eliminated(rank)

func _on_server_match_ended(leaderboard: Array[Dictionary], player_rank: int) -> void:
	if customization_menu != null:
		var soc: Variant = customization_menu.get("social")
		if soc != null and server != null:
			soc.record_match_opponents(server.combatants)
			if not server.combatants.is_empty():
				var p0: MatchServer.CombatantState = server.combatants[0]
				soc.record_match_result(p0.stolen_parts_count, p0.is_abomination, player_rank, p0.kills)
				# Season Pass XP and coins for the match, shown on the result screen.
				var rewards: Dictionary = MatchRewards.compute(balance, player_rank, p0.kills, p0.stolen_parts_count, p0.is_abomination)
				var summary: Dictionary = soc.grant_match_rewards(rewards)
				if hud != null:
					hud.show_match_rewards(summary, int(soc.season_xp_max))
	if hud != null:
		hud.on_match_ended(leaderboard, player_rank, balance.result_screen_duration_sec)

func _on_server_match_restarted() -> void:
	current_cam_yaw = 0.0
	target_cam_yaw = 0.0
	arena_builder.build_from_server(server)
	for i: int in range(server.combatants.size()):
		var c: MatchServer.CombatantState = server.combatants[i]
		if i < fighter_nodes.size():
			fighter_nodes[i].apply_slots(c.slots, c.is_abomination, false)
			_apply_body_state(i)
			fighter_nodes[i].update_visual_state(c.pos, c.vel, c.facing_angle, 0.0, 0.0, c.alive, 0.016)
	if sound_controller != null:
		sound_controller.set_music_intensity(&"normal")
	if hud != null and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		hud.on_player_slots_updated(p0.slots, p0.is_abomination, p0.total_mass)
		hud.on_stolen_parts_updated(p0.stolen_parts_count)
		hud.on_match_restarted()

func _update_attack_fx(dt: float) -> void:
	var idx: int = active_attack_fx.size() - 1
	while idx >= 0:
		var item: Dictionary = active_attack_fx[idx]
		var fx: MeshInstance3D = item["node"]
		var ttl: float = float(item["ttl"]) - dt
		if ttl <= 0.0:
			fx.visible = false
			attack_fx_pool.append(fx)
			active_attack_fx.remove_at(idx)
		else:
			item["ttl"] = ttl
		idx -= 1

func _mark_web_first_input() -> void:
	if OS.has_feature("web") and not _web_first_input_reported:
		_web_first_input_reported = true
		JavaScriptBridge.eval("if(window.__spliceRushMetrics && !window.__spliceRushMetrics.firstInputMs){window.__spliceRushMetrics.firstInputMs=performance.now()-window.__spliceRushMetrics.navStart;}")

func _update_web_telemetry() -> void:
	if not _web_first_frame_reported and _frame_counter >= 2:
		_web_first_frame_reported = true
		JavaScriptBridge.eval("if(window.__spliceRushMetrics && !window.__spliceRushMetrics.firstFrameMs){window.__spliceRushMetrics.firstFrameMs=performance.now()-window.__spliceRushMetrics.navStart;}")
	if _frame_counter % 15 == 0:
		var fps: float = Engine.get_frames_per_second()
		var dc: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		JavaScriptBridge.eval("if(window.__spliceRushMetrics){window.__spliceRushMetrics.fpsSamples.push(%.1f);window.__spliceRushMetrics.drawCalls=%d;}" % [fps, int(dc)])

## Screenshot staging for the menu screens: --preview-menu=shop|pass|pass-xp|missions,
## optional --preview-scroll=<px> and --preview-skin=<skin id>. Never saves.
func _stage_menu_preview() -> void:
	if customization_menu == null or (_preview_menu == "" and _preview_skin == ""):
		return
	var soc: SocialManager = customization_menu.get("social") as SocialManager
	if soc == null:
		return
	soc.persistence_enabled = false
	if _preview_skin != "" and EconomyCatalog.has_skin(_preview_skin):
		soc.unlock_skin(_preview_skin)
		soc.equip_skin(_preview_skin)
	var shop: ShopScreen = customization_menu.get("shop_screen") as ShopScreen
	var pass_modal: SeasonPassModal = customization_menu.get("season_pass_modal") as SeasonPassModal
	match _preview_menu:
		"shop":
			shop.open()
			if _preview_scroll >= 0.0:
				shop.scroll_to(_preview_scroll, false)
		"pass", "pass-xp", "missions":
			if _preview_menu == "pass-xp":
				soc.grant_match_rewards(MatchRewards.compute(balance, 1, 6, 5, true))
			pass_modal.open(SeasonPassModal.TAB_MISSIONS if _preview_menu == "missions" else SeasonPassModal.TAB_REWARDS)
			if _preview_scroll >= 0.0:
				pass_modal.scroll_to(_preview_scroll, false)

## Dresses the player's fighter in the skin equipped in the shop or the Season Pass.
func _apply_player_skin(animate: bool = true) -> void:
	if fighter_nodes.is_empty() or customization_menu == null:
		return
	var soc: Variant = customization_menu.get("social")
	if soc == null:
		return
	var skin: Dictionary = EconomyCatalog.get_skin(str(soc.equipped_skin))
	var fn: BlockyFighter3D = fighter_nodes[0]
	if fn.skin_id == str(skin["id"]):
		return
	fn.apply_skin(skin)
	_apply_body_state(0)
	if animate:
		fn.trigger_transform_pop()

func _on_custom_part_selected(slot: int, part_id: StringName) -> void:
	if fighter_nodes.is_empty() or customization_menu == null:
		return
	var fn: BlockyFighter3D = fighter_nodes[0]
	var slots: Dictionary = customization_menu.equipped_slots.duplicate()
	slots[slot] = part_id
	fn.apply_slots(slots, false, true)
	fn.trigger_transform_pop()
	if sound_controller != null:
		sound_controller.play_equip_sfx()

func _on_custom_color_selected(col: Color) -> void:
	if fighter_nodes.is_empty():
		return
	var fn: BlockyFighter3D = fighter_nodes[0]
	if fn.char_mesh != null:
		var mat: Material = fn.char_mesh.get_surface_override_material(0)
		if mat is ShaderMaterial:
			mat.set_shader_parameter("base_color", col)
		elif mat is StandardMaterial3D:
			mat.albedo_color = col
	fn.trigger_transform_pop()
	if sound_controller != null:
		sound_controller.play_equip_sfx()

func _on_custom_hero_rotated(dx: float) -> void:
	_custom_hero_yaw += dx * 0.018

func _on_custom_play_pressed(slots: Dictionary, col: Color) -> void:
	is_customizing = false
	if customize_stage_root != null:
		customize_stage_root.visible = false
	if arena_builder != null:
		arena_builder.visible = true
	var ped: Node = arena_builder.get_node_or_null("PowerPedestal")
	if ped != null:
		ped.set("visible", true)
	if customization_menu != null:
		customization_menu.visible = false
	if hud != null:
		hud.visible = true
	if virtual_joystick != null:
		virtual_joystick.visible = true
	server.bots_enabled = true
	if customization_menu != null:
		var soc: Variant = customization_menu.get("social")
		if soc != null:
			if soc.selected_mode == "frenzy":
				server.start_new_match(55.0, true)
			var comp_slot: int = 1
			for lm: Dictionary in soc.lobby_members:
				if not bool(lm.get("is_host", false)) and comp_slot < server.combatants.size():
					server.combatants[comp_slot].display_name = str(lm.get("username", "Friend"))
					server.combatants[comp_slot].base_color = Color(str(lm.get("color_hex", "#6B4EFF")))
					comp_slot += 1
	for fn: BlockyFighter3D in fighter_nodes:
		fn.visible = true

	# Equip chosen loadout on player 0
	if not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		p0.slots = slots.duplicate()
		p0.base_color = col
		server._recalc_combatant_stats(p0, true)
	if not fighter_nodes.is_empty():
		fighter_nodes[0].apply_slots(slots, false, true)
		if fighter_nodes[0].char_mesh != null:
			var mat: Material = fighter_nodes[0].char_mesh.get_surface_override_material(0)
			if mat is ShaderMaterial:
				mat.set_shader_parameter("base_color", col)
			elif mat is StandardMaterial3D:
				mat.albedo_color = col

	# Smooth camera sweep to arena battle view
	var safe_b: Vector2 = server.get_safe_bounds_xz()
	var p0_y: float = server.combatants[0].pos.y if not server.combatants.is_empty() else 0.0
	var p0_x: float = server.combatants[0].pos.x if not server.combatants.is_empty() else 0.0
	current_cam_yaw = 0.0
	target_cam_yaw = 0.0
	var target_z: float = clampf(p0_y + balance.camera_z_bias, -safe_b.y + balance.camera_z_bias, safe_b.y + balance.camera_z_bias)
	var target_x: float = clampf(p0_x, -safe_b.x + 2.5, safe_b.x - 2.5)
	_camera_transitioning = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(camera, "position", Vector3(target_x, balance.camera_distance, target_z), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "rotation_degrees:x", balance.camera_pitch_deg, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "rotation_degrees:y", 0.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		_camera_transitioning = false
	)

	if sound_controller != null:
		sound_controller.play_steal_stinger()

func _on_hud_customize_requested() -> void:
	server.bots_enabled = false
	server.start_new_match(0.0, true)
	is_customizing = true
	_camera_transitioning = false
	kill_cam_timer = 0.0
	if customize_stage_root != null:
		customize_stage_root.visible = true
	if arena_builder != null:
		arena_builder.visible = false
	if target_ring_mesh != null:
		target_ring_mesh.visible = false
	if customization_menu != null:
		customization_menu.visible = true
		customization_menu.is_loading = false
		customization_menu.queue_redraw()
	if hud != null:
		if hud.settings_modal != null and hud.settings_modal.is_open:
			hud.settings_modal.close()
		hud.visible = false
		hud.show_result_overlay = false
		hud.queue_redraw()
	if virtual_joystick != null:
		virtual_joystick.visible = false
	current_cam_yaw = 0.0
	target_cam_yaw = 0.0
	camera.fov = balance.camera_fov_deg
	camera.position = Vector3(0.0, 1.78, 4.35)
	camera.rotation_degrees = Vector3(-14.5, 0.0, 0.0)
	if not fighter_nodes.is_empty():
		fighter_nodes[0].visible = true
		fighter_nodes[0].position = Vector3.ZERO
		fighter_nodes[0].rotation = Vector3.ZERO
		if customization_menu != null:
			fighter_nodes[0].apply_slots(customization_menu.equipped_slots, false, true)
	for i: int in range(1, fighter_nodes.size()):
		fighter_nodes[i].visible = false

func _on_hud_leave_match_requested() -> void:
	_on_hud_customize_requested()

func _setup_customization_stage() -> void:
	customize_stage_root = Node3D.new()
	customize_stage_root.name = "CustomizationPedestalStage"
	add_child(customize_stage_root)

	# 1. Stepped Cylindrical Pedestal
	var ped_base := MeshInstance3D.new()
	ped_base.name = "PedestalBase"
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = 1.75
	base_cyl.bottom_radius = 1.85
	base_cyl.height = 0.22
	ped_base.mesh = base_cyl
	ped_base.position = Vector3(0.0, -0.22, 0.0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.10, 0.08, 0.18)
	base_mat.roughness = 0.75
	ped_base.material_override = base_mat
	customize_stage_root.add_child(ped_base)

	var ped_top := MeshInstance3D.new()
	ped_top.name = "PedestalTop"
	var top_cyl := CylinderMesh.new()
	top_cyl.top_radius = 1.50
	top_cyl.bottom_radius = 1.50
	top_cyl.height = 0.18
	ped_top.mesh = top_cyl
	ped_top.position = Vector3(0.0, -0.06, 0.0)
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.36, 0.28, 0.65)
	top_mat.roughness = 0.88
	top_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ped_top.material_override = top_mat
	customize_stage_root.add_child(ped_top)

	# 2. Glowing Neon Rings on Pedestal Rim
	var rim_outer := MeshInstance3D.new()
	rim_outer.name = "RimOuter"
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 1.44
	torus_mesh.outer_radius = 1.54
	rim_outer.mesh = torus_mesh
	rim_outer.position = Vector3(0.0, 0.02, 0.0)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.albedo_color = Color(0.95, 0.88, 0.12) # Bright yellow rim
	rim_outer.material_override = rim_mat
	customize_stage_root.add_child(rim_outer)

	var rim_inner := MeshInstance3D.new()
	rim_inner.name = "RimInner"
	rim_inner.visible = false
	var torus_inner := TorusMesh.new()
	torus_inner.inner_radius = 0.88
	torus_inner.outer_radius = 0.92
	rim_inner.mesh = torus_inner
	rim_inner.position = Vector3(0.0, 0.022, 0.0)
	var inner_mat := StandardMaterial3D.new()
	inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_mat.albedo_color = Color(1.0, 0.18, 0.58) # Magenta neon ring
	rim_inner.material_override = inner_mat
	customize_stage_root.add_child(rim_inner)

	# 3. Overhead Spotlight (Faro)
	customize_spotlight = SpotLight3D.new()
	customize_spotlight.name = "StageSpotlight"
	customize_spotlight.position = Vector3(0.0, 4.4, 1.8)
	customize_spotlight.rotation_degrees = Vector3(-62.0, 0.0, 0.0)
	customize_spotlight.light_color = Color(1.0, 0.96, 0.90)
	customize_spotlight.light_energy = 2.1
	customize_spotlight.spot_range = 10.0
	customize_spotlight.spot_angle = 38.0
	customize_stage_root.add_child(customize_spotlight)

	# Fill light
	customize_fill_light = OmniLight3D.new()
	customize_fill_light.name = "StageFillLight"
	customize_fill_light.position = Vector3(0.0, 1.4, 2.5)
	customize_fill_light.light_color = Color(0.55, 0.45, 0.85)
	customize_fill_light.light_energy = 1.8
	customize_fill_light.omni_range = 6.0
	customize_stage_root.add_child(customize_fill_light)

	# 4. Radiant Light Shaft (Raggi di luce)
	customize_light_shaft = MeshInstance3D.new()
	customize_light_shaft.name = "StageLightShaft"
	var shaft_cyl := CylinderMesh.new()
	shaft_cyl.top_radius = 0.55
	shaft_cyl.bottom_radius = 1.95
	shaft_cyl.height = 5.2
	customize_light_shaft.mesh = shaft_cyl
	customize_light_shaft.position = Vector3(0.0, 2.4, -0.4)
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft_mat.albedo_color = Color(1.0, 0.82, 0.28, 0.16)
	customize_light_shaft.material_override = shaft_mat
	customize_stage_root.add_child(customize_light_shaft)

	# 5. Floating Bobbing Cubes (Cubi fluttuanti)
	customize_floating_cubes.clear()
	var cube_configs: Array[Dictionary] = [
		{ "pos": Vector3(-1.8, 1.2, -0.4), "sz": 0.20, "col": Color(1.0, 0.78, 0.15), "spd": 1.8, "amp": 0.12, "phase": 0.0 },
		{ "pos": Vector3(1.7, 1.5, -0.3), "sz": 0.18, "col": Color(1.0, 0.18, 0.58), "spd": 2.2, "amp": 0.14, "phase": 1.2 },
		{ "pos": Vector3(-1.4, 2.4, -0.8), "sz": 0.14, "col": Color(0.18, 0.88, 1.0), "spd": 1.5, "amp": 0.10, "phase": 2.5 },
		{ "pos": Vector3(1.5, 2.2, -0.7), "sz": 0.16, "col": Color(1.0, 0.78, 0.15), "spd": 1.9, "amp": 0.11, "phase": 3.8 },
		{ "pos": Vector3(-0.9, 3.1, -1.0), "sz": 0.22, "col": Color(0.75, 0.45, 1.0), "spd": 1.4, "amp": 0.15, "phase": 4.5 },
		{ "pos": Vector3(0.9, 3.3, -1.0), "sz": 0.15, "col": Color(0.25, 0.95, 0.45), "spd": 2.0, "amp": 0.12, "phase": 5.2 },
		{ "pos": Vector3(-2.1, 0.6, 0.2), "sz": 0.16, "col": Color(1.0, 0.18, 0.58), "spd": 1.6, "amp": 0.08, "phase": 1.7 },
		{ "pos": Vector3(2.0, 0.7, 0.1), "sz": 0.14, "col": Color(1.0, 0.78, 0.15), "spd": 2.4, "amp": 0.09, "phase": 3.1 },
		{ "pos": Vector3(-1.2, 0.3, 0.9), "sz": 0.12, "col": Color(0.18, 0.88, 1.0), "spd": 2.1, "amp": 0.07, "phase": 0.8 },
		{ "pos": Vector3(1.3, 0.4, 0.8), "sz": 0.13, "col": Color(0.75, 0.45, 1.0), "spd": 1.7, "amp": 0.08, "phase": 4.0 },
	]
	for cfg: Dictionary in cube_configs:
		var c_mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sz: float = cfg["sz"] as float
		bm.size = Vector3(sz, sz, sz)
		c_mesh.mesh = bm
		c_mesh.position = cfg["pos"] as Vector3
		var c_mat := StandardMaterial3D.new()
		c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c_mat.albedo_color = cfg["col"] as Color
		c_mesh.material_override = c_mat
		customize_stage_root.add_child(c_mesh)
		customize_floating_cubes.append({
			"node": c_mesh,
			"base_pos": cfg["pos"] as Vector3,
			"spd": cfg["spd"] as float,
			"amp": cfg["amp"] as float,
			"phase": cfg["phase"] as float
		})

	# 6. Spark Prisms (Scintille)
	for si: int in range(8):
		var p_mesh := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.06, 0.08, 0.06)
		p_mesh.mesh = pm
		var ang: float = float(si) * (TAU / 8.0)
		var rad: float = 1.15 + 0.35 * sin(float(si) * 2.3)
		var s_pos := Vector3(cos(ang) * rad, 0.4 + float(si % 4) * 0.4, sin(ang) * rad)
		p_mesh.position = s_pos
		var p_mat := StandardMaterial3D.new()
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.albedo_color = Color(1.0, 0.88, 0.35)
		p_mesh.material_override = p_mat
		customize_stage_root.add_child(p_mesh)
		customize_floating_cubes.append({
			"node": p_mesh,
			"base_pos": s_pos,
			"spd": 2.5 + float(si % 3) * 0.5,
			"amp": 0.15,
			"phase": float(si) * 0.8
		})

	customize_stage_root.visible = is_customizing
