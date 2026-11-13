class_name UIKit
extends RefCounted
## Shared drawing helpers for the menu screens (shop, Season Pass, rewards): one place for the
## chunky bevelled boxes, outlined Lilita text, coin icon, gradients and easing curves, so every
## screen reads as the same game. All functions draw on the CanvasItem passed as `ci`.

const FONT: Font = preload("res://game/ui/fonts/LilitaOne-Regular.ttf")
const COIN_TEX: Texture2D = preload("res://game/ui/assets/coin.svg")
const CROWN_TEX: Texture2D = preload("res://game/ui/assets/crown.svg")
const TIMER_TEX: Texture2D = preload("res://game/ui/assets/timer.svg")

const DARK := Color(0.063, 0.075, 0.118, 1.0)
const SLATE := Color(0.149, 0.176, 0.259, 1.0)
const SLATE_BEVEL := Color(0.098, 0.118, 0.176, 1.0)
const GOLD := Color(0.941, 0.745, 0.094, 1.0)
const GOLD_BEVEL := Color(0.765, 0.565, 0.047, 1.0)
const GREEN := Color(0.18, 0.80, 0.44, 1.0)
const GREEN_BEVEL := Color(0.10, 0.55, 0.28, 1.0)
const MAGENTA := Color(1.0, 0.18, 0.58, 1.0)
const MAGENTA_BEVEL := Color(0.68, 0.08, 0.36, 1.0)
const VIOLET := Color(0.42, 0.31, 0.96, 1.0)
const CARD_BLUE := Color(0.69, 0.80, 0.98, 1.0)
const CARD_BLUE_BEVEL := Color(0.45, 0.55, 0.86, 1.0)
const BG_TOP := Color(0.32, 0.52, 0.98, 1.0)
const BG_BOTTOM := Color(0.42, 0.32, 0.86, 1.0)
const CONFETTI_COLORS: Array[Color] = [
	Color(1.0, 0.90, 0.10), Color(0.30, 0.90, 0.36), Color(1.0, 0.18, 0.58),
	Color(0.13, 0.89, 0.90), Color(0.98, 0.30, 0.36),
]

static func box(ci: CanvasItem, rect: Rect2, fill: Color, bevel: Color, border: Color = DARK, radius: float = 14.0, bw: float = 2.5, bevel_h: float = 4.0) -> void:
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = bevel
	b_sb.set_corner_radius_all(int(radius))
	b_sb.set_border_width_all(int(ceilf(bw)))
	b_sb.border_color = border
	b_sb.anti_aliasing = true
	ci.draw_style_box(b_sb, Rect2(rect.position.x, rect.position.y + bevel_h, rect.size.x, rect.size.y))
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = fill
	t_sb.set_corner_radius_all(int(radius))
	t_sb.set_border_width_all(int(ceilf(bw)))
	t_sb.border_color = border
	t_sb.anti_aliasing = true
	ci.draw_style_box(t_sb, rect)

static func flat(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = 10.0, border: Color = Color(0, 0, 0, 0), bw: float = 0.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	if bw > 0.0:
		sb.set_border_width_all(int(ceilf(bw)))
		sb.border_color = border
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)

## Outlined text. `pos` is the baseline, like CanvasItem.draw_string.
static func text(ci: CanvasItem, pos: Vector2, txt: String, align: HorizontalAlignment, width: float, font_size: int, col: Color, outline: float = 2.0, outline_col: Color = DARK) -> void:
	if outline > 0.0:
		var oc := Color(outline_col.r, outline_col.g, outline_col.b, outline_col.a * col.a)
		for off: Vector2 in [Vector2(-outline, 0), Vector2(outline, 0), Vector2(0, -outline), Vector2(0, outline), Vector2(-outline, -outline) * 0.7, Vector2(outline, -outline) * 0.7, Vector2(-outline, outline) * 0.7, Vector2(outline, outline) * 0.7]:
			ci.draw_string(FONT, pos + off, txt, align, width, font_size, oc)
		ci.draw_string(FONT, pos + Vector2(0.0, outline + 1.0), txt, align, width, font_size, oc)
	ci.draw_string(FONT, pos, txt, align, width, font_size, col)

## Text centred both ways inside a rect.
static func text_in(ci: CanvasItem, rect: Rect2, txt: String, font_size: int, col: Color, outline: float = 2.0, outline_col: Color = DARK) -> void:
	var asc: float = FONT.get_ascent(font_size)
	var desc: float = FONT.get_descent(font_size)
	var base_y: float = rect.position.y + (rect.size.y + asc - desc) * 0.5
	text(ci, Vector2(rect.position.x, base_y), txt, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, col, outline, outline_col)

static func text_width(txt: String, font_size: int) -> float:
	return FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

static func gradient_v(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom])
	)

static func _rounded_points(rect: Rect2, radius: float, segs: int = 6) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(rect.end.x - r, rect.position.y + r), Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r), Vector2(rect.position.x + r, rect.position.y + r),
	]
	for c_i: int in range(4):
		var start: float = -PI * 0.5 + float(c_i) * PI * 0.5
		for s_i: int in range(segs + 1):
			var a: float = start + (PI * 0.5) * float(s_i) / float(segs)
			pts.append(corners[c_i] + Vector2(cos(a), sin(a)) * r)
	return pts

## Rounded rectangle filled with a left-to-right gradient, with an optional dark border.
static func gradient_box(ci: CanvasItem, rect: Rect2, left: Color, right: Color, radius: float = 12.0, border: Color = DARK, bw: float = 2.5) -> void:
	if bw > 0.0:
		ci.draw_colored_polygon(_rounded_points(rect.grow(bw), radius + bw), border)
	var pts: PackedVector2Array = _rounded_points(rect, radius)
	var cols := PackedColorArray()
	for p: Vector2 in pts:
		cols.append(left.lerp(right, clampf((p.x - rect.position.x) / maxf(rect.size.x, 1.0), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)

static func coin(ci: CanvasItem, center: Vector2, diameter: float, alpha: float = 1.0) -> void:
	var h: float = diameter * 56.0 / 54.0
	ci.draw_texture_rect(COIN_TEX, Rect2(center.x - diameter * 0.5, center.y - h * 0.5, diameter, h), false, Color(1, 1, 1, alpha))

## Stack of coins like a small treasure pile, used on coin offers.
static func coin_pile(ci: CanvasItem, center: Vector2, scale: float, count: int = 5) -> void:
	var offsets: Array[Vector2] = [Vector2(-22, 10), Vector2(22, 12), Vector2(0, -16), Vector2(-9, 20), Vector2(12, 24), Vector2(0, 4)]
	for i: int in range(mini(count, offsets.size())):
		coin(ci, center + offsets[i] * scale, 38.0 * scale)

## Dark rounded pill with a coin and an amount (the wallet counter and coin prices).
static func coin_pill(ci: CanvasItem, rect: Rect2, amount_text: String, font_size: int = 22, fill: Color = Color(0.10, 0.14, 0.30, 0.92), txt_col: Color = Color.WHITE) -> void:
	flat(ci, rect, fill, rect.size.y * 0.5, DARK, 2.0)
	var d: float = rect.size.y - 8.0
	coin(ci, Vector2(rect.position.x + 6.0 + d * 0.5, rect.get_center().y), d)
	text_in(ci, Rect2(rect.position.x + d + 8.0, rect.position.y, rect.size.x - d - 14.0, rect.size.y), amount_text, font_size, txt_col, 2.0)

## Rounded pill with a stopwatch and a countdown.
static func timer_pill(ci: CanvasItem, rect: Rect2, txt: String, font_size: int = 17) -> void:
	flat(ci, rect, Color(0.16, 0.20, 0.42, 0.80), rect.size.y * 0.5)
	var ic: float = rect.size.y - 14.0
	ci.draw_texture_rect(TIMER_TEX, Rect2(rect.position.x + 10.0, rect.position.y + 7.0, ic, ic), false, Color(0.80, 0.84, 1.0))
	text_in(ci, Rect2(rect.position.x + ic + 14.0, rect.position.y, rect.size.x - ic - 22.0, rect.size.y), txt, font_size, Color(0.80, 0.84, 1.0), 0.0)

static func progress_bar(ci: CanvasItem, rect: Rect2, ratio: float, left: Color = MAGENTA, right: Color = GOLD) -> void:
	flat(ci, rect, Color(0.10, 0.12, 0.20, 1.0), rect.size.y * 0.5, DARK, 2.0)
	var w: float = (rect.size.x - 6.0) * clampf(ratio, 0.0, 1.0)
	if w > rect.size.y - 6.0:
		gradient_box(ci, Rect2(rect.position.x + 3.0, rect.position.y + 3.0, w, rect.size.y - 6.0), left, right, (rect.size.y - 6.0) * 0.5, DARK, 0.0)

## Square confetti drifting behind a screen, like the key art of the shop.
static func confetti(ci: CanvasItem, area: Rect2, time: float, count: int = 14, alpha: float = 0.9) -> void:
	for i: int in range(count):
		var seed_f: float = float(i) * 12.9898
		var fx: float = fposmod(sin(seed_f) * 43758.5453, 1.0)
		var fy: float = fposmod(sin(seed_f * 1.7 + 4.1) * 24634.6345, 1.0)
		var speed: float = 6.0 + fposmod(seed_f, 7.0) * 2.0
		var y: float = fposmod(fy * area.size.y + time * speed, area.size.y + 40.0) - 20.0
		var size: float = 14.0 + fposmod(seed_f * 3.3, 26.0)
		var col: Color = CONFETTI_COLORS[i % CONFETTI_COLORS.size()]
		ci.draw_rect(Rect2(area.position.x + fx * area.size.x - size * 0.5, area.position.y + y, size, size), Color(col.r, col.g, col.b, alpha), true)

## "12h 34m", "34m 05s" or "59s".
static func format_duration(total_sec: int) -> String:
	var s: int = maxi(0, total_sec)
	var h: int = s / 3600
	var m: int = (s % 3600) / 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, s % 60]
	return "%ds" % s

## Euro price from cents, with the decimal separator of the current language.
static func format_price(cents: int) -> String:
	var sep: String = "." if TranslationServer.get_locale().begins_with("en") else ","
	return "€ %d%s%02d" % [cents / 100, sep, cents % 100]

static func ease_out_back(t: float) -> float:
	var c: float = 1.70158
	var x: float = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x

static func ease_out_cubic(t: float) -> float:
	var x: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - x * x * x

## 1 -> peak -> 1 scale bump for a tap or a claim (t in 0..1).
static func punch(t: float, strength: float = 0.18) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return 1.0 + sin(x * PI) * strength * (1.0 - x * 0.5)

## Scales a rect around its centre.
static func scaled(rect: Rect2, s: float) -> Rect2:
	var c: Vector2 = rect.get_center()
	return Rect2(c - rect.size * s * 0.5, rect.size * s)

## Draws a skin preview texture fitted inside `rect` (bottom-aligned), or a simple character
## silhouette while the 3D preview is still rendering.
static func skin_preview(ci: CanvasItem, rect: Rect2, tex: Texture2D, fallback_col: Color, modulate: Color = Color.WHITE) -> void:
	if tex != null:
		var aspect: float = float(tex.get_width()) / float(maxi(tex.get_height(), 1))
		var h: float = rect.size.y
		var w: float = h * aspect
		if w > rect.size.x:
			w = rect.size.x
			h = w / aspect
		ci.draw_texture_rect(tex, Rect2(rect.position.x + (rect.size.x - w) * 0.5, rect.end.y - h, w, h), false, modulate)
		return
	var c := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.36)
	var head_r: float = minf(rect.size.x, rect.size.y) * 0.22
	var col := Color(fallback_col.r, fallback_col.g, fallback_col.b, 0.85 * modulate.a)
	ci.draw_circle(c, head_r, col)
	flat(ci, Rect2(c.x - head_r * 0.95, c.y + head_r * 0.9, head_r * 1.9, rect.end.y - (c.y + head_r * 0.9) - 4.0), col, head_r * 0.6)

## Five-point star (XP icon).
static func star(ci: CanvasItem, center: Vector2, radius: float, fill: Color, border: Color = DARK) -> void:
	for pass_i: int in range(2):
		var r_out: float = radius + (3.0 if pass_i == 0 else 0.0)
		var pts := PackedVector2Array()
		for i: int in range(10):
			var a: float = -PI * 0.5 + float(i) * PI / 5.0
			var r: float = r_out if i % 2 == 0 else r_out * 0.48
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(pts, border if pass_i == 0 else fill)

## Small padlock for locked rewards.
static func padlock(ci: CanvasItem, center: Vector2, size: float, col: Color) -> void:
	ci.draw_arc(center + Vector2(0.0, -size * 0.18), size * 0.26, PI, TAU, 12, col, size * 0.14, true)
	flat(ci, Rect2(center.x - size * 0.36, center.y - size * 0.12, size * 0.72, size * 0.56), col, size * 0.12)

## Tick mark for claimed rewards.
static func check(ci: CanvasItem, center: Vector2, size: float, col: Color, width: float = 5.0) -> void:
	var pts := PackedVector2Array([center + Vector2(-size * 0.42, 0.0), center + Vector2(-size * 0.10, size * 0.32), center + Vector2(size * 0.46, -size * 0.34)])
	ci.draw_polyline(pts, DARK, width + 4.0, true)
	ci.draw_polyline(pts, col, width, true)

## Back arrow button used in every page header.
static func back_button(ci: CanvasItem, rect: Rect2) -> void:
	box(ci, rect, Color(0.22, 0.26, 0.38), SLATE_BEVEL, DARK, 14.0, 3.0)
	var c: Vector2 = rect.get_center()
	var s: float = rect.size.y * 0.20
	ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.6, -s), c + Vector2(-s * 0.6, 0.0), c + Vector2(s * 0.6, s)]), Color.WHITE, 5.0, true)
