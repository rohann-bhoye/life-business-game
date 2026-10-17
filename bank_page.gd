extends Panel

# "APNA BANK" page on the management PC: take the Rs20,000 business loan, see the
# daily instalment, and repay early. Kenney UI Pack styling like the store.
signal back_requested

const KenneyTheme = preload("res://kenney_theme.gd")
const SIZE := Vector2(912, 468)
var business
var format_money: Callable
var balance_label: Label
var loan_label: Label
var status_label: Label
var take_button: Button
var repay_button: Button

func setup(business_ref, money_formatter: Callable) -> void:
	business = business_ref
	format_money = money_formatter
	name = "BankPage"
	size = SIZE
	# Fill the theme before assigning it: every change to an assigned theme re-themes
	# the whole page on the next frame (that made loading the game take ~10 s longer).
	var page_theme := Theme.new()
	page_theme.default_font_size = 16
	KenneyTheme.apply(page_theme)
	theme = page_theme
	add_theme_stylebox_override("panel", _flat(Color("eff6ff"), 12))
	var bar := Panel.new()
	bar.size = Vector2(SIZE.x, 58)
	bar.add_theme_stylebox_override("panel", _flat(Color("1d4ed8"), 12))
	add_child(bar)
	var logo := _label("APNA BANK", Vector2(18, 8), 300, 26, Color.WHITE, bar)
	logo.add_theme_font_override("font", KenneyTheme.heading_font())
	_label("Business banking for small shops", Vector2(20, 38), 400, 11, Color("dbeafe"), bar)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.position = Vector2(748, 12)
	back.size = Vector2(146, 36)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): back_requested.emit())
	bar.add_child(back)
	var account := _card(Vector2(20, 76), Vector2(420, 170), "YOUR ACCOUNT")
	balance_label = _label("", Vector2(16, 44), 388, 16, KenneyTheme.TEXT, account)
	balance_label.size.y = 110
	balance_label.clip_text = false
	var offer := _card(Vector2(460, 76), Vector2(432, 370), "BUSINESS LOAN")
	var terms := _label("Borrow %s now. Pay back %s a day for %d days\n(%d%% interest), taken automatically each morning.\nMissed days wait until you have the money." % [_money(business.LOAN_AMOUNT), _money(business.loan_daily_payment_for_new()), business.LOAN_DAYS, business.LOAN_INTEREST_PERCENT], Vector2(16, 44), 400, 14, KenneyTheme.TEXT, offer)
	terms.size.y = 90
	terms.clip_text = false
	loan_label = _label("", Vector2(16, 144), 400, 15, KenneyTheme.TEXT, offer)
	loan_label.size.y = 90
	loan_label.clip_text = false
	take_button = Button.new()
	take_button.name = "TakeLoanButton"
	take_button.theme_type_variation = "PrimaryButton"
	take_button.position = Vector2(16, 248)
	take_button.size = Vector2(400, 44)
	take_button.focus_mode = Control.FOCUS_NONE
	take_button.pressed.connect(func():
		_show_status("Loan received. Use it to grow your shop!" if business.take_loan() else "You already have a loan.", true)
		refresh())
	offer.add_child(take_button)
	repay_button = Button.new()
	repay_button.name = "RepayLoanButton"
	repay_button.theme_type_variation = "InfoButton"
	repay_button.position = Vector2(16, 300)
	repay_button.size = Vector2(400, 44)
	repay_button.focus_mode = Control.FOCUS_NONE
	repay_button.pressed.connect(func():
		_show_status("Loan fully repaid." if business.repay_loan() else "Not enough money to repay everything.", business.loan_left() == 0)
		refresh())
	offer.add_child(repay_button)
	var tips := _card(Vector2(20, 262), Vector2(420, 184), "TIP")
	var tip := _label("A loan helps you buy more stock, racks or a farm expansion early. Keep enough money each morning for the instalment, staff wages and the shop bill.", Vector2(16, 44), 388, 14, KenneyTheme.MUTED, tips)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.clip_text = false
	tip.size = Vector2(388, 120)
	status_label = _label("", Vector2(20, 440), 420, 13, KenneyTheme.GREEN)
	business.changed.connect(refresh)
	refresh()

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
	var heading := _label(title, Vector2(16, 12), card_size.x - 32, 16, Color("1d4ed8"), card)
	heading.add_theme_font_override("font", KenneyTheme.heading_font())
	return card

func _money(value: int) -> String:
	return String.chr(8377) + (format_money.call(value) if format_money.is_valid() else str(value))

func _show_status(text: String, good: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", KenneyTheme.GREEN if good else Color("b91c1c"))

func refresh() -> void:
	if business == null: return
	balance_label.text = "Money: %s\nNet profit: %s\nUnpaid bills: %s\nLoan interest paid: %s" % [_money(business.money), _money(business.net_profit()), _money(business.unpaid_bills()), _money(business.loan_interest_paid)]
	var left: int = business.loan_left()
	if left > 0:
		loan_label.text = "Loan left: %s\nNext instalment: %s each morning\nMissed payments: %d" % [_money(left), _money(business.loan_daily_payment()), business.loan_missed_payments]
	else:
		loan_label.text = "No active loan."
	take_button.text = "Take loan - %s" % _money(business.LOAN_AMOUNT)
	take_button.disabled = left > 0
	repay_button.text = "Repay all now - %s" % _money(business.loan_payoff_amount()) if left > 0 else "Nothing to repay"
	repay_button.disabled = left <= 0 or business.money < business.loan_payoff_amount()
