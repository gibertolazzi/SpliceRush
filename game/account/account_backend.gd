class_name AccountBackend
extends RefCounted
## What AccountService needs from an online account backend. The base class is the
## "nothing wired yet" backend: it is not configured, so the client keeps playing as a guest.
##
## A Firebase backend would subclass this: anonymous sign-in for the guest, then link the
## Google or Apple credential to that same user so progress follows the player
## (see docs/decisions/0002-economia-e-account.md for the plan and what still needs checking).

## Emitted when a link started with start_link() ends.
## result: { "ok": bool, "provider": String, "display": String, "reason": String }
signal link_finished(result: Dictionary)

func is_configured() -> bool:
	return false

## provider_id is "google" or "apple".
func supports(_provider_id: String) -> bool:
	return false

## Starts linking the guest to the provider. Must end with exactly one link_finished.
func start_link(provider_id: String, _guest_id: String) -> void:
	link_finished.emit({ "ok": false, "provider": provider_id, "display": "", "reason": "not_configured" })

func unlink(_provider_id: String) -> void:
	pass
