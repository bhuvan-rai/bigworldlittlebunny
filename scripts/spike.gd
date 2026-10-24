class_name GroundSpike
extends Area2D
## A triangle spike that rises out of the ground, lingers, then sinks back.
## Jump over it.

const RISE_TIME := 0.3
const SINK_TIME := 0.3
const GROUND_Y := 336.0  # top edge of the ground strip
const SCREEN_BOTTOM := 360.0

var sprite: Sprite2D
var half_height := 28.0
var standing_y := 0.0
var hidden_y := 0.0
var linger_time := 3.0
var age := 0.0

static var _ink_bottom_cache := {}  # texture instance id -> ink bottom margin


func setup(texture: Texture2D, scale_factor: float, linger: float) -> void:
	linger_time = linger
	half_height = texture.get_height() * scale_factor * 0.5
	# Place the node so the art's LOWEST INK PIXEL (not the padded canvas edge)
	# lands exactly on the ground line — no hovering, whatever the art's margins.
	standing_y = GROUND_Y - (0.5 - _ink_bottom_margin(texture)) * half_height * 2.0
	hidden_y = SCREEN_BOTTOM + half_height

	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(scale_factor, scale_factor)
	add_child(sprite)

	# Forgiving hitbox around the lower half: the sharp tip doesn't kill.
	var collider := CollisionShape2D.new()
	var ball := CircleShape2D.new()
	ball.radius = maxf(texture.get_width() * scale_factor * 0.5 * 0.55, 4.0)
	collider.shape = ball
	collider.position = Vector2(0, half_height * 0.3)
	collider.name = "Hitbox"
	add_child(collider)

	collision_layer = 2
	collision_mask = 1
	monitoring = true

	position.y = hidden_y


static func _ink_bottom_margin(texture: Texture2D) -> float:
	# Fraction of the canvas height between the lowest ink pixel and the bottom
	# edge. Measured once per texture so spikes always sit flush on the ground.
	var key := texture.get_instance_id()
	if _ink_bottom_cache.has(key):
		return _ink_bottom_cache[key]
	var margin := 0.06  # sensible default if pixels can't be read
	var image := texture.get_image()
	if image != null and (not image.is_compressed() or image.decompress() == OK):
		var found := -1
		for yy in range(image.get_height() - 1, -1, -1):
			for xx in image.get_width():
				if image.get_pixel(xx, yy).a > 0.1:
					found = yy
					break
			if found >= 0:
				break
		if found >= 0:
			margin = float(image.get_height() - 1 - found) / float(image.get_height())
	_ink_bottom_cache[key] = margin
	return margin


func _process(delta: float) -> void:
	age += delta
	if age < RISE_TIME:
		position.y = lerpf(hidden_y, standing_y, age / RISE_TIME)
	elif age < RISE_TIME + linger_time:
		position.y = standing_y
	elif age < RISE_TIME + linger_time + SINK_TIME:
		var t := (age - RISE_TIME - linger_time) / SINK_TIME
		position.y = lerpf(standing_y, hidden_y, t)
	else:
		queue_free()
