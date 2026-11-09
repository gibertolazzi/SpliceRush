class_name PartData
extends Resource

enum Slot {
	HEAD = 0,
	ARMS = 1,
	LEGS = 2,
	CORE = 3,
}

enum Rarity {
	COMMON = 0,
	RARE = 1,
	EPIC = 2,
	LEGENDARY = 3,
}

@export var part_id: StringName = &"base_fist"
@export var translation_key: StringName = &"PART_BASE_FIST"
@export var slot: Slot = Slot.ARMS
@export var rarity: Rarity = Rarity.COMMON
@export var effect_id: StringName = &"melee_punch"
@export var cosmetic_id: StringName = &"default_fist"
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var range_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0
@export var mass_value: int = 10
@export var primary_color: Color = Color(0.95, 0.88, 0.82)
@export var accent_color: Color = Color(1.0, 0.55, 0.0)
