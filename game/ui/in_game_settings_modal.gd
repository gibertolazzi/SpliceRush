class_name InGameSettingsModal
extends Control

signal closed()
signal leave_match_requested()
signal music_volume_changed(val: float)
signal sfx_volume_changed(val: float)
signal language_changed(locale: String)

var sound_controller: SoundController
var music_volume: float = 0.45
var sfx_volume: float = 0.85
var current_locale: String = "it"
var sub_dialog: int = 0 # 0: None, 1: Privacy Policy, 2: Terms of Service

var is_open: bool = false
var _pulse_timer: float = 0.0

var font_bold: Font = preload("res://game/ui/fonts/LondrinaSolid-Black.ttf")
var font_regular: Font = preload("res://game/ui/fonts/LondrinaSolid-Regular.ttf")

var _card_rect := Rect2()
var _close_btn_rect := Rect2()
var _warning_banner_rect := Rect2()

var _music_minus_rect := Rect2()
var _music_plus_rect := Rect2()
var _music_mute_rect := Rect2()
var _music_bar_rect := Rect2()

var _sfx_minus_rect := Rect2()
var _sfx_plus_rect := Rect2()
var _sfx_mute_rect := Rect2()
var _sfx_bar_rect := Rect2()

var _lang_it_rect := Rect2()
var _lang_en_rect := Rect2()

var _privacy_btn_rect := Rect2()
var _tos_btn_rect := Rect2()

var _leave_match_btn_rect := Rect2()
var _resume_btn_rect := Rect2()

var _subdialog_rect := Rect2()
var _subdialog_close_rect := Rect2()
var _subdialog_link_rect := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false
	current_locale = TranslationServer.get_locale()
	if current_locale == "":
		current_locale = "it"

func _process(delta: float) -> void:
	if visible and is_open:
		_pulse_timer += delta
		queue_redraw()

func open() -> void:
	is_open = true
	visible = true
	sub_dialog = 0
	current_locale = TranslationServer.get_locale()
	if sound_controller != null:
		music_volume = sound_controller.get_music_volume_linear()
		sfx_volume = sound_controller.get_sfx_volume_linear()
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func close() -> void:
	is_open = false
	visible = false
	sub_dialog = 0
	mouse_filter = Control.MOUSE_FILTER_PASS
	closed.emit()
	queue_redraw()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func set_language(loc: String) -> void:
	current_locale = loc
	I18nService.set_locale(loc)
	language_changed.emit(loc)
	queue_redraw()

func _apply_music() -> void:
	if sound_controller != null:
		sound_controller.set_music_volume_linear(music_volume)
	music_volume_changed.emit(music_volume)
	queue_redraw()

func _apply_sfx() -> void:
	if sound_controller != null:
		sound_controller.set_sfx_volume_linear(sfx_volume)
		sound_controller.play_pickup_pop()
	sfx_volume_changed.emit(sfx_volume)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_open:
		return

	var pos := Vector2.ZERO
	var is_click: bool = false

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			pos = st.position
			is_click = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
			is_click = true

	if not is_click:
		return

	# 1. Subdialog modal interaction (Privacy Policy / Terms of Service)
	if sub_dialog != 0:
		if _subdialog_close_rect.has_point(pos):
			sub_dialog = 0
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
		elif _subdialog_link_rect.has_point(pos):
			var url: String = "https://splicerush.game/privacy" if sub_dialog == 1 else "https://splicerush.game/terms"
			OS.shell_open(url)
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		return

	# 2. Main card interaction
	if _close_btn_rect.has_point(pos) or _resume_btn_rect.has_point(pos):
		close()
		get_viewport().set_input_as_handled()
		return

	if _music_mute_rect.has_point(pos):
		music_volume = 0.0 if music_volume > 0.01 else 0.50
		_apply_music()
		get_viewport().set_input_as_handled()
		return
	elif _music_minus_rect.has_point(pos):
		music_volume = clampf(music_volume - 0.20, 0.0, 1.0)
		_apply_music()
		get_viewport().set_input_as_handled()
		return
	elif _music_plus_rect.has_point(pos):
		music_volume = clampf(music_volume + 0.20, 0.0, 1.0)
		_apply_music()
		get_viewport().set_input_as_handled()
		return
	elif _music_bar_rect.has_point(pos):
		var ratio: float = clampf((pos.x - _music_bar_rect.position.x) / _music_bar_rect.size.x, 0.0, 1.0)
		music_volume = roundf(ratio * 5.0) / 5.0
		_apply_music()
		get_viewport().set_input_as_handled()
		return

	if _sfx_mute_rect.has_point(pos):
		sfx_volume = 0.0 if sfx_volume > 0.01 else 0.85
		_apply_sfx()
		get_viewport().set_input_as_handled()
		return
	elif _sfx_minus_rect.has_point(pos):
		sfx_volume = clampf(sfx_volume - 0.20, 0.0, 1.0)
		_apply_sfx()
		get_viewport().set_input_as_handled()
		return
	elif _sfx_plus_rect.has_point(pos):
		sfx_volume = clampf(sfx_volume + 0.20, 0.0, 1.0)
		_apply_sfx()
		get_viewport().set_input_as_handled()
		return
	elif _sfx_bar_rect.has_point(pos):
		var ratio: float = clampf((pos.x - _sfx_bar_rect.position.x) / _sfx_bar_rect.size.x, 0.0, 1.0)
		sfx_volume = roundf(ratio * 5.0) / 5.0
		_apply_sfx()
		get_viewport().set_input_as_handled()
		return

	if _lang_it_rect.has_point(pos):
		set_language("it")
		get_viewport().set_input_as_handled()
		return
	elif _lang_en_rect.has_point(pos):
		set_language("en")
		get_viewport().set_input_as_handled()
		return

	if _privacy_btn_rect.has_point(pos):
		sub_dialog = 1
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	elif _tos_btn_rect.has_point(pos):
		sub_dialog = 2
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if _leave_match_btn_rect.has_point(pos):
		leave_match_requested.emit()
		close()
		get_viewport().set_input_as_handled()
		return

	if not _card_rect.has_point(pos):
		# Tapping outside card closes settings overlay so player can return to fighting instantly
		close()
		get_viewport().set_input_as_handled()
		return

	get_viewport().set_input_as_handled()

func _calculate_layout(view_size: Vector2) -> void:
	var card_w: float = minf(460.0, view_size.x - 32.0)
	var card_h: float = 640.0
	var card_x: float = (view_size.x - card_w) * 0.5
	var card_y: float = (view_size.y - card_h) * 0.5
	_card_rect = Rect2(Vector2(card_x, card_y), Vector2(card_w, card_h))

	_close_btn_rect = Rect2(Vector2(_card_rect.end.x - 46.0, card_y + 14.0), Vector2(32.0, 32.0))
	_warning_banner_rect = Rect2(Vector2(card_x + 16.0, card_y + 58.0), Vector2(card_w - 32.0, 32.0))

	# Music row (Y = card_y + 102.0)
	var m_y: float = card_y + 102.0
	_music_mute_rect = Rect2(Vector2(card_x + 22.0, m_y + 24.0), Vector2(36.0, 34.0))
	_music_minus_rect = Rect2(Vector2(card_x + 68.0, m_y + 24.0), Vector2(34.0, 34.0))
	_music_bar_rect = Rect2(Vector2(card_x + 112.0, m_y + 28.0), Vector2(card_w - 210.0, 26.0))
	_music_plus_rect = Rect2(Vector2(_card_rect.end.x - 88.0, m_y + 24.0), Vector2(34.0, 34.0))

	# SFX row (Y = card_y + 172.0)
	var s_y: float = card_y + 172.0
	_sfx_mute_rect = Rect2(Vector2(card_x + 22.0, s_y + 24.0), Vector2(36.0, 34.0))
	_sfx_minus_rect = Rect2(Vector2(card_x + 68.0, s_y + 24.0), Vector2(34.0, 34.0))
	_sfx_bar_rect = Rect2(Vector2(card_x + 112.0, s_y + 28.0), Vector2(card_w - 210.0, 26.0))
	_sfx_plus_rect = Rect2(Vector2(_card_rect.end.x - 88.0, s_y + 24.0), Vector2(34.0, 34.0))

	# Language row (Y = card_y + 244.0)
	var l_y: float = card_y + 244.0
	var lang_btn_w: float = (card_w - 48.0) * 0.5
	_lang_it_rect = Rect2(Vector2(card_x + 20.0, l_y + 26.0), Vector2(lang_btn_w, 40.0))
	_lang_en_rect = Rect2(Vector2(card_x + 28.0 + lang_btn_w, l_y + 26.0), Vector2(lang_btn_w, 40.0))

	# Legal links row (Y = card_y + 334.0)
	var leg_y: float = card_y + 334.0
	var legal_btn_w: float = (card_w - 48.0) * 0.5
	_privacy_btn_rect = Rect2(Vector2(card_x + 20.0, leg_y), Vector2(legal_btn_w, 38.0))
	_tos_btn_rect = Rect2(Vector2(card_x + 28.0 + legal_btn_w, leg_y), Vector2(legal_btn_w, 38.0))

	# Leave match row (Y = card_y + 394.0)
	_leave_match_btn_rect = Rect2(Vector2(card_x + 24.0, card_y + 394.0), Vector2(card_w - 48.0, 48.0))

	# Resume match row (Y = card_y + 456.0)
	_resume_btn_rect = Rect2(Vector2(card_x + 24.0, card_y + 456.0), Vector2(card_w - 48.0, 48.0))

	# Subdialog modal rect
	var sub_w: float = minf(480.0, view_size.x - 24.0)
	var sub_h: float = 520.0
	var sub_x: float = (view_size.x - sub_w) * 0.5
	var sub_y: float = (view_size.y - sub_h) * 0.5
	_subdialog_rect = Rect2(Vector2(sub_x, sub_y), Vector2(sub_w, sub_h))
	_subdialog_link_rect = Rect2(Vector2(sub_x + 24.0, _subdialog_rect.end.y - 110.0), Vector2(sub_w - 48.0, 42.0))
	_subdialog_close_rect = Rect2(Vector2(sub_x + 24.0, _subdialog_rect.end.y - 56.0), Vector2(sub_w - 48.0, 42.0))

func _draw() -> void:
	if not visible or not is_open:
		return

	var view_size: Vector2 = size
	if view_size.x < 10.0:
		view_size = get_viewport_rect().size
		if view_size.x < 10.0:
			view_size = Vector2(540.0, 960.0)

	_calculate_layout(view_size)

	# 1. Semi-translucent screen tint (Live match continues visible behind!)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.04, 0.03, 0.12, 0.65), true)

	var navy_bg := Color(0.08, 0.07, 0.22, 0.96)
	var gold := Color(1.0, 0.78, 0.15)
	var magenta := Color(1.0, 0.18, 0.58)
	var border_col := Color(0.42, 0.35, 0.70, 0.75)
	var white := Color.WHITE

	# 2. Main Settings Card
	_draw_rounded_rect(_card_rect, navy_bg, 16.0, true)
	_draw_rounded_rect(_card_rect, border_col, 16.0, false, 2.0)

	# Header Title
	var title_str: String = "⚙ " + tr(&"SETTINGS_TITLE")
	draw_string(font_bold, Vector2(_card_rect.position.x + 24.0, _card_rect.position.y + 38.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, gold)

	# Close button [X]
	_draw_rounded_rect(_close_btn_rect, Color(0.22, 0.10, 0.32, 0.90), 8.0, true)
	_draw_rounded_rect(_close_btn_rect, border_col, 8.0, false, 1.4)
	draw_string(font_bold, _close_btn_rect.position + Vector2(0.0, 24.0), "✕", HORIZONTAL_ALIGNMENT_CENTER, _close_btn_rect.size.x, 18, white)

	# Warning Banner: Live Match Continues!
	var pulse: float = 0.70 + 0.30 * sin(_pulse_timer * 6.0)
	var warn_bg := Color(0.32, 0.08, 0.14, 0.92)
	_draw_rounded_rect(_warning_banner_rect, warn_bg, 8.0, true)
	_draw_rounded_rect(_warning_banner_rect, Color(1.0, 0.35, 0.45, pulse), 8.0, false, 1.8)
	var warn_str: String = "⚡ " + tr(&"SETTINGS_MATCH_CONTINUES_HINT")
	draw_string(font_bold, _warning_banner_rect.position + Vector2(6.0, 22.0), warn_str, HORIZONTAL_ALIGNMENT_CENTER, _warning_banner_rect.size.x - 12.0, 13, Color(1.0, 0.90, 0.30))

	# Music row
	var m_y: float = _card_rect.position.y + 102.0
	draw_string(font_bold, Vector2(_card_rect.position.x + 24.0, m_y + 18.0), tr(&"SETTINGS_MUSIC"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
	_draw_stepped_volume_bar(_music_mute_rect, _music_minus_rect, _music_bar_rect, _music_plus_rect, music_volume, Color(0.20, 0.85, 1.0))

	# SFX row
	var s_y: float = _card_rect.position.y + 172.0
	draw_string(font_bold, Vector2(_card_rect.position.x + 24.0, s_y + 18.0), tr(&"SETTINGS_SFX"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
	_draw_stepped_volume_bar(_sfx_mute_rect, _sfx_minus_rect, _sfx_bar_rect, _sfx_plus_rect, sfx_volume, Color(1.0, 0.75, 0.20))

	# Language row
	var l_y: float = _card_rect.position.y + 244.0
	draw_string(font_bold, Vector2(_card_rect.position.x + 24.0, l_y + 18.0), tr(&"SETTINGS_LANGUAGE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)

	var is_it: bool = (current_locale.begins_with("it"))
	var is_en: bool = (current_locale.begins_with("en"))

	_draw_rounded_rect(_lang_it_rect, Color(0.26, 0.12, 0.45, 0.95) if is_it else Color(0.12, 0.10, 0.24, 0.80), 8.0, true)
	_draw_rounded_rect(_lang_it_rect, gold if is_it else border_col, 8.0, false, 2.0 if is_it else 1.2)
	draw_string(font_bold, _lang_it_rect.position + Vector2(0.0, 26.0), "🇮🇹 " + tr(&"SETTINGS_LANG_IT"), HORIZONTAL_ALIGNMENT_CENTER, _lang_it_rect.size.x, 16, gold if is_it else Color(0.85, 0.85, 0.95))

	_draw_rounded_rect(_lang_en_rect, Color(0.26, 0.12, 0.45, 0.95) if is_en else Color(0.12, 0.10, 0.24, 0.80), 8.0, true)
	_draw_rounded_rect(_lang_en_rect, gold if is_en else border_col, 8.0, false, 2.0 if is_en else 1.2)
	draw_string(font_bold, _lang_en_rect.position + Vector2(0.0, 26.0), "🇬🇧 " + tr(&"SETTINGS_LANG_EN"), HORIZONTAL_ALIGNMENT_CENTER, _lang_en_rect.size.x, 16, gold if is_en else Color(0.85, 0.85, 0.95))

	# Legal buttons row
	_draw_rounded_rect(_privacy_btn_rect, Color(0.14, 0.12, 0.28, 0.90), 8.0, true)
	_draw_rounded_rect(_privacy_btn_rect, border_col, 8.0, false, 1.4)
	draw_string(font_bold, _privacy_btn_rect.position + Vector2(0.0, 24.0), "📄 " + tr(&"SETTINGS_PRIVACY_POLICY"), HORIZONTAL_ALIGNMENT_CENTER, _privacy_btn_rect.size.x, 13, Color(0.90, 0.88, 1.0))

	_draw_rounded_rect(_tos_btn_rect, Color(0.14, 0.12, 0.28, 0.90), 8.0, true)
	_draw_rounded_rect(_tos_btn_rect, border_col, 8.0, false, 1.4)
	draw_string(font_bold, _tos_btn_rect.position + Vector2(0.0, 24.0), "📜 " + tr(&"SETTINGS_TERMS_OF_SERVICE"), HORIZONTAL_ALIGNMENT_CENTER, _tos_btn_rect.size.x, 13, Color(0.90, 0.88, 1.0))

	# Leave match button
	_draw_rounded_rect(_leave_match_btn_rect, Color(0.38, 0.08, 0.18, 0.95), 10.0, true)
	_draw_rounded_rect(_leave_match_btn_rect, magenta, 10.0, false, 2.2)
	draw_string(font_bold, _leave_match_btn_rect.position + Vector2(0.0, 31.0), "✕  " + tr(&"SETTINGS_LEAVE_MATCH"), HORIZONTAL_ALIGNMENT_CENTER, _leave_match_btn_rect.size.x, 18, Color(1.0, 0.90, 0.95))

	# Resume brawl button
	_draw_rounded_rect(_resume_btn_rect, Color(0.16, 0.14, 0.36, 0.95), 10.0, true)
	_draw_rounded_rect(_resume_btn_rect, gold, 10.0, false, 2.4)
	draw_string(font_bold, _resume_btn_rect.position + Vector2(0.0, 31.0), "▶  " + tr(&"SETTINGS_RESUME"), HORIZONTAL_ALIGNMENT_CENTER, _resume_btn_rect.size.x, 18, gold)

	# 3. Subdialog (Privacy Policy or Terms of Service)
	if sub_dialog != 0:
		_draw_subdialog()

func _draw_stepped_volume_bar(mute_r: Rect2, min_r: Rect2, bar_r: Rect2, plus_r: Rect2, vol: float, bar_col: Color) -> void:
	var navy_pill := Color(0.12, 0.10, 0.26, 0.90)
	var border_c := Color(0.40, 0.35, 0.65, 0.70)
	var is_muted: bool = (vol <= 0.01)

	# Mute button
	_draw_rounded_rect(mute_r, Color(0.24, 0.08, 0.14) if is_muted else navy_pill, 7.0, true)
	_draw_rounded_rect(mute_r, border_c, 7.0, false, 1.2)
	draw_string(font_bold, mute_r.position + Vector2(0.0, 22.0), "🔇" if is_muted else "🔊", HORIZONTAL_ALIGNMENT_CENTER, mute_r.size.x, 14, Color.WHITE)

	# Minus button [-]
	_draw_rounded_rect(min_r, navy_pill, 7.0, true)
	_draw_rounded_rect(min_r, border_c, 7.0, false, 1.2)
	draw_string(font_bold, min_r.position + Vector2(0.0, 22.0), "-", HORIZONTAL_ALIGNMENT_CENTER, min_r.size.x, 20, Color.WHITE)

	# 5-Segmented bar
	_draw_rounded_rect(bar_r, Color(0.06, 0.05, 0.14, 0.95), 6.0, true)
	_draw_rounded_rect(bar_r, border_c, 6.0, false, 1.2)

	var seg_w: float = (bar_r.size.x - 8.0) / 5.0
	var seg_cnt: int = int(round(vol * 5.0))
	for i in range(5):
		var seg_r := Rect2(Vector2(bar_r.position.x + 4.0 + float(i) * seg_w + 1.0, bar_r.position.y + 3.0), Vector2(seg_w - 2.0, bar_r.size.y - 6.0))
		if i < seg_cnt and not is_muted:
			draw_rect(seg_r, bar_col, true)
		else:
			draw_rect(seg_r, Color(0.16, 0.14, 0.28, 0.60), true)

	# Plus button [+]
	_draw_rounded_rect(plus_r, navy_pill, 7.0, true)
	_draw_rounded_rect(plus_r, border_c, 7.0, false, 1.2)
	draw_string(font_bold, plus_r.position + Vector2(0.0, 23.0), "+", HORIZONTAL_ALIGNMENT_CENTER, plus_r.size.x, 18, Color.WHITE)

	# Readout
	var pct_str: String = "%d%%" % int(round(vol * 100.0))
	draw_string(font_bold, Vector2(plus_r.end.x + 8.0, plus_r.position.y + 22.0), pct_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE if not is_muted else Color(0.6, 0.6, 0.7))

func _draw_subdialog() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.08, 0.70), true)

	var bg_col := Color(0.08, 0.07, 0.22, 0.98)
	var gold := Color(1.0, 0.78, 0.15)
	_draw_rounded_rect(_subdialog_rect, bg_col, 16.0, true)
	_draw_rounded_rect(_subdialog_rect, gold, 16.0, false, 2.4)

	var is_priv: bool = (sub_dialog == 1)
	var sub_title: String = "📄 " + (tr(&"SETTINGS_PRIVACY_POLICY") if is_priv else tr(&"SETTINGS_TERMS_OF_SERVICE"))
	draw_string(font_bold, Vector2(_subdialog_rect.position.x + 24.0, _subdialog_rect.position.y + 44.0), sub_title, HORIZONTAL_ALIGNMENT_LEFT, _subdialog_rect.size.x - 48.0, 22, gold)

	var body_text: String = tr(&"PRIVACY_TEXT") if is_priv else tr(&"TOS_TEXT")
	var text_rect := Rect2(Vector2(_subdialog_rect.position.x + 24.0, _subdialog_rect.position.y + 70.0), Vector2(_subdialog_rect.size.x - 48.0, _subdialog_rect.size.y - 190.0))
	_draw_wrapped_text(body_text, text_rect, font_regular, 15, Color(0.92, 0.90, 1.0))

	# Link button
	_draw_rounded_rect(_subdialog_link_rect, Color(0.18, 0.14, 0.36, 0.95), 8.0, true)
	_draw_rounded_rect(_subdialog_link_rect, Color(0.45, 0.85, 1.0), 8.0, false, 1.6)
	draw_string(font_bold, _subdialog_link_rect.position + Vector2(0.0, 27.0), "🌐  " + tr(&"SETTINGS_OPEN_WEB"), HORIZONTAL_ALIGNMENT_CENTER, _subdialog_link_rect.size.x, 16, Color(0.45, 0.85, 1.0))

	# Close button
	_draw_rounded_rect(_subdialog_close_rect, Color(0.24, 0.12, 0.32, 0.95), 8.0, true)
	_draw_rounded_rect(_subdialog_close_rect, gold, 8.0, false, 1.8)
	draw_string(font_bold, _subdialog_close_rect.position + Vector2(0.0, 27.0), "✕  " + tr(&"SETTINGS_CLOSE"), HORIZONTAL_ALIGNMENT_CENTER, _subdialog_close_rect.size.x, 16, gold)

func _draw_wrapped_text(text: String, area: Rect2, font: Font, fsize: int, col: Color) -> void:
	var words: PackedStringArray = text.split(" ")
	var line: String = ""
	var line_y: float = area.position.y + float(fsize)
	var line_h: float = float(fsize) * 1.35

	for w: String in words:
		var test_line: String = w if line == "" else (line + " " + w)
		var str_sz: Vector2 = font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		if str_sz.x > area.size.x and line != "":
			draw_string(font, Vector2(area.position.x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, area.size.x, fsize, col)
			line = w
			line_y += line_h
		else:
			line = test_line

	if line != "":
		draw_string(font, Vector2(area.position.x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, area.size.x, fsize, col)

func _draw_rounded_rect(rect: Rect2, col: Color, radius: float, fill: bool = true, width: float = 1.0) -> void:
	var r: float = minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	var pts := PackedVector2Array()
	var c_tl := rect.position + Vector2(r, r)
	var c_tr := Vector2(rect.end.x - r, rect.position.y + r)
	var c_br := rect.end - Vector2(r, r)
	var c_bl := Vector2(rect.position.x + r, rect.end.y - r)

	for i in range(5):
		var a: float = PI + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_tl + Vector2(cos(a), sin(a)) * r)
	for i in range(5):
		var a: float = -PI * 0.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_tr + Vector2(cos(a), sin(a)) * r)
	for i in range(5):
		var a: float = 0.0 + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_br + Vector2(cos(a), sin(a)) * r)
	for i in range(5):
		var a: float = PI * 0.5 + float(i) * (PI * 0.5 / 4.0)
		pts.append(c_bl + Vector2(cos(a), sin(a)) * r)

	if fill:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, width)
