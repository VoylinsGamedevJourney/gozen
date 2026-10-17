class_name Approximator


const HISTORY_AMOUNT: int = 5000


## Calculating remaining with past 5 seconds of history.
static func calculate_remaining(history: Array[Vector2], current_target: float) -> float:
	var now: int = Time.get_ticks_msec()
	if history.is_empty():
		history.append(Vector2(now, current_target))
		return 0.0

	if now - history[-1].x < 1000:
		return -2.0 # Not enough time has passed to calculate a new rate.

	history.append(Vector2(now, current_target))
	if history.size() < 2:
		return 0.0

	while history.size() > 2 and now - history[0].x > HISTORY_AMOUNT:
		history.pop_front()

	var time_elapsed: float = (history[-1].x - history[0].x) / 1000.0
	var progress_gained: float = history[-1].y - history[0].y
	if progress_gained <= 0.001:
		return -1.0 # Something probably went wrong.

	var rate: float = time_elapsed / progress_gained
	return rate * (100.0 - current_target)
