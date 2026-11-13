class_name ProfileModal
extends Control

signal closed()

const FONT_BOLD := preload("res://game/ui/fonts/LilitaOne-Regular.ttf")
const CUP_TEX: Texture2D = preload("res://game/ui/assets/cup.svg")
const CROWN_TEX: Texture2D = preload("res://game/ui/assets/crown.svg")

const BG_TOP := Color(0.18, 0.12, 0.42, 0.98)
const BG_BOT := Color(0.08, 0.09, 0.20, 0.98)
const SLATE_BG := Color(0.149, 0.176, 0.259, 1.0)
const SLATE_BEVEL := Color(0.098, 0.118, 0.176, 1.0)
const DARK_BORDER := Color(0.063, 0.075, 0.118, 1.0)
const GOLD_FILL := Color(0.941, 0.745, 0.094, 1.0)
const MAGENTA_FILL := Color(1.0, 0.18, 0.58, 1.0)

var social: SocialManager = null
var hero_color: Color = Color.WHITE
var is_open: bool = false

var _back_rect := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false

func open(active_col: Color = Color.WHITE) -> void:
	hero_color = active_col
	is_open = true
	visible = true
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
	get_viewport().set_input_as_handled()

func _draw() -> void:
	if not is_open:
		return
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)

	# Full-screen vertical Splice Rush gradient
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOT, BG_BOT])
	)

	# Header
	draw_rect(Rect2(0.0, 0.0, sz.x, 82.0), Color(0.08, 0.09, 0.18, 0.96), true)
	draw_line(Vector2(0.0, 82.0), Vector2(sz.x, 82.0), DARK_BORDER, 3.0)

	_back_rect = Rect2(16.0, 18.0, 48.0, 46.0)
	_draw_box(_back_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 12.0, 2.5)
	_draw_text_ol(Vector2(_back_rect.position.x, _back_rect.position.y + 32.0), "‹", HORIZONTAL_ALIGNMENT_CENTER, 48.0, 28, Color.WHITE, 2.0)
	_draw_text_ol(Vector2(80.0, 51.0), tr(&"PROFILE_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 100.0, 26, Color.WHITE, 2.5)

	var uname: String = social.player_username if social != null else "Pinguino"
	var utag: String = social.player_tag if social != null else "#SPL1C3P"
	var trop: int = social.player_trophies if social != null else 2805
	var best_trop: int = social.best_trophies if social != null else 2940
	var wins: int = social.wins_survival if social != null else 42
	var kills: int = social.total_kills if social != null else 314
	var stolen: int = social.parts_stolen if social != null else 628
	var abom: int = social.abomination_count if social != null else 19
	var matches: int = social.matches_played if social != null else 87
	var pass_lvl: int = social.season_level if social != null else 34

	# Hero Battle Card (distinctive vertical Splice Rush showcase)
	var battle_card := Rect2(20.0, 102.0, sz.x - 40.0, 240.0)
	_draw_box(battle_card, Color(0.28, 0.16, 0.56), Color(0.16, 0.09, 0.34), DARK_BORDER, 18.0, 3.0)
	var av_box := Rect2(battle_card.position.x + 22.0, battle_card.position.y + 26.0, 136.0, 136.0)
	_draw_hero_portrait(av_box)

	_draw_text_ol(Vector2(av_box.end.x + 20.0, battle_card.position.y + 66.0), uname, HORIZONTAL_ALIGNMENT_LEFT, 300.0, 32, Color.WHITE, 3.0)
	_draw_text_ol(Vector2(av_box.end.x + 20.0, battle_card.position.y + 98.0), utag, HORIZONTAL_ALIGNMENT_LEFT, 240.0, 17, Color(0.75, 0.78, 0.94), 2.0)

	# Crown tier badge inside battle card
	var rank_pill := Rect2(av_box.end.x + 20.0, battle_card.position.y + 118.0, 190.0, 42.0)
	_draw_box(rank_pill, Color(0.14, 0.10, 0.28), DARK_BORDER, DARK_BORDER, 11.0, 2.0)
	if CROWN_TEX != null:
		draw_texture_rect(CROWN_TEX, Rect2(rank_pill.position.x + 12.0, rank_pill.position.y + 9.0, 26.0, 22.0), false)
	_draw_text_ol(Vector2(rank_pill.position.x + 46.0, rank_pill.position.y + 28.0), "SEASON 1 • LV.%d" % pass_lvl, HORIZONTAL_ALIGNMENT_LEFT, 140.0, 16, GOLD_FILL, 1.5)

	# Footer bar of Battle Card
	draw_rect(Rect2(battle_card.position.x + 3.0, battle_card.end.y - 46.0, battle_card.size.x - 6.0, 43.0), Color(0.10, 0.08, 0.22, 0.90), true)
	_draw_text_ol(Vector2(battle_card.position.x + 22.0, battle_card.end.y - 17.0), tr(&"HOME_MODE_SURVIVAL"), HORIZONTAL_ALIGNMENT_LEFT, 260.0, 18, MAGENTA_FILL, 2.0)

	# Trophies Row (Current vs Record)
	var half_w: float = (sz.x - 52.0) * 0.5
	var cur_r := Rect2(20.0, 362.0, half_w, 108.0)
	var best_r := Rect2(20.0 + half_w + 12.0, 362.0, half_w, 108.0)
	_draw_trophy_card(cur_r, tr(&"PROFILE_TROPHIES"), trop, GOLD_FILL)
	_draw_trophy_card(best_r, tr(&"PROFILE_BEST_TROPHIES"), best_trop, Color(0.45, 0.85, 1.0))

	# Combat Stats Grid (2 columns x 3 rows)
	_draw_text_ol(Vector2(20.0, 506.0), tr(&"PROFILE_STATS_HEADER"), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 40.0, 20, GOLD_FILL, 2.0)
	var stats_list: Array[Dictionary] = [
		{ "label": tr(&"PROFILE_STAT_WINS"), "val": str(wins), "col": Color(0.28, 0.92, 0.50) },
		{ "label": tr(&"PROFILE_STAT_KILLS"), "val": str(kills), "col": Color(1.0, 0.35, 0.35) },
		{ "label": tr(&"PROFILE_STAT_STOLEN"), "val": str(stolen), "col": GOLD_FILL },
		{ "label": tr(&"PROFILE_STAT_ABOM"), "val": str(abom), "col": MAGENTA_FILL },
		{ "label": tr(&"PROFILE_STAT_MATCHES"), "val": str(matches), "col": Color(0.45, 0.85, 1.0) },
		{ "label": tr(&"PROFILE_STAT_PASS"), "val": str(pass_lvl), "col": Color(0.75, 0.55, 1.0) },
	]
	for i: int in range(stats_list.size()):
		var col_i: int = i % 2
		var row_i: int = i / 2
		var sr := Rect2(20.0 + float(col_i) * (half_w + 12.0), 522.0 + float(row_i) * 116.0, half_w, 102.0)
		_draw_box(sr, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 14.0, 2.5)
		var st_d: Dictionary = stats_list[i]
		_draw_text_ol(Vector2(sr.position.x + 10.0, sr.position.y + 32.0), str(st_d["label"]), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 20.0, 15, Color(0.78, 0.82, 0.94), 1.5)
		_draw_text_ol(Vector2(sr.position.x + 10.0, sr.position.y + 78.0), str(st_d["val"]), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 20.0, 34, st_d["col"] as Color, 2.5)

func _draw_trophy_card(rect: Rect2, label: String, val: int, accent: Color) -> void:
	_draw_box(rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 14.0, 2.5)
	_draw_text_ol(Vector2(rect.position.x + 8.0, rect.position.y + 28.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0, 14, Color(0.78, 0.82, 0.94), 1.5)
	if CUP_TEX != null:
		draw_texture_rect(CUP_TEX, Rect2(rect.position.x + 34.0, rect.position.y + 46.0, 34.0, 28.0), false)
	_draw_text_ol(Vector2(rect.position.x + 74.0, rect.position.y + 72.0), str(val), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 82.0, 30, accent, 2.5)

func _draw_hero_portrait(rect: Rect2) -> void:
	_draw_box(rect, Color(0.18, 0.09, 0.32), DARK_BORDER, DARK_BORDER, 14.0, 2.5)
	var c := rect.get_center()
	draw_circle(c + Vector2(0.0, 4.0), 46.0, Color(0.48, 0.22, 0.78, 0.55))
	var body_pts := PackedVector2Array([
		Vector2(rect.position.x + 18.0, rect.end.y - 6.0),
		Vector2(rect.position.x + 30.0, c.y + 22.0),
		Vector2(rect.end.x - 30.0, c.y + 22.0),
		Vector2(rect.end.x - 18.0, rect.end.y - 6.0),
	])
	draw_colored_polygon(body_pts, Color(0.12, 0.11, 0.14) if hero_color == Color.WHITE else hero_color)
	draw_circle(c + Vector2(0.0, 2.0), 30.0, Color(0.96, 0.90, 0.87))
	var hair_pts := PackedVector2Array([
		Vector2(c.x - 22.0, c.y - 12.0),
		Vector2(c.x + 2.0, rect.position.y + 10.0),
		Vector2(c.x + 22.0, c.y - 12.0),
	])
	draw_colored_polygon(hair_pts, Color(0.14, 0.12, 0.16))
	draw_circle(c + Vector2(-10.0, 0.0), 4.5, Color(0.14, 0.12, 0.16))
	draw_circle(c + Vector2(9.0, 0.0), 4.5, Color(0.14, 0.12, 0.16))

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
