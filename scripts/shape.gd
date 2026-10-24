class_name GiantShape
extends Area2D
## A giant shape falling from the sky. Made of pure palette menace.
## Starts slow and accelerates on the way down.

var fall_speed := 120.0
var fall_accel := 0.0
var half_size := 128.0


func setup(texture: Texture2D, scale_factor: float, speed: float, accel: float) -> void:
	fall_speed = speed
	fall_accel = accel
	half_size = texture.get_width() * scale_factor * 0.5

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)

	# Circle hitbox slightly smaller than the sprite: corners are forgiving.
	var collider := CollisionShape2D.new()
	var ball := CircleShape2D.new()
	ball.radius = maxf(half_size * 0.84, 4.0)
	collider.shape = ball
	add_child(collider)

	collision_layer = 2
	collision_mask = 1
	monitoring = true


func _process(delta: float) -> void:
	fall_speed += fall_accel * delta  # slow at spawn, fast by impact
	position.y += fall_speed * delta
	if position.y - half_size > 400.0:
		queue_free()
