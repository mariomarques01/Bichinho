extends RefCounted

const INTERVAL := 3.85
const DURATION := 0.23

static func closure(elapsed: float) -> float:
	var phase := clampf((fmod(elapsed, INTERVAL) - INTERVAL + DURATION) / DURATION, 0.0, 1.0)
	return sin(phase * PI)
