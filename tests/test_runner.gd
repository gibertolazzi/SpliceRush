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
	TranslationServer.set_locale("en")
	assert_true(tr(&"HUD_BECOME_ABOMINATION").find("ABOMINATION") != -1, "i18n_en_abomination")
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
	# Submit oversized client vector (cheat attempt: length 10)
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
		c.pos = Vector2(50.0, 50.0) # move others far away
	var p: MatchServer.CombatantState = srv.combatants[0]
	var enemy_far: MatchServer.CombatantState = srv.combatants[1]
	var enemy_near: MatchServer.CombatantState = srv.combatants[2]
	p.pos = Vector2(0.0, 0.0)
	p.attack_cooldown = 0.0
	enemy_far.pos = Vector2(2.4, 0.0)
	enemy_near.pos = Vector2(1.3, 0.0)
	var hp_before: int = enemy_near.hp
	var far_hp_before: int = enemy_far.hp
	srv.step_simulation(1.0 / 30.0)
	assert_eq(enemy_near.hp, hp_before - srv.balance.auto_attack_damage, "nearest_enemy_damaged")
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
