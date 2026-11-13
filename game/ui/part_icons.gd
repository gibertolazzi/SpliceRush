class_name PartIcons
extends RefCounted
## Flat vector icons for the 16 parts, shared by the Aspetto screen and anything else that
## lists parts. Each icon fits a square box; the rarity colour frames it.

static func draw(ci: CanvasItem, pid: StringName, box: Rect2, r_col: Color) -> void:
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
			_chamfer(ci, v_rect, dark, Color(0.4, 0.4, 0.5), 3.0)
			ci.draw_circle(c, 6.0, Color(0.95, 0.15, 0.15))
			ci.draw_circle(c, 3.0, Color(1.0, 0.9, 0.9))
			ci.draw_line(Vector2(c.x - 14.0, c.y), Vector2(c.x + 14.0, c.y), Color(1.0, 0.25, 0.25, 0.9), 1.5)
			ci.draw_line(Vector2(c.x, c.y - 6.0), Vector2(c.x, c.y + 6.0), Color(1.0, 0.25, 0.25, 0.9), 1.5)

		&"visor_head":
			# Sleek cyber glasses with glowing cyan lenses
			var v_rect := Rect2(c.x - 16.0, c.y - 8.0, 32.0, 16.0)
			_chamfer(ci, v_rect, dark, Color(0.3, 0.28, 0.45), 4.0)
			var l1 := Rect2(c.x - 13.0, c.y - 4.0, 11.0, 8.0)
			var l2 := Rect2(c.x + 2.0, c.y - 4.0, 11.0, 8.0)
			ci.draw_rect(l1, cyan, true)
			ci.draw_rect(l2, cyan, true)
			ci.draw_line(Vector2(c.x - 11.0, c.y - 2.0), Vector2(c.x - 4.0, c.y - 2.0), white, 1.5)

		&"spike_helm":
			# Gladiator helmet with 3 sharp golden spikes
			var h_rect := Rect2(c.x - 13.0, c.y - 3.0, 26.0, 16.0)
			_chamfer(ci, h_rect, Color(0.25, 0.20, 0.38), r_col, 4.0)
			var pts_mid := PackedVector2Array([Vector2(c.x - 4.0, c.y - 3.0), Vector2(c.x, c.y - 16.0), Vector2(c.x + 4.0, c.y - 3.0)])
			var pts_l := PackedVector2Array([Vector2(c.x - 11.0, c.y - 2.0), Vector2(c.x - 8.0, c.y - 11.0), Vector2(c.x - 5.0, c.y - 3.0)])
			var pts_r := PackedVector2Array([Vector2(c.x + 5.0, c.y - 3.0), Vector2(c.x + 8.0, c.y - 11.0), Vector2(c.x + 11.0, c.y - 2.0)])
			ci.draw_colored_polygon(pts_mid, gold)
			ci.draw_colored_polygon(pts_l, gold)
			ci.draw_colored_polygon(pts_r, gold)

		&"base_head":
			# Blocky hero cube head with visor slit
			var h_rect := Rect2(c.x - 13.0, c.y - 13.0, 26.0, 26.0)
			_chamfer(ci, h_rect, Color(0.38, 0.30, 0.62), Color(0.55, 0.45, 0.78), 4.0)
			var eye_rect := Rect2(c.x - 9.0, c.y - 4.0, 18.0, 7.0)
			ci.draw_rect(eye_rect, cyan, true)

		&"chainsaw_arm":
			# Industrial orange motor + gray serrated guide bar
			var mot := Rect2(c.x - 15.0, c.y - 7.0, 11.0, 14.0)
			_chamfer(ci, mot, Color(1.0, 0.48, 0.08), gold, 2.0)
			var bar := Rect2(c.x - 4.0, c.y - 4.0, 19.0, 8.0)
			ci.draw_rect(bar, Color(0.72, 0.72, 0.80), true)
			for ti: int in range(4):
				var tx: float = c.x - 2.0 + float(ti) * 4.5
				ci.draw_line(Vector2(tx, c.y - 4.0), Vector2(tx + 2.0, c.y - 7.0), white, 1.5)
				ci.draw_line(Vector2(tx, c.y + 4.0), Vector2(tx + 2.0, c.y + 7.0), white, 1.5)

		&"giant_fist":
			# Massive metallic gauntlet with knuckle plates
			var f_rect := Rect2(c.x - 13.0, c.y - 12.0, 26.0, 24.0)
			_chamfer(ci, f_rect, Color(0.85, 0.22, 0.58), gold, 5.0)
			for ki: int in range(4):
				var kx: float = c.x - 10.0 + float(ki) * 5.5
				ci.draw_rect(Rect2(kx, c.y - 10.0, 4.0, 7.0), gold, true)

		&"mega_claws":
			# Razor triple talons with energy tips
			var b_rect := Rect2(c.x - 14.0, c.y - 8.0, 8.0, 16.0)
			_chamfer(ci, b_rect, dark, r_col, 2.0)
			for claw_i: int in range(3):
				var cy: float = c.y - 7.0 + float(claw_i) * 7.0
				var pts := PackedVector2Array([
					Vector2(c.x - 6.0, cy - 2.0),
					Vector2(c.x + 15.0, cy),
					Vector2(c.x - 6.0, cy + 2.0)
				])
				ci.draw_colored_polygon(pts, gold)
				ci.draw_line(Vector2(c.x + 4.0, cy), Vector2(c.x + 16.0, cy), Color(1.0, 0.2, 0.2), 2.0)

		&"base_fist":
			# Rounded brawler glove
			var f_rect := Rect2(c.x - 12.0, c.y - 12.0, 24.0, 24.0)
			_chamfer(ci, f_rect, Color(0.44, 0.35, 0.78), Color(0.65, 0.55, 0.92), 6.0)
			ci.draw_circle(Vector2(c.x + 6.0, c.y + 3.0), 4.5, Color(0.55, 0.45, 0.88))

		&"rocket_legs":
			# Dual rocket thrusters with flame exhaust
			var t1 := Rect2(c.x - 12.0, c.y - 11.0, 9.0, 16.0)
			var t2 := Rect2(c.x + 3.0, c.y - 11.0, 9.0, 16.0)
			_chamfer(ci, t1, Color(0.90, 0.15, 0.20), white, 2.0)
			_chamfer(ci, t2, Color(0.90, 0.15, 0.20), white, 2.0)
			ci.draw_rect(Rect2(c.x - 11.0, c.y + 4.0, 7.0, 3.0), Color(0.2, 0.2, 0.25), true)
			ci.draw_rect(Rect2(c.x + 4.0, c.y + 4.0, 7.0, 3.0), Color(0.2, 0.2, 0.25), true)
			var f1 := PackedVector2Array([Vector2(c.x - 11.0, c.y + 7.0), Vector2(c.x - 7.5, c.y + 15.0), Vector2(c.x - 4.0, c.y + 7.0)])
			var f2 := PackedVector2Array([Vector2(c.x + 4.0, c.y + 7.0), Vector2(c.x + 7.5, c.y + 15.0), Vector2(c.x + 11.0, c.y + 7.0)])
			ci.draw_colored_polygon(f1, Color(1.0, 0.60, 0.10))
			ci.draw_colored_polygon(f2, Color(1.0, 0.60, 0.10))

		&"roller_wheels":
			# Dual speed wheels with chassis
			ci.draw_rect(Rect2(c.x - 14.0, c.y - 6.0, 28.0, 5.0), Color(0.35, 0.25, 0.50), true)
			ci.draw_circle(Vector2(c.x - 7.0, c.y + 3.0), 8.0, Color(0.16, 0.14, 0.24))
			ci.draw_circle(Vector2(c.x - 7.0, c.y + 3.0), 8.0, magenta, false, 2.0)
			ci.draw_circle(Vector2(c.x - 7.0, c.y + 3.0), 2.5, cyan)
			ci.draw_circle(Vector2(c.x + 7.0, c.y + 3.0), 8.0, Color(0.16, 0.14, 0.24))
			ci.draw_circle(Vector2(c.x + 7.0, c.y + 3.0), 8.0, magenta, false, 2.0)
			ci.draw_circle(Vector2(c.x + 7.0, c.y + 3.0), 2.5, cyan)

		&"spring_legs":
			# High-tension coil spring
			ci.draw_rect(Rect2(c.x - 11.0, c.y - 12.0, 22.0, 4.0), Color(0.3, 0.3, 0.4), true)
			var spr := PackedVector2Array([
				Vector2(c.x - 7.0, c.y - 8.0),
				Vector2(c.x + 7.0, c.y - 4.0),
				Vector2(c.x - 7.0, c.y),
				Vector2(c.x + 7.0, c.y + 4.0),
				Vector2(c.x - 7.0, c.y + 8.0),
				Vector2(c.x + 5.0, c.y + 11.0)
			])
			ci.draw_polyline(spr, cyan, 2.8, true)
			ci.draw_rect(Rect2(c.x - 9.0, c.y + 11.0, 18.0, 4.0), Color(0.4, 0.4, 0.5), true)

		&"base_boots":
			# Armored combat boots
			var b1 := Rect2(c.x - 12.0, c.y - 8.0, 10.0, 18.0)
			var b2 := Rect2(c.x + 2.0, c.y - 8.0, 10.0, 18.0)
			_chamfer(ci, b1, Color(0.28, 0.24, 0.38), Color(0.48, 0.44, 0.60), 3.0)
			_chamfer(ci, b2, Color(0.28, 0.24, 0.38), Color(0.48, 0.44, 0.60), 3.0)
			ci.draw_rect(Rect2(c.x - 13.0, c.y + 7.0, 12.0, 4.0), Color(0.14, 0.12, 0.20), true)
			ci.draw_rect(Rect2(c.x + 1.0, c.y + 7.0, 12.0, 4.0), Color(0.14, 0.12, 0.20), true)

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
			ci.draw_colored_polygon(pts, gold)
			pts.append(pts[0])
			ci.draw_polyline(pts, Color(1.0, 0.95, 0.6), 1.5, true)
			ci.draw_circle(Vector2(c.x, c.y - 11.0), 2.2, Color(1.0, 0.2, 0.4))
			ci.draw_circle(Vector2(c.x - 14.0, c.y - 3.0), 1.8, cyan)
			ci.draw_circle(Vector2(c.x + 14.0, c.y - 3.0), 1.8, cyan)

		&"shield_core":
			# Reinforced fortress shield
			var pts := PackedVector2Array([
				Vector2(c.x - 12.0, c.y - 10.0),
				Vector2(c.x + 12.0, c.y - 10.0),
				Vector2(c.x + 12.0, c.y),
				Vector2(c.x, c.y + 13.0),
				Vector2(c.x - 12.0, c.y)
			])
			ci.draw_colored_polygon(pts, Color(0.18, 0.55, 0.92))
			pts.append(pts[0])
			ci.draw_polyline(pts, cyan, 2.0, true)
			ci.draw_line(Vector2(c.x - 9.0, c.y - 2.0), Vector2(c.x + 9.0, c.y - 2.0), white, 1.8)
			ci.draw_line(Vector2(c.x, c.y - 8.0), Vector2(c.x, c.y + 8.0), white, 1.8)

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
			ci.draw_colored_polygon(pts, magenta)
			ci.draw_rect(Rect2(c.x - 12.0, c.y - 10.0, 8.0, 5.0), cyan, true)
			ci.draw_rect(Rect2(c.x + 4.0, c.y - 10.0, 8.0, 5.0), gold, true)

		&"base_core":
			# High-tech cyber core reactor
			var r_box := Rect2(c.x - 12.0, c.y - 12.0, 24.0, 24.0)
			_chamfer(ci, r_box, Color(0.24, 0.22, 0.38), cyan, 5.0)
			ci.draw_circle(c, 6.0, cyan)
			ci.draw_circle(c, 2.5, white)

		_:
			ci.draw_rect(box, r_col, true)

static func _chamfer(ci: CanvasItem, rect: Rect2, fill: Color, border: Color, chamfer: float) -> void:
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
	ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, border, 2.0, true)

## Same icon at any size: the artwork is drawn for a 42 px box and scaled around `center`.
static func draw_scaled(ci: CanvasItem, pid: StringName, center: Vector2, size_px: float, r_col: Color) -> void:
	var s: float = size_px / 42.0
	ci.draw_set_transform(center, 0.0, Vector2(s, s))
	draw(ci, pid, Rect2(-21.0, -21.0, 42.0, 42.0), r_col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
