class_name MainArenaController
extends Node3D

@export var balance: BalanceConfig = preload("res://shared/default_balance.tres")

var server: MatchServer
var arena_builder: ArenaBuilder3D
var sound_controller: SoundController
const CustomizationMenuScript := preload("res://game/ui/customization_menu.gd")

var camera: Camera3D
var hud: VerticalHUD
var virtual_joystick: TouchJoystick
var customization_menu: Control
var is_customizing: bool = false
var fighter_nodes: Array[BlockyFighter3D] = []
var attack_fx_pool: Array[MeshInstance3D] = []
var active_attack_fx: Array[Dictionary] = []

var camera_shake_trauma: float = 0.0
var kill_cam_timer: float = 0.0
var kill_cam_focus_xz: Vector2 = Vector2.ZERO
var hit_stop_active: bool = false
var _hit_stop_id: int = 0
var _pending_combatant_slots: Dictionary = {}
var _flying_parts_in_flight: Dictionary = {}
var target_ring_mesh: MeshInstance3D
var _custom_hero_yaw: float = 0.0

var _joystick_vec: Vector2 = Vector2.ZERO
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
var _web_first_frame_reported: bool = false
var _web_first_input_reported: bool = false

func _ready() -> void:
	_parse_cmdline_args()
	if _preview_customize:
		is_customizing = true
	elif _simulate_input_preview or _preview_frenzy or _preview_last10s or _preview_result or _preview_clip or _preview_steal_juice or _preview_tutorial_phase2 or _preview_tutorial_dismissed or _skip_customize or _requested_map_theme != -1:
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
	if _preview_tutorial_phase2 and hud != null:
		hud.intro_tutorial_timer = 2.4
		hud._intro_elapsed = 3.6
	elif _preview_tutorial_dismissed and hud != null:
		hud.intro_tutorial_timer = 0.0
		hud._intro_elapsed = 6.0
	if _simulate_input_preview and virtual_joystick != null:
		virtual_joystick.simulate_drag(Vector2(210.0, 868.0), Vector2(246.0, 832.0))

func _exit_tree() -> void:
	Engine.time_scale = 1.0

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
		elif arg == "--preview-loading":
			_preview_loading = true
		elif arg == "--preview-one-leg":
			_preview_one_leg = true
		elif arg == "--skip-customize" or arg == "--instant-match":
			_skip_customize = true

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
	# Keep rocket legs & laser eye for iconic key-art silhouette after clip steal
	p0.pos = Vector2(0.0, 4.4)
	p0.prev_pos = p0.pos
	p0.slots[PartData.Slot.LEGS] = &"rocket_legs"
	p0.slots[PartData.Slot.HEAD] = &"laser_eye"
	server._recalc_combatant_stats(p0, true)
	if hud != null:
		hud.intro_tutorial_timer = 0.0
		hud._intro_elapsed = 6.0

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
	sky_mat.sky_top_color = Color(0.38, 0.26, 0.92)     # #6B4EFF saturated violet-blue
	sky_mat.sky_horizon_color = Color(0.56, 0.42, 0.88) # Lavender-violet horizon
	sky_mat.ground_horizon_color = Color(0.42, 0.28, 0.68)
	sky_mat.ground_bottom_color = Color(0.14, 0.10, 0.28)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.36, 0.68)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.88, 0.76)
	sun.light_energy = 0.88
	sun.rotation_degrees = Vector3(-48.0, 26.0, 0.0)
	sun.shadow_enabled = false
	add_child(sun)

	var rim_dir := DirectionalLight3D.new()
	rim_dir.name = "RimLight"
	rim_dir.light_color = Color(0.68, 0.38, 0.96)
	rim_dir.light_energy = 0.32
	rim_dir.rotation_degrees = Vector3(-32.0, -145.0, 0.0)
	rim_dir.shadow_enabled = false
	add_child(rim_dir)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ArenaCamera3D"
	camera.fov = balance.camera_fov_deg
	camera.near = 0.2
	camera.far = 95.0
	if is_customizing:
		camera.position = Vector3(0.0, 1.25, 3.45)
		camera.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	else:
		camera.position = Vector3(0.0, balance.camera_distance, 15.0)
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
	arena_builder.build_from_server(server)
	if is_customizing:
		var ped: Node = arena_builder.get_node_or_null("PowerPedestal")
		if ped != null:
			ped.set("visible", false)

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

	for i: int in range(8):
		var fx := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 0.14, 1.0)
		fx.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.25)
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

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)

	customization_menu = CustomizationMenuScript.new()
	customization_menu.name = "CustomizationMenu"
	customization_menu.visible = is_customizing
	customization_menu.part_selected.connect(_on_custom_part_selected)
	customization_menu.color_selected.connect(_on_custom_color_selected)
	customization_menu.hero_rotated.connect(_on_custom_hero_rotated)
	customization_menu.play_pressed.connect(_on_custom_play_pressed)
	layer.add_child(customization_menu)

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
	hud.visible = not is_customizing
	layer.add_child(hud)
	hud.rematch_requested.connect(_on_hud_rematch_requested)
	hud.customize_requested.connect(_on_hud_customize_requested)
	if not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		hud.on_player_slots_updated(p0.slots, p0.is_abomination, p0.total_mass)
		hud.on_stolen_parts_updated(p0.stolen_parts_count)

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
	if p0.dash_cooldown > 0.1 and p0.dash_timer <= 0.0:
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
	server.submit_client_input(0, combined, _ability_queued, _attack_queued)
	_ability_queued = false
	_attack_queued = false

func _process(delta: float) -> void:
	_frame_counter += 1
	if OS.has_feature("web"):
		_update_web_telemetry()

	if is_customizing:
		if not fighter_nodes.is_empty():
			var fn: BlockyFighter3D = fighter_nodes[0]
			fn.global_position = Vector3(0.0, 0.0, 0.0)
			fn.update_visual_state(Vector2.ZERO, Vector2.ZERO, PI * 0.5, 0.0, 0.0, true, delta, false)
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
	arena_builder.sync_dropped_parts(server.dropped_parts, delta)
	arena_builder.update_arena_vfx(delta)
	_update_attack_fx(delta)
	if hud != null:
		hud.update_overhead_combatants(server.combatants, camera)

	if _screenshot_path != "" and _frame_counter >= _target_screenshot_frame:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_screenshot_path)
		get_tree().quit(0)

func _update_camera_follow(dt: float) -> void:
	if is_customizing or server.combatants.is_empty():
		return
	var player_state: MatchServer.CombatantState = server.combatants[0]
	var focus_pos: Vector2 = player_state.pos
	var desired_fov: float = balance.camera_fov_deg
	if kill_cam_timer > 0.0:
		kill_cam_timer = maxf(0.0, kill_cam_timer - dt)
		focus_pos = player_state.pos.lerp(kill_cam_focus_xz, 0.14)
		desired_fov = balance.camera_fov_deg - 2.4
	camera.fov = lerpf(camera.fov, desired_fov, minf(1.0, 12.0 * dt))

	var safe_b: Vector2 = server.get_safe_bounds_xz()
	var max_cam_x: float = maxf(4.0, safe_b.x - 4.5)
	var max_cam_z: float = maxf(6.0, safe_b.y - 4.0)
	var target_x: float = clampf(focus_pos.x * 0.82, -max_cam_x, max_cam_x)
	var target_z: float = clampf(focus_pos.y + balance.camera_z_bias, -max_cam_z + balance.camera_z_bias, max_cam_z + balance.camera_z_bias)
	var desired := Vector3(target_x, balance.camera_distance, target_z)
	var t: float = 1.0 - exp(-balance.camera_smooth_rate * dt)
	var base_cam_pos: Vector3 = camera.position.lerp(desired, t)

	var shake_off := Vector3.ZERO
	if camera_shake_trauma > 0.0 and (hud == null or hud.screen_shake_enabled):
		camera_shake_trauma = maxf(0.0, camera_shake_trauma - 2.8 * dt)
		var amt: float = camera_shake_trauma * camera_shake_trauma * 0.28
		shake_off = Vector3(sin(float(_frame_counter) * 1.9) * amt, cos(float(_frame_counter) * 2.3) * amt, 0.0)

	camera.position = base_cam_pos + shake_off
	camera.rotation_degrees = Vector3(balance.camera_pitch_deg, 0.0, 0.0)

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
			hud.on_stolen_parts_updated(server.combatants[0].stolen_parts_count)
	if virtual_joystick != null and not server.combatants.is_empty():
		var p0: MatchServer.CombatantState = server.combatants[0]
		virtual_joystick.attack_cooldown_timer = p0.attack_cooldown
		virtual_joystick.attack_max_cooldown = maxf(0.1, balance.auto_attack_cooldown_sec * p0.cooldown_mult)
		virtual_joystick.dash_cooldown_timer = p0.dash_cooldown
		virtual_joystick.dash_max_cooldown = maxf(0.1, balance.dash_cooldown_sec * p0.cooldown_mult)

func _on_server_attack_performed(attacker_id: int, target_id: int, from_xz: Vector2, to_xz: Vector2, _damage: int) -> void:
	var is_ko: bool = (target_id >= 0 and target_id < server.combatants.size() and not server.combatants[target_id].alive)
	if arena_builder != null:
		arena_builder.spawn_impact_star(to_xz, is_ko)
		arena_builder.spawn_impact_debris(to_xz, 4 if is_ko else 2)

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
	arena_builder.spawn_dropped_part_visual(drop_id, part_id, slot, rarity, pos_xz, is_power)

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
					sky_mat.sky_top_color = Color(0.38, 0.26, 0.92)
					sky_mat.sky_horizon_color = Color(0.56, 0.42, 0.88)

func _on_server_combatant_lives_changed(combatant_id: int, lives: int) -> void:
	if combatant_id == 0 and hud != null:
		hud.on_player_lives_updated(lives)

func _on_server_combatant_eliminated(combatant_id: int, rank: int) -> void:
	if combatant_id == 0 and hud != null:
		hud.on_player_eliminated(rank)

func _on_server_match_ended(leaderboard: Array[Dictionary], player_rank: int) -> void:
	if hud != null:
		hud.on_match_ended(leaderboard, player_rank, balance.result_screen_duration_sec)

func _on_server_match_restarted() -> void:
	arena_builder.build_from_server(server)
	for i: int in range(server.combatants.size()):
		var c: MatchServer.CombatantState = server.combatants[i]
		if i < fighter_nodes.size():
			fighter_nodes[i].apply_slots(c.slots, c.is_abomination, false)
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

func _on_custom_part_selected(slot: int, part_id: StringName) -> void:
	if fighter_nodes.is_empty() or customization_menu == null:
		return
	var fn: BlockyFighter3D = fighter_nodes[0]
	var slots: Dictionary = customization_menu.equipped_slots.duplicate()
	slots[slot] = part_id
	fn.apply_slots(slots, false, true)
	if sound_controller != null:
		sound_controller.play_pickup_pop()

func _on_custom_color_selected(col: Color) -> void:
	if fighter_nodes.is_empty():
		return
	var fn: BlockyFighter3D = fighter_nodes[0]
	if fn.char_mesh != null:
		var mat: Material = fn.char_mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color = col

func _on_custom_hero_rotated(dx: float) -> void:
	_custom_hero_yaw += dx * 0.018

func _on_custom_play_pressed(slots: Dictionary, col: Color) -> void:
	is_customizing = false
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
			if mat is StandardMaterial3D:
				mat.albedo_color = col

	# Smooth camera sweep to arena battle view
	var safe_b: Vector2 = server.get_safe_bounds_xz()
	var target_z: float = clampf(balance.camera_z_bias, -safe_b.y + balance.camera_z_bias, safe_b.y + balance.camera_z_bias)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(camera, "position", Vector3(0.0, balance.camera_distance, target_z), 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "rotation_degrees:x", balance.camera_pitch_deg, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if sound_controller != null:
		sound_controller.play_steal_stinger()

func _on_hud_customize_requested() -> void:
	server.reset_match()
	is_customizing = true
	if customization_menu != null:
		customization_menu.visible = true
		customization_menu.is_loading = false
	if hud != null:
		hud.visible = false
		hud.show_result_overlay = false
	if virtual_joystick != null:
		virtual_joystick.visible = false
	server.bots_enabled = false
	camera.position = Vector3(0.0, 1.45, 3.4)
	camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	if not fighter_nodes.is_empty():
		fighter_nodes[0].position = Vector3.ZERO
		fighter_nodes[0].rotation = Vector3.ZERO
	for i: int in range(1, fighter_nodes.size()):
		fighter_nodes[i].visible = false
