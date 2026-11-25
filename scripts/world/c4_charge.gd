extends Node3D
## Planted C4 with a beeping countdown.

signal detonated

var fuse := 6.0
var radius := 9.0
var damage := 260.0
var beep_t := 0.0


func _ready() -> void:
	var m := Models.make("c4", false)
	add_child(m)


func _process(delta: float) -> void:
	fuse -= delta
	beep_t -= delta
	if beep_t <= 0.0:
		beep_t = clampf(fuse * 0.18, 0.12, 0.8)
		Sfx.play3d("c4_beep", global_position, -4.0, 40.0, 0.0)
	if fuse <= 0.0:
		set_process(false)
		Fx.explosion(global_position + Vector3.UP * 0.4, radius, damage)
		get_tree().call_group("enemy", "hear_noise", global_position, 90.0, true)
		detonated.emit()
		queue_free()
