extends CharacterBody3D
## Red Jackal Front soldier (Mixamo SWAT model). IGI-style stealth AI:
## patrol -> suspicious (investigate) -> alert/attack, runs to raise the alarm, reacts to bodies and noise.

signal died(enemy)

enum State { IDLE, SUSPICIOUS, ALERT, ATTACK, ALARM_RUN, DEAD }

const PickupScript = preload("res://scripts/world/pickup.gd")

const RUN := 4.3
const WALKSPD := 1.6
const GRAVITY := 14.0
const MAG := 30

static var _gun_offset := Transform3D()
static var _gun_offset_ready := false

var state := State.IDLE
var hp := 100.0
var stationary := false
var rush := false
var patrol_points: Array = []
var patrol_i := 0
var wait_t := 0.0
var awareness := 0.0
var last_known := Vector3.ZERO
var susp_pos := Vector3.ZERO
var look_t := 0.0
var see_player := false
var lost_t := 0.0
var reaction := 0.0
var burst_left := 0
var shot_cd := 0.0
var burst_pause := 0.5
var rounds := MAG
var reload_t := 0.0
var think_t := 0.0
var strafe := 0.0
var strafe_t := 0.0
var hunt_t := 0.0
var step_t := 0.0
var dead_t := 0.0
var home := Vector3.ZERO
var home_yaw := 0.0
var voice_index := 1
var sight_range := 38.0
var noticed_bodies := {}
var player = null
var agent: NavigationAgent3D
var model: Node3D
var ap: AnimationPlayer
var skel: Skeleton3D
var gun: Node3D
var cur_anim := ""


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("damageable")
	collision_layer = 4
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.33
	sh.height = 1.8
	cs.shape = sh
	cs.position.y = 0.9
	add_child(cs)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.0
	agent.path_max_distance = 4.0
	agent.radius = 0.45
	agent.height = 1.8
	add_child(agent)
	model = Models.character("swat")
	model.rotation.y = PI   # Mixamo characters face +Z; our soldiers face -Z
	add_child(model)
	_militia_tint(model)
	skel = model.get_node_or_null(Models.skeleton_path("swat"))
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.add_animation_library("", Models.anim_library("swat"))
	_anim("idle")
	ap.seek(randf() * 3.0, true)
	_attach_gun()
	voice_index = randi_range(1, 2)
	think_t = randf() * 0.3
	burst_pause = randf_range(0.3, 1.0)
	home = global_position
	home_yaw = rotation.y
	last_known = global_position


static var _tinted := {}


## Re-colour the SWAT uniform into Red Jackal militia olive/khaki (keeps all texture detail).
func _militia_tint(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src = mi.get_active_material(i)
			if not (src is BaseMaterial3D):
				continue
			if not _tinted.has(src):
				var m: BaseMaterial3D = src.duplicate()
				m.albedo_color = m.albedo_color * Color(0.78, 0.74, 0.52)
				_tinted[src] = m
			mi.set_surface_override_material(i, _tinted[src])


func _attach_gun() -> void:
	if skel == null:
		return
	var rh := skel.find_bone("mixamorig_RightHand")
	var lh := skel.find_bone("mixamorig_LeftHand")
	if rh < 0:
		return
	if not _gun_offset_ready and lh >= 0:
		# Work out once how the rifle sits in the right hand: barrel points from the right hand to the left hand.
		ap.seek(0.4, true)
		var rt: Transform3D = skel.global_transform * skel.get_bone_global_pose(rh)
		var lt: Transform3D = skel.global_transform * skel.get_bone_global_pose(lh)
		var dir := (lt.origin - rt.origin)
		if dir.length() > 0.1:
			var g := Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), rt.origin)
			_gun_offset = rt.affine_inverse() * g
			_gun_offset_ready = true
	var ba := BoneAttachment3D.new()
	ba.bone_name = "mixamorig_RightHand"
	skel.add_child(ba)
	gun = Node3D.new()
	ba.add_child(gun)
	gun.transform = _gun_offset
	var m := Models.make("ak")
	m.rotation.y = PI / 2.0
	m.position = Vector3(0, 0.04, -0.2)
	gun.add_child(m)


func _anim(n: String, spd := 1.0, blend := 0.25) -> void:
	if cur_anim == n:
		ap.speed_scale = spd
		return
	cur_anim = n
	ap.speed_scale = spd
	if ap.has_animation(n):
		ap.play(n, blend)


func muzzle_pos() -> Vector3:
	if gun != null:
		return gun.global_transform * Vector3(0, 0.06, -0.75)
	return global_position + Vector3.UP * 1.4 - global_transform.basis.z * 0.6


func is_unaware() -> bool:
	return state == State.IDLE or (state == State.SUSPICIOUS and awareness < 0.6)


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		dead_t += delta
		if not is_on_floor() and dead_t < 3.0:
			velocity.y -= GRAVITY * delta
			move_and_slide()
		elif dead_t > 4.0:
			set_physics_process(false)
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.15
		_perceive(0.15)
	var hv := Vector3.ZERO
	match state:
		State.IDLE:
			hv = _idle(delta)
		State.SUSPICIOUS:
			hv = _suspicious(delta)
		State.ALERT:
			hv = _alert(delta)
		State.ATTACK:
			hv = _attack(delta)
		State.ALARM_RUN:
			hv = _alarm_run(delta)
	if stationary:
		hv = Vector3.ZERO
	var k := 1.0 - exp(-10.0 * delta)
	velocity.x = lerpf(velocity.x, hv.x, k)
	velocity.z = lerpf(velocity.z, hv.z, k)
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_animate(delta)


func _idle(delta: float) -> Vector3:
	if patrol_points.is_empty() or stationary:
		if _flat_dist(home) > 1.5 and not stationary:
			var d0 := _nav_dir(home)
			_face(d0, delta, 5.0)
			return d0 * WALKSPD
		rotation.y = lerp_angle(rotation.y, home_yaw + sin(Time.get_ticks_msec() * 0.0003 + home.x) * 0.6, delta * 0.8)
		return Vector3.ZERO
	if wait_t > 0.0:
		wait_t -= delta
		return Vector3.ZERO
	var tgt: Vector3 = patrol_points[patrol_i]
	if _flat_dist(tgt) < 1.0:
		patrol_i = (patrol_i + 1) % patrol_points.size()
		wait_t = randf_range(2.0, 5.0)
		return Vector3.ZERO
	var d := _nav_dir(tgt)
	_face(d, delta, 5.0)
	return d * WALKSPD


func _suspicious(delta: float) -> Vector3:
	if _flat_dist(susp_pos) > 1.8:
		var d := _nav_dir(susp_pos)
		_face(d, delta, 6.0)
		return d * WALKSPD * 1.3
	look_t -= delta
	rotation.y += sin(look_t * 1.6) * delta * 1.2
	if look_t <= 0.0:
		state = State.IDLE
		awareness = 0.0
		Sfx.shout("nothing", global_position, voice_index)
	return Vector3.ZERO


func _alert(delta: float) -> Vector3:
	hunt_t -= delta
	var p_ok: bool = player != null and not player.dead
	if p_ok and (rush or hunt_t <= 0.0):
		if rush or _flat_dist(last_known) < 2.0:
			last_known = player.global_position
			hunt_t = 3.0
	if _flat_dist(last_known) < 1.5:
		return Vector3.ZERO
	var d := _nav_dir(last_known)
	_face(d, delta, 8.0)
	return d * RUN


func _attack(delta: float) -> Vector3:
	if player == null or player.dead:
		state = State.ALERT
		return Vector3.ZERO
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		_face(to / dist, delta, 10.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			rounds = MAG
		return Vector3.ZERO
	if see_player:
		lost_t = 0.0
		if reaction > 0.0:
			reaction -= delta
		else:
			_shooting(delta)
	else:
		lost_t += delta
		if lost_t > 1.5:
			state = State.ALERT
			last_known = player.global_position
			hunt_t = 2.0
			if randf() < 0.4:
				Sfx.shout("lost", global_position, voice_index)
			return Vector3.ZERO
	if stationary:
		return Vector3.ZERO
	var desired := 14.0 if rush else 22.0
	if dist > desired + 4.0 or not see_player:
		var d := _nav_dir(player.global_position)
		return d * (RUN * 0.55 if see_player else RUN)
	if dist < 5.0 and dist > 0.01:
		return -to / dist * 1.6
	strafe_t -= delta
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.5, 3.2)
		strafe = [-1.0, 0.0, 0.0, 1.0].pick_random()
	if dist < 0.01:
		return Vector3.ZERO
	return (to / dist).cross(Vector3.UP) * strafe * 1.4


func _alarm_run(delta: float) -> Vector3:
	var alarm = _alarm()
	if alarm == null or alarm.raised or not alarm.can_raise():
		state = State.ATTACK if see_player else State.ALERT
		return Vector3.ZERO
	var panel = alarm.nearest_panel(global_position)
	if panel == null:
		state = State.ALERT
		return Vector3.ZERO
	var tgt: Vector3 = panel.global_position
	if _flat_dist(tgt) < 1.8:
		alarm.raise(global_position)
		state = State.ATTACK if see_player else State.ALERT
		return Vector3.ZERO
	var d := _nav_dir(tgt)
	_face(d, delta, 8.0)
	return d * RUN


func _shooting(delta: float) -> void:
	shot_cd -= delta
	if burst_left > 0:
		if shot_cd <= 0.0:
			_shoot()
			burst_left -= 1
			shot_cd = 0.11
	else:
		burst_pause -= delta
		if burst_pause <= 0.0:
			burst_left = randi_range(2, 5)
			burst_pause = randf_range(0.9, 1.8)


func _shoot() -> void:
	rounds -= 1
	if rounds <= 0:
		reload_t = 2.4
		burst_left = 0
		_anim("reload")
		if randf() < 0.5:
			Sfx.shout("reload", global_position, voice_index)
		return
	var from := muzzle_pos()
	var target: Vector3 = player.get_aim_point()
	var dist := from.distance_to(target)
	Sfx.play3d("enemy_shot", from, -2.0, 180.0)
	Fx.muzzle_flash(from)
	var acc := clampf(0.42 - dist * 0.009, 0.08, 0.36) * Game.enemy_accuracy_mult()
	var pv: Vector3 = player.velocity
	var ps := Vector2(pv.x, pv.z).length()
	if ps > 5.0:
		acc *= 0.55
	elif ps > 1.0:
		acc *= 0.8
	if player.crouching:
		acc *= 0.8
	var hit_player := randf() < acc
	var aim := target
	if not hit_player:
		var off := Vector3(randf_range(-1, 1), randf_range(-0.6, 0.9), randf_range(-1, 1)).normalized()
		aim = target + off * randf_range(0.6, 1.6)
	var dir := (aim - from).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 250.0, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + dir * 250.0
	if not hit.is_empty():
		end = hit.position
		if hit.collider == player:
			player.take_damage(randf_range(7.0, 10.0), global_position, false, "bullet")
		else:
			Fx.impact(end, hit.normal, false)
	if not hit_player:
		var eye: Vector3 = player.get_eye_position()
		var cp := Geometry3D.get_closest_point_to_segment(eye, from, end)
		if cp.distance_to(eye) < 2.0 and randf() < 0.6:
			Sfx.play("whiz", -10.0, 0.2)
	Fx.tracer(from, end)


# ---------------------------------------------------------------- senses

func _perceive(dt: float) -> void:
	see_player = false
	if player == null or player.dead or player.mode != 0:
		return
	var eye := global_position + Vector3.UP * 1.65
	var tgt: Vector3 = player.get_eye_position()
	var to := tgt - eye
	var dist := to.length()
	var rng := sight_range
	if state in [State.ALERT, State.ATTACK, State.ALARM_RUN]:
		rng = 75.0
	if stationary:
		rng += 15.0
	if player.crouching and state in [State.IDLE, State.SUSPICIOUS]:
		rng *= 0.6
	var visible := false
	if dist < rng and dist > 0.01:
		var fwd := -global_transform.basis.z
		var cosang := fwd.dot(to / dist)
		var in_cone := cosang > 0.35 or dist < 3.0 or state in [State.ATTACK, State.ALERT, State.ALARM_RUN]
		if in_cone:
			var q := PhysicsRayQueryParameters3D.create(eye, tgt, 1 | 2, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			visible = hit.is_empty() or hit.collider == player
	if visible:
		see_player = true
		last_known = player.global_position
		if state in [State.ATTACK, State.ALERT, State.ALARM_RUN]:
			if state == State.ALERT:
				_engage()
			return
		# awareness fills faster when close, when the player moves, and when he is standing
		var k := clampf(1.25 - dist / rng, 0.15, 1.2)
		var pv: Vector3 = player.velocity
		if Vector2(pv.x, pv.z).length() > 3.0:
			k *= 1.5
		if player.crouching:
			k *= 0.6
		awareness += k * dt * 1.6
		if dist < 6.0:
			awareness += dt * 3.0
		if awareness >= 1.0:
			_spotted()
		elif awareness > 0.3 and state == State.IDLE:
			_become_suspicious(player.global_position)
	else:
		if state in [State.IDLE, State.SUSPICIOUS]:
			awareness = maxf(awareness - dt * 0.12, 0.0)
	# bodies
	if state in [State.IDLE, State.SUSPICIOUS]:
		for c in get_tree().get_nodes_in_group("corpse"):
			if noticed_bodies.has(c) or not is_instance_valid(c):
				continue
			var bd: float = c.global_position.distance_to(global_position)
			if bd < 16.0:
				var q2 := PhysicsRayQueryParameters3D.create(eye, c.global_position + Vector3.UP * 0.4, 1, [get_rid()])
				if get_world_3d().direct_space_state.intersect_ray(q2).is_empty():
					noticed_bodies[c] = true
					Sfx.shout("mandown", global_position, voice_index)
					_become_suspicious(c.global_position)
					awareness = 0.75
					get_tree().call_group("enemy", "hear_noise", global_position, 20.0, false)


func _become_suspicious(pos: Vector3) -> void:
	if state == State.IDLE:
		Sfx.shout("heard", global_position, voice_index)
	state = State.SUSPICIOUS
	susp_pos = pos
	look_t = 5.0


func _spotted() -> void:
	awareness = 1.0
	Sfx.shout("intruder" if randf() < 0.6 else "overthere", global_position, voice_index)
	var alarm = _alarm()
	if alarm != null and not alarm.raised and alarm.can_raise() and not alarm.someone_running:
		var panel = alarm.nearest_panel(global_position)
		if panel != null and panel.global_position.distance_to(global_position) < 70.0:
			alarm.someone_running = true
			state = State.ALARM_RUN
			Sfx.shout("alarm", global_position, voice_index)
			_alert_friends(14.0)
			return
	_engage()
	_alert_friends(18.0)


func _engage() -> void:
	reaction = randf_range(0.5, 0.9) / Game.enemy_accuracy_mult() if state in [State.IDLE, State.SUSPICIOUS] else randf_range(0.25, 0.5)
	state = State.ATTACK
	awareness = 1.0
	lost_t = 0.0


func _alert_friends(radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e.global_position.distance_to(global_position) < radius:
			e.alarm_alert(last_known)


func _alarm() -> Node:
	return get_tree().get_first_node_in_group("alarm_system")


## Noise from the player (gunshots, explosions). loud = unsilenced.
func hear_noise(pos: Vector3, radius: float, loud := true) -> void:
	if state == State.DEAD:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	if state in [State.IDLE, State.SUSPICIOUS]:
		if loud and d < radius * 0.7:
			state = State.ALERT
			awareness = 1.0
			last_known = pos + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			hunt_t = 3.0
			Sfx.shout("overthere", global_position, voice_index)
		else:
			_become_suspicious(pos)
			awareness = maxf(awareness, 0.5)


## Told by a friend or by the alarm where the player is.
func alarm_alert(pos: Vector3) -> void:
	if state in [State.IDLE, State.SUSPICIOUS]:
		state = State.ALERT
		awareness = 1.0
		last_known = pos
		hunt_t = 4.0


func rush_to(pos: Vector3) -> void:
	rush = true
	state = State.ALERT
	awareness = 1.0
	last_known = pos


func forget() -> void:
	if state == State.DEAD:
		return
	state = State.ALERT if rush else State.IDLE
	see_player = false
	awareness = 0.0
	burst_left = 0
	reaction = 1.0
	last_known = global_position
	hunt_t = 4.0


# ---------------------------------------------------------------- damage

func take_damage(amount: float, from_pos: Vector3, headshot := false, _kind := "bullet") -> bool:
	if state == State.DEAD:
		return false
	hp -= amount
	if hp <= 0.0:
		_die(from_pos, headshot)
		return true
	if state in [State.IDLE, State.SUSPICIOUS]:
		last_known = from_pos
		state = State.ALERT
		awareness = 1.0
		hunt_t = 1.0
		reaction = 0.3
		_alert_friends(12.0)
	return false


func _die(from_pos: Vector3, headshot: bool) -> void:
	state = State.DEAD
	remove_from_group("enemy")
	remove_from_group("damageable")
	add_to_group("corpse")
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	var alarm = _alarm()
	if alarm != null and alarm.someone_running:
		alarm.someone_running = false
	died.emit(self)
	var away := global_position - from_pos
	away.y = 0.0
	var front := (-global_transform.basis.z).dot(away.normalized()) < 0.0
	var options := ["death_front", "death"] if front else ["death_back", "death"]
	if headshot:
		options = ["death_front"] if front else ["death_back"]
	_anim(options.pick_random(), 1.0, 0.1)
	call_deferred("_drop_loot")


func _drop_loot() -> void:
	var r: Node = Fx.root()
	if r == null:
		return
	var p := PickupScript.new()
	p.kind = "weapon"
	p.item = "ak"
	p.amount = randi_range(12, 30)
	r.add_child(p)
	p.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.25, randf_range(-0.5, 0.5))
	if randf() < 0.22:
		var m := PickupScript.new()
		m.kind = "medkit"
		r.add_child(m)
		m.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.25, randf_range(-0.8, 0.8))


# ---------------------------------------------------------------- helpers

func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _nav_dir(target: Vector3) -> Vector3:
	if agent.target_position.distance_to(target) > 0.75:
		agent.target_position = target
	var next := agent.get_next_path_position()
	var d := next - global_position
	d.y = 0.0
	if d.length() < 0.1:
		d = target - global_position
		d.y = 0.0
		if d.length() < 1.0:
			return Vector3.ZERO
	return d.normalized()


func _face(dir: Vector3, delta: float, spd: float) -> void:
	if dir.length_squared() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-spd * delta))


func _animate(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if reload_t > 0.0:
		_anim("reload")
	elif state == State.ATTACK and see_player and hs < 1.0:
		_anim("fire" if burst_left > 0 else "idle")
	elif hs > 3.0:
		_anim("run", clampf(hs / 4.3, 0.7, 1.2))
	elif hs > 0.4:
		_anim("walk", clampf(hs / 1.6, 0.7, 1.5))
	else:
		_anim("idle")
	if hs > 3.0 and player != null:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.36
			if player.global_position.distance_to(global_position) < 25.0:
				Sfx.play3d("step%d" % randi_range(1, 3), global_position, -6.0, 25.0)
