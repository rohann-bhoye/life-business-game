extends SceneTree

# The AI Tester bot (ai_tester.gd) must finish short games, report no broken rule and
# produce a readable report. A BUG here means the bot found a real problem in the
# game rules (the report text says which); fix the game, or the bot if it is wrong.
const AiTester := preload("res://ai_tester.gd")
const Backend := preload("res://business_backend.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Found by the bot (2026-11-05): bulk shoppers carry 5-7 of one product and family
	# baskets can be 8+ items over Rs1000; the sale and the save check must allow both.
	assert(Backend.MAX_BASKET_LINE >= 7)
	assert(Backend._is_basket_visit("Basket of 8 items for %s1200" % String.chr(8377)))
	assert(Backend._is_basket_visit("Basket of 5 items for %s1000" % String.chr(8377)))
	assert(not Backend._is_basket_visit("Basket of 1 items for %s100" % String.chr(8377)))
	assert(not Backend._is_basket_visit("Basket of 3 items for %s105" % String.chr(8377)))
	var bot = AiTester.new()
	var results: Array = bot.run_suite(4, 7)
	var text: String = bot.report_text(results)
	assert(results.size() == AiTester.STYLE_ORDER.size())
	for result in results:
		assert(int(result.days) >= 1 and int(result.checks) > 0 and not result.rows.is_empty())
		assert(int(result.items_sold) > 0 or result.style == "lazy")
	assert(text.contains("# AI Tester report") and text.contains("## Problems found"))
	# Same seed, same game.
	var again = AiTester.new().play("balanced", 4, 7, 1)
	assert(again.money_end == results[0].money_end and again.items_sold == results[0].items_sold)
	var bugs := 0
	for result in results:
		for item in result.findings:
			if item.level == "BUG": bugs += 1
	if bugs > 0: print(text)
	assert(bugs == 0, "The AI Tester found %d broken rule(s); see the report above" % bugs)
	print("PASS: AI Tester plays %d test games with no broken rule, same seed gives the same game, report is readable" % results.size())
	quit()
