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
		"test_expressive_face_and_toon_materials",
		"test_statusfx_guy_character_model_and_sockets",
		"test_statusfx_effects_overlay_and_vfx",
		"test_statusfx_pedestal_aura_sphere_and_streaks",
		"test_statusfx_attack_and_shooting_vfx",
		"test_characters_collection_models_and_mixamo_rigs",
		"test_reference_mockup_vertical_hud",
		"test_ingame_character_visibility_and_walk_retargeting",
		"test_camera_follow_rotation_and_enemy_visibility",
		"test_abomination_transformation_at_9_parts",
		"test_in_game_settings_modal_non_pausing_and_realtime_combat",
		"test_hp_thresholds_pop_limbs_off_as_real_drops",
		"test_loose_limb_pickup_becomes_club_that_wears_out",
		"test_loose_limb_reattaches_as_graft_when_limb_missing",
		"test_ko_bursts_limbs_and_body_regrows_on_respawn",
		"test_loose_limb_expires_and_bots_seek_clubs",
		"test_limb_mesh_library_cuts_real_limbs_from_models",
		"test_fighter_shows_club_grafts_and_sockets",
		"test_dropped_pieces_render_real_limb_meshes",
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

func _special_drops(srv: MatchServer) -> Array[MatchServer.DroppedPartState]:
	var out: Array[MatchServer.DroppedPartState] = []
	for d: MatchServer.DroppedPartState in srv.dropped_parts:
		if not d.is_limb:
			out.append(d)
	return out

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
	assert_eq(_special_drops(srv).size(), 1, "one_part_dropped_on_kill")
	assert_true(srv.dropped_parts.size() > 1, "ko_also_bursts_loose_limbs")
	var drop: MatchServer.DroppedPartState = _special_drops(srv)[0]
	assert_eq(drop.part_id, &"chainsaw_arm", "dropped_part_is_chainsaw_arm")

	var stolen_before: int = p.stolen_parts_count
	for _i: int in range(10):
		p.pos = drop.pos
		srv.step_simulation(1.0 / 30.0)
	assert_eq(_special_drops(srv).size(), 0, "dropped_part_picked_up_from_ground")
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
	assert_eq(_special_drops(srv).size(), 3, "abomination_drops_3_parts_on_death")
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
		var specials: Array[MatchServer.DroppedPartState] = _special_drops(srv)
		if not specials.is_empty():
			p0.pos = specials[specials.size() - 1].pos
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

func test_expressive_face_and_toon_materials() -> bool:
	# Test Point 9: Big eyes, eyebrows, expressive mouth, toon shader, rim light, warmth boost and dark outline
	var root: Node = (self as SceneTree).root

	# 1. Test Player Fighter 0 (Blocky Hero)
	var hero := BlockyFighter3D.new()
	root.add_child(hero)
	hero.setup_fighter(0, false, Color.WHITE, 0, {}, false, BlockyFighter3D.CharacterModelType.BLOCKY_HERO)

	# Verify face root and alignment
	assert_true(hero.face_root != null, "hero_face_root_exists")
	assert_eq(hero.face_root.position, Vector3(0.0, 1.625, 0.118), "hero_face_root_position_aligned")
	assert_true(is_equal_approx(hero.face_root.rotation_degrees.x, -17.5), "hero_face_root_tilt_aligned")

	# Verify face elements
	assert_true(hero.face_eyes_root != null, "hero_face_eyes_root_exists")
	assert_true(hero.face_eyes_root.get_child_count() >= 8, "hero_big_eyes_with_sclera_iris_glints")
	assert_true(hero.face_root.get_child_count() >= 6, "hero_face_features_mask_eyebrows_mouth")

	# Verify toon shader on char_mesh
	assert_true(hero.char_mesh != null, "hero_char_mesh_exists")
	var mat: Material = hero.char_mesh.get_surface_override_material(0)
	assert_true(mat is ShaderMaterial, "hero_char_mesh_uses_shader_material")
	var smat := mat as ShaderMaterial
	assert_eq(smat.shader, BlockyFighter3D.TOON_SHADER, "hero_uses_toon_shader")
	assert_eq(smat.get_shader_parameter("use_texture"), true, "hero_toon_uses_albedo_texture")
	assert_eq(smat.get_shader_parameter("skin_warmth_boost"), 0.55, "hero_toon_has_skin_warmth_boost")
	assert_eq(smat.get_shader_parameter("rim_strength"), 0.48, "hero_toon_has_rim_light_strength")

	# Verify dark inverted-hull outline
	assert_true(smat.next_pass is ShaderMaterial, "hero_toon_has_outline_next_pass")
	var out_mat := smat.next_pass as ShaderMaterial
	assert_eq(out_mat.shader, BlockyFighter3D.OUTLINE_SHADER, "hero_outline_shader_assigned")
	assert_eq(out_mat.get_shader_parameter("outline_width"), 0.024, "hero_subtle_dark_outline_width")

	# 2. Test Head Slot Equipment Toggles
	# Default base_head -> eyes visible
	hero.apply_slots({PartData.Slot.HEAD: &"base_head"}, false, false)
	assert_eq(hero.face_eyes_root.visible, true, "eyes_visible_with_base_head")

	# laser_eye -> eyes hidden by visor, laser mesh in head socket
	hero.apply_slots({PartData.Slot.HEAD: &"laser_eye"}, false, false)
	assert_eq(hero.face_eyes_root.visible, false, "eyes_hidden_with_laser_eye")
	assert_true(hero.head_socket.get_child_count() >= 2, "laser_eye_visor_and_lens_present")

	# visor_head -> eyes hidden by cyber shades, shades mesh in head socket
	hero.apply_slots({PartData.Slot.HEAD: &"visor_head"}, false, false)
	assert_eq(hero.face_eyes_root.visible, false, "eyes_hidden_with_visor_head")
	assert_true(hero.head_socket.get_child_count() >= 2, "visor_head_sunglasses_present")

	# spike_helm -> eyes visible, crest on top of head
	hero.apply_slots({PartData.Slot.HEAD: &"spike_helm"}, false, false)
	assert_eq(hero.face_eyes_root.visible, true, "eyes_visible_with_spike_helm")
	assert_true(hero.head_socket.get_child_count() >= 1, "spike_helm_crest_present")

	# 3. Test Bot Fighter 1
	var bot := BlockyFighter3D.new()
	var bot_color := Color(0.95, 0.28, 0.28)
	root.add_child(bot)
	bot.setup_fighter(1, true, bot_color, 1, {}, false, BlockyFighter3D.CharacterModelType.BLOCKY_HERO)

	assert_eq(bot.is_bot, true, "bot_fighter_flag_set")
	assert_true(bot.face_root != null, "bot_has_face_root")
	var bot_mat := bot.char_mesh.get_surface_override_material(0) as ShaderMaterial
	assert_true(bot_mat != null, "bot_char_mesh_uses_toon_shader")
	assert_eq(bot_mat.get_shader_parameter("base_color"), bot_color, "bot_inherits_palette_base_color")

	hero.free()
	bot.free()
	return true

func test_statusfx_guy_character_model_and_sockets() -> bool:
	# 1. Test Guy Model Instantiation from StatusFXFree
	var guy_fighter := BlockyFighter3D.new()
	root.add_child(guy_fighter)
	var guy_color := Color(0.24, 0.58, 0.92)
	guy_fighter.setup_fighter(2, true, guy_color, 2, {}, false, BlockyFighter3D.CharacterModelType.STATUSFX_GUY)

	assert_eq(guy_fighter.character_model_type, BlockyFighter3D.CharacterModelType.STATUSFX_GUY, "statusfx_guy_type_set")
	assert_true(guy_fighter.hero_instance != null, "guy_model_instance_exists")
	assert_eq(guy_fighter.hero_instance.name, "GuyModel", "guy_model_instance_name_matches")

	# Mesh and Skeleton assertions
	assert_true(guy_fighter.char_mesh != null, "guy_char_mesh_exists")
	assert_eq(guy_fighter.char_mesh.name, "Chest", "guy_mesh_named_chest")
	assert_true(guy_fighter.skeleton != null, "guy_skeleton_exists")
	assert_eq(guy_fighter.skeleton.get_bone_count(), 588, "guy_skeleton_has_588_bones")

	# Sockets and Toon Shading
	assert_true(guy_fighter.head_socket != null, "guy_head_socket_exists")
	assert_true(guy_fighter.left_arm_socket != null, "guy_left_arm_socket_exists")
	assert_true(guy_fighter.right_arm_socket != null, "guy_right_arm_socket_exists")
	assert_true(guy_fighter.left_leg_socket != null, "guy_left_leg_socket_exists")
	assert_true(guy_fighter.right_leg_socket != null, "guy_right_leg_socket_exists")
	assert_true(guy_fighter.core_socket != null, "guy_core_socket_exists")

	# Apply parts on Guy model
	guy_fighter.apply_slots({
		PartData.Slot.HEAD: &"laser_eye",
		PartData.Slot.ARMS: &"chainsaw_arm",
		PartData.Slot.LEGS: &"rocket_legs",
		PartData.Slot.CORE: &"crown_core"
	}, false, false)
	assert_true(guy_fighter.head_socket.get_child_count() > 0, "guy_laser_eye_equipped")
	assert_true(guy_fighter.right_arm_socket.get_child_count() > 0, "guy_chainsaw_arm_equipped")
	assert_true(guy_fighter.right_leg_socket.get_child_count() > 0, "guy_rocket_legs_equipped")
	assert_true(guy_fighter.core_socket.get_child_count() > 0, "guy_crown_core_equipped")

	# Severed limbs
	guy_fighter.apply_slots({
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"severed_arms",
		PartData.Slot.LEGS: &"severed_legs",
		PartData.Slot.CORE: &"base_core"
	}, false, false)
	assert_true((guy_fighter.limb_extra_roots[&"arm_l"] as Node3D).get_child_count() > 0, "guy_severed_arm_stump_present")
	assert_true((guy_fighter.limb_extra_roots[&"leg_l"] as Node3D).get_child_count() > 0, "guy_severed_leg_stump_present")

	# Visual update animation: moving plays Walk, stationary plays Idle
	guy_fighter.update_visual_state(Vector2(2.0, 3.0), Vector2(1.5, 0.0), 0.0, 0.0, 0.0, true, 0.016)
	assert_eq(guy_fighter.anim_player.current_animation, "Walk", "guy_plays_walk_anim_when_moving")
	guy_fighter.update_visual_state(Vector2(2.0, 3.0), Vector2.ZERO, 0.0, 0.0, 0.0, true, 0.016)
	assert_eq(guy_fighter.anim_player.current_animation, "Idle", "guy_plays_idle_anim_when_stationary")

	guy_fighter.free()
	return true

func test_statusfx_effects_overlay_and_vfx() -> bool:
	var fighter := BlockyFighter3D.new()
	root.add_child(fighter)
	fighter.setup_fighter(0, false, Color.WHITE, 0)

	# 1. Test status overlay material attached to char_mesh
	assert_true(fighter.status_overlay_mat != null, "status_overlay_material_initialized")
	assert_true(fighter.char_mesh.material_overlay is ShaderMaterial, "material_overlay_assigned_to_mesh")

	# 2. Test Hurt Overlay Reaction
	fighter.update_visual_state(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, 0.30, true, 0.016)
	var hurt_amount: float = fighter.status_overlay_mat.get_shader_parameter("effect_amount")
	assert_true(hurt_amount > 0.3, "hurt_triggers_status_overlay_amount")
	var hurt_col: Color = fighter.status_overlay_mat.get_shader_parameter("primary_color")
	assert_true(hurt_col.r > 0.8 and hurt_col.b < 0.3, "hurt_overlay_is_red_hot")

	# 3. Test Transformation Burst Reaction
	fighter.trigger_transform_pop()
	fighter.update_visual_state(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, 0.0, true, 0.016)
	var xform_amount: float = fighter.status_overlay_mat.get_shader_parameter("effect_amount")
	assert_true(xform_amount > 0.5, "transform_pop_triggers_status_overlay_surge")

	# 4. Test Abomination Pulse
	fighter.is_abomination = true
	fighter.update_visual_state(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, 0.0, true, 0.016)
	var abom_amount: float = fighter.status_overlay_mat.get_shader_parameter("effect_amount")
	assert_true(abom_amount > 0.2, "abomination_triggers_pulsing_overlay")

	# 5. Test Shatter VFX instantiation
	var before_children: int = fighter.pivot.get_child_count()
	fighter.play_shatter_vfx(Vector3(0.0, 1.0, 0.0))
	var after_children: int = fighter.pivot.get_child_count()
	assert_true(after_children > before_children, "shatter_vfx_instantiated_into_pivot")

	fighter.free()
	return true

func test_statusfx_pedestal_aura_sphere_and_streaks() -> bool:
	var ab := ArenaBuilder3D.new()
	root.add_child(ab)
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)

	ab.build_from_server(srv)
	assert_true(ab.power_cube_node != null, "pedestal_power_cube_node_exists")

	# Check for aura sphere child on power_cube_node
	var found_aura_sphere: bool = false
	for c: Node in ab.power_cube_node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
			var mat: Material = (c as MeshInstance3D).material_override
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader == ArenaBuilder3D.AURA_SPHERE_SHADER:
				found_aura_sphere = true
				break
	assert_true(found_aura_sphere, "pedestal_power_cube_has_statusfx_aura_sphere")

	# Check for ground streaks on pedestal
	var ped: Node3D = ab.find_child("PowerPedestal", true, false) as Node3D
	assert_true(ped != null, "power_pedestal_node_found")
	var found_streaks: bool = false
	for c: Node in ped.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is QuadMesh:
			var mat: Material = (c as MeshInstance3D).material_override
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader == ArenaBuilder3D.STREAKS_SHADER:
				found_streaks = true
				break
	assert_true(found_streaks, "pedestal_has_statusfx_ground_streaks")

	ab.free()
	srv.free()
	return true

func test_statusfx_attack_and_shooting_vfx() -> bool:
	var ab := ArenaBuilder3D.new()
	root.add_child(ab)

	# 1. Test muzzle flash pool and spawn
	assert_eq(ab.active_statusfx_flashes.size(), 0, "no_flashes_initially")
	ab.spawn_statusfx_muzzle_flash(Vector2(2.0, 3.0), Color(0.20, 0.90, 1.00))
	assert_eq(ab.active_statusfx_flashes.size(), 1, "muzzle_flash_spawned")
	var flash_item: Dictionary = ab.active_statusfx_flashes[0]
	var flash_mesh: MeshInstance3D = flash_item["node"]
	assert_true(flash_mesh.visible, "flash_node_visible")
	var f_smat := flash_mesh.material_override as ShaderMaterial
	assert_true(f_smat != null, "flash_has_shader_material")
	var p_col: Color = f_smat.get_shader_parameter("primary_color")
	assert_true(absf(p_col.r - 0.20) < 0.05 and absf(p_col.g - 0.90) < 0.05, "flash_color_matches_laser_cyan")

	# 2. Test impact sphere pool and spawn
	assert_eq(ab.active_statusfx_impacts.size(), 0, "no_impacts_initially")
	ab.spawn_statusfx_impact(Vector2(4.0, 5.0), true, Color(1.0, 0.18, 0.58))
	assert_eq(ab.active_statusfx_impacts.size(), 1, "statusfx_impact_spawned")
	var imp_item: Dictionary = ab.active_statusfx_impacts[0]
	var imp_mesh: MeshInstance3D = imp_item["node"]
	assert_true(imp_mesh.visible, "impact_node_visible")
	var i_smat := imp_mesh.material_override as ShaderMaterial
	assert_true(i_smat != null, "impact_has_shader_material")
	var i_col: Color = i_smat.get_shader_parameter("primary_color")
	assert_true(absf(i_col.r - 1.0) < 0.05 and absf(i_col.g - 0.18) < 0.05, "impact_color_matches_abomination_magenta")
	assert_true(imp_item["peak_scale"] > 2.0, "ko_impact_has_larger_peak_scale")

	# 3. Test VFX update ticking and pool recycling
	ab.update_arena_vfx(0.10)
	assert_eq(ab.active_statusfx_flashes.size(), 0, "flash_recycled_after_ttl")
	assert_true(imp_mesh.scale.x > 0.5, "impact_expanded_during_animation")
	ab.update_arena_vfx(0.20)
	assert_eq(ab.active_statusfx_impacts.size(), 0, "impact_recycled_after_ttl")

	ab.free()
	return true

func test_characters_collection_models_and_mixamo_rigs() -> bool:
	var models: Array = [
		BlockyFighter3D.CharacterModelType.MAN_CUTIE,
		BlockyFighter3D.CharacterModelType.MAN_OFFICER,
		BlockyFighter3D.CharacterModelType.WOMAN_CUTIE,
		BlockyFighter3D.CharacterModelType.WOMAN_OFFICER,
	]
	for m_type in models:
		var fighter := BlockyFighter3D.new()
		root.add_child(fighter)
		fighter.setup_fighter(0, false, Color.WHITE, 0, {}, false, m_type)
		assert_eq(fighter.character_model_type, m_type, "model_type_assigned")
		assert_true(fighter.hero_instance != null, "hero_instance_instantiated")
		assert_true(fighter.skeleton != null, "skeleton_found")
		assert_eq(fighter.skeleton.get_bone_count(), 25, "mixamo_skeleton_has_25_bones")
		assert_true(fighter.head_socket != null, "head_socket_exists")
		assert_true(fighter.left_arm_socket != null, "left_arm_socket_exists")
		assert_true(fighter.right_arm_socket != null, "right_arm_socket_exists")
		assert_true(fighter.left_leg_socket != null, "left_leg_socket_exists")
		assert_true(fighter.right_leg_socket != null, "right_leg_socket_exists")
		assert_true(fighter.core_socket != null, "core_socket_exists")
		assert_true(fighter.anim_player != null, "anim_player_exists")
		assert_true(fighter.anim_player.has_animation("Walk"), "has_walk_anim")
		assert_true(fighter.anim_player.has_animation("Idle"), "has_idle_anim")
		assert_true(fighter.anim_player.has_animation("Attack"), "has_attack_anim")

		# Apply parts on character model
		fighter.apply_slots({
			PartData.Slot.HEAD: &"laser_eye",
			PartData.Slot.ARMS: &"chainsaw_arm",
			PartData.Slot.LEGS: &"rocket_legs",
			PartData.Slot.CORE: &"crown_core"
		}, false, false)
		assert_true(fighter.head_socket.get_child_count() > 0, "laser_eye_equipped")
		assert_true(fighter.right_arm_socket.get_child_count() > 0, "chainsaw_arm_equipped")
		assert_true(fighter.right_leg_socket.get_child_count() > 0, "rocket_legs_equipped")
		assert_true(fighter.core_socket.get_child_count() > 0, "crown_core_equipped")

		# Test animation triggers
		fighter.update_visual_state(Vector2(2.0, 3.0), Vector2(1.5, 0.0), 0.0, 0.0, 0.0, true, 0.016)
		assert_eq(fighter.anim_player.current_animation, "Walk", "plays_walk_when_moving")
		fighter.update_visual_state(Vector2(2.0, 3.0), Vector2.ZERO, 0.0, 0.0, 0.0, true, 0.016)
		assert_eq(fighter.anim_player.current_animation, "Idle", "plays_idle_when_stationary")
		fighter.update_visual_state(Vector2(2.0, 3.0), Vector2.ZERO, 0.0, 0.20, 0.0, true, 0.016)
		assert_eq(fighter.anim_player.current_animation, "Attack", "plays_attack_when_attacking")

		fighter.free()
	return true

func test_reference_mockup_vertical_hud() -> bool:
	var hud := VerticalHUD.new()
	root.add_child(hud)
	hud.size = Vector2(540.0, 960.0)

	# Test timer capsule update
	hud.on_match_time_updated(52.0)
	assert_true(is_equal_approx(hud.time_remaining_sec, 52.0), "hud_time_remaining_set")

	# Test kill count / stolen parts update
	hud.on_stolen_parts_updated(5)
	assert_eq(hud.stolen_parts_count, 5, "hud_stolen_parts_count_5")

	# Test equipped slots
	hud.on_player_slots_updated({
		PartData.Slot.HEAD: &"laser_eye",
		PartData.Slot.ARMS: &"chainsaw_arm",
		PartData.Slot.LEGS: &"rocket_legs",
		PartData.Slot.CORE: &"crown_core"
	}, false, 100)
	assert_eq(hud.equipped_slots[PartData.Slot.ARMS], &"chainsaw_arm", "equipped_chainsaw_arm")
	assert_eq(hud.equipped_slots[PartData.Slot.LEGS], &"rocket_legs", "equipped_rocket_legs")

	# Test overhead data assignment
	hud.overhead_combatant_data.clear()
	hud.overhead_combatant_data.append({
		"screen_pos": Vector2(270.0, 480.0),
		"is_player": true,
		"is_bot": false,
		"is_abomination": false,
		"hp_ratio": 1.0,
		"base_color": Color.WHITE,
		"id": 0,
	})
	hud.overhead_combatant_data.append({
		"screen_pos": Vector2(300.0, 350.0),
		"is_player": false,
		"is_bot": true,
		"is_abomination": false,
		"hp_ratio": 0.65,
		"base_color": Color.CYAN,
		"id": 1,
	})
	assert_eq(hud.overhead_combatant_data.size(), 2, "overhead_combatants_count_2")

	# Verify redraw request queued cleanly
	hud.queue_redraw()

	# Verify SVG textures preloaded cleanly
	assert_true(hud.TIMER_SVG != null, "hud_timer_svg_loaded")
	assert_true(hud.SKULL_SVG != null, "hud_skull_svg_loaded")
	assert_true(hud.HAMBURGER_SVG != null, "hud_hamburger_svg_loaded")
	assert_true(hud.ARM_SVG != null, "hud_arm_svg_loaded")
	assert_true(hud.LEG_SVG != null, "hud_leg_svg_loaded")
	assert_true(hud.CORE_SVG != null, "hud_core_svg_loaded")

	# Verify Hamburger button interaction opens In-Game Settings Modal
	var toggled_emitted := [false]
	var on_toggled := func(open_state: bool) -> void:
		toggled_emitted[0] = open_state
	hud.settings_toggled.connect(on_toggled)
	var ham_event := InputEventMouseButton.new()
	ham_event.pressed = true
	ham_event.button_index = MOUSE_BUTTON_LEFT
	ham_event.position = hud._hamburger_btn_rect.get_center()
	hud._input(ham_event)
	assert_true(toggled_emitted[0], "hud_hamburger_button_toggles_settings_modal")
	assert_true(hud.is_settings_open(), "hud_settings_modal_is_open")

	# Verify TouchJoystick button layout matches reference mockup
	var joy := TouchJoystick.new()
	root.add_child(joy)
	joy.size = Vector2(540.0, 960.0)
	var att_c: Vector2 = joy.get_attack_btn_center()
	var dash_c: Vector2 = joy.get_dash_btn_center()
	var rest_c: Vector2 = joy.get_default_joystick_center()
	assert_true(is_equal_approx(att_c.x, 540.0 - 76.0), "attack_btn_center_x")
	assert_true(is_equal_approx(att_c.y, 960.0 - 195.0), "attack_btn_center_y")
	assert_true(is_equal_approx(dash_c.x, 540.0 - 76.0), "dash_btn_center_x")
	assert_true(is_equal_approx(dash_c.y, 960.0 - 85.0), "dash_btn_center_y")
	assert_true(is_equal_approx(rest_c.x, 115.0), "joystick_rest_center_x")
	assert_true(is_equal_approx(rest_c.y, 960.0 - 110.0), "joystick_rest_center_y")
	joy.free()

	hud.free()
	return true

func test_ingame_character_visibility_and_walk_retargeting() -> bool:
	# 1. Verify Mixamo collection walk animation uses only 3D rotation tracks (no position explosions)
	var walk_anim: Animation = BlockyFighter3D._get_or_build_mixamo_walk_anim()
	assert_true(walk_anim != null, "mixamo_walk_anim_built")
	assert_true(walk_anim.get_track_count() > 0, "mixamo_walk_anim_has_tracks")
	var has_position_track: bool = false
	for t: int in range(walk_anim.get_track_count()):
		if walk_anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			has_position_track = true
			break
	assert_true(not has_position_track, "mixamo_walk_anim_has_no_position_tracks")

	# 2. Verify camera balance parameters are tuned for clear third-person brawler visibility
	var balance_cfg: BalanceConfig = load("res://shared/default_balance.tres") as BalanceConfig
	assert_true(balance_cfg != null, "balance_cfg_loaded")
	# Key-art framing: high angle (about 50 degrees down) so limbs on the floor and the fight around the player read.
	assert_true(balance_cfg.camera_distance >= 7.0 and balance_cfg.camera_distance <= 10.0, "camera_distance_shows_arena_around_player")
	assert_true(balance_cfg.camera_pitch_deg <= -45.0 and balance_cfg.camera_pitch_deg >= -65.0, "camera_pitch_high_angle_like_key_art")
	assert_true(balance_cfg.camera_z_bias >= 3.4, "camera_z_bias_positions_player_foreground")

	# 3. Verify fighter 0 model scale and sockets
	var fighter := BlockyFighter3D.new()
	root.add_child(fighter)
	fighter.setup_fighter(0, false, Color.WHITE, 0, {}, false, BlockyFighter3D.CharacterModelType.MAN_CUTIE)
	assert_true(fighter.hero_instance.scale.x >= 2.5, "fighter_hero_scale_chunky")
	assert_true(fighter.visible, "fighter_is_visible")
	assert_true(fighter.hero_instance.visible, "hero_instance_is_visible")

	# Test walk animation maintains stable hips
	var hips_idx: int = fighter.skeleton.find_bone("mixamorig_Hips")
	var base_hips_origin: Vector3 = fighter.skeleton.get_bone_global_pose(hips_idx).origin
	fighter.anim_player.play("Walk")
	fighter.anim_player.seek(0.2, true)
	var walking_hips_origin: Vector3 = fighter.skeleton.get_bone_global_pose(hips_idx).origin
	assert_true(base_hips_origin.is_equal_approx(walking_hips_origin), "hips_pose_anchored_during_walk")

	fighter.free()
	return true

func test_camera_follow_rotation_and_enemy_visibility() -> bool:
	# 1. Verify BalanceConfig has camera rotation & look-ahead parameters
	var cfg: BalanceConfig = load("res://shared/default_balance.tres") as BalanceConfig
	assert_true(cfg != null, "balance_cfg_loaded_for_camera")
	assert_true(cfg.camera_rotation_enabled, "camera_rotation_enabled_by_default")
	assert_true(cfg.camera_rotation_smooth_rate >= 4.0, "camera_rotation_smooth_rate_tuned")
	assert_true(cfg.camera_look_ahead_dist >= 1.0, "camera_look_ahead_dist_configured")

	# 2. Test mathematical rotation angles for all 4 headings:
	# North (-PI/2) -> yaw = 0
	var yaw_north: float = wrapf(-(-PI * 0.5) - PI * 0.5, -PI, PI)
	assert_true(is_zero_approx(yaw_north), "yaw_north_is_zero")
	# East (0.0) -> yaw = -PI/2 (-90 deg)
	var yaw_east: float = wrapf(-(0.0) - PI * 0.5, -PI, PI)
	assert_true(is_equal_approx(yaw_east, -PI * 0.5), "yaw_east_is_minus_90_deg")
	# South (PI/2) -> yaw = -PI / +PI (180 deg)
	var yaw_south: float = wrapf(-(PI * 0.5) - PI * 0.5, -PI, PI)
	assert_true(is_equal_approx(absf(yaw_south), PI), "yaw_south_is_180_deg")
	# West (PI) -> yaw = +PI/2 (+90 deg)
	var yaw_west: float = wrapf(-(PI) - PI * 0.5, -PI, PI)
	assert_true(is_equal_approx(yaw_west, PI * 0.5), "yaw_west_is_plus_90_deg")

	# 3. Test camera-relative input transformation:
	# Screen UP (0, -1) when facing North (yaw 0) -> World (0, -1)
	var fwd_n := Vector2(-sin(0.0), -cos(0.0))
	var right_n := Vector2(cos(0.0), -sin(0.0))
	var world_up_n: Vector2 = right_n * 0.0 + fwd_n * (-(-1.0))
	assert_true(world_up_n.is_equal_approx(Vector2(0.0, -1.0)), "input_up_facing_north_moves_north")

	# Screen UP (0, -1) when facing East (yaw -PI/2) -> World (1, 0)
	var fwd_e := Vector2(-sin(-PI * 0.5), -cos(-PI * 0.5))
	var right_e := Vector2(cos(-PI * 0.5), -sin(-PI * 0.5))
	var world_up_e: Vector2 = right_e * 0.0 + fwd_e * (-(-1.0))
	assert_true(world_up_e.is_equal_approx(Vector2(1.0, 0.0)), "input_up_facing_east_moves_east")

	# Screen RIGHT (1, 0) when facing East (yaw -PI/2) -> World (0, 1) (South)
	var world_right_e: Vector2 = right_e * 1.0 + fwd_e * 0.0
	assert_true(world_right_e.is_equal_approx(Vector2(0.0, 1.0)), "input_right_facing_east_moves_south")

	# Screen UP (0, -1) when facing South (yaw PI) -> World (0, 1)
	var fwd_s := Vector2(-sin(PI), -cos(PI))
	var world_up_s: Vector2 = fwd_s * 1.0
	assert_true(world_up_s.is_equal_approx(Vector2(0.0, 1.0)), "input_up_facing_south_moves_south")

	# 4. Test MainArenaController camera follow in action
	var arena_ctrl := MainArenaController.new()
	arena_ctrl._skip_customize = true
	root.add_child(arena_ctrl)

	# Initial yaw is zero (facing North)
	assert_true(is_zero_approx(arena_ctrl.current_cam_yaw), "initial_cam_yaw_is_zero")
	assert_true(is_zero_approx(arena_ctrl.target_cam_yaw), "initial_target_cam_yaw_is_zero")

	# Set player facing East (facing_angle = 0.0)
	var p0: MatchServer.CombatantState = arena_ctrl.server.combatants[0]
	p0.facing_angle = 0.0
	p0.pos = Vector2(0.0, 0.0)

	# Step camera update for 1.0 second
	for _i: int in range(60):
		arena_ctrl._update_camera_follow(0.0166)

	# Camera yaw should have smoothly converged toward -PI/2 (-90 deg)
	assert_true(arena_ctrl.current_cam_yaw < -0.8, "cam_yaw_smoothly_rotated_east")
	assert_true(is_equal_approx(arena_ctrl.target_cam_yaw, -PI * 0.5), "target_cam_yaw_is_minus_pi_over_two")

	# Camera position should be located West of the player (X < 0) looking East
	assert_true(arena_ctrl.camera.position.x < -1.0, "camera_is_behind_player_to_the_west")
	assert_true(arena_ctrl.camera.rotation_degrees.y < -40.0, "camera_rotation_y_pitched_toward_east")

	# Verify enemy visibility in front of player:
	# Enemy placed 3 units East of player (0.0 + 3.0, 0.0)
	var enemy_pos_3d := Vector3(3.0, 1.0, 0.0)
	assert_true(not arena_ctrl.camera.is_position_behind(enemy_pos_3d), "enemy_in_front_is_not_behind_camera")

	arena_ctrl.free()
	return true

func test_abomination_transformation_at_9_parts() -> bool:
	var srv := MatchServer.new()
	srv.bots_enabled = false
	root.add_child(srv)
	srv.dropped_parts.clear()

	var bot: MatchServer.CombatantState = srv.combatants[1]
	bot.slots = {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"base_fist",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}
	bot.collected_parts = {
		PartData.Slot.ARMS: 0,
		PartData.Slot.LEGS: 0,
		PartData.Slot.CORE: 0,
	}
	bot.stolen_parts_count = 0
	srv._recalc_combatant_stats(bot, false)
	assert_eq(bot.is_abomination, false, "initial_bot_is_not_abomination")
	assert_eq(bot.stolen_parts_count, 0, "initial_stolen_parts_0")

	# Equip 3 arms, 2 legs, 3 core (total 8 parts, missing 1 leg)
	srv.equip_part_on_combatant(bot.id, &"chainsaw_arm")
	srv.equip_part_on_combatant(bot.id, &"chainsaw_arm")
	srv.equip_part_on_combatant(bot.id, &"chainsaw_arm")
	assert_eq(bot.collected_parts[PartData.Slot.ARMS], 3, "arms_count_3")

	srv.equip_part_on_combatant(bot.id, &"rocket_legs")
	srv.equip_part_on_combatant(bot.id, &"rocket_legs")
	assert_eq(bot.collected_parts[PartData.Slot.LEGS], 2, "legs_count_2")

	srv.equip_part_on_combatant(bot.id, &"shield_core")
	srv.equip_part_on_combatant(bot.id, &"shield_core")
	srv.equip_part_on_combatant(bot.id, &"shield_core")
	assert_eq(bot.collected_parts[PartData.Slot.CORE], 3, "core_count_3")
	assert_eq(bot.stolen_parts_count, 8, "total_stolen_parts_8")
	assert_eq(bot.is_abomination, false, "not_abomination_at_8_parts")

	# Equip the 3rd leg -> 3 arms, 3 legs, 3 core = 9 parts total
	srv.equip_part_on_combatant(bot.id, &"rocket_legs")
	assert_eq(bot.collected_parts[PartData.Slot.LEGS], 3, "legs_count_3")
	assert_eq(bot.stolen_parts_count, 9, "total_stolen_parts_9")
	assert_eq(bot.is_abomination, true, "becomes_abomination_at_9_parts_collected")

	# When killed, victim drops parts and collected_parts decrements below 9 -> Abomination is lost
	srv._handle_combatant_death(bot, srv.combatants[0])
	assert_true(bot.stolen_parts_count < 9, "stolen_parts_count_decreased_on_death")
	assert_eq(bot.is_abomination, false, "abomination_lost_status_after_dropping_parts")

	srv.free()
	return true

func test_in_game_settings_modal_non_pausing_and_realtime_combat() -> bool:
	# 1. Test InGameSettingsModal in isolation
	var modal: Control = VerticalHUD.InGameSettingsModalScript.new()
	var snd := SoundController.new()
	root.add_child(snd)
	root.add_child(modal)
	modal.sound_controller = snd
	modal.custom_minimum_size = Vector2(540.0, 960.0)
	modal.size = Vector2(540.0, 960.0)

	# Open modal
	assert_eq(modal.is_open, false, "modal_initially_closed")
	modal.open()
	assert_eq(modal.is_open, true, "modal_is_open_after_open_call")
	assert_eq(modal.visible, true, "modal_visible_after_open_call")

	# CRUCIAL CONSTRAINT: The game must NOT pause!
	assert_eq(self.paused, false, "game_tree_is_NOT_paused_while_settings_modal_is_open")

	# Test Audio volume adjustments
	snd.set_music_volume_linear(0.5)
	assert_true(is_equal_approx(snd.get_music_volume_linear(), 0.5), "music_volume_linear_set_to_0_5")
	modal.music_volume = 0.2
	modal._apply_music()
	assert_true(is_equal_approx(snd.get_music_volume_linear(), 0.2), "music_volume_reflected_in_sound_controller")

	snd.set_sfx_volume_linear(0.8)
	assert_true(is_equal_approx(snd.get_sfx_volume_linear(), 0.8), "sfx_volume_linear_set_to_0_8")
	modal.sfx_volume = 0.4
	modal._apply_sfx()
	assert_true(is_equal_approx(snd.get_sfx_volume_linear(), 0.4), "sfx_volume_reflected_in_sound_controller")

	# Test Language Switcher
	modal.set_language("en")
	assert_eq(modal.current_locale, "en", "locale_switched_to_en")
	assert_eq(I18nService.get_current_locale(), "en", "i18n_service_locale_en")
	assert_true(tr(&"SETTINGS_TITLE").to_upper().find("SETTINGS") != -1, "i18n_en_settings_title")

	modal.set_language("it")
	assert_eq(modal.current_locale, "it", "locale_switched_back_to_it")
	assert_eq(I18nService.get_current_locale(), "it", "i18n_service_locale_it")
	assert_true(tr(&"SETTINGS_TITLE").to_upper().find("IMPOSTAZIONI") != -1, "i18n_it_settings_title")

	# Test Privacy Policy & Terms of Service Subdialogs
	assert_eq(modal.sub_dialog, 0, "initial_subdialog_none")
	modal.sub_dialog = 1
	assert_eq(modal.sub_dialog, 1, "subdialog_privacy_policy_active")
	modal.sub_dialog = 2
	assert_eq(modal.sub_dialog, 2, "subdialog_tos_active")
	modal.sub_dialog = 0
	assert_eq(modal.sub_dialog, 0, "subdialog_closed")

	# Test Leave Match signal
	var leave_emitted := [false]
	modal.leave_match_requested.connect(func() -> void:
		leave_emitted[0] = true
	)
	modal.leave_match_requested.emit()
	assert_true(leave_emitted[0], "leave_match_signal_emits_cleanly")

	# Close modal
	modal.close()
	assert_eq(modal.is_open, false, "modal_closed")
	assert_eq(modal.visible, false, "modal_hidden_when_closed")
	assert_eq(self.paused, false, "game_remains_unpaused_after_close")

	modal.free()
	snd.free()

	# 2. Test Live Arena Simulation with Settings Open (Real-time combat constraint)
	var arena_ctrl := MainArenaController.new()
	arena_ctrl._skip_customize = true
	root.add_child(arena_ctrl)

	# Open settings via HUD
	arena_ctrl.hud.toggle_settings()
	assert_true(arena_ctrl.hud.is_settings_open(), "hud_settings_opened_during_match")
	assert_eq(self.paused, false, "tree_not_paused_in_full_arena")

	# Step server simulation and verify combat continues
	var p0: MatchServer.CombatantState = arena_ctrl.server.combatants[0]
	var initial_hp: int = p0.hp
	var bot1: MatchServer.CombatantState = arena_ctrl.server.combatants[1]
	bot1.pos = p0.pos + Vector2(0.5, 0.0) # Bot right next to player

	# Step simulation for 60 ticks (2 seconds)
	for _i: int in range(60):
		arena_ctrl.server.step_simulation(1.0 / 30.0)

	# Match time should have elapsed while in settings
	assert_true(arena_ctrl.server.match_elapsed_sec > 1.8, "match_timer_continues_running_in_settings")

	# Bot auto-attacks player while player is in settings, proving player can take damage / be killed
	assert_true(p0.hp < initial_hp, "player_takes_damage_from_enemies_while_settings_modal_is_open")

	arena_ctrl.free()
	return true


# ---------------------------------------------------------------------------
# Dismemberment loop: limbs pop off, lie on the floor as real pieces, become clubs or grafts.
# ---------------------------------------------------------------------------

func _make_duel_server() -> MatchServer:
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
	for c: MatchServer.CombatantState in [p, bot]:
		c.slots = {
			PartData.Slot.HEAD: &"base_head",
			PartData.Slot.ARMS: &"base_fist",
			PartData.Slot.LEGS: &"base_boots",
			PartData.Slot.CORE: &"base_core",
		}
		srv._recalc_combatant_stats(c, false)
	p.pos = Vector2(0.0, 0.0)
	bot.pos = Vector2(1.2, 0.0)
	bot.attack_cooldown = 999.0
	return srv

func test_hp_thresholds_pop_limbs_off_as_real_drops() -> bool:
	# Arrange
	var srv: MatchServer = _make_duel_server()
	var p: MatchServer.CombatantState = srv.combatants[0]
	var bot: MatchServer.CombatantState = srv.combatants[1]
	var severed_events: Array[int] = []
	srv.limb_severed.connect(func(victim_id: int, _att: int, slot: int, _pos: Vector2) -> void:
		if victim_id == bot.id:
			severed_events.append(slot)
	)

	# Act: one punch takes the bot from 70% to 52%, across the 66% threshold.
	bot.hp = 70
	p.attack_cooldown = 0.0
	srv.step_simulation(1.0 / 30.0)

	# Assert
	assert_eq(bot.slots[PartData.Slot.ARMS], &"severed_one_arm", "first_threshold_pops_an_arm")
	assert_eq(severed_events.size(), 1, "limb_severed_signal_emitted_once")
	assert_eq(srv.dropped_parts.size(), 1, "popped_arm_lands_on_the_floor")
	var arm_drop: MatchServer.DroppedPartState = srv.dropped_parts[0]
	assert_eq(arm_drop.part_id, &"limb_arm", "drop_is_a_loose_arm")
	assert_eq(arm_drop.is_limb, true, "drop_flagged_as_limb")
	assert_eq(arm_drop.owner_id, bot.id, "loose_arm_remembers_its_owner")
	assert_true(bot.damage_mult < 0.8, "one_armed_bot_hits_softer")

	# Act: healing back above the threshold and dropping below it again takes nothing more.
	srv.dropped_parts.clear()
	bot.pos = Vector2(1.2, 0.0)
	bot.vel = Vector2.ZERO
	bot.hp = 70
	p.attack_cooldown = 0.0
	srv.step_simulation(1.0 / 30.0)
	assert_eq(srv.dropped_parts.size(), 0, "each_threshold_pops_a_limb_once_per_life")

	# Act: second threshold (33%) takes a leg.
	srv.dropped_parts.clear()
	bot.pos = Vector2(1.2, 0.0)
	bot.vel = Vector2.ZERO
	bot.hp = 36
	p.attack_cooldown = 0.0
	srv.step_simulation(1.0 / 30.0)

	# Assert
	assert_eq(bot.slots[PartData.Slot.LEGS], &"severed_one_leg", "second_threshold_pops_a_leg")
	assert_eq(srv.dropped_parts[0].part_id, &"limb_leg", "drop_is_a_loose_leg")
	assert_true(bot.speed_mult < 0.8, "one_legged_bot_is_slower")
	assert_eq(bot.alive, true, "thresholds_do_not_kill")
	srv.free()
	return true

func test_loose_limb_pickup_becomes_club_that_wears_out() -> bool:
	# Arrange: a leg from fighter 3 lies under the player's feet.
	var srv: MatchServer = _make_duel_server()
	var p: MatchServer.CombatantState = srv.combatants[0]
	var bot: MatchServer.CombatantState = srv.combatants[1]
	bot.pos = Vector2(30.0, 0.0)
	bot.max_hp = 5000
	bot.hp = 5000
	var stolen_before: int = p.stolen_parts_count
	var drop: MatchServer.DroppedPartState = srv.spawn_dropped_part(&"limb_leg", p.pos, Vector2.ZERO, false, 3)
	drop.spawn_time = srv.match_elapsed_sec - 1.0

	# Act
	srv.step_simulation(1.0 / 30.0)

	# Assert: whole body, so the leg goes in the hand as a club.
	assert_eq(p.held_limb_slot, int(PartData.Slot.LEGS), "whole_fighter_wields_the_leg")
	assert_eq(p.held_limb_owner_id, 3, "club_keeps_its_owner")
	assert_eq(p.held_limb_hits_left, srv.balance.limb_club_leg_hits, "club_starts_with_full_durability")
	assert_eq(p.slots[PartData.Slot.LEGS], &"base_boots", "own_legs_untouched")
	assert_true(is_equal_approx(p.damage_mult, srv.balance.limb_club_leg_damage_mult), "leg_club_boosts_damage")
	assert_true(is_equal_approx(p.range_mult, srv.balance.limb_club_leg_range_mult), "leg_club_boosts_reach")
	assert_eq(p.stolen_parts_count, stolen_before, "club_in_hand_is_not_a_stolen_body_piece")
	assert_eq(srv.can_wield_limb(p), false, "cannot_stack_a_second_club")

	# Act: swing until it breaks.
	var bonks: Array[bool] = []
	srv.limb_bonk.connect(func(_a: int, _t: int, _slot: int, _pos: Vector2, broke: bool) -> void:
		bonks.append(broke)
	)
	var vel_after_first: float = 0.0
	for i: int in range(srv.balance.limb_club_leg_hits):
		bot.pos = Vector2(1.5, 0.0)
		bot.vel = Vector2.ZERO
		p.pos = Vector2.ZERO
		p.attack_cooldown = 0.0
		srv.step_simulation(1.0 / 30.0)
		if i == 0:
			vel_after_first = bot.vel.length()

	# Assert
	assert_eq(bonks.size(), srv.balance.limb_club_leg_hits, "every_club_hit_bonks")
	assert_eq(bonks[bonks.size() - 1], true, "last_hit_breaks_the_club")
	assert_eq(bonks[0], false, "first_hit_does_not_break_it")
	assert_eq(p.held_limb_slot, -1, "broken_club_leaves_the_hand")
	assert_true(is_equal_approx(p.damage_mult, 1.0), "damage_back_to_normal_after_break")
	assert_true(vel_after_first > srv.balance.auto_attack_knockback * 2.0, "club_knockback_sends_target_flying")
	srv.free()
	return true

func test_loose_limb_reattaches_as_graft_when_limb_missing() -> bool:
	# Arrange: the player lost an arm; fighter 2's arm lies under their feet.
	var srv: MatchServer = _make_duel_server()
	var p: MatchServer.CombatantState = srv.combatants[0]
	srv.combatants[1].pos = Vector2(30.0, 0.0)
	p.slots[PartData.Slot.ARMS] = &"severed_one_arm"
	srv._recalc_combatant_stats(p, false)
	p.hp = 50
	var stolen_at_start: int = p.stolen_parts_count
	var body_changes: Array[int] = []
	srv.combatant_body_changed.connect(func(id: int) -> void: body_changes.append(id))
	var drop: MatchServer.DroppedPartState = srv.spawn_dropped_part(&"limb_arm", p.pos, Vector2.ZERO, false, 2)
	drop.spawn_time = srv.match_elapsed_sec - 1.0

	# Act
	srv.step_simulation(1.0 / 30.0)

	# Assert
	assert_eq(p.slots[PartData.Slot.ARMS], &"base_fist", "missing_arm_is_restored")
	assert_eq(p.held_limb_slot, -1, "reattached_limb_is_not_a_club")
	assert_eq(int(p.graft_owners.get(&"arm_l", -1)), 2, "graft_remembers_foreign_owner")
	assert_true(p.hp > 50, "stolen_graft_heals")
	assert_eq(p.stolen_parts_count, stolen_at_start + 1, "graft_counts_as_a_stolen_piece")
	assert_true(is_equal_approx(p.damage_mult, 1.0), "arm_debuff_removed")
	assert_true(body_changes.has(0), "body_changed_signal_for_visuals")

	# Act: lose that arm again.
	srv.dropped_parts.clear()
	srv._sever_limb(p, srv.combatants[1], int(PartData.Slot.ARMS), Vector2.RIGHT)

	# Assert: the graft falls off still belonging to fighter 2.
	assert_eq(srv.dropped_parts[0].owner_id, 2, "severed_graft_keeps_original_owner")
	assert_eq(p.graft_owners.has(&"arm_l"), false, "graft_record_cleared")
	assert_eq(p.stolen_parts_count, stolen_at_start, "losing_the_graft_gives_the_piece_back")
	assert_eq(srv.wants_limb_drop(p, srv.dropped_parts[0]), false, "cannot_grab_a_freshly_lost_limb_right_back")

	# Act: picking your own limb back up is not a theft.
	var own: MatchServer.DroppedPartState = srv.spawn_dropped_part(&"limb_arm", p.pos, Vector2.ZERO, false, 0)
	own.spawn_time = srv.match_elapsed_sec - 1.0
	srv.dropped_parts.erase(srv.dropped_parts[0])
	var stolen_before: int = p.stolen_parts_count
	srv.step_simulation(1.0 / 30.0)

	# Assert
	assert_eq(p.slots[PartData.Slot.ARMS], &"base_fist", "own_arm_snaps_back")
	assert_eq(p.graft_owners.has(&"arm_l"), false, "own_limb_is_not_a_graft")
	assert_eq(p.stolen_parts_count, stolen_before, "own_limb_does_not_count_as_stolen")
	srv.free()
	return true

func test_ko_bursts_limbs_and_body_regrows_on_respawn() -> bool:
	# Arrange: the bot swings a club and wears a graft when it dies.
	var srv: MatchServer = _make_duel_server()
	var p: MatchServer.CombatantState = srv.combatants[0]
	var bot: MatchServer.CombatantState = srv.combatants[1]
	bot.held_limb_slot = int(PartData.Slot.ARMS)
	bot.held_limb_owner_id = 5
	bot.held_limb_hits_left = 3
	bot.graft_owners[&"leg_r"] = 4

	# Act
	srv._handle_combatant_death(bot, p)

	# Assert
	var limb_drops: int = 0
	var held_dropped: bool = false
	for d: MatchServer.DroppedPartState in srv.dropped_parts:
		if d.is_limb:
			limb_drops += 1
			if d.owner_id == 5:
				held_dropped = true
	assert_eq(limb_drops, srv.balance.ko_limb_burst_count + 1, "ko_drops_club_plus_burst_limbs")
	assert_true(held_dropped, "held_club_falls_on_ko")
	assert_eq(bot.held_limb_slot, -1, "dead_fighter_holds_nothing")
	assert_true(PartCatalog.is_severed(bot.slots[PartData.Slot.ARMS]), "ko_burst_takes_an_arm")
	assert_true(PartCatalog.is_severed(bot.slots[PartData.Slot.LEGS]), "ko_burst_takes_a_leg")

	# Act: wait out the respawn.
	bot.respawn_timer = 0.01
	srv.step_simulation(1.0 / 30.0)

	# Assert
	assert_eq(bot.alive, true, "bot_respawned")
	assert_eq(bot.slots[PartData.Slot.ARMS], &"base_fist", "arms_regrow_on_respawn")
	assert_eq(bot.slots[PartData.Slot.LEGS], &"base_boots", "legs_regrow_on_respawn")
	assert_eq(bot.graft_owners.is_empty(), true, "grafts_gone_after_respawn")
	srv.free()
	return true

func test_loose_limb_expires_and_bots_seek_clubs() -> bool:
	# Arrange
	var srv: MatchServer = _make_duel_server()
	var p: MatchServer.CombatantState = srv.combatants[0]
	var bot: MatchServer.CombatantState = srv.combatants[1]
	p.pos = Vector2(-14.0, 14.0)
	bot.pos = Vector2(6.0, 6.0)
	srv._power_part_timer = 20.0
	var drop: MatchServer.DroppedPartState = srv.spawn_dropped_part(&"limb_arm", Vector2(8.0, 6.0), Vector2.ZERO, false, 0)

	# Act
	var decision: Dictionary = BotUtilityAI.decide_bot_input(bot, srv, srv.get_safe_bounds_xz())

	# Assert: a whole-bodied bot walks over to grab a club.
	assert_eq(decision["action"], &"collect_upgrade_part", "bot_goes_for_loose_limb")
	assert_true((decision["move_input"] as Vector2).x > 0.5, "bot_moves_toward_the_limb")

	# Arrange: the limb outlives its lifetime.
	var expired: Array[int] = []
	srv.part_expired.connect(func(id: int, _pos: Vector2) -> void: expired.append(id))
	drop.spawn_time = srv.match_elapsed_sec - srv.balance.limb_drop_lifetime_sec - 0.5

	# Act
	srv.step_simulation(1.0 / 30.0)

	# Assert
	assert_eq(srv.dropped_parts.size(), 0, "old_limb_removed")
	assert_eq(expired, [drop.id], "expiry_signal_emitted")

	# Act: the floor never fills up with limbs.
	for i: int in range(srv.balance.max_limb_drops + 5):
		srv.spawn_dropped_part(&"limb_leg", Vector2(-10.0 + float(i) * 0.4, -10.0), Vector2.ZERO, false, 2)

	# Assert
	assert_true(srv.dropped_parts.size() <= srv.balance.max_limb_drops, "limb_drops_are_capped")
	srv.free()
	return true

func test_limb_mesh_library_cuts_real_limbs_from_models() -> bool:
	# Arrange / Act
	var limb_set: Dictionary = LimbMeshLibrary.get_limb_set(BlockyFighter3D.MAN_CUTIE_SCENE)

	# Assert: both arms, both legs and the head come out of the single skinned body.
	for limb: int in [LimbMeshLibrary.Limb.ARM_L, LimbMeshLibrary.Limb.ARM_R, LimbMeshLibrary.Limb.LEG_L, LimbMeshLibrary.Limb.LEG_R, LimbMeshLibrary.Limb.HEAD]:
		assert_true(limb_set.has(limb), "limb_%d_extracted" % limb)
	var arm: Dictionary = limb_set[LimbMeshLibrary.Limb.ARM_L]
	var arm_mesh: ArrayMesh = arm["mesh"] as ArrayMesh
	assert_true(arm_mesh.surface_get_array_len(0) >= 300, "arm_has_real_geometry")
	assert_true(float(arm["length"]) > 0.05, "arm_length_measured")
	var aabb: AABB = arm_mesh.get_aabb()
	assert_true(aabb.position.y < -0.05 and aabb.end.y < 0.08, "arm_hangs_down_from_its_joint")
	assert_true(aabb.size.y > aabb.size.x and aabb.size.y > aabb.size.z, "arm_long_axis_is_vertical")
	var leg: Dictionary = limb_set[LimbMeshLibrary.Limb.LEG_L]
	assert_true(float(leg["length"]) > float(arm["length"]), "leg_longer_than_arm")
	assert_true(LimbMeshLibrary.get_limb_set(BlockyFighter3D.MAN_CUTIE_SCENE) == limb_set, "limb_set_is_cached")

	# A model without usable skin data still yields a stand-in limb instead of nothing.
	var fallback: Node3D = LimbMeshLibrary.build_limb_node(BlockyFighter3D.GUY_SCENE, LimbMeshLibrary.Limb.ARM_L, Color.RED, 1.0)
	assert_true(fallback.get_child_count() > 0, "fallback_limb_built")
	fallback.free()
	return true

func test_fighter_shows_club_grafts_and_sockets() -> bool:
	# Arrange
	var fighter := BlockyFighter3D.new()
	root.add_child(fighter)
	var base_slots: Dictionary = {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"base_fist",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}
	fighter.setup_fighter(1, true, Color(0.98, 0.18, 0.22), 1, base_slots, false)
	var donor: Dictionary = {"scene": BlockyFighter3D.WOMAN_CUTIE_SCENE, "tint": Color(0.2, 0.9, 0.3), "tint_amount": 1.0}

	# Act: a leg in the hand and a foreign arm on the left shoulder.
	fighter.apply_body_state(int(PartData.Slot.LEGS), donor, {&"arm_l": donor})

	# Assert
	assert_true(fighter.held_limb_node != null, "club_node_in_hand")
	assert_true(fighter.held_limb_node.get_parent() is BoneAttachment3D, "club_follows_the_hand_bone")
	assert_true(fighter.held_limb_node.find_child("LimbMesh", true, false) != null, "club_is_a_real_limb_mesh")
	assert_eq((fighter.limb_extra_roots[&"arm_l"] as Node3D).get_child_count(), 1, "graft_node_on_left_shoulder")
	assert_true(fighter._collapsed_bones.has(fighter._bone_left_arm), "native_arm_hidden_under_graft")
	fighter.update_visual_state(Vector2.ZERO, Vector2(3.0, 0.0), 0.0, 0.25, 0.0, true, 0.016)
	assert_true(fighter._club_dir.is_normalized(), "club_pose_updates_during_swing")

	# Act: club breaks, graft gone, both legs severed.
	fighter.apply_body_state(-1, {}, {})
	var legless: Dictionary = base_slots.duplicate()
	legless[PartData.Slot.LEGS] = &"severed_legs"
	fighter.apply_slots(legless, false, false)
	fighter.update_visual_state(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, 0.0, true, 0.5)

	# Assert
	assert_true(fighter.held_limb_node == null, "club_removed_from_hand")
	assert_eq(fighter._collapsed_bones.has(fighter._bone_left_arm), false, "native_arm_back_after_graft_removed")
	assert_true((fighter.limb_extra_roots[&"leg_l"] as Node3D).get_child_count() > 0, "empty_socket_shown_for_missing_leg")
	assert_true(fighter.is_limb_missing(&"leg_r") and fighter.is_limb_missing(&"leg_l"), "both_legs_reported_missing")
	assert_true(fighter.pivot.position.y < -0.3, "legless_torso_drops_to_the_floor")
	fighter.free()

	# A fighter configured before it enters the tree: Skeleton3D does not flag pose changes
	# made off-tree, and an idle fighter has no animation track on its legs to refresh them,
	# so without the per-frame re-assert the collapsed leg bones would render at full size.
	var idle_fighter := BlockyFighter3D.new()
	idle_fighter.setup_fighter(3, true, Color.CYAN, 0, legless, false)
	root.add_child(idle_fighter)
	idle_fighter.update_visual_state(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, 0.0, true, 0.016)
	assert_true(idle_fighter.skeleton.get_bone_global_pose(idle_fighter._bone_left_upleg).basis.get_scale().x < 0.01, "leg_bones_stay_collapsed_while_idle")
	idle_fighter.free()
	return true

func test_dropped_pieces_render_real_limb_meshes() -> bool:
	# Arrange
	var ab := ArenaBuilder3D.new()
	root.add_child(ab)
	ab._init_vfx_pools()
	var resolver_calls: Array[int] = []
	ab.drop_owner_resolver = func(owner_id: int) -> Dictionary:
		resolver_calls.append(owner_id)
		return {"scene": BlockyFighter3D.MAN_OFFICER_SCENE, "tint": Color(0.1, 0.5, 1.0), "tint_amount": 1.0}

	# Act: a loose arm from fighter 4 and an ownerless chainsaw arm.
	ab.spawn_dropped_part_visual(501, &"limb_arm", int(PartData.Slot.ARMS), int(PartData.Rarity.COMMON), Vector2(1.0, 1.0), false, 4, true)
	ab.spawn_dropped_part_visual(502, &"chainsaw_arm", int(PartData.Slot.ARMS), int(PartData.Rarity.EPIC), Vector2(3.0, 1.0), false)

	# Assert
	var limb_node: Node3D = ab.dropped_part_nodes[501] as Node3D
	var limb_mesh: MeshInstance3D = limb_node.find_child("LimbMesh", true, false) as MeshInstance3D
	assert_true(limb_mesh != null and limb_mesh.mesh is ArrayMesh, "loose_arm_is_an_extracted_mesh_not_a_box")
	assert_eq(resolver_calls, [4], "drop_coloured_after_its_owner")
	assert_eq(bool(limb_node.get_meta("lying")), true, "common_limb_lies_on_the_floor")
	var saw_node: Node3D = ab.dropped_part_nodes[502] as Node3D
	assert_true(saw_node.find_child("LimbMesh", true, false) != null, "chainsaw_drop_shows_the_arm_it_is_on")
	assert_eq(bool(saw_node.get_meta("lying")), false, "rare_loot_hovers_in_its_beam")
	assert_true(saw_node.get_node("RarityMarker").get_child_count() >= 3, "epic_rarity_reads_by_shape_and_beam")

	# Act: comic text pops and returns to the pool.
	var pool_before: int = ab.comic_text_pool.size()
	ab.spawn_comic_text(Vector3(0.0, 2.0, 0.0), "BONK!", Color.YELLOW)
	assert_eq(ab.comic_text_pool.size(), pool_before - 1, "comic_text_taken_from_pool")
	ab.update_arena_vfx(1.0)
	assert_eq(ab.comic_text_pool.size(), pool_before, "comic_text_returned_to_pool")
	ab.free()
	return true
