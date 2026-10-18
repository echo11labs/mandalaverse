class_name GopalaSimulationClock
extends RefCounted

var paused: bool = true
var speed: int = 1
var logical_tick: int = 0
var elapsed_logical_nanoseconds: int = 0
var _fractional_logical_nanoseconds: int = 0
var _tick_interval_nanoseconds: int = 1_000_000_000

func configure(tick_interval_nanoseconds: int) -> bool:
	if tick_interval_nanoseconds <= 0 or tick_interval_nanoseconds > GopalaSimulationConfig.MAX_ELAPSED_NANOSECONDS:
		return false
	_tick_interval_nanoseconds = tick_interval_nanoseconds
	_fractional_logical_nanoseconds = 0
	return true

func set_paused(value: bool) -> bool:
	if paused == value:
		return false
	paused = value
	return true

func set_speed(value: int) -> bool:
	if value < 1 or value > 4 or speed == value:
		return false
	speed = value
	return true

func advance_frame(delta: float) -> int:
	if paused or not is_finite(delta) or delta <= 0.0 or delta > GopalaSimulationConfig.MAX_RUNTIME_FRAME_SECONDS:
		return 0
	var frame_nanoseconds := roundi(delta * 1_000_000_000.0)
	if frame_nanoseconds <= 0:
		return 0
	var scaled_elapsed := frame_nanoseconds * speed
	if scaled_elapsed > GopalaSimulationConfig.MAX_ELAPSED_NANOSECONDS - elapsed_logical_nanoseconds:
		return 0
	var total_fraction := _fractional_logical_nanoseconds + scaled_elapsed
	var ticks := int(total_fraction / _tick_interval_nanoseconds)
	if ticks > GopalaSimulationConfig.MAX_SEQUENCE - logical_tick:
		return 0
	_fractional_logical_nanoseconds = total_fraction % _tick_interval_nanoseconds
	logical_tick += ticks
	elapsed_logical_nanoseconds += scaled_elapsed
	return ticks

func advance_ticks(count: int) -> bool:
	if paused and count > 0:
		return false
	if count < 0 or count > GopalaSimulationConfig.MAX_MANUAL_TICK_ADVANCE:
		return false
	if count == 0:
		return true
	if count > GopalaSimulationConfig.MAX_SEQUENCE - logical_tick:
		return false
	var extra_nanoseconds := count * _tick_interval_nanoseconds
	if extra_nanoseconds > GopalaSimulationConfig.MAX_ELAPSED_NANOSECONDS - elapsed_logical_nanoseconds:
		return false
	logical_tick += count
	elapsed_logical_nanoseconds += extra_nanoseconds
	return true

func reset() -> void:
	paused = true
	speed = 1
	logical_tick = 0
	elapsed_logical_nanoseconds = 0
	_fractional_logical_nanoseconds = 0
