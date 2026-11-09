class_name VerticalHUD
extends Control

var time_remaining_sec: float = 47.0
var stolen_parts_count: int = 4
var screen_shake_enabled: bool = true
var colorblind_mode_enabled: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_safe_area()

func _apply_safe_area() -> void:
	# Safe area inset calculation per game-ui-ux skill
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win := Rect2(Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()))
	if win.size.x > 0 and win.size.y > 0:
		var _inner := safe.intersection(win)
	queue_redraw()

func on_match_time_updated(seconds_left: float) -> void:
	var prev_int: int = int(ceil(time_remaining_sec))
	var next_int: int = int(ceil(seconds_left))
	time_remaining_sec = seconds_left
	if prev_int != next_int:
		queue_redraw()

func on_stolen_parts_updated(new_count: int) -> void:
	if stolen_parts_count != new_count:
		stolen_parts_count = new_count
		queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var rect_size: Vector2 = size
	if rect_size.x < 10.0:
		rect_size = Vector2(540.0, 960.0)

	var navy_bg := Color(0.078, 0.078, 0.196, 0.94)
	var border_col := Color(0.48, 0.42, 0.78, 0.85)
	var magenta := Color(1.0, 0.18, 0.576, 1.0)
	var gold := Color(1.0, 0.76, 0.12, 1.0)
	var white := Color(0.98, 0.98, 1.0, 1.0)

	# 1. TOP-CENTER: Timer Panel (00:47) with Stopwatch Icon
	var timer_rect := Rect2(Vector2(rect_size.x * 0.5 - 66.0, 14.0), Vector2(132.0, 42.0))
	_draw_chamfer_panel(timer_rect, navy_bg, border_col, 6.0)
	var clock_c := timer_rect.position + Vector2(26.0, 22.0)
	draw_arc(clock_c, 10.5, 0.0, TAU, 24, white, 2.4)
	draw_line(clock_c + Vector2(0.0, -10.5), clock_c + Vector2(0.0, -14.5), white, 2.5)
	draw_line(clock_c + Vector2(-4.0, -14.5), clock_c + Vector2(4.0, -14.5), white, 2.5)
	draw_line(clock_c, clock_c + Vector2(4.5, -4.5), white, 2.2)

	var total_sec: int = maxi(0, int(ceil(time_remaining_sec)))
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	var timer_str: String = tr(&"HUD_TIMER_FORMAT") % [mins, secs]
	draw_string(font, timer_rect.position + Vector2(45.0, 30.0), timer_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, white)

	# 2. TOP-RIGHT: 4-Slot Panel + Stolen Parts Counter (Decision #1: 4 slots + stolen counter, no fixed threshold)
	var slots_rect := Rect2(Vector2(rect_size.x - 156.0, 14.0), Vector2(144.0, 62.0))
	_draw_chamfer_panel(slots_rect, navy_bg, border_col, 7.0)
	var slot_Colors: Array[Color] = [
		Color(0.75, 0.58, 1.0), # Fist (Epic glow)
		Color(1.0, 0.45, 0.58), # Boot (Rare glow)
		Color(1.0, 0.72, 0.22), # Head (Legendary glow)
		Color(0.78, 0.42, 1.0), # Core (Epic glow)
	]
	for s_idx: int in range(4):
		var sx: float = slots_rect.position.x + 12.0 + float(s_idx) * 32.0
		var sy: float = slots_rect.position.y + 8.0
		var box_r := Rect2(Vector2(sx, sy), Vector2(26.0, 26.0))
		draw_rect(box_r, Color(0.14, 0.12, 0.30, 0.95), true)
		draw_rect(box_r, slot_Colors[s_idx], false, 1.8)
		_draw_slot_mini_icon(s_idx, box_r.get_center(), slot_Colors[s_idx])

	var counter_str: String = tr(&"HUD_STOLEN_COUNTER") % [stolen_parts_count]
	draw_string(font, slots_rect.position + Vector2(62.0, 54.0), counter_str, HORIZONTAL_ALIGNMENT_CENTER, 32.0, 16, white)

	# 3. TOP-LEFT: Stylized SPLICE RUSH Logo with Golden Crown
	var logo_origin := Vector2(14.0, 18.0)
	var logo_bg_pts := PackedVector2Array([
		logo_origin + Vector2(0.0, 14.0),
		logo_origin + Vector2(146.0, 2.0),
		logo_origin + Vector2(138.0, 78.0),
		logo_origin + Vector2(6.0, 92.0),
	])
	draw_colored_polygon(logo_bg_pts, Color(0.05, 0.04, 0.14, 0.96))
	draw_polyline(logo_bg_pts, magenta, 2.5)
	_draw_crown(logo_origin + Vector2(56.0, 6.0), 16.0, gold)
	draw_string(font, logo_origin + Vector2(14.0, 42.0), tr(&"GAME_TITLE_TOP"), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, white)
	draw_string(font, logo_origin + Vector2(22.0, 74.0), tr(&"GAME_TITLE_BOTTOM"), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, magenta)

	# 4. BOTTOM-LEFT: Tutorial Callout ("RUBA I PEZZI!" + 4-Slot Body Diagram)
	var callout_pos := Vector2(12.0, rect_size.y - 250.0)
	var header_pts := PackedVector2Array([
		callout_pos + Vector2(0.0, 8.0),
		callout_pos + Vector2(104.0, 0.0),
		callout_pos + Vector2(98.0, 42.0),
		callout_pos + Vector2(4.0, 48.0),
	])
	draw_colored_polygon(header_pts, Color(0.06, 0.06, 0.14, 0.96))
	var steal_lines: PackedStringArray = tr(&"HUD_STEAL_PARTS").split("\n")
	if steal_lines.size() > 0:
		draw_string(font, callout_pos + Vector2(12.0, 21.0), steal_lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, white)
	if steal_lines.size() > 1:
		draw_string(font, callout_pos + Vector2(12.0, 37.0), steal_lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gold)

	var diag_rect := Rect2(callout_pos + Vector2(2.0, 50.0), Vector2(114.0, 128.0))
	_draw_chamfer_panel(diag_rect, navy_bg, border_col, 6.0)
	# Blocky Body Silhouette on left of diagram
	var fig_c := diag_rect.position + Vector2(32.0, 66.0)
	draw_rect(Rect2(fig_c + Vector2(-9.0, -34.0), Vector2(18.0, 16.0)), Color(0.95, 0.92, 0.84), true) # Head
	draw_rect(Rect2(fig_c + Vector2(-12.0, -15.0), Vector2(24.0, 26.0)), Color(0.95, 0.92, 0.84), true) # Torso
	draw_rect(Rect2(fig_c + Vector2(-21.0, -14.0), Vector2(8.0, 22.0)), Color(0.95, 0.92, 0.84), true) # L Arm
	draw_rect(Rect2(fig_c + Vector2(13.0, -14.0), Vector2(8.0, 22.0)), Color(0.95, 0.92, 0.84), true) # R Arm
	draw_rect(Rect2(fig_c + Vector2(-11.0, 12.0), Vector2(9.0, 24.0)), Color(0.95, 0.92, 0.84), true) # L Leg
	draw_rect(Rect2(fig_c + Vector2(2.0, 12.0), Vector2(9.0, 24.0)), Color(0.95, 0.92, 0.84), true) # R Leg

	for i: int in range(4):
		var icon_c := diag_rect.position + Vector2(88.0, 22.0 + float(i) * 28.0)
		draw_line(fig_c + Vector2(14.0, -18.0 + float(i) * 12.0), icon_c + Vector2(-14.0, 0.0), Color(0.75, 0.78, 0.92, 0.85), 1.6)
		draw_circle(icon_c, 11.0, Color(0.16, 0.16, 0.32, 0.95))
		_draw_slot_mini_icon(i, icon_c, slot_Colors[i])

	# 5. BOTTOM-RIGHT: Tilted "DIVENTA L'ABOMINIO!" Banner with Magenta Border & Crown
	var abom_origin := Vector2(rect_size.x - 196.0, rect_size.y - 122.0)
	var abom_pts := PackedVector2Array([
		abom_origin + Vector2(10.0, 18.0),
		abom_origin + Vector2(184.0, 4.0),
		abom_origin + Vector2(176.0, 78.0),
		abom_origin + Vector2(0.0, 90.0),
	])
	draw_colored_polygon(abom_pts, Color(0.05, 0.04, 0.14, 0.96))
	draw_polyline(abom_pts, magenta, 3.2)
	_draw_crown(abom_origin + Vector2(132.0, 0.0), 18.0, gold)
	var abom_lines: PackedStringArray = tr(&"HUD_BECOME_ABOMINATION").split("\n")
	if abom_lines.size() > 0:
		draw_string(font, abom_origin + Vector2(36.0, 42.0), abom_lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, white)
	if abom_lines.size() > 1:
		draw_string(font, abom_origin + Vector2(18.0, 68.0), abom_lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, gold)

func _draw_chamfer_panel(r: Rect2, fill: Color, border: Color, cut: float) -> void:
	var pts := PackedVector2Array([
		Vector2(r.position.x + cut, r.position.y),
		Vector2(r.end.x - cut, r.position.y),
		Vector2(r.end.x, r.position.y + cut),
		Vector2(r.end.x, r.end.y - cut),
		Vector2(r.end.x - cut, r.end.y),
		Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut),
		Vector2(r.position.x, r.position.y + cut),
		Vector2(r.position.x + cut, r.position.y),
	])
	draw_colored_polygon(pts.slice(0, 8), fill)
	draw_polyline(pts, border, 2.0)

func _draw_crown(center: Vector2, half_w: float, col: Color) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-half_w, 10.0),
		center + Vector2(-half_w * 0.85, -6.0),
		center + Vector2(-half_w * 0.35, 3.0),
		center + Vector2(0.0, -10.0),
		center + Vector2(half_w * 0.35, 3.0),
		center + Vector2(half_w * 0.85, -6.0),
		center + Vector2(half_w, 10.0),
	])
	draw_colored_polygon(pts, col)

func _draw_slot_mini_icon(slot_idx: int, c: Vector2, col: Color) -> void:
	var white := Color(0.98, 0.98, 1.0)
	match slot_idx:
		0: # Fist
			draw_rect(Rect2(c + Vector2(-6.0, -5.0), Vector2(12.0, 10.0)), white, true)
			draw_rect(Rect2(c + Vector2(-4.0, 4.0), Vector2(7.0, 4.0)), col, true)
		1: # Boot
			draw_rect(Rect2(c + Vector2(-4.0, -7.0), Vector2(6.0, 11.0)), white, true)
			draw_rect(Rect2(c + Vector2(-4.0, 2.0), Vector2(11.0, 5.0)), col, true)
		2: # Head
			draw_rect(Rect2(c + Vector2(-6.0, -6.0), Vector2(12.0, 12.0)), col, true)
			draw_rect(Rect2(c + Vector2(-3.0, -2.0), Vector2(6.0, 3.0)), white, true)
		3: # Core / Gear
			draw_circle(c, 6.5, col)
			draw_circle(c, 2.8, Color(0.08, 0.08, 0.20))
