extends RigidBody3D
## Recovery is performed inside the physics callback, never by fighting the solver.
const IslandShape = preload("res://game/world/island_shape.gd")
## On the lawn beside the sail loft, a short kick from the coastal trail.
const HOME := Vector3(-56.5, 0.7, 22.6)
var recall_requested := false
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 var p := state.transform.origin
 if recall_requested or p.y < -4.0 or not IslandShape.contains(Vector2(p.x, p.z)):
  state.transform=Transform3D(Basis.IDENTITY,HOME)
  state.linear_velocity=Vector3.ZERO
  state.angular_velocity=Vector3.ZERO
  recall_requested=false
