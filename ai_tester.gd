extends RefCounted

# AI Tester: a rule-based "player" that plays the shop for a number of days and
# writes a short report.
#
# - It uses the same Backend methods the game uses (order, deliver, shelve, sell,
#   hire, upgrade, loan, licences, sleep) and checks the game rules after every step.
# - It is NOT an AI service: no network, no API calls, so it uses no tokens and
#   costs nothing. The "AI" is a fixed set of play rules plus a random customer.
# - It plays a throw-away Backend with no save file, so real saves are never touched.
# - Same seed = same game, so a problem can be reproduced.
#
# Use: `var bot = preload("res://ai_tester.gd").new()`, `bot.run_suite(10, 1)` returns
# the results, `bot.report_text(results)` turns them into the text report.
# Command line: tools/ai_tester_run.gd. In the game: AI Test button on the main menu.

const Backend := preload("res://business_backend.gd")
const Catalog := preload("res://product_catalog.gd")
const RackStore := preload("res://rack_store.gd")
const Settings := preload("res://game_settings.gd")

## Play styles. reserve = cash the bot keeps; hire_day = first day it hires staff;
## grow = buys licences, upgrades, expansion, wings, racks and new products;
## restock_until = last day it orders stock (lazy stops after day 1 to test empty shelves);
## pay_bills = pays bills by hand (lazy leaves it to the daily auto-payment);
## markup = shelf prices over the MRP (aggressive tests the price rules: some walk out);
## story = the story start: shop for sale (bought from Seth Ramlal) and a rented home.
const STYLE_ORDER := ["balanced", "aggressive", "lazy", "story"]
const STYLES := {
	"balanced": {"reserve": 1500, "hire_day": 3, "grow": true, "restock_until": 9999, "marketing": true, "pay_bills": true, "markup": 1.0, "story": false},
	"aggressive": {"reserve": 300, "hire_day": 1, "grow": true, "restock_until": 9999, "marketing": true, "pay_bills": true, "markup": 1.25, "story": false},
	"lazy": {"reserve": 1500, "hire_day": 9999, "grow": false, "restock_until": 1, "marketing": false, "pay_bills": false, "markup": 1.0, "story": false},
	"story": {"reserve": 1500, "hire_day": 4, "grow": true, "restock_until": 9999, "marketing": true, "pay_bills": true, "markup": 1.0, "story": true},
}
## Real seconds -> game minutes at the default (Relaxed) day length, like day_clock.gd.
const MINUTES_PER_SECOND: float = Settings.DAY_SPEEDS[2]
## customer_spawner.gd GAP_SPREAD: the real gap is the average times this chance.
const GAP_SPREAD := Vector2(0.55, 1.45)
## Shopper types, like customer.gd: weight, budget per item (in tens of rupees),
## most different products in the basket and most of one product.
const MAX_FINDINGS := 40
## The name on the bot's star reviews (APNA REVIEWS app), so they are easy to spot.
const SHOPPER := "AI Tester"
## Same numbers as customer.gd SHOPPER_TYPES: items = how many of the main product,
## extras = other products (each extra_count), haggle = may bargain the main price.
const KINDS := [
	{"name": "quick", "weight": 35, "budget": [8, 15], "items": [1, 1], "extras": [0, 0], "extra_count": [1, 1], "haggle": true},
	{"name": "regular", "weight": 40, "budget": [10, 20], "items": [1, 3], "extras": [0, 1], "extra_count": [1, 1], "haggle": true},
	{"name": "family", "weight": 20, "budget": [14, 25], "items": [2, 4], "extras": [1, 2], "extra_count": [1, 2], "haggle": false},
	{"name": "bulk", "weight": 5, "budget": [12, 20], "items": [5, 7], "extras": [0, 0], "extra_count": [1, 1], "haggle": false},
]

var rng := RandomNumberGenerator.new()
var state                      # the Backend being played
var style_name := "balanced"
var style := {}
var seed_value := 1
var findings: Array = []       # {level BUG|WARN|NOTE, day, text, count}
var seen := {}                 # "level+text" -> index in findings (so repeats are counted)
var actions := {}              # action name -> [done, refused]
var rows: Array = []           # one entry per finished day
var customers := {}
var ranged := {}               # products the shop sells (the bot orders these)
var checks := 0
var marketing_left := 0.0
var last := {}                 # counters of the last check: they must never go down
var racks_bought := 0
var stopped := false

# --- Public ---------------------------------------------------------------

func run_suite(days := 10, seed_number := 1) -> Array:
	var results: Array = []
	for name in STYLE_ORDER:
		results.append(play(name, days, seed_number, 1))
	return results

func play(style_id: String, days: int, seed_number: int, difficulty := 1) -> Dictionary:
	var started := Time.get_ticks_msec()
	_reset(style_id, seed_number)
	_setup(difficulty, bool(style.story))
	var money_start: int = state.money
	var played := 0
	for index in range(maxi(1, days)):
		_play_day()
		played += 1
		if stopped: break
	# The game's numbers are taken before the fuzz round: its junk calls buy random things.
	var result := {
		"style": style_id, "seed": seed_number, "days": played, "difficulty": difficulty,
		"money_start": money_start, "money_end": int(state.money), "net_profit": int(state.net_profit()),
		"items_sold": int(state.items_sold), "missed": int(state.missed_sales), "walkouts": int(state.price_walkouts),
		"reputation": int(state.customer_reviews.reputation), "rating": float(state.customer_reviews.rating()),
		"popularity": int(round(state.popularity)), "shop_level": int(state.shop_level),
		"expansion": int(state.shop_expansion), "wing": int(state.shop_wing), "racks": int(state.racks.records.size()),
		"home": "owned" if state.house_owned else ("rented" if state.home_rented else "none"), "rent_paid": int(state.rent_paid),
		"staff": int(state.staff_count()), "licences": state.licences.keys(), "loan_left": int(state.loan_left()),
	}
	_fuzz(120)
	_check("End")
	_roundtrip("End")
	result.merge({"customers": customers.duplicate(), "findings": findings.duplicate(true), "rows": rows.duplicate(true), "actions": actions.duplicate(true), "checks": checks, "ms": Time.get_ticks_msec() - started})
	return result

# --- Set-up and bookkeeping ----------------------------------------------------

func _reset(style_id: String, seed_number: int) -> void:
	style_name = style_id
	style = STYLES[style_id]
	seed_value = seed_number
	rng.seed = seed_number
	findings = []
	seen = {}
	actions = {}
	rows = []
	customers = {"served": 0, "missed_stock": 0, "missed_price": 0, "walked_out": 0}
	ranged = {"bottle": true}
	checks = 0
	marketing_left = 0.0
	last = {}
	racks_bought = 0
	stopped = false

## The same start as a new game from the menu (game_session.new_game), without a save
## file (save_path stays empty, so nothing is ever written to disk).
func _setup(difficulty: int, story: bool) -> void:
	state = Backend.new()
	state.difficulty = clampi(difficulty, 0, 2)
	state.starting_money = Backend.DIFFICULTY_MONEY[state.difficulty]
	state.money = state.starting_money
	_expect(state.start_with_one_rack(), "New game: start_with_one_rack() failed")
	state.start_with_licences()
	if story:
		state.start_unowned_shop()
		_expect(state.start_renting(), "Story start: start_renting() failed")
	else:
		_expect(state.grant_home(), "New game: grant_home() failed")
	_set_prices()
	_check("Start")

## Shelf prices: the MRP times the style's markup, in steps of Rs10 (Rs50-200 rule).
func _set_prices() -> void:
	var markup: float = float(style.markup)
	if is_equal_approx(markup, 1.0): return
	for id in Catalog.IDS:
		var price: int = clampi(int(round(Backend.fair_price(id) * markup / 10.0)) * 10, 50, 200)
		_act("set_price", state.set_product_price(id, price))

func _act(action: String, ok: bool) -> bool:
	var entry: Array = actions.get(action, [0, 0])
	entry[0 if ok else 1] += 1
	actions[action] = entry
	return ok

func _find(level: String, text: String) -> void:
	var key := level + text
	if seen.has(key):
		var item: Dictionary = findings[int(seen[key])]
		item["count"] = int(item["count"]) + 1
		return
	if findings.size() >= MAX_FINDINGS: return
	seen[key] = findings.size()
	findings.append({"level": level, "day": int(state.day), "text": text, "count": 1})

func _expect(condition: bool, text: String, level := "BUG") -> void:
	checks += 1
	if not condition: _find(level, text)

# --- Rule checks -------------------------------------------------------------

## Things that must always be true, whatever the player did.
func _check(where: String) -> void:
	_expect(state.money >= 0, "%s: money went below zero (%d)" % [where, state.money])
	_expect(state.stock >= 0 and state.boxed_stock >= 0 and state.carried_stock >= 0 and state.worker_carried_stock >= 0, "%s: a stock counter went below zero" % where)
	for id in Catalog.IDS:
		_expect(state.product_stock(id) >= 0, "%s: %s stock is negative (%d)" % [where, id, state.product_stock(id)])
	_expect(state.minutes_of_day >= 0.0 and state.minutes_of_day < 1440.0 and state.day >= 1, "%s: the clock is out of range (day %d, minute %s)" % [where, state.day, state.minutes_of_day])
	_expect(state.popularity >= 0.0 and state.popularity <= 100.0, "%s: popularity is out of 0-100 (%s)" % [where, state.popularity])
	_expect(state.operating_due >= 0 and state.wages_due >= 0 and state.rent_due >= 0, "%s: a bill went below zero" % where)
	_expect(not (state.house_owned and state.home_rented), "%s: the home is owned and rented at the same time" % where)
	var stars: float = state.customer_reviews.rating()
	_expect(stars >= 0.0 and stars <= 5.0, "%s: the star rating is out of 0-5 (%s)" % [where, stars])
	for id in Catalog.EXTRA:
		var item: Dictionary = state.inventory[id]
		_expect(int(item.sold) <= int(item.purchased), "%s: %s sold more than was ever bought" % [where, id])
	var now := {"day": state.day, "items_sold": state.items_sold, "sales_revenue": state.sales_revenue, "restocking_expenses": state.restocking_expenses, "missed_sales": state.missed_sales, "price_walkouts": state.price_walkouts, "rent_paid": state.rent_paid, "reviews": state.customer_reviews.review_count}
	for key in now:
		_expect(int(now[key]) >= int(last.get(key, 0)), "%s: %s went down (%d -> %d)" % [where, key, int(last.get(key, 0)), int(now[key])])
	last = now
	# Cash book: every rupee in or out must be in the totals the tablet shows.
	var expected: int = state.starting_money + state.sales_revenue + state.loan_received - state.loan_principal_repaid - state.total_spending()
	_expect(state.money == expected, "%s: cash book does not add up (money %d, expected %d, off by %d)" % [where, state.money, expected, state.money - expected])
	# The game's own save check also covers the racks, bills, staff and loan rules.
	_expect(state._is_valid_snapshot(state.snapshot()), "%s: the game's save validator rejects the current state" % where)

## Save, load, save again and compare the two save texts (what lands on disk): nothing
## may be lost or changed. Comparing the texts, not the live values, ignores the last
## digits of floats that JSON rounds (popularity 16.610812577075652 -> ...757).
func _roundtrip(where: String) -> void:
	var data: Dictionary = state.snapshot()
	var text: String = JSON.stringify(data)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		_find("BUG", "%s: the snapshot is not valid JSON" % where)
		return
	var copy = Backend.new()
	copy.restore(parsed)
	var back: Dictionary = copy.snapshot()
	if JSON.stringify(back) != text:
		var changed: Array = []
		for key in data:
			if JSON.stringify(data[key]) != JSON.stringify(back.get(key)): changed.append(str(key))
		for key in back:
			if not data.has(key): changed.append(str(key))
		_find("BUG", "%s: save/load changed these fields: %s" % [where, ", ".join(changed)])
	checks += 1

# --- One day ----------------------------------------------------------------

func _play_day() -> void:
	var day_number: int = state.day
	var items_before: int = state.items_sold
	var revenue_before: int = state.sales_revenue
	var missed_before: int = state.missed_sales
	var walkouts_before: int = state.price_walkouts
	_expect((state.shop_is_open() or not state.shop_owned) and absf(state.minutes_of_day - 480.0) < 0.01, "Morning: the day does not start at 08:00 with the shop open (minute %s)" % state.minutes_of_day)
	if not state.shop_owned: _buy_the_shop()
	_morning_money()
	if state.shop_owned and state.day <= int(style.restock_until): _order_and_stock()
	_open_shop()
	var sold_today: int = state.items_sold - items_before
	_evening(day_number, sold_today)
	if stopped: return
	rows.append({"day": day_number, "money": int(state.money), "sold": sold_today, "revenue": int(state.sales_revenue) - revenue_before, "missed": int(state.missed_sales) - missed_before, "walkouts": int(state.price_walkouts) - walkouts_before, "reputation": int(state.customer_reviews.reputation), "popularity": int(round(state.popularity)), "stock": int(state.stock)})
	_check("Day %d" % day_number)
	_roundtrip("Day %d" % day_number)

## Story start: buy Apna Mart from Seth Ramlal on the first morning, like the shop door
## offer (shop_sale.gd). The starting money must cover it and still leave room to stock.
func _buy_the_shop() -> void:
	var price: int = state.shop_price()
	if not state.can_buy_shop():
		_find("BUG", "Story start: the shop costs Rs%d but there is only Rs%d, so it can never open" % [price, state.money])
		return
	var before: int = state.money
	if not _act("buy_shop", state.buy_shop()):
		_find("BUG", "buy_shop() was refused although can_buy_shop() was true")
		return
	_expect(state.shop_owned and state.money == before - price, "buy_shop() did not open the shop for exactly shop_price()")
	_expect(state.shop_is_open(), "The shop was bought at 08:00 but is not open")
	_expect(state.money >= Backend.STOCK_COST * 2, "Story start: after buying the shop only Rs%d is left for stock" % state.money, "WARN")

## Bills, loan, licences, upgrades, staff, marketing. Every purchase first asks the
## game's own can_...() and then must succeed and charge exactly the listed price.
func _morning_money() -> void:
	var reserve: int = int(style.reserve)
	if bool(style.pay_bills) and state.can_pay_bills():
		var due: int = state.unpaid_bills()
		_act("pay_bills", state.pay_bills())
		_expect(state.unpaid_bills() < due, "pay_bills() worked but the unpaid bills did not shrink")
	if state.money < reserve and state.loan_left() == 0 and state.day >= 2:
		var before: int = state.money
		if _act("take_loan", state.take_loan()):
			_expect(state.money == before + Backend.LOAN_AMOUNT, "take_loan() paid out the wrong amount")
		else:
			_find("BUG", "take_loan() was refused although no loan is open")
	if state.loan_left() > 0 and state.money >= state.loan_payoff_amount() + 5000:
		var before_pay: int = state.money
		var owed: int = state.loan_payoff_amount()
		if _act("repay_loan", state.repay_loan()):
			_expect(state.money == before_pay - owed and state.loan_left() == 0, "repay_loan() did not take exactly loan_payoff_amount()")
		else:
			_find("BUG", "repay_loan() was refused although there is enough money")
	if state.money < Backend.STOCK_COST and state.stock <= 0 and state.supply_box_count() == 0 and state.loan_left() > 0:
		_find("WARN", "Soft-lock risk: no stock, no boxes on the way, no money and a loan is already open")
	if bool(style.grow): _grow(reserve)
	if state.day >= int(style.hire_day): _hire(reserve)
	if bool(style.marketing) and state.marketing_seconds_left <= 0.0 and state.money >= Backend.MARKETING_COST + reserve + 500 and rng.randf() < 0.5:
		var before_m: int = state.money
		if _act("start_marketing", state.start_marketing()):
			marketing_left = Backend.MARKETING_DURATION * MINUTES_PER_SECOND
			_expect(state.money == before_m - Backend.MARKETING_COST, "start_marketing() charged the wrong amount")
		else:
			_find("BUG", "start_marketing() was refused although there is enough money")

func _grow(reserve: int) -> void:
	for id in ["dairy", "packaged", "fresh"]:
		var price: int = int(state.licence(id).price)
		if state.can_buy_licence(id) and state.money >= price + reserve + 1500:
			var before: int = state.money
			if _act("buy_licence", state.buy_licence(id)):
				_expect(state.money == before - price and state.licences.has(id), "buy_licence(%s) charged the wrong amount or did not grant the licence" % id)
			else:
				_find("BUG", "buy_licence(%s) was refused although can_buy_licence() was true" % id)
	if state.can_upgrade_shop() and state.money >= state.next_upgrade_cost() + reserve + 1000:
		var level: int = state.shop_level
		var cost: int = state.next_upgrade_cost()
		var before_u: int = state.money
		if _act("upgrade_shop", state.upgrade_shop()):
			_expect(state.shop_level == level + 1 and state.money == before_u - cost, "upgrade_shop() did not raise the level by one for exactly the listed price")
		else:
			_find("BUG", "upgrade_shop() was refused although can_upgrade_shop() was true")
	if state.can_expand_shop() and state.money >= state.next_expansion_cost() + reserve + 1000:
		var steps: int = state.shop_expansion
		var price_e: int = state.next_expansion_cost()
		var before_e: int = state.money
		if _act("expand_shop", state.expand_shop()):
			_expect(state.shop_expansion == steps + 1 and state.money == before_e - price_e, "expand_shop() did not add one step for exactly the listed price")
		else:
			_find("BUG", "expand_shop() was refused although can_expand_shop() was true")
	if state.can_build_wing() and state.money >= state.next_wing_cost() + reserve + 3000:
		var wing: int = state.shop_wing
		var price_w: int = state.next_wing_cost()
		var before_w: int = state.money
		if _act("build_wing", state.build_wing()):
			_expect(state.shop_wing == wing + 1 and state.money == before_w - price_w, "build_wing() did not add one wing for exactly next_wing_cost()")
		else:
			_find("BUG", "build_wing() was refused although can_build_wing() was true")
	# Story games rent the family home until it is bought; then the rent stops.
	if state.home_rented and state.money >= Backend.HOUSE_COST + reserve + 3000:
		var before_h: int = state.money
		if _act("buy_house", state.buy_house()):
			_expect(state.house_owned and not state.home_rented and state.money == before_h - Backend.HOUSE_COST, "buy_house() did not end the rent for exactly HOUSE_COST")
		else:
			_find("BUG", "buy_house() was refused although there is enough money")

func _hire(reserve: int) -> void:
	if not state.staff.active(state, "cashier") and state.money >= Backend.CASHIER_COSTS[0] + reserve + 1000:
		var before: int = state.money
		if _act("hire_worker", state.hire_worker(1)):
			_expect(state.money == before - Backend.CASHIER_COSTS[0], "hire_worker() charged the wrong amount")
		else:
			_find("WARN", "hire_worker() was refused although there is enough money and no cashier")
	if not state.staff.active(state, "stock") and state.money >= Backend.HIRING_COST + reserve + 1000:
		var before_s: int = state.money
		if _act("hire_stock_worker", state.hire_stock_worker()):
			_expect(state.money == before_s - Backend.HIRING_COST, "hire_stock_worker() charged the wrong amount")
		else:
			_find("WARN", "hire_stock_worker() was refused although there is enough money and no stock worker")

# --- Ordering and stocking ------------------------------------------------------

func _shelf_space(id: String) -> int:
	var total := 0
	for record in state.racks.records:
		total += int(state.racks.free_space(int(record.id), id))
	return total

func _licensed_ids() -> Array:
	var result: Array = []
	for id in Catalog.IDS:
		if state.has_licence(id): result.append(id)
	return result

## Orders what is running low, one product at a time: order, truck arrives, shelve.
func _order_and_stock() -> void:
	var reserve: int = int(style.reserve)
	if bool(style.grow) and state.day >= 2 and state.money > 3500:
		for id in _licensed_ids():
			if ranged.has(id): continue
			if _shelf_space(id) < 10: _get_rack(id)
			if _shelf_space(id) >= 10: ranged[id] = true
			break
	for id in ranged.keys():
		if state.product_stock(id) > 12: continue
		var space := _shelf_space(id)
		if space < 10 and bool(style.grow) and state.money > reserve + 1000 + RackStore.COST:
			_get_rack(id)
			space = _shelf_space(id)
		var boxes: int = mini(space / 10, 2 if state.money > 4000 else 1)
		if boxes < 1: continue
		if state.money - state.order_cost(id, boxes) < reserve and state.product_stock(id) > 0: continue
		if not state.can_order_stock(id, boxes): continue
		var before: int = state.money
		if not _act("order_stock", state.order_stock(id, boxes)):
			_find("BUG", "order_stock(%s, %d) was refused although can_order_stock() was true" % [id, boxes])
			continue
		_expect(before - state.money == state.order_cost(id, boxes), "order_stock(%s) charged a different price than order_cost()" % id)
		_expect(state.supply_in_transit > 0, "An order was paid but nothing is on the way")
		if not _act("receive_delivery", state.receive_delivery()):
			_find("BUG", "receive_delivery() refused a paid order")
			continue
		_expect(state.supply_in_transit == 0, "receive_delivery() left supply_in_transit above zero")
		_stock_shelves()
		_check("After stocking %s" % id)

## Picks the boxes up and puts them on the racks (the stock worker does it when on shift).
func _stock_shelves() -> void:
	var guard := 0
	while guard < 60:
		guard += 1
		var by_worker: bool = state.stock_worker_hired and state.stock_worker_on_shift()
		var carrying: int = state.worker_carried_stock if by_worker else state.carried_stock
		if carrying <= 0:
			if state.boxed_stock <= 0 and state.queued_boxes.is_empty(): return
			if not _act("pick_up_box", state.pick_up_box(by_worker)):
				_find("BUG", "pick_up_box() refused: a box is waiting and the hands are empty")
				return
		var product: String = state.pending_product
		var stock_before: int = state.stock
		var product_before: int = state.product_stock(product)
		if not _act("shelve_box", state.shelve_box(by_worker)):
			_find("WARN", "Could not shelve %s although the racks showed room (box stays in hand)" % product)
			return
		_expect(state.stock > stock_before and state.product_stock(product) > product_before, "shelve_box() worked but the stock did not go up")

## One more rack for this product: order on the PC, delivery, place it on the floor.
func _get_rack(id: String) -> void:
	if racks_bought >= 4 or not state.can_order_racks(id, 1): return
	var before: int = state.money
	if not _act("order_racks", state.order_racks(id, 1)):
		_find("BUG", "order_racks(%s) was refused although can_order_racks() was true" % id)
		return
	_expect(before - state.money == RackStore.COST, "order_racks() charged the wrong price")
	if not _act("receive_rack_delivery", state.receive_rack_delivery()):
		_find("BUG", "receive_rack_delivery() refused a paid rack")
		return
	if _place_delivered_rack(id):
		racks_bought += 1
	else:
		_find("WARN", "No free floor spot found for a %s rack (the paid rack stays in the delivery area)" % id)

## Like a player with G-move: tries the whole floor of this shop size in 10 cm steps and
## every turn until place_rack() takes it (all 8 base racks fit this way).
func _place_delivered_rack(id: String) -> bool:
	var area: Rect2 = RackStore.floor_rect(state.shop_expansion, state.shop_wing)
	var z: float = area.position.y + 0.2
	while z < area.end.y:
		var x: float = area.position.x + 0.2
		while x < area.end.x:
			for turn in range(4):
				if state.place_rack(id, Vector2(x, z), turn, -1, true):
					_act("place_rack", true)
					return true
			x += 0.1
		z += 0.1
	_act("place_rack", false)
	return false

# --- Customers --------------------------------------------------------------

func _pick_kind() -> Dictionary:
	var total := 0
	for kind in KINDS: total += int(kind.weight)
	var roll := rng.randi_range(1, total)
	for kind in KINDS:
		roll -= int(kind.weight)
		if roll <= 0: return kind
	return KINDS[0]

## Runs the shop day: shoppers come as often as the game's own spawner sends them
## (customer_gap_minutes with the same chance), until closing time.
func _open_shop() -> void:
	if not state.shop_owned:
		# Nothing to sell yet: the day just passes to closing time.
		state.advance_clock(float(Backend.SHOP_CLOSE_MINUTE) - state.minutes_of_day)
		return
	var guard := 0
	var restocked := false
	while state.shop_is_open() and guard < 3000:
		guard += 1
		var wait: float = maxf(0.5, state.customer_gap_minutes(marketing_left > 0.0) * rng.randf_range(GAP_SPREAD.x, GAP_SPREAD.y))
		var minute_before: float = state.minutes_of_day
		state.advance_clock(wait)
		_expect(state.minutes_of_day > minute_before or not state.shop_is_open(), "advance_clock() did not move the clock forward")
		if marketing_left > 0.0:
			marketing_left -= wait
			if marketing_left <= 0.0 and state.marketing_seconds_left > 0.0: state.finish_marketing()
		if not state.shop_is_open(): break
		_customer()
		# Midday: top up anything that sold out, like a player would.
		if not restocked and state.minutes_of_day >= 780.0 and state.day <= int(style.restock_until):
			restocked = true
			_order_and_stock()

func _customer() -> void:
	var kind: Dictionary = _pick_kind()
	# Budget like customer.gd: the shopper type's range, richer on Aasaan, tighter on Mushkil.
	var budget: int = maxi(50, roundi(rng.randi_range(int(kind.budget[0]), int(kind.budget[1])) * 10 * state.budget_factor() / 10.0) * 10)
	var wait_seconds: float = rng.randf_range(3.0, 40.0)
	var lines: Array = []
	var used := {}
	# Like customer.gd: shoppers go for what is on the shelf, something they can afford
	# when there is a choice; only an empty shop sends them to an empty shelf.
	var choices: Array = ranged.keys().filter(func(id): return state.product_stock(id) > 0)
	var cheap_enough: Array = choices.filter(func(id): return state.product_price(id) <= budget)
	var first_pool: Array = cheap_enough if not cheap_enough.is_empty() else (choices if not choices.is_empty() else ranged.keys())
	var haggled := false
	# The main product: they take as many as they want, or what is left on the shelf.
	var main: String = first_pool[rng.randi_range(0, first_pool.size() - 1)]
	used[main] = true
	var retail: int = state.product_price(main)
	var price: int = retail
	if bool(kind.haggle) and rng.randf() < 0.3:
		price = maxi(50, retail - 10 * rng.randi_range(1, 2))
		haggled = price < retail
	var want: int = rng.randi_range(int(kind.items[0]), int(kind.items[1]))
	var on_shelf: int = state.product_stock(main)
	lines.append({"product": main, "count": mini(want, on_shelf) if on_shelf > 0 else want, "price": price})
	# Extras (customer.gd _plan_extra_products): other stocked products they can afford, at retail.
	var others: Array = cheap_enough.filter(func(id): return id != main)
	for index in range(mini(rng.randi_range(int(kind.extras[0]), int(kind.extras[1])), others.size())):
		var extra: String = others[rng.randi_range(0, others.size() - 1)]
		if used.has(extra): continue
		used[extra] = true
		var count: int = mini(rng.randi_range(int(kind.extra_count[0]), int(kind.extra_count[1])), state.product_stock(extra))
		lines.append({"product": extra, "count": count, "price": state.product_price(extra)})
	# Price rules (customer.gd): at the shelf a dear tag can lose the shopper. Only a
	# product that is on the shelf gets this far; an empty shelf is a "stock" miss.
	var kept: Array = []
	for index in range(lines.size()):
		var line: Dictionary = lines[index]
		if state.product_stock(line.product) > 0 and rng.randf() > state.buy_chance(line.product):
			if index == 0:
				_price_walkout(line.product, wait_seconds)
				return
			continue # a too-dear extra stays on the shelf, the rest of the basket goes on
		kept.append(line)
	lines = kept
	var affordable := true
	var in_stock := true
	var total := 0
	var units := 0
	for line in lines:
		if int(line.price) > budget: affordable = false
		if state.product_stock(line.product) < int(line.count): in_stock = false
		total += int(line.price) * int(line.count)
		units += int(line.count)
	var money_before: int = state.money
	var stock_before: int = state.stock
	var sold_before: int = state.items_sold
	var missed_before: int = state.missed_sales
	var ok: bool
	if lines.size() == 1:
		ok = state.sell_basket(int(lines[0].count), budget, int(lines[0].price), lines[0].product)
	else:
		ok = state.sell_mixed_basket(lines, budget)
	_act("sell", ok)
	var expected: bool = affordable and in_stock
	var most: int = 0
	for line in lines: most = maxi(most, int(line.count))
	_expect(ok == expected, "A %s shopper's sale does not follow the rules (%d items in %d lines, most of one %d, in stock %s, affordable %s, sale returned %s)" % [kind.name, units, lines.size(), most, in_stock, affordable, ok])
	if ok:
		customers.served += 1
		_expect(state.money == money_before + total and state.stock == stock_before - units and state.items_sold == sold_before + units, "A sale changed money or stock by the wrong amount")
		state.record_customer_review("sold", wait_seconds, haggled, SHOPPER, lines[0].product)
	else:
		_expect(state.money == money_before and state.stock == stock_before and state.items_sold == sold_before, "A refused sale still changed money or stock")
		_expect(state.missed_sales == missed_before + 1, "A refused sale was not counted as a missed sale")
		if in_stock:
			customers.missed_price += 1
			state.record_customer_review("price", wait_seconds, false, SHOPPER, lines[0].product)
		else:
			customers.missed_stock += 1
			state.record_customer_review("stock", wait_seconds, false, SHOPPER, lines[0].product)

## The shelf price was too dear: they walk out (record_price_walkout), nothing is sold.
func _price_walkout(product: String, wait_seconds: float) -> void:
	var walkouts_before: int = state.price_walkouts
	var money_before: int = state.money
	var stock_before: int = state.stock
	state.record_price_walkout()
	_act("price_walkout", true)
	_expect(state.price_walkouts == walkouts_before + 1 and state.money == money_before and state.stock == stock_before, "A price walkout was not counted, or it changed money or stock")
	customers.walked_out += 1
	state.record_customer_review("price", wait_seconds, false, SHOPPER, product)

# --- Evening ----------------------------------------------------------------

func _evening(day_number: int, sold_today: int) -> void:
	_expect(not state.shop_is_open() and state.sleep_time_allowed(), "Evening: after closing time the shop should be shut and sleeping allowed")
	if not _act("sleep_until_morning", state.sleep_until_morning()):
		_find("BUG", "sleep_until_morning() was refused after closing time with a home (%s): the player is stuck" % ("owned" if state.house_owned else "rented"))
		stopped = true
		return
	_expect(state.day == day_number + 1 and absf(state.minutes_of_day - 480.0) < 0.01, "Sleeping did not land on 08:00 of the next day")
	var report: Dictionary = state.day_report.last
	_expect(not report.is_empty(), "No day report was written after sleeping")
	if not report.is_empty():
		_expect(int(report.profit) == int(report.revenue) - int(report.expenses), "Day report: profit is not revenue minus expenses")
		# The first report starts from day 2 because the clock baseline is set at the first sleep.
		if day_number >= 2: _expect(int(report.items_sold) == sold_today, "Day report says %d items sold, the sales counter says %d" % [int(report.items_sold), sold_today], "WARN")

# --- Fuzz: nonsense input must never break the game ---------------------------------

func _fuzz(rounds: int) -> void:
	var ids := ["", "nope", "bottle", "snack", "soap", "milk", "oil", "apple"]
	for index in range(rounds):
		var id: String = ids[rng.randi_range(0, ids.size() - 1)]
		var number: int = rng.randi_range(-3, 14)
		var operation: int = rng.randi_range(0, 11)
		match operation:
			0: state.order_stock(id, number)
			1: state.sell_basket(number, rng.randi_range(-50, 300), rng.randi_range(-1, 220), id)
			2: state.set_selling_price(rng.randi_range(-20, 260))
			3: state.set_product_price(id, rng.randi_range(0, 260))
			4: state.shelve_one(rng.randi_range(-2, 5))
			5: state.unshelve_one(rng.randi_range(-2, 5))
			6: state.pick_up_box()
			7: state.shelve_box()
			8: state.drop_box()
			9: state.buy_licence(["dairy", "packaged", "fresh", ""][absi(number) % 4])
			10: state.hire_worker(number)
			11: state.order_cart({id: number})
		if index % 5 == 4: _check("Fuzz call %d (operation %d, id '%s', number %d)" % [index, operation, id, number])

# --- Report ---------------------------------------------------------------

static func _num(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + out

static func verdict(results: Array) -> String:
	var bugs := 0
	var warnings := 0
	for result in results:
		for item in result.findings:
			if item.level == "BUG": bugs += 1
			elif item.level == "WARN": warnings += 1
	if bugs > 0: return "FAIL"
	return "PASS WITH WARNINGS" if warnings > 0 else "PASS"

## A short report (about 40 lines) in plain text / Markdown, to read or to paste.
func report_text(results: Array) -> String:
	var lines: PackedStringArray = []
	var checks_total := 0
	var ms_total := 0
	var bugs := 0
	var warnings := 0
	for result in results:
		checks_total += int(result.checks)
		ms_total += int(result.ms)
		for item in result.findings:
			if item.level == "BUG": bugs += 1
			elif item.level == "WARN": warnings += 1
	lines.append("# AI Tester report")
	lines.append("Verdict: %s  |  %d bugs, %d warnings  |  %d test games  |  %s rule checks  |  %.1f s" % [verdict(results), bugs, warnings, results.size(), _num(checks_total), ms_total / 1000.0])
	lines.append("Seed %d, %d days per game. The bot plays by fixed rules (no AI service, no tokens); the same seed gives the same game." % [results[0].seed, results[0].days])
	lines.append("")
	lines.append("## Games")
	for result in results:
		var c: Dictionary = result.customers
		lines.append("- %s: %d days, Rs%s -> Rs%s (profit Rs%s), sold %s, missed %s (no stock %s, over budget %s), %s walked out over price, rating %.1f stars, popularity %d, shop level %d+%d, wing %d, %d racks, %d staff, home %s (rent paid Rs%s), loan left Rs%s" % [result.style, result.days, _num(result.money_start), _num(result.money_end), _num(result.net_profit), _num(result.items_sold), _num(result.missed), _num(c.missed_stock), _num(c.missed_price), _num(c.walked_out), result.rating, result.popularity, result.shop_level, result.expansion, result.wing, result.racks, result.staff, result.home, _num(result.rent_paid), _num(result.loan_left)])
	lines.append("")
	lines.append("## Problems found")
	var any := false
	for level in ["BUG", "WARN"]:
		for result in results:
			for item in result.findings:
				if item.level != level: continue
				any = true
				lines.append("- [%s] (%s, day %d%s) %s" % [level, result.style, item.day, (", x%d" % item.count) if int(item.count) > 1 else "", item.text])
	if not any: lines.append("- None. Every rule check passed.")
	lines.append("")
	lines.append("## Day by day (%s game)" % results[0].style)
	lines.append("| Day | Money | Sold | Revenue | Missed | Walked out | Rep | Popularity | Stock |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for row in results[0].rows:
		lines.append("| %d | %s | %d | %s | %d | %d | %d | %d | %d |" % [row.day, _num(row.money), row.sold, _num(row.revenue), row.missed, row.walkouts, row.reputation, row.popularity, row.stock])
	lines.append("")
	lines.append("## Actions tried (done / refused, all games)")
	var totals := {}
	for result in results:
		for name in result.actions:
			var entry: Array = totals.get(name, [0, 0])
			entry[0] += int(result.actions[name][0])
			entry[1] += int(result.actions[name][1])
			totals[name] = entry
	var names: Array = totals.keys()
	names.sort()
	var parts: PackedStringArray = []
	for name in names: parts.append("%s %d/%d" % [name, totals[name][0], totals[name][1]])
	lines.append(", ".join(parts))
	lines.append("")
	lines.append("## Not covered")
	lines.append("Walking, 3D scene, farm, export, dungeon and co-op. Run the tests/ scenes for those.")
	return "\n".join(lines)
