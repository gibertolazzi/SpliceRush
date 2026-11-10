class_name CustomizationMenu
extends Control

signal part_selected(slot: int, part_id: StringName)
signal color_selected(color: Color)
signal play_pressed(slots: Dictionary, color: Color)
signal hero_rotated(delta_x: float)

const LOGO_TEX: Texture2D = preload("res://game/ui/assets/logo.svg")
const FONT_REGULAR := preload("res://game/ui/fonts/LondrinaSolid-Regular.ttf")
const FONT_BOLD := preload("res://game/ui/fonts/LondrinaSolid-Black.ttf")

const TAB_HEAD: int = 0
const TAB_ARMS: int = 1
const TAB_LEGS: int = 2
const TAB_CORE: int = 3
const TAB_COLOR: int = 4

var current_tab: int = 0
var equipped_slots: Dictionary = {
	PartData.Slot.HEAD: &"base_head",
	PartData.Slot.ARMS: &"base_fist",
	PartData.Slot.LEGS: &"base_boots",
	PartData.Slot.CORE: &"crown_core",
}
var equipped_color: Color = Color.WHITE

var is_loading: bool = false
var loading_progress: float = 0.0
var _loading_timer: float = 0.0

var _pulse_timer: float = 0.0
var _is_dragging: bool = false
var _tab_rects: Array[Rect2] = []
var _option_rects: Array[Dictionary] = [] # { rect: Rect2, data: Variant }
var _play_btn_rect: Rect2 = Rect2()

const COLOR_OPTIONS: Array[Dictionary] = [
	{ "name": "Blu Reale", "color": Color.WHITE, "badge_col": Color(0.18, 0.44, 0.98) },
	{ "name": "Viola Neon", "color": Color(0.42, 0.31, 0.96), "badge_col": Color(0.42, 0.31, 0.96) },
	{ "name": "Rosso Furia", "color": Color(0.95, 0.28, 0.28), "badge_col": Color(0.95, 0.28, 0.28) },
	{ "name": "Verde Tossico", "color": Color(0.25, 0.90, 0.50), "badge_col": Color(0.25, 0.90, 0.50) },
	{ "name": "Oro Abominio", "color": Color(1.0, 0.78, 0.15), "badge_col": Color(1.0, 0.78, 0.15) },
]

func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	if is_loading:
		_loading_timer += delta
		loading_progress = clampf(_loading_timer / 1.10, 0.0, 1.0)
		if _loading_timer >= 1.10:
			is_loading = false
			play_pressed.emit(equipped_slots, equipped_color)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if is_loading:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				# Check play button
				if _play_btn_rect.has_point(mb.position):
					start_loading_flow()
					accept_event()
					return

				# Check tabs
				for t_i: int in range(_tab_rects.size()):
					if _tab_rects[t_i].has_point(mb.position):
						current_tab = t_i
						accept_event()
						return

				# Check options
				for opt: Dictionary in _option_rects:
					var r: Rect2 = opt["rect"] as Rect2
					if r.has_point(mb.position):
						_apply_option(opt["data"])
						accept_event()
						return

				# Check center drag area (y: 120 to 540)
				if mb.position.y >= 120.0 and mb.position.y <= 540.0:
					_is_dragging = true
					accept_event()
			else:
				_is_dragging = false

	elif event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event
		hero_rotated.emit(mm.relative.x)
		accept_event()

func _apply_option(data: Variant) -> void:
	match current_tab:
		TAB_HEAD:
			equipped_slots[PartData.Slot.HEAD] = data as StringName
			part_selected.emit(int(PartData.Slot.HEAD), data as StringName)
		TAB_ARMS:
			equipped_slots[PartData.Slot.ARMS] = data as StringName
			part_selected.emit(int(PartData.Slot.ARMS), data as StringName)
		TAB_LEGS:
			equipped_slots[PartData.Slot.LEGS] = data as StringName
			part_selected.emit(int(PartData.Slot.LEGS), data as StringName)
		TAB_CORE:
			equipped_slots[PartData.Slot.CORE] = data as StringName
			part_selected.emit(int(PartData.Slot.CORE), data as StringName)
		TAB_COLOR:
			equipped_color = data as Color
			color_selected.emit(equipped_color)

func start_loading_flow() -> void:
	is_loading = true
	_loading_timer = 0.0
	loading_progress = 0.0

func _draw() -> void:
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)

	var magenta := Color(1.0, 0.18, 0.58)
	var gold := Color(1.0, 0.78, 0.15)
	var white := Color(0.96, 0.96, 0.98)
	var border_col := Color(0.32, 0.26, 0.52)
	var panel_bg := Color(0.08, 0.06, 0.19, 0.94)

	# 1. TOP HEADER (Logo + Title)
	var header_rect := Rect2(16.0, 16.0, sz.x - 32.0, 102.0)
	_draw_chamfer_box(header_rect, panel_bg, border_col, 8.0)
	if LOGO_TEX != null:
		var lw: float = 120.0
		var lh: float = lw * (300.0 / 401.0)
		draw_texture_rect(LOGO_TEX, Rect2(Vector2(26.0, 22.0), Vector2(lw, lh)), false)

	var title_str: String = tr(&"MENU_CUSTOMIZE_TITLE")
	draw_string(FONT_BOLD, Vector2(158.0, 66.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 180.0, 24, gold)
	var sub_str: String = tr(&"MENU_DRAG_HINT")
	draw_string(FONT_REGULAR, Vector2(158.0, 96.0), sub_str, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 180.0, 15, Color(0.82, 0.80, 0.94))

	# 2. ROTATION HINT OVERLAY IN 3D HERO VIEWPORT
	var rot_hint := "« ↻ »"
	draw_string(FONT_BOLD, Vector2(sz.x * 0.5 - 40.0, 142.0), rot_hint, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color(1.0, 0.78, 0.15, 0.75))

	# 3. BOTTOM CUSTOMIZATION PANEL
	var panel_y: float = clampf(sz.y - 410.0, 520.0, sz.y - 360.0)
	var panel_h: float = sz.y - panel_y - 12.0
	var bot_panel := Rect2(16.0, panel_y, sz.x - 32.0, panel_h)
	_draw_chamfer_box(bot_panel, panel_bg, border_col, 10.0)

	# 4. CATEGORY TABS
	var tab_names := [tr(&"MENU_TAB_HEAD"), tr(&"MENU_TAB_ARMS"), tr(&"MENU_TAB_LEGS"), tr(&"MENU_TAB_CORE"), tr(&"MENU_TAB_COLOR")]
	var tab_icons := ["👑", "🦾", "🦿", "🛡️", "🎨"]
	_tab_rects.clear()
	var tab_w: float = (bot_panel.size.x - 16.0) / float(tab_names.size())
	for i: int in range(tab_names.size()):
		var tr_rect := Rect2(bot_panel.position.x + 8.0 + float(i) * tab_w, bot_panel.position.y + 10.0, tab_w - 4.0, 42.0)
		_tab_rects.append(tr_rect)
		var is_sel: bool = (i == current_tab)
		var bg_col: Color = magenta if is_sel else Color(0.14, 0.12, 0.28, 0.85)
		var b_col: Color = gold if is_sel else border_col
		_draw_chamfer_box(tr_rect, bg_col, b_col, 6.0)
		var tab_label := "%s %s" % [tab_icons[i], tab_names[i]]
		draw_string(FONT_BOLD, Vector2(tr_rect.position.x, tr_rect.position.y + 27.0), tab_label, HORIZONTAL_ALIGNMENT_CENTER, tr_rect.size.x, 15, white)

	# 5. OPTIONS ROW / GRID FOR CURRENT TAB
	_option_rects.clear()
	var opt_area_y: float = bot_panel.position.y + 60.0
	_draw_options_for_tab(bot_panel, opt_area_y, gold, magenta, white, border_col)

	# 6. BIG CTA PLAY BUTTON
	var pulse: float = 0.98 + 0.04 * sin(_pulse_timer)
	var btn_w: float = bot_panel.size.x - 24.0
	var btn_h: float = 64.0
	var btn_x: float = bot_panel.position.x + 12.0
	var btn_y: float = bot_panel.end.y - 78.0
	_play_btn_rect = Rect2(btn_x, btn_y, btn_w, btn_h)

	var draw_btn_rect := Rect2(
		btn_x + btn_w * (1.0 - pulse) * 0.5,
		btn_y + btn_h * (1.0 - pulse) * 0.5,
		btn_w * pulse,
		btn_h * pulse
	)
	_draw_chamfer_box(draw_btn_rect, magenta, gold, 10.0)
	var play_label: String = "⚡ " + tr(&"MENU_PLAY_BUTTON") + " ⚡"
	draw_string(FONT_BOLD, Vector2(draw_btn_rect.position.x, draw_btn_rect.position.y + 42.0), play_label, HORIZONTAL_ALIGNMENT_CENTER, draw_btn_rect.size.x, 26, white)

	# 7. LOADING OVERLAY
	if is_loading:
		_draw_loading_curtain(sz, gold, magenta, white)

func _draw_options_for_tab(panel: Rect2, start_y: float, gold: Color, magenta: Color, white: Color, border_col: Color) -> void:
	if current_tab == TAB_COLOR:
		var item_w: float = (panel.size.x - 20.0) / float(COLOR_OPTIONS.size())
		for idx: int in range(COLOR_OPTIONS.size()):
			var opt: Dictionary = COLOR_OPTIONS[idx]
			var opt_rect := Rect2(panel.position.x + 10.0 + float(idx) * item_w, start_y + 15.0, item_w - 6.0, 95.0)
			_option_rects.append({ "rect": opt_rect, "data": opt["color"] })
			var is_equipped: bool = (equipped_color == (opt["color"] as Color))

			_draw_chamfer_box(opt_rect, Color(0.12, 0.10, 0.24), gold if is_equipped else border_col, 6.0)
			# Color swatch disc/box
			var swatch_rect := Rect2(opt_rect.position.x + (opt_rect.size.x - 42.0) * 0.5, opt_rect.position.y + 12.0, 42.0, 42.0)
			draw_rect(swatch_rect, opt["badge_col"] as Color, true)
			draw_rect(swatch_rect, gold if is_equipped else white, false, 2.0)
			var n_str: String = opt["name"] as String
			draw_string(FONT_REGULAR, Vector2(opt_rect.position.x, opt_rect.position.y + 78.0), n_str, HORIZONTAL_ALIGNMENT_CENTER, opt_rect.size.x, 13, gold if is_equipped else white)
		return

	# Equipment Part options
	var part_list: Array[StringName] = []
	var cur_equipped_part: StringName = &""
	match current_tab:
		TAB_HEAD:
			part_list = [&"base_head", &"laser_eye", &"visor_head", &"spike_helm"]
			cur_equipped_part = equipped_slots.get(PartData.Slot.HEAD, &"base_head") as StringName
		TAB_ARMS:
			part_list = [&"base_fist", &"chainsaw_arm", &"mega_claws"]
			cur_equipped_part = equipped_slots.get(PartData.Slot.ARMS, &"base_fist") as StringName
		TAB_LEGS:
			part_list = [&"base_boots", &"roller_wheels", &"spring_legs"]
			cur_equipped_part = equipped_slots.get(PartData.Slot.LEGS, &"base_boots") as StringName
		TAB_CORE:
			part_list = [&"crown_core", &"shield_core"]
			cur_equipped_part = equipped_slots.get(PartData.Slot.CORE, &"crown_core") as StringName

	var count: int = part_list.size()
	var item_w: float = (panel.size.x - 20.0) / float(count)
	for idx: int in range(count):
		var pid: StringName = part_list[idx]
		var opt_rect := Rect2(panel.position.x + 10.0 + float(idx) * item_w, start_y + 12.0, item_w - 6.0, 105.0)
		_option_rects.append({ "rect": opt_rect, "data": pid })
		var is_equipped: bool = (cur_equipped_part == pid)

		var pdata: PartData = PartCatalog.get_part(pid)
		var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
		var card_bg: Color = Color(0.18, 0.12, 0.32, 0.95) if is_equipped else Color(0.12, 0.10, 0.24, 0.90)
		_draw_chamfer_box(opt_rect, card_bg, gold if is_equipped else r_col, 8.0)

		# Thumbnail badge
		var icon_box := Rect2(opt_rect.position.x + (opt_rect.size.x - 44.0) * 0.5, opt_rect.position.y + 10.0, 44.0, 44.0)
		draw_rect(icon_box, pdata.primary_color, true)
		draw_rect(icon_box, r_col, false, 2.0)
		if is_equipped:
			draw_string(FONT_BOLD, Vector2(icon_box.position.x + 12.0, icon_box.position.y + 32.0), "✓", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 22, gold)

		var part_name: String = tr(pdata.translation_key)
		draw_string(FONT_BOLD, Vector2(opt_rect.position.x + 4.0, opt_rect.position.y + 74.0), part_name, HORIZONTAL_ALIGNMENT_CENTER, opt_rect.size.x - 8.0, 14, gold if is_equipped else white)
		var stat_str: String = "DMG x%.1f" % [pdata.damage_multiplier] if current_tab == TAB_ARMS else ("SPD x%.1f" % [pdata.speed_multiplier] if current_tab == TAB_LEGS else ("MASS +%d" % [pdata.mass_value]))
		draw_string(FONT_REGULAR, Vector2(opt_rect.position.x + 4.0, opt_rect.position.y + 94.0), stat_str, HORIZONTAL_ALIGNMENT_CENTER, opt_rect.size.x - 8.0, 12, Color(0.85, 0.85, 0.95))

func _draw_loading_curtain(sz: Vector2, gold: Color, magenta: Color, white: Color) -> void:
	# Full screen veil
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.03, 0.10, 0.95), true)

	var card_w: float = sz.x - 60.0
	var card_h: float = 280.0
	var card_rect := Rect2((sz.x - card_w) * 0.5, (sz.y - card_h) * 0.5, card_w, card_h)
	_draw_chamfer_box(card_rect, Color(0.09, 0.07, 0.22, 0.98), gold, 12.0)

	# Spinning Splice Logo
	if LOGO_TEX != null:
		var lw: float = 180.0
		var lh: float = lw * (300.0 / 401.0)
		var l_rect := Rect2(card_rect.position.x + (card_w - lw) * 0.5, card_rect.position.y + 24.0, lw, lh)
		draw_texture_rect(LOGO_TEX, l_rect, false)

	# Animated Stage Text
	var stage_text: String = ""
	if loading_progress < 0.40:
		stage_text = tr(&"MENU_MATCHMAKING")
	elif loading_progress < 0.85:
		stage_text = tr(&"MENU_ARENA_LOADING")
	else:
		stage_text = "⚡ ENTRA IN ARENA! ⚡"

	draw_string(FONT_BOLD, Vector2(card_rect.position.x + 20.0, card_rect.position.y + 190.0), stage_text, HORIZONTAL_ALIGNMENT_CENTER, card_w - 40.0, 24, gold)

	# Progress Bar
	var bar_w: float = card_w - 60.0
	var bar_h: float = 16.0
	var bar_x: float = card_rect.position.x + 30.0
	var bar_y: float = card_rect.position.y + 222.0
	var bg_bar := Rect2(bar_x, bar_y, bar_w, bar_h)
	draw_rect(bg_bar, Color(0.14, 0.12, 0.28), true)
	draw_rect(bg_bar, Color(0.32, 0.26, 0.52), false, 1.5)

	var fill_bar := Rect2(bar_x + 2.0, bar_y + 2.0, (bar_w - 4.0) * loading_progress, bar_h - 4.0)
	draw_rect(fill_bar, magenta, true)

func _draw_chamfer_box(rect: Rect2, fill: Color, border: Color, chamfer: float) -> void:
	var pts := PackedVector2Array([
		Vector2(rect.position.x + chamfer, rect.position.y),
		Vector2(rect.end.x - chamfer, rect.position.y),
		Vector2(rect.end.x, rect.position.y + chamfer),
		Vector2(rect.end.x, rect.end.y - chamfer),
		Vector2(rect.end.x - chamfer, rect.end.y),
		Vector2(rect.position.x + chamfer, rect.end.y),
		Vector2(rect.position.x, rect.end.y - chamfer),
		Vector2(rect.position.x, rect.position.y + chamfer)
	])
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, border, 2.0, true)
