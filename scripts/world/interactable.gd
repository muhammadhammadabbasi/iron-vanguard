extends Area3D
## "Hold E" interaction zone (laptops, consoles, C4 spots, keycards, boarding the helicopter).

signal done

var prompt := "Hold [E]"
var busy_text := "Working..."
var hold_time := 2.0
var radius := 2.0
var enabled := true
var once := true
var progress := 0.0
var inside := false
var marker_offset := Vector3(0, 1.0, 0)


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b: Node) -> void:
	if b.is_in_group("player"):
		inside = true


func _on_exit(b: Node) -> void:
	if b.is_in_group("player"):
		inside = false


func _process(delta: float) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if not enabled:
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or pl.dead or not inside or pl.mode != 0:
		if progress > 0.0 and hud != null and hud.prompt_owner == self:
			hud.hide_prompt()
		progress = maxf(progress - delta, 0.0)
		return
	if Input.is_action_pressed("interact"):
		progress += delta / maxf(hold_time, 0.05)
		if hud != null:
			hud.show_prompt(busy_text, progress, self)
		if progress >= 1.0:
			progress = 0.0
			if once:
				enabled = false
			if hud != null:
				hud.hide_prompt()
			Sfx.play("console", -6.0)
			done.emit()
	else:
		progress = maxf(progress - delta * 0.5, 0.0)
		if hud != null:
			hud.show_prompt(prompt, progress, self)
