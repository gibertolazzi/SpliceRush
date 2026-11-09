class_name MatchServer
extends Node

signal state_ticked(match_time_remaining: float)
signal attack_performed(attacker_id: int, target_id: int, from_xz: Vector2, to_xz: Vector2, damage: int)
signal block_damaged(cell: Vector2i, remaining_hp: int, destroyed: bool, world_xz: Vector2)
signal combatant_respawned(combatant_id: int, pos_xz: Vector2)

enum CellType {
	FLOOR = 0,
	DESTRUCTIBLE_BLOCK = 1,
	HAZARD_BARRIER = 2,
	POWER_PEDESTAL = 3,
}

class CombatantState extends RefCounted:
	var id: int = 0
	var is_bot: bool = true
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
	var attack_cooldown: float = 0.0
	var dash_cooldown: float = 0.0
	var last_target_id: int = -1
	var attack_anim_timer: float = 0.0
	var hurt_anim_timer: float = 0.0
	var stolen_parts_count: int = 0
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

@export var balance: BalanceConfig = preload("res://shared/default_balance.tres")
@export var bots_enabled: bool = true

var match_elapsed_sec: float = 43.0 # Starts at 00:47 remaining by default for visual parity, resettable
var combatants: Array[CombatantState] = []
var grid_cells: Dictionary = {} # Vector2i -> int (CellType)
var block_hp: Dictionary = {}   # Vector2i -> int
var event_log: Array[Dictionary] = []

var _tick_accumulator: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261109
	if balance == null:
		balance = BalanceConfig.new()
	setup_arena_grid()
	spawn_all_combatants()

func setup_arena_grid() -> void:
	grid_cells.clear()
	block_hp.clear()
	var hw: int = balance.grid_width / 2
	var hd: int = balance.grid_depth / 2
	for gx: int in range(-hw, hw):
		for gz: int in range(-hd, hd):
			var cell := Vector2i(gx, gz)
			grid_cells[cell] = CellType.FLOOR

	# Center Power Part pedestal (around (2, -3) in key-art composition)
	var ped_cells: Array[Vector2i] = [
		Vector2i(1, -4), Vector2i(2, -4),
		Vector2i(1, -3), Vector2i(2, -3),
	]
	for pc: Vector2i in ped_cells:
		grid_cells[pc] = CellType.POWER_PEDESTAL

	# Hazard barriers (yellow-black stripes as seen in key art left-back and right-mid)
	var hazard_coords: Array[Vector2i] = [
		Vector2i(-2, -5), Vector2i(-1, -5),
		Vector2i(5, -2), Vector2i(5, -1),
		Vector2i(-6, 1), Vector2i(6, 2),
	]
	for hc: Vector2i in hazard_coords:
		grid_cells[hc] = CellType.HAZARD_BARRIER

	# Destructible stone blocks around the arena perimeter and tactical clusters
	var destructible_coords: Array[Vector2i] = [
		Vector2i(-5, -2), Vector2i(-4, -2),
		Vector2i(4, -5), Vector2i(5, -5),
		Vector2i(-5, 3), Vector2i(-4, 3),
		Vector2i(4, 3), Vector2i(5, 3),
		Vector2i(-3, -7), Vector2i(0, -7), Vector2i(3, -7),
		Vector2i(-6, -4), Vector2i(6, -4),
	]
	for dc: Vector2i in destructible_coords:
		grid_cells[dc] = CellType.DESTRUCTIBLE_BLOCK
		block_hp[dc] = balance.destructible_block_hp

func spawn_all_combatants() -> void:
	combatants.clear()
	# Initial staging positions on the XZ plane so the scene immediately reads like key-art,
	# while remaining 100% live-simulated on the authoritative plane.
	var initial_positions: Array[Vector2] = [
		Vector2(0.0, 4.4),    # 0: Protagonist (foreground center-bottom)
		Vector2(-3.0, -0.4),  # 1: Red fighter (left mid-ground)
		Vector2(2.6, -0.6),   # 2: Blue fighter with visor (right mid-ground)
		Vector2(-2.2, 2.3),   # 3: Green fighter with mohawk (left foreground)
		Vector2(4.1, 1.2),    # 4: Yellow-orange fighter (right mid-foreground)
		Vector2(-0.3, -3.6),  # 5: Deep Blue fighter near pedestal
		Vector2(-5.0, -2.5),  # 6: Hot Pink fighter
		Vector2(4.8, -3.8),   # 7: Cyan fighter
		Vector2(-3.6, -6.2),  # 8: Coral fighter
		Vector2(2.8, -6.5),   # 9: Lime fighter
		Vector2(-1.2, -7.2),  # 10: Lavender fighter
		Vector2(4.5, 3.6),    # 11: Gold fighter
	]
	for i: int in range(balance.max_combatants):
		var c := CombatantState.new()
		c.id = i
		c.is_bot = (i != 0)
		c.pos = initial_positions[i % initial_positions.size()]
		c.prev_pos = c.pos
		c.hp = balance.max_hp
		c.max_hp = balance.max_hp
		c.base_color = FIGHTER_PALETTE[i % FIGHTER_PALETTE.size()]
		c.shape_id = i % 4
		if i == 0:
			c.facing_angle = deg_to_rad(-25.0)
			c.stolen_parts_count = 4
			c.slots[PartData.Slot.HEAD] = &"laser_eye"
			c.slots[PartData.Slot.ARMS] = &"chainsaw_arm"
			c.slots[PartData.Slot.LEGS] = &"rocket_legs"
			c.slots[PartData.Slot.CORE] = &"crown_core"
		else:
			c.facing_angle = (Vector2.ZERO - c.pos).angle()
			c.attack_cooldown = float(i % 4) * 0.12
		combatants.append(c)

func submit_client_input(combatant_id: int, move_vec: Vector2, ability_pressed: bool) -> void:
	if combatant_id < 0 or combatant_id >= combatants.size():
		return
	var c: CombatantState = combatants[combatant_id]
	# Authoritative server clamps input vector length to <= 1.0 (anti-cheat rule 1)
	if move_vec.length_squared() > 1.0:
		c.move_input = move_vec.normalized()
	else:
		c.move_input = move_vec
	if ability_pressed:
		c.ability_requested = true

func _physics_process(delta: float) -> void:
	var tick_dt: float = 1.0 / float(maxi(balance.server_tick_hz, 1))
	_tick_accumulator += delta
	var steps: int = 0
	while _tick_accumulator >= tick_dt and steps < 4:
		_tick_accumulator -= tick_dt
		step_simulation(tick_dt)
		steps += 1

func step_simulation(dt: float) -> void:
	match_elapsed_sec = fmod(match_elapsed_sec + dt, balance.match_duration_sec)
	for c: CombatantState in combatants:
		c.prev_pos = c.pos
		if not c.alive:
			c.respawn_timer -= dt
			if c.respawn_timer <= 0.0:
				c.alive = true
				c.hp = c.max_hp
				c.pos = _pick_spawn_pos(c.id)
				c.prev_pos = c.pos
				c.vel = Vector2.ZERO
				combatant_respawned.emit(c.id, c.pos)
			continue

		if c.is_bot and bots_enabled:
			_update_bot_input(c, dt)

		c.attack_cooldown = maxf(0.0, c.attack_cooldown - dt)
		c.dash_cooldown = maxf(0.0, c.dash_cooldown - dt)
		c.attack_anim_timer = maxf(0.0, c.attack_anim_timer - dt)
		c.hurt_anim_timer = maxf(0.0, c.hurt_anim_timer - dt)

		if c.ability_requested and c.dash_cooldown <= 0.0:
			var dash_dir: Vector2 = c.move_input
			if dash_dir.length_squared() < 0.01:
				dash_dir = Vector2.from_angle(c.facing_angle)
			c.vel = dash_dir.normalized() * balance.dash_impulse
			c.dash_cooldown = balance.dash_cooldown_sec
			_record_event(&"dash", c.id, -1, c.pos)
		c.ability_requested = false

		var desired_vel: Vector2 = c.move_input * balance.base_move_speed
		if c.move_input.length_squared() > 0.001:
			c.vel = c.vel.move_toward(desired_vel, balance.acceleration * dt)
			c.facing_angle = lerp_angle(c.facing_angle, c.move_input.angle(), minf(1.0, 14.0 * dt))
		else:
			c.vel = c.vel.move_toward(Vector2.ZERO, balance.friction * dt)

		var next_pos: Vector2 = c.pos + c.vel * dt
		next_pos = _resolve_grid_and_bounds(c, next_pos)
		c.pos = next_pos

	_resolve_combatant_separation()

	for c: CombatantState in combatants:
		if c.alive and c.attack_cooldown <= 0.0:
			_try_auto_attack(c)

	_prune_event_log()
	state_ticked.emit(get_time_remaining())

func _update_bot_input(bot: CombatantState, _dt: float) -> void:
	var nearest: CombatantState = find_nearest_enemy(bot.id, 999.0)
	if nearest == null:
		bot.move_input = Vector2.ZERO
		return
	var to_target: Vector2 = nearest.pos - bot.pos
	var dist: float = to_target.length()
	var dir: Vector2 = to_target / maxf(dist, 0.001)
	# Orbit + approach behavior so bots stay active and readable without clumping into 1 point
	var tangent := Vector2(-dir.y, dir.x) * (1.0 if (bot.id % 2 == 0) else -1.0)
	if dist > balance.auto_attack_range * 0.85:
		bot.move_input = (dir * 0.78 + tangent * 0.35).normalized()
	elif dist < balance.auto_attack_range * 0.48:
		bot.move_input = (-dir * 0.55 + tangent * 0.65).normalized()
	else:
		bot.move_input = (tangent * 0.75).normalized()

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

func _try_auto_attack(attacker: CombatantState) -> bool:
	var target: CombatantState = find_nearest_enemy(attacker.id, balance.auto_attack_range)
	if target != null:
		attacker.attack_cooldown = balance.auto_attack_cooldown_sec
		attacker.attack_anim_timer = 0.22
		attacker.last_target_id = target.id
		var dir: Vector2 = (target.pos - attacker.pos).normalized()
		if dir.length_squared() > 0.001:
			attacker.facing_angle = dir.angle()
		target.hp -= balance.auto_attack_damage
		target.hurt_anim_timer = 0.18
		target.vel += dir * balance.auto_attack_knockback
		if target.hp <= 0:
			target.hp = 0
			target.alive = false
			target.respawn_timer = balance.respawn_delay_sec
			attacker.stolen_parts_count += 1
			_record_event(&"kill", attacker.id, target.id, target.pos)
		else:
			_record_event(&"attack", attacker.id, target.id, target.pos)
		attack_performed.emit(attacker.id, target.id, attacker.pos, target.pos, balance.auto_attack_damage)
		return true

	# If no enemy in range, auto-attack adjacent destructible block if close
	var nearest_block_cell := Vector2i(9999, 9999)
	var best_block_dist_sq: float = balance.auto_attack_range * balance.auto_attack_range
	for cell_var: Variant in block_hp.keys():
		var cell: Vector2i = cell_var as Vector2i
		var block_xz: Vector2 = cell_to_world_xz(cell)
		var d_sq: float = attacker.pos.distance_squared_to(block_xz)
		if d_sq <= best_block_dist_sq:
			best_block_dist_sq = d_sq
			nearest_block_cell = cell

	if nearest_block_cell.x != 9999:
		attacker.attack_cooldown = balance.auto_attack_cooldown_sec
		attacker.attack_anim_timer = 0.20
		var block_xz: Vector2 = cell_to_world_xz(nearest_block_cell)
		var dir: Vector2 = (block_xz - attacker.pos).normalized()
		if dir.length_squared() > 0.001:
			attacker.facing_angle = dir.angle()
		damage_block(nearest_block_cell, balance.auto_attack_damage)
		attack_performed.emit(attacker.id, -1, attacker.pos, block_xz, balance.auto_attack_damage)
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

func _resolve_grid_and_bounds(c: CombatantState, candidate: Vector2) -> Vector2:
	var max_x: float = (float(balance.grid_width) * 0.5 - 0.8) * balance.tile_size
	var max_z: float = (float(balance.grid_depth) * 0.5 - 0.8) * balance.tile_size
	var out := Vector2(
		clampf(candidate.x, -max_x, max_x),
		clampf(candidate.y, -max_z, max_z)
	)
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
	var angle: float = float(combatant_id) * TAU / float(maxi(balance.max_combatants, 1))
	return Vector2(cos(angle) * 5.0, sin(angle) * 5.0)

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
