extends Node3D
## Black Hawk with spinning rotors, rotor sound, and scripted fly-in / landing / take-off.

signal arrived
signal departed

var rotors: Array = []      # [node, axis, speed]
var sound: AudioStreamPlayer3D
var body: Node3D
var spin := 1.0


func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	var src := Models.make("blackhawk")
	# split rotor meshes from the fuselage so they can spin
	var ab: AABB = Models.aabb("blackhawk")
	for mi in src.get_children():
		var a: AABB = mi.transform * mi.mesh.get_aabb()
		var rotor := a.size.y < 0.6 and maxf(a.size.x, a.size.z) > 10.0 and a.get_center().y > ab.size.y * 0.55
		var tail := a.size.x < 0.5 and maxf(a.size.y, a.size.z) > 2.0 and maxf(a.size.y, a.size.z) < 4.5 and a.get_center().z > ab.end.z - 3.5
		src.remove_child(mi)
		if rotor or tail:
			var pivot := Node3D.new()
			pivot.position = a.get_center()
			body.add_child(pivot)
			pivot.add_child(mi)
			mi.transform = Transform3D(mi.transform.basis, mi.transform.origin - a.get_center())
			rotors.append([pivot, Vector3.UP if rotor else Vector3.RIGHT, 22.0 if rotor else 40.0])
		else:
			body.add_child(mi)
	src.free()
	if rotors.is_empty():
		# fallback: spinning blade disc
		var pivot := Node3D.new()
		pivot.position = Vector3(0, ab.size.y * 0.92, 0)
		body.add_child(pivot)
		for i in 4:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(16.0, 0.05, 0.5)
			b.mesh = bm
			b.material_override = Fx.mats["gun_metal"]
			b.rotation.y = i * PI / 4.0
			pivot.add_child(b)
		rotors.append([pivot, Vector3.UP, 22.0])
	sound = AudioStreamPlayer3D.new()
	sound.stream = Sfx.streams.get("heli")
	sound.unit_size = 30.0
	sound.max_distance = 600.0
	sound.volume_db = 6.0
	add_child(sound)
	sound.finished.connect(_on_sound_finished)
	sound.play()


func _on_sound_finished() -> void:
	if spin > 0.05:
		sound.play()


func _process(delta: float) -> void:
	for r in rotors:
		r[0].rotate(r[1], r[2] * spin * delta)
	body.position.y = sin(Time.get_ticks_msec() * 0.0015) * 0.08 * spin


## Fly from `from` to land at `to` (facing `yaw`).
func fly_in(from: Vector3, to: Vector3, yaw: float, time := 16.0) -> Tween:
	global_position = from
	rotation = Vector3(0, yaw, 0)
	var hover := to + Vector3(0, 14, 0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", hover, time * 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "rotation:x", 0.12, time * 0.3)
	tw.tween_property(self, "rotation:x", 0.0, time * 0.1)
	tw.tween_property(self, "global_position", to, time * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): arrived.emit())
	return tw


func take_off(to: Vector3, time := 14.0) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + Vector3(0, 18, 0), time * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation:x", 0.15, 1.5)
	tw.parallel().tween_property(self, "global_position", to, time * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): departed.emit())
	return tw
