class_name RewardPopup
extends RefCounted
## The "you got something!" card shown after a purchase or a Season Pass claim: big reveal with
## a pop, rays and confetti. Used by the shop and the pass so both celebrate the same way.
##
## Usage: call show_reward(), then every frame update(delta) and draw(); route taps to
## handle_tap(), which returns "" | "equip" | "close".

const POP_SEC: float = 0.38

var active: bool = false
var reward: Dictionary = {}
var _age: float = 0.0
var _equip_rect := Rect2()
var _ok_rect := Rect2()
var _card_rect := Rect2()

func show_reward(granted: Dictionary) -> void:
	reward = granted
	active = true
	_age = 0.0

func hide() -> void:
	active = false

func update(delta: float) -> void:
	if active:
		_age += delta

func handle_tap(pos: Vector2) -> String:
	if not active or _age < 0.25:
		return ""
	if _equip_rect.has_area() and _equip_rect.has_point(pos):
		active = false
		return "equip"
	if _ok_rect.has_point(pos) or not _card_rect.has_point(pos):
		active = false
		return "close"
	return ""

func draw(ci: CanvasItem, sz: Vector2, previews: SkinPreviewRenderer, can_equip: bool) -> void:
	if not active:
		return
	var fade: float = clampf(_age / 0.18, 0.0, 1.0)
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.03, 0.10, 0.78 * fade), true)
	var pop: float = UIKit.ease_out_back(_age / POP_SEC)
	var center := Vector2(sz.x * 0.5, sz.y * 0.46)

	# Rotating rays behind the prize.
	var rtype: String = str(reward.get("type", "coins"))
	var accent: Color = UIKit.GOLD
	if rtype == "skin":
		accent = EconomyCatalog.get_rarity_color(int(EconomyCatalog.get_skin(str(reward.get("id", "")))["rarity"]))
	elif rtype == "color":
		accent = Color(str(reward.get("id", "#FFFFFF")))
	for i: int in range(12):
		var a: float = _age * 0.6 + float(i) * TAU / 12.0
		var tip_a := center + Vector2(cos(a - 0.10), sin(a - 0.10)) * 330.0 * pop
		var tip_b := center + Vector2(cos(a + 0.10), sin(a + 0.10)) * 330.0 * pop
		ci.draw_colored_polygon(PackedVector2Array([center, tip_a, tip_b]), Color(accent.r, accent.g, accent.b, 0.22 * fade))

	var card_w: float = minf(sz.x - 72.0, 400.0)
	var card := UIKit.scaled(Rect2((sz.x - card_w) * 0.5, center.y - 220.0, card_w, 440.0), pop)
	_card_rect = card
	UIKit.box(ci, card, Color(0.20, 0.16, 0.46), Color(0.11, 0.08, 0.28), UIKit.DARK, 20.0, 3.0, 6.0)

	var title_key: StringName = &"REWARD_NEW_SKIN"
	if rtype == "color":
		title_key = &"REWARD_NEW_COLOR"
	elif rtype == "coins":
		title_key = &"REWARD_COINS_TITLE"
	elif rtype == "xp":
		title_key = &"REWARD_XP_TITLE"
	UIKit.text(ci, Vector2(card.position.x, card.position.y + 54.0 * pop), ci.tr(title_key), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(34.0 * pop), UIKit.GOLD, 3.0)

	var art := Rect2(card.position.x + card.size.x * 0.18, card.position.y + 76.0 * pop, card.size.x * 0.64, 200.0 * pop)
	UIKit.flat(ci, art, Color(accent.r, accent.g, accent.b, 0.28), 18.0, UIKit.DARK, 2.0)
	var name_txt: String = ""
	match rtype:
		"skin":
			var skin: Dictionary = EconomyCatalog.get_skin(str(reward.get("id", "")))
			UIKit.skin_preview(ci, art.grow(-6.0), previews.get_texture(str(skin["id"])) if previews != null else null, accent)
			name_txt = ci.tr(StringName(str(skin["name_key"])))
		"color":
			ci.draw_circle(art.get_center(), 62.0 * pop, UIKit.DARK)
			ci.draw_circle(art.get_center(), 56.0 * pop, accent)
			ci.draw_circle(art.get_center() + Vector2(-18.0, -20.0) * pop, 14.0 * pop, Color(1, 1, 1, 0.35))
			name_txt = "#" + accent.to_html(false).to_upper()
		"xp":
			UIKit.star(ci, art.get_center(), 60.0 * pop, UIKit.MAGENTA)
			name_txt = ci.tr(&"SHOP_XP_PLUS") % int(reward.get("amount", 0))
		_:
			UIKit.coin_pile(ci, art.get_center() + Vector2(0.0, -6.0), 1.5 * pop, 6)
			name_txt = ci.tr(&"SHOP_COINS_X") % int(reward.get("amount", 0))
	UIKit.text(ci, Vector2(card.position.x, card.position.y + 318.0 * pop), name_txt, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(30.0 * pop), Color.WHITE, 3.0)
	if bool(reward.get("duplicate", false)):
		UIKit.text(ci, Vector2(card.position.x, card.position.y + 348.0 * pop), ci.tr(&"REWARD_DUPLICATE") % int(reward.get("compensation", 0)), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(17.0 * pop), Color(0.85, 0.88, 1.0), 2.0)
	elif rtype == "skin":
		var rar: int = int(EconomyCatalog.get_skin(str(reward.get("id", "")))["rarity"])
		UIKit.text(ci, Vector2(card.position.x, card.position.y + 348.0 * pop), ci.tr(EconomyCatalog.get_rarity_key(rar)), HORIZONTAL_ALIGNMENT_CENTER, card.size.x, int(17.0 * pop), accent, 2.0)

	var btn_y: float = card.end.y - 72.0 * pop
	var show_equip: bool = can_equip and rtype == "skin" and not bool(reward.get("duplicate", false))
	if show_equip:
		var half: float = (card.size.x - 54.0) * 0.5
		_ok_rect = Rect2(card.position.x + 20.0, btn_y, half, 52.0 * pop)
		_equip_rect = Rect2(_ok_rect.end.x + 14.0, btn_y, half, 52.0 * pop)
		UIKit.box(ci, _ok_rect, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, _ok_rect, ci.tr(&"REWARD_OK"), int(20.0 * pop), Color.WHITE, 2.0)
		UIKit.box(ci, _equip_rect, UIKit.GREEN, UIKit.GREEN_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, _equip_rect, ci.tr(&"REWARD_EQUIP_NOW"), int(19.0 * pop), Color.WHITE, 2.0)
	else:
		_equip_rect = Rect2()
		_ok_rect = Rect2(card.position.x + 40.0, btn_y, card.size.x - 80.0, 52.0 * pop)
		UIKit.box(ci, _ok_rect, UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, _ok_rect, ci.tr(&"REWARD_OK"), int(22.0 * pop), Color.WHITE, 2.5)

	# Confetti burst falling from the top of the card.
	for i: int in range(26):
		var seed_f: float = float(i) * 7.31
		var ang: float = -PI * 0.5 + (fposmod(seed_f, 2.0) - 1.0) * 1.3
		var spd: float = 260.0 + fposmod(seed_f * 3.0, 220.0)
		var t: float = _age
		var p := center + Vector2(cos(ang) * spd * t, sin(ang) * spd * t + 420.0 * t * t)
		var a_fade: float = clampf(1.6 - t, 0.0, 1.0)
		if a_fade > 0.0:
			var c_col: Color = UIKit.CONFETTI_COLORS[i % UIKit.CONFETTI_COLORS.size()]
			ci.draw_rect(Rect2(p, Vector2(10.0, 10.0)), Color(c_col.r, c_col.g, c_col.b, a_fade), true)
