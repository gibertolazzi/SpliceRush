class_name SeasonPassModal
extends Control

signal closed()

const FONT_BOLD := preload("res://game/ui/fonts/LilitaOne-Regular.ttf")
const CHEST_TEX: Texture2D = preload("res://game/ui/assets/chest.svg")
const CROWN_TEX: Texture2D = preload("res://game/ui/assets/crown.svg")

const BG_TOP := Color(0.16, 0.11, 0.36, 0.98)
const BG_BOT := Color(0.08, 0.09, 0.20, 0.98)
const SLATE_BG := Color(0.149, 0.176, 0.259, 1.0)
const SLATE_BEVEL := Color(0.098, 0.118, 0.176, 1.0)
const DARK_BORDER := Color(0.063, 0.075, 0.118, 1.0)
const GOLD_FILL := Color(0.941, 0.745, 0.094, 1.0)
const GOLD_BEVEL := Color(0.765, 0.565, 0.047, 1.0)
const GREEN_FILL := Color(0.18, 0.80, 0.44, 1.0)
const GREEN_BEVEL := Color(0.10, 0.55, 0.28, 1.0)
const MAGENTA_FILL := Color(1.0, 0.18, 0.58, 1.0)
const BLUE_MISSION := Color(0.11, 0.47, 0.85, 1.0)
const BLUE_BEVEL := Color(0.07, 0.31, 0.58, 1.0)

const TAB_REWARDS: int = 0
const TAB_MISSIONS: int = 1

var social: SocialManager = null
var is_open: bool = false
var current_tab: int = TAB_REWARDS
var tier_scroll_idx: int = 0

var _back_rect := Rect2()
var _tab_rects: Array[Rect2] = []
var _activate_plus_rect := Rect2()
var _scroll_left_rect := Rect2()
var _scroll_right_rect := Rect2()
var _action_rects: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false

func open(initial_tab: int = TAB_REWARDS) -> void:
	is_open = true
	visible = true
	current_tab = initial_tab
	if social != null:
		# Center scroll near current season level
		var target_idx: int = maxi(0, (social.season_level - 31) - 1)
		tier_scroll_idx = mini(target_idx, maxi(0, SocialManager.SEASON_TIERS.size() - 3))
	queue_redraw()

func close() -> void:
	is_open = false
	visible = false
	closed.emit()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_open:
		return
	var pos := Vector2.ZERO
	var pressed: bool = false
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			pos = st.position
			pressed = true
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
			pressed = true
	if not pressed:
		return

	if _back_rect.has_point(pos):
		close()
		get_viewport().set_input_as_handled()
		return

	for i: int in range(_tab_rects.size()):
		if _tab_rects[i].has_point(pos):
			current_tab = i
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if current_tab == TAB_REWARDS:
		if _activate_plus_rect.has_area() and _activate_plus_rect.has_point(pos) and social != null:
			social.activate_premium_pass()
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if _scroll_left_rect.has_area() and _scroll_left_rect.has_point(pos):
			tier_scroll_idx = maxi(0, tier_scroll_idx - 1)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		if _scroll_right_rect.has_area() and _scroll_right_rect.has_point(pos):
			tier_scroll_idx = mini(maxi(0, SocialManager.SEASON_TIERS.size() - 3), tier_scroll_idx + 1)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	for act: Dictionary in _action_rects:
		if (act["rect"] as Rect2).has_point(pos) and social != null:
			var kind: String = str(act["kind"])
			if kind == "claim_tier":
				social.claim_pass_tier(int(act["tier"]), bool(act["paid"]))
			elif kind == "claim_task":
				social.claim_task(str(act["id"]))
			elif kind == "reroll_task":
				social.reroll_task(str(act["id"]))
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	get_viewport().set_input_as_handled()

func _draw() -> void:
	if not is_open:
		return
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)

	# Full-screen vertical Splice Rush gradient backdrop
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOT, BG_BOT])
	)

	# Top Header Bar
	var hdr_r := Rect2(0.0, 0.0, sz.x, 82.0)
	draw_rect(hdr_r, Color(0.08, 0.09, 0.18, 0.96), true)
	draw_line(Vector2(0.0, 82.0), Vector2(sz.x, 82.0), DARK_BORDER, 3.0)

	_back_rect = Rect2(16.0, 18.0, 48.0, 46.0)
	_draw_box(_back_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 12.0, 2.5)
	_draw_text_ol(Vector2(_back_rect.position.x, _back_rect.position.y + 32.0), "‹", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 28, Color.WHITE, 2.0)

	var s_num: int = social.season_number if social != null else 1
	var s_lvl: int = social.season_level if social != null else 34
	var s_xp: int = social.season_xp if social != null else 435
	var s_max: int = social.season_xp_max if social != null else 900

	_draw_text_ol(Vector2(76.0, 38.0), tr(&"PASS_TITLE") % s_num, HORIZONTAL_ALIGNMENT_LEFT, 320.0, 22, GOLD_FILL, 2.0)

	# Compact XP progress bar in header
	var h_pb := Rect2(76.0, 46.0, sz.x - 96.0, 22.0)
	_draw_xp_bar(h_pb, s_lvl, s_xp, s_max)

	# Two Tabs: RICOMPENSE | MISSIONI
	var tab_labels := [tr(&"PASS_TAB_REWARDS"), tr(&"PASS_TAB_MISSIONS")]
	_tab_rects.clear()
	var tw: float = (sz.x - 44.0) * 0.5
	for i: int in range(2):
		var tr_r := Rect2(18.0 + float(i) * (tw + 8.0), 96.0, tw, 44.0)
		_tab_rects.append(tr_r)
		var sel: bool = (i == current_tab)
		_draw_box(tr_r, GOLD_FILL if sel else SLATE_BG, GOLD_BEVEL if sel else SLATE_BEVEL, DARK_BORDER, 12.0, 2.5)
		_draw_text_ol(Vector2(tr_r.position.x, tr_r.position.y + 29.0), tab_labels[i], HORIZONTAL_ALIGNMENT_CENTER, tw, 18, Color.WHITE, 2.0)

	_action_rects.clear()
	_activate_plus_rect = Rect2()
	_scroll_left_rect = Rect2()
	_scroll_right_rect = Rect2()

	if current_tab == TAB_REWARDS:
		_draw_rewards_track(sz, s_lvl)
	else:
		_draw_missions_tab(sz)

func _draw_rewards_track(sz: Vector2, s_lvl: int) -> void:
	# Cosmetic-only note + Activate Plus CTA
	var top_card := Rect2(18.0, 154.0, sz.x - 36.0, 82.0)
	_draw_box(top_card, Color(0.24, 0.14, 0.45), Color(0.15, 0.08, 0.30), DARK_BORDER, 14.0, 2.5)
	if CROWN_TEX != null:
		draw_texture_rect(CROWN_TEX, Rect2(top_card.position.x + 14.0, top_card.position.y + 18.0, 34.0, 28.0), false)
	_draw_text_ol(Vector2(top_card.position.x + 56.0, top_card.position.y + 34.0), tr(&"PASS_TIER_PAID"), HORIZONTAL_ALIGNMENT_LEFT, 230.0, 21, GOLD_FILL, 2.0)
	_draw_text_ol(Vector2(top_card.position.x + 16.0, top_card.position.y + 64.0), tr(&"PASS_COSMETIC_NOTE"), HORIZONTAL_ALIGNMENT_LEFT, 290.0, 13, Color(0.84, 0.80, 0.96), 1.5)

	var plus_active: bool = social != null and social.has_premium_pass
	_activate_plus_rect = Rect2(top_card.end.x - 146.0, top_card.position.y + 18.0, 132.0, 44.0)
	if plus_active:
		_draw_box(_activate_plus_rect, GREEN_FILL, GREEN_BEVEL, DARK_BORDER, 10.0, 2.0)
		_draw_text_ol(Vector2(_activate_plus_rect.position.x, _activate_plus_rect.position.y + 28.0), tr(&"PASS_ACTIVE_BADGE"), HORIZONTAL_ALIGNMENT_CENTER, 132.0, 14, Color.WHITE, 1.5)
	else:
		_draw_box(_activate_plus_rect, MAGENTA_FILL, Color(0.68, 0.08, 0.36), DARK_BORDER, 10.0, 2.0)
		_draw_text_ol(Vector2(_activate_plus_rect.position.x, _activate_plus_rect.position.y + 28.0), tr(&"PASS_ACTIVATE"), HORIZONTAL_ALIGNMENT_CENTER, 132.0, 14, Color.WHITE, 1.5)

	# Track labels
	_draw_text_ol(Vector2(20.0, 266.0), "★ " + tr(&"PASS_TIER_PAID"), HORIZONTAL_ALIGNMENT_LEFT, 260.0, 16, MAGENTA_FILL, 2.0)
	_draw_text_ol(Vector2(20.0, 568.0), "★ " + tr(&"PASS_TIER_FREE"), HORIZONTAL_ALIGNMENT_LEFT, 260.0, 16, Color(0.45, 0.85, 1.0), 2.0)

	# Timeline horizontal orange bar
	var line_y: float = 516.0
	draw_rect(Rect2(18.0, line_y - 5.0, sz.x - 36.0, 10.0), DARK_BORDER, true)
	draw_rect(Rect2(20.0, line_y - 3.0, sz.x - 40.0, 6.0), Color(0.96, 0.56, 0.12), true)

	# 3 Visible Tiers per page
	var tiers: Array[Dictionary] = SocialManager.SEASON_TIERS
	var loc: String = TranslationServer.get_locale()
	var is_en: bool = loc.begins_with("en")
	var col_w: float = (sz.x - 48.0) / 3.0

	for slot: int in range(3):
		var idx: int = tier_scroll_idx + slot
		if idx < 0 or idx >= tiers.size():
			continue
		var td: Dictionary = tiers[idx]
		var t_num: int = int(td["tier"])
		var x0: float = 18.0 + float(slot) * (col_w + 6.0)
		var unlocked: bool = t_num <= s_lvl

		# TOP CARD: PAID (SPLICE PLUS)
		var paid_r := Rect2(x0, 278.0, col_w, 210.0)
		var paid_claimed: bool = social != null and social.is_pass_tier_claimed(t_num, true)
		var paid_can: bool = social != null and social.can_claim_pass_tier(t_num, true)
		_draw_reward_card(paid_r, str(td["paid_en" if is_en else "paid_it"]), Color(str(td["paid_col"])), true, plus_active and unlocked, paid_claimed, paid_can, t_num)

		# MIDDLE LEVEL NODE
		var node_c := Vector2(x0 + col_w * 0.5, line_y)
		draw_circle(node_c, 22.0, DARK_BORDER)
		draw_circle(node_c, 19.0, GOLD_FILL if unlocked else SLATE_BG)
		_draw_text_ol(Vector2(node_c.x - 20.0, node_c.y + 7.0), str(t_num), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 18, Color.WHITE, 2.0)

		# BOTTOM CARD: FREE-TO-PLAY
		var free_r := Rect2(x0, 580.0, col_w, 210.0)
		var free_claimed: bool = social != null and social.is_pass_tier_claimed(t_num, false)
		var free_can: bool = social != null and social.can_claim_pass_tier(t_num, false)
		_draw_reward_card(free_r, str(td["free_en" if is_en else "free_it"]), Color(str(td["free_col"])), false, unlocked, free_claimed, free_can, t_num)

	# Scroll Left / Right Controls at bottom
	var nav_y: float = sz.y - 84.0
	_scroll_left_rect = Rect2(18.0, nav_y, 110.0, 54.0)
	_scroll_right_rect = Rect2(sz.x - 128.0, nav_y, 110.0, 54.0)
	_draw_box(_scroll_left_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 12.0, 2.5)
	_draw_text_ol(Vector2(_scroll_left_rect.position.x, _scroll_left_rect.position.y + 37.0), "◀", HORIZONTAL_ALIGNMENT_CENTER, 110.0, 24, Color.WHITE if tier_scroll_idx > 0 else Color(0.45, 0.48, 0.58), 2.0)
	_draw_box(_scroll_right_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 12.0, 2.5)
	var can_r: bool = tier_scroll_idx < maxi(0, tiers.size() - 3)
	_draw_text_ol(Vector2(_scroll_right_rect.position.x, _scroll_right_rect.position.y + 37.0), "▶", HORIZONTAL_ALIGNMENT_CENTER, 110.0, 24, Color.WHITE if can_r else Color(0.45, 0.48, 0.58), 2.0)
	_draw_text_ol(Vector2(140.0, nav_y + 35.0), "%d – %d / %d" % [int(tiers[tier_scroll_idx]["tier"]), int(tiers[mini(tier_scroll_idx + 2, tiers.size() - 1)]["tier"]), int(tiers.back()["tier"])], HORIZONTAL_ALIGNMENT_CENTER, sz.x - 280.0, 18, Color(0.84, 0.86, 0.94), 2.0)

func _draw_reward_card(rect: Rect2, label: String, accent: Color, is_paid: bool, unlocked: bool, claimed: bool, can_claim: bool, tier_num: int) -> void:
	var bg_col: Color = Color(0.28, 0.18, 0.52) if is_paid else SLATE_BG
	var border_col: Color = GOLD_FILL if can_claim else DARK_BORDER
	_draw_box(rect, bg_col, SLATE_BEVEL, border_col, 13.0, 2.5)

	# Reward visual emblem
	var c := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 68.0)
	draw_circle(c, 34.0, DARK_BORDER)
	draw_circle(c, 30.0, accent)
	if CHEST_TEX != null and label.to_lower().contains("cass") or label.to_lower().contains("chest"):
		draw_texture_rect(CHEST_TEX, Rect2(c.x - 32.0, c.y - 30.0, 64.0, 62.0), false)
	elif is_paid and not unlocked:
		_draw_text_ol(Vector2(c.x - 20.0, c.y + 10.0), "🔒", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, Color.WHITE, 0.0)
	else:
		draw_circle(c, 16.0, Color(1.0, 1.0, 1.0, 0.25))

	_draw_text_ol(Vector2(rect.position.x + 6.0, rect.position.y + 132.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, 15, Color.WHITE, 1.5)

	var btn_r := Rect2(rect.position.x + 10.0, rect.end.y - 46.0, rect.size.x - 20.0, 36.0)
	if claimed:
		_draw_box(btn_r, Color(0.16, 0.20, 0.30), SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 24.0), tr(&"PASS_CLAIMED"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 13, GREEN_FILL, 1.5)
	elif can_claim:
		_draw_box(btn_r, GREEN_FILL, GREEN_BEVEL, DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 24.0), tr(&"PASS_CLAIM"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 14, Color.WHITE, 1.5)
		_action_rects.append({ "rect": btn_r, "kind": "claim_tier", "tier": tier_num, "paid": is_paid })
	else:
		_draw_box(btn_r, Color(0.14, 0.16, 0.24), SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 24.0), tr(&"PASS_LOCKED"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 12, Color(0.62, 0.65, 0.78), 1.5)

func _draw_missions_tab(sz: Vector2) -> void:
	_draw_text_ol(Vector2(20.0, 174.0), tr(&"MISSIONS_DAILY_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, 360.0, 20, Color.WHITE, 2.0)
	if social == null:
		return
	var loc: String = TranslationServer.get_locale()
	var is_en: bool = loc.begins_with("en")

	for idx: int in range(social.tasks.size()):
		var t: Dictionary = social.tasks[idx]
		var card := Rect2(18.0, 190.0 + float(idx) * 140.0, sz.x - 36.0, 124.0)
		_draw_box(card, BLUE_MISSION, BLUE_BEVEL, DARK_BORDER, 14.0, 2.5)

		var t_title: String = str(t.get("title_en" if is_en else "title_it", ""))
		var prog: int = int(t.get("progress", 0))
		var tgt: int = int(t.get("target", 1))
		var claimed: bool = bool(t.get("claimed", false))
		var xp: int = int(t.get("xp", 100))

		_draw_text_ol(Vector2(card.position.x + 18.0, card.position.y + 38.0), t_title, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 160.0, 22, Color.WHITE, 2.0)

		# Progress bar
		var pb := Rect2(card.position.x + 18.0, card.position.y + 62.0, card.size.x - 190.0, 28.0)
		var track_sb := StyleBoxFlat.new()
		track_sb.bg_color = DARK_BORDER
		track_sb.set_corner_radius_all(9)
		draw_style_box(track_sb, pb)
		var fill_w: float = (pb.size.x - 4.0) * clampf(float(prog) / float(maxi(1, tgt)), 0.0, 1.0)
		if fill_w > 4.0:
			var fill_sb := StyleBoxFlat.new()
			fill_sb.bg_color = GOLD_FILL if prog >= tgt else Color(0.45, 0.88, 1.0)
			fill_sb.set_corner_radius_all(7)
			draw_style_box(fill_sb, Rect2(pb.position.x + 2.0, pb.position.y + 2.0, fill_w, pb.size.y - 4.0))
		_draw_text_ol(Vector2(pb.position.x, pb.position.y + 21.0), "%d/%d" % [prog, tgt], HORIZONTAL_ALIGNMENT_CENTER, pb.size.x, 16, Color.WHITE, 2.0)

		# Claim / Reroll button on right
		var btn_r := Rect2(card.end.x - 154.0, card.position.y + 36.0, 138.0, 50.0)
		if claimed:
			_draw_box(btn_r, Color(0.16, 0.20, 0.30), SLATE_BEVEL, DARK_BORDER, 10.0, 2.0)
			_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 32.0), tr(&"TASKS_CLAIMED"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 14, GREEN_FILL, 1.5)
		elif prog >= tgt:
			_draw_box(btn_r, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 10.0, 2.0)
			_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 32.0), tr(&"TASKS_CLAIM") % xp, HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 14, Color.WHITE, 1.5)
			_action_rects.append({ "rect": btn_r, "kind": "claim_task", "id": str(t.get("id", "")) })
		else:
			_draw_box(btn_r, Color(0.14, 0.18, 0.30), SLATE_BEVEL, DARK_BORDER, 10.0, 2.0)
			_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 24.0), "+%d XP" % xp, HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 16, GOLD_FILL, 1.5)
			_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 42.0), tr(&"MISSIONS_REROLL"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 12, Color(0.80, 0.84, 0.94), 1.0)
			_action_rects.append({ "rect": btn_r, "kind": "reroll_task", "id": str(t.get("id", "")) })

func _draw_xp_bar(pb_rect: Rect2, lvl: int, xp: int, xp_max: int) -> void:
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(0.10, 0.12, 0.20, 1.0)
	track_sb.set_corner_radius_all(10)
	track_sb.set_border_width_all(2)
	track_sb.border_color = DARK_BORDER
	draw_style_box(track_sb, pb_rect)
	var ratio: float = clampf(float(xp) / float(maxi(1, xp_max)), 0.0, 1.0)
	var fill_w: float = maxf(0.0, (pb_rect.size.x - 4.0) * ratio)
	if fill_w > 6.0:
		draw_polygon(
			PackedVector2Array([
				Vector2(pb_rect.position.x + 2.0, pb_rect.position.y + 2.0),
				Vector2(pb_rect.position.x + 2.0 + fill_w, pb_rect.position.y + 2.0),
				Vector2(pb_rect.position.x + 2.0 + fill_w, pb_rect.end.y - 2.0),
				Vector2(pb_rect.position.x + 2.0, pb_rect.end.y - 2.0),
			]),
			PackedColorArray([MAGENTA_FILL, GOLD_FILL, GOLD_FILL, MAGENTA_FILL])
		)
	var lvl_c := Vector2(pb_rect.position.x + 11.0, pb_rect.position.y + pb_rect.size.y * 0.5)
	draw_circle(lvl_c, 14.0, Color.WHITE)
	draw_circle(lvl_c, 12.0, DARK_BORDER)
	_draw_text_ol(Vector2(lvl_c.x - 12.0, lvl_c.y + 5.0), str(lvl), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 14, Color.WHITE, 0.0)
	_draw_text_ol(Vector2(pb_rect.position.x + 24.0, pb_rect.position.y + 17.0), "XP %d/%d" % [xp, xp_max], HORIZONTAL_ALIGNMENT_CENTER, pb_rect.size.x - 28.0, 14, Color.WHITE, 1.5)

func _draw_box(rect: Rect2, fill: Color, bevel: Color, border: Color, radius: float, bw: float) -> void:
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = bevel
	b_sb.set_corner_radius_all(int(radius))
	b_sb.set_border_width_all(int(ceilf(bw)))
	b_sb.border_color = border
	draw_style_box(b_sb, Rect2(rect.position.x, rect.position.y + 3.0, rect.size.x, rect.size.y))
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = fill
	t_sb.set_corner_radius_all(int(radius))
	t_sb.set_border_width_all(int(ceilf(bw)))
	t_sb.border_color = border
	draw_style_box(t_sb, rect)

func _draw_text_ol(pos: Vector2, text: String, align: HorizontalAlignment, w: float, fsize: int, col: Color, ol: float) -> void:
	if ol > 0.0:
		for off: Vector2 in [Vector2(-ol, 0), Vector2(ol, 0), Vector2(0, -ol), Vector2(0, ol)]:
			draw_string(FONT_BOLD, pos + off, text, align, w, fsize, DARK_BORDER)
	draw_string(FONT_BOLD, pos, text, align, w, fsize, col)
