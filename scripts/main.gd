extends Node2D
## big world, little guy
## You are 16 pixels tall. Everything else is enormous.
## Survive 60 seconds of raining giant shapes.

enum State { TITLE, PLAYING, SQUASHED, SURVIVED }

const SCREEN_W := 640.0
const SCREEN_H := 360.0
const GROUND_H := 24.0
const PARALLAX_PX := 14.0  # how far the backdrop leans as the little guy runs
const GAME_TIME := 60.0
const SPAWN_EARLY := 1.3   # seconds between spawns at the start
const SPAWN_LATE := 0.5    # seconds between spawns at the end
const SPEED_EARLY := Vector2(95.0, 165.0)   # initial fall speed range (shapes accelerate after that)
const ACCEL_EARLY := Vector2(90.0, 150.0)   # fall acceleration range: slow at spawn, fast at impact
const DIFFICULTY_TAPER := 0.5               # extra speed/accel multiplier by the end
const SPIKE_FIRST := 9.0                    # seconds played before the first ground spike
const SPIKE_EARLY := 4.5                    # seconds between spikes at the start
const SPIKE_LATE := 2.2                     # seconds between spikes at the end
const SPIKE_MIN_DIST := 90.0                # min px between two spikes
const SPIKE_PLAYER_BUFFER := 80.0           # spikes never spawn this close to the little guy

var rng := RandomNumberGenerator.new()
var state: int = State.TITLE
var elapsed := 0.0
var spawn_cooldown := 0.0
var spike_cooldown := 0.0
var shapes: Array = []
var spikes: Array = []
var shape_textures: Array = []

var player: LittleGuy
var background_sprite: Sprite2D
var shapes_root: Node2D
var ui: CanvasLayer
var time_label: Label
var bar_bg: ColorRect
var bar_fill: ColorRect
var title_root: Control
var end_root: Control
var end_title: Label
var end_sub: Label
var music_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var ui_font: Font


func _ready() -> void:
	_register_input_actions()
	rng.randomize()
	ui_font = Art.ui_font()
	shape_textures = Art.shape_textures()
	_build_world()
	_build_ui()
	_setup_audio()
	_show_title()
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke_test()


func _build_world() -> void:
	# Background image (drop art/background.png, 640x360) — drawn behind everything.
	var bg_texture := Art.background_texture()
	if bg_texture != null:
		background_sprite = Sprite2D.new()
		background_sprite.texture = bg_texture
		background_sprite.position = Vector2(SCREEN_W * 0.5, SCREEN_H * 0.5)
		# Wider than the screen so parallax shifting never exposes an edge.
		background_sprite.scale = Vector2(
			(SCREEN_W + 2.0 * PARALLAX_PX) / bg_texture.get_width(),
			SCREEN_H / bg_texture.get_height())
		add_child(background_sprite)

	# Solid platform along the bottom so the little guy visibly stands on something.
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(0, SCREEN_H - GROUND_H),
		Vector2(SCREEN_W, SCREEN_H - GROUND_H),
		Vector2(SCREEN_W, SCREEN_H),
		Vector2(0, SCREEN_H),
	])
	ground.color = Art.DARK_GRAY
	add_child(ground)

	# Bright teal top edge — reads as a neon floor line against the dark backdrop.
	var ground_line := Polygon2D.new()
	ground_line.polygon = PackedVector2Array([
		Vector2(0, SCREEN_H - GROUND_H),
		Vector2(SCREEN_W, SCREEN_H - GROUND_H),
		Vector2(SCREEN_W, SCREEN_H - GROUND_H + 2.0),
		Vector2(0, SCREEN_H - GROUND_H + 2.0),
	])
	ground_line.color = Art.TEAL
	add_child(ground_line)

	player = LittleGuy.new()
	player.position = Vector2(SCREEN_W * 0.5, SCREEN_H - GROUND_H - 8.0)
	add_child(player)
	player.area_entered.connect(_on_player_area_entered)

	# Shapes root added last so falling giants draw on top of the little guy.
	shapes_root = Node2D.new()
	add_child(shapes_root)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	bar_bg = ColorRect.new()
	bar_bg.position = Vector2(0, 0)
	bar_bg.size = Vector2(SCREEN_W, 6)
	bar_bg.color = Art.DARK_GRAY
	ui.add_child(bar_bg)

	bar_fill = ColorRect.new()
	bar_fill.position = Vector2(0, 0)
	bar_fill.size = Vector2(0, 6)
	bar_fill.color = Art.TEAL
	ui.add_child(bar_fill)

	time_label = _make_label("0 / 60 s", 16, Art.WHITE, Vector2(0, 10))
	ui.add_child(time_label)

	# Intro lines are stacked using the font's real line metrics, so the
	# backing plates can never overlap regardless of font size.
	title_root = Control.new()
	ui.add_child(title_root)
	var y := 64.0
	title_root.add_child(_make_label("big world, little guy", 28, Art.WHITE, Vector2(0, y)))
	y += _line_advance(28, 1)
	title_root.add_child(_make_label("you are very small.\neverything else is very big.", 14, Art.LIGHT_GRAY, Vector2(0, y)))
	y += _line_advance(14, 2)
	title_root.add_child(_make_label("move with  <- ->  or  A D   |   jump with  SPACE", 14, Art.LIGHT_GRAY, Vector2(0, y)))
	y += _line_advance(14, 1)
	title_root.add_child(_make_label("survive 60 seconds", 14, Art.LIGHT_GRAY, Vector2(0, y)))
	y += _line_advance(14, 1)
	title_root.add_child(_make_label("press ENTER to start", 16, Art.WHITE, Vector2(0, y)))

	end_root = Control.new()
	ui.add_child(end_root)
	var end_y := 120.0
	end_title = _make_label("", 28, Art.WHITE, Vector2(0, end_y))
	end_y += _line_advance(28, 1)
	end_sub = _make_label("", 14, Art.LIGHT_GRAY, Vector2(0, end_y))
	end_y += _line_advance(14, 2)
	end_root.add_child(end_title)
	end_root.add_child(end_sub)
	end_root.add_child(_make_label("press ENTER to try again", 16, Art.WHITE, Vector2(0, end_y)))


func _make_label(text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(SCREEN_W, float(font_size) * 3.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if ui_font != null:
		label.add_theme_font_override("font", ui_font)
	# Dark backing plate so text never blends into the busy background.
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Art.NEAR_BLACK.r, Art.NEAR_BLACK.g, Art.NEAR_BLACK.b, 0.85)
	style.border_color = Color(1.0, 1.0, 1.0, 0.15)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.z_index = -1  # draws under the label's text
	label.add_child(panel)
	label.set_meta("backing_panel", panel)
	_fit_panel(label, panel)
	return label


func _fit_panel(label: Label, panel: Panel) -> void:
	# Size the plate to the widest line of text (coordinates are label-local).
	var font := label.get_theme_font("font")
	var font_size := int(label.get_theme_font_size("font_size"))
	var lines := label.text.split("\n")
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_h := font.get_height(font_size)
	panel.position = Vector2((SCREEN_W - widest) * 0.5 - 14.0, -6.0)
	panel.size = Vector2(widest + 28.0, float(lines.size()) * line_h + 12.0)


func _set_block_text(label: Label, text: String) -> void:
	label.text = text
	var panel = label.get_meta("backing_panel", null)
	if panel != null:
		_fit_panel(label, panel)


func _line_advance(font_size: int, lines: int) -> float:
	# Vertical space a stacked block occupies: its backing plate + an 8px gap.
	# Uses the same math as _fit_panel, so plates are exactly non-overlapping.
	var line_h := ui_font.get_height(font_size) if ui_font != null else float(font_size) * 1.4
	return line_h * float(lines) + 12.0 + 8.0


func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	var music := Art.music_stream()
	if music != null:
		# Not played here: the ost starts with a run (ENTER) and stops at the end screen.
		music_player.stream = Art.make_looping(music)

	hit_player = AudioStreamPlayer.new()
	add_child(hit_player)
	var hit := Art.hit_stream()
	if hit != null:
		hit_player.stream = hit


func _register_input_actions() -> void:
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("jump", [KEY_SPACE, KEY_UP, KEY_W])
	_add_action("confirm", [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm") and state != State.PLAYING:
		_start_game()


func _process(delta: float) -> void:
	# Backdrop drifts opposite to the little guy — classic parallax, feels alive.
	if background_sprite != null:
		var from_center := (player.position.x - SCREEN_W * 0.5) / (SCREEN_W * 0.5)
		background_sprite.position.x = SCREEN_W * 0.5 - from_center * PARALLAX_PX
	if state != State.PLAYING:
		return
	elapsed += delta
	var shown := mini(int(floor(elapsed)), int(GAME_TIME))
	time_label.text = "%d / %d s" % [shown, int(GAME_TIME)]
	bar_fill.size.x = SCREEN_W * clampf(elapsed / GAME_TIME, 0.0, 1.0)

	spawn_cooldown -= delta
	if spawn_cooldown <= 0.0:
		_spawn_shape()
		var difficulty := clampf(elapsed / GAME_TIME, 0.0, 1.0)
		spawn_cooldown = lerpf(SPAWN_EARLY, SPAWN_LATE, difficulty) + rng.randf_range(-0.15, 0.15)

	if elapsed >= SPIKE_FIRST:
		spike_cooldown -= delta
		if spike_cooldown <= 0.0 and spikes.size() < 3:
			_spawn_spike()
			var difficulty := clampf(elapsed / GAME_TIME, 0.0, 1.0)
			spike_cooldown = lerpf(SPIKE_EARLY, SPIKE_LATE, difficulty) + rng.randf_range(-0.4, 0.4)

	if elapsed >= GAME_TIME:
		_end_game(true)


func _spawn_shape() -> void:
	var texture: Texture2D = shape_textures[rng.randi_range(0, shape_textures.size() - 1)]
	var scale_factor := rng.randf_range(0.45, 0.8)
	var half_w := texture.get_width() * scale_factor * 0.5

	# Anti-wall guard: don't spawn on top of a shape still hanging out up high.
	var x := SCREEN_W * 0.5
	for attempt in 10:
		x = rng.randf_range(half_w, SCREEN_W - half_w)
		var blocked := false
		for shape in shapes:
			if is_instance_valid(shape) and shape.position.y < 260.0:
				if absf(shape.position.x - x) < (half_w + shape.half_size) * 0.8:
					blocked = true
					break
		if not blocked:
			break

	var difficulty := clampf(elapsed / GAME_TIME, 0.0, 1.0)
	var mult := 1.0 + difficulty * DIFFICULTY_TAPER
	var speed := rng.randf_range(SPEED_EARLY.x, SPEED_EARLY.y) * mult
	var accel := rng.randf_range(ACCEL_EARLY.x, ACCEL_EARLY.y) * mult

	var shape := GiantShape.new()
	shape.setup(texture, scale_factor, speed, accel)
	shape.position = Vector2(x, -half_w)
	shape.tree_exited.connect(func(): shapes.erase(shape))
	shapes_root.add_child(shape)
	shapes.append(shape)


func _spawn_spike() -> void:
	var texture := Art.triangle_texture()
	var scale_factor := rng.randf_range(0.18, 0.26)
	var difficulty := clampf(elapsed / GAME_TIME, 0.0, 1.0)
	var linger := lerpf(2.6, 3.8, difficulty)

	# Never right on top of the little guy, and keep spikes from clumping.
	var x := SCREEN_W * 0.5
	for attempt in 10:
		x = rng.randf_range(40.0, SCREEN_W - 40.0)
		if absf(x - player.position.x) < SPIKE_PLAYER_BUFFER:
			continue
		var crowded := false
		for spike in spikes:
			if is_instance_valid(spike) and absf(spike.position.x - x) < SPIKE_MIN_DIST:
				crowded = true
				break
		if not crowded:
			break

	var spike := GroundSpike.new()
	spike.setup(texture, scale_factor, linger)
	spike.position = Vector2(x, spike.position.y)
	spike.tree_exited.connect(func(): spikes.erase(spike))
	shapes_root.add_child(spike)
	spikes.append(spike)


func _on_player_area_entered(area: Area2D) -> void:
	if state != State.PLAYING:
		return
	if area is GiantShape or area is GroundSpike:
		_end_game(false)


func _end_game(won: bool) -> void:
	state = State.SURVIVED if won else State.SQUASHED
	player.enabled = false
	for shape in shapes:
		if is_instance_valid(shape):
			shape.set_process(false)
	for spike in spikes:
		if is_instance_valid(spike):
			spike.set_process(false)
	if hit_player.stream != null and not won:
		hit_player.play()
	if music_player.stream != null:
		music_player.stop()  # silence while you read your fate

	bar_bg.visible = false
	bar_fill.visible = false
	time_label.visible = false
	end_root.visible = true
	if won:
		_set_block_text(end_title, "you survived!")
		_set_block_text(end_sub, "still just a little guy,\nbecause the world is big.")
	else:
		_set_block_text(end_title, "you got squashed.")
		_set_block_text(end_sub, "you were small, and the world was big.\nyou survived %.1f seconds." % maxf(elapsed, 0.0))


func _show_title() -> void:
	state = State.TITLE
	player.enabled = false
	player.position.x = SCREEN_W * 0.5
	title_root.visible = true
	end_root.visible = false
	bar_bg.visible = false
	bar_fill.visible = false
	time_label.visible = false


func _start_game() -> void:
	for shape in shapes:
		if is_instance_valid(shape):
			shape.queue_free()
	shapes.clear()
	for spike in spikes:
		if is_instance_valid(spike):
			spike.queue_free()
	spikes.clear()

	elapsed = 0.0
	spawn_cooldown = 0.8
	spike_cooldown = 0.0
	state = State.PLAYING
	player.enabled = true
	player.position.x = SCREEN_W * 0.5
	title_root.visible = false
	end_root.visible = false
	bar_bg.visible = true
	bar_fill.visible = true
	bar_fill.size.x = 0.0
	time_label.visible = true
	time_label.text = "0 / 60 s"
	if music_player.stream != null:
		music_player.play()  # every run gets the ost from the top


func _run_smoke_test() -> void:
	print("SMOKE: starting game...")
	print("SMOKE: font loaded=%s  music loaded=%s" % [ui_font != null, music_player.stream != null])
	_start_game()
	for i in 20:
		_spawn_shape()
	_spawn_spike()
	await get_tree().process_frame
	await get_tree().process_frame
	var shapes_spawned: bool = shapes.size() > 0
	var spikes_spawned: bool = spikes.size() > 0

	# 1. The jump must clear the tallest possible ground spike.
	var worst_spike := GroundSpike.new()
	shapes_root.add_child(worst_spike)
	worst_spike.setup(Art.triangle_texture(), 0.26, 0.0)  # max scale
	worst_spike.position.y = worst_spike.standing_y       # fully risen
	var hitbox: CollisionShape2D = worst_spike.get_node("Hitbox")
	var deadly_top: float = worst_spike.position.y + hitbox.position.y - (hitbox.shape as CircleShape2D).radius
	var peak_feet: float = LittleGuy.FLOOR_Y - (LittleGuy.JUMP_VELOCITY * LittleGuy.JUMP_VELOCITY) / (2.0 * LittleGuy.GRAVITY)
	var jump_clears: bool = peak_feet < deadly_top
	print("SMOKE: spike deadly top=%.1f, jump peak feet=%.1f -> %s" % [deadly_top, peak_feet, "CLEAR" if jump_clears else "BLOCKED"])

	# 2. Horizontal reach during a full jump must exceed any spike's width.
	var air_time: float = 2.0 * LittleGuy.JUMP_VELOCITY / LittleGuy.GRAVITY
	var reach: float = air_time * LittleGuy.SPEED
	var widest_spike: float = 256.0 * 0.26
	var reach_ok: bool = reach > widest_spike
	print("SMOKE: jump reach=%.0fpx vs widest spike=%.0fpx -> %s" % [reach, widest_spike, "OK" if reach_ok else "STUCK"])

	# 3. Player clamps inside the screen at both edges.
	player.position.x = -100.0
	player._process(0.016)
	var clamp_left: bool = player.position.x >= player.sprite.texture.get_width() * 0.5 - 0.01
	player.position.x = 9999.0
	player._process(0.016)
	var clamp_right: bool = player.position.x <= SCREEN_W - player.sprite.texture.get_width() * 0.5 + 0.01
	player.position.x = SCREEN_W * 0.5

	# 4. Max-difficulty spawns stay on screen, finite, and above ground.
	elapsed = 59.0
	for i in 30:
		_spawn_shape()
	_spawn_spike()
	var bounds_ok := true
	for shape in shapes:
		if not is_instance_valid(shape):
			continue
		if shape.position.x < -1.0 or shape.position.x > SCREEN_W + 1.0 or is_nan(shape.position.x) or is_nan(shape.position.y):
			bounds_ok = false
			break

	# 5. Spike lifecycle: rise, linger, sink, and free itself.
	var life_spike := GroundSpike.new()
	shapes_root.add_child(life_spike)
	life_spike.setup(Art.triangle_texture(), 0.26, 0.0)
	life_spike._process(10.0)
	var lifecycle_ok: bool = life_spike.is_queued_for_deletion()
	worst_spike.queue_free()
	life_spike.queue_free()
	elapsed = 0.0

	_end_game(false)
	await get_tree().process_frame
	_start_game()
	await get_tree().process_frame
	var passed: bool = (shapes_spawned and spikes_spawned and state == State.PLAYING
			and jump_clears and reach_ok and clamp_left and clamp_right and bounds_ok and lifecycle_ok
			and ui_font != null and music_player.stream != null)
	if not passed:
		print("SMOKE: jump_clears=%s reach_ok=%s clamp=%s/%s bounds=%s lifecycle=%s" % [
			jump_clears, reach_ok, clamp_left, clamp_right, bounds_ok, lifecycle_ok])
	print("SMOKE OK" if passed else "SMOKE FAIL")
	get_tree().quit(0 if passed else 1)
