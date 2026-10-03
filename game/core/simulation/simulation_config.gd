class_name GopalaSimulationConfig
extends RefCounted
## Prototype-wide simulation policy. No calendar or balance assumptions live here.

## Prototype policy: one logical tick represents one logical second. This is
## deliberately a configurable prototype value; the backlog does not prescribe
## a tick duration, and the value is not duplicated at call sites.
const DEFAULT_TICK_INTERVAL_SECONDS: float = 1.0
const SCHEMA_VERSION: int = 1
const MAX_BALANCE: int = 1_000_000_000_000_000
const MAX_SEQUENCE: int = 2_000_000_000
const MAX_ELAPSED_NANOSECONDS: int = 9_000_000_000_000_000
const MAX_PAYLOAD_DEPTH: int = 32
const CAPABILITY_NAMES: Array[StringName] = [
	&"simulation_clock", &"command_queue", &"resource_ledger", &"snapshots",
	&"population", &"housing", &"weather", &"seasons", &"selection", &"placement",
	&"occupancy", &"construction", &"professions", &"production", &"logistics",
	&"alerts", &"save_load",
]
const MAX_RUNTIME_FRAME_SECONDS: float = 86_400.0
const MAX_MANUAL_TICK_ADVANCE: int = 100_000
const MAX_COMMANDS_PER_DRAIN: int = 10_000

## IDs mirror the resource entries in res://data/catalog.json. Balances remain
## empty until an authorized future system supplies them.
const RESOURCE_IDS: Array[StringName] = [
	&"timber", &"stone", &"thatch", &"water", &"wild_food", &"fodder", &"milk",
]

var tick_interval_seconds: float = DEFAULT_TICK_INTERVAL_SECONDS

func tick_interval_nanoseconds() -> int:
	if not is_finite(tick_interval_seconds) or tick_interval_seconds <= 0.0:
		return 0
	if tick_interval_seconds > MAX_RUNTIME_FRAME_SECONDS:
		return 0
	return roundi(tick_interval_seconds * 1_000_000_000.0)
