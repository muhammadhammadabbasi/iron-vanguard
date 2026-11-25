extends Node
## Global settings, progress, input map, graphics quality. Autoloaded as "Game".

const DIFF_NAMES := ["RECRUIT", "REGULAR", "VETERAN"]
const DMG_MULT := [0.55, 1.0, 1.5]
const ACC_MULT := [0.7, 1.0, 1.3]
const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH"]
const SETTINGS_PATH := "user://settings.cfg"

const MISSIONS := [
	{"id": 1, "name": "BLACKOUT", "script": "res://scripts/missions/m01_blackout.gd",
		"place": "Red Jackal fuel outpost, Karsa Valley", "time": "0540 HRS",
		"brief": "Parachute from a C-130 at dawn over Karsa Valley. Infiltrate the Red Jackal fuel outpost, destroy its radio mast so they cannot call for help, and recover the commander's laptop. Raven will extract you by helicopter."},
	{"id": 2, "name": "SILENT PASS", "script": "res://scripts/missions/m02_silent_pass.gd",
		"place": "Border checkpoint, Karsa Pass", "time": "1310 HRS",
		"brief": "The only road deeper into the valley runs through a Red Jackal checkpoint beside a mountain village. Destroy the checkpoint's radio antenna, take the gate keycard from the commander's house, open the gate and meet Lt. Rauf on the other side."},
	{"id": 3, "name": "THE WATCHERS", "script": "res://scripts/missions/m03_watchers.gd",
		"place": "Hilltop radar station", "time": "1850 HRS",
		"brief": "A radar station on the hill tracks every helicopter in the valley. Shut down its security cameras from the control room, plant C4 on the radar dish and reach the landing zone for extraction."},
]

var difficulty := 1
var sensitivity := 0.3
var fullscreen := true
var quality := 1
var volume := 0.9
var unlocked := 3
var current_mission := 1
var skip_menu := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_load()
	apply_window()
	apply_volume()


func enemy_damage_mult() -> float:
	return DMG_MULT[difficulty]


func enemy_accuracy_mult() -> float:
	return ACC_MULT[difficulty]


func difficulty_name() -> String:
	return DIFF_NAMES[difficulty]


func mission_info(id: int) -> Dictionary:
	for m in MISSIONS:
		if m.id == id:
			return m
	return MISSIONS[0]


func complete_mission(id: int) -> void:
	unlocked = maxi(unlocked, mini(id + 1, MISSIONS.size()))
	save()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


## Applies graphics quality to a viewport + environment + sun.
func apply_quality(vp: Viewport, env: Environment, sun: DirectionalLight3D) -> void:
	match quality:
		0:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.7
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		1:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.85
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if env != null:
		env.ssao_enabled = quality >= 2
		env.ssil_enabled = false
		env.sdfgi_enabled = false
		env.glow_enabled = quality >= 1
		env.volumetric_fog_enabled = false
	if sun != null:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = [60.0, 110.0, 180.0][quality]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality < 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096][quality], true)
	var lod_thresh: float = [4.0, 2.0, 1.0][quality]
	vp.mesh_lod_threshold = lod_thresh


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "sensitivity", sensitivity)
	cf.set_value("game", "fullscreen", fullscreen)
	cf.set_value("game", "quality", quality)
	cf.set_value("game", "volume", volume)
	cf.set_value("progress", "unlocked", unlocked)
	cf.save(SETTINGS_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	difficulty = clampi(int(cf.get_value("game", "difficulty", 1)), 0, 2)
	sensitivity = clampf(float(cf.get_value("game", "sensitivity", 0.3)), 0.05, 1.0)
	fullscreen = bool(cf.get_value("game", "fullscreen", true))
	quality = clampi(int(cf.get_value("game", "quality", 1)), 0, 2)
	volume = clampf(float(cf.get_value("game", "volume", 0.9)), 0.0, 1.0)
	unlocked = clampi(int(cf.get_value("progress", "unlocked", 3)), 3, MISSIONS.size())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		fullscreen = not fullscreen
		apply_window()
		save()


func _setup_inputs() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("crouch", [KEY_C, KEY_CTRL])
	_bind_keys("reload", [KEY_R])
	_bind_keys("interact", [KEY_E, KEY_F])
	_bind_keys("grenade", [KEY_G])
	_bind_keys("medkit", [KEY_H])
	_bind_keys("binoculars", [KEY_B])
	_bind_keys("map", [KEY_M, KEY_TAB])
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_keys("slot1", [KEY_1])
	_bind_keys("slot2", [KEY_2])
	_bind_keys("slot3", [KEY_3])
	_bind_keys("slot4", [KEY_4])
	_bind_keys("slot5", [KEY_5])
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)
	_bind_mouse("next_weapon", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("prev_weapon", MOUSE_BUTTON_WHEEL_UP)


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
