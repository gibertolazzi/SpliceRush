extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	await process_frame
	var test_methods: Array[String] = [
		"test_i18n_translations",
		"test_twelve_combatants_and_slots",
		"test_authoritative_movement_and_anticheat",
		"test_auto_attack_nearest_target",
		"test_destructible_grid_blocks",
		"test_virtual_joystick_and_rebind",
		"test_part_drop_on_kill_and_pickup_transforms_body",
		"test_abomination_activation_and_triple_drop",
	]
	for t: String in test_methods:
		var ok: Variant = call(t)
		if ok != true:
			failed += 1
			push_error("FAIL %s: did not finish cleanly" % t)
	print("Results: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected %s, got %s" % [label, str(expected), str(actual)])

func assert_true(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("FAIL %s: expected true, got false" % label)

func test_i18n_translations() -> bool:
	I18nService.register_translations()
	TranslationServer.set_locale("it")
	assert_eq(tr(&"GAME_TITLE_TOP"), "SPLICE", "i18n_it_title")
	assert_true(tr(&"HUD_BECOME_ABOMINATION").find("ABOMINIO") != -1, "i18n_it_abominio")
	assert_eq(tr(&"PART_CHAINSAW_ARM"), "Motosega", "i18n_it_chainsaw")
	TranslationServer.set_locale("en")
	assert_true(tr(&"HUD_BECOME_ABOMINATION").find("ABOMINATION") != -1, "i18n_en_abomination")
	assert_eq(tr(&"PART_CHAINSAW_ARM"), "Chainsaw Arm", "i18n_en_chainsaw")
	TranslationServer.set_locale("it")
	return true

func test_twelve_combatants_and_slots() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	assert_eq(srv.combatants.size(), 12, "combatants_count_12")
	assert_eq(srv.combatants[0].is_bot, false, "player_0_is_human")
	assert_eq(srv.combatants[1].is_bot, true, "fighter_1_is_bot")
	assert_eq(srv.combatants[0].slots.size(), 4, "player_has_4_slots")
	srv.free()
	return true

func test_authoritative_movement_and_anticheat() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	var p: MatchServer.CombatantState = srv.combatants[0]
	p.pos = Vector2(0.0, 0.0)
	p.vel = Vector2.ZERO
	srv.submit_client_input(0, Vector2(10.0, 0.0), false)
	assert_true(is_equal_approx(p.move_input.length(), 1.0), "server_clamps_client_input_length")
	for _i: int in range(10):
		srv.step_simulation(1.0 / 30.0)
	assert_true(p.pos.x > 0.5, "player_moved_right_on_xz_plane")
	srv.free()
	return true

func test_auto_attack_nearest_target() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	for c: MatchServer.CombatantState in srv.combatants:
		c.pos = Vector2(50.0, 50.0)
	var p: MatchServer.CombatantState = srv.combatants[0]
	var enemy_far: MatchServer.CombatantState = srv.combatants[1]
	var enemy_near: MatchServer.CombatantState = srv.combatants[2]
	p.pos = Vector2(0.0, 0.0)
	p.attack_cooldown = 0.0
	enemy_far.pos = Vector2(2.4, 0.0)
	enemy_near.pos = Vector2(1.3, 0.0)
	var hp_before: int = enemy_near.hp
	var far_hp_before: int = enemy_far.hp
	var expected_dmg: int = maxi(1, int(round(float(srv.balance.auto_attack_damage) * p.damage_mult)))
	srv.step_simulation(1.0 / 30.0)
	assert_eq(enemy_near.hp, hp_before - expected_dmg, "nearest_enemy_damaged")
	assert_eq(enemy_far.hp, far_hp_before, "far_enemy_untouched")
	assert_eq(p.last_target_id, enemy_near.id, "auto_attack_targeted_nearest_id")
	assert_true(srv.event_log.size() >= 1, "attack_logged_for_clip_reconstruction")
	srv.free()
	return true

func test_destructible_grid_blocks() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	var target_cell := Vector2i(-5, -2)
	assert_eq(int(srv.grid_cells[target_cell]), MatchServer.CellType.DESTRUCTIBLE_BLOCK, "block_initially_destructible")
	var destroyed: bool = srv.damage_block(target_cell, 999)
	assert_eq(destroyed, true, "block_destroyed_on_lethal_damage")
	assert_eq(int(srv.grid_cells[target_cell]), MatchServer.CellType.FLOOR, "destroyed_block_becomes_floor")
	srv.free()
	return true

func test_virtual_joystick_and_rebind() -> bool:
	var zero_vec: Vector2 = InputRemapper.apply_radial_deadzone(Vector2(0.08, 0.05), 0.16, 1.0)
	assert_eq(zero_vec, Vector2.ZERO, "deadzone_filters_small_drift")
	var full_vec: Vector2 = InputRemapper.apply_radial_deadzone(Vector2(0.0, -1.0), 0.16, 1.0)
	assert_true(is_equal_approx(full_vec.y, -1.0), "deadzone_preserves_full_deflection")

	var vj := TouchJoystick.new()
	root.add_child(vj)
	var out_v: Vector2 = vj.simulate_drag(Vector2(100.0, 800.0), Vector2(100.0, 700.0))
	assert_true(out_v.y < -0.9, "virtual_joystick_drag_up")
	vj.free()

	var key_q := InputEventKey.new()
	key_q.physical_keycode = KEY_Q
	var rebound: bool = InputRemapper.rebind_action(&"ability_action", key_q)
	assert_eq(rebound, true, "rebind_ability_to_q_succeeds")
	var conflict: bool = InputRemapper.rebind_action(&"move_left", key_q)
	assert_eq(conflict, false, "rebind_conflict_detected")
	return true

func test_part_drop_on_kill_and_pickup_transforms_body() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	srv.dropped_parts.clear()
	for c: MatchServer.CombatantState in srv.combatants:
		if c.id >= 2:
			c.alive = false
			c.respawn_timer = 999.0

	var p: MatchServer.CombatantState = srv.combatants[0]
	var bot: MatchServer.CombatantState = srv.combatants[1]
	# Give player base arms and bot a Chainsaw Arm
	p.slots[PartData.Slot.ARMS] = &"base_fist"
	srv._recalc_combatant_stats(p, false)
	bot.slots = {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"chainsaw_arm",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}
	srv._recalc_combatant_stats(bot, false)

	p.pos = Vector2(0.0, 0.0)
	p.attack_cooldown = 0.0
	bot.pos = Vector2(1.0, 0.0)
	bot.hp = 5 # 1 hit away from death

	# Step 1: Player auto-attacks and kills bot -> Chainsaw Arm drops!
	srv.step_simulation(1.0 / 30.0)
	assert_eq(bot.alive, false, "bot_killed_by_auto_attack")
	assert_eq(bot.slots[PartData.Slot.ARMS], &"base_fist", "dead_bot_lost_chainsaw_arm")
	assert_eq(srv.dropped_parts.size(), 1, "one_part_dropped_on_kill")
	var drop: MatchServer.DroppedPartState = srv.dropped_parts[0]
	assert_eq(drop.part_id, &"chainsaw_arm", "dropped_part_is_chainsaw_arm")

	# Step 2: Move player onto the dropped part and advance past grace period
	var stolen_before: int = p.stolen_parts_count
	for _i: int in range(10):
		p.pos = drop.pos
		srv.step_simulation(1.0 / 30.0)
	assert_eq(srv.dropped_parts.size(), 0, "dropped_part_picked_up_from_ground")
	assert_eq(p.slots[PartData.Slot.ARMS], &"chainsaw_arm", "player_equipped_chainsaw_arm")
	assert_eq(p.stolen_parts_count, stolen_before + 1, "stolen_parts_count_incremented")

	# Verify 3D rig mesh socket swap
	var fighter_3d := BlockyFighter3D.new()
	root.add_child(fighter_3d)
	fighter_3d.setup_fighter(0, false, p.base_color, 0, {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"base_fist",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}, false)
	var before_children: int = fighter_3d.left_arm_socket.get_child_count()
	fighter_3d.apply_slots(p.slots, p.is_abomination, true)
	var after_children: int = fighter_3d.left_arm_socket.get_child_count()
	assert_true(after_children != before_children, "3d_arm_socket_mesh_changed_on_equip")
	fighter_3d.free()
	srv.free()
	return true

func test_abomination_activation_and_triple_drop() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	srv.dropped_parts.clear()

	var bot: MatchServer.CombatantState = srv.combatants[2]
	bot.slots = {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"giant_fist",
		PartData.Slot.LEGS: &"spring_legs",
		PartData.Slot.CORE: &"shield_core",
	}
	srv._recalc_combatant_stats(bot, false)
	assert_eq(bot.is_abomination, false, "not_abomination_with_one_common_slot")

	# Equip Rare+ head -> all 4 slots are now Rare+ -> Abomination!
	srv.equip_part_on_combatant(bot.id, &"laser_eye")
	assert_eq(bot.is_abomination, true, "becomes_abomination_with_4_rare_plus_parts")

	# Defeating the Abomination drops 3 parts!
	srv._handle_combatant_death(bot, srv.combatants[0])
	assert_eq(srv.dropped_parts.size(), 3, "abomination_drops_3_parts_on_death")
	assert_eq(bot.is_abomination, false, "abomination_lost_status_after_losing_parts")
	srv.free()
	return true
