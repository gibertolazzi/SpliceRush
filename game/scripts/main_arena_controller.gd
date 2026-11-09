class_name MainArenaController
extends Node3D

@export var balance: BalanceConfig = preload("res://shared/default_balance.tres")

var server: MatchServer
var arena_builder: ArenaBuilder3D
var camera: Camera3D
var hud: VerticalHUD
var virtual_joystick: TouchJoystick
var fighter_nodes: Array[BlockyFighter3D] = []
var attack_fx_pool: Array[MeshInstance3D] = []
var active_attack_fx: Array[Dictionary] = []

var camera_shake_trauma: float = 0.0
var target_ring_mesh: MeshInstance3D
var _joystick_vec: Vector2 = Vector2.ZERO
var _ability_queued: bool = false
var _frame_counter: int = 0
var _screenshot_path: String = ""
var _simulate_input_preview: bool = false
var _web_first_frame_reported: bool = false
var _web_first_input_reported: bool = false

func _ready() -> void:
	_parse_cmdline_args()
	_setup_environment_and_lights()
	_setup_camera()
	_setup_server_and_world()
	_setup_ui()
	if _simulate_input_preview and virtual_joystick != null:
		virtual_joystick.simulate_drag(Vector2(210.0, 868.0), Vector2(246.0, 832.0))

func _parse_cmdline_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-screenshot="):
			_screenshot_path = arg.trim_prefix("--capture-screenshot=")
		elif arg == "--simulate-input":
			_simulate_input_preview = true

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
	camera.position = Vector3(0.0, 5.8, 10.4)
	camera.rotation_degrees = Vector3(balance.camera_pitch_deg, 0.0, 0.0)
	add_child(camera)
	camera.make_current()

func _setup_server_and_world() -> void:
	server = MatchServer.new()
	server.name = "MatchServer"
	server.balance = balance
	# For initial framing screenshot, pause bots only if --static-preview is passed
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--static-preview":
			server.bots_enabled = false
	add_child(server)

	arena_builder = ArenaBuilder3D.new()
	arena_builder.name = "ArenaBuilder3D"
	add_child(arena_builder)
	arena_builder.build_from_server(server)

	fighter_nodes.clear()
	for c: MatchServer.CombatantState in server.combatants:
		var fn := BlockyFighter3D.new()
		fn.name = "Fighter_%d" % c.id
		add_child(fn)
		fn.setup_fighter(c.id, c.is_bot, c.base_color, c.shape_id)
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
	var ring_cyl := CylinderMesh.new()
	ring_cyl.top_radius = 0.92
	ring_cyl.bottom_radius = 0.98
	ring_cyl.height = 0.05
	ring_cyl.radial_segments = 16
	target_ring_mesh.mesh = ring_cyl
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.18, 0.58)
	target_ring_mesh.material_override = ring_mat
	target_ring_mesh.visible = false
	add_child(target_ring_mesh)

	server.state_ticked.connect(_on_server_state_ticked)
	server.attack_performed.connect(_on_server_attack_performed)
	server.block_damaged.connect(_on_server_block_damaged)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)

	virtual_joystick = TouchJoystick.new()
	virtual_joystick.name = "VirtualJoystick"
	virtual_joystick.deadzone = balance.joystick_deadzone
	virtual_joystick.max_radius_px = balance.joystick_max_radius_px
	layer.add_child(virtual_joystick)
	virtual_joystick.joystick_updated.connect(_on_joystick_updated)
	virtual_joystick.ability_triggered.connect(_on_ability_triggered)

	hud = VerticalHUD.new()
	hud.name = "VerticalHUD"
	layer.add_child(hud)

func _on_joystick_updated(vec: Vector2) -> void:
	_joystick_vec = vec
	_mark_web_first_input()

func _on_ability_triggered() -> void:
	_ability_queued = true
	_mark_web_first_input()

func _physics_process(_delta: float) -> void:
	var kb_vec: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", balance.joystick_deadzone)
	var combined: Vector2 = _joystick_vec if _joystick_vec.length_squared() > kb_vec.length_squared() else kb_vec
	if Input.is_action_just_pressed(&"ability_action"):
		_ability_queued = true
	if combined.length_squared() > 0.001 or _ability_queued:
		_mark_web_first_input()
	server.submit_client_input(0, combined, _ability_queued)
	_ability_queued = false

func _process(delta: float) -> void:
	_frame_counter += 1
	if OS.has_feature("web"):
		_update_web_telemetry()

	var alpha: float = clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	for i: int in range(server.combatants.size()):
		var c: MatchServer.CombatantState = server.combatants[i]
		var fn: BlockyFighter3D = fighter_nodes[i]
		var interp_xz: Vector2 = c.prev_pos.lerp(c.pos, alpha)
		fn.update_visual_state(interp_xz, c.vel, c.facing_angle, c.attack_anim_timer, c.hurt_anim_timer, c.alive, delta)

	_update_camera_follow(delta)
	_update_target_ring()
	arena_builder.update_arena_vfx(delta)
	_update_attack_fx(delta)

	if _screenshot_path != "" and _frame_counter == 12:
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_screenshot_path)
		get_tree().quit(0)

func _update_camera_follow(dt: float) -> void:
	if server.combatants.is_empty():
		return
	var player_state: MatchServer.CombatantState = server.combatants[0]
	var target_x: float = clampf(player_state.pos.x * 0.45, -3.2, 3.2)
	var target_z: float = clampf(player_state.pos.y + balance.camera_z_bias, 4.5, 13.5)
	var desired := Vector3(target_x, 5.8, target_z)
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

func _on_server_attack_performed(attacker_id: int, _target_id: int, from_xz: Vector2, to_xz: Vector2, _damage: int) -> void:
	if attacker_id == 0:
		camera_shake_trauma = minf(1.0, camera_shake_trauma + 0.35)
	arena_builder.spawn_impact_debris(to_xz, 3)
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
