class_name I18nService
extends Node

const TRANSLATIONS: Dictionary = {
	"it": {
		"GAME_TITLE_TOP": "SPLICE",
		"GAME_TITLE_BOTTOM": "RUSH",
		"HUD_STEAL_PARTS": "RUBA\nI PEZZI!",
		"HUD_BECOME_ABOMINATION": "DIVENTA\nL'ABOMINIO!",
		"HUD_ABOMINATION_ACTIVE": "SEI\nL'ABOMINIO!",
		"HUD_ABOMINATION_HUNT": "CACCIATO DA TUTTI!",
		"HUD_FRENZY_BANNER": "FASE FRENZY! L'ARENA CROLLA!",
		"HUD_BOT_BADGE": "BOT",
		"HUD_YOU_BADGE": "TU",
		"HUD_ABILITY_BTN": "SCATTO",
		"HUD_STOLEN_COUNTER": "%d",
		"HUD_TIMER_FORMAT": "%02d:%02d",
		"HUD_PART_STOLEN_TOAST": "RUBATO: %s!",
		"HUD_RESULT_TITLE_WIN": "VITTORIA MOSTRUOSA!",
		"HUD_RESULT_TITLE_RANK": "POSIZIONE #%d / 12",
		"HUD_RESULT_MASS_SCORE": "MASSA FINALE: %d  |  PEZZI RUBATI: %d",
		"HUD_REMATCH_BTN": "RIVINCITA IMMEDIATA!",
		"PART_BASE_HEAD": "Testa Base",
		"PART_VISOR_HEAD": "Visore Cyber",
		"PART_SPIKE_HELM": "Cresta Chiodata",
		"PART_LASER_EYE": "Occhio Laser",
		"PART_BASE_FIST": "Pugno Base",
		"PART_GIANT_FIST": "Pugno Gigante",
		"PART_CHAINSAW_ARM": "Motosega",
		"PART_MEGA_CLAWS": "Artigli Mega",
		"PART_BASE_BOOTS": "Stivali Base",
		"PART_SPRING_LEGS": "Gambe a Molla",
		"PART_ROLLER_WHEELS": "Ruote Turbo",
		"PART_ROCKET_LEGS": "Gamba Razzo",
		"PART_BASE_CORE": "Nucleo Base",
		"PART_SHIELD_CORE": "Nucleo Scudo",
		"PART_MAGNET_CORE": "Nucleo Magnete",
		"PART_CROWN_CORE": "Nucleo Corona",
		"A11Y_SHAKE_ON": "Shake: ON",
		"A11Y_SHAKE_OFF": "Shake: OFF",
		"A11Y_COLORBLIND_ON": "Daltonismo: ON",
		"A11Y_COLORBLIND_OFF": "Daltonismo: OFF",
	},
	"en": {
		"GAME_TITLE_TOP": "SPLICE",
		"GAME_TITLE_BOTTOM": "RUSH",
		"HUD_STEAL_PARTS": "STEAL\nPARTS!",
		"HUD_BECOME_ABOMINATION": "BECOME THE\nABOMINATION!",
		"HUD_ABOMINATION_ACTIVE": "YOU ARE THE\nABOMINATION!",
		"HUD_ABOMINATION_HUNT": "HUNTED BY ALL!",
		"HUD_FRENZY_BANNER": "FRENZY PHASE! ARENA COLLAPSING!",
		"HUD_BOT_BADGE": "BOT",
		"HUD_YOU_BADGE": "YOU",
		"HUD_ABILITY_BTN": "DASH",
		"HUD_STOLEN_COUNTER": "%d",
		"HUD_TIMER_FORMAT": "%02d:%02d",
		"HUD_PART_STOLEN_TOAST": "STOLEN: %s!",
		"HUD_RESULT_TITLE_WIN": "MONSTER VICTORY!",
		"HUD_RESULT_TITLE_RANK": "RANK #%d / 12",
		"HUD_RESULT_MASS_SCORE": "FINAL MASS: %d  |  STOLEN PARTS: %d",
		"HUD_REMATCH_BTN": "INSTANT REMATCH!",
		"PART_BASE_HEAD": "Base Head",
		"PART_VISOR_HEAD": "Cyber Visor",
		"PART_SPIKE_HELM": "Spiked Crest",
		"PART_LASER_EYE": "Laser Eye",
		"PART_BASE_FIST": "Base Fist",
		"PART_GIANT_FIST": "Giant Fist",
		"PART_CHAINSAW_ARM": "Chainsaw Arm",
		"PART_MEGA_CLAWS": "Mega Claws",
		"PART_BASE_BOOTS": "Base Boots",
		"PART_SPRING_LEGS": "Spring Legs",
		"PART_ROLLER_WHEELS": "Turbo Wheels",
		"PART_ROCKET_LEGS": "Rocket Leg",
		"PART_BASE_CORE": "Base Core",
		"PART_SHIELD_CORE": "Shield Core",
		"PART_MAGNET_CORE": "Magnet Core",
		"PART_CROWN_CORE": "Crown Core",
		"A11Y_SHAKE_ON": "Shake: ON",
		"A11Y_SHAKE_OFF": "Shake: OFF",
		"A11Y_COLORBLIND_ON": "Colorblind: ON",
		"A11Y_COLORBLIND_OFF": "Colorblind: OFF",
	}
}

func _init() -> void:
	register_translations()

static func register_translations() -> void:
	for locale_key: String in TRANSLATIONS.keys():
		var tr_res := Translation.new()
		tr_res.locale = locale_key
		var dict: Dictionary = TRANSLATIONS[locale_key]
		for msg_id: String in dict.keys():
			tr_res.add_message(StringName(msg_id), String(dict[msg_id]))
		TranslationServer.add_translation(tr_res)
	TranslationServer.set_locale("it")
