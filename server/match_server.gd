class_name MatchServer
extends Node

signal state_ticked(match_time_remaining: float)
signal attack_performed(attacker_id: int, target_id: int, from_xz: Vector2, to_xz: Vector2, damage: int)
signal block_damaged(cell: Vector2i, remaining_hp: int, destroyed: bool, world_xz: Vector2)
signal combatant_respawned(combatant_id: int, pos_xz: Vector2)
signal part_dropped(drop_id: int, part_id: StringName, slot: int, rarity: int, pos_xz: Vector2, is_power_part: bool)
signal part_picked_up(drop_id: int, collector_id: int, part_id: StringName, slot: int, rarity: int, pos_xz: Vector2)
signal combatant_slots_changed(combatant_id: int, slots: Dictionary, is_abomination: bool, total_mass: int)
signal abomination_changed(combatant_id: int, active: bool, pos_xz: Vector2)
signal frenzy_started()
signal arena_ring_collapsed(ring_index: int, collapsed_cells: Array[Vector2i], safe_bounds_xz: Vector2)
signal match_ended(leaderboard: Array[Dictionary], player_rank: int)
signal match_restarted()
signal map_theme_changed(theme: int)
signal combatant_lives_changed(combatant_id: int, lives_left: int)
signal combatant_eliminated(combatant_id: int, rank: int)

enum MapTheme {
	VIOLET_RUINS = 0,
	CYBER_FACTORY = 1,
	FLOATING_HEX = 2,
}

enum CellType {
	VOID = -1,
	FLOOR = 0,
	DESTRUCTIBLE_BLOCK = 1,
	HAZARD_BARRIER = 2,
	POWER_PEDESTAL = 3,
}

enum MatchPhase {
	SPAWN = 0,
	COMBAT = 1,
	FRENZY = 2,
	RESULT = 3,
}

class DroppedPartState extends RefCounted:
	var id: int = 0
	var part_id: StringName = &"giant_fist"
	var slot: PartData.Slot = PartData.Slot.ARMS
	var rarity: PartData.Rarity = PartData.Rarity.RARE
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var spawn_time: float = 0.0
	var is_power_part: bool = false

class CombatantState extends RefCounted:
	var id: int = 0
	var is_bot: bool = true
	var lives: int = 3
	var eliminated: bool = false
	var pos: Vector2 = Vector2.ZERO
	var prev_pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var facing_angle: float = 0.0
	var hp: int = 100
	var max_hp: int = 100
	var alive: bool = true
	var respawn_timer: float = 0.0
	var move_input: Vector2 = Vector2.ZERO
	var ability_requested: bool = false
	var attack_requested: bool = false
	var attack_cooldown: float = 0.0
	var dash_cooldown: float = 0.0
	var last_target_id: int = -1
	var attack_anim_timer: float = 0.0
	var hurt_anim_timer: float = 0.0
	var transform_anim_timer: float = 0.0
	var stolen_parts_count: int = 0
	var kills: int = 0
	var is_abomination: bool = false
	var total_mass: int = 40
	var speed_mult: float = 1.0
	var damage_mult: float = 1.0
	var cooldown_mult: float = 1.0
	var range_mult: float = 1.0
	var pickup_mult: float = 1.0
	var last_ai_action: StringName = &"attack_nearest"
	var base_color: Color = Color.WHITE
	var shape_id: int = 0
	var slots: Dictionary = {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"base_fist",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}

const FIGHTER_PALETTE: Array[Color] = [
	Color(0.45, 0.08, 0.78), # 0: Player Purple (Crown shirt)
	Color(0.86, 0.12, 0.18), # 1: Red fighter
	Color(0.16, 0.42, 0.92), # 2: Blue fighter (visor)
	Color(0.32, 0.72, 0.18), # 3: Green fighter (mohawk)
	Color(1.00, 0.68, 0.14), # 4: Yellow-Orange fighter (laser)
	Color(0.18, 0.34, 0.78), # 5: Deep Blue fighter
	Color(0.95, 0.22, 0.58), # 6: Hot Pink fighter
	Color(0.12, 0.78, 0.76), # 7: Cyan-Teal fighter
	Color(0.96, 0.42, 0.14), # 8: Coral Orange fighter
	Color(0.58, 0.84, 0.16), # 9: Lime fighter
	Color(0.64, 0.28, 0.92), # 10: Lavender fighter
	Color(0.92, 0.82, 0.22), # 11: Gold fighter
]

const PEDESTAL_WORLD_XZ := Vector2(2.2, -4.8)

@export var balance: BalanceConfig = preload("res://shared/default_balance.tres")
@export var bots_enabled: bool = true

var current_map_theme: MapTheme = MapTheme.VIOLET_RUINS
var match_elapsed_sec: float = 43.0 # Starts at 00:47 remaining by default for visual parity, resettable
var match_phase: MatchPhase = MatchPhase.COMBAT
var collapsed_rings_count: int = 0
var result_timer_sec: float = 0.0
var combatants: Array[CombatantState] = []
var dropped_parts: Array[DroppedPartState] = []
var grid_cells: Dictionary = {} # Vector2i -> int (CellType)
var block_hp: Dictionary = {}   # Vector2i -> int
var event_log: Array[Dictionary] = []

var _next_drop_id: int = 1
var _power_part_timer: float = 0.0
var _frenzy_collapse_timer: float = 0.0
var _tick_accumulator: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261109
	if balance == null:
		balance = BalanceConfig.new()
	var start_time: float = 0.0
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--static-preview":
			start_time = 43.0
		elif arg == "--map-theme=cyber":
			current_map_theme = MapTheme.CYBER_FACTORY
		elif arg == "--map-theme=hex":
			current_map_theme = MapTheme.FLOATING_HEX
		elif arg == "--map-theme=ruins":
			current_map_theme = MapTheme.VIOLET_RUINS
	start_new_match(start_time, false)

func set_map_theme(theme: MapTheme) -> void:
	current_map_theme = theme
	setup_arena_grid()
	map_theme_changed.emit(int(current_map_theme))

func _count_active_combatants() -> int:
	var count: int = 0
	for c: CombatantState in combatants:
		if not c.eliminated:
			count += 1
	return count

func start_new_match(initial_elapsed_sec: float = 0.0, emit_restart: bool = true) -> void:
	match_elapsed_sec = initial_elapsed_sec
	collapsed_rings_count = 0
	result_timer_sec = 0.0
	_frenzy_collapse_timer = balance.frenzy_collapse_interval_sec
	match_phase = _compute_phase_for_time(match_elapsed_sec)
	event_log.clear()
	setup_arena_grid()
	spawn_all_combatants()
	_spawn_initial_arena_drops()
	if emit_restart:
		match_restarted.emit()
	state_ticked.emit(get_time_remaining())

func request_rematch() -> void:
	start_new_match(0.0, true)

func setup_viral_clip_scenario() -> void:
	dropped_parts.clear()
	var p0: CombatantState = combatants[0]
	p0.pos = Vector2(0.0, 4.2)
	p0.prev_pos = p0.pos
	p0.vel = Vector2.ZERO
	p0.alive = true
	p0.hp = p0.max_hp
	p0.attack_cooldown = 0.0
	p0.dash_cooldown = 0.0
	p0.stolen_parts_count = 3
	p0.slots = {
		PartData.Slot.HEAD: &"visor_head",
		PartData.Slot.ARMS: &"base_fist",
		PartData.Slot.LEGS: &"spring_legs",
		PartData.Slot.CORE: &"crown_core",
	}
	_recalc_combatant_stats(p0, true)

	var enemy: CombatantState = combatants[1]
	enemy.pos = Vector2(-1.1, 3.8)
	enemy.prev_pos = enemy.pos
	enemy.vel = Vector2(2.0, 0.5)
	enemy.alive = true
	enemy.hp = 15
	enemy.slots = {
		PartData.Slot.HEAD: &"laser_eye",
		PartData.Slot.ARMS: &"chainsaw_arm",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}
	_recalc_combatant_stats(enemy, true)

func _compute_phase_for_time(t: float) -> MatchPhase:
	if t >= balance.match_duration_sec:
		return MatchPhase.RESULT
	if t >= balance.frenzy_start_sec:
		return MatchPhase.FRENZY
	if t < 5.0:
		return MatchPhase.SPAWN
	return MatchPhase.COMBAT

func is_frenzy_active() -> bool:
	return match_phase == MatchPhase.FRENZY

func get_power_part_timer() -> float:
	return _power_part_timer

func get_safe_bounds_xz() -> Vector2:
	var eff_hw: float = maxf(5.0, float(balance.grid_width) * 0.5 - float(collapsed_rings_count) * 1.5 - 0.8)
	var eff_hd: float = maxf(6.0, float(balance.grid_depth) * 0.5 - float(collapsed_rings_count) * 1.8 - 0.8)
	return Vector2(eff_hw * balance.tile_size, eff_hd * balance.tile_size)

func setup_arena_grid() -> void:
	grid_cells.clear()
	block_hp.clear()
	var hw: int = balance.grid_width / 2
	var hd: int = balance.grid_depth / 2

	match current_map_theme:
		MapTheme.FLOATING_HEX:
			for gx: int in range(-hw, hw):
				for gz: int in range(-hd, hd):
					var in_center: bool = (absf(float(gx)) + absf(float(gz)) * 0.75) <= 7.0
					var in_north: bool = Vector2(float(gx), float(gz) + 12.0).length() <= 5.5
					var in_south: bool = Vector2(float(gx), float(gz) - 12.0).length() <= 5.5
					var in_west: bool = Vector2(float(gx) + 10.0, float(gz)).length() <= 5.0
					var in_east: bool = Vector2(float(gx) - 10.0, float(gz)).length() <= 5.0
					var in_vert_bridge: bool = (abs(gx) <= 1 and abs(gz) <= 15)
					var in_horiz_bridge: bool = (abs(gz) <= 1 and abs(gx) <= 12)
					if in_center or in_north or in_south or in_west or in_east or in_vert_bridge or in_horiz_bridge:
						grid_cells[Vector2i(gx, gz)] = CellType.FLOOR

		MapTheme.CYBER_FACTORY:
			for gx: int in range(-hw, hw):
				for gz: int in range(-hd, hd):
					grid_cells[Vector2i(gx, gz)] = CellType.FLOOR

			var cyber_hazards: Array[Vector2i] = [
				Vector2i(-6, -10), Vector2i(-5, -10), Vector2i(5, -10), Vector2i(6, -10),
				Vector2i(-10, 0), Vector2i(-9, 0), Vector2i(9, 0), Vector2i(10, 0),
				Vector2i(-6, 10), Vector2i(-5, 10), Vector2i(5, 10), Vector2i(6, 10),
			]
			for ch: Vector2i in cyber_hazards:
				grid_cells[ch] = CellType.HAZARD_BARRIER

			var cyber_blocks: Array[Vector2i] = [
				Vector2i(-8, -6), Vector2i(-7, -6), Vector2i(7, -6), Vector2i(8, -6),
				Vector2i(-8, 6), Vector2i(-7, 6), Vector2i(7, 6), Vector2i(8, 6),
				Vector2i(-3, -12), Vector2i(3, -12), Vector2i(-3, 12), Vector2i(3, 12),
			]
			for cb: Vector2i in cyber_blocks:
				grid_cells[cb] = CellType.DESTRUCTIBLE_BLOCK
				block_hp[cb] = balance.destructible_block_hp

		MapTheme.VIOLET_RUINS, _:
			for gx: int in range(-hw, hw):
				for gz: int in range(-hd, hd):
					grid_cells[Vector2i(gx, gz)] = CellType.FLOOR

			var hazard_coords: Array[Vector2i] = [
				Vector2i(-8, -9), Vector2i(-7, -9), Vector2i(7, -9), Vector2i(8, -9),
				Vector2i(-11, 0), Vector2i(-10, 0), Vector2i(10, 0), Vector2i(11, 0),
				Vector2i(-8, 9), Vector2i(-7, 9), Vector2i(7, 9), Vector2i(8, 9),
			]
			for hc: Vector2i in hazard_coords:
				grid_cells[hc] = CellType.HAZARD_BARRIER

			var destructible_coords: Array[Vector2i] = [
				Vector2i(-9, -5), Vector2i(-8, -5), Vector2i(8, -5), Vector2i(9, -5),
				Vector2i(-9, 5), Vector2i(-8, 5), Vector2i(8, 5), Vector2i(9, 5),
				Vector2i(-5, -11), Vector2i(0, -11), Vector2i(5, -11),
				Vector2i(-5, 11), Vector2i(0, 11), Vector2i(5, 11),
				Vector2i(-11, -7), Vector2i(11, -7), Vector2i(-11, 7), Vector2i(11, 7),
			]
			for dc: Vector2i in destructible_coords:
				grid_cells[dc] = CellType.DESTRUCTIBLE_BLOCK
				block_hp[dc] = balance.destructible_block_hp

	var ped_cells: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(0, 0),
	]
	for pc: Vector2i in ped_cells:
		grid_cells[pc] = CellType.POWER_PEDESTAL

func spawn_all_combatants() -> void:
	combatants.clear()
	var initial_positions: Array[Vector2] = [
		Vector2(0.0, 14.0),   # 0: Protagonist (foreground center - generous breathing room)
		Vector2(-9.0, 9.0),   # 1: Red fighter (south-west)
		Vector2(9.0, 9.0),    # 2: Blue fighter with visor (south-east)
		Vector2(-14.0, 0.0),  # 3: Green fighter with mohawk (mid left)
		Vector2(14.0, 0.0),   # 4: Yellow-orange fighter (mid right)
		Vector2(-8.0, -8.0),  # 5: Deep Blue fighter (north-west inner)
		Vector2(8.0, -8.0),   # 6: Hot Pink fighter (north-east inner)
		Vector2(0.0, -14.0),  # 7: Cyan fighter (north center)
		Vector2(-12.0, -18.0),# 8: Coral fighter (north-west corner)
		Vector2(12.0, -18.0), # 9: Lime fighter (north-east corner)
		Vector2(-5.0, -22.0), # 10: Lavender fighter (far north left)
		Vector2(5.0, -22.0),  # 11: Gold fighter (far north right)
	]
	var bot_loadouts: Array[Dictionary] = [
		{},
		{PartData.Slot.LEGS: &"spring_legs"},
		{PartData.Slot.HEAD: &"visor_head"},
		{PartData.Slot.HEAD: &"spike_helm"},
		{PartData.Slot.LEGS: &"roller_wheels"},
		{PartData.Slot.HEAD: &"visor_head"},
		{PartData.Slot.CORE: &"shield_core"},
		{PartData.Slot.HEAD: &"spike_helm"},
		{PartData.Slot.LEGS: &"spring_legs"},
		{PartData.Slot.HEAD: &"visor_head"},
		{PartData.Slot.CORE: &"magnet_core"},
		{PartData.Slot.LEGS: &"roller_wheels"},
	]
	for i: int in range(balance.max_combatants):
		var c := CombatantState.new()
		c.id = i
		c.is_bot = (i != 0)
		c.lives = 3
		c.eliminated = false
		c.pos = initial_positions[i % initial_positions.size()]
		c.prev_pos = c.pos
		c.hp = balance.max_hp
		c.max_hp = balance.max_hp
		c.base_color = FIGHTER_PALETTE[i % FIGHTER_PALETTE.size()]
		c.shape_id = i % 4
		if i == 0:
			var is_static_preview: bool = false
			for arg: String in OS.get_cmdline_user_args():
				if arg == "--static-preview":
					is_static_preview = true
			if is_static_preview:
				c.facing_angle = deg_to_rad(-25.0)
				c.stolen_parts_count = 4
				c.slots[PartData.Slot.HEAD] = &"laser_eye"
				c.slots[PartData.Slot.ARMS] = &"chainsaw_arm"
				c.slots[PartData.Slot.LEGS] = &"rocket_legs"
				c.slots[PartData.Slot.CORE] = &"crown_core"
			else:
				c.facing_angle = -PI * 0.5
				c.stolen_parts_count = 0
				c.slots[PartData.Slot.HEAD] = &"base_head"
				c.slots[PartData.Slot.ARMS] = &"base_fist"
				c.slots[PartData.Slot.LEGS] = &"base_boots"
				c.slots[PartData.Slot.CORE] = &"base_core"
		else:
			c.facing_angle = (Vector2.ZERO - c.pos).angle()
			c.attack_cooldown = float(i % 4) * 0.12
			var custom_slots: Dictionary = bot_loadouts[i % bot_loadouts.size()]
			for s_key: Variant in custom_slots.keys():
				c.slots[s_key] = custom_slots[s_key]
		_recalc_combatant_stats(c, false)
		combatants.append(c)

func _spawn_initial_arena_drops() -> void:
	dropped_parts.clear()
	_power_part_timer = balance.power_part_interval_sec
	spawn_dropped_part(&"mega_claws", Vector2(-4.5, 3.5), Vector2.ZERO, false)
	spawn_dropped_part(&"roller_wheels", Vector2(4.5, -3.5), Vector2.ZERO, false)
	spawn_dropped_part(&"magnet_core", Vector2(2.0, -6.5), Vector2.ZERO, false)
	spawn_dropped_part(&"chainsaw_arm", Vector2(-5.5, -4.5), Vector2.ZERO, false)
	spawn_dropped_part(&"rocket_legs", Vector2(6.0, 5.5), Vector2.ZERO, false)

func spawn_dropped_part(part_id: StringName, pos_xz: Vector2, pop_vel: Vector2 = Vector2.ZERO, is_power: bool = false) -> DroppedPartState:
	var pdata: PartData = PartCatalog.get_part(part_id)
	var drop := DroppedPartState.new()
	drop.id = _next_drop_id
	_next_drop_id += 1
	drop.part_id = pdata.part_id
	drop.slot = pdata.slot
	drop.rarity = pdata.rarity
	drop.pos = _clamp_to_arena(pos_xz)
	drop.vel = pop_vel
	drop.spawn_time = match_elapsed_sec
	drop.is_power_part = is_power
	dropped_parts.append(drop)
	part_dropped.emit(drop.id, drop.part_id, int(drop.slot), int(drop.rarity), drop.pos, drop.is_power_part)
	return drop

func _recalc_combatant_stats(c: CombatantState, emit_signals: bool = true) -> void:
	var spd: float = 1.0
	var dmg: float = 1.0
	var cd: float = 1.0
	var rng: float = 1.0
	var pick: float = 1.0
	for s_key: Variant in c.slots.keys():
		var pid: StringName = c.slots[s_key] as StringName
		var p: PartData = PartCatalog.get_part(pid)
		spd *= p.speed_multiplier
		dmg *= p.damage_multiplier
		cd *= p.cooldown_multiplier
		rng *= p.range_multiplier
		if pid == &"magnet_core":
			pick *= balance.magnet_pickup_multiplier
	# Severed limbs can reduce speed down to 0.40 and damage to 0.30
	c.speed_mult = clampf(spd, 0.40, 1.80)
	c.damage_mult = clampf(dmg, 0.30, 2.50)
	c.cooldown_mult = clampf(cd, 0.55, 1.35)
	c.range_mult = clampf(rng, 0.85, 1.60)
	c.pickup_mult = pick

	var prev_abom: bool = c.is_abomination
	c.is_abomination = PartCatalog.is_abomination_slots(c.slots)
	c.total_mass = PartCatalog.compute_slots_mass(c.slots) + c.kills * balance.kill_mass_bonus

	if emit_signals:
		combatant_slots_changed.emit(c.id, c.slots.duplicate(), c.is_abomination, c.total_mass)
		if c.is_abomination != prev_abom:
			abomination_changed.emit(c.id, c.is_abomination, c.pos)
			if c.is_abomination:
				_record_event(&"abomination", c.id, -1, c.pos)

func equip_part_on_combatant(combatant_id: int, part_id: StringName) -> bool:
	if combatant_id < 0 or combatant_id >= combatants.size():
		return false
	var c: CombatantState = combatants[combatant_id]
	var pdata: PartData = PartCatalog.get_part(part_id)
	c.slots[pdata.slot] = pdata.part_id
	c.stolen_parts_count += 1
	c.transform_anim_timer = 0.48
	c.hp = mini(c.max_hp, c.hp + balance.part_pickup_heal)
	_recalc_combatant_stats(c, true)
	return true

func submit_client_input(combatant_id: int, move_vec: Vector2, ability_pressed: bool, attack_pressed: bool = false) -> void:
	if combatant_id < 0 or combatant_id >= combatants.size():
		return
	var c: CombatantState = combatants[combatant_id]
	if move_vec.length_squared() > 1.0:
		c.move_input = move_vec.normalized()
	else:
		c.move_input = move_vec
	if ability_pressed:
		c.ability_requested = true
	if attack_pressed:
		c.attack_requested = true

func _physics_process(delta: float) -> void:
	var tick_dt: float = 1.0 / float(maxi(balance.server_tick_hz, 1))
	_tick_accumulator += delta
	var steps: int = 0
	while _tick_accumulator >= tick_dt and steps < 4:
		_tick_accumulator -= tick_dt
		step_simulation(tick_dt)
		steps += 1

func step_simulation(dt: float) -> void:
	if match_phase == MatchPhase.RESULT:
		result_timer_sec = maxf(0.0, result_timer_sec - dt)
		return

	var prev_phase: MatchPhase = match_phase
	match_elapsed_sec = minf(balance.match_duration_sec, match_elapsed_sec + dt)
	match_phase = _compute_phase_for_time(match_elapsed_sec)

	if match_phase == MatchPhase.FRENZY and prev_phase != MatchPhase.FRENZY:
		frenzy_started.emit()
		_record_event(&"frenzy_start", -1, -1, Vector2.ZERO)
		collapse_outer_ring()

	if match_phase == MatchPhase.FRENZY:
		_frenzy_collapse_timer -= dt
		if _frenzy_collapse_timer <= 0.0:
			_frenzy_collapse_timer = balance.frenzy_collapse_interval_sec
			collapse_outer_ring()

	if match_phase == MatchPhase.RESULT:
		result_timer_sec = balance.result_screen_duration_sec
		var board: Array[Dictionary] = build_leaderboard()
		var p_rank: int = 1
		for idx: int in range(board.size()):
			if int(board[idx]["id"]) == 0:
				p_rank = idx + 1
				break
		match_ended.emit(board, p_rank)
		state_ticked.emit(0.0)
		return

	_power_part_timer -= dt
	if _power_part_timer <= 0.0:
		_power_part_timer = balance.power_part_interval_sec * (0.5 if match_phase == MatchPhase.FRENZY else 1.0)
		var pp: PartData = PartCatalog.pick_random_part(_rng, PartData.Rarity.EPIC, PartData.Rarity.LEGENDARY)
		var angle: float = _rng.randf_range(0.0, TAU)
		spawn_dropped_part(pp.part_id, PEDESTAL_WORLD_XZ + Vector2(cos(angle), sin(angle)) * 1.6, Vector2(cos(angle), sin(angle)) * 2.5, true)
		_record_event(&"power_part_spawn", -1, -1, PEDESTAL_WORLD_XZ)

	for c: CombatantState in combatants:
		c.prev_pos = c.pos
		if not c.alive:
			if c.eliminated:
				continue
			c.respawn_timer -= dt
			if c.respawn_timer <= 0.0:
				c.alive = true
				c.hp = c.max_hp
				c.pos = _pick_spawn_pos(c.id)
				c.prev_pos = c.pos
				c.vel = Vector2.ZERO
				# If both limbs were severed, restore base limbs on fresh respawn
				if c.slots.get(PartData.Slot.ARMS) == &"severed_arms" and c.slots.get(PartData.Slot.LEGS) == &"severed_legs":
					c.slots[PartData.Slot.ARMS] = PartCatalog.get_base_part_for_slot(PartData.Slot.ARMS)
					c.slots[PartData.Slot.LEGS] = PartCatalog.get_base_part_for_slot(PartData.Slot.LEGS)
					_recalc_combatant_stats(c, true)
				combatant_respawned.emit(c.id, c.pos)
			continue

		if c.is_bot and bots_enabled:
			_update_bot_input(c, dt)

		c.attack_cooldown = maxf(0.0, c.attack_cooldown - dt)
		c.dash_cooldown = maxf(0.0, c.dash_cooldown - dt)
		c.attack_anim_timer = maxf(0.0, c.attack_anim_timer - dt)
		c.hurt_anim_timer = maxf(0.0, c.hurt_anim_timer - dt)
		c.transform_anim_timer = maxf(0.0, c.transform_anim_timer - dt)

		if c.ability_requested and c.dash_cooldown <= 0.0:
			var dash_dir: Vector2 = c.move_input
			if dash_dir.length_squared() < 0.01:
				dash_dir = Vector2.from_angle(c.facing_angle)
			c.vel = dash_dir.normalized() * balance.dash_impulse * c.speed_mult
			c.dash_cooldown = balance.dash_cooldown_sec * c.cooldown_mult
			_record_event(&"dash", c.id, -1, c.pos)
		c.ability_requested = false

		var speed_factor: float = 0.85 if c.is_bot else 1.0
		var desired_vel: Vector2 = c.move_input * (balance.base_move_speed * c.speed_mult * speed_factor)
		if c.move_input.length_squared() > 0.001:
			c.vel = c.vel.move_toward(desired_vel, balance.acceleration * dt)
			c.facing_angle = lerp_angle(c.facing_angle, c.move_input.angle(), minf(1.0, 14.0 * dt))
		else:
			c.vel = c.vel.move_toward(Vector2.ZERO, balance.friction * dt)

		var next_pos: Vector2 = c.pos + c.vel * dt
		next_pos = _resolve_grid_and_bounds(c, next_pos)
		c.pos = next_pos

	_resolve_combatant_separation()
	_update_dropped_parts(dt)

	for c: CombatantState in combatants:
		if c.alive:
			if c.attack_requested:
				_try_auto_attack(c, true)
				c.attack_requested = false
			elif c.attack_cooldown <= 0.0:
				_try_auto_attack(c, false)

	_prune_event_log()
	state_ticked.emit(get_time_remaining())

func collapse_outer_ring() -> Array[Vector2i]:
	var max_rings: int = 3
	if collapsed_rings_count >= max_rings:
		return []
	var hw: int = balance.grid_width / 2 - collapsed_rings_count
	var hd: int = balance.grid_depth / 2 - collapsed_rings_count
	var min_x: int = -hw
	var max_x: int = hw - 1
	var min_z: int = -hd
	var max_z: int = hd - 1

	var collapsed: Array[Vector2i] = []
	for gx: int in range(min_x, max_x + 1):
		for gz: int in range(min_z, max_z + 1):
			if gx == min_x or gx == max_x or gz == min_z or gz == max_z:
				var cell := Vector2i(gx, gz)
				if grid_cells.get(cell, CellType.VOID) != CellType.VOID:
					if block_hp.has(cell):
						block_hp.erase(cell)
						block_damaged.emit(cell, 0, true, cell_to_world_xz(cell))
					grid_cells[cell] = CellType.VOID
					collapsed.append(cell)

	collapsed_rings_count += 1
	var safe_b: Vector2 = get_safe_bounds_xz()
	# Push any combatants standing on the collapsing outer ring inward
	for c: CombatantState in combatants:
		if not c.alive:
			continue
		if absf(c.pos.x) > safe_b.x or absf(c.pos.y) > safe_b.y:
			c.pos = _clamp_to_arena(c.pos)
			var inward: Vector2 = (Vector2.ZERO - c.pos).normalized()
			c.vel = inward * balance.hazard_knockback
	for drop: DroppedPartState in dropped_parts:
		drop.pos = _clamp_to_arena(drop.pos)

	arena_ring_collapsed.emit(collapsed_rings_count, collapsed, safe_b)
	return collapsed

func build_leaderboard() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for c: CombatantState in combatants:
		_recalc_combatant_stats(c, false)
		entries.append({
			"id": c.id,
			"is_bot": c.is_bot,
			"total_mass": c.total_mass,
			"stolen_parts_count": c.stolen_parts_count,
			"kills": c.kills,
			"lives": c.lives,
			"eliminated": c.eliminated,
			"is_abomination": c.is_abomination,
			"slots": c.slots.duplicate(),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_elim: bool = bool(a.get("eliminated", false))
		var b_elim: bool = bool(b.get("eliminated", false))
		if a_elim != b_elim:
			return not a_elim # Surviving combatants rank higher
		if int(a["total_mass"]) != int(b["total_mass"]):
			return int(a["total_mass"]) > int(b["total_mass"])
		return int(a["stolen_parts_count"]) > int(b["stolen_parts_count"])
	)
	return entries

func _update_dropped_parts(dt: float) -> void:
	var idx: int = dropped_parts.size() - 1
	while idx >= 0:
		var drop: DroppedPartState = dropped_parts[idx]
		if drop.vel.length_squared() > 0.001:
			drop.pos = _clamp_to_arena(drop.pos + drop.vel * dt)
			drop.vel = drop.vel.move_toward(Vector2.ZERO, 14.0 * dt)

		var age: float = absf(match_elapsed_sec - drop.spawn_time)
		if age >= balance.part_pickup_grace_sec:
			var collector: CombatantState = _find_collector_for_drop(drop)
			if collector != null:
				var drop_id: int = drop.id
				var pid: StringName = drop.part_id
				var pslot: int = int(drop.slot)
				var prarity: int = int(drop.rarity)
				var ppos: Vector2 = drop.pos
				dropped_parts.remove_at(idx)
				equip_part_on_combatant(collector.id, pid)
				_record_event(&"steal_pickup", collector.id, drop_id, ppos)
				part_picked_up.emit(drop_id, collector.id, pid, pslot, prarity, ppos)
		idx -= 1

func _find_collector_for_drop(drop: DroppedPartState) -> CombatantState:
	var best: CombatantState = null
	var best_dist_sq: float = 999999.0
	for c: CombatantState in combatants:
		if not c.alive or c.eliminated:
			continue
		var radius: float = balance.part_pickup_radius * c.pickup_mult
		var d_sq: float = c.pos.distance_squared_to(drop.pos)
		if d_sq > radius * radius:
			continue
		var current_pid: StringName = c.slots.get(drop.slot, &"base_fist") as StringName
		var current_part: PartData = PartCatalog.get_part(current_pid)
		var should_equip: bool = false
		if PartCatalog.is_severed(current_pid):
			# Always prioritize equipping when limb is severed!
			should_equip = true
		elif int(drop.rarity) > int(current_part.rarity):
			should_equip = true
		elif int(drop.rarity) == int(current_part.rarity) and drop.part_id != current_pid:
			should_equip = true
		if should_equip and d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = c
	return best

func _handle_combatant_death(victim: CombatantState, killer: CombatantState) -> void:
	victim.hp = 0
	victim.alive = false
	victim.respawn_timer = balance.respawn_delay_sec
	if killer != null:
		killer.kills += 1
		_recalc_combatant_stats(killer, true)
		_record_event(&"kill", killer.id, victim.id, victim.pos)

	if is_frenzy_active():
		victim.lives -= 1
		combatant_lives_changed.emit(victim.id, victim.lives)
		if victim.lives <= 0:
			victim.eliminated = true
			var active_left: int = _count_active_combatants()
			var rank: int = active_left + 1
			combatant_eliminated.emit(victim.id, rank)
			_record_event(&"eliminated", killer.id if killer != null else -1, victim.id, victim.pos)
			if active_left <= 1:
				match_elapsed_sec = balance.match_duration_sec
				match_phase = MatchPhase.RESULT
				result_timer_sec = balance.result_screen_duration_sec
				var board: Array[Dictionary] = build_leaderboard()
				var p_rank: int = 1
				for idx: int in range(board.size()):
					if int(board[idx]["id"]) == 0:
						p_rank = idx + 1
						break
				match_ended.emit(board, p_rank)
				state_ticked.emit(0.0)
				return

	var max_drops: int = balance.abomination_drop_count if victim.is_abomination else 2
	var non_base_slots: Array[PartData.Slot] = []
	for s_key: Variant in victim.slots.keys():
		var slot_enum: PartData.Slot = s_key as PartData.Slot
		var pid: StringName = victim.slots[slot_enum] as StringName
		var base_pid: StringName = PartCatalog.get_base_part_for_slot(slot_enum)
		if pid != base_pid and not PartCatalog.is_severed(pid):
			non_base_slots.append(slot_enum)

	non_base_slots.sort_custom(func(a: PartData.Slot, b: PartData.Slot) -> bool:
		var pa: PartData = PartCatalog.get_part(victim.slots[a] as StringName)
		var pb: PartData = PartCatalog.get_part(victim.slots[b] as StringName)
		return int(pa.rarity) > int(pb.rarity)
	)

	var dropped_count: int = 0
	for slot_to_drop: PartData.Slot in non_base_slots:
		if dropped_count >= max_drops:
			break
		var drop_pid: StringName = victim.slots[slot_to_drop] as StringName
		var severed_pid: StringName = PartCatalog.get_severed_part_for_slot(slot_to_drop)
		if severed_pid != &"":
			victim.slots[slot_to_drop] = severed_pid
		else:
			victim.slots[slot_to_drop] = PartCatalog.get_base_part_for_slot(slot_to_drop)

		var angle: float = _rng.randf_range(0.0, TAU) + float(dropped_count) * 2.1
		var pop_vel := Vector2(cos(angle), sin(angle)) * balance.part_drop_pop_speed
		spawn_dropped_part(drop_pid, victim.pos + Vector2(cos(angle), sin(angle)) * 0.45, pop_vel, false)
		dropped_count += 1

	if dropped_count == 0:
		# If victim only had base parts, sever an arm or leg and drop a bonus part
		if victim.slots.get(PartData.Slot.ARMS) != &"severed_arms":
			victim.slots[PartData.Slot.ARMS] = &"severed_arms"
		elif victim.slots.get(PartData.Slot.LEGS) != &"severed_legs":
			victim.slots[PartData.Slot.LEGS] = &"severed_legs"
		var bonus_part: PartData = PartCatalog.pick_random_part(_rng, PartData.Rarity.RARE, PartData.Rarity.EPIC)
		var angle: float = _rng.randf_range(0.0, TAU)
		var pop_vel := Vector2(cos(angle), sin(angle)) * balance.part_drop_pop_speed
		spawn_dropped_part(bonus_part.part_id, victim.pos, pop_vel, false)

	_recalc_combatant_stats(victim, true)

func _update_bot_input(bot: CombatantState, _dt: float) -> void:
	var decision: Dictionary = BotUtilityAI.decide_bot_input(bot, self, get_safe_bounds_xz())
	bot.last_ai_action = decision["action"] as StringName
	bot.move_input = decision["move_input"] as Vector2
	if bool(decision["dash"]):
		bot.ability_requested = true

func find_nearest_enemy(attacker_id: int, max_range: float) -> CombatantState:
	if attacker_id < 0 or attacker_id >= combatants.size():
		return null
	var attacker: CombatantState = combatants[attacker_id]
	var best: CombatantState = null
	var best_dist_sq: float = max_range * max_range
	for other: CombatantState in combatants:
		if other.id == attacker_id or not other.alive:
			continue
		var d_sq: float = attacker.pos.distance_squared_to(other.pos)
		if d_sq <= best_dist_sq:
			best_dist_sq = d_sq
			best = other
	return best

func _try_auto_attack(attacker: CombatantState, force_manual: bool = false) -> bool:
	var eff_range: float = balance.auto_attack_range * attacker.range_mult
	var base_dmg: float = float(balance.auto_attack_damage) * attacker.damage_mult
	if attacker.is_bot:
		# Bot difficulty rebalancing: bots deal 60% base damage
		base_dmg *= 0.60
	var eff_damage: int = maxi(1, int(round(base_dmg)))

	var base_cd: float = balance.auto_attack_cooldown_sec * attacker.cooldown_mult
	if attacker.is_bot:
		# Natural attack cadence for bots (~0.77s) instead of instant spam
		base_cd *= 1.40
	var eff_cd: float = base_cd

	var target: CombatantState = find_nearest_enemy(attacker.id, eff_range)
	if target != null:
		attacker.attack_cooldown = eff_cd
		attacker.attack_anim_timer = 0.22
		attacker.last_target_id = target.id
		var dir: Vector2 = (target.pos - attacker.pos).normalized()
		if dir.length_squared() > 0.001:
			attacker.facing_angle = dir.angle()
		target.hp -= eff_damage
		target.hurt_anim_timer = 0.18
		if not attacker.is_bot and target.is_bot:
			# Player hits stagger bots briefly (0.28s cooldown delay on bot)
			target.attack_cooldown = maxf(target.attack_cooldown, 0.28)
		target.vel += dir * balance.auto_attack_knockback * attacker.damage_mult
		if target.hp <= 0:
			_handle_combatant_death(target, attacker)
		else:
			_record_event(&"attack", attacker.id, target.id, target.pos)
		attack_performed.emit(attacker.id, target.id, attacker.pos, target.pos, eff_damage)
		return true

	var nearest_block_cell := Vector2i(9999, 9999)
	var best_block_dist_sq: float = eff_range * eff_range
	for cell_var: Variant in block_hp.keys():
		var cell: Vector2i = cell_var as Vector2i
		var block_xz: Vector2 = cell_to_world_xz(cell)
		var d_sq: float = attacker.pos.distance_squared_to(block_xz)
		if d_sq <= best_block_dist_sq:
			best_block_dist_sq = d_sq
			nearest_block_cell = cell

	if nearest_block_cell.x != 9999:
		attacker.attack_cooldown = eff_cd
		attacker.attack_anim_timer = 0.20
		var block_xz: Vector2 = cell_to_world_xz(nearest_block_cell)
		var dir: Vector2 = (block_xz - attacker.pos).normalized()
		if dir.length_squared() > 0.001:
			attacker.facing_angle = dir.angle()
		damage_block(nearest_block_cell, eff_damage)
		attack_performed.emit(attacker.id, -1, attacker.pos, block_xz, eff_damage)
		return true

	if force_manual:
		# Manual attack with no targets in immediate range: punch the air
		attacker.attack_cooldown = eff_cd * 0.70
		attacker.attack_anim_timer = 0.22
		var forward_pt: Vector2 = attacker.pos + Vector2(cos(attacker.facing_angle), sin(attacker.facing_angle)) * (eff_range * 0.7)
		attack_performed.emit(attacker.id, -1, attacker.pos, forward_pt, 0)
		return true

	return false

func damage_block(cell: Vector2i, amount: int) -> bool:
	if not block_hp.has(cell):
		return false
	var hp_now: int = int(block_hp[cell]) - amount
	var world_xz: Vector2 = cell_to_world_xz(cell)
	if hp_now <= 0:
		block_hp.erase(cell)
		grid_cells[cell] = CellType.FLOOR
		block_damaged.emit(cell, 0, true, world_xz)
		return true
	else:
		block_hp[cell] = hp_now
		block_damaged.emit(cell, hp_now, false, world_xz)
		return false

func _clamp_to_arena(candidate: Vector2) -> Vector2:
	var safe_b: Vector2 = get_safe_bounds_xz()
	return Vector2(clampf(candidate.x, -safe_b.x, safe_b.x), clampf(candidate.y, -safe_b.y, safe_b.y))

func _resolve_grid_and_bounds(c: CombatantState, candidate: Vector2) -> Vector2:
	var out: Vector2 = _clamp_to_arena(candidate)
	var cell: Vector2i = world_xz_to_cell(out)
	var cell_type: int = int(grid_cells.get(cell, CellType.FLOOR))
	if cell_type == CellType.DESTRUCTIBLE_BLOCK or cell_type == CellType.HAZARD_BARRIER or cell_type == CellType.POWER_PEDESTAL:
		var center: Vector2 = cell_to_world_xz(cell)
		var diff: Vector2 = out - center
		var min_dist: float = balance.tile_size * 0.52 + balance.collision_radius
		if diff.length_squared() < 0.0001:
			diff = Vector2(0.0, 1.0)
		if diff.length() < min_dist:
			out = center + diff.normalized() * min_dist
			if cell_type == CellType.HAZARD_BARRIER:
				c.vel = diff.normalized() * balance.hazard_knockback
	return out

func _resolve_combatant_separation() -> void:
	var min_sep: float = balance.collision_radius * 2.05
	var min_sep_sq: float = min_sep * min_sep
	var count: int = combatants.size()
	for i: int in range(count):
		var a: CombatantState = combatants[i]
		if not a.alive:
			continue
		for j: int in range(i + 1, count):
			var b: CombatantState = combatants[j]
			if not b.alive:
				continue
			var delta_v: Vector2 = b.pos - a.pos
			var d_sq: float = delta_v.length_squared()
			if d_sq < min_sep_sq and d_sq > 0.00001:
				var d: float = sqrt(d_sq)
				var push: Vector2 = (delta_v / d) * ((min_sep - d) * 0.5)
				a.pos -= push
				b.pos += push

func _pick_spawn_pos(combatant_id: int) -> Vector2:
	var safe_b: Vector2 = get_safe_bounds_xz()
	var angle: float = float(combatant_id) * TAU / float(maxi(balance.max_combatants, 1))
	var radius: float = minf(safe_b.x, safe_b.y) * 0.70
	return _clamp_to_arena(Vector2(cos(angle) * radius, sin(angle) * radius))

func cell_to_world_xz(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * balance.tile_size, (float(cell.y) + 0.5) * balance.tile_size)

func world_xz_to_cell(world_xz: Vector2) -> Vector2i:
	return Vector2i(floori(world_xz.x / balance.tile_size), floori(world_xz.y / balance.tile_size))

func get_time_remaining() -> float:
	return maxf(0.0, balance.match_duration_sec - match_elapsed_sec)

func _record_event(kind: StringName, actor_id: int, target_id: int, pos_xz: Vector2) -> void:
	event_log.append({
		"time": match_elapsed_sec,
		"kind": kind,
		"actor_id": actor_id,
		"target_id": target_id,
		"pos": pos_xz,
	})

func _prune_event_log() -> void:
	var cutoff: float = match_elapsed_sec - balance.clip_log_window_sec
	while not event_log.is_empty() and float(event_log[0]["time"]) < cutoff:
		event_log.pop_front()
