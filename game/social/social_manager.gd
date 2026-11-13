class_name SocialManager
extends Node

signal friends_changed()
signal recent_players_changed()
signal lobby_changed()
signal tasks_changed()
signal shop_changed()
signal pass_changed()
signal profile_changed()
signal wallet_changed()
signal inventory_changed()

const SAVE_VERSION: int = 2
const STARTING_COINS: int = 1204
const SECONDS_PER_DAY: int = 86400
const DEFAULT_SAVE_PATH: String = "user://social_save.json"
const MAX_LOBBY_SIZE: int = 4

var save_path: String = DEFAULT_SAVE_PATH
var persistence_enabled: bool = true

var player_username: String = "Pinguino"
var player_tag: String = "#SPL1C3P"
var player_trophies: int = 2805
var best_trophies: int = 2940
var wins_survival: int = 42
var matches_played: int = 87
var total_kills: int = 314
var parts_stolen: int = 628
var abomination_count: int = 19

var season_number: int = 1
var season_level: int = 34
var season_xp: int = 435
var season_xp_max: int = 900
var has_premium_pass: bool = false
var claimed_free_tiers: Array[int] = [31, 32]
var claimed_paid_tiers: Array[int] = []
var selected_mode: String = "survival" # "survival" | "frenzy"

# --- Economy: coins, skins and the daily shop. Kept in the local guest save for now. ---
# AGENTS.md wants currency, inventory and purchases owned by a backend; that stack is not chosen
# yet, so this is the single place that would move server-side.
var coins: int = STARTING_COINS
var owned_skins: Array[String] = [EconomyCatalog.DEFAULT_SKIN_ID]
var equipped_skin: String = EconomyCatalog.DEFAULT_SKIN_ID
var shop_day: int = -1
var shop_purchased: Array[String] = []    # daily offers already bought today
var shop_free_claimed: Array[String] = [] # free gifts already taken today
var purchase_gateway: PurchaseGateway = PurchaseGateway.new()
## Injectable clock for tests: returns local time as unix seconds.
var now_provider: Callable = Callable()
## XP and coins from the last finished match, for the result screen and the pass animation.
var last_match_summary: Dictionary = {}

var friends: Array[Dictionary] = []
var recent_players: Array[Dictionary] = []
var lobby_members: Array[Dictionary] = []
var pending_invites: Dictionary = {} # player_id -> remaining_sec

var tasks: Array[Dictionary] = []
var unlocked_colors: Array[Color] = [Color.WHITE, Color(0.42, 0.31, 0.96), Color(0.95, 0.28, 0.28)]

const DIRECTORY_PLAYERS: Array[Dictionary] = [
	{ "id": "u_kira", "username": "KiraVortex", "trophies": 3120, "status": "online", "is_bot": false, "color_hex": "#6B4EFF" },
	{ "id": "u_leo", "username": "LeoPixel", "trophies": 2640, "status": "online", "is_bot": false, "color_hex": "#2EE67A" },
	{ "id": "u_zack", "username": "ZackBolt", "trophies": 2910, "status": "online", "is_bot": false, "color_hex": "#FF4747" },
	{ "id": "u_mina", "username": "MinaSpark", "trophies": 2450, "status": "in_match", "is_bot": false, "color_hex": "#FF2E93" },
	{ "id": "u_niko", "username": "NikoTurbo", "trophies": 1980, "status": "online", "is_bot": false, "color_hex": "#FFB020" },
	{ "id": "u_vex", "username": "VexNova", "trophies": 3405, "status": "online", "is_bot": false, "color_hex": "#2DE2E6" },
	{ "id": "u_rex", "username": "RexBlock", "trophies": 2215, "status": "offline", "is_bot": false, "color_hex": "#8B5CF6" },
	{ "id": "u_sora", "username": "SoraDash", "trophies": 2770, "status": "online", "is_bot": false, "color_hex": "#F59E0B" },
]

func _init(custom_save_path: String = "") -> void:
	if custom_save_path != "":
		save_path = custom_save_path
	_init_defaults()

func _ready() -> void:
	if persistence_enabled:
		load_state()

func _process(delta: float) -> void:
	tick_invites(delta)

func _init_defaults() -> void:
	friends = [
		DIRECTORY_PLAYERS[0].duplicate(true),
		DIRECTORY_PLAYERS[1].duplicate(true),
	]
	recent_players = [
		_make_recent_entry(DIRECTORY_PLAYERS[2], 120),
		_make_recent_entry(DIRECTORY_PLAYERS[3], 360),
	]
	lobby_members = [_make_host_member()]
	pending_invites.clear()
	tasks = [
		{ "id": "t_play_1", "title_it": "Gioca 1 partita", "title_en": "Play 1 match", "progress": 0, "target": 1, "xp": 150, "claimed": false },
		{ "id": "t_steal_3", "title_it": "Ruba 3 pezzi", "title_en": "Steal 3 parts", "progress": 1, "target": 3, "xp": 250, "claimed": false },
		{ "id": "t_abom_1", "title_it": "Diventa Abominio", "title_en": "Become Abomination", "progress": 1, "target": 1, "xp": 300, "claimed": false },
	]

func _make_host_member() -> Dictionary:
	return {
		"id": "local_player",
		"username": player_username,
		"trophies": player_trophies,
		"is_host": true,
		"ready": true,
		"is_bot": false,
		"color_hex": "#FFFFFF",
	}

func _make_recent_entry(base: Dictionary, age_sec: int) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	d["recent"] = true
	d["last_played_age_sec"] = age_sec
	return d

func tick_invites(delta: float) -> void:
	if pending_invites.is_empty():
		return
	var to_accept: Array[String] = []
	for pid: String in pending_invites.keys():
		var rem: float = float(pending_invites[pid]) - delta
		if rem <= 0.0:
			to_accept.append(pid)
		else:
			pending_invites[pid] = rem
	for pid: String in to_accept:
		accept_invite(pid)

func find_player_by_id(player_id: String) -> Dictionary:
	for f: Dictionary in friends:
		if str(f.get("id", "")) == player_id:
			return f
	for r: Dictionary in recent_players:
		if str(r.get("id", "")) == player_id:
			return r
	for d: Dictionary in DIRECTORY_PLAYERS:
		if str(d.get("id", "")) == player_id:
			return d
	return {}

func search_players(query: String) -> Array[Dictionary]:
	var q: String = query.strip_edges().to_lower()
	var seen: Dictionary = {}
	var exact_prefix: Array[Dictionary] = []
	var contains_matches: Array[Dictionary] = []

	var pool: Array[Dictionary] = []
	pool.append_array(friends)
	pool.append_array(recent_players)
	for d: Dictionary in DIRECTORY_PLAYERS:
		pool.append(d)

	for p: Dictionary in pool:
		var pid: String = str(p.get("id", ""))
		if pid == "" or seen.has(pid):
			continue
		var uname: String = str(p.get("username", ""))
		var ulow: String = uname.to_lower()
		if q != "" and not ulow.contains(q):
			continue
		seen[pid] = true
		var entry: Dictionary = p.duplicate(true)
		entry["is_friend"] = is_friend(pid)
		entry["is_recent"] = is_recent(pid)
		if q != "" and ulow.begins_with(q):
			exact_prefix.append(entry)
		else:
			contains_matches.append(entry)

	exact_prefix.append_array(contains_matches)
	return exact_prefix

func is_friend(player_id: String) -> bool:
	for f: Dictionary in friends:
		if str(f.get("id", "")) == player_id:
			return true
	return false

func is_recent(player_id: String) -> bool:
	for r: Dictionary in recent_players:
		if str(r.get("id", "")) == player_id:
			return true
	return false

func add_friend(player_id: String) -> bool:
	if is_friend(player_id):
		return false
	var p: Dictionary = find_player_by_id(player_id)
	if p.is_empty():
		return false
	friends.append(p.duplicate(true))
	friends_changed.emit()
	save_state()
	return true

func remove_friend(player_id: String) -> bool:
	for i: int in range(friends.size()):
		if str(friends[i].get("id", "")) == player_id:
			friends.remove_at(i)
			friends_changed.emit()
			save_state()
			return true
	return false

func record_match_opponents(combatants: Array) -> void:
	var added: int = 0
	for c: Variant in combatants:
		if c == null:
			continue
		var cid: int = int(c.get("id"))
		if cid == 0:
			continue
		var is_bot_flag: bool = bool(c.get("is_bot"))
		var cname: String = str(c.get("display_name")) if c.get("display_name") != null else ("Bot_%d" % cid)
		if cname == "":
			cname = "Bot_%d" % cid
		var pid: String = "match_%s" % cname.to_lower().replace(" ", "_")
		var col: Color = c.get("base_color") if c.get("base_color") is Color else Color(0.5, 0.4, 0.9)
		var entry := {
			"id": pid,
			"username": cname,
			"trophies": 1800 + (cid * 95) % 1200,
			"status": "online",
			"is_bot": is_bot_flag,
			"recent": true,
			"last_played_age_sec": 0,
			"color_hex": "#" + col.to_html(false),
		}
		# Deduplicate & prepend most recent
		for idx: int in range(recent_players.size() - 1, -1, -1):
			if str(recent_players[idx].get("id", "")) == pid:
				recent_players.remove_at(idx)
		recent_players.insert(0, entry)
		added += 1
		if added >= 6:
			break
	if recent_players.size() > 12:
		recent_players.resize(12)
	if added > 0:
		recent_players_changed.emit()
		save_state()

func get_lobby_status_for(player_id: String) -> String:
	for m: Dictionary in lobby_members:
		if str(m.get("id", "")) == player_id:
			return "in_lobby"
	if pending_invites.has(player_id):
		return "invited"
	return "none"

func invite_to_lobby(player_id: String, auto_accept_delay: float = 0.85) -> bool:
	if lobby_members.size() + pending_invites.size() >= MAX_LOBBY_SIZE:
		return false
	if get_lobby_status_for(player_id) != "none":
		return false
	var p: Dictionary = find_player_by_id(player_id)
	if p.is_empty():
		return false
	pending_invites[player_id] = maxf(0.05, auto_accept_delay)
	lobby_changed.emit()
	return true

func accept_invite(player_id: String) -> bool:
	if not pending_invites.has(player_id):
		return false
	pending_invites.erase(player_id)
	if lobby_members.size() >= MAX_LOBBY_SIZE:
		lobby_changed.emit()
		return false
	var p: Dictionary = find_player_by_id(player_id)
	if p.is_empty():
		lobby_changed.emit()
		return false
	var member := {
		"id": player_id,
		"username": str(p.get("username", "Amico")),
		"trophies": int(p.get("trophies", 2000)),
		"is_host": false,
		"ready": true,
		"is_bot": bool(p.get("is_bot", false)),
		"color_hex": str(p.get("color_hex", "#6B4EFF")),
	}
	lobby_members.append(member)
	lobby_changed.emit()
	return true

func leave_or_kick_lobby(player_id: String) -> bool:
	if player_id == "local_player":
		var had_others: bool = lobby_members.size() > 1 or not pending_invites.is_empty()
		lobby_members = [_make_host_member()]
		pending_invites.clear()
		if had_others:
			lobby_changed.emit()
		return had_others
	if pending_invites.has(player_id):
		pending_invites.erase(player_id)
		lobby_changed.emit()
		return true
	for i: int in range(lobby_members.size()):
		if str(lobby_members[i].get("id", "")) == player_id:
			lobby_members.remove_at(i)
			lobby_changed.emit()
			return true
	return false

func get_claimable_task_count() -> int:
	var count: int = 0
	for t: Dictionary in tasks:
		if not bool(t.get("claimed", false)) and int(t.get("progress", 0)) >= int(t.get("target", 1)):
			count += 1
	return count + get_claimable_pass_count()

func get_claimable_pass_count() -> int:
	var count: int = 0
	for tier_n: int in range(1, mini(season_level, EconomyCatalog.SEASON_TIER_COUNT) + 1):
		if can_claim_pass_tier(tier_n, false):
			count += 1
		if can_claim_pass_tier(tier_n, true):
			count += 1
	return count

## Lowest tier with something to claim on either track, or 0 when there is nothing.
func get_first_claimable_tier() -> int:
	for tier_n: int in range(1, mini(season_level, EconomyCatalog.SEASON_TIER_COUNT) + 1):
		if can_claim_pass_tier(tier_n, false) or can_claim_pass_tier(tier_n, true):
			return tier_n
	return 0

func can_claim_pass_tier(tier_num: int, is_paid: bool) -> bool:
	if tier_num < 1 or tier_num > EconomyCatalog.SEASON_TIER_COUNT:
		return false
	if tier_num > season_level:
		return false
	if is_paid:
		return has_premium_pass and not claimed_paid_tiers.has(tier_num)
	return not claimed_free_tiers.has(tier_num)

func is_pass_tier_claimed(tier_num: int, is_paid: bool) -> bool:
	return claimed_paid_tiers.has(tier_num) if is_paid else claimed_free_tiers.has(tier_num)

func claim_pass_tier(tier_num: int, is_paid: bool) -> bool:
	return not claim_pass_tier_reward(tier_num, is_paid).is_empty()

## Claims one side of a tier and hands out its reward. Returns what was granted (see
## grant_reward), or an empty dictionary when the tier cannot be claimed.
func claim_pass_tier_reward(tier_num: int, is_paid: bool) -> Dictionary:
	if not can_claim_pass_tier(tier_num, is_paid):
		return {}
	if is_paid:
		claimed_paid_tiers.append(tier_num)
	else:
		claimed_free_tiers.append(tier_num)
	var granted: Dictionary = grant_reward(EconomyCatalog.get_tier_reward(tier_num, is_paid), false)
	granted["tier"] = tier_num
	granted["paid"] = is_paid
	pass_changed.emit()
	tasks_changed.emit()
	save_state()
	return granted

## Claims everything available, lowest tier first. Returns one grant per claimed reward.
func claim_all_pass_tiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tier_n: int in range(1, mini(season_level, EconomyCatalog.SEASON_TIER_COUNT) + 1):
		for paid: bool in [false, true]:
			var granted: Dictionary = claim_pass_tier_reward(tier_n, paid)
			if not granted.is_empty():
				out.append(granted)
	return out

# ---------------------------------------------------------------------------
# Wallet and inventory
# ---------------------------------------------------------------------------

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	wallet_changed.emit()

func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	wallet_changed.emit()
	return true

func owns_skin(skin_id: String) -> bool:
	return owned_skins.has(skin_id)

func unlock_skin(skin_id: String) -> bool:
	if owns_skin(skin_id) or not EconomyCatalog.has_skin(skin_id):
		return false
	owned_skins.append(skin_id)
	inventory_changed.emit()
	return true

func equip_skin(skin_id: String) -> bool:
	if not owns_skin(skin_id) or equipped_skin == skin_id:
		return false
	equipped_skin = skin_id
	inventory_changed.emit()
	save_state()
	return true

## Adds Season Pass XP and levels up. The last tier is a hard cap: XP stops there.
func add_season_xp(xp: int) -> Dictionary:
	var before_level: int = season_level
	var before_xp: int = season_xp
	if xp > 0:
		season_xp += xp
		while season_xp >= season_xp_max and season_level < EconomyCatalog.SEASON_TIER_COUNT:
			season_xp -= season_xp_max
			season_level += 1
		if season_level >= EconomyCatalog.SEASON_TIER_COUNT:
			season_xp = mini(season_xp, season_xp_max)
	return {
		"xp": maxi(0, xp),
		"level_before": before_level,
		"xp_before": before_xp,
		"level_after": season_level,
		"xp_after": season_xp,
		"levels_gained": season_level - before_level,
	}

## Hands out one reward: { "type": "coins" | "xp" | "skin" | "color", "amount", "id" }.
## A skin or colour the player already owns turns into coins, so no reward is ever wasted.
## Returns the reward plus "duplicate" and, for duplicates, "compensation".
func grant_reward(reward: Dictionary, persist: bool = true) -> Dictionary:
	var out: Dictionary = reward.duplicate()
	out["duplicate"] = false
	match str(reward.get("type", "")):
		"coins":
			add_coins(int(reward.get("amount", 0)))
		"xp":
			out["progress"] = add_season_xp(int(reward.get("amount", 0)))
			pass_changed.emit()
		"skin":
			var skin_id: String = str(reward.get("id", ""))
			if not unlock_skin(skin_id):
				var comp: int = EconomyCatalog.get_duplicate_compensation(int(EconomyCatalog.get_skin(skin_id)["rarity"]))
				out["duplicate"] = true
				out["compensation"] = comp
				add_coins(comp)
		"color":
			if not unlock_color(Color(str(reward.get("id", "#FFFFFF")))):
				var comp_c: int = EconomyCatalog.get_duplicate_compensation(EconomyCatalog.Rarity.COMMON)
				out["duplicate"] = true
				out["compensation"] = comp_c
				add_coins(comp_c)
		_:
			return {}
	if persist:
		save_state()
	return out

# ---------------------------------------------------------------------------
# Daily shop
# ---------------------------------------------------------------------------

func get_now_local_unix() -> float:
	if now_provider.is_valid():
		return float(now_provider.call())
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_unix_time_from_system() + float(bias_min) * 60.0

func get_day_index() -> int:
	return int(floor(get_now_local_unix() / float(SECONDS_PER_DAY)))

## Real seconds until local midnight, when the daily offers and free gifts change.
func seconds_until_shop_reset() -> int:
	var now: float = get_now_local_unix()
	return maxi(0, int(ceil(float((get_day_index() + 1) * SECONDS_PER_DAY) - now)))

## Rolls the shop over when the day changed. Returns true if it did.
func refresh_shop_day() -> bool:
	var today: int = get_day_index()
	if today == shop_day:
		return false
	shop_day = today
	shop_purchased.clear()
	shop_free_claimed.clear()
	shop_changed.emit()
	save_state()
	return true

func get_daily_offers() -> Dictionary:
	refresh_shop_day()
	return EconomyCatalog.get_daily_offers(shop_day)

## Buys a skin with coins. `daily` uses today's discounted price for the featured skin.
## Returns { "ok": bool, "reason": "" | "owned" | "not_for_sale" | "coins", "price": int }.
func buy_skin(skin_id: String, daily: bool = false) -> Dictionary:
	if not EconomyCatalog.has_skin(skin_id):
		return { "ok": false, "reason": "not_for_sale", "price": 0 }
	var skin: Dictionary = EconomyCatalog.get_skin(skin_id)
	var price: int = int(skin["price"])
	if daily:
		var offers: Dictionary = get_daily_offers()
		if str(offers["skin_id"]) != skin_id:
			return { "ok": false, "reason": "not_for_sale", "price": 0 }
		price = int(offers["skin_price"])
	if owns_skin(skin_id):
		return { "ok": false, "reason": "owned", "price": price }
	if price <= 0:
		return { "ok": false, "reason": "not_for_sale", "price": 0 }
	if not spend_coins(price):
		return { "ok": false, "reason": "coins", "price": price }
	unlock_skin(skin_id)
	if daily:
		shop_purchased.append("skin")
	shop_changed.emit()
	save_state()
	return { "ok": true, "reason": "", "price": price }

func is_free_offer_claimed(offer_id: String) -> bool:
	refresh_shop_day()
	return shop_free_claimed.has(offer_id)

## Takes one of today's free gifts. Returns the granted reward, or empty if already taken.
func claim_free_offer(offer_id: String) -> Dictionary:
	if is_free_offer_claimed(offer_id):
		return {}
	for offer: Dictionary in EconomyCatalog.FREE_OFFERS:
		if str(offer["id"]) == offer_id:
			shop_free_claimed.append(offer_id)
			var granted: Dictionary = grant_reward(offer, false)
			shop_changed.emit()
			save_state()
			return granted
	return {}

## Real-money coin pack through the purchase gateway.
## Returns { "ok": bool, "reason": "" | "unavailable" | "unknown", "coins": int }.
func purchase_coin_pack(pack_id: String) -> Dictionary:
	var pack: Dictionary = EconomyCatalog.get_coin_pack(pack_id)
	if pack.is_empty():
		return { "ok": false, "reason": "unknown", "coins": 0 }
	if purchase_gateway == null or not purchase_gateway.is_available() or not purchase_gateway.purchase(pack_id):
		return { "ok": false, "reason": "unavailable", "coins": 0 }
	add_coins(int(pack["coins"]))
	save_state()
	return { "ok": true, "reason": "", "coins": int(pack["coins"]) }

## Splice Plus (the paid pass track) through the purchase gateway.
func purchase_plus() -> Dictionary:
	if has_premium_pass:
		return { "ok": false, "reason": "owned" }
	if purchase_gateway == null or not purchase_gateway.is_available() or not purchase_gateway.purchase(EconomyCatalog.PRODUCT_SPLICE_PLUS):
		return { "ok": false, "reason": "unavailable" }
	activate_premium_pass()
	return { "ok": true, "reason": "" }

## Pays out a finished match (see MatchRewards.compute) and remembers the before/after pass
## progress so the result screen and the pass can animate it.
func grant_match_rewards(rewards: Dictionary) -> Dictionary:
	var progress: Dictionary = add_season_xp(int(rewards.get("xp", 0)))
	var coins_before: int = coins
	add_coins(int(rewards.get("coins", 0)))
	last_match_summary = progress
	last_match_summary["coins"] = int(rewards.get("coins", 0))
	last_match_summary["coins_before"] = coins_before
	last_match_summary["lines"] = rewards.get("lines", [])
	last_match_summary["claimable"] = get_claimable_pass_count()
	last_match_summary["shown_in_pass"] = false
	pass_changed.emit()
	tasks_changed.emit()
	save_state()
	return last_match_summary

func activate_premium_pass() -> void:
	if has_premium_pass:
		return
	has_premium_pass = true
	pass_changed.emit()
	tasks_changed.emit()
	save_state()

func record_match_result(stolen_count: int, became_abomination: bool, rank: int = 1, kills: int = 0) -> void:
	matches_played += 1
	total_kills += maxi(0, kills)
	parts_stolen += maxi(0, stolen_count)
	if became_abomination:
		abomination_count += 1
	if rank <= 3:
		wins_survival += 1
		player_trophies += 30
	elif rank <= 6:
		player_trophies += 12
	else:
		player_trophies = maxi(0, player_trophies - 5)
	if player_trophies > best_trophies:
		best_trophies = player_trophies

	for t: Dictionary in tasks:
		var tid: String = str(t.get("id", ""))
		var target: int = int(t.get("target", 1))
		if tid == "t_play_1":
			t["progress"] = mini(target, int(t.get("progress", 0)) + 1)
		elif tid == "t_steal_3":
			t["progress"] = mini(target, int(t.get("progress", 0)) + maxi(0, stolen_count))
		elif tid == "t_abom_1" and became_abomination:
			t["progress"] = target
		elif tid == "t_kills_5":
			t["progress"] = mini(target, int(t.get("progress", 0)) + maxi(0, kills))
	profile_changed.emit()
	tasks_changed.emit()
	save_state()

func reroll_task(task_id: String) -> bool:
	for i: int in range(tasks.size()):
		if str(tasks[i].get("id", "")) == task_id and not bool(tasks[i].get("claimed", false)):
			tasks[i] = {
				"id": "t_kills_5",
				"title_it": "Elimina 5 avversari",
				"title_en": "Defeat 5 opponents",
				"progress": 0,
				"target": 5,
				"xp": 350,
				"claimed": false,
			}
			tasks_changed.emit()
			save_state()
			return true
	return false

func claim_task(task_id: String) -> int:
	for t: Dictionary in tasks:
		if str(t.get("id", "")) == task_id:
			if bool(t.get("claimed", false)):
				return 0
			if int(t.get("progress", 0)) < int(t.get("target", 1)):
				return 0
			t["claimed"] = true
			var xp: int = int(t.get("xp", 100))
			add_season_xp(xp)
			pass_changed.emit()
			tasks_changed.emit()
			save_state()
			return xp
	return 0

func is_color_unlocked(col: Color) -> bool:
	for c: Color in unlocked_colors:
		if c.is_equal_approx(col):
			return true
	return false

func unlock_color(col: Color) -> bool:
	if is_color_unlocked(col):
		return false
	unlocked_colors.append(col)
	shop_changed.emit()
	save_state()
	return true

func capture_state() -> Dictionary:
	var col_hexes: Array[String] = []
	for c: Color in unlocked_colors:
		col_hexes.append("#" + c.to_html(false))
	return {
		"version": SAVE_VERSION,
		"player_username": player_username,
		"player_tag": player_tag,
		"player_trophies": player_trophies,
		"best_trophies": best_trophies,
		"wins_survival": wins_survival,
		"matches_played": matches_played,
		"total_kills": total_kills,
		"parts_stolen": parts_stolen,
		"abomination_count": abomination_count,
		"season_number": season_number,
		"season_level": season_level,
		"season_xp": season_xp,
		"has_premium_pass": has_premium_pass,
		"claimed_free_tiers": claimed_free_tiers.duplicate(),
		"claimed_paid_tiers": claimed_paid_tiers.duplicate(),
		"selected_mode": selected_mode,
		"friends": friends.duplicate(true),
		"recent_players": recent_players.duplicate(true),
		"tasks": tasks.duplicate(true),
		"unlocked_colors": col_hexes,
		"coins": coins,
		"owned_skins": owned_skins.duplicate(),
		"equipped_skin": equipped_skin,
		"shop_day": shop_day,
		"shop_purchased": shop_purchased.duplicate(),
		"shop_free_claimed": shop_free_claimed.duplicate(),
	}

## Brings an older save up to the current version, one step at a time.
static func migrate_state(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	var ver: int = int(out.get("version", 0))
	if ver == 1:
		# v1 had no economy: start the wallet and wardrobe, keep all progress.
		out["coins"] = STARTING_COINS
		out["owned_skins"] = [EconomyCatalog.DEFAULT_SKIN_ID]
		out["equipped_skin"] = EconomyCatalog.DEFAULT_SKIN_ID
		out["shop_day"] = -1
		out["shop_purchased"] = []
		out["shop_free_claimed"] = []
		ver = 2
	out["version"] = ver
	return out

func apply_state(raw: Dictionary) -> bool:
	var raw_ver: int = int(raw.get("version", 0))
	if raw_ver <= 0 or raw_ver > SAVE_VERSION:
		return false
	var data: Dictionary = migrate_state(raw)
	player_username = str(data.get("player_username", player_username))
	player_tag = str(data.get("player_tag", player_tag))
	player_trophies = int(data.get("player_trophies", player_trophies))
	best_trophies = int(data.get("best_trophies", best_trophies))
	wins_survival = int(data.get("wins_survival", wins_survival))
	matches_played = int(data.get("matches_played", matches_played))
	total_kills = int(data.get("total_kills", total_kills))
	parts_stolen = int(data.get("parts_stolen", parts_stolen))
	abomination_count = int(data.get("abomination_count", abomination_count))
	season_number = int(data.get("season_number", season_number))
	season_level = int(data.get("season_level", season_level))
	season_xp = int(data.get("season_xp", season_xp))
	has_premium_pass = bool(data.get("has_premium_pass", has_premium_pass))
	if data.get("claimed_free_tiers") is Array:
		claimed_free_tiers.clear()
		for v: Variant in data["claimed_free_tiers"]:
			claimed_free_tiers.append(int(v))
	if data.get("claimed_paid_tiers") is Array:
		claimed_paid_tiers.clear()
		for v: Variant in data["claimed_paid_tiers"]:
			claimed_paid_tiers.append(int(v))
	selected_mode = str(data.get("selected_mode", selected_mode))
	if data.get("friends") is Array:
		friends.clear()
		for f: Variant in data["friends"]:
			if f is Dictionary:
				friends.append((f as Dictionary).duplicate(true))
	if data.get("recent_players") is Array:
		recent_players.clear()
		for r: Variant in data["recent_players"]:
			if r is Dictionary:
				recent_players.append((r as Dictionary).duplicate(true))
	if data.get("tasks") is Array:
		tasks.clear()
		for t: Variant in data["tasks"]:
			if t is Dictionary:
				tasks.append((t as Dictionary).duplicate(true))
	if data.get("unlocked_colors") is Array:
		unlocked_colors.clear()
		for hx: Variant in data["unlocked_colors"]:
			unlocked_colors.append(Color(str(hx)))
	coins = maxi(0, int(data.get("coins", coins)))
	if data.get("owned_skins") is Array:
		owned_skins.clear()
		for sid: Variant in data["owned_skins"]:
			if EconomyCatalog.has_skin(str(sid)) and not owned_skins.has(str(sid)):
				owned_skins.append(str(sid))
	if not owned_skins.has(EconomyCatalog.DEFAULT_SKIN_ID):
		owned_skins.insert(0, EconomyCatalog.DEFAULT_SKIN_ID)
	equipped_skin = str(data.get("equipped_skin", equipped_skin))
	if not owned_skins.has(equipped_skin):
		equipped_skin = EconomyCatalog.DEFAULT_SKIN_ID
	shop_day = int(data.get("shop_day", shop_day))
	shop_purchased.clear()
	if data.get("shop_purchased") is Array:
		for v: Variant in data["shop_purchased"]:
			shop_purchased.append(str(v))
	shop_free_claimed.clear()
	if data.get("shop_free_claimed") is Array:
		for v: Variant in data["shop_free_claimed"]:
			shop_free_claimed.append(str(v))
	season_level = clampi(season_level, 1, EconomyCatalog.SEASON_TIER_COUNT)
	return true

func save_state() -> void:
	if not persistence_enabled or save_path == "":
		return
	var json_str: String = JSON.stringify(capture_state(), "\t")
	var tmp_path: String = save_path + ".tmp"
	var bak_path: String = save_path + ".bak"
	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(json_str)
	f.flush()
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.rename_absolute(save_path, bak_path)
	DirAccess.rename_absolute(tmp_path, save_path)

func load_state() -> bool:
	if not persistence_enabled or save_path == "":
		return false
	for candidate: String in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var txt: String = FileAccess.get_file_as_string(candidate)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary and apply_state(parsed as Dictionary):
			return true
	return false
