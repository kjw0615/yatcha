extends Control

const Rules = preload("res://scripts/rules.gd")
const Die = preload("res://scripts/die.gd")
const MINT = Color("76e5c0")
const WHITE = Color("eaf3f5")
const MUTED = Color("8fa7b8")
var sheets = []
var dice = [1, 1, 1, 1, 1]
var held = [false, false, false, false, false]
var player = 0
var rolls = 0
var selected = -1
var busy = false
var finished = false
var die_buttons: Array = []
var hold_labels: Array = []
var cells: Array = []
var totals: Array = []
var bonus_labels: Array = []
var turn_label: Label
var phase_label: Label
var status_label: Label
var roll_button: Button
var commit_button: Button
var history_label: Label
var history: Array = []
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	var ui_theme = Theme.new()
	ui_theme.default_font_size = 17
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.set_color("font_color", "Label", WHITE)
	theme = ui_theme
	build_ui()
	new_game()

func style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func label_in(parent: Node, text_value: String, font_size: int = 17, color: Color = WHITE) -> Label:
	var item = Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item

func button_in(parent: Node, text_value: String, action: Callable) -> Button:
	var item = Button.new()
	item.text = text_value
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_stylebox_override("normal", style(Color("203848")))
	item.add_theme_stylebox_override("hover", style(Color("31566a")))
	item.add_theme_stylebox_override("pressed", style(Color("247967")))
	item.add_theme_stylebox_override("disabled", style(Color("14232e")))
	item.add_theme_color_override("font_disabled_color", Color("536976"))
	item.pressed.connect(action)
	parent.add_child(item)
	return item

func panel_in(parent: Node) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(Color("102431"), 20))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	return column

func build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	var header = HBoxContainer.new()
	root.add_child(header)
	var brand = VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	label_in(brand, "YACHT CLUB", 32, MINT)
	label_in(brand, "다섯 개의 주사위, 열두 번의 선택", 15, MUTED)
	button_in(header, "게임 규칙", show_rules)
	button_in(header, "새 게임", confirm_restart)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)
	var left = panel_in(body)
	left.custom_minimum_size.x = 500
	label_in(left, "LOCAL MULTIPLAYER  /  2 PLAYERS", 13, MINT)
	turn_label = label_in(left, "", 28)
	phase_label = label_in(left, "", 16, MUTED)
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 32
	left.add_child(spacer)
	var tray = HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_CENTER
	tray.add_theme_constant_override("separation", 12)
	left.add_child(tray)
	for i in range(5):
		var column = VBoxContainer.new()
		tray.add_child(column)
		var die = Die.new()
		die.custom_minimum_size = Vector2(82, 90)
		die.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		die.pressed.connect(toggle_hold.bind(i))
		column.add_child(die)
		die_buttons.append(die)
		var caption = label_in(column, "", 13, MINT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hold_labels.append(caption)
	label_in(left, "주사위를 클릭해 보관하거나 보관을 해제하세요", 14, MUTED)
	roll_button = button_in(left, "", roll_dice)
	roll_button.custom_minimum_size.y = 56
	status_label = label_in(left, "", 17, MINT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	commit_button = button_in(left, "점수표에서 족보를 선택하세요", commit_score)
	commit_button.custom_minimum_size.y = 48
	var fill = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(fill)
	label_in(left, "최근 기록", 14, MUTED)
	history_label = label_in(left, "", 15)
	history_label.custom_minimum_size.y = 86
	var right = panel_in(body)
	label_in(right, "SCORECARD", 18, MINT)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	right.add_child(grid)
	label_in(grid, "족보 / 점수 조건", 14, MUTED)
	label_in(grid, "PLAYER 1", 14, MINT)
	label_in(grid, "PLAYER 2", 14, Color("efbf78"))
	for category in range(12):
		var title = label_in(grid, Rules.TITLES[category], 16)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.tooltip_text = Rules.HINTS[category]
		var row = []
		for p in range(2):
			var cell = button_in(grid, "—", select_category.bind(category))
			cell.custom_minimum_size = Vector2(100, 32)
			cell.tooltip_text = Rules.HINTS[category]
			row.append(cell)
		cells.append(row)
	label_in(grid, "숫자 합계 / 보너스", 14, MUTED)
	for p in range(2):
		bonus_labels.append(label_in(grid, "", 13, MUTED))
	label_in(grid, "TOTAL", 21, MINT)
	for p in range(2):
		totals.append(label_in(grid, "0", 26))
	label_in(right, "숫자 족보 63점 이상 → 보너스 +35", 13, MUTED)
	label_in(root, "PROTOTYPE 01     •     한 턴에 최대 3회 굴리기     •     족보는 한 번씩만 사용     •     12라운드 후 최종 점수 비교", 13, MUTED)

func new_game() -> void:
	sheets = []
	for p in range(2):
		var sheet = []
		sheet.resize(12)
		sheet.fill(-1)
		sheets.append(sheet)
	player = 0
	rolls = 0
	selected = -1
	busy = false
	finished = false
	held.fill(false)
	dice.fill(1)
	history.clear()
	refresh()

func toggle_hold(index: int) -> void:
	if rolls == 0 or busy or finished:
		return
	held[index] = not held[index]
	refresh()

func roll_dice() -> void:
	if busy or finished or rolls >= 3 or held.all(func(value): return value):
		return
	busy = true
	selected = -1
	refresh()
	for frame in range(10):
		for i in range(5):
			if not held[i]:
				dice[i] = rng.randi_range(1, 6)
		update_dice()
		await get_tree().create_timer(0.045 + frame * 0.004).timeout
	rolls += 1
	busy = false
	refresh()

func select_category(category: int) -> void:
	if busy or finished or rolls == 0 or sheets[player][category] >= 0:
		return
	selected = category
	refresh()

func commit_score() -> void:
	if selected < 0 or busy or finished or rolls == 0 or sheets[player][selected] >= 0:
		return
	var points = Rules.score(dice, selected)
	sheets[player][selected] = points
	history.push_front("P%d  ·  %s  +%d" % [player + 1, Rules.TITLES[selected], points])
	if history.size() > 3:
		history.pop_back()
	finished = not sheets[0].has(-1) and not sheets[1].has(-1)
	if not finished:
		player = 1 - player
	rolls = 0
	selected = -1
	held.fill(false)
	refresh()

func update_dice() -> void:
	for i in range(5):
		var die = die_buttons[i]
		die.value = dice[i]
		die.held = held[i]
		die.disabled = busy or finished or rolls == 0
		var color = Color("b8f5dc") if held[i] else Color("f0f0df")
		die.add_theme_stylebox_override("normal", style(color, 14))
		die.add_theme_stylebox_override("disabled", style(color.darkened(0.10) if rolls == 0 else color, 14))
		die.add_theme_stylebox_override("hover", style(color.lightened(0.1), 14))
		die.add_theme_stylebox_override("pressed", style(Color("76e5c0"), 14))
		die.queue_redraw()
		hold_labels[i].text = "보관 중" if held[i] else ""

func refresh() -> void:
	update_dice()
	var completed = 12 - sheets[player].count(-1)
	turn_label.text = "PLAYER %d의 차례" % (player + 1)
	phase_label.text = "ROUND %02d / 12     ·     굴리기 %d / 3" % [mini(12, completed + 1), rolls]
	roll_button.text = "주사위 굴리기   ·   %d회 남음" % (3 - rolls)
	roll_button.disabled = busy or finished or rolls >= 3 or held.all(func(value): return value)
	commit_button.disabled = selected < 0 or busy or finished
	status_label.text = "주사위를 굴려 이번 턴을 시작하세요."
	if busy:
		status_label.text = "주사위를 굴리는 중…"
	elif rolls > 0:
		status_label.text = "보관할 주사위를 고르거나, 오른쪽에서 족보를 선택하세요."
		if rolls == 3:
			status_label.text = "굴리기를 모두 사용했습니다. 기록할 족보를 선택하세요."
	commit_button.text = "점수표에서 족보를 선택하세요"
	if selected >= 0:
		var points = Rules.score(dice, selected)
		commit_button.text = "%s · %d점 기록 확정" % [Rules.TITLES[selected], points]
		if points == 0:
			status_label.text = "이 족보를 0점으로 소진합니다. 확정 전에 확인하세요."
	for p in range(2):
		totals[p].text = str(Rules.total(sheets[p]))
		bonus_labels[p].text = "%d/63 · +%d" % [Rules.upper(sheets[p]), Rules.bonus(sheets[p])]
		for category in range(12):
			var cell = cells[category][p]
			var recorded = sheets[p][category]
			cell.disabled = p != player or recorded >= 0 or rolls == 0 or busy or finished
			cell.text = str(recorded) if recorded >= 0 else "—"
			cell.add_theme_color_override("font_disabled_color", WHITE if recorded >= 0 else MUTED)
			if recorded < 0 and p == player and rolls > 0 and not finished:
				cell.text = "%d" % Rules.score(dice, category)
			var color = Color("247967") if selected == category and p == player else Color("203848")
			cell.add_theme_stylebox_override("normal", style(color))
	history_label.text = "\n".join(history) if not history.is_empty() else "첫 번째 기록을 기다리고 있습니다."
	if finished:
		var first = Rules.total(sheets[0])
		var second = Rules.total(sheets[1])
		turn_label.text = "무승부!" if first == second else "PLAYER %d 승리!" % (1 if first > second else 2)
		phase_label.text = "최종 결과   ·   %d : %d" % [first, second]
		status_label.text = "한 판이 끝났습니다. 새 게임으로 다시 도전하세요."

func show_rules() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "요트 다이스 · 플레이 방법"
	dialog.dialog_text = "두 명이 번갈아 12번씩 플레이합니다.\n\n1. 주사위 5개를 굴립니다. 한 턴에 최대 3회입니다.\n2. 클릭한 주사위는 보관되어 다시 굴리지 않습니다.\n3. 점수표의 빈 족보를 선택하고 기록을 확정합니다.\n   조건을 충족하지 못해도 0점으로 기록할 수 있습니다.\n4. 숫자 1~6 족보 합계가 63점 이상이면 +35점입니다.\n5. 모든 칸을 채운 뒤 총점이 높은 사람이 승리합니다.\n\n초이스: 전체 합 / 포카드: 같은 눈 4개 이상이면 전체 합\n풀하우스: 정확히 3개+2개면 전체 합 (요트는 제외)\n스몰: 연속 4개 15점 / 라지: 연속 5개 30점\n요트: 같은 눈 5개 50점\n\n족보에 마우스를 올리면 점수 조건을 볼 수 있습니다."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(650, 530))

func confirm_restart() -> void:
	if busy:
		return
	var dialog = ConfirmationDialog.new()
	dialog.title = "새 게임"
	dialog.dialog_text = "현재 점수를 초기화하고 새 게임을 시작할까요?"
	add_child(dialog)
	dialog.confirmed.connect(func():
		new_game()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
