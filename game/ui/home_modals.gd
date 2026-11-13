class_name HomeSubModal
extends Control

signal closed()
signal cosmetic_equipped(color: Color)

const FONT_BOLD := preload("res://game/ui/fonts/LilitaOne-Regular.ttf")

const SLATE_BG := Color(0.149, 0.176, 0.259, 0.98)
const SLATE_BEVEL := Color(0.098, 0.118, 0.176, 1.0)
const DARK_BORDER := Color(0.063, 0.075, 0.118, 1.0)
const GOLD_FILL := Color(0.941, 0.745, 0.094, 1.0)
const GOLD_BEVEL := Color(0.765, 0.565, 0.047, 1.0)
const GREEN_FILL := Color(0.18, 0.80, 0.44, 1.0)
const GREEN_BEVEL := Color(0.10, 0.55, 0.28, 1.0)

const MODE_SHOP: int = 0
const MODE_TASKS: int = 1

var social: SocialManager = null
var active_color: Color = Color.WHITE
var mode: int = MODE_SHOP
var is_open: bool = false

var _card_rect := Rect2()
var _close_rect := Rect2()
var _item_buttons: Array[Dictionary] = []

const SHOP_SKINS: Array[Dictionary] = [
	{ "name": "Blu Reale", "color": Color.WHITE, "swatch": Color(0.18, 0.44, 0.98) },
	{ "name": "Viola Neon", "color": Color(0.42, 0.31, 0.96), "swatch": Color(0.42, 0.31, 0.96) },
	{ "name": "Rosso Furia", "color": Color(0.95, 0.28, 0.28), "swatch": Color(0.95, 0.28, 0.28) },
	{ "name": "Verde Tossico", "color": Color(0.25, 0.90, 0.50), "swatch": Color(0.25, 0.90, 0.50) },
	{ "name": "Oro Abominio", "color": Color(1.0, 0.78, 0.15), "swatch": Color(1.0, 0.78, 0.15) },
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false

func open_shop(current_col: Color) -> void:
	mode = MODE_SHOP
	active_color = current_col
	is_open = true
	visible = true
	queue_redraw()

func open_tasks() -> void:
	mode = MODE_TASKS
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

	if _close_rect.has_point(pos) or not _card_rect.has_point(pos):
		close()
		get_viewport().set_input_as_handled()
		return

	for btn: Dictionary in _item_buttons:
		if (btn["rect"] as Rect2).has_point(pos):
			if mode == MODE_SHOP and social != null:
				var col: Color = btn["color"] as Color
				if not social.is_color_unlocked(col):
					social.unlock_color(col)
				active_color = col
				cosmetic_equipped.emit(col)
			elif mode == MODE_TASKS and social != null:
				social.claim_task(str(btn["id"]))
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	get_viewport().set_input_as_handled()

func _draw() -> void:
	if not is_open:
		return
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)

	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.04, 0.08, 0.72), true)
	var cw: float = sz.x - 44.0
	var ch: float = 520.0
	_card_rect = Rect2(22.0, (sz.y - ch) * 0.5, cw, ch)
	_draw_box(_card_rect, SLATE_BG, SLATE_BEVEL, DARK_BORDER, 16.0, 3.0)

	var title: String = tr(&"SHOP_TITLE") if mode == MODE_SHOP else tr(&"TASKS_TITLE")
	_draw_text_ol(Vector2(_card_rect.position.x + 20.0, _card_rect.position.y + 42.0), title, HORIZONTAL_ALIGNMENT_LEFT, 360.0, 24, GOLD_FILL, 2.5)
	_close_rect = Rect2(_card_rect.end.x - 52.0, _card_rect.position.y + 14.0, 38.0, 38.0)
	_draw_box(_close_rect, Color(0.85, 0.22, 0.26), Color(0.58, 0.12, 0.16), DARK_BORDER, 10.0, 2.0)
	_draw_text_ol(Vector2(_close_rect.position.x, _close_rect.position.y + 27.0), "✕", HORIZONTAL_ALIGNMENT_CENTER, 38.0, 20, Color.WHITE, 2.0)

	_item_buttons.clear()
	if mode == MODE_SHOP:
		_draw_text_ol(Vector2(_card_rect.position.x + 20.0, _card_rect.position.y + 72.0), tr(&"SHOP_SUBTITLE"), HORIZONTAL_ALIGNMENT_LEFT, cw - 40.0, 15, Color(0.78, 0.82, 0.94), 1.5)
		for idx: int in range(SHOP_SKINS.size()):
			var sk: Dictionary = SHOP_SKINS[idx]
			var row := Rect2(_card_rect.position.x + 18.0, _card_rect.position.y + 92.0 + float(idx) * 80.0, cw - 36.0, 68.0)
			_draw_box(row, Color(0.19, 0.22, 0.33), SLATE_BEVEL, DARK_BORDER, 11.0, 2.0)
			draw_circle(Vector2(row.position.x + 32.0, row.position.y + 34.0), 18.0, DARK_BORDER)
			draw_circle(Vector2(row.position.x + 32.0, row.position.y + 34.0), 15.0, sk["swatch"] as Color)
			_draw_text_ol(Vector2(row.position.x + 62.0, row.position.y + 41.0), str(sk["name"]), HORIZONTAL_ALIGNMENT_LEFT, 190.0, 19, Color.WHITE, 2.0)
			var col: Color = sk["color"] as Color
			var unlocked: bool = social.is_color_unlocked(col) if social != null else true
			var eq: bool = active_color.is_equal_approx(col)
			var btn_r := Rect2(row.end.x - 134.0, row.position.y + 13.0, 122.0, 42.0)
			if eq:
				_draw_box(btn_r, Color(0.24, 0.28, 0.40), SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
				_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 27.0), tr(&"SHOP_BTN_EQUIPPED"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 14, GREEN_FILL, 1.5)
			elif unlocked:
				_draw_box(btn_r, GREEN_FILL, GREEN_BEVEL, DARK_BORDER, 9.0, 2.0)
				_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 27.0), tr(&"SHOP_BTN_EQUIP"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 14, Color.WHITE, 1.5)
				_item_buttons.append({ "rect": btn_r, "color": col })
			else:
				_draw_box(btn_r, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 9.0, 2.0)
				_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 27.0), tr(&"SHOP_BTN_UNLOCK"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 13, Color.WHITE, 1.5)
				_item_buttons.append({ "rect": btn_r, "color": col })
	else:
		if social == null:
			return
		var loc: String = TranslationServer.get_locale()
		var is_en: bool = loc.begins_with("en")
		for idx: int in range(social.tasks.size()):
			var t: Dictionary = social.tasks[idx]
			var row := Rect2(_card_rect.position.x + 18.0, _card_rect.position.y + 92.0 + float(idx) * 114.0, cw - 36.0, 98.0)
			_draw_box(row, Color(0.19, 0.22, 0.33), SLATE_BEVEL, DARK_BORDER, 11.0, 2.0)
			var t_title: String = str(t.get("title_en" if is_en else "title_it", ""))
			var prog: int = int(t.get("progress", 0))
			var tgt: int = int(t.get("target", 1))
			var claimed: bool = bool(t.get("claimed", false))
			var xp: int = int(t.get("xp", 100))
			_draw_text_ol(Vector2(row.position.x + 16.0, row.position.y + 32.0), t_title, HORIZONTAL_ALIGNMENT_LEFT, 240.0, 20, Color.WHITE, 2.0)
			var p_str: String = tr(&"TASKS_IN_PROGRESS") % [prog, tgt]
			_draw_text_ol(Vector2(row.position.x + 16.0, row.position.y + 66.0), p_str, HORIZONTAL_ALIGNMENT_LEFT, 160.0, 16, GOLD_FILL, 1.5)
			var btn_r := Rect2(row.end.x - 154.0, row.position.y + 26.0, 140.0, 46.0)
			if claimed:
				_draw_box(btn_r, Color(0.24, 0.28, 0.40), SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
				_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 29.0), tr(&"TASKS_CLAIMED"), HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 14, GREEN_FILL, 1.5)
			elif prog >= tgt:
				_draw_box(btn_r, GOLD_FILL, GOLD_BEVEL, DARK_BORDER, 9.0, 2.0)
				_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 29.0), tr(&"TASKS_CLAIM") % xp, HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 14, Color.WHITE, 1.5)
				_item_buttons.append({ "rect": btn_r, "id": str(t.get("id", "")) })
			else:
				_draw_box(btn_r, Color(0.14, 0.16, 0.25), SLATE_BEVEL, DARK_BORDER, 9.0, 2.0)
				_draw_text_ol(Vector2(btn_r.position.x, btn_r.position.y + 29.0), "+%d XP" % xp, HORIZONTAL_ALIGNMENT_CENTER, btn_r.size.x, 15, Color(0.65, 0.68, 0.80), 1.5)

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
