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
	assert_eq(bot.slots[PartData.Slot.ARMS], &"base_fist", "dead_bot_lost_chainsaw_arm")
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
	p.pos = Vector2(0.0, 0.0)
	p.attack_cooldown = 0.0
	target_bot.pos = Vector2(1.2, 0.0)
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
