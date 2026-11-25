extends RigidBody3D
## Frag grenade thrown by the player.

const Geo = preload("res://scripts/core/geo.gd")

var fuse := 2.6
var bounced := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	mass = 0.4
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.8
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.07
	cs.shape = sh
	add_child(cs)
	Geo.mesh_sphere(self, 0.07, Vector3.ZERO, Fx.mats["crate"], Vector3(1.0, 1.25, 1.0), 10)
	Geo.mesh_box(self, Vector3(0.03, 0.05, 0.03), Vector3(0, 0.09, 0), Fx.mats["metal"])
	body_entered.connect(_on_body_entered)


func _on_body_entered(_b: Node) -> void:
	if linear_velocity.length() > 2.0 and bounced <= 0.0:
		bounced = 0.15
		Sfx.play3d("bounce", global_position, -6.0, 40.0)


func _physics_process(delta: float) -> void:
	bounced -= delta
	fuse -= delta
	if fuse <= 0.0:
		set_physics_process(false)
		Fx.explosion(global_position, 7.5, 230.0)
		get_tree().call_group("enemy", "hear_noise", global_position, 70.0, true)
		queue_free()
