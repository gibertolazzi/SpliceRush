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
	PartData.Slot.CORE: &"base_core",
}
var equipped_color: Color = Color.WHITE

var selected_part_id: StringName = &"base_head"
var selected_color: Color = Color.WHITE

var is_loading: bool = false
var loading_progress: float = 0.0
var _loading_timer: float = 0.0

var _pulse_timer: float = 0.0
var _is_dragging: bool = false
var _tab_rects: Array[Rect2] = []
var _option_rects: Array[Dictionary] = [] # { rect: Rect2, data: Variant }
var _equip_btn_rect: Rect2 = Rect2()
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
	selected_part_id = equipped_slots.get(PartData.Slot.HEAD, &"base_head") as StringName
	selected_color = equipped_color

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
				# 1. Play button
				if _play_btn_rect.has_point(mb.position):
					_commit_preview_selection()
					start_loading_flow()
					accept_event()
					return

				# 2. Category Tabs
				for t_i: int in range(_tab_rects.size()):
					if _tab_rects[t_i].has_point(mb.position):
						_switch_tab(t_i)
						accept_event()
						return

				# 3. Equip Button in Detail Card
				if not _equip_btn_rect.has_area() == false and _equip_btn_rect.has_point(mb.position):
					_commit_preview_selection()
					accept_event()
					return

				# 4. Item Options
				for opt: Dictionary in _option_rects:
					var r: Rect2 = opt["rect"] as Rect2
					if r.has_point(mb.position):
						_select_option(opt["data"])
						accept_event()
						return

				# 5. Center drag area for 3D hero rotation (y: 120 to 520)
				if mb.position.y >= 120.0 and mb.position.y <= 520.0:
					_is_dragging = true
					accept_event()
			else:
				_is_dragging = false

	elif event is InputEventMouseMotion and _is_dragging:
		var mm: InputEventMouseMotion = event
		hero_rotated.emit(mm.relative.x)
		accept_event()

func _switch_tab(tab_idx: int) -> void:
	current_tab = tab_idx
	if current_tab == TAB_COLOR:
		selected_color = equipped_color
	else:
		selected_part_id = equipped_slots.get(current_tab, &"base_head") as StringName
		# Preview currently equipped on hero
		part_selected.emit(current_tab, selected_part_id)

func _select_option(data: Variant) -> void:
	if current_tab == TAB_COLOR:
		selected_color = data as Color
		color_selected.emit(selected_color)
	else:
		selected_part_id = data as StringName
		part_selected.emit(current_tab, selected_part_id)

func _commit_preview_selection() -> void:
	if current_tab == TAB_COLOR:
		equipped_color = selected_color
		color_selected.emit(equipped_color)
	else:
		equipped_slots[current_tab] = selected_part_id
		part_selected.emit(current_tab, selected_part_id)

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
	var panel_bg := Color(0.08, 0.06, 0.19, 0.95)

	# 1. TOP HEADER (Logo + Title)
	var header_rect := Rect2(16.0, 16.0, sz.x - 32.0, 96.0)
	_draw_chamfer_box(header_rect, panel_bg, border_col, 8.0)
	if LOGO_TEX != null:
		var lw: float = 114.0
		var lh: float = lw * (300.0 / 401.0)
		draw_texture_rect(LOGO_TEX, Rect2(Vector2(26.0, 20.0), Vector2(lw, lh)), false)

	var title_str: String = tr(&"MENU_CUSTOMIZE_TITLE")
	draw_string(FONT_BOLD, Vector2(154.0, 60.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 175.0, 24, gold)
	var sub_str: String = tr(&"MENU_DRAG_HINT")
	draw_string(FONT_REGULAR, Vector2(154.0, 88.0), sub_str, HORIZONTAL_ALIGNMENT_LEFT, sz.x - 175.0, 15, Color(0.82, 0.80, 0.94))

	# 2. ROTATION HINT OVERLAY IN 3D HERO VIEWPORT
	var rot_hint := "« ↻ »"
	draw_string(FONT_BOLD, Vector2(sz.x * 0.5 - 40.0, 134.0), rot_hint, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color(1.0, 0.78, 0.15, 0.75))

	# 3. BOTTOM CUSTOMIZATION PANEL
	var panel_y: float = clampf(sz.y - 425.0, 510.0, sz.y - 380.0)
	var panel_h: float = sz.y - panel_y - 10.0
	var bot_panel := Rect2(14.0, panel_y, sz.x - 28.0, panel_h)
	_draw_chamfer_box(bot_panel, panel_bg, border_col, 10.0)

	# 4. CATEGORY TABS
	var tab_names := [tr(&"MENU_TAB_HEAD"), tr(&"MENU_TAB_ARMS"), tr(&"MENU_TAB_LEGS"), tr(&"MENU_TAB_CORE"), tr(&"MENU_TAB_COLOR")]
	var tab_icons := ["👑", "🦾", "🦿", "🛡️", "🎨"]
	_tab_rects.clear()
	var tab_w: float = (bot_panel.size.x - 16.0) / float(tab_names.size())
	for i: int in range(tab_names.size()):
		var tr_rect := Rect2(bot_panel.position.x + 8.0 + float(i) * tab_w, bot_panel.position.y + 8.0, tab_w - 4.0, 38.0)
		_tab_rects.append(tr_rect)
		var is_sel: bool = (i == current_tab)
		var bg_col: Color = magenta if is_sel else Color(0.14, 0.12, 0.28, 0.85)
		var b_col: Color = gold if is_sel else border_col
		_draw_chamfer_box(tr_rect, bg_col, b_col, 6.0)
		var tab_label := "%s %s" % [tab_icons[i], tab_names[i]]
		draw_string(FONT_BOLD, Vector2(tr_rect.position.x, tr_rect.position.y + 25.0), tab_label, HORIZONTAL_ALIGNMENT_CENTER, tr_rect.size.x, 14, white)

	# 5. OPTIONS ROW / GRID FOR CURRENT TAB (Point 6)
	_option_rects.clear()
	var opt_area_y: float = bot_panel.position.y + 52.0
	_draw_options_for_tab(bot_panel, opt_area_y, gold, magenta, white, border_col)

	# 6. SELECTED PART DETAIL CARD (Point 7)
	var detail_y: float = opt_area_y + 112.0
	var detail_h: float = 78.0
	var detail_rect := Rect2(bot_panel.position.x + 8.0, detail_y, bot_panel.size.x - 16.0, detail_h)
	_draw_detail_card(detail_rect, gold, magenta, white, border_col)

	# 7. BIG CTA PLAY BUTTON
	var pulse: float = 0.98 + 0.04 * sin(_pulse_timer)
	var btn_w: float = bot_panel.size.x - 20.0
	var btn_h: float = 58.0
	var btn_x: float = bot_panel.position.x + 10.0
	var btn_y: float = bot_panel.end.y - 70.0
	_play_btn_rect = Rect2(btn_x, btn_y, btn_w, btn_h)

	var draw_btn_rect := Rect2(
		btn_x + btn_w * (1.0 - pulse) * 0.5,
		btn_y + btn_h * (1.0 - pulse) * 0.5,
		btn_w * pulse,
		btn_h * pulse
	)
	_draw_chamfer_box(draw_btn_rect, magenta, gold, 10.0)
	var play_label: String = "⚡ " + tr(&"MENU_PLAY_BUTTON") + " ⚡"
	draw_string(FONT_BOLD, Vector2(draw_btn_rect.position.x, draw_btn_rect.position.y + 38.0), play_label, HORIZONTAL_ALIGNMENT_CENTER, draw_btn_rect.size.x, 24, white)

	# 8. LOADING OVERLAY
	if is_loading:
		_draw_loading_curtain(sz, gold, magenta, white)

func _draw_options_for_tab(panel: Rect2, start_y: float, gold: Color, magenta: Color, white: Color, border_col: Color) -> void:
	if current_tab == TAB_COLOR:
		var item_w: float = (panel.size.x - 16.0) / float(COLOR_OPTIONS.size())
		for idx: int in range(COLOR_OPTIONS.size()):
			var opt: Dictionary = COLOR_OPTIONS[idx]
			var opt_rect := Rect2(panel.position.x + 8.0 + float(idx) * item_w, start_y + 4.0, item_w - 4.0, 98.0)
			_option_rects.append({ "rect": opt_rect, "data": opt["color"] })
			var opt_col: Color = opt["color"] as Color
			var is_selected: bool = (selected_color == opt_col)
			var is_equipped: bool = (equipped_color == opt_col)

			var frame_col: Color = gold if is_selected else (magenta if is_equipped else border_col)
			_draw_chamfer_box(opt_rect, Color(0.12, 0.10, 0.24, 0.95), frame_col, 6.0)
			if is_selected:
				# Glowing pulsating border
				_draw_chamfer_box(opt_rect.grow(1.5), Color.TRANSPARENT, Color(1.0, 0.78, 0.15, 0.45 + 0.2 * sin(_pulse_timer)), 6.0)

			# Color swatch disc/box
			var swatch_rect := Rect2(opt_rect.position.x + (opt_rect.size.x - 42.0) * 0.5, opt_rect.position.y + 10.0, 42.0, 42.0)
			draw_rect(swatch_rect, opt["badge_col"] as Color, true)
			draw_rect(swatch_rect, gold if is_selected else white, false, 2.0)
			if is_equipped:
				draw_string(FONT_BOLD, Vector2(swatch_rect.position.x + 11.0, swatch_rect.position.y + 30.0), "✓", HORIZONTAL_ALIGNMENT_CENTER, 20.0, 22, gold)

			var n_str: String = opt["name"] as String
			draw_string(FONT_BOLD, Vector2(opt_rect.position.x, opt_rect.position.y + 74.0), n_str, HORIZONTAL_ALIGNMENT_CENTER, opt_rect.size.x, 12, gold if is_selected else white)
		return

	# Equipment Part options (all 4 rarities per slot: Common, Rare, Epic, Legendary)
	var part_list: Array[StringName] = []
	var cur_equipped_part: StringName = equipped_slots.get(current_tab, &"base_head") as StringName
	match current_tab:
		TAB_HEAD:
			part_list = [&"base_head", &"spike_helm", &"visor_head", &"laser_eye"]
		TAB_ARMS:
			part_list = [&"base_fist", &"chainsaw_arm", &"giant_fist", &"mega_claws"]
		TAB_LEGS:
			part_list = [&"base_boots", &"spring_legs", &"roller_wheels", &"rocket_legs"]
		TAB_CORE:
			part_list = [&"base_core", &"shield_core", &"magnet_core", &"crown_core"]

	var cur_equipped_mass: int = 10
	var cur_eq_pdata: PartData = PartCatalog.get_part(cur_equipped_part)
	if cur_eq_pdata != null:
		cur_equipped_mass = cur_eq_pdata.mass_value

	var count: int = part_list.size()
	var item_w: float = (panel.size.x - 16.0) / float(count)
	for idx: int in range(count):
		var pid: StringName = part_list[idx]
		var opt_rect := Rect2(panel.position.x + 8.0 + float(idx) * item_w, start_y + 4.0, item_w - 4.0, 98.0)
		_option_rects.append({ "rect": opt_rect, "data": pid })
		var is_selected: bool = (selected_part_id == pid)
		var is_equipped: bool = (cur_equipped_part == pid)

		var pdata: PartData = PartCatalog.get_part(pid)
		var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
		var card_bg: Color = Color(0.18, 0.12, 0.32, 0.95) if is_selected else Color(0.11, 0.09, 0.22, 0.90)

		# Rarity glow and frame (Point 6)
		if is_selected:
			_draw_chamfer_box(opt_rect.grow(2.0), Color.TRANSPARENT, Color(r_col.r, r_col.g, r_col.b, 0.50 + 0.25 * sin(_pulse_timer)), 8.0)
			_draw_chamfer_box(opt_rect, card_bg, gold, 8.0)
		elif is_equipped:
			_draw_chamfer_box(opt_rect, card_bg, r_col, 8.0)
		else:
			_draw_chamfer_box(opt_rect, card_bg, Color(r_col.r, r_col.g, r_col.b, 0.40), 8.0)

		# Thumbnail box with stylized vector icon (Point 6)
		var icon_box := Rect2(opt_rect.position.x + (opt_rect.size.x - 42.0) * 0.5, opt_rect.position.y + 8.0, 42.0, 42.0)
		draw_rect(icon_box, Color(0.08, 0.06, 0.16, 0.95), true)
		draw_rect(icon_box, r_col, false, 2.0)
		_draw_part_icon(pid, icon_box, r_col)

		if is_equipped:
			# Gold checkmark in top-right
			draw_string(FONT_BOLD, Vector2(opt_rect.end.x - 18.0, opt_rect.position.y + 16.0), "✓", HORIZONTAL_ALIGNMENT_CENTER, 14.0, 16, gold)

		# Part Name
		var part_name: String = tr(pdata.translation_key)
		draw_string(FONT_BOLD, Vector2(opt_rect.position.x + 2.0, opt_rect.position.y + 68.0), part_name, HORIZONTAL_ALIGNMENT_CENTER, opt_rect.size.x - 4.0, 13, gold if is_selected else white)

		# Enlarged MASS with differential (+/-) relative to equipped (Point 6)
		var diff: int = pdata.mass_value - cur_equipped_mass
		var diff_str: String = ""
		var diff_col: Color = gold
		if diff > 0:
			diff_str = "+%d" % diff
			diff_col = Color(0.28, 0.95, 0.45)
		elif diff < 0:
			diff_str = "%d" % diff
			diff_col = Color(0.95, 0.35, 0.35)
		else:
			diff_str = "="
			diff_col = gold

		var mass_label: String = "%s %d (%s)" % [tr(&"LABEL_MASS"), pdata.mass_value, diff_str]
		draw_string(FONT_BOLD, Vector2(opt_rect.position.x + 2.0, opt_rect.position.y + 88.0), mass_label, HORIZONTAL_ALIGNMENT_CENTER, opt_rect.size.x - 4.0, 13, diff_col)

func _draw_detail_card(rect: Rect2, gold: Color, magenta: Color, white: Color, border_col: Color) -> void:
	if current_tab == TAB_COLOR:
		_draw_chamfer_box(rect, Color(0.06, 0.05, 0.16, 0.96), border_col, 8.0)
		# Left swatch
		var swatch_r := Rect2(rect.position.x + 12.0, rect.position.y + (rect.size.y - 48.0) * 0.5, 48.0, 48.0)
		draw_rect(swatch_r, selected_color, true)
		draw_rect(swatch_r, gold, false, 2.0)

		# Color info
		var col_name: String = "Colore Selezionato"
		for c_opt: Dictionary in COLOR_OPTIONS:
			if c_opt["color"] == selected_color:
				col_name = c_opt["name"] as String
				break
		draw_string(FONT_BOLD, Vector2(rect.position.x + 72.0, rect.position.y + 32.0), col_name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 220.0, 20, gold)
		draw_string(FONT_REGULAR, Vector2(rect.position.x + 72.0, rect.position.y + 56.0), tr(&"LABEL_COLOR_DESC"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 220.0, 14, Color(0.85, 0.82, 0.95))

		# Right CTA Button or Equipped Badge
		var btn_w: float = 124.0
		var btn_h: float = 46.0
		var btn_rect := Rect2(rect.end.x - btn_w - 12.0, rect.position.y + (rect.size.y - btn_h) * 0.5, btn_w, btn_h)
		if selected_color == equipped_color:
			_equip_btn_rect = Rect2()
			_draw_chamfer_box(btn_rect, Color(0.08, 0.22, 0.14, 0.95), Color(0.25, 0.95, 0.45), 6.0)
			draw_string(FONT_BOLD, Vector2(btn_rect.position.x, btn_rect.position.y + 28.0), tr(&"LABEL_EQUIPPED"), HORIZONTAL_ALIGNMENT_CENTER, btn_w, 14, Color(0.35, 0.98, 0.55))
		else:
			_equip_btn_rect = btn_rect
			var b_pulse: float = 0.97 + 0.03 * sin(_pulse_timer)
			_draw_chamfer_box(btn_rect, magenta, gold, 6.0)
			draw_string(FONT_BOLD, Vector2(btn_rect.position.x, btn_rect.position.y + 29.0), tr(&"LABEL_EQUIP_CTA"), HORIZONTAL_ALIGNMENT_CENTER, btn_w, 16, white)
		return

	# Equipment Part Detail Card (Point 7)
	var pdata: PartData = PartCatalog.get_part(selected_part_id)
	if pdata == null:
		return

	var r_col: Color = PartCatalog.get_rarity_color(pdata.rarity)
	_draw_chamfer_box(rect, Color(0.06, 0.05, 0.16, 0.96), r_col, 8.0)

	# Left Icon preview with rarity border
	var icon_sz: float = 54.0
	var icon_box := Rect2(rect.position.x + 10.0, rect.position.y + (rect.size.y - icon_sz) * 0.5, icon_sz, icon_sz)
	draw_rect(icon_box, Color(0.12, 0.10, 0.22, 0.98), true)
	draw_rect(icon_box, r_col, false, 2.0)
	_draw_part_icon(selected_part_id, icon_box, r_col)

	# Center text details
	var text_x: float = rect.position.x + 74.0
	var max_text_w: float = rect.size.x - 215.0

	# Line 1: Part Name + Rarity Tag
	var p_name: String = tr(pdata.translation_key)
	var r_key: StringName = PartCatalog.get_rarity_translation_key(pdata.rarity)
	var header_line: String = "%s  [%s]" % [p_name, tr(r_key)]
	draw_string(FONT_BOLD, Vector2(text_x, rect.position.y + 25.0), header_line, HORIZONTAL_ALIGNMENT_LEFT, max_text_w, 18, white)

	# Line 2: Gameplay Trait / Effect Description (Point 7)
	var trait_str: String = PartCatalog.get_part_trait_description(selected_part_id)
	draw_string(FONT_REGULAR, Vector2(text_x, rect.position.y + 46.0), trait_str, HORIZONTAL_ALIGNMENT_LEFT, max_text_w, 13, Color(0.85, 0.92, 1.0))

	# Line 3: Slot name & Mass
	var slot_tr_key: StringName = PartCatalog.get_slot_name_translation_key(pdata.slot)
	var slot_str: String = "%s: %s • %s: %d" % [tr(&"LABEL_SLOT"), tr(slot_tr_key), tr(&"LABEL_MASS"), pdata.mass_value]
	draw_string(FONT_REGULAR, Vector2(text_x, rect.position.y + 66.0), slot_str, HORIZONTAL_ALIGNMENT_LEFT, max_text_w, 12, Color(0.72, 0.70, 0.88))

	# Right CTA Button or Equipped Badge (Point 7)
	var cur_equipped_part: StringName = equipped_slots.get(current_tab, &"base_head") as StringName
	var btn_w: float = 124.0
	var btn_h: float = 46.0
	var btn_rect := Rect2(rect.end.x - btn_w - 10.0, rect.position.y + (rect.size.y - btn_h) * 0.5, btn_w, btn_h)

	if selected_part_id == cur_equipped_part:
		_equip_btn_rect = Rect2()
		_draw_chamfer_box(btn_rect, Color(0.08, 0.22, 0.14, 0.95), Color(0.25, 0.95, 0.45), 6.0)
		draw_string(FONT_BOLD, Vector2(btn_rect.position.x, btn_rect.position.y + 28.0), tr(&"LABEL_EQUIPPED"), HORIZONTAL_ALIGNMENT_CENTER, btn_w, 14, Color(0.35, 0.98, 0.55))
	else:
		_equip_btn_rect = btn_rect
		_draw_chamfer_box(btn_rect, magenta, gold, 6.0)
		draw_string(FONT_BOLD, Vector2(btn_rect.position.x, btn_rect.position.y + 29.0), tr(&"LABEL_EQUIP_CTA"), HORIZONTAL_ALIGNMENT_CENTER, btn_w, 16, white)

func _draw_part_icon(pid: StringName, box: Rect2, r_col: Color) -> void:
	var c := box.get_center()
	var gold := Color(1.0, 0.78, 0.15)
	var cyan := Color(0.18, 0.88, 1.0)
	var magenta := Color(1.0, 0.18, 0.58)
	var white := Color(0.96, 0.96, 0.98)
	var dark := Color(0.12, 0.10, 0.22)

	match pid:
		&"laser_eye":
			# Cyber visor with red laser aperture and targeting cross
			var v_rect := Rect2(c.x - 15.0, c.y - 7.0, 30.0, 14.0)
			_draw_chamfer_box(v_rect, dark, Color(0.4, 0.4, 0.5), 3.0)
			draw_circle(c, 6.0, Color(0.95, 0.15, 0.15))
			draw_circle(c, 3.0, Color(1.0, 0.9, 0.9))
			draw_line(Vector2(c.x - 14.0, c.y), Vector2(c.x + 14.0, c.y), Color(1.0, 0.25, 0.25, 0.9), 1.5)
			draw_line(Vector2(c.x, c.y - 6.0), Vector2(c.x, c.y + 6.0), Color(1.0, 0.25, 0.25, 0.9), 1.5)

		&"visor_head":
			# Sleek cyber glasses with glowing cyan lenses
			var v_rect := Rect2(c.x - 16.0, c.y - 8.0, 32.0, 16.0)
			_draw_chamfer_box(v_rect, dark, Color(0.3, 0.28, 0.45), 4.0)
			var l1 := Rect2(c.x - 13.0, c.y - 4.0, 11.0, 8.0)
			var l2 := Rect2(c.x + 2.0, c.y - 4.0, 11.0, 8.0)
			draw_rect(l1, cyan, true)
			draw_rect(l2, cyan, true)
			draw_line(Vector2(c.x - 11.0, c.y - 2.0), Vector2(c.x - 4.0, c.y - 2.0), white, 1.5)

		&"spike_helm":
			# Gladiator helmet with 3 sharp golden spikes
			var h_rect := Rect2(c.x - 13.0, c.y - 3.0, 26.0, 16.0)
			_draw_chamfer_box(h_rect, Color(0.25, 0.20, 0.38), r_col, 4.0)
			var pts_mid := PackedVector2Array([Vector2(c.x - 4.0, c.y - 3.0), Vector2(c.x, c.y - 16.0), Vector2(c.x + 4.0, c.y - 3.0)])
			var pts_l := PackedVector2Array([Vector2(c.x - 11.0, c.y - 2.0), Vector2(c.x - 8.0, c.y - 11.0), Vector2(c.x - 5.0, c.y - 3.0)])
			var pts_r := PackedVector2Array([Vector2(c.x + 5.0, c.y - 3.0), Vector2(c.x + 8.0, c.y - 11.0), Vector2(c.x + 11.0, c.y - 2.0)])
			draw_colored_polygon(pts_mid, gold)
			draw_colored_polygon(pts_l, gold)
			draw_colored_polygon(pts_r, gold)

		&"base_head":
			# Blocky hero cube head with visor slit
			var h_rect := Rect2(c.x - 13.0, c.y - 13.0, 26.0, 26.0)
			_draw_chamfer_box(h_rect, Color(0.38, 0.30, 0.62), Color(0.55, 0.45, 0.78), 4.0)
			var eye_rect := Rect2(c.x - 9.0, c.y - 4.0, 18.0, 7.0)
			draw_rect(eye_rect, cyan, true)

		&"chainsaw_arm":
			# Industrial orange motor + gray serrated guide bar
			var mot := Rect2(c.x - 15.0, c.y - 7.0, 11.0, 14.0)
			_draw_chamfer_box(mot, Color(1.0, 0.48, 0.08), gold, 2.0)
			var bar := Rect2(c.x - 4.0, c.y - 4.0, 19.0, 8.0)
			draw_rect(bar, Color(0.72, 0.72, 0.80), true)
			for ti: int in range(4):
				var tx: float = c.x - 2.0 + float(ti) * 4.5
				draw_line(Vector2(tx, c.y - 4.0), Vector2(tx + 2.0, c.y - 7.0), white, 1.5)
				draw_line(Vector2(tx, c.y + 4.0), Vector2(tx + 2.0, c.y + 7.0), white, 1.5)

		&"giant_fist":
			# Massive metallic gauntlet with knuckle plates
			var f_rect := Rect2(c.x - 13.0, c.y - 12.0, 26.0, 24.0)
			_draw_chamfer_box(f_rect, Color(0.85, 0.22, 0.58), gold, 5.0)
			for ki: int in range(4):
				var kx: float = c.x - 10.0 + float(ki) * 5.5
				draw_rect(Rect2(kx, c.y - 10.0, 4.0, 7.0), gold, true)

		&"mega_claws":
			# Razor triple talons with energy tips
			var b_rect := Rect2(c.x - 14.0, c.y - 8.0, 8.0, 16.0)
			_draw_chamfer_box(b_rect, dark, r_col, 2.0)
			for ci: int in range(3):
				var cy: float = c.y - 7.0 + float(ci) * 7.0
				var pts := PackedVector2Array([
					Vector2(c.x - 6.0, cy - 2.0),
					Vector2(c.x + 15.0, cy),
					Vector2(c.x - 6.0, cy + 2.0)
				])
				draw_colored_polygon(pts, gold)
				draw_line(Vector2(c.x + 4.0, cy), Vector2(c.x + 16.0, cy), Color(1.0, 0.2, 0.2), 2.0)

		&"base_fist":
			# Rounded brawler glove
			var f_rect := Rect2(c.x - 12.0, c.y - 12.0, 24.0, 24.0)
			_draw_chamfer_box(f_rect, Color(0.44, 0.35, 0.78), Color(0.65, 0.55, 0.92), 6.0)
			draw_circle(Vector2(c.x + 6.0, c.y + 3.0), 4.5, Color(0.55, 0.45, 0.88))

		&"rocket_legs":
			# Dual rocket thrusters with flame exhaust
			var t1 := Rect2(c.x - 12.0, c.y - 11.0, 9.0, 16.0)
			var t2 := Rect2(c.x + 3.0, c.y - 11.0, 9.0, 16.0)
			_draw_chamfer_box(t1, Color(0.90, 0.15, 0.20), white, 2.0)
			_draw_chamfer_box(t2, Color(0.90, 0.15, 0.20), white, 2.0)
			draw_rect(Rect2(c.x - 11.0, c.y + 4.0, 7.0, 3.0), Color(0.2, 0.2, 0.25), true)
			draw_rect(Rect2(c.x + 4.0, c.y + 4.0, 7.0, 3.0), Color(0.2, 0.2, 0.25), true)
			var f1 := PackedVector2Array([Vector2(c.x - 11.0, c.y + 7.0), Vector2(c.x - 7.5, c.y + 15.0), Vector2(c.x - 4.0, c.y + 7.0)])
			var f2 := PackedVector2Array([Vector2(c.x + 4.0, c.y + 7.0), Vector2(c.x + 7.5, c.y + 15.0), Vector2(c.x + 11.0, c.y + 7.0)])
			draw_colored_polygon(f1, Color(1.0, 0.60, 0.10))
			draw_colored_polygon(f2, Color(1.0, 0.60, 0.10))

		&"roller_wheels":
			# Dual speed wheels with chassis
			draw_rect(Rect2(c.x - 14.0, c.y - 6.0, 28.0, 5.0), Color(0.35, 0.25, 0.50), true)
			draw_circle(Vector2(c.x - 7.0, c.y + 3.0), 8.0, Color(0.16, 0.14, 0.24))
			draw_circle(Vector2(c.x - 7.0, c.y + 3.0), 8.0, magenta, false, 2.0)
			draw_circle(Vector2(c.x - 7.0, c.y + 3.0), 2.5, cyan)
			draw_circle(Vector2(c.x + 7.0, c.y + 3.0), 8.0, Color(0.16, 0.14, 0.24))
			draw_circle(Vector2(c.x + 7.0, c.y + 3.0), 8.0, magenta, false, 2.0)
			draw_circle(Vector2(c.x + 7.0, c.y + 3.0), 2.5, cyan)

		&"spring_legs":
			# High-tension coil spring
			draw_rect(Rect2(c.x - 11.0, c.y - 12.0, 22.0, 4.0), Color(0.3, 0.3, 0.4), true)
			var spr := PackedVector2Array([
				Vector2(c.x - 7.0, c.y - 8.0),
				Vector2(c.x + 7.0, c.y - 4.0),
				Vector2(c.x - 7.0, c.y),
				Vector2(c.x + 7.0, c.y + 4.0),
				Vector2(c.x - 7.0, c.y + 8.0),
				Vector2(c.x + 5.0, c.y + 11.0)
			])
			draw_polyline(spr, cyan, 2.8, true)
			draw_rect(Rect2(c.x - 9.0, c.y + 11.0, 18.0, 4.0), Color(0.4, 0.4, 0.5), true)

		&"base_boots":
			# Armored combat boots
			var b1 := Rect2(c.x - 12.0, c.y - 8.0, 10.0, 18.0)
			var b2 := Rect2(c.x + 2.0, c.y - 8.0, 10.0, 18.0)
			_draw_chamfer_box(b1, Color(0.28, 0.24, 0.38), Color(0.48, 0.44, 0.60), 3.0)
			_draw_chamfer_box(b2, Color(0.28, 0.24, 0.38), Color(0.48, 0.44, 0.60), 3.0)
			draw_rect(Rect2(c.x - 13.0, c.y + 7.0, 12.0, 4.0), Color(0.14, 0.12, 0.20), true)
			draw_rect(Rect2(c.x + 1.0, c.y + 7.0, 12.0, 4.0), Color(0.14, 0.12, 0.20), true)

		&"crown_core":
			# Radiant golden royal crown
			var pts := PackedVector2Array([
				Vector2(c.x - 14.0, c.y + 8.0),
				Vector2(c.x - 14.0, c.y - 3.0),
				Vector2(c.x - 7.0, c.y + 2.0),
				Vector2(c.x, c.y - 11.0),
				Vector2(c.x + 7.0, c.y + 2.0),
				Vector2(c.x + 14.0, c.y - 3.0),
				Vector2(c.x + 14.0, c.y + 8.0)
			])
			draw_colored_polygon(pts, gold)
			pts.append(pts[0])
			draw_polyline(pts, Color(1.0, 0.95, 0.6), 1.5, true)
			draw_circle(Vector2(c.x, c.y - 11.0), 2.2, Color(1.0, 0.2, 0.4))
			draw_circle(Vector2(c.x - 14.0, c.y - 3.0), 1.8, cyan)
			draw_circle(Vector2(c.x + 14.0, c.y - 3.0), 1.8, cyan)

		&"shield_core":
			# Reinforced fortress shield
			var pts := PackedVector2Array([
				Vector2(c.x - 12.0, c.y - 10.0),
				Vector2(c.x + 12.0, c.y - 10.0),
				Vector2(c.x + 12.0, c.y),
				Vector2(c.x, c.y + 13.0),
				Vector2(c.x - 12.0, c.y)
			])
			draw_colored_polygon(pts, Color(0.18, 0.55, 0.92))
			pts.append(pts[0])
			draw_polyline(pts, cyan, 2.0, true)
			draw_line(Vector2(c.x - 9.0, c.y - 2.0), Vector2(c.x + 9.0, c.y - 2.0), white, 1.8)
			draw_line(Vector2(c.x, c.y - 8.0), Vector2(c.x, c.y + 8.0), white, 1.8)

		&"magnet_core":
			# Electromagnetic horseshoe
			var pts := PackedVector2Array([
				Vector2(c.x - 12.0, c.y - 10.0),
				Vector2(c.x - 4.0, c.y - 10.0),
				Vector2(c.x - 4.0, c.y + 2.0),
				Vector2(c.x + 4.0, c.y + 2.0),
				Vector2(c.x + 4.0, c.y - 10.0),
				Vector2(c.x + 12.0, c.y - 10.0),
				Vector2(c.x + 12.0, c.y + 6.0),
				Vector2(c.x, c.y + 13.0),
				Vector2(c.x - 12.0, c.y + 6.0)
			])
			draw_colored_polygon(pts, magenta)
			draw_rect(Rect2(c.x - 12.0, c.y - 10.0, 8.0, 5.0), cyan, true)
			draw_rect(Rect2(c.x + 4.0, c.y - 10.0, 8.0, 5.0), gold, true)

		&"base_core":
			# High-tech cyber core reactor
			var r_box := Rect2(c.x - 12.0, c.y - 12.0, 24.0, 24.0)
			_draw_chamfer_box(r_box, Color(0.24, 0.22, 0.38), cyan, 5.0)
			draw_circle(c, 6.0, cyan)
			draw_circle(c, 2.5, white)

		_:
			draw_rect(box, r_col, true)

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
