extends StaticBody3D
## Alarm siren pole. Shoot it (or blow it up) to stop the alarm.

var hp := 45.0
var destroyed := false
var system: Node
var light: OmniLight3D
var t := 0.0


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("alarm_panel")
	collision_layer = 1
	collision_mask = 0
	var vis := Models.make("siren")
	add_child(vis)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 4.5, 0.6)
	cs.shape = bs
	cs.position.y = 2.25
	add_child(cs)
	light = OmniLight3D.new()
	light.light_color = Color(1, 0.15, 0.1)
	light.omni_range = 9.0
	light.light_energy = 0.0
	light.position = Vector3(0, 4.3, 0)
	add_child(light)


func _process(delta: float) -> void:
	if system != null and system.raised and not destroyed:
		t += delta
		light.light_energy = 3.0 * (0.5 + 0.5 * sin(t * 9.0))
	else:
		light.light_energy = 0.0


func take_damage(amount: float, _from: Vector3, _h := false, _k := "bullet") -> bool:
	if destroyed:
		return false
	hp -= amount
	if hp <= 0.0:
		destroyed = true
		Fx.impact(global_position + Vector3.UP * 4.2, Vector3.UP, false)
		Sfx.play3d("impact", global_position + Vector3.UP * 4.0, 0.0, 60.0)
		remove_from_group("damageable")
		rotation.z = 0.25
		if system != null:
			system.panel_destroyed()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.notify("ALARM DESTROYED")
	return false
