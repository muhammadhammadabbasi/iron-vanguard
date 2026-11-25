extends CharacterBody3D
## First-person player: movement, IGI-style arsenal, medkits, binoculars, parachute and ride modes.

signal died
signal hit_confirmed(killed: bool, headshot: bool)
signal damaged(from_pos: Vector3)
signal weapon_changed(id: String)
signal landed

const Weapons = preload("res://scripts/player/weapons.gd")
const GrenadeScript = preload("res://scripts/world/grenade.gd")

enum Mode { WALK, FREEFALL, CANOPY, RIDE }

const WALK := 4.4
const SPRINT := 7.2
const CROUCH := 2.2
const ADS_MOVE := 2.6
const JUMP_V := 4.6
const GRAVITY := 14.0
const STAND_H := 1.8
const CROUCH_H := 1.15
const EYE_STAND := 1.62
const EYE_CROUCH := 1.0

var mode := Mode.WALK
var hp := 100.0
var max_hp := 100.0
var medkits := 2
var dead := false
var god := false
var controls_enabled := true
var invuln := 0.0
var clock := 0.0
var last_hurt := -10.0

# inventory: weapon id -> {"mag": int, "reserve": int}
var inv := {}
var current := ""
var grenades := 3
var fire_cd := 0.0
var reloading := false
var reload_t := 0.0
var switching := 0.0
var melee_t := 0.0
var ads := 0.0
var sprint_blend := 0.0
var crouching := false
var sprinting := false
var spread := 0.0
var recoil := 0.0
var kick := 0.0
var shake := 0.0
var bob_t := 0.0
var step_dist := 0.0
var grenade_cd := 0.0
var binocs := false
var yaw := 0.0
var pitch := 0.0
var sway := Vector2.ZERO
var noise_level := 0.0   # how loud the player is right now (0..1), read by enemies

var head: Node3D
var cam: Camera3D
var vm: Node3D
var gun_holder: Node3D
var gun_models := {}
var flash_mesh: MeshInstance3D
var flash_light: OmniLight3D
var flash_t := 0.0
var shape: CapsuleShape3D
var col: CollisionShape3D
var chute: Node3D
var chute_speed := 9.0
var ride_target: Node3D = null
var ride_offset := Vector3.ZERO
var wind_player: AudioStreamPlayer

var stats := {"shots": 0, "hits": 0, "headshots": 0, "kills": 0, "stealth_kills": 0}


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = STAND_H
	col = CollisionShape3D.new()
	col.shape = shape
	col.position.y = STAND_H / 2.0
	add_child(col)
	head = Node3D.new()
	head.position.y = EYE_STAND
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.01
	cam.far = 2500.0
	head.add_child(cam)
	cam.current = true
	vm = Node3D.new()
	vm.scale = Vector3.ONE * 0.1   # tiny + close = never clips into walls
	cam.add_child(vm)
	gun_holder = Node3D.new()
	vm.add_child(gun_holder)
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.75, 0.4)
	flash_light.omni_range = 7.0
	flash_light.light_energy = 0.0
	flash_light.position = Vector3(0.05, -0.05, -0.6)
	cam.add_child(flash_light)
	flash_mesh = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.1
	flash_mesh.mesh = fm
	flash_mesh.material_override = Fx.mats["flash"]
	flash_mesh.scale = Vector3(1.2, 1.2, 2.6)
	flash_mesh.visible = false
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun_holder.add_child(flash_mesh)
	wind_player = AudioStreamPlayer.new()
	wind_player.stream = Sfx.streams.get("freefall")
	wind_player.volume_db = -80.0
	add_child(wind_player)


## Give the player a loadout: ["knife", "m9", "m4"] etc.
func give_loadout(ids: Array, start: String) -> void:
	for id in ids:
		give_weapon(id, true)
	equip(start, true)


func give_weapon(id: String, quiet := false) -> bool:
	var d: Dictionary = Weapons.get_def(id)
	if d.is_empty():
		return false
	if inv.has(id):
		if d.get("melee", false):
			return false
		var before: int = inv[id].reserve
		inv[id].reserve = mini(inv[id].reserve + d.mag, d.max_reserve)
		return inv[id].reserve > before
	inv[id] = {"mag": d.get("mag", 0), "reserve": d.get("start_reserve", 0)}
	_build_gun_model(id)
	if not quiet:
		Sfx.play("pickup", -6.0)
	return true


func _build_gun_model(id: String) -> void:
	var d: Dictionary = Weapons.get_def(id)
	var holder := Node3D.new()
	holder.visible = false
	gun_holder.add_child(holder)
	var model: Node3D = Models.make(d.model, false)
	holder.add_child(model)
	# source models have the muzzle along +X: turn it to -Z
	model.rotation = Vector3(0, PI / 2.0, 0) + d.get("vm_rot", Vector3.ZERO)
	model.position = d.get("vm_offset", Vector3.ZERO)
	gun_models[id] = holder


func equip(id: String, instant := false) -> void:
	if not inv.has(id) or id == current:
		return
	reloading = false
	for k in gun_models:
		gun_models[k].visible = false
	current = id
	gun_models[id].visible = true
	switching = 0.0 if instant else 0.45
	ads = 0.0
	weapon_changed.emit(id)
	if not instant:
		Sfx.play("pickup", -12.0, 0.1)


func wdef() -> Dictionary:
	return Weapons.get_def(current)


func _cycle(dirn: int) -> void:
	var owned := []
	for id in Weapons.ORDER:
		if inv.has(id):
			owned.append(id)
	if owned.is_empty():
		return
	var i := owned.find(current)
	equip(owned[(i + dirn + owned.size()) % owned.size()])


func _slot(n: int) -> void:
	var options := []
	for id in Weapons.ORDER:
		if inv.has(id) and Weapons.get_def(id).slot == n:
			options.append(id)
	if options.is_empty():
		return
	var i := options.find(current)
	equip(options[(i + 1) % options.size()])


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if dead or not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var zoom := 1.0
		if binocs:
			zoom = 0.25
		elif ads > 0.5 and wdef().get("scope", false):
			zoom = 0.18
		var s: float = Game.sensitivity * 0.01 * lerpf(1.0, 0.55, ads) * zoom
		yaw -= event.relative.x * s
		pitch = clampf(pitch - event.relative.y * s, -1.45, 1.45)
		sway += Vector2(event.relative.x, event.relative.y) * 0.00012
		sway = sway.limit_length(0.04)
		return
	if mode != Mode.WALK:
		return
	if event.is_action_pressed("crouch"):
		crouching = not crouching
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("grenade"):
		throw_grenade()
	elif event.is_action_pressed("medkit"):
		use_medkit()
	elif event.is_action_pressed("binoculars"):
		binocs = not binocs
		Sfx.play("pickup", -14.0, 0.0)
	elif event.is_action_pressed("next_weapon"):
		_cycle(1)
	elif event.is_action_pressed("prev_weapon"):
		_cycle(-1)
	else:
		for n in range(1, 6):
			if event.is_action_pressed("slot%d" % n):
				_slot(n)


# ---------------------------------------------------------------- physics

func _physics_process(delta: float) -> void:
	clock += delta
	invuln = maxf(invuln - delta, 0.0)
	noise_level = move_toward(noise_level, 0.0, delta * 1.5)
	match mode:
		Mode.FREEFALL:
			_freefall(delta)
			return
		Mode.CANOPY:
			_canopy(delta)
			return
		Mode.RIDE:
			if ride_target != null and is_instance_valid(ride_target):
				global_position = ride_target.global_transform * ride_offset
			velocity = Vector3.ZERO
			return
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var firing := controls_enabled and Input.is_action_pressed("fire")
	var want_ads: bool = controls_enabled and Input.is_action_pressed("aim") and not reloading and not binocs and switching <= 0.0 and not wdef().get("melee", false)
	ads = move_toward(ads, 1.0 if want_ads else 0.0, delta * 7.0)
	sprinting = controls_enabled and Input.is_action_pressed("sprint") and input_dir.y < -0.3 and ads < 0.2 and not firing and not binocs
	if sprinting and crouching:
		crouching = false
	sprint_blend = move_toward(sprint_blend, 1.0 if sprinting else 0.0, delta * 6.0)
	var speed := WALK
	if sprinting:
		speed = SPRINT
	elif crouching:
		speed = CROUCH
	speed = lerpf(speed, minf(speed, ADS_MOVE), ads)
	if binocs:
		speed = minf(speed, 1.5)
	var wish := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y)
	var accel := 11.0 if is_on_floor() else 2.5
	var k := 1.0 - exp(-accel * delta)
	velocity.x = lerpf(velocity.x, wish.x * speed, k)
	velocity.z = lerpf(velocity.z, wish.z * speed, k)
	if is_on_floor():
		if controls_enabled and Input.is_action_just_pressed("jump"):
			if crouching:
				crouching = false
			else:
				velocity.y = JUMP_V
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	rotation.y = yaw
	var target_h := CROUCH_H if crouching else STAND_H
	shape.height = move_toward(shape.height, target_h, delta * 4.0)
	col.position.y = shape.height / 2.0
	head.position.y = move_toward(head.position.y, EYE_CROUCH if crouching else EYE_STAND, delta * 4.0)
	var hs := Vector2(velocity.x, velocity.z).length()
	if sprinting and hs > 4.0:
		noise_level = maxf(noise_level, 0.5)
	elif hs > 2.0 and not crouching:
		noise_level = maxf(noise_level, 0.2)
	_weapon_logic(delta)
	_footsteps(delta)


func _weapon_logic(delta: float) -> void:
	fire_cd -= delta
	grenade_cd -= delta
	melee_t = maxf(melee_t - delta, 0.0)
	spread = move_toward(spread, 0.0, delta * 0.08)
	if switching > 0.0:
		switching -= delta
		return
	if current == "":
		return
	var d := wdef()
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			var st: Dictionary = inv[current]
			var take := mini(d.mag - st.mag, st.reserve)
			st.mag += take
			st.reserve -= take
			reloading = false
	if not controls_enabled or binocs:
		return
	var trigger: bool = Input.is_action_pressed("fire") if d.get("auto", false) else Input.is_action_just_pressed("fire")
	if d.get("melee", false):
		if trigger and fire_cd <= 0.0:
			_melee()
		return
	if trigger and fire_cd <= 0.0 and not reloading and sprint_blend < 0.35:
		if inv[current].mag > 0:
			_fire()
		else:
			Sfx.play("empty_click", -6.0)
			fire_cd = 0.25
			start_reload()


func _fire() -> void:
	var d := wdef()
	inv[current].mag -= 1
	fire_cd = d.rate
	stats.shots += 1
	Sfx.play(d.sound, -3.0 if not d.silenced else -6.0, 0.05)
	var loud := 9.0 if d.silenced else 55.0
	noise_level = 1.0 if not d.silenced else 0.3
	get_tree().call_group("enemy", "hear_noise", global_position, loud, not d.silenced)
	if not d.silenced:
		flash_t = 0.045
		flash_mesh.visible = true
		flash_mesh.rotation.z = randf() * TAU
		flash_light.light_energy = 3.0
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var cone: float = lerpf(d.hip, d.ads_spread, ads) + spread + hspeed * 0.0025 * (1.0 - ads * 0.7)
	if crouching:
		cone *= 0.75
	if not is_on_floor():
		cone += 0.03
	spread = minf(spread + d.recoil * 0.3 * (1.0 - ads * 0.75), 0.035)
	var b := cam.global_transform.basis
	var dir := (-b.z + b.x * randf_range(-cone, cone) + b.y * randf_range(-cone, cone)).normalized()
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 900.0, 1 | 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_process_hit(hit, from, d)
	var k_amt: float = d.recoil * randf_range(0.8, 1.2) * lerpf(1.0, 0.6, ads) * (0.75 if crouching else 1.0)
	pitch = clampf(pitch + k_amt * 0.55, -1.45, 1.45)
	recoil += k_amt * 0.45
	yaw += randf_range(-0.3, 0.35) * k_amt * lerpf(1.0, 0.6, ads)
	kick = 1.0


func _process_hit(hit: Dictionary, from: Vector3, d: Dictionary) -> void:
	var c = hit.collider
	var pos: Vector3 = hit.position
	var n: Vector3 = hit.normal
	if c != null and c.is_in_group("enemy") and c.has_method("take_damage"):
		var headshot: bool = pos.y - c.global_position.y > 1.5
		var dmg: float = d.head if headshot else d.damage
		if from.distance_to(pos) > 60.0 and not d.get("scope", false):
			dmg *= 0.8
		var killed: bool = c.take_damage(dmg, global_position, headshot, "bullet")
		stats.hits += 1
		if killed:
			stats.kills += 1
			if headshot:
				stats.headshots += 1
		hit_confirmed.emit(killed, headshot)
		Fx.impact(pos, n, true)
		Sfx.play("kill_confirm" if killed else "hitmarker", -10.0, 0.0)
	elif c != null and c.has_method("take_damage"):
		c.take_damage(d.damage, global_position, false, "bullet")
		Fx.impact(pos, n, false)
	else:
		Fx.impact(pos, n, false)
		Fx.bullet_hole(pos, n)


func _melee() -> void:
	var d := wdef()
	fire_cd = d.rate
	melee_t = 0.35
	Sfx.play("knife_swing", -6.0)
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * d.range, 1 | 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		# forgiving sweep for enemies just off-centre
		for e in get_tree().get_nodes_in_group("enemy"):
			var to: Vector3 = (e.global_position + Vector3.UP * 1.2) - from
			if to.length() < d.range + 0.3 and fwd.dot(to.normalized()) > 0.75:
				hit = {"collider": e, "position": e.global_position + Vector3.UP * 1.2, "normal": -fwd}
				break
	if hit.is_empty():
		return
	var c = hit.collider
	if c != null and c.is_in_group("enemy"):
		var silent: bool = c.has_method("is_unaware") and c.is_unaware()
		var killed: bool = c.take_damage(999.0 if silent else 65.0, global_position, false, "knife")
		Sfx.play("knife_hit", -4.0)
		Fx.impact(hit.position, hit.normal, true)
		hit_confirmed.emit(killed, false)
		if killed:
			stats.kills += 1
			if silent:
				stats.stealth_kills += 1
	elif c != null and c.has_method("take_damage"):
		c.take_damage(30.0, global_position, false, "knife")


func _footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	step_dist += Vector2(velocity.x, velocity.z).length() * delta
	var stride := 2.6 if sprinting else 2.0
	if step_dist > stride:
		step_dist = 0.0
		if not crouching:
			Sfx.play("step%d" % randi_range(1, 3), -11.0 if sprinting else -17.0, 0.1)


# ---------------------------------------------------------------- parachute

func start_freefall(from_pos: Vector3, heading: float) -> void:
	mode = Mode.FREEFALL
	global_position = from_pos
	set_yaw(heading)
	pitch = -0.9
	velocity = Basis(Vector3.UP, heading) * Vector3(0, 0, -20)
	vm.visible = false
	wind_player.volume_db = -4.0
	wind_player.play()
	if not wind_player.finished.is_connected(wind_player.play):
		wind_player.finished.connect(wind_player.play)


func altitude() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 3000.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return global_position.y - hit.position.y if not hit.is_empty() else global_position.y


func _freefall(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Basis(Vector3.UP, yaw) * Vector3(input_dir.x, 0.0, input_dir.y) * 14.0
	velocity.x = lerpf(velocity.x, wish.x, 1.0 - exp(-1.2 * delta))
	velocity.z = lerpf(velocity.z, wish.z, 1.0 - exp(-1.2 * delta))
	velocity.y = move_toward(velocity.y, -52.0, 9.8 * delta)
	rotation.y = yaw
	shake = maxf(shake, 0.12)
	move_and_slide()
	var alt := altitude()
	if (controls_enabled and Input.is_action_just_pressed("jump") and alt < 650.0) or alt < 160.0:
		open_chute()
	if is_on_floor():
		_land(true)


func open_chute() -> void:
	mode = Mode.CANOPY
	Sfx.play("chute_open", 0.0, 0.0)
	wind_player.volume_db = -16.0
	add_shake(0.6)
	if Models.has("parachute"):
		chute = Models.make("parachute", false)
		add_child(chute)
		chute.position = Vector3(0, 6.2, -1.6)
	chute_speed = 9.0


func _canopy(delta: float) -> void:
	var steer := 0.0
	var brake := 0.0
	if controls_enabled:
		steer = Input.get_axis("move_right", "move_left")
		brake = Input.get_axis("move_forward", "move_back")
	yaw += steer * 0.7 * delta
	chute_speed = move_toward(chute_speed, 9.0 - brake * 5.0, delta * 4.0)
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	velocity.x = fwd.x * chute_speed
	velocity.z = fwd.z * chute_speed
	velocity.y = move_toward(velocity.y, -4.5 - brake * 1.5, 30.0 * delta)
	rotation.y = yaw
	if chute != null:
		chute.rotation.z = lerpf(chute.rotation.z, steer * 0.25, delta * 3.0)
	move_and_slide()
	if is_on_floor() or altitude() < 0.4:
		_land(false)


func _land(hard: bool) -> void:
	mode = Mode.WALK
	velocity = Vector3.ZERO
	wind_player.stop()
	Sfx.play("land", -2.0)
	add_shake(0.5)
	if hard and not god:
		take_damage(200.0, global_position, false, "fall")
	if chute != null:
		var c := chute
		chute = null
		var p := c.global_transform
		remove_child(c)
		Fx.root().add_child(c)
		c.global_transform = p
		var tw := c.create_tween()
		tw.tween_property(c, "global_position", p.origin + Vector3(2.5, -5.5, 2.0), 2.2)
		tw.parallel().tween_property(c, "scale", Vector3(1.0, 0.15, 1.0), 2.2)
		tw.tween_interval(20.0)
		tw.tween_callback(c.queue_free)
	vm.visible = true
	pitch = 0.0
	landed.emit()


# ---------------------------------------------------------------- riding (helicopter / cutscenes)

func ride(target: Node3D, local_offset: Vector3) -> void:
	mode = Mode.RIDE
	ride_target = target
	ride_offset = local_offset
	controls_enabled = false
	vm.visible = false
	binocs = false
	col.disabled = true


func stop_ride(at: Vector3) -> void:
	mode = Mode.WALK
	ride_target = null
	global_position = at
	controls_enabled = true
	vm.visible = true
	col.disabled = false
	velocity = Vector3.ZERO


# ---------------------------------------------------------------- visuals

func _process(delta: float) -> void:
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			flash_mesh.visible = false
			flash_light.light_energy = 0.0
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-9.0 * delta))
	kick = lerpf(kick, 0.0, 1.0 - exp(-16.0 * delta))
	if dead:
		return
	head.rotation.x = pitch + recoil
	shake = move_toward(shake, 0.0, delta * 1.6)
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 0.5 and mode == Mode.WALK:
		bob_t += delta * hs * 1.7
	var bob_amt := clampf(hs / 6.0, 0.0, 1.0) * (1.0 - ads * 0.85) * (1.0 if mode == Mode.WALK else 0.0)
	var bob := Vector3(cos(bob_t) * 0.03, absf(sin(bob_t)) * 0.04, 0.0) * bob_amt
	cam.position = Vector3(0.0, bob.y * 0.6, 0.0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * shake * 0.06
	cam.rotation.z = randf_range(-1, 1) * shake * 0.02
	var d := wdef()
	var target_fov := 75.0
	if binocs:
		target_fov = 14.0
	elif ads > 0.0:
		target_fov = lerpf(75.0, d.get("ads_fov", 55.0), ads)
	cam.fov = lerpf(cam.fov, target_fov + sprint_blend * 6.0, 1.0 - exp(-14.0 * delta))
	var scoped: bool = d.get("scope", false) and ads > 0.85
	vm.visible = mode == Mode.WALK and not binocs and not scoped
	if current == "":
		return
	sway = sway.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	var rl := 0.0
	if reloading:
		rl = sin((1.0 - reload_t / maxf(d.get("reload", 2.0), 0.1)) * PI)
	var sw := 0.0
	if switching > 0.0:
		sw = clampf(switching / 0.45, 0.0, 1.0)
	var hip: Vector3 = d.get("hip_pos", Vector3(0.2, -0.22, -0.5))
	var adsp: Vector3 = d.get("ads_pos", Vector3(0.0, -0.11, -0.36))
	var p := hip.lerp(adsp, ads)
	p += Vector3(bob.x, -bob.y, 0.0) * (1.0 - ads)
	p += Vector3(-sway.x, sway.y, 0.0) * 0.6 * (1.0 - ads * 0.8)
	p.z += kick * 0.05
	p += Vector3(-0.04, -0.12, 0.05) * rl
	p += Vector3(-0.06, -0.07, 0.03) * sprint_blend
	p += Vector3(0.0, -0.3, 0.1) * sw
	var stab := sin(clampf(melee_t / 0.35, 0.0, 1.0) * PI)
	p += Vector3(-0.08, 0.04, -0.18) * stab
	gun_holder.position = p
	gun_holder.rotation = Vector3(kick * 0.06 - rl * 0.5 - sprint_blend * 0.25 - stab * 0.4, sprint_blend * 0.8 + rl * 0.3, rl * 0.5 + sway.x * 0.5)


# ---------------------------------------------------------------- actions / API

func start_reload() -> void:
	if current == "" or reloading or dead:
		return
	var d := wdef()
	if d.get("melee", false):
		return
	var st: Dictionary = inv[current]
	if st.mag >= d.mag or st.reserve <= 0:
		return
	reloading = true
	reload_t = d.reload
	Sfx.play("reload", -4.0, 0.0)


func throw_grenade() -> void:
	if grenades <= 0 or grenade_cd > 0.0 or dead or reloading:
		return
	grenades -= 1
	grenade_cd = 1.0
	Sfx.play("pin_pull", -4.0)
	var g := GrenadeScript.new()
	Fx.root().add_child(g)
	var fwd := -cam.global_transform.basis.z
	g.global_position = cam.global_position + fwd * 0.6 + Vector3.DOWN * 0.15
	g.linear_velocity = fwd * 16.0 + Vector3.UP * 3.5 + velocity * 0.5
	g.angular_velocity = Vector3(randf(), randf(), randf()) * 8.0


func use_medkit() -> void:
	if medkits <= 0 or hp >= max_hp or dead:
		return
	medkits -= 1
	hp = minf(max_hp, hp + 55.0)
	Sfx.play("medkit", -4.0)


func take_damage(amount: float, from_pos: Vector3, _headshot := false, kind := "bullet") -> bool:
	if dead or god or invuln > 0.0:
		return false
	if kind == "bullet":
		amount *= Game.enemy_damage_mult()
	hp -= amount
	last_hurt = clock
	shake = minf(shake + (0.12 if kind == "bullet" else 0.6), 1.0)
	damaged.emit(from_pos)
	Sfx.play("hurt", -8.0)
	if hp <= 0.0:
		_die()
	return dead


func _die() -> void:
	hp = 0.0
	dead = true
	controls_enabled = false
	reloading = false
	binocs = false
	ads = 0.0
	vm.visible = false
	mode = Mode.WALK
	var tw := create_tween()
	tw.tween_property(head, "position:y", 0.35, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(cam, "rotation:z", 0.9, 0.7)
	died.emit()


func respawn(cp: Dictionary) -> void:
	dead = false
	controls_enabled = true
	mode = Mode.WALK
	hp = maxf(cp.get("hp", max_hp), 60.0)
	invuln = 3.0
	velocity = Vector3.ZERO
	global_position = cp.pos
	set_yaw(cp.yaw)
	pitch = 0.0
	inv = cp.inv.duplicate(true)
	medkits = maxi(cp.medkits, 1)
	grenades = cp.grenades
	crouching = false
	reloading = false
	head.position.y = EYE_STAND
	cam.rotation = Vector3.ZERO
	vm.visible = true
	col.disabled = false
	var cur: String = cp.current
	current = ""
	equip(cur, true)


func checkpoint_data() -> Dictionary:
	return {"pos": global_position + Vector3.UP * 0.1, "yaw": yaw, "inv": inv.duplicate(true),
		"medkits": medkits, "grenades": grenades, "current": current, "hp": hp}


func set_yaw(y: float) -> void:
	yaw = y
	rotation.y = y


func look_at_point(p: Vector3) -> void:
	var d := p - head.global_position
	set_yaw(atan2(-d.x, -d.z))
	pitch = atan2(d.y, Vector2(d.x, d.z).length())
	head.rotation.x = pitch


func add_ammo_for(id: String, amount: int) -> bool:
	if not inv.has(id):
		return false
	var d: Dictionary = Weapons.get_def(id)
	var before: int = inv[id].reserve
	inv[id].reserve = mini(inv[id].reserve + amount, d.get("max_reserve", 999))
	return inv[id].reserve > before


func add_shake(a: float) -> void:
	shake = minf(shake + a, 1.0)


func get_eye_position() -> Vector3:
	return head.global_position


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * (0.8 if crouching else 1.25)


func ammo_text() -> String:
	if current == "" or wdef().get("melee", false):
		return ""
	return "%d / %d" % [inv[current].mag, inv[current].reserve]
