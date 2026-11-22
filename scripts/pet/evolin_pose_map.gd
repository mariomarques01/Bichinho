extends Resource

@export var poses: Dictionary[StringName, Texture2D] = {}

func texture_for(state: StringName) -> Texture2D:
	var texture: Texture2D = poses.get(state)
	return texture if texture else poses.get(&"idle")
