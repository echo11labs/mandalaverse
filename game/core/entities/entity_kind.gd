class_name GopalaEntityKind
extends RefCounted

const SETTLEMENT: StringName = &"settlement"
const VILLAGER: StringName = &"villager"
const HOUSEHOLD: StringName = &"household"
const BUILDING: StringName = &"building"
const RESOURCE_SOURCE: StringName = &"resource_source"
const ROAD: StringName = &"road"
const CONSTRUCTION_SITE: StringName = &"construction_site"
const TASK: StringName = &"task"
const INVENTORY: StringName = &"inventory"

const ALL: Array[StringName] = [
	SETTLEMENT,
	VILLAGER,
	HOUSEHOLD,
	BUILDING,
	RESOURCE_SOURCE,
	ROAD,
	CONSTRUCTION_SITE,
	TASK,
	INVENTORY,
]

static func is_valid(kind: StringName) -> bool:
	return not kind.is_empty() and kind in ALL
