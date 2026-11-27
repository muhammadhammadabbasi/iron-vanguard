extends Area3D
## Pickup: weapon (gives the weapon or its ammo), ammo, medkit, grenade.

var kind := "weapon"     # weapon | medkit | grenade
var item := "ak"
var amount := 30
var life := 120.0
var visual: Node3D
var base_y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	add_child(cs)
	visual = Node3D.new()
	add_child(visual)
	match kind:
		"weapon":
			var m := Models.weapon(item)
			visual.add_child(m)
			m.rotate_object_local(Vector3.FORWARD, PI / 2.0)
			visual.rotation.y = randf() * TAU
			visual.position.y = -0.2
		"medkit":
			visual.add_child(Models.make("medkit", false))
			visual.position.y = -0.2
		"grenade":
			var g := Models.make("grenade", false)
			visual.add_child(g)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body(b: Node) -> void:
	if not b.is_in_group("player") or b.dead:
		return
	var took := false
	match kind:
		"weapon":
			if b.inv.has(item):
				took = b.add_ammo_for(item, amount)
			else:
				took = b.give_weapon(item)
				if took:
					b.inv[item].reserve = amount
		"medkit":
			if b.medkits < 5:
				b.medkits += 1
				took = true
		"grenade":
			if b.grenades < 5:
				b.grenades += 1
				took = true
	if took:
		Sfx.play("pickup", -6.0)
		var hud = get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.notify(_label())
		queue_free()


func _label() -> String:
	match kind:
		"weapon":
			return "PICKED UP  " + str(item).to_upper()
		"medkit":
			return "MEDKIT"
		"grenade":
			return "GRENADE"
	return ""
