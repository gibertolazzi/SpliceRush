class_name CustomizationMenu
extends Control

signal part_selected(slot: int, part_id: StringName)
signal color_selected(color: Color)
signal play_pressed(slots: Dictionary, color: Color)
signal hero_rotated(delta_x: float)
## The skin to show on the hero changed (a try-on in Aspetto, or back to the equipped one).
signal skin_preview_changed(skin_id: String)

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
const SeasonPassModalScript := preload("res://game/ui/season_pass_modal.gd")
const ProfileModalScript := preload("res://game/ui/profile_modal.gd")
const ShopScreenScript := preload("res://game/ui/shop_screen.gd")
const SkinPreviewRendererScript := preload("res://game/ui/skin_preview_renderer.gd")
const AppearanceScreenScript := preload("res://game/ui/appearance_screen.gd")
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

var sound_controller: SoundController = null:
	set(val):
		sound_controller = val
		if settings_modal != null:
			settings_modal.sound_controller = val
		if shop_screen != null:
			shop_screen.sound = val
		if season_pass_modal != null:
			season_pass_modal.sound = val
		if appearance_screen != null:
			appearance_screen.sound = val

var settings_modal: Control = null
var friends_modal: FriendsLobbyModal = null
var season_pass_modal: SeasonPassModal = null
var profile_modal: ProfileModal = null
var social: SocialManager = null
var shop_screen: ShopScreen = null
var skin_previews: SkinPreviewRenderer = null
var appearance_screen: AppearanceScreen = null
var account: AccountService = null
var coins: int = 0
var _coin_btn_rect: Rect2 = Rect2()

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
var _profile_rect: Rect2 = Rect2()
var _hamburger_rect: Rect2 = Rect2()
var _shop_btn_rect: Rect2 = Rect2()
var _skin_btn_rect: Rect2 = Rect2()
var _friends_btn_rect: Rect2 = Rect2()
var _task_btn_rect: Rect2 = Rect2()
var _season_btn_rect: Rect2 = Rect2()
var _mode_btn_rect: Rect2 = Rect2()
var _lobby_leave_rect: Rect2 = Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS
	selected_part_id = equipped_slots.get(PartData.Slot.HEAD, &"base_head") as StringName
	selected_color = equipped_color

	social = SocialManager.new()
	social.name = "SocialManager"
	# Headless runs are tests and tools, never a player: keep them out of the real save file.
	social.persistence_enabled = DisplayServer.get_name() != "headless"
	add_child(social)
	_sync_from_social()
	social.lobby_changed.connect(_sync_from_social)
	social.tasks_changed.connect(_sync_from_social)
	social.pass_changed.connect(_sync_from_social)
	social.profile_changed.connect(_sync_from_social)
	social.wallet_changed.connect(_sync_from_social)
	social.inventory_changed.connect(_sync_from_social)
	social.refresh_shop_day()

	# One renderer feeds 3D skin thumbnails to the shop, the pass and the reward popups.
	skin_previews = SkinPreviewRendererScript.new()
	skin_previews.name = "SkinPreviewRenderer"
	add_child(skin_previews)

	account = AccountService.new(social)
	settings_modal = InGameSettingsModalScript.new()
	settings_modal.name = "HomeSettingsModal"
	settings_modal.sound_controller = sound_controller
	# In the home menu there is no match to leave: the card shows the account instead.
	settings_modal.in_match = false
	settings_modal.social = social
	settings_modal.account = account
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

	season_pass_modal = SeasonPassModalScript.new()
	season_pass_modal.name = "SeasonPassModal"
	season_pass_modal.social = social
	season_pass_modal.previews = skin_previews
	season_pass_modal.sound = sound_controller
	add_child(season_pass_modal)

	shop_screen = ShopScreenScript.new()
	shop_screen.name = "ShopScreen"
	shop_screen.social = social
	shop_screen.previews = skin_previews
	shop_screen.sound = sound_controller
	add_child(shop_screen)
	# The pass sends you to the shop for Splice Plus; the shop sends you back to the pass.
	season_pass_modal.open_shop_requested.connect(func() -> void:
		season_pass_modal.close()
		shop_screen.open()
	)
	shop_screen.open_pass_requested.connect(func() -> void:
		shop_screen.close()
		season_pass_modal.open(SeasonPassModal.TAB_REWARDS)
	)

	appearance_screen = AppearanceScreenScript.new()
	appearance_screen.name = "AppearanceScreen"
	appearance_screen.social = social
	appearance_screen.previews = skin_previews
	appearance_screen.sound = sound_controller
	add_child(appearance_screen)
	appearance_screen.skin_preview_changed.connect(func(skin_id: String) -> void:
		skin_preview_changed.emit(skin_id)
	)
	appearance_screen.part_equipped.connect(func(slot: int, part_id: StringName) -> void:
		equipped_slots[slot] = part_id
		selected_part_id = part_id
		part_selected.emit(slot, part_id)
	)
	appearance_screen.color_preview_changed.connect(func(col: Color) -> void:
		color_selected.emit(col)
	)
	appearance_screen.hero_rotated.connect(func(dx: float) -> void:
		hero_rotated.emit(dx)
	)
	appearance_screen.play_requested.connect(func() -> void:
		appearance_screen.close()
		start_loading_flow()
	)
	appearance_screen.open_pass_requested.connect(func() -> void:
		season_pass_modal.open(SeasonPassModal.TAB_REWARDS)
	)
	# Buying goes through the shop's own confirm dialog, so there is one way to spend coins.
	appearance_screen.buy_requested.connect(func(skin_id: String, daily: bool) -> void:
		shop_screen.open()
		shop_screen._activate("daily_skin" if daily else "buy", skin_id, get_viewport_rect().size * 0.5)
	)
	social.inventory_changed.connect(func() -> void:
		if appearance_screen.is_open:
			appearance_screen.refresh_after_inventory_change()
	)

	profile_modal = ProfileModalScript.new()
	profile_modal.name = "ProfileModal"
	profile_modal.social = social
	add_child(profile_modal)

func _sync_from_social() -> void:
	if social == null:
		return
	player_name = social.player_username
	trophies = social.player_trophies
	season_number = social.season_number
	season_level = social.season_level
	season_xp = social.season_xp
	season_xp_max = social.season_xp_max
	coins = social.coins
	season_badge_count = social.get_claimable_task_count()
	for slot: Variant in social.loadout.keys():
		equipped_slots[int(slot)] = social.loadout[slot]
	equipped_color = social.get_equipped_color()
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
	if season_pass_modal != null and season_pass_modal.is_open:
		return
	if shop_screen != null and shop_screen.is_open:
		return
	if profile_modal != null and profile_modal.is_open:
		return
	if appearance_screen != null and appearance_screen.is_open:
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
	# Home screen interactions
	if _coin_btn_rect.has_area() and _coin_btn_rect.has_point(pos):
		if shop_screen != null:
			shop_screen.open()
		return true
	if _profile_rect.has_point(pos):
		if profile_modal != null:
			profile_modal.open(equipped_color)
		return true
	if _hamburger_rect.has_point(pos):
		if settings_modal != null:
			settings_modal.open()
		return true
	if _play_btn_rect.has_point(pos):
		_commit_preview_selection()
		start_loading_flow()
		return true
	if _skin_btn_rect.has_point(pos):
		if appearance_screen != null:
			appearance_screen.open()
		return true
	if _shop_btn_rect.has_point(pos):
		if shop_screen != null:
			shop_screen.open()
		return true
	if _friends_btn_rect.has_point(pos):
		if friends_modal != null:
			friends_modal.open(FriendsLobbyModal.TAB_FRIENDS)
		return true
	if _task_btn_rect.has_point(pos):
		if season_pass_modal != null:
			season_pass_modal.open(SeasonPassModal.TAB_MISSIONS)
		return true
	if _season_btn_rect.has_point(pos):
		if season_pass_modal != null:
			season_pass_modal.open(SeasonPassModal.TAB_REWARDS)
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
		var entry: Dictionary = EconomyCatalog.find_color(selected_color)
		if social != null and not entry.is_empty():
			social.equip_color(str(entry["id"]))
		color_selected.emit(equipped_color)
	else:
		equipped_slots[current_tab] = selected_part_id
		if social != null:
			social.set_loadout_part(current_tab, selected_part_id)
		part_selected.emit(current_tab, selected_part_id)

## Skin to show on the hero: what Aspetto is trying on, else the equipped one.
func get_display_skin_id() -> String:
	if appearance_screen != null and appearance_screen.is_open:
		return appearance_screen.get_display_skin_id()
	return social.equipped_skin if social != null else EconomyCatalog.DEFAULT_SKIN_ID

func get_display_color() -> Color:
	if appearance_screen != null and appearance_screen.is_open:
		return appearance_screen.get_display_color()
	return social.get_equipped_color() if social != null else Color.WHITE

func start_loading_flow() -> void:
	is_loading = true
	_loading_timer = 0.0
	loading_progress = 0.0

func _draw() -> void:
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)

	if appearance_screen == null or not appearance_screen.is_open:
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
	_profile_rect = prof_rect
	_draw_brawl_box(prof_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 14.0, 2.5)

	# Avatar portrait box
	var av_rect := Rect2(prof_rect.position.x + 9.0, prof_rect.position.y + 8.0, 52.0, 52.0)
	_draw_hero_avatar(av_rect)

	# Player name + Cup + Trophies
	_draw_outlined_text(FONT_BOLD, Vector2(av_rect.end.x + 12.0, prof_rect.position.y + 33.0), player_name, HORIZONTAL_ALIGNMENT_LEFT, prof_w - 86.0 - 130.0, 24, Color.WHITE, 2.5)
	if CUP_TEX != null:
		draw_texture_rect(CUP_TEX, Rect2(av_rect.end.x + 12.0, prof_rect.position.y + 41.0, 20.0, 17.0), false)
	_draw_outlined_text(FONT_BOLD, Vector2(av_rect.end.x + 37.0, prof_rect.position.y + 56.0), str(trophies), HORIZONTAL_ALIGNMENT_LEFT, 160.0, 19, Color(0.98, 0.78, 0.15), 2.0)

	# Wallet: coins on the right of the profile bar. Tapping it opens the shop.
	_coin_btn_rect = Rect2(prof_rect.end.x - 126.0, prof_rect.position.y + 14.0, 114.0, 40.0)
	UIKit.coin_pill(self, _coin_btn_rect, str(coins), 20, Color(0.09, 0.11, 0.20, 0.95))

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
