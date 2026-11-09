class_name InputRemapper
extends RefCounted

static func apply_radial_deadzone(stick: Vector2, deadzone: float = 0.16, curve: float = 1.0) -> Vector2:
	if not (deadzone >= 0.0 and deadzone < 1.0 and curve > 0.0):
		push_error("apply_radial_deadzone requires 0 <= deadzone < 1 and curve > 0.")
		return Vector2.ZERO
	var mag: float = stick.length()
	if mag <= deadzone:
		return Vector2.ZERO
	var scaled: float = minf((mag - deadzone) / (1.0 - deadzone), 1.0)
	return (stick / mag) * pow(scaled, curve)

static func rebind_action(action: StringName, captured: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	var event: InputEvent = _normalize_binding_event(captured)
	for other_var: Variant in InputMap.get_actions():
		var other := StringName(other_var)
		if other != action and not String(other).begins_with("ui_") and InputMap.action_has_event(other, event):
			return false
	for old_event: InputEvent in InputMap.action_get_events(action):
		if old_event.get_class() == event.get_class():
			InputMap.action_erase_event(action, old_event)
	InputMap.action_add_event(action, event)
	return true

static func _normalize_binding_event(e: InputEvent) -> InputEvent:
	if e is InputEventKey:
		var k := InputEventKey.new()
		var src_k: InputEventKey = e as InputEventKey
		k.physical_keycode = src_k.physical_keycode if src_k.physical_keycode != KEY_NONE else src_k.keycode
		return k
	var copy: InputEvent = e.duplicate() as InputEvent
	copy.device = -1
	if copy is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = copy as InputEventJoypadMotion
		jm.axis_value = signf(jm.axis_value)
	return copy
