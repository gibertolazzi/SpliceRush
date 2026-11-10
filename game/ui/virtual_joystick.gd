class_name TouchJoystick
extends Control

signal joystick_updated(vector: Vector2)
signal ability_triggered()
signal attack_triggered()

@export var max_radius_px: float = 64.0
@export var deadzone: float = 0.16

var current_vector: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _base_pos: Vector2 = Vector2(118.0, 825.0)
var _knob_pos: Vector2 = Vector2(118.0, 825.0)
var _active: bool = false

var _attack_pressed_timer: float = 0.0
var _dash_pressed_timer: float = 0.0

var font_bold: Font = preload("res://game/ui/fonts/LondrinaSolid-Black.ttf")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	var redraw: bool = false
	if _attack_pressed_timer > 0.0:
		_attack_pressed_timer = maxf(0.0, _attack_pressed_timer - delta)
		redraw = true
	if _dash_pressed_timer > 0.0:
		_dash_pressed_timer = maxf(0.0, _dash_pressed_timer - delta)
		redraw = true
	if redraw:
		queue_redraw()

func get_attack_btn_center() -> Vector2:
	var view_size: Vector2 = size
	if view_size.x < 10.0:
		view_size = get_viewport_rect().size
		if view_size.x < 10.0:
			view_size = Vector2(540.0, 960.0)
	return Vector2(view_size.x - 72.0, view_size.y - 126.0)

func get_dash_btn_center() -> Vector2:
	var view_size: Vector2 = size
	if view_size.x < 10.0:
		view_size = get_viewport_rect().size
		if view_size.x < 10.0:
			view_size = Vector2(540.0, 960.0)
	return Vector2(view_size.x - 146.0, view_size.y - 74.0)

func _gui_input(event: InputEvent) -> void:
	var view_size: Vector2 = get_viewport_rect().size
	var att_c := get_attack_btn_center()
	var dash_c := get_dash_btn_center()

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			if st.position.distance_to(att_c) <= 46.0:
				_attack_pressed_timer = 0.16
				attack_triggered.emit()
				queue_redraw()
			elif st.position.distance_to(dash_c) <= 36.0:
				_dash_pressed_timer = 0.16
				ability_triggered.emit()
				queue_redraw()
			elif st.position.x <= view_size.x * 0.58 and st.position.y >= view_size.y * 0.45 and _touch_index == -1:
				_touch_index = st.index
				_active = true
				_base_pos = st.position
				_knob_pos = st.position
				_update_from_positions()
				queue_redraw()
			else:
				# Tapping anywhere else on field triggers attack towards tap
				_attack_pressed_timer = 0.12
				attack_triggered.emit()
				queue_redraw()
		elif st.index == _touch_index:
			_release_stick()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if sd.index == _touch_index and _active:
			_set_knob(sd.position)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.position.distance_to(att_c) <= 46.0:
					_attack_pressed_timer = 0.16
					attack_triggered.emit()
					queue_redraw()
				elif mb.position.distance_to(dash_c) <= 36.0:
					_dash_pressed_timer = 0.16
					ability_triggered.emit()
					queue_redraw()
				elif mb.position.x <= view_size.x * 0.58 and mb.position.y >= view_size.y * 0.45:
					_touch_index = 0
					_active = true
					_base_pos = mb.position
					_knob_pos = mb.position
					_update_from_positions()
					queue_redraw()
				else:
					_attack_pressed_timer = 0.12
					attack_triggered.emit()
					queue_redraw()
			elif _touch_index == 0:
				_release_stick()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_dash_pressed_timer = 0.16
			ability_triggered.emit()
			queue_redraw()
	elif event is InputEventMouseMotion and _active and _touch_index == 0:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_set_knob(mm.position)

func simulate_drag(base: Vector2, drag_to: Vector2) -> Vector2:
	_active = true
	_base_pos = base
	_set_knob(drag_to)
	return current_vector

func _set_knob(pos: Vector2) -> void:
	var delta: Vector2 = pos - _base_pos
	if delta.length() > max_radius_px:
		delta = delta.normalized() * max_radius_px
	_knob_pos = _base_pos + delta
	_update_from_positions()
	queue_redraw()

func _update_from_positions() -> void:
	var raw: Vector2 = (_knob_pos - _base_pos) / maxf(max_radius_px, 1.0)
	current_vector = InputRemapper.apply_radial_deadzone(raw, deadzone, 1.0)
	joystick_updated.emit(current_vector)

func _release_stick() -> void:
	_touch_index = -1
	_active = false
	_knob_pos = _base_pos
	current_vector = Vector2.ZERO
	joystick_updated.emit(Vector2.ZERO)
	queue_redraw()

func _draw() -> void:
	var att_c := get_attack_btn_center()
	var dash_c := get_dash_btn_center()

	# 1. Subtle translucent thumb-zone ring when joystick active
	if _active:
		draw_circle(_base_pos, max_radius_px, Color(0.08, 0.08, 0.20, 0.48))
		draw_arc(_base_pos, max_radius_px, 0.0, TAU, 36, Color(0.65, 0.55, 1.0, 0.72), 3.0)
		draw_circle(_knob_pos, 24.0, Color(1.0, 0.18, 0.58, 0.88))
		draw_arc(_knob_pos, 24.0, 0.0, TAU, 28, Color(1.0, 0.92, 0.98, 0.95), 2.5)

	# 2. Dedicated Attack Button (Mobile UI)
	var is_att_down: bool = (_attack_pressed_timer > 0.0)
	var att_bg := Color(1.0, 0.74, 0.14, 0.95) if is_att_down else Color(0.92, 0.58, 0.08, 0.84)
	var att_border := Color(1.0, 0.92, 0.55, 1.0) if is_att_down else Color(0.18, 0.10, 0.32, 0.90)
	var att_r: float = 34.0 if is_att_down else 37.0
	draw_circle(att_c, att_r, att_bg)
	draw_arc(att_c, att_r, 0.0, TAU, 32, att_border, 3.2)
	# Fist icon inside Attack button
	draw_rect(Rect2(att_c + Vector2(-10.0, -14.0), Vector2(20.0, 16.0)), Color(0.12, 0.08, 0.24, 0.95), true)
	draw_rect(Rect2(att_c + Vector2(-6.0, 2.0), Vector2(12.0, 6.0)), Color(0.12, 0.08, 0.24, 0.95), true)
	var att_text: String = tr(&"HUD_ATTACK_BTN")
	draw_string(font_bold, att_c + Vector2(-28.0, 24.0), att_text, HORIZONTAL_ALIGNMENT_CENTER, 56.0, 13, Color(0.98, 0.98, 1.0))

	# 3. Dedicated Dash / Ability Button
	var is_dash_down: bool = (_dash_pressed_timer > 0.0)
	var dash_bg := Color(1.0, 0.32, 0.68, 0.95) if is_dash_down else Color(0.88, 0.16, 0.52, 0.82)
	var dash_border := Color(1.0, 0.85, 0.95, 1.0) if is_dash_down else Color(0.18, 0.10, 0.32, 0.90)
	var dash_r: float = 25.0 if is_dash_down else 28.0
	draw_circle(dash_c, dash_r, dash_bg)
	draw_arc(dash_c, dash_r, 0.0, TAU, 28, dash_border, 2.6)
	# Lightning bolt icon
	var bolt_pts := PackedVector2Array([
		dash_c + Vector2(-3.0, -10.0),
		dash_c + Vector2(6.0, -2.0),
		dash_c + Vector2(0.0, 0.0),
		dash_c + Vector2(4.0, 10.0),
		dash_c + Vector2(-6.0, 1.0),
		dash_c + Vector2(-1.0, -1.0),
	])
	draw_colored_polygon(bolt_pts, Color(0.98, 0.98, 1.0))
	var dash_text: String = tr(&"HUD_ABILITY_BTN")
	draw_string(font_bold, dash_c + Vector2(-24.0, 21.0), dash_text, HORIZONTAL_ALIGNMENT_CENTER, 48.0, 11, Color(0.98, 0.98, 1.0))
