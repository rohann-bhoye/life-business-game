extends SceneTree

# Daily report (closed by sleep or midnight, saved) and reputation-driven customer
# traffic. Temporary saves only.
const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("day_report_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _run() -> void:
	# Reputation: 50 is neutral, 100 brings customers 25% sooner, 0 makes them 25% slower.
	var state = Backend.new()
	state.save_path = _path()
	var base: float = state.customer_spawn_interval()
	assert(is_equal_approx(state.reputation_traffic_factor(), 1.0))
	state.customer_reviews.reputation = 100
	assert(is_equal_approx(state.customer_spawn_interval(), base * 0.75))
	state.customer_reviews.reputation = 0
	assert(is_equal_approx(state.customer_spawn_interval(), base * 1.25))
	state.customer_reviews.reputation = 50

	# One day of trade, closed by sleeping.
	assert(state.save_progress())
	assert(state.order_stock("snack") and state.receive_delivery() and state.pick_up_box() and state.shelve_box())
	assert(state.sell_basket(3, 1000, -1, "snack"))
	assert(state.sell_basket(2, 1000, -1, "snack"))
	assert(state.sell_basket(1, 1000))
	assert(state.record_customer_review("sold", 5.0) and state.record_customer_review("sold", 5.0))
	assert(state.grant_home())
	state.advance_clock(1260.0 - state.minutes_of_day)
	assert(state.sleep_until_morning() and state.day == 2)
	var report: Dictionary = state.day_report.last
	assert(report.day == 1 and report.items_sold == 6, str(report))
	assert(report.revenue == 5 * 80 + 100 and report.expenses == 400 and report.profit == 100, str(report))
	assert(report.best == "snack" and report.best_count == 5)
	var cost_total := 0
	for key in report.costs: cost_total += int(report.costs[key])
	assert(report.costs.stock == 400 and cost_total == report.expenses, str(report.costs))
	assert(report.reputation_change == 4 and report.reviews == 2)
	assert(state.day_report.start.day == 2 and state.day_report.start.items_sold == 6)

	# Saved and restored exactly; invalid data is rejected.
	var restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.save_status == "Save: Loaded")
	assert(restored.day_report.last == report and restored.snapshot() == state.snapshot())
	var invalid: Dictionary = state.snapshot()
	invalid.day_report.last.best = "gold"
	assert(not state._is_valid_snapshot(invalid))
	invalid = state.snapshot()
	invalid.day_report.last.costs["gold"] = 5
	assert(not state._is_valid_snapshot(invalid))

	# A day that ends at midnight without sleeping is still closed.
	assert(state.sell_basket(1, 1000))
	state.advance_clock(1440.0 - state.minutes_of_day + 30.0)
	assert(state.day == 3 and state.day_report.last.day == 2 and state.day_report.last.items_sold == 1)

	# In the game: sleeping shows the full report; the next day starts on Space/Enter.
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	var business = current_scene.get_node("Shop/ShopArea").business
	var player = current_scene.get_node("Player")
	var ui = current_scene.get_node("Ui")
	assert(business.grant_home() and business.sell_basket(2, 1000))
	business.advance_clock(1260.0 - business.minutes_of_day)
	player.indoors = true
	player.global_position = Vector3(3.0, 1.1, -4.7)
	for frame in range(3): await physics_frame
	var bed = current_scene.get_node("House/Bed/SleepArea")
	assert(bed.try_sleep())
	var screen = ui.day_report_screen
	assert(screen.visible and player._menu_is_open() and paused, "Report must hold the next day")
	assert(screen.title.text == "END OF DAY 1" and screen.result.text.begins_with("PROFIT"))
	assert(screen.start_button.text == "START DAY 2" and screen.tomorrow.text.begins_with("Tomorrow: Day 2"))
	var labels: Array = screen.income.get_children().map(func(label): return label.text)
	assert(labels.has("Items sold") and labels.has("2"), str(labels))
	await process_frame
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	screen._input(space)
	assert(not screen.visible and not paused and not player._menu_is_open())

	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: daily report on sleep and at midnight, cost breakdown, saved/validated, full-screen report held until Space, reputation changes customer arrival rate")
	quit()
