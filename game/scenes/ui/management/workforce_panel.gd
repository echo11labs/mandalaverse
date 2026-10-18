class_name GopalaWorkforcePanel
extends Window
var simulation: GopalaSettlementSimulation
var _enabled: CheckBox
var _summary: Label
var _rows: Dictionary = {}
var _workers: Dictionary = {}
var _roster: VBoxContainer
var _refreshing := false

func _ready() -> void:
	title = "Settlement workforce"
	visible = false
	exclusive = true
	transient = true
	wrap_controls = false
	min_size = Vector2i(760,580)
	close_requested.connect(hide)
	window_input.connect(func(event):
		if event.is_action_pressed("ui_cancel"):
			hide()
			set_input_as_handled()
	)
	visibility_changed.connect(func():
		if visible: refresh()
	)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",GopalaTheme.flat(GopalaTheme.NAV_SURFACE,4,1,GopalaTheme.NAV_BORDER,12,12))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	_enabled = CheckBox.new()
	_enabled.text = "Automatic workforce · priorities apply when workers become free"
	_enabled.toggled.connect(func(_on): _submit_policy())
	column.add_child(_enabled)
	_summary = Label.new()
	column.add_child(_summary)
	var help := Label.new()
	help.text = "Targets include manual assignments. Off disables new assignments. Busy workers finish their load or build. Material-starved builders can release their site safely."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",12)
	column.add_child(grid)
	for heading in ["Job","Target","Priority","Assigned","Status"]:
		var label := Label.new()
		label.text = heading
		label.add_theme_color_override("font_color",GopalaTheme.BRASS_LIGHT)
		grid.add_child(label)
	for role in GopalaWorkforceService.ROLES:
		var label := Label.new()
		label.text = role.replace("_"," ").capitalize()
		grid.add_child(label)
		var target := SpinBox.new()
		target.min_value = 0
		target.max_value = 128
		target.custom_minimum_size.x = 90
		target.value_changed.connect(func(_amount): _submit_policy())
		grid.add_child(target)
		var priority := OptionButton.new()
		for option in ["Off","Low","Normal","High"]: priority.add_item(option)
		priority.item_selected.connect(func(_index): _submit_policy())
		grid.add_child(priority)
		var assigned := Label.new()
		grid.add_child(assigned)
		var status := Label.new()
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status.clip_text = true
		grid.add_child(status)
		_rows[role] = {"target":target,"priority":priority,"assigned":assigned,"status":status}
	var heading := Label.new()
	heading.text = "SETTLERS · manual assignments stay yours until you enable Auto"
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_roster = VBoxContainer.new()
	_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 32
	close.pressed.connect(hide)
	column.add_child(close)

func bind_simulation(value: GopalaSettlementSimulation) -> void:
	if is_instance_valid(simulation) and simulation.snapshot_committed.is_connected(_on_snapshot): simulation.snapshot_committed.disconnect(_on_snapshot)
	simulation = value
	simulation.snapshot_committed.connect(_on_snapshot)
	refresh()

func _on_snapshot(_snapshot: GopalaSettlementSnapshot) -> void:
	if visible: refresh()

func _submit_policy() -> void:
	if _refreshing or not is_instance_valid(simulation): return
	var jobs := {}
	for role in _rows: jobs[role] = {"target":int(_rows[role].target.value),"priority":_rows[role].priority.selected}
	simulation.submit_command(GopalaSimulationCommand.SET_WORKFORCE_POLICY,{"policy":{"enabled":_enabled.button_pressed,"jobs":jobs}},&"workforce_panel")
	simulation.process_pending_commands()
	refresh()

func refresh() -> void:
	if _enabled == null or not is_instance_valid(simulation): return
	_refreshing = true
	var data := simulation._workforce_service.summary()
	_enabled.set_pressed_no_signal(data.policy.enabled)
	var automatic := 0
	for entry in data.jobs:
		var row: Dictionary = _rows[entry.role]
		row.target.set_value_no_signal(entry.target)
		row.priority.select(entry.priority)
		row.assigned.text = str(entry.assigned)
		row.status.text = _status_label(entry.status)
		row.status.tooltip_text = _status_help(entry.role,entry.status)
	var live := {}
	for entry in data.workers:
		var id: int = entry.id
		live[id] = true
		if entry.automatic: automatic += 1
		if not _workers.has(id): _add_worker(id)
		var row: Dictionary = _workers[id]
		row.auto.set_pressed_no_signal(entry.automatic)
		row.role.select(row.roles.find(entry.role))
		row.role.disabled = entry.role == "construction"
		var pending: String = " → " + entry.pending.capitalize() if entry.pending not in ["",entry.role] else ""
		row.status.text = _status_label(entry.status) + pending + (" · carrying %d" % entry.carried if entry.carried > 0 else "")
		row.status.tooltip_text = row.status.text
	for id in _workers.keys():
		if not live.has(id):
			_workers[id].root.queue_free()
			_workers.erase(id)
	_summary.text = "%d settlers · %d automatic · %s" % [data.workers.size(),automatic,"Running" if not simulation.paused else "Paused — changes start when time runs"]
	_refreshing = false

func _add_worker(id: int) -> void:
	var root_row := HBoxContainer.new()
	root_row.add_theme_constant_override("separation",10)
	_roster.add_child(root_row)
	var name_label := Button.new()
	name_label.text = "Settler #%d" % id
	name_label.custom_minimum_size.x = 95
	name_label.tooltip_text = "Inspect this settler"
	name_label.pressed.connect(func():
		simulation.selection_service().select_entity(id)
		hide()
	)
	root_row.add_child(name_label)
	var auto := CheckBox.new()
	auto.text = "Auto"
	auto.toggled.connect(func(on):
		if _refreshing: return
		simulation.submit_command(GopalaSimulationCommand.SET_WORKER_AUTOMATION,{"villager_id":id,"enabled":on},&"workforce_panel")
		simulation.process_pending_commands()
	)
	root_row.add_child(auto)
	var options := OptionButton.new()
	var roles := ["NONE"] + GopalaWorkforceService.ROLES
	for role in roles: options.add_item("Unassigned" if role == "NONE" else role.replace("_"," ").capitalize())
	options.set_item_disabled(roles.find("construction"),true)
	options.tooltip_text = "Manual resource role. Assign a specific construction site from the settler inspector."
	options.item_selected.connect(func(index):
		if _refreshing or roles[index] == "construction": return
		simulation.submit_command(GopalaSimulationCommand.SET_WORK_ROLE,{"villager_id":id,"role":StringName(roles[index])},&"workforce_panel")
		simulation.process_pending_commands()
		refresh()
	)
	root_row.add_child(options)
	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	root_row.add_child(status)
	_workers[id] = {"root":root_row,"auto":auto,"role":options,"roles":roles,"status":status}

func _status_label(value: String) -> String:
	return str({"NO_SITE":"No unfinished sites","NO_SOURCE":"No available source","NO_FREE_WORKER":"Waiting for a settler","STORAGE_FULL":"No storage space","NO_SUPPORTED_HERD":"Needs pasture + shelter","AUTOMATION_OFF":"Automation off","DISABLED":"Priority off","NO_TARGET":"Target is zero","SITES_STAFFED":"All sites staffed"}.get(value,value.replace("_"," ").capitalize()))

func _status_help(role: String, status: String) -> String:
	if status == "NO_SOURCE" and role == "water": return "Build and finish a water point to provide a collection source."
	if status == "NO_SUPPORTED_HERD": return "Assign cattle to a pasture and provide a completed cattle shelter."
	if status == "NO_SITE": return "Plan a building or a path. Builders use existing physical hauling and labor."
	if status == "NO_FREE_WORKER": return "Busy settlers finish their current load or build. Reduce other targets, change priorities, or enrol a manual worker."
	if status == "STORAGE_FULL": return "Build storage or consume stock; workers resume when capacity becomes available."
	return _status_label(status)
