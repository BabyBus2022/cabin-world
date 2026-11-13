extends RefCounted

## The near side of a bed may extend below its standing exit anchor.
static func sort(feet: Vector2, stage: Dictionary, modules: Dictionary) -> float:
	var depth: float = float(stage.get("sort", feet.y))
	if stage.get("front", "") == "quilt" or stage.get("seat", false):
		return depth
	for module in modules.values():
		if module.get("kind", "") != "bed":
			continue
		var right: float = float(module.x) + float(module.w)
		var bottom: float = float(module.y) + float(module.h)
		if feet.x >= right - 2.0 and feet.x <= right + 32.0 and feet.y >= bottom - 55.0 and feet.y <= bottom + 16.0:
			depth = maxf(depth, float(module.get("depth", bottom)) + 0.1)
	return depth
