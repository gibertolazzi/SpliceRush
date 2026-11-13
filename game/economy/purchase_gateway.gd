class_name PurchaseGateway
extends RefCounted
## Seam for real-money purchases (Splice Plus, coin packs).
##
## No store is connected yet: there is no Apple/Google in-app purchase and no web checkout, and
## receipts must be validated on a server before anything is granted (AGENTS.md rule 1).
## Until that exists this gateway only works as a sandbox in debug builds, so the whole flow can
## be played and tested. In a release export it reports itself unavailable and grants nothing.

var sandbox_enabled: bool = OS.is_debug_build()

func is_available() -> bool:
	return sandbox_enabled

## Returns true when the purchase went through. The sandbox approves instantly and charges nothing.
func purchase(_product_id: String) -> bool:
	return sandbox_enabled
