class_name TouchScreenBase
extends Control
## Base for full-screen menu pages that scroll vertically (shop, Season Pass).
##
## It turns touch and mouse input into one pointer, tells a tap from a drag, and owns the
## scroll position with inertia, rubber-band edges and animated jumps. Subclasses draw in
## three layers: the page background (this node), the scrolled content (clipped to
## `scroll_area`) and an overlay on top for the header, footer and effects.

signal closed()

const TAP_SLOP_PX: float = 12.0
const WHEEL_STEP_PX: float = 90.0
const FRICTION: float = 4.5
const EDGE_PULL: float = 14.0

var is_open: bool = false
var scroll_y: float = 0.0
var scroll_velocity: float = 0.0
var content_height: float = 0.0
var scroll_area := Rect2()
var time_sec: float = 0.0

var _content: Control
var _overlay: Control
var _pointer_down: bool = false
var _pointer_id: int = -1
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _moved: float = 0.0
var _dragging_scroll: bool = false
var _scroll_target: float = -1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_content = Control.new()
	_content.name = "ScrollContent"
	_content.clip_contents = true
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	_content.draw.connect(_on_content_draw)
	add_child(_content)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_on_overlay_draw)
	add_child(_overlay)

func get_screen_size() -> Vector2:
	var sz: Vector2 = size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(540.0, 960.0)
	return sz

func show_screen() -> void:
	is_open = true
	visible = true
	scroll_velocity = 0.0
	_scroll_target = -1.0
	_pointer_down = false
	queue_redraw()

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()

func max_scroll() -> float:
	return maxf(0.0, content_height - scroll_area.size.y)

## Jumps or glides so that content coordinate `y` sits near the top of the scroll area.
func scroll_to(y: float, animated: bool = true) -> void:
	var target: float = clampf(y, 0.0, max_scroll())
	if animated:
		_scroll_target = target
		scroll_velocity = 0.0
	else:
		scroll_y = target
		_scroll_target = -1.0
		scroll_velocity = 0.0

func is_scroll_animating() -> bool:
	return _scroll_target >= 0.0

func _process(delta: float) -> void:
	if not is_open:
		return
	time_sec += delta
	if _scroll_target >= 0.0:
		scroll_y = lerpf(scroll_y, _scroll_target, 1.0 - exp(-9.0 * delta))
		if absf(scroll_y - _scroll_target) < 0.6:
			scroll_y = _scroll_target
			_scroll_target = -1.0
	elif not _dragging_scroll:
		scroll_y += scroll_velocity * delta
		scroll_velocity *= exp(-FRICTION * delta)
		if absf(scroll_velocity) < 4.0:
			scroll_velocity = 0.0
		# Rubber band back inside the content.
		var limit: float = max_scroll()
		if scroll_y < 0.0:
			scroll_y = lerpf(scroll_y, 0.0, 1.0 - exp(-EDGE_PULL * delta))
			scroll_velocity = 0.0
		elif scroll_y > limit:
			scroll_y = lerpf(scroll_y, limit, 1.0 - exp(-EDGE_PULL * delta))
			scroll_velocity = 0.0
	_update_screen(delta)
	_content.position = scroll_area.position
	_content.size = scroll_area.size
	queue_redraw()
	_content.queue_redraw()
	_overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_open or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed and not _pointer_down:
			_pointer_id = st.index
			_begin_pointer(st.position)
		elif not st.pressed and _pointer_down and st.index == _pointer_id:
			_end_pointer(st.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _pointer_down and sd.index == _pointer_id:
			_move_pointer(sd.position, sd.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _pointer_down:
				_pointer_id = -2
				_begin_pointer(mb.position)
			elif not mb.pressed and _pointer_down and _pointer_id == -2:
				_end_pointer(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_wheel(1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_wheel(-1.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _pointer_down and _pointer_id == -2:
			_move_pointer(mm.position, mm.relative)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _wheel(direction: float) -> void:
	if _is_scroll_locked():
		return
	_scroll_target = -1.0
	scroll_y = clampf(scroll_y + direction * WHEEL_STEP_PX, 0.0, max_scroll())
	scroll_velocity = 0.0

func _begin_pointer(pos: Vector2) -> void:
	_pointer_down = true
	_press_pos = pos
	_last_pos = pos
	_moved = 0.0
	_dragging_scroll = false
	scroll_velocity = 0.0

func _move_pointer(pos: Vector2, relative: Vector2) -> void:
	_moved += relative.length()
	_last_pos = pos
	if _is_scroll_locked():
		return
	if not _dragging_scroll and _moved > TAP_SLOP_PX and scroll_area.has_point(_press_pos):
		_dragging_scroll = true
		_scroll_target = -1.0
	if not _dragging_scroll and _moved > TAP_SLOP_PX and not scroll_area.has_point(_press_pos):
		_on_outside_drag(relative)
	if _dragging_scroll:
		var limit: float = max_scroll()
		var resist: float = 0.4 if (scroll_y < 0.0 or scroll_y > limit) else 1.0
		scroll_y -= relative.y * resist
		# Finger speed becomes the fling speed on release.
		scroll_velocity = lerpf(scroll_velocity, -relative.y * 60.0, 0.5)

func _end_pointer(pos: Vector2) -> void:
	var was_drag: bool = _dragging_scroll or _moved > TAP_SLOP_PX
	_pointer_down = false
	_dragging_scroll = false
	if not was_drag:
		scroll_velocity = 0.0
		_on_tap(pos)

## Content coordinates -> screen coordinates for hit testing rows drawn in the scroll area.
func content_to_screen(rect: Rect2) -> Rect2:
	return Rect2(rect.position + scroll_area.position - Vector2(0.0, scroll_y), rect.size)

## True when a screen rect drawn in the scroll area is actually visible there.
func is_hit_in_scroll(rect: Rect2, pos: Vector2) -> bool:
	return rect.has_point(pos) and scroll_area.has_point(pos)

func _on_content_draw() -> void:
	if is_open:
		_draw_content(_content)

func _on_overlay_draw() -> void:
	if is_open:
		_draw_overlay(_overlay)

# --- For subclasses -------------------------------------------------------

## Per-frame state updates (animations, timers) before drawing.
func _update_screen(_delta: float) -> void:
	pass

## Draws the scrolled rows on `ci`, whose origin is the top-left of `scroll_area`.
## Subtract `scroll_y` from every content y.
func _draw_content(_ci: CanvasItem) -> void:
	pass

## Draws the fixed header, footer and effects above the content.
func _draw_overlay(_ci: CanvasItem) -> void:
	pass

func _on_tap(_pos: Vector2) -> void:
	pass

## A drag that started outside the scroll area (e.g. spinning the 3D hero above a panel).
func _on_outside_drag(_relative: Vector2) -> void:
	pass

## Return true while a popup is up and the page must not scroll.
func _is_scroll_locked() -> bool:
	return false
