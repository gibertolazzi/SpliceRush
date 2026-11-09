class_name I18nService
extends Node

const TRANSLATIONS: Dictionary = {
	"it": {
		"GAME_TITLE_TOP": "SPLICE",
		"GAME_TITLE_BOTTOM": "RUSH",
		"HUD_STEAL_PARTS": "RUBA\nI PEZZI!",
		"HUD_BECOME_ABOMINATION": "DIVENTA\nL'ABOMINIO!",
		"HUD_BOT_BADGE": "BOT",
		"HUD_YOU_BADGE": "TU",
		"HUD_ABILITY_BTN": "SCATTO",
		"HUD_STOLEN_COUNTER": "%d",
		"HUD_TIMER_FORMAT": "%02d:%02d",
		"PART_BASE_HEAD": "Testa Base",
		"PART_LASER_EYE": "Occhio Laser",
		"PART_BASE_FIST": "Pugno Gigante",
		"PART_CHAINSAW_ARM": "Motosega",
		"PART_BASE_BOOTS": "Stivali",
		"PART_ROCKET_LEGS": "Gamba Razzo",
		"PART_BASE_CORE": "Nucleo Corona",
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
		"HUD_BOT_BADGE": "BOT",
		"HUD_YOU_BADGE": "YOU",
		"HUD_ABILITY_BTN": "DASH",
		"HUD_STOLEN_COUNTER": "%d",
		"HUD_TIMER_FORMAT": "%02d:%02d",
		"PART_BASE_HEAD": "Base Head",
		"PART_LASER_EYE": "Laser Eye",
		"PART_BASE_FIST": "Giant Fist",
		"PART_CHAINSAW_ARM": "Chainsaw Arm",
		"PART_BASE_BOOTS": "Base Boots",
		"PART_ROCKET_LEGS": "Rocket Leg",
		"PART_BASE_CORE": "Crown Core",
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
