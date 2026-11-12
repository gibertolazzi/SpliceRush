class_name ArenaBuilder3D
extends Node3D

const HAZARD_SHADER := preload("res://game/shaders/hazard_stripes.gdshader")
const BEAM_SHADER := preload("res://game/shaders/power_beam.gdshader")
const AURA_SPHERE_SHADER := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/StatusFX/shader/aura_sphere.gdshader")
const STREAKS_SHADER := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/StatusFX/shader/streaks.gdshader")
const STATUS_SHATTER_VFX := preload("res://StatusFXFree/assets/BinbunVFX_Vol2/StatusFX/effects/status/vfx_status_shatter.tscn")

var destructible_nodes: Dictionary = {} # Vector2i -> Node3D
var dropped_part_nodes: Dictionary = {} # int (drop_id) -> Node3D
var floor_cell_map: Dictionary = {}     # Vector2i -> Dictionary {mm, idx}
var power_cube_node: Node3D
var floor_base_mi: MeshInstance3D
var frenzy_perimeter_root: Node3D
var debris_pool: Array[MeshInstance3D] = []
var active_debris: Array[Dictionary] = []
var impact_star_pool: Array[Node3D] = []
var active_impact_stars: Array[Dictionary] = []
var spark_pool: Array[MeshInstance3D] = []
var active_sparks: Array[Dictionary] = []
var dust_pool: Array[MeshInstance3D] = []
var active_dust: Array[Dictionary] = []
var active_flying_parts: Array[Dictionary] = []
var active_statusfx_impacts: Array[Dictionary] = []
var active_statusfx_flashes: Array[Dictionary] = []
var _statusfx_impact_pool: Array[MeshInstance3D] = []
var _statusfx_flash_pool: Array[MeshInstance3D] = []

var _stone_mat_a: StandardMaterial3D
var _stone_mat_b: StandardMaterial3D
var _stone_dark_mat: StandardMaterial3D
var _stone_rim_mat: StandardMaterial3D
var _debris_mat: StandardMaterial3D
var _gold_glow_mat: StandardMaterial3D
var _white_glow_mat: StandardMaterial3D
var _magenta_glow_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _dust_mat: StandardMaterial3D
var _cloud_mat_a: StandardMaterial3D
var _cloud_mat_b: StandardMaterial3D
var _rarity_mats: Dictionary = {}
var _crate_mats: Array[StandardMaterial3D] = []

func _ready() -> void:
	_init_materials()
	if _statusfx_impact_pool.is_empty():
		_init_statusfx_pools()

func _init_statusfx_pools() -> void:
	_statusfx_impact_pool.clear()
	active_statusfx_impacts.clear()
	_statusfx_flash_pool.clear()
	active_statusfx_flashes.clear()

	for i: int in range(8):
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.10
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		if AURA_SPHERE_SHADER != null:
			var mat := ShaderMaterial.new()
			mat.shader = AURA_SPHERE_SHADER
			mat.set_shader_parameter("primary_color", Color(1.0, 0.85, 0.25))
			mat.set_shader_parameter("emission", 3.5)
			mi.material_override = mat
		mi.visible = false
		add_child(mi)
		_statusfx_impact_pool.append(mi)

	for i: int in range(8):
		var fl := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.85, 0.85)
		fl.mesh = qm
		if STREAKS_SHADER != null:
			var mat := ShaderMaterial.new()
			mat.shader = STREAKS_SHADER
			mat.set_shader_parameter("primary_color", Color(1.0, 0.85, 0.25))
			mat.set_shader_parameter("secondary_color", Color(1.0, 0.45, 0.15))
			mat.set_shader_parameter("emission", 4.0)
			mat.set_shader_parameter("billboard", true)
			fl.material_override = mat
		fl.visible = false
		add_child(fl)
		_statusfx_flash_pool.append(fl)

func _init_materials() -> void:
	_stone_mat_a = StandardMaterial3D.new()
	_stone_mat_a.albedo_color = Color(0.60, 0.44, 0.44) # Sunlit rose-sand stone slabs
	_stone_mat_a.roughness = 0.84

	_stone_mat_b = StandardMaterial3D.new()
	_stone_mat_b.albedo_color = Color(0.50, 0.36, 0.41) # Dusky rose stone slabs
	_stone_mat_b.roughness = 0.88

	_stone_rim_mat = StandardMaterial3D.new()
	_stone_rim_mat.albedo_color = Color(0.72, 0.58, 0.56) # Sunlit stone rim
	_stone_rim_mat.roughness = 0.78

	_stone_dark_mat = StandardMaterial3D.new()
	_stone_dark_mat.albedo_color = Color(0.26, 0.20, 0.42) # Violet cliff foundation
	_stone_dark_mat.roughness = 0.92

	_debris_mat = StandardMaterial3D.new()
	_debris_mat.albedo_color = Color(0.88, 0.72, 0.62) # Warm sandstone fractured chunks
	_debris_mat.roughness = 0.72

	_gold_glow_mat = StandardMaterial3D.new()
	_gold_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gold_glow_mat.albedo_color = Color(1.0, 0.74, 0.14)

	_white_glow_mat = StandardMaterial3D.new()
	_white_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_white_glow_mat.albedo_color = Color(1.0, 0.96, 0.84)

	_magenta_glow_mat = StandardMaterial3D.new()
	_magenta_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_magenta_glow_mat.albedo_color = Color(1.0, 0.18, 0.58)

	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.albedo_color = Color(1.0, 0.95, 0.45)

	_dust_mat = StandardMaterial3D.new()
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.albedo_color = Color(0.90, 0.86, 0.98, 0.65)

	_cloud_mat_a = StandardMaterial3D.new()
	_cloud_mat_a.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat_a.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat_a.albedo_color = Color(0.78, 0.68, 0.98, 0.52)

	_cloud_mat_b = StandardMaterial3D.new()
	_cloud_mat_b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat_b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat_b.albedo_color = Color(0.62, 0.52, 0.90, 0.62)

	# Toy-bright crates for destructible blocks (key art: magenta, blue, yellow, slate).
	_crate_mats.clear()
	for crate_col: Color in [Color(0.96, 0.22, 0.56), Color(0.24, 0.46, 0.92), Color(1.0, 0.76, 0.16), Color(0.46, 0.42, 0.66)]:
		var cm := StandardMaterial3D.new()
		cm.albedo_color = crate_col
		cm.roughness = 0.7
		_crate_mats.append(cm)

	for r: int in [PartData.Rarity.COMMON, PartData.Rarity.RARE, PartData.Rarity.EPIC, PartData.Rarity.LEGENDARY]:
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.albedo_color = PartCatalog.get_rarity_color(r as PartData.Rarity)
		_rarity_mats[r] = rmat

func apply_theme_materials(theme: MatchServer.MapTheme) -> void:
	if _stone_mat_a == null:
		_init_materials()
	match theme:
		MatchServer.MapTheme.CYBER_FACTORY:
			_stone_mat_a.albedo_color = Color(0.28, 0.31, 0.38)
			_stone_mat_b.albedo_color = Color(0.21, 0.24, 0.31)
			_stone_dark_mat.albedo_color = Color(0.11, 0.13, 0.19)
			_stone_rim_mat.albedo_color = Color(0.46, 0.52, 0.62)
			_debris_mat.albedo_color = Color(0.70, 0.78, 0.88)
		MatchServer.MapTheme.FLOATING_HEX:
			_stone_mat_a.albedo_color = Color(0.38, 0.44, 0.56)
			_stone_mat_b.albedo_color = Color(0.30, 0.36, 0.48)
			_stone_dark_mat.albedo_color = Color(0.15, 0.19, 0.29)
			_stone_rim_mat.albedo_color = Color(0.54, 0.62, 0.76)
			_debris_mat.albedo_color = Color(0.80, 0.86, 0.96)
		_:
			_stone_mat_a.albedo_color = Color(0.60, 0.44, 0.44)
			_stone_mat_b.albedo_color = Color(0.50, 0.36, 0.41)
			_stone_dark_mat.albedo_color = Color(0.26, 0.20, 0.42)
			_stone_rim_mat.albedo_color = Color(0.72, 0.58, 0.56)
			_debris_mat.albedo_color = Color(0.88, 0.72, 0.62)

func build_from_server(server: MatchServer) -> void:
	if _stone_mat_a == null:
		_init_materials()
	apply_theme_materials(server.current_map_theme)
	for child: Node in get_children():
		child.queue_free()
	destructible_nodes.clear()
	dropped_part_nodes.clear()
	floor_cell_map.clear()
	active_debris.clear()
	debris_pool.clear()
	impact_star_pool.clear()
	active_impact_stars.clear()
	spark_pool.clear()
	active_sparks.clear()
	dust_pool.clear()
	active_dust.clear()
	active_flying_parts.clear()
	comic_text_pool.clear()
	active_comic_texts.clear()
	_statusfx_impact_pool.clear()
	active_statusfx_impacts.clear()
	_statusfx_flash_pool.clear()
	active_statusfx_flashes.clear()

	var tile: float = server.balance.tile_size
	_build_floor_multimesh(server, tile)
	_build_grid_props(server, tile)
	_build_void_clouds(server)
	_build_sky_decor(server)

	var is_static_preview: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--static-preview":
			is_static_preview = true

	# Pedestal is always situated right at the center of the arena
	var ped_pos := Vector3(0.0, 0.0, 0.0)
	_build_power_pedestal(ped_pos)
	_build_background_ruins_and_cliffs(server, is_static_preview)
	if is_static_preview:
		_build_dust_and_action_accents()
	_init_vfx_pools()

	for drop: MatchServer.DroppedPartState in server.dropped_parts:
		spawn_dropped_part_visual(drop.id, drop.part_id, int(drop.slot), int(drop.rarity), drop.pos, drop.is_power_part)

func on_arena_ring_collapsed(collapsed_cells: Array[Vector2i], safe_bounds_xz: Vector2, server: MatchServer) -> void:
	var step_debris: int = 0
	for cell: Vector2i in collapsed_cells:
		if floor_cell_map.has(cell):
			var info: Dictionary = floor_cell_map[cell]
			var mm: MultiMesh = info["mm"] as MultiMesh
			var idx: int = int(info["idx"])
			mm.set_instance_transform(idx, Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), Vector3(0.0, -50.0, 0.0)))
			floor_cell_map.erase(cell)
		if step_debris % 5 == 0 and server != null:
			spawn_impact_debris(server.cell_to_world_xz(cell), 2)
		step_debris += 1

	if floor_base_mi != null and is_instance_valid(floor_base_mi):
		var bm: BoxMesh = floor_base_mi.mesh as BoxMesh
		if bm != null:
			bm.size = Vector3(safe_bounds_xz.x * 2.0 + 1.8, 1.4, safe_bounds_xz.y * 2.0 + 1.8)

	if frenzy_perimeter_root != null and is_instance_valid(frenzy_perimeter_root):
		frenzy_perimeter_root.queue_free()
	frenzy_perimeter_root = Node3D.new()
	frenzy_perimeter_root.name = "FrenzyPerimeter"
	add_child(frenzy_perimeter_root)

	var danger_mat := StandardMaterial3D.new()
	danger_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	danger_mat.albedo_color = Color(1.0, 0.20, 0.45)

	var edge_x: float = safe_bounds_xz.x
	var edge_z: float = safe_bounds_xz.y
	_spawn_box(frenzy_perimeter_root, Vector3(0.28, 0.24, edge_z * 2.0), Vector3(-edge_x, 0.12, 0.0), danger_mat)
	_spawn_box(frenzy_perimeter_root, Vector3(0.28, 0.24, edge_z * 2.0), Vector3(edge_x, 0.12, 0.0), danger_mat)
	_spawn_box(frenzy_perimeter_root, Vector3(edge_x * 2.0, 0.24, 0.28), Vector3(0.0, 0.12, -edge_z), danger_mat)
	_spawn_box(frenzy_perimeter_root, Vector3(edge_x * 2.0, 0.24, 0.28), Vector3(0.0, 0.12, edge_z), danger_mat)

## Resolves who a dropped piece came from: owner id -> {"scene", "tint", "tint_amount"}.
## Set by the arena controller; without it drops use a neutral mannequin.
var drop_owner_resolver: Callable

const COMIC_FONT: Font = preload("res://game/ui/fonts/LondrinaSolid-Black.ttf")
const DROP_POP_SEC: float = 0.46
const DROP_POP_HEIGHT: float = 1.25
const DROP_BLINK_WINDOW_SEC: float = 3.0

var comic_text_pool: Array[Label3D] = []
var active_comic_texts: Array[Dictionary] = []

func _resolve_drop_owner(part_id: StringName, owner_id: int) -> Dictionary:
	if owner_id >= 0 and drop_owner_resolver.is_valid():
		var info: Variant = drop_owner_resolver.call(owner_id)
		if info is Dictionary and not (info as Dictionary).is_empty():
			return info as Dictionary
	# Arena spawns have no owner: a mannequin limb in the part's own colour.
	return {
		"scene": BlockyFighter3D.MAN_CUTIE_SCENE,
		"tint": PartCatalog.get_part(part_id).primary_color,
		"tint_amount": 1.0,
	}

func _build_drop_item(part_id: StringName, owner_id: int) -> Node3D:
	var info: Dictionary = _resolve_drop_owner(part_id, owner_id)
	return PartDropVisuals.build(part_id, info.get("scene") as PackedScene, info.get("tint", Color.WHITE) as Color, float(info.get("tint_amount", 1.0)))

func spawn_dropped_part_visual(drop_id: int, part_id: StringName, slot: int, rarity: int, pos_xz: Vector2, _is_power: bool, owner_id: int = -1, popped: bool = false) -> void:
	if _stone_mat_a == null:
		_init_materials()
	if dropped_part_nodes.has(drop_id):
		return
	var root_n := Node3D.new()
	root_n.name = "Drop_%d" % drop_id
	root_n.position = Vector3(pos_xz.x, 0.0, pos_xz.y)
	add_child(root_n)

	var r_mat: StandardMaterial3D = _rarity_mats.get(rarity, _gold_glow_mat) as StandardMaterial3D
	# Loose limbs and plain pieces lie on the floor; rare loot hovers in a light beam.
	var lying: bool = rarity == PartData.Rarity.COMMON

	# Rarity reads by shape and glow, not colour alone: ring, diamond, double diamond, beam height.
	var marker := Node3D.new()
	marker.name = "RarityMarker"
	root_n.add_child(marker)
	match rarity:
		PartData.Rarity.COMMON:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.56
			torus.outer_radius = 0.64
			torus.rings = 20
			torus.ring_segments = 4
			ring.mesh = torus
			ring.material_override = _white_glow_mat
			ring.position = Vector3(0.0, 0.04, 0.0)
			marker.add_child(ring)
		PartData.Rarity.RARE:
			_spawn_box(marker, Vector3(0.76, 0.07, 0.76), Vector3(0.0, 0.05, 0.0), r_mat, Vector3(0.0, 45.0, 0.0))
			_spawn_box(marker, Vector3(0.10, 1.35, 0.10), Vector3(0.0, 0.72, 0.0), r_mat)
		PartData.Rarity.EPIC:
			_spawn_box(marker, Vector3(0.84, 0.08, 0.84), Vector3(0.0, 0.05, 0.0), r_mat)
			_spawn_box(marker, Vector3(0.84, 0.08, 0.84), Vector3(0.0, 0.06, 0.0), r_mat, Vector3(0.0, 45.0, 0.0))
			_spawn_box(marker, Vector3(0.14, 1.85, 0.14), Vector3(0.0, 0.95, 0.0), r_mat)
		PartData.Rarity.LEGENDARY:
			_spawn_box(marker, Vector3(0.96, 0.09, 0.96), Vector3(0.0, 0.05, 0.0), r_mat)
			_spawn_box(marker, Vector3(0.96, 0.09, 0.96), Vector3(0.0, 0.07, 0.0), _white_glow_mat, Vector3(0.0, 45.0, 0.0))
			_spawn_box(marker, Vector3(0.18, 2.55, 0.18), Vector3(0.0, 1.30, 0.0), r_mat)

	var item_pivot := Node3D.new()
	item_pivot.name = "ItemMesh"
	root_n.add_child(item_pivot)
	var visual: Node3D = _build_drop_item(part_id, owner_id)
	item_pivot.add_child(visual)

	var yaw: float = float((drop_id * 97) % 360)
	if lying:
		# Flat on the slabs like a dropped toy part, at a random angle.
		visual.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		item_pivot.rotation_degrees.y = yaw
		item_pivot.position = Vector3(0.0, 0.20, 0.0)
	else:
		visual.rotation_degrees = Vector3(0.0, 0.0, 24.0)
		item_pivot.position = Vector3(0.0, 0.95 if slot != PartData.Slot.CORE else 0.80, 0.0)

	root_n.set_meta("lying", lying)
	root_n.set_meta("age", 0.0 if popped else DROP_POP_SEC)
	root_n.set_meta("landed", not popped)
	root_n.set_meta("rest_y", item_pivot.position.y)
	root_n.set_meta("yaw", yaw)
	dropped_part_nodes[drop_id] = root_n

func remove_dropped_part_visual(drop_id: int, pos_xz: Vector2) -> void:
	spawn_impact_debris(pos_xz, 4)
	if dropped_part_nodes.has(drop_id):
		var n: Node3D = dropped_part_nodes[drop_id]
		if is_instance_valid(n):
			n.queue_free()
		dropped_part_nodes.erase(drop_id)

## A loose limb timed out: it fades in a puff of dust instead of a loot burst.
func expire_dropped_part_visual(drop_id: int, pos_xz: Vector2) -> void:
	spawn_dust_puff(Vector3(pos_xz.x, 0.2, pos_xz.y), 3, 0.3)
	if dropped_part_nodes.has(drop_id):
		var n: Node3D = dropped_part_nodes[drop_id]
		if is_instance_valid(n):
			n.queue_free()
		dropped_part_nodes.erase(drop_id)

func sync_dropped_parts(drops: Array[MatchServer.DroppedPartState], dt: float, match_time: float = -1.0) -> void:
	var t_sec: float = float(Time.get_ticks_msec()) * 0.004
	for drop: MatchServer.DroppedPartState in drops:
		if not dropped_part_nodes.has(drop.id):
			spawn_dropped_part_visual(drop.id, drop.part_id, int(drop.slot), int(drop.rarity), drop.pos, drop.is_power_part, drop.owner_id, drop.vel.length_squared() > 0.5)
		var n: Node3D = dropped_part_nodes[drop.id]
		if not is_instance_valid(n):
			continue
		n.position = Vector3(drop.pos.x, 0.0, drop.pos.y)
		var item_mesh: Node3D = n.get_node_or_null("ItemMesh") as Node3D
		if item_mesh == null:
			continue
		var age: float = float(n.get_meta("age", DROP_POP_SEC)) + dt
		n.set_meta("age", age)
		var rest_y: float = float(n.get_meta("rest_y", 0.66))
		var lying: bool = bool(n.get_meta("lying", false))
		if age < DROP_POP_SEC:
			# Popped off a body: tumble through the air in an arc before landing.
			var k: float = age / DROP_POP_SEC
			item_mesh.position.y = rest_y + sin(k * PI) * DROP_POP_HEIGHT
			item_mesh.rotate_x(15.0 * dt)
			item_mesh.rotate_y(9.0 * dt)
		else:
			if not bool(n.get_meta("landed", true)):
				n.set_meta("landed", true)
				item_mesh.rotation = Vector3(0.0, deg_to_rad(float(n.get_meta("yaw", 0.0))), 0.0)
				spawn_dust_puff(Vector3(drop.pos.x, 0.12, drop.pos.y), 2, 0.25)
			if lying:
				# Tiny rubbery wobble so the limb reads as a pickup, not as debris.
				item_mesh.position.y = rest_y + absf(sin(t_sec * 0.9 + float(drop.id))) * 0.07
				item_mesh.rotation.z = sin(t_sec * 0.7 + float(drop.id) * 1.3) * 0.10
			else:
				item_mesh.rotate_y(2.6 * dt)
				item_mesh.position.y = rest_y + sin(t_sec + float(drop.id)) * 0.14
		var marker: Node3D = n.get_node_or_null("RarityMarker") as Node3D
		if marker != null and lying:
			marker.scale = Vector3.ONE * (1.0 + 0.10 * sin(t_sec * 1.6 + float(drop.id)))
		# About to time out: blink.
		if match_time >= 0.0 and drop.lifetime_sec > 0.0:
			var left: float = drop.lifetime_sec - absf(match_time - drop.spawn_time)
			item_mesh.visible = left > DROP_BLINK_WINDOW_SEC or (int(left * 8.0) % 2 == 0)

func _init_comic_text_pool() -> void:
	comic_text_pool.clear()
	active_comic_texts.clear()
	for i: int in range(8):
		var lbl := Label3D.new()
		lbl.name = "ComicText_%d" % i
		lbl.font = COMIC_FONT
		lbl.font_size = 96
		lbl.outline_size = 28
		lbl.pixel_size = 0.0085
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.fixed_size = false
		lbl.outline_modulate = Color(0.10, 0.05, 0.20)
		lbl.render_priority = 4
		lbl.outline_render_priority = 3
		lbl.visible = false
		add_child(lbl)
		comic_text_pool.append(lbl)

## Comic-book onomatopoeia that pops over an impact ("BONK!", "POP!"). Pass translated text.
func spawn_comic_text(world_pos: Vector3, text: String, color: Color, size_mult: float = 1.0) -> void:
	if comic_text_pool.is_empty():
		return
	var lbl: Label3D = comic_text_pool.pop_back()
	lbl.text = text
	lbl.modulate = color
	lbl.position = world_pos
	lbl.rotation_degrees.z = randf_range(-14.0, 14.0)
	lbl.scale = Vector3.ONE * 0.2
	lbl.visible = true
	active_comic_texts.append({"node": lbl, "ttl": 0.62, "max_ttl": 0.62, "size": size_mult})

func _update_comic_texts(dt: float) -> void:
	var idx: int = active_comic_texts.size() - 1
	while idx >= 0:
		var item: Dictionary = active_comic_texts[idx]
		var lbl: Label3D = item["node"]
		var ttl: float = float(item["ttl"]) - dt
		if ttl <= 0.0 or not is_instance_valid(lbl):
			if is_instance_valid(lbl):
				lbl.visible = false
				comic_text_pool.append(lbl)
			active_comic_texts.remove_at(idx)
		else:
			var t_norm: float = 1.0 - ttl / float(item["max_ttl"])
			var size: float = float(item["size"])
			# Overshoot pop, hold, then shrink away while drifting up.
			var sc: float = lerpf(0.2, 1.25, t_norm / 0.18) if t_norm < 0.18 else (lerpf(1.25, 1.0, (t_norm - 0.18) / 0.12) if t_norm < 0.30 else lerpf(1.0, 0.55, (t_norm - 0.30) / 0.70))
			lbl.scale = Vector3.ONE * sc * size
			lbl.position.y += 1.1 * dt
			lbl.modulate.a = 1.0 if t_norm < 0.7 else lerpf(1.0, 0.0, (t_norm - 0.7) / 0.3)
			lbl.outline_modulate.a = lbl.modulate.a
			item["ttl"] = ttl
		idx -= 1

func _build_floor_multimesh(server: MatchServer, tile: float) -> void:
	# 1. Main floating island foundation (monolithic rock slab with cliff depth)
	var island_root := Node3D.new()
	island_root.name = "FloatingIslandBase"
	add_child(island_root)

	var base_w: float = float(server.balance.grid_width) * tile
	var base_d: float = float(server.balance.grid_depth) * tile

	floor_base_mi = MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(base_w + 1.6, 1.4, base_d + 1.6)
	floor_base_mi.mesh = base_box
	floor_base_mi.position = Vector3(0.0, -0.72, 0.0)
	floor_base_mi.material_override = _stone_dark_mat
	island_root.add_child(floor_base_mi)

	# Lighter perimeter stone ledge trim (crisp edge definition)
	_spawn_box(island_root, Vector3(base_w + 1.8, 0.14, 0.32), Vector3(0.0, -0.05, -base_d * 0.5 - 0.72), _stone_rim_mat)
	_spawn_box(island_root, Vector3(base_w + 1.8, 0.14, 0.32), Vector3(0.0, -0.05, base_d * 0.5 + 0.72), _stone_rim_mat)
	_spawn_box(island_root, Vector3(0.32, 0.14, base_d + 1.8), Vector3(-base_w * 0.5 - 0.72, -0.05, 0.0), _stone_rim_mat)
	_spawn_box(island_root, Vector3(0.32, 0.14, base_d + 1.8), Vector3(base_w * 0.5 + 0.72, -0.05, 0.0), _stone_rim_mat)

	# Tiered tapering subterranean cliff underbelly (Y = -2.0 to -5.0)
	_spawn_box(island_root, Vector3(base_w * 0.92, 2.2, base_d * 0.92), Vector3(0.0, -2.1, 0.0), _stone_dark_mat)
	_spawn_box(island_root, Vector3(base_w * 0.75, 2.6, base_d * 0.75), Vector3(0.0, -3.8, 0.0), _stone_dark_mat)
	_spawn_box(island_root, Vector3(base_w * 0.52, 2.2, base_d * 0.52), Vector3(0.0, -5.4, 0.0), _stone_dark_mat)

	var cells_a_coords: Array[Vector2i] = []
	var cells_b_coords: Array[Vector2i] = []
	var cells_a: Array[Transform3D] = []
	var cells_b: Array[Transform3D] = []
	for cell_var: Variant in server.grid_cells.keys():
		var cell: Vector2i = cell_var as Vector2i
		if int(server.grid_cells[cell]) == MatchServer.CellType.VOID:
			continue
		var wxz: Vector2 = server.cell_to_world_xz(cell)
		var hash_v: int = abs((cell.x * 73856093) ^ (cell.y * 19349663))
		# Physical slab height variation with visible stepped joints
		var y_off: float = -0.05 + float(hash_v % 6) * 0.016
		var yaw: float = float(hash_v % 4) * (PI * 0.5)
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
		var xform := Transform3D(basis, Vector3(wxz.x, y_off, wxz.y))
		if ((cell.x + cell.y) & 1) == 0:
			cells_a_coords.append(cell)
			cells_a.append(xform)
		else:
			cells_b_coords.append(cell)
			cells_b.append(xform)

	# MultiMesh for checkered slabs with distinct stone tones
	var mm_a: MultiMesh = _add_slab_multimesh(cells_a, tile * 0.97, _stone_mat_a)
	for i: int in range(cells_a_coords.size()):
		floor_cell_map[cells_a_coords[i]] = {"mm": mm_a, "idx": i}

	var mm_b: MultiMesh = _add_slab_multimesh(cells_b, tile * 0.96, _stone_mat_b)
	for i: int in range(cells_b_coords.size()):
		floor_cell_map[cells_b_coords[i]] = {"mm": mm_b, "idx": i}

func _build_sky_decor(_server: MatchServer) -> void:
	var root := Node3D.new()
	root.name = "SkyDecor"
	add_child(root)

	# Floating islands beyond the arena rim (key-art horizon).
	_build_far_island(root, Vector3(-27.0, 1.4, -49.0), 12.0, 8.0)
	_build_far_island(root, Vector3(24.0, 2.2, -57.0), 15.0, 10.0)
	_build_far_island(root, Vector3(-5.0, 0.6, -66.0), 20.0, 13.0)
	_build_far_island(root, Vector3(39.0, 0.8, -45.0), 9.0, 6.0)

	# Broken towers on the horizon.
	var far_mat := StandardMaterial3D.new()
	far_mat.albedo_color = Color(0.24, 0.18, 0.38)
	far_mat.roughness = 0.92

	var tower_positions: Array[Vector3] = [
		Vector3(-19.0, -2.0, -58.0),
		Vector3(-11.0, -2.0, -63.0),
		Vector3(9.0, -2.0, -61.0),
		Vector3(31.0, -2.0, -53.0),
	]
	for i: int in range(tower_positions.size()):
		var tp: Vector3 = tower_positions[i]
		var h: float = 4.6 + float(i % 3) * 1.5
		_spawn_box(root, Vector3(2.2, h, 2.2), tp + Vector3(0.0, h * 0.5, 0.0), far_mat)
		_spawn_box(root, Vector3(1.2, 0.5, 1.2), tp + Vector3(0.0, h + 0.2, 0.0), far_mat)

	# Voxel cloud banks hugging the arena rim.
	var cloud_positions: Array[Vector3] = [
		Vector3(-25.0, 0.7, -36.0),
		Vector3(-12.0, 1.2, -40.0),
		Vector3(2.0, 0.4, -38.0),
		Vector3(15.0, 1.0, -41.0),
		Vector3(28.0, 0.6, -37.0),
		Vector3(-33.0, 2.0, -43.0),
		Vector3(34.0, 1.8, -45.0),
	]
	for i: int in range(cloud_positions.size()):
		var cp: Vector3 = cloud_positions[i]
		var rot := Vector3(0.0, 20.0 * float(i), 0.0)
		_spawn_box(root, Vector3(7.2, 1.4, 3.6), cp, _cloud_mat_a, rot)
		_spawn_box(root, Vector3(4.4, 1.0, 2.8), cp + Vector3(3.0, 0.35, 0.5), _cloud_mat_b, rot)
		_spawn_box(root, Vector3(3.2, 0.9, 2.2), cp + Vector3(-3.5, 0.2, 0.3), _cloud_mat_a, rot)

	# Higher cloud puffs breaking the horizon silhouette.
	var high_cloud_positions: Array[Vector3] = [
		Vector3(-16.0, 4.2, -40.0),
		Vector3(8.0, 5.0, -42.0),
		Vector3(26.0, 4.6, -38.0),
	]
	for i: int in range(high_cloud_positions.size()):
		var hcp: Vector3 = high_cloud_positions[i]
		var hrot := Vector3(0.0, 24.0 * float(i), 0.0)
		_spawn_box(root, Vector3(8.0, 1.4, 3.2), hcp, _cloud_mat_a, hrot)
		_spawn_box(root, Vector3(5.0, 1.0, 2.6), hcp + Vector3(3.2, 0.2, 0.4), _cloud_mat_b, hrot)

	# Small floating rocks framing the play space.
	var rock_positions: Array[Vector3] = [
		Vector3(-27.0, 3.2, -12.0),
		Vector3(27.5, 4.0, -6.0),
		Vector3(-26.5, 2.6, 14.0),
		Vector3(26.0, 3.4, 18.0),
	]
	for i: int in range(rock_positions.size()):
		var rp: Vector3 = rock_positions[i]
		_spawn_box(root, Vector3(2.2, 1.6, 2.0), rp, _stone_mat_b, Vector3(8.0 * float(i), 25.0 * float(i), -6.0))
		_spawn_box(root, Vector3(1.2, 0.9, 1.0), rp + Vector3(0.6, 1.1, 0.2), _stone_rim_mat, Vector3(0.0, 15.0, 12.0))

func _build_far_island(root: Node3D, pos: Vector3, width: float, depth: float) -> void:
	_spawn_box(root, Vector3(width, 0.8, depth), pos, _stone_mat_b)
	_spawn_box(root, Vector3(width * 0.82, 2.6, depth * 0.82), pos + Vector3(0.0, -1.6, 0.0), _stone_dark_mat)
	_spawn_box(root, Vector3(width * 0.55, 2.4, depth * 0.55), pos + Vector3(0.0, -3.9, 0.0), _stone_dark_mat)
	_spawn_box(root, Vector3(1.4, 4.8, 1.4), pos + Vector3(-width * 0.22, 2.7, 0.0), _stone_mat_a, Vector3(0.0, 12.0, 4.0))
	_spawn_box(root, Vector3(1.0, 3.4, 1.0), pos + Vector3(width * 0.26, 2.0, depth * 0.16), _stone_mat_a, Vector3(0.0, -18.0, -5.0))
	_spawn_box(root, Vector3(width * 0.12, 1.8, depth * 0.12), pos + Vector3(width * 0.05, 1.2, -depth * 0.18), _stone_mat_a, Vector3(0.0, 28.0, 8.0))

func _build_void_clouds(server: MatchServer) -> void:
	var clouds_root := Node3D.new()
	clouds_root.name = "VoidCloudsDeck"
	add_child(clouds_root)

	var w: float = float(server.balance.grid_width) * server.balance.tile_size * 2.4
	var d: float = float(server.balance.grid_depth) * server.balance.tile_size * 2.4

	# Deep atmospheric cloud planes hovering in the abyss below the floating island
	_spawn_box(clouds_root, Vector3(w, 0.4, d), Vector3(0.0, -7.5, 0.0), _cloud_mat_a)
	_spawn_box(clouds_root, Vector3(w * 1.3, 0.5, d * 1.3), Vector3(2.0, -11.0, -2.0), _cloud_mat_b)
	_spawn_box(clouds_root, Vector3(w * 1.6, 0.6, d * 1.6), Vector3(-3.0, -15.5, 3.0), _cloud_mat_a)

	# Stylized cloud puffs around the lower edges of the floating island
	var puff_offsets: Array[Vector3] = [
		Vector3(-w * 0.45, -6.8, -d * 0.35),
		Vector3(w * 0.48, -7.2, -d * 0.28),
		Vector3(-w * 0.42, -7.0, d * 0.38),
		Vector3(w * 0.44, -7.4, d * 0.32),
		Vector3(0.0, -8.2, -d * 0.52),
		Vector3(0.0, -8.2, d * 0.52),
	]
	for p_pos: Vector3 in puff_offsets:
		_spawn_box(clouds_root, Vector3(8.5, 2.4, 7.5), p_pos, _cloud_mat_a, Vector3(0.0, 35.0, 0.0))

func _add_slab_multimesh(transforms: Array[Transform3D], slab_size: float, mat: Material) -> MultiMesh:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(slab_size, 0.24, slab_size)
	mm.mesh = bm
	mm.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mm

func _build_grid_props(server: MatchServer, tile: float) -> void:
	var hazard_mat := ShaderMaterial.new()
	hazard_mat.shader = HAZARD_SHADER

	for cell_var: Variant in server.grid_cells.keys():
		var cell: Vector2i = cell_var as Vector2i
		var ctype: int = int(server.grid_cells[cell])
		var wxz: Vector2 = server.cell_to_world_xz(cell)
		if ctype == MatchServer.CellType.HAZARD_BARRIER:
			var barrier := Node3D.new()
			barrier.position = Vector3(wxz.x, 0.0, wxz.y)
			add_child(barrier)
			_spawn_box(barrier, Vector3(tile * 0.92, 1.25, 0.42), Vector3(0.0, 0.65, 0.0), hazard_mat)
			_spawn_box(barrier, Vector3(0.22, 1.55, 0.48), Vector3(-tile * 0.44, 0.78, 0.0), _gold_glow_mat)
			_spawn_box(barrier, Vector3(0.22, 1.55, 0.48), Vector3(tile * 0.44, 0.78, 0.0), _gold_glow_mat)
		elif ctype == MatchServer.CellType.DESTRUCTIBLE_BLOCK:
			var block_root := Node3D.new()
			block_root.position = Vector3(wxz.x, 0.0, wxz.y)
			add_child(block_root)
			var crate_idx: int = abs((cell.x * 31) ^ (cell.y * 17)) % maxi(_crate_mats.size(), 1)
			var crate_mat: Material = _crate_mats[crate_idx] if not _crate_mats.is_empty() else _stone_mat_b
			_spawn_box(block_root, Vector3(tile * 0.88, tile * 0.88, tile * 0.88), Vector3(0.0, tile * 0.44, 0.0), crate_mat)
			_spawn_box(block_root, Vector3(tile * 0.92, 0.18, tile * 0.92), Vector3(0.0, tile * 0.82, 0.0), _stone_rim_mat)
			destructible_nodes[cell] = block_root

	var left_mystery := Node3D.new()
	left_mystery.position = Vector3(-5.8, 0.95, 0.5)
	left_mystery.rotation_degrees = Vector3(0.0, 22.0, 0.0)
	add_child(left_mystery)
	var blue_crate_mat := StandardMaterial3D.new()
	blue_crate_mat.albedo_color = Color(0.32, 0.48, 0.88)
	blue_crate_mat.emission_enabled = true
	blue_crate_mat.emission = Color(0.22, 0.38, 0.85) * 0.4
	_spawn_box(left_mystery, Vector3(1.55, 1.55, 1.55), Vector3.ZERO, blue_crate_mat)
	_build_question_mark(left_mystery, Vector3(0.0, 0.0, 0.80), 0.75, _white_glow_mat)

func _build_power_pedestal(pos: Vector3) -> void:
	var ped := Node3D.new()
	ped.name = "PowerPedestal"
	ped.position = pos
	add_child(ped)

	var cyl_outer := MeshInstance3D.new()
	var cm_outer := CylinderMesh.new()
	cm_outer.top_radius = 1.80
	cm_outer.bottom_radius = 2.05
	cm_outer.height = 0.42
	cm_outer.radial_segments = 6
	cyl_outer.mesh = cm_outer
	cyl_outer.position = Vector3(0.0, 0.21, 0.0)
	cyl_outer.material_override = _stone_dark_mat
	ped.add_child(cyl_outer)

	var ped_gold_mat := StandardMaterial3D.new()
	ped_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ped_gold_mat.albedo_color = Color(0.96, 0.66, 0.16)

	var cyl_gold := MeshInstance3D.new()
	var cm_gold := CylinderMesh.new()
	cm_gold.top_radius = 1.30
	cm_gold.bottom_radius = 1.45
	cm_gold.height = 0.30
	cm_gold.radial_segments = 6
	cyl_gold.mesh = cm_gold
	cyl_gold.position = Vector3(0.0, 0.48, 0.0)
	cyl_gold.material_override = ped_gold_mat
	ped.add_child(cyl_gold)

	# StatusFX Pedestal Ground Streaks
	if STREAKS_SHADER != null:
		var streaks_mat := ShaderMaterial.new()
		streaks_mat.shader = STREAKS_SHADER
		streaks_mat.set_shader_parameter("primary_color", Color(1.0, 0.88, 0.35))
		streaks_mat.set_shader_parameter("secondary_color", Color(1.0, 0.40, 0.10))
		streaks_mat.set_shader_parameter("emission", 3.2)
		streaks_mat.set_shader_parameter("billboard", false)

		var streaks_mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(3.6, 3.6)
		streaks_mi.mesh = qm
		streaks_mi.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		streaks_mi.position = Vector3(0.0, 0.65, 0.0)
		streaks_mi.material_override = streaks_mat
		ped.add_child(streaks_mi)

	power_cube_node = Node3D.new()
	power_cube_node.position = Vector3(0.0, 1.45, 0.0)
	ped.add_child(power_cube_node)
	_spawn_box(power_cube_node, Vector3(0.92, 0.92, 0.92), Vector3.ZERO, ped_gold_mat)

	# StatusFX Glowing Aura Sphere surrounding the Power Part cube
	if AURA_SPHERE_SHADER != null:
		var aura_mat := ShaderMaterial.new()
		aura_mat.shader = AURA_SPHERE_SHADER
		aura_mat.set_shader_parameter("primary_color", Color(1.0, 0.88, 0.25))
		aura_mat.set_shader_parameter("secondary_color", Color(1.0, 0.42, 0.10))
		aura_mat.set_shader_parameter("tertiary_color", Color(0.85, 0.15, 0.45))
		aura_mat.set_shader_parameter("emission", 2.8)
		aura_mat.set_shader_parameter("noise_scale", Vector2(2.5, 1.2))
		aura_mat.set_shader_parameter("noise_scroll", Vector2(0.15, 0.5))
		var n_tex := NoiseTexture2D.new()
		n_tex.width = 128
		n_tex.height = 128
		var fnl := FastNoiseLite.new()
		fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX
		n_tex.noise = fnl
		aura_mat.set_shader_parameter("noise_texture", n_tex)

		var aura_sphere := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.88
		sm.height = 1.76
		aura_sphere.mesh = sm
		aura_sphere.material_override = aura_mat
		power_cube_node.add_child(aura_sphere)
	# Question mark on all 4 vertical faces of the spinning power cube
	_build_question_mark(power_cube_node, Vector3(0.0, 0.0, 0.47), 0.54, _white_glow_mat, Vector3.ZERO)
	_build_question_mark(power_cube_node, Vector3(0.0, 0.0, -0.47), 0.54, _white_glow_mat, Vector3(0.0, 180.0, 0.0))
	_build_question_mark(power_cube_node, Vector3(0.47, 0.0, 0.0), 0.54, _white_glow_mat, Vector3(0.0, 90.0, 0.0))
	_build_question_mark(power_cube_node, Vector3(-0.47, 0.0, 0.0), 0.54, _white_glow_mat, Vector3(0.0, -90.0, 0.0))

	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = BEAM_SHADER
	beam_mat.set_shader_parameter("beam_color", Color(1.0, 0.62, 0.10, 0.16))
	var beam_mi := MeshInstance3D.new()
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius = 0.52
	beam_cyl.bottom_radius = 0.70
	beam_cyl.height = 26.0
	beam_cyl.radial_segments = 16
	beam_cyl.cap_top = false
	beam_cyl.cap_bottom = false
	beam_mi.mesh = beam_cyl
	beam_mi.position = Vector3(0.0, 13.0, 0.0)
	beam_mi.material_override = beam_mat
	ped.add_child(beam_mi)

	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.78, 0.28)
	omni.light_energy = 1.6
	omni.omni_range = 8.0
	omni.position = Vector3(0.0, 2.0, 0.0)
	ped.add_child(omni)

func _build_question_mark(parent: Node3D, offset: Vector3, scale_f: float, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var q := Node3D.new()
	q.position = offset
	q.rotation_degrees = rot_deg
	q.scale = Vector3.ONE * scale_f
	parent.add_child(q)
	_spawn_box(q, Vector3(0.52, 0.16, 0.08), Vector3(0.0, 0.38, 0.0), mat)
	_spawn_box(q, Vector3(0.16, 0.28, 0.08), Vector3(0.18, 0.22, 0.0), mat)
	_spawn_box(q, Vector3(0.34, 0.16, 0.08), Vector3(0.09, 0.06, 0.0), mat)
	_spawn_box(q, Vector3(0.16, 0.20, 0.08), Vector3(0.0, -0.08, 0.0), mat)
	_spawn_box(q, Vector3(0.18, 0.18, 0.08), Vector3(0.0, -0.36, 0.0), mat)

func _build_background_ruins_and_cliffs(server: MatchServer, is_static_preview: bool) -> void:
	var ruins := Node3D.new()
	ruins.name = "BackgroundRuins"
	add_child(ruins)

	var ruin_mat := StandardMaterial3D.new()
	ruin_mat.albedo_color = _stone_mat_a.albedo_color
	ruin_mat.roughness = 0.85

	var banner_bg := StandardMaterial3D.new()
	banner_bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	banner_bg.albedo_color = Color(0.86, 0.34, 0.92)
	var banner_border := StandardMaterial3D.new()
	banner_border.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	banner_border.albedo_color = Color(1.0, 0.72, 0.98)

	var safe_b: Vector2 = server.get_safe_bounds_xz()
	var north_z: float = -safe_b.y - 2.8

	# Broken north rampart: open gaps keep the horizon readable instead of a flat wall.
	var wall_offsets: Array[float] = [-0.74, 0.02, 0.74]
	for i: int in range(wall_offsets.size()):
		var wx: float = safe_b.x * wall_offsets[i]
		var wh: float = 1.4 + float(i % 3) * 0.8
		_spawn_box(ruins, Vector3(4.8, wh, 2.0), Vector3(wx, wh * 0.5, north_z), ruin_mat, Vector3(0.0, 4.0 * float(i), 0.0))
	_spawn_box(ruins, Vector3(3.4, 5.8, 3.2), Vector3(-safe_b.x * 0.65, 2.6, north_z + 0.4), ruin_mat)
	_spawn_box(ruins, Vector3(3.4, 5.8, 3.2), Vector3(safe_b.x * 0.65, 2.6, north_z + 0.4), ruin_mat)
	_spawn_box(ruins, Vector3(2.4, 1.8, 2.2), Vector3(-safe_b.x * 0.85, 4.8, north_z - 0.8), ruin_mat, Vector3(6.0, 18.0, -8.0))
	_spawn_box(ruins, Vector3(2.0, 1.6, 2.0), Vector3(safe_b.x * 0.85, 5.2, north_z - 0.8), ruin_mat, Vector3(-5.0, -15.0, 10.0))

	# Pixel Crown Heraldic Banner in the ruins
	var banner := Node3D.new()
	banner.position = Vector3(0.0, 2.8, north_z + 1.2)
	ruins.add_child(banner)
	_spawn_box(banner, Vector3(2.8, 1.8, 0.2), Vector3.ZERO, banner_bg)
	_spawn_box(banner, Vector3(1.4, 0.30, 0.26), Vector3(0.0, -0.30, 0.05), banner_border)
	_spawn_box(banner, Vector3(0.28, 0.55, 0.26), Vector3(-0.56, 0.06, 0.05), banner_border)
	_spawn_box(banner, Vector3(0.28, 0.65, 0.26), Vector3(0.0, 0.12, 0.05), banner_border)
	_spawn_box(banner, Vector3(0.28, 0.55, 0.26), Vector3(0.56, 0.06, 0.05), banner_border)

	# East and West perimeter boundary rocks
	var side_x: float = safe_b.x + 2.4
	_spawn_box(ruins, Vector3(3.2, 2.8, safe_b.y * 2.2), Vector3(-side_x, 0.8, 0.0), _stone_dark_mat)
	_spawn_box(ruins, Vector3(3.2, 2.8, safe_b.y * 2.2), Vector3(side_x, 0.8, 0.0), _stone_dark_mat)

func _build_dust_and_action_accents() -> void:
	var dust_mat := StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.76, 0.56, 0.44)
	dust_mat.roughness = 0.92

	var dust_positions: Array[Vector3] = [
		Vector3(-0.1, 0.26, 5.4),
		Vector3(0.5, 0.34, 5.0),
		Vector3(-0.6, 0.22, 5.8),
		Vector3(0.9, 0.25, 5.6),
	]
	for i: int in range(dust_positions.size()):
		var s: float = 0.48 + float(i % 3) * 0.16
		_spawn_box(self, Vector3(s, s * 0.68, s), dust_positions[i], dust_mat, Vector3(15.0 * float(i), 25.0 * float(i), 10.0))

	var impact := Node3D.new()
	impact.position = Vector3(-2.6, 1.0, -0.2)
	add_child(impact)
	_spawn_box(impact, Vector3(1.5, 0.20, 0.20), Vector3.ZERO, _white_glow_mat, Vector3(0.0, 20.0, 25.0))
	_spawn_box(impact, Vector3(0.20, 1.5, 0.20), Vector3.ZERO, _white_glow_mat, Vector3(0.0, 20.0, 25.0))
	_spawn_box(impact, Vector3(1.1, 0.24, 0.24), Vector3.ZERO, _gold_glow_mat, Vector3(0.0, 20.0, 70.0))

func _init_vfx_pools() -> void:
	# 1. Impact debris chunks
	for i: int in range(18):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.32, 0.32, 0.32)
		mi.mesh = bm
		mi.material_override = _debris_mat
		mi.visible = false
		add_child(mi)
		debris_pool.append(mi)

	# 2. Impact starburst flashes (key art impact stars facing camera)
	for i: int in range(8):
		var star_root := Node3D.new()
		star_root.name = "ImpactStar_%d" % i
		star_root.rotation_degrees = Vector3(58.0, 0.0, 0.0)
		star_root.visible = false
		add_child(star_root)
		_spawn_box(star_root, Vector3(0.18, 1.45, 0.04), Vector3.ZERO, _white_glow_mat)
		_spawn_box(star_root, Vector3(1.45, 0.18, 0.04), Vector3.ZERO, _white_glow_mat)
		_spawn_box(star_root, Vector3(0.14, 1.05, 0.04), Vector3.ZERO, _gold_glow_mat, Vector3(0.0, 0.0, 45.0))
		_spawn_box(star_root, Vector3(1.05, 0.14, 0.04), Vector3.ZERO, _gold_glow_mat, Vector3(0.0, 0.0, 45.0))
		_spawn_box(star_root, Vector3(0.40, 0.40, 0.06), Vector3.ZERO, _white_glow_mat)
		impact_star_pool.append(star_root)

	# 3. Flying spark specks
	for i: int in range(24):
		var sp := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.12, 0.12, 0.12)
		sp.mesh = sm
		sp.material_override = _spark_mat
		sp.visible = false
		add_child(sp)
		spark_pool.append(sp)

	# 4. Cartoon low-poly dust puffs
	for i: int in range(24):
		var dp := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.40, 0.40, 0.40)
		dp.mesh = dm
		dp.material_override = _dust_mat
		dp.visible = false
		add_child(dp)
		dust_pool.append(dp)

	# 5. StatusFX pools (muzzle flashes & impacts)
	_init_statusfx_pools()

	# 6. Comic onomatopoeia labels
	_init_comic_text_pool()

func spawn_impact_debris(world_xz: Vector2, count: int = 4) -> void:
	for i: int in range(count):
		if debris_pool.is_empty():
			break
		var mi: MeshInstance3D = debris_pool.pop_back()
		mi.visible = true
		var angle: float = float(i) * (TAU / float(maxi(count, 1))) + 0.4
		mi.position = Vector3(world_xz.x, 0.7, world_xz.y)
		active_debris.append({
			"node": mi,
			"vel": Vector3(cos(angle) * 3.8, 5.2 + float(i % 2) * 1.4, sin(angle) * 3.8),
			"ttl": 0.55,
		})

func spawn_statusfx_muzzle_flash(world_xz: Vector2, muzzle_col: Color = Color(1.0, 0.85, 0.25)) -> void:
	if _statusfx_flash_pool.is_empty():
		return
	var fl: MeshInstance3D = _statusfx_flash_pool.pop_back()
	fl.visible = true
	fl.position = Vector3(world_xz.x, 1.25, world_xz.y)
	fl.scale = Vector3(0.4, 0.4, 0.4)
	var smat := fl.material_override as ShaderMaterial
	if smat != null:
		smat.set_shader_parameter("primary_color", muzzle_col)
	active_statusfx_flashes.append({
		"node": fl,
		"ttl": 0.08,
		"max_ttl": 0.08,
	})

func spawn_statusfx_impact(world_xz: Vector2, is_crit_or_ko: bool = false, impact_col: Color = Color(1.0, 0.85, 0.25)) -> void:
	if is_crit_or_ko and STATUS_SHATTER_VFX != null and is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var vfx: Node3D = STATUS_SHATTER_VFX.instantiate() as Node3D
			vfx.position = Vector3(world_xz.x, 1.20, world_xz.y)
			add_child(vfx)
			var ap: AnimationPlayer = vfx.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap != null and ap.has_animation("open"):
				ap.play("open")
			var t: SceneTreeTimer = tree.create_timer(0.70, true, false, true)
			t.timeout.connect(func() -> void:
				if is_instance_valid(vfx):
					vfx.queue_free()
			)

	if not _statusfx_impact_pool.is_empty():
		var mi: MeshInstance3D = _statusfx_impact_pool.pop_back()
		mi.visible = true
		mi.position = Vector3(world_xz.x, 1.15, world_xz.y)
		mi.scale = Vector3(0.2, 0.2, 0.2)
		var smat := mi.material_override as ShaderMaterial
		if smat != null:
			smat.set_shader_parameter("primary_color", impact_col)
		active_statusfx_impacts.append({
			"node": mi,
			"ttl": 0.18,
			"max_ttl": 0.18,
			"peak_scale": 2.2 if is_crit_or_ko else 1.35,
		})

	spawn_impact_star(world_xz, is_crit_or_ko)
	spawn_impact_debris(world_xz, 4 if is_crit_or_ko else 2)

func spawn_impact_star(world_xz: Vector2, is_crit_or_ko: bool = false) -> void:
	var star_node: Node3D = null
	if not impact_star_pool.is_empty():
		star_node = impact_star_pool.pop_back()
	elif not active_impact_stars.is_empty():
		var oldest: Dictionary = active_impact_stars.pop_front()
		star_node = oldest["node"]
	if star_node == null:
		return

	star_node.visible = true
	star_node.position = Vector3(world_xz.x, 1.25, world_xz.y)
	var peak: float = 2.4 if is_crit_or_ko else 1.55
	var lifetime: float = 0.22 if is_crit_or_ko else 0.16
	star_node.scale = Vector3(0.15, 0.15, 0.15)
	active_impact_stars.append({
		"node": star_node,
		"ttl": lifetime,
		"max_ttl": lifetime,
		"peak_scale": peak,
		"rot": 0.0,
	})
	spawn_impact_sparks(world_xz, 8 if is_crit_or_ko else 4)
	spawn_dust_puff(Vector3(world_xz.x, 0.35, world_xz.y), 2, 0.3)

func spawn_impact_sparks(world_xz: Vector2, count: int = 6) -> void:
	for i: int in range(count):
		if spark_pool.is_empty():
			break
		var sp: MeshInstance3D = spark_pool.pop_back()
		sp.visible = true
		sp.position = Vector3(world_xz.x, 1.15, world_xz.y)
		sp.scale = Vector3.ONE
		var angle: float = float(i) * (TAU / float(maxi(count, 1))) + randf_range(-0.3, 0.3)
		var spd: float = randf_range(3.2, 5.8)
		active_sparks.append({
			"node": sp,
			"vel": Vector3(cos(angle) * spd, randf_range(3.5, 6.2), sin(angle) * spd),
			"ttl": randf_range(0.24, 0.40),
			"max_ttl": 0.40,
		})

func spawn_dust_puff(pos_3d: Vector3, count: int = 3, spread: float = 0.4) -> void:
	for i: int in range(count):
		if dust_pool.is_empty():
			break
		var dp: MeshInstance3D = dust_pool.pop_back()
		dp.visible = true
		var offset := Vector3(randf_range(-spread, spread), randf_range(0.02, 0.15), randf_range(-spread, spread))
		dp.position = pos_3d + offset
		dp.scale = Vector3(0.25, 0.25, 0.25)
		active_dust.append({
			"node": dp,
			"vel": Vector3(randf_range(-0.5, 0.5), randf_range(1.1, 1.8), randf_range(-0.5, 0.5)),
			"ttl": 0.36,
			"max_ttl": 0.36,
		})

func spawn_dash_dust(pos_3d: Vector3, back_dir_xz: Vector2) -> void:
	var base_pos := Vector3(pos_3d.x, 0.12, pos_3d.z)
	var norm_dir: Vector2 = back_dir_xz.normalized()
	for i: int in range(4):
		if dust_pool.is_empty():
			break
		var dp: MeshInstance3D = dust_pool.pop_back()
		dp.visible = true
		var spread_angle: float = randf_range(-0.4, 0.4)
		var rotated_dir: Vector2 = norm_dir.rotated(spread_angle)
		dp.position = base_pos + Vector3(rotated_dir.x * 0.25 * float(i), 0.05, rotated_dir.y * 0.25 * float(i))
		dp.scale = Vector3(0.30, 0.30, 0.30)
		active_dust.append({
			"node": dp,
			"vel": Vector3(rotated_dir.x * randf_range(2.4, 4.2), randf_range(1.2, 2.0), rotated_dir.y * randf_range(2.4, 4.2)),
			"ttl": 0.32,
			"max_ttl": 0.32,
		})

func spawn_flying_part(drop_id: int, part_id: StringName, slot: int, rarity: int, start_xz: Vector2, target_node: Node3D, on_arrived: Callable) -> void:
	var item_root: Node3D = null
	if dropped_part_nodes.has(drop_id):
		item_root = dropped_part_nodes[drop_id]
		dropped_part_nodes.erase(drop_id)
		# Only the piece itself flies to the body; the ground marker stays behind.
		var marker: Node = item_root.get_node_or_null("RarityMarker")
		if marker != null:
			marker.queue_free()
	else:
		item_root = Node3D.new()
		item_root.name = "FlyingDrop_%d" % drop_id
		item_root.position = Vector3(start_xz.x, 0.65, start_xz.y)
		add_child(item_root)
		item_root.add_child(_build_drop_item(part_id, -1))

	active_flying_parts.append({
		"node": item_root,
		"start_pos": Vector3(start_xz.x, 0.65, start_xz.y),
		"target_node": target_node,
		"progress": 0.0,
		"duration": 0.28,
		"on_arrived": on_arrived,
		"trail_timer": 0.0,
	})

func on_block_damaged(cell: Vector2i, _remaining_hp: int, destroyed: bool, world_xz: Vector2) -> void:
	spawn_impact_debris(world_xz, 5 if destroyed else 2)
	spawn_impact_star(world_xz, destroyed)
	if destroyed and destructible_nodes.has(cell):
		var n: Node3D = destructible_nodes[cell]
		if is_instance_valid(n):
			n.queue_free()
		destructible_nodes.erase(cell)

func update_arena_vfx(dt: float, cam_yaw: float = 0.0) -> void:
	if power_cube_node != null and is_instance_valid(power_cube_node):
		power_cube_node.rotate_y(1.4 * dt)
		power_cube_node.position.y = 1.45 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.14

	# 1. Update impact debris
	var idx: int = active_debris.size() - 1
	while idx >= 0:
		var item: Dictionary = active_debris[idx]
		var mi: MeshInstance3D = item["node"]
		var vel: Vector3 = item["vel"]
		var ttl: float = float(item["ttl"]) - dt
		if ttl <= 0.0:
			mi.visible = false
			debris_pool.append(mi)
			active_debris.remove_at(idx)
		else:
			vel.y -= 16.0 * dt
			mi.position += vel * dt
			mi.rotate_x(6.0 * dt)
			mi.rotate_z(5.0 * dt)
			item["vel"] = vel
			item["ttl"] = ttl
		idx -= 1

	# 2. Update impact stars (rapid pop overshoot -> settle to zero)
	var star_idx: int = active_impact_stars.size() - 1
	while star_idx >= 0:
		var s_data: Dictionary = active_impact_stars[star_idx]
		var s_node: Node3D = s_data["node"]
		var ttl: float = float(s_data["ttl"]) - dt
		if ttl <= 0.0:
			s_node.visible = false
			impact_star_pool.append(s_node)
			active_impact_stars.remove_at(star_idx)
		else:
			var max_t: float = float(s_data["max_ttl"])
			var peak_s: float = float(s_data["peak_scale"])
			var t_norm: float = 1.0 - (ttl / max_t)
			# Overshoot curve: rapid pop in first 25% of lifetime, then decay
			var cur_scale: float = 0.0
			if t_norm < 0.25:
				cur_scale = lerpf(0.2, peak_s, t_norm / 0.25)
			else:
				cur_scale = lerpf(peak_s, 0.02, (t_norm - 0.25) / 0.75)
			s_node.scale = Vector3.ONE * cur_scale
			var r: float = float(s_data["rot"]) + 16.0 * dt
			s_data["rot"] = r
			s_node.rotation_degrees = Vector3(58.0, rad_to_deg(cam_yaw), r * 57.2958)
			s_data["ttl"] = ttl
		star_idx -= 1

	# 3. Update sparks
	var sp_idx: int = active_sparks.size() - 1
	while sp_idx >= 0:
		var sp_item: Dictionary = active_sparks[sp_idx]
		var sp_node: MeshInstance3D = sp_item["node"]
		var sp_vel: Vector3 = sp_item["vel"]
		var sp_ttl: float = float(sp_item["ttl"]) - dt
		if sp_ttl <= 0.0:
			sp_node.visible = false
			spark_pool.append(sp_node)
			active_sparks.remove_at(sp_idx)
		else:
			sp_vel.y -= 18.0 * dt
			sp_node.position += sp_vel * dt
			var max_sp_ttl: float = float(sp_item["max_ttl"])
			var shrink: float = clampf(sp_ttl / max_sp_ttl, 0.05, 1.0)
			sp_node.scale = Vector3.ONE * shrink
			sp_item["vel"] = sp_vel
			sp_item["ttl"] = sp_ttl
		sp_idx -= 1

	# 4. Update dust puffs
	var d_idx: int = active_dust.size() - 1
	while d_idx >= 0:
		var d_item: Dictionary = active_dust[d_idx]
		var d_node: MeshInstance3D = d_item["node"]
		var d_vel: Vector3 = d_item["vel"]
		var d_ttl: float = float(d_item["ttl"]) - dt
		if d_ttl <= 0.0:
			d_node.visible = false
			dust_pool.append(d_node)
			active_dust.remove_at(d_idx)
		else:
			d_node.position += d_vel * dt
			d_vel.x = lerpf(d_vel.x, 0.0, 4.0 * dt)
			d_vel.z = lerpf(d_vel.z, 0.0, 4.0 * dt)
			var max_d_ttl: float = float(d_item["max_ttl"])
			var t_grow: float = 1.0 - (d_ttl / max_d_ttl)
			var grow_s: float = lerpf(0.3, 1.35, t_grow)
			d_node.scale = Vector3.ONE * grow_s
			d_item["vel"] = d_vel
			d_item["ttl"] = d_ttl
		d_idx -= 1

	# 5. Update flying stolen parts (arcing toward hero body)
	var fly_idx: int = active_flying_parts.size() - 1
	while fly_idx >= 0:
		var fp: Dictionary = active_flying_parts[fly_idx]
		var f_node: Node3D = fp["node"]
		var prog: float = float(fp["progress"]) + dt / float(fp["duration"])
		var start_p: Vector3 = fp["start_pos"]
		var t_node: Node3D = fp["target_node"]
		var target_p: Vector3 = (t_node.global_position + Vector3(0.0, 1.25, 0.0)) if is_instance_valid(t_node) else start_p

		var t_clamped: float = clampf(prog, 0.0, 1.0)
		var ease_t: float = t_clamped * t_clamped * (3.0 - 2.0 * t_clamped) # smoothstep
		var arc_h: float = sin(t_clamped * PI) * 1.85
		f_node.global_position = start_p.lerp(target_p, ease_t) + Vector3(0.0, arc_h, 0.0)
		f_node.rotate_y(24.0 * dt)
		f_node.rotate_z(14.0 * dt)

		var tr_timer: float = float(fp["trail_timer"]) + dt
		if tr_timer >= 0.045:
			tr_timer = 0.0
			spawn_dust_puff(f_node.global_position, 1, 0.15)
		fp["trail_timer"] = tr_timer
		fp["progress"] = prog

		if prog >= 1.0:
			var cb: Callable = fp["on_arrived"]
			if not cb.is_null():
				cb.call()
			spawn_impact_star(Vector2(target_p.x, target_p.z), true)
			if is_instance_valid(f_node):
				f_node.queue_free()
			active_flying_parts.remove_at(fly_idx)
		fly_idx -= 1

	_update_comic_texts(dt)

	# 6. Update StatusFX flashes
	var f_idx: int = active_statusfx_flashes.size() - 1
	while f_idx >= 0:
		var item: Dictionary = active_statusfx_flashes[f_idx]
		item["ttl"] = float(item["ttl"]) - dt
		var fl: MeshInstance3D = item["node"]
		var prog: float = clampf(1.0 - (float(item["ttl"]) / float(item["max_ttl"])), 0.0, 1.0)
		fl.scale = Vector3.ONE * lerpf(0.4, 0.9, prog)
		if float(item["ttl"]) <= 0.0:
			fl.visible = false
			_statusfx_flash_pool.append(fl)
			active_statusfx_flashes.remove_at(f_idx)
		f_idx -= 1

	# 7. Update StatusFX impacts
	var imp_idx: int = active_statusfx_impacts.size() - 1
	while imp_idx >= 0:
		var item: Dictionary = active_statusfx_impacts[imp_idx]
		item["ttl"] = float(item["ttl"]) - dt
		var mi: MeshInstance3D = item["node"]
		var prog: float = clampf(1.0 - (float(item["ttl"]) / float(item["max_ttl"])), 0.0, 1.0)
		var current_scale: float = lerpf(0.3, float(item["peak_scale"]), sin(prog * PI * 0.5))
		mi.scale = Vector3.ONE * current_scale
		if float(item["ttl"]) <= 0.0:
			mi.visible = false
			_statusfx_impact_pool.append(mi)
			active_statusfx_impacts.remove_at(imp_idx)
		imp_idx -= 1

func _spawn_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _exit_tree() -> void:
	for mi: MeshInstance3D in _statusfx_impact_pool:
		if is_instance_valid(mi):
			mi.material_override = null
	for fl: MeshInstance3D in _statusfx_flash_pool:
		if is_instance_valid(fl):
			fl.material_override = null
