class_name AppearanceScreen
extends TouchScreenBase
## "Aspetto": dress the fighter. Same cards, coins and buttons as the shop and the pass.
##
## The top half stays see-through so the live 3D hero shows (drag there to spin it). The
## panel below has three tabs: skins grouped by character (styles), starting parts per slot,
## and signature colours. Locked skins and colours can be tried on before buying or reaching
## them in the pass; leaving the screen puts the equipped look back.

signal skin_preview_changed(skin_id: String) ## "" means: show the equipped skin again.
signal part_equipped(slot: int, part_id: StringName)
signal color_preview_changed(col: Color)
signal play_requested()
signal buy_requested(skin_id: String, daily: bool)
signal open_pass_requested()
signal hero_rotated(delta_x: float)

const TAB_SKINS: int = 0
const TAB_PARTS: int = 1
const TAB_COLORS: int = 2
const HEADER_H: float = 124.0
const TABS_H: float = 62.0
const FOOTER_H: float = 100.0
const MARGIN: float = 22.0
const GAP: float = 12.0
const FAMILY_TITLE_H: float = 46.0
const SKIN_CARD_H: float = 200.0
const SLOT_ROW_H: float = 104.0
const PART_CARD_H: float = 156.0
const COLOR_CARD_H: float = 156.0

const PARTS_BY_SLOT: Dictionary = {
	PartData.Slot.HEAD: [&"base_head", &"spike_helm", &"visor_head", &"laser_eye"],
	PartData.Slot.ARMS: [&"base_fist", &"chainsaw_arm", &"giant_fist", &"mega_claws"],
	PartData.Slot.LEGS: [&"base_boots", &"spring_legs", &"roller_wheels", &"rocket_legs"],
	PartData.Slot.CORE: [&"base_core", &"shield_core", &"magnet_core", &"crown_core"],
}
const SLOT_ORDER: Array[int] = [PartData.Slot.HEAD, PartData.Slot.ARMS, PartData.Slot.LEGS, PartData.Slot.CORE]

var social: SocialManager = null
var previews: SkinPreviewRenderer = null
var sound: SoundController = null

var current_tab: int = TAB_SKINS
var selected_slot: int = PartData.Slot.HEAD
var tryon_skin_id: String = ""
var tryon_color_id: String = ""

var panel_top: float = 480.0
var _hits: Array[Dictionary] = [] # { "rect": Rect2 (screen), "kind": String, "id": String }
var _back_rect := Rect2()
var _pill_rect := Rect2()
var _tab_rects: Array[Rect2] = []
var _cta_rect := Rect2()
var _cta_kind: String = "play"
var _card_punch: Dictionary = {}
var _toast: String = ""
var _toast_timer: float = 0.0
var _scroll_per_tab: Dictionary = {}

func open(tab: int = TAB_SKINS) -> void:
	current_tab = tab
	tryon_skin_id = ""
	tryon_color_id = ""
	scroll_y = 0.0
	show_screen()
	_update_screen(0.0)

func close() -> void:
	_end_tryon()
	super.close()

func switch_tab(tab: int) -> void:
	if tab == current_tab:
		return
	_scroll_per_tab[current_tab] = scroll_y
	current_tab = tab
	scroll_y = float(_scroll_per_tab.get(tab, 0.0))
	scroll_velocity = 0.0
	_update_screen(0.0)
	scroll_y = clampf(scroll_y, 0.0, max_scroll())

## The skin the hero should wear right now: the one being tried on, or the equipped one.
func get_display_skin_id() -> String:
	if tryon_skin_id != "":
		return tryon_skin_id
	return social.equipped_skin if social != null else EconomyCatalog.DEFAULT_SKIN_ID

func get_display_color() -> Color:
	if tryon_color_id != "":
		return Color(str(EconomyCatalog.get_color(tryon_color_id)["hex"]))
	return social.get_equipped_color() if social != null else Color.WHITE

func _end_tryon() -> void:
	if tryon_skin_id != "":
		tryon_skin_id = ""
		skin_preview_changed.emit("")
	if tryon_color_id != "":
		tryon_color_id = ""
		color_preview_changed.emit(get_display_color())

# ---------------------------------------------------------------------------
# Layout and state
# ---------------------------------------------------------------------------

func _update_screen(delta: float) -> void:
	var sz: Vector2 = get_screen_size()
	panel_top = clampf(sz.y * 0.50, 440.0, sz.y - 420.0)
	scroll_area = Rect2(0.0, panel_top + TABS_H, sz.x, sz.y - panel_top - TABS_H - FOOTER_H)
	content_height = _content_height_for(current_tab, sz)
	_toast_timer = maxf(0.0, _toast_timer - delta)
	for key: Variant in _card_punch.keys():
		_card_punch[key] = float(_card_punch[key]) - delta
		if float(_card_punch[key]) <= 0.0:
			_card_punch.erase(key)

func _card_w(sz: Vector2, columns: int) -> float:
	return (sz.x - MARGIN * 2.0 - GAP * float(columns - 1)) / float(columns)

func _content_height_for(tab: int, _sz: Vector2) -> float:
	match tab:
		TAB_SKINS:
			var h: float = 14.0
			for fam: Dictionary in EconomyCatalog.get_skin_families():
				var rows: int = int(ceil(float((fam["skins"] as Array).size()) / 3.0))
				h += FAMILY_TITLE_H + float(rows) * (SKIN_CARD_H + GAP) + 10.0
			return h + 20.0
		TAB_PARTS:
			return 14.0 + SLOT_ROW_H + 18.0 + 2.0 * (PART_CARD_H + GAP) + 60.0
		_:
			var rows: int = int(ceil(float(EconomyCatalog.COLORS.size()) / 3.0))
			return 14.0 + 40.0 + float(rows) * (COLOR_CARD_H + GAP) + 30.0

func _punch(id: String) -> float:
	if not _card_punch.has(id):
		return 1.0
	return UIKit.punch(1.0 - float(_card_punch[id]) / 0.28, 0.10)

func _add_hit(rect: Rect2, kind: String, id: String) -> void:
	_hits.append({ "rect": content_to_screen(rect), "kind": kind, "id": id })

func _owned_count(fam: Dictionary) -> int:
	var n: int = 0
	for s: Dictionary in fam["skins"]:
		if social.owns_skin(str(s["id"])):
			n += 1
	return n

## Lock label for something that comes from the pass: "PASS LIV. 8" or "PLUS LIV. 15".
func _pass_label(source: Dictionary) -> String:
	if source.is_empty():
		return tr(&"SHOP_IN_PASS")
	return (tr(&"LOOK_PLUS_LEVEL") if bool(source["is_paid"]) else tr(&"LOOK_PASS_LEVEL")) % int(source["tier"])

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not is_open:
		return
	var sz: Vector2 = get_screen_size()
	# Soft fade behind the header so the title reads over the 3D stage.
	UIKit.gradient_v(self, Rect2(0.0, 0.0, sz.x, HEADER_H + 20.0), Color(0.10, 0.08, 0.30, 0.70), Color(0.10, 0.08, 0.30, 0.0))
	_draw_hero_label(sz)
	# Panel: same blue-violet page as the shop, rounded on top.
	var panel := Rect2(0.0, panel_top, sz.x, sz.y - panel_top + 30.0)
	UIKit.flat(self, Rect2(panel.position.x, panel.position.y - 4.0, panel.size.x, panel.size.y), UIKit.DARK, 28.0)
	var pts: PackedVector2Array = UIKit._rounded_points(panel, 26.0)
	var cols := PackedColorArray()
	for p: Vector2 in pts:
		cols.append(UIKit.BG_TOP.lerp(UIKit.BG_BOTTOM, clampf((p.y - panel.position.y) / panel.size.y, 0.0, 1.0)))
	draw_polygon(pts, cols)
	UIKit.confetti(self, Rect2(0.0, panel_top + TABS_H, sz.x, sz.y - panel_top - TABS_H), time_sec, 8, 0.6)

func _draw_hero_label(sz: Vector2) -> void:
	if social == null:
		return
	var skin: Dictionary = EconomyCatalog.get_skin(get_display_skin_id())
	var name_txt: String = tr(StringName(str(skin["name_key"])))
	var rar: int = int(skin["rarity"])
	var w: float = maxf(200.0, UIKit.text_width(name_txt, 24) + 150.0)
	var r := Rect2((sz.x - w) * 0.5, panel_top - 50.0, w, 44.0)
	UIKit.box(self, r, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 14.0, 2.5)
	var chip := Rect2(r.position.x + 10.0, r.position.y + 9.0, 82.0, 26.0)
	UIKit.flat(self, chip, EconomyCatalog.get_rarity_color(rar), 8.0, UIKit.DARK, 2.0)
	UIKit.text_in(self, chip, tr(EconomyCatalog.get_rarity_key(rar)), 13, Color.WHITE, 1.5)
	UIKit.text(self, Vector2(chip.end.x + 10.0, r.position.y + 31.0), name_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 110.0, 24, Color.WHITE, 2.5)
	if tryon_skin_id != "" or tryon_color_id != "":
		var tag := Rect2(r.end.x - 66.0, r.position.y - 16.0, 74.0, 26.0)
		UIKit.flat(self, tag, UIKit.MAGENTA, 8.0, UIKit.DARK, 2.0)
		UIKit.text_in(self, tag, tr(&"LOOK_TRYING"), 14, Color.WHITE, 1.5)

func _draw_content(ci: CanvasItem) -> void:
	if social == null:
		return
	_hits.clear()
	match current_tab:
		TAB_SKINS:
			_draw_skins(ci)
		TAB_PARTS:
			_draw_parts(ci)
		TAB_COLORS:
			_draw_colors(ci)

func _draw_skins(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	var card_w: float = _card_w(sz, 3)
	var oy: float = -scroll_y
	var y: float = 14.0
	for fam: Dictionary in EconomyCatalog.get_skin_families():
		var base: Dictionary = EconomyCatalog.get_skin(str(fam["base_id"]))
		var skins: Array = fam["skins"]
		UIKit.text(ci, Vector2(MARGIN, y + 32.0 + oy), tr(StringName(str(base["name_key"]))), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 200.0, 26, Color.WHITE, 3.0)
		var count_txt: String = tr(&"LOOK_STYLES_OWNED") % [_owned_count(fam), skins.size()]
		var cw: float = UIKit.text_width(count_txt, 16) + 28.0
		var cr := Rect2(sz.x - MARGIN - cw, y + 10.0 + oy, cw, 30.0)
		UIKit.flat(ci, cr, Color(0.10, 0.14, 0.30, 0.85), 15.0)
		UIKit.text_in(ci, cr, count_txt, 16, Color.WHITE, 1.5)
		y += FAMILY_TITLE_H
		for i: int in range(skins.size()):
			var r := Rect2(MARGIN + float(i % 3) * (card_w + GAP), y + float(i / 3) * (SKIN_CARD_H + GAP), card_w, SKIN_CARD_H)
			if r.end.y + oy > -20.0 and r.position.y + oy < scroll_area.size.y + 20.0:
				_draw_skin_card(ci, r, oy, skins[i] as Dictionary)
		y += float(int(ceil(float(skins.size()) / 3.0))) * (SKIN_CARD_H + GAP) + 10.0

func _draw_skin_card(ci: CanvasItem, rect: Rect2, oy: float, skin: Dictionary) -> void:
	var id: String = str(skin["id"])
	var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch("s_" + id))
	var owned: bool = social.owns_skin(id)
	var equipped: bool = social.equipped_skin == id
	var trying: bool = tryon_skin_id == id
	var rar_col: Color = EconomyCatalog.get_rarity_color(int(skin["rarity"]))
	var border: Color = UIKit.GOLD if equipped else (UIKit.MAGENTA if trying else UIKit.DARK)
	UIKit.box(ci, r, UIKit.CARD_BLUE if owned else Color(0.56, 0.64, 0.86), UIKit.CARD_BLUE_BEVEL, border, 16.0, 4.0 if (equipped or trying) else 3.0, 5.0)
	UIKit.flat(ci, Rect2(r.position.x + 10.0, r.position.y + 10.0, r.size.x - 20.0, 20.0), rar_col, 6.0, UIKit.DARK, 1.5)
	UIKit.text_in(ci, Rect2(r.position.x + 10.0, r.position.y + 10.0, r.size.x - 20.0, 20.0), tr(EconomyCatalog.get_rarity_key(int(skin["rarity"]))), 12, Color.WHITE, 1.5)
	UIKit.skin_preview(ci, Rect2(r.position.x + 8.0, r.position.y + 34.0, r.size.x - 16.0, 100.0), previews.get_texture(id) if previews != null else null, rar_col, Color.WHITE if owned else Color(0.78, 0.80, 0.92))
	UIKit.text(ci, Vector2(r.position.x, r.position.y + 154.0), tr(StringName(str(skin["name_key"]))), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color.WHITE, 2.5)
	var bar := Rect2(r.position.x + 12.0, r.end.y - 38.0, r.size.x - 24.0, 28.0)
	if equipped:
		UIKit.flat(ci, bar, Color(0.09, 0.10, 0.14), 6.0)
		UIKit.text_in(ci, bar, tr(&"SHOP_IN_USE"), 17, UIKit.GOLD, 0.0)
	elif owned:
		UIKit.flat(ci, bar, UIKit.GREEN, 6.0, UIKit.DARK, 2.0)
		UIKit.text_in(ci, bar, tr(&"SHOP_USE"), 17, Color.WHITE, 2.0)
	elif int(skin["price"]) > 0:
		UIKit.flat(ci, bar, Color(0.09, 0.10, 0.14), 6.0)
		var price_txt: String = str(int(skin["price"]))
		var tw: float = UIKit.text_width(price_txt, 18)
		var x0: float = bar.get_center().x - (tw + 26.0) * 0.5
		UIKit.coin(ci, Vector2(x0 + 11.0, bar.get_center().y), 21.0)
		UIKit.text_in(ci, Rect2(x0 + 26.0, bar.position.y, tw, bar.size.y), price_txt, 18, Color.WHITE, 0.0)
	else:
		UIKit.flat(ci, bar, Color(0.09, 0.10, 0.14), 6.0)
		UIKit.padlock(ci, Vector2(bar.position.x + 15.0, bar.get_center().y), 15.0, Color(1.0, 0.62, 0.86))
		UIKit.text_in(ci, Rect2(bar.position.x + 24.0, bar.position.y, bar.size.x - 26.0, bar.size.y), _pass_label(EconomyCatalog.find_skin_source(id)), 14, Color(1.0, 0.62, 0.86), 0.0)
	_add_hit(rect, "skin", id)

func _draw_parts(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	var oy: float = -scroll_y
	# Slot chips: the equipped part of each slot, the selected slot in gold.
	var chip_w: float = _card_w(sz, 4)
	for i: int in range(SLOT_ORDER.size()):
		var slot: int = SLOT_ORDER[i]
		var rect := Rect2(MARGIN + float(i) * (chip_w + GAP), 14.0, chip_w, SLOT_ROW_H)
		var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch("slot_%d" % slot))
		var sel: bool = slot == selected_slot
		UIKit.box(ci, r, UIKit.GOLD if sel else UIKit.SLATE, UIKit.GOLD_BEVEL if sel else UIKit.SLATE_BEVEL, UIKit.DARK, 14.0, 2.5, 4.0)
		var pid: StringName = social.loadout.get(slot, PartCatalog.get_base_part_for_slot(slot)) as StringName
		var pdata: PartData = PartCatalog.get_part(pid)
		var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity) if pdata != null else Color.WHITE
		UIKit.flat(ci, Rect2(r.get_center().x - 27.0, r.position.y + 10.0, 54.0, 54.0), Color(0.08, 0.07, 0.16, 0.92), 10.0, r_col, 2.0)
		PartIcons.draw_scaled(ci, pid, Vector2(r.get_center().x, r.position.y + 37.0), 50.0, r_col)
		UIKit.text(ci, Vector2(r.position.x, r.end.y - 14.0), tr(PartCatalog.get_slot_name_translation_key(slot)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color.WHITE, 2.0)
		_add_hit(rect, "slot", str(slot))
	# Part cards for the selected slot.
	var card_w: float = _card_w(sz, 2)
	var parts: Array = PARTS_BY_SLOT[selected_slot]
	var top: float = 14.0 + SLOT_ROW_H + 18.0
	for i: int in range(parts.size()):
		var rect := Rect2(MARGIN + float(i % 2) * (card_w + GAP), top + float(i / 2) * (PART_CARD_H + GAP), card_w, PART_CARD_H)
		_draw_part_card(ci, rect, oy, parts[i] as StringName)
	UIKit.text(ci, Vector2(MARGIN, top + 2.0 * (PART_CARD_H + GAP) + 30.0 + oy), tr(&"LOOK_PARTS_NOTE"), HORIZONTAL_ALIGNMENT_CENTER, sz.x - MARGIN * 2.0, 15, Color(0.92, 0.94, 1.0, 0.9), 1.5)

func _draw_part_card(ci: CanvasItem, rect: Rect2, oy: float, pid: StringName) -> void:
	var pdata: PartData = PartCatalog.get_part(pid)
	if pdata == null:
		return
	var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch("p_" + str(pid)))
	var equipped: bool = social.loadout.get(selected_slot, &"") == pid
	var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
	UIKit.box(ci, r, UIKit.CARD_BLUE, UIKit.CARD_BLUE_BEVEL, UIKit.GOLD if equipped else UIKit.DARK, 16.0, 4.0 if equipped else 3.0, 5.0)
	var strip := Rect2(r.position.x + 10.0, r.position.y + 10.0, r.size.x - 20.0, 20.0)
	UIKit.flat(ci, strip, r_col, 6.0, UIKit.DARK, 1.5)
	UIKit.text_in(ci, strip, tr(PartCatalog.get_rarity_translation_key(pdata.rarity)), 12, Color.WHITE, 1.5)
	var icon_r := Rect2(r.position.x + 12.0, r.position.y + 38.0, 64.0, 64.0)
	UIKit.flat(ci, icon_r, Color(0.08, 0.07, 0.16, 0.92), 12.0, r_col, 2.0)
	PartIcons.draw_scaled(ci, pid, icon_r.get_center(), 60.0, r_col)
	var tx: float = icon_r.end.x + 10.0
	var tw: float = r.end.x - tx - 10.0
	UIKit.text(ci, Vector2(tx, r.position.y + 62.0), tr(pdata.translation_key), HORIZONTAL_ALIGNMENT_LEFT, tw, 18, Color.WHITE, 2.0)
	var lines: PackedStringArray = _wrap(PartCatalog.get_part_trait_description(pid), tw, 14, 2)
	for l_i: int in range(lines.size()):
		UIKit.text(ci, Vector2(tx, r.position.y + 84.0 + float(l_i) * 17.0), lines[l_i], HORIZONTAL_ALIGNMENT_LEFT, tw, 14, Color(0.10, 0.12, 0.26), 0.0)
	var bar := Rect2(r.position.x + 12.0, r.end.y - 40.0, r.size.x - 24.0, 28.0)
	if equipped:
		UIKit.flat(ci, bar, Color(0.09, 0.10, 0.14), 6.0)
		UIKit.text_in(ci, bar, tr(&"SHOP_IN_USE"), 17, UIKit.GOLD, 0.0)
	else:
		UIKit.flat(ci, bar, UIKit.GREEN, 6.0, UIKit.DARK, 2.0)
		UIKit.text_in(ci, bar, tr(&"SHOP_USE"), 17, Color.WHITE, 2.0)
	_add_hit(rect, "part", str(pid))

## Greedy word wrap into at most `max_lines` lines; the last one is cut with an ellipsis.
func _wrap(txt: String, width: float, font_size: int, max_lines: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line: String = ""
	for w: String in txt.split(" "):
		var test: String = w if line == "" else line + " " + w
		if UIKit.text_width(test, font_size) > width and line != "":
			out.append(line)
			line = w
		else:
			line = test
	if line != "":
		out.append(line)
	if out.size() > max_lines:
		out.resize(max_lines)
		out[max_lines - 1] = out[max_lines - 1] + "…"
	return out

func _draw_colors(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	var oy: float = -scroll_y
	UIKit.text(ci, Vector2(MARGIN, 40.0 + oy), tr(&"LOOK_COLORS_HINT"), HORIZONTAL_ALIGNMENT_CENTER, sz.x - MARGIN * 2.0, 17, Color.WHITE, 2.0)
	var card_w: float = _card_w(sz, 3)
	for i: int in range(EconomyCatalog.COLORS.size()):
		var c: Dictionary = EconomyCatalog.COLORS[i]
		var rect := Rect2(MARGIN + float(i % 3) * (card_w + GAP), 54.0 + float(i / 3) * (COLOR_CARD_H + GAP), card_w, COLOR_CARD_H)
		_draw_color_card(ci, rect, oy, c)

func _draw_color_card(ci: CanvasItem, rect: Rect2, oy: float, c: Dictionary) -> void:
	var id: String = str(c["id"])
	var col := Color(str(c["hex"]))
	var r := UIKit.scaled(Rect2(rect.position + Vector2(0.0, oy), rect.size), _punch("c_" + id))
	var unlocked: bool = social.is_color_id_unlocked(id)
	var equipped: bool = social.equipped_color_id == id
	var trying: bool = tryon_color_id == id
	UIKit.box(ci, r, UIKit.CARD_BLUE if unlocked else Color(0.56, 0.64, 0.86), UIKit.CARD_BLUE_BEVEL, UIKit.GOLD if equipped else (UIKit.MAGENTA if trying else UIKit.DARK), 16.0, 4.0 if (equipped or trying) else 3.0, 5.0)
	var center := Vector2(r.get_center().x, r.position.y + 46.0)
	ci.draw_circle(center, 31.0, UIKit.DARK)
	ci.draw_circle(center, 28.0, col)
	_draw_shape(ci, str(c["shape"]), center, 12.0, UIKit.DARK if col.get_luminance() > 0.6 else Color.WHITE)
	UIKit.text(ci, Vector2(r.position.x, r.position.y + 104.0), tr(StringName(str(c["name_key"]))), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color.WHITE, 2.5)
	var bar := Rect2(r.position.x + 12.0, r.end.y - 38.0, r.size.x - 24.0, 28.0)
	if equipped:
		UIKit.flat(ci, bar, Color(0.09, 0.10, 0.14), 6.0)
		UIKit.text_in(ci, bar, tr(&"SHOP_IN_USE"), 17, UIKit.GOLD, 0.0)
	elif unlocked:
		UIKit.flat(ci, bar, UIKit.GREEN, 6.0, UIKit.DARK, 2.0)
		UIKit.text_in(ci, bar, tr(&"SHOP_USE"), 17, Color.WHITE, 2.0)
	else:
		UIKit.flat(ci, bar, Color(0.09, 0.10, 0.14), 6.0)
		UIKit.padlock(ci, Vector2(bar.position.x + 15.0, bar.get_center().y), 15.0, Color(1.0, 0.62, 0.86))
		UIKit.text_in(ci, Rect2(bar.position.x + 24.0, bar.position.y, bar.size.x - 26.0, bar.size.y), _pass_label(EconomyCatalog.find_color_source(id)), 14, Color(1.0, 0.62, 0.86), 0.0)
	_add_hit(rect, "color", id)

## A small white symbol on each colour, so colours differ by shape too (colour-blind players).
func _draw_shape(ci: CanvasItem, shape: String, c: Vector2, s: float, col: Color) -> void:
	match shape:
		"diamond":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)
		"square":
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.8, Vector2(s, s) * 1.6), col)
		"triangle":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		"drop":
			ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.7, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.62, s * 0.05), c + Vector2(-s * 0.62, s * 0.05)]), col)
		"star":
			UIKit.star(ci, c, s * 1.1, col, Color(0, 0, 0, 0))
		"heart":
			ci.draw_circle(c + Vector2(-s * 0.45, -s * 0.25), s * 0.5, col)
			ci.draw_circle(c + Vector2(s * 0.45, -s * 0.25), s * 0.5, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.93, -s * 0.05), c + Vector2(s * 0.93, -s * 0.05), c + Vector2(0, s)]), col)
		_:
			ci.draw_circle(c, s * 0.8, col)

func _draw_overlay(ci: CanvasItem) -> void:
	var sz: Vector2 = get_screen_size()
	_back_rect = Rect2(MARGIN + 8.0, 34.0, 76.0, 74.0)
	UIKit.back_button(ci, _back_rect)
	UIKit.text(ci, Vector2(0.0, 88.0), tr(&"LOOK_HEADER"), HORIZONTAL_ALIGNMENT_CENTER, sz.x - 30.0, 36, Color.WHITE, 3.5)
	_pill_rect = Rect2(sz.x - MARGIN - 8.0 - 136.0, 48.0, 136.0, 50.0)
	UIKit.coin_pill(ci, _pill_rect, str(social.coins if social != null else 0), 22, Color(0.16, 0.24, 0.52, 0.92))

	# Tabs, pinned at the top of the panel.
	_tab_rects.clear()
	var labels: Array[StringName] = [&"LOOK_TAB_SKINS", &"LOOK_TAB_PARTS", &"LOOK_TAB_COLORS"]
	var tab_w: float = _card_w(sz, 3)
	for i: int in range(labels.size()):
		var tr_rect := Rect2(MARGIN + float(i) * (tab_w + GAP), panel_top + 12.0, tab_w, 42.0)
		_tab_rects.append(tr_rect)
		var sel: bool = i == current_tab
		UIKit.box(ci, tr_rect, UIKit.GOLD if sel else Color(0.12, 0.14, 0.26, 0.92), UIKit.GOLD_BEVEL if sel else UIKit.DARK, UIKit.DARK, 12.0, 2.5, 3.0)
		UIKit.text_in(ci, tr_rect, tr(labels[i]), 19, Color.WHITE, 2.0)
	# Fade the cards out under the tabs.
	UIKit.gradient_v(ci, Rect2(0.0, scroll_area.position.y, sz.x, 14.0), Color(UIKit.BG_TOP.r, UIKit.BG_TOP.g, UIKit.BG_TOP.b, 0.9), Color(UIKit.BG_TOP.r, UIKit.BG_TOP.g, UIKit.BG_TOP.b, 0.0))

	# Footer CTA: buy or reach what you are trying on, otherwise play.
	var foot := Rect2(0.0, sz.y - FOOTER_H, sz.x, FOOTER_H)
	UIKit.gradient_v(ci, foot, Color(UIKit.BG_BOTTOM.r, UIKit.BG_BOTTOM.g, UIKit.BG_BOTTOM.b, 0.0), UIKit.BG_BOTTOM)
	_cta_rect = Rect2(MARGIN, sz.y - FOOTER_H + 16.0, sz.x - MARGIN * 2.0, 66.0)
	_draw_cta(ci)

	if _toast_timer > 0.0:
		var tw: float = minf(sz.x - 60.0, UIKit.text_width(_toast, 19) + 44.0)
		var t_rect := Rect2((sz.x - tw) * 0.5, panel_top - 130.0, tw, 46.0)
		UIKit.box(ci, t_rect, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(ci, t_rect, _toast, 19, Color.WHITE, 2.0)

## What the big bottom button does now: "buy" a tried-on shop skin, reach a tried-on pass
## item ("pass"), or "play".
func get_cta_kind() -> String:
	if tryon_skin_id != "":
		return "buy" if int(EconomyCatalog.get_skin(tryon_skin_id)["price"]) > 0 else "pass"
	if tryon_color_id != "":
		return "pass"
	return "play"

func _draw_cta(ci: CanvasItem) -> void:
	_cta_kind = get_cta_kind()
	var label: String = tr(&"HOME_PLAY_NOW")
	if tryon_skin_id != "":
		if _cta_kind == "buy":
			var price: int = _tryon_price()
			UIKit.box(ci, _cta_rect, UIKit.GREEN, UIKit.GREEN_BEVEL, UIKit.DARK, 16.0, 3.0)
			var buy_txt: String = tr(&"LOOK_BUY_FOR")
			var tw: float = UIKit.text_width(buy_txt, 28)
			var pw: float = UIKit.text_width(str(price), 28)
			var total: float = tw + 18.0 + 32.0 + 8.0 + pw
			var x0: float = _cta_rect.get_center().x - total * 0.5
			UIKit.text(ci, Vector2(x0, _cta_rect.position.y + 44.0), buy_txt, HORIZONTAL_ALIGNMENT_LEFT, tw + 4.0, 28, Color.WHITE, 3.0)
			UIKit.coin(ci, Vector2(x0 + tw + 18.0 + 16.0, _cta_rect.get_center().y), 34.0)
			UIKit.text(ci, Vector2(x0 + tw + 18.0 + 40.0, _cta_rect.position.y + 44.0), str(price), HORIZONTAL_ALIGNMENT_LEFT, pw + 4.0, 28, Color.WHITE, 3.0)
			return
		label = tr(&"LOOK_GET_IN_PASS") % _pass_label(EconomyCatalog.find_skin_source(tryon_skin_id))
	elif tryon_color_id != "":
		label = tr(&"LOOK_GET_IN_PASS") % _pass_label(EconomyCatalog.find_color_source(tryon_color_id))
	if _cta_kind == "pass":
		UIKit.box(ci, _cta_rect, UIKit.MAGENTA, UIKit.MAGENTA_BEVEL, UIKit.DARK, 16.0, 3.0)
		UIKit.text_in(ci, _cta_rect, label, 24, Color.WHITE, 3.0)
		return
	UIKit.box(ci, _cta_rect, UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 16.0, 3.0)
	UIKit.text_in(ci, _cta_rect, label, 30, Color.WHITE, 3.0)

## Today's discounted price when the skin is the daily offer, else the wardrobe price.
func _tryon_price() -> int:
	var offers: Dictionary = social.get_daily_offers()
	if str(offers["skin_id"]) == tryon_skin_id and not social.shop_purchased.has(tryon_skin_id):
		return int(offers["skin_price"])
	return int(EconomyCatalog.get_skin(tryon_skin_id)["price"])

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_outside_drag(relative: Vector2) -> void:
	if _press_pos.y > HEADER_H and _press_pos.y < panel_top:
		hero_rotated.emit(relative.x)

func _on_tap(pos: Vector2) -> void:
	if social == null:
		return
	if _back_rect.has_point(pos):
		close()
		return
	if _pill_rect.has_point(pos):
		return
	for i: int in range(_tab_rects.size()):
		if _tab_rects[i].has_point(pos):
			switch_tab(i)
			_click()
			return
	if _cta_rect.has_point(pos):
		activate_cta()
		return
	for hit: Dictionary in _hits:
		if is_hit_in_scroll(hit["rect"] as Rect2, pos):
			activate(str(hit["kind"]), str(hit["id"]))
			return

## What a tap on a card does. Public so tests can drive it.
func activate(kind: String, id: String) -> void:
	match kind:
		"skin":
			_card_punch["s_" + id] = 0.28
			if social.owns_skin(id):
				if tryon_skin_id != "":
					tryon_skin_id = ""
					skin_preview_changed.emit("")
				if social.equip_skin(id):
					_equip_sfx()
				return
			# Locked: try it on. Tapping it again takes it off.
			tryon_skin_id = "" if tryon_skin_id == id else id
			skin_preview_changed.emit(tryon_skin_id)
			_click()
		"slot":
			selected_slot = int(id)
			_card_punch["slot_" + id] = 0.28
			_click()
		"part":
			_card_punch["p_" + id] = 0.28
			if social.set_loadout_part(selected_slot, StringName(id)):
				part_equipped.emit(selected_slot, StringName(id))
				_equip_sfx()
		"color":
			_card_punch["c_" + id] = 0.28
			if social.is_color_id_unlocked(id):
				tryon_color_id = ""
				if social.equip_color(id):
					_equip_sfx()
				color_preview_changed.emit(get_display_color())
				return
			tryon_color_id = "" if tryon_color_id == id else id
			color_preview_changed.emit(get_display_color())
			_click()

func activate_cta() -> void:
	match get_cta_kind():
		"buy":
			var daily: bool = str(social.get_daily_offers()["skin_id"]) == tryon_skin_id and not social.shop_purchased.has(tryon_skin_id)
			buy_requested.emit(tryon_skin_id, daily)
		"pass":
			open_pass_requested.emit()
		_:
			play_requested.emit()

## Called by the menu when a purchase or a pass reward lands, so a tried-on item becomes yours.
func refresh_after_inventory_change() -> void:
	if tryon_skin_id != "" and social.owns_skin(tryon_skin_id):
		var skin_id: String = tryon_skin_id
		tryon_skin_id = ""
		social.equip_skin(skin_id)
		skin_preview_changed.emit("")
	if tryon_color_id != "" and social.is_color_id_unlocked(tryon_color_id):
		var color_id: String = tryon_color_id
		tryon_color_id = ""
		social.equip_color(color_id)
		color_preview_changed.emit(get_display_color())

func show_toast(txt: String) -> void:
	_toast = txt
	_toast_timer = 2.0

func _click() -> void:
	if sound != null:
		sound.play_pickup_pop()

func _equip_sfx() -> void:
	if sound != null:
		sound.play_equip_sfx()
