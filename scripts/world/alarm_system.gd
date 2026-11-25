extends Node3D
## Base alarm. Enemies who spot the player run to the nearest alarm panel. When raised: siren, every enemy
## hunts the player, and (if the radio link is still up) reinforcements arrive in waves.
## Destroying every panel silences it; destroying the radio mast stops reinforcements.

signal alarm_raised
signal alarm_stopped

var raised := false
var someone_running := false
var radio_up := true
var panels: Array = []
var reinforcement_points: Array = []
var reinforcement_size := 3
var reinforcement_interval := 40.0
var max_reinforcements := 9
var spawned := 0
var spawn_fn: Callable
var _timer := 0.0
var siren: AudioStreamPlayer


func _ready() -> void:
	add_to_group("alarm_system")
	siren = AudioStreamPlayer.new()
	siren.stream = Sfx.streams.get("alarm")
	siren.volume_db = -10.0
	add_child(siren)
	siren.finished.connect(_on_siren_finished)


func _on_siren_finished() -> void:
	if raised:
		siren.play()


func can_raise() -> bool:
	for p in panels:
		if is_instance_valid(p) and not p.destroyed:
			return true
	return false


func nearest_panel(from: Vector3):
	var best = null
	var bd := INF
	for p in panels:
		if is_instance_valid(p) and not p.destroyed:
			var d: float = p.global_position.distance_to(from)
			if d < bd:
				bd = d
				best = p
	return best


func raise(_by: Vector3) -> void:
	if raised or not can_raise():
		return
	raised = true
	someone_running = false
	siren.play()
	_timer = 12.0
	var pl = get_tree().get_first_node_in_group("player")
	if pl != null:
		get_tree().call_group("enemy", "alarm_alert", pl.global_position)
	alarm_raised.emit()


func stop() -> void:
	if not raised:
		return
	raised = false
	siren.stop()
	alarm_stopped.emit()


func panel_destroyed() -> void:
	if not can_raise():
		stop()


func _process(delta: float) -> void:
	if not raised or not radio_up or reinforcement_points.is_empty() or not spawn_fn.is_valid():
		return
	if spawned >= max_reinforcements:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = reinforcement_interval
		var pt: Vector3 = reinforcement_points.pick_random()
		for i in mini(reinforcement_size, max_reinforcements - spawned):
			spawn_fn.call(pt + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
			spawned += 1
