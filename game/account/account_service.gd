class_name AccountService
extends RefCounted
## Links the local guest profile to a Google or Apple account through an AccountBackend.
## Playing never needs an account: linking only protects progress and moves it between devices.
##
## Until a real backend is plugged in, link() answers "not_configured" and nothing changes.

signal account_changed()
## result: { "ok": bool, "provider": String, "display": String, "reason": String }
signal link_result(result: Dictionary)

const PROVIDER_GOOGLE: String = "google"
const PROVIDER_APPLE: String = "apple"
const PROVIDERS: Array[String] = [PROVIDER_GOOGLE, PROVIDER_APPLE]

var social: SocialManager = null
var backend: AccountBackend = null:
	set(value):
		if backend != null and backend.link_finished.is_connected(_on_link_finished):
			backend.link_finished.disconnect(_on_link_finished)
		backend = value
		if backend != null:
			backend.link_finished.connect(_on_link_finished)
var _pending: String = ""

func _init(p_social: SocialManager = null) -> void:
	social = p_social
	backend = AccountBackend.new()

func get_guest_id() -> String:
	return social.ensure_guest_id() if social != null else ""

func is_linked() -> bool:
	return social != null and social.linked_provider != ""

func get_linked_provider() -> String:
	return social.linked_provider if social != null else ""

func is_backend_ready() -> bool:
	return backend != null and backend.is_configured()

func can_link(provider_id: String) -> bool:
	return PROVIDERS.has(provider_id) and is_backend_ready() and backend.supports(provider_id)

func is_pending() -> bool:
	return _pending != ""

## Starts linking. Returns { "ok": bool, "reason": "pending" | "not_configured" | "busy" | "linked" | "unknown_provider" }.
func link(provider_id: String) -> Dictionary:
	if not PROVIDERS.has(provider_id):
		return { "ok": false, "reason": "unknown_provider" }
	if is_linked():
		return { "ok": false, "reason": "linked" }
	if _pending != "":
		return { "ok": false, "reason": "busy" }
	if not can_link(provider_id):
		return { "ok": false, "reason": "not_configured" }
	_pending = provider_id
	backend.start_link(provider_id, get_guest_id())
	return { "ok": true, "reason": "pending" }

func unlink() -> void:
	if not is_linked():
		return
	if backend != null:
		backend.unlink(social.linked_provider)
	social.set_linked_account("", "")
	account_changed.emit()

func _on_link_finished(result: Dictionary) -> void:
	var provider: String = str(result.get("provider", _pending))
	_pending = ""
	if bool(result.get("ok", false)) and social != null and PROVIDERS.has(provider):
		social.set_linked_account(provider, str(result.get("display", "")))
		account_changed.emit()
	link_result.emit(result)
