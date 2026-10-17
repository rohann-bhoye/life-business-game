extends SceneTree

# APNA Bank loan, rainy/sunny weather, the Sharma General Store rival, and the
# in-game music/rain/bank wiring. Temporary saves only.
const Backend := preload("res://business_backend.gd")
var paths: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _path() -> String:
	var path := OS.get_environment("TEMP").path_join("economy_world_%d.json" % Time.get_ticks_usec())
	paths.append(path)
	return path

func _run() -> void:
	# --- Bank loan ---
	var state = Backend.new()
	state.save_path = _path()
	var money: int = state.money
	assert(state.loan_daily_payment_for_new() == 2200 and state.loan_left() == 0)
	assert(state.take_loan() and not state.take_loan(), "Only one loan at a time")
	assert(state.money == money + 20000 and state.loan_left() == 20000 and state.loan_payoff_amount() == 22000)
	assert(state._is_valid_snapshot(state.snapshot()))
	money = state.money
	state.advance_clock(1440.0)
	assert(state.day == 2 and state.loan_left() == 18000 and state.loan_interest_paid == 200)
	assert(state.money == money - 2200 - 100, "Instalment plus the daily shop bill")
	assert(state._is_valid_snapshot(state.snapshot()))
	var restored = Backend.new()
	restored.load_progress(state.save_path)
	assert(restored.save_status == "Save: Loaded" and restored.loan_left() == 18000)
	assert(state.repay_loan() and state.loan_left() == 0 and state.loan_interest_paid == 2000)
	assert(state._is_valid_snapshot(state.snapshot()))
	var invalid: Dictionary = state.snapshot()
	invalid.loan_interest_paid = 1999
	assert(not state._is_valid_snapshot(invalid))
	var broke = Backend.new()
	assert(broke.take_loan())
	broke.money = 50
	broke._pay_loan_installments(1)
	assert(broke.loan_missed_payments == 1 and broke.loan_left() == 20000, "Missed payment waits")

	# --- Weather ---
	assert(Backend.weather_for_day(1) == "sunny")
	var rainy := -1
	for day_number in range(2, 80):
		if Backend.weather_for_day(day_number) == "rain":
			rainy = day_number
			break
	assert(rainy > 0, "Some days must be rainy")
	assert(Backend.weather_for_day(rainy) == Backend.weather_for_day(rainy), "Forecast is stable")
	var weather = Backend.new()
	weather.save_path = ""
	weather.day = rainy - 1 if Backend.weather_for_day(rainy - 1) == "sunny" else 1
	var sunny_interval: float = weather.customer_spawn_interval()
	weather.day = rainy
	assert(weather.is_raining())
	assert(weather.customer_spawn_interval() > sunny_interval, "Rain brings fewer customers")
	weather.day = 1
	weather.save_path = _path()
	assert(weather.buy_seeds(1) and weather.plant_crop(0))
	assert(weather.farm.plots[0].watered_at < 0)
	weather.day = rainy
	weather.minutes_of_day = 480.0
	weather._rain_waters_farm()
	assert(weather.farm.plots[0].watered_at >= 0, "Rain waters planted beds")

	# --- Rival shop ---
	var market = Backend.new()
	market.save_path = ""
	assert(not market.rival_open() and is_equal_approx(market.rival_traffic_factor(), 1.0))
	market.day = 3
	if market.is_raining(): market.day = 4 if not Backend.weather_for_day(4) == "rain" else 5
	assert(market.rival_open())
	var fair: float = market.rival_traffic_factor()
	assert(market.set_selling_price(130))
	assert(market.price_index() > 1.25 and market.rival_traffic_factor() > fair, "Expensive prices lose customers to Sharma")
	assert(market.set_selling_price(80))
	assert(market.price_index() < 1.0 and market.rival_traffic_factor() < fair, "Cheaper prices win customers")
	market.customer_reviews.reputation = 100
	assert(market.rival_traffic_factor() >= 0.85)

	# --- Beginner money: New Game starts small; older saves (no field) keep 50,000 ---
	var beginner = Backend.new()
	beginner.save_path = _path()
	beginner.starting_money = Backend.BEGINNER_MONEY
	beginner.money = Backend.BEGINNER_MONEY
	assert(beginner.save_progress())
	var reloaded = Backend.new()
	reloaded.load_progress(beginner.save_path)
	assert(reloaded.save_status == "Save: Loaded" and reloaded.money == 10000 and reloaded.starting_money == 10000)
	var legacy: Dictionary = Backend.new().snapshot()
	legacy.erase("starting_money")
	assert(beginner._is_valid_snapshot(legacy), "Saves from before keep their 50,000 start")
	var cheat: Dictionary = reloaded.snapshot()
	cheat.starting_money = 99999
	cheat.money = 99999
	assert(not beginner._is_valid_snapshot(cheat), "Only real starting amounts are accepted")

	# --- Price war: Sharma's deterministic daily sale ---
	assert(Backend.rival_sale_for_day(2).is_empty())
	var sale_days := 0
	for day_number in range(3, 43):
		var offer: Dictionary = Backend.rival_sale_for_day(day_number)
		assert(offer == Backend.rival_sale_for_day(day_number), "The daily sale is deterministic")
		if offer.is_empty(): continue
		sale_days += 1
		assert(offer.cut in [10, 20] and offer.price == Backend.rival_price(offer.id) - offer.cut and offer.price >= 50, str(offer))
	assert(sale_days > 15 and sale_days < 40, "Sharma runs a sale on most days, not every day")
	var sale_day := 3
	while Backend.rival_sale_for_day(sale_day).is_empty(): sale_day += 1
	market.day = sale_day
	var today: Dictionary = market.rival_sale()
	for id in market.Catalog.IDS:
		assert(market.rival_price_today(id) == (today.price if id == today.id else Backend.rival_price(id)))

	# --- Music volume setting and the Music bus ---
	var Settings := preload("res://game_settings.gd")
	var settings_path := OS.get_environment("TEMP").path_join("economy_settings_%d.cfg" % Time.get_ticks_usec())
	var settings = Settings.new()
	settings.music_volume = 0.25
	assert(settings.save_file(settings_path))
	var loaded = Settings.new()
	loaded.load_file(settings_path)
	assert(is_equal_approx(loaded.music_volume, 0.25))
	loaded.apply_global()
	var music_bus := AudioServer.get_bus_index("Music")
	assert(music_bus > 0 and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.25)))
	DirAccess.remove_absolute(settings_path)

	# --- In the game ---
	var fixture = load("res://main.tscn.tscn").instantiate()
	fixture.get_node("Shop/ShopArea").save_path = _path()
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	change_scene_to_packed(packed)
	await scene_changed
	for frame in range(3): await process_frame
	current_scene.get_node("DayClock").set_process(false)
	current_scene.get_node("CustomerSpawner/SpawnTimer").stop()
	current_scene.get_node("Player").set_physics_process(false)
	var business = current_scene.get_node("Shop/ShopArea").business
	var audio = current_scene.get_node("WorldAudio")
	assert(audio.music.stream != null and audio.ambience.stream != null and audio.rain.stream != null)
	assert(audio.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	# One continuous music player under the root, shared with the lobby.
	assert(audio.music == root.get_node("BackgroundMusic") and audio.music.bus == "Music")
	assert(audio.music.stream.resource_path.ends_with("music_nature.wav") and audio.night_ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(current_scene.get_node("Ui/ClockLabel").text.ends_with("Sunny") or not current_scene.get_node("DayClock").is_processing())
	var rival: Node3D = current_scene.get_node("Neighbourhood/RivalStore")
	assert(not rival.visible)
	business.advance_clock(2 * 1440.0)
	assert(rival.visible, "Sharma store opens on day 3")
	# Orders > Sale price shows Sharma's price and matches his sale in one click.
	var supplier = current_scene.get_node("Ui").supplier_menu
	var offer_today: Dictionary = business.rival_sale()
	if not offer_today.is_empty():
		supplier.product_input.select(business.Catalog.IDS.find(offer_today.id))
		supplier._refresh()
		assert(supplier.get_node("RivalPriceLabel").text.contains("SALE") and not supplier.get_node("MatchSharmaButton").disabled)
		supplier.get_node("MatchSharmaButton").pressed.emit()
		assert(business.product_price(offer_today.id) == offer_today.price)
	var terminal = current_scene.get_node("ShopOperations").pc.get_node("ComputerTerminal")
	terminal.open(true)
	for frame in range(10): await process_frame
	terminal.open_bank()
	assert(terminal.bank.visible)
	money = business.money
	terminal.bank.take_button.pressed.emit()
	assert(business.money == money + 20000 and business.loan_left() == 20000)
	terminal.close()
	assert(not terminal.bank.visible)

	business.save_path = ""
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("PASS: bank loan instalments/repay/validation, deterministic rain weather with traffic and farm effects, rival store pricing, Sharma daily sale and Match, music volume bus and continuous nature music, rain/bank wiring")
	quit()
