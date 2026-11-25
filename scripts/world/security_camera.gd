extends StaticBody3D
## CCTV camera: sweeps left/right; if it sees the player for ~1.2 s it raises the alarm.
## Can be shot out, or switched off from a control console (set_active(false)).

var sweep := 50.0          # degrees each side
var sweep_speed := 0.35
var view_range := 24.0
var fov_cos := 0.82
var active := true
var destroyed := false
var hp := 20.0
var detect := 0.0
var t := 0.0
var base_yaw := 0.0
var head: Node3D
var led: OmniLight3D
var cooldown := 0.0


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("security_camera")
	collision_layer = 1
	collision_mask = 0
	head = Node3D.new()
	add_child(head)
	var m := Models.make("cctv")
	m.rotation.y = PI / 2.0
	head.add_child(m)
	head.rotation.x = -0.35
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.35, 0.35, 0.6)
	cs.shape = bs
	add_child(cs)
	led = OmniLight3D.new()
	led.omni_range = 1.5
	led.light_energy = 1.0
	led.light_color = Color(0.2, 1, 0.3)
	led.position = Vector3(0, 0.1, -0.2)
	head.add_child(led)
	base_yaw = 0.0
	t = randf() * TAU


func set_active(on: bool) -> void:
	active = on
	led.light_energy = 1.0 if on else 0.0


func _physics_process(delta: float) -> void:
	if destroyed or not active:
		return
	cooldown -= delta
	t += delta * sweep_speed
	head.rotation.y = base_yaw + deg_to_rad(sweep) * sin(t)
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or pl.dead or pl.mode != 0:
		return
	var eye: Vector3 = head.global_position
	var to: Vector3 = pl.get_eye_position() - eye
	var dist := to.length()
	var seen := false
	if dist < view_range:
		var fwd := -head.global_transform.basis.z
		if fwd.dot(to / dist) > fov_cos:
			var q := PhysicsRayQueryParameters3D.create(eye, pl.get_eye_position(), 1 | 2, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			seen = hit.is_empty() or hit.collider == pl
	if seen:
		detect += delta * (1.4 if not pl.crouching else 0.9)
		led.light_color = Color(1, 0.2, 0.1)
		if detect >= 1.2 and cooldown <= 0.0:
			cooldown = 15.0
			Sfx.play("camera_alert", -4.0)
			Sfx.voice("g_camera_spot")
			var alarm = get_tree().get_first_node_in_group("alarm_system")
			if alarm != null:
				alarm.raise(global_position)
			get_tree().call_group("enemy", "alarm_alert", pl.global_position)
	else:
		detect = maxf(detect - delta * 0.6, 0.0)
		led.light_color = Color(0.2, 1, 0.3)


func take_damage(amount: float, _from: Vector3, _h := false, _k := "bullet") -> bool:
	if destroyed:
		return false
	hp -= amount
	if hp <= 0.0:
		destroyed = true
		led.light_energy = 0.0
		head.rotation.x = -1.1
		Fx.impact(head.global_position, Vector3.UP, false)
		remove_from_group("damageable")
		get_tree().call_group("enemy", "hear_noise", global_position, 10.0, false)
	return false
