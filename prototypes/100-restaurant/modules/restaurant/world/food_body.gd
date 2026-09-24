extends RigidBody2D

var board_velocity := Vector2.ZERO
var board_spin := 0.0
var board_height := 0.0
var board_vertical_speed := 0.0
var board_settling := false
var board_bounds := Rect2()

func begin_board_settle(bounds: Rect2, velocity: Vector2, spin: float, height := 5.0) -> void:
	# A fixed support plane with height/gravity; normal world rigid bodies take over off-board.
	freeze = true
	board_bounds = bounds
	board_velocity = velocity.limit_length(45.0)
	board_spin = clampf(spin, -2.0, 2.0)
	board_height = height
	board_vertical_speed = 0.0
	board_settling = true
	set_meta("on_board", true)

func stop_board_settle() -> void:
	board_settling = false
	board_height = 0.0
	var art := get_node_or_null("FoodArt") as Node2D
	if art: art.position = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not board_settling: return
	if not get_meta("on_board", false):
		stop_board_settle()
		return
	var world := get_parent().get_parent()
	if not world.controls_enabled: return
	var dt := minf(delta, 1.0 / 30.0)
	board_vertical_speed += 260.0 * dt
	board_height = maxf(0.0, board_height - board_vertical_speed * dt)
	position += board_velocity * dt
	position = position.clamp(board_bounds.position, board_bounds.end)
	rotation += board_spin * dt
	var grounded := board_height <= 0.0
	board_velocity = board_velocity.move_toward(Vector2.ZERO, (90.0 if grounded else 6.0) * dt)
	board_spin = move_toward(board_spin, 0.0, (3.8 if grounded else 0.35) * dt)
	var art := get_node_or_null("FoodArt") as Node2D
	if art: art.position = Vector2(0, -board_height)
	if grounded and board_velocity.length() < 0.1 and absf(board_spin) < 0.01: stop_board_settle()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void :
	state.linear_velocity = state.linear_velocity.limit_length(420.0)
	state.angular_velocity = clampf(state.angular_velocity, -8.0, 8.0)
