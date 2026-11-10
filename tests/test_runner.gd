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
		"test_bot_utility_ai_decisions",
		"test_90s_match_frenzy_collapse_result_and_rematch",
		"test_3s_viral_clip_and_game_feel",
		"test_logo_and_londrina_font_resources",
		"test_manual_attack_and_bot_rebalance_and_animated_intro",
		"test_brawl_royale_lives_and_elimination",
		"test_severed_limb_debuffs",
		"test_multiple_map_themes",
		"test_combat_juice_and_stolen_flying_part",
		"test_customization_hangar_stage_and_cards",
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
	p.pos = Vector2(3.0, 3.0)
	p.vel = Vector2.ZERO
	srv.submit_client_input(0, Vector2(10.0, 0.0), false)
	assert_true(is_equal_approx(p.move_input.length(), 1.0), "server_clamps_client_input_length")
	for _i: int in range(10):
		srv.step_simulation(1.0 / 30.0)
	assert_true(p.pos.x > 3.5, "player_moved_right_on_xz_plane")
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
	var target_cell := Vector2i(-9, -5)
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
	bot.hp = 5

	srv.step_simulation(1.0 / 30.0)
	assert_eq(bot.alive, false, "bot_killed_by_auto_attack")
	assert_true(PartCatalog.is_severed(bot.slots[PartData.Slot.ARMS]), "dead_bot_lost_chainsaw_arm")
	assert_eq(srv.dropped_parts.size(), 1, "one_part_dropped_on_kill")
	var drop: MatchServer.DroppedPartState = srv.dropped_parts[0]
	assert_eq(drop.part_id, &"chainsaw_arm", "dropped_part_is_chainsaw_arm")

	var stolen_before: int = p.stolen_parts_count
	for _i: int in range(10):
		p.pos = drop.pos
		srv.step_simulation(1.0 / 30.0)
	assert_eq(srv.dropped_parts.size(), 0, "dropped_part_picked_up_from_ground")
	assert_eq(p.slots[PartData.Slot.ARMS], &"chainsaw_arm", "player_equipped_chainsaw_arm")
	assert_eq(p.stolen_parts_count, stolen_before + 1, "stolen_parts_count_incremented")

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

	srv.equip_part_on_combatant(bot.id, &"laser_eye")
	assert_eq(bot.is_abomination, true, "becomes_abomination_with_4_rare_plus_parts")

	srv._handle_combatant_death(bot, srv.combatants[0])
	assert_eq(srv.dropped_parts.size(), 3, "abomination_drops_3_parts_on_death")
	assert_eq(bot.is_abomination, false, "abomination_lost_status_after_losing_parts")
	srv.free()
	return true

func test_bot_utility_ai_decisions() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = true
	root.add_child(srv)
	srv.dropped_parts.clear()

	var bot: MatchServer.CombatantState = srv.combatants[1]
	bot.slots = {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"base_fist",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}
	srv._recalc_combatant_stats(bot, false)
	bot.pos = Vector2(0.0, 0.0)

	# Place a Legendary part 1.5m to the right -> Utility AI should choose collect_upgrade_part
	srv.spawn_dropped_part(&"laser_eye", Vector2(1.5, 0.0), Vector2.ZERO, true)
	var dec_loot: Dictionary = BotUtilityAI.decide_bot_input(bot, srv, srv.get_safe_bounds_xz())
	assert_eq(dec_loot["action"], &"collect_upgrade_part", "utility_ai_prioritizes_nearby_legendary_upgrade")
	assert_true((dec_loot["move_input"] as Vector2).x > 0.8, "utility_ai_steers_toward_upgrade_part")

	# Place bot on the outer edge during Frenzy -> Utility AI should choose evade_collapse
	srv.match_phase = MatchServer.MatchPhase.FRENZY
	var safe_b: Vector2 = srv.get_safe_bounds_xz()
	bot.pos = Vector2(safe_b.x * 0.98, 0.0)
	var dec_evade: Dictionary = BotUtilityAI.decide_bot_input(bot, srv, safe_b)
	assert_eq(dec_evade["action"], &"evade_collapse", "utility_ai_evades_collapsing_frenzy_edge")
	assert_true((dec_evade["move_input"] as Vector2).x < -0.8, "utility_ai_steers_inward_from_edge")
	srv.free()
	return true

func test_90s_match_frenzy_collapse_result_and_rematch() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = true
	root.add_child(srv)
	srv.start_new_match(0.0, false)
	assert_eq(srv.match_phase, MatchServer.MatchPhase.SPAWN, "match_starts_in_spawn_phase")

	# Step past 60s into Frenzy
	srv.match_elapsed_sec = 59.95
	srv.step_simulation(0.1)
	assert_eq(srv.match_phase, MatchServer.MatchPhase.FRENZY, "match_enters_frenzy_at_60s")
	assert_eq(srv.collapsed_rings_count, 1, "outer_ring_collapsed_on_frenzy_start")
	var outer_cell := Vector2i(-srv.balance.grid_width / 2, 0)
	assert_eq(int(srv.grid_cells[outer_cell]), MatchServer.CellType.VOID, "outer_ring_cell_is_void")

	# Step to 90s match end
	srv.match_elapsed_sec = 89.95
	srv.step_simulation(0.1)
	assert_eq(srv.match_phase, MatchServer.MatchPhase.RESULT, "match_enters_result_at_90s")
	assert_true(is_equal_approx(srv.result_timer_sec, 5.0), "result_screen_timer_is_5_seconds")
	var board: Array[Dictionary] = srv.build_leaderboard()
	assert_eq(board.size(), 12, "leaderboard_has_12_combatants")
	assert_true(int(board[0]["total_mass"]) >= int(board[1]["total_mass"]), "leaderboard_sorted_by_mass_desc")

	# 1-Tap Rematch resets match cleanly
	srv.request_rematch()
	assert_eq(srv.match_phase, MatchServer.MatchPhase.SPAWN, "rematch_resets_to_spawn_phase")
	assert_eq(srv.collapsed_rings_count, 0, "rematch_restores_collapsed_rings")
	assert_eq(int(srv.grid_cells[outer_cell]), MatchServer.CellType.FLOOR, "rematch_restores_outer_floor_cells")
	srv.free()
	return true

func test_3s_viral_clip_and_game_feel() -> bool:
	var sc := SoundController.new()
	root.add_child(sc)
	assert_true(AudioServer.get_bus_index(&"Music") != -1, "audio_bus_music_exists")
	assert_true(AudioServer.get_bus_index(&"SFX") != -1, "audio_bus_sfx_exists")
	assert_true(sc.stream_steal_stinger != null, "steal_stinger_wav_synthesized")

	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	for c: MatchServer.CombatantState in srv.combatants:
		if c.id >= 2:
			c.alive = false
			c.respawn_timer = 999.0

	srv.setup_viral_clip_scenario()
	var p0: MatchServer.CombatantState = srv.combatants[0]
	var bot1: MatchServer.CombatantState = srv.combatants[1]
	assert_eq(p0.slots[PartData.Slot.LEGS], &"spring_legs", "clip_starts_with_spring_legs")
	assert_eq(p0.is_abomination, false, "clip_starts_not_abomination")
	assert_eq(bot1.slots[PartData.Slot.ARMS], &"chainsaw_arm", "enemy_has_chainsaw_arm")
	assert_eq(bot1.slots[PartData.Slot.HEAD], &"laser_eye", "enemy_has_laser_eye")

	# 1. Spring-legs dash + counter-attack kills enemy -> Chainsaw Arm & Laser Eye drop
	srv.submit_client_input(0, (bot1.pos - p0.pos).normalized(), true)
	sc.play_dash_sfx()
	srv.step_simulation(1.0 / 30.0)
	assert_eq(bot1.alive, false, "clip_enemy_defeated")
	assert_true(srv.dropped_parts.size() >= 1, "clip_parts_dropped")

	# 2. Steal Chainsaw Arm within 3s -> Transform into Abomination + Stinger!
	for _i: int in range(15):
		if not srv.dropped_parts.is_empty():
			p0.pos = srv.dropped_parts[srv.dropped_parts.size() - 1].pos
		srv.step_simulation(1.0 / 30.0)
	sc.play_steal_stinger()
	sc.play_abomination_stinger()

	assert_eq(p0.slots[PartData.Slot.ARMS], &"chainsaw_arm", "clip_player_stole_chainsaw_arm")
	assert_eq(p0.is_abomination, true, "clip_player_transformed_into_abomination")
	assert_eq(sc.current_music_mode, &"abomination", "clip_music_switched_to_abomination")

	sc.free()
	srv.free()
	return true

func test_logo_and_londrina_font_resources() -> bool:
	var f_bold: Font = load("res://game/ui/fonts/LondrinaSolid-Black.ttf")
	var f_regular: Font = load("res://game/ui/fonts/LondrinaSolid-Regular.ttf")
	var l_tex: Texture2D = load("res://game/ui/assets/logo.svg")
	assert_true(f_bold != null, "londrina_solid_black_font_loaded")
	assert_true(f_regular != null, "londrina_solid_regular_font_loaded")
	assert_true(l_tex != null, "splice_rush_vector_logo_loaded")
	if l_tex != null:
		assert_true(l_tex.get_width() > 0, "logo_texture_has_valid_width")
		assert_true(l_tex.get_height() > 0, "logo_texture_has_valid_height")

	var hud := VerticalHUD.new()
	root.add_child(hud)
	assert_true(hud.font_bold != null, "hud_has_font_bold")
	assert_true(hud.font_regular != null, "hud_has_font_regular")
	assert_true(hud.logo_texture != null, "hud_has_logo_texture")
	hud.free()
	return true

func test_manual_attack_and_bot_rebalance_and_animated_intro() -> bool:
	# 1. Test translations for mobile attack button and animated tutorial
	I18nService.register_translations()
	TranslationServer.set_locale("it")
	assert_eq(tr(&"HUD_ATTACK_BTN"), "ATTACCO", "it_hud_attack_btn")
	assert_true(tr(&"HUD_TUTORIAL_STEAL_SUB").length() > 0, "it_hud_tutorial_steal_sub")
	assert_true(tr(&"HUD_TUTORIAL_ABOM_SUB").length() > 0, "it_hud_tutorial_abom_sub")
	assert_true(tr(&"HUD_TUTORIAL_TAP_TO_SKIP").length() > 0, "it_hud_tutorial_tap_to_skip")
	TranslationServer.set_locale("en")
	assert_eq(tr(&"HUD_ATTACK_BTN"), "ATTACK", "en_hud_attack_btn")
	TranslationServer.set_locale("it")

	# 2. Test bot loadouts & rebalanced difficulty
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	# Verify bot loadouts don't have overpowered parts at match start
	for i: int in range(1, srv.combatants.size()):
		var b: MatchServer.CombatantState = srv.combatants[i]
		# Ensure bots do not start with chainsaw arm or giant fist by default
		assert_true(b.slots[PartData.Slot.ARMS] == &"base_fist" or b.slots[PartData.Slot.ARMS] == &"base_arms", "bot_starts_with_balanced_arms")

	# 3. Test manual attack click / button
	var p: MatchServer.CombatantState = srv.combatants[0]
	var target_bot: MatchServer.CombatantState = srv.combatants[1]
	p.pos = Vector2(2.0, 2.0)
	p.attack_cooldown = 0.0
	target_bot.pos = Vector2(3.2, 2.0)
	target_bot.hp = 100
	target_bot.attack_cooldown = 0.0

	# Submit manual attack button press
	srv.submit_client_input(0, Vector2.ZERO, false, true)
	assert_eq(p.attack_requested, true, "manual_attack_requested_flag_set")

	# Step simulation - manual attack must execute and damage bot
	srv.step_simulation(1.0 / 30.0)
	assert_true(target_bot.hp < 100, "manual_attack_damaged_enemy")
	assert_true(target_bot.attack_cooldown >= 0.25, "manual_attack_staggered_enemy_cadence")

	# 4. Test TouchJoystick Attack Button
	var joy := TouchJoystick.new()
	root.add_child(joy)
	assert_true(joy.has_signal(&"attack_triggered"), "touch_joystick_has_attack_signal")
	assert_true(joy.has_signal(&"ability_triggered"), "touch_joystick_has_ability_signal")
	joy.free()

	# 5. Test VerticalHUD intro tutorial timer lifecycle
	var hud := VerticalHUD.new()
	root.add_child(hud)
	assert_eq(hud.intro_tutorial_timer, 6.0, "hud_starts_with_6s_intro_timer")
	hud._process(3.5)
	assert_true(hud.intro_tutorial_timer <= 2.5, "hud_advances_to_phase_2")
	# Fast skip upon player action
	hud.intro_tutorial_timer = minf(hud.intro_tutorial_timer, 0.8)
	hud._process(0.9)
	assert_eq(hud.intro_tutorial_timer, 0.0, "hud_intro_tutorial_fades_out_cleanly")
	hud.on_match_restarted()
	assert_eq(hud.intro_tutorial_timer, 6.0, "hud_resets_intro_on_rematch")

	hud.free()
	srv.free()
	return true

func test_brawl_royale_lives_and_elimination() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)

	# Verify 3 initial lives for all combatants
	for c: MatchServer.CombatantState in srv.combatants:
		assert_eq(c.lives, 3, "combatant_starts_with_3_lives")
		assert_eq(c.eliminated, false, "combatant_not_eliminated_at_start")

	# Advance to Frenzy phase
	srv.start_new_match(61.0, false)
	assert_true(srv.is_frenzy_active(), "frenzy_active_at_61s")

	var victim: MatchServer.CombatantState = srv.combatants[1]
	var killer: MatchServer.CombatantState = srv.combatants[0]

	# Lethal blow 1 in Frenzy
	victim.hp = 1
	srv._handle_combatant_death(victim, killer)
	assert_eq(victim.lives, 2, "victim_loses_1_life_on_death_in_frenzy")
	assert_eq(victim.eliminated, false, "victim_not_eliminated_with_2_lives")

	# Lethal blow 2
	victim.hp = 1
	srv._handle_combatant_death(victim, killer)
	assert_eq(victim.lives, 1, "victim_loses_second_life")
	assert_eq(victim.eliminated, false, "victim_not_eliminated_with_1_life")

	# Lethal blow 3 -> Permanent elimination
	victim.hp = 1
	srv._handle_combatant_death(victim, killer)
	assert_eq(victim.lives, 0, "victim_lives_reduced_to_zero")
	assert_eq(victim.eliminated, true, "victim_permanently_eliminated")

	# Elimination rankings in leaderboard
	var board: Array[Dictionary] = srv.build_leaderboard()
	var victim_found: bool = false
	for entry: Dictionary in board:
		if int(entry["id"]) == 1:
			assert_eq(entry["eliminated"], true, "leaderboard_reflects_elimination")
			victim_found = true
	assert_true(victim_found, "eliminated_victim_in_leaderboard")

	srv.free()
	return true

func test_severed_limb_debuffs() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	var c: MatchServer.CombatantState = srv.combatants[0]

	# Base combatant multipliers are 1.0
	srv._recalc_combatant_stats(c, false)
	assert_true(is_equal_approx(c.speed_mult, 1.0), "base_speed_mult_is_1")
	assert_true(is_equal_approx(c.damage_mult, 1.0), "base_damage_mult_is_1")

	# Sever one arm -> moderate damage debuff (~0.70)
	c.slots[PartData.Slot.ARMS] = &"severed_one_arm"
	srv._recalc_combatant_stats(c, false)
	assert_true(c.damage_mult <= 0.75 and c.damage_mult >= 0.65, "severed_one_arm_applies_moderate_debuff")

	# Sever both arms -> severe damage debuff (~0.35)
	c.slots[PartData.Slot.ARMS] = &"severed_arms"
	srv._recalc_combatant_stats(c, false)
	assert_true(c.damage_mult <= 0.40, "severed_arms_applies_severe_damage_debuff")

	# Reset arms to isolate leg test
	c.slots[PartData.Slot.ARMS] = &"base_fist"

	# Sever one leg -> moderate speed debuff (~0.75)
	c.slots[PartData.Slot.LEGS] = &"severed_one_leg"
	srv._recalc_combatant_stats(c, false)
	assert_true(c.speed_mult <= 0.80 and c.speed_mult >= 0.70, "severed_one_leg_applies_moderate_debuff")

	# Sever both legs -> severe speed debuff (~0.50)
	c.slots[PartData.Slot.LEGS] = &"severed_legs"
	srv._recalc_combatant_stats(c, false)
	assert_true(c.speed_mult <= 0.55, "severed_legs_applies_severe_speed_debuff")

	# Restoring arms and legs removes debuffs
	c.slots[PartData.Slot.ARMS] = &"base_fist"
	c.slots[PartData.Slot.LEGS] = &"base_boots"
	srv._recalc_combatant_stats(c, false)
	assert_true(c.damage_mult >= 0.95, "restoring_arms_restores_damage")
	assert_true(c.speed_mult >= 0.95, "restoring_legs_restores_speed")

	srv.free()
	return true

func test_multiple_map_themes() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)

	# Theme 1: Violet Ruins
	srv.set_map_theme(MatchServer.MapTheme.VIOLET_RUINS)
	assert_eq(srv.current_map_theme, MatchServer.MapTheme.VIOLET_RUINS, "violet_ruins_theme_set")
	assert_true(srv.grid_cells.size() >= 1000, "violet_ruins_has_32x40_grid")

	# Theme 2: Cyber Factory
	srv.set_map_theme(MatchServer.MapTheme.CYBER_FACTORY)
	assert_eq(srv.current_map_theme, MatchServer.MapTheme.CYBER_FACTORY, "cyber_factory_theme_set")
	assert_true(srv.grid_cells.has(Vector2i(-6, -10)), "cyber_factory_has_cyber_hazards")

	# Theme 3: Floating Hex
	srv.set_map_theme(MatchServer.MapTheme.FLOATING_HEX)
	assert_eq(srv.current_map_theme, MatchServer.MapTheme.FLOATING_HEX, "floating_hex_theme_set")
	# In Floating Hex, void cells are not present in grid_cells
	assert_true(srv.grid_cells.size() < 1280, "floating_hex_has_void_islands")

	srv.free()
	return true

func test_combat_juice_and_stolen_flying_part() -> bool:
	# 1. Test I18n translations for "RUBATO!" and slot & rarity titles
	I18nService.register_translations()
	TranslationServer.set_locale("it")
	assert_eq(tr(&"HUD_PART_STOLEN_BANNER_TITLE"), "RUBATO!", "it_part_stolen_banner_title")
	assert_eq(tr(&"RARITY_EPIC"), "EPICO", "it_rarity_epic")
	assert_eq(tr(&"SLOT_NAME_ARMS"), "BRACCIA", "it_slot_arms")
	TranslationServer.set_locale("en")
	assert_eq(tr(&"HUD_PART_STOLEN_BANNER_TITLE"), "STOLEN!", "en_part_stolen_banner_title")
	assert_eq(tr(&"RARITY_EPIC"), "EPIC", "en_rarity_epic")
	TranslationServer.set_locale("it")

	# 2. Test ArenaBuilder3D Juice Pools
	var ab := ArenaBuilder3D.new()
	root.add_child(ab)
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	ab.build_from_server(srv)

	assert_true(ab.impact_star_pool.size() > 0, "arena_builder_has_impact_star_pool")
	assert_true(ab.spark_pool.size() > 0, "arena_builder_has_spark_pool")
	assert_true(ab.dust_pool.size() > 0, "arena_builder_has_dust_pool")

	# 3. Test Impact Starburst and Dash Dust Spawning
	ab.spawn_impact_star(Vector2(2.0, 3.0), false)
	assert_eq(ab.active_impact_stars.size(), 1, "active_impact_star_spawned")
	assert_true(ab.active_sparks.size() >= 4, "impact_sparks_spawned")

	ab.spawn_dash_dust(Vector3(1.0, 0.0, 2.0), Vector2(-1.0, 0.0))
	assert_true(ab.active_dust.size() >= 4, "dash_dust_puffs_spawned")

	# 4. Test Flying Stolen Part Visual & Arrival Callback
	var target_dummy := Node3D.new()
	target_dummy.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(target_dummy)

	var arrival_state: Array[bool] = [false]
	var on_arrive := func() -> void:
		arrival_state[0] = true

	ab.spawn_flying_part(999, &"chainsaw_arm", int(PartData.Slot.ARMS), int(PartData.Rarity.EPIC), Vector2(4.0, 4.0), target_dummy, on_arrive)
	assert_eq(ab.active_flying_parts.size(), 1, "flying_part_registered_in_flight")

	# Step VFX to completion (duration 0.28s)
	ab.update_arena_vfx(0.15)
	assert_eq(arrival_state[0], false, "flying_part_in_transit")
	ab.update_arena_vfx(0.16)
	assert_eq(arrival_state[0], true, "flying_part_arrived_at_target_body")
	assert_eq(ab.active_flying_parts.size(), 0, "flying_part_freed_on_arrival")

	# 5. Test BlockyFighter3D Squash & Stretch and Burst Ring
	var fighter := BlockyFighter3D.new()
	root.add_child(fighter)
	fighter.setup_fighter(0, false, Color.WHITE, 0, srv.combatants[0].slots, false)
	assert_true(fighter.transform_burst_ring != null, "fighter_has_transform_burst_ring")

	fighter.trigger_transform_pop()
	assert_true(fighter._transform_flash_timer > 0.0, "transform_flash_timer_started")
	assert_eq(fighter.transform_burst_ring.visible, true, "transform_burst_ring_active")

	# 6. Test VerticalHUD Stolen Banner & Slot Aura Pulse
	var hud := VerticalHUD.new()
	root.add_child(hud)
	hud.show_part_stolen_banner(&"chainsaw_arm", int(PartData.Rarity.EPIC), int(PartData.Slot.ARMS))
	assert_true(hud._stolen_banner_timer > 0.0, "stolen_banner_timer_active")
	assert_eq(hud._stolen_part_id, &"chainsaw_arm", "stolen_banner_part_id_set")
	assert_true(hud._slot_flash_timers[int(PartData.Slot.ARMS)] > 0.0, "stolen_slot_flashing_gold_aura")

	hud.free()
	fighter.free()
	target_dummy.free()
	srv.free()
	ab.free()
	return true

func test_customization_hangar_stage_and_cards() -> bool:
	# 1. Test Part Catalog Trait Descriptions for all 16 parts
	var all_parts: Array[StringName] = [
		&"laser_eye", &"visor_head", &"spike_helm", &"base_head",
		&"chainsaw_arm", &"giant_fist", &"mega_claws", &"base_fist",
		&"rocket_legs", &"roller_wheels", &"spring_legs", &"base_boots",
		&"crown_core", &"shield_core", &"magnet_core", &"base_core"
	]
	for pid: StringName in all_parts:
		var desc: String = PartCatalog.get_part_trait_description(pid)
		assert_true(desc != "" and desc != "Pezzo Speciale", "trait_desc_valid_%s" % pid)

	# 2. Test SoundController equip SFX
	var sc := SoundController.new()
	root.add_child(sc)
	sc.play_equip_sfx()
	assert_eq(sc.last_played_stinger, &"equip", "sound_controller_equip_stinger_played")
	sc.free()

	# 3. Test I18n translations for customization
	I18nService.register_translations()
	TranslationServer.set_locale("it")
	assert_eq(tr(&"BTN_EQUIP_PART"), "EQUIPA PEZZO", "it_btn_equip_part")
	assert_eq(tr(&"LABEL_EQUIPPED"), "EQUIPAGGIATO ✓", "it_label_equipped")
	assert_eq(tr(&"LABEL_TRAIT"), "EFFETTO:", "it_label_trait")
	assert_eq(tr(&"LABEL_MASS"), "MASSA", "it_label_mass")
	assert_eq(tr(&"LABEL_SLOT"), "SLOT", "it_label_slot")

	TranslationServer.set_locale("en")
	assert_eq(tr(&"BTN_EQUIP_PART"), "EQUIP PART", "en_btn_equip_part")
	assert_eq(tr(&"LABEL_EQUIPPED"), "EQUIPPED ✓", "en_label_equipped")
	assert_eq(tr(&"LABEL_TRAIT"), "TRAIT:", "en_label_trait")
	assert_eq(tr(&"LABEL_MASS"), "MASS", "en_label_mass")
	assert_eq(tr(&"LABEL_SLOT"), "SLOT", "en_label_slot")
	TranslationServer.set_locale("it")

	# 4. Test CustomizationMenu Selection, Tab Switching & Committing
	var menu := CustomizationMenu.new()
	root.add_child(menu)
	assert_eq(menu.selected_part_id, &"base_head", "custom_menu_initial_head_selected")

	# Switch to ARMS tab
	menu._switch_tab(CustomizationMenu.TAB_ARMS)
	assert_eq(menu.current_tab, CustomizationMenu.TAB_ARMS, "custom_menu_tab_arms_active")
	assert_eq(menu.selected_part_id, &"base_fist", "custom_menu_arms_initial_equipped_selected")

	# Preview unequipped part (e.g. chainsaw_arm)
	menu._select_option(&"chainsaw_arm")
	assert_eq(menu.selected_part_id, &"chainsaw_arm", "custom_menu_chainsaw_selected")
	assert_eq(menu.equipped_slots[PartData.Slot.ARMS], &"base_fist", "equipped_slots_not_changed_until_commit")

	# Commit preview selection
	menu._commit_preview_selection()
	assert_eq(menu.equipped_slots[PartData.Slot.ARMS], &"chainsaw_arm", "equipped_slots_committed")

	# Switch to COLOR tab
	menu._switch_tab(CustomizationMenu.TAB_COLOR)
	assert_eq(menu.current_tab, CustomizationMenu.TAB_COLOR, "custom_menu_tab_color_active")
	menu._select_option(Color(0.95, 0.28, 0.28))
	assert_eq(menu.selected_color, Color(0.95, 0.28, 0.28), "custom_menu_color_selected")
	menu._commit_preview_selection()
	assert_eq(menu.equipped_color, Color(0.95, 0.28, 0.28), "custom_menu_color_committed")
	menu.free()

	# 5. Test 3D Hero Customization Stage in MainArenaController
	var controller := MainArenaController.new()
	controller.is_customizing = true
	root.add_child(controller)

	assert_eq(controller.is_customizing, true, "controller_is_customizing")
	assert_true(controller.customize_stage_root != null, "stage_root_created")
	assert_eq(controller.customize_stage_root.visible, true, "stage_root_visible_in_customization")
	assert_eq(controller.arena_builder.visible, false, "arena_builder_hidden_in_customization")
	assert_true(controller.customize_spotlight != null, "stage_spotlight_present")
	assert_true(controller.customize_light_shaft != null, "stage_light_shaft_present")
	assert_eq(controller.customize_floating_cubes.size(), 18, "stage_18_floating_cubes_and_sparks_present")

	# Test Hero idle breathing simulation
	controller._process(0.016)
	assert_true(controller._custom_stage_time > 0.0, "stage_time_advanced")

	# Test Part Selected feedback pop
	controller._on_custom_part_selected(int(PartData.Slot.HEAD), &"laser_eye")
	assert_eq(controller.fighter_nodes[0]._transform_flash_timer > 0.0, true, "hero_transform_pop_triggered_on_equip")

	controller.free()
	return true
