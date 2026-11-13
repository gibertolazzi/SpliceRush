class_name ShopScreen
extends TouchScreenBase
## Full-screen shop: Splice Plus banner, today's offers, free daily gifts and the wardrobe.
## Coins buy skins; real-money products go through SocialManager's purchase gateway.
## Cosmetics only: nothing sold here changes how a match plays.

signal open_pass_requested()

const HEADER_H: float = 124.0
const MARGIN: float = 36.0
const BANNER_Y: float = 64.0
const BANNER_H: float = 176.0
const DAILY_TITLE_Y: float = 322.0
const DAILY_CARDS_Y: float = 346.0
const DAILY_CARD_H: float = 185.0
const FREE_TITLE_Y: float = 598.0
const FREE_CARDS_Y: float = 637.0
const FREE_CARD_H: float = 184.0
const WARDROBE_TITLE_Y: float = 890.0
const WARDROBE_Y: float = 914.0
const SKIN_CARD_H: float = 214.0
const SKIN_GAP: float = 12.0
const COIN_FLY_SEC: float = 0.55

var social: SocialManager = null
var previews: SkinPreviewRenderer = null
var sound: SoundController = null

var _back_rect := Rect2()
var _pill_rect := Rect2()
var _hits: Array[Dictionary] = [] # { "rect": Rect2 (screen), "kind": String, "id": String }
var _coin_shown: float = 0.0
var _pill_punch: float = 0.0
var _pill_shake: float = 0.0
var _card_punch: Dictionary = {} # hit id -> seconds left
var _flying: Array[Dictionary] = [] # { "from", "to", "t", "delay" }
var _toast: String = ""
var _toast_timer: float = 0.0
var _confirm: Dictionary = {} # pending purchase waiting for a yes
var _confirm_yes := Rect2()
var _confirm_no := Rect2()
var _popup := RewardPopup.new()

func open() -> void:
	if social != null:
		social.refresh_shop_day()
		_coin_shown = float(social.coins)
	_confirm.clear()
	_popup.hide()
	_flying.clear()
	scroll_y = 0.0
	show_screen()
	_update_screen(0.0) # Lay out now so scroll_to() works right after opening.

func _is_scroll_locked() -> bool:
	return not _confirm.is_empty() or _popup.active

func _update_screen(delta: float) -> void:
	var sz: Vector2 = get_screen_size()
	scroll_area = Rect2(0.0, HEADER_H, sz.x, sz.y - HEADER_H)
	var rows: int = int(ceil(float(EconomyCatalog.SKINS.size()) / 3.0))
	content_height = WARDROBE_Y + float(rows) * (SKIN_CARD_H + SKIN_GAP) + 70.0
	if social != null:
		_coin_shown = lerpf(_coin_shown, float(social.coins), 1.0 - exp(-10.0 * delta))
		if absf(_coin_shown - float(social.coins)) < 0.6:
			_coin_shown = float(social.coins)
	_pill_punch = maxf(0.0, _pill_punch - delta)
	_pill_shake = maxf(0.0, _pill_shake - delta)
	_toast_timer = maxf(0.0, _toast_timer - delta)
	for key: Variant in _card_punch.keys():
		_card_punch[key] = float(_card_punch[key]) - delta
		if float(_card_punch[key]) <= 0.0:
			_card_punch.erase(key)
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

func _punch_scale(id: String) -> float:
	if not _card_punch.has(id):
		return 1.0
	return UIKit.punch(1.0 - float(_card_punch[id]) / 0.28, 0.10)

func _add_hit(rect: Rect2, kind: String, id: String) -> void:
	_hits.append({ "rect": content_to_screen(rect), "kind": kind, "id": id })

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not is_open:
		return
	var sz: Vector2 = get_screen_size()
	UIKit.gradient_v(self, Rect2(Vector2.ZERO, sz), UIKit.BG_TOP, UIKit.BG_BOTTOM)
	UIKit.confetti(self, Rect2(0.0, 0.0, sz.x, sz.y), time_sec, 14, 0.85)

func _draw_content(ci: CanvasItem) -> void:
	if social == null:
		return
	_hits.clear()
	var sz: Vector2 = get_screen_size()
	var w: float = sz.x - MARGIN * 2.0
	var oy: float = -scroll_y
	var reset_txt: String = UIKit.format_duration(social.seconds_until_shop_reset())

	_draw_plus_banner(ci, Rect2(MARGIN, BANNER_Y, w, BANNER_H), oy)

	# --- Offers of the day ---
	UIKit.text(ci, Vector2(MARGIN, DAILY_TITLE_Y + oy), tr(&"SHOP_DAILY"), HORIZONTAL_ALIGNMENT_LEFT, w - 150.0, 30, Color.WHITE, 3.0)
	UIKit.timer_pill(ci, Rect2(sz.x - MARGIN - 136.0, DAILY_TITLE_Y - 36.0 + oy, 136.0, 46.0), reset_txt)
	var offers: Dictionary = social.get_daily_offers()
	var card_w: float = (w - 24.0) / 3.0
	var skin_r := Rect2(MARGIN, DAILY_CARDS_Y, card_w, DAILY_CARD_H)
	_draw_daily_skin_card(ci, skin_r, oy, offers)
	var packs: Array = offers["packs"]
	for i: int in range(packs.size()):
		var pack: Dictionary = EconomyCatalog.get_coin_pack(str(packs[i]))
		var pr := Rect2(MARGIN + float(i + 1) * (card_w + 12.0), DAILY_CARDS_Y, card_w, DAILY_CARD_H)
		_draw_pack_card(ci, pr, oy, pack)

	# --- Free offers ---
	UIKit.text(ci, Vector2(MARGIN, FREE_TITLE_Y + oy), tr(&"SHOP_FREE"), HORIZONTAL_ALIGNMENT_LEFT, w - 150.0, 30, Color.WHITE, 3.0)
	UIKit.timer_pill(ci, Rect2(sz.x - MARGIN - 136.0, FREE_TITLE_Y - 36.0 + oy, 136.0, 46.0), reset_txt)
	var free_w: float = (w - 16.0) * 0.5
	for i: int in range(EconomyCatalog.FREE_OFFERS.size()):
		var fr := Rect2(MARGIN + float(i) * (free_w + 16.0), FREE_CARDS_Y, free_w, FREE_CARD_H)
		_draw_free_card(ci, fr, oy, EconomyCatalog.FREE_OFFERS[i])

	# --- Wardrobe: every skin in the game ---
	UIKit.text(ci, Vector2(MARGIN, WARDROBE_TITLE_Y + oy), tr(&"SHOP_WARDROBE"), HORIZONTAL_ALIGNMENT_LEFT, w, 30, Color.WHITE, 3.0)
	for i: int in range(EconomyCatalog.SKINS.size()):
		var col_i: int = i % 3
		var row_i: int = i / 3
		var sr := Rect2(MARGIN + float(col_i) * (card_w + 12.0), WARDROBE_Y + float(row_i) * (SKIN_CARD_H + SKIN_GAP), card_w, SKIN_CARD_H)
		if sr.end.y + oy < -20.0 or sr.position.y + oy > scroll_area.size.y + 20.0:
			continue
		_draw_wardrobe_card(ci, sr, oy, EconomyCatalog.SKINS[i])

	UIKit.text(ci, Vector2(MARGIN, content_height - 26.0 + oy), tr(&"SHOP_COSMETIC_NOTE"), HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color(0.88, 0.90, 1.0, 0.85), 1.5)

func _draw_plus_banner(ci: CanvasItem, rect: Rect2, oy: float) -> void:
	var r := Rect2(rect.position + Vector2(0.0, oy), rect.size)
	r = UIKit.scaled(r, _punch_scale("plus"))
	UIKit.flat(ci, Rect2(r.position.x, r.position.y + 6.0, r.size.x, r.size.y), Color(0.20, 0.06, 0.34), 22.0, UIKit.DARK, 3.0)
	UIKit.gradient_box(ci, r, Color(1.0, 0.16, 0.62), Color(0.40, 0.14, 0.72), 22.0, UIKit.DARK, 3.0)
	# Faint crown pattern.
	for cx: int in range(7):
		for cy: int in range(3):
			var p := Vector2(r.position.x + 30.0 + float(cx) * 66.0 + (33.0 if cy % 2 == 1 else 0.0), r.position.y + 18.0 + float(cy) * 54.0)
			if p.x + 36.0 < r.end.x - 6.0:
				ci.draw_texture_rect(UIKit.CROWN_TEX, Rect2(p, Vector2(36.0, 30.0)), false, Color(1, 1, 1, 0.07))
	ci.draw_texture_rect(UIKit.CROWN_TEX, Rect2(r.position.x + 18.0, r.position.y + 22.0, 42.0, 35.0), false)
	UIKit.text(ci, Vector2(r.position.x + 72.0, r.position.y + 56.0), tr(&"SHOP_PLUS_NAME"), HORIZONTAL_ALIGNMENT_LEFT, 240.0, 34, Color.WHITE, 3.0)
	var plus_owned: bool = social.has_premium_pass
	var price_txt: String = tr(&"SHOP_PLUS_ACTIVE") if plus_owned else UIKit.format_price(EconomyCatalog.SPLICE_PLUS_PRICE_CENTS)
	UIKit.text(ci, Vector2(r.position.x + 24.0, r.position.y + 134.0), price_txt, HORIZONTAL_ALIGNMENT_LEFT, 260.0, 34, UIKit.GREEN if plus_owned else Color.WHITE, 3.0)
	UIKit.text(ci, Vector2(r.position.x + 24.0, r.position.y + 160.0), tr(&"SHOP_PLUS_SUB"), HORIZONTAL_ALIGNMENT_LEFT, 280.0, 14, Color(1.0, 0.90, 0.98), 1.5)
	# The equipped hero waves from the banner, poking out above it like in the key art.
	var hero := Rect2(r.end.x - 196.0, r.position.y - 62.0, 190.0, r.size.y + 58.0)
	UIKit.skin_preview(ci, hero, previews.get_texture(social.equipped_skin) if previews != null else null, Color(1.0, 0.85, 0.95))
	_add_hit(rect, "plus", "plus")

func _card_bg(ci: CanvasItem, r: Rect2) -> void:
	UIKit.box(ci, r, UIKit.CARD_BLUE, UIKit.CARD_BLUE_BEVEL, UIKit.DARK, 16.0, 3.0, 5.0)

func _price_bar(ci: CanvasItem, r: Rect2, txt: String, with_coin: bool, col: Color = Color.WHITE) -> void:
	UIKit.flat(ci, r, Color(0.09, 0.10, 0.14), 6.0)
	if with_coin:
		var tw: float = UIKit.text_width(txt, 19)
		var x0: float = r.get_center().x - (tw + 26.0) * 0.5
		UIKit.coin(ci, Vector2(x0 + 11.0, r.get_center().y), 22.0)
		UIKit.text_in(ci, Rect2(x0 + 26.0, r.position.y, tw, r.size.y), txt, 19, col, 0.0)
	else:
		UIKit.text_in(ci, r, txt, 19, col, 0.0)

func _draw_daily_skin_card(ci: CanvasItem, rect: Rect2, oy: float, offers: Dictionary) -> void:
	var skin: Dictionary = EconomyCatalog.get_skin(str(offers["skin_id"]))
	var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch_scale("daily_skin"))
	_card_bg(ci, r)
	var rar_col: Color = EconomyCatalog.get_rarity_color(int(skin["rarity"]))
	UIKit.skin_preview(ci, Rect2(r.position.x + 10.0, r.position.y + 8.0, r.size.x - 20.0, 106.0), previews.get_texture(str(skin["id"])) if previews != null else null, rar_col)
	UIKit.text(ci, Vector2(r.position.x, r.position.y + 136.0), tr(StringName(str(skin["name_key"]))), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 19, Color.WHITE, 2.5)
	var bar := Rect2(r.position.x + 14.0, r.end.y - 42.0, r.size.x - 28.0, 30.0)
	if social.owns_skin(str(skin["id"])):
		_price_bar(ci, bar, tr(&"SHOP_OWNED"), false, UIKit.GREEN)
	else:
		_price_bar(ci, bar, str(int(offers["skin_price"])), true)
		# Discount tag: the real saving against the wardrobe price.
		var tag := Rect2(r.position.x - 4.0, r.position.y + 6.0, 54.0, 24.0)
		UIKit.flat(ci, tag, UIKit.MAGENTA, 8.0, UIKit.DARK, 2.0)
		UIKit.text_in(ci, tag, tr(&"SHOP_DISCOUNT") % EconomyCatalog.DAILY_SKIN_DISCOUNT_PCT, 14, Color.WHITE, 1.5)
		_add_hit(rect, "daily_skin", str(skin["id"]))

func _draw_pack_card(ci: CanvasItem, rect: Rect2, oy: float, pack: Dictionary) -> void:
	var id: String = str(pack["id"])
	var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch_scale(id))
	_card_bg(ci, r)
	UIKit.coin_pile(ci, Vector2(r.get_center().x, r.position.y + 58.0), 1.0, 6)
	UIKit.text(ci, Vector2(r.position.x, r.position.y + 136.0), tr(&"SHOP_COINS_X") % int(pack["coins"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1.0, 0.72, 0.10), 2.5)
	_price_bar(ci, Rect2(r.position.x + 14.0, r.end.y - 42.0, r.size.x - 28.0, 30.0), UIKit.format_price(int(pack["price_cents"])), false)
	_add_hit(rect, "pack", id)

func _draw_free_card(ci: CanvasItem, rect: Rect2, oy: float, offer: Dictionary) -> void:
	var id: String = str(offer["id"])
	var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch_scale(id))
	_card_bg(ci, r)
	var claimed: bool = social.is_free_offer_claimed(id)
	var icon_c := Vector2(r.position.x + r.size.x * 0.34, r.position.y + 66.0)
	var label: String = ""
	if str(offer["type"]) == "xp":
		UIKit.star(ci, icon_c, 38.0, UIKit.MAGENTA)
		label = tr(&"SHOP_XP_PLUS") % int(offer["amount"])
	else:
		UIKit.coin_pile(ci, icon_c, 0.95, 5)
		label = tr(&"SHOP_COINS_X") % int(offer["amount"])
	UIKit.text(ci, Vector2(r.position.x + r.size.x * 0.56, r.position.y + 76.0), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.42, 22, Color(1.0, 0.72, 0.10), 2.5)
	var btn := Rect2(r.position.x + 16.0, r.end.y - 46.0, r.size.x - 32.0, 32.0)
	if claimed:
		UIKit.flat(ci, btn, Color(0.30, 0.36, 0.56), 6.0)
		UIKit.text_in(ci, btn, tr(&"SHOP_CLAIMED"), 18, Color(0.82, 0.88, 1.0), 0.0)
	else:
		var pulse: float = 1.0 + 0.03 * sin(time_sec * 5.0)
		UIKit.gradient_box(ci, UIKit.scaled(btn, pulse), Color(0.95, 0.24, 0.66), Color(0.38, 0.30, 0.72), 6.0, UIKit.DARK, 0.0)
		UIKit.text_in(ci, btn, tr(&"SHOP_CLAIM"), 20, Color.WHITE, 2.0)
		_add_hit(rect, "free", id)

func _draw_wardrobe_card(ci: CanvasItem, rect: Rect2, oy: float, skin: Dictionary) -> void:
	var id: String = str(skin["id"])
	var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch_scale("w_" + id))
	var owned: bool = social.owns_skin(id)
	var equipped: bool = social.equipped_skin == id
	var rar_col: Color = EconomyCatalog.get_rarity_color(int(skin["rarity"]))
	UIKit.box(ci, r, UIKit.CARD_BLUE if owned else Color(0.56, 0.64, 0.86), UIKit.CARD_BLUE_BEVEL, UIKit.GOLD if equipped else UIKit.DARK, 16.0, 3.0, 5.0)
	# Rarity reads by the strip colour and by its label, not by colour alone.
	UIKit.flat(ci, Rect2(r.position.x + 10.0, r.position.y + 10.0, r.size.x - 20.0, 20.0), rar_col, 6.0, UIKit.DARK, 1.5)
	UIKit.text_in(ci, Rect2(r.position.x + 10.0, r.position.y + 10.0, r.size.x - 20.0, 20.0), tr(EconomyCatalog.get_rarity_key(int(skin["rarity"]))), 12, Color.WHITE, 1.5)
	UIKit.skin_preview(ci, Rect2(r.position.x + 8.0, r.position.y + 34.0, r.size.x - 16.0, 108.0), previews.get_texture(id) if previews != null else null, rar_col, Color.WHITE if owned else Color(0.80, 0.82, 0.92))
	UIKit.text(ci, Vector2(r.position.x, r.position.y + 164.0), tr(StringName(str(skin["name_key"]))), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color.WHITE, 2.5)
	var bar := Rect2(r.position.x + 12.0, r.end.y - 40.0, r.size.x - 24.0, 30.0)
	if equipped:
		_price_bar(ci, bar, tr(&"SHOP_IN_USE"), false, UIKit.GOLD)
	elif owned:
		UIKit.flat(ci, bar, UIKit.GREEN, 6.0, UIKit.DARK, 2.0)
		UIKit.text_in(ci, bar, tr(&"SHOP_USE"), 18, Color.WHITE, 2.0)
		_add_hit(rect, "equip", id)
	elif int(skin["price"]) > 0:
		_price_bar(ci, bar, str(int(skin["price"])), true)
		_add_hit(rect, "buy", id)
	else:
		_price_bar(ci, bar, tr(&"SHOP_IN_PASS"), false, Color(1.0, 0.62, 0.86))
		_add_hit(rect, "pass_only", id)

func _draw_overlay(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	# Header fades into the page so cards slide under it.
	UIKit.gradient_v(ci, Rect2(0.0, 0.0, sz.x, HEADER_H - 22.0), UIKit.BG_TOP, UIKit.BG_TOP)
	UIKit.gradient_v(ci, Rect2(0.0, HEADER_H - 22.0, sz.x, 22.0), UIKit.BG_TOP, Color(UIKit.BG_TOP.r, UIKit.BG_TOP.g, UIKit.BG_TOP.b, 0.0))
	_back_rect = Rect2(MARGIN, 34.0, 76.0, 74.0)
	UIKit.back_button(ci, _back_rect)
	UIKit.text(ci, Vector2(0.0, 88.0), tr(&"SHOP_HEADER"), HORIZONTAL_ALIGNMENT_CENTER, sz.x - 30.0, 36, Color.WHITE, 3.5)
	var shake: float = sin(time_sec * 60.0) * 6.0 * (_pill_shake / 0.35) if _pill_shake > 0.0 else 0.0
	_pill_rect = Rect2(sz.x - MARGIN - 136.0 + shake, 48.0, 136.0, 50.0)
	var coins_now: int = int(round(_coin_shown))
	UIKit.coin_pill(ci, UIKit.scaled(_pill_rect, UIKit.punch(1.0 - _pill_punch / 0.22, 0.16) if _pill_punch > 0.0 else 1.0), str(coins_now), 22, Color(0.16, 0.24, 0.52, 0.92), Color(1.0, 0.45, 0.45) if _pill_shake > 0.0 else Color.WHITE)

	# Coins flying to the wallet.
	for f: Dictionary in _flying:
		if float(f["delay"]) > 0.0:
			continue
		var t: float = UIKit.ease_out_cubic(float(f["t"]))
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var mid: Vector2 = from.lerp(to, 0.5) + Vector2(-60.0, -40.0)
		var p: Vector2 = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		UIKit.coin(ci, p, lerpf(34.0, 22.0, t))

	if _toast_timer > 0.0:
		var tw: float = minf(sz.x - 60.0, UIKit.text_width(_toast, 19) + 44.0)
		var tr_rect := Rect2((sz.x - tw) * 0.5, sz.y - 150.0, tw, 46.0)
		UIKit.box(ci, tr_rect, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, tr_rect, _toast, 19, Color.WHITE, 2.0)

	if not _confirm.is_empty():
		_draw_confirm(ci, sz)
	_popup.draw(ci, sz, previews, true)

func _draw_confirm(ci: CanvasItem, sz: Vector2) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.03, 0.10, 0.72), true)
	var card := Rect2(40.0, sz.y * 0.5 - 190.0, sz.x - 80.0, 380.0)
	UIKit.box(ci, card, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 20.0, 3.0, 6.0)
	var kind: String = str(_confirm["kind"])
	var offline: bool = bool(_confirm.get("offline", false))
	UIKit.text(ci, Vector2(card.position.x + 16.0, card.position.y + 50.0), tr(&"SHOP_STORE_OFFLINE_TITLE") if offline else tr(&"SHOP_CONFIRM_TITLE"), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 32.0, 24, UIKit.GOLD, 2.5)
	var art := Rect2(card.position.x + card.size.x * 0.5 - 80.0, card.position.y + 70.0, 160.0, 140.0)
	var label: String = ""
	if kind == "skin":
		var skin: Dictionary = EconomyCatalog.get_skin(str(_confirm["id"]))
		UIKit.skin_preview(ci, art, previews.get_texture(str(skin["id"])) if previews != null else null, UIKit.CARD_BLUE)
		label = tr(StringName(str(skin["name_key"])))
	elif kind == "pack":
		UIKit.coin_pile(ci, art.get_center(), 1.3, 6)
		label = tr(&"SHOP_COINS_X") % int(EconomyCatalog.get_coin_pack(str(_confirm["id"]))["coins"])
	else:
		ci.draw_texture_rect(UIKit.CROWN_TEX, Rect2(art.get_center() - Vector2(54.0, 45.0), Vector2(108.0, 90.0)), false)
		label = tr(&"SHOP_PLUS_NAME")
	UIKit.text(ci, Vector2(card.position.x, card.position.y + 244.0), label, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 26, Color.WHITE, 2.5)
	if offline:
		UIKit.text(ci, Vector2(card.position.x + 20.0, card.position.y + 276.0), tr(&"SHOP_STORE_OFFLINE_BODY"), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 40.0, 15, Color(0.82, 0.86, 0.98), 1.5)
		_confirm_yes = Rect2()
		_confirm_no = Rect2(card.position.x + 60.0, card.end.y - 76.0, card.size.x - 120.0, 54.0)
		UIKit.box(ci, _confirm_no, UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, _confirm_no, tr(&"SHOP_CONFIRM_OK"), 22, Color.WHITE, 2.5)
		return
	var price_r := Rect2(card.position.x + card.size.x * 0.5 - 80.0, card.position.y + 254.0, 160.0, 36.0)
	if bool(_confirm.get("real_money", false)):
		UIKit.text_in(ci, price_r, UIKit.format_price(int(_confirm["price"])), 24, Color.WHITE, 2.5)
		UIKit.text(ci, Vector2(card.position.x + 16.0, card.position.y + 306.0), tr(&"SHOP_SANDBOX_NOTE"), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 32.0, 13, Color(0.80, 0.84, 0.98), 1.0)
	else:
		UIKit.coin_pill(ci, price_r, str(int(_confirm["price"])), 22)
	var half: float = (card.size.x - 54.0) * 0.5
	_confirm_no = Rect2(card.position.x + 20.0, card.end.y - 70.0, half, 52.0)
	_confirm_yes = Rect2(_confirm_no.end.x + 14.0, card.end.y - 70.0, half, 52.0)
	UIKit.box(ci, _confirm_no, Color(0.30, 0.34, 0.48), UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
	UIKit.text_in(ci, _confirm_no, tr(&"SHOP_CONFIRM_CANCEL"), 20, Color.WHITE, 2.0)
	UIKit.box(ci, _confirm_yes, UIKit.GREEN, UIKit.GREEN_BEVEL, UIKit.DARK, 12.0, 2.5)
	UIKit.text_in(ci, _confirm_yes, tr(&"SHOP_CONFIRM_BUY"), 20, Color.WHITE, 2.0)

# ---------------------------------------------------------------------------
# Input and actions
# ---------------------------------------------------------------------------

func _on_tap(pos: Vector2) -> void:
	if social == null:
		return
	if _popup.active:
		var act: String = _popup.handle_tap(pos)
		if act == "equip":
			social.equip_skin(str(_popup.reward.get("id", "")))
			_play_equip()
		return
	if not _confirm.is_empty():
		if _confirm_yes.has_area() and _confirm_yes.has_point(pos):
			_run_confirmed()
		elif _confirm_no.has_point(pos):
			_confirm.clear()
		return
	if _back_rect.has_point(pos):
		close()
		return
	if _pill_rect.has_point(pos):
		scroll_to(DAILY_TITLE_Y - 60.0)
		return
	for hit: Dictionary in _hits:
		if is_hit_in_scroll(hit["rect"] as Rect2, pos):
			_activate(str(hit["kind"]), str(hit["id"]), (hit["rect"] as Rect2).get_center())
			return

func _activate(kind: String, id: String, origin: Vector2) -> void:
	match kind:
		"plus":
			if social.has_premium_pass:
				open_pass_requested.emit()
				return
			_card_punch["plus"] = 0.28
			_ask_real_money("plus", EconomyCatalog.PRODUCT_SPLICE_PLUS, EconomyCatalog.SPLICE_PLUS_PRICE_CENTS, origin)
		"pack":
			_card_punch[id] = 0.28
			_ask_real_money("pack", id, int(EconomyCatalog.get_coin_pack(id)["price_cents"]), origin)
		"daily_skin":
			_card_punch["daily_skin"] = 0.28
			_confirm = { "kind": "skin", "id": id, "price": int(social.get_daily_offers()["skin_price"]), "daily": true, "origin": origin }
		"buy":
			_card_punch["w_" + id] = 0.28
			_confirm = { "kind": "skin", "id": id, "price": int(EconomyCatalog.get_skin(id)["price"]), "daily": false, "origin": origin }
		"equip":
			_card_punch["w_" + id] = 0.28
			if social.equip_skin(id):
				_play_equip()
		"pass_only":
			_card_punch["w_" + id] = 0.28
			_show_toast(tr(&"SHOP_PASS_ONLY_TOAST"))
		"free":
			_card_punch[id] = 0.28
			var granted: Dictionary = social.claim_free_offer(id)
			if granted.is_empty():
				return
			if str(granted.get("type", "")) == "coins":
				_fly_coins(origin, mini(8, maxi(3, int(granted.get("amount", 0)) / 3)))
			else:
				_show_toast(tr(&"SHOP_XP_PLUS") % int(granted.get("amount", 0)))
				if sound != null:
					sound.play_equip_sfx()

func _ask_real_money(kind: String, id: String, price_cents: int, origin: Vector2) -> void:
	var available: bool = social.purchase_gateway != null and social.purchase_gateway.is_available()
	_confirm = { "kind": kind, "id": id, "price": price_cents, "real_money": true, "offline": not available, "origin": origin }

func _run_confirmed() -> void:
	var pending: Dictionary = _confirm.duplicate()
	_confirm.clear()
	var origin: Vector2 = pending.get("origin", get_screen_size() * 0.5) as Vector2
	match str(pending["kind"]):
		"skin":
			var res: Dictionary = social.buy_skin(str(pending["id"]), bool(pending.get("daily", false)))
			if bool(res["ok"]):
				_popup.show_reward({ "type": "skin", "id": str(pending["id"]), "duplicate": false })
				_play_equip()
			elif str(res["reason"]) == "coins":
				_pill_shake = 0.35
				_show_toast(tr(&"SHOP_NOT_ENOUGH"))
		"pack":
			var pres: Dictionary = social.purchase_coin_pack(str(pending["id"]))
			if bool(pres["ok"]):
				_fly_coins(origin, 10)
		"plus":
			var plus_res: Dictionary = social.purchase_plus()
			if bool(plus_res["ok"]):
				_show_toast(tr(&"SHOP_PLUS_UNLOCKED"))
				_play_equip()

func _fly_coins(from: Vector2, count: int) -> void:
	for i: int in range(count):
		_flying.append({
			"from": from + Vector2(randf_range(-26.0, 26.0), randf_range(-20.0, 20.0)),
			"to": Vector2(_pill_rect.position.x + 24.0, _pill_rect.get_center().y),
			"t": 0.0,
			"delay": float(i) * 0.045,
		})

func _show_toast(txt: String) -> void:
	_toast = txt
	_toast_timer = 2.0

func _play_equip() -> void:
	if sound != null:
		sound.play_equip_sfx()
