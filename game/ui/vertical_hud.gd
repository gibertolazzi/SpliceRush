class_name VerticalHUD
extends Control

signal rematch_requested
signal customize_requested()
signal leave_match_requested()
signal settings_toggled(is_open: bool)

var time_remaining_sec: float = 90.0
var stolen_parts_count: int = 0
var collected_slot_counts: Dictionary = {
	PartData.Slot.ARMS: 0,
	PartData.Slot.LEGS: 0,
	PartData.Slot.CORE: 0,
}
const InGameSettingsModalScript := preload("res://game/ui/in_game_settings_modal.gd")

var sound_controller: SoundController = null:
	set(val):
		sound_controller = val
		if settings_modal != null:
			settings_modal.sound_controller = val

var settings_modal: Control = null
var is_abomination: bool = false
var is_frenzy: bool = false
var show_result_overlay: bool = false
var player_rank: int = 1
var player_lives: int = 3
var is_player_eliminated: bool = false
var result_countdown_sec: float = 5.0
var leaderboard_entries: Array[Dictionary] = []
var total_mass: int = 100
var screen_shake_enabled: bool = true
var colorblind_mode_enabled: bool = true
var equipped_slots: Dictionary = {
	PartData.Slot.HEAD: &"base_head",
	PartData.Slot.ARMS: &"base_fist",
	PartData.Slot.LEGS: &"base_boots",
	PartData.Slot.CORE: &"base_core",
}

var _toast_text: String = ""
var _toast_timer: float = 0.0
var _flash_timer: float = 0.0
var _speed_lines_timer: float = 0.0
var _stolen_banner_timer: float = 0.0
var _stolen_banner_max: float = 1.8
var _stolen_part_id: StringName = &""
var _stolen_rarity: int = 0
var _stolen_slot: int = 0
var _slot_flash_timers: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _rematch_btn_rect := Rect2(Vector2(110.0, 560.0), Vector2(320.0, 48.0))
var _customize_btn_rect := Rect2(Vector2(110.0, 614.0), Vector2(320.0, 36.0))
var overhead_combatant_data: Array[Dictionary] = []

var intro_tutorial_timer: float = 6.0
var _intro_elapsed: float = 0.0
var _abom_banner_timer: float = 0.0

var font_bold: Font = preload("res://game/ui/fonts/LondrinaSolid-Black.ttf")
var font_regular: Font = preload("res://game/ui/fonts/LondrinaSolid-Regular.ttf")
var logo_texture: Texture2D = preload("res://game/ui/assets/logo.svg")

const TIMER_SVG: Texture2D = preload("res://game/ui/assets/timer.svg")
const SKULL_SVG: Texture2D = preload("res://game/ui/assets/skull.svg")
const HAMBURGER_SVG: Texture2D = preload("res://game/ui/assets/hamburger.svg")
const ARM_SVG: Texture2D = preload("res://game/ui/assets/arm.svg")
const LEG_SVG: Texture2D = preload("res://game/ui/assets/leg.svg")
const CORE_SVG: Texture2D = preload("res://game/ui/assets/components.svg")

var _hamburger_btn_rect := Rect2(Vector2(540.0 - 24.0 - 54.0, 18.0), Vector2(54.0, 46.0))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_settings_modal()
	_apply_safe_area()

func _setup_settings_modal() -> void:
	if settings_modal == null:
		settings_modal = InGameSettingsModalScript.new()
		settings_modal.name = "InGameSettingsModal"
		settings_modal.sound_controller = sound_controller
		add_child(settings_modal)
		settings_modal.leave_match_requested.connect(func() -> void:
			leave_match_requested.emit()
		)
		settings_modal.closed.connect(func() -> void:
			settings_toggled.emit(false)
			queue_redraw()
		)
		settings_modal.language_changed.connect(func(_loc: String) -> void:
			queue_redraw()
		)

func toggle_settings() -> void:
	_setup_settings_modal()
	settings_modal.toggle()
	settings_toggled.emit(settings_modal.is_open)
	queue_redraw()

func is_settings_open() -> bool:
	return settings_modal != null and settings_modal.is_open

func _process(delta: float) -> void:
	var needs_redraw: bool = false
	if intro_tutorial_timer > 0.0:
		intro_tutorial_timer = maxf(0.0, intro_tutorial_timer - delta)
		_intro_elapsed += delta
		needs_redraw = true
	if _abom_banner_timer > 0.0:
		_abom_banner_timer = maxf(0.0, _abom_banner_timer - delta)
		needs_redraw = true
	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0:
			needs_redraw = true
	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		needs_redraw = true
	if _speed_lines_timer > 0.0:
		_speed_lines_timer = maxf(0.0, _speed_lines_timer - delta)
		needs_redraw = true
	if _stolen_banner_timer > 0.0:
		_stolen_banner_timer = maxf(0.0, _stolen_banner_timer - delta)
		needs_redraw = true
	for s_i: int in range(4):
		if _slot_flash_timers[s_i] > 0.0:
			_slot_flash_timers[s_i] = maxf(0.0, _slot_flash_timers[s_i] - delta)
			needs_redraw = true
	if show_result_overlay and result_countdown_sec > 0.0:
		result_countdown_sec = maxf(0.0, result_countdown_sec - delta)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not show_result_overlay:
		if event is InputEventScreenTouch:
			var st := event as InputEventScreenTouch
			if st.pressed and _hamburger_btn_rect.has_point(st.position):
				toggle_settings()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _hamburger_btn_rect.has_point(mb.position):
				toggle_settings()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _rematch_btn_rect.has_point(st.position):
				rematch_requested.emit()
				get_viewport().set_input_as_handled()
			elif _customize_btn_rect.has_point(st.position):
				customize_requested.emit()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _rematch_btn_rect.has_point(mb.position):
				rematch_requested.emit()
				get_viewport().set_input_as_handled()
			elif _customize_btn_rect.has_point(mb.position):
				customize_requested.emit()
				get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ability_action"):
		rematch_requested.emit()
		get_viewport().set_input_as_handled()

func _apply_safe_area() -> void:
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win := Rect2(Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()))
	if win.size.x > 0 and win.size.y > 0:
		var _inner := safe.intersection(win)
	queue_redraw()

func on_match_time_updated(seconds_left: float) -> void:
	var prev_int: int = int(ceil(time_remaining_sec))
	var next_int: int = int(ceil(seconds_left))
	time_remaining_sec = seconds_left
	is_frenzy = (seconds_left <= 30.0 and seconds_left > 0.0)
	if prev_int != next_int:
		queue_redraw()

func on_frenzy_started() -> void:
	is_frenzy = true
	queue_redraw()

func on_match_ended(board: Array[Dictionary], rank: int, duration_sec: float = 5.0) -> void:
	leaderboard_entries = board
	player_rank = rank
	result_countdown_sec = duration_sec
	show_result_overlay = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	queue_redraw()

func on_player_lives_updated(lives: int) -> void:
	player_lives = lives
	queue_redraw()

func on_player_eliminated(rank: int) -> void:
	is_player_eliminated = true
	player_rank = rank
	queue_redraw()

func on_match_restarted() -> void:
	show_result_overlay = false
	is_frenzy = false
	player_lives = 3
	is_player_eliminated = false
	_toast_timer = 0.0
	intro_tutorial_timer = 6.0
	_intro_elapsed = 0.0
	_abom_banner_timer = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func on_stolen_parts_updated(new_count: int) -> void:
	if stolen_parts_count != new_count:
		stolen_parts_count = new_count
		queue_redraw()

func on_collected_parts_updated(parts: Dictionary, total_count: int) -> void:
	collected_slot_counts = parts.duplicate()
	stolen_parts_count = total_count
	queue_redraw()

func on_player_slots_updated(slots: Dictionary, abom: bool, mass: int) -> void:
	if abom and not is_abomination:
		_abom_banner_timer = 2.8
		_flash_timer = 0.35
		_speed_lines_timer = 0.65
	equipped_slots = slots.duplicate()
	is_abomination = abom
	total_mass = mass
	queue_redraw()

func show_part_stolen_toast(part_id: StringName) -> void:
	var pdata: PartData = PartCatalog.get_part(part_id)
	_toast_text = tr(&"HUD_PART_STOLEN_TOAST") % [tr(pdata.translation_key)]
	_toast_timer = 1.6
	_flash_timer = 0.22
	_speed_lines_timer = 0.45
	queue_redraw()

func show_part_stolen_banner(part_id: StringName, rarity: int, slot: int) -> void:
	_stolen_part_id = part_id
	_stolen_rarity = rarity
	_stolen_slot = slot
	_stolen_banner_timer = 1.8
	_stolen_banner_max = 1.8
	_flash_timer = 0.22
	_speed_lines_timer = 0.55
	if slot >= 0 and slot < _slot_flash_timers.size():
		_slot_flash_timers[slot] = 1.6
	show_part_stolen_toast(part_id)

func trigger_impact_speed_lines(duration_sec: float = 0.28) -> void:
	_speed_lines_timer = maxf(_speed_lines_timer, duration_sec)
	queue_redraw()

func update_overhead_combatants(combatants: Array, cam: Camera3D) -> void:
	overhead_combatant_data.clear()
	if cam == null:
		queue_redraw()
		return

	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 10.0:
		vp_size = size

	var player_pos := Vector2.ZERO
	if not combatants.is_empty():
		player_pos = (combatants[0] as MatchServer.CombatantState).pos

	for c: MatchServer.CombatantState in combatants:
		if not c.alive:
			continue
		# Only nearby fighters get overhead bars: keep the far arena clean.
		if c.id != 0 and not c.is_abomination and c.pos.distance_to(player_pos) > 11.5:
			continue
		var head_y: float = 2.75 if c.is_abomination else 2.15
		var world_pos := Vector3(c.pos.x, head_y, c.pos.y)
		if cam.is_position_behind(world_pos):
			continue
		var s_pos: Vector2 = cam.unproject_position(world_pos)
		if s_pos.x < -80.0 or s_pos.x > vp_size.x + 80.0 or s_pos.y < -80.0 or s_pos.y > vp_size.y + 80.0:
			continue

		var max_h: float = maxf(1.0, float(c.max_hp))
		var ratio: float = clampf(float(c.hp) / max_h, 0.0, 1.0)
		overhead_combatant_data.append({
			"screen_pos": s_pos,
			"is_player": (c.id == 0),
			"is_bot": c.is_bot,
			"is_abomination": c.is_abomination,
			"hp_ratio": ratio,
			"base_color": c.base_color,
			"id": c.id,
		})
	queue_redraw()

func _draw() -> void:
	var rect_size: Vector2 = size
	if rect_size.x < 10.0:
		rect_size = Vector2(540.0, 960.0)

	var navy_bg := Color(0.078, 0.078, 0.196, 0.94)
	var border_col := Color(0.48, 0.42, 0.78, 0.85)
	var magenta := Color(1.0, 0.18, 0.576, 1.0)
	var gold := Color(1.0, 0.76, 0.12, 1.0)
	var white := Color(0.98, 0.98, 1.0, 1.0)

	# Overhead character tags & health bars (Readability & Comprehensibility)
	_draw_overhead_combatants()

	# 0. ACTION SPEED LINES & STEAL TRANSFORMATION FLASH (Passo 4 Game Feel)
	if _flash_timer > 0.0:
		var flash_alpha: float = clampf(_flash_timer / 0.22, 0.0, 1.0) * 0.22
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(1.0, 0.86, 0.35, flash_alpha), true)
	if _speed_lines_timer > 0.0:
		var line_alpha: float = clampf(_speed_lines_timer / 0.45, 0.35, 1.0) * 0.88
		var center_pt := Vector2(rect_size.x * 0.5, rect_size.y * 0.54)
		for l_i: int in range(18):
			var ang: float = float(l_i) * (TAU / 18.0) + 0.16
			var dir := Vector2(cos(ang), sin(ang))
			var p_in: Vector2 = center_pt + dir * 205.0
			var p_out: Vector2 = center_pt + dir * 340.0
			var l_col: Color = Color(1.0, 0.94, 0.48, line_alpha) if (l_i % 2 == 0) else Color(1.0, 0.22, 0.62, line_alpha)
			draw_line(p_in, p_out, l_col, 3.6)

	# 1. TOP BARS (Row 1 & Row 2 matching exact reference mockup)
	_draw_mockup_top_bar(rect_size)

	# Frenzy Phase Banner or Part-Stolen Toast below Row 2
	if is_frenzy and not show_result_overlay:
		var f_rect := Rect2(Vector2(rect_size.x * 0.5 - 130.0, 134.0), Vector2(260.0, 36.0))
		_draw_chamfer_panel(f_rect, Color(0.24, 0.04, 0.16, 0.95), magenta, 6.0)
		draw_string(font_bold, f_rect.position + Vector2(10.0, 18.0), tr(&"HUD_FRENZY_BANNER"), HORIZONTAL_ALIGNMENT_CENTER, 240.0, 13, gold)

		# 3-Lives pips: hearts/shields
		var pips_center_x: float = f_rect.position.x + f_rect.size.x * 0.5
		var pip_w: float = 22.0
		var pip_gap: float = 8.0
		var total_pips_w: float = 3.0 * pip_w + 2.0 * pip_gap
		var start_pip_x: float = pips_center_x - total_pips_w * 0.5
		for l_i: int in range(3):
			var px: float = start_pip_x + float(l_i) * (pip_w + pip_gap)
			var py: float = f_rect.position.y + 22.0
			var is_full: bool = (l_i < player_lives)
			var pip_r := Rect2(Vector2(px, py), Vector2(pip_w, 9.0))
			draw_rect(pip_r, Color(0.12, 0.06, 0.18, 0.90), true)
			if is_full:
				draw_rect(pip_r, gold, true)
			else:
				draw_rect(pip_r, Color(0.5, 0.20, 0.28, 0.8), false, 1.5)
	elif _toast_timer > 0.0 and _toast_text != "" and _stolen_banner_timer <= 0.0:
		var toast_rect := Rect2(Vector2(rect_size.x - 196.0, 134.0), Vector2(184.0, 28.0))
		_draw_chamfer_panel(toast_rect, Color(0.10, 0.06, 0.24, 0.96), gold, 5.0)
		draw_string(font_bold, toast_rect.position + Vector2(8.0, 20.0), _toast_text, HORIZONTAL_ALIGNMENT_CENTER, 168.0, 15, gold)

	# Elimination Banner
	if is_player_eliminated and not show_result_overlay:
		var elim_rect := Rect2(Vector2(rect_size.x * 0.5 - 160.0, 150.0), Vector2(320.0, 52.0))
		_draw_chamfer_panel(elim_rect, Color(0.30, 0.05, 0.12, 0.96), magenta, 8.0)
		var elim_str: String = tr(&"HUD_ELIMINATED_BANNER") % [player_rank]
		draw_string(font_bold, elim_rect.position + Vector2(10.0, 34.0), elim_str, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 20, white)

	# 4. ANIMATED INTRO ONBOARDING ("RUBA I PEZZI!" & "DIVENTA L'ABOMINIO!")
	_draw_animated_intro_tutorial(rect_size)

	# 5.5. JUICY STOLEN PART BANNER ("RUBATO!")
	_draw_stolen_part_banner(rect_size)

	# 5. ABOMINATION TRANSFORMATION STINGER BANNER
	_draw_abomination_active_banner(rect_size)

	# 6. 5-SECOND RESULT OVERLAY & 1-TAP REMATCH BUTTON (Passo 3)
	if show_result_overlay:
		draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.03, 0.02, 0.09, 0.76), true)
		var card_rect := Rect2(Vector2(rect_size.x * 0.5 - 210.0, 210.0), Vector2(420.0, 440.0))
		_draw_chamfer_panel(card_rect, Color(0.07, 0.06, 0.18, 0.98), gold if player_rank == 1 else magenta, 12.0)
		_draw_crown(Vector2(rect_size.x * 0.5, card_rect.position.y + 28.0), 22.0, gold)

		var title_str: String = tr(&"HUD_RESULT_TITLE_WIN") if player_rank == 1 else (tr(&"HUD_RESULT_TITLE_RANK") % [player_rank])
		draw_string(font_bold, Vector2(card_rect.position.x + 20.0, card_rect.position.y + 72.0), title_str, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 28, gold if player_rank == 1 else white)

		var score_str: String = tr(&"HUD_RESULT_MASS_SCORE") % [total_mass, stolen_parts_count]
		draw_string(font_regular, Vector2(card_rect.position.x + 20.0, card_rect.position.y + 104.0), score_str, HORIZONTAL_ALIGNMENT_CENTER, 380.0, 16, Color(0.88, 0.86, 0.98))

		var max_rows: int = mini(4, leaderboard_entries.size())
		for r_i: int in range(max_rows):
			var entry: Dictionary = leaderboard_entries[r_i]
			var row_y: float = card_rect.position.y + 130.0 + float(r_i) * 46.0
			var row_rect := Rect2(Vector2(card_rect.position.x + 24.0, row_y), Vector2(372.0, 38.0))
			var is_player_row: bool = (int(entry["id"]) == 0)
			draw_rect(row_rect, Color(0.22, 0.12, 0.42, 0.95) if is_player_row else Color(0.12, 0.10, 0.26, 0.92), true)
			draw_rect(row_rect, gold if is_player_row else border_col, false, 1.5)
			var badge_str: String = tr(&"HUD_YOU_BADGE") if not bool(entry["is_bot"]) else tr(&"HUD_BOT_BADGE")
			var row_label: String = "#%d  [%s] #%d   —   %d" % [r_i + 1, badge_str, int(entry["id"]) + 1, int(entry["total_mass"])]
			draw_string(font_regular, row_rect.position + Vector2(14.0, 26.0), row_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, gold if is_player_row else white)

		_rematch_btn_rect = Rect2(Vector2(rect_size.x * 0.5 - 165.0, card_rect.end.y - 108.0), Vector2(330.0, 46.0))
		_draw_chamfer_panel(_rematch_btn_rect, magenta, gold, 8.0)
		draw_string(font_bold, _rematch_btn_rect.position + Vector2(12.0, 31.0), tr(&"HUD_REMATCH_BTN"), HORIZONTAL_ALIGNMENT_CENTER, 306.0, 20, white)

		_customize_btn_rect = Rect2(Vector2(rect_size.x * 0.5 - 165.0, card_rect.end.y - 56.0), Vector2(330.0, 36.0))
		_draw_chamfer_panel(_customize_btn_rect, Color(0.16, 0.14, 0.32, 0.95), border_col, 6.0)
		draw_string(font_bold, _customize_btn_rect.position + Vector2(12.0, 25.0), tr(&"BTN_CUSTOMIZE"), HORIZONTAL_ALIGNMENT_CENTER, 306.0, 16, gold)

		# 5-second countdown bar at bottom of result card
		var bar_w: float = 330.0 * clampf(result_countdown_sec / 5.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2(_rematch_btn_rect.position.x, card_rect.end.y - 12.0), Vector2(bar_w, 4.0)), gold, true)

func _draw_animated_intro_tutorial(rect_size: Vector2) -> void:
	if intro_tutorial_timer <= 0.0 or show_result_overlay:
		return

	var enter_fade: float = clampf(_intro_elapsed / 0.28, 0.0, 1.0)
	var exit_fade: float = clampf(intro_tutorial_timer / 0.70, 0.0, 1.0)
	var alpha: float = minf(enter_fade, exit_fade)
	if alpha <= 0.001:
		return

	var is_phase_1: bool = (intro_tutorial_timer > 3.0)
	var card_w: float = minf(rect_size.x - 28.0, 480.0)
	var card_h: float = 96.0
	var card_rect := Rect2(Vector2((rect_size.x - card_w) * 0.5, 134.0), Vector2(card_w, card_h))

	var gold := Color(1.0, 0.76, 0.12, alpha)
	var muted := Color(0.86, 0.84, 0.96, alpha * 0.92)
	var magenta := Color(1.0, 0.18, 0.576, alpha)

	_draw_chamfer_panel(card_rect, Color(0.06, 0.05, 0.16, 0.90 * alpha), gold if is_phase_1 else magenta, 8.0)

	var title: String = tr(&"HUD_STEAL_PARTS").replace("\n", " ") if is_phase_1 else tr(&"HUD_BECOME_ABOMINATION").replace("\n", " ")
	draw_string(font_bold, card_rect.position + Vector2(12.0, 25.0), title, HORIZONTAL_ALIGNMENT_CENTER, card_w - 24.0, 19, gold)

	var subtitle: String = tr(&"HUD_TUTORIAL_STEAL_SUB") if is_phase_1 else tr(&"HUD_TUTORIAL_ABOM_SUB")
	draw_string(font_regular, card_rect.position + Vector2(12.0, 42.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, card_w - 24.0, 12, muted)

	var display_slot_order: Array[PartData.Slot] = [
		PartData.Slot.ARMS,
		PartData.Slot.LEGS,
		PartData.Slot.HEAD,
		PartData.Slot.CORE,
	]
	var box_sz: float = 30.0
	var gap: float = 14.0
	var row_w: float = 4.0 * box_sz + 3.0 * gap
	var start_x: float = card_rect.position.x + (card_w - row_w) * 0.5
	var box_y: float = card_rect.position.y + 50.0
	for s_idx: int in range(4):
		var slot_enum: PartData.Slot = display_slot_order[s_idx]
		var pid: StringName = equipped_slots.get(slot_enum, PartCatalog.get_base_part_for_slot(slot_enum)) as StringName
		var pdata: PartData = PartCatalog.get_part(pid)
		var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
		r_col.a = alpha
		var bx: float = start_x + float(s_idx) * (box_sz + gap)
		var box_r := Rect2(Vector2(bx, box_y), Vector2(box_sz, box_sz))
		draw_rect(box_r, Color(0.12, 0.10, 0.26, 0.95 * alpha), true)
		draw_rect(box_r, r_col, false, 2.0)
		_draw_slot_mini_icon(s_idx, box_r.get_center(), r_col)

	var hint_alpha: float = alpha * (0.55 + 0.45 * sin(_intro_elapsed * 5.0))
	draw_string(font_regular, card_rect.position + Vector2(12.0, card_h - 7.0), tr(&"HUD_TUTORIAL_TAP_TO_SKIP"), HORIZONTAL_ALIGNMENT_CENTER, card_w - 24.0, 10, Color(1.0, 0.88, 0.50, hint_alpha))

func _draw_abomination_active_banner(rect_size: Vector2) -> void:
	if _abom_banner_timer <= 0.0 or show_result_overlay:
		return
	var b_alpha: float = clampf(_abom_banner_timer / 0.4, 0.0, 1.0)
	var ban_w: float = minf(380.0, rect_size.x - 40.0)
	var ban_h: float = 64.0
	var ban_rect := Rect2(Vector2((rect_size.x - ban_w) * 0.5, 186.0), Vector2(ban_w, ban_h))
	_draw_chamfer_panel(ban_rect, Color(0.26, 0.04, 0.18, 0.98 * b_alpha), Color(1.0, 0.76, 0.12, b_alpha), 8.0)
	_draw_crown(Vector2(ban_rect.get_center().x, ban_rect.position.y + 4.0), 16.0, Color(1.0, 0.76, 0.12, b_alpha))
	var active_lines: PackedStringArray = tr(&"HUD_ABOMINATION_ACTIVE").split("\n")
	var line1: String = active_lines[0] if active_lines.size() > 0 else ""
	var line2: String = active_lines[1] if active_lines.size() > 1 else tr(&"HUD_ABOMINATION_HUNT")
	var full_text: String = "%s %s" % [line1, line2]
	draw_string(font_bold, ban_rect.position + Vector2(8.0, 42.0), full_text, HORIZONTAL_ALIGNMENT_CENTER, ban_w - 16.0, 20, Color(1.0, 0.88, 0.2, b_alpha))

func _draw_stolen_part_banner(rect_size: Vector2) -> void:
	if _stolen_banner_timer <= 0.0 or show_result_overlay or _stolen_part_id == &"":
		return

	var t_elapsed: float = _stolen_banner_max - _stolen_banner_timer
	var enter_fade: float = clampf(t_elapsed / 0.18, 0.0, 1.0)
	var exit_fade: float = clampf(_stolen_banner_timer / 0.35, 0.0, 1.0)
	var alpha: float = minf(enter_fade, exit_fade)
	if alpha <= 0.01:
		return

	# Overshoot bounce on entry
	var scale_pop: float = 1.0
	if t_elapsed < 0.25:
		var p_t: float = t_elapsed / 0.25
		scale_pop = lerpf(0.65, 1.08, sin(p_t * PI * 0.5))
	else:
		scale_pop = 1.0 + 0.02 * sin(t_elapsed * 8.0)

	var center_pt := Vector2(rect_size.x * 0.5, 296.0)

	# 1. Radiant rotating sunburst rays behind banner
	var ray_count: int = 16
	var ray_len: float = 96.0 * scale_pop
	var ray_rot: float = t_elapsed * 2.2
	for r_i: int in range(ray_count):
		var ang: float = float(r_i) * (TAU / float(ray_count)) + ray_rot
		var dir := Vector2(cos(ang), sin(ang))
		var r_col: Color = Color(1.0, 0.82, 0.18, 0.20 * alpha) if (r_i % 2 == 0) else Color(1.0, 0.20, 0.58, 0.16 * alpha)
		var p1: Vector2 = center_pt + dir * 42.0
		var p2: Vector2 = center_pt + dir * ray_len
		draw_line(p1, p2, r_col, 3.6 * scale_pop)

	# 2. Main banner card (slight dynamic tilt)
	var ban_w: float = clampf((rect_size.x - 32.0) * scale_pop, 280.0, 480.0)
	var ban_h: float = 90.0 * scale_pop
	var ban_rect := Rect2(center_pt - Vector2(ban_w * 0.5, ban_h * 0.5), Vector2(ban_w, ban_h))

	var navy_bg := Color(0.08, 0.05, 0.22, 0.98 * alpha)
	var gold := Color(1.0, 0.82, 0.18, alpha)
	var magenta := Color(1.0, 0.18, 0.58, alpha)

	# Double chamfer panel with outer magenta and inner border
	_draw_chamfer_panel(ban_rect, navy_bg, magenta, 10.0 * scale_pop)
	var inner_rect := Rect2(ban_rect.position + Vector2(4.0, 4.0), ban_rect.size - Vector2(8.0, 8.0))
	_draw_chamfer_panel(inner_rect, Color(0.14, 0.09, 0.32, 0.98 * alpha), gold, 8.0 * scale_pop)

	# Crown emblem at top center of banner
	_draw_crown(Vector2(ban_rect.get_center().x, ban_rect.position.y + 6.0), 16.0 * scale_pop, gold)

	# 3. Header: "RUBATO!" in bold italic with drop shadow
	var title_str: String = tr(&"HUD_PART_STOLEN_BANNER_TITLE")
	var title_fsize: int = int(round(42.0 * scale_pop))
	# Drop shadow
	draw_string(font_bold, ban_rect.position + Vector2(2.0, 44.0 * scale_pop + 2.0), title_str, HORIZONTAL_ALIGNMENT_CENTER, ban_w, title_fsize, Color(0.0, 0.0, 0.0, 0.90 * alpha))
	# Main glowing text
	draw_string(font_bold, ban_rect.position + Vector2(0.0, 44.0 * scale_pop), title_str, HORIZONTAL_ALIGNMENT_CENTER, ban_w, title_fsize, gold)

	# 4. Subtitle: e.g. "MOTOSEGA [EPICO]"
	var pdata: PartData = PartCatalog.get_part(_stolen_part_id)
	var part_name: String = tr(pdata.translation_key)
	var r_color: Color = PartCatalog.get_rarity_color(pdata.rarity)
	r_color.a = alpha
	var rarity_key: StringName = PartCatalog.get_rarity_translation_key(pdata.rarity)
	var sub_str: String = "%s  [%s]" % [part_name.to_upper(), tr(rarity_key)]
	var sub_fsize: int = int(round(18.0 * scale_pop))

	var badge_w: float = clampf(280.0 * scale_pop, 200.0, ban_w - 24.0)
	var badge_r := Rect2(Vector2(center_pt.x - badge_w * 0.5, ban_rect.position.y + 56.0 * scale_pop), Vector2(badge_w, 24.0 * scale_pop))
	draw_rect(badge_r, Color(0.07, 0.04, 0.18, 0.92 * alpha), true)
	draw_rect(badge_r, r_color, false, 1.5)
	draw_string(font_bold, badge_r.position + Vector2(0.0, 18.0 * scale_pop), sub_str, HORIZONTAL_ALIGNMENT_CENTER, badge_w, sub_fsize, r_color)

func _draw_chamfer_panel(r: Rect2, fill: Color, border: Color, cut: float) -> void:
	var pts := PackedVector2Array([
		Vector2(r.position.x + cut, r.position.y),
		Vector2(r.end.x - cut, r.position.y),
		Vector2(r.end.x, r.position.y + cut),
		Vector2(r.end.x, r.end.y - cut),
		Vector2(r.end.x - cut, r.end.y),
		Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut),
		Vector2(r.position.x, r.position.y + cut),
		Vector2(r.position.x + cut, r.position.y),
	])
	draw_colored_polygon(pts.slice(0, 8), fill)
	draw_polyline(pts, border, 2.0)

func _draw_crown(center: Vector2, half_w: float, col: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-half_w, 10.0),
		center + Vector2(-half_w * 0.85, -6.0),
		center + Vector2(-half_w * 0.35, 3.0),
		center + Vector2(0.0, -10.0),
		center + Vector2(half_w * 0.35, 3.0),
		center + Vector2(half_w * 0.85, -6.0),
		center + Vector2(half_w, 10.0),
	])
	draw_colored_polygon(pts, col)

func _draw_slot_svg_icon(slot_idx: int, box_r: Rect2, alpha: float, col: Color) -> void:
	match slot_idx:
		0: # ARMS (Vector SVG)
			if ARM_SVG != null:
				var icon_sz := Vector2(18.0, 25.0)
				var icon_pos := box_r.position + (box_r.size - icon_sz) * 0.5
				draw_texture_rect(ARM_SVG, Rect2(icon_pos, icon_sz), false, Color(1.0, 1.0, 1.0, alpha))
			else:
				var c := box_r.get_center()
				draw_rect(Rect2(c + Vector2(-8.0, -7.0), Vector2(16.0, 14.0)), Color(col.r, col.g, col.b, alpha), true)
		1: # LEGS (Vector SVG)
			if LEG_SVG != null:
				var icon_sz := Vector2(16.0, 26.0)
				var icon_pos := box_r.position + (box_r.size - icon_sz) * 0.5
				draw_texture_rect(LEG_SVG, Rect2(icon_pos, icon_sz), false, Color(1.0, 1.0, 1.0, alpha))
			else:
				var c := box_r.get_center()
				draw_rect(Rect2(c + Vector2(-6.0, -9.0), Vector2(12.0, 18.0)), Color(col.r, col.g, col.b, alpha), true)
		2: # HEAD (Visor Helmet Icon)
			var c := box_r.get_center()
			draw_rect(Rect2(c + Vector2(-10.0, -10.0), Vector2(20.0, 20.0)), Color(col.r, col.g, col.b, alpha), true)
			draw_rect(Rect2(c + Vector2(-7.0, -3.0), Vector2(14.0, 6.0)), Color(1.0, 1.0, 1.0, alpha * 0.95), true)
			draw_rect(Rect2(c + Vector2(-3.0, 4.0), Vector2(6.0, 2.5)), Color(0.12, 0.08, 0.22, alpha), true)
		3: # CORE / Components (Vector SVG)
			if CORE_SVG != null:
				var icon_sz := Vector2(13.0, 26.0)
				var icon_pos := box_r.position + (box_r.size - icon_sz) * 0.5
				draw_texture_rect(CORE_SVG, Rect2(icon_pos, icon_sz), false, Color(1.0, 1.0, 1.0, alpha))
			else:
				var c := box_r.get_center()
				draw_circle(c, 8.5, Color(col.r, col.g, col.b, alpha))
				draw_circle(c, 3.5, Color(0.08, 0.08, 0.20, alpha))

func _draw_slot_mini_icon(slot_idx: int, c: Vector2, col: Color) -> void:
	var white := Color(0.98, 0.98, 1.0)
	match slot_idx:
		0: # Fist (ARMS)
			draw_rect(Rect2(c + Vector2(-6.0, -5.0), Vector2(12.0, 10.0)), white, true)
			draw_rect(Rect2(c + Vector2(-4.0, 4.0), Vector2(7.0, 4.0)), col, true)
		1: # Boot (LEGS)
			draw_rect(Rect2(c + Vector2(-4.0, -7.0), Vector2(6.0, 11.0)), white, true)
			draw_rect(Rect2(c + Vector2(-4.0, 2.0), Vector2(11.0, 5.0)), col, true)
		2: # Head (HEAD)
			draw_rect(Rect2(c + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), col, true)
			draw_rect(Rect2(c + Vector2(-3.0, -2.0), Vector2(6.0, 3.0)), white, true)
		3: # Core / Gear (CORE)
			draw_circle(c, 6.5, col)
			draw_circle(c, 2.8, Color(0.08, 0.08, 0.20))

func _draw_mockup_top_bar(rect_size: Vector2) -> void:
	var total_sec: int = maxi(0, int(ceil(time_remaining_sec)))
	var is_last_10s: bool = (total_sec <= 10 and not show_result_overlay)
	var pulse_scale: float = (1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.015)) if is_last_10s else 1.0

	var navy_bg := Color(0.08, 0.08, 0.22, 0.94)
	var pill_border := Color(0.24, 0.24, 0.46, 0.50)
	var white := Color.WHITE
	var radius: float = 14.0

	# ----------------- ROW 1: TOP BAR (Y = 18.0, H = 46.0) -----------------
	# 1. Timer Pill [timer.svg] 00:47
	var timer_w: float = 142.0 * pulse_scale
	var timer_h: float = 46.0 * pulse_scale
	var timer_rect := Rect2(Vector2(24.0, 18.0), Vector2(timer_w, timer_h))
	var t_border: Color = Color(1.0, 0.25, 0.35) if is_last_10s else (Color(1.0, 0.18, 0.58) if is_frenzy else pill_border)
	_draw_rounded_rect(timer_rect, navy_bg, radius * pulse_scale, true)
	_draw_rounded_rect(timer_rect, t_border, radius * pulse_scale, false, 1.4)

	var icon_timer_sz := Vector2(22.0, 26.0) * pulse_scale
	var icon_timer_pos := timer_rect.position + Vector2(12.0 * pulse_scale, (timer_h - icon_timer_sz.y) * 0.5)
	if TIMER_SVG != null:
		draw_texture_rect(TIMER_SVG, Rect2(icon_timer_pos, icon_timer_sz), false, white)
	else:
		_draw_stopwatch_icon(timer_rect.position + Vector2(22.0, timer_h * 0.5), 11.0, white)

	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	var timer_str: String = "%02d:%02d" % [mins, secs]
	var timer_col: Color = Color(1.0, 0.30, 0.40) if is_last_10s else white
	var timer_fsize: int = int(round(26.0 * pulse_scale))
	draw_string(font_bold, timer_rect.position + Vector2(44.0 * pulse_scale, timer_h * 0.5 + 9.0 * pulse_scale), timer_str, HORIZONTAL_ALIGNMENT_LEFT, -1, timer_fsize, timer_col)

	# 2. Skull Pill [skull.svg] 5
	var skull_w: float = 84.0
	var skull_h: float = 46.0
	var skull_rect := Rect2(Vector2(176.0, 18.0), Vector2(skull_w, skull_h))
	_draw_rounded_rect(skull_rect, navy_bg, radius, true)
	_draw_rounded_rect(skull_rect, pill_border, radius, false, 1.4)

	var icon_skull_sz := Vector2(24.0, 24.0)
	var icon_skull_pos := skull_rect.position + Vector2(10.0, (skull_h - icon_skull_sz.y) * 0.5)
	if SKULL_SVG != null:
		draw_texture_rect(SKULL_SVG, Rect2(icon_skull_pos, icon_skull_sz), false, white)
	else:
		_draw_skull_icon(skull_rect.position + Vector2(22.0, skull_h * 0.5), 11.0, white)

	var kills_str: String = str(stolen_parts_count)
	draw_string(font_bold, skull_rect.position + Vector2(36.0, skull_h * 0.5 + 9.0), kills_str, HORIZONTAL_ALIGNMENT_CENTER, 42.0, 26, white)

	# 3. Hamburger Button [hamburger.svg] (Top-right)
	var ham_w: float = 54.0
	var ham_h: float = 46.0
	_hamburger_btn_rect = Rect2(Vector2(rect_size.x - 24.0 - ham_w, 18.0), Vector2(ham_w, ham_h))
	_draw_rounded_rect(_hamburger_btn_rect, navy_bg, radius, true)
	_draw_rounded_rect(_hamburger_btn_rect, pill_border, radius, false, 1.4)

	var icon_ham_sz := Vector2(24.0, 21.0)
	var icon_ham_pos := _hamburger_btn_rect.position + (_hamburger_btn_rect.size - icon_ham_sz) * 0.5
	if HAMBURGER_SVG != null:
		draw_texture_rect(HAMBURGER_SVG, Rect2(icon_ham_pos, icon_ham_sz), false, white)
	else:
		var c_x: float = _hamburger_btn_rect.position.x + 14.0
		var c_w: float = _hamburger_btn_rect.size.x - 28.0
		for bar_i in range(3):
			var bar_y: float = _hamburger_btn_rect.position.y + 15.0 + float(bar_i) * 8.0
			draw_line(Vector2(c_x, bar_y), Vector2(c_x + c_w, bar_y), white, 3.0)

	# ----------------- ROW 2: PARTS & SLOTS (Y = 74.0, H = 48.0) -----------------
	# 1. Stolen Parts Progress Pill: [ 2/9 ]
	var prog_rect := Rect2(Vector2(24.0, 74.0), Vector2(78.0, 48.0))
	var is_abom_ready: bool = (stolen_parts_count >= 9 or is_abomination)
	var prog_border: Color = Color(1.0, 0.85, 0.20) if is_abom_ready else pill_border
	var prog_border_w: float = 2.4 if is_abom_ready else 1.4
	_draw_rounded_rect(prog_rect, navy_bg, radius, true)
	_draw_rounded_rect(prog_rect, prog_border, radius, false, prog_border_w)
	var prog_str: String = "%d/9" % [mini(9, stolen_parts_count)]
	var prog_text_col: Color = Color(1.0, 0.88, 0.25) if is_abom_ready else white
	draw_string(font_bold, prog_rect.position + Vector2(0.0, 33.0), prog_str, HORIZONTAL_ALIGNMENT_CENTER, 78.0, 24, prog_text_col)

	# 2. Slot Boxes: Arm (Fist), Leg (Boot), Components (Wrench)
	var slot_defs: Array[Dictionary] = [
		{
			"rect": Rect2(Vector2(112.0, 74.0), Vector2(48.0, 48.0)),
			"slot_enum": PartData.Slot.ARMS,
			"slot_idx": 1,
			"tex": ARM_SVG,
			"tex_sz": Vector2(22.0, 31.0)
		},
		{
			"rect": Rect2(Vector2(170.0, 74.0), Vector2(48.0, 48.0)),
			"slot_enum": PartData.Slot.LEGS,
			"slot_idx": 2,
			"tex": LEG_SVG,
			"tex_sz": Vector2(20.0, 32.0)
		},
		{
			"rect": Rect2(Vector2(228.0, 74.0), Vector2(48.0, 48.0)),
			"slot_enum": PartData.Slot.CORE,
			"slot_idx": 3,
			"tex": CORE_SVG,
			"tex_sz": Vector2(16.0, 34.0)
		},
	]

	for item: Dictionary in slot_defs:
		var b_rect: Rect2 = item["rect"]
		var s_enum: PartData.Slot = item["slot_enum"]
		var s_idx: int = item["slot_idx"]
		var tex: Texture2D = item["tex"]
		var tex_sz: Vector2 = item["tex_sz"]

		var pid: StringName = equipped_slots.get(s_enum, PartCatalog.get_base_part_for_slot(s_enum)) as StringName
		var is_upgraded: bool = (pid != PartCatalog.get_base_part_for_slot(s_enum))
		var pdata: PartData = PartCatalog.get_part(pid)
		var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
		var slot_cnt: int = int(collected_slot_counts.get(s_enum, 0))
		var is_slot_full: bool = (slot_cnt >= 3)

		_draw_rounded_rect(b_rect, navy_bg, radius, true)

		var b_border: Color = Color(1.0, 0.85, 0.20) if is_slot_full else (r_col if is_upgraded else pill_border)
		var b_w: float = 2.4 if is_slot_full else (2.0 if is_upgraded else 1.4)
		_draw_rounded_rect(b_rect, b_border, radius, false, b_w)

		# Slot flash pulse when part stolen
		if s_idx < _slot_flash_timers.size() and _slot_flash_timers[s_idx] > 0.0:
			var f_timer: float = _slot_flash_timers[s_idx]
			var p_alpha: float = clampf(f_timer / 1.6, 0.0, 1.0)
			var pulse: float = 0.5 + 0.5 * sin(f_timer * 16.0)
			_draw_rounded_rect(b_rect, Color(1.0, 0.85, 0.20, 0.95 * p_alpha), radius, false, 2.8)
			_draw_rounded_rect(b_rect, Color(1.0, 0.85, 0.20, 0.30 * pulse * p_alpha), radius, true)

		if tex != null:
			var tex_pos := b_rect.position + (b_rect.size - tex_sz) * 0.5
			draw_texture_rect(tex, Rect2(tex_pos, tex_sz), false, white)
		else:
			_draw_slot_mini_icon(s_idx, b_rect.get_center(), r_col)

		# 3-dot pip indicator at bottom of slot box (0/3 to 3/3 collected)
		var pip_y: float = b_rect.position.y + 41.5
		var pip_cx: float = b_rect.get_center().x
		for pip_i in range(3):
			var pip_x: float = pip_cx - 10.0 + float(pip_i) * 10.0
			var is_pip_filled: bool = (pip_i < slot_cnt)
			var dot_col: Color = (Color(1.0, 0.85, 0.20) if is_pip_filled else Color(0.35, 0.35, 0.55, 0.55))
			draw_circle(Vector2(pip_x, pip_y), 2.2, dot_col)

func _draw_top_bar_capsules(rect_size: Vector2) -> void:
	var total_sec: int = maxi(0, int(ceil(time_remaining_sec)))
	var is_last_10s: bool = (total_sec <= 10 and not show_result_overlay)
	var pulse_scale: float = (1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.015)) if is_last_10s else 1.0

	var pill_bg := Color(0.06, 0.08, 0.16, 0.92)
	var pill_border := Color(0.35, 0.40, 0.65, 0.60)
	var white := Color.WHITE

	# 1. TOP-LEFT: Stopwatch Timer Capsule (⏱ 00:52)
	var timer_w: float = 146.0 * pulse_scale
	var timer_h: float = 46.0 * pulse_scale
	var timer_rect := Rect2(Vector2(18.0, 16.0), Vector2(timer_w, timer_h))
	var t_border: Color = Color(1.0, 0.25, 0.35) if is_last_10s else (Color(1.0, 0.18, 0.58) if is_frenzy else pill_border)
	_draw_capsule_pill(timer_rect, pill_bg, t_border, 1.8)

	var clock_c := timer_rect.position + Vector2(25.0 * pulse_scale, timer_h * 0.5)
	_draw_stopwatch_icon(clock_c, 11.0 * pulse_scale, white)

	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	var timer_str: String = tr(&"HUD_TIMER_FORMAT") % [mins, secs]
	var timer_col: Color = Color(1.0, 0.30, 0.40) if is_last_10s else white
	var timer_fsize: int = int(round(28.0 * pulse_scale))
	draw_string(font_bold, timer_rect.position + Vector2(44.0 * pulse_scale, timer_h * 0.5 + 9.0 * pulse_scale), timer_str, HORIZONTAL_ALIGNMENT_LEFT, -1, timer_fsize, timer_col)

	# 2. TOP-RIGHT: Skull Kills Capsule (💀 5)
	var kill_w: float = 88.0
	var kill_h: float = 46.0
	var kill_rect := Rect2(Vector2(rect_size.x - kill_w - 18.0, 16.0), Vector2(kill_w, kill_h))
	_draw_capsule_pill(kill_rect, pill_bg, pill_border, 1.8)

	var skull_c := kill_rect.position + Vector2(24.0, kill_h * 0.5)
	_draw_skull_icon(skull_c, 11.0, white)

	var kills_str: String = str(stolen_parts_count)
	draw_string(font_bold, kill_rect.position + Vector2(42.0, kill_h * 0.5 + 9.0), kills_str, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 28, white)

func _draw_capsule_pill(rect: Rect2, bg_col: Color, border_col: Color, border_w: float = 1.6) -> void:
	var r: float = rect.size.y * 0.5
	var c_left := Vector2(rect.position.x + r, rect.position.y + r)
	var c_right := Vector2(rect.end.x - r, rect.position.y + r)
	var mid_rect := Rect2(Vector2(c_left.x, rect.position.y), Vector2(maxf(1.0, rect.size.x - r * 2.0), rect.size.y))

	draw_circle(c_left, r, bg_col)
	draw_circle(c_right, r, bg_col)
	draw_rect(mid_rect, bg_col, true)

	if border_w > 0.0:
		draw_arc(c_left, r, PI * 0.5, PI * 1.5, 16, border_col, border_w)
		draw_arc(c_right, r, -PI * 0.5, PI * 0.5, 16, border_col, border_w)
		draw_line(Vector2(c_left.x, rect.position.y), Vector2(c_right.x, rect.position.y), border_col, border_w)
		draw_line(Vector2(c_left.x, rect.end.y), Vector2(c_right.x, rect.end.y), border_col, border_w)

func _draw_stopwatch_icon(c: Vector2, r: float, col: Color) -> void:
	draw_arc(c, r, 0.0, TAU, 20, col, 2.2)
	draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, -r - 4.5), col, 2.2)
	draw_line(c + Vector2(-3.5, -r - 4.5), c + Vector2(3.5, -r - 4.5), col, 2.0)
	draw_line(c, c + Vector2(0.0, -r * 0.52), col, 2.0)
	draw_line(c, c + Vector2(r * 0.44, 0.0), col, 2.0)

func _draw_skull_icon(c: Vector2, sz: float, col: Color) -> void:
	draw_circle(c + Vector2(0.0, -2.0), sz * 0.60, col)
	var jaw_r := Rect2(c + Vector2(-sz * 0.35, sz * 0.12), Vector2(sz * 0.70, sz * 0.44))
	draw_rect(jaw_r, col, true)
	var dark_col := Color(0.06, 0.08, 0.16, 0.95)
	draw_circle(c + Vector2(-sz * 0.25, -sz * 0.08), sz * 0.18, dark_col)
	draw_circle(c + Vector2(sz * 0.25, -sz * 0.08), sz * 0.18, dark_col)
	draw_circle(c + Vector2(0.0, sz * 0.16), sz * 0.08, dark_col)
	draw_line(c + Vector2(-sz * 0.12, sz * 0.26), c + Vector2(-sz * 0.12, sz * 0.54), dark_col, 1.2)
	draw_line(c + Vector2(sz * 0.12, sz * 0.26), c + Vector2(sz * 0.12, sz * 0.54), dark_col, 1.2)

func _draw_bottom_equipment_dock(rect_size: Vector2) -> void:
	var total_w: float = 284.0
	var total_h: float = 74.0
	var dock_x: float = rect_size.x * 0.5 - total_w * 0.5
	var dock_y: float = rect_size.y - 100.0
	var dock_rect := Rect2(Vector2(dock_x, dock_y), Vector2(total_w, total_h))

	var bg_col := Color(0.09, 0.06, 0.18, 0.82)
	var b_col := Color(0.38, 0.32, 0.62, 0.55)
	_draw_capsule_pill(dock_rect, bg_col, b_col, 1.5)

	var display_slots: Array[PartData.Slot] = [
		PartData.Slot.ARMS,
		PartData.Slot.LEGS,
		PartData.Slot.HEAD,
		PartData.Slot.CORE,
	]

	var card_w: float = 58.0
	var card_h: float = 60.0
	var card_r: float = 12.0
	var card_y: float = dock_y + 7.0

	for s_idx: int in range(4):
		var slot_enum: PartData.Slot = display_slots[s_idx]
		var pid: StringName = equipped_slots.get(slot_enum, PartCatalog.get_base_part_for_slot(slot_enum)) as StringName
		var pdata: PartData = PartCatalog.get_part(pid)
		var is_upgraded: bool = (pid != PartCatalog.get_base_part_for_slot(slot_enum))
		var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)

		var card_x: float = dock_x + 12.0 + float(s_idx) * 66.0
		var card_rect := Rect2(Vector2(card_x, card_y), Vector2(card_w, card_h))

		var card_bg := Color(0.14, 0.10, 0.26, 0.90) if is_upgraded else Color(0.08, 0.06, 0.16, 0.70)
		_draw_rounded_rect(card_rect, card_bg, card_r, true)

		var border_color: Color = r_col if is_upgraded else Color(0.32, 0.28, 0.48, 0.50)
		var border_width: float = 2.0 if is_upgraded else 1.2
		_draw_rounded_rect(card_rect, border_color, card_r, false, border_width)

		var c_center := card_rect.position + card_rect.size * 0.5
		_draw_dock_part_icon(s_idx, pid, c_center, is_upgraded, r_col)

		if int(slot_enum) < _slot_flash_timers.size() and _slot_flash_timers[int(slot_enum)] > 0.0:
			var f_timer: float = _slot_flash_timers[int(slot_enum)]
			var p_alpha: float = clampf(f_timer / 1.6, 0.0, 1.0)
			var pulse: float = 0.5 + 0.5 * sin(f_timer * 16.0)
			_draw_rounded_rect(card_rect, Color(1.0, 0.85, 0.20, 0.95 * p_alpha), card_r, false, 3.2)
			_draw_rounded_rect(card_rect, Color(1.0, 0.85, 0.20, 0.35 * pulse * p_alpha), card_r, true)

func _draw_dock_part_icon(s_idx: int, pid: StringName, c: Vector2, is_upgraded: bool, _r_col: Color) -> void:
	match s_idx:
		0: # ARMS (Fist or weapon)
			if pid == &"chainsaw_arm":
				_draw_icon_chainsaw(c, 24.0)
			else:
				_draw_icon_fist(c, 24.0, Color(1.0, 0.75, 0.68) if is_upgraded else Color(0.85, 0.68, 0.62))
		1: # LEGS (Boot or Rocket boot)
			_draw_icon_boot(c, 26.0, pid == &"rocket_legs")
		2: # HEAD (Helmet or Visor)
			_draw_icon_helmet(c, 24.0, pid == &"laser_eye" or pid == &"visor_head")
		3: # CORE / WEAPON (Chainsaw or Core)
			if pid == &"chainsaw_arm" or pid == &"base_core" or pid == &"shield_core" or pid == &"crown_core":
				_draw_icon_chainsaw(c, 24.0)
			else:
				_draw_icon_fist(c, 24.0, Color(1.0, 0.75, 0.68))

func _draw_icon_fist(c: Vector2, sz: float, skin_col: Color) -> void:
	draw_circle(c + Vector2(-2.0, 0.0), sz * 0.42, skin_col)
	var knuckles_r := Rect2(c + Vector2(-sz * 0.38, -sz * 0.36), Vector2(sz * 0.76, sz * 0.45))
	draw_rect(knuckles_r, skin_col, true)
	draw_circle(c + Vector2(-sz * 0.35, sz * 0.15), sz * 0.22, skin_col)
	var div_col := Color(skin_col.r * 0.72, skin_col.g * 0.62, skin_col.b * 0.62)
	draw_line(c + Vector2(-sz * 0.12, -sz * 0.35), c + Vector2(-sz * 0.12, sz * 0.08), div_col, 1.2)
	draw_line(c + Vector2(sz * 0.12, -sz * 0.35), c + Vector2(sz * 0.12, sz * 0.08), div_col, 1.2)

func _draw_icon_boot(c: Vector2, sz: float, is_rocket: bool) -> void:
	var boot_blue := Color(0.18, 0.45, 0.92)
	var white := Color(0.96, 0.96, 0.98)
	var shaft_r := Rect2(c + Vector2(-sz * 0.30, -sz * 0.42), Vector2(sz * 0.44, sz * 0.52))
	draw_rect(shaft_r, boot_blue, true)
	var toe_r := Rect2(c + Vector2(-sz * 0.42, sz * 0.10), Vector2(sz * 0.76, sz * 0.26))
	draw_rect(toe_r, white, true)
	draw_rect(Rect2(c + Vector2(-sz * 0.42, sz * 0.34), Vector2(sz * 0.76, 3.0)), Color(0.10, 0.10, 0.20), true)
	if is_rocket:
		var flame_pts := PackedVector2Array([
			c + Vector2(-sz * 0.20, sz * 0.38),
			c + Vector2(sz * 0.05, sz * 0.38),
			c + Vector2(-sz * 0.08, sz * 0.65),
		])
		draw_colored_polygon(flame_pts, Color(1.0, 0.55, 0.10))

func _draw_icon_helmet(c: Vector2, sz: float, _has_visor: bool) -> void:
	var white := Color(0.96, 0.96, 0.98)
	var dark_screen := Color(0.06, 0.08, 0.15)
	draw_circle(c + Vector2(0.0, -2.0), sz * 0.46, white)
	var chin_r := Rect2(c + Vector2(-sz * 0.42, 0.0), Vector2(sz * 0.84, sz * 0.40))
	draw_rect(chin_r, white, true)
	var visor_r := Rect2(c + Vector2(-sz * 0.34, -sz * 0.16), Vector2(sz * 0.68, sz * 0.26))
	draw_rect(visor_r, dark_screen, true)
	draw_line(visor_r.position + Vector2(4.0, 3.0), visor_r.position + Vector2(visor_r.size.x - 4.0, 3.0), Color(0.35, 0.85, 1.0, 0.85), 1.2)

func _draw_icon_chainsaw(c: Vector2, sz: float) -> void:
	var orange := Color(1.0, 0.45, 0.10)
	var steel := Color(0.38, 0.42, 0.52)
	var motor_r := Rect2(c + Vector2(-sz * 0.42, sz * 0.02), Vector2(sz * 0.36, sz * 0.36))
	draw_rect(motor_r, orange, true)
	var blade_r := Rect2(c + Vector2(-sz * 0.10, -sz * 0.36), Vector2(sz * 0.52, sz * 0.30))
	draw_rect(blade_r, steel, true)
	for t_i in range(4):
		var tx: float = blade_r.position.x + 3.0 + float(t_i) * 6.5
		draw_line(Vector2(tx, blade_r.position.y), Vector2(tx + 2.0, blade_r.position.y - 3.0), Color.WHITE, 1.2)

func _draw_rounded_rect(rect: Rect2, col: Color, radius: float, fill: bool = true, width: float = 1.0) -> void:
	var r: float = minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	var pts := PackedVector2Array()
	var c_tl := rect.position + Vector2(r, r)
	var c_tr := Vector2(rect.end.x - r, rect.position.y + r)
	var c_br := rect.end - Vector2(r, r)
	var c_bl := Vector2(rect.position.x + r, rect.end.y - r)

	for i in range(5):
		var a: float = PI + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_tl + Vector2(cos(a), sin(a)) * r)
	for i in range(5):
		var a: float = -PI * 0.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_tr + Vector2(cos(a), sin(a)) * r)
	for i in range(5):
		var a: float = 0.0 + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_br + Vector2(cos(a), sin(a)) * r)
	for i in range(5):
		var a: float = PI * 0.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_bl + Vector2(cos(a), sin(a)) * r)

	if fill:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, width)

func _draw_overhead_combatants() -> void:
	var navy_bg := Color(0.04, 0.04, 0.08, 0.95)
	var white := Color(1.0, 1.0, 1.0, 1.0)
	var bot_text: String = tr(&"HUD_BOT_BADGE")

	for item: Dictionary in overhead_combatant_data:
		var p: Vector2 = item["screen_pos"]
		var is_p: bool = bool(item["is_player"])
		var ratio: float = float(item["hp_ratio"])
		var b_col: Color = item.get("base_color", Color(0.96, 0.32, 0.24)) as Color

		if is_p:
			var float_y: float = sin(float(Time.get_ticks_msec()) * 0.007) * 2.2
			var caret_pts := PackedVector2Array([
				p + Vector2(-9.0, -32.0 + float_y),
				p + Vector2(9.0, -32.0 + float_y),
				p + Vector2(0.0, -18.0 + float_y),
			])
			var caret_outline := PackedVector2Array([
				p + Vector2(-9.0, -32.0 + float_y),
				p + Vector2(9.0, -32.0 + float_y),
				p + Vector2(0.0, -18.0 + float_y),
				p + Vector2(-9.0, -32.0 + float_y),
			])
			draw_colored_polygon(caret_pts, white)
			draw_polyline(caret_outline, Color(0.04, 0.04, 0.08, 0.95), 1.6)

			var bar_w: float = 52.0
			var bar_h: float = 7.0
			var bar_rect := Rect2(p + Vector2(-bar_w * 0.5, -9.0), Vector2(bar_w, bar_h))
			_draw_rounded_rect(bar_rect, navy_bg, 3.5, true)
			var fill_w: float = maxf(0.0, (bar_w - 2.0) * ratio)
			if fill_w > 1.0:
				var fill_rect := Rect2(bar_rect.position + Vector2(1.0, 1.0), Vector2(fill_w, bar_h - 2.0))
				var fill_col := Color(0.12, 0.85, 1.0) if ratio > 0.30 else Color(1.0, 0.32, 0.22)
				_draw_rounded_rect(fill_rect, fill_col, 2.5, true)
			_draw_rounded_rect(bar_rect, Color(0.04, 0.04, 0.08, 0.95), 3.5, false, 1.2)
		else:
			var bot_w: float = 44.0
			var bot_h: float = 6.0
			var bar_rect := Rect2(p + Vector2(-bot_w * 0.5, -8.0), Vector2(bot_w, bot_h))
			_draw_rounded_rect(bar_rect, navy_bg, 3.0, true)
			var fill_w: float = maxf(0.0, (bot_w - 2.0) * ratio)
			if fill_w > 1.0:
				var fill_rect := Rect2(bar_rect.position + Vector2(1.0, 1.0), Vector2(fill_w, bot_h - 2.0))
				_draw_rounded_rect(fill_rect, b_col, 2.0, true)
			_draw_rounded_rect(bar_rect, Color(0.04, 0.04, 0.08, 0.95), 3.0, false, 1.2)

			var bot_tag_w: float = 24.0
			var bot_tag_h: float = 11.0
			var tag_rect := Rect2(p + Vector2(-bot_tag_w * 0.5, -22.0), Vector2(bot_tag_w, bot_tag_h))
			_draw_rounded_rect(tag_rect, Color(0.06, 0.05, 0.14, 0.75), 3.0, true)
			draw_string(font_bold, tag_rect.position + Vector2(0.0, 9.0), bot_text, HORIZONTAL_ALIGNMENT_CENTER, bot_tag_w, 9, Color(0.85, 0.85, 0.95))
