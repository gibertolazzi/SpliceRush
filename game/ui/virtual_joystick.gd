class_name TouchJoystick
extends Control

signal joystick_updated(vector: Vector2)
signal ability_triggered()

@export var max_radius_px: float = 64.0
@export var deadzone: float = 0.16

var current_vector: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _base_pos: Vector2 = Vector2(118.0, 825.0)
var _knob_pos: Vector2 = Vector2(118.0, 825.0)
var _active: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	var view_size: Vector2 = get_viewport_rect().size
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			# Left 62% of bottom half is floating joystick; right 38% of bottom 35% is ability tap
			if st.position.x <= view_size.x * 0.62 and st.position.y >= view_size.y * 0.48 and _touch_index == -1:
				_touch_index = st.index
				_active = true
				_base_pos = st.position
				_knob_pos = st.position
				_update_from_positions()
				queue_redraw()
			elif st.position.x > view_size.x * 0.62 and st.position.y >= view_size.y * 0.62:
				ability_triggered.emit()
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
				if mb.position.x <= view_size.x * 0.62 and mb.position.y >= view_size.y * 0.48:
					_touch_index = 0
					_active = true
					_base_pos = mb.position
					_knob_pos = mb.position
					_update_from_positions()
					queue_redraw()
				elif mb.position.x > view_size.x * 0.62 and mb.position.y >= view_size.y * 0.62:
					ability_triggered.emit()
			elif _touch_index == 0:
				_release_stick()
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
	# Subtle translucent thumb-zone ring when active (keeps bottom 35% clean when idle, per key-art)
	if _active:
		draw_circle(_base_pos, max_radius_px, Color(0.08, 0.08, 0.20, 0.48))
		draw_arc(_base_pos, max_radius_px, 0.0, TAU, 36, Color(0.65, 0.55, 1.0, 0.72), 3.0)
		draw_circle(_knob_pos, 24.0, Color(1.0, 0.18, 0.58, 0.88))
		draw_arc(_knob_pos, 24.0, 0.0, TAU, 28, Color(1.0, 0.92, 0.98, 0.95), 2.5)
