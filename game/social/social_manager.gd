class_name SocialManager
extends Node

signal friends_changed()
signal recent_players_changed()
signal lobby_changed()
signal tasks_changed()
signal shop_changed()

const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://social_save.json"
const MAX_LOBBY_SIZE: int = 4

var save_path: String = DEFAULT_SAVE_PATH
var persistence_enabled: bool = true

var player_username: String = "Pinguino"
var player_trophies: int = 2805
var season_number: int = 1
var season_level: int = 34
var season_xp: int = 435
var season_xp_max: int = 900
var selected_mode: String = "survival" # "survival" | "frenzy"

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
	return count

func record_match_result(stolen_count: int, became_abomination: bool) -> void:
	for t: Dictionary in tasks:
		var tid: String = str(t.get("id", ""))
		var target: int = int(t.get("target", 1))
		if tid == "t_play_1":
			t["progress"] = mini(target, int(t.get("progress", 0)) + 1)
		elif tid == "t_steal_3":
			t["progress"] = mini(target, int(t.get("progress", 0)) + maxi(0, stolen_count))
		elif tid == "t_abom_1" and became_abomination:
			t["progress"] = target
	tasks_changed.emit()
	save_state()

func claim_task(task_id: String) -> int:
	for t: Dictionary in tasks:
		if str(t.get("id", "")) == task_id:
			if bool(t.get("claimed", false)):
				return 0
			if int(t.get("progress", 0)) < int(t.get("target", 1)):
				return 0
			t["claimed"] = true
			var xp: int = int(t.get("xp", 100))
			season_xp += xp
			while season_xp >= season_xp_max:
				season_xp -= season_xp_max
				season_level += 1
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
		"player_trophies": player_trophies,
		"season_number": season_number,
		"season_level": season_level,
		"season_xp": season_xp,
		"selected_mode": selected_mode,
		"friends": friends.duplicate(true),
		"recent_players": recent_players.duplicate(true),
		"tasks": tasks.duplicate(true),
		"unlocked_colors": col_hexes,
	}

func apply_state(data: Dictionary) -> bool:
	var ver: int = int(data.get("version", 0))
	if ver <= 0 or ver > SAVE_VERSION:
		return false
	player_username = str(data.get("player_username", player_username))
	player_trophies = int(data.get("player_trophies", player_trophies))
	season_number = int(data.get("season_number", season_number))
	season_level = int(data.get("season_level", season_level))
	season_xp = int(data.get("season_xp", season_xp))
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
