extends RefCounted
## Shared wall-clock budget scale for native review fixtures on slower machines.
## SNAPLAND_REVIEW_WALL_SCALE only lengthens limits (values below 1 or invalid are ignored),
## so default runs keep the original budgets.

const ENV_NAME := "SNAPLAND_REVIEW_WALL_SCALE"

static func factor() -> float:
	var raw := OS.get_environment(ENV_NAME).strip_edges()
	return maxf(1.0, float(raw)) if raw.is_valid_float() else 1.0

static func seconds(base: float) -> float:
	return base * factor()
