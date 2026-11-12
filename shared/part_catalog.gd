class_name PartCatalog
extends RefCounted

static var _parts: Dictionary = {}

static func _ensure_initialized() -> void:
	if not _parts.is_empty():
		return

	# SLOT 0: HEAD
	_register(
		&"base_head", &"PART_BASE_HEAD", PartData.Slot.HEAD, PartData.Rarity.COMMON,
		&"head_basic", 1.0, 1.0, 1.0, 1.0, 10,
		Color(0.84, 0.78, 0.74), Color(0.55, 0.52, 0.62)
	)
	_register(
		&"visor_head", &"PART_VISOR_HEAD", PartData.Slot.HEAD, PartData.Rarity.RARE,
		&"head_visor", 1.10, 0.96, 1.18, 1.0, 24,
		Color(0.20, 0.62, 0.98), Color(0.12, 0.92, 1.0)
	)
	_register(
		&"spike_helm", &"PART_SPIKE_HELM", PartData.Slot.HEAD, PartData.Rarity.EPIC,
		&"head_spikes", 1.22, 0.94, 1.12, 1.04, 42,
		Color(0.68, 0.28, 0.96), Color(0.95, 0.22, 0.36)
	)
	_register(
		&"laser_eye", &"PART_LASER_EYE", PartData.Slot.HEAD, PartData.Rarity.LEGENDARY,
		&"head_laser", 1.35, 0.90, 1.45, 1.05, 65,
		Color(0.92, 0.84, 0.78), Color(1.0, 0.20, 0.18)
	)

	# SLOT 1: ARMS
	_register(
		&"base_fist", &"PART_BASE_FIST", PartData.Slot.ARMS, PartData.Rarity.COMMON,
		&"melee_punch", 1.0, 1.0, 1.0, 1.0, 10,
		Color(0.82, 0.74, 0.68), Color(0.45, 0.42, 0.54)
	)
	_register(
		&"giant_fist", &"PART_GIANT_FIST", PartData.Slot.ARMS, PartData.Rarity.RARE,
		&"heavy_knockback", 1.28, 1.04, 1.10, 1.0, 26,
		Color(0.90, 0.76, 0.66), Color(0.24, 0.68, 1.0)
	)
	_register(
		&"chainsaw_arm", &"PART_CHAINSAW_ARM", PartData.Slot.ARMS, PartData.Rarity.EPIC,
		&"chainsaw_shred", 1.32, 0.76, 1.12, 1.02, 46,
		Color(0.98, 0.44, 0.04), Color(0.76, 0.28, 0.98)
	)
	_register(
		&"mega_claws", &"PART_MEGA_CLAWS", PartData.Slot.ARMS, PartData.Rarity.LEGENDARY,
		&"twin_claws", 1.48, 0.74, 1.22, 1.06, 68,
		Color(1.0, 0.74, 0.14), Color(1.0, 0.18, 0.58)
	)

	# SLOT 2: LEGS
	_register(
		&"base_boots", &"PART_BASE_BOOTS", PartData.Slot.LEGS, PartData.Rarity.COMMON,
		&"walk_basic", 1.0, 1.0, 1.0, 1.0, 10,
		Color(0.22, 0.20, 0.32), Color(0.52, 0.50, 0.64)
	)
	_register(
		&"spring_legs", &"PART_SPRING_LEGS", PartData.Slot.LEGS, PartData.Rarity.RARE,
		&"spring_hop", 1.04, 1.0, 1.0, 1.16, 24,
		Color(0.24, 0.78, 0.96), Color(1.0, 0.82, 0.20)
	)
	_register(
		&"roller_wheels", &"PART_ROLLER_WHEELS", PartData.Slot.LEGS, PartData.Rarity.EPIC,
		&"turbo_roll", 1.06, 0.95, 1.05, 1.28, 42,
		Color(0.74, 0.28, 0.96), Color(1.0, 0.42, 0.68)
	)
	_register(
		&"rocket_legs", &"PART_ROCKET_LEGS", PartData.Slot.LEGS, PartData.Rarity.LEGENDARY,
		&"rocket_thruster", 1.12, 0.90, 1.10, 1.38, 64,
		Color(0.88, 0.12, 0.16), Color(1.0, 0.62, 0.10)
	)

	# SLOT 3: CORE
	_register(
		&"base_core", &"PART_BASE_CORE", PartData.Slot.CORE, PartData.Rarity.COMMON,
		&"core_basic", 1.0, 1.0, 1.0, 1.0, 10,
		Color(0.54, 0.48, 0.72), Color(0.45, 0.42, 0.58)
	)
	_register(
		&"shield_core", &"PART_SHIELD_CORE", PartData.Slot.CORE, PartData.Rarity.RARE,
		&"core_shield", 1.08, 0.96, 1.05, 1.04, 25,
		Color(0.20, 0.68, 0.98), Color(0.42, 0.92, 1.0)
	)
	_register(
		&"magnet_core", &"PART_MAGNET_CORE", PartData.Slot.CORE, PartData.Rarity.EPIC,
		&"core_magnet", 1.14, 0.92, 1.12, 1.08, 44,
		Color(0.82, 0.24, 0.96), Color(1.0, 0.22, 0.58)
	)
	_register(
		&"crown_core", &"PART_CROWN_CORE", PartData.Slot.CORE, PartData.Rarity.LEGENDARY,
		&"core_crown", 1.24, 0.88, 1.16, 1.12, 66,
		Color(1.0, 0.78, 0.15), Color(1.0, 0.18, 0.58)
	)

	# SEVERED / MISSING SLOTS
	_register(
		&"severed_one_arm", &"PART_SEVERED_ONE_ARM", PartData.Slot.ARMS, PartData.Rarity.COMMON,
		&"severed_stub_one", 0.70, 1.15, 0.85, 0.95, 0,
		Color(0.20, 0.18, 0.28), Color(0.35, 0.10, 0.15)
	)
	_register(
		&"severed_arms", &"PART_SEVERED_ARMS", PartData.Slot.ARMS, PartData.Rarity.COMMON,
		&"severed_stub", 0.35, 1.40, 0.65, 0.85, 0,
		Color(0.20, 0.18, 0.28), Color(0.35, 0.10, 0.15)
	)
	_register(
		&"severed_one_leg", &"PART_SEVERED_ONE_LEG", PartData.Slot.LEGS, PartData.Rarity.COMMON,
		&"severed_hop", 0.90, 1.05, 0.95, 0.75, 0,
		Color(0.20, 0.18, 0.28), Color(0.35, 0.10, 0.15)
	)
	_register(
		&"severed_legs", &"PART_SEVERED_LEGS", PartData.Slot.LEGS, PartData.Rarity.COMMON,
		&"severed_crawl", 0.80, 1.10, 0.90, 0.50, 0,
		Color(0.20, 0.18, 0.28), Color(0.35, 0.10, 0.15)
	)

static func _register(
	id: StringName,
	tr_key: StringName,
	slot: PartData.Slot,
	rarity: PartData.Rarity,
	effect: StringName,
	dmg_mult: float,
	cd_mult: float,
	rng_mult: float,
	spd_mult: float,
	mass: int,
	prim_col: Color,
	acc_col: Color
) -> void:
	var p := PartData.new()
	p.part_id = id
	p.translation_key = tr_key
	p.slot = slot
	p.rarity = rarity
	p.effect_id = effect
	p.cosmetic_id = id
	p.damage_multiplier = dmg_mult
	p.cooldown_multiplier = cd_mult
	p.range_multiplier = rng_mult
	p.speed_multiplier = spd_mult
	p.mass_value = mass
	p.primary_color = prim_col
	p.accent_color = acc_col
	_parts[id] = p

static func get_part(part_id: StringName) -> PartData:
	_ensure_initialized()
	if _parts.has(part_id):
		return _parts[part_id] as PartData
	return _parts[&"base_fist"] as PartData

static func get_base_part_for_slot(slot: PartData.Slot) -> StringName:
	match slot:
		PartData.Slot.HEAD:
			return &"base_head"
		PartData.Slot.ARMS:
			return &"base_fist"
		PartData.Slot.LEGS:
			return &"base_boots"
		PartData.Slot.CORE:
			return &"base_core"
	return &"base_fist"

static func get_severed_part_for_slot(slot: PartData.Slot) -> StringName:
	match slot:
		PartData.Slot.ARMS:
			return &"severed_one_arm"
		PartData.Slot.LEGS:
			return &"severed_one_leg"
		PartData.Slot.HEAD:
			return &"base_head"
		PartData.Slot.CORE:
			return &"base_core"
	return &"base_fist"

static func get_severed_step(current_id: StringName, slot: PartData.Slot) -> StringName:
	match slot:
		PartData.Slot.LEGS:
			if current_id == &"severed_one_leg":
				return &"severed_legs"
			elif current_id == &"severed_legs":
				return &"severed_legs"
			return &"severed_one_leg"
		PartData.Slot.ARMS:
			if current_id == &"severed_one_arm":
				return &"severed_arms"
			elif current_id == &"severed_arms":
				return &"severed_arms"
			return &"severed_one_arm"
		PartData.Slot.HEAD:
			return &"base_head"
		PartData.Slot.CORE:
			return &"base_core"
	return &"base_fist"

static func is_severed(part_id: StringName) -> bool:
	return part_id == &"severed_arms" or part_id == &"severed_legs" or part_id == &"severed_one_arm" or part_id == &"severed_one_leg"

static func get_rarity_color(rarity: PartData.Rarity) -> Color:
	match rarity:
		PartData.Rarity.COMMON:
			return Color(0.68, 0.70, 0.80)
		PartData.Rarity.RARE:
			return Color(0.22, 0.68, 1.0)
		PartData.Rarity.EPIC:
			return Color(0.78, 0.32, 1.0)
		PartData.Rarity.LEGENDARY:
			return Color(1.0, 0.74, 0.14)
	return Color.WHITE

static func get_rarity_translation_key(rarity: PartData.Rarity) -> StringName:
	match rarity:
		PartData.Rarity.COMMON:
			return &"RARITY_COMMON"
		PartData.Rarity.RARE:
			return &"RARITY_RARE"
		PartData.Rarity.EPIC:
			return &"RARITY_EPIC"
		PartData.Rarity.LEGENDARY:
			return &"RARITY_LEGENDARY"
	return &"RARITY_COMMON"

static func get_slot_name_translation_key(slot: PartData.Slot) -> StringName:
	match slot:
		PartData.Slot.HEAD:
			return &"SLOT_NAME_HEAD"
		PartData.Slot.ARMS:
			return &"SLOT_NAME_ARMS"
		PartData.Slot.LEGS:
			return &"SLOT_NAME_LEGS"
		PartData.Slot.CORE:
			return &"SLOT_NAME_CORE"
	return &"SLOT_NAME_ARMS"

static func get_part_trait_description(part_id: StringName) -> String:
	match part_id:
		&"laser_eye":
			return "Portata +45%, Danno +35% (Raggio Laser)"
		&"visor_head":
			return "Portata +18%, Mira Rapida"
		&"spike_helm":
			return "Danno +22%, Difesa Cresta"
		&"base_head":
			return "Bilanciamento Standard (Testa Base)"
		&"chainsaw_arm":
			return "Danno +32%, Cadenza Taglio x1.2"
		&"giant_fist":
			return "Danno +28%, Contraccolpo Pesante"
		&"mega_claws":
			return "Danno +48%, Lacerazione Rapida"
		&"base_fist":
			return "Bilanciamento Standard (Pugno Base)"
		&"rocket_legs":
			return "Velocità +35%, Fiammata Posteriore"
		&"roller_wheels":
			return "Velocità +28%, Virata Fluida"
		&"spring_legs":
			return "Scatto Elastico +30%"
		&"base_boots":
			return "Bilanciamento Standard (Stivali Base)"
		&"crown_core":
			return "Aura Reale, Status Abominio +40%"
		&"shield_core":
			return "Resistenza Danni, Scudo Assorbente"
		&"magnet_core":
			return "Raggio Attrazione Drop +50%"
		&"base_core":
			return "Bilanciamento Standard (Reattore Base)"
		_:
			return "Pezzo Speciale"

static func compute_slots_mass(slots: Dictionary) -> int:
	_ensure_initialized()
	var total: int = 0
	for slot_key: Variant in slots.keys():
		var pid: StringName = slots[slot_key] as StringName
		var p: PartData = get_part(pid)
		total += p.mass_value
	return total

static func is_abomination_counts(arms_cnt: int, legs_cnt: int, core_cnt: int) -> bool:
	return arms_cnt >= 3 and legs_cnt >= 3 and core_cnt >= 3

static func is_abomination_slots(slots: Dictionary) -> bool:
	_ensure_initialized()
	var required_slots: Array[PartData.Slot] = [
		PartData.Slot.HEAD,
		PartData.Slot.ARMS,
		PartData.Slot.LEGS,
		PartData.Slot.CORE,
	]
	for s: PartData.Slot in required_slots:
		if not slots.has(s):
			return false
		var p: PartData = get_part(slots[s] as StringName)
		if int(p.rarity) < int(PartData.Rarity.RARE):
			return false
	return true

static func pick_random_part(rng: RandomNumberGenerator, min_rarity: int = PartData.Rarity.RARE, max_rarity: int = PartData.Rarity.LEGENDARY) -> PartData:
	_ensure_initialized()
	var candidates: Array[PartData] = []
	for p_var: Variant in _parts.values():
		var p: PartData = p_var as PartData
		if int(p.rarity) >= min_rarity and int(p.rarity) <= max_rarity:
			candidates.append(p)
	if candidates.is_empty():
		return get_part(&"giant_fist")
	return candidates[rng.randi_range(0, candidates.size() - 1)]
