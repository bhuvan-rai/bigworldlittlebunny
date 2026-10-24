class_name Art
extends RefCounted
## Loads real art/audio from res://art and res://audio if those files exist,
## otherwise draws placeholder graphics in code so the game always runs.
## Just drop your PNGs in and they appear automatically.

const WHITE := Color("fcfbfc")
const LIGHT_GRAY := Color("d9d4d8")
const NEAR_BLACK := Color("2d2732")
const DARK_GRAY := Color("514d4a")
const ROSE := Color("9e696b")
const TEAL := Color("009c89")
const PURPLE := Color("735fb1")
const GREEN := Color("6da16b")


static func player_texture() -> Texture2D:
	return _texture_or_placeholder("res://art/player.png", _placeholder_player())


static func shape_textures() -> Array:
	return [
		_texture_or_placeholder("res://art/shape_square.png", _placeholder_square()),
		_texture_or_placeholder("res://art/shape_circle.png", _placeholder_circle()),
		_texture_or_placeholder("res://art/shape_triangle.png", _placeholder_triangle()),
		_texture_or_placeholder("res://art/shape_blob.png", _placeholder_blob()),
	]


static func music_stream() -> AudioStream:
	for path in ["res://audio/bgm.ogg", "res://audio/bgm.mp3", "res://audio/bgm.wav"]:
		if FileAccess.file_exists(path):
			var stream = load(path)
			if stream is AudioStream:
				return stream
	return null


static func hit_stream() -> AudioStream:
	for path in ["res://audio/sfx_hit.wav", "res://audio/sfx_hit.ogg"]:
		if FileAccess.file_exists(path):
			var stream = load(path)
			if stream is AudioStream:
				return stream
	return null


static func make_looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


static func ui_font() -> Font:
	if FileAccess.file_exists("res://fonts/game.ttf"):
		var resource = load("res://fonts/game.ttf")
		if resource is Font:
			return resource
	return null


static func triangle_texture() -> Texture2D:
	return _texture_or_placeholder("res://art/shape_triangle.png", _placeholder_triangle())


static func background_texture() -> Texture2D:
	if FileAccess.file_exists("res://art/background.png"):
		var resource = load("res://art/background.png")
		if resource is Texture2D:
			return resource
	return null


static func _texture_or_placeholder(path: String, placeholder: Image) -> Texture2D:
	if FileAccess.file_exists(path):
		var resource = load(path)
		if resource is Texture2D:
			return resource
	return ImageTexture.create_from_image(placeholder)


static func _placeholder_player() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(NEAR_BLACK)
	img.fill_rect(Rect2i(3, 5, 3, 4), WHITE)  # left eye
	img.fill_rect(Rect2i(10, 5, 3, 4), WHITE)  # right eye
	return img


static func _placeholder_square() -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(ROSE)
	return img


static func _placeholder_circle() -> Image:
	return _circle_image(256, TEAL)


static func _placeholder_triangle() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size * 0.5
	for y in size:
		var t := float(y) / float(size - 1)
		var half := t * center
		img.fill_rect(Rect2i(int(center - half), y, int(half * 2.0), 1), PURPLE)
	return img


static func _placeholder_blob() -> Image:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - center + 0.5, y - center + 0.5)
			var angle := atan2(d.y, d.x)
			var wobble := 1.0 + 0.08 * sin(angle * 5.0)
			if d.length() <= center * 0.9 * wobble:
				img.set_pixel(x, y, GREEN)
	return img


static func _circle_image(size: int, color: Color) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size * 0.5
	for y in size:
		for x in size:
			if Vector2(x - center + 0.5, y - center + 0.5).length() <= center:
				img.set_pixel(x, y, color)
	return img
