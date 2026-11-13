class_name SeasonPassModal
extends TouchScreenBase
## Season Pass as one tall vertical track: scroll up to see what you already took, down to see
## what is coming. Free rewards on the left, Splice Plus on the right, your level on the rail
## in the middle. A jump button takes you to the first reward you can claim.
##
## Rewards are coins, skins and colours only (see EconomyCatalog): nothing here adds power.

signal open_shop_requested()

const TAB_REWARDS: int = 0
const TAB_MISSIONS: int = 1

const HEADER_H: float = 196.0
const COLUMN_BAR_H: float = 44.0
const FOOTER_H: float = 92.0
const ROW_H: float = 150.0
const CARD_W: float = 196.0
const CARD_H: float = 134.0
const SIDE: float = 20.0
const NODE_R: float = 24.0
const XP_ANIM_SPEED: float = 0.9 # pass levels per second while match XP pours in
const CLAIM_FX_SEC: float = 0.55
const COIN_FLY_SEC: float = 0.6
const LEVEL_UP_SEC: float = 1.4

var social: SocialManager = null
var previews: SkinPreviewRenderer = null
var sound: SoundController = null
var current_tab: int = TAB_REWARDS

var _back_rect := Rect2()
var _pill_rect := Rect2()
var _tab_rects: Array[Rect2] = []
var _plus_chip_rect := Rect2()
var _jump_rect := Rect2()
var _claim_all_rect := Rect2()
var _hits: Array[Dictionary] = []
var _shown_progress: float = 0.0 # level + xp fraction currently drawn (eases to the real one)
var _xp_gain_label: int = 0
var _xp_gain_timer: float = 0.0
var _level_up_level: int = 0
var _level_up_timer: float = 0.0
var _claim_fx: Dictionary = {} # "tier:paid" -> seconds left
var _coin_shown: float = 0.0
var _pill_punch: float = 0.0
var _flying: Array[Dictionary] = []
var _popup := RewardPopup.new()
var _popup_queue: Array[Dictionary] = []
var _toast: String = ""
var _toast_timer: float = 0.0

func open(initial_tab: int = TAB_REWARDS) -> void:
	current_tab = initial_tab
	_popup.hide()
	_popup_queue.clear()
	_flying.clear()
	_claim_fx.clear()
	_level_up_timer = 0.0
	_xp_gain_timer = 0.0
	show_screen()
	_layout()
	if social == null:
		return
	_coin_shown = float(social.coins)
	_shown_progress = _real_progress()
	# XP earned in the last match pours into the bar the first time the pass is opened after it.
	var summary: Dictionary = social.last_match_summary
	if not summary.is_empty() and not bool(summary.get("shown_in_pass", true)) and int(summary.get("xp", 0)) > 0:
		_shown_progress = _progress_of(int(summary["level_before"]), int(summary["xp_before"]))
		_xp_gain_label = int(summary["xp"])
		_xp_gain_timer = 2.4
		summary["shown_in_pass"] = true
	# Start a little above the interesting row, then glide onto it.
	var focus: int = get_focus_tier()
	scroll_to(_row_y(focus) - scroll_area.size.y * 0.30 - 260.0, false)
	scroll_to(_row_y(focus) - scroll_area.size.y * 0.30, true)

## The row the pass opens on: the first reward to claim, otherwise your current level.
func get_focus_tier() -> int:
	if social == null:
		return 1
	var first: int = social.get_first_claimable_tier()
	return first if first > 0 else clampi(social.season_level, 1, EconomyCatalog.SEASON_TIER_COUNT)

func _progress_of(level: int, xp: int) -> float:
	var max_xp: float = float(maxi(1, social.season_xp_max if social != null else EconomyCatalog.SEASON_XP_PER_LEVEL))
	if level >= EconomyCatalog.SEASON_TIER_COUNT:
		return float(EconomyCatalog.SEASON_TIER_COUNT)
	return float(level) + clampf(float(xp) / max_xp, 0.0, 0.999)

func _real_progress() -> float:
	if social == null:
		return 1.0
	return _progress_of(social.season_level, social.season_xp)

func _row_y(tier: int) -> float:
	return float(tier - 1) * ROW_H

func _layout() -> void:
	var sz: Vector2 = get_screen_size()
	if current_tab == TAB_REWARDS:
		var top: float = HEADER_H + COLUMN_BAR_H
		scroll_area = Rect2(0.0, top, sz.x, sz.y - top - FOOTER_H)
		content_height = float(EconomyCatalog.SEASON_TIER_COUNT) * ROW_H + 24.0
	else:
		scroll_area = Rect2(0.0, HEADER_H, sz.x, sz.y - HEADER_H)
		content_height = 60.0 + float(social.tasks.size() if social != null else 3) * 140.0 + 30.0

func _is_scroll_locked() -> bool:
	return _popup.active

func _update_screen(delta: float) -> void:
	_layout()
	if social == null:
		return
	var real: float = _real_progress()
	if _shown_progress < real:
		var before_level: int = int(floor(_shown_progress))
		_shown_progress = minf(real, _shown_progress + XP_ANIM_SPEED * delta * maxf(1.0, (real - _shown_progress)))
		var after_level: int = int(floor(_shown_progress))
		if after_level > before_level:
			_level_up_level = after_level
			_level_up_timer = LEVEL_UP_SEC
			if sound != null:
				sound.play_steal_stinger()
	else:
		_shown_progress = real
	_coin_shown = lerpf(_coin_shown, float(social.coins), 1.0 - exp(-10.0 * delta))
	if absf(_coin_shown - float(social.coins)) < 0.6:
		_coin_shown = float(social.coins)
	_pill_punch = maxf(0.0, _pill_punch - delta)
	_xp_gain_timer = maxf(0.0, _xp_gain_timer - delta)
	_level_up_timer = maxf(0.0, _level_up_timer - delta)
	_toast_timer = maxf(0.0, _toast_timer - delta)
	for key: Variant in _claim_fx.keys():
		_claim_fx[key] = float(_claim_fx[key]) - delta
		if float(_claim_fx[key]) <= 0.0:
			_claim_fx.erase(key)
	var idx: int = _flying.size() - 1
	while idx >= 0:
		var f: Dictionary = _flying[idx]
		if float(f["delay"]) > 0.0:
			f["delay"] = float(f["delay"]) - delta
		else:
			f["t"] = float(f["t"]) + delta / COIN_FLY_SEC
			if float(f["t"]) >= 1.0:
				_flying.remove_at(idx)
				_pill_punch = 0.22
				if sound != null:
					sound.play_pickup_pop()
		idx -= 1
	_popup.update(delta)
	if not _popup.active and not _popup_queue.is_empty():
		_popup.show_reward(_popup_queue.pop_front())

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not is_open:
		return
	var sz: Vector2 = get_screen_size()
	UIKit.gradient_v(self, Rect2(Vector2.ZERO, sz), Color(0.30, 0.22, 0.72), Color(0.14, 0.12, 0.38))
	UIKit.confetti(self, Rect2(Vector2.ZERO, sz), time_sec, 10, 0.30)

func _draw_content(ci: CanvasItem) -> void:
	_hits.clear()
	if social == null:
		return
	if current_tab == TAB_REWARDS:
		_draw_track(ci)
	else:
		_draw_missions(ci)

func _draw_track(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	var oy: float = -scroll_y
	var rail_x: float = sz.x * 0.5
	var first: int = clampi(int(floor(scroll_y / ROW_H)), 1, EconomyCatalog.SEASON_TIER_COUNT)
	var last: int = clampi(int(ceil((scroll_y + scroll_area.size.y) / ROW_H)) + 1, 1, EconomyCatalog.SEASON_TIER_COUNT)

	# Rail: dark groove, then the gold fill up to the animated progress.
	var rail_top: float = _row_y(1) + ROW_H * 0.5 + oy
	var rail_bot: float = _row_y(EconomyCatalog.SEASON_TIER_COUNT) + ROW_H * 0.5 + oy
	UIKit.flat(ci, Rect2(rail_x - 9.0, rail_top, 18.0, rail_bot - rail_top), UIKit.DARK, 9.0)
	var fill_bot: float = _row_y(1) + ROW_H * 0.5 + (_shown_progress - 1.0) * ROW_H + oy
	if fill_bot > rail_top:
		UIKit.flat(ci, Rect2(rail_x - 5.0, rail_top, 10.0, fill_bot - rail_top), UIKit.GOLD, 5.0)
		# Bright head of the fill, so the XP visibly travels down the rail.
		ci.draw_circle(Vector2(rail_x, fill_bot), 8.0 + 2.0 * sin(time_sec * 8.0), Color(1.0, 0.95, 0.60))

	var shown_level: int = int(floor(_shown_progress))
	for tier: int in range(first, last + 1):
		var y: float = _row_y(tier) + oy
		var reached: bool = tier <= shown_level
		_draw_reward_card(ci, Rect2(SIDE, _row_y(tier) + 8.0, CARD_W, CARD_H), oy, tier, false)
		_draw_reward_card(ci, Rect2(sz.x - SIDE - CARD_W, _row_y(tier) + 8.0, CARD_W, CARD_H), oy, tier, true)

		# Level node on the rail.
		var node_c := Vector2(rail_x, y + ROW_H * 0.5)
		var is_current: bool = tier == social.season_level
		var node_scale: float = 1.0
		if _level_up_timer > 0.0 and tier == _level_up_level:
			node_scale = UIKit.punch(1.0 - _level_up_timer / LEVEL_UP_SEC, 0.45)
		elif is_current:
			node_scale = 1.0 + 0.05 * sin(time_sec * 4.0)
		ci.draw_circle(node_c, (NODE_R + 4.0) * node_scale, UIKit.DARK)
		ci.draw_circle(node_c, NODE_R * node_scale, UIKit.GOLD if reached else Color(0.24, 0.28, 0.44))
		UIKit.text_in(ci, Rect2(node_c.x - 30.0, node_c.y - 16.0, 60.0, 32.0), str(tier), 20, Color.WHITE if reached else Color(0.70, 0.74, 0.88), 2.0)
		if is_current:
			var here := Rect2(rail_x - 44.0, node_c.y - NODE_R - 30.0, 88.0, 22.0)
			UIKit.flat(ci, here, UIKit.MAGENTA, 11.0, UIKit.DARK, 2.0)
			UIKit.text_in(ci, here, tr(&"PASS_YOU_ARE_HERE"), 13, Color.WHITE, 1.5)

func _draw_reward_card(ci: CanvasItem, rect: Rect2, oy: float, tier: int, is_paid: bool) -> void:
	var reward: Dictionary = EconomyCatalog.get_tier_reward(tier, is_paid)
	var claimed: bool = social.is_pass_tier_claimed(tier, is_paid)
	var can_claim: bool = social.can_claim_pass_tier(tier, is_paid)
	var reached: bool = tier <= social.season_level
	var needs_plus: bool = is_paid and not social.has_premium_pass
	var fx_key: String = "%d:%d" % [tier, 1 if is_paid else 0]
	var fx: float = float(_claim_fx.get(fx_key, 0.0)) / CLAIM_FX_SEC # 1 -> 0 after a claim

	var r := Rect2(rect.position + Vector2(0.0, oy), rect.size)
	if fx > 0.0:
		r = UIKit.scaled(r, UIKit.punch(1.0 - fx, 0.14))
	elif can_claim:
		r = UIKit.scaled(r, 1.0 + 0.015 * sin(time_sec * 5.0 + float(tier)))

	var fill: Color = Color(0.36, 0.22, 0.66) if is_paid else Color(0.20, 0.30, 0.56)
	var bevel: Color = Color(0.20, 0.10, 0.40) if is_paid else Color(0.10, 0.16, 0.34)
	if claimed:
		fill = fill.darkened(0.35)
	elif not reached or needs_plus:
		fill = fill.darkened(0.20)
	UIKit.box(ci, r, fill, bevel, UIKit.GOLD if can_claim else UIKit.DARK, 16.0, 3.0, 5.0)

	# Reward art.
	var dim: Color = Color(1, 1, 1, 0.45) if claimed else (Color(0.78, 0.80, 0.90) if (not reached or needs_plus) else Color.WHITE)
	var art_c := Vector2(r.position.x + 52.0, r.position.y + 54.0)
	var label: String = ""
	var sub: String = ""
	match str(reward.get("type", "coins")):
		"skin":
			var skin: Dictionary = EconomyCatalog.get_skin(str(reward["id"]))
			var rar_col: Color = EconomyCatalog.get_rarity_color(int(skin["rarity"]))
			UIKit.flat(ci, Rect2(r.position.x + 10.0, r.position.y + 10.0, 84.0, 90.0), Color(rar_col.r, rar_col.g, rar_col.b, 0.35 * dim.a), 12.0, UIKit.DARK, 2.0)
			UIKit.skin_preview(ci, Rect2(r.position.x + 12.0, r.position.y + 10.0, 80.0, 88.0), previews.get_texture(str(skin["id"])) if previews != null else null, rar_col, dim)
			label = tr(StringName(str(skin["name_key"])))
			sub = tr(&"PASS_REWARD_SKIN")
		"color":
			var col := Color(str(reward["id"]))
			ci.draw_circle(art_c, 34.0, UIKit.DARK)
			ci.draw_circle(art_c, 30.0, Color(col.r, col.g, col.b, dim.a))
			ci.draw_circle(art_c + Vector2(-10.0, -11.0), 8.0, Color(1, 1, 1, 0.35 * dim.a))
			label = tr(&"PASS_REWARD_COLOR")
			sub = "#" + col.to_html(false).to_upper()
		_:
			var amount: int = int(reward.get("amount", 0))
			UIKit.coin_pile(ci, art_c + Vector2(0.0, -4.0), 0.82, 3 if amount < 60 else (5 if amount < 150 else 6))
			if claimed:
				ci.draw_circle(art_c, 40.0, Color(fill.r, fill.g, fill.b, 0.55))
			label = tr(&"SHOP_COINS_X") % amount
			sub = tr(&"PASS_REWARD_COINS")
	var txt_col: Color = Color(1, 1, 1, 0.55) if claimed else Color.WHITE
	UIKit.text(ci, Vector2(r.position.x + 100.0, r.position.y + 46.0), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 106.0, 19, txt_col, 2.0)
	UIKit.text(ci, Vector2(r.position.x + 100.0, r.position.y + 68.0), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 106.0, 13, Color(0.82, 0.86, 1.0, txt_col.a), 1.5)

	# State strip at the bottom of the card.
	var btn := Rect2(r.position.x + 10.0, r.end.y - 36.0, r.size.x - 20.0, 28.0)
	if claimed:
		var stamp: float = UIKit.ease_out_back(1.0 - fx) if fx > 0.0 else 1.0
		UIKit.check(ci, Vector2(r.end.x - 26.0, r.position.y + 24.0), 22.0 * stamp, UIKit.GREEN)
		UIKit.text_in(ci, btn, tr(&"PASS_CLAIMED"), 14, UIKit.GREEN, 1.5)
	elif can_claim:
		UIKit.box(ci, btn, UIKit.GREEN, UIKit.GREEN_BEVEL, UIKit.DARK, 8.0, 2.0, 3.0)
		UIKit.text_in(ci, btn, tr(&"PASS_CLAIM"), 16, Color.WHITE, 2.0)
		_hits.append({ "rect": content_to_screen(rect), "kind": "claim", "tier": tier, "paid": is_paid })
	elif needs_plus:
		UIKit.padlock(ci, Vector2(btn.position.x + 16.0, btn.get_center().y), 20.0, Color(1.0, 0.80, 0.95))
		UIKit.text_in(ci, Rect2(btn.position.x + 22.0, btn.position.y, btn.size.x - 22.0, btn.size.y), tr(&"PASS_NEED_PLUS"), 14, Color(1.0, 0.80, 0.95), 1.5)
		_hits.append({ "rect": content_to_screen(rect), "kind": "need_plus", "tier": tier, "paid": is_paid })
	else:
		UIKit.padlock(ci, Vector2(btn.position.x + 16.0, btn.get_center().y), 20.0, Color(0.72, 0.76, 0.92))
		UIKit.text_in(ci, Rect2(btn.position.x + 22.0, btn.position.y, btn.size.x - 22.0, btn.size.y), tr(&"PASS_LEVEL") % tier, 14, Color(0.72, 0.76, 0.92), 1.5)

	# White flash on the frame right after a claim.
	if fx > 0.0:
		UIKit.flat(ci, r, Color(1, 1, 1, 0.75 * fx * fx), 16.0)

func _draw_missions(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	var oy: float = -scroll_y
	UIKit.text(ci, Vector2(SIDE, 34.0 + oy), tr(&"MISSIONS_DAILY_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 40.0, 22, Color.WHITE, 2.5)
	var is_en: bool = TranslationServer.get_locale().begins_with("en")
	for idx: int in range(social.tasks.size()):
		var t: Dictionary = social.tasks[idx]
		var base := Rect2(SIDE, 52.0 + float(idx) * 140.0, sz.x - SIDE * 2.0, 124.0)
		var card := Rect2(base.position + Vector2(0.0, oy), base.size)
		UIKit.box(ci, card, Color(0.11, 0.47, 0.85), Color(0.07, 0.31, 0.58), UIKit.DARK, 16.0, 3.0, 5.0)
		var prog: int = int(t.get("progress", 0))
		var tgt: int = int(t.get("target", 1))
		var claimed: bool = bool(t.get("claimed", false))
		var xp: int = int(t.get("xp", 100))
		UIKit.text(ci, Vector2(card.position.x + 18.0, card.position.y + 40.0), str(t.get("title_en" if is_en else "title_it", "")), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 176.0, 22, Color.WHITE, 2.5)
		var pb := Rect2(card.position.x + 18.0, card.position.y + 64.0, card.size.x - 190.0, 30.0)
		UIKit.progress_bar(ci, pb, float(prog) / float(maxi(1, tgt)), Color(0.45, 0.88, 1.0), UIKit.GOLD if prog >= tgt else Color(0.45, 0.88, 1.0))
		UIKit.text_in(ci, pb, "%d/%d" % [prog, tgt], 16, Color.WHITE, 2.0)
		var btn_base := Rect2(base.end.x - 154.0, base.position.y + 36.0, 138.0, 52.0)
		var btn := Rect2(btn_base.position + Vector2(0.0, oy), btn_base.size)
		if claimed:
			UIKit.flat(ci, btn, Color(0.10, 0.20, 0.40), 12.0, UIKit.DARK, 2.0)
			UIKit.text_in(ci, btn, tr(&"TASKS_CLAIMED"), 14, UIKit.GREEN, 1.5)
		elif prog >= tgt:
			UIKit.box(ci, UIKit.scaled(btn, 1.0 + 0.03 * sin(time_sec * 5.0)), UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 12.0, 2.5)
			UIKit.text_in(ci, btn, tr(&"TASKS_CLAIM") % xp, 14, Color.WHITE, 2.0)
			_hits.append({ "rect": content_to_screen(btn_base), "kind": "claim_task", "id": str(t.get("id", "")) })
		else:
			UIKit.box(ci, btn, Color(0.14, 0.18, 0.30), UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
			UIKit.text_in(ci, Rect2(btn.position.x, btn.position.y + 2.0, btn.size.x, 28.0), "+%d XP" % xp, 16, UIKit.GOLD, 1.5)
			UIKit.text_in(ci, Rect2(btn.position.x, btn.position.y + 26.0, btn.size.x, 22.0), tr(&"MISSIONS_REROLL"), 12, Color(0.80, 0.84, 0.94), 1.0)
			_hits.append({ "rect": content_to_screen(btn_base), "kind": "reroll_task", "id": str(t.get("id", "")) })

func _draw_overlay(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	# --- Header ---
	ci.draw_rect(Rect2(0.0, 0.0, sz.x, HEADER_H), Color(0.10, 0.09, 0.26, 0.98), true)
	_back_rect = Rect2(SIDE, 22.0, 60.0, 58.0)
	UIKit.back_button(ci, _back_rect)
	var s_num: int = social.season_number if social != null else 1
	UIKit.text(ci, Vector2(94.0, 48.0), tr(&"PASS_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, 260.0, 28, UIKit.GOLD, 3.0)
	UIKit.text(ci, Vector2(94.0, 72.0), tr(&"HOME_SEASON") % s_num, HORIZONTAL_ALIGNMENT_LEFT, 200.0, 16, Color(0.84, 0.86, 1.0), 2.0)
	_pill_rect = Rect2(sz.x - SIDE - 128.0, 28.0, 128.0, 46.0)
	UIKit.coin_pill(ci, UIKit.scaled(_pill_rect, UIKit.punch(1.0 - _pill_punch / 0.22, 0.16) if _pill_punch > 0.0 else 1.0), str(int(round(_coin_shown))), 20)

	# XP bar: current level on the left, next level on the right.
	var level_now: int = clampi(int(floor(_shown_progress)), 1, EconomyCatalog.SEASON_TIER_COUNT)
	var maxed: bool = level_now >= EconomyCatalog.SEASON_TIER_COUNT
	var frac: float = 1.0 if maxed else (_shown_progress - float(level_now))
	var xp_max: int = social.season_xp_max if social != null else EconomyCatalog.SEASON_XP_PER_LEVEL
	var bar := Rect2(SIDE + 26.0, 96.0, sz.x - SIDE * 2.0 - 52.0, 30.0)
	UIKit.progress_bar(ci, bar, frac)
	UIKit.text_in(ci, bar, tr(&"PASS_MAX") if maxed else "%d / %d XP" % [int(round(frac * float(xp_max))), xp_max], 16, Color.WHITE, 2.0)
	var badge_scale: float = UIKit.punch(1.0 - _level_up_timer / LEVEL_UP_SEC, 0.4) if _level_up_timer > 0.0 else 1.0
	for side_i: int in range(2):
		var bc := Vector2(bar.position.x - 4.0 if side_i == 0 else bar.end.x + 4.0, bar.get_center().y)
		var lvl: int = level_now if side_i == 0 else mini(level_now + 1, EconomyCatalog.SEASON_TIER_COUNT)
		var bs: float = badge_scale if side_i == 0 else 1.0
		ci.draw_circle(bc, 23.0 * bs, UIKit.DARK)
		ci.draw_circle(bc, 20.0 * bs, UIKit.GOLD if side_i == 0 else Color(0.26, 0.30, 0.48))
		UIKit.text_in(ci, Rect2(bc.x - 24.0, bc.y - 15.0, 48.0, 30.0), str(lvl), 19, Color.WHITE, 2.0)
	if _xp_gain_timer > 0.0:
		var rise: float = (2.4 - _xp_gain_timer) * 10.0
		UIKit.text(ci, Vector2(bar.position.x, bar.position.y - 4.0 - rise), tr(&"PASS_XP_GAINED") % _xp_gain_label, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 20, Color(0.55, 1.0, 0.70, clampf(_xp_gain_timer, 0.0, 1.0)), 2.5)

	# Tabs.
	var labels: Array[String] = [tr(&"PASS_TAB_REWARDS"), tr(&"PASS_TAB_MISSIONS")]
	_tab_rects.clear()
	var tw: float = (sz.x - SIDE * 2.0 - 10.0) * 0.5
	for i: int in range(2):
		var tab := Rect2(SIDE + float(i) * (tw + 10.0), 140.0, tw, 42.0)
		_tab_rects.append(tab)
		var sel: bool = i == current_tab
		UIKit.box(ci, tab, UIKit.GOLD if sel else UIKit.SLATE, UIKit.GOLD_BEVEL if sel else UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, tab, labels[i], 18, Color.WHITE, 2.0)

	_plus_chip_rect = Rect2()
	_jump_rect = Rect2()
	_claim_all_rect = Rect2()
	if current_tab == TAB_REWARDS and social != null:
		# Column titles.
		ci.draw_rect(Rect2(0.0, HEADER_H, sz.x, COLUMN_BAR_H), Color(0.14, 0.12, 0.34, 0.98), true)
		UIKit.text_in(ci, Rect2(SIDE, HEADER_H, CARD_W, COLUMN_BAR_H), tr(&"PASS_TIER_FREE"), 18, Color(0.55, 0.88, 1.0), 2.0)
		var plus_col := Rect2(sz.x - SIDE - CARD_W, HEADER_H + 5.0, CARD_W, COLUMN_BAR_H - 10.0)
		if social.has_premium_pass:
			ci.draw_texture_rect(UIKit.CROWN_TEX, Rect2(plus_col.position.x + 10.0, plus_col.position.y + 6.0, 26.0, 22.0), false)
			UIKit.text_in(ci, Rect2(plus_col.position.x + 30.0, plus_col.position.y, plus_col.size.x - 30.0, plus_col.size.y), tr(&"PASS_TIER_PAID"), 18, UIKit.GOLD, 2.0)
		else:
			_plus_chip_rect = plus_col
			UIKit.gradient_box(ci, UIKit.scaled(plus_col, 1.0 + 0.02 * sin(time_sec * 4.0)), Color(1.0, 0.16, 0.62), Color(0.48, 0.20, 0.82), 10.0, UIKit.DARK, 2.0)
			ci.draw_texture_rect(UIKit.CROWN_TEX, Rect2(plus_col.position.x + 10.0, plus_col.position.y + 6.0, 26.0, 22.0), false)
			UIKit.text_in(ci, Rect2(plus_col.position.x + 34.0, plus_col.position.y, plus_col.size.x - 38.0, plus_col.size.y), tr(&"PASS_ACTIVATE"), 16, Color.WHITE, 2.0)
		ci.draw_line(Vector2(0.0, HEADER_H + COLUMN_BAR_H), Vector2(sz.x, HEADER_H + COLUMN_BAR_H), UIKit.DARK, 3.0)

		# Footer: jump to the first claimable reward, and claim everything in one go.
		var foot_y: float = sz.y - FOOTER_H
		ci.draw_rect(Rect2(0.0, foot_y, sz.x, FOOTER_H), Color(0.10, 0.09, 0.26, 0.98), true)
		ci.draw_line(Vector2(0.0, foot_y), Vector2(sz.x, foot_y), UIKit.DARK, 3.0)
		var claimable: int = social.get_claimable_pass_count()
		if claimable > 0:
			var half: float = (sz.x - SIDE * 2.0 - 12.0) * 0.5
			_jump_rect = Rect2(SIDE, foot_y + 16.0, half, 56.0)
			_claim_all_rect = Rect2(_jump_rect.end.x + 12.0, foot_y + 16.0, half, 56.0)
			UIKit.box(ci, _jump_rect, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 14.0, 2.5)
			UIKit.text_in(ci, _jump_rect, tr(&"PASS_GO_CLAIMABLE"), 16, Color.WHITE, 2.0)
			UIKit.box(ci, UIKit.scaled(_claim_all_rect, 1.0 + 0.02 * sin(time_sec * 5.0)), UIKit.GREEN, UIKit.GREEN_BEVEL, UIKit.DARK, 14.0, 2.5)
			UIKit.text_in(ci, _claim_all_rect, tr(&"PASS_CLAIM_ALL") % claimable, 16, Color.WHITE, 2.0)
		else:
			_jump_rect = Rect2(SIDE, foot_y + 16.0, sz.x - SIDE * 2.0, 56.0)
			UIKit.box(ci, _jump_rect, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 14.0, 2.5)
			UIKit.text_in(ci, _jump_rect, tr(&"PASS_GO_LEVEL"), 18, Color.WHITE, 2.0)

	# Level-up banner.
	if _level_up_timer > 0.0:
		var k: float = 1.0 - _level_up_timer / LEVEL_UP_SEC
		var pop: float = UIKit.ease_out_back(clampf(k / 0.25, 0.0, 1.0))
		var alpha: float = clampf(_level_up_timer / 0.35, 0.0, 1.0)
		var banner := UIKit.scaled(Rect2(sz.x * 0.5 - 170.0, sz.y * 0.40, 340.0, 76.0), pop)
		UIKit.gradient_box(ci, banner, Color(1.0, 0.16, 0.62, alpha), Color(1.0, 0.72, 0.10, alpha), 18.0, Color(UIKit.DARK.r, UIKit.DARK.g, UIKit.DARK.b, alpha), 3.0)
		UIKit.text_in(ci, banner, tr(&"PASS_LEVEL_UP") % _level_up_level, int(34.0 * pop), Color(1, 1, 1, alpha), 3.0)

	for f: Dictionary in _flying:
		if float(f["delay"]) > 0.0:
			continue
		var t: float = UIKit.ease_out_cubic(float(f["t"]))
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var mid: Vector2 = from.lerp(to, 0.5) + Vector2(-70.0, -50.0)
		UIKit.coin(ci, from.lerp(mid, t).lerp(mid.lerp(to, t), t), lerpf(34.0, 20.0, t))

	if _toast_timer > 0.0:
		var tw2: float = minf(sz.x - 60.0, UIKit.text_width(_toast, 18) + 44.0)
		var toast_r := Rect2((sz.x - tw2) * 0.5, sz.y - FOOTER_H - 62.0, tw2, 44.0)
		UIKit.box(ci, toast_r, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, toast_r, _toast, 18, Color.WHITE, 2.0)

	_popup.draw(ci, sz, previews, true)

# ---------------------------------------------------------------------------
# Input and actions
# ---------------------------------------------------------------------------

func _on_tap(pos: Vector2) -> void:
	if social == null:
		return
	if _popup.active:
		if _popup.handle_tap(pos) == "equip":
			social.equip_skin(str(_popup.reward.get("id", "")))
			if sound != null:
				sound.play_equip_sfx()
		return
	if _back_rect.has_point(pos):
		close()
		return
	for i: int in range(_tab_rects.size()):
		if _tab_rects[i].has_point(pos):
			current_tab = i
			scroll_to(0.0, false)
			_layout()
			if i == TAB_REWARDS:
				scroll_to(_row_y(get_focus_tier()) - scroll_area.size.y * 0.30, false)
			return
	if _plus_chip_rect.has_area() and _plus_chip_rect.has_point(pos):
		open_shop_requested.emit()
		return
	if _jump_rect.has_area() and _jump_rect.has_point(pos):
		jump_to_focus()
		return
	if _claim_all_rect.has_area() and _claim_all_rect.has_point(pos):
		claim_all(_claim_all_rect.get_center())
		return
	for hit: Dictionary in _hits:
		if is_hit_in_scroll(hit["rect"] as Rect2, pos):
			match str(hit["kind"]):
				"claim":
					claim_tier(int(hit["tier"]), bool(hit["paid"]), (hit["rect"] as Rect2).get_center())
				"need_plus":
					_toast = tr(&"PASS_NEED_PLUS_TOAST")
					_toast_timer = 2.0
				"claim_task":
					var gained: int = social.claim_task(str(hit["id"]))
					if gained > 0:
						_xp_gain_label = gained
						_xp_gain_timer = 2.4
				"reroll_task":
					social.reroll_task(str(hit["id"]))
			return

## Glides to the first claimable reward, or to the current level when nothing is waiting.
func jump_to_focus() -> void:
	scroll_to(_row_y(get_focus_tier()) - scroll_area.size.y * 0.30, true)

## Claims one reward with its little celebration. Returns what was granted.
func claim_tier(tier: int, is_paid: bool, origin: Vector2) -> Dictionary:
	var granted: Dictionary = social.claim_pass_tier_reward(tier, is_paid)
	if granted.is_empty():
		return granted
	_claim_fx["%d:%d" % [tier, 1 if is_paid else 0]] = CLAIM_FX_SEC
	_celebrate(granted, origin)
	return granted

func claim_all(origin: Vector2) -> Array[Dictionary]:
	var grants: Array[Dictionary] = social.claim_all_pass_tiers()
	var coin_total: int = 0
	for g: Dictionary in grants:
		_claim_fx["%d:%d" % [int(g["tier"]), 1 if bool(g["paid"]) else 0]] = CLAIM_FX_SEC
		if str(g.get("type", "")) == "coins":
			coin_total += int(g.get("amount", 0))
		else:
			_popup_queue.append(g)
			coin_total += int(g.get("compensation", 0))
	if coin_total > 0:
		_fly_coins(origin, clampi(coin_total / 20, 6, 16))
	if sound != null and not grants.is_empty():
		sound.play_equip_sfx()
	return grants

func _celebrate(granted: Dictionary, origin: Vector2) -> void:
	if sound != null:
		sound.play_equip_sfx()
	if str(granted.get("type", "")) == "coins":
		_fly_coins(origin, clampi(int(granted.get("amount", 0)) / 10, 4, 10))
	else:
		_popup_queue.append(granted)

func _fly_coins(from: Vector2, count: int) -> void:
	for i: int in range(count):
		_flying.append({
			"from": from + Vector2(randf_range(-30.0, 30.0), randf_range(-22.0, 22.0)),
			"to": Vector2(_pill_rect.position.x + 22.0, _pill_rect.get_center().y),
			"t": 0.0,
			"delay": float(i) * 0.04,
		})
