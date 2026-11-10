class_name BotUtilityAI
extends RefCounted

# Normalized [0..1] response curves following ai-behavior-trees-utility-ai skill
static func curve_linear(x: float, m: float = 1.0, b: float = 0.0) -> float:
	return clampf(m * clampf(x, 0.0, 1.0) + b, 0.0, 1.0)

static func curve_quadratic(x: float, k: float = 2.0) -> float:
	return clampf(pow(clampf(x, 0.0, 1.0), k), 0.0, 1.0)

static func curve_logistic(x: float, k: float = 10.0, x0: float = 0.5) -> float:
	var xc: float = clampf(x, 0.0, 1.0)
	return clampf(1.0 / (1.0 + exp(-k * (xc - x0))), 0.0, 1.0)

static func decide_bot_input(
	bot: MatchServer.CombatantState,
	server: MatchServer,
	safe_bounds_xz: Vector2
) -> Dictionary:
	var best_action: StringName = &"patrol_wander"
	var best_score: float = -1.0
	var best_target_pos: Vector2 = Vector2.ZERO
	var request_dash: bool = false

	var hp_ratio: float = clampf(float(bot.hp) / float(maxi(bot.max_hp, 1)), 0.0, 1.0)

	# 1. Evade collapsing border (highest priority if near arena edge during Frenzy)
	var x_edge_ratio: float = absf(bot.pos.x) / maxf(safe_bounds_xz.x, 1.0)
	var z_edge_ratio: float = absf(bot.pos.y) / maxf(safe_bounds_xz.y, 1.0)
	var edge_danger: float = maxf(x_edge_ratio, z_edge_ratio)
	var frenzy_boost: float = 1.25 if server.is_frenzy_active() else 0.75
	var evade_score: float = curve_quadratic(clampf((edge_danger - 0.55) / 0.45, 0.0, 1.0), 2.2) * frenzy_boost
	if evade_score > best_score:
		best_score = evade_score
		best_action = &"evade_collapse"
		best_target_pos = Vector2.ZERO

	# 2. Collect nearby dropped part that upgrades a slot
	var best_drop: MatchServer.DroppedPartState = null
	var best_drop_score: float = 0.0
	for drop: MatchServer.DroppedPartState in server.dropped_parts:
		var cur_pid: StringName = bot.slots.get(drop.slot, &"base_fist") as StringName
		var cur_part: PartData = PartCatalog.get_part(cur_pid)
		var rarity_gain: int = int(drop.rarity) - int(cur_part.rarity)
		if PartCatalog.is_severed(cur_pid):
			rarity_gain = 4 # Desperately seek replacement for severed limb!
		elif rarity_gain <= 0:
			continue
		var dist: float = bot.pos.distance_to(drop.pos)
		var prox: float = 1.0 - curve_linear(dist / 14.0)
		var gain_norm: float = clampf(float(rarity_gain) / 3.0, 0.35, 1.0)
		var score: float = prox * 0.78 + gain_norm * 0.38
		if drop.is_power_part:
			score += 0.22
		if score > best_drop_score:
			best_drop_score = score
			best_drop = drop
	if best_drop != null and best_drop_score > best_score:
		best_score = best_drop_score
		best_action = &"collect_upgrade_part"
		best_target_pos = best_drop.pos

	# 3. Hunt the Abomination (if healthy and Abomination is active)
	var abom_target: MatchServer.CombatantState = null
	var best_abom_dist: float = 999.0
	for other: MatchServer.CombatantState in server.combatants:
		if other.id == bot.id or not other.alive or not other.is_abomination:
			continue
		var d: float = bot.pos.distance_to(other.pos)
		if d < best_abom_dist:
			best_abom_dist = d
			abom_target = other
	if abom_target != null:
		var prox_abom: float = 1.0 - curve_linear(best_abom_dist / 18.0)
		var hunt_score: float = (0.52 + 0.35 * prox_abom) * curve_logistic(hp_ratio, 8.0, 0.25)
		if hunt_score > best_score:
			best_score = hunt_score
			best_action = &"hunt_abomination"
			best_target_pos = abom_target.pos

	# 4. Contest Center Power Pedestal when timer is close
	var ped_dist: float = bot.pos.distance_to(MatchServer.PEDESTAL_WORLD_XZ)
	var ped_urgency: float = 1.0 - curve_linear(server.get_power_part_timer() / 8.0)
	var ped_prox: float = 1.0 - curve_linear(ped_dist / 14.0)
	var ped_score: float = ped_urgency * 0.65 + ped_prox * 0.25
	if ped_score > best_score:
		best_score = ped_score
		best_action = &"contest_power_pedestal"
		best_target_pos = MatchServer.PEDESTAL_WORLD_XZ

	# 5. Attack nearest enemy within aggro radius (prevents all 11 bots from congregating in 1 mosh pit!)
	var aggro_radius: float = 8.5 if not server.is_frenzy_active() else 14.0
	var nearest: MatchServer.CombatantState = server.find_nearest_enemy(bot.id, aggro_radius)
	if nearest != null:
		var d_enemy: float = bot.pos.distance_to(nearest.pos)
		var enemy_prox: float = 1.0 - curve_linear(d_enemy / aggro_radius)
		# Dogpile reduction: count how many bots are already crowding this target
		var crowd_count: int = 0
		for other: MatchServer.CombatantState in server.combatants:
			if other.id != bot.id and other.id != nearest.id and other.alive:
				if other.pos.distance_to(nearest.pos) < 2.8:
					crowd_count += 1
		var crowd_penalty: float = 0.20 * float(crowd_count)
		var combat_score: float = maxf(0.10, (0.55 + 0.38 * enemy_prox) - crowd_penalty)
		if combat_score > best_score:
			best_score = combat_score
			best_action = &"attack_nearest"
			best_target_pos = nearest.pos

	# 6. Default Fallback: Patrol / Roam quadrant locally
	if best_score < 0.22:
		best_score = 0.25
		best_action = &"patrol_wander"
		var t_cycle: float = server.match_elapsed_sec * 0.5 + float(bot.id) * 1.57
		best_target_pos = bot.pos + Vector2(cos(t_cycle) * 4.0, sin(t_cycle) * 3.0)

	# Convert chosen action into movement vector + dash decision
	var move_vec := Vector2.ZERO
	match best_action:
		&"evade_collapse":
			move_vec = (Vector2.ZERO - bot.pos).normalized()
			if edge_danger > 0.88 and bot.dash_cooldown <= 0.0:
				request_dash = true
		&"collect_upgrade_part", &"contest_power_pedestal":
			var diff: Vector2 = best_target_pos - bot.pos
			if diff.length_squared() > 0.04:
				move_vec = diff.normalized()
			if diff.length() > 4.5 and bot.dash_cooldown <= 0.0 and best_action == &"collect_upgrade_part":
				request_dash = true
		&"hunt_abomination", &"attack_nearest":
			var to_t: Vector2 = best_target_pos - bot.pos
			var dist: float = to_t.length()
			var dir: Vector2 = to_t / maxf(dist, 0.001)
			var tangent := Vector2(-dir.y, dir.x) * (1.0 if (bot.id % 2 == 0) else -1.0)
			var eff_range: float = server.balance.auto_attack_range * bot.range_mult
			if hp_ratio < 0.28 and dist < eff_range * 1.1:
				move_vec = (-dir * 0.72 + tangent * 0.55).normalized()
			elif dist > eff_range * 0.85:
				move_vec = (dir * 0.82 + tangent * 0.32).normalized()
				if best_action == &"hunt_abomination" and dist > 5.0 and bot.dash_cooldown <= 0.0:
					request_dash = true
			elif dist < eff_range * 0.48:
				move_vec = (-dir * 0.55 + tangent * 0.65).normalized()
			else:
				move_vec = (tangent * 0.78).normalized()
		&"patrol_wander":
			var wander_diff: Vector2 = best_target_pos - bot.pos
			if wander_diff.length_squared() > 0.1:
				move_vec = wander_diff.normalized() * 0.65
			else:
				move_vec = Vector2.ZERO

	return {
		"action": best_action,
		"score": best_score,
		"move_input": move_vec,
		"dash": request_dash,
	}
