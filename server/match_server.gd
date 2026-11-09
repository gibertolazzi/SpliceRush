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

enum CellType {
	FLOOR = 0,
	DESTRUCTIBLE_BLOCK = 1,
	HAZARD_BARRIER = 2,
	POWER_PEDESTAL = 3,
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

var match_elapsed_sec: float = 43.0 # Starts at 00:47 remaining by default for visual parity, resettable
var combatants: Array[CombatantState] = []
var dropped_parts: Array[DroppedPartState] = []
var grid_cells: Dictionary = {} # Vector2i -> int (CellType)
var block_hp: Dictionary = {}   # Vector2i -> int
var event_log: Array[Dictionary] = []

var _next_drop_id: int = 1
var _power_part_timer: float = 0.0
var _tick_accumulator: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261109
	if balance == null:
		balance = BalanceConfig.new()
	setup_arena_grid()
	spawn_all_combatants()
	_spawn_initial_arena_drops()

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
	# Distinct bot starter parts so every bot has a clear silhouette and drops exciting parts on death
	var bot_loadouts: Array[Dictionary] = [
		{}, # 0: Player handled below
		{PartData.Slot.ARMS: &"giant_fist", PartData.Slot.LEGS: &"spring_legs"},
		{PartData.Slot.HEAD: &"visor_head", PartData.Slot.CORE: &"shield_core"},
		{PartData.Slot.HEAD: &"spike_helm", PartData.Slot.ARMS: &"giant_fist"},
		{PartData.Slot.HEAD: &"laser_eye", PartData.Slot.LEGS: &"roller_wheels"},
		{PartData.Slot.HEAD: &"visor_head", PartData.Slot.ARMS: &"chainsaw_arm"},
		{PartData.Slot.CORE: &"magnet_core", PartData.Slot.LEGS: &"roller_wheels"},
		{PartData.Slot.ARMS: &"mega_claws", PartData.Slot.CORE: &"shield_core"},
		{PartData.Slot.HEAD: &"spike_helm", PartData.Slot.LEGS: &"rocket_legs"},
		{PartData.Slot.ARMS: &"chainsaw_arm", PartData.Slot.LEGS: &"spring_legs"},
		{PartData.Slot.CORE: &"crown_core", PartData.Slot.HEAD: &"visor_head"},
		{PartData.Slot.ARMS: &"mega_claws", PartData.Slot.LEGS: &"rocket_legs"},
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
			var custom_slots: Dictionary = bot_loadouts[i % bot_loadouts.size()]
			for s_key: Variant in custom_slots.keys():
				c.slots[s_key] = custom_slots[s_key]
		_recalc_combatant_stats(c, false)
		combatants.append(c)

func _spawn_initial_arena_drops() -> void:
	dropped_parts.clear()
	_power_part_timer = balance.power_part_interval_sec
	# Spawn collectible parts in clear mid-ground lanes so their 3D shapes & rarity beacons are immediately visible
	spawn_dropped_part(&"mega_claws", Vector2(-1.4, 0.9), Vector2.ZERO, false)
	spawn_dropped_part(&"roller_wheels", Vector2(1.7, 0.6), Vector2.ZERO, false)
	spawn_dropped_part(&"magnet_core", Vector2(0.2, -2.2), Vector2.ZERO, false)

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
	c.speed_mult = clampf(spd, 0.75, 1.65)
	c.damage_mult = clampf(dmg, 0.75, 2.20)
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

	_power_part_timer -= dt
	if _power_part_timer <= 0.0:
		_power_part_timer = balance.power_part_interval_sec
		var pp: PartData = PartCatalog.pick_random_part(_rng, PartData.Rarity.EPIC, PartData.Rarity.LEGENDARY)
		var angle: float = _rng.randf_range(0.0, TAU)
		spawn_dropped_part(pp.part_id, PEDESTAL_WORLD_XZ + Vector2(cos(angle), sin(angle)) * 1.6, Vector2(cos(angle), sin(angle)) * 2.5, true)
		_record_event(&"power_part_spawn", -1, -1, PEDESTAL_WORLD_XZ)

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
		c.transform_anim_timer = maxf(0.0, c.transform_anim_timer - dt)

		if c.ability_requested and c.dash_cooldown <= 0.0:
			var dash_dir: Vector2 = c.move_input
			if dash_dir.length_squared() < 0.01:
				dash_dir = Vector2.from_angle(c.facing_angle)
			c.vel = dash_dir.normalized() * balance.dash_impulse * c.speed_mult
			c.dash_cooldown = balance.dash_cooldown_sec * c.cooldown_mult
			_record_event(&"dash", c.id, -1, c.pos)
		c.ability_requested = false

		var desired_vel: Vector2 = c.move_input * (balance.base_move_speed * c.speed_mult)
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
		if c.alive and c.attack_cooldown <= 0.0:
			_try_auto_attack(c)

	_prune_event_log()
	state_ticked.emit(get_time_remaining())

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
		if not c.alive:
			continue
		var radius: float = balance.part_pickup_radius * c.pickup_mult
		var d_sq: float = c.pos.distance_squared_to(drop.pos)
		if d_sq > radius * radius:
			continue
		var current_pid: StringName = c.slots.get(drop.slot, &"base_fist") as StringName
		var current_part: PartData = PartCatalog.get_part(current_pid)
		# Equip if dropped part is an upgrade, or a different piece of equal rarity (never auto-downgrade a higher-rarity slot!)
		var should_equip: bool = false
		if int(drop.rarity) > int(current_part.rarity):
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

	# Determine which slots to drop & lose on death (AGENTS.md Section 1 & GDD: Abomination drops 3, normal drops 1)
	var max_drops: int = balance.abomination_drop_count if victim.is_abomination else 1
	var non_base_slots: Array[PartData.Slot] = []
	for s_key: Variant in victim.slots.keys():
		var slot_enum: PartData.Slot = s_key as PartData.Slot
		var pid: StringName = victim.slots[slot_enum] as StringName
		var base_pid: StringName = PartCatalog.get_base_part_for_slot(slot_enum)
		if pid != base_pid:
			non_base_slots.append(slot_enum)

	# Sort non-base slots by rarity descending so the juiciest piece drops first
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
		victim.slots[slot_to_drop] = PartCatalog.get_base_part_for_slot(slot_to_drop)
		var angle: float = _rng.randf_range(0.0, TAU) + float(dropped_count) * 2.1
		var pop_vel := Vector2(cos(angle), sin(angle)) * balance.part_drop_pop_speed
		spawn_dropped_part(drop_pid, victim.pos + Vector2(cos(angle), sin(angle)) * 0.45, pop_vel, false)
		dropped_count += 1

	# Even if a bot had only base parts left, guarantee a Rare combat part drop so every kill rewards the player!
	if dropped_count == 0:
		var bonus_part: PartData = PartCatalog.pick_random_part(_rng, PartData.Rarity.RARE, PartData.Rarity.EPIC)
		var angle: float = _rng.randf_range(0.0, TAU)
		var pop_vel := Vector2(cos(angle), sin(angle)) * balance.part_drop_pop_speed
		spawn_dropped_part(bonus_part.part_id, victim.pos, pop_vel, false)

	_recalc_combatant_stats(victim, true)

func _update_bot_input(bot: CombatantState, _dt: float) -> void:
	# If a high-value dropped part is nearby and upgrades a slot, steer toward it!
	var best_drop: DroppedPartState = null
	var best_drop_dist_sq: float = 36.0 # 6m search radius
	for drop: DroppedPartState in dropped_parts:
		var cur_pid: StringName = bot.slots.get(drop.slot, &"base_fist") as StringName
		var cur_part: PartData = PartCatalog.get_part(cur_pid)
		if int(drop.rarity) > int(cur_part.rarity):
			var d_sq: float = bot.pos.distance_squared_to(drop.pos)
			if d_sq < best_drop_dist_sq:
				best_drop_dist_sq = d_sq
				best_drop = drop
	if best_drop != null:
		bot.move_input = (best_drop.pos - bot.pos).normalized()
		return

	var nearest: CombatantState = find_nearest_enemy(bot.id, 999.0)
	if nearest == null:
		bot.move_input = Vector2.ZERO
		return
	var to_target: Vector2 = nearest.pos - bot.pos
	var dist: float = to_target.length()
	var dir: Vector2 = to_target / maxf(dist, 0.001)
	var tangent := Vector2(-dir.y, dir.x) * (1.0 if (bot.id % 2 == 0) else -1.0)
	var eff_range: float = balance.auto_attack_range * bot.range_mult
	if dist > eff_range * 0.85:
		bot.move_input = (dir * 0.78 + tangent * 0.35).normalized()
	elif dist < eff_range * 0.48:
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
	var eff_range: float = balance.auto_attack_range * attacker.range_mult
	var eff_damage: int = maxi(1, int(round(float(balance.auto_attack_damage) * attacker.damage_mult)))
	var eff_cd: float = balance.auto_attack_cooldown_sec * attacker.cooldown_mult

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
		target.vel += dir * balance.auto_attack_knockback * attacker.damage_mult
		if target.hp <= 0:
			_handle_combatant_death(target, attacker)
		else:
			_record_event(&"attack", attacker.id, target.id, target.pos)
		attack_performed.emit(attacker.id, target.id, attacker.pos, target.pos, eff_damage)
		return true

	# If no enemy in range, auto-attack adjacent destructible block if close
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
	var max_x: float = (float(balance.grid_width) * 0.5 - 0.8) * balance.tile_size
	var max_z: float = (float(balance.grid_depth) * 0.5 - 0.8) * balance.tile_size
	return Vector2(clampf(candidate.x, -max_x, max_x), clampf(candidate.y, -max_z, max_z))

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
