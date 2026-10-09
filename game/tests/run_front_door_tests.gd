extends SceneTree
var checks := 0
var failures: Array[String] = []
const DIRECTORY := "user://tests/front-door"
func _initialize(): run.call_deferred()
func check(ok: bool, description: String):
	checks += 1
	if not ok: failures.append(description); push_error(description)
func run():
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	for name in ["mvp.json","mvp.json.bak","mvp-2.json","mvp-2.json.bak","mvp-3.json","slots.cfg","settings.cfg"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIRECTORY+"/"+name))
	var old_scale := GopalaUISettings.settings().ui_scale
	var game := GopalaFrontDoor.new()
	game.slots.directory = DIRECTORY
	game.settings.storage_path = DIRECTORY+"/settings.cfg"
	root.add_child(game)
	await process_frame
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/front_door.tscn","Launch scene is front door")
	check(game.world == null and game.page == "main" and game.buttons.continue.disabled,"Launch shows menu and Continue disabled without a save")
	game.buttons.new.pressed.emit()
	game.world.simulation.set_physics_process(false)
	await process_frame
	check(game.page == "playing" and game.world.simulation.paused,"New settlement starts paused")
	check(game.world.simulation.entity_queries().snapshots_by_kind(GopalaEntityKind.VILLAGER).size() == 8,"New settlement has actual eight settlers")
	game.world.hud.button_for(&"dwelling").button_pressed = true
	game.world.hud._show_inspection("Test","Selection","","Body")
	check(game.world.handle_game_escape() == "placement" and not game.world.hud._placement_active,"Escape cancels placement first")
	check(game.world.handle_game_escape() == "panel" and not game.world.hud._inspection.get_parent().visible,"Second Escape closes panel")
	game.world.simulation.set_paused(false)
	game.world.simulation.process_pending_commands()
	game.world.simulation.advance_ticks(3)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game.world._unhandled_input(escape)
	check(game.page == "pause","Third Escape through actual input handler opens pause menu")
	check(game.world.simulation.paused and game.world.menu_input_blocked and game.world.camera.input_blocked,"Pause menu blocks world and camera and pauses authority")
	var tick: int = game.world.simulation.logical_tick
	await physics_frame
	await physics_frame
	check(game.world.simulation.logical_tick == tick,"Menus never advance logical time")
	game.resume()
	check(not game.world.simulation.paused and not game.world.camera.input_blocked,"Resume restores the running state and controls")
	game.open_menu("save")
	check(game.save_slot(0,"Hill camp"),"Save using original MVP filename and schema")
	var saved: Dictionary = game.world._save_service.capture(game.world.simulation,game.world._save_context(),false)
	check(not game.has_unsaved_progress(),"Fresh save has no unsaved progress")
	game.request_save(0,"Hill camp")
	check(game.page == "confirm","Existing slot asks before overwrite")
	game.buttons.cancel.pressed.emit()
	check(game.page == "save","Cancelling overwrite leaves the slot intact")
	game.request_main_menu()
	await process_frame
	check(game.world == null and not game.buttons.continue.disabled,"Save then menu enables Continue")
	game.buttons.continue.pressed.emit()
	game.world.simulation.set_physics_process(false)
	await process_frame
	var restored: Dictionary = game.world._save_service.capture(game.world.simulation,game.world._save_context(),false)
	check(saved == restored,"Save -> menu -> Continue restores identical authoritative state including clock, records, goods and tasks")
	game.world.simulation.set_paused(false)
	game.world.simulation.process_pending_commands()
	game.world.simulation.advance_ticks(1)
	game.open_menu()
	game.request_main_menu()
	check(game.page == "confirm" and game.world != null,"Unsaved gameplay asks before return to main")
	game.buttons.cancel.pressed.emit()
	check(game.page == "pause" and game.world != null,"Cancel preserves live session")
	game.show_page("save")
	game.request_save(0,"Updated camp")
	game.buttons.confirm.pressed.emit()
	check(FileAccess.file_exists(DIRECTORY+"/mvp.json.bak"),"Confirmed overwrite retains backup")
	check(game.save_slot(1,"River camp") and game.slots.rows()[1].name == "River camp","Second named slot saved")
	check(game.save_slot(2,"Forest camp") and game.slots.latest() == 2,"Continue selects most recently saved slot")
	var invalid := FileAccess.open(DIRECTORY+"/mvp-3.json",FileAccess.WRITE)
	invalid.store_string("not json")
	invalid.close()
	check(not game.slots.rows()[2].valid and game.slots.latest() >= 0,"Corrupt slot is disabled; other valid slots remain usable")
	game.show_page("settings")
	game.settings_controls.master.value = 0.4
	game.settings_controls.music.value = 0.25
	game.settings_controls.sfx.value = 0.0
	game.settings_controls.pan_speed.value = 1.8
	game.settings_controls.edge_pan.button_pressed = true
	game.settings_controls.fullscreen.button_pressed = true
	game.settings_controls.ui_scale.value = 1.3
	check(game.world.camera.edge_pan_enabled and is_equal_approx(game.world.camera.pan_speed_multiplier,1.8),"Camera preferences applied live")
	check(is_equal_approx(GopalaUISettings.settings().ui_scale,1.3) and game.world.hud._root.get_theme_font_size("font_size") == 17,"UI scale applied to shared settings and active HUD text")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.4),"Volume buses apply live, zero mutes")
	var restarted := GopalaGameSettings.new()
	restarted.storage_path = DIRECTORY+"/settings.cfg"
	check(restarted.load_from_disk() and restarted.values == game.settings.values,"All settings survive a restart via settings.cfg")
	check(not restarted.set_value("pan_speed",NAN) and not restarted.set_value("fullscreen",1),"Wrong-type and non-finite preferences rejected")
	var persisted := game.settings.values.duplicate()
	game.queue_free()
	await process_frame
	var launch := GopalaFrontDoor.new()
	launch.slots.directory = DIRECTORY
	launch.settings.storage_path = DIRECTORY+"/settings.cfg"
	root.add_child(launch)
	await process_frame
	check(launch.settings.values == persisted and is_equal_approx(GopalaUISettings.settings().ui_scale,1.3),"Actual menu restart loads and applies preferences on launch")
	launch.queue_free()
	await process_frame
	GopalaUISettings.settings().ui_scale = old_scale
	var defaults := GopalaGameSettings.new()
	defaults.apply(null,false)
	GopalaUISettings.settings().ui_scale = old_scale
	print("GOPALA_TEST_REPORT="+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
