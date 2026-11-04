extends Panel

# "APNA REVIEWS" page on the shop PC: the star rating with this week's trend, how many
# reviews of each star, the town's popularity, shoppers on the last seven days, what people
# complain about (with a tip) and the newest written reviews. Reads customer_reviews.gd,
# business_backend.gd popularity and day_report.gd history; refreshes while open.
signal back_requested

const KenneyTheme = preload("res://kenney_theme.gd")
const Reviews = preload("res://customer_reviews.gd")
const SIZE := Vector2(912, 468)
const BRAND := Color("b45309")
const GOLD := Color("f59e0b")
const GOOD := Color("15803d")
const BAD := Color("b91c1c")
const TRACK := Color("fde7c4")
const SHOWN_REVIEWS := 20
const COMPLAINTS := {"stock": ["Out of stock", "keep every shelf full."], "price": ["Too dear", "bring prices near the MRP."], "wait": ["Long wait", "serve faster or hire a cashier."]}
var business
var big_rating: Label
var star_row: Label
var count_label: Label
var reputation_label: Label
var trend_label: Label
var star_fills: Array[ColorRect] = []
var star_counts: Array[Label] = []
var town_label: Label
var town_fill: ColorRect
var town_note: Label
var chart: Control
var complaints_label: Label
var review_list: VBoxContainer
var shown := ""
var tick := 0.0

func setup(business_ref, _money_formatter: Callable) -> void:
	business = business_ref
	name = "ReviewsPage"
	size = SIZE
	var page_theme := Theme.new()
	page_theme.default_font_size = 16
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("fffbeb"), 12))
	var bar := Panel.new()
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(BRAND, 12))
	add_child(bar)
	var logo := _label("APNA REVIEWS", Vector2(18, 8), 360, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("What Dholkarpur says about Apna Mart", Vector2(20, 38), 460, 11, Color("ffedd5"), bar)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.position = Vector2(748, 12)
	back.size = Vector2(146, 36)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): back_requested.emit())
	bar.add_child(back)
	# Left: the rating and the stars it is made of.
	var rating_card := _card(Vector2(20, 76), Vector2(280, 160), "RATING")
	big_rating = _label("-", Vector2(16, 36), 104, 48, Color("3a2a1e"), rating_card)
	big_rating.size.y = 60
	star_row = _label("", Vector2(112, 46), 160, 24, GOLD, rating_card)
	count_label = _label("", Vector2(114, 76), 156, 12, KenneyTheme.MUTED, rating_card)
	reputation_label = _label("", Vector2(114, 94), 156, 12, KenneyTheme.MUTED, rating_card)
	trend_label = _label("", Vector2(16, 116), 252, 14, KenneyTheme.MUTED, rating_card)
	var stars_card := _card(Vector2(20, 246), Vector2(280, 204), "STARS")
	for stars in range(5, 0, -1):
		var y := 44.0 + (5 - stars) * 30.0
		_label("%d ★" % stars, Vector2(16, y - 4), 40, 14, Color("3a2a1e"), stars_card)
		var track := ColorRect.new()
		track.color = TRACK
		track.position = Vector2(60, y)
		track.size = Vector2(150, 12)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_card.add_child(track)
		var fill := ColorRect.new()
		fill.color = GOLD if stars >= 4 else (Color("fbbf24") if stars == 3 else Color("f97316"))
		fill.position = track.position
		fill.size = Vector2(0, 12)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_card.add_child(fill)
		star_fills.append(fill)
		var count := _label("0", Vector2(214, y - 4), 50, 13, KenneyTheme.MUTED, stars_card)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		star_counts.append(count)
	# Middle: the town's word, the last days and the complaints.
	var town_card := _card(Vector2(316, 76), Vector2(280, 120), "TOWN")
	town_label = _label("", Vector2(16, 38), 248, 18, Color("3a2a1e"), town_card)
	var town_track := ColorRect.new()
	town_track.color = TRACK
	town_track.position = Vector2(16, 70)
	town_track.size = Vector2(248, 12)
	town_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	town_card.add_child(town_track)
	town_fill = ColorRect.new()
	town_fill.position = town_track.position
	town_fill.size = Vector2(0, 12)
	town_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	town_card.add_child(town_fill)
	# Marks where Known, Popular and Famous begin.
	for tier in business.POPULARITY_TIERS.slice(1):
		var mark := ColorRect.new()
		mark.color = Color("3a2a1e")
		mark.position = town_track.position + Vector2(248.0 * float(tier[0]) / 100.0, -2)
		mark.size = Vector2(2, 16)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		town_card.add_child(mark)
	town_note = _label("", Vector2(16, 88), 248, 12, KenneyTheme.MUTED, town_card)
	var chart_card := _card(Vector2(316, 206), Vector2(280, 130), "SHOPPERS, LAST 7 DAYS")
	chart = Control.new()
	chart.position = Vector2(16, 40)
	chart.size = Vector2(248, 82)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.draw.connect(_draw_chart)
	chart_card.add_child(chart)
	var complaints_card := _card(Vector2(316, 346), Vector2(280, 104), "COMPLAINTS")
	complaints_label = _label("", Vector2(16, 38), 252, 12, Color("3a2a1e"), complaints_card)
	complaints_label.size.y = 60
	complaints_label.clip_text = false
	complaints_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Right: the newest written reviews.
	var reviews_card := _card(Vector2(612, 76), Vector2(280, 374), "NEWEST REVIEWS")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 40)
	scroll.size = Vector2(260, 326)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reviews_card.add_child(scroll)
	review_list = VBoxContainer.new()
	review_list.custom_minimum_size.x = 244
	review_list.add_theme_constant_override("separation", 6)
	scroll.add_child(review_list)

func _process(delta: float) -> void:
	if not visible: return
	tick += delta
	if tick >= 1.0:
		tick = 0.0
		refresh()

func refresh() -> void:
	if business == null: return
	var reviews = business.customer_reviews
	var rating: float = reviews.rating()
	big_rating.text = "%.1f" % rating if rating > 0.0 else "-"
	star_row.text = Reviews.star_text(roundi(rating)) if rating > 0.0 else Reviews.star_text(0)
	var written: int = reviews.written_count()
	count_label.text = "%d written review%s" % [written, "" if written == 1 else "s"]
	reputation_label.text = "Reputation %d/100" % reviews.reputation
	_show_trend(rating)
	var counts: Array = reviews.star_counts
	var most := 1
	for value in counts: most = maxi(most, int(value))
	for index in range(5):
		var stars := 5 - index
		star_fills[index].size.x = 150.0 * int(counts[stars - 1]) / most
		star_counts[index].text = str(counts[stars - 1])
	town_label.text = "%s  (%d/100)" % [business.popularity_name(), roundi(business.popularity)]
	town_fill.size.x = 248.0 * business.popularity / 100.0
	town_fill.color = [Color("9ca3af"), Color("60a5fa"), GOOD, GOLD][business.popularity_tier()]
	town_note.text = "About %d shoppers a day now" % roundi(business.customers_per_day())
	chart.queue_redraw()
	_show_complaints(reviews.complaints())
	var signature := "%d|%d" % [written, reviews.written.size()]
	if signature != shown:
		shown = signature
		_fill_reviews(reviews.written)

## This week: today's rating against the one a week ago (from the day report history).
func _show_trend(rating: float) -> void:
	var history: Array = business.day_report.history
	var then := 0
	for entry in history.slice(maxi(0, history.size() - 7)):
		if int(entry.get("rating10", 0)) > 0:
			then = int(entry.rating10)
			break
	trend_label.remove_theme_color_override("font_color")
	if rating <= 0.0:
		trend_label.text = "Reviews appear as shoppers write them."
		return
	var moved := roundi(rating * 10.0) - then
	if then == 0 or moved == 0:
		trend_label.text = "Steady this week"
		trend_label.add_theme_color_override("font_color", KenneyTheme.MUTED)
	else:
		trend_label.text = "%s %s%.1f this week" % ["▲" if moved > 0 else "▼", "+" if moved > 0 else "", moved / 10.0]
		trend_label.add_theme_color_override("font_color", GOOD if moved > 0 else BAD)

func _show_complaints(counts: Dictionary) -> void:
	var kinds: Array = counts.keys().filter(func(kind): return int(counts[kind]) > 0)
	if kinds.is_empty():
		complaints_label.text = "No complaints in the recent reviews. Keep it up!"
		complaints_label.add_theme_color_override("font_color", GOOD)
		return
	complaints_label.add_theme_color_override("font_color", Color("3a2a1e"))
	kinds.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	var parts: Array = kinds.map(func(kind): return "%s: %d" % [COMPLAINTS[kind][0], counts[kind]])
	complaints_label.text = "%s\nTip: %s" % ["   ".join(parts), COMPLAINTS[kinds[0]][1]]

## Newest first: stars and name, when, and what they wrote.
func _fill_reviews(written: Array) -> void:
	for child in review_list.get_children():
		review_list.remove_child(child)
		child.queue_free()
	if written.is_empty():
		var empty := _label("No written reviews yet. About a third of shoppers write one.", Vector2.ZERO, 244, 13, KenneyTheme.MUTED, review_list)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.clip_text = false
		empty.custom_minimum_size = Vector2(244, 40)
		return
	for index in range(written.size() - 1, maxi(-1, written.size() - 1 - SHOWN_REVIEWS), -1):
		var entry: Dictionary = written[index]
		var card := PanelContainer.new()
		var style := _flat(Color.WHITE if int(entry.stars) >= 3 else Color("fff1f2"), 8)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 5
		style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", style)
		review_list.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 1)
		card.add_child(column)
		var head := Label.new()
		head.text = "%s  %s" % [Reviews.star_text(int(entry.stars)), entry.name]
		head.add_theme_font_size_override("font_size", 13)
		head.add_theme_color_override("font_color", GOLD if int(entry.stars) >= 3 else BAD)
		head.clip_text = true
		column.add_child(head)
		var words := Label.new()
		words.text = "\"%s\"" % entry.text
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size.x = 226
		words.add_theme_font_size_override("font_size", 13)
		words.add_theme_color_override("font_color", Color("3a2a1e"))
		column.add_child(words)
		var when := Label.new()
		when.text = "Day %d, %02d:%02d" % [int(entry.day), int(entry.minute) / 60, int(entry.minute) % 60]
		when.add_theme_font_size_override("font_size", 11)
		when.add_theme_color_override("font_color", KenneyTheme.MUTED)
		column.add_child(when)

## Shoppers on each of the last seven finished days, as bars.
func _draw_chart() -> void:
	var days: Array = business.day_report.history.slice(maxi(0, business.day_report.history.size() - 7))
	var font := ThemeDB.fallback_font
	if days.is_empty():
		chart.draw_string(font, Vector2(0, 46), "Each finished day shows here.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, KenneyTheme.MUTED)
		return
	var most := 1
	for entry in days: most = maxi(most, int(entry.shoppers))
	var slot := chart.size.x / 7.0
	for index in range(days.size()):
		var height := (chart.size.y - 32.0) * int(days[index].shoppers) / most
		var x := index * slot + slot * 0.2
		chart.draw_rect(Rect2(x, chart.size.y - 16.0 - height, slot * 0.6, maxf(2.0, height)), GOLD)
		chart.draw_string(font, Vector2(x - 2, chart.size.y - 18.0 - height), str(days[index].shoppers), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("3a2a1e"))
		chart.draw_string(font, Vector2(x - 2, chart.size.y - 2.0), "D%d" % int(days[index].day), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, KenneyTheme.MUTED)

func _flat(colour: Color, radius := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	return style

func _label(text: String, position: Vector2, width: float, font_size := 14, colour := KenneyTheme.TEXT, parent: Node = self) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(width, font_size + 8)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.clip_text = true
	parent.add_child(label)
	return label

func _card(position: Vector2, card_size: Vector2, title: String) -> Panel:
	var card := Panel.new()
	card.position = position
	card.size = card_size
	add_child(card)
	var heading := _label(title, Vector2(16, 12), card_size.x - 32, 16, BRAND, card)
	heading.add_theme_font_override("font", KenneyTheme.heading_font())
	return card
