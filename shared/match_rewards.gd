class_name MatchRewards
extends RefCounted
## What one finished match pays out in Season Pass XP and coins. Pure function of the match
## result, shared so the server or a backend can compute the same payout.

## Returns { "xp": int, "coins": int, "lines": Array[Dictionary] } where each line is
## { "key": translation key, "count": int, "xp": int, "coins": int } for the result screen.
static func compute(balance: BalanceConfig, rank: int, kills: int, stolen_parts: int, became_abomination: bool) -> Dictionary:
	var lines: Array[Dictionary] = []
	lines.append({ "key": &"REWARD_LINE_MATCH", "count": 1, "xp": balance.reward_xp_match, "coins": balance.reward_coins_match })
	if kills > 0:
		lines.append({ "key": &"REWARD_LINE_KILLS", "count": kills, "xp": kills * balance.reward_xp_per_kill, "coins": kills * balance.reward_coins_per_kill })
	if stolen_parts > 0:
		lines.append({ "key": &"REWARD_LINE_STOLEN", "count": stolen_parts, "xp": stolen_parts * balance.reward_xp_per_stolen_part, "coins": 0 })
	if became_abomination:
		lines.append({ "key": &"REWARD_LINE_ABOMINATION", "count": 1, "xp": balance.reward_xp_abomination, "coins": 0 })
	if rank == 1:
		lines.append({ "key": &"REWARD_LINE_WIN", "count": 1, "xp": balance.reward_xp_win, "coins": balance.reward_coins_win })
	elif rank <= 3:
		lines.append({ "key": &"REWARD_LINE_PODIUM", "count": 1, "xp": balance.reward_xp_podium, "coins": balance.reward_coins_podium })
	var xp: int = 0
	var coins: int = 0
	for line: Dictionary in lines:
		xp += int(line["xp"])
		coins += int(line["coins"])
	return { "xp": xp, "coins": coins, "lines": lines }
