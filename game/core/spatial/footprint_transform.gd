class_name GopalaFootprintTransform
extends RefCounted

const ROTATION_0 = 0
const ROTATION_90 = 1
const ROTATION_180 = 2
const ROTATION_270 = 3

static func transform_footprint(offsets: Array[Vector2i], rotation: int, anchor: Vector2i) -> Array[Vector2i]:
	if offsets.is_empty():
		return []

	if rotation != ROTATION_0 and rotation != ROTATION_90 and rotation != ROTATION_180 and rotation != ROTATION_270:
		return []

	var result: Array[Vector2i] = []
	var seen = {}

	for offset in offsets:
		var rx: int = offset.x
		var ry: int = offset.y

		if rotation == ROTATION_90:
			var temp = rx
			rx = -ry
			ry = temp
		elif rotation == ROTATION_180:
			rx = -rx
			ry = -ry
		elif rotation == ROTATION_270:
			var temp = rx
			rx = ry
			ry = -temp

		var tx = rx + anchor.x
		var ty = ry + anchor.y

		# integer overflow check (simple boundary)
		if tx > 100000000 or tx < -100000000 or ty > 100000000 or ty < -100000000:
			return []

		var transformed = Vector2i(tx, ty)

		if seen.has(transformed):
			return [] # duplicate source offsets or transformed cells
		seen[transformed] = true

		result.append(transformed)

	result.sort_custom(func(a, b):
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	return result
