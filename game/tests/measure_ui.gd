extends SceneTree
## Layout facts a screenshot would reveal. Reports how much of the screen the
## interface occupies, whether plates collide or overflow, and whether any plate
## is squeezed smaller than its content needs.

func run() -> void:
	for target in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		await _measure(target)
	_finish()

func _measure(target: Vector2i) -> void:
	var hud := load("res://scenes/ui/hud.tscn").instantiate() as GopalaKathmanduHud
	root.size = target
	root.add_child(hud)
	var terrain := GopalaKathmanduTerrain.new()
	terrain.load_data()
	hud.configure_survey(terrain, [])
	for i in 5:
		await process_frame

	var viewport_area := float(target.x * target.y)
	var plates: Array = []
	var covered := 0.0
	for child in hud._root.get_children():
		if not (child is Control):
			continue
		var control: Control = child
		if not control.visible:
			continue
		var rect := control.get_global_rect()
		covered += rect.size.x * rect.size.y
		plates.append({
			"name": control.name,
			"rect": [snappedf(rect.position.x, 1), snappedf(rect.position.y, 1), snappedf(rect.size.x, 1), snappedf(rect.size.y, 1)],
			"needs": [snappedf(control.get_combined_minimum_size().x, 1), snappedf(control.get_combined_minimum_size().y, 1)],
			"squeezed": control.get_combined_minimum_size().y > rect.size.y + 1.0 or control.get_combined_minimum_size().x > rect.size.x + 1.0,
			"outside": rect.position.x < -1 or rect.position.y < -1 or rect.end.x > target.x + 1 or rect.end.y > target.y + 1,
		})

	var overlaps := []
	for i in plates.size():
		for j in range(i + 1, plates.size()):
			var a: Rect2 = Rect2(Vector2(plates[i]["rect"][0], plates[i]["rect"][1]), Vector2(plates[i]["rect"][2], plates[i]["rect"][3]))
			var b: Rect2 = Rect2(Vector2(plates[j]["rect"][0], plates[j]["rect"][1]), Vector2(plates[j]["rect"][2], plates[j]["rect"][3]))
			if a.intersects(b):
				overlaps.append([plates[i]["name"], plates[j]["name"]])

	# Control census: how much of the interface is text, buttons, or icons.
	var buttons := 0
	var labels := 0
	var glyph_buttons := []
	for node in hud._root.find_children("*", "Button", true, false):
		var button := node as Button
		buttons += 1
		# Any button whose only label is a symbol depends on the font shipping it.
		if button.text.strip_edges().length() <= 2 and button.icon == null:
			glyph_buttons.append(button.tooltip_text)
	for node in hud._root.find_children("*", "Label", true, false):
		labels += 1

	print("UI_MEASURE=", JSON.stringify({
		"viewport": [target.x, target.y],
		"chrome_coverage_pct": snappedf(covered / viewport_area * 100.0, 1),
		"plate_count": plates.size(),
		"plates": plates,
		"overlaps": overlaps,
		"buttons": buttons,
		"labels": labels,
		"symbol_only_buttons": glyph_buttons.size(),
		"symbol_only_tooltips": glyph_buttons,
	}))
	hud.queue_free()
	await process_frame

func _initialize() -> void:
	run.call_deferred()

func _finish() -> void:
	quit(0)