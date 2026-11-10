class_name VerticalHUD
extends Control

signal rematch_requested
signal customize_requested()

var time_remaining_sec: float = 90.0
var stolen_parts_count: int = 0
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

const ARM_SVG: Texture2D = preload("res://game/ui/assets/arm.svg")
const LEG_SVG: Texture2D = preload("res://game/ui/assets/leg.svg")
const CORE_SVG: Texture2D = preload("res://game/ui/assets/components.svg")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_safe_area()

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

	for c: MatchServer.CombatantState in combatants:
		if not c.alive:
			continue
		var head_y: float = 2.25 if c.is_abomination else 1.70
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

	# 1. TOP-CENTER: Timer Panel with Stopwatch Icon (Larger + Urgent pulse in last 10s)
	var total_sec: int = maxi(0, int(ceil(time_remaining_sec)))
	var is_last_10s: bool = (total_sec <= 10 and not show_result_overlay)
	var pulse_scale: float = (1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.015)) if is_last_10s else 1.0
	var timer_w: float = 154.0 * pulse_scale
	var timer_h: float = 48.0 * pulse_scale
	var timer_rect := Rect2(Vector2(rect_size.x * 0.5 - timer_w * 0.5, 14.0), Vector2(timer_w, timer_h))
	var timer_border_col: Color = Color(1.0, 0.20, 0.35) if is_last_10s else (magenta if is_frenzy else border_col)
	_draw_chamfer_panel(timer_rect, navy_bg, timer_border_col, 6.0)

	var clock_c := timer_rect.position + Vector2(28.0 * pulse_scale, timer_h * 0.5)
	draw_arc(clock_c, 11.5 * pulse_scale, 0.0, TAU, 24, white, 2.4)
	draw_line(clock_c + Vector2(0.0, -11.5 * pulse_scale), clock_c + Vector2(0.0, -16.0 * pulse_scale), white, 2.5)
	draw_line(clock_c + Vector2(-4.0, -16.0 * pulse_scale), clock_c + Vector2(4.0, -16.0 * pulse_scale), white, 2.5)
	draw_line(clock_c, clock_c + Vector2(5.0 * pulse_scale, -5.0 * pulse_scale), white, 2.2)

	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	var timer_str: String = tr(&"HUD_TIMER_FORMAT") % [mins, secs]
	var timer_text_col: Color = Color(1.0, 0.30, 0.40) if is_last_10s else (gold if is_frenzy else white)
	var timer_fsize: int = int(round(30.0 * pulse_scale))
	draw_string(font_bold, timer_rect.position + Vector2(48.0 * pulse_scale, timer_h * 0.5 + 10.0 * pulse_scale), timer_str, HORIZONTAL_ALIGNMENT_LEFT, -1, timer_fsize, timer_text_col)

	# 2. TOP-RIGHT: 4-Slot Panel with Vector SVGs & Stolen Parts Counter (Translucent empty / Opaque upgraded)
	var slots_w: float = 168.0
	var slots_h: float = 68.0
	var slots_rect := Rect2(Vector2(rect_size.x - slots_w - 12.0, 14.0), Vector2(slots_w, slots_h))
	_draw_chamfer_panel(slots_rect, navy_bg, gold if is_abomination else border_col, 7.0)
	var display_slot_order: Array[PartData.Slot] = [
		PartData.Slot.ARMS,
		PartData.Slot.LEGS,
		PartData.Slot.HEAD,
		PartData.Slot.CORE,
	]
	var box_sz: float = 34.0
	for s_idx: int in range(4):
		var slot_enum: PartData.Slot = display_slot_order[s_idx]
		var pid: StringName = equipped_slots.get(slot_enum, PartCatalog.get_base_part_for_slot(slot_enum)) as StringName
		var pdata: PartData = PartCatalog.get_part(pid)
		var is_upgraded: bool = (pid != PartCatalog.get_base_part_for_slot(slot_enum))
		var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
		var sx: float = slots_rect.position.x + 8.0 + float(s_idx) * 38.0
		var sy: float = slots_rect.position.y + 7.0
		var box_r := Rect2(Vector2(sx, sy), Vector2(box_sz, box_sz))

		# Transparency: muted when empty / basic, full bright opacity when holding upgraded part
		var fill_alpha: float = 0.95 if is_upgraded else 0.40
		var icon_alpha: float = 1.0 if is_upgraded else 0.32
		draw_rect(box_r, Color(0.12, 0.10, 0.26, fill_alpha), true)
		draw_rect(box_r, Color(r_col.r, r_col.g, r_col.b, fill_alpha), false, 2.0 if is_upgraded else 1.2)

		_draw_slot_svg_icon(s_idx, box_r, icon_alpha, r_col)

		if int(slot_enum) < _slot_flash_timers.size() and _slot_flash_timers[int(slot_enum)] > 0.0:
			var f_timer: float = _slot_flash_timers[int(slot_enum)]
			var p_alpha: float = clampf(f_timer / 1.6, 0.0, 1.0)
			var pulse: float = 0.5 + 0.5 * sin(f_timer * 16.0)
			draw_rect(box_r, Color(1.0, 0.85, 0.20, 0.95 * p_alpha), false, 3.2)
			draw_rect(box_r, Color(1.0, 0.85, 0.20, 0.35 * pulse * p_alpha), true)

		if colorblind_mode_enabled:
			var pip_count: int = int(pdata.rarity) + 1
			for p_i: int in range(pip_count):
				var px: float = box_r.position.x + 3.0 + float(p_i) * 6.5
				draw_rect(Rect2(Vector2(px, box_r.end.y - 4.0), Vector2(4.5, 3.0)), white, true)

	var counter_str: String = tr(&"HUD_STOLEN_COUNTER") % [stolen_parts_count]
	draw_string(font_bold, slots_rect.position + Vector2(24.0, 61.0), counter_str, HORIZONTAL_ALIGNMENT_CENTER, slots_w - 48.0, 16, white)

	# 3. TOP-LEFT: Clean field in match (Logo is reserved for menu to keep HUD uncluttered)

	# Frenzy Phase Banner or Part-Stolen Toast below timer
	if is_frenzy and not show_result_overlay:
		var f_rect := Rect2(Vector2(rect_size.x * 0.5 - 130.0, 62.0), Vector2(260.0, 36.0))
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
		var toast_rect := Rect2(Vector2(rect_size.x - 196.0, 82.0), Vector2(184.0, 28.0))
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

	# 5. ABOMINATION TRANSFORMATION STINGER BANNER
	_draw_abomination_active_banner(rect_size)

	# 5.5. JUICY STOLEN PART BANNER ("RUBATO!")
	_draw_stolen_part_banner(rect_size)

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

	var enter_fade: float = clampf(_intro_elapsed / 0.30, 0.0, 1.0)
	var exit_fade: float = clampf(intro_tutorial_timer / 0.80, 0.0, 1.0)
	var alpha: float = minf(enter_fade, exit_fade)
	if alpha <= 0.001:
		return

	var is_phase_1: bool = (intro_tutorial_timer > 3.0)
	var card_w: float = clampf(rect_size.x - 48.0, 320.0, 440.0)
	var card_h: float = 230.0
	var card_center := Vector2(rect_size.x * 0.5, rect_size.y * 0.44)
	var card_rect := Rect2(card_center - Vector2(card_w * 0.5, card_h * 0.5), Vector2(card_w, card_h))

	var navy_bg := Color(0.06, 0.05, 0.16, 0.94 * alpha)
	var border_col := Color(0.48, 0.42, 0.78, 0.92 * alpha)
	var magenta := Color(1.0, 0.18, 0.576, alpha)
	var gold := Color(1.0, 0.76, 0.12, alpha)
	var white := Color(0.98, 0.98, 1.0, alpha)

	if is_phase_1:
		# PHASE 1: RUBA I PEZZI! (0.0s - 3.0s)
		_draw_chamfer_panel(card_rect, navy_bg, border_col, 10.0)

		# Tilted animated header
		var bounce_y: float = sin(_intro_elapsed * 6.5) * 3.5
		var banner_rect := Rect2(Vector2(card_rect.position.x + 20.0, card_rect.position.y + 12.0 + bounce_y), Vector2(card_w - 40.0, 36.0))
		_draw_chamfer_panel(banner_rect, Color(0.12, 0.08, 0.28, 0.96 * alpha), gold, 6.0)
		draw_string(font_bold, banner_rect.position + Vector2(10.0, 26.0), tr(&"HUD_STEAL_PARTS").replace("\n", " "), HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x - 20.0, 22, gold)

		# Subtitle
		draw_string(font_regular, card_rect.position + Vector2(14.0, 72.0), tr(&"HUD_TUTORIAL_STEAL_SUB"), HORIZONTAL_ALIGNMENT_CENTER, card_w - 28.0, 16, Color(0.85, 0.84, 0.96, alpha))

		# Interactive 4-Slot Character Breakdown
		var fig_c := card_rect.position + Vector2(card_w * 0.24, 136.0)
		var fig_col := Color(0.95, 0.92, 0.84, alpha)
		draw_rect(Rect2(fig_c + Vector2(-9.0, -32.0), Vector2(18.0, 16.0)), fig_col, true)
		draw_rect(Rect2(fig_c + Vector2(-12.0, -14.0), Vector2(24.0, 24.0)), fig_col, true)
		draw_rect(Rect2(fig_c + Vector2(-20.0, -12.0), Vector2(7.0, 20.0)), fig_col, true)
		draw_rect(Rect2(fig_c + Vector2(13.0, -12.0), Vector2(7.0, 20.0)), fig_col, true)
		draw_rect(Rect2(fig_c + Vector2(-10.0, 12.0), Vector2(8.0, 22.0)), fig_col, true)
		draw_rect(Rect2(fig_c + Vector2(2.0, 12.0), Vector2(8.0, 22.0)), fig_col, true)

		var display_slot_order: Array[PartData.Slot] = [
			PartData.Slot.ARMS,
			PartData.Slot.LEGS,
			PartData.Slot.HEAD,
			PartData.Slot.CORE,
		]
		var limb_targets: Array[Vector2] = [
			fig_c + Vector2(16.0, -2.0),
			fig_c + Vector2(6.0, 20.0),
			fig_c + Vector2(0.0, -24.0),
			fig_c + Vector2(0.0, -2.0),
		]
		var slots_start_x: float = card_rect.position.x + card_w * 0.42
		var slot_spacing_x: float = (card_w * 0.54) / 4.0

		for s_idx: int in range(4):
			var slot_enum: PartData.Slot = display_slot_order[s_idx]
			var pid: StringName = equipped_slots.get(slot_enum, PartCatalog.get_base_part_for_slot(slot_enum)) as StringName
			var pdata: PartData = PartCatalog.get_part(pid)
			var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
			r_col.a = alpha

			var reveal_delay: float = 0.12 + float(s_idx) * 0.18
			var pop: float = clampf((_intro_elapsed - reveal_delay) / 0.22, 0.0, 1.0)
			if pop > 0.0:
				var scale_bounce: float = 1.0 + sin(pop * PI) * 0.22 if pop < 1.0 else 1.0
				var box_size := Vector2(38.0, 46.0) * scale_bounce
				var box_pos := Vector2(slots_start_x + float(s_idx) * slot_spacing_x, card_rect.position.y + 112.0) - (box_size - Vector2(38.0, 46.0)) * 0.5
				var box_r := Rect2(box_pos, box_size)
				# Draw connecting line from puppet
				draw_line(limb_targets[s_idx], box_r.position + Vector2(0.0, box_r.size.y * 0.5), Color(0.72, 0.76, 0.95, 0.65 * alpha * pop), 1.6)
				draw_rect(box_r, Color(0.12, 0.10, 0.26, 0.95 * alpha), true)
				draw_rect(box_r, r_col, false, 2.0)
				_draw_slot_mini_icon(s_idx, box_r.get_center() - Vector2(0.0, 4.0), r_col)
				draw_rect(Rect2(Vector2(box_r.position.x + 4.0, box_r.end.y - 6.0), Vector2(box_r.size.x - 8.0, 2.5)), r_col, true)

		# Tap/move to start prompt
		var hint_alpha: float = alpha * (0.55 + 0.45 * sin(_intro_elapsed * 5.0))
		draw_string(font_regular, card_rect.position + Vector2(10.0, card_h - 16.0), tr(&"HUD_TUTORIAL_TAP_TO_SKIP"), HORIZONTAL_ALIGNMENT_CENTER, card_w - 20.0, 14, Color(1.0, 0.88, 0.50, hint_alpha))

	else:
		# PHASE 2: DIVENTA L'ABOMINIO! (3.0s - 6.0s)
		_draw_chamfer_panel(card_rect, Color(0.16, 0.04, 0.20, 0.96 * alpha), magenta, 10.0)

		# Pulsing Gold Crown
		var p2_time: float = _intro_elapsed - 3.0
		var crown_pulse: float = 1.0 + sin(p2_time * 7.0) * 0.15
		var crown_c := Vector2(card_center.x, card_rect.position.y - 12.0)
		_draw_crown(crown_c, 24.0 * crown_pulse, gold)

		# Radiant golden accent lines behind crown
		for ray_i: int in range(8):
			var ang: float = -PI * 0.85 + float(ray_i) * (PI * 0.70 / 7.0)
			var r_dir := Vector2(cos(ang), sin(ang))
			draw_line(crown_c + r_dir * 18.0, crown_c + r_dir * (28.0 + 4.0 * sin(p2_time * 8.0 + float(ray_i))), Color(1.0, 0.85, 0.25, 0.65 * alpha), 2.2)

		# Title
		var banner_rect := Rect2(Vector2(card_rect.position.x + 20.0, card_rect.position.y + 16.0), Vector2(card_w - 40.0, 36.0))
		_draw_chamfer_panel(banner_rect, Color(0.24, 0.04, 0.18, 0.98 * alpha), magenta, 6.0)
		draw_string(font_bold, banner_rect.position + Vector2(10.0, 26.0), tr(&"HUD_BECOME_ABOMINATION").replace("\n", " "), HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x - 20.0, 23, gold)

		# Subtitle
		draw_string(font_regular, card_rect.position + Vector2(14.0, 74.0), tr(&"HUD_TUTORIAL_ABOM_SUB"), HORIZONTAL_ALIGNMENT_CENTER, card_w - 28.0, 16, Color(0.95, 0.88, 1.0, alpha))

		# Epic Abomination Perk Badges in Center (Localized)
		var badge_y: float = card_rect.position.y + 104.0
		var perks: Array[String] = [
			tr(&"HUD_TUTORIAL_PERK_STATS"),
			tr(&"HUD_TUTORIAL_PERK_CROWN"),
			tr(&"HUD_TUTORIAL_PERK_HUNT"),
		]
		var perk_cols: Array[Color] = [gold, Color(1.0, 0.45, 0.2), magenta]
		var col_w: float = (card_w - 36.0) / 3.0
		for pk_i: int in range(3):
			var pk_rect := Rect2(Vector2(card_rect.position.x + 18.0 + float(pk_i) * col_w, badge_y), Vector2(col_w - 8.0, 44.0))
			_draw_chamfer_panel(pk_rect, Color(0.08, 0.06, 0.22, 0.92 * alpha), perk_cols[pk_i] * alpha, 5.0)
			draw_string(font_bold, pk_rect.position + Vector2(2.0, 28.0), perks[pk_i], HORIZONTAL_ALIGNMENT_CENTER, pk_rect.size.x - 4.0, 13, perk_cols[pk_i] * alpha)

		# Tap/move to start prompt
		var hint_alpha: float = alpha * (0.55 + 0.45 * sin(p2_time * 5.0))
		draw_string(font_regular, card_rect.position + Vector2(10.0, card_h - 16.0), tr(&"HUD_TUTORIAL_TAP_TO_SKIP"), HORIZONTAL_ALIGNMENT_CENTER, card_w - 20.0, 14, Color(1.0, 0.88, 0.50, hint_alpha))

func _draw_abomination_active_banner(rect_size: Vector2) -> void:
	if _abom_banner_timer <= 0.0 or show_result_overlay:
		return
	var b_alpha: float = clampf(_abom_banner_timer / 0.4, 0.0, 1.0)
	var ban_w: float = minf(380.0, rect_size.x - 40.0)
	var ban_h: float = 64.0
	var ban_rect := Rect2(Vector2((rect_size.x - ban_w) * 0.5, 96.0), Vector2(ban_w, ban_h))
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

	var center_pt := Vector2(rect_size.x * 0.5, 212.0)

	# 1. Radiant rotating sunburst rays behind banner
	var ray_count: int = 16
	var ray_len: float = 210.0 * scale_pop
	var ray_rot: float = t_elapsed * 2.2
	for r_i: int in range(ray_count):
		var ang: float = float(r_i) * (TAU / float(ray_count)) + ray_rot
		var dir := Vector2(cos(ang), sin(ang))
		var r_col: Color = Color(1.0, 0.82, 0.18, 0.35 * alpha) if (r_i % 2 == 0) else Color(1.0, 0.20, 0.58, 0.28 * alpha)
		var p1: Vector2 = center_pt + dir * 42.0
		var p2: Vector2 = center_pt + dir * ray_len
		draw_line(p1, p2, r_col, 5.5 * scale_pop)

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

func _draw_overhead_combatants() -> void:
	var navy_bg := Color(0.078, 0.078, 0.196, 0.92)
	var gold := Color(1.0, 0.76, 0.12, 1.0)
	var magenta := Color(1.0, 0.18, 0.576, 1.0)
	var player_green := Color(0.22, 0.96, 0.38, 1.0)
	var bot_red := Color(0.96, 0.32, 0.24, 1.0)
	var bot_text: String = tr(&"HUD_BOT_BADGE")

	for item: Dictionary in overhead_combatant_data:
		var p: Vector2 = item["screen_pos"]
		var is_p: bool = bool(item["is_player"])
		var is_abom: bool = bool(item["is_abomination"])
		var ratio: float = float(item["hp_ratio"])

		if is_p:
			# PLAYER BADGE: Sleek floating crown & chevron pointer (Eliminated clunky debug "TU" badge!)
			var float_y: float = sin(float(Time.get_ticks_msec()) * 0.007) * 2.5
			_draw_crown(p + Vector2(0.0, -36.0 + float_y), 11.0, gold)

			# Downward gold pointer chevron directly above player
			var arrow_pts := PackedVector2Array([
				p + Vector2(-5.0, -20.0 + float_y),
				p + Vector2(5.0, -20.0 + float_y),
				p + Vector2(0.0, -14.0 + float_y),
			])
			draw_colored_polygon(arrow_pts, gold)

			# Health bar
			var bar_w: float = 54.0
			var bar_h: float = 6.0
			var bar_rect := Rect2(p + Vector2(-bar_w * 0.5, -7.0), Vector2(bar_w, bar_h))
			draw_rect(bar_rect, navy_bg, true)
			draw_rect(bar_rect, gold, false, 1.2)
			var fill_col: Color = player_green if ratio > 0.35 else Color(1.0, 0.35, 0.2)
			draw_rect(Rect2(bar_rect.position + Vector2(1.0, 1.0), Vector2((bar_w - 2.0) * ratio, bar_h - 2.0)), fill_col, true)
		else:
			# BOTS
			if is_abom:
				# Abomination Bot: Big warning badge with crown
				var abom_w: float = 72.0
				var abom_h: float = 18.0
				var abom_rect := Rect2(p + Vector2(-abom_w * 0.5, -30.0), Vector2(abom_w, abom_h))
				_draw_chamfer_panel(abom_rect, Color(0.35, 0.04, 0.12, 0.95), gold, 4.0)
				_draw_crown(p + Vector2(0.0, -36.0), 10.0, gold)
				draw_string(font_bold, abom_rect.position + Vector2(2.0, 14.0), bot_text, HORIZONTAL_ALIGNMENT_CENTER, abom_w - 4.0, 12, gold)

				var bar_w: float = 50.0
				var bar_h: float = 6.0
				var bar_rect := Rect2(p + Vector2(-bar_w * 0.5, -10.0), Vector2(bar_w, bar_h))
				draw_rect(bar_rect, navy_bg, true)
				draw_rect(bar_rect, magenta, false, 1.0)
				draw_rect(Rect2(bar_rect.position + Vector2(1.0, 1.0), Vector2((bar_w - 2.0) * ratio, bar_h - 2.0)), magenta, true)
			else:
				# Regular Bot: clean, compact, non-intrusive
				var bot_w: float = 38.0
				var bot_h: float = 5.0
				var bar_rect := Rect2(p + Vector2(-bot_w * 0.5, -8.0), Vector2(bot_w, bot_h))
				draw_rect(bar_rect, Color(0.06, 0.05, 0.14, 0.85), true)
				draw_rect(bar_rect, Color(0.35, 0.32, 0.55, 0.70), false, 1.0)
				draw_rect(Rect2(bar_rect.position + Vector2(0.5, 0.5), Vector2((bot_w - 1.0) * ratio, bot_h - 1.0)), bot_red, true)

				var bot_tag_w: float = 26.0
				var bot_tag_h: float = 12.0
				var tag_rect := Rect2(p + Vector2(-bot_tag_w * 0.5, -22.0), Vector2(bot_tag_w, bot_tag_h))
				draw_rect(tag_rect, Color(0.06, 0.05, 0.14, 0.75), true)
				draw_rect(tag_rect, Color(0.32, 0.30, 0.48, 0.60), false, 1.0)
				draw_string(font_bold, tag_rect.position + Vector2(0.0, 10.0), bot_text, HORIZONTAL_ALIGNMENT_CENTER, bot_tag_w, 10, Color(0.78, 0.78, 0.90))
