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

@export_group("Limbs & Clubs")
## HP ratios at which a hit pops a limb off the victim (one limb per threshold crossed).
@export var limb_break_hp_ratios: PackedFloat32Array = PackedFloat32Array([0.66, 0.33])
@export var limb_club_arm_damage_mult: float = 1.2
@export var limb_club_arm_range_mult: float = 1.30
@export var limb_club_arm_knockback_mult: float = 2.2
@export var limb_club_arm_hits: int = 6
@export var limb_club_leg_damage_mult: float = 1.4
@export var limb_club_leg_range_mult: float = 1.45
@export var limb_club_leg_knockback_mult: float = 2.8
@export var limb_club_leg_cooldown_mult: float = 1.12
@export var limb_club_leg_hits: int = 5
## Chance that a club hit knocks an extra limb off the target.
@export var limb_club_sever_chance: float = 0.15
## Seconds before a fighter can pick its own freshly lost limb back up.
@export var limb_owner_pickup_lock_sec: float = 2.5
@export var limb_drop_lifetime_sec: float = 14.0
@export var max_limb_drops: int = 16
## Limbs that burst out of a fighter on KO (on top of special parts).
@export var ko_limb_burst_count: int = 2
@export var limb_pop_speed: float = 6.2

@export_group("Match Rewards")
## Season Pass XP and coins paid at the end of a match (see shared/match_rewards.gd).
@export var reward_xp_match: int = 60
@export var reward_xp_per_kill: int = 12
@export var reward_xp_per_stolen_part: int = 8
@export var reward_xp_abomination: int = 60
@export var reward_xp_podium: int = 80
@export var reward_xp_win: int = 150
@export var reward_coins_match: int = 5
@export var reward_coins_per_kill: int = 2
@export var reward_coins_podium: int = 10
@export var reward_coins_win: int = 25

@export_group("Input & Camera")
@export var joystick_deadzone: float = 0.16
@export var joystick_max_radius_px: float = 68.0
@export var camera_pitch_deg: float = -50.0
@export var camera_fov_deg: float = 52.0
@export var camera_distance: float = 8.6
@export var camera_z_bias: float = 5.8
@export var camera_smooth_rate: float = 9.0
@export var camera_rotation_enabled: bool = true
@export var camera_rotation_smooth_rate: float = 5.0
@export var camera_look_ahead_dist: float = 1.4
