class_name EconomyCatalog
extends RefCounted
## Everything the shop and the Season Pass can hand out: skins, coin packs, daily offers and
## the 40-tier reward track. Pure data and pure functions, so a backend can run the same rules.
##
## Cosmetics and currency only. Nothing in here changes damage, speed, cooldowns or part power.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const DEFAULT_SKIN_ID: String = "pinguino"
const SEASON_TIER_COUNT: int = 40
const SEASON_XP_PER_LEVEL: int = 900
const PRODUCT_SPLICE_PLUS: String = "splice_plus"
const SPLICE_PLUS_PRICE_CENTS: int = 499
## Coins paid back when a reward is a skin or colour the player already owns.
const DUPLICATE_COMPENSATION: Array[int] = [40, 80, 150, 300]
const DAILY_SKIN_DISCOUNT_PCT: int = 30

## A skin is a character model plus an optional two-tone outfit palette.
## "model" is one of: man_cutie, man_officer, woman_cutie, woman_officer.
## price 0 means the skin is not sold for coins (default skin or Season Pass reward).
const SKINS: Array[Dictionary] = [
	{ "id": "pinguino", "name_key": "SKIN_PINGUINO", "model": "man_cutie", "tint": 0.0, "primary": "#FFFFFF", "secondary": "#FFFFFF", "glow": 0.0, "rarity": Rarity.COMMON, "price": 0 },
	{ "id": "sceriffo", "name_key": "SKIN_SCERIFFO", "model": "man_officer", "tint": 0.0, "primary": "#FFFFFF", "secondary": "#FFFFFF", "glow": 0.0, "rarity": Rarity.COMMON, "price": 0 },
	{ "id": "stella", "name_key": "SKIN_STELLA", "model": "woman_cutie", "tint": 0.0, "primary": "#FFFFFF", "secondary": "#FFFFFF", "glow": 0.0, "rarity": Rarity.RARE, "price": 300 },
	{ "id": "agente", "name_key": "SKIN_AGENTE", "model": "woman_officer", "tint": 0.0, "primary": "#FFFFFF", "secondary": "#FFFFFF", "glow": 0.0, "rarity": Rarity.RARE, "price": 0 },
	{ "id": "corallo", "name_key": "SKIN_CORALLO", "model": "man_officer", "tint": 1.0, "primary": "#FF6B5E", "secondary": "#2B3A67", "glow": 0.0, "rarity": Rarity.RARE, "price": 350 },
	{ "id": "menta", "name_key": "SKIN_MENTA", "model": "woman_officer", "tint": 1.0, "primary": "#5EF2C2", "secondary": "#1F4B5C", "glow": 0.0, "rarity": Rarity.RARE, "price": 350 },
	{ "id": "zucchero", "name_key": "SKIN_ZUCCHERO", "model": "woman_cutie", "tint": 1.0, "primary": "#FF9ED1", "secondary": "#FFF4FA", "glow": 0.0, "rarity": Rarity.RARE, "price": 450 },
	{ "id": "tossico", "name_key": "SKIN_TOSSICO", "model": "woman_cutie", "tint": 1.0, "primary": "#59F24D", "secondary": "#402073", "glow": 0.05, "rarity": Rarity.RARE, "price": 0 },
	{ "id": "blacky", "name_key": "SKIN_BLACKY", "model": "man_cutie", "tint": 1.0, "primary": "#1C1C24", "secondary": "#33333F", "glow": 0.0, "rarity": Rarity.EPIC, "price": 600 },
	{ "id": "neon", "name_key": "SKIN_NEON", "model": "man_cutie", "tint": 1.0, "primary": "#FF2E93", "secondary": "#2DE2E6", "glow": 0.18, "rarity": Rarity.EPIC, "price": 0 },
	{ "id": "lava", "name_key": "SKIN_LAVA", "model": "man_officer", "tint": 1.0, "primary": "#FF5A14", "secondary": "#400D0D", "glow": 0.15, "rarity": Rarity.EPIC, "price": 0 },
	{ "id": "ghiaccio", "name_key": "SKIN_GHIACCIO", "model": "woman_officer", "tint": 1.0, "primary": "#B3EBFF", "secondary": "#3373F2", "glow": 0.08, "rarity": Rarity.EPIC, "price": 0 },
	{ "id": "cromo", "name_key": "SKIN_CROMO", "model": "man_officer", "tint": 1.0, "primary": "#D1D6E6", "secondary": "#404557", "glow": 0.05, "rarity": Rarity.EPIC, "price": 800 },
	{ "id": "fantasma", "name_key": "SKIN_FANTASMA", "model": "woman_officer", "tint": 1.0, "primary": "#F4F7FF", "secondary": "#9FB4FF", "glow": 0.20, "rarity": Rarity.EPIC, "price": 0 },
	{ "id": "oro", "name_key": "SKIN_ORO", "model": "man_cutie", "tint": 1.0, "primary": "#FFC726", "secondary": "#8C4D0D", "glow": 0.25, "rarity": Rarity.LEGENDARY, "price": 0 },
]

## Real-money products. Prices are in euro cents; the store itself is not connected yet.
const COIN_PACKS: Array[Dictionary] = [
	{ "id": "coins_100", "coins": 100, "price_cents": 199 },
	{ "id": "coins_300", "coins": 300, "price_cents": 499 },
	{ "id": "coins_700", "coins": 700, "price_cents": 999 },
]

## Free once-a-day gifts.
const FREE_OFFERS: Array[Dictionary] = [
	{ "id": "free_coins", "type": "coins", "amount": 10 },
	{ "id": "free_xp", "type": "xp", "amount": 50 },
]

## Skins and colours placed on the pass track: tier -> reward.
const _FREE_MILESTONES: Dictionary = {
	5: { "type": "skin", "id": "sceriffo" },
	8: { "type": "color", "id": "#40E680" },
	20: { "type": "skin", "id": "agente" },
	30: { "type": "skin", "id": "tossico" },
	40: { "type": "skin", "id": "fantasma" },
}
const _PAID_MILESTONES: Dictionary = {
	1: { "type": "skin", "id": "neon" },
	10: { "type": "skin", "id": "lava" },
	15: { "type": "color", "id": "#FFC726" },
	20: { "type": "skin", "id": "ghiaccio" },
	40: { "type": "skin", "id": "oro" },
}

static func get_skin(skin_id: String) -> Dictionary:
	for s: Dictionary in SKINS:
		if str(s["id"]) == skin_id:
			return s
	return SKINS[0]

static func has_skin(skin_id: String) -> bool:
	for s: Dictionary in SKINS:
		if str(s["id"]) == skin_id:
			return true
	return false

static func get_shop_skins() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in SKINS:
		if int(s["price"]) > 0:
			out.append(s)
	return out

static func get_rarity_color(rarity: int) -> Color:
	match rarity:
		Rarity.RARE:
			return Color(0.22, 0.68, 1.0)
		Rarity.EPIC:
			return Color(0.78, 0.32, 1.0)
		Rarity.LEGENDARY:
			return Color(1.0, 0.74, 0.14)
	return Color(0.68, 0.70, 0.80)

static func get_rarity_key(rarity: int) -> StringName:
	match rarity:
		Rarity.RARE:
			return &"RARITY_RARE"
		Rarity.EPIC:
			return &"RARITY_EPIC"
		Rarity.LEGENDARY:
			return &"RARITY_LEGENDARY"
	return &"RARITY_COMMON"

static func get_coin_pack(pack_id: String) -> Dictionary:
	for p: Dictionary in COIN_PACKS:
		if str(p["id"]) == pack_id:
			return p
	return {}

## The reward on one side of a pass tier. Milestones are skins and colours; the rest is coins,
## growing a little every five tiers so later levels still feel worth reaching.
static func get_tier_reward(tier: int, is_paid: bool) -> Dictionary:
	if tier < 1 or tier > SEASON_TIER_COUNT:
		return {}
	var milestones: Dictionary = _PAID_MILESTONES if is_paid else _FREE_MILESTONES
	if milestones.has(tier):
		return (milestones[tier] as Dictionary).duplicate()
	var step: int = (tier - 1) / 5
	var amount: int = (40 + step * 10) if is_paid else (20 + step * 5)
	if tier % 5 == 0:
		amount *= 3
	return { "type": "coins", "amount": amount }

## The day's shop window: one skin at a discount and two coin packs. The same day index always
## gives the same offers, so the countdown on screen is the real time until they change.
static func get_daily_offers(day_index: int) -> Dictionary:
	var shop_skins: Array[Dictionary] = get_shop_skins()
	var skin: Dictionary = shop_skins[posmod(day_index, shop_skins.size())]
	var full_price: int = int(skin["price"])
	var price: int = int(round(float(full_price) * float(100 - DAILY_SKIN_DISCOUNT_PCT) / 100.0 / 10.0)) * 10
	var first_pack: int = posmod(day_index, COIN_PACKS.size())
	var second_pack: int = posmod(day_index + 1, COIN_PACKS.size())
	return {
		"day": day_index,
		"skin_id": str(skin["id"]),
		"skin_price": price,
		"skin_full_price": full_price,
		"packs": [str(COIN_PACKS[first_pack]["id"]), str(COIN_PACKS[second_pack]["id"])],
	}

static func get_duplicate_compensation(rarity: int) -> int:
	return DUPLICATE_COMPENSATION[clampi(rarity, 0, DUPLICATE_COMPENSATION.size() - 1)]
