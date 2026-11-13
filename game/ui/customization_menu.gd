class_name CustomizationMenu
extends Control

signal part_selected(slot: int, part_id: StringName)
signal color_selected(color: Color)
signal play_pressed(slots: Dictionary, color: Color)
signal hero_rotated(delta_x: float)

const LOGO_TEX: Texture2D = preload("res://game/ui/assets/logo.svg")
const CUP_TEX: Texture2D = preload("res://game/ui/assets/cup.svg")
const SHOP_TEX: Texture2D = preload("res://game/ui/assets/shop.svg")
const SKIN_TEX: Texture2D = preload("res://game/ui/assets/skin.svg")
const FRIENDS_TEX: Texture2D = preload("res://game/ui/assets/friends.svg")
const TASK_TEX: Texture2D = preload("res://game/ui/assets/task.svg")
const CHEST_TEX: Texture2D = preload("res://game/ui/assets/chest.svg")
const CROWN_TEX: Texture2D = preload("res://game/ui/assets/crown.svg")

const InGameSettingsModalScript := preload("res://game/ui/in_game_settings_modal.gd")
const FriendsLobbyModalScript := preload("res://game/ui/friends_lobby_modal.gd")
const HomeSubModalScript := preload("res://game/ui/home_modals.gd")
const FONT_REGULAR := preload("res://game/ui/fonts/LilitaOne-Regular.ttf")
const FONT_BOLD := preload("res://game/ui/fonts/LilitaOne-Regular.ttf")

const TAB_HEAD: int = 0
const TAB_ARMS: int = 1
const TAB_LEGS: int = 2
const TAB_CORE: int = 3
const TAB_COLOR: int = 4

const SLATE_BG := Color(0.149, 0.176, 0.259, 0.96)
const SLATE_BEVEL := Color(0.098, 0.118, 0.176, 1.0)
const DARK_BORDER := Color(0.063, 0.075, 0.118, 1.0)
const GOLD_FILL := Color(0.941, 0.745, 0.094, 1.0)
const GOLD_BEVEL := Color(0.765, 0.565, 0.047, 1.0)

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

var player_name: String = "Pinguino"
var trophies: int = 2805
var season_number: int = 1
var season_level: int = 34
var season_xp: int = 435
var season_xp_max: int = 900
var season_badge_count: int = 7
var is_appearance_open: bool = false

var sound_controller: SoundController = null:
	set(val):
		sound_controller = val
		if settings_modal != null:
			settings_modal.sound_controller = val

var settings_modal: Control = null
var friends_modal: FriendsLobbyModal = null
var sub_modal: HomeSubModal = null
var social: SocialManager = null

var is_loading: bool = false
var loading_progress: float = 0.0
var _loading_timer: float = 0.0

var _pulse_timer: float = 0.0
var _is_dragging: bool = false
var _drag_touch_idx: int = -1
var _last_drag_x: float = 0.0
var _toast_text: String = ""
var _toast_timer: float = 0.0

var _tab_rects: Array[Rect2] = []
var _option_rects: Array[Dictionary] = [] # { rect: Rect2, data: Variant }
var _equip_btn_rect: Rect2 = Rect2()
var _play_btn_rect: Rect2 = Rect2()
var _hamburger_rect: Rect2 = Rect2()
var _shop_btn_rect: Rect2 = Rect2()
var _skin_btn_rect: Rect2 = Rect2()
var _friends_btn_rect: Rect2 = Rect2()
var _task_btn_rect: Rect2 = Rect2()
var _season_btn_rect: Rect2 = Rect2()
var _mode_btn_rect: Rect2 = Rect2()
var _drawer_close_rect: Rect2 = Rect2()
var _lobby_leave_rect: Rect2 = Rect2()

const COLOR_OPTIONS: Array[Dictionary] = [
	{ "name": "Blu Reale", "color": Color.WHITE, "badge_col": Color(0.18, 0.44, 0.98) },
	{ "name": "Viola Neon", "color": Color(0.42, 0.31, 0.96), "badge_col": Color(0.42, 0.31, 0.96) },
	{ "name": "Rosso Furia", "color": Color(0.95, 0.28, 0.28), "badge_col": Color(0.95, 0.28, 0.28) },
	{ "name": "Verde Tossico", "color": Color(0.25, 0.90, 0.50), "badge_col": Color(0.25, 0.90, 0.50) },
	{ "name": "Oro Abominio", "color": Color(1.0, 0.78, 0.15), "badge_col": Color(1.0, 0.78, 0.15) },
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS
	selected_part_id = equipped_slots.get(PartData.Slot.HEAD, &"base_head") as StringName
	selected_color = equipped_color

	social = SocialManager.new()
	social.name = "SocialManager"
	add_child(social)
	_sync_from_social()
	social.lobby_changed.connect(_sync_from_social)
	social.tasks_changed.connect(_sync_from_social)

	settings_modal = InGameSettingsModalScript.new()
	settings_modal.name = "HomeSettingsModal"
	settings_modal.sound_controller = sound_controller
	settings_modal.visible = false
	add_child(settings_modal)

	friends_modal = FriendsLobbyModalScript.new()
	friends_modal.name = "FriendsLobbyModal"
	friends_modal.social = social
	friends_modal.play_with_lobby_requested.connect(func() -> void:
		_commit_preview_selection()
		start_loading_flow()
	)
	add_child(friends_modal)

	sub_modal = HomeSubModalScript.new()
	sub_modal.name = "HomeSubModal"
	sub_modal.social = social
	sub_modal.cosmetic_equipped.connect(func(col: Color) -> void:
		equipped_color = col
		selected_color = col
		color_selected.emit(col)
	)
	add_child(sub_modal)

func _sync_from_social() -> void:
	if social == null:
		return
	player_name = social.player_username
	trophies = social.player_trophies
	season_number = social.season_number
	season_level = social.season_level
	season_xp = social.season_xp
	season_xp_max = social.season_xp_max
	var claimable: int = social.get_claimable_task_count()
	if claimable > 0:
		season_badge_count = claimable
	queue_redraw()

func _process(delta: float) -> void:
	_pulse_timer += delta * 4.0
	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
	if is_loading:
		_loading_timer += delta
		loading_progress = clampf(_loading_timer / 1.10, 0.0, 1.0)
		if _loading_timer >= 1.10:
			is_loading = false
			play_pressed.emit(equipped_slots, equipped_color)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_loading:
		return
	if settings_modal != null and settings_modal.is_open:
		return
	if friends_modal != null and friends_modal.is_open:
		return
	if sub_modal != null and sub_modal.is_open:
		return

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if _handle_press_at(st.position, st.index):
				get_viewport().set_input_as_handled()
		elif st.index == _drag_touch_idx:
			_is_dragging = false
			_drag_touch_idx = -1
	elif event is InputEventScreenDrag and _is_dragging:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _drag_touch_idx:
			hero_rotated.emit(sd.relative.x)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _handle_press_at(mb.position, 0):
					get_viewport().set_input_as_handled()
			else:
				_is_dragging = false
				_drag_touch_idx = -1
	elif event is InputEventMouseMotion and _is_dragging and _drag_touch_idx == 0:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		hero_rotated.emit(mm.relative.x)
		get_viewport().set_input_as_handled()

func _handle_press_at(pos: Vector2, pointer_idx: int) -> bool:
	if is_appearance_open:
		if _drawer_close_rect.has_point(pos):
			is_appearance_open = false
			queue_redraw()
			return true
		if _play_btn_rect.has_point(pos):
			_commit_preview_selection()
			start_loading_flow()
			return true
		for t_i: int in range(_tab_rects.size()):
			if _tab_rects[t_i].has_point(pos):
				_switch_tab(t_i)
				return true
		if _equip_btn_rect.has_area() and _equip_btn_rect.has_point(pos):
			_commit_preview_selection()
			return true
		for opt: Dictionary in _option_rects:
			var r: Rect2 = opt["rect"] as Rect2
			if r.has_point(pos):
				_select_option(opt["data"])
				return true
		if pos.y >= 100.0 and pos.y <= 520.0:
			_is_dragging = true
			_drag_touch_idx = pointer_idx
			_last_drag_x = pos.x
			return true
		return false

	# Home screen interactions
	if _hamburger_rect.has_point(pos):
		if settings_modal != null:
			settings_modal.open()
		return true
	if _play_btn_rect.has_point(pos):
		_commit_preview_selection()
		start_loading_flow()
		return true
	if _skin_btn_rect.has_point(pos):
		is_appearance_open = true
		queue_redraw()
		return true
	if _shop_btn_rect.has_point(pos):
		if sub_modal != null:
			sub_modal.open_shop(equipped_color)
		return true
	if _friends_btn_rect.has_point(pos):
		if friends_modal != null:
			friends_modal.open(FriendsLobbyModal.TAB_FRIENDS)
		return true
	if _task_btn_rect.has_point(pos) or _season_btn_rect.has_point(pos):
		if sub_modal != null:
			sub_modal.open_tasks()
		return true
	if _mode_btn_rect.has_point(pos):
		if social != null:
			social.selected_mode = "frenzy" if social.selected_mode == "survival" else "survival"
			social.save_state()
			queue_redraw()
		return true
	if _lobby_leave_rect.has_area() and _lobby_leave_rect.has_point(pos):
		if social != null:
			social.leave_or_kick_lobby("local_player")
		return true
	if pos.y >= 110.0 and pos.y <= 660.0:
		_is_dragging = true
		_drag_touch_idx = pointer_idx
		_last_drag_x = pos.x
		return true
	return false

func _switch_tab(tab_idx: int) -> void:
	current_tab = tab_idx
	if current_tab == TAB_COLOR:
		selected_color = equipped_color
	else:
		selected_part_id = equipped_slots.get(current_tab, &"base_head") as StringName
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

	if is_appearance_open:
		_draw_appearance_drawer(sz)
	else:
		_draw_home_screen(sz)

	if _toast_timer > 0.0 and _toast_text != "":
		var tw: float = 230.0
		var th: float = 36.0
		var t_rect := Rect2((sz.x - tw) * 0.5, 94.0, tw, th)
		_draw_brawl_box(t_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 10.0, 2.0)
		_draw_outlined_text(FONT_BOLD, Vector2(t_rect.position.x, t_rect.position.y + 24.0), _toast_text, HORIZONTAL_ALIGNMENT_CENTER, tw, 17, Color.WHITE, 2.0)

	if is_loading:
		_draw_loading_curtain(sz, GOLD_FILL, Color(1.0, 0.18, 0.58), Color(0.96, 0.96, 0.98))

func _draw_home_screen(sz: Vector2) -> void:
	var margin_x: float = 20.0
	var top_y: float = 14.0

	# 1. TOP BAR: Profile Pill (left) + Hamburger Button (right)
	var ham_w: float = 82.0
	var ham_h: float = 68.0
	_hamburger_rect = Rect2(sz.x - margin_x - ham_w, top_y, ham_w, ham_h)

	var prof_w: float = _hamburger_rect.position.x - margin_x - 16.0
	var prof_rect := Rect2(margin_x, top_y, prof_w, ham_h)
	_draw_brawl_box(prof_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 14.0, 2.5)

	# Avatar portrait box
	var av_rect := Rect2(prof_rect.position.x + 9.0, prof_rect.position.y + 8.0, 52.0, 52.0)
	_draw_hero_avatar(av_rect)

	# Player name + Cup + Trophies
	_draw_outlined_text(FONT_BOLD, Vector2(av_rect.end.x + 12.0, prof_rect.position.y + 33.0), player_name, HORIZONTAL_ALIGNMENT_LEFT, prof_w - 86.0, 24, Color.WHITE, 2.5)
	if CUP_TEX != null:
		draw_texture_rect(CUP_TEX, Rect2(av_rect.end.x + 12.0, prof_rect.position.y + 41.0, 20.0, 17.0), false)
	_draw_outlined_text(FONT_BOLD, Vector2(av_rect.end.x + 37.0, prof_rect.position.y + 56.0), str(trophies), HORIZONTAL_ALIGNMENT_LEFT, 160.0, 19, Color(0.98, 0.78, 0.15), 2.0)

	# Hamburger button
	_draw_brawl_box(_hamburger_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 14.0, 2.5)
	var bar_w: float = 36.0
	var bar_h: float = 5.5
	var bar_x: float = _hamburger_rect.position.x + (_hamburger_rect.size.x - bar_w) * 0.5
	var bar_y0: float = _hamburger_rect.position.y + 18.0
	for b_i: int in range(3):
		var bar_r := Rect2(bar_x, bar_y0 + float(b_i) * 12.0, bar_w, bar_h)
		var bar_sb := StyleBoxFlat.new()
		bar_sb.bg_color = Color.WHITE
		bar_sb.set_corner_radius_all(3)
		draw_style_box(bar_sb, bar_r)

	# 2. SIDE ACTION BUTTONS (NEGOZIO, ASPETTO, AMICI, TASK)
	var btn_w: float = 92.0
	var btn_h: float = 82.0
	var row1_y: float = 118.0
	var row2_y: float = 212.0

	_shop_btn_rect = Rect2(margin_x, row1_y, btn_w, btn_h)
	_skin_btn_rect = Rect2(margin_x, row2_y, btn_w, btn_h)
	_friends_btn_rect = Rect2(sz.x - margin_x - btn_w, row1_y, btn_w, btn_h)
	_task_btn_rect = Rect2(sz.x - margin_x - btn_w, row2_y, btn_w, btn_h)

	_draw_side_icon_btn(_shop_btn_rect, SHOP_TEX, Vector2(46.0, 32.0), tr(&"HOME_SHOP"))
	_draw_side_icon_btn(_skin_btn_rect, SKIN_TEX, Vector2(46.0, 35.0), tr(&"HOME_APPEARANCE"))
	_draw_side_icon_btn(_friends_btn_rect, FRIENDS_TEX, Vector2(54.0, 36.0), tr(&"HOME_FRIENDS"))
	_draw_side_icon_btn(_task_btn_rect, TASK_TEX, Vector2(39.0, 39.0), tr(&"HOME_TASKS"))

	# 3. BOTTOM CTA + MODE BAR + SEASON PASS CARD
	var cta_h: float = 74.0
	var cta_y: float = sz.y - 34.0 - cta_h
	_play_btn_rect = Rect2(margin_x, cta_y, sz.x - margin_x * 2.0, cta_h)

	var mode_h: float = 70.0
	var mode_y: float = cta_y - 14.0 - mode_h
	_mode_btn_rect = Rect2(margin_x, mode_y, sz.x - margin_x * 2.0, mode_h)

	# Season Pass card (right side, above mode bar)
	var sp_w: float = 248.0
	var sp_h: float = 84.0
	var sp_x: float = sz.x - margin_x - sp_w
	var sp_y: float = mode_y - 16.0 - sp_h
	_season_btn_rect = Rect2(sp_x, sp_y, sp_w, sp_h)
	_draw_brawl_box(_season_btn_rect, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 13.0, 2.5)

	# Season title
	var season_str: String = tr(&"HOME_SEASON") % season_number
	_draw_outlined_text(FONT_BOLD, Vector2(sp_x + 12.0, sp_y + 28.0), season_str, HORIZONTAL_ALIGNMENT_LEFT, 150.0, 20, Color.WHITE, 2.5)

	# Progress bar
	var pb_rect := Rect2(sp_x + 14.0, sp_y + 42.0, sp_w - 28.0, 26.0)
	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(0.10, 0.12, 0.20, 1.0)
	track_sb.set_corner_radius_all(11)
	track_sb.set_border_width_all(2)
	track_sb.border_color = DARK_BORDER
	draw_style_box(track_sb, pb_rect)

	var ratio: float = clampf(float(season_xp) / float(maxi(1, season_xp_max)), 0.0, 1.0)
	var fill_w: float = maxf(0.0, (pb_rect.size.x - 4.0) * ratio)
	if fill_w > 6.0:
		var fill_pts := PackedVector2Array([
			Vector2(pb_rect.position.x + 2.0, pb_rect.position.y + 2.0),
			Vector2(pb_rect.position.x + 2.0 + fill_w, pb_rect.position.y + 2.0),
			Vector2(pb_rect.position.x + 2.0 + fill_w, pb_rect.end.y - 2.0),
			Vector2(pb_rect.position.x + 2.0, pb_rect.end.y - 2.0),
		])
		var fill_cols := PackedColorArray([
			Color(1.0, 0.13, 0.56),
			Color(1.0, 0.62, 0.10),
			Color(1.0, 0.62, 0.10),
			Color(1.0, 0.13, 0.56),
		])
		draw_polygon(fill_pts, fill_cols)

	# Level badge circle on left end of progress bar
	var lvl_c := Vector2(pb_rect.position.x + 11.0, pb_rect.position.y + pb_rect.size.y * 0.5)
	draw_circle(lvl_c, 16.0, Color.WHITE)
	draw_circle(lvl_c, 13.5, DARK_BORDER)
	_draw_outlined_text(FONT_BOLD, Vector2(lvl_c.x - 14.0, lvl_c.y + 6.0), str(season_level), HORIZONTAL_ALIGNMENT_CENTER, 28.0, 16, Color.WHITE, 0.0)

	# Progress text
	var xp_str: String = "%d/%d" % [season_xp, season_xp_max]
	_draw_outlined_text(FONT_BOLD, Vector2(pb_rect.position.x + 24.0, pb_rect.position.y + 19.0), xp_str, HORIZONTAL_ALIGNMENT_CENTER, pb_rect.size.x - 28.0, 17, Color.WHITE, 2.0)

	# Chest overlapping top-right of Season card
	if CHEST_TEX != null:
		draw_texture_rect(CHEST_TEX, Rect2(sp_x + sp_w - 118.0, sp_y - 66.0, 124.0, 121.0), false)

	# Red notification badge
	if season_badge_count > 0:
		var badge_c := Vector2(sp_x + sp_w - 20.0, sp_y - 16.0)
		draw_circle(badge_c, 15.0, DARK_BORDER)
		draw_circle(badge_c, 13.0, Color(0.93, 0.11, 0.14))
		_draw_outlined_text(FONT_BOLD, Vector2(badge_c.x - 13.0, badge_c.y + 6.0), str(season_badge_count), HORIZONTAL_ALIGNMENT_CENTER, 26.0, 17, Color.WHITE, 1.5)

	# Mode selector bar ("Sopravvivenza" / "Frenzy Rapida")
	_draw_brawl_box(_mode_btn_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 14.0, 2.5)
	if CROWN_TEX != null:
		draw_texture_rect(CROWN_TEX, Rect2(_mode_btn_rect.position.x + 22.0, _mode_btn_rect.position.y + 21.0, 33.0, 27.0), false)
	var mode_key: StringName = &"HOME_MODE_FRENZY" if (social != null and social.selected_mode == "frenzy") else &"HOME_MODE_SURVIVAL"
	_draw_outlined_text(FONT_BOLD, Vector2(_mode_btn_rect.position.x + 70.0, _mode_btn_rect.position.y + 45.0), tr(mode_key), HORIZONTAL_ALIGNMENT_LEFT, 320.0, 29, Color.WHITE, 2.5)

	# Lobby Party Strip (shown when friends are in lobby or invited)
	_lobby_leave_rect = Rect2()
	if social != null and (social.lobby_members.size() > 1 or not social.pending_invites.is_empty()):
		var bar_r := Rect2(124.0, 96.0, sz.x - 248.0, 48.0)
		_draw_brawl_box(bar_r, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 12.0, 2.0)
		var mem_names: PackedStringArray = PackedStringArray()
		for m: Dictionary in social.lobby_members:
			if not bool(m.get("is_host", false)):
				mem_names.append(str(m.get("username", "")))
		var lobby_txt: String = (tr(&"LOBBY_HEADER") % [social.lobby_members.size(), SocialManager.MAX_LOBBY_SIZE])
		if not mem_names.is_empty():
			lobby_txt = ", ".join(mem_names) + " (" + tr(&"LOBBY_READY") + ")"
		elif not social.pending_invites.is_empty():
			lobby_txt = tr(&"LOBBY_WAITING")
		_draw_outlined_text(FONT_BOLD, Vector2(bar_r.position.x + 10.0, bar_r.position.y + 30.0), lobby_txt, HORIZONTAL_ALIGNMENT_LEFT, bar_r.size.x - 66.0, 15, Color(0.28, 0.92, 0.50), 1.5)
		_lobby_leave_rect = Rect2(bar_r.end.x - 56.0, bar_r.position.y + 9.0, 48.0, 30.0)
		_draw_brawl_box(_lobby_leave_rect, Color(0.85, 0.22, 0.26), Color(0.58, 0.12, 0.16), DARK_BORDER, 8.0, 1.5)
		_draw_outlined_text(FONT_BOLD, Vector2(_lobby_leave_rect.position.x, _lobby_leave_rect.position.y + 20.0), tr(&"LOBBY_LEAVE"), HORIZONTAL_ALIGNMENT_CENTER, 48.0, 12, Color.WHITE, 1.5)

	# Refresh / cycle arrows icon on right of mode bar
	var cyc_c := Vector2(_mode_btn_rect.end.x - 40.0, _mode_btn_rect.position.y + _mode_btn_rect.size.y * 0.5)
	_draw_cycle_icon(cyc_c, 14.0, Color.WHITE)

	# Primary CTA button ("GIOCA ORA")
	_draw_brawl_box(_play_btn_rect, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 14.0, 2.5)
	_draw_outlined_text(FONT_BOLD, Vector2(_play_btn_rect.position.x, _play_btn_rect.position.y + 48.0), tr(&"HOME_PLAY_NOW"), HORIZONTAL_ALIGNMENT_CENTER, _play_btn_rect.size.x, 32, Color.WHITE, 3.0)

func _draw_side_icon_btn(rect: Rect2, icon_tex: Texture2D, icon_sz: Vector2, label: String) -> void:
	_draw_brawl_box(rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 14.0, 2.5)
	if icon_tex != null:
		var ix: float = rect.position.x + (rect.size.x - icon_sz.x) * 0.5
		var iy: float = rect.position.y + 11.0 + (40.0 - icon_sz.y) * 0.5
		draw_texture_rect(icon_tex, Rect2(ix, iy, icon_sz.x, icon_sz.y), false)
	_draw_outlined_text(FONT_BOLD, Vector2(rect.position.x + 2.0, rect.end.y - 12.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4.0, 14, Color.WHITE, 2.0)

func _draw_brawl_box(rect: Rect2, fill: Color, bevel: Color, border: Color, radius: float, border_w: float) -> void:
	var bevel_sb := StyleBoxFlat.new()
	bevel_sb.bg_color = bevel
	bevel_sb.set_corner_radius_all(int(radius))
	bevel_sb.set_border_width_all(int(ceilf(border_w)))
	bevel_sb.border_color = border
	draw_style_box(bevel_sb, Rect2(rect.position.x, rect.position.y + 3.0, rect.size.x, rect.size.y))

	var top_sb := StyleBoxFlat.new()
	top_sb.bg_color = fill
	top_sb.set_corner_radius_all(int(radius))
	top_sb.set_border_width_all(int(ceilf(border_w)))
	top_sb.border_color = border
	draw_style_box(top_sb, rect)

func _draw_outlined_text(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, font_size: int, color: Color, outline_px: float) -> void:
	if outline_px > 0.0:
		var ol_col := DARK_BORDER
		var offsets: Array[Vector2] = [
			Vector2(-outline_px, 0.0), Vector2(outline_px, 0.0),
			Vector2(0.0, -outline_px), Vector2(0.0, outline_px),
			Vector2(-outline_px * 0.7, -outline_px * 0.7), Vector2(outline_px * 0.7, -outline_px * 0.7),
			Vector2(-outline_px * 0.7, outline_px * 0.7), Vector2(outline_px * 0.7, outline_px * 0.7),
		]
		for off: Vector2 in offsets:
			draw_string(font, pos + off, text, align, width, font_size, ol_col)
		draw_string(font, pos + Vector2(0.0, outline_px + 1.0), text, align, width, font_size, ol_col)
	draw_string(font, pos, text, align, width, font_size, color)

func _draw_hero_avatar(rect: Rect2) -> void:
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.18, 0.09, 0.30, 1.0)
	bg_sb.set_corner_radius_all(8)
	bg_sb.set_border_width_all(2)
	bg_sb.border_color = DARK_BORDER
	draw_style_box(bg_sb, rect)

	var c := rect.get_center()
	draw_circle(c + Vector2(0.0, 2.0), 18.0, Color(0.45, 0.20, 0.72, 0.55))
	# Shoulders / dark jacket
	var body_pts := PackedVector2Array([
		Vector2(rect.position.x + 7.0, rect.end.y - 3.0),
		Vector2(rect.position.x + 12.0, c.y + 8.0),
		Vector2(rect.end.x - 12.0, c.y + 8.0),
		Vector2(rect.end.x - 7.0, rect.end.y - 3.0),
	])
	draw_colored_polygon(body_pts, Color(0.12, 0.11, 0.14))
	# Face
	draw_circle(c + Vector2(0.0, 1.0), 11.5, Color(0.96, 0.90, 0.87))
	# Mohawk hair
	var hair_pts := PackedVector2Array([
		Vector2(c.x - 9.0, c.y - 5.0),
		Vector2(c.x + 1.0, rect.position.y + 4.0),
		Vector2(c.x + 9.0, c.y - 5.0),
	])
	draw_colored_polygon(hair_pts, Color(0.14, 0.12, 0.16))
	# Eyes
	draw_circle(c + Vector2(-4.0, 0.0), 2.1, Color(0.14, 0.12, 0.16))
	draw_circle(c + Vector2(3.5, 0.0), 2.1, Color(0.14, 0.12, 0.16))

func _draw_cycle_icon(center: Vector2, rad: float, col: Color) -> void:
	draw_arc(center, rad, deg_to_rad(25.0), deg_to_rad(175.0), 16, col, 3.2, true)
	draw_arc(center, rad, deg_to_rad(205.0), deg_to_rad(355.0), 16, col, 3.2, true)
	var top_tip := center + Vector2(rad * 0.95, -2.0)
	draw_colored_polygon(PackedVector2Array([top_tip + Vector2(-6.0, -5.0), top_tip + Vector2(4.0, -4.0), top_tip + Vector2(0.0, 5.0)]), col)
	var bot_tip := center + Vector2(-rad * 0.95, 2.0)
	draw_colored_polygon(PackedVector2Array([bot_tip + Vector2(6.0, 5.0), bot_tip + Vector2(-4.0, 4.0), bot_tip + Vector2(0.0, -5.0)]), col)

func _draw_appearance_drawer(sz: Vector2) -> void:
	var magenta := Color(1.0, 0.18, 0.58)
	var gold := Color(1.0, 0.78, 0.15)
	var white := Color(0.96, 0.96, 0.98)
	var border_col := Color(0.32, 0.26, 0.52)
	var panel_bg := Color(0.08, 0.06, 0.19, 0.95)

	var panel_y: float = clampf(sz.y - 425.0, 510.0, sz.y - 380.0)
	var panel_h: float = sz.y - panel_y - 10.0
	var bot_panel := Rect2(14.0, panel_y, sz.x - 28.0, panel_h)
	_draw_chamfer_box(bot_panel, panel_bg, border_col, 10.0)

	# Close drawer button
	_drawer_close_rect = Rect2(bot_panel.end.x - 44.0, bot_panel.position.y - 42.0, 38.0, 34.0)
	_draw_brawl_box(_drawer_close_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
	_draw_outlined_text(FONT_BOLD, Vector2(_drawer_close_rect.position.x, _drawer_close_rect.position.y + 24.0), "✕", HORIZONTAL_ALIGNMENT_CENTER, 38.0, 18, Color.WHITE, 1.5)

	# CATEGORY TABS
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

	_option_rects.clear()
	var opt_area_y: float = bot_panel.position.y + 52.0
	_draw_options_for_tab(bot_panel, opt_area_y, gold, magenta, white, border_col)

	var detail_y: float = opt_area_y + 112.0
	var detail_h: float = 78.0
	var detail_rect := Rect2(bot_panel.position.x + 8.0, detail_y, bot_panel.size.x - 16.0, detail_h)
	_draw_detail_card(detail_rect, gold, magenta, white, border_col)

	var btn_w: float = bot_panel.size.x - 20.0
	var btn_h: float = 58.0
	var btn_x: float = bot_panel.position.x + 10.0
	var btn_y: float = bot_panel.end.y - 70.0
	_play_btn_rect = Rect2(btn_x, btn_y, btn_w, btn_h)
	_draw_brawl_box(_play_btn_rect, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 12.0, 2.5)
	_draw_outlined_text(FONT_BOLD, Vector2(_play_btn_rect.position.x, _play_btn_rect.position.y + 39.0), tr(&"HOME_PLAY_NOW"), HORIZONTAL_ALIGNMENT_CENTER, _play_btn_rect.size.x, 26, Color.WHITE, 2.5)

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
