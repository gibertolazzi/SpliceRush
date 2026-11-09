class_name ArenaBuilder3D
extends Node3D

const HAZARD_SHADER := preload("res://game/shaders/hazard_stripes.gdshader")
const BEAM_SHADER := preload("res://game/shaders/power_beam.gdshader")

var destructible_nodes: Dictionary = {} # Vector2i -> Node3D
var power_cube_node: Node3D
var debris_pool: Array[MeshInstance3D] = []
var active_debris: Array[Dictionary] = []

var _stone_mat_a: StandardMaterial3D
var _stone_mat_b: StandardMaterial3D
var _stone_dark_mat: StandardMaterial3D
var _gold_glow_mat: StandardMaterial3D
var _white_glow_mat: StandardMaterial3D

func _ready() -> void:
	_init_materials()

func _init_materials() -> void:
	_stone_mat_a = StandardMaterial3D.new()
	_stone_mat_a.albedo_color = Color(0.44, 0.36, 0.62) # #7A6BB0 violet-lavender
	_stone_mat_a.roughness = 0.82

	_stone_mat_b = StandardMaterial3D.new()
	_stone_mat_b.albedo_color = Color(0.35, 0.28, 0.54) # #5B4B8A deeper lavender
	_stone_mat_b.roughness = 0.86

	_stone_dark_mat = StandardMaterial3D.new()
	_stone_dark_mat.albedo_color = Color(0.20, 0.15, 0.34)
	_stone_dark_mat.roughness = 0.90

	_gold_glow_mat = StandardMaterial3D.new()
	_gold_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gold_glow_mat.albedo_color = Color(1.0, 0.72, 0.14)

	_white_glow_mat = StandardMaterial3D.new()
	_white_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_white_glow_mat.albedo_color = Color(1.0, 0.96, 0.82)

func build_from_server(server: MatchServer) -> void:
	for child: Node in get_children():
		child.queue_free()
	destructible_nodes.clear()
	active_debris.clear()
	debris_pool.clear()

	var tile: float = server.balance.tile_size
	_build_floor_multimesh(server, tile)
	_build_grid_props(server, tile)
	_build_power_pedestal(Vector3(2.2, 0.0, -4.8))
	_build_background_ruins_and_cliffs()
	_build_dust_and_action_accents()
	_init_debris_pool()

func _build_floor_multimesh(server: MatchServer, tile: float) -> void:
	# Sub-base dark slab for cracks between tiles
	var base_mi := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(float(server.balance.grid_width) * tile + 1.2, 1.4, float(server.balance.grid_depth) * tile + 1.2)
	base_mi.mesh = base_box
	base_mi.position = Vector3(0.0, -0.82, 0.0)
	base_mi.material_override = _stone_dark_mat
	add_child(base_mi)

	var cells_a: Array[Transform3D] = []
	var cells_b: Array[Transform3D] = []
	for cell_var: Variant in server.grid_cells.keys():
		var cell: Vector2i = cell_var as Vector2i
		var wxz: Vector2 = server.cell_to_world_xz(cell)
		var hash_v: int = abs((cell.x * 73856093) ^ (cell.y * 19349663))
		var y_off: float = -0.06 + float(hash_v % 5) * 0.018
		var yaw: float = float(hash_v % 4) * (PI * 0.5)
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
		var xform := Transform3D(basis, Vector3(wxz.x, y_off, wxz.y))
		if ((cell.x + cell.y) & 1) == 0:
			cells_a.append(xform)
		else:
			cells_b.append(xform)

	_add_slab_multimesh(cells_a, tile * 0.92, _stone_mat_a)
	_add_slab_multimesh(cells_b, tile * 0.90, _stone_mat_b)

func _add_slab_multimesh(transforms: Array[Transform3D], slab_size: float, mat: Material) -> void:
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

	# Left mystery blue "?" block seen in key art
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

	# Hexagonal/stepped golden-purple base
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

	# Glowing "?" Power Part Cube
	power_cube_node = Node3D.new()
	power_cube_node.position = Vector3(0.0, 1.45, 0.0)
	ped.add_child(power_cube_node)
	_spawn_box(power_cube_node, Vector3(1.38, 1.38, 1.38), Vector3.ZERO, _gold_glow_mat)
	_build_question_mark(power_cube_node, Vector3(0.0, 0.0, 0.72), 0.82, _white_glow_mat)

	# Vertical Golden Light Beam
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = BEAM_SHADER
	var beam_mi := MeshInstance3D.new()
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius = 0.72
	beam_cyl.bottom_radius = 0.95
	beam_cyl.height = 18.0
	beam_cyl.radial_segments = 12
	beam_mi.mesh = beam_cyl
	beam_mi.position = Vector3(0.0, 9.5, 0.0)
	beam_mi.material_override = beam_mat
	ped.add_child(beam_mi)

	# Warm golden point light for bounce lighting on stone slabs
	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.76, 0.24)
	omni.light_energy = 2.8
	omni.omni_range = 11.0
	omni.position = Vector3(0.0, 2.4, 0.0)
	ped.add_child(omni)

func _build_question_mark(parent: Node3D, offset: Vector3, scale_f: float, mat: Material) -> void:
	var q := Node3D.new()
	q.position = offset
	q.scale = Vector3.ONE * scale_f
	parent.add_child(q)
	_spawn_box(q, Vector3(0.52, 0.16, 0.08), Vector3(0.0, 0.38, 0.0), mat)
	_spawn_box(q, Vector3(0.16, 0.28, 0.08), Vector3(0.18, 0.22, 0.0), mat)
	_spawn_box(q, Vector3(0.34, 0.16, 0.08), Vector3(0.09, 0.06, 0.0), mat)
	_spawn_box(q, Vector3(0.16, 0.20, 0.08), Vector3(0.0, -0.08, 0.0), mat)
	_spawn_box(q, Vector3(0.18, 0.18, 0.08), Vector3(0.0, -0.36, 0.0), mat)

func _build_background_ruins_and_cliffs() -> void:
	var ruins := Node3D.new()
	ruins.name = "BackgroundRuins"
	add_child(ruins)

	var ruin_mat := StandardMaterial3D.new()
	ruin_mat.albedo_color = Color(0.44, 0.34, 0.64)
	ruin_mat.roughness = 0.85

	# Back fortress wall & towers (-Z)
	_spawn_box(ruins, Vector3(14.0, 5.5, 2.2), Vector3(0.5, 2.2, -13.5), ruin_mat)
	_spawn_box(ruins, Vector3(3.4, 8.2, 2.8), Vector3(-5.8, 3.6, -13.0), ruin_mat)
	_spawn_box(ruins, Vector3(3.6, 7.6, 2.8), Vector3(6.2, 3.2, -12.8), ruin_mat)
	_spawn_box(ruins, Vector3(2.4, 9.5, 2.4), Vector3(-9.5, 4.2, -11.0), ruin_mat)
	_spawn_box(ruins, Vector3(2.2, 8.8, 2.2), Vector3(9.6, 3.8, -10.2), ruin_mat)

	# Glowing Magenta Pixel-Crown Banner on the back ruin wall (key art landmark!)
	var banner_bg := StandardMaterial3D.new()
	banner_bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	banner_bg.albedo_color = Color(0.86, 0.34, 0.92)
	var banner_border := StandardMaterial3D.new()
	banner_border.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	banner_border.albedo_color = Color(1.0, 0.72, 0.98)

	var banner := Node3D.new()
	banner.position = Vector3(-1.5, 3.6, -11.8)
	ruins.add_child(banner)
	_spawn_box(banner, Vector3(3.2, 2.1, 0.2), Vector3.ZERO, banner_bg)
	# Pixel Crown inside banner
	_spawn_box(banner, Vector3(1.6, 0.35, 0.26), Vector3(0.0, -0.35, 0.05), banner_border)
	_spawn_box(banner, Vector3(0.32, 0.65, 0.26), Vector3(-0.64, 0.08, 0.05), banner_border)
	_spawn_box(banner, Vector3(0.32, 0.75, 0.26), Vector3(0.0, 0.14, 0.05), banner_border)
	_spawn_box(banner, Vector3(0.32, 0.65, 0.26), Vector3(0.64, 0.08, 0.05), banner_border)

	# Side cliffs and floating islands
	_spawn_box(ruins, Vector3(3.2, 4.5, 18.0), Vector3(-10.2, 0.4, -2.0), _stone_dark_mat)
	_spawn_box(ruins, Vector3(3.2, 4.5, 18.0), Vector3(10.2, 0.4, -2.0), _stone_dark_mat)

func _build_dust_and_action_accents() -> void:
	# Warm golden-tan dust clouds near the foreground jump & left impact burst from key art
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

	# Impact star burst under fighter 1 (left side)
	var impact := Node3D.new()
	impact.position = Vector3(-2.6, 1.0, -0.2)
	add_child(impact)
	_spawn_box(impact, Vector3(1.5, 0.20, 0.20), Vector3.ZERO, _white_glow_mat, Vector3(0.0, 20.0, 25.0))
	_spawn_box(impact, Vector3(0.20, 1.5, 0.20), Vector3.ZERO, _white_glow_mat, Vector3(0.0, 20.0, 25.0))
	_spawn_box(impact, Vector3(1.1, 0.24, 0.24), Vector3.ZERO, _gold_glow_mat, Vector3(0.0, 20.0, 70.0))

func _init_debris_pool() -> void:
	for i: int in range(18):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.32, 0.32, 0.32)
		mi.mesh = bm
		mi.material_override = _stone_dark_mat
		mi.visible = false
		add_child(mi)
		debris_pool.append(mi)

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

func on_block_damaged(cell: Vector2i, _remaining_hp: int, destroyed: bool, world_xz: Vector2) -> void:
	spawn_impact_debris(world_xz, 5 if destroyed else 2)
	if destroyed and destructible_nodes.has(cell):
		var n: Node3D = destructible_nodes[cell]
		if is_instance_valid(n):
			n.queue_free()
		destructible_nodes.erase(cell)

func update_arena_vfx(dt: float) -> void:
	if power_cube_node != null and is_instance_valid(power_cube_node):
		power_cube_node.rotate_y(1.4 * dt)
		power_cube_node.position.y = 1.45 + sin(float(Time.get_ticks_msec()) * 0.004) * 0.14

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
