class_name LittleGuy
extends Area2D
## The little guy. 16x16 pixels of bravery. Runs left/right and jumps.

const SPEED := 230.0
const ACCEL := 1400.0      # px/s² — reach top speed in ~0.16s
const DECEL := 2000.0      # px/s² — stopping/reversing is snappier than accelerating
const AIR_ACCEL := 1000.0  # px/s² — slightly less grip in the air
const GRAVITY := 600.0
const JUMP_VELOCITY := 290.0
const JUMP_CUT := 0.5  # releasing jump early = a shorter hop
const FLOOR_Y := 328.0  # center y when standing on the ground strip

var enabled := true
var velocity := Vector2.ZERO
var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.player_texture()
	add_child(sprite)

	# Forgiving hitbox: a bit smaller than the sprite so near-misses feel fair.
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 12)
	collider.shape = box
	add_child(collider)

	collision_layer = 1
	collision_mask = 2
	monitoring = true


func _process(delta: float) -> void:
	if not enabled:
		return

	# Horizontal movement with acceleration: it takes a moment to reach top
	# speed, and letting go (or reversing) decelerates you to a stop.
	var axis := Input.get_axis("move_left", "move_right")
	var target_speed := axis * SPEED
	var rate := ACCEL if is_on_floor() else AIR_ACCEL
	if absf(target_speed) < 0.01 or signf(target_speed) != signf(velocity.x):
		rate = DECEL
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	# Face the way you're actually moving — the drawn sprite faces left,
	# so moving right means mirrored
	if velocity.x > 1.0:
		sprite.flip_h = true
	elif velocity.x < -1.0:
		sprite.flip_h = false

	# Jump — only when standing on the ground
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -JUMP_VELOCITY
	# Variable jump height: letting go early cuts the jump short
	if velocity.y < 0.0 and Input.is_action_just_released("jump"):
		velocity.y *= JUMP_CUT

	# Gravity
	velocity.y += GRAVITY * delta
	position += velocity * delta

	# Land on the ground
	if position.y >= FLOOR_Y:
		position.y = FLOOR_Y
		velocity.y = 0.0

	# Stay inside the screen
	var half_w: float = maxf(sprite.texture.get_width() * 0.5, 6.0)
	var screen_w: float = get_viewport_rect().size.x
	position.x = clampf(position.x, half_w, screen_w - half_w)


func is_on_floor() -> bool:
	return position.y >= FLOOR_Y - 0.01
