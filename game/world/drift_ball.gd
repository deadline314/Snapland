extends RigidBody3D
## Recovery is performed inside the physics callback, never by fighting the solver.
const HOME := Vector3(-24.0, 0.7, 5.1)
var recall_requested := false
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 var p := state.transform.origin
 if recall_requested or p.y < -4.0 or absf(p.x)>36.0 or p.z < -78.0 or p.z>28.0:
  state.transform=Transform3D(Basis.IDENTITY,HOME)
  state.linear_velocity=Vector3.ZERO
  state.angular_velocity=Vector3.ZERO
  recall_requested=false
