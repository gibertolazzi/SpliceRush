class_name FriendsLobbyModal
extends Control

signal closed()
signal play_with_lobby_requested()

const FONT_BOLD := preload("res://game/ui/fonts/LilitaOne-Regular.ttf")
const CUP_TEX: Texture2D = preload("res://game/ui/assets/cup.svg")

const SLATE_BG := Color(0.149, 0.176, 0.259, 0.98)
const SLATE_BEVEL := Color(0.098, 0.118, 0.176, 1.0)
const DARK_BORDER := Color(0.063, 0.075, 0.118, 1.0)
const GOLD_FILL := Color(0.941, 0.745, 0.094, 1.0)
const GOLD_BEVEL := Color(0.765, 0.565, 0.047, 1.0)
const GREEN_FILL := Color(0.18, 0.80, 0.44, 1.0)
const GREEN_BEVEL := Color(0.10, 0.55, 0.28, 1.0)
const MAGENTA_FILL := Color(1.0, 0.18, 0.58, 1.0)

const TAB_FRIENDS: int = 0
const TAB_RECENT: int = 1
const TAB_SEARCH: int = 2

var social: SocialManager = null:
	set(val):
		social = val
		queue_redraw()

var is_open: bool = false
var current_tab: int = TAB_FRIENDS
var search_query: String = ""
var _scroll_offset: int = 0

var _search_edit: LineEdit = null
var _card_rect := Rect2()
var _close_rect := Rect2()
var _tab_rects: Array[Rect2] = []
var _row_actions: Array[Dictionary] = [] # { rect: Rect2, kind: String, id: String }
var _lobby_actions: Array[Dictionary] = [] # { rect: Rect2, id: String }
var _play_lobby_rect := Rect2()
var _scroll_up_rect := Rect2()
var _scroll_down_rect := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false

	_search_edit = LineEdit.new()
	_search_edit.name = "FriendsSearchInput"
	_search_edit.placeholder_text = tr(&"FRIENDS_SEARCH_PLACEHOLDER")
	_search_edit.visible = false
	_search_edit.add_theme_font_override("font", FONT_BOLD)
	_search_edit.add_theme_font_size_override("font_size", 18)
	_search_edit.add_theme_color_override("font_color", Color.WHITE)
	_search_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.66, 0.78))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.20, 1.0)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = DARK_BORDER
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	_search_edit.add_theme_stylebox_override("normal", sb)
	_search_edit.add_theme_stylebox_override("focus", sb)
	_search_edit.text_changed.connect(_on_search_text_changed)
	add_child(_search_edit)

func open(initial_tab: int = TAB_FRIENDS) -> void:
	is_open = true
	visible = true
	current_tab = initial_tab
	_scroll_offset = 0
	if _search_edit != null:
		_search_edit.placeholder_text = tr(&"FRIENDS_SEARCH_PLACEHOLDER")
		_search_edit.visible = true
		_layout_search_box()
	queue_redraw()

func close() -> void:
	is_open = false
	visible = false
	if _search_edit != null:
		_search_edit.visible = false
		_search_edit.release_focus()
	closed.emit()
	queue_redraw()

func _on_search_text_changed(new_text: String) -> void:
	search_query = new_text
	_scroll_offset = 0
	if new_text.strip_edges() != "" and current_tab == TAB_FRIENDS:
		# Searching automatically checks all discoverable players if needed, or filters current tab
		pass
	queue_redraw()

func _layout_search_box() -> void:
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)
	var cw: float = sz.x - 36.0
	var ch: float = 700.0
	var cx: float = 18.0
	var cy: float = (sz.y - ch) * 0.5
	_card_rect = Rect2(cx, cy, cw, ch)
	if _search_edit != null:
		_search_edit.position = Vector2(cx + 16.0, cy + 114.0)
		_search_edit.size = Vector2(cw - 32.0, 42.0)

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

	# Allow LineEdit focus when tapping inside search bar
	if _search_edit != null and _search_edit.visible:
		var se_rect := Rect2(_search_edit.position, _search_edit.size)
		if se_rect.has_point(pos):
			_search_edit.grab_focus()
			return

	if _close_rect.has_point(pos) or not _card_rect.has_point(pos):
		close()
		get_viewport().set_input_as_handled()
		return

	for t_i: int in range(_tab_rects.size()):
		if _tab_rects[t_i].has_point(pos):
			current_tab = t_i
			_scroll_offset = 0
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if _scroll_up_rect.has_area() and _scroll_up_rect.has_point(pos):
		_scroll_offset = maxi(0, _scroll_offset - 1)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _scroll_down_rect.has_area() and _scroll_down_rect.has_point(pos):
		_scroll_offset += 1
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _play_lobby_rect.has_area() and _play_lobby_rect.has_point(pos):
		close()
		play_with_lobby_requested.emit()
		get_viewport().set_input_as_handled()
		return

	for act: Dictionary in _row_actions:
		if (act["rect"] as Rect2).has_point(pos) and social != null:
			var kind: String = str(act["kind"])
			var pid: String = str(act["id"])
			if kind == "add":
				social.add_friend(pid)
			elif kind == "remove":
				social.remove_friend(pid)
			elif kind == "invite":
				social.invite_to_lobby(pid)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	for lact: Dictionary in _lobby_actions:
		if (lact["rect"] as Rect2).has_point(pos) and social != null:
			social.leave_or_kick_lobby(str(lact["id"]))
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	get_viewport().set_input_as_handled()

func _get_displayed_players() -> Array[Dictionary]:
	if social == null:
		return []
	var q: String = search_query.strip_edges().to_lower()
	if current_tab == TAB_SEARCH or q != "":
		if current_tab == TAB_RECENT:
			var res_r: Array[Dictionary] = []
			for r: Dictionary in social.recent_players:
				if q == "" or str(r.get("username", "")).to_lower().contains(q):
					res_r.append(r)
			return res_r
		elif current_tab == TAB_FRIENDS and q == "":
			return social.friends
		return social.search_players(q)
	elif current_tab == TAB_RECENT:
		return social.recent_players
	else:
		return social.friends

func _draw() -> void:
	if not is_open:
		return
	_layout_search_box()
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)

	# Dimmed backdrop
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.04, 0.08, 0.72), true)

	# Main modal card
	_draw_box(_card_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 16.0, 3.0)

	# Header Title + Close button
	_draw_text_ol(Vector2(_card_rect.position.x + 20.0, _card_rect.position.y + 40.0), tr(&"FRIENDS_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, 360.0, 26, Color.WHITE, 2.5)
	_close_rect = Rect2(_card_rect.end.x - 52.0, _card_rect.position.y + 14.0, 38.0, 38.0)
	_draw_box(_close_rect, Color(0.85, 0.22, 0.26), Color(0.58, 0.12, 0.16), DARK_BORDER, 10.0, 2.0)
	_draw_text_ol(Vector2(_close_rect.position.x, _close_rect.position.y + 27.0), "✕", HORIZONTAL_ALIGNMENT_CENTER, 38.0, 20, Color.WHITE, 2.0)

	# Tabs (AMICI | RECENTI | CERCA)
	var tab_labels := [tr(&"FRIENDS_TAB_LIST"), tr(&"FRIENDS_TAB_RECENT"), tr(&"FRIENDS_TAB_SEARCH")]
	_tab_rects.clear()
	var tab_w: float = (_card_rect.size.x - 40.0) / 3.0
	for i: int in range(3):
		var tr_r := Rect2(_card_rect.position.x + 16.0 + float(i) * (tab_w + 4.0), _card_rect.position.y + 62.0, tab_w, 40.0)
		_tab_rects.append(tr_r)
		var sel: bool = (i == current_tab)
		_draw_box(tr_r, GOLD_FILL if sel else Color(0.20, 0.23, 0.34), GOLD_BEVEL if sel else SLATE_BEVEL, DARK_BORDER, 10.0, 2.0)
		_draw_text_ol(Vector2(tr_r.position.x, tr_r.position.y + 26.0), tab_labels[i], HORIZONTAL_ALIGNMENT_CENTER, tab_w, 16, Color.WHITE, 2.0)

	# Player List Area
	var list_y: float = _card_rect.position.y + 168.0
	var list_h: float = 312.0
	var max_rows: int = 4
	var players: Array[Dictionary] = _get_displayed_players()
	if _scroll_offset > maxi(0, players.size() - max_rows):
		_scroll_offset = maxi(0, players.size() - max_rows)

	_row_actions.clear()
	_scroll_up_rect = Rect2()
	_scroll_down_rect = Rect2()

	if players.is_empty():
		var empty_key: StringName = &"FRIENDS_RECENT_EMPTY" if current_tab == TAB_RECENT else &"FRIENDS_EMPTY"
		_draw_text_ol(Vector2(_card_rect.position.x + 20.0, list_y + 90.0), tr(empty_key), HORIZONTAL_ALIGNMENT_CENTER, _card_rect.size.x - 40.0, 18, Color(0.75, 0.78, 0.88), 2.0)
	else:
		var visible_count: int = mini(max_rows, players.size() - _scroll_offset)
		for idx: int in range(visible_count):
			var p: Dictionary = players[_scroll_offset + idx]
			var row_r := Rect2(_card_rect.position.x + 16.0, list_y + float(idx) * 72.0, _card_rect.size.x - 32.0, 64.0)
			_draw_player_row(row_r, p)

		if players.size() > max_rows:
			_scroll_up_rect = Rect2(_card_rect.end.x - 92.0, list_y + list_h - 14.0, 34.0, 26.0)
			_scroll_down_rect = Rect2(_card_rect.end.x - 52.0, list_y + list_h - 14.0, 34.0, 26.0)
			_draw_box(_scroll_up_rect, Color(0.22, 0.25, 0.36), SLATE_BEVEL, DARK_BORDER, 7.0, 1.5)
			_draw_text_ol(Vector2(_scroll_up_rect.position.x, _scroll_up_rect.position.y + 19.0), "▲", HORIZONTAL_ALIGNMENT_CENTER, 34.0, 14, Color.WHITE, 1.5)
			_draw_box(_scroll_down_rect, Color(0.22, 0.25, 0.36), SLATE_BEVEL, DARK_BORDER, 7.0, 1.5)
			_draw_text_ol(Vector2(_scroll_down_rect.position.x, _scroll_down_rect.position.y + 19.0), "▼", HORIZONTAL_ALIGNMENT_CENTER, 34.0, 14, Color.WHITE, 1.5)

	# Bottom Lobby Panel
	var lobby_y: float = _card_rect.position.y + 506.0
	var lobby_r := Rect2(_card_rect.position.x + 16.0, lobby_y, _card_rect.size.x - 32.0, 118.0)
	_draw_box(lobby_r, Color(0.11, 0.13, 0.21), Color(0.08, 0.09, 0.15), DARK_BORDER, 12.0, 2.0)

	var l_count: int = social.lobby_members.size() if social != null else 1
	var l_header: String = tr(&"LOBBY_HEADER") % [l_count, SocialManager.MAX_LOBBY_SIZE]
	_draw_text_ol(Vector2(lobby_r.position.x + 12.0, lobby_r.position.y + 24.0), l_header, HORIZONTAL_ALIGNMENT_LEFT, 260.0, 17, GOLD_FILL, 2.0)

	_lobby_actions.clear()
	if social != null:
		var slot_w: float = (lobby_r.size.x - 24.0) / float(SocialManager.MAX_LOBBY_SIZE)
		for m_i: int in range(SocialManager.MAX_LOBBY_SIZE):
			var sr := Rect2(lobby_r.position.x + 12.0 + float(m_i) * slot_w, lobby_r.position.y + 34.0, slot_w - 6.0, 74.0)
			if m_i < social.lobby_members.size():
				var mem: Dictionary = social.lobby_members[m_i]
				var is_h: bool = bool(mem.get("is_host", false))
				_draw_box(sr, Color(0.20, 0.24, 0.36), SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
				var dot_c := Color(str(mem.get("color_hex", "#FFFFFF")))
				draw_circle(Vector2(sr.position.x + sr.size.x * 0.5, sr.position.y + 20.0), 11.0, DARK_BORDER)
				draw_circle(Vector2(sr.position.x + sr.size.x * 0.5, sr.position.y + 20.0), 9.0, dot_c)
				_draw_text_ol(Vector2(sr.position.x + 2.0, sr.position.y + 46.0), str(mem.get("username", "")), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 4.0, 13, Color.WHITE, 1.5)
				var tag_str: String = tr(&"LOBBY_HOST") if is_h else tr(&"LOBBY_READY")
				var tag_col: Color = GOLD_FILL if is_h else GREEN_FILL
				_draw_text_ol(Vector2(sr.position.x + 2.0, sr.position.y + 64.0), tag_str, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 4.0, 11, tag_col, 1.5)
				if not is_h:
					var kick_r := Rect2(sr.end.x - 20.0, sr.position.y + 2.0, 18.0, 18.0)
					draw_circle(kick_r.get_center(), 8.0, Color(0.85, 0.20, 0.24))
					_draw_text_ol(Vector2(kick_r.position.x, kick_r.position.y + 13.0), "✕", HORIZONTAL_ALIGNMENT_CENTER, 18.0, 11, Color.WHITE, 1.0)
					_lobby_actions.append({ "rect": kick_r, "id": str(mem.get("id", "")) })
			else:
				_draw_box(sr, Color(0.14, 0.16, 0.25, 0.65), Color(0.10, 0.11, 0.18), Color(0.24, 0.27, 0.38), 9.0, 1.5)
				_draw_text_ol(Vector2(sr.position.x, sr.position.y + 44.0), "+", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 22, Color(0.45, 0.50, 0.62), 0.0)

	# Bottom Play Lobby CTA
	_play_lobby_rect = Rect2(_card_rect.position.x + 16.0, _card_rect.end.y - 62.0, _card_rect.size.x - 32.0, 48.0)
	_draw_box(_play_lobby_rect, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 12.0, 2.5)
	_draw_text_ol(Vector2(_play_lobby_rect.position.x, _play_lobby_rect.position.y + 33.0), tr(&"HOME_PLAY_NOW"), HORIZONTAL_ALIGNMENT_CENTER, _play_lobby_rect.size.x, 22, Color.WHITE, 2.5)

func _draw_player_row(row_r: Rect2, p: Dictionary) -> void:
	_draw_box(row_r, Color(0.19, 0.22, 0.32), SLATE_BEVEL, DARK_BORDER, 11.0, 2.0)
	var pid: String = str(p.get("id", ""))
	var uname: String = str(p.get("username", ""))
	var trop: int = int(p.get("trophies", 0))
	var is_bot_p: bool = bool(p.get("is_bot", false))
	var p_col := Color(str(p.get("color_hex", "#6B4EFF")))

	# Avatar dot
	var av_c := Vector2(row_r.position.x + 28.0, row_r.position.y + row_r.size.y * 0.5)
	draw_circle(av_c, 18.0, DARK_BORDER)
	draw_circle(av_c, 15.5, p_col)

	# Name + Bot tag + Trophies
	var title_str: String = uname + (" [" + tr(&"FRIENDS_BOT_TAG") + "]" if is_bot_p else "")
	_draw_text_ol(Vector2(row_r.position.x + 54.0, row_r.position.y + 27.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, 210.0, 18, Color.WHITE, 2.0)
	if CUP_TEX != null:
		draw_texture_rect(CUP_TEX, Rect2(row_r.position.x + 54.0, row_r.position.y + 34.0, 15.0, 13.0), false)
	_draw_text_ol(Vector2(row_r.position.x + 73.0, row_r.position.y + 47.0), str(trop), HORIZONTAL_ALIGNMENT_LEFT, 90.0, 14, GOLD_FILL, 1.5)

	var lobby_st: String = social.get_lobby_status_for(pid) if social != null else "none"
	var already_friend: bool = social.is_friend(pid) if social != null else false

	# Invite / Status Button (rightmost)
	var inv_r := Rect2(row_r.end.x - 104.0, row_r.position.y + 12.0, 94.0, 40.0)
	if lobby_st == "in_lobby":
		_draw_box(inv_r, Color(0.24, 0.28, 0.40), SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(inv_r.position.x, inv_r.position.y + 26.0), tr(&"FRIENDS_BTN_IN_LOBBY"), HORIZONTAL_ALIGNMENT_CENTER, inv_r.size.x, 13, GREEN_FILL, 1.5)
	elif lobby_st == "invited":
		_draw_box(inv_r, MAGENTA_FILL, Color(0.68, 0.08, 0.36), DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(inv_r.position.x, inv_r.position.y + 26.0), tr(&"FRIENDS_BTN_INVITED"), HORIZONTAL_ALIGNMENT_CENTER, inv_r.size.x, 13, Color.WHITE, 1.5)
	else:
		_draw_box(inv_r, GREEN_FILL, GREEN_BEVEL, DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(inv_r.position.x, inv_r.position.y + 26.0), tr(&"FRIENDS_BTN_INVITE"), HORIZONTAL_ALIGNMENT_CENTER, inv_r.size.x, 14, Color.WHITE, 1.5)
		_row_actions.append({ "rect": inv_r, "kind": "invite", "id": pid })

	# Add / Remove Friend Button
	var fr_r := Rect2(inv_r.position.x - 86.0, row_r.position.y + 12.0, 78.0, 40.0)
	if not already_friend:
		_draw_box(fr_r, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(fr_r.position.x, fr_r.position.y + 26.0), tr(&"FRIENDS_BTN_ADD"), HORIZONTAL_ALIGNMENT_CENTER, fr_r.size.x, 12, Color.WHITE, 1.5)
		_row_actions.append({ "rect": fr_r, "kind": "add", "id": pid })
	elif current_tab == TAB_FRIENDS:
		_draw_box(fr_r, Color(0.28, 0.22, 0.30), Color(0.18, 0.14, 0.20), DARK_BORDER, 9.0, 2.0)
		_draw_text_ol(Vector2(fr_r.position.x, fr_r.position.y + 26.0), tr(&"FRIENDS_BTN_REMOVE"), HORIZONTAL_ALIGNMENT_CENTER, fr_r.size.x, 12, Color(0.95, 0.55, 0.55), 1.5)
		_row_actions.append({ "rect": fr_r, "kind": "remove", "id": pid })

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
