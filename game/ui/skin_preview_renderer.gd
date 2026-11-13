class_name SkinPreviewRenderer
extends Node
## Renders each skin once into a small transparent texture, so the shop, the Season Pass and
## the reward popups can show the real 3D character instead of a placeholder icon.
##
## One off-screen viewport with its own 3D world holds a single fighter. Requested skins are
## rendered one at a time over a few frames and cached. Headless runs (tests) render nothing:
## get_texture() then returns null and callers draw a fallback.

const PREVIEW_SIZE := Vector2i(256, 320)
const SETTLE_FRAMES: int = 3

var _viewport: SubViewport
var _fighter: BlockyFighter3D
var _cache: Dictionary = {} # skin id -> ImageTexture
var _queue: Array[String] = []
var _current: String = ""
var _frames_left: int = 0
var _enabled: bool = true

func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	_viewport = SubViewport.new()
	_viewport.name = "SkinPreviewViewport"
	_viewport.size = PREVIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.78, 0.95)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-35.0, 28.0, 0.0)
	_viewport.add_child(sun)

	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0.0, 1.08, 4.5)
	cam.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
	_viewport.add_child(cam)
	cam.current = true

	_fighter = BlockyFighter3D.new()
	_fighter.name = "PreviewFighter"
	_viewport.add_child(_fighter)

func has_texture(skin_id: String) -> bool:
	return _cache.has(skin_id)

## Returns the cached preview, or null while it is still being rendered (it gets queued).
func get_texture(skin_id: String) -> Texture2D:
	if _cache.has(skin_id):
		return _cache[skin_id] as Texture2D
	if _enabled and skin_id != _current and not _queue.has(skin_id) and EconomyCatalog.has_skin(skin_id):
		_queue.append(skin_id)
	return null

func _process(_delta: float) -> void:
	if not _enabled:
		return
	if _current == "":
		if _queue.is_empty():
			return
		_current = _queue.pop_front()
		_pose_fighter(EconomyCatalog.get_skin(_current))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_frames_left = SETTLE_FRAMES
		return
	_fighter.update_visual_state(Vector2.ZERO, Vector2.ZERO, PI * 0.5 - 0.35, 0.0, 0.0, true, 0.016)
	_frames_left -= 1
	if _frames_left > 0:
		return
	var img: Image = _viewport.get_texture().get_image()
	if img != null and not img.is_empty():
		_cache[_current] = ImageTexture.create_from_image(img)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_current = ""

func _pose_fighter(skin: Dictionary) -> void:
	var base_slots: Dictionary = {
		PartData.Slot.HEAD: &"base_head",
		PartData.Slot.ARMS: &"base_fist",
		PartData.Slot.LEGS: &"base_boots",
		PartData.Slot.CORE: &"base_core",
	}
	_fighter.fighter_id = 0
	_fighter.is_bot = false
	_fighter.current_slots = base_slots
	_fighter.apply_skin(skin)
	if _fighter.player_cursor_ring != null:
		_fighter.player_cursor_ring.visible = false
	for child: Node in _fighter.get_children():
		# Hide the ground shadow disc and rings: the card provides its own backdrop.
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
