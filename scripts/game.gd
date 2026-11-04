extends Node2D

const PLAYER_X := 230.0
const GROUND_Y := 575.0
const PLAYER_SIZE := 34.0
const GRAVITY := 1900.0
const JUMP_VELOCITY := -690.0
const SPEED_START := 390.0

var player_y := GROUND_Y - PLAYER_SIZE
var velocity_y := 0.0
var obstacles: Array[Rect2] = []
var particles: Array[Dictionary] = []
var distance := 0.0
var score := 0
var best := 0
var speed := SPEED_START
var started := false
var dead := false
var spawn_timer := 0.0
var pulse := 0.0
var level_time := 0.0
var rng := RandomNumberGenerator.new()
var font: Font

func _ready() -> void:
    rng.randomize()
    font = ThemeDB.fallback_font
    _reset_level()

func _reset_level() -> void:
    player_y = GROUND_Y - PLAYER_SIZE
    velocity_y = 0.0
    obstacles.clear()
    particles.clear()
    distance = 0.0
    score = 0
    speed = SPEED_START
    started = false
    dead = false
    spawn_timer = 1.1
    level_time = 0.0
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _action()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _action()
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
            _action()
        elif event.keycode == KEY_R and dead:
            _reset_level()

func _action() -> void:
    if dead:
        _reset_level()
        return
    if not started:
        started = true
    if is_on_ground():
        velocity_y = JUMP_VELOCITY
        _emit_jump_particles()

func is_on_ground() -> bool:
    return player_y >= GROUND_Y - PLAYER_SIZE - 0.5

func _process(delta: float) -> void:
    pulse += delta * 3.0
    if not started or dead:
        queue_redraw()
        return

    level_time += delta
    distance += speed * delta
    score = int(distance / 55.0)
    speed = min(SPEED_START + level_time * 7.0, 650.0)

    velocity_y += GRAVITY * delta
    player_y += velocity_y * delta
    if player_y > GROUND_Y - PLAYER_SIZE:
        player_y = GROUND_Y - PLAYER_SIZE
        velocity_y = 0.0

    spawn_timer -= delta
    if spawn_timer <= 0.0:
        _spawn_obstacle()
        spawn_timer = rng.randf_range(1.0, 1.65) * (SPEED_START / speed)

    for i in range(obstacles.size() - 1, -1, -1):
        var ob := obstacles[i]
        ob.position.x -= speed * delta
        obstacles[i] = ob
        if ob.end.x < -20:
            obstacles.remove_at(i)
        elif _player_rect().intersects(ob.grow(-5.0)):
            _die()

    _update_particles(delta)
    queue_redraw()

func _player_rect() -> Rect2:
    return Rect2(Vector2(PLAYER_X, player_y), Vector2(PLAYER_SIZE, PLAYER_SIZE))

func _spawn_obstacle() -> void:
    var x := 1320.0
    var count := 1
    if level_time > 18.0 and rng.randf() < 0.25:
        count = 2
    for i in range(count):
        obstacles.append(Rect2(Vector2(x + i * 42.0, GROUND_Y - 42.0), Vector2(38.0, 42.0)))

func _die() -> void:
    dead = true
    best = max(best, score)
    for i in range(22):
        particles.append({
            "pos": Vector2(PLAYER_X + PLAYER_SIZE / 2, player_y + PLAYER_SIZE / 2),
            "vel": Vector2(rng.randf_range(-260, 260), rng.randf_range(-360, 100)),
            "life": rng.randf_range(0.35, 0.8)
        })

func _emit_jump_particles() -> void:
    for i in range(5):
        particles.append({
            "pos": Vector2(PLAYER_X + 10, GROUND_Y - 5),
            "vel": Vector2(rng.randf_range(-130, -20), rng.randf_range(-100, 20)),
            "life": 0.35
        })

func _update_particles(delta: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var p: Dictionary = particles[i]
        p.life -= delta
        p.pos += p.vel * delta
        p.vel.y += 500.0 * delta
        if p.life <= 0:
            particles.remove_at(i)
        else:
            particles[i] = p

func _draw() -> void:
    var w := 1280.0
    var h := 720.0
    draw_rect(Rect2(0, 0, w, h), Color("#08051b"))
    # Distant neon grid
    for x in range(0, 1300, 80):
        draw_line(Vector2(x, 0), Vector2(x, GROUND_Y), Color(0.22, 0.12, 0.48, 0.18), 1.0)
    for y in range(40, int(GROUND_Y), 80):
        draw_line(Vector2(0, y), Vector2(w, y), Color(0.22, 0.12, 0.48, 0.18), 1.0)

    var glow := 0.65 + sin(pulse) * 0.12
    draw_rect(Rect2(0, GROUND_Y, w, 5), Color(0.1, 0.9, 1.0, glow), true)
    draw_rect(Rect2(0, GROUND_Y + 5, w, h - GROUND_Y), Color("#120d2d"))

    # Moving floor markers
    for x in range(-100, 1400, 90):
        var offset := fmod(distance, 90.0)
        draw_line(Vector2(x - offset, GROUND_Y + 30), Vector2(x + 35 - offset, GROUND_Y + 30), Color(0.2, 0.8, 1.0, 0.22), 2)

    for ob in obstacles:
        var pts := PackedVector2Array([
            ob.position,
            Vector2(ob.position.x + ob.size.x / 2, ob.position.y - ob.size.y),
            Vector2(ob.position.x + ob.size.x, ob.position.y)
        ])
        draw_colored_polygon(pts, Color("#ff3e9d"))
        draw_polyline(pts, Color("#ffd2ed"), 3.0, true)

    for p in particles:
        var alpha: float = clamp(p.life, 0.0, 1.0)
        draw_circle(p.pos, 4.0 * alpha, Color(0.0, 0.9, 1.0, alpha))

    if not dead:
        var r := _player_rect()
        draw_rect(r.grow(7), Color(0.0, 0.85, 1.0, 0.12), true)
        draw_rect(r, Color("#21e6ff"), true)
        draw_rect(r.grow(-7), Color("#10234c"), true)
        draw_line(r.position + Vector2(8, 10), r.position + Vector2(25, 10), Color.WHITE, 3)

    _draw_text("NEON RUSH", Vector2(48, 68), 34, Color("#65f4ff"))
    _draw_text("SCORE  %06d" % score, Vector2(48, 112), 20, Color.WHITE)
    _draw_text("BEST   %06d" % best, Vector2(48, 140), 16, Color("#a99bce"))

    if not started and not dead:
        _center_text("TAP TO START", 330, 34, Color.WHITE)
        _center_text("Tap / click / SPACE to jump", 375, 18, Color("#b9b0d7"))
    if dead:
        _center_text("CRASH!", 300, 54, Color("#ff4d9d"))
        _center_text("SCORE  %06d" % score, 355, 24, Color.WHITE)
        _center_text("TAP TO RETRY  •  R", 410, 20, Color("#65f4ff"))

func _draw_text(value: String, pos: Vector2, size: int, color: Color) -> void:
    draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center_text(value: String, y: float, size: int, color: Color) -> void:
    var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    draw_string(font, Vector2((1280.0 - width) / 2.0, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
