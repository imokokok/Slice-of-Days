extends RigidBody2D

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void :
	state.linear_velocity = state.linear_velocity.limit_length(420.0)
	state.angular_velocity = clampf(state.angular_velocity, -8.0, 8.0)
