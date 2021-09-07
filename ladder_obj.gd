extends MeshInstance


onready var ladder_dir = -global_transform.basis.z.normalized()
onready var pos = global_transform.origin + ladder_dir * scale.z
onready var height = scale.y

func _process(delta):
	DebugDraw.draw_line_3d(pos, pos + -global_transform.basis.z * 10.0, Color.red)
