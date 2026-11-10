class_name BalanceConfig
extends Resource

@export_group("Match & Server")
@export var match_duration_sec: float = 90.0
@export var frenzy_start_sec: float = 60.0
@export var frenzy_collapse_interval_sec: float = 7.5
@export var power_part_interval_sec: float = 25.0
@export var respawn_delay_sec: float = 3.0
@export var result_screen_duration_sec: float = 5.0
@export var max_combatants: int = 12
@export var server_tick_hz: int = 30
@export var clip_log_window_sec: float = 15.0

@export_group("Arena Grid")
@export var grid_width: int = 32
@export var grid_depth: int = 40
@export var tile_size: float = 1.5
@export var destructible_block_hp: int = 45
@export var hazard_damage_per_sec: float = 15.0
@export var hazard_knockback: float = 7.0

@export_group("Combatant Movement")
@export var base_move_speed: float = 7.2
@export var acceleration: float = 42.0
@export var friction: float = 34.0
@export var collision_radius: float = 0.58
@export var dash_impulse: float = 14.0
@export var dash_cooldown_sec: float = 2.8

@export_group("Combat & Auto-Attack")
@export var max_hp: int = 100
@export var auto_attack_range: float = 2.85
@export var auto_attack_cooldown_sec: float = 0.55
@export var auto_attack_damage: int = 18
@export var auto_attack_knockback: float = 5.5
@export var attack_arc_dot_threshold: float = -1.0 # -1.0 = full 360 omni auto-target on closest

@export_group("Parts & Abomination")
@export var part_pickup_radius: float = 1.35
@export var magnet_pickup_multiplier: float = 1.75
@export var part_drop_pop_speed: float = 4.6
@export var part_pickup_grace_sec: float = 0.18
@export var part_pickup_heal: int = 18
@export var abomination_scale_multiplier: float = 1.50
@export var abomination_drop_count: int = 3
@export var kill_mass_bonus: int = 15

@export_group("Input & Camera")
@export var joystick_deadzone: float = 0.16
@export var joystick_max_radius_px: float = 68.0
@export var camera_pitch_deg: float = -46.0
@export var camera_fov_deg: float = 58.0
@export var camera_distance: float = 8.6
@export var camera_z_bias: float = 3.0
@export var camera_smooth_rate: float = 9.0
