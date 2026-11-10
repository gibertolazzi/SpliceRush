class_name ArenaBuilder3D
extends Node3D

const HAZARD_SHADER := preload("res://game/shaders/hazard_stripes.gdshader")
const BEAM_SHADER := preload("res://game/shaders/power_beam.gdshader")

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

func _ready() -> void:
	_init_materials()

func _init_materials() -> void:
	_stone_mat_a = StandardMaterial3D.new()
	_stone_mat_a.albedo_color = Color(0.24, 0.21, 0.32) # Dark desaturated slate-lavender
	_stone_mat_a.roughness = 0.84

	_stone_mat_b = StandardMaterial3D.new()
	_stone_mat_b.albedo_color = Color(0.18, 0.16, 0.26) # Deeper desaturated slate
	_stone_mat_b.roughness = 0.88

	_stone_rim_mat = StandardMaterial3D.new()
	_stone_rim_mat.albedo_color = Color(0.42, 0.38, 0.52) # Light stone rim & crack highlight
	_stone_rim_mat.roughness = 0.78

	_stone_dark_mat = StandardMaterial3D.new()
	_stone_dark_mat.albedo_color = Color(0.11, 0.09, 0.16) # Deep cliff foundation
	_stone_dark_mat.roughness = 0.92

	_debris_mat = StandardMaterial3D.new()
	_debris_mat.albedo_color = Color(0.90, 0.84, 0.74) # Bright cream-sandstone fractured chunks
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
	_cloud_mat_a.albedo_color = Color(0.36, 0.24, 0.62, 0.45)

	_cloud_mat_b = StandardMaterial3D.new()
	_cloud_mat_b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat_b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cloud_mat_b.albedo_color = Color(0.24, 0.16, 0.44, 0.60)

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
			_stone_mat_a.albedo_color = Color(0.16, 0.18, 0.22)
			_stone_mat_b.albedo_color = Color(0.12, 0.14, 0.18)
			_stone_dark_mat.albedo_color = Color(0.08, 0.09, 0.12)
			_stone_rim_mat.albedo_color = Color(0.32, 0.38, 0.46)
			_debris_mat.albedo_color = Color(0.72, 0.82, 0.92)
		MatchServer.MapTheme.FLOATING_HEX:
			_stone_mat_a.albedo_color = Color(0.28, 0.34, 0.46)
			_stone_mat_b.albedo_color = Color(0.20, 0.24, 0.36)
			_stone_dark_mat.albedo_color = Color(0.12, 0.15, 0.24)
			_stone_rim_mat.albedo_color = Color(0.50, 0.58, 0.72)
			_debris_mat.albedo_color = Color(0.85, 0.90, 1.0)
		_:
			_stone_mat_a.albedo_color = Color(0.24, 0.21, 0.32)
			_stone_mat_b.albedo_color = Color(0.18, 0.16, 0.26)
			_stone_dark_mat.albedo_color = Color(0.11, 0.09, 0.16)
			_stone_rim_mat.albedo_color = Color(0.42, 0.38, 0.52)
			_debris_mat.albedo_color = Color(0.90, 0.84, 0.74)

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

	var tile: float = server.balance.tile_size
	_build_floor_multimesh(server, tile)
	_build_grid_props(server, tile)
	_build_void_clouds(server)

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

func spawn_dropped_part_visual(drop_id: int, part_id: StringName, slot: int, rarity: int, pos_xz: Vector2, _is_power: bool) -> void:
	if _stone_mat_a == null:
		_init_materials()
	if dropped_part_nodes.has(drop_id):
		return
	var root_n := Node3D.new()
	root_n.name = "Drop_%d" % drop_id
	root_n.position = Vector3(pos_xz.x, 0.0, pos_xz.y)
	add_child(root_n)

	var r_mat: StandardMaterial3D = _rarity_mats.get(rarity, _gold_glow_mat) as StandardMaterial3D
	var pdata: PartData = PartCatalog.get_part(part_id)
	var prim_mat := StandardMaterial3D.new()
	prim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	prim_mat.albedo_color = pdata.primary_color

	match rarity:
		PartData.Rarity.COMMON:
			_spawn_box(root_n, Vector3(0.62, 0.06, 0.62), Vector3(0.0, 0.05, 0.0), r_mat)
		PartData.Rarity.RARE:
			_spawn_box(root_n, Vector3(0.76, 0.07, 0.76), Vector3(0.0, 0.05, 0.0), r_mat, Vector3(0.0, 45.0, 0.0))
			_spawn_box(root_n, Vector3(0.10, 1.35, 0.10), Vector3(0.0, 0.72, 0.0), r_mat)
		PartData.Rarity.EPIC:
			_spawn_box(root_n, Vector3(0.84, 0.08, 0.84), Vector3(0.0, 0.05, 0.0), r_mat)
			_spawn_box(root_n, Vector3(0.84, 0.08, 0.84), Vector3(0.0, 0.06, 0.0), r_mat, Vector3(0.0, 45.0, 0.0))
			_spawn_box(root_n, Vector3(0.14, 1.85, 0.14), Vector3(0.0, 0.95, 0.0), r_mat)
		PartData.Rarity.LEGENDARY:
			_spawn_box(root_n, Vector3(0.96, 0.09, 0.96), Vector3(0.0, 0.05, 0.0), r_mat)
			_spawn_box(root_n, Vector3(0.96, 0.09, 0.96), Vector3(0.0, 0.07, 0.0), _white_glow_mat, Vector3(0.0, 45.0, 0.0))
			_spawn_box(root_n, Vector3(0.18, 2.55, 0.18), Vector3(0.0, 1.30, 0.0), r_mat)

	var item_pivot := Node3D.new()
	item_pivot.name = "ItemMesh"
	item_pivot.position = Vector3(0.0, 0.68, 0.0)
	root_n.add_child(item_pivot)

	match slot:
		PartData.Slot.HEAD:
			_spawn_box(item_pivot, Vector3(0.50, 0.48, 0.48), Vector3.ZERO, prim_mat)
			_spawn_box(item_pivot, Vector3(0.54, 0.16, 0.52), Vector3(0.0, 0.06, 0.0), r_mat)
		PartData.Slot.ARMS:
			_spawn_box(item_pivot, Vector3(0.56, 0.42, 0.42), Vector3(-0.06, 0.0, 0.0), prim_mat, Vector3(0.0, 0.0, 18.0))
			_spawn_box(item_pivot, Vector3(0.24, 0.28, 0.62), Vector3(0.24, 0.0, 0.0), r_mat)
		PartData.Slot.LEGS:
			_spawn_box(item_pivot, Vector3(0.36, 0.52, 0.36), Vector3(0.0, 0.06, 0.0), prim_mat)
			_spawn_box(item_pivot, Vector3(0.46, 0.20, 0.52), Vector3(0.0, -0.20, 0.06), r_mat)
		PartData.Slot.CORE:
			_spawn_box(item_pivot, Vector3(0.48, 0.48, 0.24), Vector3.ZERO, r_mat, Vector3(0.0, 0.0, 45.0))
			_spawn_box(item_pivot, Vector3(0.28, 0.28, 0.30), Vector3.ZERO, _white_glow_mat)

	dropped_part_nodes[drop_id] = root_n

func remove_dropped_part_visual(drop_id: int, pos_xz: Vector2) -> void:
	spawn_impact_debris(pos_xz, 4)
	if dropped_part_nodes.has(drop_id):
		var n: Node3D = dropped_part_nodes[drop_id]
		if is_instance_valid(n):
			n.queue_free()
		dropped_part_nodes.erase(drop_id)

func sync_dropped_parts(drops: Array[MatchServer.DroppedPartState], dt: float) -> void:
	var t_sec: float = float(Time.get_ticks_msec()) * 0.004
	for drop: MatchServer.DroppedPartState in drops:
		if not dropped_part_nodes.has(drop.id):
			spawn_dropped_part_visual(drop.id, drop.part_id, int(drop.slot), int(drop.rarity), drop.pos, drop.is_power_part)
		var n: Node3D = dropped_part_nodes[drop.id]
		if is_instance_valid(n):
			n.position = Vector3(drop.pos.x, 0.0, drop.pos.y)
			var item_mesh: Node3D = n.get_node_or_null("ItemMesh") as Node3D
			if item_mesh != null:
				item_mesh.rotate_y(2.6 * dt)
				item_mesh.position.y = 0.66 + sin(t_sec + float(drop.id)) * 0.14

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
	var mm_a: MultiMesh = _add_slab_multimesh(cells_a, tile * 0.93, _stone_mat_a)
	for i: int in range(cells_a_coords.size()):
		floor_cell_map[cells_a_coords[i]] = {"mm": mm_a, "idx": i}

	var mm_b: MultiMesh = _add_slab_multimesh(cells_b, tile * 0.91, _stone_mat_b)
	for i: int in range(cells_b_coords.size()):
		floor_cell_map[cells_b_coords[i]] = {"mm": mm_b, "idx": i}

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
			_spawn_box(block_root, Vector3(tile * 0.88, tile * 0.88, tile * 0.88), Vector3(0.0, tile * 0.44, 0.0), _stone_mat_b)
			_spawn_box(block_root, Vector3(tile * 0.92, 0.18, tile * 0.92), Vector3(0.0, tile * 0.82, 0.0), _stone_mat_a)
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
	cm_outer.top_radius = 2.1
	cm_outer.bottom_radius = 2.4
	cm_outer.height = 0.42
	cm_outer.radial_segments = 6
	cyl_outer.mesh = cm_outer
	cyl_outer.position = Vector3(0.0, 0.21, 0.0)
	cyl_outer.material_override = _stone_dark_mat
	ped.add_child(cyl_outer)

	var cyl_gold := MeshInstance3D.new()
	var cm_gold := CylinderMesh.new()
	cm_gold.top_radius = 1.65
	cm_gold.bottom_radius = 1.85
	cm_gold.height = 0.35
	cm_gold.radial_segments = 6
	cyl_gold.mesh = cm_gold
	cyl_gold.position = Vector3(0.0, 0.48, 0.0)
	cyl_gold.material_override = _gold_glow_mat
	ped.add_child(cyl_gold)

	power_cube_node = Node3D.new()
	power_cube_node.position = Vector3(0.0, 1.85, 0.0)
	ped.add_child(power_cube_node)
	_spawn_box(power_cube_node, Vector3(1.32, 1.32, 1.32), Vector3.ZERO, _gold_glow_mat)
	# Question mark on all 4 vertical faces of the spinning power cube
	_build_question_mark(power_cube_node, Vector3(0.0, 0.0, 0.68), 0.78, _white_glow_mat, Vector3.ZERO)
	_build_question_mark(power_cube_node, Vector3(0.0, 0.0, -0.68), 0.78, _white_glow_mat, Vector3(0.0, 180.0, 0.0))
	_build_question_mark(power_cube_node, Vector3(0.68, 0.0, 0.0), 0.78, _white_glow_mat, Vector3(0.0, 90.0, 0.0))
	_build_question_mark(power_cube_node, Vector3(-0.68, 0.0, 0.0), 0.78, _white_glow_mat, Vector3(0.0, -90.0, 0.0))

	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = BEAM_SHADER
	var beam_mi := MeshInstance3D.new()
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius = 1.15
	beam_cyl.bottom_radius = 1.45
	beam_cyl.height = 36.0
	beam_cyl.radial_segments = 16
	beam_cyl.cap_top = false
	beam_cyl.cap_bottom = false
	beam_mi.mesh = beam_cyl
	beam_mi.position = Vector3(0.0, 18.0, 0.0)
	beam_mi.material_override = beam_mat
	ped.add_child(beam_mi)

	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.76, 0.24)
	omni.light_energy = 2.8
	omni.omni_range = 11.0
	omni.position = Vector3(0.0, 2.4, 0.0)
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

	# North ruins & ruined monolithic pillars
	_spawn_box(ruins, Vector3(safe_b.x * 2.2, 3.2, 2.4), Vector3(0.0, 1.2, north_z), ruin_mat)
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
	else:
		item_root = Node3D.new()
		item_root.name = "FlyingDrop_%d" % drop_id
		item_root.position = Vector3(start_xz.x, 0.65, start_xz.y)
		add_child(item_root)
		var pdata: PartData = PartCatalog.get_part(part_id)
		var r_mat: StandardMaterial3D = _rarity_mats.get(rarity, _gold_glow_mat) as StandardMaterial3D
		var prim_mat := StandardMaterial3D.new()
		prim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		prim_mat.albedo_color = pdata.primary_color
		var box_item := _spawn_box(item_root, Vector3(0.52, 0.52, 0.52), Vector3.ZERO, prim_mat)
		_spawn_box(box_item, Vector3(0.58, 0.16, 0.58), Vector3.ZERO, r_mat)

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

func update_arena_vfx(dt: float) -> void:
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
			s_node.rotation_degrees = Vector3(58.0, 0.0, r * 57.2958)
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
