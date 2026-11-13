class_name InGameSettingsModal
extends Control
## Settings card, used both in the home menu and during a match.
##
## In a match (`in_match`) it warns that the fight goes on behind it and offers Leave / Resume.
## In the home menu it shows the guest account instead, with Google / Apple linking, and a
## plain Close. Same look as the shop and the Season Pass (UIKit).

signal closed()
signal leave_match_requested()
signal music_volume_changed(val: float)
signal sfx_volume_changed(val: float)
signal language_changed(locale: String)
signal screen_shake_changed(enabled: bool)

const SUB_NONE: int = 0
const SUB_PRIVACY: int = 1
const SUB_TERMS: int = 2
const SUB_ACCOUNT: int = 3
const SETTINGS_PATH: String = "user://settings.cfg"

## Shared by the home and the match cards, read by the camera shake.
static var screen_shake_on: bool = true
static var _shake_loaded: bool = false

var sound_controller: SoundController
var social: SocialManager = null
var account: AccountService = null
var in_match: bool = true
var music_volume: float = 0.45
var sfx_volume: float = 0.85
var current_locale: String = "it"
var sub_dialog: int = SUB_NONE

var is_open: bool = false
var _time: float = 0.0
var _account_note: String = ""

var _card_rect := Rect2()
var _close_btn_rect := Rect2()
var _music_minus_rect := Rect2()
var _music_plus_rect := Rect2()
var _music_mute_rect := Rect2()
var _music_bar_rect := Rect2()
var _sfx_minus_rect := Rect2()
var _sfx_plus_rect := Rect2()
var _sfx_mute_rect := Rect2()
var _sfx_bar_rect := Rect2()
var _shake_rect := Rect2()
var _lang_it_rect := Rect2()
var _lang_en_rect := Rect2()
var _privacy_btn_rect := Rect2()
var _tos_btn_rect := Rect2()
var _google_btn_rect := Rect2()
var _apple_btn_rect := Rect2()
var _unlink_btn_rect := Rect2()
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
	load_shake_setting()

func _process(delta: float) -> void:
	if visible and is_open:
		_time += delta
		queue_redraw()

func open() -> void:
	is_open = true
	visible = true
	sub_dialog = SUB_NONE
	current_locale = TranslationServer.get_locale()
	if sound_controller != null:
		music_volume = sound_controller.get_music_volume_linear()
		sfx_volume = sound_controller.get_sfx_volume_linear()
	if social != null:
		social.ensure_guest_id()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout(_view_size())
	queue_redraw()

func close() -> void:
	is_open = false
	visible = false
	sub_dialog = SUB_NONE
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

func set_screen_shake(enabled: bool) -> void:
	screen_shake_on = enabled
	screen_shake_changed.emit(enabled)
	if DisplayServer.get_name() != "headless":
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value("accessibility", "screen_shake", enabled)
		cfg.save(SETTINGS_PATH)
	queue_redraw()

static func load_shake_setting() -> void:
	if _shake_loaded or DisplayServer.get_name() == "headless":
		return
	_shake_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		screen_shake_on = bool(cfg.get_value("accessibility", "screen_shake", true))

## Asks the account service to link a provider; explains honestly when no backend is live.
func request_link(provider_id: String) -> Dictionary:
	if account == null:
		_account_note = tr(&"ACCOUNT_LINK_SOON")
		sub_dialog = SUB_ACCOUNT
		return { "ok": false, "reason": "not_configured" }
	var res: Dictionary = account.link(provider_id)
	if not bool(res["ok"]):
		match str(res["reason"]):
			"not_configured":
				_account_note = tr(&"ACCOUNT_LINK_SOON")
			"busy":
				_account_note = tr(&"ACCOUNT_LINK_BUSY")
			_:
				_account_note = ""
		if _account_note != "":
			sub_dialog = SUB_ACCOUNT
	queue_redraw()
	return res

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

func _view_size() -> Vector2:
	var view_size: Vector2 = size
	if view_size.x < 10.0:
		view_size = get_viewport_rect().size
		if view_size.x < 10.0:
			view_size = Vector2(540.0, 960.0)
	return view_size

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

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
	elif event.is_action_pressed(&"ui_cancel"):
		if sub_dialog != SUB_NONE:
			sub_dialog = SUB_NONE
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if not is_click:
		return
	handle_tap(pos)
	get_viewport().set_input_as_handled()

## One tap on the card. Public so tests can drive the card without real input events.
func handle_tap(pos: Vector2) -> void:
	_layout(_view_size())
	if sub_dialog != SUB_NONE:
		if _subdialog_close_rect.has_point(pos):
			sub_dialog = SUB_NONE
		elif _subdialog_link_rect.has_area() and _subdialog_link_rect.has_point(pos):
			var url: String = "https://splicerush.game/privacy" if sub_dialog == SUB_PRIVACY else "https://splicerush.game/terms"
			OS.shell_open(url)
		_layout(_view_size())
		queue_redraw()
		return
	if _close_btn_rect.has_point(pos) or (_resume_btn_rect.has_area() and _resume_btn_rect.has_point(pos)):
		close()
		return
	if _music_mute_rect.has_point(pos):
		music_volume = 0.0 if music_volume > 0.01 else 0.50
		_apply_music()
	elif _music_minus_rect.has_point(pos):
		music_volume = clampf(music_volume - 0.20, 0.0, 1.0)
		_apply_music()
	elif _music_plus_rect.has_point(pos):
		music_volume = clampf(music_volume + 0.20, 0.0, 1.0)
		_apply_music()
	elif _music_bar_rect.has_point(pos):
		music_volume = roundf(clampf((pos.x - _music_bar_rect.position.x) / _music_bar_rect.size.x, 0.0, 1.0) * 5.0) / 5.0
		_apply_music()
	elif _sfx_mute_rect.has_point(pos):
		sfx_volume = 0.0 if sfx_volume > 0.01 else 0.85
		_apply_sfx()
	elif _sfx_minus_rect.has_point(pos):
		sfx_volume = clampf(sfx_volume - 0.20, 0.0, 1.0)
		_apply_sfx()
	elif _sfx_plus_rect.has_point(pos):
		sfx_volume = clampf(sfx_volume + 0.20, 0.0, 1.0)
		_apply_sfx()
	elif _sfx_bar_rect.has_point(pos):
		sfx_volume = roundf(clampf((pos.x - _sfx_bar_rect.position.x) / _sfx_bar_rect.size.x, 0.0, 1.0) * 5.0) / 5.0
		_apply_sfx()
	elif _shake_rect.has_point(pos):
		set_screen_shake(not screen_shake_on)
	elif _lang_it_rect.has_point(pos):
		set_language("it")
	elif _lang_en_rect.has_point(pos):
		set_language("en")
	elif _privacy_btn_rect.has_point(pos):
		sub_dialog = SUB_PRIVACY
	elif _tos_btn_rect.has_point(pos):
		sub_dialog = SUB_TERMS
	elif _google_btn_rect.has_area() and _google_btn_rect.has_point(pos):
		request_link(AccountService.PROVIDER_GOOGLE)
	elif _apple_btn_rect.has_area() and _apple_btn_rect.has_point(pos):
		request_link(AccountService.PROVIDER_APPLE)
	elif _unlink_btn_rect.has_area() and _unlink_btn_rect.has_point(pos):
		if account != null:
			account.unlink()
	elif _leave_match_btn_rect.has_area() and _leave_match_btn_rect.has_point(pos):
		leave_match_requested.emit()
		close()
		return
	elif not _card_rect.has_point(pos):
		close()
		return
	_layout(_view_size())  # rects follow the new state (e.g. a sub-dialog just opened)
	queue_redraw()

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

const ROW_LABEL_H: float = 26.0

func _layout(view_size: Vector2) -> void:
	var card_w: float = minf(476.0, view_size.x - 28.0)
	var card_h: float = 640.0 if in_match else 730.0
	card_h = minf(card_h, view_size.y - 24.0)
	var card_x: float = (view_size.x - card_w) * 0.5
	var card_y: float = (view_size.y - card_h) * 0.5
	_card_rect = Rect2(card_x, card_y, card_w, card_h)
	_close_btn_rect = Rect2(_card_rect.end.x - 62.0, card_y + 16.0, 46.0, 44.0)
	var x0: float = card_x + 22.0
	var inner_w: float = card_w - 44.0
	var y: float = card_y + 78.0
	if in_match:
		y += 44.0 # live-match warning banner

	# Volume rows: label, then [mute][-][bar][+] and the percentage.
	for row: int in range(2):
		var ry: float = y + ROW_LABEL_H
		var mute := Rect2(x0, ry, 42.0, 38.0)
		var minus := Rect2(x0 + 50.0, ry, 38.0, 38.0)
		var plus := Rect2(card_x + card_w - 22.0 - 54.0 - 38.0, ry, 38.0, 38.0)
		var bar := Rect2(minus.end.x + 8.0, ry + 4.0, plus.position.x - minus.end.x - 16.0, 30.0)
		if row == 0:
			_music_mute_rect = mute
			_music_minus_rect = minus
			_music_plus_rect = plus
			_music_bar_rect = bar
		else:
			_sfx_mute_rect = mute
			_sfx_minus_rect = minus
			_sfx_plus_rect = plus
			_sfx_bar_rect = bar
		y += ROW_LABEL_H + 50.0

	# Screen shake toggle (accessibility).
	_shake_rect = Rect2(card_x + card_w - 22.0 - 112.0, y, 112.0, 38.0)
	y += 52.0

	# Language.
	var half: float = (inner_w - 12.0) * 0.5
	_lang_it_rect = Rect2(x0, y + ROW_LABEL_H, half, 42.0)
	_lang_en_rect = Rect2(x0 + half + 12.0, y + ROW_LABEL_H, half, 42.0)
	y += ROW_LABEL_H + 58.0

	# Account (home only).
	_google_btn_rect = Rect2()
	_apple_btn_rect = Rect2()
	_unlink_btn_rect = Rect2()
	if not in_match:
		var linked: bool = account != null and account.is_linked()
		if linked:
			_unlink_btn_rect = Rect2(x0, y + ROW_LABEL_H + 96.0, inner_w, 44.0)
		else:
			_google_btn_rect = Rect2(x0, y + ROW_LABEL_H + 96.0, half, 46.0)
			_apple_btn_rect = Rect2(x0 + half + 12.0, y + ROW_LABEL_H + 96.0, half, 46.0)
		y += ROW_LABEL_H + 160.0

	# Legal.
	_privacy_btn_rect = Rect2(x0, y, half, 40.0)
	_tos_btn_rect = Rect2(x0 + half + 12.0, y, half, 40.0)
	y += 56.0

	# Bottom buttons.
	if in_match:
		_leave_match_btn_rect = Rect2(x0, y, inner_w, 52.0)
		_resume_btn_rect = Rect2(x0, y + 64.0, inner_w, 56.0)
	else:
		_leave_match_btn_rect = Rect2()
		_resume_btn_rect = Rect2(x0, _card_rect.end.y - 80.0, inner_w, 58.0)

	var sub_w: float = minf(480.0, view_size.x - 28.0)
	var sub_h: float = 520.0 if sub_dialog != SUB_ACCOUNT else 360.0
	_subdialog_rect = Rect2((view_size.x - sub_w) * 0.5, (view_size.y - sub_h) * 0.5, sub_w, sub_h)
	if sub_dialog == SUB_ACCOUNT:
		_subdialog_link_rect = Rect2()
	else:
		_subdialog_link_rect = Rect2(_subdialog_rect.position.x + 24.0, _subdialog_rect.end.y - 120.0, sub_w - 48.0, 46.0)
	_subdialog_close_rect = Rect2(_subdialog_rect.position.x + 24.0, _subdialog_rect.end.y - 64.0, sub_w - 48.0, 48.0)

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if not visible or not is_open:
		return
	var view_size: Vector2 = _view_size()
	_layout(view_size)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.03, 0.03, 0.10, 0.62 if in_match else 0.70), true)

	var card: Rect2 = _card_rect
	UIKit.box(self, card, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 22.0, 3.0, 6.0)
	UIKit.text(self, Vector2(card.position.x + 24.0, card.position.y + 50.0), tr(&"SETTINGS_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 100.0, 30, UIKit.GOLD, 3.0)
	UIKit.box(self, _close_btn_rect, Color(0.30, 0.34, 0.48), UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
	_draw_cross(_close_btn_rect.get_center(), 9.0, Color.WHITE)

	var x0: float = card.position.x + 22.0
	var inner_w: float = card.size.x - 44.0
	if in_match:
		var banner := Rect2(x0, card.position.y + 72.0, inner_w, 34.0)
		var pulse: float = 0.70 + 0.30 * sin(_time * 6.0)
		UIKit.flat(self, banner, Color(0.42, 0.10, 0.18), 10.0, Color(1.0, 0.40, 0.48, pulse), 2.0)
		UIKit.text_in(self, banner, tr(&"SETTINGS_MATCH_CONTINUES_HINT"), 15, Color(1.0, 0.90, 0.35), 1.5)

	_row_label(_music_mute_rect.position.y - 8.0, tr(&"SETTINGS_MUSIC"))
	_draw_volume(_music_mute_rect, _music_minus_rect, _music_bar_rect, _music_plus_rect, music_volume, Color(0.24, 0.80, 1.0))
	_row_label(_sfx_mute_rect.position.y - 8.0, tr(&"SETTINGS_SFX"))
	_draw_volume(_sfx_mute_rect, _sfx_minus_rect, _sfx_bar_rect, _sfx_plus_rect, sfx_volume, UIKit.GOLD)

	UIKit.text(self, Vector2(x0, _shake_rect.position.y + 27.0), tr(&"SETTINGS_SHAKE"), HORIZONTAL_ALIGNMENT_LEFT, inner_w - 120.0, 18, Color.WHITE, 2.0)
	_draw_toggle(_shake_rect, screen_shake_on)

	_row_label(_lang_it_rect.position.y - 8.0, tr(&"SETTINGS_LANGUAGE"))
	_choice_button(_lang_it_rect, tr(&"SETTINGS_LANG_IT"), current_locale.begins_with("it"))
	_choice_button(_lang_en_rect, tr(&"SETTINGS_LANG_EN"), current_locale.begins_with("en"))

	if not in_match:
		_draw_account(x0, inner_w)

	_small_button(_privacy_btn_rect, tr(&"SETTINGS_PRIVACY_POLICY"))
	_small_button(_tos_btn_rect, tr(&"SETTINGS_TERMS_OF_SERVICE"))

	if in_match:
		UIKit.box(self, _leave_match_btn_rect, UIKit.MAGENTA, UIKit.MAGENTA_BEVEL, UIKit.DARK, 14.0, 2.5)
		UIKit.text_in(self, _leave_match_btn_rect, tr(&"SETTINGS_LEAVE_MATCH"), 21, Color.WHITE, 2.5)
		UIKit.box(self, _resume_btn_rect, UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 14.0, 2.5)
		UIKit.text_in(self, _resume_btn_rect, tr(&"SETTINGS_RESUME"), 23, Color.WHITE, 2.5)
	else:
		UIKit.box(self, _resume_btn_rect, UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 14.0, 2.5)
		UIKit.text_in(self, _resume_btn_rect, tr(&"SETTINGS_CLOSE"), 24, Color.WHITE, 2.5)

	if sub_dialog != SUB_NONE:
		_draw_subdialog(view_size)

func _row_label(baseline_y: float, txt: String) -> void:
	UIKit.text(self, Vector2(_card_rect.position.x + 22.0, baseline_y), txt, HORIZONTAL_ALIGNMENT_LEFT, _card_rect.size.x - 44.0, 18, Color.WHITE, 2.0)

func _draw_account(x0: float, inner_w: float) -> void:
	var top: float = _lang_it_rect.end.y + 16.0
	_row_label(top + ROW_LABEL_H - 8.0, tr(&"ACCOUNT_TITLE"))
	var card := Rect2(x0, top + ROW_LABEL_H, inner_w, 86.0)
	UIKit.flat(self, card, Color(0.10, 0.12, 0.20), 14.0, UIKit.DARK, 2.0)
	var linked: bool = account != null and account.is_linked()
	# Badge: a person for a guest, a check for a linked account (shape, not only colour).
	var badge_c := Vector2(card.position.x + 40.0, card.get_center().y)
	draw_circle(badge_c, 26.0, UIKit.DARK)
	draw_circle(badge_c, 23.0, UIKit.GREEN if linked else UIKit.VIOLET)
	if linked:
		UIKit.check(self, badge_c, 22.0, Color.WHITE, 5.0)
	else:
		draw_circle(badge_c + Vector2(0.0, -6.0), 7.5, Color.WHITE)
		draw_colored_polygon(PackedVector2Array([badge_c + Vector2(-13.0, 15.0), badge_c + Vector2(-9.0, 4.0), badge_c + Vector2(9.0, 4.0), badge_c + Vector2(13.0, 15.0)]), Color.WHITE)
	var tx: float = card.position.x + 80.0
	var tw: float = card.size.x - 92.0
	var guest: String = social.ensure_guest_id() if social != null else ""
	if linked:
		var prov_key: StringName = &"ACCOUNT_PROVIDER_GOOGLE" if account.get_linked_provider() == AccountService.PROVIDER_GOOGLE else &"ACCOUNT_PROVIDER_APPLE"
		UIKit.text(self, Vector2(tx, card.position.y + 34.0), tr(&"ACCOUNT_LINKED_TO") % tr(prov_key), HORIZONTAL_ALIGNMENT_LEFT, tw, 19, UIKit.GREEN, 2.0)
		UIKit.text(self, Vector2(tx, card.position.y + 62.0), social.linked_display if social != null and social.linked_display != "" else guest, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, Color(0.85, 0.88, 1.0), 1.5)
	else:
		UIKit.text(self, Vector2(tx, card.position.y + 32.0), tr(&"ACCOUNT_GUEST") % guest, HORIZONTAL_ALIGNMENT_LEFT, tw, 19, Color.WHITE, 2.0)
		UIKit.text(self, Vector2(tx, card.position.y + 56.0), tr(&"ACCOUNT_GUEST_HINT_1"), HORIZONTAL_ALIGNMENT_LEFT, tw, 14, Color(0.80, 0.84, 0.98), 1.0)
		UIKit.text(self, Vector2(tx, card.position.y + 75.0), tr(&"ACCOUNT_GUEST_HINT_2"), HORIZONTAL_ALIGNMENT_LEFT, tw, 14, Color(0.80, 0.84, 0.98), 1.0)
	if linked:
		_small_button(_unlink_btn_rect, tr(&"ACCOUNT_UNLINK"))
		return
	# Text-only buttons for now: the final ones must follow Google's and Apple's sign-in
	# button guidelines once the real SDKs are in.
	UIKit.box(self, _google_btn_rect, Color(0.97, 0.97, 0.99), Color(0.74, 0.76, 0.84), UIKit.DARK, 12.0, 2.5)
	UIKit.text_in(self, _google_btn_rect, tr(&"ACCOUNT_LINK_GOOGLE"), 17, Color(0.16, 0.18, 0.26), 0.0)
	UIKit.box(self, _apple_btn_rect, Color(0.07, 0.07, 0.09), Color(0.0, 0.0, 0.0), UIKit.DARK, 12.0, 2.5)
	UIKit.text_in(self, _apple_btn_rect, tr(&"ACCOUNT_LINK_APPLE"), 17, Color.WHITE, 0.0)

func _draw_volume(mute_r: Rect2, min_r: Rect2, bar_r: Rect2, plus_r: Rect2, vol: float, bar_col: Color) -> void:
	var muted: bool = vol <= 0.01
	UIKit.box(self, mute_r, Color(0.52, 0.16, 0.24) if muted else Color(0.30, 0.34, 0.48), UIKit.SLATE_BEVEL, UIKit.DARK, 10.0, 2.0, 3.0)
	_draw_speaker(mute_r.get_center(), muted)
	UIKit.box(self, min_r, Color(0.30, 0.34, 0.48), UIKit.SLATE_BEVEL, UIKit.DARK, 10.0, 2.0, 3.0)
	draw_rect(Rect2(min_r.get_center() - Vector2(8.0, 2.0), Vector2(16.0, 4.0)), Color.WHITE)
	UIKit.box(self, plus_r, Color(0.30, 0.34, 0.48), UIKit.SLATE_BEVEL, UIKit.DARK, 10.0, 2.0, 3.0)
	draw_rect(Rect2(plus_r.get_center() - Vector2(8.0, 2.0), Vector2(16.0, 4.0)), Color.WHITE)
	draw_rect(Rect2(plus_r.get_center() - Vector2(2.0, 8.0), Vector2(4.0, 16.0)), Color.WHITE)
	UIKit.flat(self, bar_r, Color(0.07, 0.08, 0.14), 8.0, UIKit.DARK, 2.0)
	var seg_w: float = (bar_r.size.x - 8.0) / 5.0
	var lit: int = int(round(vol * 5.0))
	for i: int in range(5):
		var seg := Rect2(bar_r.position.x + 4.0 + float(i) * seg_w + 1.5, bar_r.position.y + 4.0, seg_w - 3.0, bar_r.size.y - 8.0)
		UIKit.flat(self, seg, bar_col if (i < lit and not muted) else Color(0.20, 0.22, 0.32), 4.0)
	UIKit.text(self, Vector2(plus_r.end.x + 6.0, plus_r.position.y + 27.0), "%d%%" % int(round(vol * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, 54.0, 17, Color.WHITE if not muted else Color(0.6, 0.62, 0.72), 1.5)

func _draw_speaker(c: Vector2, muted: bool) -> void:
	draw_rect(Rect2(c + Vector2(-11.0, -4.0), Vector2(6.0, 8.0)), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5.0, -4.0), c + Vector2(2.0, -10.0), c + Vector2(2.0, 10.0), c + Vector2(-5.0, 4.0)]), Color.WHITE)
	if muted:
		draw_line(c + Vector2(5.0, -5.0), c + Vector2(13.0, 5.0), Color.WHITE, 2.5)
		draw_line(c + Vector2(13.0, -5.0), c + Vector2(5.0, 5.0), Color.WHITE, 2.5)
	else:
		draw_arc(c + Vector2(2.0, 0.0), 7.0, -0.9, 0.9, 8, Color.WHITE, 2.0)
		draw_arc(c + Vector2(2.0, 0.0), 11.0, -0.9, 0.9, 8, Color.WHITE, 2.0)

## ON / OFF pill: the label and the knob side say the state, not just the colour.
func _draw_toggle(r: Rect2, on: bool) -> void:
	UIKit.flat(self, r, UIKit.GREEN if on else Color(0.30, 0.34, 0.48), r.size.y * 0.5, UIKit.DARK, 2.5)
	var knob_x: float = r.end.x - r.size.y * 0.5 if on else r.position.x + r.size.y * 0.5
	draw_circle(Vector2(knob_x, r.get_center().y), r.size.y * 0.5 - 4.0, Color.WHITE)
	var label_r := Rect2(r.position.x + (6.0 if on else r.size.y), r.position.y, r.size.x - r.size.y - 6.0, r.size.y)
	UIKit.text_in(self, label_r, tr(&"SETTINGS_ON") if on else tr(&"SETTINGS_OFF"), 16, Color.WHITE, 1.5)

func _choice_button(r: Rect2, txt: String, selected: bool) -> void:
	if selected:
		UIKit.box(self, r, UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 12.0, 2.5)
		UIKit.check(self, Vector2(r.position.x + 22.0, r.get_center().y), 14.0, Color.WHITE, 3.5)
	else:
		UIKit.box(self, r, Color(0.30, 0.34, 0.48), UIKit.SLATE_BEVEL, UIKit.DARK, 12.0, 2.5)
	UIKit.text_in(self, r, txt, 18, Color.WHITE, 2.0)

func _small_button(r: Rect2, txt: String) -> void:
	UIKit.box(self, r, Color(0.24, 0.28, 0.42), UIKit.SLATE_BEVEL, UIKit.DARK, 10.0, 2.0, 3.0)
	UIKit.text_in(self, r, txt, 15, Color(0.92, 0.94, 1.0), 1.5)

func _draw_cross(c: Vector2, half: float, col: Color) -> void:
	draw_line(c + Vector2(-half, -half), c + Vector2(half, half), col, 4.0)
	draw_line(c + Vector2(half, -half), c + Vector2(-half, half), col, 4.0)

func _draw_subdialog(view_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.02, 0.02, 0.08, 0.70), true)
	var r: Rect2 = _subdialog_rect
	UIKit.box(self, r, UIKit.SLATE, UIKit.SLATE_BEVEL, UIKit.DARK, 20.0, 3.0, 6.0)
	var title: String = ""
	var body: String = ""
	match sub_dialog:
		SUB_PRIVACY:
			title = tr(&"SETTINGS_PRIVACY_POLICY")
			body = tr(&"PRIVACY_TEXT")
		SUB_TERMS:
			title = tr(&"SETTINGS_TERMS_OF_SERVICE")
			body = tr(&"TOS_TEXT")
		SUB_ACCOUNT:
			title = tr(&"ACCOUNT_TITLE")
			body = _account_note
	UIKit.text(self, Vector2(r.position.x + 24.0, r.position.y + 50.0), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 48.0, 26, UIKit.GOLD, 2.5)
	_draw_wrapped_text(body, Rect2(r.position.x + 24.0, r.position.y + 72.0, r.size.x - 48.0, r.size.y - 190.0), 17, Color(0.92, 0.94, 1.0))
	if _subdialog_link_rect.has_area():
		UIKit.box(self, _subdialog_link_rect, Color(0.24, 0.40, 0.80), Color(0.14, 0.26, 0.58), UIKit.DARK, 12.0, 2.5)
		UIKit.text_in(self, _subdialog_link_rect, tr(&"SETTINGS_OPEN_WEB"), 18, Color.WHITE, 2.0)
	UIKit.box(self, _subdialog_close_rect, UIKit.GOLD, UIKit.GOLD_BEVEL, UIKit.DARK, 12.0, 2.5)
	UIKit.text_in(self, _subdialog_close_rect, tr(&"SETTINGS_CLOSE"), 20, Color.WHITE, 2.0)

func _draw_wrapped_text(text: String, area: Rect2, fsize: int, col: Color) -> void:
	var words: PackedStringArray = text.split(" ")
	var line: String = ""
	var line_y: float = area.position.y + float(fsize)
	var line_h: float = float(fsize) * 1.35
	for w: String in words:
		var test_line: String = w if line == "" else (line + " " + w)
		if UIKit.text_width(test_line, fsize) > area.size.x and line != "":
			UIKit.text(self, Vector2(area.position.x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, area.size.x, fsize, col, 1.0)
			line = w
			line_y += line_h
		else:
			line = test_line
	if line != "":
		UIKit.text(self, Vector2(area.position.x, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, area.size.x, fsize, col, 1.0)
